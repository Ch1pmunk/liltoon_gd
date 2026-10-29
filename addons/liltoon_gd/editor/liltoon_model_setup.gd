class_name LiltoonModelSetup
extends RefCounted
## 对齐 lilToon 的「Setup from FBX」（原版 `lilToonEditorUtils.cs:233-300` + `SetUpMaterial:308`）。
##
## 原版做的事：为模型里的每个材质建 `.mat`（放在模型同目录的 `Materials/`），
## 换 lilToon shader，按材质名找主贴图/阴影强度遮罩/描边宽度遮罩，
## 再按名字关键词套预设（face / body|skin / hair / 其它=cloth），最后重映射导入材质。
##
## Godot 侧等价范围：
## - ✅ 逐 surface 建 liltoon 材质（`StandardMaterial3D` 走现有转换器，参数尽量映射）
## - ✅ 按材质名关键词套预设、默认开描边、材质名规范化
## - ✅ 落盘到 `Materials/` 子目录（模型场景同目录）
## - ❌ 导入期材质重映射（`ModelImporter.SearchAndRemapMaterials`）：Godot 的模型导入由
##   引擎导入器负责，插件没有等价钩子 → 登记为引擎限制
## - ❌ 按名字猜贴图（`t:texture2d` 全库搜索）：Godot 的 `StandardMaterial3D` 已带贴图引用，
##   转换器会直接继承，无需按名字猜


const Presets := preload("res://addons/liltoon_gd/editor/preset_library.gd")
const Tools := preload("res://addons/liltoon_gd/editor/liltoon_tools.gd")
const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")


## 材质名 → 预设名。对应原版 `SetUpMaterial` 的关键词判断。
## 差异：原版有独立的「面部」预设，本项目预设库只有 默认/皮肤/头发/布料/金属，面部取最近的「皮肤」。
static func preset_for_material_name(material_name: String) -> String:
	var name_lower := material_name.to_lower()
	if name_lower.contains("hair") or name_lower.contains("头发") or name_lower.contains("毛"):
		return "头发"
	if name_lower.contains("metal") or name_lower.contains("金属"):
		return "金属"
	if name_lower.contains("face") or name_lower.contains("面部"):
		return "皮肤"
	if name_lower.contains("body") or name_lower.contains("skin") or name_lower.contains("皮肤") or name_lower.contains("身体"):
		return "皮肤"
	return "布料"


## 收集节点树里的全部网格 surface：[{node, surface, material}]
static func collect_surfaces(root: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_collect(root, out)
	return out


## 为单个 surface 建材质（不写盘、不改场景）。返回 {material, name, preset, skipped, warnings}
static func build_material_for_surface(entry: Dictionary) -> Dictionary:
	var node: Node = entry["node"]
	var surface: int = entry["surface"]
	var existing: Material = entry["material"]
	var material_name := _material_name(existing, node, surface)

	if existing is ShaderMaterial and Tools.is_liltoon_material(existing):
		return {"material": existing, "name": material_name, "preset": "", "skipped": true,
			"warnings": PackedStringArray()}

	var warnings := PackedStringArray()
	var mat: ShaderMaterial
	if existing is BaseMaterial3D:
		var converted: Dictionary = Tools.convert_standard_material_ex(existing as BaseMaterial3D)
		mat = converted["material"]
		for item in converted["warnings"]:
			warnings.append(item)
	elif existing is ShaderMaterial:
		mat = Factory.create_opaque()
		warnings.append("原材质使用非 liltoon shader，参数无法映射，已用默认参数新建")
	else:
		mat = Factory.create_opaque()

	var preset := preset_for_material_name(material_name)
	Presets.apply_to_material(mat, preset)
	Factory.set_outline_enabled(mat, true)
	mat.resource_name = material_name
	return {"material": mat, "name": material_name, "preset": preset, "skipped": false, "warnings": warnings}


## 材质落盘目录：优先用所属场景（模型）同目录的 `Materials/`，否则用 `res://materials/model_setup`。
static func save_dir_for(node: Node) -> String:
	var scene_path := ""
	if node != null:
		if node.owner != null and node.owner.scene_file_path != "":
			scene_path = node.owner.scene_file_path
		elif node.scene_file_path != "":
			scene_path = node.scene_file_path
	if scene_path != "":
		return scene_path.get_base_dir().path_join("Materials")
	return "res://materials/model_setup"


static func _collect(node: Node, out: Array[Dictionary]) -> void:
	var mesh_inst := node as MeshInstance3D
	if mesh_inst != null and mesh_inst.mesh != null:
		for index in mesh_inst.mesh.get_surface_count():
			out.append({
				"node": mesh_inst,
				"surface": index,
				"material": mesh_inst.get_active_material(index),
			})
	for child in node.get_children():
		_collect(child, out)


static func _material_name(existing: Material, node: Node, surface: int) -> String:
	if existing != null:
		if existing.resource_path != "":
			return existing.resource_path.get_file().get_basename()
		if existing.resource_name != "":
			return existing.resource_name
	var owner_name := "material"
	if node != null and node.name != "":
		owner_name = String(node.name)
	return "%s_%d" % [owner_name, surface]
