// liltoon_gd - 外扩描边（作为 next_pass 使用，unlit / 不透明）
// 公共实现见 include/outline_common.gdshaderinc。
shader_type spatial;
render_mode cull_front, shadows_disabled, depth_draw_opaque;

#include "res://addons/liltoon_gd/shaders/include/outline_common.gdshaderinc"
