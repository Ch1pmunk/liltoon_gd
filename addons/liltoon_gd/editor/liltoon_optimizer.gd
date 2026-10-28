class_name LiltoonOptimizer
extends RefCounted
## 对齐 lilToon 的 lilOptimizer：分析材质，给出优化建议。
## 只读，不修改材质。返回建议列表（空 = 无问题）。
##
## 与原版差异：原版还会读 Unity 的材质关键字与变体表；Godot 无关键字机制，
## 这里只查参数开关、贴图分辨率与已知高开销组合。


## 分析单个材质，返回建议（每条一行中文）。
static func analyze(mat: ShaderMaterial) -> PackedStringArray:
	var tips := PackedStringArray()
	if mat == null or mat.shader == null:
		return tips

	var shader_path := mat.shader.resource_path
	var is_outline := shader_path.contains("outline")
	var is_fur := shader_path.contains("fur")

	# 1. 开关关闭但参数非默认：白占内存/绑定
	tips.append_array(_check_dead_params(mat))

	# 2. 贴图分辨率过大
	tips.append_array(_check_texture_sizes(mat))

	# 3. 已知高开销组合
	if not is_outline:
		if _bool(mat, "use_matcap", false) and _float(mat, "matcap_enable_lighting", 0.0) > 0.001:
			tips.append("MatCap 受光开启：多光源下逐光源重复采样，光源多时开销线性增长")
		if _bool(mat, "use_glitter", false) and _float(mat, "glitter_enable_lighting", 0.0) > 0.001:
			tips.append("闪点受光开启：多光源下逐光源重复采样")
		if _bool(mat, "use_refraction", false) and shader_path.find("refraction") < 0:
			tips.append("use_refraction 已开启但材质不在折射变体上，参数不生效")
		if _bool(mat, "use_fur_rim", false) and is_fur:
			tips.append("毛发边缘光开启：每壳层逐光源计算")
		if _bool(mat, "use_triplanar", false) and _bool(mat, "use_main_texture", false):
			tips.append("三平面映射开启：主贴图采样 3 次")

	# 4. 透明 + 深度预通道组合
	if shader_path.contains("transparent") and _bool(mat, "outline_enable_lighting", false):
		pass  # 无额外提示

	# 5. 描边宽度为 0 但描边开启
	if _bool(mat, "outline_enabled", true) and _float(mat, "outline_width", 0.02) <= 0.0005:
		tips.append("描边已开启但宽度接近 0，建议关闭描边以省一个 draw call")

	# 6. 三层阴影全开但 2nd/3rd 色与主阴影一致
	if _bool(mat, "use_shade_2nd", false) or _bool(mat, "use_shade_3rd", false):
		var c1 := _color(mat, "shade_color", Color(1, 1, 1, 1))
		var c2 := _color(mat, "shade_2nd_color", Color(1, 1, 1, 1))
		if _bool(mat, "use_shade_2nd", false) and c1 == c2:
			tips.append("第二层阴影色与第一层相同，可关闭 use_shade_2nd 省一次阶跃计算")

	return tips


## 批量分析，返回 [Dictionary]：path -> tips。
static func analyze_many(materials: Array) -> Dictionary:
	var result := {}
	for item in materials:
		var mat := item as ShaderMaterial
		if mat == null:
			continue
		var tips := analyze(mat)
		if not tips.is_empty():
			var key := mat.resource_path if not mat.resource_path.is_empty() else str(mat.get_instance_id())
			result[key] = tips
	return result


# ============================================================================
# 内部工具
# ============================================================================


static func _check_dead_params(mat: ShaderMaterial) -> PackedStringArray:
	var tips := PackedStringArray()
	# 开关与依赖参数的对照：开关关但参数被改动，说明用户改了没生效的参数
	var pairs := [
		["use_main_texture", "main_texture"],
		["use_normal_map", "normal_texture"],
		["use_specular", "specular_color"],
		["use_matcap", "matcap_texture"],
		["use_glitter", "glitter_color"],
		["use_dissolve", "dissolve_noise_texture"],
		["use_emission", "emission_texture"],
		["use_reflection_cubemap", "reflection_cubemap"],
	]
	for pair in pairs:
		var enabled := _bool(mat, pair[0], false)
		var tex := mat.get_shader_parameter(pair[1])
		if not enabled and tex is Texture2D:
			tips.append("%s 未开启但 %s 已设置，该贴图不会生效" % [pair[0], pair[1]])
	return tips


static func _check_texture_sizes(mat: ShaderMaterial) -> PackedStringArray:
	var tips := PackedStringArray()
	var sampler_keys := [
		"main_texture", "normal_texture", "shade_color_texture",
		"emission_texture", "matcap_texture", "glitter_shape_texture",
		"decal_texture", "fur_noise_texture", "alpha_mask_texture",
	]
	for key in sampler_keys:
		var tex = mat.get_shader_parameter(key)
		if tex is Texture2D:
			var w := (tex as Texture2D).get_width()
			var h := (tex as Texture2D).get_height()
			if w > 2048 or h > 2048:
				tips.append("%s 分辨率 %dx%d 超过 2048，弱机上建议降到 1024 或用烘焙压缩" % [key, w, h])
	return tips


static func _bool(mat: ShaderMaterial, key: String, fallback: bool) -> bool:
	var v = mat.get_shader_parameter(key)
	return bool(v) if v != null else fallback


static func _float(mat: ShaderMaterial, key: String, fallback: float) -> float:
	var v = mat.get_shader_parameter(key)
	return float(v) if v != null else fallback


static func _color(mat: ShaderMaterial, key: String, fallback: Color) -> Color:
	var v = mat.get_shader_parameter(key)
	return v if v is Color else fallback
