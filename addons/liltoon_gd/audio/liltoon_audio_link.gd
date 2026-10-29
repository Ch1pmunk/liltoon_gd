extends Node
## liltoon_gd AudioLink 等价实现（对应 lilToon 的 LIL_FEATURE_AUDIOLINK）
##
## 原版依赖 VRChat 的 AudioLink 服务：它把 4 个频段的频谱写成一张随时间滚动的
## 全局纹理 `_AudioTexture`（列 = 时间、行 = 频段），材质再按 UV 采样这张纹理。
## Godot 没有这个服务，本脚本用 AudioEffectSpectrumAnalyzer 自己算：
##
##   音频总线 → 频谱分析 → 4 频段幅值 → 128 列历史环形缓冲 → 全局纹理
##                                                    ↘ 当前值写入全局 vec4
##
## 暴露的全局 uniform（shader 里用 `global uniform` 读取）：
##   audiolink_texture  sampler2D  128×4，行 = 频段（低→高），列 = 时间（越右越新）
##   audiolink_bands    vec4       当前 4 个频段的幅值（0..1）
##   audiolink_time     float      已写入的列数 / 128，配合 shader 里的 TIME 做时间对齐
##
## 用法：把本脚本挂成 autoload（单例名 LiltoonAudioLink），再在材质里打开 `use_audiolink`。

const HISTORY_LEN := 128
const BAND_COUNT := 4
## 4 个频段的频率范围（Hz），对应 AudioLink 的 Bass / Low Mid / High Mid / Treble。
const BANDS := [
	Vector2(20.0, 250.0),
	Vector2(250.0, 1000.0),
	Vector2(1000.0, 4000.0),
	Vector2(4000.0, 20000.0),
]
## 幅值放大倍数：频谱分析返回的是线性幅值，通常很小，放大后才有可用动态范围。
@export var gain := 8.0:
	set(v):
		gain = maxf(v, 0.0)
## 每个频段的平滑系数（0=不跟随，1=立刻跟随）。
@export var smoothing := 0.4
## 要分析的音频总线名；留空则用 Master。
@export var bus_name := "Master"

var _analyzer: AudioEffectSpectrumAnalyzerInstance = null
var _effect_index := -1
var _bus_index := -1
var _history := PackedFloat32Array()
var _write_col := 0
var _texture: ImageTexture
var _image: Image
var _ready_done := false
var _available := false
var _last_silent := false


func _ready() -> void:
	_history.resize(HISTORY_LEN * BAND_COUNT)
	_history.fill(0.0)
	_image = Image.create(HISTORY_LEN, BAND_COUNT, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0, 0, 0, 1))
	_texture = ImageTexture.create_from_image(_image)

	# 三个全局参数由 project.godot 的 [shader_globals] 预注册（见 ensure_globals()）。
	# 运行期不再 add：重复登记会报错，而 global_shader_parameter_get_list 是编辑器专用 API。

	_available = _setup_analyzer()
	_ready_done = true
	if not _available:
		push_warning("liltoon_gd AudioLink: 未找到可用的频谱分析器，shader 会回退到合成脉冲。")


## 把三个全局参数写进 ProjectSettings（对应 project.godot 的 [shader_globals]）。
## 由插件的「启用 AudioLink 全局参数」菜单调用；迁移到新项目时必须先执行一次，
## 否则 shader 里 `global uniform` 取不到值。
static func ensure_globals() -> bool:
	var changed := false
	var wanted := {
		"audiolink_bands": {"type": "vec4", "value": "Vector4(0, 0, 0, 0)"},
		"audiolink_texture": {"type": "sampler2D", "value": ""},
		"audiolink_time": {"type": "float", "value": 0.0},
	}
	for key in wanted:
		var path: String = "shader_globals/" + str(key)
		if not ProjectSettings.has_setting(path):
			ProjectSettings.set_setting(path, wanted[key])
			changed = true
	if changed:
		ProjectSettings.save()
	return changed


## 在当前总线上挂一个 SpectrumAnalyzer，并拿到它的实例。
func _setup_analyzer() -> bool:
	_bus_index = AudioServer.get_bus_index(bus_name)
	if _bus_index < 0:
		push_warning("liltoon_gd AudioLink: 总线 \"%s\" 不存在，改用 Master。" % bus_name)
		_bus_index = AudioServer.get_bus_index("Master")
		if _bus_index < 0:
			return false

	# 已有就复用，避免重复添加
	for i in AudioServer.get_bus_effect_count(_bus_index):
		if AudioServer.get_bus_effect(_bus_index, i) is AudioEffectSpectrumAnalyzer:
			_effect_index = i
			break
	if _effect_index < 0:
		var fx := AudioEffectSpectrumAnalyzer.new()
		fx.buffer_length = 2.0
		fx.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
		AudioServer.add_bus_effect(_bus_index, fx)
		_effect_index = AudioServer.get_bus_effect_count(_bus_index) - 1

	var inst = AudioServer.get_bus_effect_instance(_bus_index, _effect_index)
	_analyzer = inst as AudioEffectSpectrumAnalyzerInstance
	return _analyzer != null


func _process(_delta: float) -> void:
	if not _ready_done:
		return
	var bands := Vector4.ZERO
	for i in BAND_COUNT:
		var mag := 0.0
		if _analyzer != null:
			var v: Vector2 = _analyzer.get_magnitude_for_frequency_range(BANDS[i].x, BANDS[i].y)
			mag = v.length() * gain
		mag = clampf(mag, 0.0, 1.0)
		bands[i] = mag
		_push_sample(i, mag)
	# 推进环形缓冲：_write_col 指向"下一帧要写的位置"，写完再前进
	_write_col = (_write_col + 1) % HISTORY_LEN
	# 静音节流：全零且上一帧也全零时不重建纹理，避免给不用 AudioLink 的用户白付开销
	var silent := is_zero_approx(bands.x + bands.y + bands.z + bands.w)
	if not (silent and _last_silent):
		_rebuild_texture()
		RenderingServer.global_shader_parameter_set("audiolink_texture", _texture)
	_last_silent = silent
	RenderingServer.global_shader_parameter_set("audiolink_bands", bands)
	RenderingServer.global_shader_parameter_set("audiolink_time", float(_write_col) / float(HISTORY_LEN))


func _push_sample(band: int, value: float) -> void:
	var idx := band * HISTORY_LEN + _write_col
	var prev := _history[idx]
	# 平滑：上升快、下降慢，视觉上更接近 AudioLink 的表现
	var s := smoothing if value > prev else smoothing * 0.35
	_history[idx] = lerpf(prev, value, 1.0 - s)


func _rebuild_texture() -> void:
	# 环形缓冲 → 纹理：最右列是最新
	for band in BAND_COUNT:
		for col in HISTORY_LEN:
			# col=0 是最旧的一列，col=LEN-1 是最新写入的一列
			var src := (_write_col + col) % HISTORY_LEN
			var v := _history[band * HISTORY_LEN + src]
			_image.set_pixel(col, band, Color(v, v, v, 1.0))
	_texture.update(_image)


func _exit_tree() -> void:
	# 全局参数属于工程设置（[shader_globals]），不在这里删；总线效果可能是用户自己挂的，也不动。
	pass


## 供材质/演示脚本查询当前频段值（0..1）。
func get_band(band: int) -> float:
	var idx := clampi(band, 0, BAND_COUNT - 1) * HISTORY_LEN + _write_col
	return _history[idx]


## 频谱分析是否可用；不可用时 shader 会走合成脉冲。
func is_available() -> bool:
	return _available
