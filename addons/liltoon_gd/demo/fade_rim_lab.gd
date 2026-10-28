extends Node3D
## 距离淡出时的边缘光染色（`_DistanceFadeRimColor` / `_DistanceFadeRimFresnelPower`）。
## 左：只做距离淡出；右：淡出同时叠加青色边缘光。
## 两球都处于 near/far 之间，确保淡出确实生效。
## 直接运行时追加 `-- shot` 会把视口保存到 user://fade_rim_lab.png 并退出。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")

const CAMERA_Z := 6.0
const FADE_NEAR := 3.5
const FADE_FAR := 9.0


func _ready() -> void:
	_build_world()
	_add_sphere(Vector3(-1.5, 0.0, 0.0), _make(false), "仅淡出")
	_add_sphere(Vector3(1.5, 0.0, 0.0), _make(true), "淡出 + 边缘光")
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.44, 0.54)
	env.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.2, CAMERA_Z), Vector3(0.0, 0.0, 0.0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	light.light_energy = 1.3
	add_child(light)

	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "距离淡出：边缘光染色"
	title.position = Vector2(24.0, 20.0)
	layer.add_child(title)
	var note := Label.new()
	note.text = "_DistanceFadeRimColor / _DistanceFadeRimFresnelPower"
	note.position = Vector2(24.0, 556.0)
	layer.add_child(note)


func _add_sphere(pos: Vector3, material: ShaderMaterial, label_text: String) -> void:
	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.85
	ball.height = 1.7
	ball.radial_segments = 48
	ball.rings = 24
	mesh.mesh = ball
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)

	var label := Label3D.new()
	label.text = label_text
	label.font_size = 34
	label.pixel_size = 0.006
	label.position = pos + Vector3(0.0, -1.2, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)


func _make(with_rim: bool) -> ShaderMaterial:
	var mat := Factory.create_opaque()
	mat.set_shader_parameter("main_color", Color(0.55, 0.58, 0.66))
	mat.set_shader_parameter("use_specular", false)
	mat.set_shader_parameter("use_distance_fade", true)
	mat.set_shader_parameter("distance_fade_near", FADE_NEAR)
	mat.set_shader_parameter("distance_fade_far", FADE_FAR)
	mat.set_shader_parameter("distance_fade_strength", 1.0)
	mat.set_shader_parameter("distance_fade_color", Color(0.02, 0.02, 0.03, 1.0))
	mat.set_shader_parameter("distance_fade_rim_fresnel_power", 2.5)
	if with_rim:
		mat.set_shader_parameter("distance_fade_rim_color", Color(0.35, 0.95, 1.0, 1.0))
	return mat


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("user://fade_rim_lab.png")
	get_tree().quit()
