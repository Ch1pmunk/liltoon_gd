@tool
extends RefCounted
## 解析 shader 及其 include 链中的 `/** */` 文档注释，返回 uniform 名称到描述文本的映射。
## 不依赖编辑器类，便于在无头冒烟测试中复用。

const DOC_PATTERN := "(?ms)^\\s*/\\*\\*((?:(?!\\*/).)*)\\*/\\s*uniform\\s+[A-Za-z0-9_]+\\s+([A-Za-z0-9_]+)"
const INCLUDE_PATTERN := "#include\\s+\"([^\"]+)\""


static func collect(shader_path: String) -> Dictionary:
	var docs := {}
	_collect_into(shader_path, docs, {})
	return docs


static func _collect_into(path: String, docs: Dictionary, visited: Dictionary) -> void:
	if visited.has(path) or not FileAccess.file_exists(path):
		return
	visited[path] = true

	var text := FileAccess.get_file_as_string(path)
	var doc_regex := RegEx.new()
	doc_regex.compile(DOC_PATTERN)
	for match_result in doc_regex.search_all(text):
		docs[match_result.get_string(2)] = _clean(match_result.get_string(1))

	var include_regex := RegEx.new()
	include_regex.compile(INCLUDE_PATTERN)
	for match_result in include_regex.search_all(text):
		_collect_into(match_result.get_string(1), docs, visited)


static func _clean(raw: String) -> String:
	var lines := []
	for line in raw.split("\n"):
		var cleaned := line.strip_edges()
		if cleaned.begins_with("*"):
			cleaned = cleaned.substr(1).strip_edges()
		if cleaned != "":
			lines.append(cleaned)
	return "\n".join(lines)
