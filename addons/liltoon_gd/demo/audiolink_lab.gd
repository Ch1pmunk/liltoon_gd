extends Node3D
## AudioLink 演示：左球用音频驱动自发光，右球用音频驱动顶点缩放。
## 音频来源是场景里挂的 LiltoonAudioLink autoload（分析 Master 总线）。
## 没有音频在播时，脚本会注入一段合成频谱，保证效果可见、截图可验证。
## 用法：godot --path . res://addons/liltoon_gd/demo/audiolink_lab.tscn -- shot

const SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_opaque.gdshader")

var _time := 0.0
var _bars: Array[MeshInstance3D] = []


func _ready() -> void:
	_build_world()
	_build_ui()
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.35)
	env.ambient_light_energy = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 45.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 0.3, 4.6), Vector3(0.0, 0.0, 0.0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	light.light_energy = 0.9
	add_child(light)

	var mesh := SphereMesh.new()
	mesh.radius = 0.62
	mesh.height = 1.24
	mesh.radial_segments = 48
	mesh.rings = 24

	# 左：自发光脉动
	var left := MeshInstance3D.new()
	left.mesh = mesh
	left.position = Vector3(-1.1, 0.0, 0.0)
	var lm := ShaderMaterial.new()
	lm.shader = SHADER
	lm.set_shader_parameter("main_color", Color(0.9, 0.35, 0.5, 1.0))
	lm.set_shader_parameter("use_emission", true)
	lm.set_shader_parameter("emission_color", Color(0.35, 0.9, 1.0, 1.0))
	lm.set_shader_parameter("emission_intensity", 2.5)
	lm.set_shader_parameter("use_audiolink", true)
	lm.set_shader_parameter("audiolink_uv_mode", 0)
	lm.set_shader_parameter("audiolink_uv_params", Vector4(0.25, 0.0, 0.0, 0.0))
	lm.set_shader_parameter("audiolink_2_emission", true)
	left.material_override = lm
	add_child(left)

	# 右：顶点随音量缩放
	var right := MeshInstance3D.new()
	right.mesh = mesh
	right.position = Vector3(1.1, 0.0, 0.0)
	var rm := ShaderMaterial.new()
	rm.shader = SHADER
	rm.set_shader_parameter("main_color", Color(0.95, 0.8, 0.35, 1.0))
	rm.set_shader_parameter("use_audiolink", true)
	rm.set_shader_parameter("audiolink_uv_mode", 0)
	rm.set_shader_parameter("audiolink_uv_params", Vector4(0.25, 0.0, 0.0, 0.0))
	rm.set_shader_parameter("audiolink_2_vertex", true)
	rm.set_shader_parameter("audiolink_vertex_strength", Vector4(0.0, 0.0, 0.0, 0.35))
	right.material_override = rm
	add_child(right)

	# 基准尺寸参考环：球被音频推大时会明显超出这个环，静帧也能看出位移生效
	var ref := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.63
	torus.outer_radius = 0.645
	torus.rings = 64
	torus.ring_segments = 8
	ref.mesh = torus
	ref.position = right.position
	ref.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var refmat := StandardMaterial3D.new()
	refmat.albedo_color = Color(0.35, 0.95, 0.75)
	refmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ref.material_override = refmat
	add_child(ref)

	# 底部四条频段指示条
	for i in 4:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.28, 1.0, 0.28)
		bar.mesh = bm
		bar.position = Vector3(-0.6 + 0.4 * i, -1.15, 0.0)
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.3, 0.9, 0.7)
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bar.material_override = bmat
		add_child(bar)
		_bars.append(bar)

	_add_label("音频驱动自发光", Vector3(-1.1, 1.05, 0.0))
	_add_label("音频驱动顶点", Vector3(1.1, 1.05, 0.0))
	_add_label("4 频段（低→高）", Vector3(0.0, -1.75, 0.0))


func _add_label(text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 34
	label.pixel_size = 0.0038
	label.modulate = Color(1.0, 0.96, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	add_child(label)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "AudioLink：全局频谱纹理驱动 自发光 / 顶点。无音频时注入合成频谱。"
	title.position = Vector2(16.0, 14.0)
	title.add_theme_font_size_override("font_size", 14)
	layer.add_child(title)


func _process(delta: float) -> void:
	_time += delta
	# 没有真实音频时注入合成频谱，保证效果可见
	# 从 autoload 取真实频谱（global_shader_parameter_get 是编辑器专用 API，运行期不能用）
	var bands := Vector4.ZERO
	var al := get_node_or_null("/root/LiltoonAudioLink")
	if al != null and al.has_method("get_band"):
		bands = Vector4(al.get_band(0), al.get_band(1), al.get_band(2), al.get_band(3))
	if bands.x + bands.y + bands.z + bands.w < 0.01:
		bands = Vector4(
			0.55 + 0.45 * sin(_time * 3.1),
			0.45 + 0.40 * sin(_time * 5.3 + 1.1),
			0.35 + 0.35 * sin(_time * 7.7 + 2.3),
			0.25 + 0.30 * sin(_time * 11.3 + 3.7),
		)
		RenderingServer.global_shader_parameter_set("audiolink_bands", bands)
	# 指示条高度
	for i in _bars.size():
		var v: float = clampf(bands[i], 0.02, 1.0)
		_bars[i].scale = Vector3(1.0, v, 1.0)
		_bars[i].position.y = -1.15 + v * 0.5


func _take_shot() -> void:
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("user://audiolink_lab.png")
	get_tree().quit()
