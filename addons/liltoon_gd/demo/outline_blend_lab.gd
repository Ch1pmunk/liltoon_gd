extends Node3D
## 描边混合组合对比：普通透明 / 预乘透明 / 受光+透明。
## 直接运行时追加 `-- shot` 会把视口保存到 user://outline_blend_lab.png 并退出。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")


func _ready() -> void:
	_build_world()
	_add_case(Vector3(-1.7, 0.0, 0.0), Factory.create_opaque(), false, "普通透明描边")
	_add_case(Vector3(0.0, 0.0, 0.0), Factory.create_transparent_premul(), false, "预乘主材质的描边")
	_add_case(Vector3(1.7, 0.0, 0.0), Factory.create_opaque(), true, "受光+透明描边")
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.1, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.55)
	env.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.fov = 42.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.0, 5.4), Vector3(0.0, 0.0, 0.0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 28.0, 0.0)
	light.light_energy = 1.2
	add_child(light)

	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "透明描边混合组合：预乘随主材质自动选择，受光+透明使用独立变体"
	title.position = Vector2(24.0, 20.0)
	layer.add_child(title)
	var note := Label.new()
	note.text = "左：普通透明描边      中：预乘主材质（描边自动预乘）      右：受光+透明描边"
	note.position = Vector2(24.0, 556.0)
	layer.add_child(note)


func _add_case(pos: Vector3, mat: ShaderMaterial, lighting: bool, _caption: String) -> void:
	mat.set_shader_parameter("main_color", Color(1.0, 0.42, 0.38))
	mat.set_shader_parameter("main_opacity", 0.55)
	mat.set_shader_parameter("use_specular", false)
	var mesh := SphereMesh.new()
	mesh.radius = 0.65
	mesh.height = 1.3
	mesh.radial_segments = 64
	mesh.rings = 32
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	add_child(instance)
	Factory.set_outline_enabled(mat, true, 0.035)
	var outline := Factory.get_outline_material(mat)
	if outline != null:
		outline.set_shader_parameter("outline_color", Color(0.95, 0.88, 0.35))
		outline.set_shader_parameter("outline_opacity", 0.6)
	Factory.set_outline_lighting(mat, lighting)
	Factory.set_outline_transparency(mat, true)


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("user://outline_blend_lab.png")
	get_tree().quit()
