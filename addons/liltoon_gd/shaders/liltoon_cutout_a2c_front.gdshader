// liltoon_gd - Cutout 卡通着色器（仅渲染背面），开启 Alpha To Coverage
// alpha_to_coverage 用像素 Alpha 生成 MSAA 覆盖，需视口开启 MSAA（2× 及以上）才有效果。
shader_type spatial;
render_mode alpha_to_coverage, diffuse_toon, cull_front;

#define LILTOON_CUTOUT
#define LILTOON_A2C

#include "res://addons/liltoon_gd/shaders/include/uniforms.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/vertex.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/surface.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/lighting.gdshaderinc"
#include "res://addons/liltoon_gd/shaders/include/fragment.gdshaderinc"
