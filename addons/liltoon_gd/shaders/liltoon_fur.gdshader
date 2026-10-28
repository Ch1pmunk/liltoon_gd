// liltoon_gd - 毛发壳层（透明），作为 next_pass 链的一层使用。
// 每层由材质上的 fur_layer / fur_layers 决定偏移量与透明度。
shader_type spatial;
render_mode blend_mix, diffuse_toon, cull_back, depth_draw_never;

#define LILTOON_TRANSPARENT
#define LILTOON_FUR

#include "res://addons/liltoon_gd/shaders/include/uniforms.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/vertex.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/surface.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/lighting.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/fragment.gdshaderinc"