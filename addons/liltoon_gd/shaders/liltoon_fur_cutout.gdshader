// liltoon_gd - 毛发壳层（裁切），作为 next_pass 链的一层使用。
shader_type spatial;
render_mode cull_back, depth_draw_never, diffuse_toon;

#define LILTOON_CUTOUT
#define LILTOON_FUR

#include "res://addons/liltoon_gd/shaders/include/uniforms.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/vertex.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/surface.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/lighting.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/fragment.gdshaderinc"