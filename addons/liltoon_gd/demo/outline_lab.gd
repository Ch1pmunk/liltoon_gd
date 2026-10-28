extends Node3D
## 后处理描边演示：控制屏幕空间描边的开关、粗细、深度敏感度与颜色。

var _material: ShaderMaterial
var _enabled := true
var _thickness := 2.0
var _threshold := 0.08
var _normal_threshold := 0.4
var _basic := false
var _shot_mode := false
var _quad: MeshInstance3D
var _post_outline_supported := true
var _color := Color(1.0, 0.8, 0.5)


func _ready() -> void:
	var quad := find_child("OutlineQuad", true, false)
	if quad is MeshInstance3D:
		_quad = quad as MeshInstance3D
		_material = _quad.material_override as ShaderMaterial
	var method := ""
	if RenderingServer.has_method("get_current_rendering_method"):
		method = String(RenderingServer.get_current_rendering_method())
	_basic = method != "forward_plus"
	_post_outline_supported = method == "forward_plus"
	if not _post_outline_supported:
		_enabled = false
		if _quad != null:
			_quad.visible = false
	if not _basic and _material != null:
		_material.shader = load("res://addons/liltoon_gd/effects/post_outline_screen.gdshader")
	_build_ui()
	_apply()
	_shot_mode = OS.get_cmdline_user_args().has("shot")
	if _shot_mode:
		_take_shot()


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("user://outline_shot.png")
	get_tree().quit()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(24.0, 20.0)
	panel.add_theme_constant_override("separation", 6)
	layer.add_child(panel)

	var title := Label.new()
	title.text = "后处理描边演示"
	title.add_theme_font_size_override("font_size", 18)
	panel.add_child(title)
	if not _post_outline_supported:
		var note := Label.new()
		note.text = "当前渲染器不支持深度纹理，后处理描边已关闭。"
		panel.add_child(note)

	var toggle := CheckBox.new()
	toggle.text = "启用描边"
	toggle.button_pressed = _enabled
	toggle.toggled.connect(func(on: bool) -> void:
		_enabled = on
		_apply()
	)
	panel.add_child(toggle)

	_add_slider(panel, "粗细", 1.0, 6.0, 0.5, _thickness, func(value: float) -> void:
		_thickness = value
		_apply()
	)
	_add_slider(panel, "深度敏感度", 0.01, 1.0, 0.01, _threshold, func(value: float) -> void:
		_threshold = value
		_apply()
	)
	_add_slider(panel, "法线敏感度", 0.0, 1.0, 0.01, _normal_threshold, func(value: float) -> void:
		_normal_threshold = value
		_apply()
	)

	var color_row := HBoxContainer.new()
	panel.add_child(color_row)
	var color_label := Label.new()
	color_label.text = "描边颜色"
	color_row.add_child(color_label)
	var color_button := ColorPickerButton.new()
	color_button.custom_minimum_size = Vector2(64.0, 24.0)
	color_button.color = _color
	color_button.color_changed.connect(func(color: Color) -> void:
		_color = color
		_apply()
	)
	color_row.add_child(color_button)


func _add_slider(panel: VBoxContainer, label_text: String, min_value: float, max_value: float, step: float, value: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	panel.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(110.0, 0.0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(200.0, 0.0)
	slider.value_changed.connect(setter)
	row.add_child(slider)


func _apply() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("outline_alpha", 1.0 if _enabled else 0.0)
	_material.set_shader_parameter("thickness", _thickness)
	_material.set_shader_parameter("depth_threshold", _threshold)
	if not _basic:
		_material.set_shader_parameter("normal_threshold", _normal_threshold)
	_material.set_shader_parameter("outline_color", _color)
