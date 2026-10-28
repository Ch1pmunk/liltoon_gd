extends Node3D
## 法线贴图与高光：法线强度、高光法线强度（_SpecularNormalStrength）、金属度与光滑度。
## 左起：基准、法线贴图、高光法线=0、高光法线=1、金属 0.8、光滑度 0.9。
## 直接运行时追加 `-- shot` 保存到 user://normal_specular_lab.png 并退出。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")


func _ready() -> void:
	_build_world()
	_add_sphere(Vector3(-3.45, 0.0, 0.0), _make("base"), "基准")
	_add_sphere(Vector3(-2.07, 0.0, 0.0), _make("normal"), "法线贴图")
	_add_sphere(Vector3(-0.69, 0.0, 0.0), _make("spec0"), "高光法线 0")
	_add_sphere(Vector3(0.69, 0.0, 0.0), _make("spec1"), "高光法线 1")
	_add_sphere(Vector3(2.07, 0.0, 0.0), _make("metal"), "金属 0.8")
	_add_sphere(Vector3(3.45, 0.0, 0.0), _make("gloss"), "光滑度 0.9")
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.33, 0.42)
	env.ambient_light_energy = 0.35
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.fov = 38.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.25, 8.6), Vector3(0.0, 0.0, 0.0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30.0, -34.0, 0.0)
	light.light_energy = 1.6
	add_child(light)

	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "法线与高光：强度 / 高光法线 / 金属 / 光滑度"
	title.position = Vector2(20.0, 16.0)
	layer.add_child(title)


func _add_sphere(pos: Vector3, material: ShaderMaterial, label_text: String) -> void:
	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.58
	ball.height = 1.16
	ball.radial_segments = 64
	ball.rings = 32
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
	mat.set_shader_parameter("main_color", Color(0.6, 0.62, 0.68))
	mat.set_shader_parameter("use_specular", kind in ["base", "normal", "spec0", "spec1"])
	mat.set_shader_parameter("specular_color", Color(1.0, 1.0, 1.0, 1.0))
	mat.set_shader_parameter("specular_size", 0.35)
	mat.set_shader_parameter("specular_smoothness", 0.02)
	match kind:
		"normal":
			mat.set_shader_parameter("use_normal_map", true)
			mat.set_shader_parameter("normal_texture", _make_normal_texture())
			mat.set_shader_parameter("normal_strength", 1.0)
		"spec0":
			mat.set_shader_parameter("use_normal_map", true)
			mat.set_shader_parameter("normal_texture", _make_normal_texture())
			mat.set_shader_parameter("normal_strength", 1.0)
			mat.set_shader_parameter("specular_normal_strength", 0.0)
		"spec1":
			mat.set_shader_parameter("use_normal_map", true)
			mat.set_shader_parameter("normal_texture", _make_normal_texture())
			mat.set_shader_parameter("normal_strength", 1.0)
			mat.set_shader_parameter("specular_normal_strength", 1.0)
		"metal":
			mat.set_shader_parameter("use_reflection", true)
			mat.set_shader_parameter("metallic", 0.8)
			mat.set_shader_parameter("roughness", 0.35)
		"gloss":
			mat.set_shader_parameter("use_reflection", true)
			mat.set_shader_parameter("metallic", 0.0)
			mat.set_shader_parameter("roughness", 0.1)
	return mat


## 斜向波纹法线贴图：明暗边界会被扰动出凹凸，高光也会跟着弯。
func _make_normal_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var u := float(x) / size
			var v := float(y) / size
			var nx := sin(u * TAU * 3.0) * 0.5
			var ny := sin(v * TAU * 3.0) * 0.5
			img.set_pixel(x, y, Color(nx * 0.5 + 0.5, ny * 0.5 + 0.5, 1.0))
	return ImageTexture.create_from_image(img)


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("user://normal_specular_lab.png")
	get_tree().quit()
