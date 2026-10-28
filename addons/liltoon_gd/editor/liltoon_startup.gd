class_name LiltoonStartup
extends RefCounted
## 对齐 lilToon 的 lilStartup：编辑器启动时做版本检查与迁移提示。
##
## 与原版差异：原版有 12 KB 的版本迁移链（旧材质自动改属性名）；这里只做
## 版本对比 + 过时参数名扫描，发现迁移需求时提示用户执行「校验并修复」。


const Settings := preload("res://addons/liltoon_gd/editor/liltoon_setting.gd")


## 启动检查：返回提示列表（空 = 无事）。只读，不修改任何资源。
static func check() -> PackedStringArray:
	var tips := PackedStringArray()
	var current := Settings.plugin_version()
	var previous := str(Settings.get_value("installed_version"))

	if previous.is_empty():
		tips.append("首次安装 liltoon_gd %s。建议先跑「校验并修复选中材质（资源）」。" % current)
	elif previous != current:
		tips.append("liltoon_gd 已从 %s 升级到 %s。建议跑一次冒烟测试（tools/smoke.ps1）。" % [previous, current])

	Settings.set_value("installed_version", current)
	return tips


## 扫描项目内 .tres 材质是否含过时参数名（如 bool 形态的 shadow_receive）。
## 返回 [Dictionary]：path -> 过时键列表。
static func scan_deprecated_keys(root: String = "res://") -> Dictionary:
	var found := {}
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	_scan_dir(dir, root, found)
	return found


static func _scan_dir(dir: DirAccess, base: String, found: Dictionary) -> void:
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var full := base.path_join(name)
			if dir.current_is_dir():
				var sub := DirAccess.open(full)
				if sub != null:
					_scan_dir(sub, full, found)
			elif name.ends_with(".tres") or name.ends_with(".tscn"):
				var text := FileAccess.get_file_as_string(full)
				var deprecated := PackedStringArray()
				# P9 把三个 bool 改成 float 程度值，旧场景里的 true/false 会被静默拒绝
				for key in ["shadow_receive", "rim_enable_lighting", "rim_shadow_mask"]:
					if text.contains(key + " = true") or text.contains(key + " = false"):
						deprecated.append(key)
				if not deprecated.is_empty():
					found[full] = deprecated
		name = dir.get_next()
	dir.list_dir_end()
