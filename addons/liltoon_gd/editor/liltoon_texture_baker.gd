class_name LiltoonTextureBaker
extends RefCounted
## 对齐 lilToon 的 lilEditorTextureBaker：把「主色 × 主贴图 × HSV × 渐变 × 贴花」
## 的复合结果烘成一张贴图，并把材质参数重置为恒等，减少运行时采样与计算。
##
## 与原版差异：
## - 原版用 GPU RenderTexture 烘焙，这里用 CPU 逐像素合成（无 GPU 依赖，弱机可用）。
## - 只烘焙主色路径（含 2nd/3rd 贴花），不含阴影色/MatCap/自发光的烘焙（原版分多种 bakeType）。
## - 烘焙前会检查 UV 缩放/滚动/旋转；非恒等 UV 会先烘焙到"参数等效"的贴图上（警告提示）。
##
## 用法：`LiltoonTextureBaker.bake_material(mat, 512)` 返回烘焙后的 Image，或用插件菜单调用。


## 烘焙一个主材质，返回 [Dictionary]：image=Image, path=保存路径, warnings=PackedStringArray。
## size 为输出分辨率（正方形）。save_dir 为空则不落盘。
static func bake_material(mat: ShaderMaterial, size: int = 512, save_dir: String = "res://addons/liltoon_gd/materials/baked") -> Dictionary:
	var warnings := PackedStringArray()
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 1))

	var main_color := _param_color(mat, "main_color", Color(1, 1, 1, 1))
	var hsvg := _param_vec4(mat, "main_hsvg", Vector4(0, 1, 1, 1))
	var uv_scale := _param_vec2(mat, "main_uv_scale", Vector2(1, 1))
	var uv_scroll := _param_vec2(mat, "main_uv_scroll", Vector2(0, 0))
	var uv_rotate := _param_vec2(mat, "main_uv_rotate", Vector2(0, 0))

	if uv_scale != Vector2.ONE:
		warnings.append("main_uv_scale 非 (1,1)，烘焙会把缩放固化进贴图")
	if uv_scroll != Vector2.ZERO or uv_rotate != Vector2.ZERO:
		warnings.append("main_uv_scroll/main_uv_rotate 非零，烘焙后滚动/旋转会失效")

	var main_tex := _param_texture(mat, "main_texture")
	var grad_tex := _param_texture(mat, "main_gradation_texture")
	var grad_strength := _param_float(mat, "main_gradation_strength", 0.0)

	# 逐像素合成主色路径
	for y in size:
		for x in size:
			var uv := Vector2(float(x) + 0.5, float(y) + 0.5) / float(size)
			var suv := _transform_uv(uv, uv_scale, uv_scroll, uv_rotate)
			var c := main_color
			if main_tex != null:
				c *= _sample_tex(main_tex, suv)
			c = _apply_hsvg(c, hsvg)
			if grad_tex != null and grad_strength > 0.001:
				c = _apply_gradation(c, _sample_tex(grad_tex, Vector2(clamp(c.r + c.g + c.b, 0.0, 1.0) / 3.0, 0.5)), grad_strength)
			image.set_pixel(x, y, c)

	# 贴花层：2nd/3rd 按混合模式叠到同一张图上
	for layer in [2, 3]:
		var prefix := "decal_%d_" % layer
		if not _param_bool(mat, "use_decal" if layer == 2 else "use_decal_%d" % layer, false) and layer == 2:
			continue
		if layer == 3 and not _param_bool(mat, "use_decal_3rd", false):
			continue
		var decal_tex := _param_texture(mat, prefix + "texture")
		if decal_tex == null:
			continue
		var d_color := _param_color(mat, prefix + "color", Color(1, 1, 1, 1))
		var d_uv_scale := _param_vec2(mat, prefix + "uv_scale", Vector2(1, 1))
		var d_uv_offset := _param_vec2(mat, prefix + "uv_offset", Vector2(0, 0))
		var d_strength := _param_float(mat, prefix + "strength", 1.0)
		var d_blend := _param_int(mat, prefix + "blend_mode", 0)
		for y in size:
			for x in size:
				var uv := Vector2(float(x) + 0.5, float(y) + 0.5) / float(size)
				var duv := uv * d_uv_scale + d_uv_offset
				var dc := _sample_tex(decal_tex, duv) * d_color
				var a := clamp(dc.a * d_strength, 0.0, 1.0)
				if a <= 0.0:
					continue
				var base := image.get_pixel(x, y)
				var out := _blend(base, dc, a, d_blend)
				image.set_pixel(x, y, out)

	# 重置材质参数为恒等，改用烘焙贴图
	mat.set_shader_parameter("main_color", Color(1, 1, 1, 1))
	mat.set_shader_parameter("main_hsvg", Vector4(0, 1, 1, 1))
	mat.set_shader_parameter("main_gradation_strength", 0.0)
	mat.set_shader_parameter("main_uv_scale", Vector2(1, 1))
	mat.set_shader_parameter("main_uv_scroll", Vector2(0, 0))
	mat.set_shader_parameter("main_uv_rotate", Vector2(0, 0))
	mat.set_shader_parameter("use_decal", false)
	mat.set_shader_parameter("use_decal_2nd", false)
	mat.set_shader_parameter("use_decal_3rd", false)

	var path := ""
	if not save_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
		path = save_dir.path_join("baked_%s.png" % str(mat.get_instance_id()))
		image.save_png(path)
		var baked_tex := load(path) as Texture2D
		if baked_tex != null:
			mat.set_shader_parameter("main_texture", baked_tex)
			mat.set_shader_parameter("use_main_texture", true)
		else:
			warnings.append("烘焙贴图保存后未能重新加载：%s" % path)

	return {"image": image, "path": path, "warnings": warnings}


# ============================================================================
# 内部工具
# ============================================================================


static func _transform_uv(uv: Vector2, scale: Vector2, scroll: Vector2, rotate: Vector2) -> Vector2:
	var out := uv * scale
	if rotate.x != 0.0 or rotate.y != 0.0:
		var angle := rotate.x
		var c := cos(angle)
		var s := sin(angle)
		out = Vector2(out.x * c - out.y * s, out.x * s + out.y * c)
	return out


static func _sample_tex(tex: Texture2D, uv: Vector2) -> Color:
	if tex is ImageTexture:
		var img := (tex as ImageTexture).get_image()
		if img != null:
			var w := img.get_width()
			var h := img.get_height()
			var px := int(uv.x * float(w)) % w
			var py := int(uv.y * float(h)) % h
			if px < 0:
				px += w
			if py < 0:
				py += h
			return img.get_pixel(px, py)
	return Color(1, 1, 1, 1)


static func _apply_hsvg(c: Color, hsvg: Vector4) -> Color:
	if hsvg == Vector4(0, 1, 1, 1):
		return c
	var h := c.h
	var s := c.s
	var v := c.v
	h = fposmod(h + hsvg.x, 1.0)
	s = clamp(s * hsvg.y, 0.0, 1.0)
	v = clamp(v * hsvg.z, 0.0, 1.0)
	var out := Color.from_hsv(h, s, v, c.a)
	if hsvg.w != 1.0 and hsvg.w > 0.0:
		out = Color(pow(out.r, hsvg.w), pow(out.g, hsvg.w), pow(out.b, hsvg.w), out.a)
	return out


static func _apply_gradation(c: Color, grad: Color, strength: float) -> Color:
	return c.lerp(grad, clamp(strength, 0.0, 1.0))


static func _blend(base: Color, over: Color, alpha: float, mode: int) -> Color:
	match mode:
		1:
			return Color(base.r + over.r * alpha, base.g + over.g * alpha, base.b + over.b * alpha, base.a)
		2:
			return Color(base.r * (1.0 - alpha + over.r * alpha), base.g * (1.0 - alpha + over.g * alpha), base.b * (1.0 - alpha + over.b * alpha), base.a)
		_:
			return base.lerp(over, alpha)


static func _param_color(mat: ShaderMaterial, key: String, fallback: Color) -> Color:
	var v = mat.get_shader_parameter(key)
	return v if v is Color else fallback


static func _param_vec4(mat: ShaderMaterial, key: String, fallback: Vector4) -> Vector4:
	var v = mat.get_shader_parameter(key)
	return v if v is Vector4 else fallback


static func _param_vec2(mat: ShaderMaterial, key: String, fallback: Vector2) -> Vector2:
	var v = mat.get_shader_parameter(key)
	return v if v is Vector2 else fallback


static func _param_float(mat: ShaderMaterial, key: String, fallback: float) -> float:
	var v = mat.get_shader_parameter(key)
	return float(v) if v != null else fallback


static func _param_int(mat: ShaderMaterial, key: String, fallback: int) -> int:
	var v = mat.get_shader_parameter(key)
	return int(v) if v != null else fallback


static func _param_bool(mat: ShaderMaterial, key: String, fallback: bool) -> bool:
	var v = mat.get_shader_parameter(key)
	return bool(v) if v != null else fallback


static func _param_texture(mat: ShaderMaterial, key: String) -> Texture2D:
	var v = mat.get_shader_parameter(key)
	return v if v is Texture2D else null
