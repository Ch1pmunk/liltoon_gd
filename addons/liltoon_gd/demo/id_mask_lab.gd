extends Node3D

## ID 遮罩可视化对照（三组，同一份自建网格）：
## A = StandardMaterial3D（引擎原生）→ 验证网格本身是否正常
## B = 本项目材质，不开 ID 遮罩 → 验证 shader 在自建网格上是否正常
## C = 本项目材质，开 ID 遮罩隐藏 ID=1、3 两列 → 验证「按 ID 隐藏区域」是否真的生效
##
## 2026-10-29 结论：三组渲染证明「按 ID 隐藏区域」生效；此前 mask_lab 的"拉成大条带"
## 是顶点阶段丢弃导致的，已改为 fragment() discard（见 docs/evidence/阶段9/id_mask/）。
##
## 判读：
## - A 若是 4 条竖条、B 也是 4 条 → 网格与 shader 都正常，C 出现隔列缺失即说明 ID 遮罩生效；
## - A 正常但 B 异常 → shader 在处理 UV.x>1 的自建网格上有问题；
## - A 就异常 → 网格本身有问题（顶点/索引）。

const SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_opaque.gdshader")


func _ready() -> void:
	# 排查用：`-- only=a|b|c` 只渲染一列，便于隔离是网格问题还是 shader 问题
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5)
	_build_world()
	if only == "" or only == "a":
		_build_column(0, "A 标准材质（网格对照）", _standard_material())
	if only == "" or only == "b":
		_build_column(1, "B 本项目材质（无遮罩）", _our_material(false))
	if only == "" or only == "c":
		_build_column(2, "C 本项目材质（隐藏 ID=1、3）", _our_material(true))
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.47, 0.55)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 42.0
	cam.look_at_from_position(Vector3(0.0, 0.15, 6.4), Vector3(0.0, 0.0, 0.0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28.0, 18.0, 0.0)
	add_child(light)


func _standard_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.72, 0.9, 1.0)
	mat.roughness = 0.7
	return mat


func _our_material(with_id_mask: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("main_color", Color(0.55, 0.72, 0.9, 1.0))
	if with_id_mask:
		mat.set_shader_parameter("use_id_mask", true)
		mat.set_shader_parameter("id_mask_from", 0)        # 0 = 主 UV.x
		mat.set_shader_parameter("id_mask_is_bitmap", false)
		mat.set_shader_parameter("id_mask_1", true)
		mat.set_shader_parameter("id_mask_index_1", 1)
		mat.set_shader_parameter("id_mask_2", true)
		mat.set_shader_parameter("id_mask_index_2", 3)
	return mat


func _build_column(index: int, label_text: String, material: Material) -> void:
	var inst := MeshInstance3D.new()
	inst.name = "Column%d" % index
	inst.mesh = _make_id_strip_mesh(4)
	inst.material_override = material
	inst.position = Vector3(-2.0 + float(index) * 2.0, 0.35, 0.0)
	add_child(inst)

	var label := Label3D.new()
	label.text = label_text
	label.font_size = 30
	label.pixel_size = 0.0032
	label.modulate = Color(1.0, 0.97, 0.92)
	label.position = Vector3(-2.0 + float(index) * 2.0, -0.62, 0.0)
	label.no_depth_test = true
	add_child(label)


## 4 条竖条，每条 UV.x 写绝对列号（0..1 / 1..2 / 2..3 / 3..4），供 ID 遮罩按 int(UV.x) 定位。
func _make_id_strip_mesh(columns: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var half_width := 0.42
	var half_height := 0.5
	var step := (half_width * 2.0) / float(columns)
	for i in columns:
		var x0 := -half_width + step * float(i)
		var x1 := x0 + step
		var base := verts.size()
		verts.append_array([
			Vector3(x0, -half_height, 0.0), Vector3(x1, -half_height, 0.0),
			Vector3(x1, half_height, 0.0), Vector3(x0, half_height, 0.0),
		])
		for _v in 4:
			normals.append(Vector3(0.0, 0.0, 1.0))
			tangents.append_array([1.0, 0.0, 0.0, 1.0])
		uvs.append_array([
			Vector2(float(i), 0.0), Vector2(float(i + 1), 0.0),
			Vector2(float(i + 1), 1.0), Vector2(float(i), 1.0),
		])
		# Godot 前面按顺时针绕序判定（viewed from +Z）；原先是逆时针，会被背面剔除而"看不见网格"。
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _take_shot() -> void:
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("user://id_mask_lab.png")
		print("id_mask_lab: 截图已保存 id_mask_lab.png")
	get_tree().quit()
