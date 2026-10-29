// liltoon_gd - 自定义 toon 光照
// ATTENUATION 已包含距离衰减与阴影，因此阴影区不会被该光源照亮。

float ss_scatter(float ndl) {
    float back_facing = clamp(-ndl, 0.0, 1.0);
    return pow(back_facing + 0.02, sss_power) * sss_strength;
}

void light() {
    // 边界遮罩（AO）：RGB 分别压 1st/2nd/3rd 阴影边界，对应 _ShadowBorderMask + _ShadowAOShift。
    // shadow_post_ao 对应 _ShadowPostAO：关闭时遮罩在 toon 阶跃前作用（原版默认），开启后在阶跃后作用。
    float border_r = 1.0;
    float border_g = 1.0;
    float border_b = 1.0;
    if (use_shadow_border_mask) {
        vec4 border_mask = textureLod(shadow_border_mask, UV, shadow_border_mask_lod);
        border_r = clamp(border_mask.r * shadow_ao_shift.x + shadow_ao_shift.y, 0.0, 1.0);
        border_g = clamp(border_mask.g * shadow_ao_shift.z + shadow_ao_shift.w, 0.0, 1.0);
        border_b = clamp(border_mask.b * shadow_ao_shift_2.x + shadow_ao_shift_2.y, 0.0, 1.0);
    }

    float ndl = mix(1.0, dot(NORMAL, LIGHT), shade_normal_strength);
    float ndl2 = mix(1.0, dot(NORMAL, LIGHT), shade_2nd_normal_strength);
    float ndl3 = mix(1.0, dot(NORMAL, LIGHT), shade_3rd_normal_strength);
    if (use_shadow_border_mask && !shadow_post_ao) {
        // 阶跃前作用：遮罩先乘 N·L 再过 toon 阶跃（对应原版 lns.xyz *= mask 后 lilTooningScale）。
        ndl *= border_r;
        ndl2 *= border_g;
        ndl3 *= border_b;
    }
    float lit = lil_shade_step(ndl, UV);
    float lit2 = use_shade_2nd ? lil_shade_2nd_step(ndl2, UV) : 1.0;
    float lit3 = use_shade_3rd ? lil_shade_3rd_step(ndl3, UV) : 1.0;
    float lit_range = lil_shade_step_range(ndl, UV);

    // 阴影强度：对应 liltoon 的 `shadowStrength *= shadowStrengthMask.r; lns.x = lerp(1.0, lns.x, shadowStrength)`，
    // 作用于 toon 阴影的深浅。默认 shadow_strength = 1 时 mix 恒等，不改变现有行为。
    float toon_strength = clamp(shadow_strength, 0.0, 1.0);
    if (use_shadow_strength_mask) {
        toon_strength = clamp(toon_strength * textureLod(shadow_strength_mask, UV, shadow_strength_mask_lod).r, 0.0, 1.0);
    }
    if (toon_strength < 0.999) {
        lit = mix(1.0, lit, toon_strength);
        lit2 = mix(1.0, lit2, toon_strength);
        lit3 = mix(1.0, lit3, toon_strength);
        lit_range = mix(1.0, lit_range, toon_strength);
    }

    // 阶跃后作用（_ShadowPostAO = 1）：遮罩直接乘到 toon 结果上。
    if (use_shadow_border_mask && shadow_post_ao) {
        lit *= border_r;
        lit2 *= border_g;
        lit3 *= border_b;
        lit_range *= border_r;
    }

    // 平面阴影：用更平的法线生成边界，再按强度遮罩与 toon 阴影混合，对应 _ShadowMaskType。
    if (shadow_mask_type == 1) {
        vec3 flat_normal = normalize(lil_geo_normal + vec3(0.0, 0.25, 1.0));
        float flat_lit = clamp((dot(flat_normal, LIGHT) + shadow_flat_border) / max(shadow_flat_blur, 0.001), 0.0, 1.0);
        float flat_mask = use_shadow_strength_mask ? textureLod(shadow_strength_mask, UV, shadow_strength_mask_lod).r : 1.0;
        lit = mix(flat_lit, lit, flat_mask);
        lit2 = mix(flat_lit, lit2, flat_mask);
        lit3 = mix(flat_lit, lit3, flat_mask);
        lit_range = mix(flat_lit, lit_range, flat_mask);
    }

    // 背面强制阴影：反面按比例压回阴影区，对应 liltoon 的 _BackfaceForceShadow。
    if (backface_force_shadow > 0.0 && lil_facing < 0.0) {
        float bfshadow = 1.0 - clamp(backface_force_shadow, 0.0, 1.0);
        lit *= bfshadow;
        lit2 *= bfshadow;
        lit3 *= bfshadow;
    }

    // DIFFUSE_LIGHT 是光照染色项，引擎会在最终合成时统一乘以 ALBEDO，
    // 因此这里只能写入 shade 染色与 1.0，不能再次乘 ALBEDO，否则亮部会变成 ALBEDO²。
    vec3 shade = shade_color.rgb;
    if (use_shade_color_texture) {
        if (shade_color_type == 1) {
            // LUT 模式（_ShadowColorType = 1）：按反照率亮度从横向色带采样阴影色。
            float shade_lum = dot(ALBEDO, vec3(0.299, 0.587, 0.114));
            shade *= texture(shade_color_texture, vec2(clamp(shade_lum, 0.0, 1.0), 0.5)).rgb;
        } else {
            // 原版用贴图 Alpha 与反照率混合；这里乘进阴影色，等价于贴图 Alpha=1 的情形。
            shade *= texture(shade_color_texture, UV).rgb;
        }
    }
    vec3 shade2_rgb = shade_2nd_color.rgb;
    if (use_shade_2nd_color_tex) {
        shade2_rgb *= texture(shade_2nd_color_tex, UV).rgb;
    }
    vec3 shade3_rgb = shade_3rd_color.rgb;
    if (use_shade_3rd_color_tex) {
        shade3_rgb *= texture(shade_3rd_color_tex, UV).rgb;
    }
    if (use_shade_2nd) {
        shade = mix(shade2_rgb, shade, lit2);
    }
    if (use_shade_3rd) {
        shade = mix(shade3_rgb, shade, lit3);
    }
    vec3 toon_tint = mix(shade, vec3(1.0), lit);
    // 阴影再与反照率相乘：DIFFUSE_LIGHT 之后还会被引擎乘一次 ALBEDO，这里按比例补上。
    toon_tint *= mix(vec3(1.0), ALBEDO, shadow_main_strength);
    // 边界染色：过渡带内把阴影色拉向受光色，对应 _ShadowBorderColor。
    toon_tint = mix(toon_tint, vec3(1.0), lit_range * shade_border_color.rgb);
    float shadow_strength_value = shadow_strength;
    if (use_shadow_strength_mask) {
        shadow_strength_value *= textureLod(shadow_strength_mask, UV, shadow_strength_mask_lod).r;
    }
    float shadow = mix(1.0, ATTENUATION, clamp(shadow_strength_value, 0.0, 1.0));
    // shadow_receive 是程度值（0=不接收引擎阴影，1=完全接收），对应原版 _ShadowReceive 的 Range(0,1)。
    // 原版默认 0，所以默认不接收引擎阴影。
    shadow = mix(1.0, shadow, clamp(shadow_receive, 0.0, 1.0));
    // liltoon 直接使用光源颜色，不除以 PI；并对每个光源做上下限钳制（_LightMinLimit / _LightMaxLimit）。
    vec3 light_source = monochrome_lighting ? vec3(dot(LIGHT_COLOR, vec3(0.299, 0.587, 0.114))) : LIGHT_COLOR;
    vec3 light_rgb = clamp(light_source, vec3(light_min_limit), vec3(light_max_limit));
    DIFFUSE_LIGHT += toon_tint * light_rgb * shadow;
    if (!use_shade_2nd_receive && use_shade_2nd) {
        DIFFUSE_LIGHT += shade2_rgb * light_rgb * (1.0 - shadow) * (1.0 - lit2);
    }
    if (!use_shade_3rd_receive && use_shade_3rd) {
        DIFFUSE_LIGHT += shade3_rgb * light_rgb * (1.0 - shadow) * (1.0 - lit3);
    }

    // 预乘透明：liltoon 在输出前执行 col.rgb *= col.a，覆盖包括高光在内的整条颜色。
    // Godot 引擎只会对 diffuse/ambient 乘 ALBEDO，直射高光由 shader 自行预乘。
#ifdef LILTOON_PREMUL
    float specular_alpha = clamp(ALPHA, 0.0, 1.0);
#else
    float specular_alpha = 1.0;
#endif

    if (use_sss) {
        float transmission = ss_scatter(ndl) * mix(1.0, texture(sss_thickness_texture, UV).r, sss_thickness_strength);
        DIFFUSE_LIGHT += sss_color.rgb * light_rgb * transmission * shadow * 0.2;
    }

    if (use_rim && !use_unlit) {
        // 按 liltoon 的 lilGetRim：Fresnel 幂 → 受光/背光方向 → 色阶 → 阴影遮罩 → 颜色混合。
        vec3 rim_normal = normalize(mix(lil_geo_normal, NORMAL, rim_normal_strength));
        float rim_fresnel = lil_rim_fresnel(rim_normal, VIEW);
        if (rim_backface_mask && lil_facing < 0.0) {
            rim_fresnel = 0.0;
        }
        float rim_ndl = dot(rim_normal, LIGHT);
        float ln_raw = rim_ndl * 0.5 + 0.5;
        float ln_dir = clamp((ln_raw + rim_dir_range) / (1.0 + rim_dir_range), 0.0, 1.0);
        float ln_indir = clamp((1.0 - ln_raw + rim_indir_range) / (1.0 + rim_indir_range), 0.0, 1.0);
        float rim_dir = mix(rim_fresnel, rim_fresnel * ln_dir, rim_dir_strength);
        float rim_indir = rim_fresnel * ln_indir * rim_dir_strength;
        rim_dir = lil_tooning_scale(rim_dir, rim_border, rim_blur);
        rim_indir = lil_tooning_scale(rim_indir, rim_indir_border, rim_indir_blur);

        float rim_mask_value = 1.0;
        if (use_rim_mask) {
            float mask_sample = texture(rim_mask, UV * rim_mask_uv_scale).r;
            rim_mask_value = smoothstep(rim_mask_threshold - 0.05, rim_mask_threshold + 0.05, mask_sample);
        }

        // rim_shadow_mask 是程度值（0=不受阴影，1=完全按阴影淡化），对应 _RimShadowMask 的 Range(0,1)。
        float rim_shadowmix = clamp(mix(1.0, shadow, rim_shadow_mask), 0.0, 1.0);
        rim_dir *= rim_shadowmix;
        rim_indir *= rim_shadowmix;

        vec3 rim_rgb = rim_color.rgb;
        if (use_rim_color_tex) {
            rim_rgb *= texture(rim_color_tex, UV).rgb;
        }
        if (use_rim_2nd) {
            rim_rgb = mix(rim_rgb, rim_2nd_color.rgb, rim_fresnel);
        }
        // _RimMainStrength 是颜色向 albedo 的插值，不是强度乘数。
        rim_rgb = mix(rim_rgb, rim_rgb * ALBEDO, rim_main_strength);
        // rim_enable_lighting 是程度值（0=恒定亮度，1=完全跟随光色），对应 _RimEnableLighting 的 Range(0,1)。
        vec3 rim_light = mix(vec3(1.0), light_rgb, rim_enable_lighting);
        float rim_alpha = rim_apply_transparency ? clamp(ALPHA, 0.0, 1.0) : 1.0;
        float rim_gain = rim_intensity * rim_mask_value * rim_alpha * specular_alpha;
        // 对齐 lilBlendColor：dst 是"写 rim 之前的表面色"（原版 fd.col.rgb）。
        // 注意：light() 里读不到 EMISSION（实测 "Unknown identifier: EMISSION"），
        // 所以这里只能取 ALBEDO 作 dst —— 混合模式=1（相加）时 out-dst = src*srcA，
        // 与 dst 取值无关，**逐位等价于旧实现**；0/2/3 则是"以基色为 dst"的近似，
        // 差异只出现在同时启用了自发光/MatCap 的材质上（已在 §9 登记）。
        vec3 rim_dst = ALBEDO;
        // 主色：src = 颜色 × 光色，srcA = 方向因子 × 颜色 alpha（对应 lil_common_frag.hlsl:1696）
        vec3 rim_src = rim_rgb * rim_light * rim_gain;
        float rim_src_alpha = clamp(rim_dir * rim_color.a, 0.0, 1.0);
        vec3 rim_out = lil_blend_color(rim_dst, rim_src, vec3(rim_src_alpha), rim_blend_mode);
        SPECULAR_LIGHT += (rim_out - rim_dst);
        // 内侧色：同上（对应 :1697），dst 用上一式的结果，保持原版的顺序叠加
        vec3 rim_indir_src = rim_indir_color.rgb * rim_light * rim_indir_strength * rim_gain;
        float rim_indir_alpha = clamp(rim_indir * rim_indir_color.a, 0.0, 1.0);
        vec3 rim_indir_out = lil_blend_color(rim_out, rim_indir_src, vec3(rim_indir_alpha), rim_blend_mode);
        SPECULAR_LIGHT += (rim_indir_out - rim_out);
    }

    // 逆光：按视角与光源的夹角在轮廓上叠加透射光，对应 liltoon 的 lilBacklight。
    if (use_backlight && !use_unlit) {
        vec3 backlight_normal = normalize(mix(lil_geo_normal, NORMAL, backlight_normal_strength));
        vec4 backlight_rgb = backlight_color;
        if (use_backlight_color_tex) {
            backlight_rgb *= texture(backlight_color_tex, UV);
        }
        float hl = clamp(dot(normalize(LIGHT + VIEW), LIGHT), -1.0, 1.0);
        float backlight_factor = pow(clamp(-hl * 0.5 + 0.5, 0.0, 1.0), max(backlight_directivity, 0.001));
        float backlight_ln = dot(normalize(-VIEW * backlight_view_strength + LIGHT), backlight_normal) * 0.5 + 0.5;
        if (backlight_receive_shadow) {
            backlight_ln *= clamp(shadow, 0.0, 1.0);
        }
        backlight_ln = lil_tooning_scale(backlight_ln, backlight_border, backlight_blur);
        float backlight = clamp(backlight_factor * backlight_ln, 0.0, 1.0);
        if (backlight_backface_mask && lil_facing < 0.0) {
            backlight = 0.0;
        }
        vec3 backlight_out = mix(backlight_rgb.rgb, backlight_rgb.rgb * ALBEDO, backlight_main_strength);
        SPECULAR_LIGHT += backlight * backlight_rgb.a * backlight_out * light_rgb * specular_alpha;
    }

    // 毛发边缘光：只在毛发壳层生效，抗光按当前光的 N·L 削减。
#ifdef LILTOON_FUR
    if (use_fur_rim) {
        float fur_fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fur_rim_fresnel_power);
        float fur_anti = mix(1.0, clamp(1.0 - ndl, 0.0, 1.0), fur_rim_anti_light);
        SPECULAR_LIGHT += fur_rim_color.rgb * fur_fres * fur_anti * shadow * light_rgb * clamp(ALPHA, 0.0, 1.0);
    }
#endif

    if (use_anisotropy) {
        vec3 up = abs(NORMAL.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
        vec3 tangent = normalize(cross(up, NORMAL));
        vec3 bitangent = cross(NORMAL, tangent);
        // 切线贴图：对应 _AnisotropyTangentMap，用贴图给出切线方向并正交化到法线。
        // light() 里没有 TANGENT/BINORMAL 内建量，切线由 varying lil_tangent_view 提供。
        if (use_anisotropy_tangent_map) {
            vec3 aniso_map = texture(anisotropy_tangent_map, UV).xyz * 2.0 - 1.0;
            vec3 tangent_view = normalize(lil_tangent_view);
            vec3 bitangent_view = cross(NORMAL, tangent_view);
            tangent = normalize(tangent_view * aniso_map.x + bitangent_view * aniso_map.y + NORMAL * aniso_map.z);
            tangent = normalize(tangent - NORMAL * dot(tangent, NORMAL));
            bitangent = cross(NORMAL, tangent);
        }
        float aniso_shift_value = anisotropy_shift;
        if (use_anisotropy_shift_noise) {
            aniso_shift_value += (texture(anisotropy_shift_noise_texture, UV).r - 0.5) * anisotropy_shift_noise_scale;
        }
        vec3 aniso_t = normalize(tangent * anisotropy_tangent_width + bitangent * anisotropy_bitangent_width + NORMAL * aniso_shift_value);
        float tl = dot(aniso_t, LIGHT);
        float sin_tl = sqrt(max(0.0, 1.0 - tl * tl));
        float aniso_scale_value = anisotropy_scale;
        if (use_anisotropy_scale_mask) {
            aniso_scale_value *= texture(anisotropy_scale_mask, UV).r;
        }
        float exponent = mix(200.0, 8.0, aniso_scale_value);
        float aniso = pow(sin_tl, exponent) * anisotropy_specular_strength;
        SPECULAR_LIGHT += vec3(aniso) * light_rgb * shadow * specular_alpha;
    }
    if (use_anisotropy_2nd) {
        vec3 up_a2 = abs(NORMAL.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
        vec3 tan_a2 = normalize(cross(up_a2, NORMAL));
        vec3 bi_a2 = cross(NORMAL, tan_a2);
        float as2 = anisotropy_2nd_shift;
        if (use_anisotropy_2nd_shift_noise) {
            as2 += (texture(anisotropy_2nd_shift_noise_texture, UV).r - 0.5) * anisotropy_2nd_shift_noise_scale;
        }
        vec3 at2 = normalize(tan_a2 * anisotropy_2nd_tangent_width + bi_a2 * anisotropy_2nd_bitangent_width + NORMAL * as2);
        float tl2 = dot(at2, LIGHT);
        float st2 = sqrt(max(0.0, 1.0 - tl2 * tl2));
        SPECULAR_LIGHT += vec3(pow(st2, mix(200.0, 8.0, anisotropy_2nd_scale)) * anisotropy_2nd_specular_strength) * light_rgb * shadow * specular_alpha;
    }
    if (use_anisotropy_3rd) {
        vec3 up_a3 = abs(NORMAL.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
        vec3 tan_a3 = normalize(cross(up_a3, NORMAL));
        vec3 bi_a3 = cross(NORMAL, tan_a3);
        float as3 = anisotropy_3rd_shift;
        if (use_anisotropy_3rd_shift_noise) {
            as3 += (texture(anisotropy_3rd_shift_noise_texture, UV).r - 0.5) * anisotropy_3rd_shift_noise_scale;
        }
        vec3 at3 = normalize(tan_a3 * anisotropy_3rd_tangent_width + bi_a3 * anisotropy_3rd_bitangent_width + NORMAL * as3);
        float tl3 = dot(at3, LIGHT);
        float st3 = sqrt(max(0.0, 1.0 - tl3 * tl3));
        SPECULAR_LIGHT += vec3(pow(st3, mix(200.0, 8.0, anisotropy_3rd_scale)) * anisotropy_3rd_specular_strength) * light_rgb * shadow * specular_alpha;
    }
    if (use_specular || use_specular_2nd || use_specular_3rd) {
        // 高光法线在几何法线与扰动法线之间插值，对应 liltoon 的 _SpecularNormalStrength：
        // 设为 0 时法线贴图只影响明暗，不改变高光位置。
        vec3 spec_normal = normalize(mix(lil_geo_normal, NORMAL, specular_normal_strength));
        vec3 half_dir = normalize(LIGHT + VIEW);
        float nh = clamp(dot(spec_normal, half_dir), 0.0, 1.0);

        if (use_specular) {
            // 对齐 lilToon 的 lilCalcSpecular：toon 模式对 pow(nh, 1/粗糙度) 做阶跃
            // （lilTooningScale，border/blur 控制），非 toon 模式输出平滑值。
            float spec_rough = clamp(1.0 - specular_size, 0.02, 1.0);
            float spec_pow = pow(nh, 1.0 / spec_rough);
            float spec;
            if (specular_toon) {
                spec = lil_tooning_scale(spec_pow, specular_border, specular_blur + specular_smoothness);
            } else {
                spec = spec_pow;
            }
            SPECULAR_LIGHT += specular_color.rgb * specular_intensity * spec
                * shadow * SPECULAR_AMOUNT * light_rgb * specular_alpha;
        }

        if (use_specular_2nd) {
            float edge2 = 0.999 - specular_2nd_size * 0.15;
            float spec2_aa = lil_aa_edge(nh) + specular_2nd_smoothness;
            float spec2 = smoothstep(edge2 - spec2_aa, edge2 + spec2_aa, nh);
            SPECULAR_LIGHT += specular_2nd_color.rgb * specular_2nd_intensity * spec2
                * shadow * SPECULAR_AMOUNT * light_rgb * specular_alpha;
        }

        if (use_specular_3rd) {
            vec3 tangent = normalize(lil_tangent_view);
            float dot_th = clamp(dot(tangent, half_dir) + specular_3rd_shift, -1.0, 1.0);
            float sin_th = sqrt(max(0.0, 1.0 - dot_th * dot_th));
            float exponent = mix(400.0, 32.0, specular_3rd_size);
            float spec3 = pow(sin_th, exponent);
            SPECULAR_LIGHT += specular_3rd_color.rgb * specular_3rd_intensity * spec3
                * shadow * SPECULAR_AMOUNT * light_rgb * specular_alpha;
        }
    }

    // 第二层自发光荧光：按当前光源的受光强度调制，对应 liltoon 的 _Emission2ndFluorescence。
    // 写 SPECULAR_LIGHT 可避开引擎对 diffuse 的 ALBEDO 二次染色；多光源时会逐光源累加，
    // 比原版（只取主光）偏亮，已在 §9 记录。
    // 主自发光荧光：与 2nd 同一套近似（写 SPECULAR_LIGHT，多光源逐光源累加）。
    // AudioLink 渐变相位（_AudioLink2EmissionGrad / _AudioLink2Emission2ndGrad）：
    // 用显式 if 而不是三元，避免两边都求值带来的无谓采样。
    float al_grad_main = 0.0;
    float al_grad_2nd = 0.0;
    if (use_audiolink && audiolink_2_emission_grad) {
        al_grad_main = lil_audiolink_value(lil_uv(UV), UV2, UV2, UV2,
            dot(NORMAL, VIEW), lil_position_os, TIME,
            audiolink_uv_mode, audiolink_uv_params, audiolink_start);
    }
    if (use_audiolink && audiolink_2_emission_2nd_grad) {
        al_grad_2nd = lil_audiolink_value(lil_uv(UV), UV2, UV2, UV2,
            dot(NORMAL, VIEW), lil_position_os, TIME,
            audiolink_uv_mode, audiolink_uv_params, audiolink_start);
    }

    if (use_emission && emission_fluorescence > 0.001 && !use_unlit) {
        SPECULAR_LIGHT += lil_emission(lil_uv(UV), lil_view.xy / max(abs(lil_view.z), 0.001), ALBEDO, al_grad_main)
            * emission_fluorescence * lil_inv_lighting(light_rgb, shadow);
    }

    if (use_emission_2nd && emission_2nd_blend_mode == 0 && !use_unlit && emission_2nd_fluorescence > 0.001) {
        SPECULAR_LIGHT += lil_emission_2nd(lil_uv(UV), al_grad_2nd) * emission_2nd_fluorescence * lil_inv_lighting(light_rgb, shadow);
    }

    // MatCap 的受光/受阴影：需要逐光源的 light_rgb 与 shadow，只能在光照阶段算。
    // 参数非 0 时 fragment() 已跳过输出，这里按光源累加一次（多光源会重复采样，见 §9）。
    if (use_matcap && !matcap_multiply
        && (matcap_enable_lighting > 0.001 || matcap_shadow_mask > 0.001) && !use_unlit) {
        vec2 matcap_uv_l = lil_uv(UV);
        vec2 matcap_base_uv_l = lil_main_uv(matcap_uv_l);
        float matcap_persp = matcap_perspective ? 1.0 / max(1.0 + lil_view_depth * 0.2, 0.2) : 1.0;
        vec3 matcap_rgb = lil_matcap_color_light(NORMAL, matcap_persp, matcap_uv_l, matcap_base_uv_l);
        // 与 fragment 一致：main_strength 是向主色靠拢的程度，不是强度乘数。
        matcap_rgb = mix(matcap_rgb, matcap_rgb * ALBEDO, clamp(matcap_main_strength, 0.0, 1.0));
        float matcap_mask_l = lil_matcap_mask_value(matcap_uv_l);
        if (matcap_backface_mask && lil_facing < 0.0) {
            matcap_mask_l = 0.0;
        }
        float matcap_alpha_l = matcap_apply_transparency ? clamp(ALPHA, 0.0, 1.0) : 1.0;
        vec3 matcap_tint = mix(vec3(1.0), light_rgb, matcap_enable_lighting);
        float matcap_shadow = mix(1.0, shadow, matcap_shadow_mask);
        SPECULAR_LIGHT += matcap_rgb * matcap_tint * matcap_shadow
            * matcap_intensity * matcap_mask_l * matcap_alpha_l * specular_alpha;
    }

    // 第二槽 MatCap 的受光/受阴影：与主槽同构。
    if (use_matcap_2nd && !matcap_2nd_multiply
        && (matcap_2nd_enable_lighting > 0.001 || matcap_2nd_shadow_mask > 0.001) && !use_unlit) {
        vec2 matcap2_uv_l = lil_uv(UV);
        vec2 matcap2_base_l = lil_main_uv(matcap2_uv_l);
        float matcap2_persp = matcap_2nd_perspective ? 1.0 / max(1.0 + lil_view_depth * 0.2, 0.2) : 1.0;
        vec3 matcap2_rgb = lil_matcap_color_light_2nd(NORMAL, matcap2_persp, matcap2_uv_l, matcap2_base_l);
        // 第二槽同样：main_strength 是向主色靠拢的程度。
        matcap2_rgb = mix(matcap2_rgb, matcap2_rgb * ALBEDO, clamp(matcap_main_strength, 0.0, 1.0));
        float matcap2_mask_l = 1.0;
        if (use_matcap_2nd_mask) {
            float m2 = texture(matcap_2nd_mask, matcap2_uv_l * matcap_mask_uv_scale).r;
            matcap2_mask_l = smoothstep(matcap_mask_threshold - 0.05, matcap_mask_threshold + 0.05, m2);
        }
        float matcap2_alpha_l = matcap_2nd_apply_transparency ? clamp(ALPHA, 0.0, 1.0) : 1.0;
        if (matcap_2nd_backface_mask && lil_facing < 0.0) {
            matcap2_alpha_l = 0.0;
        }
        vec3 matcap2_tint = mix(vec3(1.0), light_rgb, matcap_2nd_enable_lighting);
        float matcap2_shadow = mix(1.0, shadow, matcap_2nd_shadow_mask);
        SPECULAR_LIGHT += matcap2_rgb * matcap2_tint * matcap2_shadow
            * matcap_2nd_intensity * matcap2_mask_l * matcap2_alpha_l * specular_alpha;
    }

    // 闪点的受光/受阴影：同上，参数非 0 时由光照阶段逐光源输出。
    if (use_glitter && (glitter_enable_lighting > 0.001 || glitter_shadow_mask > 0.001) && !use_unlit) {
        vec3 glitter_rgb_l = lil_glitter_color_light(NORMAL, lil_uv(UV), lil_uv2, lil_facing, clamp(ALPHA, 0.0, 1.0));
        vec3 glitter_tint_l = mix(vec3(1.0), light_rgb, glitter_enable_lighting);
        float glitter_shadow_l = mix(1.0, shadow, glitter_shadow_mask);
        SPECULAR_LIGHT += glitter_rgb_l * glitter_tint_l * glitter_shadow_l * specular_alpha;
    }

    if (use_unlit) {
        DIFFUSE_LIGHT = vec3(0.0);
        SPECULAR_LIGHT = vec3(0.0);
    }
}
