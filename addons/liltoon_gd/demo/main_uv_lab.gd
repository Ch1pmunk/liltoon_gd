extends Node3D
## 主贴图 UV/HSV 演示：左侧色相旋转 180°，右侧 UV 每秒滚动 0.05。
## 直接运行时追加 `-- shot` 会保存间隔 1 秒的两帧到 user://main_uv_lab_0.png / _1.png，便于确认滚动。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")


func _ready() -> void:
	_build_world()
	var texture := _make_checker_texture()
	_add_sphere(Vector3(-0.9, 0.0, 0.0), _make_material(texture, Vector4(0.5, 1.0, 1.0, 1.0), Vector2.ZERO), "色相旋转 0.5")
	_add_sphere(Vector3(0.9, 0.0, 0.0), _make_material(texture, Vector4(0.0, 1.0, 1.0, 1.0), Vector2(0.05, 0.05)), "UV 滚动 0.05/秒")
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.7)
	env.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.fov = 42.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.0, 4.4), Vector3.ZERO)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30.0, 25.0, 0.0)
	add_child(light)

	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "主贴图 UV/HSV：左 = 色相旋转，右 = UV 滚动（间隔 1 秒的两帧对比）"
	title.position = Vector2(24.0, 20.0)
	layer.add_child(title)
	var note := Label.new()
	note.text = "main_hsvg = (0.5, 1, 1, 1)                    main_uv_scroll = (0.05, 0.05)"
	note.position = Vector2(24.0, 556.0)
	layer.add_child(note)


func _make_material(texture: Texture2D, hsvg: Vector4, scroll: Vector2) -> ShaderMaterial:
	var mat := Factory.create_opaque()
	mat.set_shader_parameter("use_main_texture", true)
	mat.set_shader_parameter("main_texture", texture)
	mat.set_shader_parameter("main_uv_scale", Vector2(2.0, 2.0))
	mat.set_shader_parameter("main_hsvg", hsvg)
	mat.set_shader_parameter("main_uv_scroll", scroll)
	mat.set_shader_parameter("use_specular", false)
	mat.set_shader_parameter("shade_threshold", 0.4)
	return mat


func _add_sphere(pos: Vector3, mat: ShaderMaterial, _caption: String) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.75
	mesh.height = 1.5
	mesh.radial_segments = 64
	mesh.rings = 32
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	add_child(instance)


func _make_checker_texture() -> ImageTexture:
	const SIZE := 128
	const CELL := 16
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var even := ((x / CELL) + (y / CELL)) % 2 == 0
			image.set_pixel(x, y, Color(0.9, 0.25, 0.2) if even else Color(0.95, 0.9, 0.85))
	return ImageTexture.create_from_image(image)


func _take_shot() -> void:
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var first := get_viewport().get_texture().get_image()
	if first != null:
		first.save_png("user://main_uv_lab_0.png")
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var second := get_viewport().get_texture().get_image()
	if second != null:
		second.save_png("user://main_uv_lab_1.png")
	get_tree().quit()
