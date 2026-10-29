class_name LiltoonAssetTools
extends RefCounted
## 对齐 lilToon 的三个 Assets/GameObject 菜单功能（原版 `lilToonEditorUtils.cs`）：
##
## - **Remove unused properties**（`:78`）：删掉材质里已不在 shader 声明中的残留参数
##   （原版 `lilMaterialUtils.RemoveUnusedTexture`；Godot 侧残留来自换 shader 后遗留的键）。
## - **Convert LUT to PNG**（`:149` → `lilTextureUtils.ConvertLUTToPNG`）：解析 `.cube`
##   的 `LUT_3D_SIZE` 与 `DATA` 行，按 `ltspass_baker.shader:279-292` 的 `_LUT3D_TO_2D`
##   规则展开成一张横向排布的图集（原版固定 16 格，这里按 LUT 实际尺寸泛化）。
## - **Generate bug report**（`:550`）：把版本/环境/材质参数导出成文本，便于报 issue。
## - **Fix lighting**（`:408`）：把 liltoon 材质的光照参数与渲染器开关复位到默认值。
##
## 与原版的差异：
## - 原版 `_AsUnlit` / `_VertexLightStrength` / `_BeforeExposureLimit` / `_lilDirectionalLightStrength`
##   在 Godot Forward+ 下没有对应机制（顶点光不存在），本项目只处理有对应物的四项：
##   `use_unlit` / `light_min_limit` / `light_max_limit` / `monochrome_lighting`。
## - 渲染器侧原版设 `lightProbeUsage` / `reflectionProbeUsage` / `probeAnchor`；
##   Godot 对应 `gi_mode` 与 `cast_shadow`，probe anchor 无等价物。


## 收集 shader 声明的 uniform 名（用于判断材质里哪些参数是残留）
static func shader_uniform_names(mat: ShaderMaterial) -> Dictionary:
	var names := {}
	if mat == null or mat.shader == null:
		return names
	for item in mat.shader.get_shader_uniform_list(false):
		names[String(item.get("name", ""))] = true
	return names


## 从材质序列化文本里剔除未在 shader 中声明的 `shader_parameter/<名称>` 行。
## 返回 {"text": 新文本, "removed": [参数名...]}。
static func filter_unused_properties(text: String, valid: Dictionary) -> Dictionary:
	var kept := PackedStringArray()
	var removed := PackedStringArray()
	for line in text.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("shader_parameter/") and stripped.contains("="):
			var key := stripped.substr("shader_parameter/".length())
			key = key.substr(0, key.find("=")).strip_edges()
			if key != "" and not valid.has(key):
				removed.append(key)
				continue
		kept.append(line)
	return {"text": "\n".join(kept), "removed": removed}


## 解析 `.cube` 文本。返回 {"ok": bool, "size": int, "colors": PackedColorArray, "error": String}。
## `.cube` 的 DATA 顺序是 R 变化最快，索引 = r + g*N + b*N*N。
static func parse_cube(text: String) -> Dictionary:
	var size := 0
	var colors := PackedColorArray()
	var error := ""
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("TITLE") or line.begins_with("DOMAIN_MIN") or line.begins_with("DOMAIN_MAX"):
			continue
		if line.begins_with("LUT_3D_SIZE"):
			var rest := line.substr("LUT_3D_SIZE".length()).strip_edges()
			if not rest.is_valid_int():
				return {"ok": false, "size": 0, "colors": colors, "error": "LUT_3D_SIZE 无法解析"}
			size = int(rest)
			continue
		if line.begins_with("LUT_1D_SIZE"):
			return {"ok": false, "size": 0, "colors": colors, "error": "仅支持 3D LUT（LUT_3D_SIZE），1D LUT 不适用"}
		var parts := line.split(" ", false)
		if parts.size() != 3:
			continue
		if not (parts[0].is_valid_float() and parts[1].is_valid_float() and parts[2].is_valid_float()):
			error = "存在无法解析的数值行"
			continue
		colors.append(Color(float(parts[0]), float(parts[1]), float(parts[2]), 1.0))
	if size < 2:
		return {"ok": false, "size": size, "colors": colors, "error": "缺少 LUT_3D_SIZE 或尺寸小于 2"}
	if colors.size() != size * size * size:
		return {"ok": false, "size": size, "colors": colors,
			"error": "数据行数 %d 与 %d³ = %d 不符" % [colors.size(), size, size * size * size]}
	if error != "":
		return {"ok": false, "size": size, "colors": colors, "error": error}
	return {"ok": true, "size": size, "colors": colors, "error": ""}


## 把解析后的 LUT 展开成图集：尺寸 (N*N) × N，第 i 片（宽 N）对应 B 通道 = i/(N-1)。
## 像素取值按原版 shader 的映射后再做三线性采样。
static func lut_to_atlas(lut: Dictionary) -> Image:
	if not lut.get("ok", false):
		return null
	var n: int = lut["size"]
	var colors: PackedColorArray = lut["colors"]
	var image := Image.create(n * n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n * n:
			var r := float(x % n) / float(n - 1)
			var g := 1.0 - float(y) / float(n - 1)
			var b := float(x / n) / float(n - 1)
			# 原版对坐标做"半个体素"修正后再采样（ltspass_baker.shader:290）
			var corrected := Vector3(r, g, b)
			corrected = corrected - corrected / float(n) + Vector3.ONE * (0.5 / float(n))
			image.set_pixel(x, y, _sample_trilinear(colors, n, corrected))
	return image


## `.cube` 三线性采样，坐标会被夹到 [0,1]。
static func _sample_trilinear(colors: PackedColorArray, n: int, coord: Vector3) -> Color:
	var r := clampf(coord.x, 0.0, 1.0) * float(n - 1)
	var g := clampf(coord.y, 0.0, 1.0) * float(n - 1)
	var b := clampf(coord.z, 0.0, 1.0) * float(n - 1)
	var r0 := int(floor(r))
	var g0 := int(floor(g))
	var b0 := int(floor(b))
	var r1 := mini(r0 + 1, n - 1)
	var g1 := mini(g0 + 1, n - 1)
	var b1 := mini(b0 + 1, n - 1)
	var fr := r - float(r0)
	var fg := g - float(g0)
	var fb := b - float(b0)
	var c000 := _at(colors, n, r0, g0, b0)
	var c100 := _at(colors, n, r1, g0, b0)
	var c010 := _at(colors, n, r0, g1, b0)
	var c110 := _at(colors, n, r1, g1, b0)
	var c001 := _at(colors, n, r0, g0, b1)
	var c101 := _at(colors, n, r1, g0, b1)
	var c011 := _at(colors, n, r0, g1, b1)
	var c111 := _at(colors, n, r1, g1, b1)
	var c00 := c000.lerp(c100, fr)
	var c10 := c010.lerp(c110, fr)
	var c01 := c001.lerp(c101, fr)
	var c11 := c011.lerp(c111, fr)
	return c00.lerp(c10, fg).lerp(c01.lerp(c11, fg), fb)


static func _at(colors: PackedColorArray, n: int, r: int, g: int, b: int) -> Color:
	var index := r + g * n + b * n * n
	if index < 0 or index >= colors.size():
		return Color(0, 0, 0, 1)
	return colors[index]


## 生成 bug 报告文本。materials 里非 ShaderMaterial 的项会被跳过。
static func build_bug_report(materials: Array, plugin_version: String) -> String:
	var lines := PackedStringArray()
	lines.append("# liltoon_gd bug report")
	lines.append("")
	lines.append("## 环境")
	lines.append("- 插件版本：%s" % plugin_version)
	lines.append("- Godot：%s" % Engine.get_version_info().get("string", "unknown"))
	lines.append("- 平台：%s / %s" % [OS.get_name(), OS.get_version()])
	lines.append("- 渲染方式：%s" % str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")))
	lines.append("- 项目：%s" % ProjectSettings.globalize_path("res://"))
	lines.append("")
	lines.append("## 材质（%d）" % materials.size())
	var index := 0
	for item in materials:
		var mat := item as ShaderMaterial
		if mat == null:
			continue
		index += 1
		lines.append("")
		lines.append("### %d. %s" % [index, mat.resource_path if mat.resource_path != "" else "(未保存)"])
		lines.append("- shader：%s" % (mat.shader.resource_path if mat.shader != null else "(无)"))
		var params := _set_parameters(mat)
		lines.append("- 参数（%d 项）：" % params.size())
		for key in params:
			lines.append("  - %s = %s" % [key, str(params[key])])
	if index == 0:
		lines.append("（没有可用材质，请先在资源面板选中材质后重试）")
	lines.append("")
	lines.append("## 备注")
	lines.append("把本文件连同复现场景一起提交。")
	return "\n".join(lines)


## 只返回真正赋过值的参数（Godot 对未赋值参数返回 null）。
static func _set_parameters(mat: ShaderMaterial) -> Dictionary:
	var result := {}
	if mat.shader == null:
		return result
	var names := []
	for item in mat.shader.get_shader_uniform_list(false):
		names.append(String(item.get("name", "")))
	names.sort()
	for key in names:
		var value = mat.get_shader_parameter(key)
		if value != null:
			result[key] = value
	return result


## "修复光照"要写入的材质参数（对齐原版置为默认值的行为）。
## 返回 name -> value，只包含本项目有对应物的项。
static func lighting_fix_values(defaults: Dictionary) -> Dictionary:
	var values := {}
	for key in ["use_unlit", "light_min_limit", "light_max_limit", "monochrome_lighting"]:
		if defaults.has(key):
			values[key] = defaults[key]
	return values
