@tool
class_name LiltoonMaterialFactory
extends RefCounted
## 材质工厂：按透明度变体创建材质，并管理 next_pass 描边与描边变体切换。

const OPAQUE_SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_opaque.gdshader")
const CUTOUT_SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_cutout.gdshader")
const TRANSPARENT_SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_transparent.gdshader")
const OPAQUE_DOUBLE_SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_opaque_double.gdshader")
const CUTOUT_DOUBLE_SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_cutout_double.gdshader")
const TRANSPARENT_DOUBLE_SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_transparent_double.gdshader")
const TRANSPARENT_PREMUL_SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_transparent_premul.gdshader")
const OUTLINE_SHADER := preload("res://addons/liltoon_gd/shaders/liltoon_outline.gdshader")

const OPAQUE_FRONT_PATH := "res://addons/liltoon_gd/shaders/liltoon_opaque_front.gdshader"
const CUTOUT_FRONT_PATH := "res://addons/liltoon_gd/shaders/liltoon_cutout_front.gdshader"
const TRANSPARENT_FRONT_PATH := "res://addons/liltoon_gd/shaders/liltoon_transparent_front.gdshader"
const OUTLINE_LIT_SHADER_PATH := "res://addons/liltoon_gd/shaders/liltoon_outline_lit.gdshader"
const OUTLINE_TRANSPARENT_SHADER_PATH := "res://addons/liltoon_gd/shaders/liltoon_outline_transparent.gdshader"
# 描边变体是「受光 × 透明 × 预乘」的三维组合，原版两个开关可自由搭配。
const OUTLINE_LIT_TRANSPARENT_SHADER_PATH := "res://addons/liltoon_gd/shaders/liltoon_outline_lit_transparent.gdshader"
const OUTLINE_TRANSPARENT_PREMUL_SHADER_PATH := "res://addons/liltoon_gd/shaders/liltoon_outline_transparent_premul.gdshader"
const OUTLINE_LIT_TRANSPARENT_PREMUL_SHADER_PATH := "res://addons/liltoon_gd/shaders/liltoon_outline_lit_transparent_premul.gdshader"

# Alpha To Coverage：仅 Cutout 支持，按渲染面分出三个变体（对齐 liltoon 的 _AlphaToMask）。
const CUTOUT_A2C_SHADER_PATH := "res://addons/liltoon_gd/shaders/liltoon_cutout_a2c.gdshader"
const CUTOUT_A2C_DOUBLE_PATH := "res://addons/liltoon_gd/shaders/liltoon_cutout_a2c_double.gdshader"
const CUTOUT_A2C_FRONT_PATH := "res://addons/liltoon_gd/shaders/liltoon_cutout_a2c_front.gdshader"

const DEFAULT_OUTLINE_WIDTH := 0.012

static var _outline_cache: Dictionary = {}


static func create_opaque() -> ShaderMaterial:
	return _make(OPAQUE_SHADER)


static func create_cutout() -> ShaderMaterial:
	return _make(CUTOUT_SHADER)


static func create_transparent() -> ShaderMaterial:
	return _make(TRANSPARENT_SHADER)


static func create_opaque_double() -> ShaderMaterial:
	return _make(OPAQUE_DOUBLE_SHADER)


static func create_cutout_double() -> ShaderMaterial:
	return _make(CUTOUT_DOUBLE_SHADER)


static func create_transparent_double() -> ShaderMaterial:
	return _make(TRANSPARENT_DOUBLE_SHADER)


static func create_transparent_premul() -> ShaderMaterial:
	return _make(TRANSPARENT_PREMUL_SHADER)


static func _make(shader: Shader) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


## 0=不透明、1=Cutout、2=透明、-1=不支持切换（如预乘透明）。
static func shader_family(shader: Shader) -> int:
	if shader == null:
		return -1
	var path := shader.resource_path
	if shader == OPAQUE_SHADER or shader == OPAQUE_DOUBLE_SHADER or path == OPAQUE_FRONT_PATH:
		return 0
	if shader == CUTOUT_SHADER or shader == CUTOUT_DOUBLE_SHADER or path == CUTOUT_FRONT_PATH:
		return 1
	if is_alpha_to_mask_shader(path):
		return 1
	if shader == TRANSPARENT_SHADER or shader == TRANSPARENT_DOUBLE_SHADER or path == TRANSPARENT_FRONT_PATH:
		return 2
	return -1


static func _single_shader(family: int) -> Shader:
	match family:
		0:
			return OPAQUE_SHADER
		1:
			return CUTOUT_SHADER
		2:
			return TRANSPARENT_SHADER
	return null


static func _double_shader(family: int) -> Shader:
	match family:
		0:
			return OPAQUE_DOUBLE_SHADER
		1:
			return CUTOUT_DOUBLE_SHADER
		2:
			return TRANSPARENT_DOUBLE_SHADER
	return null


static func front_shader(family: int) -> Shader:
	var path := ""
	match family:
		0:
			path = OPAQUE_FRONT_PATH
		1:
			path = CUTOUT_FRONT_PATH
		2:
			path = TRANSPARENT_FRONT_PATH
	if path.is_empty():
		return null
	return load(path)


## mode：0=单面、1=双面、2=仅背面。
static func with_cull_mode(shader: Shader, mode: int) -> Shader:
	var family := shader_family(shader)
	if family < 0:
		return shader
	# Cutout 的 A2C 变体独立于渲染面，切换渲染面时必须保留 alpha_to_coverage。
	if alpha_to_mask_of(shader):
		var a2c := _alpha_to_mask_shader(mode)
		return a2c if a2c != null else shader
	if mode == 1:
		var double_shader := _double_shader(family)
		return double_shader if double_shader != null else shader
	if mode == 2:
		var front := front_shader(family)
		return front if front != null else shader
	var single := _single_shader(family)
	return single if single != null else shader


static func cull_mode_of(shader: Shader) -> int:
	if shader == null:
		return 0
	if shader == OPAQUE_DOUBLE_SHADER or shader == CUTOUT_DOUBLE_SHADER or shader == TRANSPARENT_DOUBLE_SHADER:
		return 1
	var path := shader.resource_path
	if path == OPAQUE_FRONT_PATH or path == CUTOUT_FRONT_PATH or path == TRANSPARENT_FRONT_PATH:
		return 2
	if path == CUTOUT_A2C_DOUBLE_PATH:
		return 1
	if path == CUTOUT_A2C_FRONT_PATH:
		return 2
	return 0


static func create_outline_material(width: float = DEFAULT_OUTLINE_WIDTH, transparent: bool = false, premul: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var path := _outline_shader_path(false, transparent, premul)
	var shader: Shader = load(path) if not path.is_empty() else OUTLINE_SHADER
	mat.shader = shader if shader != null else OUTLINE_SHADER
	mat.set_shader_parameter("outline_width", width)
	if transparent:
		mat.set_shader_parameter("outline_apply_transparency", true)
	return mat


## 预乘材质（透明预乘变体）的描边也必须用预乘混合，否则重叠处会发灰。
static func is_premultiplied_shader(shader: Shader) -> bool:
	return shader == TRANSPARENT_PREMUL_SHADER


static func outline_premultiplied(mat: ShaderMaterial) -> bool:
	return mat != null and is_premultiplied_shader(mat.shader)


static func get_outline_material(mat: ShaderMaterial) -> ShaderMaterial:
	if mat == null:
		return null
	return mat.next_pass as ShaderMaterial


static func outline_enabled(mat: ShaderMaterial) -> bool:
	return get_outline_material(mat) != null


static func set_outline_enabled(mat: ShaderMaterial, enabled: bool, width: float = DEFAULT_OUTLINE_WIDTH) -> void:
	if mat == null:
		return
	if enabled:
		if mat.next_pass is ShaderMaterial:
			sync_outline_distance_fade(mat)
			return
		var cached: ShaderMaterial = null
		var ref = _outline_cache.get(mat.get_instance_id())
		if ref is WeakRef:
			cached = ref.get_ref() as ShaderMaterial
		var premul := is_premultiplied_shader(mat.shader)
		if cached != null:
			# 缓存可能来自另一种主材质变体，先按当前主材质重选描边变体。
			var cached_transparent := _bool_param(cached, "outline_apply_transparency") or premul
			_apply_outline_shader(cached, _bool_param(cached, "outline_enable_lighting"), cached_transparent, premul)
			mat.next_pass = cached
		else:
			mat.next_pass = create_outline_material(width, premul, premul)
		_outline_cache.erase(mat.get_instance_id())
		sync_outline_distance_fade(mat)
	else:
		if mat.next_pass is ShaderMaterial:
			_outline_cache[mat.get_instance_id()] = weakref(mat.next_pass)
		mat.next_pass = null


static func sync_outline_distance_fade(mat: ShaderMaterial) -> void:
	var outline := get_outline_material(mat)
	if outline == null:
		return
	for key in ["use_distance_fade", "distance_fade_near", "distance_fade_far", "distance_fade_strength"]:
		outline.set_shader_parameter(key, mat.get_shader_parameter(key))


## 按受光/透明/预乘三轴选择描边变体路径；空字符串表示默认的 unlit-opaque。
static func _outline_shader_path(lighting: bool, transparent: bool, premul: bool) -> String:
	if transparent:
		if premul:
			return OUTLINE_LIT_TRANSPARENT_PREMUL_SHADER_PATH if lighting else OUTLINE_TRANSPARENT_PREMUL_SHADER_PATH
		return OUTLINE_LIT_TRANSPARENT_SHADER_PATH if lighting else OUTLINE_TRANSPARENT_SHADER_PATH
	if lighting:
		return OUTLINE_LIT_SHADER_PATH
	return ""


## 按受光/透明/预乘开关选择描边变体，并保留现有参数。
static func _apply_outline_shader(outline: ShaderMaterial, lighting: bool, transparent: bool, premul: bool) -> void:
	var values := {}
	if outline.shader != null:
		for item in outline.shader.get_shader_uniform_list():
			var key: String = item["name"]
			var value = outline.get_shader_parameter(key)
			if value != null:
				values[key] = value
	var path := _outline_shader_path(lighting, transparent, premul)
	var shader: Shader = OUTLINE_SHADER
	if not path.is_empty():
		var loaded: Shader = load(path)
		if loaded != null:
			shader = loaded
	outline.shader = shader
	for key in values:
		outline.set_shader_parameter(key, values[key])


## get_shader_parameter 在未显式赋值时返回 null，直接 bool(null) 会抛错，这里统一兜底。
static func _bool_param(material: ShaderMaterial, key: String, fallback: bool = false) -> bool:
	if material == null:
		return fallback
	var value = material.get_shader_parameter(key)
	return value if value is bool else fallback


static func set_outline_lighting(mat: ShaderMaterial, enabled: bool) -> void:
	var outline := get_outline_material(mat)
	if outline == null:
		return
	var transparent := _bool_param(outline, "outline_apply_transparency")
	_apply_outline_shader(outline, enabled, transparent, transparent and outline_premultiplied(mat))
	outline.set_shader_parameter("outline_enable_lighting", enabled)


static func set_outline_transparency(mat: ShaderMaterial, enabled: bool) -> void:
	var outline := get_outline_material(mat)
	if outline == null:
		return
	var lighting := _bool_param(outline, "outline_enable_lighting")
	_apply_outline_shader(outline, lighting, enabled, enabled and outline_premultiplied(mat))
	outline.set_shader_parameter("outline_apply_transparency", enabled)


static func create_cutout_a2c() -> ShaderMaterial:
	var shader: Shader = load(CUTOUT_A2C_SHADER_PATH)
	return _make(shader if shader != null else CUTOUT_SHADER)


## 是否使用 alpha_to_coverage 变体（Cutout 的 MSAA Alpha 抗锯齿）。
static func alpha_to_mask_of(shader: Shader) -> bool:
	if shader == null:
		return false
	return is_alpha_to_mask_shader(shader.resource_path)


static func is_alpha_to_mask_shader(path: String) -> bool:
	return path == CUTOUT_A2C_SHADER_PATH or path == CUTOUT_A2C_DOUBLE_PATH or path == CUTOUT_A2C_FRONT_PATH


static func _alpha_to_mask_shader(mode: int) -> Shader:
	var path := CUTOUT_A2C_SHADER_PATH
	match mode:
		1:
			path = CUTOUT_A2C_DOUBLE_PATH
		2:
			path = CUTOUT_A2C_FRONT_PATH
	return load(path)


## 保留当前渲染面，只切换 alpha_to_coverage；非 Cutout 变体原样返回。
static func with_alpha_to_mask(shader: Shader, enabled: bool) -> Shader:
	if shader == null or shader_family(shader) != 1:
		return shader
	if enabled:
		var a2c := _alpha_to_mask_shader(cull_mode_of(shader))
		return a2c if a2c != null else shader
	var single := with_cull_mode(CUTOUT_SHADER, cull_mode_of(shader))
	return single if single != null else shader


## 切换材质的 Alpha To Coverage；返回是否真的切换（非 Cutout 变体返回 false）。
static func set_alpha_to_mask(mat: ShaderMaterial, enabled: bool) -> bool:
	if mat == null or mat.shader == null:
		return false
	if shader_family(mat.shader) != 1:
		return false
	var target := with_alpha_to_mask(mat.shader, enabled)
	if target == null or target == mat.shader:
		return false
	mat.shader = target
	return true