// liltoon_gd - 外扩描边（unlit / 透明 / 预乘，blend_premul_alpha）
// 公共实现见 include/outline_common.gdshaderinc。
shader_type spatial;
render_mode blend_premul_alpha, cull_front, shadows_disabled, depth_draw_never;

#define LILTOON_OUTLINE_TRANSPARENT
#define LILTOON_OUTLINE_PREMUL

#include "res://addons/liltoon_gd/shaders/include/outline_common.gdshaderinc"
