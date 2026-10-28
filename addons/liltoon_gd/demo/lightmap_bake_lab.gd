extends Node3D
## 光照贴图烘焙测试：运行时关闭静态光，
## 若 A 面仍被点亮，说明引擎的烘焙光照能进入 liltoon shader。

func _ready() -> void:
	var light := get_node_or_null("StaticLight") as Light3D
	if light != null:
		light.visible = false