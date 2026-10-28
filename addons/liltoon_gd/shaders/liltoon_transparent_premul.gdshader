// liltoon_gd - 半透明卡通着色器（预乘 Alpha）
shader_type spatial;
render_mode blend_premul_alpha, diffuse_toon, depth_prepass_alpha, cull_back;

#define LILTOON_TRANSPARENT
#define LILTOON_PREMUL

#include "res://addons/liltoon_gd/shaders/include/uniforms.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/vertex.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/surface.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/lighting.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/fragment.gdshaderinc"
