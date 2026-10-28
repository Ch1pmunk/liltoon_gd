class_name LiltoonSetting
extends RefCounted
## 对齐 lilToon 的 lilToonSetting：全局设置（默认预设、性能档、烘焙尺寸、语言、版本）。
## 用 ProjectSettings 持久化（`liltoon_gd/*`），不依赖 Unity 的 EditorPrefs。
##
## 与原版差异：原版有 95 KB 的设置窗口（分类/搜索/重置）；这里只提供键值读写与
## 一个精简对话框，设置项覆盖常用部分。


const PREFIX := "liltoon_gd/"

const DEFAULTS := {
	"default_preset": "默认",
	"quality_tier": "high",
	"bake_size": 512,
	"language": "zh",
	"installed_version": "",
	"startup_check_done": false,
}


static func get_value(key: String) -> Variant:
	var full := PREFIX + key
	if ProjectSettings.has_setting(full):
		return ProjectSettings.get_setting(full)
	return DEFAULTS.get(key)


static func set_value(key: String, value: Variant) -> void:
	ProjectSettings.set_setting(PREFIX + key, value)
	ProjectSettings.save()


static func ensure_defaults() -> void:
	for key in DEFAULTS:
		if not ProjectSettings.has_setting(PREFIX + key):
			ProjectSettings.set_setting(PREFIX + key, DEFAULTS[key])
	ProjectSettings.save()


## 当前插件版本（读 plugin.cfg）。
static func plugin_version() -> String:
	var cfg := ConfigFile.new()
	var path := "res://addons/liltoon_gd/plugin.cfg"
	if cfg.load(path) != OK:
		return ""
	return str(cfg.get_value("plugin", "version", ""))


## 生成设置摘要文本（用于对话框展示）。
static func summary() -> String:
	var lines := PackedStringArray()
	for key in DEFAULTS:
		lines.append("%s = %s" % [key, str(get_value(key))])
	return "\n".join(lines)
