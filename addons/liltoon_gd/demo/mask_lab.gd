extends Node3D
## 遮罩类功能演示：UDIM 平铺丢弃 / ID 遮罩 / 三通道特性遮罩。
## 用法：godot --path . res://addons/liltoon_gd/demo/mask_lab.tscn -- shot

const SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_opaque.gdshader")


func _ready() -> void:
	_build_world()
	_build_udim_off()
	_build_udim_on()
	_build_tri_mask()
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.42, 0.5)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 40.0
	cam.look_at_from_position(Vector3(0.0, 0.1, 5.2), Vector3.ZERO)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-32.0, 22.0, 0.0)
	add_child(light)


## UDIM 关闭：正常显示，作为对照基准。
func _build_udim_off() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("main_color", Color(0.85, 0.55, 0.35, 1.0))
	_add_plane(mat, Vector3(-1.5, 0.0, 0.0), "UDIM 关（基准）")


## UDIM 开启：内置网格 UV 只在 0..1，只能命中 (0,0) 格，故整块被丢弃。
## 真实用法需要美术把 UV 铺到 0..4（平铺工作流），才能按格丢弃。
func _build_udim_on() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("main_color", Color(0.85, 0.55, 0.35, 1.0))
	mat.set_shader_parameter("use_udim_discard", true)
	mat.set_shader_parameter("udim_discard_mode", 1)   # 片元模式
	mat.set_shader_parameter("udim_discard_uv", 0)
	mat.set_shader_parameter("udim_discard_row0_0", true)
	_add_plane(mat, Vector3(0.0, 0.0, 0.0), "UDIM 开（弃 (0,0) 格 → 整块消失）")


## 三通道特性遮罩：R 压 MatCap、G 压边缘光、B 压自发光。
## 这里给边缘光套一张竖条遮罩（G 通道），于是边缘光只剩竖条区域。
func _build_tri_mask() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("main_color", Color(0.5, 0.55, 0.6, 1.0))
	mat.set_shader_parameter("use_rim", true)
	mat.set_shader_parameter("rim_color", Color(1.0, 0.95, 0.4, 1.0))
	mat.set_shader_parameter("rim_intensity", 2.0)
	mat.set_shader_parameter("rim_border", 0.25)
	mat.set_shader_parameter("use_tri_mask", true)
	mat.set_shader_parameter("tri_mask", _make_stripe_mask())
	_add_sphere(mat, Vector3(1.5, 0.0, 0.0), "三通道遮罩（G 通道挡边缘光）")


## 竖条纹遮罩：R/B 恒为 1（MatCap / 自发光不受影响），G 交替，用来看出通道分别作用在哪。
func _make_stripe_mask() -> ImageTexture:
	const SIZE := 64
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var stripe := 1.0 if (x / 8) % 2 == 0 else 0.0
			img.set_pixel(x, y, Color(1.0, stripe, 1.0, 1.0))
	return ImageTexture.create_from_image(img)


func _add_plane(mat: ShaderMaterial, pos: Vector3, label_text: String) -> void:
	var mesh := MeshInstance3D.new()
	# 用薄 BoxMesh 而非 PlaneMesh：plane 的朝向在旋转后容易背对相机被剔除，
	# 薄盒子从任何方向都可见，且每个面的 UV 都是 0..1，正好用来演示 4×4 网格。
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 1.2, 0.02)
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = pos
	add_child(mesh)
	_add_label(label_text, pos + Vector3(0.0, 0.95, 0.0))


func _add_sphere(mat: ShaderMaterial, pos: Vector3, label_text: String) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.58
	sphere.height = 1.16
	sphere.radial_segments = 48
	sphere.rings = 24
	mesh.mesh = sphere
	mesh.material_override = mat
	mesh.position = pos
	add_child(mesh)
	_add_label(label_text, pos + Vector3(0.0, 0.95, 0.0))


func _add_label(text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 26
	label.pixel_size = 0.0034
	label.modulate = Color(1.0, 0.97, 0.92)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	add_child(label)


func _take_shot() -> void:
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("user://mask_lab.png")
	get_tree().quit()
