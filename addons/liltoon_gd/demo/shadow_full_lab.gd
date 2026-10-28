extends Node3D
## 阴影子系统全量对比：明暗分界 / 柔化 / 边界染色 / 二层阴影 / 渐变色阶 / 平面阴影。
## 左起：基准、blur、边界染色、二层阴影、渐变色阶、平面阴影。
## 直接运行时追加 `-- shot` 保存到 user://shadow_full_lab.png 并退出。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")


func _ready() -> void:
	_build_world()
	_add_sphere(Vector3(-3.45, 0.0, 0.0), _make("base"), "基准")
	_add_sphere(Vector3(-2.07, 0.0, 0.0), _make("blur"), "柔化 0.4")
	_add_sphere(Vector3(-0.69, 0.0, 0.0), _make("border"), "边界染色")
	_add_sphere(Vector3(0.69, 0.0, 0.0), _make("2nd"), "二层阴影")
	_add_sphere(Vector3(2.07, 0.0, 0.0), _make("ramp"), "渐变色阶")
	_add_sphere(Vector3(3.45, 0.0, 0.0), _make("flat"), "平面阴影")
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.42)
	env.ambient_light_energy = 0.35
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.fov = 38.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.25, 8.6), Vector3(0.0, 0.0, 0.0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-32.0, -26.0, 0.0)
	light.light_energy = 1.5
	light.light_color = Color(1.0, 0.94, 0.86)
	add_child(light)

	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "阴影子系统：分界 / 柔化 / 边界染色 / 二层 / 色阶 / 平面"
	title.position = Vector2(20.0, 16.0)
	layer.add_child(title)


func _add_sphere(pos: Vector3, material: ShaderMaterial, label_text: String) -> void:
	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.58
	ball.height = 1.16
	ball.radial_segments = 48
	ball.rings = 24
	mesh.mesh = ball
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)

	var label := Label3D.new()
	label.text = label_text
	label.font_size = 30
	label.pixel_size = 0.0058
	label.position = pos + Vector3(0.0, -0.9, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)


func _make(kind: String) -> ShaderMaterial:
	var mat := Factory.create_opaque()
	mat.set_shader_parameter("main_color", Color(0.72, 0.73, 0.78))
	mat.set_shader_parameter("use_specular", false)
	match kind:
		"blur":
			mat.set_shader_parameter("shade_blur", 0.4)
		"border":
			mat.set_shader_parameter("shade_border_range", 0.35)
			mat.set_shader_parameter("shade_border_color", Color(1.0, 0.55, 0.25, 1.0))
		"2nd":
			mat.set_shader_parameter("use_shade_2nd", true)
			mat.set_shader_parameter("shade_2nd_threshold", 0.25)
			mat.set_shader_parameter("shade_2nd_color", Color(0.18, 0.22, 0.45, 1.0))
		"ramp":
			mat.set_shader_parameter("use_shade_ramp", true)
			mat.set_shader_parameter("shade_ramp", _make_ramp_texture())
			mat.set_shader_parameter("shade_ramp_strength", 1.0)
		"flat":
			mat.set_shader_parameter("shadow_mask_type", 1)
			mat.set_shader_parameter("shadow_flat_border", 0.15)
			mat.set_shader_parameter("shadow_flat_blur", 0.35)
	return mat


## 从冷到暖的四段色阶，用于验证 Ramp 是否被采样。
func _make_ramp_texture() -> ImageTexture:
	var w := 64
	var h := 8
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	# 冷→暖四段色阶。注意 ramp 会把硬阶跃换成连续过渡，对比度天然低于基准，
	# 曾误判为"没生效"，后用纯黑探针确认采样路径正常。
	for x in w:
		var t := float(x) / (w - 1)
		var c := Color(0.05, 0.06, 0.22).lerp(Color(0.95, 0.35, 0.25), t)
		for y in h:
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("user://shadow_full_lab.png")
	get_tree().quit()
