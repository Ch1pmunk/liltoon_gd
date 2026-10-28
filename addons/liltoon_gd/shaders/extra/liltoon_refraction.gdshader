// liltoon_gd - 折射变体（对齐 lilToon lts_ref.shader 的折射部分）
// 用法：把该 shader 用在半透明材质上并打开 `use_refraction`。
// 单独成变体的原因：`hint_screen_texture` 会让引擎每帧做一次屏幕拷贝，
// 只有真正需要折射的材质才应承担这个开销。
shader_type spatial;
render_mode blend_mix, diffuse_toon, depth_prepass_alpha, cull_back;

#define LILTOON_TRANSPARENT
#define LILTOON_REFRACTION

#include "res://addons/liltoon_gd/shaders/include/uniforms.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/vertex.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/surface.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/lighting.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/fragment.gdshaderinc"
