class_name LiltoonTextureTools
extends RefCounted
## 对齐 lilToon 的三个纹理工具（原版入口：`Editor/lilToonEditorUtils.cs` 的 MenuItem）。
##
## - **法线图 DirectX ↔ OpenGL**：原版走 `Hidden/ltsother_baker` 的 `_NORMAL_DXGL` 分支，
##   数学只有一句 `col.g = 1.0 - col.g`（`ltspass_baker.shader:250-252`）。
## - **像素画降采样**：原版按 `scale` 取点（`outTex(x,y) = src(x*scale, y*scale)`），
##   即最近邻抽样，输出 `_resized.png`，导入设为 Point 过滤（`lilToonEditorUtils.cs:184-223`）。
## - **生成 Ramp**：原版把 `Hidden/ltsother_bakeramp` 渲染到 128×16 渲染目标
##   （`lilToon2Ramp.cs:9-27`），因此每列对应一个 `uv.x`。
##
## 与原版的差异：
## - 原版用 GPU/RenderTexture + `ReadPixels`，这里用 CPU 逐像素；数学相同，单测可覆盖。
## - Ramp 的阴影强度：原版乘 `_ShadowStrength`；本项目 `shadow_strength` 作用于**引擎投影**，
##   不参与色阶，故这里按原版默认值 1.0 处理（等价于原版 `_ShadowStrength = 1`）。
## - 保存后的导入设置（Clamp / 压缩）原版会顺手改，Godot 侧由 `.import` 决定，
##   这里只保证像素内容，导入选项在返回的 warnings 中提示。


## 输出建议尺寸（与原版一致）
const RAMP_WIDTH := 128
const RAMP_HEIGHT := 16

## 主材质参数声明所在文件（用于回读默认值，避免在工具里重复硬编码后漂移）
const UNIFORM_INCLUDE := "res://addons/liltoon_gd/shaders/include/uniforms.gdshaderinc"

## Ramp 用到的参数默认值。**必须与 uniforms.gdshaderinc 的声明一致**，
## 冒烟里的 `参数默认值应与 shader 声明一致` 断言会逐项比对，漂移即失败。
const PARAM_DEFAULTS := {
	"shade_color": Color(0.55, 0.45, 0.52, 1.0),
	"shade_threshold": 0.5,
	"shade_blur": 0.01,
	"shade_border_range": 0.0,
	"shade_border_color": Color(0.0, 0.0, 0.0, 1.0),
	"shade_2nd_color": Color(0.32, 0.22, 0.28, 1.0),
	"shade_2nd_threshold": 0.1,
	"shade_2nd_blur": 0.05,
	"shade_3rd_color": Color(0.18, 0.12, 0.16, 1.0),
	"shade_3rd_threshold": -0.2,
	"shade_3rd_blur": 0.05,
}


## DirectX ↔ OpenGL 法线图互转：绿通道取反（G' = 1 - G），返回新 Image。
static func convert_normal_map(image: Image) -> Image:
	if image == null:
		return null
	var out := _to_rgba8(image)
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			c.g = 1.0 - c.g
			out.set_pixel(x, y, c)
	return out


## 像素画降采样：按 scale 取样（最近邻），输出尺寸为原图除以 scale（至少 1 像素）。
static func reduce_pixel_art(image: Image, scale: int = 2) -> Image:
	if image == null:
		return null
	scale = maxi(scale, 1)
	var src := _to_rgba8(image)
	var w := maxi(src.get_width() / scale, 1)
	var h := maxi(src.get_height() / scale, 1)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			out.set_pixel(x, y, src.get_pixel(mini(x * scale, src.get_width() - 1), mini(y * scale, src.get_height() - 1)))
	return out


## 生成色阶 Ramp：输出 width×height 的 RGBA8，每列按 `uv.x` 求值，同列各行相同。
## 公式对齐原版 `ltspass_bakeramp.shader` 的 frag()。
static func generate_ramp(mat: ShaderMaterial, width: int = RAMP_WIDTH, height: int = RAMP_HEIGHT) -> Image:
	if mat == null:
		return null
	width = clampi(width, 2, 4096)
	height = clampi(height, 1, 1024)

	var shade := _param_color(mat, "shade_color")
	var border := _param_float(mat, "shade_threshold")
	var blur := _param_float(mat, "shade_blur")
	var border_range := _param_float(mat, "shade_border_range")
	var border_color := _param_color(mat, "shade_border_color")
	var shade2 := _param_color(mat, "shade_2nd_color")
	var border2 := _param_float(mat, "shade_2nd_threshold")
	var blur2 := _param_float(mat, "shade_2nd_blur")
	var shade3 := _param_color(mat, "shade_3rd_color")
	var border3 := _param_float(mat, "shade_3rd_threshold")
	var blur3 := _param_float(mat, "shade_3rd_blur")

	var columns := PackedColorArray()
	columns.resize(width)
	for x in width:
		# 原版取像素中心 uv，即 (x + 0.5) / width
		var v := (float(x) + 0.5) / float(width)
		var lit := _tooning(v, border, blur)
		var lit2 := _tooning(v, border2, blur2)
		var lit3 := _tooning(v, border3, blur3)
		var lit_range := _tooning_range(v, border, blur, border_range)

		# 第一层阴影色 → 第二层 → 第三层（原版用各层颜色的 alpha 作混合量）
		var indirect := Vector3(shade.r, shade.g, shade.b)
		var mix2 := shade2.a - lit2 * shade2.a
		indirect = _lerp3(indirect, Vector3(shade2.r, shade2.g, shade2.b), mix2)
		var mix3 := shade3.a - lit3 * shade3.a
		indirect = _lerp3(indirect, Vector3(shade3.r, shade3.g, shade3.b), mix3)
		# 边界染色：过渡带向受光色靠拢（原版是逐通道 t，不能直接用 Vector3.lerp 的标量权重）
		indirect = _lerp3(indirect, Vector3.ONE, Vector3(border_color.r, border_color.g, border_color.b) * lit_range)
		# 最后按第一层色阶混到受光色
		var lit_col := _lerp3(indirect, Vector3.ONE, lit)
		columns[x] = Color(lit_col.x, lit_col.y, lit_col.z, 1.0)

	var out := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			out.set_pixel(x, y, columns[x])
	return out


## 保存结果时的统一命名：`<原文件名><后缀>.png`，放在同目录。
static func output_path(source_path: String, suffix: String) -> String:
	var dir := source_path.get_base_dir()
	var base := source_path.get_file().get_basename()
	return dir.path_join("%s%s.png" % [base, suffix])


## 供插件提示用：说明保存后需要手动确认的导入选项。
static func import_note(is_pixel_art: bool, is_ramp: bool) -> String:
	if is_pixel_art:
		return "像素画降采样：请把导入的 Filter 设为 Nearest（原版会顺手把 filterMode 改成 Point）。"
	if is_ramp:
		return "Ramp：请把导入的 Repeat 设为 Disabled/Clamp（原版会给贴图设 Clamp，否则色阶两端会串色）。"
	return ""


## 逐通道插值：t 既可以是 float，也可以是 Vector3（原版 `lerp(vec3, vec3, vec3)` 的语义）。
static func _lerp3(a: Vector3, b: Vector3, t: Variant) -> Vector3:
	if t is Vector3:
		var tv := t as Vector3
		return Vector3(lerpf(a.x, b.x, tv.x), lerpf(a.y, b.y, tv.y), lerpf(a.z, b.z, tv.z))
	return a.lerp(b, float(t))


static func _to_rgba8(image: Image) -> Image:
	var out := Image.new()
	out.copy_from(image)
	if out.is_compressed():
		out.decompress()
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	return out


## 原版 lilTooningScale：border 两侧各 blur/2 的线性过渡。
static func _tooning(value: float, border: float, blur: float) -> float:
	var border_min := clampf(border - blur * 0.5, 0.0, 1.0)
	var border_max := clampf(border + blur * 0.5, 0.0, 1.0)
	return clampf((value - border_min) / maxf(border_max - border_min, 0.000001), 0.0, 1.0)


## 原版带 borderRange 的重载：下沿额外向左扩 borderRange。
static func _tooning_range(value: float, border: float, blur: float, border_range: float) -> float:
	var border_min := clampf(border - blur * 0.5 - border_range, 0.0, 1.0)
	var border_max := clampf(border + blur * 0.5, 0.0, 1.0)
	return clampf((value - border_min) / maxf(border_max - border_min, 0.000001), 0.0, 1.0)


## 材质上没写这个参数时（Godot 只在赋过值后才返回非 null），回落到 shader 声明的默认值。
static func _param_float(mat: ShaderMaterial, name: String) -> float:
	var value = mat.get_shader_parameter(name)
	if value == null:
		return float(PARAM_DEFAULTS.get(name, 0.0))
	return float(value)


static func _param_color(mat: ShaderMaterial, name: String) -> Color:
	var value = mat.get_shader_parameter(name)
	if value == null:
		return PARAM_DEFAULTS.get(name, Color(1, 1, 1, 1)) as Color
	return value as Color


## 从 uniforms.gdshaderinc 解析 `uniform <type> <name> ... = <default>;`，返回 name -> 值。
## 支持 float/int/bool/vec2/vec3/vec4（Ramp 与"修复光照"都用它回读默认值）；
## 解析失败的名字不会出现在结果里。
static func shader_defaults(path: String = UNIFORM_INCLUDE) -> Dictionary:
	var defaults := {}
	if not FileAccess.file_exists(path):
		return defaults
	var regex := RegEx.new()
	regex.compile("(?m)^\\s*uniform\\s+(float|int|bool|vec2|vec3|vec4)\\s+([A-Za-z0-9_]+)[^=;]*=\\s*([^;]+);")
	for result in regex.search_all(FileAccess.get_file_as_string(path)):
		var type_name := result.get_string(1)
		var param_name := result.get_string(2)
		var raw := result.get_string(3).strip_edges()
		if type_name == "bool":
			defaults[param_name] = raw.begins_with("true")
		elif type_name == "vec4" or type_name == "vec3" or type_name == "vec2":
			var inner := raw
			var open := raw.find("(")
			var close := raw.rfind(")")
			if open >= 0 and close > open:
				inner = raw.substr(open + 1, close - open - 1)
			var parts := inner.split(",")
			var values: Array[float] = []
			for part in parts:
				values.append(float(part.strip_edges()))
			if type_name == "vec4" and values.size() >= 4:
				defaults[param_name] = Color(values[0], values[1], values[2], values[3])
			elif type_name == "vec3" and values.size() >= 3:
				defaults[param_name] = Vector3(values[0], values[1], values[2])
			elif type_name == "vec2" and values.size() >= 2:
				defaults[param_name] = Vector2(values[0], values[1])
		else:
			defaults[param_name] = float(raw)
	return defaults
