extends Node3D
## 主色渐变 / 背面颜色与 UV 偏移 / 抖动透明 的对比演示。
## 直接运行时追加 `-- shot` 会把视口保存到 user://material_extra_lab.png 并退出。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")


func _ready() -> void:
	_build_world()
	_add_sphere(Vector3(-1.9, 0.0, 0.0), _make_gradation_material(), "主色渐变")
	_add_backface_quad(Vector3(0.0, 0.0, 0.0))
	_add_sphere(Vector3(1.9, 0.0, 0.0), _make_dither_material(), "抖动透明")
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.65)
	env.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.fov = 42.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.0, 5.6), Vector3.ZERO)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28.0, 25.0, 0.0)
	add_child(light)

	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "主色渐变 / 背面颜色与 UV 偏移 / 抖动透明"
	title.position = Vector2(24.0, 20.0)
	layer.add_child(title)
	var note := Label.new()
	note.text = "左：_MainGradationTex      中：_BackfaceColor + _ShiftBackfaceUV      右：_UseDither"
	note.position = Vector2(24.0, 556.0)
	layer.add_child(note)


func _make_gradation_material() -> ShaderMaterial:
	var mat := Factory.create_opaque()
	mat.set_shader_parameter("use_main_texture", true)
	mat.set_shader_parameter("main_texture", _make_gradient_texture())
	mat.set_shader_parameter("main_uv_scale", Vector2(1.0, 1.0))
	mat.set_shader_parameter("use_main_gradation", true)
	mat.set_shader_parameter("main_gradation_texture", _make_gradation_lut())
	mat.set_shader_parameter("main_gradation_strength", 1.0)
	mat.set_shader_parameter("use_specular", false)
	return mat


func _make_dither_material() -> ShaderMaterial:
	var mat := Factory.create_transparent()
	mat.set_shader_parameter("main_color", Color(0.3, 0.8, 1.0))
	mat.set_shader_parameter("main_opacity", 0.5)
	mat.set_shader_parameter("use_dither", true)
	mat.set_shader_parameter("dither_texture", _make_dither_texture())
	mat.set_shader_parameter("dither_max_value", 255.0)
	mat.set_shader_parameter("use_specular", false)
	return mat


func _add_sphere(pos: Vector3, mat: ShaderMaterial, _caption: String) -> void:
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


func _add_backface_quad(pos: Vector3) -> void:
	var mat := Factory.create_opaque_double()
	mat.set_shader_parameter("use_main_texture", true)
	mat.set_shader_parameter("main_texture", _make_gradient_texture())
	mat.set_shader_parameter("main_uv_scale", Vector2(1.0, 1.0))
	mat.set_shader_parameter("backface_color", Color(0.95, 0.35, 0.3, 0.6))
	mat.set_shader_parameter("shift_backface_uv", true)
	mat.set_shader_parameter("use_specular", false)

	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.7, 1.7)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	instance.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	add_child(instance)


func _make_gradient_texture() -> ImageTexture:
	const SIZE := 128
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var t := x / float(SIZE - 1)
			image.set_pixel(x, y, Color(t, t, t))
	return ImageTexture.create_from_image(image)


func _make_gradation_lut() -> ImageTexture:
	const SIZE := 256
	var image := Image.create(SIZE, 1, false, Image.FORMAT_RGBA8)
	for x in SIZE:
		var t := x / float(SIZE - 1)
		var r := pow(t, 0.8)
		var g := pow(t, 1.2) * 0.85
		var b := pow(t, 2.2) * 0.9 + 0.1 * (1.0 - t)
		image.set_pixel(x, 0, Color(r, g, b, 1.0))
	return ImageTexture.create_from_image(image)


func _make_dither_texture() -> ImageTexture:
	const BAYER := [
		[0, 8, 2, 10],
		[12, 4, 14, 6],
		[3, 11, 1, 9],
		[15, 7, 13, 5],
	]
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 4:
			var v: float = BAYER[y][x] / 15.0
			image.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(image)


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("user://material_extra_lab.png")
	get_tree().quit()
