extends Node3D
## Alpha To Coverage 对比演示：左侧纯 Alpha Scissor，右侧 alpha_to_coverage。
## 视口强制开启 4× MSAA，否则 alpha_to_coverage 没有可见效果。
## 直接运行时追加 `-- shot` 会把视口保存到 user://a2c_lab.png 并退出。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")


func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_build_world()
	var cutout_mat := _make_material(false)
	var a2c_mat := _make_material(true)
	_add_quad(Vector3(-0.8, 0.0, 0.0), cutout_mat)
	_add_quad(Vector3(0.8, 0.0, 0.0), a2c_mat)
	_build_labels()
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.3, 0.38)
	env.ambient_light_energy = 0.25
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.0, 3.4), Vector3(0.0, 0.0, 0.0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28.0, 32.0, 0.0)
	light.light_energy = 1.0
	add_child(light)

	# 背景板：透过裁切掉的区域应能看到橙色，用来确认 A2C 变体没有在深度预通道写入整块四边形。
	var backdrop := MeshInstance3D.new()
	var backdrop_mesh := QuadMesh.new()
	backdrop_mesh.size = Vector2(6.0, 3.2)
	backdrop.mesh = backdrop_mesh
	var backdrop_mat := StandardMaterial3D.new()
	backdrop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	backdrop_mat.albedo_color = Color(0.9, 0.45, 0.2)
	backdrop.material_override = backdrop_mat
	backdrop.position = Vector3(0.0, 0.0, -0.9)
	add_child(backdrop)


func _build_labels() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "Alpha To Coverage：左右边缘由 MSAA 覆盖率柔化（4× MSAA）"
	title.position = Vector2(24.0, 20.0)
	layer.add_child(title)
	var note := Label.new()
	note.text = "贴图圆内统一 50% Alpha：左 = Cutout 裁切为不透明      右 = A2C 平均为半透明（可透出背景板）"
	note.position = Vector2(24.0, 556.0)
	layer.add_child(note)


func _make_material(alpha_to_mask: bool) -> ShaderMaterial:
	var mat := Factory.create_cutout()
	mat.set_shader_parameter("main_color", Color(0.62, 0.82, 1.0))
	mat.set_shader_parameter("main_texture", _make_alpha_texture())
	mat.set_shader_parameter("use_main_texture", true)
	mat.set_shader_parameter("alpha_cutoff", 0.25)
	mat.set_shader_parameter("shade_color", Color(0.24, 0.32, 0.52))
	mat.set_shader_parameter("shade_threshold", 0.48)
	mat.set_shader_parameter("shade_blur", 0.02)
	mat.set_shader_parameter("specular_intensity", 0.35)
	mat.set_shader_parameter("specular_size", 0.3)
	if alpha_to_mask:
		Factory.set_alpha_to_mask(mat, true)
	return mat


## 生成统一 50% Alpha 的圆形贴图（圆外 0）。
## Cutout 只做二值裁切，圆内全部保留为不透明；A2C 把 0.5 的 Alpha 平均成半透明覆盖，
## 两者差异在截图中一眼可辨，便于确认 alpha_to_coverage 真正生效。
func _make_alpha_texture() -> ImageTexture:
	const SIZE := 256
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var dx := (x + 0.5 - SIZE * 0.5) / (SIZE * 0.5)
			var dy := (y + 0.5 - SIZE * 0.5) / (SIZE * 0.5)
			var radius := sqrt(dx * dx + dy * dy)
			var alpha := 0.5 if radius <= 0.9 else 0.0
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _add_quad(pos: Vector3, mat: ShaderMaterial) -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.6, 1.6)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	add_child(instance)


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("user://a2c_lab.png")
	get_tree().quit()
