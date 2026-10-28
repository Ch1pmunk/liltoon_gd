extends Node3D
## P6 性能测试：高面数网格 + 6 层毛发；到点打印平均帧率并退出。

const FUR_SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_fur_multi.gdshader")

var _elapsed := 0.0
var _frames := 0
var _shot_taken := false


func _ready() -> void:
	var base := get_node_or_null("Base") as MeshInstance3D
	var shells := get_node_or_null("FurShells") as MultiMeshInstance3D
	if base == null or shells == null or base.mesh == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = base.mesh
	mm.instance_count = 6
	for i in 6:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(float(i) / 5.0, 0.0, 0.0, 1.0))
	shells.multimesh = mm
	shells.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := ShaderMaterial.new()
	mat.shader = FUR_SHADER
	mat.set_shader_parameter("alpha_cutoff", 0.3)
	mat.set_shader_parameter("fur_length", 0.12)
	mat.set_shader_parameter("fur_gravity", 0.3)
	mat.set_shader_parameter("fur_ao", 0.65)
	mat.set_shader_parameter("fur_noise_strength", 0.35)
	mat.set_shader_parameter("fur_strand_density", 0.55)
	mat.set_shader_parameter("fur_strand_scale", 8.0)
	mat.set_shader_parameter("fur_noise_uv_scale", Vector2(10.0, 10.0))
	mat.set_shader_parameter("fur_vector", Vector3(0.15, 0.85, 0.35))
	mat.set_shader_parameter("fur_direction_strength", 0.2)
	mat.set_shader_parameter("fur_wind_direction", Vector3(1.0, 0.0, 0.0))
	mat.set_shader_parameter("fur_wind_strength", 0.4)
	mat.set_shader_parameter("fur_wind_speed", 1.0)
	mat.set_shader_parameter("fur_root_color", Color(0.2, 0.1, 0.05, 1.0))
	mat.set_shader_parameter("fur_tip_color", Color(0.9, 0.75, 0.55, 1.0))
	var base_mat := base.material_override as ShaderMaterial
	if base_mat != null:
		mat.set_shader_parameter("main_color", base_mat.get_shader_parameter("main_color"))
		mat.set_shader_parameter("shade_color", base_mat.get_shader_parameter("shade_color"))
		mat.set_shader_parameter("use_specular", false)
	shells.material_override = mat
	var base2 := MeshInstance3D.new()
	base2.name = "Base2"
	base2.mesh = base.mesh
	base2.position = Vector3(1.7, 0, 0)
	base2.material_override = base.material_override
	add_child(base2)
	var shells2 := MultiMeshInstance3D.new()
	shells2.name = "FurShells2"
	shells2.position = Vector3(1.7, 0, 0)
	shells2.multimesh = mm
	shells2.material_override = mat
	shells2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shells2)
	print("fur_count=", shells.multimesh.instance_count)


func _process(delta: float) -> void:
	_elapsed += delta
	_frames += 1
	if _elapsed >= 5.0 and not _shot_taken and OS.get_cmdline_user_args().has("shot"):
		_shot_taken = true
		_take_shot()
	if _elapsed >= 6.0:
		print("AVG_FPS=", _frames / _elapsed)
		get_tree().quit()


func _take_shot() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("user://fur_perf_lab.png")