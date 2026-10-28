extends Node3D
## 渲染编译自检：把指定 shader 挂在一个四边形上，跑几帧后退出。
## 判读方式：stderr 里没有 `SHADER ERROR` 即该变体在当前渲染器下编译通过。
##
## 安全警告（重要）：
##   本机（Intel UHD 617 + D3D12）在一次性加载全部 shader、并开启 MSAA 与阴影时，
##   曾两次触发 0x00000139 蓝屏（KERNEL_SECURITY_CHECK_FAILURE，内核链表损坏）。
##   因此本工具默认**只编译一个 shader**、关闭 MSAA 与阴影，必须用参数指定目标；
##   需要全量检查时请在外层脚本里逐个循环调用，每次一个独立进程。
##
## 用法：
##   Godot --path . res://tools/compile_check.tscn --quit-after 12 --resolution 640x360 -- --shader=liltoon_opaque.gdshader
##   Godot --path . res://tools/compile_check.tscn --quit-after 12 --resolution 640x360 -- --index=0
##   Godot --path . res://tools/compile_check.tscn --quit-after 1 -- --list
## 可加 `--rendering-method mobile` / `--rendering-method gl_compatibility` 覆盖其他渲染器。

## 主材质与描边在 shaders/，后处理描边在 effects/，特殊材质（假阴影/宝石）在 shaders/extra/。
## 三个目录**先后追加**而不是混排，保证既有索引不因新增目录而错位
## （历史日志里的 index 仍然对得上）。
const SHADER_DIRS := [
	"res://addons/liltoon_gd/shaders/",
	"res://addons/liltoon_gd/effects/",
	"res://addons/liltoon_gd/shaders/extra/",
]


func _ready() -> void:
	# 不启用 MSAA：全量加载 + 4x MSAA 是此前蓝屏的配置之一。
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.12)
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var camera := Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.0, 3.0), Vector3.ZERO)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30.0, 25.0, 0.0)
	# 默认不投影：阴影 pass 会额外编译变体，是蓝屏时的另一个负载来源。
	light.shadow_enabled = false
	add_child(light)

	# 逐目录追加，各自排序；目录之间不混排，保持既有索引稳定
	var shaders: Array[String] = []
	for dir in SHADER_DIRS:
		var local: Array[String] = []
		for file_name in DirAccess.get_files_at(dir):
			if file_name.ends_with(".gdshader"):
				local.append(dir + file_name)
		local.sort()
		shaders.append_array(local)

	var args := _parse_args()
	if args.has("list"):
		for shader_name in shaders:
			print("COMPILE_CHECK_LIST ", shader_name)
		get_tree().quit()
		return
	if shaders.is_empty():
		push_error("compile_check: 没有找到任何 .gdshader")
		get_tree().quit(1)
		return

	var target := ""
	if args.has("shader"):
		# 允许只写文件名（liltoon_opaque.gdshader）或完整 res:// 路径
		var want := str(args["shader"])
		for shader_path in shaders:
			if shader_path == want or shader_path.get_file() == want:
				target = shader_path
				break
		if target.is_empty():
			push_error("compile_check: 找不到 shader " + want)
			get_tree().quit(1)
			return
	else:
		var index := int(args.get("index", "0"))
		if index < 0 or index >= shaders.size():
			push_error("compile_check: index 超出范围 0..%d" % (shaders.size() - 1))
			get_tree().quit(1)
			return
		target = shaders[index]

	var shader: Shader = load(target)
	if shader == null:
		push_error("compile_check: 无法加载 " + target)
		get_tree().quit(1)
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.0, 1.0)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	add_child(instance)

	print("COMPILE_CHECK name=", target, " index=", shaders.find(target), " total=", shaders.size())
	_finish_later()


func _parse_args() -> Dictionary:
	var parsed := {}
	for arg in OS.get_cmdline_user_args():
		var text := arg.trim_prefix("--")
		var pair := text.split("=", true, 1)
		if pair.size() == 2:
			parsed[pair[0]] = pair[1]
		else:
			parsed[pair[0]] = ""
	return parsed


func _finish_later() -> void:
	# 留出几帧给引擎创建管线；--quit-after 也会兜底退出。
	for i in 6:
		await get_tree().process_frame
	print("COMPILE_CHECK_DONE")
	get_tree().quit()
