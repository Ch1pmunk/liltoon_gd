extends Node3D
## 折射演示：左球普通半透明，右球启用折射（屏幕纹理按视角法线扰动）。
## 对应 lilToon lts_ref.shader 的 _Refraction* 四项。
## 直接运行时追加 `-- shot` 会把视口保存到 user://refraction_lab.png 并退出。

const TRANSPARENT_SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_transparent.gdshader")
const REFRACTION_SHADER := preload("res://addons/liltoon_gd/shaders/extra/liltoon_refraction.gdshader")


func _ready() -> void:
	_build_world()
	_build_ui()
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.42, 0.5)
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	light.light_energy = 1.0
	add_child(light)

	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.current = true
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.0, 4.2), Vector3.ZERO)

	# 背景用高对比棋盘，折射后条纹会明显错位。
	var backdrop := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(7.5, 4.5)
	backdrop.mesh = plane
	backdrop.position = Vector3(0.0, 0.0, -1.6)
	backdrop.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var backdrop_mat := StandardMaterial3D.new()
	backdrop_mat.albedo_texture = _make_checker_texture()
	backdrop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	backdrop.material_override = backdrop_mat
	add_child(backdrop)

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.95
	sphere_mesh.height = 1.9

	var left := MeshInstance3D.new()
	left.mesh = sphere_mesh
	left.position = Vector3(-1.0, 0.0, 0.0)
	var left_mat := ShaderMaterial.new()
	left_mat.shader = TRANSPARENT_SHADER
	left_mat.set_shader_parameter("main_color", Color(0.85, 0.9, 1.0, 1.0))
	left_mat.set_shader_parameter("main_opacity", 0.35)
	left_mat.set_shader_parameter("use_specular", false)
	left.material_override = left_mat
	add_child(left)

	var right := MeshInstance3D.new()
	right.mesh = sphere_mesh
	right.position = Vector3(1.0, 0.0, 0.0)
	var right_mat := ShaderMaterial.new()
	right_mat.shader = REFRACTION_SHADER
	right_mat.set_shader_parameter("main_color", Color(0.85, 0.9, 1.0, 1.0))
	right_mat.set_shader_parameter("main_opacity", 0.35)
	right_mat.set_shader_parameter("use_specular", false)
	right_mat.set_shader_parameter("use_refraction", true)
	right_mat.set_shader_parameter("refraction_strength", 0.35)
	right_mat.set_shader_parameter("refraction_fresnel_power", 1.0)
	right.material_override = right_mat
	add_child(right)

	_add_label("普通半透明", Vector3(-1.0, 1.35, 0.0))
	_add_label("折射开启（强度 0.35）", Vector3(1.0, 1.35, 0.0))


func _add_label(text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.004
	label.modulate = Color(1.0, 0.95, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	add_child(label)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "折射演示：右球背景条纹被法线扰动"
	title.position = Vector2(20.0, 16.0)
	title.add_theme_font_size_override("font_size", 16)
	layer.add_child(title)


func _make_checker_texture() -> ImageTexture:
	var size := 256
	var cell := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var on := ((x / cell) + (y / cell)) % 2 == 0
			var color := Color(0.95, 0.62, 0.25) if on else Color(0.15, 0.35, 0.65)
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("user://refraction_lab.png")
	get_tree().quit()
