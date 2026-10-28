extends Node3D
## 阴影遮罩的采样 LOD（`_ShadowStrengthMaskLOD` / `_ShadowBorderMaskLOD` / `_ShadowBlurMaskLOD`）。
## 用高频噪声做强度遮罩：lod 越大，遮罩越模糊，阴影区内的斑块越粗。
## 直接运行时追加 `-- shot` 会把视口保存到 user://shadow_lod_lab.png 并退出。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")


func _ready() -> void:
	_build_world()
	_add_sphere(Vector3(-2.4, 0.0, 0.0), _make(0.0), "LOD 0（清晰）")
	_add_sphere(Vector3(0.0, 0.0, 0.0), _make(2.0), "LOD 2")
	_add_sphere(Vector3(2.4, 0.0, 0.0), _make(4.0), "LOD 4（模糊）")
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.34, 0.44)
	env.ambient_light_energy = 0.4
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.3, 6.6), Vector3(0.0, 0.0, 0.0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30.0, -25.0, 0.0)
	light.light_energy = 1.3
	add_child(light)

	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "阴影强度遮罩的采样 LOD"
	title.position = Vector2(24.0, 20.0)
	layer.add_child(title)
	var note := Label.new()
	note.text = "_ShadowStrengthMaskLOD（同一张高频噪声遮罩，只改 lod）"
	note.position = Vector2(24.0, 586.0)
	layer.add_child(note)


func _add_sphere(pos: Vector3, material: ShaderMaterial, label_text: String) -> void:
	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.75
	ball.height = 1.5
	ball.radial_segments = 56
	ball.rings = 28
	mesh.mesh = ball
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)

	var label := Label3D.new()
	label.text = label_text
	label.font_size = 32
	label.pixel_size = 0.006
	label.position = pos + Vector3(0.0, -1.1, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)


func _make(lod: float) -> ShaderMaterial:
	var mat := Factory.create_opaque()
	mat.set_shader_parameter("main_color", Color(0.62, 0.64, 0.7))
	mat.set_shader_parameter("use_specular", false)
	mat.set_shader_parameter("use_shadow_strength_mask", true)
	mat.set_shader_parameter("shadow_strength_mask", _make_noise_texture())
	mat.set_shader_parameter("shadow_strength_mask_lod", lod)
	return mat


## 低频竖条纹：球面上能看到 3~4 条明暗带，lod 升高时明显变糊。
## （最初用 128×128 高频噪声，投影到 200px 的球上被降采样成平均灰，lod 差异完全看不出。）
func _make_noise_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var u := (float(x) + 0.5) / size
			var k := 1.0 if u < 0.5 else 0.1
			img.set_pixel(x, y, Color(k, k, k))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("user://shadow_lod_lab.png")
	get_tree().quit()
