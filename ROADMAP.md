# liltoon_gd 路线图

> 开发原则（强制）：所有新增 shader 参数必须带 Inspector 中文悬停描述，所有自定义 UI 控件必须带 `tooltip_text`。详见 [addons/liltoon_gd/DEVELOPMENT_PRINCIPLES.md](addons/liltoon_gd/DEVELOPMENT_PRINCIPLES.md)。

目标：在 Godot 4.7（Forward+）中以插件形式实现 liltoon 的卡通渲染能力，最终阶段对齐 [lilToon](https://github.com/lilxyzw/lilToon) 仓库的全部功能。

规则：**每个阶段完成后打勾并进入下一阶段**；阶段内功能可分多次提交，但验收条件必须全部满足才算完成。功能对照表只增不减（`未实现 → 部分 → 完成`）。

## 阶段总览

| 阶段 | 主题 | 状态 |
|---|---|---|
| P0 | 核心卡通渲染 | 完成 |
| P1 | 光照与阴影完善 | 完成 |
| P2 | 材质扩展与描边体系 | 完成 |
| P3 | 角色特化 | 完成 |
| P4 | 编辑器工具链 | 完成 |
| P5 | 高级效果（透视隐藏 / 探针 / 贴花） | 完成 |
| P6 | 毛发与绒毛 | 完成（近似） |
| P7 | 渲染器兼容（Mobile / Compatibility） | 完成（降级完成；Vulkan 受环境限制） |
| P8 | 性能与变体管理 | 完成 |
| P9 | 全量对齐与发布 | 完成 |
| P10 | 可选扩展（AudioLink 等） | 未开始 |

## 当前任务（最后更新 2026-10-27）

- [x] P0–P4：核心卡通渲染、光照阴影、材质扩展与描边、角色特化、编辑器工具链
- [x] P5：溶解、后处理描边、透视/描边隐藏、反射与环境探针、双层贴花
- [x] CULL_FRONT：3 个 `cull_front` 变体 + 面板「渲染面」三选一 + 双面/背面法线重复翻转修复
- [x] **LightmapGI 烘焙验证（完成）**：`lightmap_bake_lab.tscn` 烘焙后运行，关闭实时光时 A 面仍被点亮，确认烘焙光进入 liltoon shader
- [x] P6 毛发与绒毛（MultiMesh 壳层、风/阴影/描边、编辑器集成、6 层 60 FPS）
- [x] P7 渲染器兼容（Mobile / Compatibility 降级完成；Vulkan 环境限制）
- [x] P8 性能与变体管理（档位/演示完成；三档基准已跑通并归档）
- [x] P9 全量对齐与发布（2026-10-29 完成：矩阵 307 对齐、15 项遗漏补齐、命名语义对齐、迁移指南、回归、发布 v1.0；剩余 Editor 工具为可选项）
- [ ] P10 可选扩展（AudioLink 等，不阻塞主线）

## 阶段治理

- **规模**：每个阶段主题单一、交付项 ≤ 3，超出则拆到下一阶段；毛发、AudioLink 这类子系统单独成阶段。
- **流程**：设计（参数表 + 风险）→ 实现 → 自审 → 证据归档 → 用户确认 → 进入下一阶段。未自审不得开工下一阶段。
- **完成定义（DoD）**：① shader 编译与场景运行无错误；② 功能行为与 lilToon 2.4.1 对齐（差异须写明）；③ 参数描述 100%、预设同步；④ 冒烟测试全绿；⑤ 文档（§0/§9、ROADMAP 表）同步；⑥ 证据截图归档。
- **自审清单**：残留代码、语法、冒烟、实机渲染、参数覆盖、文档同步、风险与遗留项。
- **证据归档**：每个阶段至少在 `docs/evidence/阶段N/` 留 1 张关键截图 + 1 段说明；未归档视为未完成。
- **阶段外变更**：临时插入的修复/增强记入文末 `SCOPE LOG`，注明影响阶段，不静默扩大当前阶段范围。
- **风险登记**：见文末 `RISKS`，新增风险当阶段登记，下阶段复核。

---

---

## P0 核心卡通渲染

交付：
- [x] 插件骨架：`addons/liltoon_gd/`、EditorPlugin、项目启用
- [x] 主色/贴图/UV 缩放、阴影色、shade threshold/blur
- [x] 自定义 `light()`：方向光/点光/聚光的 toon 阶跃，阴影区保留明暗分区
- [x] Toon 高光（强度、大小、柔边）
- [x] Rim Light（颜色、强度、宽度）
- [x] MatCap（贴图、颜色、强度、叠加/乘算）
- [x] Emission（颜色、贴图、强度）
- [x] 法线贴图
- [x] 不透明 / Cutout / 透明 shader 变体
- [x] `next_pass` 外扩描边（颜色、宽度、遮罩）
- [x] 自定义 Inspector：预设应用、描边开关、参数重置
- [x] 预设库：默认/皮肤/头发/布料/金属
- [x] 演示场景（预设球阵 + 图元角色）

验收：Godot 命令行导入无 ERROR；演示场景渲染截图可确认双色阶、描边、Rim、高光；切换预设与描边开关生效。

## P1 光照与阴影完善

- [x] 色阶 ramp 贴图（采样与强度混合）
- [x] 2nd / 3rd 阴影色与阴影色混合
- [x] 受影强度、阴影模糊、阴影偏移（shading shift）
- [x] 环境光补充（`ambient_color` / `ambient_strength`；引擎环境光仍按 ALBEDO 参与）
- [x] Rim 的 2nd 颜色与 mask
- [x] 高光 2nd 层
- [x] AO（贴图/顶点色）与 `AO_LIGHT_AFFECT`
- [x] 多光源一致性校验（方向光 + 点光 + 聚光，演示场景已加入）

验收：三层阴影、双光源、AO 参数在材质面板可见；演示场景渲染无 shader 错误。

## P2 材质扩展与描边体系

- [x] 顶点色混合（`COLOR`）
- [x] 双法线贴图（双张法线合成）
- [x] MatCap 2/3 槽位与 mask
- [x] 三平面映射（无需 UV，主色贴图）
- [x] 描边模式：法线外扩 / 位置外扩 / 屏幕空间等宽
- [x] 描边颜色遮罩、顶点色宽度、Z 偏移
- [x] 透明排序模式（普通 / 前置深度 / 预乘 Alpha）
- [x] 双面渲染变体（不透明 / Cutout / 透明）

验收：`variant_lab.tscn` 可对比双面、预乘、三平面；主场景使用三种描边模式渲染无错误。

## P3 角色特化

- [x] 皮肤 SSS / 透射（背光透射近似，着色器内实现）
- [x] 头发各向异性与高光偏移（含高光 3rd 层）
- [x] Rim 受光/背光切换（依赖光照方向的 Rim）
- [x] 眼睛视差（parallax，高度图）
- [x] 金属/镜面反射（METALLIC / ROUGHNESS / 环境天空）
- [x] 阴影 caster 控制、深度偏移
- [x] 角色演示场景（皮肤/头发/眼睛/布料/金属分层材质）

验收：`character.tscn` 可看到 SSS 皮肤、发丝高光、视差眼睛、金属反射；无 shader 错误。

## P4 编辑器工具链

- [x] 材质转换器（StandardMaterial3D → liltoon_gd）
- [x] 参数预设导出/导入（`.tres`）
- [x] 批量材质替换（StandardMaterial3D → liltoon_gd，节点树批处理、可撤销）
- [x] 预设缩略图预览（CPU 示意图；真实离屏渲染延后到路线图最后）
- [x] 材质参数校验与修复

验收：工具菜单可完成转换与批量替换；预设可跨工程复用。

## P5 高级效果（完成）

- [x] 溶解（噪声/遮罩/UV/物体空间，含边缘发光带与噪声滚动）
- [x] 后处理描边（屏幕空间四边形 + 深度纹理）
- [x] 透视 / 描边隐藏（按相机距离淡出表面与描边，参数对齐 `_DistanceFade`）
- [x] 反射 / 光照探针（环境 IBL + LightmapGI 已验证；ReflectionProbe 在当前 D3D12 + Intel UHD 617 上不生效，Vulkan 无法完成验证）
- [x] 贴花 / 装饰（主贴花 + 第二贴层：UV 缩放/偏移、三种混合）

验收：三项各有独立演示场景与截图（`fade_lab` / `probe_lab` / `decal_lab`）；参数描述覆盖 100%；冒烟测试全绿；§9 同步。
自审：按「阶段治理」执行，通过后进入 P6。

## P6 毛发与绒毛（完成）

- [x] 预研（时间盒）：壳层链 + cutout + 噪声贴图原型，6 层 56 FPS（VSync 上限），**go**
- [x] 毛发参数：层数/长度/重力/根部压暗/噪声/毛束密度/方向/长度遮罩/根梢色（13 项）
- [x] MultiMesh 壳层：单 draw call 承载 1–8 层（`INSTANCE_CUSTOM.r` 传层高）；6 层 57 FPS
- [x] 动态：风与重力（TIME 驱动顶点摆动，演示有风力滑条）
- [x] 阴影与描边适配（壳层不投影、主体投影；描边独立节点、宽度需大于毛长）
- [x] 演示定稿 `fur_multi_lab.tscn`（6 层、风/阴影/描边；重启后实测 60 FPS，截图已归档）
- [x] 编辑器集成：菜单「为选中网格添加毛发壳层」/「同步毛发参数」（`liltoon_fur_tools.gd`）
- [x] 还原项 A：毛发 rim、噪声滚动/旋转、向量缩放、裁切长度、顶点色毛向量、根部偏移、溶解旋转；描边淡出自动同步；预设→毛发自动同步
- [x] 还原项 B10：描边受光（独立 lit 变体 + 面板开关 + 对照场景 `outline_light_lab.tscn`）
- [x] 还原项 B15：第三贴层（`decal_3rd_*`）
- [x] 还原项 B11：毛发透明模式（透明 MultiMesh 变体、演示开关、菜单「添加透明毛发壳层」）
- [x] 还原项 B12：毛发层数上限 8 → 12（6 层默认；12 层透明模式 60 FPS，球体规模）
- [~] 还原项 B13：后处理描边法线边（`hint_normal_roughness_texture`）——**2026-10-28 复查：原先只采样未参与运算，是死代码**。已接线但默认关闭（`use_normal_edge`），因为 `normal_roughness_texture` 取不到值时会让 `edge` 变 NaN、整个 quad 不渲染。同时发现深度边在本机也不生效，见下方风险
- [x] 还原项 B17/B18：每层遮罩（共享 `decal_shared_mask` + `decal_2nd_mask` / `decal_3rd_mask`）与每层 UV 滚动/旋转（`decal_*_uv_scroll` / `decal_*_uv_rotate`）
- [x] 还原项 B16：每层贴花 UV 模式（UV / UV2）
- [x] 还原项 B19（部分）：liltoon 预设导入（解析 .asset 的 colors/vectors/floats，别名映射；textures 未导入）
- [x] B14 逐物体后处理描边：**不做**（本插件自有效果，liltoon 无对应能力，避免偏离对齐目标）
- [x] C 组：参数对齐矩阵（`docs/参数对齐矩阵.md`，2026-10-25 重跑：516 项对 322 项，已对齐 117 项，未对齐 399 项）
- [x] 自审修复：补齐 8 个“预设有键但 shader 无参数”的项（贴花 2nd/3rd 序列帧 6 项 + 不受光 2 项），参数 227
- [x] 工具链：材质 A→B 批量替换（菜单「批量替换选中网格的材质…」，支持 material_override 与 surface override）
- [x] UndoRedo：毛发生成与材质替换均已接入 `EditorUndoRedoManager`，用户已在编辑器内实测撤销/重做通过
- [x] 贴花序列帧：2nd/3rd 的列/行/速度，按 `TIME` 取帧
- [x] 2nd/3rd 不受光开关：关闭后贴花写入自发光
- [x] MatCap 每槽法线强度：`matcap_2nd/3rd_normal_strength`（223 参数）
- [x] MatCap 每槽遮罩：`use_matcap_2nd/3rd_mask` + 贴图（227 参数）
- [x] 2nd/3rd 名称别名 25 条（BlendMask/UVMode/Angle/BlendMode/Color/DissolveColor/MatCapBlend/Lod/MainStrength/NormalStrength/Receive 未含）
- [x] MatCap 每槽 LOD：`matcap_2nd/3rd_lod`（229 参数）
- [x] 2nd/3rd 贴层法线贴图：`use_decal_2nd/3rd_normal` + 贴图 + 强度（235 参数）
- [x] MatCap 每槽法线贴图：`use_matcap_2nd/3rd_bump` + 贴图 + 强度（241 参数）
- [x] 每层阴影色贴图：`use_shade_2nd/3rd_color_tex`（245 参数）
- [x] 逐层接收阴影：`use_shade_2nd/3rd_receive`，阴影中加回该层颜色（247 参数）
- [x] 各向异性（1st）：`use_anisotropy` / shift / scale / specular_strength，Kajiya-Kay 近似（251 参数）
- [x] 各向异性（2nd/3rd）：`use_anisotropy_2nd/3rd` + shift/scale/strength（259 参数）
- [x] Glitter：`use_glitter` + 颜色/强度/密度/灵敏度/对比度，程序化闪点（265 参数）
- [x] Parallax（主贴花）：复用 `use_parallax` / `parallax_texture` / `parallax_height`，按视角偏移 UV（265 参数）
- [x] Parallax（2nd/3rd）：`use_parallax_2nd/3rd` + 高度图 + 深度（271 参数）
- [x] 每层溶解遮罩：`use_decal_2nd/3rd_dissolve_mask`（275 参数）
- [x] 2nd 自发光 UV 模式/滚动（277 参数）
- [x] Glitter / 各向异性别名 14 条
- [x] 2nd 自发光渐变：`use_emission_2nd_grad` + 贴图 + 速度（280 参数）
- [x] 每层溶解噪声：`use_decal_2nd/3rd_dissolve_noise` + 贴图 + 强度（286 参数）
- [x] Glitter 细分：`use_glitter_shape` + 形状贴图 + `glitter_scale_randomize`（289 参数）
- [x] 各向异性宽度：tangent / bitangent，1st/2nd/3rd（295 参数）
- [x] 综合效果演示 `feature_lab.tscn`（各向异性 + Glitter + Parallax）：`-- shot` 已复验可用，截图归档到 `docs/evidence/阶段5/feature_lab.png`
- [x] Glitter UV 模式：`glitter_uv_mode`（UV / UV2），296 参数
- [x] 各向异性偏移噪声：`use_anisotropy_shift_noise` + 贴图 + 幅度（299 参数）
- [x] 2nd/3rd 各向异性偏移噪声（305 参数）
- [x] MatCap 逐槽透明预乘：`matcap_2nd/3rd_apply_transparency`
- [x] 贴层距离淡出：`decal_2nd/3rd_distance_fade`（309 参数）
- [x] 逐层阴影法线强度：`shade_2nd/3rd_normal_strength`，按层独立 `N·L`（311 参数）
- [x] MatCap 逐槽背面遮罩：`matcap_2nd/3rd_backface_mask`（313 参数）
- [x] 贴层 Alpha 模式：`decal_2nd/3rd_alpha_mode`（315 参数）
- [x] 贴层剔除：`decal_2nd/3rd_cull_mode`（320 参数）
- [x] 2nd 自发光视差：`use_emission_2nd_parallax` + 高度图 + 深度（320 参数）
- [x] 每层溶解位置偏移：`decal_2nd/3rd_dissolve_offset`（322 参数）
- [x] AlphaMask：`use_alpha_mask` + 贴图 + scale/value/strength（327 参数）
- [x] 法线翻转：`flip_normal`；别名 `_ApplyReflection` → `use_reflection`（328 参数）
- [x] MatCap 透视缩放：`matcap_perspective` / `matcap_2nd/3rd_perspective`（331 参数）
- [x] AlphaToMask：3 个 A2C 变体 + 工厂 `set_alpha_to_mask()` + 面板开关 + 预设键 + `a2c_lab` 实机验证
- [x] 每层溶解噪声：`use_decal_2nd/3rd_dissolve_noise` + 贴图 + 强度（286 参数）
- [x] 多毛发物体 + 透明共存：双 9k 面毛球 + 两块透明面同场景，透明面正确染色、无层级反转（`docs/evidence/阶段6/fur_multiobject.png`）
- [x] C 组小批次：阴影 2nd/3rd 柔化、自发光闪烁、无光照（`use_unlit`）、单色光照（190 参数）
- [x] C 组 Rim 套件：`rim_blur`、`rim_main_strength`、`rim_indir_color/strength`、`rim_shadow_mask`、`rim_apply_transparency`（196 参数）
- [x] C 组描边补全：`outline_texture` / `outline_texture_uv_scale` / `outline_fix_width`（描边 19 参数）
- [x] 描边变体组合补齐：受光+透明、透明+预乘、受光+透明+预乘（新增 3 个描边 shader，预乘随主材质自动选择）
- [x] C 组第二层自发光：`use_emission_2nd` / 贴图 / 颜色 / 强度 / UV 缩放（201 参数）
- [x] C 组 MatCap 套件：`matcap_lod` / `matcap_normal_strength` / `matcap_main_strength`（204 参数）
- [x] C 组阴影：`shadow_receive` / `shade_normal_strength`（206 参数）
- [x] C 组 2nd 层：第二层自发光混合模式 + 遮罩（209 参数）
- [x] C 组每层溶解：`decal_2nd/3rd_dissolve_strength`，复用全局溶解遮罩与噪声（211 参数）
- [x] 透明描边变体：`outline_apply_transparency` / `outline_opacity`，面板「描边透明」+ 预设（描边 21 参数）
- [x] SSS 厚度：`sss_thickness_texture` / `sss_thickness_strength`（213 参数）
- [x] 工厂重建：误截断后按 API 重建并通过 showcase 实机回归
- [x] 角色级测试：约 9k 面 + 6 层 + 2 块透明面，55.2 FPS；视觉复验改用低负载短跑，截图为 6 层球体

验收：演示规模 ≥ 55 FPS（VSync 上限约 57）；参数描述 100%；与 liltoon 毛发行为差异有书面说明。

自审（2026-10-24）：通过。6 层 60 FPS（1152×648）；参数 152、描述 100%；冒烟全绿；证据 4 张。遗留现状：UndoRedo 与毛发 rim 已补，角色级帧率与视觉证据已补（`docs/evidence/阶段9/fur_perf_lab.png`，复测 37 FPS 记入 RISKS），毛束动效仍只能动态验证；`touch` 在 lilToon 2.4.1 中无对应参数。

## P7 渲染器兼容（完成，Vulkan 环境限制）

- [x] Mobile 降级：实测 `hint_depth_texture` 取不到有效深度，后处理描边自动关闭并提示；网格描边仍可用（截图 `阶段7/outline_mobile.png`）
- [x] Compatibility 降级：同样关闭后处理描边并提示；decal / fur / showcase 在 OpenGL 3.3 下无 shader 错误（截图 `阶段7/outline_gl_compatibility.png`）
- [x] 双驱动：D3D12 正常；Vulkan 启动即退出（环境限制，已记录）

验收：D3D12 Forward+/Mobile、OpenGL Compatibility 加载无报错；Vulkan 未验证；降级清单与限制写入 §9。`outline_forward_plus.png` 复用阶段 6 的 Forward+ 截图。

## P8 性能与变体管理（完成）

- [x] Shader 变体与关键字管理：Godot 无 Unity 关键字，改用参数开关（`liltoon_quality.gd`）
- [x] 性能档位：高/中/低，关闭高光/Rim/MatCap/SSS/法线/AO；演示 `quality_lab.tscn` 可按键切换
- [x] 基准场景：`-- bench` 可用（关 VSync + 跳过 0.5 s 预热 + 平均帧时间）；结果 high 151 FPS / medium 145 / low 145 @ 1152×648，见 `docs/evidence/阶段8/quality_bench.txt`

验收：档位可切换且画面符合预期；基准数据归档。

## P9 全量对齐与发布（进行中）

- [x] 参数级对照矩阵（现由 `tools/gen_alignment_matrix.py` 自动重算：465 主参数 + 32 描边，**296 对齐 / 282 未对齐**；旧口径 433/239/277 已废弃，原因是属性基线虚高 36 项表情占位参数）
- [x] 「其他 161」逐条审计（见 `docs/其他_161审计.md`）
- [x] Alpha To Coverage、`_AAStrength`、`_Emission2ndFluorescence`
- [x] 真实预设缩略图（离线渲染静态 PNG）
- [x] 描边受光/透明/预乘组合
- [x] 主贴图 UV 与 HSV（`_MainTex_ScrollRotate` / `_MainTexHSVG`）
- [x] 反射率（`_Reflectance` → `reflectance`）
- [x] 边缘光数学（`rim_border` / `rim_blur` / 方向性 / 背光色 / `rim_enable_lighting`）
- [-] 反射染色 / 反射法线（`_ReflectionColor` / `_ReflectionNormalStrength`）：Godot 环境 IBL 硬限制，接受差异
- [x] `_GSAAStrength`、主色渐变、背面颜色、抖动透明
- [x] 金属度/光滑度贴图、反射乘透明、Rim 背面遮罩/颜色贴图/法线强度
- [x] Rim Shade 子套件
- [x] 逆光 / 背光套件（`_UseBacklight` / `_Backlight*`）
- [x] 描边贴图动画与宽度遮罩
- [x] 描边矢量图 / 顶点色宽度
- [x] 2nd 法线 UV/遮罩、遮罩与噪声滚动
- [x] 阴影主开关/色贴图/乘反照率/背面强制阴影、逆光接收阴影
- [x] 阴影边界染色/范围/强度遮罩、描边受光阴影开关
- [x] 阴影边界/柔化遮罩、AO 偏移、平面阴影
- [x] 主自发光套件（开关/UV/渐变/视差/荧光/混合与遮罩）
- [x] MatCap 主槽补登记、背面遮罩与主槽法线贴图
- [x] Glitter 形状贴图与背面遮罩
- [x] 命名/默认值语义对齐，可映射 liltoon 预设（2026-10-28 完成：默认值差异 20→0，3 个 `*_enable_lighting` 默认值修正、`_MatCapMainStrength` 语义修正、3 个 bool→float 程度值）
- [x] 迁移指南与文档（2026-10-28：`docs/迁移指南.md` 三条迁移路径 + 参数对照 + 不支持项分类 + 已知差异 + 排查表）
- [x] 全量回归场景（2026-10-28：回归由多 lab 分担，`docs/发布检查清单.md` 把自动检查 / 人工目视 / 换机待验串成流程；`showcase.tscn` 作为整体观感入口）
- [x] 发布 v1.0（2026-10-28：`plugin.cfg` 版本 0.1.0→1.0.0、描述去掉"P0 核心版"；补 `README.md`；清理 `docs/参数对齐矩阵.md.bak`；最终检查冒烟 / 默认值 / 矩阵三项全绿）
- [x] P9 产出自审（2026-10-28 补做）：修 12 处 `.tscn` 过时参数值（bool/null → float）、`rim_lab.gd` 传参类型、补 `LiltoonPresetImport` 的 `class_name`、修正迁移指南类名与 5 处数字、`plugin.cfg` 去掉误导的"三槽"；详见 `docs/自审报告_2026-10-28.md` 追加章节
- [x] 发布前静态全量审计（2026-10-28）：新增 `tools/audit_release.py`，资源路径 / 类名唯一性 / 插件入口 / 文档死链 / 未完成标记**全部 0**；修正 2 处过时数字（变体 13→17、矩阵 433/239/277→465/280/200）
- [x] 补 `effects/` 编译验证缺口（2026-10-28）：`compile_check.gd` 改为扫描 `shaders/` + `effects/` 两个目录，**追加在末尾**保证前 23 个索引不变；`check_all_shaders.ps1` 默认范围 22→24；用 `--headless --list` 确认索引顺序正确（23、24 为后处理）。**2026-10-29 换机后已实跑**：25/25 全部 `OK`（23 个主材质/描边 + 2 个后处理），日志 `docs/evidence/compile_check.log`
- [x] 参数描述质量抽查（2026-10-28）：484 个描述块、0 个重复；11 个"过短"中 8 个是 `group_uniforms` 分组标题（简短正常），实际补全 3 个参数（`sss_strength` / `glitter_color` / `glitter_intensity`）
- [x] 预设质量审查（2026-10-28）：5 个预设（default / skin / hair / cloth / metal）色值合理、开关配套；hair 用三层直接高光模拟发丝而非各向异性，属设计选择
- [x] **复查发现功能性遗漏（2026-10-28 发现，2026-10-29 补齐）**：属性统计口径先后三次修正（480 → 521 → **578**），因为最初只读 `lts.shader` 一个文件。最终确认 **15 项"可做但未做"**：折射 4（`_Refraction*`）、宝石 4（`_GemChromaticAberration` / `_GemEnvColor` / `_GemEnvContrast` / `_GemParticleColor`）、假阴影 1（`_FakeShadowVector`）、毛发 6（`_FurMask` / `_FurNoiseMask` / `_FurRandomize` / `_FurVectorTex` / `_VertexColor2FurVector` / `_FurTouchStrength`）。**2026-10-29 全部实现**，矩阵升至 **306 对齐 / 272 未对齐**，每项有截图证据（`docs/evidence/阶段9/`：`fakeshadow_lab.png` / `refraction_lab.png` / `fur_features_lab.png` / `gem_lab.png`）
- [x] **Editor 工具缺失（2026-10-28 复查，2026-10-29 补齐）**：lilToon 有 46 个 Editor 脚本（约 800 KB），本项目缺 5 个模块，**2026-10-29 全部实现**——`liltoon_texture_baker.gd`（纹理烘焙：主色/贴图/HSV/渐变/贴花烘成一张，CPU 逐像素，弱机可用）、`liltoon_setting.gd`（全局设置，ProjectSettings 持久化）、`liltoon_optimizer.gd`（材质优化建议）、`liltoon_startup.gd`（启动版本检查与过时参数扫描）、`liltoon_language_manager.gd`（中/英文案）。菜单已接入插件，冒烟含 5 项功能验证
- [x] 交接文档（2026-10-28）：`docs/交接文档.md` 汇总现状、15 项 shader 遗漏、4–5 个 Editor 缺失、硬件限制成因、换机后的五步执行顺序、工具速查与八条踩坑记录

验收：矩阵无缺项；回归全绿；发布说明完成。

## P10 可选扩展（未开始，不阻塞主线）

- [ ] AudioLink 等价实现（依赖音频总线与频谱分析）
- [ ] A 类特色功能（clearcoat 等，若实现则单列，不混入对齐主线）

验收：每项独立演示；默认关闭，不影响主线。

---

## 功能对照表

> 对齐基准：所有项以 **liltoon（Unity 原版）** 的行为为准，「完成」指**行为对齐**而非仅接口存在。
> 若 Godot 侧实现与原版不同且更优，必须在备注中标注并交由用户裁定是否保留。

| liltoon 功能 | 状态 | 所属阶段 |
|---|---|---|
| 主色 / 阴影色 / 色阶 | 完成 | P0 |
| 主贴图 UV 滚动/旋转、HSV/Gamma | 完成 | P9（`main_uv_scroll` / `main_uv_rotate` / `main_hsvg`） |
| 主色渐变 / 主色调整遮罩 | 完成 | P9（`main_gradation_texture` / `main_color_adjust_mask`） |
| 背面颜色 / 背面 UV | 完成 | P9（`backface_color` / `shift_backface_uv`） |
| 抖动透明 | 完成 | P9（`use_dither` / `dither_texture` / `dither_max_value`） |
| 阴影 ramp / 2nd / 3rd | 完成 | P1 |
| 受影强度 / 阴影偏移 | 完成 | P1 |
| AO（贴图 / 顶点色） | 完成 | P1 |
| 多光源（方向 / 点 / 聚光） | 完成 | P1 |
| 法线贴图（单层） | 完成 | P0 |
| 双法线 | 完成 | P2 |
| 顶点色混合 | 完成 | P2 |
| 三平面映射 | 完成 | P2 |
| 透明排序（前置深度 / 预乘） | 完成 | P2 |
| Toon 高光（单层） | 完成 | P0 / P9（`specular_normal_strength` 对齐 `_SpecularNormalStrength`，控制法线贴图对高光的影响） |
| 多层 / 各向异性高光 | 完成 | P3 |
| Rim Light（单层） | 完成 | P0 |
| Rim 2nd / mask | 完成 | P1 |
| Rim 方向性 / 背光色 / 边界柔化 | 完成 | P9（对齐 `_RimBorder` / `_RimBlur` / `_RimDir*` / `_RimIndir*` / `_RimEnableLighting`） |
| Rim 背面遮罩 / 颜色贴图 / 法线强度 | 完成 | P9（`_RimBackfaceMask` / `_RimColorTex` / `_RimNormalStrength`） |
| Rim Shade | 近似 | P9（`_UseRimShade` / `_RimShade*`；在 ALBEDO 上压暗近似原版最终颜色混合） |
| Rim 受光/背光切换 | 完成 | P3 |
| 逆光 / 背光（`_UseBacklight` / `_Backlight*`） | 完成 | P9（10 项对齐；加法写入 `SPECULAR_LIGHT`，不随阴影衰减） |
| 金属 / 镜面反射 | 完成 | P3 / P9（`_Reflectance`、`_MetallicGlossMap`、`_SmoothnessTex`、`_ReflectionApplyTransparency`、`_ReflectionColorTex`（标量亮度近似）；反射染色/反射法线/反射混合模式受环境 IBL 限制） |
| 阴影 caster / 深度偏移 | 完成 | P3 |
| MatCap（单槽） | 完成 | P0 |
| MatCap 2/3 | 完成 | P2 |
| Emission | 完成 | P0 |
| 描边（法线外扩） | 完成 | P0 |
| 描边多模式 / 屏幕空间 | 完成 | P2 |
| 描边贴图动画 / 宽度遮罩 | 完成 | P9（`_OutlineTex_ScrollRotate` / `_OutlineTexHSVG` / `_OutlineWidthMask`；6 个描边变体抽成公共 include） |
| 描边矢量图 / 顶点色宽度 | 完成 | P9（`_OutlineVectorTex/Scale/UVMode`、`_OutlineVertexR2Width`） |
| 描边受光 / 透明 / 预乘组合 | 完成 | P9（6 种有效组合，预乘随主材质自动选择） |
| Cutout / 透明 | 完成 | P0 |
| Alpha To Coverage（`_AlphaToMask`） | 完成 | P9（3 个 A2C 变体 + 面板开关 + 预设键；需视口 MSAA） |
| 阴影抗锯齿（`_AAStrength`） | 完成 | P9（`aa_strength`，fwidth 扩宽 toon 边界） |
| 第二层自发光荧光（`_Emission2ndFluorescence`） | 近似 | P9（多光源逐光源累加，正片叠底不生效） |
| 主自发光套件 | 完成 | P9（开关/UV/渐变/视差/荧光/混合与遮罩；正片叠底近似） |
| MatCap 主槽补登记 / 背面遮罩 | 完成 | P9（`_MatCapBlend*` / `_MatCapPerspective` / `_MatCapBackfaceMask` / `_MatCapBump*`；其余 MatCap 项仍待补） |
| Glitter 形状与背面遮罩 | 完成 | P9（`_GlitterApplyShape` / `_GlitterShapeTex` / `_GlitterBackfaceMask`） |
| 双面渲染 / 仅背面渲染 | 完成 | P2 / P4 |
| SSS / 头发 / 眼睛 | 完成（SSS 为透射近似） | P3 |
| 溶解 | 完成 | P5（噪声/遮罩/UV/物体空间 + 边缘发光带；AlphaMask 经遮罩贴图覆盖） |
| 后处理描边 | **不生效（待查）** | P5（全屏四边形 + 深度/法线纹理，8 方向相对差）。2026-10-28 复查：`depth_texture` 采样恒为 0 → 描边不出现；法线边原为死代码，现已接线但默认关闭 |
| 距离淡出 / 描边隐藏 | 完成 | P5（相机/物体距离；表面与描边同步淡出） |
| 反射 / 光照探针 | 部分 | P5（环境 IBL + LightmapGI 已验证；ReflectionProbe 在当前环境不生效，已记入 RISKS） |
| 贴花 / 装饰 | 近似 | P5 / P9（三层贴花 + 每层遮罩/UV 滚动/序列帧/法线 UV 与强度遮罩；主贴花无序列帧） |
| 2nd 遮罩与逐层噪声滚动 | 完成 | P9（`_Emission2ndBlendMask_ScrollRotate` / `_Main2nd·3rdDissolveNoiseMask_ScrollRotate`） |
| 阴影主开关 / 色贴图 / 乘反照率 / 背面强制阴影 | 完成 | P9（`_UseShadow` / `_ShadowColorTex` / `_ShadowMainStrength` / `_BackfaceForceShadow` / `_BacklightReceiveShadow`） |
| 阴影边界染色 / 强度遮罩 / 描边受光阴影 | 完成 | P9（`_ShadowBorderColor` / `_ShadowBorderRange` / `_ShadowStrengthMask` / `_OutlineLitShadowReceive`） |
| 阴影边界/柔化遮罩、AO 偏移、平面阴影 | 完成 | P9（`_ShadowBorderMask` / `_ShadowBlurMask` / `_ShadowAOShift*` / `_ShadowMaskType` / `_ShadowFlat*`；LOD 跳过） |
| 毛发 | 完成（近似） | P6（MultiMesh 1–12 层、cutout/透明、风/重力、根梢色、噪声、rim；无几何着色器、无 touch） |
| 材质转换器 / 批量替换 / 预设导入导出 / 校验修复 | 完成 | P4 |
| 多渲染器支持 | 完成（降级） | P7（D3D12 Forward+/Mobile、OpenGL Compatibility 可加载；Vulkan 启动即退出） |
| 完整功能对齐 | 完成（可做项） | P9（矩阵 336/578 对齐；剩余 242 项全部为 Unity 渲染状态 / IDMask / UDIM / AudioLink / VR / 引擎限制，逐项理由见 §9。含 15 项遗漏 + 16 项二轮复核 + 15 项登记缺口） |
---

## SCOPE LOG

| 日期 | 变更 | 影响阶段 |
|---|---|---|
| 2026-10-23 | 溶解、后处理描边提前完成（原 P5 清单） | P5 |
| 2026-10-23 | 转换器补 AO、Alpha Hash 改透明近似、SSS 近似、未转换项提示 | P4 收尾 |
| 2026-10-23 | `cull_front` 变体与面板「渲染面」下拉补齐 | P2/P4 收尾 |
| 2026-10-23 | 后处理描边由 CompositorEffect 改为全屏四边形（D3D12 挂起） | P5 |
| 2026-10-23 | 移除主体 render_mode 的 `specular_disabled`，默认 `SPECULAR = 0`；修复反射探针不生效 | 全部阶段（已回归 showcase / variant） |
| 2026-10-24 | 毛发从 `next_pass` 壳层链改为 MultiMesh 实例（next_pass 只支持一层）；删除 `fur_lab` 旧原型 | P6 |
| 2026-10-24 | 批量编辑时误将 `liltoon_material_factory.gd` 截断为 40 行；按调用点重建全部 API，冒烟与 showcase 回归通过 | 全阶段 |
| 2026-10-25 | 补 A2C 收尾：`liltoon_cutout_a2c{,_double,_front}.gdshader`、工厂变体切换、面板开关、预设键 `use_alpha_to_mask`、转换器映射；新增 `a2c_lab` 演示与证据 | P9 |
| 2026-10-25 | 新增 `aa_strength`（`_AAStrength`）、`emission_2nd_fluorescence`（`_Emission2ndFluorescence`）；新增 `emission_lab` 演示与证据 | P9 |
| 2026-10-25 | `quality_lab -- bench` 修复：关闭垂直同步、跳过 0.5 s 预热、统计平均帧时间；三档基准已归档 | P8 收尾 |
| 2026-10-25 | 刷新参数对齐矩阵（337 主参数 + 21 描边）与「其他 161」逐条审计 | P9 |
| 2026-10-25 | 修复 `use_alpha_mask` 误缩进在 `use_distance_fade` 分支内、未开淡出时不生效的问题；A2C 的最终裁切也改为使用含遮罩的 ALPHA | P1 / P9 |
| 2026-10-25 | 描边变体补齐：`liltoon_outline_lit_transparent` / `_transparent_premul` / `_lit_transparent_premul` 三个 shader；工厂按受光×透明×预乘选变体，预乘随主材质；修复 `bool(null)` 导致的描边开关报错 | P2 / P9 |
| 2026-10-25 | 主贴图 UV/HSV：`main_uv_scroll` / `main_uv_rotate` / `main_hsvg`（对齐 `_MainTex_ScrollRotate` / `_MainTexHSVG`）；新增 `main_uv_lab` 演示 | P1 / P9 |
| 2026-10-25 | 反射率 `reflectance`（对齐 `_Reflectance`，写入 Godot `SPECULAR`/F0） | P3 / P9 |
| 2026-10-26 | 边缘光按 lilToon 原式重写：`rim_border` / `rim_dir_strength` / `rim_dir_range` / `rim_indir_range` / `rim_indir_border` / `rim_indir_blur` / `rim_enable_lighting`；移除 `rim_light_mode`；新增 `rim_lab` 演示 | P1 / P9 |
| 2026-10-26 | 主色渐变/遮罩、背面颜色/UV、抖动透明、GSAA：对齐 `_MainGradation*` / `_MainColorAdjustMask` / `_BackfaceColor` / `_ShiftBackfaceUV` / `_UseDither` / `_Dither*` / `_GSAAStrength`；新增 `material_extra_lab` | P1 / P9 |
| 2026-10-26 | 金属度/光滑度贴图、反射乘透明、Rim 背面遮罩/颜色贴图/法线强度；新增 varyings `lil_geo_normal` / `lil_facing`，顺带修正 `lil_view` 的模型空间/视空间混用 | P3 / P9 |
| 2026-10-26 | Rim Shade 子套件（`_UseRimShade` / `_RimShade*` 6 项）；矩阵 Rim 未对齐降到 6 项 | P1 / P9 |
| 2026-10-26 | 逆光/背光套件（`_UseBacklight` / `_Backlight*` 10 项）；光照限制未对齐降到 5 项 | P1 / P9 |
| 2026-10-26 | 描边贴图动画/宽度遮罩（`_OutlineTex_ScrollRotate` / `_OutlineTexHSVG` / `_OutlineWidthMask`）；6 个描边 shader 抽成 `outline_common.gdshaderinc` | P2 / P9 |
| 2026-10-26 | 描边矢量图与顶点色宽度（`_OutlineVector*` / `_OutlineVertexR2Width`）；描边未对齐降到 35 项 | P2 / P9 |
| 2026-10-26 | 2nd/3rd 矩阵补登记 24 项（实际已实现但未登记），未对齐从 56 降到 32 | P2 / P9 |
| 2026-10-26 | 补齐 2nd 法线 UV/强度遮罩、2nd 遮罩与逐层溶解噪声滚动；2nd/3rd 未对齐降到 27 | P2 / P9 |
| 2026-10-26 | 阴影补全：`use_shadow` / `shade_color_texture` / `shadow_main_strength` / `backface_force_shadow` / `backlight_receive_shadow`；阴影未对齐降到 19 | P1 / P9 |
| 2026-10-26 | 阴影边界染色/范围/强度遮罩、描边受光阴影开关；阴影未对齐降到 15 | P1 / P9 |
| 2026-10-27 | 阴影边界/柔化遮罩、AO 偏移、平面阴影；阴影未对齐降到 8 | P1 / P9 |
| 2026-10-27 | 主自发光套件：`use_emission` / UV 旋转滚动 / 渐变 / 视差 / 主荧光；自发光未对齐降到 7 | P1 / P9 |
| 2026-10-27 | 主自发光混合：`emission_blend` / `emission_blend_mode` / `emission_mask` / `emission_main_strength`；自发光未对齐只剩 AudioLink 2 项 | P1 / P9 |
| 2026-10-27 | MatCap 主槽补登记与背面遮罩；MatCap 未对齐降到 10 | P3 / P9 |
| 2026-10-27 | MatCap 主槽法线贴图、Glitter 形状/背面遮罩；MatCap 未对齐 8、Glitter 10 | P3 / P9 |
| 2026-10-27 | 高光法线强度 `specular_normal_strength`、反射染色贴图 `reflection_color_tex`（标量近似）；「其他 161」的可做未做清零 | P1 / P3 / P9 |
| 2026-10-27 | MatCap 主槽预乘透明与 UV1 混合、Glitter 颜色贴图/预乘透明/法线强度/朝向随机、阴影三遮罩 LOD、各向异性缩放遮罩；参数 449 | P1 / P3 / P9 |
| 2026-10-27 | MatCap 自定义法线与第二槽 UV1 混合、距离淡出边缘光（颜色 + 菲涅尔幂）、阴影环境光强度（近似）；参数 454 | P1 / P3 / P9 |
| 2026-10-28 | 各向异性切线贴图 `use_anisotropy_tangent_map`（对齐 `_AnisotropyTangentMap`）；`_RimBlendMode` 判定为硬限制；参数 456 | P3 / P9 |
| 2026-10-28 | MatCap / 闪点的受光与阴影 4 项开关化实现（`matcap_enable_lighting` / `matcap_shadow_mask` / `glitter_enable_lighting` / `glitter_shadow_mask`）；新增 varying `lil_view_depth`；参数 460 | P1 / P3 / P9 |
| 2026-10-28 | 第二槽 MatCap 三项（自定义法线 / 受光 / 阴影）照主槽同构补齐；矩阵改为 `tools/gen_alignment_matrix.py` 重算，当前 278 对齐 / 202 未对齐；参数 463 | P3 / P9 |
| 2026-10-28 | 各向异性法线复用到 MatCap 两槽（`anisotropy_2_matcap` / `_2nd`，对齐 `_Anisotropy2MatCap(2nd)`）；矩阵 280 对齐 / 200 未对齐；参数 465 | P3 / P9 |
| 2026-10-28 | 新增 `tools/smoke.ps1`（120 秒硬超时）：冒烟曾因 `preset_library.gd` 字典键重复导致编译失败、`smoke_test.gd` 继续执行卡死 5 分钟；原则新增第 11 条 | 工具 |
| 2026-10-28 | **P9 开工**：新增 `tools/compare_defaults.py`，默认值差异从 20 项修到 0；修正 3 个 `*_enable_lighting` 的默认值（原版为 1，此前误设 0）、`_MatCapMainStrength` 语义（改为向主色靠拢）、3 个 bool→float 程度值（`_RimEnableLighting` / `_RimShadowMask` / `_ShadowReceive`） | P9 |
| 2026-10-28 | 各向异性法线复用到 MatCap 两槽（`anisotropy_2_matcap` / `_2nd`，对齐 `_Anisotropy2MatCap(2nd)`）；矩阵 280 对齐 / 200 未对齐；参数 465 | P3 / P9 |
| 2026-10-28 | 视觉验证 6 组（MatCap 受光/阴影、第二槽、UV1、Glitter、距离淡出边缘光、各向异性、阴影 LOD）；**修正实现错误**：阴影强度遮罩原先只作用于引擎实时阴影，未作用于 toon 阴影，现按原版 `lerp(1, lns.x, shadowStrength)` 修正 | P1 / P3 / P9 |
| 2026-10-28 | 历史欠账复测：A2C、毛发壳层与阶段记录一致；**后处理描边复测不通过**——`depth_texture` 采样恒为 0，描边实际不出现（详见 §9 与审计）；补 `fur_multi_lab` 缺失的 `-- shot` 分支 | P5 / P6 / P7 |
| 2026-10-28 | P0–P8 全量代码审查（8 维度：数学安全 / 死参数 / 采样浪费 / 边界 / 参数名 / 变体配置 / 导入映射 / 画质档位）。修复：毛发束参数未接线、导入映射 2 处错名；记录画质档位语义问题 | P0–P8 |
| 2026-10-29 | 换机首轮验证（RTX 4060 / Win11 / Godot 4.7.2 D3D12）：`character` 正常出图、`dissolve_lab` 一次通过、两个后处理 shader 编译 OK。工具脚本去旧机硬编码：Godot 路径改 `GODOT_EXE` 环境变量优先、lilToon 源码改项目内 `lilToon-2.4.1/`、冒烟修复含空格路径被拆参数的问题 | 工具 / P5–P9 |
| 2026-10-29 | **修复后处理描边**：定位 `depth_texture` 恒 0 的根因为 opaque shader 写 `ALPHA` 被 Godot 判为透明、主通道不写深度；三个 opaque 变体加 `depth_prepass_alpha`。实测描边恢复，证据 `docs/evidence/阶段9/outline_postprocess_fixed.png` | P5 / P9 |
| 2026-10-29 | **补齐 15 项遗漏**：假阴影 1（`liltoon_fakeshadow.gdshader`）、折射 4（`liltoon_refraction.gdshader`）、毛发 6（遮罩/噪声遮罩/随机化/向量贴图/顶点色/触摸）、宝石 4（`liltoon_gem.gdshader`：色散折射/环境色/对比度/粒子色）。矩阵 296→307 对齐，证据 `docs/evidence/阶段9/` 四张截图 | P9 |
| 2026-10-29 | **二轮复核补 16 项隐藏遗漏**（「明确不做」分类是粗糙的、无逐项理由，里面藏了可做项）：高光 toon 化 3（`_SpecularToon/Border/Blur`）、描边受光 4（`_OutlineLit*`）、阴影遮罩顺序 1（`_ShadowPostAO`）、阴影色 LUT 1（`_ShadowColorType`）、视差零点 1（`_ParallaxOffset`）、MatCap 滚转抵消 1（`_MatCapZRotCancel`）、闪点图集 1（`_GlitterAtras`）、自定义反射立方体贴图 4（`_ReflectionCube*`）。另补 15 项登记缺口（`_FurLayerNum`→`fur_layers` 等，已有实现但矩阵漏登记）。矩阵 307→**336** 对齐 | P9 |
| 2026-10-29 | **补齐 Editor 工具 5 模块**：`liltoon_texture_baker.gd`（纹理烘焙，CPU 逐像素）、`liltoon_setting.gd`（全局设置）、`liltoon_optimizer.gd`（优化建议）、`liltoon_startup.gd`（启动检查）、`liltoon_language_manager.gd`（中/英）。菜单接入插件，冒烟含 5 项功能验证 | P9 |
| 2026-10-29 | `project.godot` 移除失效的 `config/icon` 引用（项目内无 `icon.svg`，每次启动都报 ERROR）。注：编辑器已打开时改 project.godot，需重启编辑器才生效 | 工具 |

## RISKS

| 风险 | 影响 | 处置 |
|---|---|---|
| CompositorEffect 的 compute 写回在 D3D12 + Intel UHD 挂起 | 后处理类效果无法用计算路径 | 已改屏幕空间四边形；后续计算类需求先做 Spikes |
| 毛发依赖透明排序与深度 | 已验证方案 | next_pass 只支持一层，已改用 MultiMesh（6 层 57 FPS）；角色级约 9k 面 + 6 层历史记录 55.2 FPS，2026-10-26 复测 37 FPS，视觉证据已补（`阶段9/fur_perf_lab.png`），帧率差异待换环境复核 |
| MCP 截图通道在编辑器长时运行后失效 | 视觉证据无法抓取 | 本次靠直跑日志与窗口截图；建议重启编辑器后补拍角色级毛发截图 |
| ReflectionProbe 在当前 D3D12 + Intel UHD 617 上不生效 | 探针反射不可用 | 标准材质对照同样全黑；Vulkan 启动即退出，需换驱动/硬件复验，暂以环境 IBL 兜底 |
| AudioLink 依赖音频总线与频谱全局 uniform | P10 依赖外部配置 | 放最后，可选，不阻塞主线 |
| Mobile/Compatibility 缺少屏幕纹理/计算 | P7 降级范围大 | 先列降级清单再实现 |
| 参数级对齐工作量大且易漏 | P9 风险 | 用脚本生成 lilToon 2.4.1 参数矩阵逐项核对 |
| LightmapGI 烘焙只有编辑器 UI、无脚本 API | 已关闭 | 已人工烘焙一次并验证生效；自动化仍无法覆盖，回归时需手动烘焙 |
| 渲染类全量自检（一次加载全部 shader + MSAA 4x + 阴影） | Intel UHD 617 + D3D12 上两次触发 `0x139` 蓝屏（2026-10-27 14:48、16:06） | `compile_check` 已改为默认单 shader、关闭 MSAA 与阴影；全量检查必须逐进程循环，且确认编辑器空闲 |
| 溶解场景触发设备重置 | `dissolve_lab.tscn` 4 次尝试（2026-10-28 16:12 / 17:22 / 17:28 / 17:39）全部 `DXGI_ERROR_DEVICE_REMOVED`，崩点固定在截图读回的 `buffer_create`；同机其他场景正常。已排除噪声 GPU 生成（改 CPU 无效）与分辨率因素 | 该场景在本机无法验证，视觉验证换环境补；若用户场景出现同样崩溃，优先怀疑溶解材质相关的 GPU 状态 |
| `character` 场景本机无法渲染（加载阶段即失效） | 2026-10-28 实测：场景 579 KB（`variant_lab` 仅 96 KB，6 倍），29 个 `sub_resource`、11 个身体部件各挂 465 参数的材质。启动画面之后**全程全黑**，日志无 `PipelineState` 错误、无 TDR 记录——设备静默失效。相机位置与环境（天空背景）均正常 | 判断为**加载/上传阶段超出本机能力**。该场景转"换环境验证"，本机不再尝试。另记一条方法论教训：命令行跑场景时"无报错"不等于"有画面"，黑屏不产生日志，必须截图或人工确认 |
| 触发点在**场景初始化**而非运行时长（已定位，推翻"60 秒阈值"） | `character` 用 `--quit-after 1`（只渲染 1 帧）**8.1 秒内即 TDR +1**，说明崩溃发生在第一帧之前；而 `variant_lab` 可稳定跑 61.6 秒。两者差异在初始化负担：character 579 KB / 29 个 sub_resource / 11 个部件 × 4 光源，variant_lab 96 KB / 14 个 sub_resource / 1 光源 | 模型：**参数 152→465 使 shader 源码 1500→3900 行 → 单材质编译时间上升 → 11 材质 × 4 光源串行编译，初始化阶段累计超 2 秒 → TDR → 设备重置 → 全黑**。处置：本机验证只跑"少材质 + 少光源"的场景；`character` 转换环境验证。注意 `--quit-after` 控制帧数**无法规避**此问题（1 帧也崩） |
| 多材质场景：重启后多数可用，character 待定 | 事件日志实测：TDR（4101）14 次全部集中在 2026-10-28 16:06–19:01；WHEA 硬件错误 **0 条**；空场景 `test.tscn` 300 帧 TDR 零增加。**重启后复测**：`variant_lab`（13 材质）300 帧零 TDR，加长到 1800 帧 / 61.6 秒**仍零 TDR**；`character` 跑 26.5 秒后 **TDR +1**，但该次是在 variant_lab 之后累计 87 秒时发生，无法区分是场景本身重还是累积 | 判断：**硬件未损坏**。多材质场景重启后可用（至少 `variant_lab` 稳定）。`character` 需重启后**单独**跑一次才能定性；若单独跑也 TDR，则它属于"重到本机画不动"，转换环境验证。缓解手段仍可试 `--rendering-method mobile` |
| 设备移除会波及全部场景（不止溶解） | 2026-10-28 用户手动测试：`variant_lab` / `quality_lab` / `dissolve_lab` 三个场景在启动后 34–39 秒全部报 `render_pipeline_create: Create(Graphics)PipelineState failed 0x887a0005` 并黑屏；`character` 直接把编辑器带崩。失败点是**管线创建**，早于截图读回 | 判断为 GPU 当前状态失效，非场景/代码问题（用户回忆早前曾成功运行过这些场景）。**处置：渲染验证前先重启机器**；若 Forward+ 仍黑屏，改用 `--rendering-method mobile` 再试；两个都黑则只能换环境。2026-10-29 换机（RTX 4060 / Win11）后 `variant_lab`、`character`、`dissolve_lab` 全部一次通过，确认旧机结论成立 |
| 后处理描边取不到深度 | 2026-10-28 实测：`depth_texture` 采样恒为 0（`ALBEDO = vec3(depth_center)` 探针全黑），`edge` 恒为 0，橙色描边不出现；去掉 `depth_test_disabled` 无效 | **2026-10-29 已定位并修复**：根因不是 D3D12/硬件，而是 opaque shader 在若干分支写 `ALPHA`，Godot 把材质判为透明、主通道不写深度。三个 opaque 变体加 `depth_prepass_alpha` 后描边恢复（`docs/evidence/阶段9/outline_postprocess_fixed.png`）。网格描边（next_pass）不受影响 |
| D3D12 渲染不稳（次数累积，静默可清零） | 2026-10-27 对照实验：编辑器全程开 + 30 秒间隔，**无冷却时第 14–15 次后崩**；分段跑并在段间静默 5 分钟后**累计 21 次全过**。全程内核池稳定在 151→168 MB 无单调增长，空闲内存 2.8→3.7 GB 只增不减 → **排除内存泄漏与显存耗尽**。蓝屏瞬间花屏，说明显示驱动在其内部结构上崩溃 | 判断：存在"随次数累积、静默几分钟可清零、不占内存"的效应，候选为热累积或驱动延迟回收（无温度传感器，无法细分，对策相同）。**执行规则：不要在短时间内频繁 run**——连续 5–10 次后让机器静默几分钟再继续，不设固定节奏；关掉编辑器可延长耐受。仍用 `tools/check_all_shaders.ps1` 逐进程 + `--resolution 640x360`。注：P6 及更早曾有过更密集的 run 而未崩，说明触发条件是在某个时间点之后才具备的，具体加的是什么仍未查明 |
| OpenGL 兼容路径不可用于本 shader | 主 shader 有 66 个 `sampler2D`，UHD 617 的 `GL_MAX_TEXTURE_IMAGE_UNITS` 为 16，`SceneShaderGLES3: Program linking failed` | 兼容性渲染器只能验证不含全部贴图的小 shader；本项目主材质无法在 Compatibility 下编译 |

## 收尾：非功能性细节（最后处理）

- [x] 真实预设缩略图（离线渲染球体，替代 CPU 示意图；工具 `tools/bake_preset_thumbnails.tscn`）
