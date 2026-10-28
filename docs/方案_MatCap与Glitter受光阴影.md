# 方案：MatCap / Glitter 的受光与阴影（4 项）

> 目标参数：`_MatCapEnableLighting`、`_MatCapShadowMask`、`_GlitterEnableLighting`、`_GlitterShadowMask`
> 状态：**方案，未实施**。写于 2026-10-28。

## 1. 原版行为

`lil_common_frag.hlsl` 里 MatCap 的收尾（`lilGetMatCap`）：

```hlsl
matCapColor.rgb = lerp(matCapColor.rgb, matCapColor.rgb * fd.lightColor, _MatCapEnableLighting);
matCapColor.a   = lerp(matCapColor.a,   matCapColor.a   * fd.shadowmix,  _MatCapShadowMask);
```

Glitter 同构：

```hlsl
glitterColor.rgb = lerp(glitterColor.rgb, glitterColor.rgb * fd.lightColor, _GlitterEnableLighting);
glitterColor.a   = lerp(glitterColor.a,   glitterColor.a   * fd.shadowmix,  _GlitterShadowMask);
```

关键点：

- `fd.lightColor` 与 `fd.shadowmix` 都是**逐光源**的量，只在光照阶段存在
- 两个参数都是 0..1 的插值权重，**默认 0**（即默认不受光、不受阴影，与我们当前行为一致）
- 只影响这个效果的亮度/显隐，不改变采样位置

## 2. 当前实现与差距

MatCap 与 Glitter 都写在 `fragment()` 里，结果直接进 `EMISSION`：

```glsl
// fragment.gdshaderinc
EMISSION += mc * matcap_weight;                                  // MatCap
EMISSION += glitter_tint * glitter_mask * glitter_intensity;     // Glitter
```

`EMISSION` 是自发光，**不参与光照、不受阴影**。所以：

| 参数 | 当前 | 差距 |
|---|---|---|
| `_MatCapEnableLighting` | 不存在 | MatCap 永远以全亮度显示，暗处也发亮 |
| `_MatCapShadowMask` | 不存在 | 阴影里 MatCap 不减淡 |
| `_GlitterEnableLighting` | 不存在 | 同上 |
| `_GlitterShadowMask` | 不存在 | 同上 |

这不是"漏加参数"，而是**渲染阶段放错了位置**：这两个效果需要光照信息，但被算在了光照之前。

## 3. 三个可选方案

### 方案 A：搬到 `light()`，逐光源累加（精确）

把 MatCap / Glitter 的计算从 `fragment()` 移进 `light()`：

```glsl
// lighting.gdshaderinc，light() 内
if (use_matcap && (matcap_enable_lighting > 0.0 || matcap_shadow_mask > 0.0)) {
    vec3 mc = lil_sample_matcap(lil_shaded_normal(UV), ..., UV);
    vec3 tint = mix(vec3(1.0), light_rgb, matcap_enable_lighting);
    float sh = mix(1.0, shadow, matcap_shadow_mask);
    SPECULAR_LIGHT += mc * tint * sh * matcap_weight;
}
```

- **优点**：语义与原版一致，`lightColor`、`shadow` 都能拿到，多光源行为正确
- **缺点**：
  - 逐光源重复采样 MatCap 贴图（3 个光源 = 3 次采样 + 3 次法线贴图采样）
  - `light()` 里没有 `TANGENT`/`BINORMAL`，重建映射后法线要走 varying `lil_tangent_view`
  - 需要在 `light()` 里重复一遍法线贴图的解包与 TBN 变换（现在这段在 `fragment()`）
  - 采样器数量不变，但逐光源采样对这台弱机是实打实的开销

### 方案 B：留在 `fragment()`，用近似量代替（不精确）

在片元用 `AMBIENT_LIGHT` 或 `ALBEDO` 近似"亮度"，乘到 MatCap 上。

- **优点**：零结构改动、零性能代价
- **缺点**：`fragment()` 里没有方向光信息，近似出来的"受光"和原版几乎不相关。真做出来只会比现在更错，属于"为了有参数而有参数"，违反 §0 的对齐原则

**否决。**

### 方案 C：不做，登记为硬限制

- **优点**：没有风险
- **缺点**：这两个是原版实际存在且常用的效果（尤其 MatCapShadowMask，用来让 MatCap 融进阴影），不是可忽略的边角

**不推荐**，因为方案 A 是可行的，只是有代价。

## 4. 推荐方案：A 的开关化版本

核心思路：**默认不付代价，需要时精确对齐**。

```glsl
uniform float matcap_enable_lighting : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float matcap_shadow_mask     : hint_range(0.0, 1.0, 0.01) = 0.0;
```

- 两个都为 0（默认）→ 走现有的 `EMISSION` 路径，**一行代码都不变**，性能与现在完全相同
- 任一非 0 → 该效果改由 `light()` 输出，`fragment()` 跳过

这与原版默认值（0）一致，也符合"性能开销明显高于原版才妥协"的 C 类原则。

### 实施清单

1. **`surface.gdshaderinc`**：抽出 `lil_shaded_normal(vec2 uv)`，把 `fragment.gdshaderinc` 里已有的"法线贴图重建映射后法线"逻辑搬进函数，两处共用。
2. **`surface.gdshaderinc`**：抽出 `lil_matcap_color(vec3 view_normal, vec2 uv)`，返回已乘 intensity / mask / alpha 的最终颜色，供 `fragment()` 与 `light()` 共用。
3. **`uniforms.gdshaderinc`**：新增上述两个 uniform（含中文描述），Glitter 同理再加两个。
4. **`fragment.gdshaderinc`**：MatCap 段加条件——`if (enableLighting 或 shadowMask 任一 > 0)` 时跳过 `EMISSION` 输出，否则维持现状。
5. **`lighting.gdshaderinc`**：在 `light()` 末尾（`use_unlit` 清零之前）加对应的累加分支。
6. **`editor/preset_library.gd`**：`BASE` 增加 4 个键（默认 0）。
7. **文档**：§9 增加一条说明"开启后逐光源重复采样，多光源场景开销随光源数线性增长"。

### 需要留意的技术点

| 点 | 说明 |
|---|---|
| `shaded_normal` 的传递 | 逐像素值，varying 传不了。必须在 `light()` 里用同一套逻辑重建，靠抽函数保证一致 |
| `light()` 缺内建量 | 没有 `TANGENT`/`BINORMAL`，用 `lil_tangent_view` varying + `cross(NORMAL, T)` |
| `FRONT_FACING` | `light()` 里不可用，背面判断沿用 `lil_facing` varying |
| 预乘透明 | `light()` 里 `ALPHA` 可用（现有 rim/backlight 代码已在用） |
| 多光源重复 | 3 光源时 MatCap 采样 3 次。可接受，但要写进 §9 |
| varying 数量 | 不新增 varying（复用 `lil_tangent_view` / `lil_facing`） |

## 5. 风险

| 风险 | 影响 | 缓解 |
|---|---|---|
| `light()` 里重建法线成本 | 每光源多一次法线贴图采样 | 只在参数非 0 时进入分支 |
| 抽函数后 `fragment()` 行为漂移 | 现有 MatCap 表现变化 | 抽函数只做搬移，不改逻辑；抽完先跑冒烟 + 单 shader 编译对比 |
| 多光源亮度叠加 | 与原版单次计算结果不同 | 原版本来就是逐光源累加（`lilGetMatCap` 在 `LIL_PASS_FORWARDADD` 里也会跑），方向一致 |
| 这 4 项无渲染验证环境 | 视觉对错无法确认 | 改完只算"代码对齐"，视觉验证挂起 |

## 6. 验证

1. `godot --headless --path . -s res://tools/smoke_test.gd`：参数描述覆盖 + 预设往返
2. 单 shader 编译：`tools/check_all_shaders.ps1 -Start 10 -End 10`（opaque）
3. **视觉验证必须等有环境时做**：
   - 一个球体，单方向光，`matcap_enable_lighting` 从 0 拉到 1，MatCap 应从"恒定亮度"变成"朝向光的一侧更亮"
   - 加一个投影体挡住光，`matcap_shadow_mask` 从 0 拉到 1，MatCap 在阴影区应淡出
