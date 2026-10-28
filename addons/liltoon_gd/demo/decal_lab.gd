extends Node3D
## 贴花层演示：主贴花 + 第二贴层，支持强度与三种混合方式。

var _materials: Array[ShaderMaterial] = []
var _enabled := true
var _enabled_2nd := true
var _strength := 1.0
var _blend := 0


func _ready() -> void:
	for child in get_children():
		if child is MeshInstance3D and child.has_meta("decal_demo"):
			var mat := (child as MeshInstance3D).material_override as ShaderMaterial
			if mat != null:
				_materials.append(mat)
	_build_ui()
	_apply()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(24.0, 20.0)
	panel.add_theme_constant_override("separation", 6)
	layer.add_child(panel)

	var title := Label.new()
	title.text = "贴花 / 装饰演示"
	title.add_theme_font_size_override("font_size", 18)
	panel.add_child(title)

	var toggle := CheckBox.new()
	toggle.text = "启用主贴花"
	toggle.button_pressed = _enabled
	toggle.toggled.connect(func(on: bool) -> void:
		_enabled = on
		_apply()
	)
	panel.add_child(toggle)

	var toggle_2nd := CheckBox.new()
	toggle_2nd.text = "启用第二贴层"
	toggle_2nd.button_pressed = _enabled_2nd
	toggle_2nd.toggled.connect(func(on: bool) -> void:
		_enabled_2nd = on
		_apply()
	)
	panel.add_child(toggle_2nd)

	var row := HBoxContainer.new()
	panel.add_child(row)
	var label := Label.new()
	label.text = "强度"
	label.custom_minimum_size = Vector2(60.0, 0.0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = _strength
	slider.custom_minimum_size = Vector2(220.0, 0.0)
	slider.value_changed.connect(func(value: float) -> void:
		_strength = value
		_apply()
	)
	row.add_child(slider)

	var blend_row := HBoxContainer.new()
	panel.add_child(blend_row)
	var blend_label := Label.new()
	blend_label.text = "混合方式"
	blend_label.custom_minimum_size = Vector2(90.0, 0.0)
	blend_row.add_child(blend_label)
	var blend_select := OptionButton.new()
	blend_select.add_item("叠色")
	blend_select.add_item("正片叠底")
	blend_select.add_item("相加")
	blend_select.selected = _blend
	blend_select.item_selected.connect(func(index: int) -> void:
		_blend = index
		_apply()
	)
	blend_row.add_child(blend_select)


func _apply() -> void:
	for mat in _materials:
		mat.set_shader_parameter("use_decal", _enabled)
		mat.set_shader_parameter("decal_strength", _strength)
		mat.set_shader_parameter("decal_blend_mode", _blend)
		mat.set_shader_parameter("use_decal_2nd", _enabled_2nd)
		mat.set_shader_parameter("decal_2nd_strength", _strength)
		mat.set_shader_parameter("decal_2nd_blend_mode", _blend)