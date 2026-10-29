# liltoon_gd 使用说明书

> **liltoon_gd** 是 [lilToon](https://github.com/lilxyzw/lilToon)（Unity 版卡通渲染）的 **Godot 4 非官方移植**。
> 目标是让 Unity 用户能几乎无损地把 lilToon 材质搬进 Godot。
>
> **许可证**：本项目采用 **MIT License**（Copyright (c) 2026 Ch1pmunk_Z），见 [`LICENSE`](LICENSE)。
> 实现参考了 lilToon（MIT，Copyright 2020-2024 lilxyzw），
> 相关声明与原始许可证全文见 [`addons/liltoon_gd/THIRD_PARTY_NOTICES.md`](addons/liltoon_gd/THIRD_PARTY_NOTICES.md)。
> 对外分发时**必须一并保留该文件**。
>
> **本项目是非官方移植**，与 lilToon 作者无隶属关系。名称中的 `_gd` 用于区分平台。
>
> **功能覆盖情况**：lilToon 的 578 项材质属性中已对齐 434 项。此处"已对齐"指**参数语义、
> 取值范围、默认值与关键场景表现一致**；未做与原版的逐项行为等价验证（需 Unity 对照环境），
> 因此不宣称像素级等价。剩余 144 项全部是 Godot 引擎机制无法表达的部分——
> Unity 渲染状态（Blend/Stencil/ZTest/Offset/ColorMask/Cull）、曲面细分、VR 视差、
> VRChat Light Volumes、Unity 各 pass 专属，以及 Godot `SPECULAR` 为标量导致的反射染色/反射法线。
> 每一项的理由都记在 `DEVELOPMENT_PRINCIPLES.md` §9。
> 逐项标注「完美复刻 / 稍有妥协 / 阉割严重 / 根本没做」的功能对照表与参数矩阵在开发仓库的 `docs/` 中维护，不随本仓库分发。

---

## 一、要求

| 项 | 要求 |
|---|---|
| Godot | **4.4+**（开发与验证在 4.7.2 上完成） |
| 渲染器 | **必须 Forward+** |
| GPU | 支持 Vulkan/D3D12 的显卡；核显可运行但多材质场景初始化慢 |
| 语言 | GDShader + GDScript，无 C# 依赖 |

**渲染器说明**：

- **Mobile**：后处理描边与法线粗糙度纹理不可用，会自动降级并提示
- **Compatibility（OpenGL）**：主材质无法编译（67 个 `sampler2D` 超过 16 个纹理单元上限），只能用小 shader
- **Vulkan / D3D12**：完整功能

---

## 二、安装

1. 把 `addons/liltoon_gd/` 整个目录复制进你的项目 `addons/`
2. `项目设置 → 插件` 里启用 **liltoon_gd**
3. 重启编辑器（让启动检查生效）

无需其他依赖。

---

## 三、快速上手

### 创建材质

**方法 A**：工具菜单 **liltoon_gd → 创建材质**，会生成一个绑定了 `liltoon_opaque.gdshader` 的材质资源。

**方法 B**：新建 `ShaderMaterial`，着色器选 `res://addons/liltoon_gd/shaders/liltoon_opaque.gdshader`。

**方法 C**（从 Unity 材质迁移）：见第七节。

### 调参

Inspector 里参数按分组排列（Main / Shade / Normal / Specular / Rim / MatCap / Emission / …），
**每组都有中文悬停描述**，写清作用、取值范围、默认行为。

### 加描边

描边是独立的 `next_pass` 材质（不是 shader 参数）。在 Inspector 里展开「描边」分组，
勾选 `outline_enabled` 即可自动创建描边 pass。

---

## 四、Shader 变体速查

| 变体 | 用途 |
|---|---|
| `liltoon_opaque` | 不透明主体（默认） |
| `liltoon_cutout` | Alpha 裁切（硬边） |
| `liltoon_cutout_a2c` | Alpha To Coverage（平滑半透明，**需要视口 MSAA ≥ 2×**） |
| `liltoon_transparent` | 半透明 |
| `liltoon_transparent_premul` | 预乘 Alpha 半透明 |
| `liltoon_opaque_double` / `_cutout_double` / `_transparent_double` | 双面渲染 |
| `liltoon_opaque_front` / `_cutout_front` / `_transparent_front` | 仅背面渲染 |
| `liltoon_cutout_a2c_double` / `_front` | A2C 双面 / 仅背面 |
| `liltoon_fur_multi` / `_transparent` | 毛发壳层（MultiMesh，1–12 层） |
| `liltoon_outline` / `_lit` / `_transparent` / `_lit_transparent` / `_transparent_premul` / `_lit_transparent_premul` | 网格描边（受光×透明×预乘 6 种组合，工厂自动选） |
| `shaders/extra/liltoon_refraction.gdshader` | 折射（屏幕纹理） |
| `shaders/extra/liltoon_gem.gdshader` | 宝石（色散折射 + 粒子闪烁） |
| `shaders/extra/liltoon_fakeshadow.gdshader` | 假阴影（地面影） |
| `effects/post_outline_screen*.gdshader` | 后处理描边（屏幕空间） |

**变体怎么选**：在 Inspector 的「渲染面」下拉切换单面/双面/仅背面，工厂会自动换 shader。
A2C 用 `set_alpha_to_mask()` 或面板开关。

---

## 五、功能分组使用说明

### 主色（Main）
- `main_color` × `main_texture` = 反照率
- `main_hsvg` 色相/饱和/明度/Gamma 校正
- `main_uv_scale/scroll/rotate` UV 控制
- `main_gradation_texture` 主色渐变 LUT
- `use_dither` 抖动透明（二值化 Alpha）
- `use_unlit` 不受光（全亮）

### 阴影（Shade）
- 三层阴影：`shade_color` / `shade_2nd_color` / `shade_3rd_color`，各自阈值/柔化/法线强度
- `shade_border_color` + `shade_border_range` 边界染色（过渡带染色）
- 三种遮罩：`shadow_border_mask`（边界）/ `shadow_blur_mask`（柔化）/ `shadow_strength_mask`（强度），各带采样 LOD
- `shadow_mask_type = 1` 平面阴影
- `backface_force_shadow` 背面强制压暗
- `shadow_post_ao` 遮罩应用顺序（关=阶跃前，开=阶跃后）
- `shade_color_type = 1` 阴影色 LUT 模式（按反照率亮度采色带）

### 高光（Specular）
- `use_specular` 开关；`specular_toon` toon 化
- `specular_border` / `specular_blur` 阶跃位置与柔边
- `specular_size` 高光范围（映射为粗糙度指数）
- `specular_normal_strength` 法线贴图对高光位置的影响（0=圆斑，1=不规则）

### 各向异性（Anisotropy）
- 三层各向异性（1st/2nd/3rd），Kajiya-Kay 模型
- `anisotropy_tangent_map` 切线贴图改方向
- `anisotropy_scale_mask` 缩放遮罩
- `anisotropy_shift_noise_texture` 偏移噪声
- `anisotropy_2_matcap` 把各向异性法线复用到 MatCap 采样

### Rim 边缘光
- `rim_border` / `rim_blur` 边界与柔化
- `rim_dir_strength` / `rim_dir_range` 方向性（分受光/背光）
- `rim_indir_color/strength/range/border/blur` 间接光
- `rim_enable_lighting` 程度值（0=恒定亮度，1=完全跟随光色）
- `use_rim_shade` Rim Shade 子套件

### MatCap
- 三个槽位（主 + 2nd + 3rd），每槽：强度/颜色/遮罩/法线贴图/自定义法线/受光/阴影/背面遮罩/透视/UV1 混合/LOD
- `matcap_zrot_cancel` 抵消相机滚转（默认开）
- `matcap_main_strength` 向主色靠拢的程度（**不是强度乘数**）

### Glitter 闪点
- `glitter_scale/contrast/speed/angle` 形态
- `use_glitter_shape` + `glitter_shape_texture` 形状贴图（`glitter_shape_atlas` 图集）
- `use_glitter_color_tex` 颜色贴图
- `glitter_enable_lighting` / `glitter_shadow_mask` 受光/受阴影

### 自发光（Emission）
- 主 + 第二层，各含 UV/渐变/视差/荧光/混合模式/遮罩
- `emission_fluorescence` 荧光（受光照调制）
- `emission_blink_strength` 闪烁

### 反射（Reflection）
- `use_reflection` + `metallic` / `roughness` / `reflectance`
- `use_metallic_gloss_map` + `use_smoothness_texture` 贴图
- `use_reflection_cubemap` + `reflection_cubemap` 自定义立方体贴图（覆盖环境 IBL）
- `gsaa_strength` 几何高光抗锯齿

### 逆光（Backlight）
- `use_backlight` + `backlight_color/color_tex`
- `backlight_border/blur/directivity` 形态
- `backlight_receive_shadow` 接收阴影

### 距离淡出（Distance Fade）
- `use_distance_fade` + `distance_fade_mode/near/far/strength`
- `distance_fade_rim_color` 淡出边缘光染色

### 溶解（Dissolve）
- `use_dissolve` + `dissolve_mode`（遮罩/UV/物体空间）+ `dissolve_shape`（线性/圆形）
- `dissolve_noise_texture` 噪声扰动
- `dissolve_color` 边界发光带

### 贴花（Decal）
- 三层贴花（主 + 2nd + 3rd），每层：颜色/UV 缩放偏移/强度/混合模式/遮罩/法线/溶解噪声
- `use_parallax` + `parallax_texture/height/offset` 视差

### 描边（Outline）
- `outline_enabled` 开关（自动创建 `next_pass`）
- `outline_mode` 法线外扩 / 位置外扩 / 屏幕空间等宽
- `outline_texture` + `outline_hsvg` 贴图与 HSV
- `outline_width_mask` 宽度遮罩
- `outline_vector_map` 矢量图控方向
- `outline_lit_color/scale/offset` 受光染色
- `outline_apply_transparency` 透明描边

### 毛发（Fur）
- 用 **工具菜单 → 为选中网格添加毛发壳层** 自动生成 MultiMesh 壳层
- `fur_layers` 1–12 层；`fur_length` / `fur_gravity` / `fur_root_offset` / `fur_cutout_length`
- `fur_root_color` / `fur_tip_color` 根梢色
- `fur_mask` / `fur_noise_mask` / `fur_length_mask` 三种遮罩
- `use_fur_vector_texture` 毛向量贴图
- `fur_randomize` 毛向量随机化
- `fur_touch_strength` + `fur_touch_position` 触摸推开
- `fur_wind_strength/speed` 风力摆动

### 折射 / 宝石
- 折射变体（`liltoon_refraction.gdshader`）：`use_refraction` + `refraction_strength/fresnel_power/color`
- 宝石变体（`liltoon_gem.gdshader`）：`gem_chromatic_aberration`（色散）+ `gem_env_color/contrast` + `gem_particle_color`

### 假阴影
- 用 `liltoon_fakeshadow.gdshader` 挂在地面四边形上
- `fake_shadow_vector` .xyz 附加方向、.w 偏移距离
- **注意**：Godot 顶点阶段取不到光照方向，需要脚本每帧同步 `light_direction`（演示脚本见 `demo/fakeshadow_lab.gd`）

### AudioLink（音频律动）
- 先做一次性配置：工具菜单 **liltoon_gd → 启用 AudioLink 全局参数**，然后在
  `项目设置 → 自动加载` 里加上 `res://addons/liltoon_gd/audio/liltoon_audio_link.gd`
- 材质里勾 `use_audiolink`，再按需打开路由：
  `audiolink_2_emission` / `audiolink_2_emission_2nd` / `audiolink_2_emission_grad` /
  `audiolink_2_emission_2nd_grad` / `audiolink_2_main_2nd` / `audiolink_2_main_3rd` / `audiolink_2_vertex`
- `audiolink_uv_mode` 决定音频值的取法（固定偏移 / 按视角 / UV 旋转 / 遮罩 RG / 遮罩阈值 / 按距离）
- 没有音频在播时，shader 会走合成脉冲（由 `audiolink_default_value` 控制频率与亮度），不会静默失效
- 演示：`demo/audiolink_lab.tscn`

---

## 六、Editor 工具（工具菜单 → liltoon_gd）

| 菜单项 | 功能 |
|---|---|
| **创建材质** | 生成绑定 `liltoon_opaque` 的材质资源 |
| **转换选中材质（资源）** | 把选中的 `StandardMaterial3D` 批量转成 liltoon_gd 材质 |
| **批量转换选中节点的材质** | 遍历节点树，转换所有 `StandardMaterial3D` |
| **校验并修复选中材质（资源）** | 检查越界参数/缺键/类型错误，确认后修复并写盘 |
| **为选中网格添加毛发壳层** | 生成 6 层 MultiMesh 毛发壳层（可撤销） |
| **为选中网格添加透明毛发壳层** | 同上，透明变体 |
| **同步选中网格的毛发参数** | 主体颜色改后，同步到毛发壳层 |
| **批量替换选中网格的材质…** | 材质 A→B 批量替换（支持 material_override 与 surface override） |
| **烘焙选中材质的主色贴图…** | 把「主色×贴图×HSV×渐变×贴花」烘成一张贴图，参数重置为恒等（省运行时采样） |
| **分析选中材质的优化建议** | 检查未生效参数、超大贴图、高开销组合 |
| **全局设置…** | 查看/修改全局设置（默认预设、性能档、烘焙尺寸、语言） |

**启动检查**：插件加载时自动比对版本，提示升级/首次安装。

**多语言**：全局设置里 `language` 可切 `zh` / `en`（影响菜单与对话框文案；shader 参数的 Inspector 描述始终中文）。

---

## 七、从 lilToon 迁移

三条路径：

1. **转换器**（推荐）：选中 Unity 导入的 `StandardMaterial3D` 或 lilToon 材质 → 工具菜单「转换」。会映射 127 条别名 + 蛇形自动匹配。
2. **预设导入**：`LiltoonPresetImport.parse_file()` 解析 Unity `.asset` 预设（colors/vectors/floats；textures 需手动重挂）。
3. **手动映射**：对照参数对齐矩阵（开发仓库 `docs/`）逐项设置。

**转换器不转换的项**（会逐项提示）：Clearcoat / Refraction / Anisotropy（Unity 特有）、屏幕空间 SSS（映射为透射 SSS）。

---

## 八、性能建议

1. **贴图尺寸**：主材质有 67 个采样器，大贴图（>2048）会拖慢初始化。弱机建议 1024 或用「烘焙主色贴图」。
2. **多光源**：MatCap/Glitter 的 `enable_lighting` / `shadow_mask` 非 0 时会逐光源重复采样，光源多时开销线性增长。不用时保持默认 0。
3. **毛发**：层数越多越贵；12 层透明毛发在中端显卡约 60 FPS（球体规模）。
4. **描边**：`outline_width ≈ 0` 时关闭描边可省一个 draw call。
5. **画质档位**：`LiltoonQuality.apply(mat, tier)` 可切 high/medium/low，用参数开关降载。
6. **三平面映射**：主贴图采样 3 次，按需开启。

**优化分析**：工具菜单「分析选中材质的优化建议」会自动检查以上问题。

---

## 九、故障排查

| 现象 | 原因 | 处置 |
|---|---|---|
| A2C 边缘没效果 | 视口 MSAA 未开 | 项目设置里 `msaa_3d` 设 2× 或 4× |
| 后处理描边不出现 | Mobile/Compatibility 无深度纹理 | 用网格描边（`outline_enabled`） |
| 描边变粉/报错 | 变体组合不存在 | 用材质工厂的 `set_outline_*` API 切换 |
| 预设切换后某参数没重置 | 预设漏键 | 重新套用一次预设，或检查该参数是否在当前 shader 变体上 |
| 场景启动黑屏 | 多材质×多光源初始化超 GPU 驱动超时 | 减材质数/光源数，或换更强显卡 |
| 材质参数改了没反应 | 参数不在当前变体上（如 `use_refraction` 需折射变体） | 看参数描述里的「仅在 X 变体生效」 |
| Inspector 悬停描述全黑 | `EditorProperty.tooltip_text` 被覆盖 | 不要改写该字段，描述注入到属性行内部控件 |

---

## 十、开发与验证

本仓库只包含插件本体。开发期用的自动化校验链（冒烟测试、shader 编译自检、
参数对齐矩阵重算、一致性/默认值/发布审计）与项目内部文档**不随仓库分发**，
它们在开发环境维护，对插件使用者无需求。

需要自检时，最直接的方式是打开 Godot 运行 `addons/liltoon_gd/demo/` 下的演示场景。

---

## 十一、文档

| 文档 | 内容 |
|---|---|
| [`addons/liltoon_gd/DEVELOPMENT_PRINCIPLES.md`](addons/liltoon_gd/DEVELOPMENT_PRINCIPLES.md) | 开发原则 + 每条实现的对齐判定与差异（含与原版的已知差距） |
| [`addons/liltoon_gd/THIRD_PARTY_NOTICES.md`](addons/liltoon_gd/THIRD_PARTY_NOTICES.md) | lilToon MIT 声明（**分发必须保留**） |

**不随本仓库分发**（开发环境维护）：lilToon ↔ liltoon_gd 全量功能对照表、
参数对齐矩阵（578 项属性逐项对照）、迁移指南、开发记录、证据截图。
需要了解差异时，`DEVELOPMENT_PRINCIPLES.md` 里有每条实现的对齐判定与已知差距说明。

---

## 十二、演示场景

`addons/liltoon_gd/demo/` 下有 37 个演示/验证场景，每个功能一个 lab：

| 场景 | 演示 |
|---|---|
| `showcase.tscn` | 整体观感（5 预设球 + 角色） |
| `character.tscn` | 角色全材质（最重的场景） |
| `shadow_full_lab` | 阴影全量（分界/柔化/边界染色/二层/色阶/平面） |
| `matcap_shade_lab` / `matcap_uv_lab` / `matcap_2nd_lab` | MatCap 受光/UV/第二槽 |
| `glitter_lab` / `aniso_lab` / `aniso_matcap_lab` | 闪点 / 各向异性 |
| `normal_specular_lab` | 法线与高光 |
| `rim_lab` / `fade_rim_lab` / `fade_lab` | 边缘光 / 距离淡出 |
| `emission_lab` / `material_extra_lab` | 自发光 / 主色渐变/背面/抖动 |
| `decal_lab` / `feature_lab` | 贴花 / 综合效果 |
| `dissolve_lab` | 溶解 |
| `outline_lab` / `outline_blend_lab` / `outline_light_lab` | 描边（后处理/混合/受光） |
| `fur_multi_lab` / `fur_features_lab` / `fur_perf_lab` | 毛发（壳层/6 项/性能） |
| `refraction_lab` / `gem_lab` / `fakeshadow_lab` | 折射 / 宝石 / 假阴影 |
| `audiolink_lab` | 音频律动（自发光 / 顶点） |
| `a2c_lab` / `variant_lab` / `quality_lab` | A2C / 变体 / 画质档位 |

直接运行时加 `-- shot` 可截图到 `user://<场景名>.png`（部分场景支持 `-- bench`）。
