extends Node3D
## 质量档位演示：按 1/2/3 切换高/中/低；直接运行时加 `-- bench` 会依次测三档并退出。

const QUALITY := preload("res://addons/liltoon_gd/quality/liltoon_quality.gd")
const BENCH_SECONDS := 2.5

var _material: ShaderMaterial
var _fps_label: Label
var _tier_label: Label
const BENCH_WARMUP := 0.5

var _bench_mode := false
var _bench_index := 0
var _bench_elapsed := 0.0
var _bench_frames := 0
var _bench_frame_time := 0.0
var _bench_tiers: Array = []
var _bench_results: Array[String] = []


func _ready() -> void:
	var sphere := get_node_or_null("Sphere") as MeshInstance3D
	if sphere != null:
		_material = sphere.material_override as ShaderMaterial
	_build_ui()
	_bench_tiers = QUALITY.tiers()
	if OS.get_cmdline_user_args().has("bench"):
		var f := FileAccess.open("user://quality_bench.txt", FileAccess.WRITE)
		if f != null:
			f.close()
		# 垂直同步会把三档都钉在刷新率上，基准必须关闭才能看出差异。
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		_bench_mode = true
		_apply_tier(_bench_tiers[0])
	else:
		_apply_tier(QUALITY.TIER_HIGH)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(24.0, 20.0)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "质量档位演示（1 高 / 2 中 / 3 低）"
	title.add_theme_font_size_override("font_size", 16)
	panel.add_child(title)
	_tier_label = Label.new()
	panel.add_child(_tier_label)
	_fps_label = Label.new()
	panel.add_child(_fps_label)


func _process(delta: float) -> void:
	if _fps_label != null:
		_fps_label.text = "FPS %d" % Engine.get_frames_per_second()
	if not _bench_mode:
		return
	_bench_elapsed += delta
	# 切档后的前几帧包含 shader 编译与资源绑定，先跳过再统计，避免首档虚高。
	if _bench_elapsed < BENCH_WARMUP:
		return
	_bench_frames += 1
	_bench_frame_time += delta
	if _bench_elapsed < BENCH_SECONDS:
		return
	var avg_ms := _bench_frame_time / maxf(float(_bench_frames), 1.0) * 1000.0
	var fps := int(round(1000.0 / maxf(avg_ms, 0.001)))
	print("TIER=%s FPS=%d MS=%.2f" % [_bench_tiers[_bench_index], fps, avg_ms])
	_bench_results.append("%s=%d FPS, %.2f ms" % [_bench_tiers[_bench_index], fps, avg_ms])
	_bench_index += 1
	_bench_elapsed = 0.0
	_bench_frames = 0
	_bench_frame_time = 0.0
	if _bench_index >= _bench_tiers.size():
		_write_bench_results()
		get_tree().quit()
	else:
		_apply_tier(_bench_tiers[_bench_index])


func _write_bench_results() -> void:
	var file := FileAccess.open("user://quality_bench.txt", FileAccess.WRITE)
	if file == null:
		return
	for line in _bench_results:
		file.store_line(line)
	file.close()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_1:
			_apply_tier(QUALITY.TIER_HIGH)
		elif key == KEY_2:
			_apply_tier(QUALITY.TIER_MEDIUM)
		elif key == KEY_3:
			_apply_tier(QUALITY.TIER_LOW)


func _apply_tier(tier: String) -> void:
	QUALITY.apply(_material, tier)
	if _tier_label != null:
		_tier_label.text = "当前档位：%s" % tier
