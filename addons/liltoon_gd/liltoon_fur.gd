class_name LiltoonFur
extends RefCounted
## 毛发壳层辅助：把普通 MeshInstance3D 转成「主体 + MultiMesh 壳层」。
## Godot 的 next_pass 只支持一层，因此壳层用 MultiMesh 的实例自定义数据承载。

const FUR_SHADER_PATH := "res://addons/liltoon_gd/shaders/liltoon_fur_multi.gdshader"
const FUR_TRANSPARENT_SHADER_PATH := "res://addons/liltoon_gd/shaders/liltoon_fur_multi_transparent.gdshader"
const DEFAULT_LAYERS := 6
const MAX_LAYERS := 12


static func build_multimesh(mesh: Mesh, layers: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = maxi(layers, 1)
	for i in mm.instance_count:
		var t := float(i) / maxf(float(mm.instance_count - 1), 1.0)
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(t, 0.0, 0.0, 1.0))
	return mm


static func set_layers(shells: MultiMeshInstance3D, layers: int) -> void:
	if shells == null or shells.multimesh == null:
		return
	var mesh := shells.multimesh.mesh
	if mesh == null:
		return
	var old := shells.multimesh
	shells.multimesh = build_multimesh(mesh, layers)
	old = null


static func create_shells(source: MeshInstance3D, layers: int = DEFAULT_LAYERS, transparent: bool = false) -> MultiMeshInstance3D:
	if source == null or source.mesh == null:
		return null
	var shells := MultiMeshInstance3D.new()
	shells.name = source.name + "_Fur"
	shells.multimesh = build_multimesh(source.mesh, layers)
	shells.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load(FUR_TRANSPARENT_SHADER_PATH if transparent else FUR_SHADER_PATH)
	shells.material_override = mat
	sync_params(source, shells)
	return shells


## 把主体的基础颜色、阴影色与描边/反射开关复制到毛发材质。
static func sync_params(source: MeshInstance3D, shells: MultiMeshInstance3D) -> void:
	if source == null or shells == null:
		return
	var base_mat := source.material_override as ShaderMaterial
	var fur_mat := shells.material_override as ShaderMaterial
	if base_mat == null or fur_mat == null:
		return
	for key in ["main_color", "shade_color", "use_specular", "use_rim"]:
		var value = base_mat.get_shader_parameter(key)
		if value != null:
			fur_mat.set_shader_parameter(key, value)


## 材质参数同步到已存在的毛发壳层（找不到壳层时静默返回）。
static func sync_from_material(base_mat: ShaderMaterial, shells: MultiMeshInstance3D) -> void:
	if base_mat == null or shells == null:
		return
	var fur_mat := shells.material_override as ShaderMaterial
	if fur_mat == null:
		return
	for key in ["main_color", "shade_color", "use_specular", "use_rim"]:
		var value = base_mat.get_shader_parameter(key)
		if value != null:
			fur_mat.set_shader_parameter(key, value)

## 把主体材质上的毛发参数复制到壳材质（跳过层索引与层数）。
static func copy_fur_params(base_mat: ShaderMaterial, fur_mat: ShaderMaterial) -> void:
	if base_mat == null or fur_mat == null or base_mat.shader == null:
		return
	for item in base_mat.shader.get_shader_uniform_list():
		var key: String = item["name"]
		if not key.begins_with("fur_") or key == "fur_layer" or key == "fur_layers":
			continue
		var value = base_mat.get_shader_parameter(key)
		if value != null:
			fur_mat.set_shader_parameter(key, value)

## 切换壳层的裁切/透明模式，尽量保留现有参数。
static func set_transparent(shells: MultiMeshInstance3D, transparent: bool) -> void:
	if shells == null:
		return
	var fur_mat := shells.material_override as ShaderMaterial
	if fur_mat == null:
		return
	var values := {}
	if fur_mat.shader != null:
		for item in fur_mat.shader.get_shader_uniform_list():
			var key: String = item["name"]
			var value = fur_mat.get_shader_parameter(key)
			if value != null:
				values[key] = value
	fur_mat.shader = load(FUR_TRANSPARENT_SHADER_PATH if transparent else FUR_SHADER_PATH)
	for key in values:
		fur_mat.set_shader_parameter(key, values[key])
