# liltoon_gd 开发原则（强制）

本文件约束后续所有功能开发。**违反描述规范的功能不视为完成。**

## 0. 功能对齐基准（最高优先级）

- 参考版本**固定为 lilToon 2.4.1**，源码随仓库分发在 `lilToon-2.4.1/`（`Assets/lilToon/Shader/lts.shader` 等）。版本以 `package.json` 为准；根目录 `version.json` 是上游遗留文件（2.1.1），不可作为版本依据。
- 不主动从上游拉取新版本，避免作者更新打乱计划；升级参考版本需由用户提供新目录并明确确认。
- 所有功能以 **liltoon（Unity 原版）** 为对齐基准：参数语义、取值范围、默认值、视觉效果、交互方式都向原版看齐。
- 引擎差异只允许影响**实现方式**，不允许作为缺功能、改行为或降级效果的理由；必须主动调整 shader/管线实现，尽可能贴近原版表现。
- 若发现 liltoon_gd 某处实现**确实优于原版**（更正确、更高效或交互更好），**单独向用户报告**，由用户决定是否保留；不得自行默认保留，也不得悄悄改回。
- 差异项与对齐状态记录在 `ROADMAP.md` 的功能对照表中，便于逐项核对。

### 功能取舍（A / B / C 三类）

- **A 类：原版没有的能力**（如 clearcoat、detail 层、refraction、PBR anisotropy）。能不做就不做；若顺手实现，单列为“特色新功能”，不混入对齐主线。
- **B 类：语义不同但可近似或等价**（如 Alpha Hash、屏幕空间 SSS、CULL_FRONT）。尽可能做到等价；无法等价时取最接近的近似，并在工具输出里明确标注，禁止静默丢弃。
- **C 类：实现成本与性能**。先评估运行时与构建开销；若最优实现的性能明显高于原版，可退化为近似甚至不做，并记录原因。

## 1. 参数描述

- 每个新增或修改的 shader `uniform`，必须在其声明**正上方紧邻**写 `/** 中文描述 */` 文档注释。
- Godot 4.7 不会把 `.gdshaderinc` 里的文档注释直接显示到 Inspector，因此插件会解析根 shader 及其 include 链中的文档注释，并注入到属性行内部值控件的 `tooltip_text`。解析实现在 `editor/shader_doc_parser.gd` 的 `collect()`，注入实现在 `editor/liltoon_inspector_plugin.gd` 的 `_apply_descriptions()`。
- **禁止改写 `EditorProperty.tooltip_text`。** 该字段由编辑器写入文档 id（形如 `property|Class|prop`），Godot 会把它交给 `EditorHelpBit` 解析并渲染悬停文档。改成普通文本会触发 `Invalid doc id` 报错，并显示空白（全黑）提示框。因此属性行（含分组标题、分类标题）的悬停由引擎负责，无描述时显示“暂无可用描述”属于预期行为。
- 描述只能注入到属性行内部的值控件（`EditorSpinSlider`、`CheckBox`、`OptionButton`、`ColorPickerButton`、`EditorResourcePicker` 等）；编辑器自绘的图标按钮（回退、固定、清空等）保留原生提示。
- 描述必须说明：**作用、取值范围或单位、默认行为**，不要只写参数名翻译。
- 示例：

```glsl
/**
 * 明暗分界阈值（N·L），越大阴影范围越大；默认 0.5。
 */
uniform float shade_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;
```

- 推荐使用多行格式（每行以 `*` 开头）；解析器同时兼容单行 `/** ... */`。
- 文档注释必须与 `uniform` 之间只隔空白，不能有其它代码或注释，否则不会被识别。
- 修改描述后需重启编辑器或重新加载插件，因为描述以 shader 路径为键做了进程内缓存。
- 新增 include 文件时，必须确保它位于某个根 shader 的 `#include` 链中，否则插件无法收集其中的描述。
- 分组标题（`group_uniforms`）的说明可以保留在源码中，但 Godot 目前不会为分组标题提供悬停提示。
- 枚举类型必须使用 `hint_enum`，选项文本使用中文。
- 不允许把说明只写在 README、ROADMAP 或独立 md 文件中；用户必须能在 Inspector 中直接看到。

### 标准流程（新增 / 修改参数时）

1. 在 `shaders/include/uniforms.gdshaderinc`（或对应根 shader、include 文件）中，于 `uniform` 声明正上方写 `/** ... */` 中文描述，覆盖作用、范围或单位、默认行为。
2. 若新增了 include 文件，确认它已挂在某个根 shader 的 `#include` 链上，否则描述收集不到。
3. 同步写入 `editor/preset_library.gd` 的 `BASE` 字典（见 §3）。
4. 运行 `godot --headless --path . -s res://tools/smoke_test.gd`，`参数描述应完整（缺失 []）` 必须全部通过。
5. 编辑器内打开材质，悬停值控件应显示中文描述；属性名（叶标签）悬停显示“暂无可用描述”属于正常现象。

### 常见错误

- 把描述写进 `EditorProperty.tooltip_text` → 触发 `Invalid doc id`，提示框全黑。
- 文档注释与 `uniform` 之间插入其它代码或语句 → 正则不匹配（只允许空白/空行）。
- 只把说明写进 README、ROADMAP、分组标题 → Inspector 中看不到。
- 改完 shader 描述未重载插件 → 描述缓存（以 shader 路径为键）仍是旧内容。

## 2. 自定义 UI

- `EditorInspectorPlugin` 实例在所有 Inspector（含浮动/独立窗口）之间共享，**禁止用成员变量保存当前材质或当前面板控件**；`_parse_begin` 里必须用局部变量，并把材质与控件捕获进信号回调的闭包，否则后打开的 Inspector 会让先前面板操作错材质。
- 所有由插件创建的 `Label`、`Button`、`CheckBox`、`SpinBox`、`OptionButton` 等控件，必须设置 `tooltip_text` 中文说明。
- 按钮类控件的提示应说明点击后的结果，而不是重复按钮文字。
- 新增自定义面板或分组时，标题与副标题也要提供 `tooltip_text`。
- 编辑器 UI 缩略图**不要依赖异步渲染帧**（如 `await RenderingServer.frame_post_draw`）：编辑器空闲时可能不再重绘，协程会永久挂起并泄漏离屏视口。缩略图请用 CPU 绘制（`Image` + `ImageTexture`）或预置静态资源。

## 3. 预设同步

- 新增 uniform 必须同步加入 `editor/preset_library.gd` 的 `BASE` 字典。
- 若该参数属于某类材质的关键差异，应同时写入对应预设的 `OVERRIDES`。
- 预设应用必须覆盖所有已暴露 uniform，避免切换预设后残留旧值。
- **例外：sampler 类 uniform 不进 `BASE`**：预设只序列化标量/颜色/向量，资源引用无法可靠跨工程保存；贴图参数由使用者在材质上直接指定，预设不覆盖。

## 4. 参数命名与兼容

- uniform 名称即材质序列化键，只允许追加，不允许重命名或复用。
- 删除参数前必须确认没有预设、演示场景或材质资源引用。
- 新增 shader 变体时，必须在 `liltoon_material_factory.gd` 中提供创建方法，并在 `tools/smoke_test.gd` 增加校验项。

## 5. 用户可见文本

- Inspector、菜单、预设名、演示场景标签优先使用中文。
- 技术标识（如 `next_pass`、shader 名称）可保留英文，但必须附带中文说明。

## 6. 阶段完成标准

每个阶段完成时必须：

1. 更新 `ROADMAP.md` 的阶段状态与功能对照表。
2. 更新或新增演示场景与预览图。
3. 跑通 `tools/smoke_test.gd`。
4. 在 Godot 中实际渲染，确认无 shader 编译错误。**必须单 shader 最小负载**（`compile_check` 一次一个、关 MSAA 与阴影），全量加载曾两次触发 `0x139` 蓝屏，见 `ROADMAP.md` 的 RISKS。
5. 在编辑器中确认新增参数的悬停描述可见。

## 7. 描述补齐与校验

- 历史参数若缺少描述，应在下一次修改该 shader 时补齐。
- 当前覆盖：**17 个主材质变体**（6 个 cutout 含 3 个 Alpha To Coverage、3 个 opaque、4 个 transparent、4 个 fur）各 **465** 个参数，另加 6 个描边变体共用 32 个参数；描述全部注入到属性行的值控件。
- 校验方式：`tools/smoke_test.gd` 会比对 include 中声明的 uniform 与解析出的描述条目，缺一条即失败；编辑器内可再用 gdmcp 抽查 `EditorProperty.tooltip_text` 必须保持 `property|...` 形式（即未被插件改写），且每个属性行至少有一个子控件带描述。
- 新增参数后，覆盖率必须保持 100%。
- 描述注入是**多帧重复执行**的（Inspector 分组与属性行分帧创建），不能在首帧成功后提前返回；重复执行靠控件 meta 保证幂等。
- 属性名（叶标签）悬停显示“暂无可用描述”属于引擎预期行为，不是缺陷；中文描述出现在值控件（滑条、复选框、下拉框、颜色/资源选择器）的悬停提示中。

## 8. 渲染管线语义（移植 liltoon 时必须核对）

Godot 的 spatial shader 与 Unity 表面着色器的语义不同，`light()` 中的输出会被引擎二次加工，移植时逐条核对：

- **`DIFFUSE_LIGHT` 是光照染色项**：引擎在最终合成时统一执行 `diffuse_light *= albedo`。因此 `light()` 里只能写 shade 染色或 `vec3(1.0)`，**禁止再乘 `ALBEDO`**，否则亮部会变成 `ALBEDO²`，深色材质直接压成近黑。
- **`SPECULAR_LIGHT` 不乘 `ALBEDO`**：适合高光、边缘光等不应被基色染色的项；写入后由引擎叠加到最终颜色。
- **`EMISSION` 直接加法**：适合环境光补充、MatCap、自发光、常量边缘光（不随光照方向变化的部分）。
- **`light()` 按光源逐个调用**：liltoon 在 ForwardAdd pass 中同样逐光源计算 toon 阶跃（`lil_pass_forward_normal.hlsl` 的 `fd.ln = dot(fd.L, fd.N)`），因此逐光源叠加是与原版一致的行为，不是移植偏差。
- **不做 `/PI` 归一化**：liltoon 全程直接使用光源颜色（`indirectCol * lightColor`、`lilCalcSpecular` 均无 `/PI`），本项目同样不除 PI；改用物理单位会整体偏暗约 3 倍。
- **亮度上下限**：`light_min_limit` / `light_max_limit` 对应原版 `_LightMinLimit`（默认 0.05）/ `_LightMaxLimit`（默认 1.0），按光源逐个 `clamp(LIGHT_COLOR, min, max)`。注意 Godot 是单 pass 累加所有光源，Unity 是 base + add 多 pass，因此多光源总量仍可超过上限（原版 add pass 同样会叠加）。
- **AO**：引擎先让 AO 作用于环境光，`AO_LIGHT_AFFECT` 只控制 AO 对直射光的影响程度（0 为不影响直射光）。
- **`DEPTH`** 映射到 `gl_FragDepth`：只要 shader 写了 DEPTH，整个材质都会失去 early-Z 优化，非必要不要写。
- **屏幕空间描边**：偏移量在 NDC 中不具像素各向同性，必须按 `PROJECTION_MATRIX` 的 x/y 比例换算，否则非正方形视口下横竖宽度不一致。
- **环境反射依赖引擎镜面 IBL**：`render_mode specular_disabled` 会同时关闭 ReflectionProbe 与环境反射；主体已移除该声明，默认在片元把 `SPECULAR` 置 0 抑制引擎直射高光，`use_reflection` 打开时才启用 `METALLIC` / `ROUGHNESS` / `SPECULAR`。
- **背面法线由引擎翻转**：`cull_disabled` / `cull_front` 会让 Godot 定义 `DO_SIDE_CHECK`，并在片元开始时自动对背面执行 `normal_highp = -normal_highp`。shader 里**禁止再翻转 `NORMAL`**，否则两次翻转互相抵消，背面会按正面光照计算（表现为背面发黑、双面材质内外亮度错乱）。
- **片元阶段的法线**：`fragment()` 里的 `NORMAL` 是未映射法线，引擎在 fragment 之后才应用 `NORMAL_MAP`。MatCap、Rim 等片元阶段效果若需要映射后法线，必须在片元内用 `normal_ts` 重建（见 `fragment.gdshaderinc` 中 `shaded_normal` 的构建），并对无切线网格回退插值法线避免 NaN。

## 9. 已知限制与延后项（2026-10-22 验收裁定）

| 项 | 状态 | 说明 |
|---|---|---|
| MatCap 不跟随法线贴图 | 已修复 | 片元内重建映射后法线；无切线网格回退插值法线 |
| 描边受光（`_OutlineEnableLighting`） | 已实现 | 提供 lit 描边变体（toon step + 暗部染色），面板「描边受光」切换；unlit 仍为默认 |
| 阴影色阶（`_Ramp`） | 自有效果 | 原版仅声明 `_Ramp`（`lts.shader:574`），HLSL 中**零引用**——是遗留的未使用参数。本项目的 `use_shade_ramp` / `shade_ramp` 是独立实现：按 `ndl*0.5+0.5` 采样色阶贴图的 R 通道重映射明暗，会把硬阶跃换成连续过渡，因此对比度天然低于基准（曾误判为"没生效"，后用纯黑探针确认采样路径正常） |
| 第三槽 MatCap（`matcap_3rd_*`） | 自有效果（扩展） | lilToon 只有 `_MatCap` / `_MatCap2nd` 两槽，第三槽是本项目「顺手实现」的扩展，按 A 类处理：不参与对齐计数，保留但不再深入（`_MatCap3rd*` 属性在原版不存在） |
| 直接高光层（`use_specular` / 2nd / 3rd） | 自有效果 | lilToon 没有独立的逐光高光颜色参数，它的「高光」来自反射组；本项目的这层是额外的 Godot 特有实现，默认开启但可关闭，不参与对齐计数，按约定保留。其中 `specular_normal_strength`（对齐 `_SpecularNormalStrength`）在几何法线与扰动法线之间插值，0 时法线贴图不影响高光位置 |
| 反射高光 / 环境反射（`_Reflectance` / `_SpecularBorder` / `_SpecularBlur` / `_SpecularToon` / `_ReflectionColor` / `_ReflectionNormalStrength` / `_ReflectionBlendMode`） | 硬限制（`_Reflectance` 已对齐） | `reflectance` 已写入 Godot 的 `SPECULAR`/F0；其余项受环境 IBL 限制：无法逐材质给反射染色、无法单独为反射指定法线、也无法在引擎反射上做 toon 阶跃与自定义混合模式。只能靠 `METALLIC` / `ROUGHNESS` / `SPECULAR` 近似，按你的规则接受差异 |
| 反射染色贴图（`_ReflectionColorTex`） | 近似 | `use_reflection_color_tex` + `reflection_color_tex`：按主 UV 采样后取 Rec.601 亮度乘进 F0。因为 Godot 的 `SPECULAR` 是标量，只能表达「空间变化的反射强度」，无法像原版那样按 RGB 给反射染色；原版是 `_ReflectionColor` × 贴图，而染色本体受 IBL 限制未做 |
| 边缘光数学（`_RimBorder` / `_RimBlur` / `_RimDir*` / `_RimIndir*` / `_RimMainStrength`） | 已对齐（math） | 按原版实现：`pow(1-|N·V|, power)` → `lilTooningScale(border, blur)`、受光/背光方向、背光色、阴影遮罩、main strength 作为颜色向 albedo 的插值。唯一差异是最终颜色仍以加法写进 `SPECULAR_LIGHT`，而不是原版按 blendMode 混入最终颜色——Godot 没有光照后处理阶段，属于硬限制 |
| 边缘光背光色（`_RimIndirColor`） | 部分 | 颜色按 `rim_indir_color.a` 使用；额外保留 `rim_indir_strength` 作为总倍率（0 默认关闭） |
| 写 `DEPTH` 导致失去 early-Z | 接受 | `depth_offset` 为低频调参；彻底规避需变体翻倍 |
| 多光源总量可超 `light_max_limit` | 接受 | 与原版 base + add 的叠加行为一致 |
| 批量材质替换仅覆盖 StandardMaterial3D → liltoon_gd | 接受 | 未实现“材质 A → 材质 B”的引用替换 |
| 预设中的外部贴图按路径引用 | 接受 | 跨工程复用时需一并拷贝贴图；内嵌资源会打包进 `.tres` |
| 预设缩略图 | 已实现 | 由 `tools/bake_preset_thumbnails.tscn` 离线渲染真实材质（96×96 透明底、4× MSAA），静态 PNG 放在 `addons/liltoon_gd/materials/preset_icons/`；面板优先加载烘焙图，缺失时退回 CPU 示意图。重新烘焙后需执行一次 `--import` |
| 多 Inspector 共享实例串扰 | 不可达 | Godot 4.7 无法同时打开两个 Inspector（只能把单个浮动，内容跟随当前选择）；闭包隔离属防御性修复 |
| 转换器：Alpha Hash | 近似 | 映射为透明变体（平滑半透明更接近抖动效果），排序行为差异在结果中提示 |
| 转换器：屏幕空间 SSS | 近似 | 映射为透射 SSS（`use_sss`），结果中提示语义不同 |
| 转换器：CULL_FRONT | 已支持 | 新增 3 个 `cull_front` 变体并随包体导出；转换与面板「渲染面」下拉均可切换，不做启用开关 |
| 转换器：detail / clearcoat / anisotropy / refraction | 不转换 | A 类：liltoon 无对应能力，转换结果中逐项提示 |
| 后处理描边的实现方式 | **已修复（2026-10-29）** | CompositorEffect 的 compute 写回渲染目标在当前 D3D12 + Intel UHD 上会卡死 GPU；改用全屏四边形 + `hint_depth_texture`。**根因**：lilToon 的 opaque shader 在 alpha mask / dither / 溶解 / 毛发分支里写 `ALPHA`，Godot 据此把材质判为透明，主渲染通道不写深度，`depth_texture` 里没有这些几何（探针显示全黑），`edge` 恒为 0。**修复**：三个 opaque 变体加 `depth_prepass_alpha`（与 cutout/transparent 变体一致），本机 D3D12 Forward+ 实测描边恢复，见 `docs/evidence/阶段9/outline_postprocess_fixed.png`。`hint_normal_roughness_texture` 仍默认关闭（`use_normal_edge`），因为取不到值时会让 `edge` 变 NaN、整个 quad 不渲染 |
| 假阴影 | 已对齐 | `liltoon_fakeshadow.gdshader`（`shaders/extra/`），对齐 `_FakeShadowVector` / `_Invisible`；Godot 顶点阶段拿不到光照方向，改用 `light_direction` uniform + 演示脚本每帧同步（原版 Unity 直接读主方向光）。辅助参数 `shadow_color`（阴影色，对应 lts_fakeshadow 的 `_Color`，与主材质 `_Color` 重名故单列）/ `shadow_texture`（阴影贴图）/ `shadow_uv_scale`（UV 缩放），不进主材质预设 |
| 高光 toon 化 | 已对齐 | `specular_toon` / `specular_border` / `specular_blur`（对应 `_SpecularToon` / `_SpecularBorder` / `_SpecularBlur`）；toon 模式对 `pow(nh, 1/粗糙度)` 做 `lil_tooning_scale` 阶跃，非 toon 输出平滑值。`specular_size` 映射为粗糙度（原版无 `_SpecularSize`，是本项目参数） |
| 描边受光四项 | 已对齐 | `outline_lit_color` / `outline_lit_apply_tex` / `outline_lit_scale` / `outline_lit_offset`（对应 `_OutlineLit*`）；亮部走 `SPECULAR_LIGHT`（不被引擎乘 ALBEDO）、暗部走 `DIFFUSE_LIGHT`，精确复现 `lerp(暗部, 亮部, factor)`。`outline_shade_color` 语义改为"暗部乘色"（默认白=不改变，对齐原版暗部=描边基色） |
| 阴影遮罩顺序 | 已对齐 | `shadow_post_ao`（对应 `_ShadowPostAO`）：关闭时遮罩在 toon 阶跃前乘 N·L（原版默认），开启后乘 toon 结果 |
| 阴影色 LUT | 已对齐（近似） | `shade_color_type`（对应 `_ShadowColorType`）：1 时按反照率亮度从 `shade_color_texture` 横向色带采样；原版用 16 格 LUT + 插值，这里用连续横带近似 |
| 视差零点 | 已对齐 | `parallax_offset`（对应 `_ParallaxOffset`）：主视差与主贴花视差的高度图零点；2nd/3rd/自发光视差无对应参数，固定 0.5 |
| MatCap 滚转抵消 | 已对齐 | `matcap_zrot_cancel`（对应 `_MatCapZRotCancel`）：用世界上方向在视空间的投影建立"无滚转"基（经 varying 传递，辅助函数取不到 VIEW_MATRIX） |
| 闪点形状图集 | 已对齐（近似） | `glitter_shape_atlas`（对应 `_GlitterAtras`）：XY 为图集行列、ZW 为偏移，每个闪点随机取一格；原版用 `near.xy` 噪声选格，这里用闪点 hash |
| 自定义反射立方体贴图 | 已对齐（近似） | `use_reflection_cubemap` / `reflection_cubemap` / `reflection_cubemap_color` / `reflection_cubemap_lighting`（对应 `_ReflectionCube*`）：覆盖环境 IBL；受光程度按"乘 ALBEDO"近似（原版逐光源调制，Godot 片元阶段取不到光色） |
| POM 视差遮蔽 | 近似 | `_UsePOM`：本项目视差是偏移映射（单次采样），原版 POM 是射线步进；Godot 可实现但采样开销大，暂按近似放行 |
| 顶点光强度 | 不做 | `_VertexLightStrength`：Godot 4 Forward+ 的 shader 语言不提供顶点光输入，无对应机制 |
| 阴影色 LUT 精度 | 近似 | `_ShadowColorType=1` 的 LUT 用连续横带近似原版 16 格 LUT + 插值 |
| 3D 贴图 / 三平面遮罩 | 不做 | `_MainTex3D`（Godot 无 3D 贴图采样器约定）、`_TriMask`（原版三平面遮罩，本项目三平面无遮罩参数） |
| 透明模式选择器 / 子通道裁切 / 叠加渲染 | 不做 | `_TransparentMode`（我们用 shader 变体表达）、`_SubpassCutoff`（Unity 深度子通道专属）、`_AsOverlay`（Unity 叠加渲染专属） |
| 多光源高光开关 | 不做 | `_ApplySpecularFA`（ForwardAdd 通道专属；Godot 单 pass 多光源，无对应通道） |
| 折射 | 已对齐 | `liltoon_refraction.gdshader`（`shaders/extra/`），对齐 `_RefractionColor` / `_RefractionColorFromMain` / `_RefractionStrength` / `_RefractionFresnelPower`；单独变体避免所有材质每帧屏幕拷贝 |
| 毛发遮罩 / 噪声遮罩 | 已对齐 | `fur_mask` / `fur_noise_mask`（对应 `_FurMask` / `_FurNoiseMask`），乘入壳层 Alpha |
| 毛发随机化 | 已对齐 | `fur_randomize`（对应 `_FurRandomize`）；原版乘毛长，这里只改方向，差异见演示截图 |
| 毛向量贴图 | 已对齐 | `fur_vector_texture`（对应 `_FurVectorTex`），按 `fur_vector_scale` 缩放，`lilBlendNormal` 叠加 |
| 顶点色毛向量 | 已对齐 | `use_vertex_color_fur_vector`（对应 `_VertexColor2FurVector`），`lilBlendNormal` 规则 |
| 毛发触摸 | 已对齐（近似） | `fur_touch_strength` / `fur_touch_position` / `fur_touch_range`（对应 `_FurTouchStrength`）；原版用 Unity 点光源作为触摸源，本实现改用物体空间触摸点 |
| 宝石 | 已对齐（近似） | `liltoon_gem.gdshader`（`shaders/extra/`），对齐 `_GemChromaticAberration` / `_GemEnvColor` / `_GemEnvContrast` / `_GemParticleColor`；`_GemParticleLoop` 固定 8（原版需粒子系统联动，不在对齐清单）；反射色散只在背面生效（原版如此），正面靠折射色散体现 |
| 折射 / 宝石屏幕纹理 | 辅助参数 | `refraction_screen_texture` / `gem_screen_texture`（`hint_screen_texture`，引擎自动填充，不进预设） |
| 毛发触摸辅助参数 | 辅助参数 | `fur_touch_position`（物体空间触摸点）、`fur_touch_range`（影响半径）；`fur_noise_mask_uv_scale`（噪声遮罩 UV 缩放） |
| AudioLink | 已对齐（自建服务） | 22 项全覆盖。原版依赖 VRChat AudioLink 服务的全局 `_AudioTexture`；本项目用 `audio/liltoon_audio_link.gd` 自己实现：`AudioEffectSpectrumAnalyzer` → 4 频段 → 128 列历史环形缓冲 → 全局纹理 `audiolink_texture` + `audiolink_bands` + `audiolink_time`。UV 模式 0–5、遮罩 RG/阈值、本地贴图、以及 6 条路由（Emission / Emission2nd / EmissionGrad / Emission2ndGrad / Main2nd / Main3rd / Vertex）均已接线。差异：①频谱来自本机总线而非 VRChat；②纹理布局 128×4（原版 128×16 仅用 4 行），shader 里按行取样等价；③`audiolink_texture` 等三个全局参数需写在 `project.godot` 的 `[shader_globals]`（插件菜单「启用 AudioLink 全局参数」可一键写入）；④`_AudioLinkMask_ST` 的缩放拆成 `audiolink_mask_uv_scale`，滚动/旋转拆成 `audiolink_mask_uv_scroll` / `audiolink_mask_uv_rotate` |
| 采样器数量 | 已知代价 | v1.0 后新增 12 个采样器（毛发遮罩 2、反射立方体贴图 1、屏幕纹理 2、AudioLink 遮罩/本地图 2 等），总数 67→79。`reflection_cubemap` 是 `samplerCube` 且**无条件声明**（无法用 `#ifdef` 收起，否则需要新变体），每个 shader 多占一个纹理单元。Forward+/Vulkan 上限充足无实际影响；但「多材质×多光源初始化开销」这条已知风险会略微加重。属功能代价，非缺陷 |
| 反射探针 / 环境反射 | 部分 | 环境 IBL 正常（天空反射已验证）；ReflectionProbe 在当前 D3D12 + Intel UHD 617 上不生效（标准材质对照也全黑），Vulkan 启动即退出，待换环境复验 |
| 距离淡出与描边隐藏 | 已适配 | 主体与描边共用参数，工厂在创建/应用预设时同步；面板提供「同步描边淡出」按钮，改完 Inspector 参数点一次即可。淡出时的边缘光染色 `distance_fade_rim_color` 与菲涅尔幂 `distance_fade_rim_fresnel_power` 已对齐 `_DistanceFadeRimColor` / `_DistanceFadeRimFresnelPower`，默认 Alpha 0 不生效 |
| 贴花层 | 近似 | 三层贴花 + 每层遮罩（共享 + 专用）+ 每层 UV 滚动/旋转 + 每层 UV/UV2 模式 + 2nd/3rd 序列帧；主贴花没有序列帧 |
| liltoon 预设导入 | 部分 | 解析 Unity `.asset` 的 `colors` / `vectors` / `floats`；别名已覆盖 2nd/3rd、Rim、MatCap、描边等常用项；`textures` 未导入。Cloth-Anime 189 项中映射 26 项、描边 4 项 |
| LightmapGI / 烘焙光照 | 已验证 | 编辑器烘焙后运行，关闭实时光时静态网格仍被点亮，说明引擎把烘焙光叠加到 ambient，shader 无需改动；烘焙本身只能手动触发 |
| 毛发外观参数 | 实测 | 描边宽度取「毛长 × 1.2 + 0.02」即可包住毛束；1.6 倍会形成明显的深色厚边。方向强度默认 0.3（1.0 时毛沿切向生长、外扩不明显） |
| 毛发透明模式 | 已实现 | 新增 `liltoon_fur_multi_transparent.gdshader`（`blend_mix` + 平滑 alpha），演示可切换裁切/透明；透明模式在 6 层下仍为 60 FPS |
| 无光照 / 单色光照 | 已实现 | `use_unlit` 把主色写入 EMISSION 并把 ALBEDO 置 0，同时在 `light()` 末尾清零光照；`monochrome_lighting` 用光色亮度替代彩色 |
| SSS 厚度 | 近似 | `sss_thickness_texture` 的 R 通道乘到透射项上，仍非真实次表面散射；默认强度 0 不影响旧材质 |
| AudioLink | 不做 | liltoon 的 AudioLink 依赖 Udon / Unity 音频链路；Godot 端需要自建音频总线 + 全局 uniform + 频谱驱动，属于新子系统，不纳入“还原原版”范围 |
| UndoRedo | 已验证 | 毛发与材质替换用 `EditorUndoRedoManager`（custom_context）；编辑器内实测撤销/重做通过 |
| 贴花序列帧 | 已实现 | 2nd/3rd 支持列/行/速度，按整帧跳变；不支持每层不同播放方向与曲线 |
| 后处理描边的渲染器差异 | 已验证 | `hint_normal_roughness_texture` 只有 Forward+ 支持，Mobile/Compatibility 会编译失败；现提供 `post_outline_screen_basic`（纯深度），场景默认用降级版，Forward+ 下脚本自动换成完整版 |
| 质量档位 | 已实现 | `LiltoonQuality.apply(mat, tier)`：高/中/低用参数开关降载；Godot 无 Unity 关键字变体。演示 `quality_lab`，加 `-- bench` 会关垂直同步、跳过 0.5 s 预热后统计平均帧时间，结果写入 `user://quality_bench.txt`（证据：`docs/evidence/阶段8/quality_bench.txt`） |
| Mobile / Compatibility | 降级完成 | 实测 `hint_depth_texture` 在 Mobile/Compatibility 下取不到有效深度，后处理描边直接关闭并在面板提示；网格描边（next_pass）仍可用。`hint_normal_roughness_texture` 只有 Forward+ 支持，相关 shader 仅 Forward+ 加载 | 命令行 `--rendering-method mobile`（D3D12 Forward Mobile）与 `gl_compatibility`（OpenGL 3.3）均能加载 showcase，无 shader 编译错误；降级截图见 `docs/evidence/阶段7/`。注意编辑器运行不会重读外部修改的 project.godot，必须用命令行参数验证 |
| 各向异性 | 近似 | Kajiya-Kay，1st/2nd/3rd 各自参数，均支持偏移噪声贴图与幅度（`anisotropy_shift_noise_*`）；1st 另支持缩放遮罩（`use_anisotropy_scale_mask`）与切线贴图（`use_anisotropy_tangent_map`，贴图方向经 `lil_tangent_view` 变换后正交化到法线）；`anisotropy_2_matcap` / `anisotropy_2_matcap_2nd` 把各向异性法线（`lil_anisotropy_normal`，对应 `lilGetAnisotropyNormalWS`）用于 MatCap 两槽采样，`_Anisotropy2Reflection` 因无独立反射法线未做。与原版差异只在高光形状用 `sin(T·L)` 的幂函数，没有原版完整的切线噪声组合链 |
| Glitter | 近似 | 程序化哈希闪点，支持形状贴图、位置随机化与 UV/UV2 模式；不是原版的形状合成链；默认关闭 |
| Parallax | 近似 | 视空间 UV 偏移（`VIEW.xy / |VIEW.z|` × 高度差 × 深度），主/2nd/3rd 各自高度图 |
| 2nd 自发光 UV | 部分 | 支持 UV/UV2、滚动与水平渐变（`emission_2nd_grad_texture` / `grad_speed`），没有纵向渐变 UV |
| 逐层法线/阴影色/接收阴影 | 近似 | 法线用 NORMAL 现算正交基扰动；阴影色贴图与 `shade_*_color` 相乘；`use_shade_*_receive=false` 时在阴影区按该层权重加回颜色 |
| 2nd/3rd 层剩余 | 已接受差距 | 27 项（见 `docs/参数对齐矩阵.md`）：贴花子参数与 UV 标记 16（`_Main2ndTexIsDecal` / `ShouldCopy` / `IsMSDF` 等 Unity 图集与左右眼专用）、MatCap 第二槽专用 6、AudioLink 映射 4、`_Anisotropy2MatCap2nd` 1。已实现三层贴花、每层遮罩/UV/滚动/序列帧/不受光、MatCap 遮罩与法线强度 |
| 材质 A→B 替换 | 已提供 | 编辑器菜单「批量替换选中网格的材质…」：以第一个选中网格的材质为源，替换所有选中网格的 `material_override` 与 surface override；不处理嵌套子节点 |
| 每层溶解 | 近似 | 把溶解可见度因子提前计算，乘到 2nd/3rd 贴花遮罩上；复用全局溶解遮罩/噪声，没有逐层独立遮罩 |
| 第二层自发光混合 | 近似 | 支持加法/正片叠底与 R 通道遮罩；正片叠底直接乘 ALBEDO，可能压暗，非原版的独立混合链 |
| 阴影接收 / 法线强度 | 近似 | `shadow_receive` 直接清零阴影项；`shade_normal_strength` 把 N·L 向 1 插值（0 为全平），不是原版的逐层 `_Shadow2ndReceive` |
| MatCap 套件 | 已补齐 | `matcap_lod` 用 `textureLod`；`matcap_normal_strength` 在几何法线与法线贴图法线之间插值；`matcap_main_strength` 同时作用于三个槽位 |
| 第二层自发光 | 近似 | 支持加法/正片叠底、R 通道遮罩、UV/UV2、水平渐变与闪烁；没有纵向渐变 UV 与多层独立混合链 |
| 第二层自发光荧光（`_Emission2ndFluorescence`） | 近似 | `emission_2nd_fluorescence` 把自发光拆成两部分：片元写 `(1 - fl)`，`light()` 里按 `(1 - 光色) × sqrt(光色)` 叠加剩余部分（写 `SPECULAR_LIGHT` 避开 ALBEDO 二次染色）。多光源时逐光源累加，比原版只取主光偏亮；正片叠底模式下不生效。演示 `emission_lab` |
| 阴影抗锯齿（`_AAStrength`） | 已实现 | `aa_strength` 用 `fwidth(N·L)` 把 1st/2nd/3rd 阴影与 toon 高光边缘各扩宽约半像素，等价于原版把 `fwidth` 加进阶跃宽度；默认 1，0 恢复旧行为 |
| 主贴图 UV/HSV（`_MainTex_ScrollRotate` / `_MainTexHSVG`） | 已对齐 | `main_uv_scroll` / `main_uv_rotate`（拆自原版 vec4）与 `main_hsvg`；旋转绕 UV 中心，滚动按时间取小数；作用于主色/法线/AO/Alpha 遮罩，贴花层保持未动画 uv。演示 `main_uv_lab` |
| 阴影主开关 / 主阴影色贴图 / 阴影乘反照率 / 背面强制阴影（`_UseShadow` / `_ShadowColorTex` / `_ShadowMainStrength` / `_BackfaceForceShadow`） | 已对齐（色贴图为近似） | `use_shadow` 关闭后所有区域按受光处理；色贴图乘进阴影色（等价于原版贴图 Alpha=1，未做 alpha 与反照率混合）；`shadow_main_strength` 通过 `tint *= mix(1, ALBEDO, s)` 补偿引擎的 ALBEDO 二次相乘；背面按 `lil_facing` 压回阴影 |
| 阴影遮罩与平面阴影（`_ShadowBorderMask` / `_ShadowBlurMask` / `_ShadowAOShift*` / `_ShadowMaskType` / `_ShadowFlat*`） | 已对齐（近似） | 边界遮罩 RGB 分层压 1st/2nd/3rd 阴影因子，AO 偏移按原式 `c*x+y`；柔化遮罩 RGB 乘各层 blur；平面阴影用 `lil_geo_normal + (0,0.25,1)` 近似原版世界空间平面法线，按强度遮罩与 toon 阴影混合。边界与柔化遮罩支持采样 LOD（`shadow_border_mask_lod` / `shadow_blur_mask_lod`，默认 0） |
| 阴影边界染色 / 范围 / 强度遮罩（`_ShadowBorderColor` / `_ShadowBorderRange` / `_ShadowStrengthMask`） | 已对齐 | `shade_border_range` 把色阶下沿向暗部扩宽，扩宽后的权重乘 `shade_border_color` 把阴影色拉向受光色。**2026-10-28 修正**：强度遮罩原先只乘在 `mix(1.0, ATTENUATION, …)`（引擎实时阴影）上，toon 阴影没受影响；现改为按原版 `shadowStrength *= mask.r; lns.x = lerp(1.0, lns.x, shadowStrength)` 作用于 `lit`/`lit2`/`lit3`/`lit_range`，采样 LOD 由 `shadow_strength_mask_lod` 控制 |
| 默认值语义对齐（P9） | 已对齐 | 2026-10-28 用 `tools/compare_defaults.py` 逐项对照 `lts.shader` 的 Properties 默认值，修复 20 处不一致，其中两类值得记录：①`_MatCapEnableLighting` / `_MatCap2ndEnableLighting` / `_GlitterEnableLighting` 原版默认是 **1**（默认受光），此前误设为 0 且文档里错误声称"与原版默认一致"；②`_MatCapMainStrength` 的语义是「MatCap 向主色靠拢的程度」（原版 `lerp(matCapColor, matCapColor*albedo, k)`），此前被当作强度乘数使用，现已改为 `mix(mc, mc*ALBEDO, k)`，强度只由 `matcap_intensity` 控制，默认值随之为 0 |
| 程度值 vs 开关（P9） | 已对齐 | `_RimEnableLighting`（默认 1）、`_RimShadowMask`（默认 0.5）、`_ShadowReceive`（默认 0）在原版都是 `Range(0,1)` 的程度值，此前实现为 bool 开关。已改为 float 并用 `mix()` 混合：`shadow = mix(1.0, shadow, shadow_receive)`、`rim_dir *= mix(1.0, shadow, rim_shadow_mask)`、`rim_light = mix(vec3(1.0), light_rgb, rim_enable_lighting)`。**注意 `shadow_receive` 默认从 true 变为 0，即默认不接收引擎阴影**，这是原版行为 |
| 阴影环境光强度（`_ShadowEnvStrength`） | 近似 | `shadow_env_strength` 把环境项底色从反照率拉向白色；原版只作用于阴影区的间接光，这里对整段环境项生效，默认 0 行为不变 |
| 受光描边阴影开关（`_OutlineLitShadowReceive`） | 已对齐 | lit 描边的 `light()` 按开关决定是否乘 `ATTENUATION` |
| 逆光接收阴影（`_BacklightReceiveShadow`） | 已对齐 | `backlight_receive_shadow` 开启时逆光乘 `shadow` |
| 主色渐变 / 调整遮罩（`_MainGradationTex` / `_MainGradationStrength` / `_MainColorAdjustMask`） | 已对齐 | 1D LUT 按 `lilGradationMap` 原式逐通道查表（sRGB 空间采样后转回线性），遮罩控制整套颜色调整的生效比例；LUT 建议按线性导入 |
| 背面颜色 / 背面 UV（`_BackfaceColor` / `_ShiftBackfaceUV`） | 近似 | 背面按颜色 Alpha 混入 ALBEDO；为适配 Godot 的光照管线，改为光照前替换（原版是光照后混合），背面 UV 加 (1,0) |
| 抖动透明（`_UseDither` / `_DitherTex` / `_DitherMaxValue`） | 已对齐 | 按屏幕像素点采样图案，用 `(r*255+1)/(max+2)` 二值化 ALPHA；255 为标准抖动 |
| 金属度/光滑度贴图（`_MetallicGlossMap` / `_SmoothnessTex`） | 已对齐 | R=金属度、A=光滑度乘到 `METALLIC`，光滑度贴图 R 乘到光滑度；再换算成 `ROUGHNESS` |
| 反射乘透明（`_ReflectionApplyTransparency`） | 近似 | 用 `SPECULAR *= ALPHA` 让环境反射随透明度淡出；原版是在反射合成时乘 `col.a`，效果一致 |
| Rim 背面遮罩 / 颜色贴图 / 法线强度（`_RimBackfaceMask` / `_RimColorTex` / `_RimNormalStrength`） | 已对齐 | 背面用 `lil_facing` 判定；颜色贴图按主 UV 相乘；法线强度在几何法线与法线贴图法线之间插值 |
| 逆光 / 背光（`_UseBacklight` / `_Backlight*`） | 已对齐（近似混合） | 按原版实现：`pow(saturate(-hl*0.5+0.5), directivity)` × `dot(normalize(-V*viewStrength+L), N)` 色阶、背光色/贴图、NormalStrength、BackfaceMask；最终写入 `SPECULAR_LIGHT` 的加法项，避免被 ALBEDO 二次染色 |
| Rim Shade（`_UseRimShade` / `_RimShade*`） | 近似 | `pow(1-|N·V|, power)` → `lilTooningScale(border, blur)` × 颜色 Alpha × 遮罩；原版对最终颜色做 `lerp(col, col*color, rim)`，这里改为在 ALBEDO 上等价压暗（Godot 没有光照后处理阶段） |
| GSAA（`_GSAAStrength`） | 近似 | 按法线屏幕导数抬高 `ROUGHNESS`，柔化引擎 IBL 反射边缘；公式与原版一致，效果受环境 IBL 限制 |
| Alpha 遮罩（`_AlphaMask*`） | 已修复 | 此前 `use_alpha_mask` 误缩进在 `use_distance_fade` 分支内，未开距离淡出时完全不生效；现已移到淡出分支之后、始终生效，A2C 变体的最终裁切也使用含遮罩的 ALPHA |
| Alpha To Coverage（`_AlphaToMask`） | 已实现 | 新增 `liltoon_cutout_a2c{,_double,_front}.gdshader` + 面板开关 + 预设键 `use_alpha_to_mask`。颜色 pass 不能写 `ALPHA_SCISSOR_THRESHOLD`（写了覆盖率恒为 1），改手动 `discard`；阴影 pass 走同一 `discard`，镂空阴影仍正确；变体不声明 `depth_prepass_alpha`。**必须开启视口 MSAA 2× 以上**。演示 `a2c_lab` |
| MatCap 主槽（`_MatCapBlend*` / `_MatCapPerspective` / `_MatCapBackfaceMask` / `_MatCapBump*`） | 已对齐（部分） | 强度 `matcap_intensity`、遮罩 `matcap_mask`、混合模式 `matcap_multiply`、透视 `matcap_perspective`、背面遮罩 `matcap_backface_mask`、主槽法线 `matcap_bump_map` / `matcap_bump_scale`、预乘透明 `matcap_apply_transparency`、UV1 混合 `matcap_blend_uv1` / `matcap_2nd_blend_uv1`、自定义法线 `matcap_custom_normal`、受光与阴影 `matcap_enable_lighting` / `matcap_shadow_mask`；第二槽同构（`matcap_2nd_blend_uv1` / `matcap_2nd_custom_normal` / `matcap_2nd_enable_lighting` / `matcap_2nd_shadow_mask`）；各向异性法线复用（`anisotropy_2_matcap` / `anisotropy_2_matcap_2nd`，对应 `_Anisotropy2MatCap(2nd)`，用 `lil_anisotropy_normal` 按 `lilGetAnisotropyNormalWS` 的规则替换采样法线）；仍缺 `_MatCapZRotCancel` / `_MatCap2ndZRotCancel`（需要角色空间法线，与当前视空间实现语义不兼容）、`_MatCapVRParallaxStrength` / `_MatCap2ndVRParallaxStrength`（VR 专用）；`_Anisotropy2Reflection` 不做——没有独立反射法线，`SPECULAR` 是标量 |
| Glitter 形状与背面（`_GlitterApplyShape` / `_GlitterShapeTex` / `_GlitterBackfaceMask`） | 已对齐 | 形状贴图与开关、背面遮罩、颜色贴图（`use_glitter_color_tex` + UV 通道）、预乘透明（`glitter_apply_transparency`）、法线扰动强度（`glitter_normal_strength`）、朝向随机（`glitter_angle_randomize`）、受光与阴影（`glitter_enable_lighting` / `glitter_shadow_mask`）。**已知偏差**：本项目的闪点是程序化哈希噪声，`glitter_angle_randomize` 只旋转采样坐标、`glitter_normal_strength` 只改变扰动幅度，噪声的统计分布不变，因此视觉差异远小于原版（原版的朝向随机作用于有明确方向性的 `_GlitterShapeTex`）；`glitter_color_texture` 的染色效果则明确可见（见 `docs/evidence/阶段9/glitter_lab.png`） |
| MatCap / 闪点的受光与阴影（4 项） | 已对齐（开关化） | 这 4 个参数默认 0，与原版默认一致；为 0 时走原路径，行为与开销都不变。非 0 时整段从 `fragment()` 搬到 `light()` 按光源累加，多光源会逐光源重复采样贴图，开销随光源数线性增长。`light()` 里没有 `TANGENT` / `VERTEX` / `UV2`，法线、透视缩放、UV2 分别改用 `lil_tangent_view`、新增的 `lil_view_depth`、`lil_uv2` 三个 varying |
| 主自发光混合（`_EmissionBlend` / `_EmissionBlendMode` / `_EmissionBlendMask` / `_EmissionBlendMask_ScrollRotate` / `_EmissionMainStrength`） | 已对齐（正片叠底近似） | 自发光颜色乘遮罩 RGBA 与混合强度；`_EmissionMainStrength` 按 `mix(color, color*ALBEDO)` 实现；正片叠底模式用乘 ALBEDO 近似（Godot 的 `EMISSION` 只能加法） |
| 主自发光套件（`_UseEmission` / `_EmissionMap*` / `_EmissionGrad*` / `_EmissionParallaxDepth` / `_EmissionFluorescence`） | 已对齐（荧光近似） | 新增 `use_emission` 总开关、UV/UV2 + 旋转/滚动、渐变贴图与速度、视差、主荧光；荧光与 2nd 共用逐光源近似（写 `SPECULAR_LIGHT`，多光源偏亮） |
| 2nd 法线 UV/强度遮罩、2nd 遮罩/噪声滚动（`_Bump2ndMap_UVMode` / `_Bump2ndScaleMask` / `_Emission2ndBlendMask_ScrollRotate` / `_Main2nd·3rdDissolveNoiseMask_ScrollRotate`） | 已对齐 | 法线 UV 模式与第二 UV，遮罩 R 乘缩放；遮罩与逐层噪声复用 `lil_uv_anim`（旋转 + 按时间取小数滚动） |
| 描边矢量图 / 顶点色宽度（`_OutlineVector*` / `_OutlineVertexR2Width`） | 已对齐 | 矢量图按切线空间法线解码（XY 乘 scale、Z 重建），经 TBN 变换后作为外扩方向；顶点色模式 1 用 R 乘宽度、模式 2 用 RGB 作方向并用 A 乘宽度 |
| 描边贴图动画 / 宽度遮罩（`_OutlineTex_ScrollRotate` / `_OutlineTexHSVG` / `_OutlineWidthMask`） | 已对齐 | 与主贴图同一套 UV 旋转/滚动与 `lilToneCorrection`；宽度遮罩 R 通道乘到外扩宽度（与顶点色宽度叠加） |
| 描边补全 | 已补齐 | 支持 `outline_texture`、`outline_fix_width`、透明变体（`outline_apply_transparency` / `outline_opacity`，面板可切） |
| 描边变体组合 | 已补齐 | 提供 unlit-opaque / lit-opaque / unlit-transparent / lit-transparent / unlit-transparent-premul / lit-transparent-premul 六种，覆盖「受光 × 透明 × 预乘」全部有效组合；预乘描边随主材质的预乘变体自动选择，对齐原版 LIL_TRANSPARENT_PREMULTIPLY |
| Rim 套件 | 近似 | `rim_blur` 用指数插值柔化菲涅尔；`rim_indir_*` 把内侧颜色混进边缘光；`rim_shadow_mask` 把权重从 `shadow` 翻转为 `1 - shadow`；`rim_apply_transparency` 乘 ALPHA |
| 自发光闪烁 | 近似 | 用 `1 + sin(TIME * speed) * strength` 乘整段 EMISSION；会连带影响 MatCap/Rim 的发光部分 |
| 毛发边缘光 | 近似 | 在 `light()` 内按光源累加菲涅尔；抗光用当前光的 N·L 削减，近似 `_FurRimAntiLight`，不是原版的固定主光判定 |
| 毛发噪声/向量/裁切 | 已对齐 | 噪声 UV 滚动/旋转、`fur_vector_scale`、`fur_cutout_length`、顶点色毛向量、`fur_root_offset` 均已实现 |
| 描边淡出同步 | 自动 | 面板每 0.3 秒轮询距离淡出参数，变化时写入描边子材质；预设/重置也会同步 |
| 预设 → 毛发 | 自动 | 应用/重置预设时递归同步场景中使用该材质的 `_Fur` 子节点 |
| 毛发数学细节 | 实测 | `INSTANCE_CUSTOM` 只在 vertex 可用（fragment 使用会编译失败）；方向强度 1.0 会让毛沿切向生长、轮廓外扩不明显，默认应取 0.2–0.4 |
| 毛发集成 | 已提供 | 编辑器菜单「为选中网格添加毛发壳层」生成 MultiMesh 子节点；改主体颜色后用「同步毛发参数」。毛发不能只靠单个材质实现 |
| 毛发 / 绒毛 | 已实现（近似） | Godot 无几何着色器；`next_pass` 仅支持一层（实测），改用 **MultiMesh + `INSTANCE_CUSTOM.r`** 承载 1–12 层，单 draw call；风动由 TIME 驱动顶点摆动；壳层 `cast_shadow=OFF` 由主体投影；描边用独立节点且宽度必须大于毛长；6 层 60 FPS；12 层透明模式同样 60 FPS（球体规模） |
## 10. 阶段治理与自审（2026-10-23 起）

- **规模**：每阶段单一主题、交付项 ≤ 3；毛发、AudioLink 这类子系统单独成阶段。超出范围拆到下一阶段，不硬塞。
- **流程**：设计（参数表 + 风险）→ 实现 → 自审 → 证据归档 → 用户确认 → 下一阶段。未完成自审不得开工下一阶段。
- **完成定义（DoD）**：编译与运行无错误；行为对齐 lilToon 2.4.1（差异须写明）；参数描述 100% 且预设同步；冒烟测试全绿；§0/§9 与 ROADMAP 同步；证据归档。
- **证据**：每阶段至少在 `docs/evidence/阶段N/` 留 1 张关键截图 + 一段说明（目录随阶段创建）；未归档视为未完成。
- **阶段外变更**：记入 ROADMAP 文末 `SCOPE LOG`，注明影响阶段；新增风险记入 `RISKS`，下阶段复核。
- **自审清单**：残留代码、脚本语法、冒烟测试、实机渲染、参数覆盖、文档同步、风险与遗留项。
- **编辑器内生成场景**：若刚给 shader 加过 uniform，脚本构建场景前必须用 `ResourceLoader.CACHE_MODE_REPLACE` 重新加载 shader；否则编辑器缓存的旧 uniform 列表会让新参数被静默丢弃。
- **shader 局部变量不要与 uniform 重名**：如 `decal_mask` 既是 uniform 又是局部变量会导致 `Redefinition` 编译失败；冒烟里的预设测试会连带失败，看到「预设往返」失败先查 shader 编译错误。
- **class_name 脚本改坏后**：即使磁盘已修好，编辑器进程可能仍持有损坏的类缓存，静态函数会静默中断；重载插件（`set_plugin_enabled` 关闭再开启）可刷新，不必重启编辑器。
