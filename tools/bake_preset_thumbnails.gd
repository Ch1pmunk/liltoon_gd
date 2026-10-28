extends Node3D
## 预设缩略图烘焙工具：用真实材质把每个内置预设渲染成 96×96 透明底 PNG。
## 运行：Godot --path . res://tools/bake_preset_thumbnails.tscn
## 输出：user://preset_icons/<预设名>.png，再复制到
## res://addons/liltoon_gd/materials/preset_icons/ 并执行一次 --import。
## 编辑器面板只读取静态 PNG，不在打开 Inspector 时触发渲染帧，避免协程挂起。

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")
const Presets := preload("res://addons/liltoon_gd/editor/preset_library.gd")

const SIZE := 96
const OUT_DIR := "user://preset_icons"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.world_3d = World3D.new()
	viewport.world_3d.environment = _make_environment()

	var camera := Camera3D.new()
	camera.fov = 32.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.0, 3.15), Vector3.ZERO)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28.0, 36.0, 0.0)
	key.light_energy = 1.2
	viewport.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-8.0, -140.0, 0.0)
	fill.light_energy = 0.35
	viewport.add_child(fill)

	var sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.82
	mesh.height = 1.64
	mesh.radial_segments = 64
	mesh.rings = 32
	sphere.mesh = mesh
	viewport.add_child(sphere)

	for preset_name in Presets.get_names():
		var mat := Factory.create_opaque()
		Presets.apply_to_material(mat, preset_name)
		# 缩略图只展示主体，不叠加 next_pass 描边。
		Factory.set_outline_enabled(mat, false)
		sphere.material_override = mat
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		if image == null:
			push_error("缩略图渲染失败：%s" % preset_name)
			continue
		var path := "%s/%s.png" % [OUT_DIR, preset_name]
		var err := image.save_png(path)
		print("THUMB=", path, " ERR=", err)
	get_tree().quit()


func _make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.7, 0.85)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	return env
