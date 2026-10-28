@tool
class_name LiltoonTools
extends RefCounted
## P4 编辑器工具链：材质转换、批量替换、参数校验/修复。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")

const SHADER_DIR := "res://addons/liltoon_gd/shaders/"
const OUTLINE_SHADER_PATH := "res://addons/liltoon_gd/shaders/liltoon_outline.gdshader"


static func is_liltoon_material(value) -> bool:
	var mat := value as ShaderMaterial
	return mat != null and mat.shader != null and mat.shader.resource_path.begins_with(SHADER_DIR)


## StandardMaterial3D -> liltoon_gd，按透明度/双面自动选择变体。
static func convert_standard_material(src: BaseMaterial3D) -> ShaderMaterial:
	return convert_standard_material_ex(src).get("material", ShaderMaterial.new())


## 转换并返回未完全等价的项，供 UI 提示，避免静默丢弃。
static func convert_standard_material_ex(src: BaseMaterial3D) -> Dictionary:
	var warnings := PackedStringArray()
	var mat := ShaderMaterial.new()
	if src == null:
		return {"material": mat, "warnings": warnings}
	mat.shader = _pick_shader(src)
	mat.resource_name = "%s_liltoon" % src.resource_name if src.resource_name != "" else "liltoon_material"

	mat.set_shader_parameter("main_color", src.albedo_color)
	if src.albedo_texture != null:
		mat.set_shader_parameter("use_main_texture", true)
		mat.set_shader_parameter("main_texture", src.albedo_texture)
	mat.set_shader_parameter("main_uv_scale", Vector2(src.uv1_scale.x, src.uv1_scale.y))
	mat.set_shader_parameter("use_vertex_color", src.vertex_color_use_as_albedo)

	if src.normal_enabled and src.normal_texture != null:
		mat.set_shader_parameter("use_normal_map", true)
		mat.set_shader_parameter("normal_texture", src.normal_texture)
		mat.set_shader_parameter("normal_strength", src.normal_scale)

	if src.emission_enabled:
		mat.set_shader_parameter("emission_color", src.emission)
		mat.set_shader_parameter("emission_intensity", src.emission_energy_multiplier)
		if src.emission_texture != null:
			mat.set_shader_parameter("use_emission_texture", true)
			mat.set_shader_parameter("emission_texture", src.emission_texture)

	if src.metallic > 0.001 or src.roughness < 0.999:
		mat.set_shader_parameter("use_reflection", true)
		mat.set_shader_parameter("metallic", src.metallic)
		mat.set_shader_parameter("roughness", src.roughness)

	if src.ao_enabled and src.ao_texture != null:
		mat.set_shader_parameter("use_ao_map", true)
		mat.set_shader_parameter("ao_texture", src.ao_texture)
		mat.set_shader_parameter("ao_light_affect", clampf(src.ao_light_affect, 0.0, 1.0))

	if src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		mat.set_shader_parameter("alpha_cutoff", clampf(src.alpha_scissor_threshold, 0.0, 1.0))

	if src.rim_enabled and src.rim > 0.0:
		mat.set_shader_parameter("use_rim", true)
		mat.set_shader_parameter("rim_intensity", clampf(src.rim * 2.0, 0.0, 4.0))

	if src.backlight_enabled:
		# BaseMaterial3D.backlight 是颜色而非强度，强度沿用默认值。
		mat.set_shader_parameter("use_sss", true)
		mat.set_shader_parameter("sss_color", src.backlight)
		mat.set_shader_parameter("sss_strength", 0.6)

	# 屏幕空间 SSS 用透射近似：语义不同，但比直接丢弃更接近。
	if src.subsurf_scatter_enabled:
		mat.set_shader_parameter("use_sss", true)
		mat.set_shader_parameter("sss_strength", clampf(src.subsurf_scatter_strength * 2.0, 0.0, 2.0))
		warnings.append("屏幕空间 SSS 已近似为透射 SSS")
	if src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH:
		warnings.append("Alpha Hash 已近似为普通透明（排序行为不同）")
	if src.alpha_antialiasing_mode != BaseMaterial3D.ALPHA_ANTIALIASING_OFF \
			and src.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		warnings.append("Alpha 抗锯齿（A2C）仅 Cutout 支持，已按普通透明处理")
	if src.detail_enabled:
		warnings.append("Detail 层未转换")
	if src.clearcoat_enabled:
		warnings.append("Clearcoat 未转换")
	if src.anisotropy_enabled:
		warnings.append("Anisotropy 未转换")
	if src.refraction_enabled:
		warnings.append("Refraction 未转换")

	return {"material": mat, "warnings": warnings}


static func _pick_shader(src: BaseMaterial3D) -> Shader:
	var shader := _pick_shader_base(src)
	# Godot 的 Alpha 抗锯齿在 Cutout 上等价于 liltoon 的 _AlphaToMask。
	if src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR \
			and src.alpha_antialiasing_mode != BaseMaterial3D.ALPHA_ANTIALIASING_OFF:
		var a2c := Factory.with_alpha_to_mask(shader, true)
		if a2c != null:
			shader = a2c
	return shader


static func _pick_shader_base(src: BaseMaterial3D) -> Shader:
	if src.cull_mode == BaseMaterial3D.CULL_FRONT:
		match src.transparency:
			BaseMaterial3D.TRANSPARENCY_DISABLED:
				return Factory.front_shader(0)
			BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				return Factory.front_shader(1)
			_:
				return Factory.front_shader(2)
	var double_sided := src.cull_mode == BaseMaterial3D.CULL_DISABLED
	match src.transparency:
		BaseMaterial3D.TRANSPARENCY_DISABLED:
			return Factory.OPAQUE_DOUBLE_SHADER if double_sided else Factory.OPAQUE_SHADER
		BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			return Factory.CUTOUT_DOUBLE_SHADER if double_sided else Factory.CUTOUT_SHADER
		_:
			return Factory.TRANSPARENT_DOUBLE_SHADER if double_sided else Factory.TRANSPARENT_SHADER


## 返回问题描述列表；不修改材质。
static func validate_material(mat: ShaderMaterial) -> PackedStringArray:
	var issues := PackedStringArray()
	if mat == null:
		issues.append("材质为空")
		return issues
	if mat.shader == null:
		issues.append("未绑定 shader")
		return issues
	if not mat.shader.resource_path.begins_with(SHADER_DIR):
		issues.append("shader 不属于 liltoon_gd：%s" % mat.shader.resource_path)
		return issues

	var outline = mat.next_pass
	if outline != null:
		if not (outline is ShaderMaterial):
			issues.append("next_pass 不是 ShaderMaterial（%s）" % outline.get_class())
		else:
			var outline_mat := outline as ShaderMaterial
			if outline_mat.shader == null or outline_mat.shader.resource_path != OUTLINE_SHADER_PATH:
				issues.append("next_pass 未使用描边 shader")

	for info in mat.shader.get_shader_uniform_list(true):
		var uniform_name := str(info.get("name", ""))
		if is_group(info):
			continue
		var value = mat.get_shader_parameter(uniform_name)
		if value == null:
			continue
		var hint := int(info.get("hint", 0))
		var hint_string := str(info.get("hint_string", ""))
		if hint == PROPERTY_HINT_RANGE:
			var bounds := _parse_range(hint_string)
			if bounds.size() >= 2:
				var current := float(value)
				if is_nan(current) or current < bounds[0] or current > bounds[1]:
					issues.append("参数 %s 超出范围 [%s, %s]：%s" % [uniform_name, bounds[0], bounds[1], current])
		elif hint == PROPERTY_HINT_ENUM:
			var count := max(hint_string.split(",").size(), 1)
			var current_enum := int(value)
			if current_enum < 0 or current_enum >= count:
				issues.append("枚举参数 %s 非法：%d" % [uniform_name, current_enum])

	return issues


## 自动修复：越界参数夹取、非法枚举归零、错误 next_pass 重建。返回修复描述列表。
static func repair_material(mat: ShaderMaterial) -> PackedStringArray:
	var fixed := PackedStringArray()
	if mat == null or mat.shader == null:
		return fixed

	var outline = mat.next_pass
	if outline != null and not (outline is ShaderMaterial):
		mat.next_pass = Factory.create_outline_material()
		fixed.append("已重建 next_pass 描边材质")

	for info in mat.shader.get_shader_uniform_list(true):
		var uniform_name := str(info.get("name", ""))
		if is_group(info):
			continue
		var value = mat.get_shader_parameter(uniform_name)
		if value == null:
			continue
		var hint := int(info.get("hint", 0))
		var hint_string := str(info.get("hint_string", ""))
		if hint == PROPERTY_HINT_RANGE:
			var bounds := _parse_range(hint_string)
			if bounds.size() >= 2:
				var current := float(value)
				var clamped := clampf(0.0 if is_nan(current) else current, bounds[0], bounds[1])
				if not is_equal_approx(clamped, current):
					mat.set_shader_parameter(uniform_name, clamped)
					fixed.append("%s：%s → %s" % [uniform_name, current, clamped])
		elif hint == PROPERTY_HINT_ENUM:
			var count := max(hint_string.split(",").size(), 1)
			var current_enum := int(value)
			if current_enum < 0 or current_enum >= count:
				mat.set_shader_parameter(uniform_name, 0)
				fixed.append("%s：%d → 0" % [uniform_name, current_enum])

	if not fixed.is_empty():
		mat.emit_changed()
	return fixed


static func is_group(info: Dictionary) -> bool:
	var usage := int(info.get("usage", 0))
	return usage == PROPERTY_USAGE_GROUP or usage == PROPERTY_USAGE_SUBGROUP


static func _parse_range(hint_string: String) -> Array[float]:
	var bounds: Array[float] = []
	for part in hint_string.split(","):
		bounds.append(part.to_float())
	return bounds
