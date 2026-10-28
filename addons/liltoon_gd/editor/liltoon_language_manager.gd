class_name LiltoonLanguageManager
extends RefCounted
## 对齐 lilToon 的 lilLanguageManager：编辑器 UI 文案多语言。
## 当前支持 zh / en，默认 zh（项目原本仅中文，这里补英文便于分发）。
##
## 与原版差异：原版 19 KB 支持 10+ 语言并从外部文件加载；这里内置字典、
## 只覆盖编辑器菜单与对话框文案，shader 参数的 Inspector 描述仍是中文。


const STRINGS := {
	"zh": {
		"create_material": "创建材质",
		"convert_resources": "转换选中材质（资源）",
		"convert_nodes": "批量转换选中节点的材质",
		"validate": "校验并修复选中材质（资源）",
		"bake": "烘焙选中材质的主色贴图…",
		"optimize": "分析选中材质的优化建议",
		"settings": "全局设置…",
		"add_fur": "为选中网格添加毛发壳层",
		"sync_fur": "同步选中网格的毛发参数",
		"replace_material": "批量替换选中网格的材质…",
		"no_selection": "请先选中节点或材质。",
		"done": "完成",
	},
	"en": {
		"create_material": "Create Material",
		"convert_resources": "Convert Selected Materials (Resources)",
		"convert_nodes": "Convert Materials on Selected Nodes",
		"validate": "Validate & Repair Selected Materials",
		"bake": "Bake Main Texture of Selected Materials…",
		"optimize": "Analyze Selected Materials for Optimizations",
		"settings": "Global Settings…",
		"add_fur": "Add Fur Shells to Selected Meshes",
		"sync_fur": "Sync Fur Parameters on Selected Meshes",
		"replace_material": "Replace Materials on Selected Meshes…",
		"no_selection": "Select nodes or materials first.",
		"done": "Done",
	},
}


const Settings := preload("res://addons/liltoon_gd/editor/liltoon_setting.gd")


## 取文案；缺失时回退到 key 本身。（不叫 tr，避开 Object.tr 内置方法）
static func tr_text(key: String) -> String:
	var lang := str(Settings.get_value("language"))
	var table: Dictionary = STRINGS.get(lang, STRINGS["zh"])
	return str(table.get(key, key))


## 列出支持的语言代码。
static func languages() -> Array:
	return STRINGS.keys()
