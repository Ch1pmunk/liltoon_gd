// liltoon_gd - 公共 vertex 主体
// 传递视空间切线（各向异性高光）与物体空间位置（溶解的物体空间模式）。

varying vec3 lil_position_os;
varying float lil_fur_t;
// 世界上方向在视空间的 XY 投影：MatCap 滚转抵消用（辅助函数里取不到 VIEW_MATRIX）。
varying vec2 lil_matcap_up;

// 安全归一化：长度近零时回退到 fallback，避免 normalize(0) 产生 NaN 顶点（表现为几何炸裂/消失）。
// 毛发方向由多个可为零的向量合成（毛向量 + 顶点色 + 贴图 + 重力 + 随机 + 触摸），逐层都有归零可能。
vec3 lil_safe_normalize(vec3 v, vec3 fallback) {
    return dot(v, v) > 1e-8 ? normalize(v) : fallback;
}

void vertex() {
    vec3 tangent = MODELVIEW_NORMAL_MATRIX * TANGENT;
    lil_tangent_view = length(tangent) > 0.0001 ? normalize(tangent) : vec3(1.0, 0.0, 0.0);
    lil_uv2 = UV2;
    vec3 view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 geo_normal_view = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
    lil_view = normalize(-view_position);
    lil_view_depth = length(view_position);
    lil_geo_normal = geo_normal_view;
    lil_facing = dot(geo_normal_view, lil_view);
    lil_position_os = VERTEX;
    // 世界上方向在视空间的 XY，用于 MatCap 抵消相机滚转（辅助函数里取不到 VIEW_MATRIX）。
    lil_matcap_up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xy + vec2(0.0, 0.0001));

#ifdef LILTOON_FUR
#ifdef LILTOON_FUR_INSTANCED
    float fur_t = clamp(INSTANCE_CUSTOM.r, 0.0, 1.0);
#else
    float fur_t = float(fur_layer) / max(float(fur_layers), 1.0);
#endif
    fur_t = fur_root_offset + (1.0 - fur_root_offset) * fur_t;
    lil_fur_t = fur_t;
    float fur_hash = fract(sin(dot(VERTEX.xz, vec2(12.9898, 78.233))) * 43758.5453);
    float fur_jitter = 1.0 + (fur_hash - 0.5) * fur_noise_strength;
    float fur_len_mask = texture(fur_length_mask, UV).r;
    vec3 fur_tangent = length(TANGENT) > 0.0001 ? normalize(TANGENT) : vec3(1.0, 0.0, 0.0);
    vec3 fur_bitangent = length(BINORMAL) > 0.0001 ? normalize(BINORMAL) : normalize(cross(NORMAL, fur_tangent));
    // 切线空间毛向量：顶点色与贴图都按 lilToon 的 lilBlendNormal 规则叠加
    // （dst.xy + src.xy, dst.z * src.z），再变换到物体空间。
    vec3 fur_vec = fur_vector + vec3(0.0, 0.0, 0.001);
    if (use_vertex_color_fur_vector) {
        fur_vec = vec3(fur_vec.xy + COLOR.rgb.xy, fur_vec.z * COLOR.rgb.z);
    }
    if (use_fur_vector_texture) {
        vec3 fur_tex_n = textureLod(fur_vector_texture, UV, 0.0).rgb * 2.0 - 1.0;
        fur_tex_n.xy *= fur_vector_scale;
        fur_vec = vec3(fur_vec.xy + fur_tex_n.xy, fur_vec.z * fur_tex_n.z);
    }
    // 每一层都可能合成零向量（毛向量被顶点色 z=0 抹掉、与法线反向、重力抵消等），逐层回退。
    vec3 fur_tangent_dir = lil_safe_normalize(fur_tangent * fur_vec.x + fur_bitangent * fur_vec.y + NORMAL * fur_vec.z, NORMAL);
    vec3 fur_base_dir = lil_safe_normalize(mix(NORMAL, fur_tangent_dir, fur_direction_strength), NORMAL);
    vec3 fur_dir = lil_safe_normalize(fur_base_dir + vec3(0.0, -fur_gravity * fur_t, 0.0) * 0.6, fur_base_dir);
    // 毛向量随机化：给方向加确定性随机扰动，对应 _FurRandomize（原版还乘毛长，这里只改方向）。
    if (fur_randomize > 0.001) {
        vec3 fur_rand = lil_safe_normalize(vec3(fur_hash - 0.5, fract(fur_hash * 7.31) - 0.5, fract(fur_hash * 3.17) - 0.5) + vec3(0.0001), vec3(0.0, 1.0, 0.0));
        fur_dir = lil_safe_normalize(fur_dir + fur_rand * fur_randomize, fur_dir);
    }
    // 触摸：把毛发从触摸点推开，对应 _FurTouchStrength（原版用 Unity 点光源，这里用物体空间触摸点）。
    if (fur_touch_strength > 0.001) {
        vec3 touch_delta = VERTEX - fur_touch_position;
        float touch_atten = clamp(1.0 - length(touch_delta) / max(fur_touch_range, 0.001), 0.0, 1.0);
        fur_dir = lil_safe_normalize(fur_dir + lil_safe_normalize(touch_delta + vec3(0.0001), vec3(0.0, 1.0, 0.0)) * touch_atten * fur_touch_strength, fur_dir);
    }
    VERTEX += fur_dir * fur_length * fur_vector_scale * fur_t * fur_jitter * fur_len_mask;
    float fur_phase = sin(TIME * fur_wind_speed + VERTEX.x * 3.0 + VERTEX.y * 2.5);
    vec3 fur_wind = normalize(fur_wind_direction + vec3(0.0001)) * fur_phase * fur_wind_strength * fur_length * fur_t;
    VERTEX += fur_wind;
#endif
}
