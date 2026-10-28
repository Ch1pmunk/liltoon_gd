extends Node3D
## 毛发 MultiMesh 壳层演示：风动、阴影与描边。

const FUR_SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_fur_multi.gdshader")
const FUR_TRANSPARENT_SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_fur_multi_transparent.gdshader")
const FUR_HELPER := preload("res://addons/liltoon_gd/liltoon_fur.gd")
const FLOOR_SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_cutout.gdshader")

var _base: MeshInstance3D
var _shells: MultiMeshInstance3D
var _outline: MeshInstance3D
var _layers := 6
var _length := 0.12
var _gravity := 0.3
var _ao := 0.65
var _noise := 0.35
var _density := 0.55
var _dir_strength := 0.3
var _transparent := true
var _wind := 0.4
var _wind_speed := 1.0
var _noise_tex: ImageTexture
var _mask_tex: ImageTexture
var _fps_label: Label
var _elapsed := 0.0
var _frames := 0
var _bench := false


func _ready() -> void:
	_bench = OS.get_cmdline_user_args().has("bench")
	_base = get_node_or_null("Base") as MeshInstance3D
	_shells = get_node_or_null("FurShells") as MultiMeshInstance3D
	_noise_tex = _make_noise()
	_mask_tex = _make_length_mask()
	_build_ui()
	_rebuild()
	for child in get_children():
		if child is DirectionalLight3D:
			var dl := child as DirectionalLight3D
			dl.rotation_degrees = Vector3(-40, 90, 0)
			dl.shadow_enabled = true
	_add_floor()
	_add_outline()
	# 直接运行时追加 `-- shot` 会把视口保存到 user://fur_multi_lab.png 并退出。
	# 之前缺这个分支，用 `-- shot` 启动会一直跑下去、被误认为"卡住"。
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _take_shot() -> void:
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("user://fur_multi_lab.png")
	get_tree().quit()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(24.0, 20.0)
	panel.add_theme_constant_override("separation", 6)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "毛发 MultiMesh 壳层"
	title.add_theme_font_size_override("font_size", 18)
	panel.add_child(title)
	_fps_label = Label.new()
	_fps_label.text = "FPS --"
	panel.add_child(_fps_label)

	var transparent_toggle := CheckBox.new()
	transparent_toggle.text = "透明毛发"
	transparent_toggle.tooltip_text = "裁切（默认）与平滑透明之间切换；透明模式更软，排序更敏感。"
	transparent_toggle.button_pressed = _transparent
	transparent_toggle.toggled.connect(func(on: bool) -> void:
		_transparent = on
		_apply()
	)
	panel.add_child(transparent_toggle)
	_add_slider(panel, "层数", 1.0, 12.0, 1.0, _layers, func(v: float) -> void:
		_layers = int(v)
		_rebuild()
	)
	_add_slider(panel, "长度", 0.0, 0.2, 0.005, _length, func(v: float) -> void:
		_length = v
		_apply()
	)
	_add_slider(panel, "方向强度", 0.0, 1.0, 0.01, _dir_strength, func(v: float) -> void:
		_dir_strength = v
		_apply()
	)
	_add_slider(panel, "风力", 0.0, 1.0, 0.01, _wind, func(v: float) -> void:
		_wind = v
		_apply()
	)
	_add_slider(panel, "重力", 0.0, 1.0, 0.01, _gravity, func(v: float) -> void:
		_gravity = v
		_apply()
	)
	_add_slider(panel, "根部压暗", 0.0, 1.0, 0.01, _ao, func(v: float) -> void:
		_ao = v
		_apply()
	)
	_add_slider(panel, "噪声", 0.0, 1.0, 0.01, _noise, func(v: float) -> void:
		_noise = v
		_apply()
	)
	_add_slider(panel, "毛束密度", 0.0, 1.0, 0.01, _density, func(v: float) -> void:
		_density = v
		_apply()
	)


func _add_slider(panel: VBoxContainer, text: String, min_value: float, max_value: float, step: float, value: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	panel.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(80.0, 0.0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(220.0, 0.0)
	slider.value_changed.connect(setter)
	row.add_child(slider)


func _add_floor() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.0, 8.0)
	mi.mesh = plane
	mi.position = Vector3(0, -0.85, 0)
	var mat := ShaderMaterial.new()
	mat.shader = FLOOR_SHADER
	mat.set_shader_parameter("main_color", Color(0.35, 0.33, 0.3, 1.0))
	mi.material_override = mat
	add_child(mi)


func _add_outline() -> void:
	if _base == null or _base.mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Outline"
	mi.mesh = _base.mesh
	mi.transform = _base.transform
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var om := LiltoonMaterialFactory.create_outline_material(_length * 1.2 + 0.02)
	mi.material_override = om
	add_child(mi)
	_outline = mi


func _make_noise() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.06
	for y in 128:
		for x in 128:
			var v := clampf(noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, v))
	return ImageTexture.create_from_image(img)


func _make_length_mask() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	for y in 128:
		for x in 128:
			var v := clampf(0.15 + (noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5) * 0.85, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	_elapsed += delta
	_frames += 1
	if _fps_label != null:
		_fps_label.text = "FPS %d" % Engine.get_frames_per_second()
	if _bench and _elapsed >= 6.0:
		print("AVG_FPS=", _frames / _elapsed)
		get_tree().quit()


func _rebuild() -> void:
	if _base == null or _shells == null or _base.mesh == null:
		return
	_shells.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _base.mesh
	mm.instance_count = _layers
	for i in _layers:
		var t := float(i) / maxf(float(_layers - 1), 1.0)
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(t, 0.0, 0.0, 1.0))
	_shells.multimesh = mm
	if _shells.material_override == null:
		var mat := ShaderMaterial.new()
		mat.shader = FUR_SHADER
		_shells.material_override = mat
	_apply()


func _apply() -> void:
	var mat := _shells.material_override as ShaderMaterial
	var target := FUR_TRANSPARENT_SHADER if _transparent else FUR_SHADER
	if mat.shader != target:
		FUR_HELPER.set_transparent(_shells, _transparent)
	if mat == null:
		return
	var base_mat := _base.material_override as ShaderMaterial
	if base_mat != null:
		mat.set_shader_parameter("main_color", base_mat.get_shader_parameter("main_color"))
		mat.set_shader_parameter("shade_color", base_mat.get_shader_parameter("shade_color"))
		mat.set_shader_parameter("use_specular", false)
	mat.set_shader_parameter("alpha_cutoff", 0.3)
	mat.set_shader_parameter("fur_length", _length)
	mat.set_shader_parameter("fur_gravity", _gravity)
	mat.set_shader_parameter("fur_ao", _ao)
	mat.set_shader_parameter("fur_noise_strength", _noise)
	mat.set_shader_parameter("fur_strand_density", _density)
	mat.set_shader_parameter("fur_strand_scale", 8.0)
	mat.set_shader_parameter("fur_noise_texture", _noise_tex)
	mat.set_shader_parameter("fur_noise_uv_scale", Vector2(10.0, 10.0))
	mat.set_shader_parameter("fur_vector", Vector3(0.15, 0.85, 0.35))
	mat.set_shader_parameter("fur_direction_strength", _dir_strength)
	mat.set_shader_parameter("fur_length_mask", _mask_tex)
	mat.set_shader_parameter("fur_root_color", Color(0.2, 0.1, 0.05, 1.0))
	mat.set_shader_parameter("fur_tip_color", Color(0.9, 0.75, 0.55, 1.0))
	mat.set_shader_parameter("use_fur_rim", true)
	mat.set_shader_parameter("fur_rim_color", Color(1.0, 0.9, 0.7, 1.0))
	mat.set_shader_parameter("fur_rim_fresnel_power", 4.0)
	mat.set_shader_parameter("fur_rim_anti_light", 0.5)
	mat.set_shader_parameter("fur_wind_direction", Vector3(1.0, 0.0, 0.0))
	mat.set_shader_parameter("fur_wind_strength", _wind)
	mat.set_shader_parameter("fur_wind_speed", _wind_speed)
	if _outline != null and _outline.material_override is ShaderMaterial:
		var om := _outline.material_override as ShaderMaterial
		om.set_shader_parameter("outline_width", _length * 1.2 + 0.02)
