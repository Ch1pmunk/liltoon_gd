class_name LiltoonMultiEditor
extends RefCounted
## 对齐 lilToon 的「Multi-Editor」（原版 `Editor/lilInspector/lilInspector.cs:152` 的
## `[Beta] lilToon Multi-Editor` 窗口）：一次给多个材质设同一个参数。
##
## 复刻范围：
## - 取选中材质 shader 参数的**交集**（只有所有材质都有的参数才能批量改，避免把值写到不存在的键上）
## - 按参数类型解析输入的文本值（bool / int / float / Color / Vector2-4 / 贴图路径）
## - 应用到全部 + 撤销（撤销逻辑在插件里用 EditorUndoRedoManager 完成）
##
## 与原版的差异：原版是完整 Inspector 的镜像面板（分组、滑条、贴图槽一应俱全）；
## 这里是「参数名 + 文本值」的精简形式，够批量改数值/颜色，不做分组与控件镜像。


## 选中材质共有的参数名（保持首个材质的声明顺序）。
static func common_parameters(materials: Array) -> Array[String]:
	var result: Array[String] = []
	var first := _first_valid(materials)
	if first == null:
		return result
	for item in first.shader.get_shader_uniform_list(false):
		var uniform_name := String(item.get("name", ""))
		if uniform_name == "":
			continue
		var everywhere := true
		for material in materials:
			var mat := material as ShaderMaterial
			if mat == null or mat.shader == null or not has_parameter(mat, uniform_name):
				everywhere = false
				break
		if everywhere:
			result.append(uniform_name)
	return result


## 某材质是否声明了该参数。
static func has_parameter(mat: ShaderMaterial, uniform_name: String) -> bool:
	if mat == null or mat.shader == null:
		return false
	for item in mat.shader.get_shader_uniform_list(false):
		if String(item.get("name", "")) == uniform_name:
			return true
	return false


## 参数类型（取首个声明该参数的材质）。返回 Variant.Type，找不到返回 TYPE_NIL。
static func parameter_type(materials: Array, uniform_name: String) -> int:
	for material in materials:
		var mat := material as ShaderMaterial
		if mat == null or mat.shader == null:
			continue
		for item in mat.shader.get_shader_uniform_list(false):
			if String(item.get("name", "")) == uniform_name:
				return int(item.get("type", TYPE_NIL))
	return TYPE_NIL


## 把用户输入解析成指定类型的值。返回 {ok, value, error}
static func parse_value(text: String, type: int) -> Dictionary:
	var trimmed := text.strip_edges()
	if trimmed == "":
		return {"ok": false, "value": null, "error": "值为空"}
	match type:
		TYPE_BOOL:
			var lower := trimmed.to_lower()
			if lower in ["true", "1", "是", "开", "on"]:
				return {"ok": true, "value": true, "error": ""}
			if lower in ["false", "0", "否", "关", "off"]:
				return {"ok": true, "value": false, "error": ""}
			return {"ok": false, "value": null, "error": "布尔值只接受 true/false"}
		TYPE_INT:
			if not trimmed.is_valid_int():
				return {"ok": false, "value": null, "error": "需要一个整数"}
			return {"ok": true, "value": int(trimmed), "error": ""}
		TYPE_FLOAT:
			if not trimmed.is_valid_float():
				return {"ok": false, "value": null, "error": "需要一个小数"}
			return {"ok": true, "value": float(trimmed), "error": ""}
		TYPE_COLOR:
			if trimmed.begins_with("#") and Color.html_is_valid(trimmed):
				return {"ok": true, "value": Color.html(trimmed), "error": ""}
			var color_value = str_to_var(trimmed)
			if color_value is Color:
				return {"ok": true, "value": color_value, "error": ""}
			return {"ok": false, "value": null, "error": "需要颜色，例如 Color(1,0,0,1) 或 #ff0000"}
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I:
			var vector_value = str_to_var(trimmed)
			if vector_value != null and typeof(vector_value) == type:
				return {"ok": true, "value": vector_value, "error": ""}
			return {"ok": false, "value": null, "error": "需要向量，例如 Vector3(1,0,0)"}
		TYPE_OBJECT:
			if not trimmed.begins_with("res://"):
				return {"ok": false, "value": null, "error": "贴图需要 res:// 路径"}
			if not ResourceLoader.exists(trimmed):
				return {"ok": false, "value": null, "error": "资源不存在：%s" % trimmed}
			return {"ok": true, "value": load(trimmed), "error": ""}
		TYPE_NIL:
			return {"ok": false, "value": null, "error": "参数类型未知，无法解析"}
		_:
			return {"ok": false, "value": null, "error": "暂不支持该类型（%d）" % type}


## 值的可读描述，用于窗口回显。
static func value_to_text(value) -> String:
	if value == null:
		return "null"
	return var_to_str(value)


static func _first_valid(materials: Array) -> ShaderMaterial:
	for material in materials:
		var mat := material as ShaderMaterial
		if mat != null and mat.shader != null:
			return mat
	return null
