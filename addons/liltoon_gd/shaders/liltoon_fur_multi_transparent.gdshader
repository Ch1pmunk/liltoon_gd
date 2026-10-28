// liltoon_gd - 毛发壳层（MultiMesh 透明版）：用 INSTANCE_CUSTOM.r 表示层高 0–1。
// 与裁切版的区别：平滑 alpha 混合，适合软毛/绒毛。
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, diffuse_toon;

#define LILTOON_TRANSPARENT
#define LILTOON_FUR
#define LILTOON_FUR_INSTANCED

#include "res://addons/liltoon_gd/shaders/include/uniforms.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/vertex.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/surface.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/lighting.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/fragment.gdshaderinc"