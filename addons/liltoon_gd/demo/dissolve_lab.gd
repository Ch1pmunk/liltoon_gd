extends Node3D
## 溶解演示：勾选启用、拖动阈值或自动播放，观察四种配置的消失过程。

@export var animate_speed := 0.15

var _materials: Array[ShaderMaterial] = []
var _border := 0.2
var _enabled := true
var _auto := false
var _toggle: CheckBox
var _auto_toggle: CheckBox
var _slider: HSlider


func _ready() -> void:
	for child in get_children():
		if child is MeshInstance3D and child.has_meta("dissolve_demo"):
			var mat := (child as MeshInstance3D).material_override as ShaderMaterial
			if mat != null:
				_materials.append(mat)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	# 用 CPU 采样生成贴图。NoiseTexture2D 会走 GPU 生成，在本机（UHD 617 + 2026 驱动）
	# 上两次触发 DXGI_ERROR_DEVICE_REMOVED（16:12、17:22 各一次，均只跑这一个场景）。
	var noise_texture := _make_noise_texture(noise)
	for mat in _materials:
		mat.set_shader_parameter("dissolve_noise_texture", noise_texture)
	# 命令行 `-- auto` 直接开启自动播放，便于无 UI 交互的回归验证。
	_auto = OS.get_cmdline_user_args().has("auto")
	_build_ui()
	_apply()
	# 直接运行时追加 `-- shot` 会把视口保存到 user://dissolve_lab.png 并退出。
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("user://dissolve_lab.png")
	get_tree().quit()


## 在 CPU 上逐像素采样噪声，生成一张 256×256 的灰度贴图。
func _make_noise_texture(noise: FastNoiseLite) -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var v := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			img.set_pixel(x, y, Color(v, v, v, v))
	return ImageTexture.create_from_image(img)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(24.0, 20.0)
	panel.add_theme_constant_override("separation", 6)
	layer.add_child(panel)

	var title := Label.new()
	title.text = "溶解演示"
	title.add_theme_font_size_override("font_size", 18)
	panel.add_child(title)

	_toggle = CheckBox.new()
	_toggle.text = "启用溶解"
	_toggle.button_pressed = _enabled
	_toggle.toggled.connect(func(on: bool) -> void:
		_enabled = on
		_apply()
	)
	panel.add_child(_toggle)

	var row := HBoxContainer.new()
	panel.add_child(row)
	var label := Label.new()
	label.text = "溶解阈值"
	row.add_child(label)
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.001
	_slider.value = _border
	_slider.custom_minimum_size = Vector2(240.0, 0.0)
	_slider.value_changed.connect(func(value: float) -> void:
		if _auto:
			return
		_border = value
		_apply()
	)
	row.add_child(_slider)

	_auto_toggle = CheckBox.new()
	_auto_toggle.text = "自动播放"
	_auto_toggle.button_pressed = _auto
	_auto_toggle.toggled.connect(func(on: bool) -> void:
		_auto = on
	)
	panel.add_child(_auto_toggle)


func _process(delta: float) -> void:
	if not _auto or not _enabled:
		return
	_border = fmod(_border + delta * animate_speed, 1.0)
	_slider.set_value_no_signal(_border)
	_apply()


func _apply() -> void:
	for mat in _materials:
		mat.set_shader_parameter("use_dissolve", _enabled)
		mat.set_shader_parameter("dissolve_border", _border)
