class_name LiltoonQuality
extends RefCounted
## 质量档位：通过关闭高成本特性来降负载。Godot 没有 Unity 的关键字变体，
## 因此这里用参数开关代替“变体裁剪”，不改变 shader 文件。
##
## 注意：后处理描边是场景级效果，不在材质参数里，需要调用方自行隐藏四边形。

const TIER_HIGH := "high"
const TIER_MEDIUM := "medium"
const TIER_LOW := "low"

const SETTINGS := {
	TIER_HIGH: {
		"use_specular": true,
		"use_rim": true,
		"use_matcap": false,
		"use_sss": false,
		"use_dissolve": false,
		"use_normal_map": true,
		"use_ao_map": true,
	},
	TIER_MEDIUM: {
		"use_specular": true,
		"use_rim": false,
		"use_matcap": false,
		"use_sss": false,
		"use_dissolve": false,
		"use_normal_map": true,
		"use_ao_map": true,
	},
	TIER_LOW: {
		"use_specular": false,
		"use_rim": false,
		"use_matcap": false,
		"use_sss": false,
		"use_dissolve": false,
		"use_normal_map": false,
		"use_ao_map": false,
	},
}


static func apply(mat: ShaderMaterial, tier: String) -> void:
	if mat == null or not SETTINGS.has(tier):
		return
	var values: Dictionary = SETTINGS[tier]
	for key in values:
		mat.set_shader_parameter(key, values[key])


static func tiers() -> Array:
	return [TIER_HIGH, TIER_MEDIUM, TIER_LOW]
