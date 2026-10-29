# Changelog

本文件记录面向使用者的变更。格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。
对齐进度（参数级）以仓库内 `addons/liltoon_gd/DEVELOPMENT_PRINCIPLES.md` §9 与开发仓库的
参数对齐矩阵为准。

## [未发布]

### 新增

- **Rim / 反射混合模式**：新增 `rim_blend_mode`、`reflection_blend_mode`（默认 `1`=相加，
  与旧行为完全一致）。四式对齐 lilToon 的 `lilBlendColor`：`0` Normal、`1` Add、`2` Screen、
  `3` Multiply。**限制**：引擎环境反射（未启用自定义立方体贴图时）由引擎在着色器之后合成，
  只能是相加；要用其它三式请启用 `use_reflection_cubemap`。
- **纹理工具**（工具菜单）：法线图 DirectX ↔ OpenGL 互转、像素画降采样（1/2、1/4）、
  由选中材质生成 Ramp 贴图（128×16）。
- **材质工具**（工具菜单）：移除材质中未使用的参数、转换 `.cube` LUT 为 PNG 图集、
  生成 bug 报告、修复选中节点的光照设置（可撤销）。
- **模型与批量**（工具菜单）：按默认预设装配选中模型的材质（按材质名自动选皮肤/头发/
  金属/布料预设并开启描边）、批量编辑多个材质的同一参数（可撤销）。
- **GIF → 图集**：自建 GIF 解析与 LZW 解码，逐帧合成后按 `ceil(√帧数)` 列排布，
  可选补到 2 的幂；支持 disposal 0–3 与交错帧。

### 修复

- **ID 遮罩 / UDIM 丢弃会把几何拉成长条**：原先在顶点阶段把"命中要丢弃"的顶点挪到
  裁剪空间外，与相邻未丢弃顶点组成跨边界三角形，渲染成长条（ID 遮罩因此几乎不可用）。
  现改为在片元阶段 `discard`；新增 `id_mask_lab` 演示场景，用「标准材质 / 本项目无遮罩 /
  本项目隐藏指定 ID」三组对照证明遮罩按编号生效。
- **冒烟脚本会吞掉失败**：`tools/smoke.ps1` 此前只打印子进程退出码而从不 `exit`，
  且"通过 + 脚本错误"同时出现时会被判成功。现改为取退出码、取不到按日志判定，
  并先判失败再判通过；另加 `-Script` 参数便于注入失败探针。（`tools/` 不随仓库分发。）

### 已知限制（新增记录）

- 自发光不参与 Godot 的烘焙光照：LightmapGI 不做发光面反弹（对照 `StandardMaterial3D`
  同样无反弹）。需要自发光照亮环境时请用 VoxelGI / SDFGI，或手动补一盏 Static 灯。

## [1.0.1] — 2026-10-29

### 新增

- **AudioLink**：自建频谱服务（`audio/liltoon_audio_link.gd`），把音频总线的 4 个频段写成
  随时间滚动的全局纹理，材质可跟随音乐律动。覆盖 lilToon 的 22 项 AudioLink 参数：
  UV 模式 0–5、遮罩（RG / 阈值）、本地频谱贴图，以及自发光 / 二层自发光 / 两者渐变相位 /
  二三层贴花 / 顶点位移共 6 条路由。无音频播放时走合成脉冲回退，不会静默失效。
- **UDIM 平铺丢弃**（19 项）：分支式 4×4 网格判定，顶点模式写裁剪空间外、片元模式 `discard`。
- **ID 遮罩**（28 项）：以 UV 取 ID 与 8 个索引槽比对。**限制**：原版默认用 `SV_VertexID`，
  Godot shader 无顶点 ID，故仅 UV 源可用。
- **三通道特性遮罩** `_TriMask`（R 遮 MatCap / G 遮边缘光 / B 遮自发光）。
  **注意**：原版主通道恒为 1、仅 lite pass 采样，因此原版在主材质上勾选无效果；
  本项目接入了主通道并加 `use_tri_mask` 开关（默认关闭）。
- **贴花导入约定**（16 项）：左右半裁切、镜像/复制 UV、MSDF 解码，由纹理烘焙器消费
  （与原版一致——原版 shader 亦不读取这组）。
- **纹理打包** `TextureBaker.pack_textures()`：把最多 4 张贴图按通道合成一张。
- **纹理烘焙器 / 优化器 / 全局设置 / 启动检查 / 中英文案** 五个 Editor 模块，已接入工具菜单。
- **假阴影 / 折射 / 宝石** 三个独立变体（`shaders/extra/`）。
- **毛发 6 项**：遮罩、噪声遮罩、随机化、毛向量贴图、顶点色毛向量、触摸推开。
- **高光 toon 化、描边受光、阴影遮罩顺序、阴影色 LUT、视差零点、MatCap 滚转抵消、
  闪点形状图集、自定义反射立方体贴图**。

### 修复

- **主材质全部不可见**：UDIM / ID 遮罩的几何丢弃曾在 `if` 分支内给 `POSITION` 赋值。
  Godot 在编译期即认定 shader 使用自定义裁剪空间坐标，分支不成立时 `POSITION` 未定义，
  导致所有主材质网格消失，且编译、冒烟、日志均无异常。现改为无条件赋值。
- 后处理描边在某些场景不出现：opaque 变体写 `ALPHA` 被 Godot 判为透明、主通道不写深度，
  三个 opaque 变体补 `depth_prepass_alpha`。
- 毛发方向链的 5 处无保护 `normalize`：顶点色/贴图/重力/随机/触摸多层合成可能归零，
  产生 NaN 顶点使几何炸裂。改用安全归一化并逐层回退。
- 宝石闪烁频率 `gem_particle_loop` 与第二/三槽 MatCap 滚转抵消原先缺失或硬编码。
- 纹理烘焙器 `size=0` 会除零；空材质/无 shader 材质会空引用。
- `audiolink_2_emission_grad` / `audiolink_2_emission_2nd_grad` 曾只声明未接线
  （面板可调但无效果），已接入渐变相位。

### 已知限制

- **Compatibility（OpenGL）渲染器不可用**：主材质采样器数量超出纹理单元上限，编译失败。
  请使用 Forward+。
- **Alpha To Coverage** 需要视口 MSAA ≥ 2× 才有边缘平滑效果。
- 剩余 144 项 lilToon 参数无法表达，全部属于 Godot 引擎机制差异：Unity 渲染状态
  （Blend / Stencil / ZTest / Offset / ColorMask / Cull）、曲面细分、VR 视差、
  VRChat Light Volumes、Unity 各 pass 专属，以及 Godot `SPECULAR` 为标量导致的
  反射染色 / 反射法线方向。
- 音频律动需要一次性配置：工具菜单「启用 AudioLink 全局参数」+ 自动加载
  `audio/liltoon_audio_link.gd`。

## [1.0.0] — 2026-10-28

首个公开版本。

- 28 个 shader 变体：opaque / cutout / transparent（含双面、仅背面、预乘、Alpha To Coverage）、
  4 个毛发变体、6 种描边组合、2 个后处理描边，以及折射 / 宝石 / 假阴影。
- 主色、阴影（三层 + 边界染色 + 平面阴影）、法线、高光、各向异性、Rim、MatCap、Glitter、
  自发光、反射、逆光、距离淡出、溶解、三层贴花、描边、毛发、视差等。
- 材质转换器、批量替换、预设导入导出、校验修复。
- 5 个预设与离线渲染的真实缩略图。
- 演示场景若干，每个功能一个 lab。
