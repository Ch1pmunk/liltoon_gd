// liltoon_gd - 不透明卡通着色器
shader_type spatial;
render_mode diffuse_toon, depth_draw_opaque, depth_prepass_alpha, cull_back;

#include "res://addons/liltoon_gd/shaders/include/uniforms.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/vertex.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/surface.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/lighting.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/fragment.gdshaderinc"
