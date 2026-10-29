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
const TextureTools := preload("res://addons/liltoon_gd/editor/liltoon_texture_tools.gd")
const AssetTools := preload("res://addons/liltoon_gd/editor/liltoon_asset_tools.gd")
const GifTools := preload("res://addons/liltoon_gd/editor/liltoon_gif_tools.gd")
const ModelSetup := preload("res://addons/liltoon_gd/editor/liltoon_model_setup.gd")
const MultiEditor := preload("res://addons/liltoon_gd/editor/liltoon_multi_editor.gd")
const Optimizer := preload("res://addons/liltoon_gd/editor/liltoon_optimizer.gd")
const Settings := preload("res://addons/liltoon_gd/editor/liltoon_setting.gd")
const Startup := preload("res://addons/liltoon_gd/editor/liltoon_startup.gd")
const AudioLink := preload("res://addons/liltoon_gd/audio/liltoon_audio_link.gd")

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
	add_tool_menu_item("liltoon_gd: 启用 AudioLink 全局参数", _on_setup_audiolink)
	add_tool_menu_item("liltoon_gd: 转换选中贴图的法线方向（DirectX↔OpenGL）", _on_convert_normal_map)
	add_tool_menu_item("liltoon_gd: 像素画降采样（选中贴图）…", _on_reduce_pixel_art)
	add_tool_menu_item("liltoon_gd: 由选中材质生成 Ramp 贴图", _on_generate_ramp)
	add_tool_menu_item("liltoon_gd: 移除材质中未使用的参数（资源）", _on_remove_unused_properties)
	add_tool_menu_item("liltoon_gd: 转换选中 LUT（.cube）为 PNG", _on_convert_lut)
	add_tool_menu_item("liltoon_gd: 生成 bug 报告…", _on_generate_bug_report)
	add_tool_menu_item("liltoon_gd: 修复选中节点的光照设置", _on_fix_lighting)
	add_tool_menu_item("liltoon_gd: 转换选中 GIF 为图集…", _on_convert_gif)
	add_tool_menu_item("liltoon_gd: 按默认预设装配选中模型的材质", _on_setup_from_model)
	add_tool_menu_item("liltoon_gd: 批量编辑选中材质的参数…", _on_multi_editor)


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
	remove_tool_menu_item("liltoon_gd: 转换选中贴图的法线方向（DirectX↔OpenGL）")
	remove_tool_menu_item("liltoon_gd: 像素画降采样（选中贴图）…")
	remove_tool_menu_item("liltoon_gd: 由选中材质生成 Ramp 贴图")
	remove_tool_menu_item("liltoon_gd: 移除材质中未使用的参数（资源）")
	remove_tool_menu_item("liltoon_gd: 转换选中 LUT（.cube）为 PNG")
	remove_tool_menu_item("liltoon_gd: 生成 bug 报告…")
	remove_tool_menu_item("liltoon_gd: 修复选中节点的光照设置")
	remove_tool_menu_item("liltoon_gd: 转换选中 GIF 为图集…")
	remove_tool_menu_item("liltoon_gd: 按默认预设装配选中模型的材质")
	remove_tool_menu_item("liltoon_gd: 批量编辑选中材质的参数…")


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
		var bake_size := int(Settings.get_value("bake_size"))
		if bake_size < 1:
			bake_size = 512
		var result = TextureBaker.bake_material(mat, bake_size)
		baked += 1
		for w in result["warnings"]:
			warnings.append(w)
	var text := "已烘焙 %d 个材质。" % baked
	if not warnings.is_empty():
		text += "\n\n提示：\n" + "\n".join(warnings)
	if baked == 0:
		text = "选中节点上没有可烘焙的 liltoon_gd 主材质。"
	_show_dialog("liltoon_gd 纹理烘焙", text)


# ============================================================================
# 纹理工具（对齐 lilToon 的 Assets 菜单三项）
# ============================================================================

const IMAGE_EXTS := ["png", "jpg", "jpeg", "webp", "tga", "bmp"]


func _on_convert_normal_map() -> void:
	_apply_image_tool("liltoon_gd 法线图方向转换", "_conv",
		func(img: Image) -> Image: return TextureTools.convert_normal_map(img),
		"绿通道已取反（G' = 1 - G），DirectX 与 OpenGL 法线图互转都可用同一操作。")


func _on_reduce_pixel_art() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "liltoon_gd 像素画降采样"
	dialog.dialog_text = "按最近邻抽样缩小选中贴图。原版提供 1/2 与 1/4 两档。"
	dialog.ok_button_text = "1/2"
	dialog.get_ok_button().tooltip_text = "输出尺寸为原图的一半，另存为 <名称>_resized.png"
	var quarter := dialog.add_button("1/4", true, "quarter")
	quarter.tooltip_text = "输出尺寸为原图的四分之一，另存为 <名称>_resized.png"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		_apply_image_tool("liltoon_gd 像素画降采样 1/2", "_resized",
			func(img: Image) -> Image: return TextureTools.reduce_pixel_art(img, 2),
			TextureTools.import_note(true, false)))
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"quarter":
			dialog.queue_free()
			_apply_image_tool("liltoon_gd 像素画降采样 1/4", "_resized",
				func(img: Image) -> Image: return TextureTools.reduce_pixel_art(img, 4),
				TextureTools.import_note(true, false)))
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(460, 180))


func _on_generate_ramp() -> void:
	var done := 0
	var warnings := PackedStringArray()
	for path in EditorInterface.get_selected_paths():
		if not (path.ends_with(".tres") or path.ends_with(".res")):
			warnings.append("%s：不是材质资源（.tres/.res）" % path.get_file())
			continue
		var res = load(path)
		if not (res is ShaderMaterial) or not Tools.is_liltoon_material(res):
			warnings.append("%s：不是 liltoon_gd 主材质" % path.get_file())
			continue
		var image: Image = TextureTools.generate_ramp(res)
		if image == null:
			warnings.append("%s：生成失败" % path.get_file())
			continue
		var save_path: String = TextureTools.output_path(path, "_ramp")
		if image.save_png(save_path) != OK:
			warnings.append("%s：保存失败（%s）" % [path.get_file(), save_path])
			continue
		done += 1
	if done > 0:
		EditorInterface.get_resource_filesystem().scan()
	var text := "已生成 %d 张 Ramp（128×16）。" % done
	var note := TextureTools.import_note(false, true)
	if note != "":
		text += "\n\n" + note
	if not warnings.is_empty():
		text += "\n\n未处理：\n" + "\n".join(warnings)
	if done == 0 and warnings.is_empty():
		text = "请先在资源面板选中 liltoon_gd 材质（.tres）。"
	_show_dialog("liltoon_gd 生成 Ramp", text)


## 图片类工具的公共流程：选中资源 → 读图 → 变换 → 另存 `<名称><后缀>.png`。
func _apply_image_tool(title: String, suffix: String, transform: Callable, note: String) -> void:
	var done := 0
	var warnings := PackedStringArray()
	for path in EditorInterface.get_selected_paths():
		if not IMAGE_EXTS.has(path.get_extension().to_lower()):
			warnings.append("%s：不是支持的图片格式（png/jpg/webp/tga/bmp）" % path.get_file())
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null:
			warnings.append("%s：读取失败" % path.get_file())
			continue
		var out: Image = transform.call(image)
		if out == null:
			warnings.append("%s：转换失败" % path.get_file())
			continue
		var save_path: String = TextureTools.output_path(path, suffix)
		if out.save_png(save_path) != OK:
			warnings.append("%s：保存失败（%s）" % [path.get_file(), save_path])
			continue
		done += 1
	if done > 0:
		EditorInterface.get_resource_filesystem().scan()
	var text := "已处理 %d 张（原文件保留）。" % done
	if note != "":
		text += "\n\n" + note
	if not warnings.is_empty():
		text += "\n\n未处理：\n" + "\n".join(warnings)
	if done == 0 and warnings.is_empty():
		text = "请在资源面板选中要处理的贴图。"
	_show_dialog(title, text)


# ============================================================================
# 资产工具（Remove unused properties / LUT→PNG / bug report / Fix lighting）
# ============================================================================


func _on_remove_unused_properties() -> void:
	var cleaned := 0
	var removed_total := 0
	var warnings := PackedStringArray()
	for path in EditorInterface.get_selected_paths():
		if not path.ends_with(".tres"):
			warnings.append("%s：仅支持文本资源 .tres" % path.get_file())
			continue
		var res = load(path)
		if not (res is ShaderMaterial) or not Tools.is_liltoon_material(res):
			warnings.append("%s：不是 liltoon_gd 材质" % path.get_file())
			continue
		var filtered: Dictionary = AssetTools.filter_unused_properties(
			FileAccess.get_file_as_string(path), AssetTools.shader_uniform_names(res))
		var removed: PackedStringArray = filtered["removed"]
		if removed.is_empty():
			continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			warnings.append("%s：写入失败" % path.get_file())
			continue
		file.store_string(filtered["text"])
		file.close()
		cleaned += 1
		removed_total += removed.size()
	if cleaned > 0:
		EditorInterface.get_resource_filesystem().scan()
	var text := "已清理 %d 个材质，共移除 %d 个未使用参数。" % [cleaned, removed_total]
	if cleaned == 0 and warnings.is_empty():
		text = "选中材质里没有未使用的参数。"
	if not warnings.is_empty():
		text += "\n\n未处理：\n" + "\n".join(warnings)
	_show_dialog("liltoon_gd 移除未使用参数", text)


func _on_convert_lut() -> void:
	var done := 0
	var warnings := PackedStringArray()
	for path in EditorInterface.get_selected_paths():
		if not path.to_lower().ends_with(".cube"):
			warnings.append("%s：不是 .cube 文件" % path.get_file())
			continue
		var lut: Dictionary = AssetTools.parse_cube(FileAccess.get_file_as_string(path))
		if not lut["ok"]:
			warnings.append("%s：%s" % [path.get_file(), lut["error"]])
			continue
		var image: Image = AssetTools.lut_to_atlas(lut)
		if image == null:
			warnings.append("%s：展开失败" % path.get_file())
			continue
		var save_path := path.get_basename() + ".png"
		if image.save_png(save_path) != OK:
			warnings.append("%s：保存失败（%s）" % [path.get_file(), save_path])
			continue
		done += 1
	if done > 0:
		EditorInterface.get_resource_filesystem().scan()
	var text := "已转换 %d 个 LUT。" % done
	if done > 0:
		text += "\n\n导入后请把 Repeat 设为 Disabled，避免相邻切片串色。"
	if not warnings.is_empty():
		text += "\n\n未处理：\n" + "\n".join(warnings)
	if done == 0 and warnings.is_empty():
		text = "请在资源面板选中 .cube 文件。"
	_show_dialog("liltoon_gd LUT → PNG", text)


func _on_generate_bug_report() -> void:
	var materials: Array = []
	for path in EditorInterface.get_selected_paths():
		var res = load(path)
		if res is ShaderMaterial:
			materials.append(res)
	var text: String = AssetTools.build_bug_report(materials, Settings.plugin_version())
	var save_path := "user://liltoon_gd_bugreport.txt"
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		_show_dialog("liltoon_gd bug 报告", "写入失败：%s" % save_path)
		return
	file.store_string(text)
	file.close()
	_show_dialog("liltoon_gd bug 报告", "已写入：\n%s\n\n%s" % [ProjectSettings.globalize_path(save_path), text])


func _on_fix_lighting() -> void:
	var materials: Array[ShaderMaterial] = []
	var renderers: Array[GeometryInstance3D] = []
	for node in EditorInterface.get_selection().get_selected_nodes():
		_collect_lighting_targets(node, materials, renderers)
	if materials.is_empty() and renderers.is_empty():
		_show_dialog("liltoon_gd 修复光照", "选中节点及其子节点里没有 liltoon_gd 材质或网格。")
		return
	var values: Dictionary = AssetTools.lighting_fix_values(TextureTools.shader_defaults())
	var undo := get_undo_redo()
	undo.create_action("liltoon_gd: 修复光照设置")
	for mat in materials:
		for key in values:
			var property := "shader_parameter/%s" % key
			undo.add_do_property(mat, property, values[key])
			undo.add_undo_property(mat, property, mat.get_shader_parameter(key))
	for inst in renderers:
		if inst.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			undo.add_do_property(inst, "cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
			undo.add_undo_property(inst, "cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		if inst.gi_mode == GeometryInstance3D.GI_MODE_DISABLED:
			undo.add_do_property(inst, "gi_mode", GeometryInstance3D.GI_MODE_DYNAMIC)
			undo.add_undo_property(inst, "gi_mode", GeometryInstance3D.GI_MODE_DISABLED)
	undo.commit_action()
	_show_dialog("liltoon_gd 修复光照", "已复位 %d 个材质的光照参数、%d 个网格的渲染设置（可撤销）。\n\n原版还会设 _VertexLightStrength / _BeforeExposureLimit / _lilDirectionalLightStrength，Godot Forward+ 无对应机制。" % [materials.size(), renderers.size()])


func _on_multi_editor() -> void:
	var materials := _selected_liltoon_materials()
	if materials.size() < 2:
		_show_dialog("liltoon_gd 批量编辑", "请至少在资源面板选中 2 个 liltoon_gd 材质（当前 %d 个）。" % materials.size())
		return
	var params: Array[String] = MultiEditor.common_parameters(materials)
	if params.is_empty():
		_show_dialog("liltoon_gd 批量编辑", "选中的材质没有共同的 shader 参数。")
		return

	var window := Window.new()
	window.title = "liltoon_gd 批量编辑（%d 个材质）" % materials.size()
	window.size = Vector2i(470, 240)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 8)
	window.add_child(box)

	var param_label := Label.new()
	param_label.text = "参数"
	param_label.tooltip_text = "只列出所选材质都声明的参数，避免写到不存在的键"
	box.add_child(param_label)

	var picker := OptionButton.new()
	picker.tooltip_text = "选择要批量修改的 shader 参数"
	for uniform_name in params:
		picker.add_item(uniform_name)
	box.add_child(picker)

	var value_label := Label.new()
	value_label.text = "值"
	value_label.tooltip_text = "按参数类型填写：0.5 / true / Color(1,0,0,1) / Vector3(1,0,0) / res://贴图.png"
	box.add_child(value_label)

	var value_edit := LineEdit.new()
	value_edit.placeholder_text = "0.5 / true / Color(1,0,0,1) / res://..."
	value_edit.tooltip_text = "输入要写入全部选中材质的值"
	box.add_child(value_edit)

	var status := Label.new()
	status.tooltip_text = "操作结果会显示在这里"
	box.add_child(status)

	var apply_button := Button.new()
	apply_button.text = "应用到全部"
	apply_button.tooltip_text = "把所有选中材质的该参数设为上面的值，可用 Ctrl+Z 撤销"
	box.add_child(apply_button)

	apply_button.pressed.connect(func() -> void:
		var uniform_name := picker.get_item_text(picker.selected)
		var type := MultiEditor.parameter_type(materials, uniform_name)
		var parsed: Dictionary = MultiEditor.parse_value(value_edit.text, type)
		if not parsed["ok"]:
			status.text = "值无效：%s" % parsed["error"]
			return
		var undo := get_undo_redo()
		undo.create_action("liltoon_gd: 批量设置 %s" % uniform_name)
		for mat in materials:
			var property := "shader_parameter/%s" % uniform_name
			undo.add_do_property(mat, property, parsed["value"])
			undo.add_undo_property(mat, property, mat.get_shader_parameter(uniform_name))
		undo.commit_action()
		status.text = "已把 %s 设为 %s（%d 个材质）" % [uniform_name,
			MultiEditor.value_to_text(parsed["value"]), materials.size()])

	EditorInterface.get_base_control().add_child(window)
	window.close_requested.connect(window.queue_free)
	window.popup_centered(Vector2i(470, 240))


func _selected_liltoon_materials() -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = []
	for path in EditorInterface.get_selected_paths():
		var res = load(path)
		if res is ShaderMaterial and Tools.is_liltoon_material(res):
			if not materials.has(res):
				materials.append(res)
	return materials


func _on_setup_from_model() -> void:
	var entries: Array[Dictionary] = []
	for node in EditorInterface.get_selection().get_selected_nodes():
		entries.append_array(ModelSetup.collect_surfaces(node))
	if entries.is_empty():
		_show_dialog("liltoon_gd 模型材质装配", "选中节点及其子节点里没有可处理的网格 surface。")
		return

	var pending: Array[Dictionary] = []
	var skipped := 0
	var warnings := PackedStringArray()
	for entry in entries:
		var result: Dictionary = ModelSetup.build_material_for_surface(entry)
		if result["skipped"]:
			skipped += 1
			continue
		var mat: ShaderMaterial = result["material"]
		var save_dir: String = ModelSetup.save_dir_for(entry["node"])
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
		var save_path := save_dir.path_join("%s.tres" % result["name"])
		if ResourceSaver.save(mat, save_path) != OK:
			warnings.append("%s：保存失败" % save_path)
			continue
		for item in result["warnings"]:
			warnings.append("%s：%s" % [result["name"], item])
		pending.append({
			"node": entry["node"], "surface": entry["surface"],
			"material": mat, "old": entry["material"],
			"name": result["name"], "preset": result["preset"],
		})

	if not pending.is_empty():
		var undo := get_undo_redo()
		undo.create_action("liltoon_gd: 装配模型材质")
		for item in pending:
			undo.add_do_method(item["node"], "set_surface_override_material", item["surface"], item["material"])
			undo.add_undo_method(item["node"], "set_surface_override_material", item["surface"], item["old"])
		undo.commit_action()
		EditorInterface.get_resource_filesystem().scan()

	var lines := PackedStringArray()
	for item in pending:
		lines.append("%s[%d] → %s（预设：%s）" % [item["node"].name, item["surface"], item["name"], item["preset"]])
	var text := "已装配 %d 个材质，跳过 %d 个已是 liltoon 的 surface。" % [pending.size(), skipped]
	if not lines.is_empty():
		text += "\n\n" + "\n".join(lines)
	if not warnings.is_empty():
		text += "\n\n提示：\n" + "\n".join(warnings)
	text += "\n\n说明：Godot 没有模型导入期的材质重映射钩子，本操作只处理场景里已存在的网格。"
	_show_dialog("liltoon_gd 模型材质装配", text)


func _on_convert_gif() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "liltoon_gd GIF → 图集"
	dialog.dialog_text = "把选中的 GIF 逐帧拼成图集。列数 = ceil(√帧数)，帧 i 放在 (i % 列数, i / 列数) 格。"
	dialog.ok_button_text = "补到 2 的幂"
	dialog.get_ok_button().tooltip_text = "图集边长向上补到 2 的幂；使用时要按返回的 xScale / yScale 缩放 UV"
	var compact := dialog.add_button("紧凑尺寸", true, "compact")
	compact.tooltip_text = "图集尺寸恰为 帧宽×列数，UV 不用缩放"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		_apply_gif_atlas(true))
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"compact":
			dialog.queue_free()
			_apply_gif_atlas(false))
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(500, 190))


func _apply_gif_atlas(pow2: bool) -> void:
	var done := 0
	var warnings := PackedStringArray()
	var details := PackedStringArray()
	for path in EditorInterface.get_selected_paths():
		if not path.to_lower().ends_with(".gif"):
			warnings.append("%s：不是 .gif" % path.get_file())
			continue
		var result: Dictionary = GifTools.convert(FileAccess.get_file_as_bytes(path), pow2)
		if not result["ok"]:
			warnings.append("%s：%s" % [path.get_file(), result["error"]])
			continue
		var image: Image = result["image"]
		# 文件名沿用原版：<名称>_gif2png_<列数>_<帧数>_<延时>
		var save_path := "%s_gif2png_%d_%d_%d.png" % [path.get_basename(), result["loop_xy"],
			result["frame_count"], result["duration"]]
		if image.save_png(save_path) != OK:
			warnings.append("%s：保存失败（%s）" % [path.get_file(), save_path])
			continue
		done += 1
		details.append("%s：%d 帧 / %d 列 / %d×%d / xScale=%.3f yScale=%.3f / 延时 %.2fs" % [
			path.get_file(), result["frame_count"], result["loop_xy"],
			image.get_width(), image.get_height(), result["x_scale"], result["y_scale"],
			float(result["duration"]) / 100.0])
	if done > 0:
		EditorInterface.get_resource_filesystem().scan()
	var text := "已转换 %d 个 GIF。" % done
	if not details.is_empty():
		text += "\n" + "\n".join(details)
	if not warnings.is_empty():
		text += "\n\n未处理：\n" + "\n".join(warnings)
	if done == 0 and warnings.is_empty():
		text = "请在资源面板选中 .gif 文件。"
	_show_dialog("liltoon_gd GIF → 图集", text)


func _collect_lighting_targets(node: Node, materials: Array[ShaderMaterial], renderers: Array[GeometryInstance3D]) -> void:
	var inst := node as GeometryInstance3D
	if inst != null:
		if not renderers.has(inst):
			renderers.append(inst)
		for mat in _liltoon_materials_of(inst):
			if not materials.has(mat):
				materials.append(mat)
	for child in node.get_children():
		_collect_lighting_targets(child, materials, renderers)


func _liltoon_materials_of(inst: GeometryInstance3D) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	var candidates: Array[Material] = []
	if inst.material_override != null:
		candidates.append(inst.material_override)
	for idx in inst.get_surface_override_material_count():
		var override_mat: Material = inst.get_surface_override_material(idx)
		if override_mat != null:
			candidates.append(override_mat)
	var mesh_inst := inst as MeshInstance3D
	if mesh_inst != null and mesh_inst.mesh != null:
		for idx in mesh_inst.mesh.get_surface_count():
			var surface_mat: Material = mesh_inst.mesh.surface_get_material(idx)
			if surface_mat != null:
				candidates.append(surface_mat)
	for c in candidates:
		var sm := c as ShaderMaterial
		if sm != null and sm.shader != null and sm.shader.resource_path.contains("liltoon_gd"):
			out.append(sm)
	return out


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


func _on_setup_audiolink() -> void:
	# AudioLink 依赖三个工程级全局 uniform；迁移到新项目时需要执行一次。
	var changed: bool = AudioLink.ensure_globals()
	var text := "AudioLink 全局参数已写入工程设置（重启编辑器后生效）。" if changed \
		else "AudioLink 全局参数已存在，无需重复写入。"
	text += "\n\n还需两步：\n1. 项目设置 → 自动加载，添加 res://addons/liltoon_gd/audio/liltoon_audio_link.gd\n2. 材质里勾选 use_audiolink，并按需打开 audiolink_2_emission / audiolink_2_vertex 等路由"
	_show_dialog("liltoon_gd AudioLink", text)


func _first_liltoon_material(inst: GeometryInstance3D) -> ShaderMaterial:
	var candidates: Array[Material] = []
	if inst.material_override != null:
		candidates.append(inst.material_override)
	var override_count: int = inst.get_surface_override_material_count()
	for idx in override_count:
		var override_mat: Material = inst.get_surface_override_material(idx)
		if override_mat != null:
			candidates.append(override_mat)
	# mesh 是 MeshInstance3D 的属性，GeometryInstance3D 上没有，必须先收窄类型
	var mesh_inst := inst as MeshInstance3D
	if mesh_inst != null:
		var mesh: Mesh = mesh_inst.mesh
		if mesh != null:
			var surface_count: int = mesh.get_surface_count()
			for idx in surface_count:
				var surface_mat: Material = mesh.surface_get_material(idx)
				if surface_mat != null:
					candidates.append(surface_mat)
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
