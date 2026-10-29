class_name LiltoonGifTools
extends RefCounted
## 对齐 lilToon 的「GIF → 图集」（原版 `Editor/GifParser/` 5 个文件 +
## `lilTextureUtils.ConvertGifToAtlas`，入口 `lilToonEditorUtils.cs:135`）。
##
## 复刻范围：
## - GIF87a/89a 解析：逻辑屏幕、全局/局部调色板、图形控制扩展（延时/disposal/透明索引）、
##   图像描述符（含交错）。
## - LZW 解码：变长码（min+1 → 12）、clear/end 码、字典项自引用（`code == next`）分支。
## - 逐帧合成：画布叠加 + disposal 0/1 保留、2 清本帧区域、3 回滚到本帧之前。
## - 图集布局（`lilTextureUtils.cs:273-311`）：`loopXY = ceil(sqrt(帧数))`，
##   第 i 帧放在格子 `(i % loopXY, floor(i / loopXY))`，可选补到 2 的幂并给出
##   `xScale` / `yScale`（原版用它们把 UV 归一到有效区域）。
##
## 与原版差异：原版用 `BinaryReader` + `List<byte>`，这里用 `PackedByteArray` + `Array`，
## 算法逐行对应；输出文件名沿用原版 `<名称>_gif2png_<loopXY>_<帧数>_<延时>.png`。


## 解析 GIF 字节流。返回 {ok, width, height, global_colors, frames, error}。
static func parse_gif(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 13:
		return {"ok": false, "width": 0, "height": 0, "global_colors": PackedColorArray(), "frames": [], "error": "文件太短"}
	var signature := bytes.slice(0, 6).get_string_from_ascii()
	if signature != "GIF87a" and signature != "GIF89a":
		return {"ok": false, "width": 0, "height": 0, "global_colors": PackedColorArray(), "frames": [], "error": "不是 GIF 文件（签名 %s）" % signature}

	var reader := _Reader.new(bytes)
	reader.pos = 6
	var width := reader.u16()
	var height := reader.u16()
	var packed := reader.u8()
	reader.u8()
	reader.u8()
	var global_colors := PackedColorArray()
	if (packed & 0x80) != 0:
		global_colors = reader.color_table(1 << ((packed & 0x07) + 1))

	var frames: Array = []
	var gce := {"delay": 0, "disposal": 0, "transparent": -1}
	while reader.remaining() > 0:
		var introducer := reader.u8()
		if introducer == 0x21:
			var label := reader.u8()
			if label == 0xF9:
				reader.u8()  # 块长度固定 4
				var control := reader.u8()
				var delay := reader.u16()
				var transparent_index := reader.u8()
				reader.u8()  # 块终止符
				gce = {
					"delay": delay,
					"disposal": (control >> 2) & 0x07,
					"transparent": transparent_index if (control & 0x01) != 0 else -1,
				}
			else:
				reader.sub_blocks()
		elif introducer == 0x2C:
			var left := reader.u16()
			var top := reader.u16()
			var frame_w := reader.u16()
			var frame_h := reader.u16()
			var frame_packed := reader.u8()
			var local_colors := PackedColorArray()
			if (frame_packed & 0x80) != 0:
				local_colors = reader.color_table(1 << ((frame_packed & 0x07) + 1))
			var min_code_size := reader.u8()
			var compressed := reader.sub_blocks()
			frames.append({
				"left": left, "top": top, "width": frame_w, "height": frame_h,
				"interlaced": (frame_packed & 0x40) != 0,
				"local_colors": local_colors,
				"min_code_size": min_code_size,
				"data": compressed,
				"delay": gce["delay"],
				"disposal": gce["disposal"],
				"transparent": gce["transparent"],
			})
			gce = {"delay": 0, "disposal": 0, "transparent": -1}
		elif introducer == 0x3B:
			break
		else:
			return {"ok": false, "width": width, "height": height, "global_colors": global_colors,
				"frames": frames, "error": "未知块 0x%02X" % introducer}

	if frames.is_empty():
		return {"ok": false, "width": width, "height": height, "global_colors": global_colors,
			"frames": frames, "error": "没有可解析的图像帧"}
	return {"ok": true, "width": width, "height": height, "global_colors": global_colors,
		"frames": frames, "error": ""}


## LZW 解码，对应原版 `GifLzwDecoder.Decode`。
static func decode_lzw(compressed: PackedByteArray, min_code_size: int, expected_pixels: int) -> PackedByteArray:
	var output := PackedByteArray()
	if min_code_size < 1 or min_code_size > 11:
		return output
	var clear_code := 1 << min_code_size
	var end_code := clear_code + 1
	var dictionary: Array = []
	var state := {"pos": 0, "next": 0, "size": 0, "max": 0}
	_reset_lzw(dictionary, state, min_code_size)

	var previous_code := -1
	while true:
		var code := _read_bits(compressed, state, state["size"])
		if code < 0:
			break
		if code == clear_code:
			_reset_lzw(dictionary, state, min_code_size)
			previous_code = -1
			continue
		if code == end_code:
			break

		var entry: PackedByteArray
		if code < state["next"] and code < dictionary.size() and dictionary[code] != null:
			entry = dictionary[code]
		elif code == state["next"] and previous_code >= 0:
			var prev: PackedByteArray = dictionary[previous_code]
			if prev.is_empty():
				break
			entry = prev.duplicate()
			entry.append(prev[0])
		else:
			# 与 C# 一致：非法码直接中断，返回已解出的部分
			break

		output.append_array(entry)

		if previous_code >= 0:
			var prev_entry: PackedByteArray = dictionary[previous_code]
			if not prev_entry.is_empty() and state["next"] < 4096:
				var new_entry := prev_entry.duplicate()
				new_entry.append(entry[0])
				dictionary[state["next"]] = new_entry
				state["next"] += 1
				if state["next"] > state["max"] and state["size"] < 12:
					state["size"] += 1
					state["max"] = (1 << state["size"]) - 1

		previous_code = code
		if output.size() >= expected_pixels:
			break
	return output


## 逐帧合成，对应原版 `GifFrameComposer.Compose`。返回 Array[Image]（每帧整幅画布）。
static func compose_frames(gif: Dictionary) -> Array[Image]:
	var result: Array[Image] = []
	if not gif.get("ok", false):
		return result
	var canvas_width: int = gif["width"]
	var canvas_height: int = gif["height"]
	var clear_color := Color(0, 0, 0, 0)
	var canvas := PackedColorArray()
	canvas.resize(canvas_width * canvas_height)
	for i in canvas.size():
		canvas[i] = clear_color

	for frame in gif["frames"]:
		var before := canvas.duplicate()
		_render_frame(gif, frame, canvas)
		var image := Image.create(canvas_width, canvas_height, false, Image.FORMAT_RGBA8)
		for y in canvas_height:
			for x in canvas_width:
				image.set_pixel(x, y, canvas[y * canvas_width + x])
		result.append(image)
		_apply_disposal(gif, frame, canvas, before, clear_color)
	return result


## 计算图集布局，对应 `lilTextureUtils.cs:273-289`。
## 返回 {loop_xy, width, height, x_scale, y_scale}
static func atlas_layout(cell: Vector2i, frame_count: int, pow2: bool) -> Dictionary:
	var loop_xy := int(ceil(sqrt(float(frame_count))))
	if loop_xy < 1:
		loop_xy = 1
	var content := Vector2i(cell.x * loop_xy, cell.y * loop_xy)
	var final := content
	if pow2:
		# 从 1 开始翻倍到不小于内容尺寸（原版 lilTextureUtils.cs:279-280 的写法）
		final = Vector2i(1, 1)
		while final.x < content.x:
			final.x *= 2
		while final.y < content.y:
			final.y *= 2
	return {
		"loop_xy": loop_xy,
		"width": final.x,
		"height": final.y,
		"x_scale": float(content.x) / float(final.x),
		"y_scale": float(content.y) / float(final.y),
	}


## 把帧拼成图集（左上角起始，帧 i 放在 (i % loopXY, i / loopXY) 格）。
static func make_atlas(frames: Array[Image], layout: Dictionary) -> Image:
	if frames.is_empty():
		return null
	var loop_xy: int = layout["loop_xy"]
	var width: int = layout["width"]
	var height: int = layout["height"]
	var atlas := Image.create(width, height, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	for index in frames.size():
		var frame := frames[index]
		var offset_x := (index % loop_xy) * frame.get_width()
		var offset_y := (index / loop_xy) * frame.get_height()
		atlas.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(offset_x, offset_y))
	return atlas


## 一步到位：字节流 → 图集。返回 {ok, image, frame_count, loop_xy, duration, x_scale, y_scale, error}。
## `duration` 为原版口径：第 0 帧延时（GIF 单位 1/100 秒）。
static func convert(bytes: PackedByteArray, pow2: bool = true) -> Dictionary:
	var gif := parse_gif(bytes)
	if not gif["ok"]:
		return {"ok": false, "image": null, "frame_count": 0, "loop_xy": 0, "duration": 0,
			"x_scale": 1.0, "y_scale": 1.0, "error": gif["error"]}
	var frames := compose_frames(gif)
	if frames.is_empty():
		return {"ok": false, "image": null, "frame_count": 0, "loop_xy": 0, "duration": 0,
			"x_scale": 1.0, "y_scale": 1.0, "error": "没有合成出任何帧"}
	var layout := atlas_layout(Vector2i(gif["width"], gif["height"]), frames.size(), pow2)
	var atlas := make_atlas(frames, layout)
	return {
		"ok": atlas != null,
		"image": atlas,
		"frame_count": frames.size(),
		"loop_xy": layout["loop_xy"],
		"duration": int(gif["frames"][0]["delay"]),
		"x_scale": layout["x_scale"],
		"y_scale": layout["y_scale"],
		"error": "" if atlas != null else "图集合成失败",
	}


static func _reset_lzw(dictionary: Array, state: Dictionary, min_code_size: int) -> void:
	dictionary.clear()
	dictionary.resize(4096)
	for i in 4096:
		dictionary[i] = null
	var clear_count := 1 << min_code_size
	for i in clear_count:
		dictionary[i] = PackedByteArray([i])
	state["next"] = clear_count + 2
	state["size"] = min_code_size + 1
	state["max"] = (1 << int(state["size"])) - 1


static func _read_bits(data: PackedByteArray, state: Dictionary, count: int) -> int:
	var value := 0
	for i in count:
		var bit_position: int = state["pos"]
		var byte_index := bit_position >> 3
		if byte_index >= data.size():
			return -1
		var bit := (data[byte_index] >> (bit_position & 7)) & 1
		value |= bit << i
		state["pos"] = bit_position + 1
	return value


static func _render_frame(gif: Dictionary, frame: Dictionary, canvas: PackedColorArray) -> void:
	var colors: PackedColorArray = frame["local_colors"]
	if colors.is_empty():
		colors = gif["global_colors"]
	var indices := decode_lzw(frame["data"], int(frame["min_code_size"]), int(frame["width"]) * int(frame["height"]))
	if frame["interlaced"]:
		indices = _deinterlace(indices, int(frame["width"]), int(frame["height"]))
	var src := 0
	var canvas_width: int = gif["width"]
	var canvas_height: int = gif["height"]
	for y in int(frame["height"]):
		var dst_y := int(frame["top"]) + y
		if dst_y < 0 or dst_y >= canvas_height:
			src += int(frame["width"])
			continue
		for x in int(frame["width"]):
			var dst_x := int(frame["left"]) + x
			if dst_x < 0 or dst_x >= canvas_width:
				src += 1
				continue
			if src >= indices.size():
				return
			var index := indices[src]
			src += 1
			if index == int(frame["transparent"]) or index >= colors.size():
				continue
			canvas[dst_y * canvas_width + dst_x] = colors[index]


static func _apply_disposal(gif: Dictionary, frame: Dictionary, canvas: PackedColorArray, before: PackedColorArray, clear_color: Color) -> void:
	match int(frame["disposal"]):
		2:
			var start_x := maxi(int(frame["left"]), 0)
			var start_y := maxi(int(frame["top"]), 0)
			var end_x := mini(int(frame["left"]) + int(frame["width"]), int(gif["width"]))
			var end_y := mini(int(frame["top"]) + int(frame["height"]), int(gif["height"]))
			for y in range(start_y, end_y):
				for x in range(start_x, end_x):
					canvas[y * int(gif["width"]) + x] = clear_color
		3:
			for i in canvas.size():
				canvas[i] = before[i]
		_:
			pass


static func _deinterlace(source: PackedByteArray, width: int, height: int) -> PackedByteArray:
	var output := PackedByteArray()
	output.resize(source.size())
	var src := 0
	for pass_data in [[0, 8], [4, 8], [2, 4], [1, 2]]:
		var y: int = pass_data[0]
		var step: int = pass_data[1]
		while y < height:
			var dst := y * width
			for x in width:
				if src < source.size():
					output[dst + x] = source[src]
				src += 1
			y += step
	return output


## 单帧延时列表（GIF 单位 1/100 秒），供调用方展示总时长。
static func frame_delays(gif: Dictionary) -> PackedInt32Array:
	var delays := PackedInt32Array()
	for frame in gif["frames"]:
		delays.append(int(frame["delay"]))
	return delays


class _Reader:
	var data: PackedByteArray
	var pos := 0

	func _init(bytes: PackedByteArray) -> void:
		data = bytes

	func remaining() -> int:
		return data.size() - pos

	func u8() -> int:
		if pos >= data.size():
			return -1
		var value := data[pos]
		pos += 1
		return value

	func u16() -> int:
		var low := u8()
		var high := u8()
		if low < 0 or high < 0:
			return -1
		return low | (high << 8)

	func sub_blocks() -> PackedByteArray:
		var out := PackedByteArray()
		while true:
			var size := u8()
			if size <= 0:
				break
			for i in size:
				if pos >= data.size():
					break
				out.append(data[pos])
				pos += 1
		return out

	func color_table(count: int) -> PackedColorArray:
		var colors := PackedColorArray()
		for i in count:
			var r := u8()
			var g := u8()
			var b := u8()
			if r < 0 or g < 0 or b < 0:
				break
			colors.append(Color8(r, g, b, 255))
		return colors
