# 工程速查（原交接文档）

> **本文档不再承担"新会话从这里继续"的职责**，交接与恢复统一看 [`协作约定与上下文恢复.md`](协作约定与上下文恢复.md)。
> 这里只保留那些写代码时真正会踩到的工程细节。进度看 `ROADMAP.md`，差异看 `DEVELOPMENT_PRINCIPLES.md` §9。

## 项目

- 路径：`c:\Users\Ch1pmunk_Z\Desktop\NewProject`
- 插件：`addons/liltoon_gd`
- 参考：`C:\Users\Ch1pmunk_Z\Desktop\lilToon-release`（lilToon 2.4.1）
- 编辑器：Godot 4.7.2 mono，MCP 工具 `gdmcp.exe` 在 `.gdmcp/bin`
- 冒烟：`Godot_v4.7.2-stable_mono_win64_console.exe --headless --path . -s res://tools/smoke_test.gd`

## 规则（必须遵守）

1. 每个 uniform 正上方必须有 `/** 中文描述 */`，写作用/范围/默认值；冒烟会查覆盖率。
2. 新 uniform 必须同步 `editor/preset_library.gd` 的 `BASE`（sampler 除外）。
3. 改完必须跑冒烟；失败先修，修不好写 BLOCKED。
4. 只改项目内文件，不做破坏性操作。
5. 能做的就做；只有不可抗力/Unity 专属才放弃；近似实现要写进 §9。
6. 大文件批量编辑前先备份，避免再次截断 `liltoon_material_factory.gd`。
7. **渲染类 run 一律最小负载**（单 shader、关 MSAA 与阴影）。2026-10-27 两次 `0x139` 蓝屏都与全量 shader 加载有关，详见 `ROADMAP.md` 的 RISKS。

## 当前规模

- 主材质 **436** 个 uniform，描边 **32** 个（`addons/liltoon_gd/shaders/include/outline_common.gdshaderinc`）。
- 主材质变体 13 个（10 个基础 + 3 个 Alpha To Coverage），另有毛发 4 个、描边 6 个。
- 冒烟通过（含 5 项缩略图加载校验）。

## 常用命令

```powershell
# 冒烟
& 'C:\Users\Ch1pmunk_Z\Desktop\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s res://tools/smoke_test.gd

# 参数数量
(Select-String -Path 'addons/liltoon_gd/shaders/include/uniforms.gdshaderinc' -Pattern '^\s*uniform\s').Count

# 编译自检（一次一个 shader，必须指定；加 --list 可列出全部）
& '...Godot...console.exe' --path . res://tools/compile_check.tscn --quit-after 12 --resolution 640x360 -- --shader=liltoon_opaque.gdshader

# 截图（`--` 之后才是用户参数）
& '...Godot...console.exe' --path . res://addons/liltoon_gd/demo/a2c_lab.tscn -- shot

# 三档基准
& '...Godot...console.exe' --path . res://addons/liltoon_gd/demo/quality_lab.tscn -- bench

# 重新烘焙预设缩略图（先输出到 user://，再复制到 res:// 并 --import）
& '...Godot...console.exe' --path . res://tools/bake_preset_thumbnails.tscn
& '...Godot...console.exe' --headless --path . --import

# 对话索引体检 / 备份 / 重建
python tools/rebuild_chat_index.py
```

## 编辑注意

- `uniforms.gdshaderinc` 是主参数文件；`lighting.gdshaderinc` 是光照；`fragment.gdshaderinc` 是片元；`surface.gdshaderinc` 放共用函数；`outline_common.gdshaderinc` 是 6 个描边 shader 的共用部分。
- `liltoon_material_factory.gd` 常量名是 `CUTOUT_SHADER`，没有 `CUTOUT_SHADER_PATH`；A2C 变体用 `set_alpha_to_mask()` / `alpha_to_mask_of()`。
- 新增 shader 后，编辑器需重新扫描资源，脚本里用 `load()` 而不是 `preload()` 避免缓存失败。
- **`light()` 里没有 `UV2` / `VIEW` 内建变量**：需要时用 varying（`lil_uv2` / `lil_view`，由 `vertex.gdshaderinc` 写入）。
- **`light()` 里可用的原始法线是 `lil_geo_normal`**（视空间），需要"法线贴图影响程度"这类插值时按 `mix(lil_geo_normal, NORMAL, strength)` 写。
- **A2C 变体禁止写 `ALPHA_SCISSOR_THRESHOLD`**（写了覆盖率恒为 1，A2C 失效），改手动 `discard`；也不要声明 `depth_prepass_alpha`，否则裁切区域会写深度。
- `fwidth` 只能出现在片元/`light()` 调用链里（`lil_aa_edge`），不要在 `vertex()` 里调用 shade 函数。
- 预设缩略图是静态 PNG，重新烘焙后必须 `--import`，否则 `load()` 找不到资源、冒烟的缩略图校验会失败。
