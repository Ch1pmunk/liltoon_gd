// liltoon_gd - 公共 fragment 主体
// 宏：LILTOON_CUTOUT / LILTOON_TRANSPARENT / LILTOON_PREMUL
// 注意：cull_disabled / cull_front 由引擎自动定义 DO_SIDE_CHECK 并翻转背面法线，
// 这里不能再手动翻转，否则会抵消引擎的处理，导致背面按正面光照计算。

void fragment() {
    if (IN_SHADOW_PASS && !cast_shadow) {
        discard;
    }

    vec2 uv = lil_uv(UV);
    // 双面材质：背面 UV 水平偏移一格，对应 liltoon 的 _ShiftBackfaceUV。
    if (shift_backface_uv && !FRONT_FACING) {
        uv += vec2(1.0, 0.0);
    }
    // 主贴图 UV 动画（滚动/旋转）只作用于主色链路，贴花层仍使用未动画的 uv。
    vec2 main_uv = lil_main_uv(uv);
    if (flip_normal) {
        NORMAL = -NORMAL;
    }
    float dissolve_visibility = lil_dissolve_visibility(uv, lil_position_os);

    if (use_parallax) {
        vec3 view_dir_view = normalize(-VERTEX);
        vec3 normal_view = normalize(NORMAL);
        vec3 tangent_view = normalize(TANGENT);
        vec3 binormal_view = normalize(BINORMAL);
        float denom = max(dot(view_dir_view, normal_view), 0.1);
        vec2 offset = vec2(dot(view_dir_view, tangent_view), dot(view_dir_view, binormal_view)) / denom;
        float height = texture(parallax_texture, main_uv).r;
        // parallax_offset 对应 _ParallaxOffset：高度图零点，默认 0.5（灰度中点）。
        main_uv += offset * (height - parallax_offset) * parallax_height;
    }

    vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    vec3 world_position = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

    vec4 base;
    if (use_triplanar && use_main_texture) {
        base = lil_sample_main_triplanar(world_position, world_normal);
    } else {
        base = lil_sample_main(main_uv);
    }

    ALBEDO = base.rgb;

    if (use_vertex_color) {
        ALBEDO *= mix(vec3(1.0), COLOR.rgb, vertex_color_strength);
    }

    // UDIM 片元模式（_UDIMDiscardMode = 1）：逐像素丢弃。
    if (use_udim_discard && udim_discard_mode == 1 && lil_udim_discard(UV, UV2, UV2, UV2)) {
        discard;
    }

    // 三通道特性遮罩（_TriMask）：R 遮 MatCap、G 遮边缘光、B 遮自发光。
    vec3 tri_mask_value = use_tri_mask ? texture(tri_mask, uv).rgb : vec3(1.0);

    // AudioLink：整帧只算一次，供自发光/贴花各路由复用（原版每处各算一遍，这里合并省采样）。
    float al_value = 1.0;
    if (use_audiolink) {
        al_value = lil_audiolink_value(uv, UV2, UV2, UV2,
            dot(normalize(NORMAL), normalize(VIEW)), lil_position_os, TIME,
            audiolink_uv_mode, audiolink_uv_params, audiolink_start);
    }

    if (use_decal) {
        vec2 decal_base_uv = (decal_uv_mode == 1 ? UV2 : uv);
    if (use_parallax) {
        decal_base_uv = lil_parallax_uv(decal_base_uv, parallax_texture, parallax_height, VIEW.xy / max(abs(VIEW.z), 0.001), parallax_offset);
    }
    vec4 decal = texture(decal_texture, lil_rotate_uv(decal_base_uv * decal_uv_scale + decal_uv_offset, decal_uv_rotate) + TIME * decal_uv_scroll) * decal_color;
        float decal_mask = clamp(decal.a * decal_strength, 0.0, 1.0);
        if (use_decal_mask) {
            decal_mask *= texture(decal_shared_mask, uv * decal_mask_uv_scale).r;
        }
        if (decal_blend_mode == 1) {
            ALBEDO *= mix(vec3(1.0), decal.rgb, decal_mask);
        } else if (decal_blend_mode == 2) {
            ALBEDO += decal.rgb * decal_mask;
        } else {
            ALBEDO = mix(ALBEDO, decal.rgb, decal_mask);
        }
    }

    if (use_decal_3rd) {
        vec2 decal3_uv = lil_rotate_uv((decal_3rd_uv_mode == 1 ? UV2 : uv) * decal_3rd_uv_scale + decal_3rd_uv_offset, decal_uv_rotate + decal_3rd_uv_rotate) + TIME * (decal_uv_scroll + decal_3rd_uv_scroll);
        if (decal_3rd_anim_columns > 1 || decal_3rd_anim_rows > 1) {
            vec2 grid3 = vec2(float(decal_3rd_anim_columns), float(decal_3rd_anim_rows));
            float frames3 = grid3.x * grid3.y;
            float frame3 = mod(floor(TIME * decal_3rd_anim_speed), frames3);
            vec2 cell3 = vec2(mod(frame3, grid3.x), floor(frame3 / grid3.x));
            decal3_uv = decal3_uv / grid3 + cell3 / grid3;
        }
        if (use_parallax_3rd) {
        decal3_uv = lil_parallax_uv(decal3_uv, parallax_3rd_texture, parallax_3rd_height, VIEW.xy / max(abs(VIEW.z), 0.001), 0.5);
    }
    vec4 decal3 = texture(decal_3rd_texture, decal3_uv) * decal_3rd_color;
    if (decal_3rd_alpha_mode == 1) {
        decal3.rgb *= decal3.a;
    }
        float decal3_mask = clamp(decal3.a * decal_3rd_strength, 0.0, 1.0);
        if (use_decal_3rd_normal) {
            vec3 n3 = texture(decal_3rd_normal_map, uv).rgb * 2.0 - 1.0;
            vec3 up3 = abs(NORMAL.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
            vec3 t3 = normalize(cross(up3, NORMAL));
            vec3 b3 = cross(NORMAL, t3);
            NORMAL = normalize(NORMAL + (t3 * n3.x + b3 * n3.y) * decal_3rd_normal_scale * decal3_mask);
        }
        if (use_decal_mask) {
            decal3_mask *= texture(decal_shared_mask, uv * decal_mask_uv_scale).r * texture(decal_3rd_mask, uv * decal_mask_uv_scale).r;
        }
        decal3_mask *= mix(1.0, lil_dissolve_visibility(uv + decal_3rd_dissolve_offset, lil_position_os), decal_3rd_dissolve_strength);
        if (use_decal_3rd_dissolve_mask) {
            decal3_mask *= texture(decal_3rd_dissolve_mask, uv * decal_mask_uv_scale).r;
        }
        if (use_decal_3rd_dissolve_noise) {
            vec2 dn3_uv = lil_uv_anim(uv, decal_3rd_dissolve_noise_uv_scroll, decal_3rd_dissolve_noise_uv_rotate) * decal_mask_uv_scale;
        float dn3 = texture(decal_3rd_dissolve_noise, dn3_uv).r;
            decal3_mask *= mix(1.0, dn3, decal_3rd_dissolve_noise_strength);
        }
        if (decal_3rd_distance_fade > 0.001) {
            float df3 = clamp((length(VERTEX) - distance_fade_near) / max(distance_fade_far - distance_fade_near, 0.0001), 0.0, 1.0);
            decal3_mask *= mix(1.0, 1.0 - df3, decal_3rd_distance_fade);
        }
        if (decal_3rd_cull_mode == 1 && dot(NORMAL, VIEW) < 0.0) {
            decal3_mask = 0.0;
        } else if (decal_3rd_cull_mode == 2 && dot(NORMAL, VIEW) >= 0.0) {
            decal3_mask = 0.0;
        }
        if (!decal_3rd_enable_lighting) {
            // AudioLink 接到第三贴层的 Alpha（对应 _AudioLink2Main3rd）
    if (audiolink_2_main_3rd) {
        decal3_mask *= al_value;
    }
    EMISSION += decal3.rgb * decal3_mask;
        } else if (decal_3rd_blend_mode == 1) {
            ALBEDO *= mix(vec3(1.0), decal3.rgb, decal3_mask);
        } else if (decal_3rd_blend_mode == 2) {
            ALBEDO += decal3.rgb * decal3_mask;
        } else {
            ALBEDO = mix(ALBEDO, decal3.rgb, decal3_mask);
        }
    }

    if (use_decal_2nd) {
        vec2 decal2_uv = lil_rotate_uv((decal_2nd_uv_mode == 1 ? UV2 : uv) * decal_2nd_uv_scale + decal_2nd_uv_offset, decal_uv_rotate + decal_2nd_uv_rotate) + TIME * (decal_uv_scroll + decal_2nd_uv_scroll);
        if (decal_2nd_anim_columns > 1 || decal_2nd_anim_rows > 1) {
            vec2 grid2 = vec2(float(decal_2nd_anim_columns), float(decal_2nd_anim_rows));
            float frames2 = grid2.x * grid2.y;
            float frame2 = mod(floor(TIME * decal_2nd_anim_speed), frames2);
            vec2 cell2 = vec2(mod(frame2, grid2.x), floor(frame2 / grid2.x));
            decal2_uv = decal2_uv / grid2 + cell2 / grid2;
        }
        if (use_parallax_2nd) {
        decal2_uv = lil_parallax_uv(decal2_uv, parallax_2nd_texture, parallax_2nd_height, VIEW.xy / max(abs(VIEW.z), 0.001), 0.5);
    }
    vec4 decal2 = texture(decal_2nd_texture, decal2_uv) * decal_2nd_color;
    if (decal_2nd_alpha_mode == 1) {
        decal2.rgb *= decal2.a;
    }
        float decal2_mask = clamp(decal2.a * decal_2nd_strength, 0.0, 1.0);
        if (use_decal_2nd_normal) {
            vec3 n2 = texture(decal_2nd_normal_map, uv).rgb * 2.0 - 1.0;
            vec3 up2 = abs(NORMAL.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
            vec3 t2 = normalize(cross(up2, NORMAL));
            vec3 b2 = cross(NORMAL, t2);
            NORMAL = normalize(NORMAL + (t2 * n2.x + b2 * n2.y) * decal_2nd_normal_scale * decal2_mask);
        }
        if (use_decal_mask) {
            decal2_mask *= texture(decal_shared_mask, uv * decal_mask_uv_scale).r * texture(decal_2nd_mask, uv * decal_mask_uv_scale).r;
        }
        decal2_mask *= mix(1.0, lil_dissolve_visibility(uv + decal_2nd_dissolve_offset, lil_position_os), decal_2nd_dissolve_strength);
        if (use_decal_2nd_dissolve_mask) {
            decal2_mask *= texture(decal_2nd_dissolve_mask, uv * decal_mask_uv_scale).r;
        }
        if (use_decal_2nd_dissolve_noise) {
            vec2 dn2_uv = lil_uv_anim(uv, decal_2nd_dissolve_noise_uv_scroll, decal_2nd_dissolve_noise_uv_rotate) * decal_mask_uv_scale;
        float dn2 = texture(decal_2nd_dissolve_noise, dn2_uv).r;
            decal2_mask *= mix(1.0, dn2, decal_2nd_dissolve_noise_strength);
        }
        if (decal_2nd_distance_fade > 0.001) {
            float df2 = clamp((length(VERTEX) - distance_fade_near) / max(distance_fade_far - distance_fade_near, 0.0001), 0.0, 1.0);
            decal2_mask *= mix(1.0, 1.0 - df2, decal_2nd_distance_fade);
        }
        if (decal_2nd_cull_mode == 1 && dot(NORMAL, VIEW) < 0.0) {
            decal2_mask = 0.0;
        } else if (decal_2nd_cull_mode == 2 && dot(NORMAL, VIEW) >= 0.0) {
            decal2_mask = 0.0;
        }
        if (!decal_2nd_enable_lighting) {
            // AudioLink 接到第二贴层的 Alpha（对应 _AudioLink2Main2nd）
    if (audiolink_2_main_2nd) {
        decal2_mask *= al_value;
    }
    EMISSION += decal2.rgb * decal2_mask;
        } else if (decal_2nd_blend_mode == 1) {
            ALBEDO *= mix(vec3(1.0), decal2.rgb, decal2_mask);
        } else if (decal_2nd_blend_mode == 2) {
            ALBEDO += decal2.rgb * decal2_mask;
        } else {
            ALBEDO = mix(ALBEDO, decal2.rgb, decal2_mask);
        }
    }

#ifdef LILTOON_CUTOUT
    ALPHA = base.a;
#ifndef LILTOON_A2C
    ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
#endif
#endif

#ifdef LILTOON_TRANSPARENT
    ALPHA = base.a * main_opacity;
#endif

    // 溶解：低于阈值的片元丢弃，边界带按 dissolve_color 发光（对应 liltoon 的 dissolve）。
    if (use_dissolve) {
        vec2 dissolve_noise_uv = uv * dissolve_noise_uv_scale;
        float dissolve_rot = radians(dissolve_noise_rotate);
        float dissolve_cos = cos(dissolve_rot);
        float dissolve_sin = sin(dissolve_rot);
        dissolve_noise_uv = mat2(vec2(dissolve_cos, -dissolve_sin), vec2(dissolve_sin, dissolve_cos)) * dissolve_noise_uv;
        float dissolve_noise = (texture(dissolve_noise_texture, dissolve_noise_uv + TIME * dissolve_noise_scroll).r - 0.5) * dissolve_noise_strength;
        float dissolve_value;
        if (dissolve_mode == 0) {
            float mask_value = 1.0;
            if (use_dissolve_mask) {
                mask_value = texture(dissolve_mask, uv * dissolve_mask_uv_scale).r;
            }
            dissolve_value = mask_value + dissolve_noise;
        } else if (dissolve_mode == 1) {
            vec2 dissolve_dir = normalize(dissolve_position.xy + vec2(0.0001, 0.0));
            dissolve_value = dissolve_shape == 1
                ? dot(uv, dissolve_dir) + dissolve_noise
                : distance(uv, dissolve_position.xy) + dissolve_noise;
        } else {
            vec3 dissolve_dir_3d = normalize(dissolve_position + vec3(0.0001, 0.0, 0.0));
            dissolve_value = dissolve_shape == 1
                ? dot(lil_position_os, dissolve_dir_3d) + dissolve_noise
                : distance(lil_position_os, dissolve_position) + dissolve_noise;
        }
        if (dissolve_value < dissolve_border) {
            discard;
        }
        float dissolve_edge = 1.0 - clamp(abs(dissolve_value - dissolve_border) / max(dissolve_blur, 0.001), 0.0, 1.0);
        EMISSION += dissolve_color.rgb * dissolve_edge;
    }

#ifdef LILTOON_FUR
    float fur_t = lil_fur_t;
    vec2 fur_noise_uv = UV * fur_noise_uv_scale + TIME * fur_noise_uv_scroll;
    float fur_rot = radians(fur_noise_uv_rotate);
    float fur_cos = cos(fur_rot);
    float fur_sin = sin(fur_rot);
    fur_noise_uv = mat2(vec2(fur_cos, -fur_sin), vec2(fur_sin, fur_cos)) * fur_noise_uv;
    float fur_strand_mask = texture(fur_noise_texture, fur_noise_uv).a;
    // 毛束：用同一张噪声贴图在低频尺度上调制密度，让毛发聚成簇。
    // 这是本项目的自有效果（lilToon 没有 strand 相关参数），2026-10-28 之前这两个参数
    // 只声明未接线，调了没有反应。
    if (fur_strand_density > 0.001) {
        float fur_strand = texture(fur_noise_texture, UV * fur_strand_scale).a;
        fur_strand_mask *= mix(1.0, fur_strand, fur_strand_density);
    }
    // 对齐项：_FurNoiseMask（参差裁切）与 _FurMask（生长区域），默认白图不影响。
    fur_strand_mask *= texture(fur_noise_mask, UV * fur_noise_mask_uv_scale).r;
    fur_strand_mask *= texture(fur_mask, uv).r;
    vec3 fur_color = mix(fur_root_color.rgb, fur_tip_color.rgb, fur_t);
    ALBEDO = mix(ALBEDO, fur_color, 0.35 * fur_t);
    ALBEDO *= mix(1.0 - fur_ao, 1.0, clamp(fur_t * 1.2, 0.0, 1.0));
#ifdef LILTOON_CUTOUT
    float fur_cut_t = clamp(fur_t / max(fur_cutout_length, 0.001), 0.0, 1.0);
    ALPHA = fur_strand_mask * mix(1.0, 0.1, fur_cut_t);
#else
    ALPHA *= fur_strand_mask;
    ALPHA *= clamp(1.0 - fur_t, 0.0, 1.0);
#endif
#endif

    // 片元阶段可用的法线：默认用插值法线，启用法线贴图后在片元内重建映射后法线。
    // 引擎在 fragment() 之后才应用 NORMAL_MAP，若 MatCap 直接读 NORMAL 会忽略法线贴图。
    vec3 shaded_normal = NORMAL;
    if (use_normal_map || use_normal_map_2nd) {
        vec2 normal_xy = vec2(0.0);
        if (use_normal_map) {
            normal_xy += (texture(normal_texture, main_uv).xy * 2.0 - 1.0) * normal_strength;
        }
        if (use_normal_map_2nd) {
            vec2 normal2_uv = decal_2nd_normal_uv_mode == 1 ? UV2 : uv;
            float normal2_scale = normal_strength_2nd;
            if (use_decal_2nd_normal_scale_mask) {
                normal2_scale *= texture(decal_2nd_normal_scale_mask, main_uv).r;
            }
            normal_xy += (texture(normal_texture_2nd, normal2_uv).xy * 2.0 - 1.0) * normal2_scale;
        }
        vec3 normal_ts = normalize(vec3(normal_xy, 1.0));
        NORMAL_MAP = normal_ts * 0.5 + 0.5;
        NORMAL_MAP_DEPTH = 1.0;
        // 没有切线数据的网格退回插值法线，避免除以零产生 NaN。
        if (dot(TANGENT, TANGENT) > 0.0001 && dot(BINORMAL, BINORMAL) > 0.0001) {
            shaded_normal = normalize(TANGENT * normal_ts.x + BINORMAL * normal_ts.y + NORMAL * normal_ts.z);
        }
    }

    float matcap_mask_value = lil_matcap_mask_value(uv);
    if (matcap_backface_mask && !FRONT_FACING) {
        matcap_mask_value = 0.0;
    }

    // 受光/受阴影需要 lightColor 与 shadowmix，只在光照阶段存在；
    // 这两个参数非 0 时整段让给 light()，这里连采样一起跳过。
    // use_unlit 的材质不参与光照，light() 不会被调用，必须留在片元里输出，
    // 否则参数非 0 时两边都不输出，MatCap 会整个消失。
    bool matcap_in_light = !matcap_multiply && !use_unlit
        && (matcap_enable_lighting > 0.001 || matcap_shadow_mask > 0.001);
    if (use_matcap && !matcap_in_light) {
        vec3 matcap_normal = mix(NORMAL, shaded_normal, matcap_normal_strength);
        if (use_matcap_bump_map) {
            vec3 matcap_bump = texture(matcap_bump_map, uv).xyz * 2.0 - 1.0;
            if (matcap_custom_normal && length(TANGENT) > 0.001) {
                // 对应 _MatCapCustomNormal：贴图被当作完整法线，经切线空间变换，而不是叠加扰动。
                matcap_normal = normalize(
                    normalize(TANGENT) * matcap_bump.x * matcap_bump_scale
                    + normalize(BINORMAL) * matcap_bump.y * matcap_bump_scale
                    + normalize(NORMAL) * matcap_bump.z);
            } else {
                matcap_normal = normalize(matcap_normal + vec3(matcap_bump.xy * matcap_bump_scale, 0.0));
            }
        }
        // 各向异性法线替换（_Anisotropy2MatCap）：用发丝方向的法线采样 MatCap。
        if (anisotropy_2_matcap && use_anisotropy) {
            matcap_normal = lil_anisotropy_normal(matcap_normal, uv, VIEW, anisotropy_scale);
        }
        vec3 mc = lil_sample_matcap(matcap_normal, matcap_perspective ? 1.0 / max(1.0 + length(VERTEX) * 0.2, 0.2) : 1.0, uv);
        // _MatCapMainStrength 是「MatCap 向主色靠拢的程度」，不是强度乘数：
        // 原版 matCapColor = lerp(matCapColor, matCapColor * albedo, _MatCapMainStrength)。
        mc = mix(mc, mc * ALBEDO, clamp(matcap_main_strength, 0.0, 1.0));
        float matcap_alpha = matcap_apply_transparency ? clamp(ALPHA, 0.0, 1.0) : 1.0;
        float matcap_weight = matcap_intensity * matcap_mask_value * matcap_alpha;
        if (matcap_multiply) {
            ALBEDO *= mix(vec3(1.0), mc, clamp(matcap_weight, 0.0, 1.0));
        } else {
            EMISSION += mc * matcap_weight * tri_mask_value.r;
        }
    }

    float matcap2_mask_value = 1.0;
    if (use_matcap_2nd_mask) {
        float m2 = texture(matcap_2nd_mask, uv * matcap_mask_uv_scale).r;
        matcap2_mask_value = smoothstep(matcap_mask_threshold - 0.05, matcap_mask_threshold + 0.05, m2);
    }
    // 第二槽同样：受光/受阴影参数非 0 时整段让给 light()；unlit 材质没有光照阶段，留在片元。
    bool matcap2_in_light = !matcap_2nd_multiply && !use_unlit
        && (matcap_2nd_enable_lighting > 0.001 || matcap_2nd_shadow_mask > 0.001);
    if (use_matcap_2nd && !matcap2_in_light) {
        vec3 mc_normal2 = mix(NORMAL, shaded_normal, matcap_2nd_normal_strength);
        if (use_matcap_2nd_bump) {
            vec3 nb2 = texture(matcap_2nd_bump_map, uv).rgb * 2.0 - 1.0;
            if (matcap_2nd_custom_normal && dot(TANGENT, TANGENT) > 0.0001 && dot(BINORMAL, BINORMAL) > 0.0001) {
                // 对应 _MatCap2ndCustomNormal：贴图当作完整法线，经切线空间变换。
                mc_normal2 = normalize(
                    normalize(TANGENT) * nb2.x * matcap_2nd_bump_scale
                    + normalize(BINORMAL) * nb2.y * matcap_2nd_bump_scale
                    + NORMAL * nb2.z);
            } else {
                vec3 up2 = abs(mc_normal2.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
                vec3 t2 = normalize(cross(up2, mc_normal2));
                vec3 b2 = cross(mc_normal2, t2);
                mc_normal2 = normalize(mc_normal2 + (t2 * nb2.x + b2 * nb2.y) * matcap_2nd_bump_scale);
            }
        }
        // 第二槽同样支持各向异性法线替换（_Anisotropy2MatCap2nd）。
        if (anisotropy_2_matcap_2nd && use_anisotropy) {
            mc_normal2 = lil_anisotropy_normal(mc_normal2, uv, VIEW, anisotropy_scale);
        }
        vec3 mc2 = lil_sample_matcap_2nd(mc_normal2, matcap_2nd_perspective ? 1.0 / max(1.0 + length(VERTEX) * 0.2, 0.2) : 1.0, uv);
        float matcap2_alpha = matcap_2nd_apply_transparency ? clamp(ALPHA, 0.0, 1.0) : 1.0;
        if (matcap_2nd_backface_mask && dot(NORMAL, VIEW) < 0.0) {
            matcap2_alpha = 0.0;
        }
        // 与主槽一致：main_strength 是向主色靠拢的程度，不是强度乘数。
        mc2 = mix(mc2, mc2 * ALBEDO, clamp(matcap_main_strength, 0.0, 1.0));
        float matcap2_weight = matcap_2nd_intensity * matcap2_mask_value * matcap2_alpha;
        if (matcap_2nd_multiply) {
            ALBEDO *= mix(vec3(1.0), mc2, clamp(matcap2_weight, 0.0, 1.0));
        } else {
            EMISSION += mc2 * matcap2_weight;
        }
    }

    float matcap3_mask_value = 1.0;
    if (use_matcap_3rd_mask) {
        float m3 = texture(matcap_3rd_mask, uv * matcap_mask_uv_scale).r;
        matcap3_mask_value = smoothstep(matcap_mask_threshold - 0.05, matcap_mask_threshold + 0.05, m3);
    }
    if (use_matcap_3rd) {
        vec3 mc_normal3 = mix(NORMAL, shaded_normal, matcap_3rd_normal_strength);
        if (use_matcap_3rd_bump) {
            vec3 nb3 = texture(matcap_3rd_bump_map, uv).rgb * 2.0 - 1.0;
            vec3 up3 = abs(mc_normal3.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
            vec3 t3 = normalize(cross(up3, mc_normal3));
            vec3 b3 = cross(mc_normal3, t3);
            mc_normal3 = normalize(mc_normal3 + (t3 * nb3.x + b3 * nb3.y) * matcap_3rd_bump_scale);
        }
        vec3 mc3 = lil_sample_matcap_3rd(mc_normal3, matcap_3rd_perspective ? 1.0 / max(1.0 + length(VERTEX) * 0.2, 0.2) : 1.0);
        float matcap3_alpha = matcap_3rd_apply_transparency ? clamp(ALPHA, 0.0, 1.0) : 1.0;
        if (matcap_3rd_backface_mask && dot(NORMAL, VIEW) < 0.0) {
            matcap3_alpha = 0.0;
        }
        // 第三槽同样处理（该项是本项目扩展，原版只有两槽）。
        mc3 = mix(mc3, mc3 * ALBEDO, clamp(matcap_main_strength, 0.0, 1.0));
        float matcap3_weight = matcap_3rd_intensity * matcap3_mask_value * matcap3_alpha;
        if (matcap_3rd_multiply) {
            ALBEDO *= mix(vec3(1.0), mc3, clamp(matcap3_weight, 0.0, 1.0));
        } else {
            EMISSION += mc3 * matcap3_weight;
        }
    }

    // 背面颜色：在光照前替换反照率，经过 toon 光照后近似原版的「背面颜色 × 光色」。
    if (!FRONT_FACING) {
        ALBEDO = mix(ALBEDO, backface_color.rgb, clamp(backface_color.a, 0.0, 1.0));
    }

    // 边缘阴影：把轮廓边缘压暗。原版是对最终颜色做 lerp(col, col*color, rim)，
    // 这里改在 ALBEDO 上等价地乘以暗色，避免 Godot 没有光照后处理阶段的问题。
    if (use_rim_shade) {
        vec3 rim_shade_normal = normalize(mix(lil_geo_normal, NORMAL, rim_shade_normal_strength));
        float rim_shade_fresnel = pow(clamp(1.0 - abs(dot(rim_shade_normal, VIEW)), 0.0, 1.0), rim_shade_fresnel_power);
        float rim_shade = lil_tooning_scale(rim_shade_fresnel, rim_shade_border, rim_shade_blur) * rim_shade_color.a;
        if (use_rim_shade_mask) {
            rim_shade *= texture(rim_shade_mask, uv).r;
        }
        ALBEDO = mix(ALBEDO, ALBEDO * rim_shade_color.rgb, clamp(rim_shade, 0.0, 1.0));
    }

    // 无光照材质没有 light() 阶段，边缘光在这里按纯 Fresnel 叠加。
    if (use_rim && use_unlit) {
        vec3 rim_normal = normalize(mix(lil_geo_normal, NORMAL, rim_normal_strength));
        float rim_factor = lil_rim_factor(rim_normal, VIEW);
        if (rim_backface_mask && lil_facing < 0.0) {
            rim_factor = 0.0;
        }
        vec3 rim_rgb = rim_color.rgb;
        if (use_rim_color_tex) {
            rim_rgb *= texture(rim_color_tex, uv).rgb;
        }
        if (use_rim_2nd) {
            rim_rgb = mix(rim_rgb, rim_2nd_color.rgb, rim_factor);
        }
        rim_rgb = mix(rim_rgb, rim_rgb * ALBEDO, rim_main_strength);

        float rim_mask_value = 1.0;
        if (use_rim_mask) {
            float mask_sample = texture(rim_mask, uv * rim_mask_uv_scale).r;
            rim_mask_value = smoothstep(rim_mask_threshold - 0.05, rim_mask_threshold + 0.05, mask_sample);
        }

        float rim_alpha = rim_apply_transparency ? clamp(ALPHA, 0.0, 1.0) : 1.0;
        EMISSION += rim_rgb * rim_factor * rim_color.a * rim_intensity * rim_mask_value * rim_alpha * tri_mask_value.g;
    }

    float ao_value = 1.0;
    if (use_ao_map) {
        ao_value *= texture(ao_texture, uv).r;
    }
    if (use_vertex_color_ao) {
        ao_value *= COLOR.r;
    }
    AO = mix(1.0, ao_value, ao_strength);
    AO_LIGHT_AFFECT = ao_light_affect;

    // 环境反射依赖引擎 PBR 的镜面 IBL；主体已移除 specular_disabled。
    // 默认把 SPECULAR 置 0，避免引擎直射高光与卡通高光重复；仅在启用反射时打开。
    if (use_reflection && use_reflection_cubemap) {
        // 自定义反射立方体贴图（对应 _ReflectionCubeOverride / _ReflectionCubeTex /
        // _ReflectionCubeColor / _ReflectionCubeEnableLighting）：替代环境 IBL。
        // 受光程度按"乘 ALBEDO"近似（1=随材质明暗、0=恒定），详见 §9。
        vec3 cube_view_dir = normalize(world_position - (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
        vec3 cube_reflect_dir = reflect(cube_view_dir, world_normal);
        vec3 cube_color = texture(reflection_cubemap, cube_reflect_dir).rgb * reflection_cubemap_color.rgb;
        float cube_fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
        vec3 cube_lit = mix(cube_color, cube_color * ALBEDO * 2.0, clamp(reflection_cubemap_lighting, 0.0, 1.0));
        EMISSION += cube_lit * cube_fresnel * (reflectance + 0.05);
        METALLIC = 0.0;
        ROUGHNESS = 1.0;
        SPECULAR = 0.0;
    } else if (use_reflection) {
        float metallic_value = metallic;
        float smoothness_value = clamp(1.0 - roughness, 0.0, 1.0);
        if (use_metallic_gloss_map) {
            vec4 metallic_gloss = texture(metallic_gloss_map, main_uv);
            metallic_value *= metallic_gloss.r;
            smoothness_value *= metallic_gloss.a;
        }
        if (use_smoothness_texture) {
            smoothness_value *= texture(smoothness_texture, main_uv).r;
        }
        float reflection_roughness = clamp(1.0 - smoothness_value, 0.002, 1.0);
        METALLIC = clamp(metallic_value, 0.0, 1.0);
        // GSAA：按法线屏幕导数抬高粗糙度，柔化几何边缘的反射，对应 liltoon 的 _GSAAStrength。
        vec3 normal_dx = abs(dFdx(NORMAL));
        vec3 normal_dy = abs(dFdy(NORMAL));
        float normal_dxy = max(dot(normal_dx, normal_dx), dot(normal_dy, normal_dy));
        float gsaa_roughness = normal_dxy / (normal_dxy * 5.0 + 0.002) * gsaa_strength;
        ROUGHNESS = clamp(max(reflection_roughness, gsaa_roughness), 0.0, 1.0);
        // 反射染色贴图：原版用它乘反射颜色的 RGB，这里 SPECULAR 是标量，只能按亮度缩放强度。
        float reflection_tint = 1.0;
        if (use_reflection_color_tex) {
            reflection_tint = dot(texture(reflection_color_tex, main_uv).rgb, vec3(0.299, 0.587, 0.114));
        }
        // 对齐 liltoon 的 _Reflectance：F0 强度直接交给引擎的镜面 IBL。
        float reflection_f0 = reflectance * reflection_tint;
        SPECULAR = reflection_apply_transparency ? reflection_f0 * clamp(ALPHA, 0.0, 1.0) : reflection_f0;
    } else {
        METALLIC = 0.0;
        ROUGHNESS = 1.0;
        SPECULAR = 0.0;
    }

    // 阴影环境光强度：把环境项的底色从反照率拉向白色，对应 _ShadowEnvStrength；默认 0 行为不变。
    // 近似：原版只作用于阴影区的间接光，这里对整段环境项生效，不区分受光/阴影。
    EMISSION += ambient_color.rgb * ambient_strength * mix(ALBEDO, vec3(1.0), shadow_env_strength);
    // AudioLink 接到主自发光（对应 _AudioLink2Emission / _AudioLink2EmissionGrad）
    EMISSION += lil_emission(uv, VIEW.xy / max(abs(VIEW.z), 0.001), ALBEDO)
        * (audiolink_2_emission ? al_value : 1.0) * tri_mask_value.b;
    // 闪点的受光/受阴影同样需要光照信息；unlit 材质没有光照阶段，必须留在片元里。
    bool glitter_in_light = !use_unlit
        && (glitter_enable_lighting > 0.001 || glitter_shadow_mask > 0.001);
    if (use_glitter && !glitter_in_light) {
        vec2 glitter_base_uv = glitter_uv_mode == 1 ? UV2 : uv;
        vec2 glitter_uv = glitter_base_uv * glitter_scale + NORMAL.xy * 8.0 * glitter_normal_strength;
        if (glitter_scale_randomize > 0.001) {
            float g_rand = fract(sin(dot(NORMAL.xy, vec2(41.0, 289.0))) * 43758.5453);
            glitter_uv += vec2(g_rand, fract(g_rand * 7.0)) * glitter_scale_randomize;
        }
        if (use_glitter_shape) {
            glitter_uv = glitter_base_uv * glitter_scale;
        }
        // 朝向随机：按位置哈希出角度旋转采样坐标，对应 liltoon 的 _GlitterAngleRandomize。
        if (glitter_angle_randomize > 0.001) {
            float angle = fract(sin(dot(glitter_base_uv, vec2(127.1, 311.7))) * 43758.5453)
                * 6.2831853 * glitter_angle_randomize;
            float ca = cos(angle);
            float sa = sin(angle);
            glitter_uv = mat2(vec2(ca, -sa), vec2(sa, ca)) * glitter_uv;
        }
        float glitter_seed = fract(sin(dot(glitter_uv, vec2(12.9898, 78.233))) * 43758.5453);
        if (use_glitter_shape) {
            glitter_seed *= texture(glitter_shape_texture, glitter_base_uv * glitter_scale).r;
        }
        float glitter_mask = smoothstep(1.0 - glitter_sensitivity, 1.0, glitter_seed);
        glitter_mask = pow(glitter_mask, glitter_post_contrast);
        if (glitter_backface_mask && !FRONT_FACING) {
            glitter_mask = 0.0;
        }
        vec3 glitter_tint = glitter_color.rgb;
        if (use_glitter_color_tex) {
            vec2 glitter_color_uv = glitter_color_uv_mode == 1 ? UV2 : uv;
            glitter_tint *= texture(glitter_color_texture, glitter_color_uv).rgb;
        }
        float glitter_alpha = glitter_apply_transparency ? clamp(ALPHA, 0.0, 1.0) : 1.0;
        EMISSION += glitter_tint * glitter_mask * glitter_intensity * glitter_alpha;
    }
    if (use_emission_2nd) {
        vec3 emission_2nd = lil_emission_2nd(uv);
        if (emission_2nd_blend_mode == 1) {
            ALBEDO *= emission_2nd;
        } else {
            // 荧光部分改在 light() 里按光源强度叠加，这里先扣掉，避免重复叠加。
            float fluorescence = use_unlit ? 0.0 : emission_2nd_fluorescence;
            // AudioLink 接到第二层自发光（对应 _AudioLink2Emission2nd / _AudioLink2Emission2ndGrad）
    EMISSION += emission_2nd * (1.0 - fluorescence) * (audiolink_2_emission_2nd ? al_value : 1.0);
        }
    }
    if (emission_blink_speed > 0.001 && emission_blink_strength > 0.001) {
        EMISSION *= 1.0 + sin(TIME * emission_blink_speed) * emission_blink_strength;
    }

    if (use_distance_fade) {
        // 相机距离或物体距离（对齐 liltoon 的 _DistanceFadeMode）。
        float fade_depth = distance_fade_mode == 1
            ? length(MODEL_MATRIX[3].xyz - INV_VIEW_MATRIX[3].xyz)
            : length(VERTEX);
        float fade = clamp((fade_depth - distance_fade_near) / max(distance_fade_far - distance_fade_near, 0.0001), 0.0, 1.0);
        fade *= distance_fade_strength;
        ALBEDO = mix(ALBEDO, distance_fade_color.rgb, fade);
        // 淡出时的边缘光染色，对应 _DistanceFadeRimColor；默认 Alpha 为 0 时不生效。
        if (distance_fade_rim_color.a > 0.001) {
            float fade_fresnel = pow(clamp(1.0 - abs(dot(NORMAL, VIEW)), 0.0, 1.0), distance_fade_rim_fresnel_power);
            ALBEDO = mix(ALBEDO, distance_fade_rim_color.rgb, fade * fade_fresnel * distance_fade_rim_color.a);
        }
        if (use_unlit) {
            EMISSION += ALBEDO;
            ALBEDO = vec3(0.0);
        }
        EMISSION = mix(EMISSION, vec3(0.0), fade);
#ifdef LILTOON_TRANSPARENT
        ALPHA = mix(ALPHA, ALPHA * distance_fade_color.a, fade);
#endif
    }

    // Alpha 遮罩与距离淡出无关，必须始终生效（此前误缩进到 distance fade 分支内）。
    if (use_alpha_mask) {
        float alpha_mask = clamp(texture(alpha_mask_texture, main_uv).r * alpha_mask_scale + alpha_mask_value, 0.0, 1.0);
        ALPHA = mix(ALPHA, ALPHA * alpha_mask, alpha_mask_strength);
    }

    // 抖动透明：按屏幕像素查抖动图，二值化 ALPHA，对应 liltoon 的 _UseDither。
    if (use_dither) {
        vec2 dither_size = vec2(textureSize(dither_texture, 0));
        float dither_value = texture(dither_texture, FRAGCOORD.xy / max(dither_size, vec2(1.0))).r;
        float dither_threshold = (dither_value * 255.0 + 1.0) / (dither_max_value + 2.0);
        ALPHA = ALPHA >= dither_threshold ? 1.0 : 0.0;
    }

#ifdef LILTOON_REFRACTION
    // 折射：对应 lilToon lilRefraction()——用视角法线扰动屏幕 UV，按菲涅尔与强度偏移，
    // 再按 ALPHA 与原色混合（原版为 lerp(refractCol, col, col.a)）。
    if (use_refraction) {
        float refraction_nv = pow(clamp(1.0 - dot(NORMAL, VIEW), 0.0, 1.0), refraction_fresnel_power);
        vec2 refraction_uv = SCREEN_UV + (refraction_nv * refraction_strength) * NORMAL.xy;
        vec3 refraction_col = texture(refraction_screen_texture, refraction_uv).rgb * refraction_color.rgb;
        if (refraction_color_from_main) {
            refraction_col *= ALBEDO;
        }
        ALBEDO = mix(refraction_col, ALBEDO, clamp(ALPHA, 0.0, 1.0));
    }
#endif

#ifdef LILTOON_GEM
    // 宝石：对应 lilToon lts_gem.shader——色散折射 + 环境对比度 + 粒子闪烁。
    {
        float gem_nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
        float gem_inv_nv = 1.0 - gem_nv;
        float gem_fresnel = pow(gem_inv_nv, refraction_fresnel_power);
        vec2 gem_ref = NORMAL.xy;
        // 色散折射：RGB 三通道分别在递增偏移处采样屏幕纹理。
        vec3 gem_refract;
        gem_refract.r = texture(gem_screen_texture, SCREEN_UV + (gem_fresnel * refraction_strength) * gem_ref).r;
        gem_refract.g = texture(gem_screen_texture, SCREEN_UV + (gem_fresnel * (refraction_strength + gem_chromatic_aberration)) * gem_ref).g;
        gem_refract.b = texture(gem_screen_texture, SCREEN_UV + (gem_fresnel * (refraction_strength + gem_chromatic_aberration * 2.0)) * gem_ref).b;
        // 环境对比度：pow 拉伸 + 按对比度混回灰度。
        gem_refract = pow(clamp(gem_refract, vec3(0.0), vec3(1.0)), vec3(gem_env_contrast)) * gem_env_contrast;
        float gem_gray = dot(gem_refract, vec3(1.0 / 3.0));
        gem_refract = mix(vec3(gem_gray), gem_refract, clamp(1.0 / gem_env_contrast, 0.0, 1.0));
        ALBEDO *= gem_refract;

        // 粒子闪烁：三个轴向视角分量各做一个阶跃图案，相乘得稀疏亮点。
        // 原版用 _GemParticleLoop 控制频率；该项不在对齐清单内，这里用固定值 8。
        float gem_loop = gem_particle_loop;
        vec3 gem_v = VIEW;
        float gem_nv1 = abs(dot(NORMAL, gem_v));
        float gem_nv2 = abs(dot(NORMAL, gem_v.yzx));
        float gem_nv3 = abs(dot(NORMAL, gem_v.zxy));
        float gem_particle = step(0.5, fract(gem_nv1 * gem_loop)) * step(0.5, fract(gem_nv2 * gem_loop)) * step(0.5, fract(gem_nv3 * gem_loop));
        vec3 gem_particle_col = vec3(1.0) + gem_particle * gem_particle_color.rgb;

        // 环境反射近似：用 fresnel 加权 + 对比度 + 环境色。
        float gem_surface_reduction = 1.0 / (1.0 + 0.25);
        float gem_grazing = clamp(gem_nv + 0.2, 0.0, 1.0);
        vec3 gem_env = pow(clamp(vec3(gem_grazing), vec3(0.0), vec3(1.0)), vec3(gem_env_contrast)) * gem_env_contrast * gem_env_color.rgb;
        float gem_env_gray = dot(gem_env, vec3(1.0 / 3.0));
        gem_env = mix(vec3(gem_env_gray), gem_env, clamp(1.0 / gem_env_contrast, 0.0, 1.0));
        ALBEDO += (gem_surface_reduction * gem_fresnel + 0.5) * 0.5 * gem_particle_col * gem_env;
    }
#endif

#ifdef LILTOON_CUTOUT
#ifdef LILTOON_A2C
    // alpha_to_coverage 完全依赖 ALPHA 生成覆盖率：只要写 ALPHA_SCISSOR_THRESHOLD（哪怕为 0），
    // 引擎就会按二值裁切处理、覆盖率恒为 1。这里改用逐片元 discard，放在片元最后，
    // 与 cutout 的 scissor 一样使用最终 ALPHA（含 Alpha 遮罩与淡出）；阴影 pass 同样走这里。
    if (ALPHA < alpha_cutoff) {
        discard;
    }
#endif
#endif

#ifdef LILTOON_PREMUL
    ALBEDO *= ALPHA;
    EMISSION *= ALPHA;
#endif

    DEPTH = clamp(FRAGCOORD.z + depth_offset, 0.0, 1.0);
}
