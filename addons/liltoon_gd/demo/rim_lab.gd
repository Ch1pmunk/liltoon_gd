extends Node3D
## 边缘光对比：纯 Fresnel / 方向性 / 方向性 + 背光色 + 阴影遮罩。
## 直接运行时追加 `-- shot` 会把视口保存到 user://rim_lab.png 并退出。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")


func _ready() -> void:
	_build_world()
	_add_sphere(Vector3(-1.8, 0.0, 0.0), _make_material(false, false, false))
	_add_sphere(Vector3(0.0, 0.0, 0.0), _make_material(true, false, false))
	_add_sphere(Vector3(1.8, 0.0, 0.0), _make_material(true, true, true))
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.38)
	env.ambient_light_energy = 0.5
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.fov = 42.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.0, 5.6), Vector3.ZERO)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25.0, 40.0, 0.0)
	light.light_energy = 1.1
	add_child(light)

	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "边缘光：Fresnel 幂 + 边界/柔化 + 受光方向 + 背光色 + 阴影遮罩"
	title.position = Vector2(24.0, 20.0)
	layer.add_child(title)
	var note := Label.new()
	note.text = "左：纯 Fresnel      中：方向性（受光/背光）      右：方向性 + 背光色 + 阴影遮罩"
	note.position = Vector2(24.0, 556.0)
	layer.add_child(note)


func _make_material(dir_strength: bool, enable_lighting: bool, indir: bool) -> ShaderMaterial:
	var mat := Factory.create_opaque()
	mat.set_shader_parameter("main_color", Color(0.32, 0.34, 0.42))
	mat.set_shader_parameter("shade_color", Color(0.08, 0.08, 0.12))
	mat.set_shader_parameter("shade_threshold", 0.35)
	mat.set_shader_parameter("use_specular", false)
	mat.set_shader_parameter("use_rim", true)
	mat.set_shader_parameter("rim_color", Color(1.0, 0.55, 0.35, 1.0))
	mat.set_shader_parameter("rim_intensity", 1.0)
	mat.set_shader_parameter("rim_power", 4.0)
	mat.set_shader_parameter("rim_border", 0.5)
	mat.set_shader_parameter("rim_blur", 0.2)
	mat.set_shader_parameter("rim_main_strength", 0.0)
	mat.set_shader_parameter("rim_dir_strength", 1.0 if dir_strength else 0.0)
	# 这两个参数在 P9 里从 bool 改成了 Range(0,1) 的程度值，这里显式转成浮点
	mat.set_shader_parameter("rim_enable_lighting", 1.0 if enable_lighting else 0.0)
	mat.set_shader_parameter("rim_shadow_mask", 1.0 if indir else 0.0)
	if indir:
		mat.set_shader_parameter("rim_indir_color", Color(0.4, 0.6, 1.0, 1.0))
		mat.set_shader_parameter("rim_indir_strength", 1.0)
		mat.set_shader_parameter("rim_indir_border", 0.4)
		mat.set_shader_parameter("rim_indir_blur", 0.3)
	return mat


func _add_sphere(pos: Vector3, mat: ShaderMaterial) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.7
	mesh.height = 1.4
	mesh.radial_segments = 64
	mesh.rings = 32
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	add_child(instance)


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("user://rim_lab.png")
	get_tree().quit()
