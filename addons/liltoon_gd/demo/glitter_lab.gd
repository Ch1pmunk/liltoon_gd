extends Node3D
## Glitter 三项：颜色贴图、朝向随机、法线扰动强度。
## 左起：基准、`use_glitter_color_tex`（彩条染色）、`glitter_angle_randomize=1`、`glitter_normal_strength=0`。
## 直接运行时追加 `-- shot` 会把视口保存到 user://glitter_lab.png 并退出。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")


func _ready() -> void:
	_build_world()
	_add_sphere(Vector3(-2.85, 0.0, 0.0), _make("base"), "基准")
	_add_sphere(Vector3(-0.95, 0.0, 0.0), _make("color"), "颜色贴图")
	_add_sphere(Vector3(0.95, 0.0, 0.0), _make("angle"), "朝向随机")
	_add_sphere(Vector3(2.85, 0.0, 0.0), _make("normal"), "法线强度 0")
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.48)
	env.ambient_light_energy = 0.5
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.3, 7.2), Vector3(0.0, 0.0, 0.0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38.0, -30.0, 0.0)
	light.light_energy = 1.2
	add_child(light)

	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "Glitter：颜色贴图 / 朝向随机 / 法线强度"
	title.position = Vector2(24.0, 20.0)
	layer.add_child(title)
	var note := Label.new()
	note.text = "_GlitterColorTex / _GlitterAngleRandomize / _GlitterNormalStrength"
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


func _make(kind: String) -> ShaderMaterial:
	var mat := Factory.create_opaque()
	mat.set_shader_parameter("main_color", Color(0.1, 0.1, 0.12))
	mat.set_shader_parameter("use_specular", false)
	mat.set_shader_parameter("use_glitter", true)
	mat.set_shader_parameter("glitter_intensity", 4.0)
	mat.set_shader_parameter("glitter_scale", 9.0)
	mat.set_shader_parameter("glitter_sensitivity", 0.62)
	match kind:
		"color":
			mat.set_shader_parameter("use_glitter_color_tex", true)
			mat.set_shader_parameter("glitter_color_texture", _make_color_texture())
		"angle":
			mat.set_shader_parameter("glitter_angle_randomize", 1.0)
		"normal":
			mat.set_shader_parameter("glitter_normal_strength", 0.0)
	return mat


## 横向三色条：闪点会分别染成红/绿/蓝，便于确认贴图按 UV 生效。
func _make_color_texture() -> ImageTexture:
	var w := 96
	var h := 8
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for x in w:
		var t := float(x) / (w - 1)
		var c := Color(1.0, 0.25, 0.25) if t < 0.34 else (Color(0.3, 1.0, 0.35) if t < 0.67 else Color(0.35, 0.55, 1.0))
		for y in h:
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("user://glitter_lab.png")
	get_tree().quit()
