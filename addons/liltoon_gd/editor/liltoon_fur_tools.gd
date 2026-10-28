@tool
class_name LiltoonFurTools
extends RefCounted
## 毛发壳层的编辑器入口：为选中网格生成/同步 MultiMesh 壳层。

const FurHelper := preload("res://addons/liltoon_gd/liltoon_fur.gd")


static func add_to_selection(selection: EditorSelection, layers: int = 6, transparent: bool = false) -> int:
	var added := 0
	if selection == null:
		return 0
	for node in selection.get_selected_nodes():
		if not (node is MeshInstance3D):
			continue
		var mi := node as MeshInstance3D
		var shell_name := String(mi.name) + "_Fur"
		if mi.get_node_or_null(shell_name) != null:
			continue
		var shells := FurHelper.create_shells(mi, layers, transparent)
		if shells == null:
			continue
		if EditorInterface.has_method("get_editor_undo_redo"):
			var ur: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
			ur.create_action("添加毛发壳层", UndoRedo.MERGE_DISABLE, mi)
			ur.add_do_method(mi, "add_child", shells)
			ur.add_do_method(shells, "set_owner", mi.owner)
			ur.add_do_reference(shells)
			ur.add_undo_method(mi, "remove_child", shells)
			ur.commit_action()
		else:
			mi.add_child(shells)
			shells.owner = mi.owner
		EditorInterface.mark_scene_as_unsaved()
		added += 1
	return added


static func sync_selection(selection: EditorSelection) -> int:
	var synced := 0
	if selection == null:
		return 0
	for node in selection.get_selected_nodes():
		if not (node is MeshInstance3D):
			continue
		var mi := node as MeshInstance3D
		var shells := mi.get_node_or_null(String(mi.name) + "_Fur") as MultiMeshInstance3D
		if shells != null:
			FurHelper.sync_params(mi, shells)
			synced += 1
	return synced

## 预设/重置后：把主体的毛发参数同步到场景里使用该材质的壳层。
static func sync_for_material(mat: ShaderMaterial) -> int:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or mat == null:
		return 0
	return _sync_in_node(root, mat)


static func _sync_in_node(node: Node, mat: ShaderMaterial) -> int:
	var count := 0
	if node is MeshInstance3D and (node as MeshInstance3D).material_override == mat:
		var mi := node as MeshInstance3D
		var shells := mi.get_node_or_null(String(mi.name) + "_Fur") as MultiMeshInstance3D
		if shells != null:
			FurHelper.sync_params(mi, shells)
			FurHelper.copy_fur_params(mat, shells.material_override as ShaderMaterial)
			count += 1
	for child in node.get_children():
		count += _sync_in_node(child, mat)
	return count
