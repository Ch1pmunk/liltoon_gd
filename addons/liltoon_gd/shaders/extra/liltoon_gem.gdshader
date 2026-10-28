// liltoon_gd - 宝石变体（对齐 lilToon lts_gem.shader 的宝石部分）
// 用法：把该 shader 用在半透明材质上，开启色散折射与粒子闪烁效果。
// 单独成变体的原因：需要 hint_screen_texture（每帧屏幕拷贝），只有宝石材质才承担该开销。
shader_type spatial;
render_mode blend_mix, diffuse_toon, depth_prepass_alpha, cull_back;

#define LILTOON_TRANSPARENT
#define LILTOON_GEM

#include "res://addons/liltoon_gd/shaders/include/uniforms.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/vertex.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/surface.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/lighting.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/fragment.gdshaderinc"
