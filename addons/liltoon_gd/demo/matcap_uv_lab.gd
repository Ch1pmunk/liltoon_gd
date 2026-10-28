extends Node3D
## MatCap 的 UV1 混合（_MatCapBlendUV1）与自定义法线（_MatCapCustomNormal）对比。
## 左起：球面采样基准、blend=0.5、blend=1（完全按 UV1）、自定义法线（贴图当完整法线）。
## 直接运行时追加 `-- shot` 会把视口保存到 user://matcap_uv_lab.png 并退出。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")


func _ready() -> void:
	_build_world()
	_add_sphere(Vector3(-2.85, 0.0, 0.0), _make_matcap(0.0, false), "球面采样")
	_add_sphere(Vector3(-0.95, 0.0, 0.0), _make_matcap(0.5, false), "blend 0.5")
	_add_sphere(Vector3(0.95, 0.0, 0.0), _make_probe(), "blend 1.0 探针")
	_add_sphere(Vector3(2.85, 0.0, 0.0), _make_matcap(0.0, true), "自定义法线")
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.44, 0.54)
	env.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.3, 7.2), Vector3(0.0, 0.0, 0.0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, -35.0, 0.0)
	light.light_energy = 1.2
	add_child(light)

	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "MatCap：UV1 混合与自定义法线"
	title.position = Vector2(24.0, 20.0)
	layer.add_child(title)
	var note := Label.new()
	note.text = "_MatCapBlendUV1 / _MatCapCustomNormal"
	note.position = Vector2(24.0, 556.0)
	layer.add_child(note)


func _add_sphere(pos: Vector3, material: ShaderMaterial, label_text: String) -> void:
	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.68
	ball.height = 1.36
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
	label.position = pos + Vector3(0.0, -1.05, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)


func _make_matcap(blend_uv1: float, custom_normal: bool) -> ShaderMaterial:
	var mat := Factory.create_opaque()
	mat.set_shader_parameter("main_color", Color(0.2, 0.21, 0.24))
	mat.set_shader_parameter("use_matcap", true)
	# 贴图带明暗条纹，便于区分「按球面法线」与「按 UV1」两种采样结果
	mat.set_shader_parameter("matcap_texture", _make_striped_matcap())
	mat.set_shader_parameter("matcap_intensity", 1.0)
	mat.set_shader_parameter("matcap_blend_uv1", blend_uv1)
	mat.set_shader_parameter("use_specular", false)
	if custom_normal:
		mat.set_shader_parameter("use_matcap_bump_map", true)
		mat.set_shader_parameter("matcap_bump_map", _make_bump_texture())
		mat.set_shader_parameter("matcap_bump_scale", 1.0)
		mat.set_shader_parameter("matcap_custom_normal", true)
	return mat


## 探针：blend=1 且贴图为纯绿。若球整体变绿，说明 UV1 采样路径生效；
## 若仍是灰白明暗，说明 mix 没有按预期采用 UV。
func _make_probe() -> ShaderMaterial:
	var mat := _make_matcap(1.0, false)
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color(0.0, 1.0, 0.0))
	mat.set_shader_parameter("matcap_texture", ImageTexture.create_from_image(img))
	return mat


## 竖直条纹 + 水平渐变：球面采样会绕成一圈，UV1 采样则是规整的竖条。
func _make_striped_matcap() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var u := (float(x) + 0.5) / size
			var v := (float(y) + 0.5) / size
			var stripe := 0.5 + 0.5 * sin(u * TAU * 4.0)
			var k := clampf(stripe * (0.35 + 0.65 * (1.0 - abs(v - 0.5) * 2.0)), 0.0, 1.0)
			img.set_pixel(x, y, Color(k, k, k))
	return ImageTexture.create_from_image(img)


## 斜向法线：作为完整法线使用时，MatCap 采样会被整片推向一侧。
func _make_bump_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			img.set_pixel(x, y, Color(0.85, 0.7, 0.95))
	return ImageTexture.create_from_image(img)


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("user://matcap_uv_lab.png")
	get_tree().quit()
