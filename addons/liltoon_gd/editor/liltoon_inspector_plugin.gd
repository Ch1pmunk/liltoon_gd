@tool
extends EditorInspectorPlugin

const Factory := preload("res://addons/liltoon_gd/liltoon_material_factory.gd")
const FurTools := preload("res://addons/liltoon_gd/editor/liltoon_fur_tools.gd")
const PresetImport := preload("res://addons/liltoon_gd/editor/liltoon_preset_import.gd")
const Presets := preload("res://addons/liltoon_gd/editor/preset_library.gd")
const ShaderDocs := preload("res://addons/liltoon_gd/editor/shader_doc_parser.gd")

const SHADER_DIR := "res://addons/liltoon_gd/shaders/"
const OUTLINE_SHADER_PATH := "res://addons/liltoon_gd/shaders/liltoon_outline.gdshader"
const PRESET_ICON_DIR := "res://addons/liltoon_gd/materials/preset_icons/"
const PARAM_PREFIX := "shader_parameter/"
const DESC_META := "_liltoon_doc_text"
const DESC_BASE_META := "_liltoon_doc_base_tooltip"

var _doc_cache := {}

# P4：预设缩略图按预设名缓存，整个编辑器会话只生成一次（纯 CPU 绘制，不依赖渲染帧）。
static var _preset_icons: Dictionary = {}


func _can_handle(object: Object) -> bool:
	if not object is ShaderMaterial:
		return false
	var mat := object as ShaderMaterial
	if mat.shader == null:
		return false
	return mat.shader.resource_path.begins_with(SHADER_DIR)


func _parse_begin(object: Object) -> void:
	# 插件实例在所有 Inspector 之间共享，因此这里不能把材质存到成员变量上，
	# 否则后打开的 Inspector 会覆盖先前面板的目标材质。面板把材质与控件全部作为
	# 局部变量捕获进信号回调，保证每个 Inspector 各自独立。
	var mat := object as ShaderMaterial
	if mat == null:
		return
	if mat.shader.resource_path != OUTLINE_SHADER_PATH:
		add_custom_control(_build_panel(mat))
	_apply_descriptions_deferred(mat)


func _apply_descriptions_deferred(mat: ShaderMaterial) -> void:
	# Inspector 的分组与属性行是分帧创建的，尾部新增分组可能晚于第一帧完成，
	# 因此不能在第一帧成功后就返回；_apply_descriptions 由 meta 标记保证幂等。
	for _attempt in 6:
		await Engine.get_main_loop().process_frame
		_apply_descriptions(mat)


# EditorProperty.tooltip_text 存放的是编辑器文档 id（形如 "property|Class|prop"），
# Godot 会把它交给 EditorHelpBit 解析后显示悬停文档。直接改成普通文本会让引擎继续
# 按文档 id 解析，触发 "Invalid doc id" 并渲染出空白提示框。因此描述只能写入属性行
# 内部的值控件，属性行本身保持引擎写入的文档 id 不变。
func _apply_descriptions(mat: ShaderMaterial) -> bool:
	var docs := _get_uniform_docs(mat.shader.resource_path)
	if docs.is_empty():
		return false

	var rows := _find_parameter_rows(mat)
	if rows.is_empty():
		return false

	var applied := 0
	for row in rows:
		var uniform_name := str(row.get_edited_property()).trim_prefix(PARAM_PREFIX)
		var desc := str(docs.get(uniform_name, ""))
		if desc.is_empty():
			continue
		if _apply_row_description(row, desc):
			applied += 1
	return applied > 0


func _find_parameter_rows(mat: ShaderMaterial) -> Array[EditorProperty]:
	var rows: Array[EditorProperty] = []
	# 浮动/独立窗口的 Inspector 不在主停靠面板下，从编辑器根节点遍历所有窗口，
	# 再按 get_edited_object() == mat 过滤，保证只给当前材质注入描述。
	var root: Node = Engine.get_main_loop().root
	if root == null:
		root = EditorInterface.get_base_control()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is EditorProperty:
			var row := node as EditorProperty
			if row.get_edited_object() == mat and str(row.get_edited_property()).begins_with(PARAM_PREFIX):
				rows.append(row)
		for i in node.get_child_count(true):
			stack.append(node.get_child(i, true))
	return rows


func _apply_row_description(row: EditorProperty, desc: String) -> bool:
	var applied := false
	var stack: Array[Node] = []
	for i in row.get_child_count(true):
		stack.append(row.get_child(i, true))
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Window:
			# 弹出菜单（如枚举下拉）内部控件不属于属性行界面。
			continue
		if node is Control and _accepts_description(node):
			var control := node as Control
			if str(control.get_meta(DESC_META, "")) != desc:
				var base := str(control.get_meta(DESC_BASE_META, control.tooltip_text))
				control.set_meta(DESC_META, desc)
				control.set_meta(DESC_BASE_META, base)
				control.tooltip_text = desc if base.is_empty() else base + "\n\n" + desc
				applied = true
		for i in node.get_child_count(true):
			stack.append(node.get_child(i, true))
	return applied


func _accepts_description(control: Control) -> bool:
	if control is ColorPickerButton or control is CheckBox or control is OptionButton:
		return true
	# 编辑器自绘的图标按钮（回退、固定、清空等）保留自己的原生提示。
	if control is BaseButton:
		return false
	return true


func _get_uniform_docs(shader_path: String) -> Dictionary:
	if _doc_cache.has(shader_path):
		return _doc_cache[shader_path]
	var docs := ShaderDocs.collect(shader_path)
	_doc_cache[shader_path] = docs
	return docs


func _build_panel(mat: ShaderMaterial) -> Control:
	Factory.sync_outline_distance_fade(mat)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)

	# 距离淡出参数由引擎 Inspector 直接写入材质，这里轮询变化并同步到描边子材质。
	var fade_state := {"key": ""}
	var fade_timer := Timer.new()
	fade_timer.wait_time = 0.3
	fade_timer.autostart = true
	fade_timer.timeout.connect(func() -> void:
		if mat == null:
			return
		var key := "%s|%s|%s|%s" % [
			mat.get_shader_parameter("use_distance_fade"),
			mat.get_shader_parameter("distance_fade_near"),
			mat.get_shader_parameter("distance_fade_far"),
			mat.get_shader_parameter("distance_fade_strength"),
		]
		if key != fade_state["key"]:
			fade_state["key"] = key
			Factory.sync_outline_distance_fade(mat)
	)
	root.add_child(fade_timer)

	var title := Label.new()
	title.text = "lilToon GD"
	title.tooltip_text = "lilToon GD 卡通渲染插件控制面板。"
	title.add_theme_font_size_override("font_size", 16)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "核心版 · 卡通渲染（P0–P3）"
	subtitle.tooltip_text = "当前面板覆盖核心渲染、光照、材质扩展与角色特化功能。"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.modulate = Color(1.0, 1.0, 1.0, 0.6)
	root.add_child(subtitle)

	# 先创建控件、再接线：闭包按值捕获本次面板的材质与控件，不依赖共享成员。
	var preset_select := OptionButton.new()
	preset_select.tooltip_text = "选择内置预设；点击“应用预设”后写入当前材质。"
	for preset_name in Presets.get_names():
		preset_select.add_item(preset_name)
	preset_select.select(0)
	preset_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_ensure_preset_icons()
	_apply_preset_icons(preset_select)

	var apply_button := Button.new()
	apply_button.text = "应用预设"
	apply_button.tooltip_text = "把所选预设的全部参数应用到当前材质。"

	var lil_import_button := Button.new()
	lil_import_button.text = "导入 liltoon"
	lil_import_button.tooltip_text = "解析 liltoon 的 Unity 预设（.asset），映射本插件已有的参数并应用。"

	var outline_toggle := CheckBox.new()
	outline_toggle.text = "启用描边（next_pass）"
	outline_toggle.tooltip_text = "为当前材质添加或移除 next_pass 外扩描边。"
	outline_toggle.button_pressed = Factory.outline_enabled(mat)

	var outline_width := SpinBox.new()
	outline_width.tooltip_text = "模型空间描边宽度；屏幕空间模式请修改描边子材质的屏幕空间宽度。"
	outline_width.min_value = 0.0
	outline_width.max_value = 0.2
	outline_width.step = 0.001
	outline_width.value = _get_current_outline_width(mat)

	# Alpha To Coverage 只切换 shader 变体，声明要在按钮连接之前，方便预设/重置回调同步勾选状态。
	var a2c_toggle := CheckBox.new()
	a2c_toggle.text = "Alpha To Coverage"
	a2c_toggle.tooltip_text = "用像素 Alpha 生成 MSAA 覆盖来柔化 Cutout 边缘（对应 liltoon 的 _AlphaToMask）；需要视口开启 MSAA 2× 及以上，仅 Cutout 变体可用。"
	a2c_toggle.button_pressed = Factory.alpha_to_mask_of(mat.shader)
	a2c_toggle.disabled = Factory.shader_family(mat.shader) != 1

	apply_button.pressed.connect(func(): _on_apply_preset(mat, preset_select, outline_toggle, outline_width, a2c_toggle))
	lil_import_button.pressed.connect(func(): _on_import_preset(mat))
	outline_toggle.toggled.connect(func(pressed: bool): _on_outline_toggled(mat, pressed, outline_width))
	outline_width.value_changed.connect(func(value: float): _on_outline_width_changed(mat, value))
	a2c_toggle.toggled.connect(func(pressed: bool): _on_alpha_to_mask_toggled(mat, pressed))

	var preset_row := HBoxContainer.new()
	preset_row.add_child(preset_select)
	preset_row.add_child(apply_button)
	preset_row.add_child(lil_import_button)
	root.add_child(preset_row)

	var preset_file_row := HBoxContainer.new()
	var export_button := Button.new()
	export_button.text = "导出预设…"
	export_button.tooltip_text = "把当前材质的全部参数保存为 .tres 预设文件，可在其他工程复用。"
	export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_button.pressed.connect(func(): _export_preset(mat))
	var import_button := Button.new()
	import_button.text = "导入预设…"
	import_button.tooltip_text = "从 .tres 预设文件恢复参数，只影响当前材质。"
	import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_button.pressed.connect(func(): _import_preset(mat, outline_toggle, outline_width))
	preset_file_row.add_child(export_button)
	preset_file_row.add_child(import_button)
	root.add_child(preset_file_row)

	root.add_child(outline_toggle)

	var width_row := HBoxContainer.new()
	var width_label := Label.new()
	width_label.text = "描边宽度"
	width_label.tooltip_text = "模型空间描边宽度（法线/位置模式）；屏幕空间宽度请在描边子材质中设置。"
	width_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	width_row.add_child(width_label)
	width_row.add_child(outline_width)
	root.add_child(width_row)

	var lighting_row := HBoxContainer.new()
	var lighting_toggle := CheckBox.new()
	lighting_toggle.text = "描边受光"
	lighting_toggle.tooltip_text = "改用 lit 描边变体，让描边随光照变暗；关闭则保持 unshaded。"
	var outline_mat := Factory.get_outline_material(mat)
	lighting_toggle.button_pressed = outline_mat != null and bool(outline_mat.get_shader_parameter("outline_enable_lighting"))
	lighting_toggle.disabled = outline_mat == null
	lighting_toggle.toggled.connect(func(pressed: bool) -> void:
		Factory.set_outline_lighting(mat, pressed)
	)
	lighting_row.add_child(lighting_toggle)
	root.add_child(lighting_row)

	var transparent_row := HBoxContainer.new()
	var transparent_toggle := CheckBox.new()
	transparent_toggle.text = "描边透明"
	transparent_toggle.tooltip_text = "改用透明描边变体，按顶点色 Alpha 与透明度混合。"
	var transparent_mat := Factory.get_outline_material(mat)
	var premul_outline := Factory.outline_premultiplied(mat)
	transparent_toggle.button_pressed = premul_outline or (transparent_mat != null and transparent_mat.get_shader_parameter("outline_apply_transparency") == true)
	transparent_toggle.disabled = transparent_mat == null or premul_outline
	if premul_outline:
		transparent_toggle.tooltip_text = "预乘透明材质固定使用预乘描边，不能切回普通混合；对齐 lilToon 的 LIL_TRANSPARENT_PREMULTIPLY。"
	transparent_toggle.toggled.connect(func(pressed: bool) -> void:
		Factory.set_outline_transparency(mat, pressed)
	)
	transparent_row.add_child(transparent_toggle)
	root.add_child(transparent_row)

	var sync_row := HBoxContainer.new()
	var sync_button := Button.new()
	sync_button.text = "同步描边淡出"
	sync_button.tooltip_text = "把主体的距离淡出参数写入描边子材质；在 Inspector 修改淡出参数后点一次即可。"
	sync_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sync_button.pressed.connect(func() -> void:
		Factory.sync_outline_distance_fade(mat)
		_show_message("描边淡出", "已把主体的距离淡出参数同步到描边子材质。")
	)
	sync_row.add_child(sync_button)
	root.add_child(sync_row)

	var cull_row := HBoxContainer.new()
	var cull_label := Label.new()
	cull_label.text = "渲染面"
	cull_label.tooltip_text = "单面剔除背面、双面渲染两面、仅背面剔除正面；对应 liltoon 的 Cull Mode。"
	cull_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cull_row.add_child(cull_label)

	var cull_select := OptionButton.new()
	cull_select.tooltip_text = "切换材质使用的 shader 变体，已设置的参数会保留。"
	cull_select.add_item("单面（正面可见）")
	cull_select.add_item("双面（两面可见）")
	cull_select.add_item("仅背面")
	cull_select.select(Factory.cull_mode_of(mat.shader))
	cull_select.disabled = Factory.shader_family(mat.shader) < 0
	cull_select.item_selected.connect(func(index: int): _set_cull_mode(mat, index))
	cull_row.add_child(cull_select)
	root.add_child(cull_row)

	var a2c_row := HBoxContainer.new()
	a2c_row.add_child(a2c_toggle)
	root.add_child(a2c_row)

	var reset_button := Button.new()
	reset_button.text = "重置为默认"
	reset_button.tooltip_text = "恢复默认预设并重新启用描边。"
	reset_button.pressed.connect(func(): _on_reset(mat, outline_toggle, outline_width, a2c_toggle, cull_select))
	root.add_child(reset_button)

	root.add_child(HSeparator.new())
	return root


func _get_current_outline_width(mat: ShaderMaterial) -> float:
	var outline := Factory.get_outline_material(mat)
	if outline == null:
		return Factory.DEFAULT_OUTLINE_WIDTH
	var value = outline.get_shader_parameter("outline_width")
	if value is float:
		return value
	return Factory.DEFAULT_OUTLINE_WIDTH


func _on_apply_preset(mat: ShaderMaterial, preset_select: OptionButton, outline_toggle: CheckBox, outline_width: SpinBox, a2c_toggle: CheckBox) -> void:
	if mat == null or preset_select == null:
		return
	var preset_name := preset_select.get_item_text(preset_select.selected)
	var data := Presets.get_preset(preset_name)
	Presets.apply_to_material(mat, preset_name)
	Factory.sync_outline_distance_fade(mat)
	FurTools.sync_for_material(mat)

	if outline_toggle != null:
		outline_toggle.set_pressed_no_signal(bool(data.get("outline_enabled", true)))
	if outline_width != null:
		outline_width.set_value_no_signal(float(data.get("outline_width", Factory.DEFAULT_OUTLINE_WIDTH)))
	if a2c_toggle != null:
		a2c_toggle.set_pressed_no_signal(Factory.alpha_to_mask_of(mat.shader))
	mat.emit_changed()


func _on_outline_toggled(mat: ShaderMaterial, pressed: bool, outline_width: SpinBox) -> void:
	if mat == null:
		return
	# 描边关闭时面板上的宽度值没有落点，重新开启时用它创建，避免用户输入被丢弃。
	var width := outline_width.value if outline_width != null else Factory.DEFAULT_OUTLINE_WIDTH
	Factory.set_outline_enabled(mat, pressed, width)
	mat.emit_changed()


func _set_cull_mode(mat: ShaderMaterial, index: int) -> void:
	if mat == null or mat.shader == null:
		return
	var next := Factory.with_cull_mode(mat.shader, index)
	if next == null or next == mat.shader:
		return
	mat.shader = next
	mat.emit_changed()


func _on_alpha_to_mask_toggled(mat: ShaderMaterial, pressed: bool) -> void:
	if mat == null:
		return
	if not Factory.set_alpha_to_mask(mat, pressed):
		_show_message("Alpha To Coverage", "该材质不是 Cutout 变体，无法切换 Alpha To Coverage。请先把材质切换为 Cutout。")
		return
	mat.emit_changed()


func _on_outline_width_changed(mat: ShaderMaterial, value: float) -> void:
	var outline := Factory.get_outline_material(mat)
	if outline == null:
		return
	outline.set_shader_parameter("outline_width", value)
	outline.emit_changed()


func _on_reset(mat: ShaderMaterial, outline_toggle: CheckBox, outline_width: SpinBox, a2c_toggle: CheckBox = null, cull_select: OptionButton = null) -> void:
	if mat == null:
		return
	Presets.apply_to_material(mat, "默认")
	Factory.sync_outline_distance_fade(mat)
	FurTools.sync_for_material(mat)
	if outline_toggle != null:
		outline_toggle.set_pressed_no_signal(Factory.outline_enabled(mat))
	if outline_width != null:
		outline_width.set_value_no_signal(_get_current_outline_width(mat))
	if a2c_toggle != null:
		a2c_toggle.set_pressed_no_signal(Factory.alpha_to_mask_of(mat.shader))
	if cull_select != null and mat.shader != null:
		cull_select.select(Factory.cull_mode_of(mat.shader))
	mat.emit_changed()


func _export_preset(mat: ShaderMaterial) -> void:
	var dialog := EditorFileDialog.new()
	dialog.title = "导出 liltoon 预设"
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "liltoon 预设")
	var base_name := mat.resource_name if mat.resource_name != "" else "liltoon"
	dialog.current_file = "%s_preset.tres" % base_name
	dialog.file_selected.connect(func(path: String) -> void:
		var preset := LiltoonPreset.from_material(mat)
		var err := ResourceSaver.save(preset, path)
		EditorInterface.get_resource_filesystem().scan()
		_show_message("导出预设", "已保存：%s\n错误码：%d" % [path, err])
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered_ratio(0.4)


func _import_preset(mat: ShaderMaterial, outline_toggle: CheckBox, outline_width: SpinBox) -> void:
	var dialog := EditorFileDialog.new()
	dialog.title = "导入 liltoon 预设"
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "liltoon 预设")
	dialog.file_selected.connect(func(path: String) -> void:
		var res = load(path)
		if res is LiltoonPreset:
			LiltoonPreset.apply_to_material(res, mat)
			Factory.sync_outline_distance_fade(mat)
			if outline_toggle != null:
				outline_toggle.set_pressed_no_signal(Factory.outline_enabled(mat))
			if outline_width != null:
				outline_width.set_value_no_signal(_get_current_outline_width(mat))
			var note := ""
			if not LiltoonPreset.variant_matches(res, mat):
				note = "\n注意：预设来自 %s，与当前材质变体不同，部分参数可能不生效。" % res.shader_path.get_file()
			_show_message("导入预设", "已应用预设：%s%s" % [path, note])
		else:
			_show_message("导入预设", "不是 liltoon 预设文件：%s" % path)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered_ratio(0.4)


func _on_import_preset(mat: ShaderMaterial) -> void:
	var dialog := EditorFileDialog.new()
	dialog.title = "导入 liltoon 预设（.asset）"
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.asset", "liltoon 预设")
	dialog.file_selected.connect(func(path: String) -> void:
		_apply_imported_preset(mat, path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered_ratio(0.5)


func _apply_imported_preset(mat: ShaderMaterial, path: String) -> void:
	if mat == null:
		return
	var parsed := PresetImport.parse_file(path)
	if bool(parsed.get("outline", false)):
		Factory.set_outline_enabled(mat, true)
	var mapped := PresetImport.map_to_material(parsed, mat)
	for key in mapped["applied"]:
		mat.set_shader_parameter(key, mapped["applied"][key])
	var outline := Factory.get_outline_material(mat)
	if outline != null:
		var outline_mapped := PresetImport.map_to_material(parsed, outline)
		for key in outline_mapped["applied"]:
			outline.set_shader_parameter(key, outline_mapped["applied"][key])
		outline.emit_changed()
	mat.emit_changed()
	_show_message("导入 liltoon 预设", "已应用 %d 项，跳过 %d 项（本插件无对应参数）。" % [mapped["applied"].size(), mapped["skipped"].size()])


func _show_message(title: String, text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = text
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()


# ============================================================================
# P4：预设缩略图（纯 CPU 绘制的配色小球，按预设名缓存，整会话只生成一次）
# ============================================================================


func _apply_preset_icons(preset_select: OptionButton) -> void:
	if preset_select == null or _preset_icons.is_empty():
		return
	for i in preset_select.item_count:
		var preset_name := preset_select.get_item_text(i)
		if _preset_icons.has(preset_name):
			preset_select.set_item_icon(i, _preset_icons[preset_name])


func _ensure_preset_icons() -> void:
	if not _preset_icons.is_empty():
		return
	for preset_name in Presets.get_names():
		# 优先使用 tools/bake_preset_thumbnails.tscn 烘焙的真实渲染缩略图；
		# 资源不存在时退回 CPU 绘制的示意球，保证面板永远有图标。
		var baked_path := PRESET_ICON_DIR + preset_name + ".png"
		if ResourceLoader.exists(baked_path):
			var texture = load(baked_path)
			if texture is Texture2D:
				_preset_icons[preset_name] = texture
				continue
		_preset_icons[preset_name] = ImageTexture.create_from_image(_draw_preset_icon(preset_name))


func _draw_preset_icon(preset_name: String) -> Image:
	const SIZE := 32
	var data := Presets.get_preset(preset_name)
	var main: Color = data.get("main_color", Color.WHITE)
	var shade: Color = data.get("shade_color", Color(0.5, 0.5, 0.5))
	var rim_enabled := bool(data.get("use_rim", false))
	var rim_color: Color = data.get("rim_color", Color.WHITE)
	var spec_enabled := bool(data.get("use_specular", true))

	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in SIZE:
		for x in SIZE:
			var dx := (x + 0.5 - SIZE * 0.5) / (SIZE * 0.5 - 1.0)
			var dy := (y + 0.5 - SIZE * 0.5) / (SIZE * 0.5 - 1.0)
			var d2 := dx * dx + dy * dy
			if d2 > 1.0:
				continue
			var nz := sqrt(maxf(0.0, 1.0 - d2))
			var lit := clampf(-dx * 0.45 - dy * 0.55 + nz * 0.7, 0.0, 1.0)
			var color := shade.lerp(main, smoothstep(0.38, 0.62, lit))
			if rim_enabled and d2 > 0.82:
				color = color.lerp(rim_color, 0.55)
			if spec_enabled and lit > 0.86:
				color = color.lerp(Color.WHITE, 0.65)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, 1.0))
	return image
