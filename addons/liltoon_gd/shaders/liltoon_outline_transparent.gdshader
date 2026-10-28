// liltoon_gd - 外扩描边（unlit / 透明，blend_mix）
// 公共实现见 include/outline_common.gdshaderinc。
shader_type spatial;
render_mode blend_mix, cull_front, shadows_disabled, depth_draw_never;

#define LILTOON_OUTLINE_TRANSPARENT

#include "res://addons/liltoon_gd/shaders/include/outline_common.gdshaderinc"
