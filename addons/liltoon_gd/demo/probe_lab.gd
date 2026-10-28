extends Node3D
## 反射探针演示：开关环境反射并调整粗糙度，观察金属球对天空/场景的反射。

var _materials: Array[ShaderMaterial] = []
var _enabled := true
var _roughness := 0.2


func _ready() -> void:
	for child in get_children():
		if child is MeshInstance3D and child.has_meta("probe_demo"):
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
	title.text = "反射探针演示"
	title.add_theme_font_size_override("font_size", 18)
	panel.add_child(title)

	var toggle := CheckBox.new()
	toggle.text = "启用环境反射"
	toggle.button_pressed = _enabled
	toggle.toggled.connect(func(on: bool) -> void:
		_enabled = on
		_apply()
	)
	panel.add_child(toggle)

	var row := HBoxContainer.new()
	panel.add_child(row)
	var label := Label.new()
	label.text = "粗糙度"
	label.custom_minimum_size = Vector2(80.0, 0.0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = _roughness
	slider.custom_minimum_size = Vector2(240.0, 0.0)
	slider.value_changed.connect(func(value: float) -> void:
		_roughness = value
		_apply()
	)
	row.add_child(slider)


func _apply() -> void:
	for mat in _materials:
		mat.set_shader_parameter("use_reflection", _enabled)
		mat.set_shader_parameter("metallic", 1.0 if _enabled else 0.0)
		mat.set_shader_parameter("roughness", _roughness)