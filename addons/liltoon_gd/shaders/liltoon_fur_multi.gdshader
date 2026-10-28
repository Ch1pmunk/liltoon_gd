// liltoon_gd - 毛发壳层（MultiMesh 实例版）：用 INSTANCE_CUSTOM.r 表示层高 0–1。
shader_type spatial;
render_mode cull_back, depth_draw_never, diffuse_toon;

#define LILTOON_CUTOUT
#define LILTOON_FUR
#define LILTOON_FUR_INSTANCED

#include "res://addons/liltoon_gd/shaders/include/uniforms.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/vertex.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/surface.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/lighting.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/fragment.gdshaderinc"