extends Node3D
## 综合效果演示：各向异性 + Glitter + Parallax。
## 直接运行时追加 `-- shot` 会把视口保存到 user://feature_lab.png 并退出。


func _ready() -> void:
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("user://feature_lab.png")
	get_tree().quit()
