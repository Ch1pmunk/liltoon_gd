extends Node3D
## 假阴影演示：三个胶囊 + 三块地面阴影，只改 `fake_shadow_vector.w`，
## 阴影贴图沿光照方向整体偏移。对应 lilToon 的 lts_fakeshadow.shader。
## 直接运行时追加 `-- shot` 会把视口保存到 user://fakeshadow_lab.png 并退出。

const SHADER := preload("res://addons/liltoon_gd/shaders/extra/liltoon_fakeshadow.gdshader")

var _light: DirectionalLight3D
var _materials: Array[ShaderMaterial] = []
var _shadow_texture: ImageTexture


func _ready() -> void:
	_shadow_texture = _make_shadow_texture()
	_build_world()
	_build_ui()
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _process(_delta: float) -> void:
	if _light == null:
		return
	# Godot 方向光沿 -Z 照射，指向光源的方向是 +Z。
	var direction := _light.global_transform.basis.z.normalized()
	for mat in _materials:
		mat.set_shader_parameter("light_direction", direction)


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.32, 0.38)
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	_light = DirectionalLight3D.new()
	_light.rotation_degrees = Vector3(-55.0, 40.0, 0.0)
	_light.light_energy = 1.2
	_light.shadow_enabled = false
	add_child(_light)

	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.current = true
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.9, 5.0), Vector3(0.0, 0.55, 0.0))

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24.0, 24.0)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.52, 0.54, 0.58)
	ground_mat.roughness = 1.0
	ground.material_override = ground_mat
	add_child(ground)

	var offsets := [0.0, 0.3, 0.7]
	for i in 3:
		var x := -1.5 + 1.5 * float(i)
		var capsule := MeshInstance3D.new()
		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = 0.3
		capsule_mesh.height = 1.15
		capsule.mesh = capsule_mesh
		capsule.position = Vector3(x, 0.58, 0.0)
		var body_mat := StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.75, 0.5, 0.45)
		body_mat.roughness = 0.9
		capsule.material_override = body_mat
		add_child(capsule)

		var shadow := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(2.2, 2.2)
		shadow.mesh = quad
		shadow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		shadow.position = Vector3(x, 0.02, 0.0)
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("shadow_color", Color(0.08, 0.09, 0.12, 0.7))
		mat.set_shader_parameter("shadow_texture", _shadow_texture)
		mat.set_shader_parameter("fake_shadow_vector", Vector4(0.0, 0.0, 0.0, offsets[i]))
		shadow.material_override = mat
		_materials.append(mat)
		add_child(shadow)

		var label := Label3D.new()
		label.text = "W = %.2f" % offsets[i]
		label.font_size = 48
		label.pixel_size = 0.004
		label.modulate = Color(1.0, 0.95, 0.85)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(x, 1.55, 0.0)
		add_child(label)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "假阴影演示：偏移量 W 越大，影子沿光照方向离脚越远"
	title.position = Vector2(20.0, 16.0)
	title.add_theme_font_size_override("font_size", 16)
	layer.add_child(title)


func _make_shadow_texture() -> ImageTexture:
	# 程序化生成径向渐变，避免依赖外部贴图；中心实、边缘平滑淡出。
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) / float(size) * 2.0 - Vector2.ONE
			var d := p.length()
			var a := clampf(1.0 - smoothstep(0.25, 1.0, d), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("user://fakeshadow_lab.png")
	get_tree().quit()
