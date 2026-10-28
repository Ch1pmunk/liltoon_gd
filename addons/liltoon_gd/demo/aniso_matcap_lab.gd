extends Node3D
## 各向异性法线替换 MatCap（`_Anisotropy2MatCap`）的效果对比。
## 左起：各向异性关、各向异性开但复用关、复用开（scale 0.8）、复用开（scale 0.35）。
## 各向异性高光强度设为 0，只观察 MatCap 采样位置的变化，不掺入发丝高光。
## 直接运行时追加 `-- shot` 保存到 user://aniso_matcap_lab.png 并退出。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")


func _ready() -> void:
	_build_world()
	_add_sphere(Vector3(-2.85, 0.0, 0.0), _make("off"), "各向异性关")
	_add_sphere(Vector3(-0.95, 0.0, 0.0), _make("aniso"), "开但复用关")
	_add_sphere(Vector3(0.95, 0.0, 0.0), _make("reuse8"), "复用 scale 0.8")
	_add_sphere(Vector3(2.85, 0.0, 0.0), _make("reuse35"), "复用 scale 0.35")
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.48, 0.56)
	env.ambient_light_energy = 0.9
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.3, 7.2), Vector3(0.0, 0.0, 0.0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30.0, -30.0, 0.0)
	light.light_energy = 0.8
	add_child(light)

	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "各向异性法线替换 MatCap"
	title.position = Vector2(24.0, 20.0)
	layer.add_child(title)
	var note := Label.new()
	note.text = "_Anisotropy2MatCap（各向异性高光已关闭，只看采样位置）"
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


func _make(kind: String) -> ShaderMaterial:
	var mat := Factory.create_opaque()
	mat.set_shader_parameter("main_color", Color(0.16, 0.17, 0.2))
	mat.set_shader_parameter("use_specular", false)
	mat.set_shader_parameter("use_matcap", true)
	mat.set_shader_parameter("matcap_texture", _make_matcap_texture())
	mat.set_shader_parameter("matcap_intensity", 1.0)
	if kind != "off":
		mat.set_shader_parameter("use_anisotropy", true)
		# 关掉发丝高光，只看 MatCap 的采样法线是否被替换
		mat.set_shader_parameter("anisotropy_specular_strength", 0.0)
	if kind == "reuse8" or kind == "reuse35":
		mat.set_shader_parameter("anisotropy_2_matcap", true)
		mat.set_shader_parameter("anisotropy_scale", 0.8 if kind == "reuse8" else 0.35)
	return mat


## 同心环纹：法线一变，环心就会整体偏移，最容易看出差异。
func _make_matcap_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var u := (float(x) + 0.5) / size * 2.0 - 1.0
			var v := (float(y) + 0.5) / size * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var ring := 0.5 + 0.5 * sin(r * TAU * 2.2)
			var k := clampf(ring * clampf(1.0 - r * 0.65, 0.0, 1.0), 0.0, 1.0)
			img.set_pixel(x, y, Color(k, k, k))
	return ImageTexture.create_from_image(img)


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("user://aniso_matcap_lab.png")
	get_tree().quit()
