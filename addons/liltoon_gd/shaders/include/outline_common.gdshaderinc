// liltoon_gd - 描边公共实现（uniform / 顶点外扩 / 片元着色）
// 由 6 个描边变体 include；宏 LILTOON_OUTLINE_TRANSPARENT / LILTOON_OUTLINE_PREMUL 决定混合与 Alpha 行为。

/**
 * 描边。
 */
group_uniforms Outline;
/**
 * 描边颜色。
 */
uniform vec4 outline_color : source_color = vec4(0.12, 0.09, 0.12, 1.0);
/**
 * 描边外扩模式：沿法线、沿顶点位置方向或屏幕空间等宽。
 */
uniform int outline_mode : hint_enum("法线外扩", "位置外扩", "屏幕空间") = 0;
/**
 * 模型空间外扩宽度，法线/位置模式下生效。
 */
uniform float outline_width : hint_range(0.0, 0.2, 0.001) = 0.02;
/**
 * 屏幕空间描边宽度（NDC 比例），屏幕空间模式下生效。
 */
uniform float outline_screen_width : hint_range(0.0, 0.05, 0.0005) = 0.004;
/**
 * 是否使用遮罩限制描边显示范围。
 */
uniform bool use_outline_mask = false;
/**
 * 描边遮罩贴图，取 Alpha 通道。
 */
uniform sampler2D outline_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 描边遮罩的 UV 缩放。
 */
uniform vec2 outline_mask_uv_scale = vec2(1.0, 1.0);
/**
 * 描边遮罩阈值，低于该值不绘制描边。
 */
uniform float outline_mask_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;
/**
 * 是否用顶点色红通道缩放描边宽度。
 */
uniform bool use_vertex_color_outline = false;
/**
 * 是否用宽度遮罩缩放描边宽度，对应 liltoon 的 _OutlineWidthMask。
 */
uniform bool use_outline_width_mask = false;
/**
 * 宽度遮罩贴图：R 通道乘到描边宽度上。
 */
uniform sampler2D outline_width_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 是否用矢量图控制描边外扩方向，对应 liltoon 的 _OutlineVectorTex 开关。
 */
uniform bool use_outline_vector_map = false;
/**
 * 描边矢量图：切线空间法线图，RG 为方向，对应 liltoon 的 _OutlineVectorTex。
 */
uniform sampler2D outline_vector_texture : hint_normal, filter_linear_mipmap, repeat_enable;
/**
 * 矢量图 XY 强度，对应 liltoon 的 _OutlineVectorScale。
 */
uniform float outline_vector_scale : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * 矢量图 UV 模式：0 使用 UV，1 使用 UV2，对应 liltoon 的 _OutlineVectorUVMode。
 */
uniform int outline_vector_uv_mode : hint_enum("UV", "UV2") = 0;
/**
 * 顶点色参与宽度的方式：0 关闭、1 用 R 乘宽度、2 用 RGB 作方向并用 A 乘宽度，对应 liltoon 的 _OutlineVertexR2Width。
 */
uniform int outline_vertex_r2_width : hint_enum("关闭", "顶点色 R × 宽度", "顶点色 RGB 方向 + A × 宽度") = 0;
/**
 * 描边深度偏移，用于缓解深度冲突。
 */
uniform float outline_z_offset : hint_range(-0.1, 0.1, 0.0001) = 0.0;
/**
 * 是否随相机距离淡出：开启后远处描边逐渐收窄直至消失。
 */
uniform bool use_distance_fade = false;
/**
 * 淡出起始距离（米），小于该距离不淡出。
 */
uniform float distance_fade_near : hint_range(0.0, 100.0, 0.01) = 0.0;
/**
 * 淡出结束距离（米），超过后描边完全消失。
 */
uniform float distance_fade_far : hint_range(0.0, 100.0, 0.01) = 5.0;
/**
 * 淡出强度：1 为完全消失，0 为不淡出。
 */
uniform float distance_fade_strength : hint_range(0.0, 1.0, 0.001) = 1.0;
/**
 * 描边是否受光；lit 变体使用，unlit 变体忽略。
 */
/**
 * `outline_enable_lighting` 是描边受光开关的**状态标记**：真正的切换由材质工厂换成
 * 受光 shader 变体完成（`liltoon_outline_lit*.gdshader`），shader 内部不读这个值。
 * 保留它是为了让「切换透明度」能读到当前的受光状态，避免变体组合错乱。
 */
uniform bool outline_enable_lighting = false;
/**
 * 受光描边是否接收阴影，对应 liltoon 的 _OutlineLitShadowReceive。
 */
uniform bool outline_lit_shadow_receive = true;
/**
 * 描边受光时的暗部乘色：白色为不改变描边基色，调暗可加深暗部；
 * 对应 lilToon 的暗部 `outline_color × tex`（乘 1 不改变）。
 */
uniform vec4 outline_shade_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/**
 * 描边受光时的亮部颜色；A 通道为受光强度系数；
 * 对应 lilToon `_OutlineLitColor`（默认 (1,0.2,0,0)）。
 */
uniform vec4 outline_lit_color : source_color = vec4(1.0, 0.2, 0.0, 0.0);
/**
 * 亮部颜色是否乘描边贴图；对应 lilToon `_OutlineLitApplyTex`（默认 0）。
 */
uniform bool outline_lit_apply_tex = false;
/**
 * 受光强度曲线的斜率，越大亮暗过渡越陡；对应 lilToon `_OutlineLitScale`（默认 10）。
 */
uniform float outline_lit_scale : hint_range(0.0, 100.0, 0.1) = 10.0;
/**
 * 受光强度曲线的偏移，负值使亮部范围变小；对应 lilToon `_OutlineLitOffset`（默认 -8）。
 */
uniform float outline_lit_offset : hint_range(-50.0, 50.0, 0.1) = -8.0;
/**
 * 描边贴图：颜色会与描边色相乘，默认白色。
 */
uniform sampler2D outline_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 描边贴图的 UV 缩放。
 */
uniform vec2 outline_texture_uv_scale = vec2(1.0, 1.0);
/**
 * 描边贴图 UV 滚动速度（每秒，X/Y 分别），对应 liltoon 的 _OutlineTex_ScrollRotate.xy。
 */
uniform vec2 outline_uv_scroll = vec2(0.0, 0.0);
/**
 * 描边贴图 UV 旋转：X 为初始角度（弧度），Y 为角速度（弧度/秒），对应 _OutlineTex_ScrollRotate.zw。
 */
uniform vec2 outline_uv_rotate = vec2(0.0, 0.0);
/**
 * 描边贴图 HSV/Gamma 校正，对应 liltoon 的 _OutlineTexHSVG；默认 (0,1,1,1) 不改变颜色。
 */
uniform vec4 outline_hsvg = vec4(0.0, 1.0, 1.0, 1.0);
/**
 * 固定像素宽度：开启后强制走屏幕空间模式。
 */
uniform bool outline_fix_width = false;
/**
 * 描边按顶点色 Alpha 预乘，用于半透明头发等。
 */
uniform bool outline_apply_transparency = false;

/**
 * 描边透明度（仅透明变体生效）。
 */
uniform float outline_opacity : hint_range(0.0, 1.0, 0.001) = 1.0;

group_uniforms;

varying float v_outline_fade;

// liltoon 的描边 UV 动画：绕 0.5 旋转后叠加按时间取小数的滚动。
vec2 lil_outline_uv(vec2 base_uv) {
    float angle = outline_uv_rotate.x + outline_uv_rotate.y * TIME;
    float c = cos(angle);
    float s = sin(angle);
    vec2 centered = base_uv - 0.5;
    vec2 rotated = vec2(centered.x * c - centered.y * s, centered.x * s + centered.y * c) + 0.5;
    return rotated + fract(outline_uv_scroll * TIME);
}

// 与主贴图相同的 HSV/Gamma 校正（lilToneCorrection）。
vec3 lil_outline_hsvg(vec3 color, vec4 hsvg) {
    if (hsvg == vec4(0.0, 1.0, 1.0, 1.0)) {
        return color;
    }
    vec3 c = pow(abs(color), vec3(hsvg.w));
    vec4 p = (c.b > c.g) ? vec4(c.bg, -1.0, 2.0 / 3.0) : vec4(c.gb, 0.0, -1.0 / 3.0);
    vec4 q = (p.x > c.r) ? vec4(p.xyw, c.r) : vec4(c.r, p.yzx);
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    vec3 hsv = vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
    hsv = vec3(hsv.x + hsvg.x, clamp(hsv.y * hsvg.y, 0.0, 1.0), clamp(hsv.z * hsvg.z, 0.0, 1.0));
    return hsv.z - hsv.z * hsv.y + hsv.z * hsv.y * clamp(abs(fract(hsv.x + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

void vertex() {
    float width_scale = 1.0;
    if (use_vertex_color_outline) {
        width_scale *= clamp(COLOR.r, 0.0, 1.0);
    }
    if (outline_vertex_r2_width == 1) {
        width_scale *= clamp(COLOR.r, 0.0, 1.0);
    } else if (outline_vertex_r2_width == 2) {
        width_scale *= clamp(COLOR.a, 0.0, 1.0);
    }
    if (use_outline_width_mask) {
        width_scale *= texture(outline_width_mask, UV).r;
    }

    vec3 outline_normal = NORMAL;
    if (use_outline_vector_map) {
        vec2 vector_uv = outline_vector_uv_mode == 1 ? UV2 : UV;
        vec3 vector_sample = texture(outline_vector_texture, vector_uv).rgb * 2.0 - 1.0;
        vector_sample.xy *= outline_vector_scale;
        vector_sample.z = sqrt(max(0.0, 1.0 - dot(vector_sample.xy, vector_sample.xy)));
        vec3 tangent = length(TANGENT) > 0.0001 ? normalize(TANGENT) : vec3(1.0, 0.0, 0.0);
        vec3 bitangent = length(BINORMAL) > 0.0001 ? normalize(BINORMAL) : normalize(cross(NORMAL, tangent));
        outline_normal = normalize(tangent * vector_sample.x + bitangent * vector_sample.y + NORMAL * vector_sample.z);
    }
    if (outline_vertex_r2_width == 2) {
        vec3 tangent = length(TANGENT) > 0.0001 ? normalize(TANGENT) : vec3(1.0, 0.0, 0.0);
        vec3 bitangent = length(BINORMAL) > 0.0001 ? normalize(BINORMAL) : normalize(cross(NORMAL, tangent));
        vec3 vertex_dir = normalize(COLOR.rgb * 2.0 - 1.0 + vec3(0.0001));
        outline_normal = normalize(tangent * vertex_dir.x + bitangent * vertex_dir.y + NORMAL * vertex_dir.z);
    }

    vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    v_outline_fade = 0.0;
    if (use_distance_fade) {
        float depth = length(view_position.xyz);
        v_outline_fade = clamp((depth - distance_fade_near) / max(distance_fade_far - distance_fade_near, 0.0001), 0.0, 1.0) * distance_fade_strength;
        width_scale *= 1.0 - v_outline_fade;
    }

    vec4 clip = PROJECTION_MATRIX * view_position;

    int outline_effective_mode = outline_fix_width ? 2 : outline_mode;
    if (outline_effective_mode == 0) {
        VERTEX += outline_normal * outline_width * width_scale;
        clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    } else if (outline_effective_mode == 1) {
        vec3 direction = length(VERTEX) > 0.0001 ? normalize(VERTEX) : NORMAL;
        VERTEX += direction * outline_width * width_scale;
        clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    } else {
        vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
        vec2 direction = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
        if (length(direction) > 0.0001) {
            // 先在像素空间归一化再转回 NDC，避免非正方形视口下横向描边被拉粗。
            float aspect = PROJECTION_MATRIX[1][1] / max(PROJECTION_MATRIX[0][0], 0.0001);
            vec2 pixel_dir = normalize(vec2(direction.x * aspect, direction.y));
            direction = vec2(pixel_dir.x / aspect, pixel_dir.y);
            clip.xy += direction * outline_screen_width * width_scale * clip.w * 2.0;
        }
    }

    clip.z += outline_z_offset * clip.w;
    POSITION = clip;
}

void fragment() {
    if (use_distance_fade && v_outline_fade > 0.99) {
        discard;
    }
    vec2 outline_uv = lil_outline_uv(UV);
    vec3 outline_rgb = outline_color.rgb * texture(outline_texture, outline_uv * outline_texture_uv_scale).rgb;
    ALBEDO = lil_outline_hsvg(outline_rgb, outline_hsvg);

#ifdef LILTOON_OUTLINE_TRANSPARENT
    ALPHA = outline_opacity * (outline_apply_transparency ? COLOR.a : 1.0);
#ifdef LILTOON_OUTLINE_PREMUL
    // 预乘混合要求颜色先乘 Alpha，否则整体会偏暗。
    ALBEDO *= ALPHA;
#endif
#endif

    if (use_outline_mask) {
        float mask = texture(outline_mask, UV * outline_mask_uv_scale).a;
        if (mask < outline_mask_threshold) {
            discard;
        }
    }
}
