# 构建 liltoon_gd 演示场景与预设材质
# 用法：godot --headless --path . -s res://tools/build_demo.gd
extends SceneTree

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")
const Presets := preload("res://addons/liltoon_gd/editor/preset_library.gd")

const MAT_DIR := "res://addons/liltoon_gd/materials"
const DEMO_DIR := "res://addons/liltoon_gd/demo"

const PRESET_FILES := {
	"默认": "preset_default.tres",
	"皮肤": "preset_skin.tres",
	"头发": "preset_hair.tres",
	"布料": "preset_cloth.tres",
	"金属": "preset_metal.tres",
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEMO_DIR))

	var materials := _build_materials()
	var scene := _build_scene(materials)
	_assign_owner(scene, scene)
	var packed := PackedScene.new()
	var err := packed.pack(scene)
	if err != OK:
		push_error("打包演示场景失败：%d" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, DEMO_DIR.path_join("showcase.tscn"))
	if err != OK:
		push_error("保存演示场景失败：%d" % err)
		quit(1)
		return
	print("liltoon_gd: 演示场景已生成 -> ", DEMO_DIR.path_join("showcase.tscn"))

	var lab := _build_variant_lab()
	_assign_owner(lab, lab)
	var lab_packed := PackedScene.new()
	var lab_err := lab_packed.pack(lab)
	if lab_err != OK:
		push_error("打包变体演示失败：%d" % lab_err)
	else:
		lab_err = ResourceSaver.save(lab_packed, DEMO_DIR.path_join("variant_lab.tscn"))
		if lab_err != OK:
			push_error("保存变体演示失败：%d" % lab_err)
		else:
			print("liltoon_gd: 变体演示已生成 -> ", DEMO_DIR.path_join("variant_lab.tscn"))

	var character_scene := _build_character_demo()
	_assign_owner(character_scene, character_scene)
	var character_packed := PackedScene.new()
	var character_err := character_packed.pack(character_scene)
	if character_err != OK:
		push_error("打包角色演示失败：%d" % character_err)
	else:
		character_err = ResourceSaver.save(character_packed, DEMO_DIR.path_join("character.tscn"))
		if character_err != OK:
			push_error("保存角色演示失败：%d" % character_err)
		else:
			print("liltoon_gd: 角色演示已生成 -> ", DEMO_DIR.path_join("character.tscn"))

	character_scene.free()
	lab.free()
	scene.free()
	materials.clear()
	quit(0)


func _assign_owner(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		_assign_owner(child, scene_root)


func _build_materials() -> Dictionary:
	var materials := {}
	for preset_name in PRESET_FILES:
		var mat := Factory.create_opaque()
		Presets.apply_to_material(mat, preset_name)
		if preset_name == "金属":
			mat.set_shader_parameter("use_matcap", true)
			mat.set_shader_parameter("matcap_texture", _build_matcap_texture())
			mat.set_shader_parameter("matcap_intensity", 0.5)
			mat.set_shader_parameter("matcap_multiply", true)
		var path := MAT_DIR.path_join(PRESET_FILES[preset_name])
		var err := ResourceSaver.save(mat, path)
		if err != OK:
			push_error("保存预设材质失败：%s (%d)" % [path, err])
		mat.take_over_path(path)
		materials[preset_name] = mat
	return materials


func _build_scene(materials: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Showcase"

	root.add_child(_build_environment())
	root.add_child(_build_light())
	root.add_child(_build_camera())
	root.add_child(_build_ground())

	var preset_names := Presets.get_names()
	for i in preset_names.size():
		var preset_name: String = preset_names[i]
		var sphere := MeshInstance3D.new()
		sphere.name = "Sphere_%s" % PRESET_FILES[preset_name].get_basename()
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 48
		mesh.rings = 24
		sphere.mesh = mesh
		sphere.material_override = materials[preset_name]
		sphere.position = Vector3(-3.6 + i * 0.9, 1.0, 0.0)
		root.add_child(sphere)

	root.add_child(_build_fill_lights())
	_add_variant_samples(root)
	root.add_child(_build_character(materials))
	return root


func _build_fill_lights() -> Node3D:
	var root := Node3D.new()
	root.name = "FillLights"

	var omni := OmniLight3D.new()
	omni.name = "BlueOmni"
	omni.position = Vector3(-2.2, 2.2, 1.6)
	omni.light_color = Color(0.45, 0.6, 1.0)
	omni.light_energy = 1.6
	omni.omni_range = 3.5
	omni.shadow_enabled = false
	root.add_child(omni)

	var spot := SpotLight3D.new()
	spot.name = "WarmSpot"
	spot.position = Vector3(2.8, 3.2, 2.0)
	spot.rotation_degrees = Vector3(-50.0, 12.0, 0.0)
	spot.light_color = Color(1.0, 0.75, 0.55)
	spot.light_energy = 2.5
	spot.spot_range = 6.0
	spot.spot_angle = 35.0
	spot.shadow_enabled = false
	root.add_child(spot)

	return root


func _add_variant_samples(root: Node3D) -> void:
	var cutout_mat := Factory.create_cutout()
	cutout_mat.set_shader_parameter("main_color", Color(0.85, 0.52, 0.5))
	cutout_mat.set_shader_parameter("shade_color", Color(0.4, 0.2, 0.26))
	cutout_mat.set_shader_parameter("alpha_cutoff", 0.5)
	cutout_mat.set_shader_parameter("use_main_texture", true)
	cutout_mat.set_shader_parameter("main_texture", _build_cutout_gradient())

	var cutout_sphere := _sphere(0.28, 0.56, cutout_mat, Vector3(0.7, 0.55, 0.6))
	cutout_sphere.name = "SampleCutout"
	root.add_child(cutout_sphere)

	var transparent_mat := Factory.create_transparent()
	transparent_mat.set_shader_parameter("main_color", Color(0.35, 0.75, 0.8))
	transparent_mat.set_shader_parameter("shade_color", Color(0.12, 0.35, 0.42))
	transparent_mat.set_shader_parameter("main_opacity", 0.5)
	transparent_mat.set_shader_parameter("use_specular", false)

	var transparent_sphere := _sphere(0.28, 0.56, transparent_mat, Vector3(1.25, 0.55, 0.6))
	transparent_sphere.name = "SampleTransparent"
	root.add_child(transparent_sphere)


func _build_variant_lab() -> Node3D:
	var root := Node3D.new()
	root.name = "VariantLab"
	root.add_child(_build_environment())
	root.add_child(_build_light())
	var camera := _build_camera()
	camera.position = Vector3(0.0, 1.45, 4.8)
	root.add_child(camera)
	root.add_child(_build_ground())

	var double_mat := Factory.create_opaque_double()
	double_mat.set_shader_parameter("main_color", Color(0.68, 0.82, 0.95))
	double_mat.set_shader_parameter("shade_color", Color(0.3, 0.42, 0.62))
	Factory.set_outline_enabled(double_mat, true)

	var double_sphere := _sphere(0.55, 1.1, double_mat, Vector3(-2.4, 1.0, 0.0))
	double_sphere.name = "DoubleSidedSphere"
	root.add_child(double_sphere)
	root.add_child(_label_3d("Double", Vector3(-2.4, 1.95, 0.0)))

	var premul_mat := Factory.create_transparent_premul()
	premul_mat.set_shader_parameter("main_color", Color(0.3, 0.85, 0.8))
	premul_mat.set_shader_parameter("shade_color", Color(0.1, 0.4, 0.42))
	premul_mat.set_shader_parameter("main_opacity", 0.35)
	premul_mat.set_shader_parameter("use_specular", false)

	var premul_sphere := _sphere(0.55, 1.1, premul_mat, Vector3(-0.8, 1.0, 0.0))
	premul_sphere.name = "PremulSphere"
	root.add_child(premul_sphere)
	root.add_child(_label_3d("Premul", Vector3(-0.8, 1.95, 0.0)))

	var tri_mat := Factory.create_opaque()
	tri_mat.set_shader_parameter("main_color", Color(1.0, 1.0, 1.0))
	tri_mat.set_shader_parameter("use_main_texture", true)
	tri_mat.set_shader_parameter("main_texture", _build_checker_texture())
	tri_mat.set_shader_parameter("use_triplanar", true)
	tri_mat.set_shader_parameter("triplanar_scale", 3.0)
	tri_mat.set_shader_parameter("shade_color", Color(0.38, 0.4, 0.5))
	Factory.set_outline_enabled(tri_mat, true)

	var tri_sphere := _sphere(0.55, 1.1, tri_mat, Vector3(0.8, 1.0, 0.0))
	tri_sphere.name = "TriplanarSphere"
	root.add_child(tri_sphere)
	root.add_child(_label_3d("Triplanar", Vector3(0.8, 1.95, 0.0)))

	var plane := MeshInstance3D.new()
	plane.name = "DoubleSidedPlane"
	var plane_mesh := QuadMesh.new()
	plane_mesh.size = Vector2(1.3, 1.3)
	plane.mesh = plane_mesh
	plane.material_override = double_mat
	plane.position = Vector3(2.4, 1.0, 0.0)
	plane.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	root.add_child(plane)
	root.add_child(_label_3d("Backface", Vector3(2.4, 1.95, 0.0)))

	return root


func _label_3d(text: String, pos: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 36
	label.pixel_size = 0.0035
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	return label


func _build_checker_texture() -> ImageTexture:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var cell := int(x / 8.0) + int(y / 8.0)
			var color := Color(0.92, 0.92, 0.96) if cell % 2 == 0 else Color(0.45, 0.52, 0.62)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _build_matcap_texture() -> ImageTexture:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var light_dir := Vector3(-0.45, 0.55, 0.7).normalized()
	for y in size:
		for x in size:
			var p := Vector2((float(x) + 0.5) / float(size), (float(y) + 0.5) / float(size)) * 2.0 - Vector2.ONE
			var radius := p.length()
			if radius > 1.0:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			var z := sqrt(maxf(0.0, 1.0 - radius * radius))
			var normal := Vector3(p.x, -p.y, z)
			var diffuse := clampf(normal.dot(light_dir), 0.0, 1.0)
			var specular := pow(clampf(normal.dot((light_dir + Vector3(0.0, 0.0, 1.0)).normalized()), 0.0, 1.0), 32.0)
			var color := Color(0.25, 0.3, 0.4).lerp(Color(0.75, 0.82, 0.95), diffuse)
			color = color.lerp(Color(1.0, 1.0, 1.0), specular)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _build_cutout_gradient() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.62, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.72, Color(1.0, 1.0, 1.0, 1.0))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(1.0, 0.0)
	return texture


func _build_character_demo() -> Node3D:
	var root := Node3D.new()
	root.name = "CharacterDemo"
	root.add_child(_build_environment(true))
	root.add_child(_build_light())
	root.add_child(_build_fill_lights())
	root.add_child(_build_backlight())

	var camera := _build_camera()
	camera.position = Vector3(0.0, 1.55, 3.6)
	camera.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
	camera.fov = 40.0
	root.add_child(camera)

	root.add_child(_build_ground())
	root.add_child(_build_layered_character())
	return root


func _build_backlight() -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "BackLight"
	light.position = Vector3(0.0, 1.9, -1.6)
	light.light_color = Color(1.0, 0.45, 0.35)
	light.light_energy = 2.2
	light.omni_range = 3.0
	light.shadow_enabled = false
	return light


func _build_layered_character() -> Node3D:
	var character := Node3D.new()
	character.name = "LayeredCharacter"

	var skin_mat := Factory.create_opaque()
	Presets.apply_to_material(skin_mat, "皮肤")
	skin_mat.set_shader_parameter("use_sss", true)
	skin_mat.set_shader_parameter("sss_color", Color(1.0, 0.42, 0.36))
	skin_mat.set_shader_parameter("sss_strength", 0.75)
	Factory.set_outline_enabled(skin_mat, true)

	var hair_mat := Factory.create_opaque()
	Presets.apply_to_material(hair_mat, "头发")
	Factory.set_outline_enabled(hair_mat, true)

	var cloth_mat := Factory.create_opaque()
	Presets.apply_to_material(cloth_mat, "布料")
	Factory.set_outline_enabled(cloth_mat, true)

	var metal_mat := Factory.create_opaque()
	Presets.apply_to_material(metal_mat, "金属")
	metal_mat.set_shader_parameter("use_reflection", true)
	metal_mat.set_shader_parameter("metallic", 0.85)
	metal_mat.set_shader_parameter("roughness", 0.28)
	metal_mat.set_shader_parameter("use_matcap", false)
	Factory.set_outline_enabled(metal_mat, true)

	var eye_mat := Factory.create_cutout()
	eye_mat.set_shader_parameter("main_color", Color(1.0, 1.0, 1.0))
	eye_mat.set_shader_parameter("shade_color", Color(0.72, 0.78, 0.92))
	eye_mat.set_shader_parameter("use_main_texture", true)
	eye_mat.set_shader_parameter("main_texture", _build_eye_texture())
	eye_mat.set_shader_parameter("use_parallax", true)
	eye_mat.set_shader_parameter("parallax_texture", _build_eye_height_texture())
	eye_mat.set_shader_parameter("parallax_height", 0.03)
	eye_mat.set_shader_parameter("alpha_cutoff", 0.5)
	eye_mat.set_shader_parameter("use_specular", false)
	eye_mat.set_shader_parameter("use_rim", false)

	var body := _capsule(0.32, 1.1, cloth_mat, Vector3(0.0, 1.05, 0.0))
	body.name = "Body"
	character.add_child(body)

	var head := _sphere(0.28, 0.62, skin_mat, Vector3(0.0, 1.75, 0.0))
	head.name = "Head"
	character.add_child(head)

	var hair := _hemisphere(0.33, 0.42, hair_mat, Vector3(0.0, 1.92, -0.02))
	hair.name = "Hair"
	hair.scale = Vector3(1.05, 0.85, 1.05)
	character.add_child(hair)

	var left_arm := _capsule(0.08, 0.72, cloth_mat, Vector3(-0.42, 1.22, 0.0))
	left_arm.name = "ArmLeft"
	left_arm.rotation_degrees = Vector3(0.0, 0.0, 12.0)
	character.add_child(left_arm)

	var right_arm := _capsule(0.08, 0.72, cloth_mat, Vector3(0.42, 1.22, 0.0))
	right_arm.name = "ArmRight"
	right_arm.rotation_degrees = Vector3(0.0, 0.0, -12.0)
	character.add_child(right_arm)

	var left_leg := _capsule(0.1, 0.62, cloth_mat, Vector3(-0.15, 0.31, 0.0))
	left_leg.name = "LegLeft"
	character.add_child(left_leg)

	var right_leg := _capsule(0.1, 0.62, cloth_mat, Vector3(0.15, 0.31, 0.0))
	right_leg.name = "LegRight"
	character.add_child(right_leg)

	var left_eye := _eye_quad(eye_mat, Vector3(-0.1, 1.78, 0.282))
	left_eye.name = "EyeLeft"
	character.add_child(left_eye)

	var right_eye := _eye_quad(eye_mat, Vector3(0.1, 1.78, 0.282))
	right_eye.name = "EyeRight"
	character.add_child(right_eye)

	var belt := MeshInstance3D.new()
	belt.name = "MetalBelt"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.31
	torus.outer_radius = 0.37
	torus.rings = 64
	torus.ring_segments = 12
	belt.mesh = torus
	belt.material_override = metal_mat
	belt.position = Vector3(0.0, 0.62, 0.0)
	character.add_child(belt)

	var brooch := _sphere(0.06, 0.12, metal_mat, Vector3(0.0, 1.36, 0.33))
	brooch.name = "MetalBrooch"
	character.add_child(brooch)

	return character


func _eye_quad(material: Material, pos: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.13, 0.13)
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	return node


func _build_eye_texture() -> ImageTexture:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(0.5, 0.5)
	for y in size:
		for x in size:
			var p := Vector2((float(x) + 0.5) / float(size), (float(y) + 0.5) / float(size))
			var delta := p - center
			var radius := delta.length()
			var color := Color(0.98, 0.97, 1.0)
			if radius < 0.4:
				var iris_t := clampf(radius / 0.4, 0.0, 1.0)
				color = Color(1.0, 1.0, 1.0).lerp(Color(0.18, 0.45, 0.95), 1.0 - iris_t)
				color = color.lerp(Color(0.08, 0.22, 0.65), iris_t)
			if radius < 0.15:
				color = Color(0.03, 0.04, 0.08)
			if Vector2(p.x - 0.42, p.y - 0.4).length() < 0.055:
				color = Color(1.0, 1.0, 1.0)
			if radius > 0.5:
				color = Color(0.0, 0.0, 0.0, 0.0)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _build_eye_height_texture() -> ImageTexture:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(0.5, 0.5)
	for y in size:
		for x in size:
			var p := Vector2((float(x) + 0.5) / float(size), (float(y) + 0.5) / float(size))
			var height := clampf(1.0 - (p - center).length() * 2.0, 0.0, 1.0)
			image.set_pixel(x, y, Color(height, height, height, 1.0))
	return ImageTexture.create_from_image(image)


func _build_environment(use_sky: bool = false) -> WorldEnvironment:
	var node := WorldEnvironment.new()
	node.name = "WorldEnvironment"
	var env := Environment.new()

	if use_sky:
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color(0.2, 0.32, 0.5)
		sky_material.sky_horizon_color = Color(0.62, 0.68, 0.78)
		sky_material.ground_bottom_color = Color(0.08, 0.08, 0.1)
		sky_material.ground_horizon_color = Color(0.3, 0.32, 0.38)
		var sky := Sky.new()
		sky.sky_material = sky_material
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.35
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.15, 0.17, 0.22)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.55, 0.62, 0.8)
		env.ambient_light_energy = 0.12

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	node.environment = env
	return node


func _build_light() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = "KeyLight"
	light.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	light.light_color = Color(1.0, 0.96, 0.9)
	light.light_energy = 1.1
	light.shadow_enabled = true
	return light


func _build_camera() -> Camera3D:
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 1.55, 5.4)
	camera.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	camera.fov = 50.0
	return camera


func _build_ground() -> MeshInstance3D:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 12.0)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.17, 0.2)
	mat.roughness = 1.0
	ground.material_override = mat
	return ground


func _build_character(materials: Dictionary) -> Node3D:
	var character := Node3D.new()
	character.name = "Character"
	character.position = Vector3(2.4, 0.0, 0.0)

	var body := _capsule(0.32, 1.1, materials["布料"], Vector3(0.0, 1.05, 0.0))
	body.name = "Body"
	character.add_child(body)

	var head := _sphere(0.28, 0.62, materials["皮肤"], Vector3(0.0, 1.75, 0.0))
	head.name = "Head"
	character.add_child(head)

	var hair := _hemisphere(0.31, 0.5, materials["头发"], Vector3(0.0, 1.95, -0.02))
	hair.name = "Hair"
	character.add_child(hair)

	var left_arm := _capsule(0.08, 0.72, materials["布料"], Vector3(-0.42, 1.22, 0.0))
	left_arm.name = "ArmLeft"
	left_arm.rotation_degrees = Vector3(0.0, 0.0, 12.0)
	character.add_child(left_arm)

	var right_arm := _capsule(0.08, 0.72, materials["布料"], Vector3(0.42, 1.22, 0.0))
	right_arm.name = "ArmRight"
	right_arm.rotation_degrees = Vector3(0.0, 0.0, -12.0)
	character.add_child(right_arm)

	var left_leg := _capsule(0.1, 0.62, materials["布料"], Vector3(-0.15, 0.31, 0.0))
	left_leg.name = "LegLeft"
	character.add_child(left_leg)

	var right_leg := _capsule(0.1, 0.62, materials["布料"], Vector3(0.15, 0.31, 0.0))
	right_leg.name = "LegRight"
	character.add_child(right_leg)

	var eye_mat := Factory.create_opaque()
	eye_mat.set_shader_parameter("main_color", Color(0.08, 0.09, 0.12))
	eye_mat.set_shader_parameter("shade_color", Color(0.04, 0.05, 0.07))
	eye_mat.set_shader_parameter("use_specular", false)
	eye_mat.set_shader_parameter("use_rim", false)

	var left_eye := _sphere(0.035, 0.07, eye_mat, Vector3(-0.1, 1.78, 0.255))
	left_eye.name = "EyeLeft"
	character.add_child(left_eye)

	var right_eye := _sphere(0.035, 0.07, eye_mat, Vector3(0.1, 1.78, 0.255))
	right_eye.name = "EyeRight"
	character.add_child(right_eye)

	return character


func _sphere(radius: float, height: float, material: Material, pos: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	mesh.rings = 16
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	return node


func _hemisphere(radius: float, height: float, material: Material, pos: Vector3) -> MeshInstance3D:
	var node := _sphere(radius, height, material, pos)
	var mesh := node.mesh as SphereMesh
	mesh.is_hemisphere = true
	return node


func _capsule(radius: float, height: float, material: Material, pos: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 8
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	return node
