@tool
class_name LiltoonPreset
extends Resource
## liltoon_gd 参数预设：保存材质（含描边子材质）的全部 shader 参数，可在工程之间复用。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")

@export var shader_path: String = ""
@export var outline_enabled: bool = false
@export var parameters: Dictionary = {}
@export var outline_parameters: Dictionary = {}


static func from_material(mat: ShaderMaterial) -> LiltoonPreset:
	var preset := LiltoonPreset.new()
	if mat == null or mat.shader == null:
		return preset
	preset.shader_path = mat.shader.resource_path
	preset.parameters = _collect(mat)
	var outline := mat.next_pass as ShaderMaterial
	preset.outline_enabled = outline != null
	if outline != null:
		preset.outline_parameters = _collect(outline)
	return preset


## 应用预设：先把目标上预设未包含的参数清除（回到 shader 默认值），再写入预设值，
## 保证结果与预设完全一致，而不是把目标原有参数残留在里面。
static func apply_to_material(preset: LiltoonPreset, mat: ShaderMaterial) -> void:
	if preset == null or mat == null or mat.shader == null:
		return
	_clear_unlisted(mat, preset.parameters)
	for key in preset.parameters:
		mat.set_shader_parameter(str(key), preset.parameters[key])

	Factory.set_outline_enabled(mat, preset.outline_enabled)
	var outline := mat.next_pass as ShaderMaterial
	if outline != null and not preset.outline_parameters.is_empty():
		_clear_unlisted(outline, preset.outline_parameters)
		for key in preset.outline_parameters:
			outline.set_shader_parameter(str(key), preset.outline_parameters[key])
		outline.emit_changed()
	mat.emit_changed()


static func variant_matches(preset: LiltoonPreset, mat: ShaderMaterial) -> bool:
	if preset == null or mat == null or mat.shader == null:
		return false
	if preset.shader_path.is_empty():
		return true
	return preset.shader_path == mat.shader.resource_path


static func _collect(mat: ShaderMaterial) -> Dictionary:
	var data := {}
	if mat.shader == null:
		return data
	for info in mat.shader.get_shader_uniform_list(true):
		var uniform_name := str(info.get("name", ""))
		if uniform_name.is_empty() or _is_group(info):
			continue
		var value = mat.get_shader_parameter(uniform_name)
		if value == null:
			continue
		data[uniform_name] = value
	return data


static func _clear_unlisted(mat: ShaderMaterial, keep: Dictionary) -> void:
	if mat.shader == null:
		return
	for info in mat.shader.get_shader_uniform_list(true):
		var uniform_name := str(info.get("name", ""))
		if uniform_name.is_empty() or _is_group(info) or keep.has(uniform_name):
			continue
		if mat.get_shader_parameter(uniform_name) != null:
			mat.set_shader_parameter(uniform_name, null)


static func _is_group(info: Dictionary) -> bool:
	var usage := int(info.get("usage", 0))
	return usage == PROPERTY_USAGE_GROUP or usage == PROPERTY_USAGE_SUBGROUP
