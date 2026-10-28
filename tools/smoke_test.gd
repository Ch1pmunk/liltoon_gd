# liltoon_gd 冒烟测试
# 用法：godot --headless --path . -s res://tools/smoke_test.gd
extends SceneTree

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")
const Presets := preload("res://addons/liltoon_gd/editor/preset_library.gd")
const ShaderDocs := preload("res://addons/liltoon_gd/editor/shader_doc_parser.gd")
const Tools := preload("res://addons/liltoon_gd/editor/liltoon_tools.gd")
const PresetRes := preload("res://addons/liltoon_gd/liltoon_preset.gd")
const TextureBaker := preload("res://addons/liltoon_gd/editor/liltoon_texture_baker.gd")
const Optimizer := preload("res://addons/liltoon_gd/editor/liltoon_optimizer.gd")
const Settings := preload("res://addons/liltoon_gd/editor/liltoon_setting.gd")
const LanguageManager := preload("res://addons/liltoon_gd/editor/liltoon_language_manager.gd")
const Startup := preload("res://addons/liltoon_gd/editor/liltoon_startup.gd")

const DOC_SHADERS := [
	"res://addons/liltoon_gd/shaders/liltoon_opaque.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_cutout.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_transparent.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_opaque_double.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_cutout_double.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_transparent_double.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_transparent_premul.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_opaque_front.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_cutout_front.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_transparent_front.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_cutout_a2c.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_cutout_a2c_double.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_cutout_a2c_front.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_outline.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_outline_lit.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_outline_transparent.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_outline_lit_transparent.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_outline_transparent_premul.gdshader",
	"res://addons/liltoon_gd/shaders/liltoon_outline_lit_transparent_premul.gdshader",
	"res://addons/liltoon_gd/shaders/extra/liltoon_fakeshadow.gdshader",
	"res://addons/liltoon_gd/shaders/extra/liltoon_refraction.gdshader",
	"res://addons/liltoon_gd/shaders/extra/liltoon_gem.gdshader",
]

var _failures := 0


func _initialize() -> void:
	var material := Factory.create_opaque()
	_check(material.shader != null, "不透明材质应绑定 shader")

	Presets.apply_to_material(material, "默认")
	_check(material.get_shader_parameter("main_color") is Color, "默认预设应写入 main_color")
	_check(Factory.outline_enabled(material), "默认预设应启用描边")
	var outline := Factory.get_outline_material(material)
	_check(outline != null and outline.shader == Factory.OUTLINE_SHADER, "描边 pass 应使用描边 shader")
	if outline != null:
		_check(outline.get_shader_parameter("outline_width") is float, "描边宽度应写入")

	_check_outline_variants()

	Presets.apply_to_material(material, "布料")
	_check(material.get_shader_parameter("use_specular") == false, "布料预设应关闭高光")
	_check(material.get_shader_parameter("use_shade_2nd") == true, "布料预设应启用第二层阴影")
	_check(material.get_shader_parameter("use_shade_3rd") == true, "布料预设应启用第三层阴影")

	Presets.apply_to_material(material, "金属")
	_check(material.get_shader_parameter("use_specular") == true, "金属预设应开启高光")
	_check(material.get_shader_parameter("use_specular_2nd") == true, "金属预设应启用第二层高光")

	Presets.apply_to_material(material, "皮肤")
	_check(material.get_shader_parameter("use_shade_2nd") == true, "皮肤预设应启用第二层阴影")
	_check(material.get_shader_parameter("shadow_strength") is float, "阴影强度参数应写入")
	_check(material.get_shader_parameter("use_rim_2nd") == true, "皮肤预设应启用第二层 Rim")
	_check(material.get_shader_parameter("use_triplanar") == false, "皮肤预设默认关闭三平面")
	_check(material.get_shader_parameter("use_sss") == true, "皮肤预设应启用 SSS")
	_check(material.get_shader_parameter("cast_shadow") == true, "默认应投射阴影")
	_check(material.get_shader_parameter("depth_offset") == 0.0, "默认深度偏移应为 0")
	var skin_outline := Factory.get_outline_material(material)
	_check(skin_outline != null and skin_outline.get_shader_parameter("outline_mode") == 2, "皮肤预设应使用屏幕空间描边")

	Presets.apply_to_material(material, "头发")
	_check(material.get_shader_parameter("use_specular_3rd") == true, "头发预设应启用各向异性高光")
	_check(is_equal_approx(float(material.get_shader_parameter("rim_dir_strength")), 1.0), "头发预设 Rim 应启用方向性")

	Presets.apply_to_material(material, "金属")
	_check(material.get_shader_parameter("use_reflection") == true, "金属预设应启用环境反射")

	Factory.set_outline_enabled(material, false)
	_check(not Factory.outline_enabled(material), "关闭描边后 next_pass 应为空")
	Factory.set_outline_enabled(material, true)
	_check(Factory.outline_enabled(material), "重新开启描边应创建 next_pass")

	var cutout := Factory.create_cutout()
	_check(cutout.shader == Factory.CUTOUT_SHADER, "Cutout 材质 shader 应正确")
	var cutout_a2c := Factory.create_cutout_a2c()
	_check(Factory.alpha_to_mask_of(cutout_a2c.shader), "A2C 材质应使用 alpha_to_coverage 变体")
	_check(Factory.shader_family(cutout_a2c.shader) == 1, "A2C 变体应归入 Cutout 家族")
	_check(Factory.alpha_to_mask_of(Factory.with_cull_mode(cutout_a2c.shader, 1)), "切换渲染面应保留 A2C")
	_check(Factory.cull_mode_of(Factory.with_cull_mode(cutout_a2c.shader, 2)) == 2, "A2C 仅背面变体的渲染面识别应正确")
	_check(Factory.set_alpha_to_mask(cutout, true) and Factory.alpha_to_mask_of(cutout.shader), "set_alpha_to_mask 应能开启 A2C")
	_check(Factory.set_alpha_to_mask(cutout, false) and not Factory.alpha_to_mask_of(cutout.shader), "set_alpha_to_mask 应能关闭 A2C")
	_check(not Factory.set_alpha_to_mask(material, true), "非 Cutout 材质不应允许 A2C")
	var default_preset := Presets.get_preset("默认")
	_check(default_preset.has("use_alpha_to_mask"), "预设应包含 A2C 开关键")
	_check(default_preset.has("aa_strength") and default_preset.has("emission_2nd_fluorescence"), "预设应包含抗锯齿与荧光参数")
	var transparent := Factory.create_transparent()
	_check(transparent.shader == Factory.TRANSPARENT_SHADER, "透明材质 shader 应正确")
	_check(Factory.create_opaque_double().shader == Factory.OPAQUE_DOUBLE_SHADER, "双面不透明材质 shader 应正确")
	_check(Factory.create_cutout_double().shader == Factory.CUTOUT_DOUBLE_SHADER, "双面 Cutout 材质 shader 应正确")
	_check(Factory.create_transparent_double().shader == Factory.TRANSPARENT_DOUBLE_SHADER, "双面透明材质 shader 应正确")
	_check(Factory.create_transparent_premul().shader == Factory.TRANSPARENT_PREMUL_SHADER, "预乘透明材质 shader 应正确")

	_check_editor_scripts()
	_check_doc_coverage()
	_check_preset_icons()
	_check_p4_tools()
	_check_editor_tools()

	if _failures == 0:
		print("liltoon_gd: 冒烟测试通过")
		quit(0)
	else:
		push_error("liltoon_gd: 冒烟测试失败 %d 项" % _failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  [通过] ", message)
	else:
		_failures += 1
		printerr("  [失败] ", message)


func _check_p4_tools() -> void:
	var tools := Tools.new()
	var preset_helper := PresetRes.new()

	var src := StandardMaterial3D.new()
	src.albedo_color = Color(0.2, 0.4, 0.6)
	var converted := tools.convert_standard_material(src)
	_check(converted.shader == Factory.OPAQUE_SHADER, "转换器应选择不透明 shader")
	_check(converted.get_shader_parameter("main_color") == Color(0.2, 0.4, 0.6), "转换器应复制主色")

	src.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	src.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cutout := tools.convert_standard_material(src)
	_check(cutout.shader == Factory.CUTOUT_DOUBLE_SHADER, "转换器应选择双面 Cutout shader")

	var hash_src := StandardMaterial3D.new()
	hash_src.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	_check(tools.convert_standard_material(hash_src).shader == Factory.TRANSPARENT_SHADER, "Alpha Hash 应映射为透明变体")

	var a2c_src := StandardMaterial3D.new()
	a2c_src.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	a2c_src.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	_check(Factory.alpha_to_mask_of(tools.convert_standard_material(a2c_src).shader), "转换器应把 Alpha 抗锯齿映射为 A2C 变体")

	var ao_src := StandardMaterial3D.new()
	ao_src.ao_enabled = true
	ao_src.ao_texture = GradientTexture2D.new()
	ao_src.ao_light_affect = 0.7
	var ao_result := tools.convert_standard_material_ex(ao_src)
	var ao_mat: ShaderMaterial = ao_result["material"]
	_check(ao_mat.get_shader_parameter("use_ao_map") == true, "转换器应映射 AO 贴图")
	_check(is_equal_approx(float(ao_mat.get_shader_parameter("ao_light_affect")), 0.7), "转换器应映射 AO 对光照的影响")

	var advanced := StandardMaterial3D.new()
	advanced.clearcoat_enabled = true
	_check(not tools.convert_standard_material_ex(advanced)["warnings"].is_empty(), "未转换的 Clearcoat 应产生提示")

	var front_src := StandardMaterial3D.new()
	front_src.cull_mode = BaseMaterial3D.CULL_FRONT
	var front_mat := tools.convert_standard_material(front_src)
	_check(front_mat.shader.resource_path.ends_with("_front.gdshader"), "CULL_FRONT 应映射为仅背面变体")
	_check(Factory.with_cull_mode(front_mat.shader, 0) == Factory.OPAQUE_SHADER, "渲染面切换应能回到单面变体")
	_check(Factory.with_cull_mode(Factory.OPAQUE_SHADER, 1) == Factory.OPAQUE_DOUBLE_SHADER, "渲染面切换应能切到双面变体")
	_check(Factory.with_cull_mode(Factory.OPAQUE_SHADER, 2).resource_path.ends_with("_front.gdshader"), "渲染面切换应能切到仅背面变体")
	_check(Factory.cull_mode_of(Factory.front_shader(0)) == 2, "仅背面变体的渲染面识别应正确")

	var preset := preset_helper.from_material(converted)
	var target := Factory.create_opaque()
	target.set_shader_parameter("shade_color", Color(0, 1, 0))
	target.set_shader_parameter("use_specular", false)
	preset_helper.apply_to_material(preset, target)
	_check(target.get_shader_parameter("main_color") == Color(0.2, 0.4, 0.6), "预设往返应保留主色")
	_check(target.get_shader_parameter("shade_color") == null, "预设应用应清除未包含的参数")

	target.set_shader_parameter("specular_intensity", 99.0)
	_check(not tools.validate_material(target).is_empty(), "越界参数应被校验发现")
	tools.repair_material(target)
	_check(is_equal_approx(float(target.get_shader_parameter("specular_intensity")), 4.0), "越界参数应被夹取到上限")


## 编译所有编辑器脚本（含 @tool 插件）。
## 背景：liltoon_plugin.gd 是 @tool extends EditorPlugin，运行期能加载（EditorPlugin 在 ClassDB 里），
## 但此前冒烟从不编译它，导致一处类型推断错误直到开编辑器才暴露。这里把盲区堵死。
const EDITOR_SCRIPTS := [
	"res://addons/liltoon_gd/liltoon_plugin.gd",
	"res://addons/liltoon_gd/editor/liltoon_inspector_plugin.gd",
	"res://addons/liltoon_gd/editor/liltoon_fur_tools.gd",
	"res://addons/liltoon_gd/editor/liltoon_material_tools.gd",
	"res://addons/liltoon_gd/editor/liltoon_texture_baker.gd",
	"res://addons/liltoon_gd/editor/liltoon_optimizer.gd",
	"res://addons/liltoon_gd/editor/liltoon_setting.gd",
	"res://addons/liltoon_gd/editor/liltoon_startup.gd",
	"res://addons/liltoon_gd/editor/liltoon_language_manager.gd",
	"res://addons/liltoon_gd/editor/liltoon_tools.gd",
	"res://addons/liltoon_gd/editor/preset_library.gd",
	"res://addons/liltoon_gd/editor/shader_doc_parser.gd",
]


func _check_editor_scripts() -> void:
	for path in EDITOR_SCRIPTS:
		var script = load(path)
		var compiled := script is GDScript and (script as GDScript).can_instantiate()
		_check(compiled, "编辑器脚本应可编译：%s" % path.get_file())


func _check_editor_tools() -> void:
	# 纹理烘焙器：烘一张小图，确认参数被重置为恒等
	var bake_mat := Factory.create_opaque()
	bake_mat.set_shader_parameter("main_color", Color(1.0, 0.5, 0.5, 1.0))
	bake_mat.set_shader_parameter("use_decal", true)
	var bake_result = TextureBaker.bake_material(bake_mat, 32, "")
	_check(bake_result["image"] is Image, "烘焙器应返回 Image")
	_check(bake_mat.get_shader_parameter("main_color") == Color(1, 1, 1, 1), "烘焙后 main_color 应重置")
	_check(bake_mat.get_shader_parameter("use_decal") == false, "烘焙后贴花应关闭")
	var img: Image = bake_result["image"]
	_check(img.get_width() == 32, "烘焙尺寸应符合要求")

	# 边界用例：size=0 不应除零崩溃、空材质应优雅返回
	var zero_result = TextureBaker.bake_material(Factory.create_opaque(), 0, "")
	_check(zero_result["image"] is Image, "size=0 应被夹紧而非崩溃")
	var null_result = TextureBaker.bake_material(null, 32, "")
	_check(null_result["image"] == null, "空材质应优雅返回")
	_check(Optimizer.analyze(null).is_empty(), "优化器应对空材质返回空建议")

	# 优化器：关闭的开关 + 已设贴图 → 应给出建议
	var opt_mat := Factory.create_opaque()
	opt_mat.set_shader_parameter("use_main_texture", false)
	opt_mat.set_shader_parameter("main_texture", GradientTexture2D.new())
	var tips: PackedStringArray = Optimizer.analyze(opt_mat)
	_check(tips.size() > 0, "优化器应发现未启用却设了贴图的问题")

	# 设置：读写往返
	var old_lang = Settings.get_value("language")
	Settings.set_value("language", "en")
	_check(Settings.get_value("language") == "en", "全局设置应可写入")
	Settings.set_value("language", old_lang)

	# 多语言：中英文都有 create_material
	_check(LanguageManager.tr_text("create_material") == "创建材质", "默认语言应为中文")
	Settings.set_value("language", "en")
	_check(LanguageManager.tr_text("create_material") == "Create Material", "英文文案应可用")
	Settings.set_value("language", old_lang)

	# 启动检查：不应报错，版本号可读
	var start_tips: PackedStringArray = Startup.check()
	_check(start_tips is PackedStringArray, "启动检查应返回数组")


func _check_outline_variants() -> void:
	var mat := Factory.create_opaque()
	Factory.set_outline_enabled(mat, true)
	var outline := Factory.get_outline_material(mat)
	_check(outline != null and outline.shader == Factory.OUTLINE_SHADER, "默认描边应为 unlit-opaque 变体")
	if outline == null:
		return
	Factory.set_outline_lighting(mat, true)
	_check(outline.shader.resource_path == Factory.OUTLINE_LIT_SHADER_PATH, "描边受光应切到 lit 变体")
	Factory.set_outline_transparency(mat, true)
	_check(outline.shader.resource_path == Factory.OUTLINE_LIT_TRANSPARENT_SHADER_PATH, "受光+透明应切到组合变体")
	Factory.set_outline_lighting(mat, false)
	_check(outline.shader.resource_path == Factory.OUTLINE_TRANSPARENT_SHADER_PATH, "透明+不受光应回到 transparent 变体")
	Factory.set_outline_enabled(mat, false)
	Factory.set_outline_enabled(mat, true)
	_check(outline.shader.resource_path == Factory.OUTLINE_TRANSPARENT_SHADER_PATH, "重新启用描边应保留透明变体")

	var premul := Factory.create_transparent_premul()
	Factory.set_outline_enabled(premul, true)
	var premul_outline := Factory.get_outline_material(premul)
	_check(premul_outline != null and premul_outline.shader.resource_path == Factory.OUTLINE_TRANSPARENT_PREMUL_SHADER_PATH, "预乘材质的描边应使用预乘变体")
	if premul_outline != null:
		_check(premul_outline.get_shader_parameter("outline_apply_transparency") == true, "预乘描边应标记为透明")
		Factory.set_outline_lighting(premul, true)
		_check(premul_outline.shader.resource_path == Factory.OUTLINE_LIT_TRANSPARENT_PREMUL_SHADER_PATH, "预乘描边也应支持受光")


func _check_preset_icons() -> void:
	for preset_name in Presets.get_names():
		var path := "res://addons/liltoon_gd/materials/preset_icons/%s.png" % preset_name
		var texture = load(path)
		_check(texture is Texture2D, "预设缩略图应可加载：%s" % preset_name)


func _check_doc_coverage() -> void:
	var uniform_regex := RegEx.new()
	uniform_regex.compile("(?m)^\\s*uniform\\s+[A-Za-z0-9_]+\\s+([A-Za-z0-9_]+)")
	for shader_path in DOC_SHADERS:
		var docs: Dictionary = ShaderDocs.collect(shader_path)
		var uniforms := {}
		_collect_uniform_names(shader_path, uniform_regex, uniforms, {})
		var missing := []
		for uniform_name in uniforms:
			if not docs.has(uniform_name):
				missing.append(uniform_name)
		_check(missing.is_empty(), "%s 的参数描述应完整（缺失 %s）" % [shader_path.get_file(), str(missing)])


func _collect_uniform_names(path: String, uniform_regex: RegEx, uniforms: Dictionary, visited: Dictionary) -> void:
	if visited.has(path) or not FileAccess.file_exists(path):
		return
	visited[path] = true
	var text := FileAccess.get_file_as_string(path)
	for match_result in uniform_regex.search_all(text):
		uniforms[match_result.get_string(1)] = true
	var include_regex := RegEx.new()
	include_regex.compile("#include\\s+\"([^\"]+)\"")
	for match_result in include_regex.search_all(text):
		_collect_uniform_names(match_result.get_string(1), uniform_regex, uniforms, visited)
