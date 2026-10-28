extends SceneTree
## 临时诊断脚本：验证 Forward+ 下 depth_texture 可用性，并复现 outline_lab 的布局。
## 用法：godot --path . -s res://tools/_depth_probe.gd -- variant=prod
## 输出：user://probe_<variant>.png

func _initialize() -> void:
	var variant := "base"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("variant="):
			variant = arg.split("=")[1]

	var world := Node3D.new()
	root.add_child(world)

	var cam := Camera3D.new()
	if variant.begins_with("prod"):
		cam.position = Vector3(0.0, 0.8, 4.2)
		cam.rotation = Vector3(-0.1391731, 0.0, 0.0)
	else:
		cam.position = Vector3(0.0, 0.0, 4.0)
	cam.current = true
	world.add_child(cam)

	if variant == "prod" or variant == "prod_liltoon":
		var use_liltoon := variant == "prod_liltoon"
		for i in 4:
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			s.mesh = sm
			if use_liltoon:
				var lmat := ShaderMaterial.new()
				lmat.shader = load("res://addons/liltoon_gd/shaders/liltoon_opaque.gdshader")
				lmat.set_shader_parameter("main_color", Color(0.85, 0.45, 0.25))
				s.material_override = lmat
			else:
				var smat := StandardMaterial3D.new()
				smat.albedo_color = Color(0.85, 0.45, 0.25)
				s.material_override = smat
			s.position = Vector3(-1.2 + 0.8 * i, 0.1, 0.0)
			world.add_child(s)
		var floor_mesh := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(10.0, 10.0)
		floor_mesh.mesh = pm
		floor_mesh.position = Vector3(0.0, -0.6, 0.0)
		if use_liltoon:
			var lfmat := ShaderMaterial.new()
			lfmat.shader = load("res://addons/liltoon_gd/shaders/liltoon_opaque.gdshader")
			lfmat.set_shader_parameter("main_color", Color(0.5, 0.47, 0.45))
			floor_mesh.material_override = lfmat
		else:
			var fmat := StandardMaterial3D.new()
			fmat.albedo_color = Color(0.5, 0.47, 0.45)
			floor_mesh.material_override = fmat
		world.add_child(floor_mesh)
	else:
		var sphere := MeshInstance3D.new()
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 0.8
		sphere_mesh.height = 1.6
		sphere.mesh = sphere_mesh
		var sphere_mat := StandardMaterial3D.new()
		sphere_mat.albedo_color = Color(0.9, 0.4, 0.2)
		sphere.material_override = sphere_mat
		world.add_child(sphere)

	var quad := MeshInstance3D.new()
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(4.0, 4.0) if variant.begins_with("prod") else Vector2(20.0, 20.0)
	quad.mesh = quad_mesh
	quad.position = Vector3(0.0, 0.0, -1.0) if variant.begins_with("prod") else Vector3(0.0, 0.0, -2.0)
	var mat := ShaderMaterial.new()
	if variant.begins_with("prod"):
		mat.shader = load("res://addons/liltoon_gd/effects/post_outline_screen.gdshader")
	else:
		var sh := Shader.new()
		sh.code = _shader_code(variant)
		mat.shader = sh
	quad.material_override = mat
	cam.add_child(quad)

	for i in 10:
		await process_frame
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png("user://probe_%s.png" % variant)
		print("PROBE_SAVED ", variant)
	else:
		print("PROBE_NO_IMAGE ", variant)
	quit()


func _shader_code(variant: String) -> String:
	var head := "shader_type spatial;\nrender_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never;\n"
	var depth := "uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;\n"
	var screen := "uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\n"
	var normal := "uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;\n"
	match variant:
		"red":
			return head + "void fragment(){ ALBEDO = vec3(1.0, 0.0, 0.0); ALPHA = 1.0; }\n"
		"screen":
			return head + screen + "void fragment(){ ALBEDO = texture(screen_texture, SCREEN_UV).rgb; ALPHA = 1.0; }\n"
		"depth":
			return head + depth + "void fragment(){ float d = texture(depth_texture, SCREEN_UV).r; ALBEDO = vec3(d * 100.0); ALPHA = 1.0; }\n"
		"depth_no_disable":
			return "shader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never;\n" + depth + "void fragment(){ float d = texture(depth_texture, SCREEN_UV).r; ALBEDO = vec3(d * 100.0); ALPHA = 1.0; }\n"
		"normal":
			return head + normal + "void fragment(){ ALBEDO = vec3(texture(normal_roughness_texture, SCREEN_UV).rg, 0.0); ALPHA = 1.0; }\n"
		"depth_alpha":
			return head + depth + "void fragment(){ float d = texture(depth_texture, SCREEN_UV).r; ALBEDO = vec3(d * 100.0); ALPHA = d > 0.0 ? 1.0 : 0.0; }\n"
		"edge":
			var code := head + "uniform float thickness = 2.0;\nuniform float depth_threshold = 0.08;\nuniform vec4 outline_color = vec4(1.0, 0.8, 0.5, 1.0);\n" + depth
			code += "void fragment(){\n"
			code += "  vec2 uv = SCREEN_UV;\n  vec2 texel = 1.0 / VIEWPORT_SIZE;\n"
			code += "  float depth_center = texture(depth_texture, uv).r;\n"
			code += "  float denom = max(depth_center, 0.0001);\n  float edge = 0.0;\n"
			code += "  vec2 dirs[8] = vec2[8](vec2(1,0), vec2(-1,0), vec2(0,1), vec2(0,-1), vec2(1,1), vec2(-1,1), vec2(1,-1), vec2(-1,-1));\n"
			code += "  for (int i = 0; i < 8; i++) {\n"
			code += "    float ds = texture(depth_texture, uv + dirs[i] * thickness * texel).r;\n"
			code += "    edge = max(edge, step(depth_threshold, abs(ds - depth_center) / denom));\n  }\n"
			code += "  ALBEDO = outline_color.rgb; ALPHA = edge * outline_color.a;\n}\n"
			return code
		_:
			return head + depth + "void fragment(){ float d = texture(depth_texture, SCREEN_UV).r; ALBEDO = vec3(d); ALPHA = 1.0; }\n"
