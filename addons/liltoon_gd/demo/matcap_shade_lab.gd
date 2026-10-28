extends Node3D
## MatCap / 闪点的「受光」与「受阴影」对比。
## 左起：基准（两个参数都为 0）、只开受光、只开受阴影、闪点开受光。
## 直接运行时追加 `-- shot` 会把视口保存到 user://matcap_shade_lab.png 并退出。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")

const LIGHT_DIR := Vector3(0.45, 0.82, 0.35)


func _ready() -> void:
	_build_world()
	_add_sphere(Vector3(-3.1, 0.0, 0.0), _make_matcap(0.0, 0.0), "基准")
	_add_sphere(Vector3(-1.85, 0.0, 0.0), _make_matcap(1.0, 0.0), "受光")
	_add_sphere(Vector3(-0.6, 0.0, 0.0), _make_matcap(0.0, 1.0), "受阴影")
	_add_sphere(Vector3(0.65, 0.0, 0.0), _make_glitter(), "闪点受光")
	_add_sphere(Vector3(1.9, 0.0, 0.0), _make_aniso(false), "各向异性开")
	_add_sphere(Vector3(3.15, 0.0, 0.0), _make_aniso(true), "→ MatCap 法线")
	_add_occluder()
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.46)
	env.ambient_light_energy = 0.35
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.fov = 38.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.3, 8.2), Vector3(0.0, 0.0, 0.0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-56.0, -128.0, 0.0)
	light.shadow_enabled = true
	light.light_energy = 1.4
	# 暖色光：enable_lighting 是 mix(1, 光色, k)，白光照不出差异
	light.light_color = Color(1.0, 0.68, 0.42)
	add_child(light)

	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "MatCap / 闪点：受光与受阴影"
	title.position = Vector2(24.0, 20.0)
	layer.add_child(title)
	var note := Label.new()
	note.text = "_MatCapEnableLighting / _MatCapShadowMask / _GlitterEnableLighting"
	note.position = Vector2(24.0, 556.0)
	layer.add_child(note)


## 只在「受阴影」球的正上方放一块遮挡板，其余三个球保持受光。
func _add_occluder() -> void:
	var occluder := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.3, 0.06, 1.3)
	occluder.mesh = box
	occluder.position = Vector3(0.85, 0.0, 0.0) + LIGHT_DIR.normalized() * 1.35
	add_child(occluder)


func _add_sphere(pos: Vector3, material: ShaderMaterial, label_text: String) -> void:
	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.6
	ball.height = 1.2
	ball.radial_segments = 48
	ball.rings = 24
	mesh.mesh = ball
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)

	var label := Label3D.new()
	label.text = label_text
	label.font_size = 36
	label.pixel_size = 0.006
	label.position = pos + Vector3(0.0, -0.95, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)


func _make_matcap(enable_lighting: float, shadow_mask: float) -> ShaderMaterial:
	var mat := Factory.create_opaque()
	mat.set_shader_parameter("main_color", Color(0.22, 0.23, 0.26))
	mat.set_shader_parameter("use_matcap", true)
	mat.set_shader_parameter("matcap_texture", _make_matcap_texture())
	mat.set_shader_parameter("matcap_intensity", 1.0)
	mat.set_shader_parameter("matcap_enable_lighting", enable_lighting)
	mat.set_shader_parameter("matcap_shadow_mask", shadow_mask)
	mat.set_shader_parameter("use_specular", false)
	return mat


func _make_glitter() -> ShaderMaterial:
	var mat := _make_matcap(1.0, 0.0)
	mat.set_shader_parameter("use_glitter", true)
	mat.set_shader_parameter("glitter_intensity", 2.5)
	mat.set_shader_parameter("glitter_scale", 18.0)
	mat.set_shader_parameter("glitter_sensitivity", 0.72)
	mat.set_shader_parameter("glitter_enable_lighting", 1.0)
	return mat


## 各向异性开启，但关掉各向异性高光，只观察「法线替换」对 MatCap 采样位置的影响。
func _make_aniso(use_aniso_normal: bool) -> ShaderMaterial:
	var mat := _make_matcap(0.0, 0.0)
	mat.set_shader_parameter("use_anisotropy", true)
	mat.set_shader_parameter("anisotropy_scale", 0.85)
	mat.set_shader_parameter("anisotropy_specular_strength", 0.0)
	mat.set_shader_parameter("anisotropy_2_matcap", use_aniso_normal)
	return mat


## 程序生成的 MatCap：中心亮、边缘暗，便于观察受光/受阴影带来的整体明暗变化。
func _make_matcap_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var u := (float(x) + 0.5) / size * 2.0 - 1.0
			var v := (float(y) + 0.5) / size * 2.0 - 1.0
			var k := clampf(1.0 - sqrt(u * u + v * v), 0.0, 1.0)
			img.set_pixel(x, y, Color(k, k, k * 0.92))
	return ImageTexture.create_from_image(img)


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("user://matcap_shade_lab.png")
	get_tree().quit()
