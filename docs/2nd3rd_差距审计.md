# 2nd/3rd 贴层差距审计（2026-10-26，历史记录）

> 来源：`docs/参数对齐矩阵.md` 的「2nd/3rd 贴层」未对齐清单；立项时 98 项。
> 结论分四类：已覆盖（别名/已实现）、可做未做、接受差距、不可抗力。
>
> **2026-10-28 状态更新**：矩阵该类别剩余 **22 项**（贴花子参数与 UV 标记 16、MatCap2nd 剩余 2（`_MatCap2ndVRParallaxStrength` / `_MatCap2ndZRotCancel`）、AudioLink 映射 4）。
> MatCap2nd 的 UV1 混合 / 自定义法线 / 受光 / 阴影，以及 `_Anisotropy2MatCap` / `_Anisotropy2MatCap2nd` 已完成。
> 「可做未做 0」的结论仍然成立；下方「下一步」里的三项已在 2026-10-26 全部完成，仅作历史记录保留。

## 汇总

| 类别 | 数量（约） | 处理 |
|---|---|---|
| 已覆盖 | 69 | 别名或已实现，无需再做（2026-10-26 矩阵补登记 24 项） |
| 可做未做 | 0 | 本轮已清零 |
| 接受差距 | 17 | 语义差异/收益低，记录原因 |
| 不可抗力 | 8 | 引擎/平台限制，不实现 |

## 一、已覆盖（69）

> 2026-10-26 参数矩阵补登记 24 项：`_Main2nd/3rdTex_Cull`、`_Main2nd/3rdTexAlphaMode`、`_Main2nd/3rdDistanceFade`、`_Main2nd/3rdDissolveMask`、`_Main2nd/3rdDissolveNoiseMask`、`_Main2nd/3rdDissolveParams`、`_Main2nd/3rdDissolvePos`、`_Main2nd/3rdTexDecalAnimation`、`_Emission2ndGradTex/UseGrad/Map_UVMode/Map_ScrollRotate/ParallaxDepth`、`_MatCap2ndApplyTransparency/BackfaceMask/Perspective`。

### 贴花（15）

- `_Main2ndBlendMask` / `_Main3rdBlendMask` → `decal_2nd_mask` / `decal_3rd_mask`
- `_Main2ndTex_UVMode` / `_Main3rdTex_UVMode` → `decal_2nd_uv_mode` / `decal_3rd_uv_mode`
- `_Main2ndTexAngle` / `_Main3rdTexAngle` → `decal_2nd_uv_rotate` / `decal_3rd_uv_rotate`
- `_Main2ndTexBlendMode` / `_Main3rdTexBlendMode` → `decal_2nd_blend_mode` / `decal_3rd_blend_mode`
- `_UseMain2ndTex` / `_UseMain3rdTex` → `use_decal_2nd` / `use_decal_3rd`
- `_Color2nd` / `_Color3rd` → `decal_2nd_color` / `decal_3rd_color`
- `_Main2ndDissolveNoiseStrength` / `_Main3rdDissolveNoiseStrength` → `decal_2nd_dissolve_strength` / `decal_3rd_dissolve_strength`
- `_Main2ndEnableLighting` / `_Main3rdEnableLighting` → `decal_2nd_enable_lighting` / `decal_3rd_enable_lighting`
- `_Bump2ndMap` / `_Bump2ndScale` → `decal_2nd_normal_map` / `decal_2nd_normal_scale`（已实现逐层法线扰动）
- `_UseBump2ndMap` → `use_decal_2nd_normal`

### MatCap（12）

- `_MatCap2ndBlend` / `_MatCap3rdBlend` → `matcap_2nd_intensity` / `matcap_3rd_intensity`
- `_MatCap2ndBlendMask` / `_MatCap3rdBlendMask` → `matcap_2nd_mask` / `matcap_3rd_mask`
- `_MatCap2ndBlendMode` / `_MatCap3rdBlendMode` → `matcap_2nd_multiply` / `matcap_3rd_multiply`
- `_MatCap2ndLod` / `_MatCap3rdLod` → `matcap_2nd_lod` / `matcap_3rd_lod`（已实现每槽）
- `_MatCap2ndMainStrength` / `_MatCap3rdMainStrength` → `matcap_main_strength`（共享）
- `_MatCap2ndBumpMap` / `_MatCap2ndBumpScale` → `matcap_2nd_bump_map` / `matcap_2nd_bump_scale`（已实现）
- `_MatCap3rdBumpMap` / `_MatCap3rdBumpScale` → `matcap_3rd_bump_map` / `matcap_3rd_bump_scale`（已实现）

### 阴影（7）

- `_Shadow2ndColorTex` / `_Shadow3rdColorTex` → `shade_2nd_color_tex` / `shade_3rd_color_tex`（已实现）
- `_Shadow2ndReceive` / `_Shadow3rdReceive` → `use_shade_2nd_receive` / `use_shade_3rd_receive`（已实现近似）
- `_Shadow2ndNormalStrength` / `_Shadow3rdNormalStrength` → `shade_normal_strength`（共享）
- `_Shadow2ndColor` / `_Shadow3rdColor`、`_Shadow2ndBorder` / `_Shadow3rdBorder`、`_Shadow2ndBlur` / `_Shadow3rdBlur` 已在更早批次覆盖

### 自发光（11）

- `_Emission2ndMap` → `emission_2nd_texture`
- `_Emission2ndBlend` → `emission_2nd_blend_mode`
- `_Emission2ndBlendMask` → `emission_2nd_mask`
- `_Emission2ndMainStrength` → `emission_2nd_intensity`
- `_Emission2ndBlink` → `emission_blink_strength`
- `_Emission2ndBlendMask_ScrollRotate` / `_Emission2ndMap_ScrollRotate` → `emission_2nd_uv_scale`（仅缩放）
- `_Emission2ndMap_UVMode` → `emission_2nd_uv_mode`
- `_Emission2ndGradSpeed` / `_Emission2ndGradTex` / `_Emission2ndParallaxDepth` / `_Emission2ndUseGrad` → `emission_2nd_grad_speed` / `emission_2nd_grad_texture` / `emission_2nd_parallax_depth` / `use_emission_2nd_grad`
- `_Emission2ndFluorescence` → `emission_2nd_fluorescence`（P9 补齐，逐光源近似，见 §9）

## 二、可做未做（0）

本轮已补齐 `_Bump2ndMap_UVMode` / `_Bump2ndScaleMask`、`_Emission2ndBlendMask_ScrollRotate`、`_Main2nd/3rdDissolveNoiseMask_ScrollRotate`。

剩余两项转入接受差距：

- `_Main2nd/3rdTexDecalSubParam`：在 shader 中未参与运行时计算，属于编辑器序列帧参数。
- `_Anisotropy2MatCap2nd`：**已实现**（`anisotropy_2_matcap_2nd`）。按 `lilGetAnisotropyNormalWS` 的规则（按 anisotropy 正负取副切线/切线、正交化到视线、与法线插值）算出各向异性法线，喂给第二槽采样。

## 三、接受差距（17）

| 项 | 原因 |
|---|---|
| `_MatCap2ndVRParallaxStrength` / `_MatCap3rdVRParallaxStrength` | 依赖 Unity 单通道 VR 透视，Godot 无等价 |
| `_MatCap2ndCustomNormal` / `_MatCap3rdCustomNormal` | 自定义 MatCap 法线贴图，语义与我们的法线槽不同 |
| `_Main2nd/3rdTexIsMSDF` | MSDF 字体贴花，属于特定工作流，收益极低 |
| `_Main2nd/3rdTexIsLeftOnly` / `IsRightOnly` | 左右眼分屏，非 VR 项目无意义 |
| 其余 `ShouldCopy/ShouldFlip*` | 贴花镜像贴图复制，属于编辑器工具行为，不是运行时效果 |

## 四、不可抗力（8）

| 项 | 原因 |
|---|---|
| `_AudioLink2Main2nd` / `_AudioLink2Main3rd` / `_AudioLink2Emission2nd` / `_AudioLink2Emission2ndGrad` | AudioLink 是 Unity/Udon 音频链路，Godot 无等价全局频谱系统 |
| `_Anisotropy2*`（5 项） | 1st/2nd/3rd 已实现（含偏移噪声）；`_Anisotropy2MatCap` / `_Anisotropy2MatCap2nd` 已实现（`anisotropy_2_matcap` / `anisotropy_2_matcap_2nd`）；`_Anisotropy2Reflection` 不做（没有独立反射法线，`SPECULAR` 是标量） |
| Tessellation / Stencil 相关 | 不在本清单，但同属引擎限制 |

## 五、贴花 flags（记录，不实现）

| 项 | 处理 | 原因 |
|---|---|---|
| `_Main2ndTexIsDecal` / `_Main3rdTexIsDecal` | 不实现 | 原版用于贴花锚点/镜像，我们采用 UV 变换，语义不同 |
| `_Main2ndTexIsLeftOnly` / `IsRightOnly` | 不实现 | 左右眼分屏，非 VR 项目无意义 |
| `_Main2ndTexIsMSDF` | 不实现 | MSDF 字体贴花，特定工作流，收益极低 |
| `_Main2ndTexShouldCopy` / `ShouldFlipCopy` / `ShouldFlipMirror` | 不实现 | 编辑器复制/镜像贴图行为，不是运行时效果 |
| `_Main2ndTex_Cull` / `_Main3rdTex_Cull` | 不实现 | 逐层裁剪模式，可用材质变体替代 |
| `_Main2ndTexAlphaMode` / `_Main3rdTexAlphaMode` | 不实现 | 逐层 alpha 模式，当前统一按混合模式处理 |

以上项目均已写入本审计，避免在矩阵里反复出现“未对齐”却不解释。

## 下一步（2026-10-27 更新）

1. 原三项（各向异性 1st、每层溶解遮罩/噪声、2nd 自发光渐变/UV）均已在 2026-10-26 完成，不再是待办；
2. 该类别剩余 27 项全部是接受差距/不可抗力，没有可做项；
3. 贴花镜像/MSDF 与 VR 相关项维持接受差距。
