extends Node3D
## 毛发新增 6 项对齐参数演示：基准 / 遮罩 / 随机化 / 向量贴图 / 触摸。
## 对应 lilToon lts_fur.shader 的 _FurMask / _FurNoiseMask / _FurRandomize /
## _FurVectorTex / _VertexColor2FurVector / _FurTouchStrength。
## 直接运行时追加 `-- shot` 会把视口保存到 user://fur_features_lab.png 并退出。

const FUR_SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_fur_multi_transparent.gdshader")

var _noise_tex: ImageTexture


func _ready() -> void:
	_noise_tex = _make_noise_texture()
	_build_world()
	_build_ui()
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.32, 0.38)
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, 25.0, 0.0)
	light.light_energy = 1.1
	add_child(light)

	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.current = true
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.55, 4.6), Vector3(0.0, 0.1, 0.0))

	var configs := [
		{"label": "基准", "params": {}},
		{"label": "毛发遮罩", "params": {"fur_mask": _make_mask_texture()}},
		{"label": "随机化 1.0", "params": {"fur_randomize": 1.0}},
		{"label": "向量贴图", "params": {"use_fur_vector_texture": true, "fur_vector_texture": _make_vector_texture()}},
		{"label": "触摸推开", "params": {"fur_touch_strength": 1.0, "fur_touch_position": Vector3(0.55, 0.0, 0.0), "fur_touch_range": 1.2}},
	]
	for i in configs.size():
		var x := -2.2 + 1.1 * float(i)
		_add_fur_ball(x, configs[i]["params"])
		_add_label(configs[i]["label"], Vector3(x, 0.95, 0.0))


func _add_fur_ball(x: float, params: Dictionary) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.9
	mesh.radial_segments = 48
	mesh.rings = 24

	var base := MeshInstance3D.new()
	base.mesh = mesh
	base.position = Vector3(x, 0.0, 0.0)
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.25, 0.12, 0.07)
	base_mat.roughness = 0.9
	base.material_override = base_mat
	add_child(base)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = 6
	for i in 6:
		var t := float(i) / 5.0
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(t, 0.0, 0.0, 1.0))
	var shells := MultiMeshInstance3D.new()
	shells.multimesh = mm
	shells.position = Vector3(x, 0.0, 0.0)
	shells.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := ShaderMaterial.new()
	mat.shader = FUR_SHADER
	mat.set_shader_parameter("alpha_cutoff", 0.05)
	mat.set_shader_parameter("fur_cutout_length", 1.5)
	mat.set_shader_parameter("fur_length", 0.2)
	mat.set_shader_parameter("fur_gravity", 0.2)
	mat.set_shader_parameter("fur_ao", 0.6)
	mat.set_shader_parameter("fur_noise_strength", 0.3)
	mat.set_shader_parameter("fur_strand_density", 0.3)
	mat.set_shader_parameter("fur_strand_scale", 8.0)
	mat.set_shader_parameter("fur_noise_texture", _noise_tex)
	mat.set_shader_parameter("fur_noise_uv_scale", Vector2(8.0, 8.0))
	mat.set_shader_parameter("fur_root_color", Color(0.2, 0.1, 0.05, 1.0))
	mat.set_shader_parameter("fur_tip_color", Color(0.9, 0.75, 0.55, 1.0))
	mat.set_shader_parameter("fur_wind_strength", 0.0)
	mat.set_shader_parameter("fur_vector", Vector3(0.15, 0.85, 0.35))
	mat.set_shader_parameter("fur_direction_strength", 0.5)
	for key in params:
		mat.set_shader_parameter(key, params[key])
	shells.material_override = mat
	add_child(shells)


func _add_label(text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 36
	label.pixel_size = 0.0035
	label.modulate = Color(1.0, 0.95, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	add_child(label)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "毛发 6 项：遮罩只留右半、随机化打散、向量贴图改方向、触摸从右侧推开"
	title.position = Vector2(16.0, 14.0)
	title.add_theme_font_size_override("font_size", 14)
	layer.add_child(title)


func _make_noise_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	noise.fractal_octaves = 3
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var v := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, v))
	return ImageTexture.create_from_image(img)


func _make_mask_texture() -> ImageTexture:
	# 左半不长毛、右半正常，验证 _FurMask 的生长区域控制。
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var v := 1.0 if x < size / 2 else 0.0
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(img)


func _make_vector_texture() -> ImageTexture:
	# 恒定倾斜法线，验证 _FurVectorTex 改变生长方向。
	var dir := Vector3(0.6, 0.0, 0.8).normalized()
	var color := Color(dir.x * 0.5 + 0.5, dir.y * 0.5 + 0.5, dir.z * 0.5 + 0.5, 1.0)
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("user://fur_features_lab.png")
	get_tree().quit()
