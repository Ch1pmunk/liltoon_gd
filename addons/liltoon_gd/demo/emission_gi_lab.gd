extends Node3D

## 自发光是否参与 LightmapGI 烘焙的对照场景（对应原版 META pass 的自发光输出）。
##
## A = 本项目材质 + 自发光（绿）
## B = 本项目材质 + 无自发光
## C = StandardMaterial3D + 同样能量的绿自发光（引擎原生对照）
##
## 判读方式：
## - 烘焙后地板在 **A 下方泛绿** → 本项目的 emission 参与了 GI；
## - 只有 **C 下方泛绿** → 本项目材质（ShaderMaterial）的 emission 未参与 GI，
##   与原版 META pass 输出 Emission 的行为不等价，需要单独给出替代方案（例如烘焙用的代理材质）。
##
## 已烘焙时本脚本会关掉实时光，确保看到的只剩烘焙光；未烘焙时保留实时光，避免画面全黑。

func _ready() -> void:
	var lightmap := get_node_or_null("LightmapGI") as LightmapGI
	var light := get_node_or_null("StaticLight") as Light3D
	if lightmap != null and lightmap.light_data != null and light != null:
		light.visible = false
		print("emission_gi_lab: 检测到已烘焙数据，已关闭实时光（画面只剩烘焙光）")
	else:
		print("emission_gi_lab: 尚未烘焙，保留实时光；请选中 LightmapGI 点「烘焙光照」")

	# 与其他 lab 一致：直接运行时追加 `-- shot` 会截图到 user:// 并退出
	if OS.get_cmdline_user_args().has("shot"):
		_take_shot()


func _take_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		var baked := false
		var lightmap := get_node_or_null("LightmapGI") as LightmapGI
		if lightmap != null and lightmap.light_data != null:
			baked = true
		var file_name := "emission_gi_lab_baked.png" if baked else "emission_gi_lab_unbaked.png"
		image.save_png("user://" + file_name)
		print("emission_gi_lab: 截图已保存 ", file_name)
	get_tree().quit()
