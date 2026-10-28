extends Node3D
## 各向异性：缩放遮罩与切线贴图。
## 左起：基准、`use_anisotropy_scale_mask`（左窄右宽）、`use_anisotropy_tangent_map`（方向偏转）、两者都开。
## 直接运行时追加 `-- shot` 会把视口保存到 user://aniso_lab.png 并退出。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")


func _ready() -> void:
	_build_world()
	_add_sphere(Vector3(-2.85, 0.0, 0.0), _make(false, false), "基准")
	_add_sphere(Vector3(-0.95, 0.0, 0.0), _make(true, false), "缩放遮罩")
	_add_sphere(Vector3(0.95, 0.0, 0.0), _make(false, true), "切线贴图")
	_add_sphere(Vector3(2.85, 0.0, 0.0), _make(true, true), "两者都开")
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.3, 0.38)
	env.ambient_light_energy = 0.35
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.3, 7.2), Vector3(0.0, 0.0, 0.0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-34.0, -28.0, 0.0)
	light.light_energy = 1.6
	# 冷色光让白色各向异性高光更跳
	light.light_color = Color(0.72, 0.82, 1.0)
	add_child(light)

	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "各向异性：缩放遮罩 / 切线贴图"
	title.position = Vector2(24.0, 20.0)
	layer.add_child(title)
	var note := Label.new()
	note.text = "_AnisotropyScaleMask / _AnisotropyTangentMap（各向异性高光）"
	note.position = Vector2(24.0, 596.0)
	layer.add_child(note)


func _add_sphere(pos: Vector3, material: ShaderMaterial, label_text: String) -> void:
	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.68
	ball.height = 1.36
	ball.radial_segments = 64
	ball.rings = 32
	mesh.mesh = ball
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)

	var label := Label3D.new()
	label.text = label_text
	label.font_size = 32
	label.pixel_size = 0.006
	label.position = pos + Vector3(0.0, -1.0, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)


func _make(with_scale_mask: bool, with_tangent_map: bool) -> ShaderMaterial:
	var mat := Factory.create_opaque()
	mat.set_shader_parameter("main_color", Color(0.12, 0.13, 0.16))
	mat.set_shader_parameter("use_specular", false)
	mat.set_shader_parameter("use_anisotropy", true)
	mat.set_shader_parameter("anisotropy_scale", 0.45)
	mat.set_shader_parameter("anisotropy_specular_strength", 2.2)
	mat.set_shader_parameter("anisotropy_tangent_width", 1.0)
	mat.set_shader_parameter("anisotropy_bitangent_width", 0.05)
	if with_scale_mask:
		mat.set_shader_parameter("use_anisotropy_scale_mask", true)
		mat.set_shader_parameter("anisotropy_scale_mask", _make_scale_mask())
	if with_tangent_map:
		mat.set_shader_parameter("use_anisotropy_tangent_map", true)
		mat.set_shader_parameter("anisotropy_tangent_map", _make_tangent_map())
	return mat


## 左黑右白：左半边缩放被压到 0（高光极窄），右半边保持设定值。
func _make_scale_mask() -> ImageTexture:
	var w := 64
	var h := 8
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for x in w:
		var k := 0.02 if x < w / 2 else 1.0
		for y in h:
			img.set_pixel(x, y, Color(k, k, k))
	return ImageTexture.create_from_image(img)


## 斜向法线贴图：切向被整体拧到另一个方向，各向异性高光随之偏转。
func _make_tangent_map() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color(0.9, 0.35, 0.8))
	return ImageTexture.create_from_image(img)


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("user://aniso_lab.png")
	get_tree().quit()
