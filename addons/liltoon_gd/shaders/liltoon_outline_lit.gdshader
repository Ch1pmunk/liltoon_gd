// liltoon_gd - 外扩描边（受光 / 不透明）
// 公共实现见 include/outline_common.gdshaderinc。
shader_type spatial;
render_mode cull_front, shadows_disabled, depth_draw_opaque;

#include "res://addons/liltoon_gd/shaders/include/outline_common.gdshaderinc"

void light() {
    // 对齐 lilToon 的 LIL_APPLY_OUTLINE_COLOR（受光版）：
    // 亮部系数 = saturate(2D 投影 N·L × scale + offset) × lit_color.a，可再乘阴影。
    vec3 n2 = normalize(vec3(NORMAL.xy, 0.0001));
    vec3 l2 = normalize(vec3(LIGHT.xy, 0.0001));
    float ndl2 = dot(n2, l2) * 0.5 + 0.5;
    float factor = clamp(ndl2 * outline_lit_scale + outline_lit_offset, 0.0, 1.0) * outline_lit_color.a;
    if (outline_lit_shadow_receive) {
        factor *= ATTENUATION;
    }
    vec3 lit_rgb = outline_lit_apply_tex ? ALBEDO * outline_lit_color.rgb : outline_lit_color.rgb;
    // lerp(暗部, 亮部, factor)：暗部走 DIFFUSE_LIGHT（引擎会乘 ALBEDO），
    // 亮部走 SPECULAR_LIGHT（不乘 ALBEDO），避免除法与二次染色。
    DIFFUSE_LIGHT += outline_shade_color.rgb * (1.0 - factor) * LIGHT_COLOR;
    SPECULAR_LIGHT += lit_rgb * factor * LIGHT_COLOR;
}
