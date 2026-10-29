extends Node3D

## rim_blend_mode 四式对照：0 Normal / 1 Add（默认）/ 2 Screen / 3 Multiply。
## 对应原版 `lilBlendColor`（lil_common_functions.hlsl:325-335）与
## `lil_common_frag.hlsl:1694-1697` 的调用。
##
## 判读：Add 最亮（现状），Screen 更亮但趋于饱和，Normal 边缘光直接替换基色（最"实"），
## Multiply 最暗（正片叠底，且按原版语义此时边缘光不受光）。

func _ready() -> void:
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("user://blend_modes_lab.png")
		print("blend_modes_lab: 截图已保存 blend_modes_lab.png")
	get_tree().quit()
