@tool
extends EditorPlugin

const InspectorPlugin := preload("res://addons/liltoon_gd/editor/liltoon_inspector_plugin.gd")
const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")
const Presets := preload("res://addons/liltoon_gd/editor/preset_library.gd")
const Tools := preload("res://addons/liltoon_gd/editor/liltoon_tools.gd")
const FurTools := preload("res://addons/liltoon_gd/editor/liltoon_fur_tools.gd")
const MatTools := preload("res://addons/liltoon_gd/editor/liltoon_material_tools.gd")
const FurHelper := preload("res://addons/liltoon_gd/liltoon_fur.gd")
const TextureBaker := preload("res://addons/liltoon_gd/editor/liltoon_texture_baker.gd")
const Optimizer := preload("res://addons/liltoon_gd/editor/liltoon_optimizer.gd")
const Settings := preload("res://addons/liltoon_gd/editor/liltoon_setting.gd")
const Startup := preload("res://addons/liltoon_gd/editor/liltoon_startup.gd")

const MATERIAL_DIR := "res://materials"
const MATERIAL_BASE_NAME := "liltoon_material"

var _inspector_plugin: EditorInspectorPlugin


func _enter_tree() -> void:
	_inspector_plugin = InspectorPlugin.new()
	add_inspector_plugin(_inspector_plugin)
	# 启动检查（对应 lilStartup）：版本变化/首次安装时提示
	Settings.ensure_defaults()
	for tip in Startup.check():
		print("liltoon_gd 启动检查：", tip)
	add_tool_menu_item("liltoon_gd: 创建材质", _on_create_material)
	add_tool_menu_item("liltoon_gd: 转换选中材质（资源）", _on_convert_resources)
	add_tool_menu_item("liltoon_gd: 批量转换选中节点的材质", _on_convert_nodes)
	add_tool_menu_item("liltoon_gd: 校验并修复选中材质（资源）", _on_validate_resources)
	add_tool_menu_item("liltoon_gd: 为选中网格添加毛发壳层", _on_add_fur)
	add_tool_menu_item("liltoon_gd: 为选中网格添加透明毛发壳层", _on_add_fur_transparent)
	add_tool_menu_item("liltoon_gd: 同步选中网格的毛发参数", _on_sync_fur)
	add_tool_menu_item("liltoon_gd: 批量替换选中网格的材质…", _on_replace_material)
	add_tool_menu_item("liltoon_gd: 烘焙选中材质的主色贴图…", _on_bake_material)
	add_tool_menu_item("liltoon_gd: 分析选中材质的优化建议", _on_optimize_material)
	add_tool_menu_item("liltoon_gd: 全局设置…", _on_show_settings)


func _exit_tree() -> void:
	if _inspector_plugin != null:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null
	remove_tool_menu_item("liltoon_gd: 创建材质")
	remove_tool_menu_item("liltoon_gd: 转换选中材质（资源）")
	remove_tool_menu_item("liltoon_gd: 批量转换选中节点的材质")
	remove_tool_menu_item("liltoon_gd: 校验并修复选中材质（资源）")
	remove_tool_menu_item("liltoon_gd: 为选中网格添加毛发壳层")
	remove_tool_menu_item("liltoon_gd: 为选中网格添加透明毛发壳层")
	remove_tool_menu_item("liltoon_gd: 同步选中网格的毛发参数")
	remove_tool_menu_item("liltoon_gd: 批量替换选中网格的材质…")
	remove_tool_menu_item("liltoon_gd: 烘焙选中材质的主色贴图…")
	remove_tool_menu_item("liltoon_gd: 分析选中材质的优化建议")
	remove_tool_menu_item("liltoon_gd: 全局设置…")


func _on_create_material() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATERIAL_DIR))

	var path := _unique_material_path()
	var mat := Factory.create_opaque()
	Factory.set_outline_enabled(mat, true)
	Presets.apply_to_material(mat, "默认")

	var err := ResourceSaver.save(mat, path)
	if err != OK:
		push_error("liltoon_gd: 保存材质失败（错误码 %d）：%s" % [err, path])
		return

	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.edit_resource(mat)


func _unique_material_path() -> String:
	var path := MATERIAL_DIR.path_join("%s.tres" % MATERIAL_BASE_NAME)
	var index := 2
	while ResourceLoader.exists(path) or FileAccess.file_exists(path):
		path = MATERIAL_DIR.path_join("%s_%d.tres" % [MATERIAL_BASE_NAME, index])
		index += 1
	return path


# ============================================================================
# P4 工具链：材质转换 / 批量替换 / 校验修复
# ============================================================================


func _on_convert_resources() -> void:
	var converted := 0
	var skipped := 0
	var warnings := PackedStringArray()
	for path in EditorInterface.get_selected_paths():
		if not (path.ends_with(".tres") or path.ends_with(".res")):
			skipped += 1
			continue
		var res = load(path)
		if not (res is BaseMaterial3D) or Tools.is_liltoon_material(res):
			skipped += 1
			continue
		var result := Tools.convert_standard_material_ex(res as BaseMaterial3D)
		var mat: ShaderMaterial = result["material"]
		if ResourceSaver.save(mat, _converted_path(path)) == OK:
			converted += 1
			for item in result["warnings"]:
				warnings.append("%s：%s" % [path.get_file(), item])
		else:
			skipped += 1
	if converted > 0:
		EditorInterface.get_resource_filesystem().scan()
	var text := "已转换 %d 个材质（原文件保留）。\n跳过 %d 个。" % [converted, skipped]
	if not warnings.is_empty():
		text += "\n\n未完全等价的项：\n" + "\n".join(warnings)
	_show_dialog("liltoon_gd 材质转换", text)


func _converted_path(source_path: String) -> String:
	var base := source_path.get_basename() + "_liltoon"
	var path := base + ".tres"
	var index := 2
	while ResourceLoader.exists(path) or FileAccess.file_exists(path):
		path = "%s_%d.tres" % [base, index]
		index += 1
	return path


func _on_convert_nodes() -> void:
	var nodes := EditorInterface.get_selection().get_selected_nodes()
	if nodes.is_empty():
		_show_dialog("liltoon_gd 批量转换", "请先在场景树中选中节点。")
		return
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("liltoon_gd: 批量转换材质")
	var converted := 0
	var warnings := PackedStringArray()
	for node in nodes:
		converted += _convert_node_tree(node, undo, warnings)
	undo.commit_action()
	var text := "已替换 %d 个材质槽位（可撤销）。" % converted
	if not warnings.is_empty():
		text += "\n\n未完全等价的项：\n" + "\n".join(warnings)
	_show_dialog("liltoon_gd 批量转换", text)


func _convert_node_tree(node: Node, undo: EditorUndoRedoManager, warnings: PackedStringArray) -> int:
	var count := 0
	var inst := node as GeometryInstance3D
	if inst != null:
		var override := inst.material_override
		if override is BaseMaterial3D and not Tools.is_liltoon_material(override):
			var result := Tools.convert_standard_material_ex(override as BaseMaterial3D)
			undo.add_do_property(inst, "material_override", result["material"])
			undo.add_undo_property(inst, "material_override", override)
			for item in result["warnings"]:
				warnings.append("%s：%s" % [node.name, item])
			count += 1
		var mesh_inst := inst as MeshInstance3D
		if mesh_inst != null and mesh_inst.mesh != null:
			for i in mesh_inst.mesh.get_surface_count():
				var surface_mat = mesh_inst.get_surface_override_material(i)
				if surface_mat is BaseMaterial3D and not Tools.is_liltoon_material(surface_mat):
					var result := Tools.convert_standard_material_ex(surface_mat as BaseMaterial3D)
					undo.add_do_method(mesh_inst, "set_surface_override_material", i, result["material"])
					undo.add_undo_method(mesh_inst, "set_surface_override_material", i, surface_mat)
					for item in result["warnings"]:
						warnings.append("%s：%s" % [node.name, item])
					count += 1
	for child in node.get_children():
		count += _convert_node_tree(child, undo, warnings)
	return count


func _on_validate_resources() -> void:
	# 第一阶段只读检查，不改动任何材质；有问题的文件在用户确认后才修复并写盘。
	var targets: Array[Dictionary] = []
	var lines := PackedStringArray()
	for path in EditorInterface.get_selected_paths():
		var res = load(path)
		if not (res is ShaderMaterial):
			continue
		var mat := res as ShaderMaterial
		var issues := Tools.validate_material(mat)
		if issues.is_empty():
			lines.append("%s：未发现问题" % path.get_file())
			continue
		targets.append({"path": path, "mat": mat, "issues": issues})
		lines.append("%s：发现 %d 项" % [path.get_file(), issues.size()])
		for item in issues:
			lines.append("  - " + item)

	if targets.is_empty() and lines.is_empty():
		_show_dialog("liltoon_gd 校验与修复", "请先在文件系统面板选中 liltoon 材质资源（.tres/.res）。")
		return
	if targets.is_empty():
		_show_dialog("liltoon_gd 校验与修复", "\n".join(lines))
		return
	_confirm_repair(targets, lines)


func _confirm_repair(targets: Array[Dictionary], lines: PackedStringArray) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "liltoon_gd 校验与修复"
	dialog.dialog_text = "以下问题会被修复并立即写入文件：\n\n%s\n\n继续？" % "\n".join(lines)
	dialog.ok_button_text = "修复并保存"
	dialog.cancel_button_text = "取消"
	dialog.confirmed.connect(func():
		var results := PackedStringArray()
		var total := 0
		for item in targets:
			var mat: ShaderMaterial = item["mat"]
			var path: String = item["path"]
			var fixed := Tools.repair_material(mat)
			if not fixed.is_empty():
				ResourceSaver.save(mat, path)
				total += fixed.size()
			results.append("%s：修复 %d 项" % [path.get_file(), fixed.size()])
			for entry in fixed:
				results.append("  ✓ " + entry)
		results.append("")
		results.append("合计修复 %d 项。" % total)
		_show_dialog("liltoon_gd 校验与修复", "\n".join(results))
	)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(620, 420))


func _on_replace_material() -> void:
	var dialog := EditorFileDialog.new()
	dialog.title = "选择目标材质"
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres,*.material", "材质")
	dialog.file_selected.connect(func(path: String) -> void:
		var target := load(path) as Material
		var count := MatTools.replace_in_selection(EditorInterface.get_selection(), target)
		if count > 0:
			_show_dialog("材质替换", "已替换 %d 个材质槽位。" % count)
		else:
			_show_dialog("材质替换", "没有找到可替换的槽位（请选中使用同一材质的网格）。")
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered_ratio(0.4)


func _on_add_fur() -> void:
	var count := FurTools.add_to_selection(EditorInterface.get_selection(), 6)
	if count > 0:
		_show_dialog("liltoon_gd 毛发壳层", "已为 %d 个网格生成 %d 层毛发壳层。`n毛发参数在壳层材质上调整；改完主体颜色后可执行「同步选中网格的毛发参数」。" % [count, FurHelper.DEFAULT_LAYERS])
	else:
		_show_dialog("liltoon_gd 毛发壳层", "没有可处理的选中网格，或该网格已有毛发壳层。")


func _on_add_fur_transparent() -> void:
	var count := FurTools.add_to_selection(EditorInterface.get_selection(), 6, true)
	if count > 0:
		_show_dialog("liltoon_gd 毛发壳层", "已为 %d 个网格生成透明毛发壳层。" % count)
	else:
		_show_dialog("liltoon_gd 毛发壳层", "没有可处理的选中网格，或该网格已有毛发壳层。")


func _on_sync_fur() -> void:
	var count := FurTools.sync_selection(EditorInterface.get_selection())
	if count > 0:
		_show_dialog("liltoon_gd 毛发参数", "已同步 %d 个网格的毛发材质。" % count)
	else:
		_show_dialog("liltoon_gd 毛发参数", "选中网格没有毛发壳层。")


func _on_bake_material() -> void:
	var baked := 0
	var warnings := PackedStringArray()
	for node in EditorInterface.get_selection().get_selected_nodes():
		var inst := node as GeometryInstance3D
		if inst == null:
			continue
		var mat := _first_liltoon_material(inst)
		if mat == null:
			continue
		var result = TextureBaker.bake_material(mat, int(Settings.get_value("bake_size")))
		baked += 1
		for w in result["warnings"]:
			warnings.append(w)
	var text := "已烘焙 %d 个材质。" % baked
	if not warnings.is_empty():
		text += "\n\n提示：\n" + "\n".join(warnings)
	if baked == 0:
		text = "选中节点上没有可烘焙的 liltoon_gd 主材质。"
	_show_dialog("liltoon_gd 纹理烘焙", text)


func _on_optimize_material() -> void:
	var materials: Array = []
	for node in EditorInterface.get_selection().get_selected_nodes():
		var inst := node as GeometryInstance3D
		if inst == null:
			continue
		var mat := _first_liltoon_material(inst)
		if mat != null:
			materials.append(mat)
	if materials.is_empty():
		_show_dialog("liltoon_gd 优化分析", "选中节点上没有 liltoon_gd 材质。")
		return
	var result = Optimizer.analyze_many(materials)
	if result.is_empty():
		_show_dialog("liltoon_gd 优化分析", "%d 个材质没有发现优化点。" % materials.size())
		return
	var lines := PackedStringArray()
	for key in result:
		lines.append("[%s]" % key)
		for tip in result[key]:
			lines.append("  · " + tip)
	_show_dialog("liltoon_gd 优化分析", "\n".join(lines))


func _on_show_settings() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "liltoon_gd 全局设置"
	dialog.dialog_text = "当前设置（改值请用「项目设置 → liltoon_gd」）：\n\n" + Settings.summary()
	add_child(dialog)
	dialog.popup_centered(Vector2i(420, 320))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)


func _first_liltoon_material(inst: GeometryInstance3D) -> ShaderMaterial:
	var candidates: Array = []
	if inst.material_override != null:
		candidates.append(inst.material_override)
	for i in inst.get_surface_override_material_count():
		var m := inst.get_surface_override_material(i)
		if m != null:
			candidates.append(m)
	var mesh := inst.mesh
	if mesh != null:
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m != null:
				candidates.append(m)
	for c in candidates:
		var sm := c as ShaderMaterial
		if sm != null and sm.shader != null and sm.shader.resource_path.contains("liltoon_gd"):
			return sm
	return null


func _show_dialog(title: String, text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = text
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()
