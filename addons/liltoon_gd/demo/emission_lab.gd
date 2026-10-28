extends Node3D
## 第二层自发光荧光对比：左侧普通自发光，右侧荧光（受光越强越被压暗）。
## 用点光源制造距离衰减，衰减中段能看到荧光项（对应 liltoon 的 (1 - 光色) × sqrt(光色)）。
## 直接运行时追加 `-- shot` 会把视口保存到 user://emission_lab.png 并退出。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")


func _ready() -> void:
	_build_world()
	_add_sphere(Vector3(-0.85, 0.0, 0.0), _make_material(0.0))
	_add_sphere(Vector3(0.85, 0.0, 0.0), _make_material(1.0))
	_build_labels()
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.05, 0.07)
	env.ambient_light_energy = 1.0
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.fov = 42.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.0, 3.6), Vector3(0.0, 0.0, 0.0))

	# 点光源：衰减中段对应 liltoon 荧光最亮的区间。
	var light := OmniLight3D.new()
	light.position = Vector3(-1.6, 1.4, 1.8)
	light.light_energy = 8.0
	light.omni_range = 6.0
	light.omni_attenuation = 1.5
	add_child(light)


func _build_labels() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "第二层自发光荧光：受光越强，自发光越弱；全黑与全亮都压到 0"
	title.position = Vector2(24.0, 20.0)
	layer.add_child(title)
	var note := Label.new()
	note.text = "左：emission_2nd_fluorescence = 0      右：emission_2nd_fluorescence = 1"
	note.position = Vector2(24.0, 556.0)
	layer.add_child(note)


func _make_material(fluorescence: float) -> ShaderMaterial:
	var mat := Factory.create_opaque()
	mat.set_shader_parameter("main_color", Color(0.09, 0.1, 0.14))
	mat.set_shader_parameter("shade_color", Color(0.03, 0.03, 0.05))
	mat.set_shader_parameter("shade_threshold", 0.45)
	mat.set_shader_parameter("use_specular", false)
	mat.set_shader_parameter("use_emission_2nd", true)
	mat.set_shader_parameter("emission_2nd_color", Color(0.2, 0.85, 1.0))
	mat.set_shader_parameter("emission_2nd_intensity", 1.6)
	mat.set_shader_parameter("emission_2nd_fluorescence", fluorescence)
	return mat


func _add_sphere(pos: Vector3, mat: ShaderMaterial) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.72
	mesh.height = 1.44
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
		image.save_png("user://emission_lab.png")
	get_tree().quit()
