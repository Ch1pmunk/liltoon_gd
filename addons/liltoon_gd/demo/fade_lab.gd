extends Node3D
## 距离淡出演示：物体随距离过渡到淡出颜色，描边同步收窄消失。

var _materials: Array[ShaderMaterial] = []
var _enabled := true
var _near := 4.0
var _far := 11.0


func _ready() -> void:
	for child in get_children():
		if child is MeshInstance3D and child.has_meta("fade_demo"):
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
	title.text = "距离淡出 / 描边隐藏"
	title.add_theme_font_size_override("font_size", 18)
	panel.add_child(title)

	var toggle := CheckBox.new()
	toggle.text = "启用距离淡出"
	toggle.button_pressed = _enabled
	toggle.toggled.connect(func(on: bool) -> void:
		_enabled = on
		_apply()
	)
	panel.add_child(toggle)

	_add_slider(panel, "起点距离", 0.0, 10.0, 0.1, _near, func(value: float) -> void:
		_near = value
		_apply()
	)
	_add_slider(panel, "终点距离", 1.0, 20.0, 0.1, _far, func(value: float) -> void:
		_far = maxf(value, _near + 0.1)
		_apply()
	)


func _add_slider(panel: VBoxContainer, label_text: String, min_value: float, max_value: float, step: float, value: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	panel.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(90.0, 0.0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(220.0, 0.0)
	slider.value_changed.connect(setter)
	row.add_child(slider)


func _apply() -> void:
	for mat in _materials:
		mat.set_shader_parameter("use_distance_fade", _enabled)
		mat.set_shader_parameter("distance_fade_near", _near)
		mat.set_shader_parameter("distance_fade_far", _far)
		mat.set_shader_parameter("distance_fade_strength", 1.0)
		mat.set_shader_parameter("distance_fade_color", Color(0.45, 0.5, 0.6, 1.0))
		LiltoonMaterialFactory.sync_outline_distance_fade(mat)