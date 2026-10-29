// liltoon_gd - 表面采样辅助函数（只使用 uniform 与片元可用的内建变量）

vec2 lil_uv(vec2 source_uv) {
    return source_uv * main_uv_scale;
}

// liltoon 的 lilCalcUV：先绕 (0.5,0.5) 旋转，再叠加按时间取小数的滚动量。
vec2 lil_uv_anim(vec2 base_uv, vec2 scroll, vec2 rotate) {
    float angle = rotate.x + rotate.y * TIME;
    float c = cos(angle);
    float s = sin(angle);
    vec2 centered = base_uv - 0.5;
    vec2 rotated = vec2(centered.x * c - centered.y * s, centered.x * s + centered.y * c) + 0.5;
    return rotated + fract(scroll * TIME);
}

vec2 lil_main_uv(vec2 base_uv) {
    return lil_uv_anim(base_uv, main_uv_scroll, main_uv_rotate);
}

// liltoon 的 lilToneCorrection：Gamma -> RGB 转 HSV -> 色相/饱和度/明度 -> HSV 转 RGB。
vec3 lil_tone_correction(vec3 color, vec4 hsvg) {
    vec3 c = pow(abs(color), vec3(hsvg.w));
    vec4 p = (c.b > c.g) ? vec4(c.bg, -1.0, 2.0 / 3.0) : vec4(c.gb, 0.0, -1.0 / 3.0);
    vec4 q = (p.x > c.r) ? vec4(p.xyw, c.r) : vec4(c.r, p.yzx);
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    vec3 hsv = vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
    hsv = vec3(hsv.x + hsvg.x, clamp(hsv.y * hsvg.y, 0.0, 1.0), clamp(hsv.z * hsvg.z, 0.0, 1.0));
    return hsv.z - hsv.z * hsv.y + hsv.z * hsv.y * clamp(abs(fract(hsv.x + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

vec4 lil_apply_main_hsvg(vec4 tex) {
    if (main_hsvg != vec4(0.0, 1.0, 1.0, 1.0)) {
        tex.rgb = lil_tone_correction(tex.rgb, main_hsvg);
    }
    return tex;
}

vec2 lil_rotate_uv(vec2 uv_in, float degrees) {
    float rad = radians(degrees);
    float c = cos(rad);
    float s = sin(rad);
    return mat2(vec2(c, -s), vec2(s, c)) * uv_in;
}

vec2 lil_parallax_uv(vec2 base, sampler2D hmap, float depth, vec2 view_ratio, float zero_point) {
    float h = texture(hmap, base).r - zero_point;
    return base + view_ratio * h * depth;
}

vec3 lil_linear_to_srgb(vec3 c) {
    return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}

vec3 lil_srgb_to_linear(vec3 c) {
    return mix(c / 12.92, pow(max(c + 0.055, vec3(0.0)) / 1.055, vec3(2.4)), step(0.04045, c));
}

// liltoon 的 lilGradationMap：RGB 三通道分别查 1D LUT，再按强度插值。
vec3 lil_gradation_map(vec3 color, sampler2D lut, float strength) {
    if (strength <= 0.0) {
        return color;
    }
    vec3 srgb = lil_linear_to_srgb(color);
    vec3 mapped = vec3(
        texture(lut, vec2(srgb.r, 0.5)).r,
        texture(lut, vec2(srgb.g, 0.5)).g,
        texture(lut, vec2(srgb.b, 0.5)).b);
    return mix(color, lil_srgb_to_linear(mapped), strength);
}

vec4 lil_sample_main(vec2 uv) {
    vec4 tex = vec4(1.0);
    if (use_main_texture) {
        tex = texture(main_texture, uv);
    }
    vec3 original = tex.rgb;
    tex = lil_apply_main_hsvg(tex);
    if (use_main_gradation) {
        tex.rgb = lil_gradation_map(tex.rgb, main_gradation_texture, main_gradation_strength);
    }
    if (use_main_color_adjust_mask) {
        // 对应 liltoon 的 _MainColorAdjustMask：遮罩控制整套颜色调整的生效比例。
        float adjust_mask = texture(main_color_adjust_mask, uv).r;
        tex.rgb = mix(original, tex.rgb, adjust_mask);
    }
    return main_color * tex;
}

// 明暗边界的屏幕空间抗锯齿：对应 liltoon 的 fwidth(value) * _AAStrength。
// 我们的 blur 是过渡带半宽，因此每侧各扩宽一半，保持 aa_strength=0 时与原行为一致。
float lil_aa_edge(float value) {
    return clamp(fwidth(value) * aa_strength * 0.5, 0.0, 0.25);
}

// ndl -> 0..1 的色阶强度，可选 ramp 贴图重映射
float lil_shade_step(float ndl, vec2 uv) {
    if (!use_shadow) {
        return 1.0;
    }
    ndl += shading_shift;
    float blur = shade_blur;
    if (use_shadow_blur_mask) {
        blur *= textureLod(shadow_blur_mask, uv, shadow_blur_mask_lod).r;
    }
    float edge = lil_aa_edge(ndl) + blur;
    float lit = smoothstep(shade_threshold - edge, shade_threshold + edge, ndl);
    if (use_shade_ramp) {
        // ramp 的水平轴对应 N·L（-1..1 映射到 0..1），不能用已经阶跃过的 lit 采样，
        // 否则贴图只剩两端取值，中间渐变完全丢失。
        float ramp = texture(shade_ramp, vec2(clamp(ndl * 0.5 + 0.5, 0.0, 1.0), 0.5)).r;
        lit = mix(lit, ramp, shade_ramp_strength);
    }
    return clamp(lit, 0.0, 1.0);
}

// 带 border range 的阴影边界：只向暗部扩宽，用于边界染色，对应 _ShadowBorderRange。
float lil_shade_step_range(float ndl, vec2 uv) {
    if (!use_shadow) {
        return 1.0;
    }
    ndl += shading_shift;
    float blur = shade_blur;
    if (use_shadow_blur_mask) {
        blur *= textureLod(shadow_blur_mask, uv, shadow_blur_mask_lod).r;
    }
    float edge = lil_aa_edge(ndl) + blur;
    return clamp(smoothstep(shade_threshold - edge - shade_border_range, shade_threshold + edge, ndl), 0.0, 1.0);
}

// 第二层阴影：低于该阈值的区域混入 shade_2nd_color
float lil_shade_2nd_step(float ndl, vec2 uv) {
    if (!use_shadow) {
        return 1.0;
    }
    ndl += shading_shift;
    float blur = shade_2nd_blur;
    if (use_shadow_blur_mask) {
        blur *= textureLod(shadow_blur_mask, uv, shadow_blur_mask_lod).g;
    }
    float edge = lil_aa_edge(ndl) + blur;
    return clamp(smoothstep(shade_2nd_threshold - edge, shade_2nd_threshold + edge, ndl), 0.0, 1.0);
}

// 第三层阴影：更低阈值处混入 shade_3rd_color
float lil_shade_3rd_step(float ndl, vec2 uv) {
    if (!use_shadow) {
        return 1.0;
    }
    ndl += shading_shift;
    float blur = shade_3rd_blur;
    if (use_shadow_blur_mask) {
        blur *= textureLod(shadow_blur_mask, uv, shadow_blur_mask_lod).b;
    }
    float edge = lil_aa_edge(ndl) + blur;
    return clamp(smoothstep(shade_3rd_threshold - edge, shade_3rd_threshold + edge, ndl), 0.0, 1.0);
}

// 把视空间法线旋到"无相机滚转"的基上（三个 MatCap 槽共用）。
vec3 lil_matcap_zrot_normal(vec3 view_normal) {
    vec2 up_xy = lil_matcap_up;
    vec2 right_xy = vec2(up_xy.y, -up_xy.x);
    return vec3(dot(view_normal.xy, right_xy), dot(view_normal.xy, up_xy), view_normal.z);
}

vec3 lil_sample_matcap(vec3 view_normal, float perspective, vec2 uv1) {
    // matcap_zrot_cancel 对应 _MatCapZRotCancel：抵消相机滚转，保持 MatCap 竖直。
    vec3 matcap_n = matcap_zrot_cancel ? lil_matcap_zrot_normal(view_normal) : view_normal;
    vec2 matcap_uv = matcap_n.xy * 0.5 * perspective + 0.5;
    // 对应 liltoon 的 _MatCapBlendUV1：在球面 UV 与 UV1 之间插值。
    matcap_uv = mix(matcap_uv, uv1, matcap_blend_uv1);
    return textureLod(matcap_texture, matcap_uv, matcap_lod).rgb * matcap_color.rgb;
}

vec3 lil_sample_matcap_2nd(vec3 view_normal, float perspective, vec2 uv1) {
    vec3 matcap_n = matcap_2nd_zrot_cancel ? lil_matcap_zrot_normal(view_normal) : view_normal;
    vec2 matcap_uv = matcap_n.xy * 0.5 * perspective + 0.5;
    matcap_uv = mix(matcap_uv, uv1, matcap_2nd_blend_uv1);
    return textureLod(matcap_texture_2nd, matcap_uv, matcap_2nd_lod).rgb * matcap_2nd_color.rgb;
}

vec3 lil_sample_matcap_3rd(vec3 view_normal, float perspective) {
    vec3 matcap_n = matcap_3rd_zrot_cancel ? lil_matcap_zrot_normal(view_normal) : view_normal;
    vec2 matcap_uv = matcap_n.xy * 0.5 * perspective + 0.5;
    return textureLod(matcap_texture_3rd, matcap_uv, matcap_3rd_lod).rgb * matcap_3rd_color.rgb;
}

float lil_matcap_mask_value(vec2 uv) {
    if (!use_matcap_mask) {
        return 1.0;
    }
    float mask = texture(matcap_mask, uv * matcap_mask_uv_scale).r;
    return smoothstep(matcap_mask_threshold - 0.05, matcap_mask_threshold + 0.05, mask);
}

// 光照阶段版本的 MatCap 采样，供 matcap_enable_lighting / matcap_shadow_mask 使用。
// light() 里没有 TANGENT / BINORMAL 内建量，切线改用 varying lil_tangent_view，
// 因此这段与 fragment() 里的版本分开写：默认路径（两个参数都为 0）仍走 fragment，行为不变。
vec3 lil_shaded_normal_light(vec3 base_normal, vec2 uv, vec2 base_uv) {
    if (!use_normal_map && !use_normal_map_2nd) {
        return base_normal;
    }
    vec2 normal_xy = vec2(0.0);
    if (use_normal_map) {
        normal_xy += (texture(normal_texture, base_uv).xy * 2.0 - 1.0) * normal_strength;
    }
    if (use_normal_map_2nd) {
        vec2 normal2_uv = decal_2nd_normal_uv_mode == 1 ? lil_uv2 : uv;
        float normal2_scale = normal_strength_2nd;
        if (use_decal_2nd_normal_scale_mask) {
            normal2_scale *= texture(decal_2nd_normal_scale_mask, base_uv).r;
        }
        normal_xy += (texture(normal_texture_2nd, normal2_uv).xy * 2.0 - 1.0) * normal2_scale;
    }
    vec3 normal_ts = normalize(vec3(normal_xy, 1.0));
    vec3 tangent_view = normalize(lil_tangent_view);
    vec3 bitangent_view = cross(base_normal, tangent_view);
    return normalize(tangent_view * normal_ts.x + bitangent_view * normal_ts.y + base_normal * normal_ts.z);
}

// 对应 liltoon 的 lilGetAnisotropyNormalWS：
// 按 anisotropy 正负取副切线或切线，正交化到视线方向，再与法线按 |anisotropy| 插值。
vec3 lil_anisotropy_normal(vec3 base_normal, vec2 uv, vec3 view_dir, float anisotropy_value) {
    vec3 up = abs(base_normal.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 tangent = normalize(cross(up, base_normal));
    vec3 bitangent = cross(base_normal, tangent);
    if (use_anisotropy_tangent_map) {
        vec3 aniso_map = texture(anisotropy_tangent_map, uv).xyz * 2.0 - 1.0;
        vec3 tangent_view = normalize(lil_tangent_view);
        vec3 bitangent_view = cross(base_normal, tangent_view);
        tangent = normalize(tangent_view * aniso_map.x + bitangent_view * aniso_map.y + base_normal * aniso_map.z);
        tangent = normalize(tangent - base_normal * dot(tangent, base_normal));
        bitangent = cross(base_normal, tangent);
    }
    vec3 aniso_dir = anisotropy_value > 0.0 ? bitangent : tangent;
    aniso_dir = normalize(aniso_dir - view_dir * dot(aniso_dir, view_dir));
    return normalize(mix(base_normal, aniso_dir, clamp(abs(anisotropy_value), 0.0, 1.0)));
}

vec3 lil_matcap_color_light(vec3 base_normal, float perspective, vec2 uv, vec2 base_uv) {
    vec3 matcap_normal = mix(base_normal, lil_shaded_normal_light(base_normal, uv, base_uv), matcap_normal_strength);
    if (use_matcap_bump_map) {
        vec3 bump = texture(matcap_bump_map, uv).xyz * 2.0 - 1.0;
        if (matcap_custom_normal) {
            vec3 tangent_view = normalize(lil_tangent_view);
            vec3 bitangent_view = cross(base_normal, tangent_view);
            matcap_normal = normalize(
                tangent_view * bump.x * matcap_bump_scale
                + bitangent_view * bump.y * matcap_bump_scale
                + base_normal * bump.z);
        } else {
            matcap_normal = normalize(matcap_normal + vec3(bump.xy * matcap_bump_scale, 0.0));
        }
    }
    if (anisotropy_2_matcap && use_anisotropy) {
        matcap_normal = lil_anisotropy_normal(matcap_normal, uv, lil_view, anisotropy_scale);
    }
    return lil_sample_matcap(matcap_normal, perspective, uv);
}

vec3 lil_matcap_color_light_2nd(vec3 base_normal, float perspective, vec2 uv, vec2 base_uv) {
    vec3 matcap_normal = mix(base_normal, lil_shaded_normal_light(base_normal, uv, base_uv), matcap_2nd_normal_strength);
    if (use_matcap_2nd_bump) {
        vec3 bump = texture(matcap_2nd_bump_map, uv).rgb * 2.0 - 1.0;
        if (matcap_2nd_custom_normal) {
            vec3 tangent_view = normalize(lil_tangent_view);
            vec3 bitangent_view = cross(base_normal, tangent_view);
            matcap_normal = normalize(
                tangent_view * bump.x * matcap_2nd_bump_scale
                + bitangent_view * bump.y * matcap_2nd_bump_scale
                + base_normal * bump.z);
        } else {
            vec3 up = abs(matcap_normal.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
            vec3 tangent_view = normalize(cross(up, matcap_normal));
            vec3 bitangent_view = cross(matcap_normal, tangent_view);
            matcap_normal = normalize(matcap_normal + (tangent_view * bump.x + bitangent_view * bump.y) * matcap_2nd_bump_scale);
        }
    }
    if (anisotropy_2_matcap_2nd && use_anisotropy) {
        matcap_normal = lil_anisotropy_normal(matcap_normal, uv, lil_view, anisotropy_scale);
    }
    return lil_sample_matcap_2nd(matcap_normal, perspective, uv);
}

// 光照阶段版本的闪点计算，供 glitter_enable_lighting / glitter_shadow_mask 使用。
// 与 fragment() 里那段逻辑保持一致；参数化传入法线与 UV，避免引用阶段内建量。
vec3 lil_glitter_color_light(vec3 base_normal, vec2 uv, vec2 uv2, float facing, float alpha) {
    if (!use_glitter) {
        return vec3(0.0);
    }
    vec2 glitter_base_uv = glitter_uv_mode == 1 ? uv2 : uv;
    vec2 glitter_uv = glitter_base_uv * glitter_scale + base_normal.xy * 8.0 * glitter_normal_strength;
    if (glitter_scale_randomize > 0.001) {
        float g_rand = fract(sin(dot(base_normal.xy, vec2(41.0, 289.0))) * 43758.5453);
        glitter_uv += vec2(g_rand, fract(g_rand * 7.0)) * glitter_scale_randomize;
    }
    if (use_glitter_shape) {
        glitter_uv = glitter_base_uv * glitter_scale;
    }
    if (glitter_angle_randomize > 0.001) {
        float angle = fract(sin(dot(glitter_base_uv, vec2(127.1, 311.7))) * 43758.5453)
            * 6.2831853 * glitter_angle_randomize;
        float ca = cos(angle);
        float sa = sin(angle);
        glitter_uv = mat2(vec2(ca, -sa), vec2(sa, ca)) * glitter_uv;
    }
    float glitter_seed = fract(sin(dot(glitter_uv, vec2(12.9898, 78.233))) * 43758.5453);
    if (use_glitter_shape) {
        // glitter_shape_atlas 对应 _GlitterAtras：XY 为图集行列，ZW 为偏移；
        // 每个闪点随机取图集一格（对应原版 floor(near.xy * atras.xy)）。
        vec2 atlas_grid = max(glitter_shape_atlas.xy, vec2(1.0));
        vec2 atlas_cell = floor(vec2(fract(glitter_seed * 13.7), fract(glitter_seed * 29.1)) * atlas_grid);
        vec2 shape_uv = (glitter_base_uv * glitter_scale + atlas_cell + glitter_shape_atlas.zw) / atlas_grid;
        glitter_seed *= texture(glitter_shape_texture, shape_uv).r;
    }
    float glitter_mask = smoothstep(1.0 - glitter_sensitivity, 1.0, glitter_seed);
    glitter_mask = pow(glitter_mask, glitter_post_contrast);
    if (glitter_backface_mask && facing < 0.0) {
        glitter_mask = 0.0;
    }
    vec3 glitter_tint = glitter_color.rgb;
    if (use_glitter_color_tex) {
        vec2 glitter_color_uv = glitter_color_uv_mode == 1 ? uv2 : uv;
        glitter_tint *= texture(glitter_color_texture, glitter_color_uv).rgb;
    }
    float glitter_alpha = glitter_apply_transparency ? clamp(alpha, 0.0, 1.0) : 1.0;
    return glitter_tint * glitter_mask * glitter_intensity * glitter_alpha;
}

vec3 lil_triplanar_weights(vec3 world_normal) {
    vec3 weights = pow(abs(world_normal), vec3(4.0));
    return weights / max(weights.x + weights.y + weights.z, 0.0001);
}

vec4 lil_sample_main_triplanar(vec3 world_position, vec3 world_normal) {
    vec3 p = world_position * triplanar_scale;
    vec3 weights = lil_triplanar_weights(world_normal);
    vec4 sample_x = texture(main_texture, p.zy);
    vec4 sample_y = texture(main_texture, p.xz);
    vec4 sample_z = texture(main_texture, p.xy);
    vec4 triplanar = sample_x * weights.x + sample_y * weights.y + sample_z * weights.z;
    triplanar = lil_apply_main_hsvg(triplanar);
    if (use_main_gradation) {
        triplanar.rgb = lil_gradation_map(triplanar.rgb, main_gradation_texture, main_gradation_strength);
    }
    return main_color * triplanar;
}

// liltoon 的 lilTooningScale：边界 + 过渡带 + fwidth 抗锯齿。
float lil_tooning_scale(float value, float border, float blur) {
    float border_min = clamp(border - blur * 0.5, 0.0, 1.0);
    float border_max = clamp(border + blur * 0.5, 0.0, 1.0);
    return clamp((value - border_min) / max(border_max - border_min + fwidth(value) * aa_strength, 0.0001), 0.0, 1.0);
}

float lil_rim_fresnel(vec3 view_normal, vec3 view_dir) {
    float nvabs = abs(dot(view_normal, view_dir));
    return pow(clamp(1.0 - nvabs, 0.0, 1.0), rim_power);
}

float lil_rim_factor(vec3 view_normal, vec3 view_dir) {
    return lil_tooning_scale(lil_rim_fresnel(view_normal, view_dir), rim_border, rim_blur);
}

// al_grad：AudioLink 叠加到渐变相位的量（对应 _AudioLink2EmissionGrad），未启用时传 0。
vec3 lil_emission(vec2 base_uv, vec2 view_ratio, vec3 albedo, float al_grad) {
    if (!use_emission) {
        return vec3(0.0);
    }
    vec2 uv = emission_uv_mode == 1 ? lil_uv2 : base_uv;
    uv = lil_uv_anim(uv, emission_uv_scroll, emission_uv_rotate);
    if (use_emission_parallax) {
        uv = lil_parallax_uv(uv, emission_parallax_texture, emission_parallax_depth, view_ratio, 0.5);
    }
    vec3 color = emission_color.rgb * emission_intensity;
    float alpha = emission_color.a;
    if (use_emission_texture) {
        vec4 tex = texture(emission_texture, uv);
        color *= tex.rgb;
        alpha *= tex.a;
    }
    if (use_emission_mask) {
        vec2 mask_uv = lil_uv_anim(base_uv, emission_mask_uv_scroll, emission_mask_uv_rotate);
        vec4 mask = texture(emission_mask, mask_uv);
        color *= mask.rgb;
        alpha *= mask.a;
    }
    if (use_emission_grad) {
        // 渐变相位叠加 AudioLink（原版：_EmissionGradSpeed * TIME + audioLinkValue * _AudioLink2EmissionGrad）
        color *= texture(emission_grad_texture, vec2(fract(TIME * emission_grad_speed + al_grad), 0.5)).rgb;
    }
    color = mix(color, color * albedo, emission_main_strength);
    if (emission_blend_mode == 1) {
        // 正片叠底：Godot 的 EMISSION 只能做加法，这里用乘反照率近似原版的正片叠底混合。
        color *= albedo;
    }
    return color * emission_blend * alpha;
}
// 第二层自发光的最终颜色（遮罩、UV 模式、滚动、视差、渐变全部应用），片元与光照阶段共用。
// al_grad：同 lil_emission，对应 _AudioLink2Emission2ndGrad。
vec3 lil_emission_2nd(vec2 uv, float al_grad) {
    vec2 mask_uv = lil_uv_anim(uv, emission_2nd_mask_uv_scroll, emission_2nd_mask_uv_rotate);
    float mask_value = use_emission_2nd_mask ? texture(emission_2nd_mask, mask_uv).r : 1.0;
    vec2 emission_uv = (emission_2nd_uv_mode == 1 ? lil_uv2 : uv) * emission_2nd_uv_scale + TIME * emission_2nd_uv_scroll;
    if (use_emission_2nd_parallax) {
        // 用 varying 传递的视方向：light() 阶段取不到 VIEW 内建变量。
        emission_uv = lil_parallax_uv(emission_uv, emission_2nd_parallax_texture, emission_2nd_parallax_depth, lil_view.xy / max(abs(lil_view.z), 0.001), 0.5);
    }
    vec3 color = texture(emission_2nd_texture, emission_uv).rgb * emission_2nd_color.rgb * emission_2nd_intensity * mask_value;
    if (use_emission_2nd_grad) {
        float grad_t = fract(TIME * emission_2nd_grad_speed + al_grad);
        color *= texture(emission_2nd_grad_texture, vec2(grad_t, 0.5)).rgb;
    }
    return color;
}

// liltoon 的 fd.invLighting：受光越弱衰减越小，全黑与全亮都为 0，用于荧光自发光。
vec3 lil_inv_lighting(vec3 light_rgb, float shadow_factor) {
    vec3 light_factor = clamp(light_rgb * shadow_factor, vec3(0.0), vec3(1.0));
    return clamp((vec3(1.0) - light_factor) * sqrt(light_factor), vec3(0.0), vec3(1.0));
}

float lil_dissolve_visibility(vec2 uv_in, vec3 pos_os) {
    if (!use_dissolve) {
        return 1.0;
    }
    vec2 noise_uv = uv_in * dissolve_noise_uv_scale;
    float rot = radians(dissolve_noise_rotate);
    float c = cos(rot);
    float s = sin(rot);
    noise_uv = mat2(vec2(c, -s), vec2(s, c)) * noise_uv;
    float noise = (texture(dissolve_noise_texture, noise_uv + TIME * dissolve_noise_scroll).r - 0.5) * dissolve_noise_strength;
    float value;
    if (dissolve_mode == 0) {
        float mask_value = 1.0;
        if (use_dissolve_mask) {
            mask_value = texture(dissolve_mask, uv_in * dissolve_mask_uv_scale).r;
        }
        value = mask_value + noise;
    } else if (dissolve_mode == 1) {
        vec2 dir = normalize(dissolve_position.xy + vec2(0.0001, 0.0));
        value = dissolve_shape == 1 ? dot(uv_in, dir) + noise : distance(uv_in, dissolve_position.xy) + noise;
    } else {
        vec3 dir3 = normalize(dissolve_position + vec3(0.0001, 0.0, 0.0));
        value = dissolve_shape == 1 ? dot(pos_os, dir3) + noise : distance(pos_os, dissolve_position) + noise;
    }
    return smoothstep(dissolve_border, dissolve_border + max(dissolve_blur, 0.001), value);
}
