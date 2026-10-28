@tool
class_name LiltoonMaterialTools
extends RefCounted
## 材质批量替换：把选中网格上使用「源材质」的槽位替换成「目标材质」。


## 返回替换的槽位数量。源材质取第一个选中网格的 material_override，
## 若没有 override 则取第 0 个面的材质。
static func replace_in_selection(selection: EditorSelection, target: Material) -> int:
	if selection == null or target == null:
		return 0
	var nodes := selection.get_selected_nodes()
	if nodes.is_empty():
		return 0
	var source := _first_material(nodes[0])
	if source == null:
		return 0
	var entries: Array = []
	for node in nodes:
		if not (node is MeshInstance3D):
			continue
		var mi := node as MeshInstance3D
		if mi.material_override == source:
			entries.append([mi, -1])
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			if mi.get_surface_override_material(i) == source:
				entries.append([mi, i])
	if entries.is_empty():
		return 0
	if EditorInterface.has_method("get_editor_undo_redo"):
		var ur: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
		ur.create_action("批量替换材质", UndoRedo.MERGE_DISABLE, entries[0][0])
		for entry in entries:
			var mi: MeshInstance3D = entry[0]
			var index: int = entry[1]
			if index < 0:
				ur.add_do_method(mi, "set_material_override", target)
				ur.add_undo_method(mi, "set_material_override", source)
			else:
				ur.add_do_method(mi, "set_surface_override_material", index, target)
				ur.add_undo_method(mi, "set_surface_override_material", index, source)
		ur.commit_action()
	else:
		for entry in entries:
			var mi: MeshInstance3D = entry[0]
			var index: int = entry[1]
			if index < 0:
				mi.material_override = target
			else:
				mi.set_surface_override_material(index, target)
	EditorInterface.mark_scene_as_unsaved()
	return entries.size()


static func _first_material(node: Node) -> Material:
	if not (node is MeshInstance3D):
		return null
	var mi := node as MeshInstance3D
	if mi.material_override != null:
		return mi.material_override
	if mi.mesh != null and mi.mesh.get_surface_count() > 0:
		return mi.get_active_material(0)
	return null
