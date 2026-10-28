@tool
class_name LiltoonPresetImport
extends RefCounted
## liltoon 预设（Unity YAML .asset）导入：解析 colors / vectors / floats，
## 按名称映射到本插件的 uniform，并只写入目标材质真实存在的参数。

## 常见名称的显式别名（liltoon -> 本插件）。
const ALIASES := {
	"color": "main_color",
	"shadowcolor": "shade_color",
	"maintex": "main_texture",
	"bumpmap": "normal_texture",
	"matcapcolor": "matcap_color",
	"rimcolor": "rim_color",
	"emissioncolor": "emission_color",
	"cutoff": "alpha_cutoff",
	"outlinewidth": "outline_width",
	"outlinecolor": "outline_color",
	"useshadow2nd": "use_shade_2nd",
	"useshadow3rd": "use_shade_3rd",
	"shadow2ndcolor": "shade_2nd_color",
	"shadow3rdcolor": "shade_3rd_color",
	"rimpower": "rim_power",
	"rimintensity": "rim_intensity",
	# "speculartex" 无对应项：原版的高光贴图属于反射组（_SpecularToon / _SpecularBlur），
	# 本项目受 Godot SPECULAR 为标量的限制未实现该组，导入时跳过而不是写一个不存在的参数名。
	"specularcolor": "specular_color",
	"specularsize": "specular_size",
	"shadowborder": "shade_threshold",
	"shadowblur": "shade_blur",
	"shadowstrength": "shadow_strength",
	"shadow2ndborder": "shade_2nd_threshold",
	"shadow3rdborder": "shade_3rd_threshold",
	"rimfresnelpower": "rim_power",
	"emissionstrength": "emission_intensity",
	"matcaptex": "matcap_texture",
	"matcap2ndtex": "matcap_texture_2nd",
	"matcap3rdtex": "matcap_texture_3rd",
	"main2ndtex": "decal_2nd_texture",
	"main3rdtex": "decal_3rd_texture",
	"main2ndblend": "decal_2nd_strength",
	"main3rdblend": "decal_3rd_strength",
	"main2ndtexscrollrotate": "decal_2nd_uv_scroll",
	"main3rdtexscrollrotate": "decal_3rd_uv_scroll",
	"emission2ndmap": "emission_2nd_texture",
	"emission2ndblend": "emission_2nd_blend_mode",
	"emission2ndblendmask": "emission_2nd_mask",
	"emission2ndmainstrength": "emission_2nd_intensity",
	"rimblur": "rim_blur",
	"rimborder": "rim_border",
	"rimdirstrength": "rim_dir_strength",
	"rimdirrange": "rim_dir_range",
	"rimindirrange": "rim_indir_range",
	"rimindirborder": "rim_indir_border",
	"rimindirblur": "rim_indir_blur",
	"rimenablelighting": "rim_enable_lighting",
	"rimmainstrength": "rim_main_strength",
	"rimindircolor": "rim_indir_color",
	"rimindirstrength": "rim_indir_strength",
	"rimshadowmask": "rim_shadow_mask",
	"matcaplod": "matcap_lod",
	"matcapnormalstrength": "matcap_normal_strength",
	"matcapmainstrength": "matcap_main_strength",
	"main2nddissolvenoisestrength": "decal_2nd_dissolve_strength",
	"main3rddissolvenoisestrength": "decal_3rd_dissolve_strength",
	"main2ndenablelighting": "decal_2nd_enable_lighting",
	"main3rdenablelighting": "decal_3rd_enable_lighting",
	"matcap2ndcolor": "matcap_2nd_color",
	"matcap3rdcolor": "matcap_3rd_color",
	"matcap2ndnormalstrength": "matcap_2nd_normal_strength",
	"matcap3rdnormalstrength": "matcap_3rd_normal_strength",
	"main2ndtexuvmode": "decal_2nd_uv_mode",
	"main3rdtexuvmode": "decal_3rd_uv_mode",
	"outlinefixwidth": "outline_fix_width",
	"outlineapplytransparency": "outline_apply_transparency",
	"emissionblink": "emission_blink_strength",
	"shadowreceive": "shadow_receive",
	"monochromelighting": "monochrome_lighting",
	"main2ndblendmask": "decal_2nd_mask",
	"main3rdblendmask": "decal_3rd_mask",
	"main2ndtexangle": "decal_2nd_uv_rotate",
	"main3rdtexangle": "decal_3rd_uv_rotate",
	"main2ndtexblendmode": "decal_2nd_blend_mode",
	"main3rdtexblendmode": "decal_3rd_blend_mode",
	"usemain2ndtex": "use_decal_2nd",
	"usemain3rdtex": "use_decal_3rd",
	"color2nd": "decal_2nd_color",
	"color3rd": "decal_3rd_color",
	"main2nddissolvecolor": "dissolve_color",
	"main3rddissolvecolor": "dissolve_color",
	"matcap2ndblend": "matcap_2nd_intensity",
	"matcap3rdblend": "matcap_3rd_intensity",
	"matcap2ndblendmask": "matcap_2nd_mask",
	"matcap3rdblendmask": "matcap_3rd_mask",
	"matcap2ndblendmode": "matcap_2nd_multiply",
	"matcap3rdblendmode": "matcap_3rd_multiply",
	"matcap2ndlod": "matcap_lod",
	"matcap3rdlod": "matcap_lod",
	"matcap2ndmainstrength": "matcap_main_strength",
	"matcap3rdmainstrength": "matcap_main_strength",
	"shadow2ndnormalstrength": "shade_normal_strength",
	"shadow3rdnormalstrength": "shade_normal_strength",
	"emission2ndblink": "emission_blink_strength",
	"bump2ndmap": "decal_2nd_normal_map",
	"bump2ndscale": "decal_2nd_normal_scale",
	"usebump2ndmap": "use_decal_2nd_normal",
	"bump3rdmap": "decal_3rd_normal_map",
	"bump3rdscale": "decal_3rd_normal_scale",
	"usebump3rdmap": "use_decal_3rd_normal",
	"matcap2ndbumpmap": "matcap_2nd_bump_map",
	"matcap2ndbumpscale": "matcap_2nd_bump_scale",
	"matcap3rdbumpmap": "matcap_3rd_bump_map",
	"matcap3rdbumpscale": "matcap_3rd_bump_scale",
	"shadow2ndcolortex": "shade_2nd_color_tex",
	"shadow3rdcolortex": "shade_3rd_color_tex",
	"shadow2ndreceive": "use_shade_2nd_receive",
	"shadow3rdreceive": "use_shade_3rd_receive",
	"glittercolor": "glitter_color",
	"glittermainstrength": "glitter_intensity",
	"glittersensitivity": "glitter_sensitivity",
	"glitterpostcontrast": "glitter_post_contrast",
	"glitterscalerandomize": "glitter_scale",
	"anisotropy": "anisotropy_specular_strength",
	"anisotropyshift": "anisotropy_shift",
	"anisotropyscale": "anisotropy_scale",
	"anisotropy2ndshift": "anisotropy_2nd_shift",
	"anisotropy2ndscale": "anisotropy_2nd_scale",
	"anisotropy2ndspecularstrength": "anisotropy_2nd_specular_strength",
	"anisotropy3rdshift": "anisotropy_3rd_shift",
	"anisotropy3rdscale": "anisotropy_3rd_scale",
	"anisotropy3rdspecularstrength": "anisotropy_3rd_specular_strength",
	"asunlit": "use_unlit",
	"applyreflection": "use_reflection",
	"flipnormal": "flip_normal",
	"shadownormalstrength": "shade_normal_strength",
	"shadow2ndblur": "shade_2nd_blur",
	"shadow3rdblur": "shade_3rd_blur",
}


static func parse_file(path: String) -> Dictionary:
	var result := {"colors": {}, "vectors": {}, "floats": {}, "outline": false, "name": path.get_file()}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return result
	var section := ""
	var pending := ""
	while not f.eof_reached():
		var line := f.get_line()
		var section_match := RegEx.create_from_string("^\\s{2}(colors|vectors|floats|textures):").search(line)
		if section_match != null:
			section = section_match.get_string(1)
			continue
		if line.begins_with("  outline:"):
			result["outline"] = line.contains("1")
			continue
		if section.is_empty():
			continue
		if RegEx.create_from_string("^  [A-Za-z]+:").search(line) != null and not line.contains("value:"):
			section = ""
			continue
		var name_match := RegEx.create_from_string("^\\s{2}- name:\\s*(\\S+)").search(line)
		if name_match != null:
			pending = name_match.get_string(1).trim_prefix("_")
			continue
		if pending.is_empty() or not line.contains("value:"):
			continue
		var value_text := line.substr(line.find("value:") + 6).strip_edges()
		var value = _parse_value(section, value_text)
		if value != null:
			result[section][pending] = value
		pending = ""
	f.close()
	return result


static func _parse_value(section: String, text: String) -> Variant:
	if section == "floats":
		return float(text)
	if section == "colors":
		var m := RegEx.create_from_string("r:\\s*(-?[0-9.eE+-]+).*?g:\\s*(-?[0-9.eE+-]+).*?b:\\s*(-?[0-9.eE+-]+).*?a:\\s*(-?[0-9.eE+-]+)").search(text)
		if m == null:
			return null
		return Color(float(m.get_string(1)), float(m.get_string(2)), float(m.get_string(3)), float(m.get_string(4)))
	if section == "vectors":
		var m := RegEx.create_from_string("x:\\s*(-?[0-9.eE+-]+).*?y:\\s*(-?[0-9.eE+-]+).*?z:\\s*(-?[0-9.eE+-]+).*?w:\\s*(-?[0-9.eE+-]+)").search(text)
		if m == null:
			return null
		return Vector4(float(m.get_string(1)), float(m.get_string(2)), float(m.get_string(3)), float(m.get_string(4)))
	return null


static func _normalize(name: String) -> String:
	return name.replace("_", "").to_lower()


## 返回 { applied: {uniform: value}, skipped: [liltoon 名称], outline: bool }
static func map_to_material(parsed: Dictionary, mat: ShaderMaterial) -> Dictionary:
	var result := {"applied": {}, "skipped": [], "outline": bool(parsed.get("outline", false))}
	if mat == null or mat.shader == null:
		return result
	var uniforms := {}
	for item in mat.shader.get_shader_uniform_list(false):
		var uniform_name := str(item.get("name", ""))
		if uniform_name.is_empty():
			continue
		uniforms[_normalize(uniform_name)] = {
			"name": uniform_name,
			"type": int(item.get("type", TYPE_NIL)),
		}
	for section in ["colors", "vectors", "floats"]:
		var entries: Dictionary = parsed.get(section, {})
		for source_name in entries:
			var key := _normalize(source_name)
			var target := ""
			if ALIASES.has(key):
				target = ALIASES[key]
			elif uniforms.has(key):
				target = uniforms[key]["name"]
			else:
				result["skipped"].append(source_name)
				continue
			var target_key := _normalize(target)
			if not uniforms.has(target_key):
				result["skipped"].append(source_name)
				continue
			var value: Variant = entries[source_name]
			var converted = _convert(value, uniforms[target_key]["type"])
			if converted == null:
				result["skipped"].append(source_name)
				continue
			result["applied"][uniforms[target_key]["name"]] = converted
	return result


static func _convert(value: Variant, target_type: int) -> Variant:
	if target_type == TYPE_COLOR:
		return value if value is Color else null
	if target_type == TYPE_VECTOR2 and value is Vector4:
		return Vector2(value.x, value.y)
	if target_type == TYPE_VECTOR3 and value is Vector4:
		return Vector3(value.x, value.y, value.z)
	if target_type == TYPE_BOOL and (value is float or value is int):
		return float(value) > 0.5
	if target_type == TYPE_INT and (value is float or value is int):
		return int(value)
	if target_type == TYPE_FLOAT and (value is float or value is int):
		return float(value)
	return null