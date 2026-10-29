// liltoon_gd - 公共参数（P0 + P1 + P2 + P3）
// 注意：uniform 名称即材质序列化键，后续阶段只允许追加，不允许重命名。
// 每个 uniform 上方的文档注释会被插件注入 Inspector 悬停提示。

varying vec3 lil_tangent_view;
// light() 里没有 VERTEX，MatCap 透视缩放需要相机距离，用 varying 带给光照阶段。
varying float lil_view_depth;
// light() 里没有 UV2 / VIEW 内建变量，用 varying 传递，保证片元与光照阶段的采样一致。
varying vec2 lil_uv2;
varying vec3 lil_view;
varying vec3 lil_geo_normal;
varying float lil_facing;

/**
 * 主色与基础贴图。
 */
group_uniforms Main;
/**
 * 主色：材质的基础颜色，会与主色贴图相乘。
 */
uniform vec4 main_color : source_color = vec4(1.0, 0.95, 0.92, 1.0);
/**
 * 是否启用主色贴图；关闭时只使用主色。
 */
uniform bool use_main_texture = false;
/**
 * 主色贴图，与主色相乘后作为基础反照率。
 */
uniform sampler2D main_texture : source_color, filter_linear_mipmap, repeat_enable;
/**
 * UV 缩放倍数，影响主色、法线、遮罩等贴图的采样密度。
 */
uniform vec2 main_uv_scale = vec2(1.0, 1.0);
/**
 * 主贴图 UV 滚动速度（每秒，X/Y 分别），按小数部分循环，对应 liltoon 的 _MainTex_ScrollRotate.xy。
 */
uniform vec2 main_uv_scroll = vec2(0.0, 0.0);
/**
 * 主贴图 UV 旋转：X 为初始角度（弧度），Y 为角速度（弧度/秒），对应 liltoon 的 _MainTex_ScrollRotate.zw。
 */
uniform vec2 main_uv_rotate = vec2(0.0, 0.0);
/**
 * 主色 HSV/Gamma 校正：X 色相偏移（0.5 为半圈）、Y 饱和度、Z 明度、W Gamma；默认 (0,1,1,1) 不改变颜色。
 */
uniform vec4 main_hsvg = vec4(0.0, 1.0, 1.0, 1.0);
/**
 * 是否启用主色渐变贴图（1D LUT）。
 */
uniform bool use_main_gradation = false;
/**
 * 主色渐变贴图：横向为输入色、纵向无意义，RGB 三通道分别查表；建议按线性（关闭 sRGB）导入，对应 liltoon 的 _MainGradationTex。
 */
uniform sampler2D main_gradation_texture : hint_default_white, filter_linear, repeat_disable;
/**
 * 主色渐变强度：0 不生效，1 完全替换，对应 liltoon 的 _MainGradationStrength。
 */
uniform float main_gradation_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 是否使用主色调整遮罩。
 */
uniform bool use_main_color_adjust_mask = false;
/**
 * 主色调整遮罩：R 通道控制 HSV/渐变调整的生效比例，对应 liltoon 的 _MainColorAdjustMask。
 */
uniform sampler2D main_color_adjust_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 背面颜色：双面渲染时背面使用该颜色与反照率混合，对应 liltoon 的 _BackfaceColor。
 */
uniform vec4 backface_color : source_color = vec4(0.2, 0.18, 0.22, 0.0);
/**
 * 是否把背面 UV 水平偏移一格（+1,0），对应 liltoon 的 _ShiftBackfaceUV。
 */
uniform bool shift_backface_uv = false;
/**
 * Cutout 变体的 Alpha 裁剪阈值，低于该值的像素被丢弃。
 */
uniform float alpha_cutoff : hint_range(0.0, 1.0, 0.01) = 0.5;
/**
 * 透明变体的整体不透明度，1 为完全不透明。
 */
uniform float main_opacity : hint_range(0.0, 1.0, 0.01) = 1.0;
/**
 * 是否启用抖动透明（屏幕空间图案裁切），对应 liltoon 的 _UseDither。
 */
uniform bool use_dither = false;
/**
 * 抖动图案贴图：按屏幕像素取样 R 通道，建议导入为 4×4 或 8×8 的黑白点阵。
 */
uniform sampler2D dither_texture : hint_default_white, filter_nearest, repeat_enable;
/**
 * 抖动上限：255 为标准抖动（阈值约等于图案值），数值越小裁切越强，对应 liltoon 的 _DitherMaxValue。
 */
uniform float dither_max_value : hint_range(0.0, 255.0, 1.0) = 255.0;
/**
 * 是否把顶点色乘入主色（需要模型带有顶点色）。
 */
uniform bool use_vertex_color = false;
/**
 * 顶点色影响强度：0 忽略顶点色，1 完全相乘。
 */
uniform float vertex_color_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
/**
 * 是否使用三平面映射采样主色贴图，无需模型 UV。
 */
uniform bool use_triplanar = false;
/**
 * 三平面映射的世界空间缩放，越大纹理越密。
 */
uniform float triplanar_scale : hint_range(0.01, 10.0, 0.01) = 1.0;

/**
 * 视差。
 */
group_uniforms Parallax;
/**
 * 是否启用视差贴图，常用于眼睛等需要立体感的部位。
 */
uniform bool use_parallax = false;
/**
 * 视差高度图，取红通道作为高度值。
 */
uniform sampler2D parallax_texture : hint_default_black, filter_linear_mipmap, repeat_enable;
/**
 * 视差偏移强度，越大起伏越明显。
 */
uniform float parallax_height : hint_range(0.0, 0.2, 0.001) = 0.02;
/**
 * 视差高度图零点偏移：0.5 为灰度中点，对应 lilToon `_ParallaxOffset`（默认 0.5）。
 */
uniform float parallax_offset : hint_range(0.0, 1.0, 0.01) = 0.5;
/**
 * 第二贴层是否启用视差偏移。
 */
uniform bool use_parallax_2nd = false;
/**
 * 第二贴层高度图。
 */
uniform sampler2D parallax_2nd_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第二贴层视差深度。
 */
uniform float parallax_2nd_height : hint_range(0.0, 0.2, 0.001) = 0.02;
/**
 * 第三贴层是否启用视差偏移。
 */
uniform bool use_parallax_3rd = false;
/**
 * 第三贴层高度图。
 */
uniform sampler2D parallax_3rd_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第三贴层视差深度。
 */
uniform float parallax_3rd_height : hint_range(0.0, 0.2, 0.001) = 0.02;

/**
 * 明暗分层与阴影。
 */
group_uniforms Shade;
/**
 * 第一层阴影颜色，用于背光区域。
 */
uniform vec4 shade_color : source_color = vec4(0.55, 0.45, 0.52, 1.0);
/**
 * 是否启用阴影着色，对应 liltoon 的 _UseShadow；关闭后所有区域按受光处理。
 */
uniform bool use_shadow = true;
/**
 * 是否使用阴影色贴图，对应 liltoon 的 _ShadowColorTex 开关。
 */
uniform bool use_shade_color_texture = false;
/**
 * 阴影色贴图：与阴影色相乘，按主贴图 UV 采样。
 */
uniform sampler2D shade_color_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 阴影是否再与反照率相乘，0 关闭、1 完全相乘，对应 liltoon 的 _ShadowMainStrength。
 */
uniform float shadow_main_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 背面强制进入阴影的程度，0 关闭、1 全阴影，对应 liltoon 的 _BackfaceForceShadow。
 */
uniform float backface_force_shadow : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 明暗分界阈值（N·L），越大阴影范围越大。
 */
uniform float shade_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;
/**
 * 明暗分界柔和度，0 为硬边阶跃。
 */
uniform float shade_blur : hint_range(0.001, 0.5, 0.001) = 0.01;
/**
 * 阴影边界向暗部扩宽的量，对应 liltoon 的 _ShadowBorderRange。
 */
uniform float shade_border_range : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 阴影边界染色：在边界过渡带内把阴影色拉向受光色，对应 liltoon 的 _ShadowBorderColor。
 */
uniform vec4 shade_border_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
/**
 * 是否使用阴影强度遮罩，对应 liltoon 的 _ShadowStrengthMask。
 */
uniform bool use_shadow_strength_mask = false;
/**
 * 阴影强度遮罩：R 通道乘到阴影强度上。
 */
uniform sampler2D shadow_strength_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 阴影强度遮罩的采样 LOD，对应 liltoon 的 _ShadowStrengthMaskLOD；默认 0，越大越模糊。
 */
uniform float shadow_strength_mask_lod : hint_range(0.0, 5.0, 0.01) = 0.0;
/**
 * 是否使用阴影边界遮罩，对应 liltoon 的 _ShadowBorderMask。
 */
uniform bool use_shadow_border_mask = false;
/**
 * 阴影边界遮罩：RGB 分别乘到 1st/2nd/3rd 阴影边界，A 未使用。
 */
uniform sampler2D shadow_border_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 阴影边界遮罩的采样 LOD，对应 liltoon 的 _ShadowBorderMaskLOD；默认 0，越大越模糊。
 */
uniform float shadow_border_mask_lod : hint_range(0.0, 5.0, 0.01) = 0.0;
/**
 * 阴影柔化遮罩：RGB 分别乘到 1st/2nd/3rd 阴影柔化宽度，对应 liltoon 的 _ShadowBlurMask。
 */
uniform bool use_shadow_blur_mask = false;
/**
 * 阴影柔化遮罩贴图，R/G/B 对应 1st/2nd/3rd。
 */
uniform sampler2D shadow_blur_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 阴影柔化遮罩的采样 LOD，对应 liltoon 的 _ShadowBlurMaskLOD；默认 0，越大越模糊。
 */
uniform float shadow_blur_mask_lod : hint_range(0.0, 5.0, 0.01) = 0.0;
/**
 * 边界遮罩的 AO 偏移：X/Y 作用于 R，Z/W 作用于 G，对应 liltoon 的 _ShadowAOShift。
 */
uniform vec4 shadow_ao_shift = vec4(1.0, 0.0, 1.0, 0.0);
/**
 * 边界遮罩的 AO 偏移（B 通道），对应 liltoon 的 _ShadowAOShift2。
 */
uniform vec4 shadow_ao_shift_2 = vec4(1.0, 0.0, 1.0, 0.0);
/**
 * 阴影模式：强度遮罩或平面阴影，对应 liltoon 的 _ShadowMaskType。
 */
uniform int shadow_mask_type : hint_enum("强度遮罩", "平面阴影") = 0;
/**
 * 平面阴影的边界偏移，对应 liltoon 的 _ShadowFlatBorder。
 */
uniform float shadow_flat_border : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 平面阴影的柔化宽度，对应 liltoon 的 _ShadowFlatBlur。
 */
uniform float shadow_flat_blur : hint_range(0.01, 1.0, 0.01) = 1.0;
/**
 * 明暗边界抗锯齿强度：按屏幕空间导数把过渡带额外扩宽约一个像素，0 关闭、1 为默认；
 * 只作用于 toon 阶跃边缘，不改变阈值本身（对应 liltoon 的 _AAStrength）。
 */
uniform float aa_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
/**
 * 是否用一维渐变贴图重映射明暗阶跃。
 */
uniform bool use_shade_ramp = false;
/**
 * 无光照：直接把主色当作最终颜色，跳过所有实时光照。
 */
uniform bool use_unlit = false;
/**
 * 单色光照：用光色的亮度代替彩色，弱化环境色偏。
 */
uniform bool monochrome_lighting = false;
/**
 * 色阶 ramp，水平方向对应明暗强度。
 */
uniform sampler2D shade_ramp : hint_default_white, filter_linear, repeat_disable;
/**
 * ramp 与硬阶跃的混合强度，1 完全使用 ramp。
 */
uniform float shade_ramp_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
/**
 * 是否启用第二层阴影。
 */
uniform bool use_shade_2nd = false;
/**
 * 第二层阴影颜色，出现在比第一层更暗的区域。
 */
uniform vec4 shade_2nd_color : source_color = vec4(0.32, 0.22, 0.28, 1.0);
/**
 * 第二层阴影阈值，通常低于第一层阈值。
 */
uniform float shade_2nd_threshold : hint_range(-1.0, 1.0, 0.01) = 0.1;
/**
 * 是否启用第三层阴影。
 */
uniform bool use_shade_3rd = false;
/**
 * 第三层阴影颜色，用于最深的背光区域。
 */
uniform vec4 shade_3rd_color : source_color = vec4(0.18, 0.12, 0.16, 1.0);
/**
 * 第三层阴影阈值，通常为负值。
 */
uniform float shade_3rd_threshold : hint_range(-1.0, 1.0, 0.01) = -0.2;
/**
 * 第二层阴影的柔化宽度。
 */
uniform float shade_2nd_blur : hint_range(0.0, 0.5, 0.001) = 0.05;
/**
 * 第三层阴影的柔化宽度。
 */
uniform float shade_3rd_blur : hint_range(0.0, 0.5, 0.001) = 0.05;
/**
 * 明暗分界整体偏移，正值让画面更亮。
 */
uniform float shading_shift : hint_range(-1.0, 1.0, 0.01) = 0.0;
/**
 * 接收阴影强度：0 忽略阴影，1 完全接收。
 */
uniform float shadow_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
/**
 * 阴影区环境光强度，对应 liltoon 的 _ShadowEnvStrength；越大阴影里的环境光越接近反照率，默认 0 不改变行为。
 */
uniform float shadow_env_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 阴影遮罩应用顺序：关闭时遮罩在 toon 阶跃前作用（默认），开启后在阶跃后作用；
 * 对应 lilToon `_ShadowPostAO`（默认 0）。
 */
uniform bool shadow_post_ao = false;
/**
 * 阴影色类型：0 普通颜色，1 按反照率从 `shade_color_texture` 采样 LUT；
 * 对应 lilToon `_ShadowColorType`（默认 0）。
 */
uniform int shade_color_type : hint_enum("普通", "LUT") = 0;
/**
 * 是否接收投射阴影；关闭后所有光照按未受影处理。
 */
uniform float shadow_receive : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 阴影法线强度：0 抹平 N·L 差异，1 使用完整法线。
 */
uniform float shade_normal_strength : hint_range(0.0, 1.0, 0.001) = 1.0;
/**
 * 第二层阴影的法线强度：0 抹平该层的 N·L 差异。
 */
uniform float shade_2nd_normal_strength : hint_range(0.0, 1.0, 0.001) = 1.0;
/**
 * 第三层阴影的法线强度。
 */
uniform float shade_3rd_normal_strength : hint_range(0.0, 1.0, 0.001) = 1.0;

/**
 * 皮肤透射。
 */
group_uniforms SSS;
/**
 * 是否启用皮肤透射，使用背光透射近似模拟 SSS。
 */
uniform bool use_sss = false;
/**
 * 透射光颜色，皮肤通常偏红。
 */
uniform vec4 sss_color : source_color = vec4(1.0, 0.45, 0.38, 1.0);
/**
 * 次表面散射的强度，越大越透光（对应 liltoon 的 `_SubsurfaceScatteringStrength`）。
 */
uniform float sss_strength : hint_range(0.0, 2.0, 0.01) = 0.6;
/**
 * 透射衰减指数，越大透射越集中在背光边缘。
 */
uniform float sss_power : hint_range(0.5, 8.0, 0.1) = 2.5;
/**
 * SSS 厚度贴图：R 通道越亮表示越薄、透光越强。
 */
uniform sampler2D sss_thickness_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 厚度贴图对透射的影响强度：0 为忽略厚度。
 */
uniform float sss_thickness_strength : hint_range(0.0, 1.0, 0.001) = 0.0;

/**
 * 法线贴图。
 */
group_uniforms Normal;
/**
 * 是否启用第一法线贴图。
 */
uniform bool use_normal_map = false;
/**
 * 第一法线贴图，使用切线空间法线。
 */
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
/**
 * 第一法线强度，0 为平面，1 为原始强度。
 */
uniform float normal_strength : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * 是否启用第二法线贴图，与第一法线叠加。
 */
uniform bool use_normal_map_2nd = false;
/**
 * 第二法线贴图，使用切线空间法线。
 */
uniform sampler2D normal_texture_2nd : hint_normal, filter_linear_mipmap, repeat_enable;
/**
 * 第二法线强度。
 */
uniform float normal_strength_2nd : hint_range(0.0, 2.0, 0.01) = 1.0;

/**
 * 高光。
 */
group_uniforms Specular;
/**
 * 是否启用第一层 Toon 高光。
 */
uniform bool use_specular = true;
/**
 * 是否启用各向异性高光。
 */
uniform bool use_anisotropy = false;
/**
 * 各向异性切线偏移：沿法线方向偏移切线。
 */
uniform float anisotropy_shift : hint_range(-1.0, 1.0, 0.01) = 0.0;
/**
 * 各向异性高光收敛程度：0 最宽，1 最锐。
 */
uniform float anisotropy_scale : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 是否用切线贴图指定各向异性方向，对应 liltoon 的 _AnisotropyTangentMap。
 * 关闭时按几何法线现算切线；开启后切线方向由贴图提供，可画出沿 UV 走向的发丝高光。
 */
uniform bool use_anisotropy_tangent_map = false;
/**
 * 各向异性切线贴图：按主 UV 采样，按切线空间法线（XYZ 编码 0..1）解包后变换到表面。
 */
uniform sampler2D anisotropy_tangent_map : hint_normal, filter_linear_mipmap, repeat_enable;
/**
 * 是否用遮罩贴图控制各向异性缩放，对应 liltoon 的 _AnisotropyScaleMask。
 */
uniform bool use_anisotropy_scale_mask = false;
/**
 * 各向异性缩放遮罩：按主 UV 采样，R 通道乘到缩放上，便于按区域控制发丝高光宽度。
 */
uniform sampler2D anisotropy_scale_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 是否用各向异性法线替换第一槽 MatCap 的采样法线，对应 liltoon 的 _Anisotropy2MatCap。
 */
uniform bool anisotropy_2_matcap = false;
/**
 * 是否用各向异性法线替换第二槽 MatCap 的采样法线，对应 liltoon 的 _Anisotropy2MatCap2nd。
 */
uniform bool anisotropy_2_matcap_2nd = false;
/**
 * 各向异性高光强度。
 */
uniform float anisotropy_specular_strength : hint_range(0.0, 8.0, 0.01) = 1.0;
/**
 * 第二层各向异性高光开关。
 */
uniform bool use_anisotropy_2nd = false;
/**
 * 第二层各向异性切线偏移。
 */
uniform float anisotropy_2nd_shift : hint_range(-1.0, 1.0, 0.01) = 0.0;
/**
 * 第二层各向异性收敛程度。
 */
uniform float anisotropy_2nd_scale : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 第二层各向异性强度。
 */
uniform float anisotropy_2nd_specular_strength : hint_range(0.0, 8.0, 0.01) = 0.0;
/**
 * 第三层各向异性高光开关。
 */
uniform bool use_anisotropy_3rd = false;
/**
 * 第三层各向异性切线偏移。
 */
uniform float anisotropy_3rd_shift : hint_range(-1.0, 1.0, 0.01) = 0.0;
/**
 * 第三层各向异性收敛程度。
 */
uniform float anisotropy_3rd_scale : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 第三层各向异性强度。
 */
uniform float anisotropy_3rd_specular_strength : hint_range(0.0, 8.0, 0.01) = 1.0;
/**
 * 各向异性切线方向宽度。
 */
uniform float anisotropy_tangent_width : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * 各向异性副切线方向宽度。
 */
uniform float anisotropy_bitangent_width : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * 是否用噪声贴图扰动各向异性偏移。
 */
uniform bool use_anisotropy_shift_noise = false;
/**
 * 各向异性偏移噪声贴图。
 */
uniform sampler2D anisotropy_shift_noise_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 噪声对偏移的影响幅度。
 */
uniform float anisotropy_shift_noise_scale : hint_range(0.0, 1.0, 0.001) = 0.2;
/**
 * 第二层各向异性是否使用偏移噪声。
 */
uniform bool use_anisotropy_2nd_shift_noise = false;
/**
 * 第二层各向异性偏移噪声贴图。
 */
uniform sampler2D anisotropy_2nd_shift_noise_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第二层噪声幅度。
 */
uniform float anisotropy_2nd_shift_noise_scale : hint_range(0.0, 1.0, 0.001) = 0.2;
/**
 * 第三层各向异性是否使用偏移噪声。
 */
uniform bool use_anisotropy_3rd_shift_noise = false;
/**
 * 第三层各向异性偏移噪声贴图。
 */
uniform sampler2D anisotropy_3rd_shift_noise_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第三层噪声幅度。
 */
uniform float anisotropy_3rd_shift_noise_scale : hint_range(0.0, 1.0, 0.001) = 0.2;
/**
 * 第二层各向异性切线宽度。
 */
uniform float anisotropy_2nd_tangent_width : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * 第二层各向异性副切线宽度。
 */
uniform float anisotropy_2nd_bitangent_width : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * 第三层各向异性切线宽度。
 */
uniform float anisotropy_3rd_tangent_width : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * 第三层各向异性副切线宽度。
 */
uniform float anisotropy_3rd_bitangent_width : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * 是否启用 Glitter 闪点。
 */
uniform bool use_glitter = false;
/**
 * 闪点的基色，启用颜色贴图时会与之相乘。
 */
uniform vec4 glitter_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
/**
 * 闪点的整体强度，0 时完全看不到闪点。
 */
uniform float glitter_intensity : hint_range(0.0, 8.0, 0.01) = 1.0;
/**
 * 闪点密度：越大点越密。
 */
uniform float glitter_scale : hint_range(1.0, 200.0, 0.5) = 60.0;
/**
 * 闪点灵敏度：0 全部点亮，1 只有极少点。
 */
uniform float glitter_sensitivity : hint_range(0.0, 1.0, 0.001) = 0.25;
/**
 * 闪点对比度：越大边缘越硬。
 */
uniform float glitter_post_contrast : hint_range(0.1, 8.0, 0.01) = 1.0;
/**
 * 是否用形状贴图限制闪点。
 */
uniform bool use_glitter_shape = false;
/**
 * 闪点形状贴图，取 R 通道。
 */
uniform sampler2D glitter_shape_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 闪点形状图集：XY 为图集行列数，ZW 为偏移；对应 lilToon `_GlitterAtras`（默认 (1,1,0,0) 单格）。
 */
uniform vec4 glitter_shape_atlas = vec4(1.0, 1.0, 0.0, 0.0);
/**
 * 闪点随机缩放强度：0 为规则网格，1 为完全随机。
 */
uniform float glitter_scale_randomize : hint_range(0.0, 1.0, 0.001) = 0.0;
/**
 * Glitter 使用的 UV 通道：UV 或 UV2。
 */
uniform int glitter_uv_mode : hint_enum("UV", "UV2") = 0;
/**
 * 背面是否显示闪光，对应 liltoon 的 _GlitterBackfaceMask。
 */
uniform bool glitter_backface_mask = false;
/**
 * 闪点是否乘主体透明度，对应 liltoon 的 _GlitterApplyTransparency。
 */
uniform bool glitter_apply_transparency = false;
/**
 * 是否用颜色贴图给闪点染色，对应 liltoon 的 _GlitterColorTex。
 */
uniform bool use_glitter_color_tex = false;
/**
 * 闪点颜色贴图的 UV 通道：UV 或 UV2，对应 liltoon 的 _GlitterColorTex_UVMode。
 */
uniform int glitter_color_uv_mode : hint_enum("UV", "UV2") = 0;
/**
 * 闪点颜色贴图，按所选 UV 通道采样后乘到闪点颜色上。
 */
uniform sampler2D glitter_color_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 表面法线对闪点位置的扰动强度，对应 liltoon 的 _GlitterNormalStrength；0 时闪点只由 UV 决定。
 */
uniform float glitter_normal_strength : hint_range(0.0, 1.0, 0.001) = 1.0;
/**
 * 闪点朝向的随机化程度，对应 liltoon 的 _GlitterAngleRandomize；0 为不随机，1 为完全随机。
 */
uniform float glitter_angle_randomize : hint_range(0.0, 1.0, 0.001) = 0.0;
/**
 * 闪点受光照颜色的程度，对应 liltoon 的 _GlitterEnableLighting：0 为恒定亮度，1 为完全跟随光色。
 * 非 0 时闪点改由光照阶段输出，每个光源会重复计算一次。
 */
uniform float glitter_enable_lighting : hint_range(0.0, 1.0, 0.01) = 1.0;
/**
 * 闪点受阴影影响的程度，对应 liltoon 的 _GlitterShadowMask：0 为不受阴影，1 为阴影区完全淡出。
 */
uniform float glitter_shadow_mask : hint_range(0.0, 1.0, 0.01) = 0.0;

/**
 * 第一层高光颜色。
 */
uniform vec4 specular_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/**
 * 第一层高光强度。
 */
uniform float specular_intensity : hint_range(0.0, 4.0, 0.01) = 0.35;
/**
 * 第一层高光大小，越大高光范围越大。
 */
uniform float specular_size : hint_range(0.0, 1.0, 0.01) = 0.25;
/**
 * 第一层高光边缘柔度。
 */
uniform float specular_smoothness : hint_range(0.0, 0.5, 0.001) = 0.01;
/**
 * 高光 toon 化：开启后高光按边界/柔边阶跃，关闭则为平滑高光；
 * 对应 lilToon `_SpecularToon`（默认 1）。
 */
uniform bool specular_toon = true;
/**
 * 高光 toon 边界位置：0..1，越大高光越小；对应 lilToon `_SpecularBorder`（默认 0.5）。
 */
uniform float specular_border : hint_range(0.0, 1.0, 0.01) = 0.5;
/**
 * 高光 toon 柔边宽度：0 为硬阶跃；对应 lilToon `_SpecularBlur`（默认 0）。
 */
uniform float specular_blur : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 高光受法线贴图影响的程度（对齐 liltoon 的 _SpecularNormalStrength）。
 * 0 = 高光只按几何法线计算，法线贴图不改变高光位置；
 * 1 = 高光完全跟随法线贴图。默认 1，与 liltoon 默认值一致。
 */
uniform float specular_normal_strength : hint_range(0.0, 1.0, 0.001) = 1.0;
/**
 * 是否启用第二层高光。
 */
uniform bool use_specular_2nd = false;
/**
 * 第二层高光颜色。
 */
uniform vec4 specular_2nd_color : source_color = vec4(1.0, 0.82, 0.9, 1.0);
/**
 * 第二层高光强度。
 */
uniform float specular_2nd_intensity : hint_range(0.0, 4.0, 0.01) = 0.5;
/**
 * 第二层高光大小。
 */
uniform float specular_2nd_size : hint_range(0.0, 1.0, 0.01) = 0.15;
/**
 * 第二层高光边缘柔度。
 */
uniform float specular_2nd_smoothness : hint_range(0.0, 0.5, 0.001) = 0.01;
/**
 * 是否启用第三层各向异性高光，适合头发。
 */
uniform bool use_specular_3rd = false;
/**
 * 第三层高光颜色。
 */
uniform vec4 specular_3rd_color : source_color = vec4(0.85, 0.9, 1.0, 1.0);
/**
 * 第三层高光强度。
 */
uniform float specular_3rd_intensity : hint_range(0.0, 4.0, 0.01) = 1.0;
/**
 * 发丝高光宽度，越大高光越宽。
 */
uniform float specular_3rd_size : hint_range(0.0, 1.0, 0.01) = 0.35;
/**
 * 沿切线方向偏移高光位置。
 */
uniform float specular_3rd_shift : hint_range(-1.0, 1.0, 0.01) = 0.0;

/**
 * 边缘光。
 */
group_uniforms Rim;
/**
 * 是否启用边缘光。
 */
uniform bool use_rim = false;
/**
 * 边缘光颜色。
 */
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.9, 1.0);
/**
 * 边缘光强度。
 */
uniform float rim_intensity : hint_range(0.0, 4.0, 0.01) = 0.8;
/**
 * 边缘衰减指数，越大越集中在轮廓边缘。
 */
uniform float rim_power : hint_range(1.0, 16.0, 0.1) = 4.0;
/**
 * 是否启用第二边缘色。
 */
uniform bool use_rim_2nd = false;
/**
 * 更靠边缘处混入的第二颜色。
 */
uniform vec4 rim_2nd_color : source_color = vec4(0.6, 0.72, 1.0, 1.0);
/**
 * 是否使用遮罩限制边缘光。
 */
uniform bool use_rim_mask = false;
/**
 * 边缘光遮罩贴图，取红通道。
 */
uniform sampler2D rim_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 边缘光遮罩的 UV 缩放。
 */
uniform vec2 rim_mask_uv_scale = vec2(1.0, 1.0);
/**
 * 边缘光遮罩阈值，低于该值不显示。
 */
uniform float rim_mask_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;
/**
 * 边缘光边界：Fresnel 值超过该阈值才显示，对应 liltoon 的 _RimBorder。
 */
uniform float rim_border : hint_range(0.0, 1.0, 0.01) = 0.5;
/**
 * 边缘光边界柔化宽度，对应 liltoon 的 _RimBlur；0 为硬边。
 */
uniform float rim_blur : hint_range(0.0, 0.5, 0.001) = 0.65;
/**
 * 方向性强度：0 为纯 Fresnel 边缘光，1 为按光源方向区分受光/背光，对应 liltoon 的 _RimDirStrength。
 */
uniform float rim_dir_strength : hint_range(0.0, 1.0, 0.001) = 0.0;
/**
 * 受光侧偏移，对应 liltoon 的 _RimDirRange。
 */
uniform float rim_dir_range : hint_range(-1.0, 1.0, 0.01) = 0.0;
/**
 * 背光侧偏移，对应 liltoon 的 _RimIndirRange。
 */
uniform float rim_indir_range : hint_range(-1.0, 1.0, 0.01) = 0.0;
/**
 * 背光侧边界，对应 liltoon 的 _RimIndirBorder。
 */
uniform float rim_indir_border : hint_range(0.0, 1.0, 0.01) = 0.5;
/**
 * 背光侧柔化宽度，对应 liltoon 的 _RimIndirBlur。
 */
uniform float rim_indir_blur : hint_range(0.0, 0.5, 0.001) = 0.1;
/**
 * 边缘光是否随光源颜色调制，对应 liltoon 的 _RimEnableLighting。
 */
uniform float rim_enable_lighting : hint_range(0.0, 1.0, 0.01) = 1.0;
/**
 * 背面是否也绘制边缘光；关闭后背面不显示，对应 liltoon 的 _RimBackfaceMask。
 */
uniform bool rim_backface_mask = false;
/**
 * 是否使用边缘光颜色贴图。
 */
uniform bool use_rim_color_tex = false;
/**
 * 边缘光颜色贴图：与边缘光颜色相乘，按主贴图 UV 采样。
 */
uniform sampler2D rim_color_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 边缘光用法线强度：0 用几何法线、1 用法线贴图后的法线，对应 liltoon 的 _RimNormalStrength。
 */
uniform float rim_normal_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
/**
 * 是否启用边缘阴影（把轮廓边缘压暗），对应 liltoon 的 _UseRimShade。
 */
uniform bool use_rim_shade = false;
/**
 * 边缘阴影颜色：RGB 为压暗后的染色，A 为强度，对应 liltoon 的 _RimShadeColor。
 */
uniform vec4 rim_shade_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
/**
 * 边缘阴影边界，对应 liltoon 的 _RimShadeBorder。
 */
uniform float rim_shade_border : hint_range(0.0, 1.0, 0.01) = 0.5;
/**
 * 边缘阴影柔化宽度，对应 liltoon 的 _RimShadeBlur。
 */
uniform float rim_shade_blur : hint_range(0.0, 0.5, 0.001) = 1.0;
/**
 * 边缘阴影的 Fresnel 指数，对应 liltoon 的 _RimShadeFresnelPower。
 */
uniform float rim_shade_fresnel_power : hint_range(1.0, 16.0, 0.1) = 1.0;
/**
 * 边缘阴影用法线强度：0 用几何法线、1 用法线贴图后的法线，对应 liltoon 的 _RimShadeNormalStrength。
 */
uniform float rim_shade_normal_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
/**
 * 是否启用逆光（背光透射边缘），对应 liltoon 的 _UseBacklight。
 */
uniform bool use_backlight = false;
/**
 * 逆光颜色：RGB 为光色，A 为强度，对应 liltoon 的 _BacklightColor。
 */
uniform vec4 backlight_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);
/**
 * 是否使用逆光颜色贴图。
 */
uniform bool use_backlight_color_tex = false;
/**
 * 逆光颜色贴图，按主贴图 UV 采样，对应 liltoon 的 _BacklightColorTex。
 */
uniform sampler2D backlight_color_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 逆光用法线强度：0 用几何法线、1 用法线贴图后的法线，对应 liltoon 的 _BacklightNormalStrength。
 */
uniform float backlight_normal_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
/**
 * 逆光方向性指数：越大越集中在正对光源的方向，对应 liltoon 的 _BacklightDirectivity。
 */
uniform float backlight_directivity : hint_range(0.0, 10.0, 0.01) = 5.0;
/**
 * 视角对逆光的影响强度，对应 liltoon 的 _BacklightViewStrength。
 */
uniform float backlight_view_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
/**
 * 逆光边界，对应 liltoon 的 _BacklightBorder。
 */
uniform float backlight_border : hint_range(0.0, 1.0, 0.01) = 0.35;
/**
 * 逆光柔化宽度，对应 liltoon 的 _BacklightBlur。
 */
uniform float backlight_blur : hint_range(0.0, 0.5, 0.001) = 0.05;
/**
 * 主色混合：0 保持逆光色，1 与反照率相乘，对应 liltoon 的 _BacklightMainStrength。
 */
uniform float backlight_main_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 背面是否也绘制逆光，对应 liltoon 的 _BacklightBackfaceMask。
 */
uniform bool backlight_backface_mask = false;
/**
 * 逆光是否受阴影衰减，对应 liltoon 的 _BacklightReceiveShadow。
 */
uniform bool backlight_receive_shadow = true;
/**
 * 是否使用边缘阴影遮罩。
 */
uniform bool use_rim_shade_mask = false;
/**
 * 边缘阴影遮罩：R 通道控制生效比例，对应 liltoon 的 _RimShadeMask。
 */
uniform sampler2D rim_shade_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 主色混合：0 保持边缘色，1 与反照率相乘，对应 liltoon 的 _RimMainStrength。
 */
uniform float rim_main_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 内侧间接光颜色：靠近正面的边缘会混入该颜色。
 */
uniform vec4 rim_indir_color : source_color = vec4(0.4, 0.45, 0.6, 1.0);
/**
 * 内侧间接光强度：0 关闭。
 */
uniform float rim_indir_strength : hint_range(0.0, 1.0, 0.001) = 0.0;
/**
 * 边缘光乘以阴影：开启后阴影区的边缘光被压暗，对应 liltoon 的 _RimShadowMask。
 */
 uniform float rim_shadow_mask : hint_range(0.0, 1.0, 0.01) = 0.5;
/**
 * 边缘光按透明度预乘。
 */
uniform bool rim_apply_transparency = false;

/**
 * MatCap。
 */
group_uniforms MatCap;
/**
 * 是否启用第一槽 MatCap。
 */
uniform bool use_matcap = false;
/**
 * MatCap 是否乘主体透明度，对应 liltoon 的 _MatCapApplyTransparency；开启后透明材质的 MatCap 随透明度淡出。
 */
uniform bool matcap_apply_transparency = false;
/**
 * 第一槽 MatCap 贴图，使用视空间法线采样。
 */
uniform sampler2D matcap_texture : source_color, hint_default_white, filter_linear_mipmap;
/**
 * 第一槽 MatCap 颜色。
 */
uniform vec4 matcap_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/**
 * 第一槽 MatCap 强度。
 */
uniform float matcap_intensity : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * MatCap 的贴图 LOD：越大越模糊。
 */
uniform float matcap_lod : hint_range(0.0, 5.0, 0.01) = 0.0;
/**
 * 第一槽 MatCap 球面 UV 与 UV1 平面 UV 的混合比例，对应 liltoon 的 _MatCapBlendUV1。
 * 0 为球面采样；1 为直接把 UV1 当 MatCap 坐标，适合把 MatCap 贴图直接画在 UV 布局上的情况。
 */
uniform float matcap_blend_uv1 : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * MatCap 受光照颜色的程度，对应 liltoon 的 _MatCapEnableLighting：0 为恒定亮度，1 为完全跟随光色。
 * 非 0 时 MatCap 改由光照阶段输出，每个光源会重复采样一次贴图。
 */
uniform float matcap_enable_lighting : hint_range(0.0, 1.0, 0.01) = 1.0;
/**
 * MatCap 受阴影影响的程度，对应 liltoon 的 _MatCapShadowMask：0 为不受阴影，1 为阴影区完全淡出。
 * 与受光开关一样，非 0 时改由光照阶段输出。
 */
uniform float matcap_shadow_mask : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * MatCap 的法线强度：0 用几何法线，1 用法线贴图后的法线。
 */
uniform float matcap_normal_strength : hint_range(0.0, 1.0, 0.001) = 1.0;
/**
 * 是否使用 MatCap 法线贴图，对应 liltoon 的 _MatCapBumpMap 开关。
 */
uniform bool use_matcap_bump_map = false;
/**
 * MatCap 法线贴图的用法，对应 liltoon 的 _MatCapCustomNormal：
 * 关闭时贴图作为扰动叠加到当前法线；开启时贴图被当作完整的 MatCap 法线（经切线空间变换）。
 */
uniform bool matcap_custom_normal = false;
/**
 * MatCap 法线贴图，按主 UV 采样后扰动 MatCap 球面法线。
 */
uniform sampler2D matcap_bump_map : hint_normal, filter_linear_mipmap, repeat_enable;
/**
 * MatCap 法线强度，对应 liltoon 的 _MatCapBumpScale。
 */
uniform float matcap_bump_scale : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * 第二 MatCap 槽位的法线强度。
 */
uniform float matcap_2nd_normal_strength : hint_range(0.0, 1.0, 0.001) = 1.0;
/**
 * 第二槽 MatCap 的球面 UV 与 UV1 混合比例，对应 liltoon 的 _MatCap2ndBlendUV1。
 */
uniform float matcap_2nd_blend_uv1 : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 第三 MatCap 槽位的法线强度。
 */
uniform float matcap_3rd_normal_strength : hint_range(0.0, 1.0, 0.001) = 1.0;
/**
 * 第二 MatCap 槽位的贴图 LOD。
 */
uniform float matcap_2nd_lod : hint_range(0.0, 5.0, 0.01) = 0.0;
/**
 * 第三 MatCap 槽位的贴图 LOD。
 */
uniform float matcap_3rd_lod : hint_range(0.0, 5.0, 0.01) = 0.0;
/**
 * 第二 MatCap 槽位是否使用法线贴图。
 */
uniform bool use_matcap_2nd_bump = false;
/**
 * 第二 MatCap 槽位法线贴图（切线空间）。
 */
uniform sampler2D matcap_2nd_bump_map : hint_normal, filter_linear_mipmap, repeat_enable;
/**
 * 第二 MatCap 槽位法线强度。
 */
uniform float matcap_2nd_bump_scale : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * 第三 MatCap 槽位是否使用法线贴图。
 */
uniform bool use_matcap_3rd_bump = false;
/**
 * 第三 MatCap 槽位法线贴图（切线空间）。
 */
uniform sampler2D matcap_3rd_bump_map : hint_normal, filter_linear_mipmap, repeat_enable;
/**
 * 第三 MatCap 槽位法线强度。
 */
uniform float matcap_3rd_bump_scale : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * 第二 MatCap 槽位是否按透明度预乘。
 */
/**
 * 第二槽 MatCap 是否把法线贴图当作完整法线，对应 liltoon 的 _MatCap2ndCustomNormal。
 */
uniform bool matcap_2nd_custom_normal = false;
/**
 * 第二槽 MatCap 受光照颜色的程度，对应 liltoon 的 _MatCap2ndEnableLighting；
 * 非 0 时改由光照阶段输出，每个光源会重复采样一次贴图。
 */
uniform float matcap_2nd_enable_lighting : hint_range(0.0, 1.0, 0.01) = 1.0;
/**
 * 第二槽 MatCap 受阴影影响的程度，对应 liltoon 的 _MatCap2ndShadowMask。
 */
uniform float matcap_2nd_shadow_mask : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 第二槽 MatCap 是否乘主体透明度，对应 liltoon 的 _MatCap2ndApplyTransparency。
 */
uniform bool matcap_2nd_apply_transparency = false;
/**
 * 第三 MatCap 槽位是否按透明度预乘。
 */
uniform bool matcap_3rd_apply_transparency = false;
/**
 * 第二 MatCap 槽位是否在背面隐藏。
 */
uniform bool matcap_2nd_backface_mask = false;
/**
 * 第三 MatCap 槽位是否在背面隐藏。
 */
uniform bool matcap_3rd_backface_mask = false;
/**
 * 第一 MatCap 槽位是否启用透视缩放。
 */
uniform bool matcap_perspective = false;
/**
 * MatCap 抵消相机滚转：开启后相机旋转时 MatCap 保持竖直；
 * 对应 lilToon `_MatCapZRotCancel`（默认 1）。
 */
uniform bool matcap_zrot_cancel = true;
/**
 * 第二槽 MatCap 抵消相机滚转；对应 lilToon `_MatCap2ndZRotCancel`（默认 1）。
 */
uniform bool matcap_2nd_zrot_cancel = true;
/**
 * 第三槽 MatCap 抵消相机滚转（本项目扩展槽位，与主槽语义一致）。
 */
uniform bool matcap_3rd_zrot_cancel = true;
/**
 * 背面是否显示 MatCap，对应 liltoon 的 _MatCapBackfaceMask。
 */
uniform bool matcap_backface_mask = false;
/**
 * 第二 MatCap 槽位是否启用透视缩放。
 */
uniform bool matcap_2nd_perspective = false;
/**
 * 第三 MatCap 槽位是否启用透视缩放。
 */
uniform bool matcap_3rd_perspective = false;
/**
 * 第二贴层随相机距离淡出的强度。
 */
uniform float decal_2nd_distance_fade : hint_range(0.0, 1.0, 0.001) = 0.0;
/**
 * 第三贴层随相机距离淡出的强度。
 */
uniform float decal_3rd_distance_fade : hint_range(0.0, 1.0, 0.001) = 0.0;
/**
 * 第二贴层 Alpha 模式：0 直通，1 预乘。
 */
uniform int decal_2nd_alpha_mode : hint_enum("直通", "预乘") = 0;
/**
 * 第三贴层 Alpha 模式：0 直通，1 预乘。
 */
uniform int decal_3rd_alpha_mode : hint_enum("直通", "预乘") = 0;
/**
 * 第二贴层剔除：0 双面，1 背面剔除，2 正面剔除。
 */
uniform int decal_2nd_cull_mode : hint_enum("双面", "背面剔除", "正面剔除") = 0;
/**
 * 第三贴层剔除。
 */
uniform int decal_3rd_cull_mode : hint_enum("双面", "背面剔除", "正面剔除") = 0;
/**
 * 第二层自发光是否启用视差。
 */
uniform bool use_emission_2nd_parallax = false;
/**
 * 第二层自发光视差高度图。
 */
uniform sampler2D emission_2nd_parallax_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第二层自发光视差深度。
 */
uniform float emission_2nd_parallax_depth : hint_range(0.0, 0.2, 0.001) = 0.0;
/**
 * 第二贴层溶解位置偏移：用于让该层比主体晚/早消失。
 */
uniform vec2 decal_2nd_dissolve_offset = vec2(0.0, 0.0);
/**
 * 第三贴层溶解位置偏移。
 */
uniform vec2 decal_3rd_dissolve_offset = vec2(0.0, 0.0);
/**
 * 是否使用 Alpha 遮罩。
 */
uniform bool use_alpha_mask = false;
/**
 * Alpha 遮罩贴图，取 R 通道。
 */
uniform sampler2D alpha_mask_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 遮罩缩放：与贴图采样值相乘。
 */
uniform float alpha_mask_scale : hint_range(0.0, 4.0, 0.01) = 1.0;
/**
 * 遮罩偏移：加在缩放后的值上。
 */
uniform float alpha_mask_value : hint_range(-1.0, 1.0, 0.01) = 0.0;
/**
 * 遮罩对最终 Alpha 的影响强度。
 */
uniform float alpha_mask_strength : hint_range(0.0, 1.0, 0.001) = 1.0;
/**
 * 翻转法线：用于内表面或特殊光照。
 */
uniform bool flip_normal = false;
/**
 * 第二 MatCap 槽位是否使用独立遮罩。
 */
uniform bool use_matcap_2nd_mask = false;
/**
 * 第二 MatCap 槽位遮罩，取 R 通道。
 */
uniform sampler2D matcap_2nd_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第三 MatCap 槽位是否使用独立遮罩。
 */
uniform bool use_matcap_3rd_mask = false;
/**
 * 第三 MatCap 槽位遮罩，取 R 通道。
 */
uniform sampler2D matcap_3rd_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * MatCap 总强度倍率。
 */
uniform float matcap_main_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 第一槽 MatCap 混合方式：开启为乘算到主色，关闭为叠加发光。
 */
uniform bool matcap_multiply = false;
/**
 * 是否启用第二槽 MatCap。
 */
uniform bool use_matcap_2nd = false;
/**
 * 第二槽 MatCap 贴图。
 */
uniform sampler2D matcap_texture_2nd : source_color, hint_default_white, filter_linear_mipmap;
/**
 * 第二槽 MatCap 颜色。
 */
uniform vec4 matcap_2nd_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/**
 * 第二槽 MatCap 强度。
 */
uniform float matcap_2nd_intensity : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * 第二槽 MatCap 混合方式：开启为乘算到主色，关闭为叠加发光。
 */
uniform bool matcap_2nd_multiply = false;
/**
 * 是否启用第三槽 MatCap。
 */
uniform bool use_matcap_3rd = false;
/**
 * 第三槽 MatCap 贴图。
 */
uniform sampler2D matcap_texture_3rd : source_color, hint_default_white, filter_linear_mipmap;
/**
 * 第三槽 MatCap 颜色。
 */
uniform vec4 matcap_3rd_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/**
 * 第三槽 MatCap 强度。
 */
uniform float matcap_3rd_intensity : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * 第三槽 MatCap 混合方式：开启为乘算到主色，关闭为叠加发光。
 */
uniform bool matcap_3rd_multiply = false;
/**
 * 是否用遮罩限制所有 MatCap 槽位。
 */
uniform bool use_matcap_mask = false;
/**
 * MatCap 遮罩贴图，取红通道。
 */
uniform sampler2D matcap_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * MatCap 遮罩的 UV 缩放。
 */
uniform vec2 matcap_mask_uv_scale = vec2(1.0, 1.0);
/**
 * MatCap 遮罩阈值，低于该值不显示。
 */
uniform float matcap_mask_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;

/**
 * 自发光。
 */
group_uniforms Emission;
/**
 * 自发光颜色。
 */
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
/**
 * 是否启用主自发光，对应 liltoon 的 _UseEmission。
 */
uniform bool use_emission = false;
/**
 * 主自发光贴图的 UV 模式：0 使用 UV，1 使用 UV2，对应 liltoon 的 _EmissionMap_UVMode。
 */
uniform int emission_uv_mode : hint_enum("UV", "UV2") = 0;
/**
 * 主自发光 UV 滚动速度，对应 _EmissionMap_ScrollRotate.xy。
 */
uniform vec2 emission_uv_scroll = vec2(0.0, 0.0);
/**
 * 主自发光 UV 旋转：X 初始角度、Y 角速度（弧度/秒）。
 */
uniform vec2 emission_uv_rotate = vec2(0.0, 0.0);
/**
 * 是否启用主自发光渐变贴图，对应 liltoon 的 _EmissionUseGrad。
 */
uniform bool use_emission_grad = false;
/**
 * 主自发光渐变贴图，对应 liltoon 的 _EmissionGradTex。
 */
uniform sampler2D emission_grad_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 主自发光渐变速度，对应 liltoon 的 _EmissionGradSpeed。
 */
uniform float emission_grad_speed : hint_range(0.0, 5.0, 0.01) = 1.0;
/**
 * 是否启用主自发光视差，对应 liltoon 的 _EmissionParallaxDepth 开关。
 */
uniform bool use_emission_parallax = false;
/**
 * 主自发光视差高度图。
 */
uniform sampler2D emission_parallax_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 主自发光视差深度，对应 liltoon 的 _EmissionParallaxDepth。
 */
uniform float emission_parallax_depth : hint_range(0.0, 0.2, 0.001) = 0.0;
/**
 * 主自发光荧光强度，对应 liltoon 的 _EmissionFluorescence。
 */
uniform float emission_fluorescence : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 主自发光混合强度，对应 liltoon 的 _EmissionBlend。
 */
uniform float emission_blend : hint_range(0.0, 1.0, 0.01) = 1.0;
/**
 * 主自发光与反照率相乘的比例，对应 liltoon 的 _EmissionMainStrength。
 */
uniform float emission_main_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 是否使用主自发光混合遮罩，对应 liltoon 的 _EmissionBlendMask。
 */
uniform bool use_emission_mask = false;
/**
 * 主自发光混合遮罩：RGBA 乘到自发光上。
 */
uniform sampler2D emission_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 主自发光遮罩的 UV 滚动速度，对应 _EmissionBlendMask_ScrollRotate.xy。
 */
uniform vec2 emission_mask_uv_scroll = vec2(0.0, 0.0);
/**
 * 主自发光遮罩的 UV 旋转：X 初始角度、Y 角速度（弧度/秒）。
 */
uniform vec2 emission_mask_uv_rotate = vec2(0.0, 0.0);
/**
 * 主自发光混合模式：加法或正片叠底，对应 liltoon 的 _EmissionBlendMode。
 */
uniform int emission_blend_mode : hint_enum("加法", "正片叠底") = 0;
/**
 * 是否启用自发光贴图。
 */
uniform bool use_emission_texture = false;
/**
 * 自发光贴图，与自发光颜色相乘。
 */
uniform sampler2D emission_texture : source_color, filter_linear_mipmap, repeat_enable;
/**
 * 自发光强度。
 */
uniform float emission_intensity : hint_range(0.0, 8.0, 0.01) = 1.0;
/**
 * 自发光闪烁速度（次/秒），0 为不闪。
 */
uniform float emission_blink_speed : hint_range(0.0, 10.0, 0.01) = 0.0;
/**
 * 自发光闪烁幅度：0 为不闪，1 为完全明暗交替。
 */
uniform float emission_blink_strength : hint_range(0.0, 1.0, 0.001) = 0.0;
/**
 * 是否启用第二层自发光贴图。
 */
uniform bool use_emission_2nd = false;
/**
 * 第二层自发光贴图。
 */
uniform sampler2D emission_2nd_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第二层自发光颜色，会与贴图相乘。
 */
uniform vec4 emission_2nd_color : source_color = vec4(0.5, 0.8, 1.0, 1.0);
/**
 * 第二层自发光强度。
 */
uniform float emission_2nd_intensity : hint_range(0.0, 8.0, 0.01) = 1.0;
/**
 * 第二层自发光荧光强度（0–1）：0 为普通自发光，1 时自发光随受光变暗而增强、受光充足处被压暗；
 * 衰减系数对齐 liltoon 的 (1 - 光色) × sqrt(光色)，仅加法混合模式生效。
 */
uniform float emission_2nd_fluorescence : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 第二层自发光的 UV 缩放。
 */
uniform vec2 emission_2nd_uv_scale = vec2(1.0, 1.0);
/**
 * 第二层自发光的 UV 通道：UV 或 UV2。
 */
uniform int emission_2nd_uv_mode : hint_enum("UV", "UV2") = 0;
/**
 * 第二层自发光的 UV 滚动（每秒）。
 */
uniform vec2 emission_2nd_uv_scroll = vec2(0.0, 0.0);
/**
 * 第二层自发光是否使用渐变贴图。
 */
uniform bool use_emission_2nd_grad = false;
/**
 * 第二层自发光渐变贴图，水平方向采样。
 */
uniform sampler2D emission_2nd_grad_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 渐变滚动速度（循环/秒）。
 */
uniform float emission_2nd_grad_speed : hint_range(0.0, 5.0, 0.01) = 1.0;
/**
 * 第二层自发光混合方式：加法或正片叠底。
 */
uniform int emission_2nd_blend_mode : hint_enum("加法", "正片叠底") = 0;
/**
 * 是否用遮罩限制第二层自发光的显示范围。
 */
uniform bool use_emission_2nd_mask = false;
/**
 * 第二层自发光遮罩，取 R 通道。
 */
uniform sampler2D emission_2nd_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第二层自发光遮罩的 UV 滚动速度，对应 liltoon 的 _Emission2ndBlendMask_ScrollRotate.xy。
 */
uniform vec2 emission_2nd_mask_uv_scroll = vec2(0.0, 0.0);
/**
 * 第二层自发光遮罩的 UV 旋转：X 初始角度、Y 角速度（弧度/秒）。
 */
uniform vec2 emission_2nd_mask_uv_rotate = vec2(0.0, 0.0);

/**
 * 环境光遮蔽。
 */
group_uniforms AO;
/**
 * 是否使用 AO 贴图。
 */
uniform bool use_ao_map = false;
/**
 * AO 贴图，取红通道作为遮蔽值。
 */
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * AO 强度。
 */
uniform float ao_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
/**
 * AO 对直接光的影响程度，0 只影响环境光。
 */
uniform float ao_light_affect : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 是否使用顶点色红通道作为 AO。
 */
uniform bool use_vertex_color_ao = false;

/**
 * 附加环境光。
 */
group_uniforms Ambient;
/**
 * 额外环境光颜色，用于补充引擎环境光。
 */
uniform vec4 ambient_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
/**
 * 额外环境光强度，0 为关闭。
 */
uniform float ambient_strength : hint_range(0.0, 2.0, 0.01) = 0.0;

/**
 * 金属反射。
 */
group_uniforms Reflection;
/**
 * 是否写入金属度/粗糙度以启用环境反射。
 */
uniform bool use_reflection = false;
/**
 * 金属度，0 为绝缘体，1 为纯金属。
 */
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0.0;
/**
 * 粗糙度，越小反射越锐利。
 */
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.5;
/**
 * 反射率（F0）：非金属表面的基础反射强度，对应 liltoon 的 _Reflectance；0.5 为默认，1 为最强。
 */
uniform float reflectance : hint_range(0.0, 1.0, 0.01) = 0.5;
/**
 * 几何抗锯齿强度：按法线屏幕导数抬高粗糙度，柔化反射边缘，对应 liltoon 的 _GSAAStrength。
 */
uniform float gsaa_strength : hint_range(0.0, 1.0, 0.01) = 0.5;
/**
 * 是否启用金属度/光滑度贴图：R 通道为金属度、A 通道为光滑度，对应 liltoon 的 _MetallicGlossMap。
 */
uniform bool use_metallic_gloss_map = false;
/**
 * 金属度/光滑度贴图（R=金属度，A=光滑度），按主贴图 UV 采样。
 */
uniform sampler2D metallic_gloss_map : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 是否启用光滑度贴图：R 通道乘到光滑度上，对应 liltoon 的 _SmoothnessTex。
 */
uniform bool use_smoothness_texture = false;
/**
 * 光滑度贴图，按主贴图 UV 采样，R 通道生效。
 */
uniform sampler2D smoothness_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 反射是否乘 Alpha：透明材质上让环境反射随透明度淡出，对应 liltoon 的 _ReflectionApplyTransparency。
 */
uniform bool reflection_apply_transparency = false;
/**
 * 是否启用反射染色贴图，对应 liltoon 的 _ReflectionColorTex。
 * 近似说明：Godot 的 SPECULAR（F0）是标量，只能按贴图亮度缩放反射强度，无法像原版那样按 RGB 染色。
 */
uniform bool use_reflection_color_tex = false;
/**
 * 反射染色贴图，按主贴图 UV 采样，取亮度（Rec.601）乘到反射率上；白色表示不改变。
 */
uniform sampler2D reflection_color_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 是否用自定义立方体贴图覆盖环境反射；对应 lilToon `_ReflectionCubeOverride`（默认 0）。
 */
uniform bool use_reflection_cubemap = false;
/**
 * 自定义反射立方体贴图，按世界空间反射向量采样；对应 lilToon `_ReflectionCubeTex`。
 */
uniform samplerCube reflection_cubemap : hint_default_black;
/**
 * 自定义反射立方体贴图的颜色乘子；对应 lilToon `_ReflectionCubeColor`（默认黑色=不生效）。
 */
uniform vec4 reflection_cubemap_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
/**
 * 自定义反射立方体贴图的受光程度，1 跟随光照色；对应 lilToon `_ReflectionCubeEnableLighting`（默认 1）。
 */
uniform float reflection_cubemap_lighting : hint_range(0.0, 1.0, 0.01) = 1.0;

/**
 * 阴影与深度。
 */
group_uniforms Shadow;
/**
 * 是否投射阴影；关闭后在阴影 pass 中丢弃该材质。
 */
uniform bool cast_shadow = true;
/**
 * 深度偏移，用于微调深度冲突。
 */
uniform float depth_offset : hint_range(-0.1, 0.1, 0.0001) = 0.0;

/**
 * 亮度限制。
 */
group_uniforms LightLimit;
/**
 * 最小亮度限制：着色结果不会低于该比例，避免暗部完全变黑；默认 0.05。
 */
uniform float light_min_limit : hint_range(0.0, 1.0, 0.001) = 0.05;
/**
 * 最大亮度限制：着色结果不会高于该比例，避免多光源叠加过曝；默认 1.0。
 */
uniform float light_max_limit : hint_range(0.0, 10.0, 0.01) = 1.0;

/**
 * 溶解：让表面按噪声或遮罩逐渐消失，并在边界产生发光带。
 */
group_uniforms Dissolve;
/**
 * 是否启用溶解；关闭时不产生任何额外采样与裁切。
 */
uniform bool use_dissolve = false;
/**
 * 噪声贴图：R 通道用于扰动裁切边界，让消失边缘呈不规则形状；默认中灰。
 */
uniform sampler2D dissolve_noise_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 噪声扰动强度：0 为完全平滑的边界，越大边缘越破碎；默认 0.1。
 */
uniform float dissolve_noise_strength : hint_range(0.0, 1.0, 0.001) = 0.1;
/**
 * 噪声贴图的 UV 缩放。
 */
uniform vec2 dissolve_noise_uv_scale = vec2(1.0, 1.0);
/**
 * 噪声贴图的 UV 滚动速度（单位/秒），用于流动的溶解边缘。
 */
uniform vec2 dissolve_noise_scroll = vec2(0.0, 0.0);
/**
 * 溶解噪声的 UV 旋转角度（度）。
 */
uniform float dissolve_noise_rotate : hint_range(0.0, 360.0, 1.0) = 0.0;
/**
 * 裁切依据：遮罩贴图、UV 空间或物体空间。
 */
uniform int dissolve_mode : hint_enum("遮罩", "UV", "物体空间") = 0;
/**
 * 裁切形状：线性按方向投影，圆形按距离计算。
 */
uniform int dissolve_shape : hint_enum("圆形", "线性") = 0;
/**
 * 裁切阈值：低于该值的片元被丢弃；范围 0–1，默认 0.5。
 */
uniform float dissolve_border : hint_range(0.0, 1.0, 0.001) = 0.5;
/**
 * 边缘发光带宽度：越小边缘越锐利，越大过渡越柔和；默认 0.1。
 */
uniform float dissolve_blur : hint_range(0.001, 1.0, 0.001) = 0.1;
/**
 * 线性模式的方向，或圆形模式的中心点（UV/物体空间）。
 */
uniform vec3 dissolve_position = vec3(0.0);
/**
 * 溶解边缘的发光颜色；只有边界带可见。
 */
uniform vec4 dissolve_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/**
 * 是否使用溶解遮罩贴图；仅在“遮罩”模式下生效。
 */
uniform bool use_dissolve_mask = false;
/**
 * 溶解遮罩贴图：R 通道作为裁切依据，默认白色。
 */
uniform sampler2D dissolve_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 溶解遮罩贴图的 UV 缩放。
 */
uniform vec2 dissolve_mask_uv_scale = vec2(1.0, 1.0);
/**
 * 距离淡出：按相机距离把表面颜色/透明度过渡到淡出颜色，用于“透视”与描边隐藏。
 */
group_uniforms DistanceFade;
/**
 * 是否启用距离淡出；关闭时不产生额外计算。
 */
uniform bool use_distance_fade = false;
/**
 * 淡出起始距离（米），小于该距离时不淡化；默认 0。
 */
uniform float distance_fade_near : hint_range(0.0, 100.0, 0.01) = 0.0;
/**
 * 淡出结束距离（米），大于该距离时完全过渡到淡出颜色；默认 5。
 */
uniform float distance_fade_far : hint_range(0.0, 100.0, 0.01) = 5.0;
/**
 * 淡出强度：1 为完全过渡到淡出颜色，0 为不淡出；默认 1。
 */
uniform float distance_fade_strength : hint_range(0.0, 1.0, 0.001) = 1.0;
/**
 * 淡出颜色与透明度；透明材质的 alpha 会随它衰减。
 */
uniform vec4 distance_fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
/**
 * 距离淡出时叠加的边缘光颜色，对应 liltoon 的 _DistanceFadeRimColor；默认 Alpha 为 0，不产生效果。
 */
uniform vec4 distance_fade_rim_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
/**
 * 距离淡出边缘光的菲涅尔幂，对应 liltoon 的 _DistanceFadeRimFresnelPower；越大边缘越窄。
 */
uniform float distance_fade_rim_fresnel_power : hint_range(0.01, 50.0, 0.01) = 5.0;
/**
 * 距离计算方式：相机到片元的距离，或相机到物体原点的距离。
 */
uniform int distance_fade_mode : hint_enum("相机距离", "物体距离") = 0;
/**
 * 贴花 / 装饰：在主色之上叠加一张带 UV 变换的装饰贴图。
 */
group_uniforms Decal;
/**
 * 是否启用贴花层；关闭时不采样贴图。
 */
uniform bool use_decal = false;
/**
 * 贴花贴图，使用 RGBA，A 通道作为混合遮罩。
 */
uniform sampler2D decal_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 贴花颜色，会与贴图相乘。
 */
uniform vec4 decal_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/**
 * 贴花 UV 缩放。
 */
uniform vec2 decal_uv_scale = vec2(1.0, 1.0);
/**
 * 贴花 UV 偏移。
 */
uniform vec2 decal_uv_offset = vec2(0.0, 0.0);
/**
 * 贴花强度：0 为不显示，1 为完全按遮罩混合。
 */
uniform float decal_strength : hint_range(0.0, 1.0, 0.001) = 1.0;
/**
 * 贴花混合方式：叠色、正片叠底或相加。
 */
uniform int decal_blend_mode : hint_enum("叠色", "正片叠底", "相加") = 0;
/**
 * 第二贴层：在主贴花之上再叠加一张装饰贴图（简化版 2nd 贴层）。
 */
uniform bool use_decal_2nd = false;
/**
 * 第二贴层贴图，使用 RGBA，A 通道作为混合遮罩。
 */
uniform sampler2D decal_2nd_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第二贴层颜色，会与贴图相乘。
 */
uniform vec4 decal_2nd_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/**
 * 第二贴层 UV 缩放。
 */
uniform vec2 decal_2nd_uv_scale = vec2(1.0, 1.0);
/**
 * 第二贴层 UV 偏移。
 */
uniform vec2 decal_2nd_uv_offset = vec2(0.0, 0.0);
/**
 * 第二贴层强度：0 为不显示，1 为完全按遮罩混合。
 */
uniform float decal_2nd_strength : hint_range(0.0, 1.0, 0.001) = 1.0;
/**
 * 第二贴层混合方式：叠色、正片叠底或相加。
 */
uniform int decal_2nd_blend_mode : hint_enum("叠色", "正片叠底", "相加") = 0;
/**
 * 第三贴层：在主贴花与第二贴层之上再叠加一张装饰贴图。
 */
uniform bool use_decal_3rd = false;
/**
 * 第三贴层贴图，使用 RGBA，A 通道作为混合遮罩。
 */
uniform sampler2D decal_3rd_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第三贴层颜色，会与贴图相乘。
 */
uniform vec4 decal_3rd_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/**
 * 第三贴层 UV 缩放。
 */
uniform vec2 decal_3rd_uv_scale = vec2(1.0, 1.0);
/**
 * 第三贴层 UV 偏移。
 */
uniform vec2 decal_3rd_uv_offset = vec2(0.0, 0.0);
/**
 * 第三贴层强度：0 为不显示，1 为完全按遮罩混合。
 */
uniform float decal_3rd_strength : hint_range(0.0, 1.0, 0.001) = 1.0;
/**
 * 第三贴层混合方式：叠色、正片叠底或相加。
 */
uniform int decal_3rd_blend_mode : hint_enum("叠色", "正片叠底", "相加") = 0;
/**
 * 是否用一张遮罩限制三层贴花的显示范围。
 */
uniform bool use_decal_mask = false;
/**
 * 贴花遮罩贴图，取 R 通道，三层共用。
 */
uniform sampler2D decal_shared_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 贴花遮罩的 UV 缩放。
 */
uniform vec2 decal_mask_uv_scale = vec2(1.0, 1.0);
/**
 * 第二贴层专用遮罩，取 R 通道，与共享遮罩相乘。
 */
uniform sampler2D decal_2nd_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第三贴层专用遮罩，取 R 通道，与共享遮罩相乘。
 */
uniform sampler2D decal_3rd_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第二贴层随溶解消失的强度：0 不受溶解影响，1 完全跟随。
 */
uniform float decal_2nd_dissolve_strength : hint_range(0.0, 1.0, 0.001) = 0.0;
/**
 * 第三贴层随溶解消失的强度：0 不受溶解影响，1 完全跟随。
 */
uniform float decal_3rd_dissolve_strength : hint_range(0.0, 1.0, 0.001) = 0.0;
/**
 * 贴花 UV 滚动（每秒），三层共用，用于流动纹理。
 */
uniform vec2 decal_uv_scroll = vec2(0.0, 0.0);
/**
 * 主贴花的 UV 通道：UV 或 UV2。
 */
uniform int decal_uv_mode : hint_enum("UV", "UV2") = 0;
/**
 * 第二贴层的 UV 通道：UV 或 UV2。
 */
uniform int decal_2nd_uv_mode : hint_enum("UV", "UV2") = 0;
/**
 * 第三贴层的 UV 通道：UV 或 UV2。
 */
uniform int decal_3rd_uv_mode : hint_enum("UV", "UV2") = 0;
/**
 * 主贴花的 UV 旋转（角度）。
 */
uniform float decal_uv_rotate : hint_range(0.0, 360.0, 1.0) = 0.0;
/**
 * 第二贴层的额外 UV 滚动（每秒），会叠加在共享滚动上。
 */
uniform vec2 decal_2nd_uv_scroll = vec2(0.0, 0.0);
/**
 * 第二贴层的额外 UV 旋转（角度）。
 */
uniform float decal_2nd_uv_rotate : hint_range(0.0, 360.0, 1.0) = 0.0;
/**
 * 第三贴层的额外 UV 滚动（每秒），会叠加在共享滚动上。
 */
uniform vec2 decal_3rd_uv_scroll = vec2(0.0, 0.0);
/**
 * 第三贴层的额外 UV 旋转（角度）。
 */
uniform float decal_3rd_uv_rotate : hint_range(0.0, 360.0, 1.0) = 0.0;
/**
 * 第二贴层序列帧列数。
 */
uniform int decal_2nd_anim_columns : hint_range(1, 16, 1) = 1;
/**
 * 第二贴层序列帧行数。
 */
uniform int decal_2nd_anim_rows : hint_range(1, 16, 1) = 1;
/**
 * 第二贴层序列帧速度（帧/秒）。
 */
uniform float decal_2nd_anim_speed : hint_range(0.0, 30.0, 0.01) = 0.0;
/**
 * 第三贴层序列帧列数。
 */
uniform int decal_3rd_anim_columns : hint_range(1, 16, 1) = 1;
/**
 * 第三贴层序列帧行数。
 */
uniform int decal_3rd_anim_rows : hint_range(1, 16, 1) = 1;
/**
 * 第三贴层序列帧速度（帧/秒）。
 */
uniform float decal_3rd_anim_speed : hint_range(0.0, 30.0, 0.01) = 0.0;
/**
 * 第二贴层是否参与光照；关闭后写入自发光。
 */
uniform bool decal_2nd_enable_lighting = true;
/**
 * 第二层阴影是否使用颜色贴图。
 */
uniform bool use_shade_2nd_color_tex = false;
/**
 * 第二层阴影颜色贴图，会与 shade_2nd_color 相乘。
 */
uniform sampler2D shade_2nd_color_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第三层阴影是否使用颜色贴图。
 */
uniform bool use_shade_3rd_color_tex = false;
/**
 * 第三层阴影颜色贴图。
 */
uniform sampler2D shade_3rd_color_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第二层阴影是否接收投射阴影。
 */
uniform bool use_shade_2nd_receive = true;
/**
 * 第三层阴影是否接收投射阴影。
 */
uniform bool use_shade_3rd_receive = true;
/**
 * 第三贴层是否参与光照；关闭后写入自发光。
 */
uniform bool decal_3rd_enable_lighting = true;
/**
 * 第二贴层是否使用法线贴图。
 */
uniform bool use_decal_2nd_normal = false;
/**
 * 第二贴层法线贴图（切线空间）。
 */
uniform sampler2D decal_2nd_normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
/**
 * 第二贴层法线强度。
 */
uniform float decal_2nd_normal_scale : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * 第二层法线的 UV 模式：0 使用 UV，1 使用 UV2，对应 liltoon 的 _Bump2ndMap_UVMode。
 */
uniform int decal_2nd_normal_uv_mode : hint_enum("UV", "UV2") = 0;
/**
 * 是否用遮罩缩放第二层法线强度，对应 liltoon 的 _Bump2ndScaleMask。
 */
uniform bool use_decal_2nd_normal_scale_mask = false;
/**
 * 第二层法线强度遮罩，R 通道乘到法线缩放上。
 */
uniform sampler2D decal_2nd_normal_scale_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第三贴层是否使用法线贴图。
 */
uniform bool use_decal_3rd_normal = false;
/**
 * 第三贴层法线贴图（切线空间）。
 */
uniform sampler2D decal_3rd_normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
/**
 * 第三贴层法线强度。
 */
uniform float decal_3rd_normal_scale : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * 第二贴层是否使用独立溶解遮罩。
 */
uniform bool use_decal_2nd_dissolve_mask = false;
/**
 * 第二贴层溶解遮罩，取 R 通道。
 */
uniform sampler2D decal_2nd_dissolve_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第三贴层是否使用独立溶解遮罩。
 */
uniform bool use_decal_3rd_dissolve_mask = false;
/**
 * 第三贴层溶解遮罩，取 R 通道。
 */
uniform sampler2D decal_3rd_dissolve_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第二贴层是否使用溶解噪声贴图。
 */
uniform bool use_decal_2nd_dissolve_noise = false;
/**
 * 第二贴层溶解噪声贴图。
 */
uniform sampler2D decal_2nd_dissolve_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第二贴层溶解噪声强度。
 */
uniform float decal_2nd_dissolve_noise_strength : hint_range(0.0, 1.0, 0.001) = 0.5;
/**
 * 第二层溶解噪声的 UV 滚动速度，对应 liltoon 的 _Main2ndDissolveNoiseMask_ScrollRotate.xy。
 */
uniform vec2 decal_2nd_dissolve_noise_uv_scroll = vec2(0.0, 0.0);
/**
 * 第二层溶解噪声的 UV 旋转：X 初始角度、Y 角速度（弧度/秒）。
 */
uniform vec2 decal_2nd_dissolve_noise_uv_rotate = vec2(0.0, 0.0);
/**
 * 第三贴层是否使用溶解噪声贴图。
 */
uniform bool use_decal_3rd_dissolve_noise = false;
/**
 * 第三贴层溶解噪声贴图。
 */
uniform sampler2D decal_3rd_dissolve_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 第三贴层溶解噪声强度。
 */
uniform float decal_3rd_dissolve_noise_strength : hint_range(0.0, 1.0, 0.001) = 0.5;
/**
 * 第三层溶解噪声的 UV 滚动速度，对应 liltoon 的 _Main3rdDissolveNoiseMask_ScrollRotate.xy。
 */
uniform vec2 decal_3rd_dissolve_noise_uv_scroll = vec2(0.0, 0.0);
/**
 * 第三层溶解噪声的 UV 旋转：X 初始角度、Y 角速度（弧度/秒）。
 */
uniform vec2 decal_3rd_dissolve_noise_uv_rotate = vec2(0.0, 0.0);
/**
 * 毛发：按壳层（shell）向外偏移并在片元中按层衰减，模拟绒毛。
 */
group_uniforms Fur;
/**
 * 毛发壳层数（1–4）；层数越多越蓬松，开销也越高。
 */
uniform int fur_layers : hint_range(1, 12) = 6;
/**
 * 当前壳层索引（0 为最内层），由材质链上的每个壳材质各自设置。
 */
uniform int fur_layer : hint_range(0, 11) = 0;
/**
 * 毛发长度：最外层相对表面的偏移量（米）。
 */
uniform float fur_length : hint_range(0.0, 0.3, 0.001) = 0.03;
/**
 * 重力：让外层毛发向下垂的强度。
 */
uniform float fur_gravity : hint_range(0.0, 1.0, 0.001) = 0.2;
/**
 * 根部压暗：让毛发根部接近体表颜色。
 */
uniform float fur_ao : hint_range(0.0, 1.0, 0.001) = 0.6;
/**
 * 逐顶点长度扰动，制造参差的毛发边缘。
 */
uniform float fur_noise_strength : hint_range(0.0, 1.0, 0.001) = 0.3;
/**
 * 毛束密度：按噪声裁切壳层，值越大毛束越稀疏、轮廓越破碎。
 */
uniform float fur_strand_density : hint_range(0.0, 1.0, 0.001) = 0.5;
/**
 * 毛束噪声频率：越大毛束越细密。
 */
uniform float fur_strand_scale : hint_range(1.0, 200.0, 1.0) = 45.0;
/**
 * 毛发根色：贴近皮肤的一层颜色。
 */
uniform vec4 fur_root_color : source_color = vec4(0.2, 0.1, 0.05, 1.0);
/**
 * 毛发梢色：最外层毛尖的颜色。
 */
uniform vec4 fur_tip_color : source_color = vec4(0.9, 0.75, 0.55, 1.0);
/**
 * 毛发噪声贴图：取 A 通道作为毛束遮罩，控制壳层的裁切形状。
 */
uniform sampler2D fur_noise_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 毛发噪声贴图的 UV 缩放。
 */
uniform vec2 fur_noise_uv_scale = vec2(2.0, 2.0);
/**
 * 毛发生长方向（物体空间）；与法线按“方向强度”混合。
 */
uniform vec3 fur_vector = vec3(0.0, 1.0, 0.0);
/**
 * 方向强度：0 沿法线生长，1 完全沿 fur_vector 生长。
 */
uniform float fur_direction_strength : hint_range(0.0, 1.0, 0.001) = 0.0;
/**
 * 毛长遮罩：R 通道控制各区域毛长，白色为全长。
 */
uniform sampler2D fur_length_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 风向（物体空间），与重力叠加形成摆动方向。
 */
uniform vec3 fur_wind_direction = vec3(1.0, 0.0, 0.0);
/**
 * 风力：0 为静止，越大摆动幅度越高。
 */
uniform float fur_wind_strength : hint_range(0.0, 1.0, 0.001) = 0.3;
/**
 * 摆动速度（次/秒）。
 */
uniform float fur_wind_speed : hint_range(0.0, 5.0, 0.01) = 1.0;
/**
 * 是否启用毛发边缘光。
 */
uniform bool use_fur_rim = false;

/**
 * 毛发边缘光颜色。
 */
uniform vec4 fur_rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/**
 * 边缘光菲涅尔指数：越大越集中在轮廓。
 */
uniform float fur_rim_fresnel_power : hint_range(1.0, 16.0, 0.1) = 4.0;
/**
 * 抗光：受光面削弱边缘光，0 为不削弱。
 */
uniform float fur_rim_anti_light : hint_range(0.0, 1.0, 0.001) = 0.0;
/**
 * 噪声贴图 UV 滚动（每秒）。
 */
uniform vec2 fur_noise_uv_scroll = vec2(0.0, 0.0);
/**
 * 噪声贴图 UV 旋转（角度）。
 */
uniform float fur_noise_uv_rotate : hint_range(0.0, 360.0, 1.0) = 0.0;
/**
 * 毛向量缩放：0 为不生长，1 为原始长度。
 */
uniform float fur_vector_scale : hint_range(0.0, 2.0, 0.01) = 1.0;
/**
 * 裁切长度：越小外层越早被裁掉，1 为默认。
 */
uniform float fur_cutout_length : hint_range(0.0, 1.0, 0.01) = 1.0;
/**
 * 是否用顶点色 RGB 作为毛向量。
 */
uniform bool use_vertex_color_fur_vector = false;
/**
 * 根部偏移：壳层从该层高开始生长，0 为从皮肤开始。
 */
uniform float fur_root_offset : hint_range(0.0, 0.9, 0.01) = 0.0;
/**
 * 毛发遮罩：R 通道控制哪里长毛（0 不长），与壳层 Alpha 相乘；对应 lilToon `_FurMask`。
 */
uniform sampler2D fur_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/**
 * 毛发噪声遮罩：R 通道参与壳层 Alpha 裁切，制造参差的毛发边缘；对应 lilToon `_FurNoiseMask`。
 */
uniform sampler2D fur_noise_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/** 毛发噪声遮罩的 UV 缩放。 */
uniform vec2 fur_noise_mask_uv_scale = vec2(1.0, 1.0);
/**
 * 毛向量随机化：给每根毛的方向加随机扰动，打散整齐感；0 关闭，对应 lilToon `_FurRandomize`。
 */
uniform float fur_randomize : hint_range(0.0, 1.0, 0.001) = 0.0;
/** 是否启用毛向量贴图；对应 lilToon 的 `LIL_FEATURE_FurVectorTex`。 */
uniform bool use_fur_vector_texture = false;
/**
 * 毛向量贴图（法线贴图格式）：用贴图指定毛发生长方向，按 `fur_vector_scale` 缩放；
 * 对应 lilToon `_FurVectorTex`。
 */
uniform sampler2D fur_vector_texture : hint_normal, filter_linear_mipmap, repeat_enable;
/**
 * 触摸强度：把毛发从触摸点推开；0 关闭，对应 lilToon `_FurTouchStrength`。
 * 原版用 Unity 点光源作为触摸源，本实现改用 `fur_touch_position`（物体空间）。
 */
uniform float fur_touch_strength : hint_range(0.0, 1.0, 0.001) = 0.0;
/** 触摸点（物体空间坐标）；仅在 `fur_touch_strength > 0` 时生效。 */
uniform vec3 fur_touch_position = vec3(0.0, 0.0, 0.0);
/** 触摸影响半径（物体空间单位）；超出该距离不再推开。 */
uniform float fur_touch_range : hint_range(0.01, 5.0, 0.01) = 1.0;

group_uniforms Refraction;
#ifdef LILTOON_REFRACTION
/**
 * 折射用的屏幕纹理，由引擎自动填充（hint_screen_texture）。
 * 只在折射变体里声明，避免其他材质每帧触发一次屏幕拷贝。
 */
uniform sampler2D refraction_screen_texture : hint_screen_texture, repeat_disable, filter_linear;
#endif
/**
 * 是否启用折射：按视角法线扰动屏幕 UV，把背景"折"进材质。
 * 只在 `liltoon_refraction.gdshader` 变体里有效，其他变体保留参数但不生效。
 */
uniform bool use_refraction = false;
/**
 * 折射颜色：与采样到的屏幕颜色相乘；对应 lilToon `_RefractionColor`，默认白色。
 */
uniform vec4 refraction_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/**
 * 是否改用主色（反照率）作为折射颜色；对应 lilToon `_RefractionColorFromMain`。
 */
uniform bool refraction_color_from_main = false;
/**
 * 折射强度：正值把背景向法线方向偏移，负值反向；范围 -1..1，对应 lilToon `_RefractionStrength`。
 */
uniform float refraction_strength : hint_range(-1.0, 1.0, 0.01) = 0.1;
/**
 * 折射菲涅尔指数：越大越只在轮廓附近折射；范围 0.01..10，对应 lilToon `_RefractionFresnelPower`。
 */
uniform float refraction_fresnel_power : hint_range(0.01, 10.0, 0.01) = 0.5;

group_uniforms DecalConvention;
// 贴花的导入/烘焙期约定。原版 shader 同样只声明不读取，真正消费方是纹理烘焙器与 Inspector；
// 本项目由 editor/liltoon_texture_baker.gd 消费。保留为材质属性以便预设/材质导入携带这些信息。
/** 第二贴层是否按贴花语义处理（不做重复平铺）；对应 lilToon `_Main2ndTexIsDecal`。 */
uniform bool decal_2nd_is_decal = false;
/** 第二贴层只保留左半（uv.x < 0.5），右半裁掉；对应 `_Main2ndTexIsLeftOnly`。 */
uniform bool decal_2nd_is_left_only = false;
/** 第二贴层只保留右半（uv.x > 0.5），左半裁掉；对应 `_Main2ndTexIsRightOnly`。 */
uniform bool decal_2nd_is_right_only = false;
/** 第二贴层按 MSDF（多通道有符号距离场）解码，取三通道中位数；对应 `_Main2ndTexIsMSDF`。 */
uniform bool decal_2nd_is_msdf = false;
/** 第二贴层把左半镜像复制到右半；对应 `_Main2ndTexShouldCopy`。 */
uniform bool decal_2nd_should_copy = false;
/** 第二贴层复制时翻转方向；对应 `_Main2ndTexShouldFlipCopy`。 */
uniform bool decal_2nd_should_flip_copy = false;
/** 第二贴层镜像半区是否翻转；对应 `_Main2ndTexShouldFlipMirror`。 */
uniform bool decal_2nd_should_flip_mirror = false;
/** 第二贴层附加子参数（X=UV 缩放、Y=偏移、Z=旋转、W=保留）；对应 `_Main2ndTexDecalSubParam`。 */
uniform vec4 decal_2nd_sub_param = vec4(1.0, 0.0, 0.0, 0.0);
/** 第三贴层是否按贴花语义处理；对应 `_Main3rdTexIsDecal`。 */
uniform bool decal_3rd_is_decal = false;
/** 第三贴层只保留左半；对应 `_Main3rdTexIsLeftOnly`。 */
uniform bool decal_3rd_is_left_only = false;
/** 第三贴层只保留右半；对应 `_Main3rdTexIsRightOnly`。 */
uniform bool decal_3rd_is_right_only = false;
/** 第三贴层按 MSDF 解码；对应 `_Main3rdTexIsMSDF`。 */
uniform bool decal_3rd_is_msdf = false;
/** 第三贴层把左半镜像复制到右半；对应 `_Main3rdTexShouldCopy`。 */
uniform bool decal_3rd_should_copy = false;
/** 第三贴层复制时翻转方向；对应 `_Main3rdTexShouldFlipCopy`。 */
uniform bool decal_3rd_should_flip_copy = false;
/** 第三贴层镜像半区是否翻转；对应 `_Main3rdTexShouldFlipMirror`。 */
uniform bool decal_3rd_should_flip_mirror = false;
/** 第三贴层附加子参数；对应 `_Main3rdTexDecalSubParam`。 */
uniform vec4 decal_3rd_sub_param = vec4(1.0, 0.0, 0.0, 0.0);

group_uniforms IDMask;
/** 是否启用 ID 遮罩系统；对应 lilToon `_IDMaskCompile`。 */
uniform bool use_id_mask = false;
/**
 * ID 来源：0=主 UV.x、1=UV1.x、2=UV2.x。
 * 原版还支持 UV3–UV7 与 VertexID（默认），但 Godot shader 没有顶点 ID、也只有两套 UV，
 * 故仅保留可实现的三种（详见 §9）。
 */
uniform int id_mask_from : hint_enum("主 UV", "UV1", "UV2") = 0;
/** 索引是否为位掩码（按位判 ID）而非直接相等；对应 lilToon `_IDMaskIsBitmap`。 */
uniform bool id_mask_is_bitmap = false;
/** 是否让 ID 遮罩同时驱动溶解（前后状态差即溶解边界）；对应 `_IDMaskControlsDissolve`。 */
uniform bool id_mask_controls_dissolve = false;
/** 第 1 个 ID 槽是否启用；对应 lilToon `_IDMask1`。 */
uniform bool id_mask_1 = false;
/** 第 2 个 ID 槽是否启用；对应 lilToon `_IDMask2`。 */
uniform bool id_mask_2 = false;
/** 第 3 个 ID 槽是否启用；对应 lilToon `_IDMask3`。 */
uniform bool id_mask_3 = false;
/** 第 4 个 ID 槽是否启用；对应 lilToon `_IDMask4`。 */
uniform bool id_mask_4 = false;
/** 第 5 个 ID 槽是否启用；对应 lilToon `_IDMask5`。 */
uniform bool id_mask_5 = false;
/** 第 6 个 ID 槽是否启用；对应 lilToon `_IDMask6`。 */
uniform bool id_mask_6 = false;
/** 第 7 个 ID 槽是否启用；对应 lilToon `_IDMask7`。 */
uniform bool id_mask_7 = false;
/** 第 8 个 ID 槽是否启用；对应 lilToon `_IDMask8`。 */
uniform bool id_mask_8 = false;
/** 第 1 个 ID 槽要比对的编号；对应 lilToon `_IDMaskIndex1`。 */
uniform int id_mask_index_1 : hint_range(0, 255, 1) = 1;
/** 第 2 个 ID 槽要比对的编号；对应 lilToon `_IDMaskIndex2`。 */
uniform int id_mask_index_2 : hint_range(0, 255, 1) = 2;
/** 第 3 个 ID 槽要比对的编号；对应 lilToon `_IDMaskIndex3`。 */
uniform int id_mask_index_3 : hint_range(0, 255, 1) = 4;
/** 第 4 个 ID 槽要比对的编号；对应 lilToon `_IDMaskIndex4`。 */
uniform int id_mask_index_4 : hint_range(0, 255, 1) = 8;
/** 第 5 个 ID 槽要比对的编号；对应 lilToon `_IDMaskIndex5`。 */
uniform int id_mask_index_5 : hint_range(0, 255, 1) = 16;
/** 第 6 个 ID 槽要比对的编号；对应 lilToon `_IDMaskIndex6`。 */
uniform int id_mask_index_6 : hint_range(0, 255, 1) = 32;
/** 第 7 个 ID 槽要比对的编号；对应 lilToon `_IDMaskIndex7`。 */
uniform int id_mask_index_7 : hint_range(0, 255, 1) = 64;
/** 第 8 个 ID 槽要比对的编号；对应 lilToon `_IDMaskIndex8`。 */
uniform int id_mask_index_8 : hint_range(0, 255, 1) = 128;
/** 第 1 槽的「前态」开关，用于溶解动画的起始状态；对应 `_IDMaskPrior1`。 */
uniform bool id_mask_prior_1 = false;
/** 第 2 槽的前态开关；对应 `_IDMaskPrior2`。 */
uniform bool id_mask_prior_2 = false;
/** 第 3 槽的前态开关；对应 `_IDMaskPrior3`。 */
uniform bool id_mask_prior_3 = false;
/** 第 4 槽的前态开关；对应 `_IDMaskPrior4`。 */
uniform bool id_mask_prior_4 = false;
/** 第 5 槽的前态开关；对应 `_IDMaskPrior5`。 */
uniform bool id_mask_prior_5 = false;
/** 第 6 槽的前态开关；对应 `_IDMaskPrior6`。 */
uniform bool id_mask_prior_6 = false;
/** 第 7 槽的前态开关；对应 `_IDMaskPrior7`。 */
uniform bool id_mask_prior_7 = false;
/** 第 8 槽的前态开关；对应 `_IDMaskPrior8`。 */
uniform bool id_mask_prior_8 = false;

group_uniforms Mask;
/** 是否启用三通道特性遮罩；对应 lilToon `_TriMask`（原版仅 lite pass 采样，主通道恒为 1）。 */
uniform bool use_tri_mask = false;
/**
 * 三通道特性遮罩：R 遮 MatCap、G 遮边缘光、B 遮自发光；对应 lilToon `_TriMask`。
 */
uniform sampler2D tri_mask : hint_default_white, filter_linear_mipmap, repeat_enable;

group_uniforms UDIM;
/**
 * 是否启用 UDIM 平铺丢弃（对应 lilToon `_UDIMDiscardCompile`）。
 * 按 UV 落在 4×4 网格的哪一格决定是否丢弃该像素，用于 UV 平铺工作流。
 */
uniform bool use_udim_discard = false;
/** 丢弃执行位置：0 顶点（快，整块丢弃）、1 片元（慢，逐像素）；对应 `_UDIMDiscardMode`。 */
uniform int udim_discard_mode : hint_enum("顶点", "片元") = 0;
/** 用哪套 UV 判定：0=主 UV、1=UV1、2=UV2、3=UV3（Godot 只有 UV/UV2，2 与 3 都取 UV2）；对应 `_UDIMDiscardUV`。 */
uniform int udim_discard_uv : hint_enum("主 UV", "UV1", "UV2", "UV3") = 0;
/** UV 格 (0,0)（x∈[0,1), y∈[0,1)）是否丢弃；对应 lilToon `_UDIMDiscardRow0_0`。 */
uniform bool udim_discard_row0_0 = false;
/** UV 格 (0,1)（x∈[1,2), y∈[0,1)）是否丢弃；对应 lilToon `_UDIMDiscardRow0_1`。 */
uniform bool udim_discard_row0_1 = false;
/** UV 格 (0,2)（x∈[2,3), y∈[0,1)）是否丢弃；对应 lilToon `_UDIMDiscardRow0_2`。 */
uniform bool udim_discard_row0_2 = false;
/** UV 格 (0,3)（x∈[3,4), y∈[0,1)）是否丢弃；对应 lilToon `_UDIMDiscardRow0_3`。 */
uniform bool udim_discard_row0_3 = false;
/** UV 格 (1,0)（x∈[0,1), y∈[1,2)）是否丢弃；对应 lilToon `_UDIMDiscardRow1_0`。 */
uniform bool udim_discard_row1_0 = false;
/** UV 格 (1,1)（x∈[1,2), y∈[1,2)）是否丢弃；对应 lilToon `_UDIMDiscardRow1_1`。 */
uniform bool udim_discard_row1_1 = false;
/** UV 格 (1,2)（x∈[2,3), y∈[1,2)）是否丢弃；对应 lilToon `_UDIMDiscardRow1_2`。 */
uniform bool udim_discard_row1_2 = false;
/** UV 格 (1,3)（x∈[3,4), y∈[1,2)）是否丢弃；对应 lilToon `_UDIMDiscardRow1_3`。 */
uniform bool udim_discard_row1_3 = false;
/** UV 格 (2,0)（x∈[0,1), y∈[2,3)）是否丢弃；对应 lilToon `_UDIMDiscardRow2_0`。 */
uniform bool udim_discard_row2_0 = false;
/** UV 格 (2,1)（x∈[1,2), y∈[2,3)）是否丢弃；对应 lilToon `_UDIMDiscardRow2_1`。 */
uniform bool udim_discard_row2_1 = false;
/** UV 格 (2,2)（x∈[2,3), y∈[2,3)）是否丢弃；对应 lilToon `_UDIMDiscardRow2_2`。 */
uniform bool udim_discard_row2_2 = false;
/** UV 格 (2,3)（x∈[3,4), y∈[2,3)）是否丢弃；对应 lilToon `_UDIMDiscardRow2_3`。 */
uniform bool udim_discard_row2_3 = false;
/** UV 格 (3,0)（x∈[0,1), y∈[3,4)）是否丢弃；对应 lilToon `_UDIMDiscardRow3_0`。 */
uniform bool udim_discard_row3_0 = false;
/** UV 格 (3,1)（x∈[1,2), y∈[3,4)）是否丢弃；对应 lilToon `_UDIMDiscardRow3_1`。 */
uniform bool udim_discard_row3_1 = false;
/** UV 格 (3,2)（x∈[2,3), y∈[3,4)）是否丢弃；对应 lilToon `_UDIMDiscardRow3_2`。 */
uniform bool udim_discard_row3_2 = false;
/** UV 格 (3,3)（x∈[3,4), y∈[3,4)）是否丢弃；对应 lilToon `_UDIMDiscardRow3_3`。 */
uniform bool udim_discard_row3_3 = false;

group_uniforms AudioLink;
// 由 LiltoonAudioLink 单例（autoload）每帧写入的全局 uniform。
// audiolink_texture：128×4，行 = 频段（低→高），列 = 时间（越右越新）。
global uniform sampler2D audiolink_texture : filter_linear, repeat_enable;
// 当前 4 个频段的幅值（0..1）。
global uniform vec4 audiolink_bands;
// 已写入列数 / 128，用于和 shader 的 TIME 对齐时间轴。
global uniform float audiolink_time;
/**
 * 是否启用 AudioLink（让材质跟随音频律动）。
 * 需要场景里挂 LiltoonAudioLink autoload，否则会走合成脉冲回退。
 */
uniform bool use_audiolink = false;
/**
 * 默认值：X=强度、Y=闪烁强度、Z=闪烁速度、W=闪烁阈值；
 * 对应 lilToon `_AudioLinkDefaultValue`。
 */
uniform vec4 audiolink_default_value = vec4(0.0, 0.0, 2.0, 0.75);
/**
 * UV 模式：0 固定偏移、1 按视角、2 按 UV 旋转、3 遮罩 RG、4 遮罩阈值、5 按到起点距离；
 * 对应 lilToon `_AudioLinkUVMode`。
 */
uniform int audiolink_uv_mode : hint_enum("固定偏移", "按视角", "UV 旋转", "遮罩 RG", "遮罩阈值", "按距离") = 1;
/**
 * UV 参数：X=缩放、Y=偏移、Z=旋转角度、W=频段（0=低音…1=高音）；
 * 对应 lilToon `_AudioLinkUVParams`。
 */
uniform vec4 audiolink_uv_params = vec4(0.25, 0.0, 0.0, 0.125);
/**
 * 距离模式的起点（物体空间）；对应 lilToon `_AudioLinkStart`。
 */
uniform vec3 audiolink_start = vec3(0.0);
/** 是否使用 AudioLink 遮罩贴图；对应 lilToon 的 `_AudioLinkMask` 特性。 */
uniform bool use_audiolink_mask = false;
/**
 * AudioLink 遮罩：R=延迟 G=频段 B=强度；对应 lilToon `_AudioLinkMask`。
 */
uniform sampler2D audiolink_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
/** 遮罩 UV 缩放；对应 `_AudioLinkMask_ST`。 */
uniform vec2 audiolink_mask_uv_scale = vec2(1.0, 1.0);
/** 遮罩 UV 滚动速度；对应 `_AudioLinkMask_ScrollRotate.xy`。 */
uniform vec2 audiolink_mask_uv_scroll = vec2(0.0, 0.0);
/** 遮罩 UV 旋转角度（弧度）；对应 `_AudioLinkMask_ScrollRotate.z`。 */
uniform float audiolink_mask_uv_rotate = 0.0;
/** 遮罩 UV 来源：主 UV / UV1 / UV2 / UV3；对应 `_AudioLinkMask_UVMode`。 */
uniform int audiolink_mask_uv_mode : hint_enum("主 UV", "UV1", "UV2", "UV3") = 0;
/** 把音频值接到第二贴层的 Alpha；对应 lilToon `_AudioLink2Main2nd`。 */
uniform bool audiolink_2_main_2nd = false;
/** 把音频值接到第三贴层的 Alpha；对应 lilToon `_AudioLink2Main3rd`。 */
uniform bool audiolink_2_main_3rd = false;
/** 把音频值接到主自发光的 Alpha；对应 lilToon `_AudioLink2Emission`。 */
uniform bool audiolink_2_emission = false;
/** 把音频值叠加到主自发光渐变相位；对应 lilToon `_AudioLink2EmissionGrad`。 */
uniform bool audiolink_2_emission_grad = false;
/** 把音频值接到第二层自发光的 Alpha；对应 lilToon `_AudioLink2Emission2nd`。 */
uniform bool audiolink_2_emission_2nd = false;
/** 把音频值叠加到第二层自发光渐变相位；对应 lilToon `_AudioLink2Emission2ndGrad`。 */
uniform bool audiolink_2_emission_2nd_grad = false;
/** 用音频值驱动顶点位移；对应 lilToon `_AudioLink2Vertex`。 */
uniform bool audiolink_2_vertex = false;
/** 顶点模式的 UV 模式，取值同 `audiolink_uv_mode`；对应 `_AudioLinkVertexUVMode`。 */
uniform int audiolink_vertex_uv_mode : hint_enum("固定偏移", "按视角", "UV 旋转", "遮罩 RG", "遮罩阈值", "按距离") = 1;
/** 顶点模式的 UV 参数；对应 `_AudioLinkVertexUVParams`。 */
uniform vec4 audiolink_vertex_uv_params = vec4(0.25, 0.0, 0.0, 0.125);
/** 顶点模式的起点（物体空间）；对应 `_AudioLinkVertexStart`。 */
uniform vec3 audiolink_vertex_start = vec3(0.0);
/** 顶点位移：XYZ=固定方向、W=沿法线方向的强度；对应 `_AudioLinkVertexStrength`。 */
uniform vec4 audiolink_vertex_strength = vec4(0.0, 0.0, 0.0, 1.0);
/** 是否改用本地贴图而非全局频谱；对应 lilToon `_AudioLinkAsLocal`。 */
uniform bool audiolink_as_local = false;
/** 本地频谱贴图；对应 lilToon `_AudioLinkLocalMap`。 */
uniform sampler2D audiolink_local_map : hint_default_black, filter_linear_mipmap, repeat_enable;
/** 本地贴图参数：X=速度、Y=缩放、Z=偏移；对应 `_AudioLinkLocalMapParams`。 */
uniform vec4 audiolink_local_map_params = vec4(120.0, 1.0, 0.0, 0.0);

group_uniforms Gem;
#ifdef LILTOON_GEM
/**
 * 折射用的屏幕纹理（宝石变体专用）；由引擎自动填充。
 */
uniform sampler2D gem_screen_texture : hint_screen_texture, repeat_disable, filter_linear;
#endif
/**
 * 色散强度：折射时 RGB 三通道分离采样的偏移量；对应 lilToon `_GemChromaticAberration`。
 */
uniform float gem_chromatic_aberration : hint_range(0.0, 1.0, 0.001) = 0.02;
/**
 * 环境对比度：对折射/反射颜色做 pow 对比度拉伸；对应 lilToon `_GemEnvContrast`。
 */
uniform float gem_env_contrast : hint_range(0.1, 10.0, 0.1) = 2.0;
/**
 * 环境颜色：乘在环境反射上；对应 lilToon `_GemEnvColor`（HDR）。
 */
uniform vec4 gem_env_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/**
 * 粒子色：在特定视角角度上叠加的闪烁色；对应 lilToon `_GemParticleColor`（HDR）。
 */
uniform vec4 gem_particle_color : source_color = vec4(4.0, 4.0, 4.0, 1.0);
/**
 * 粒子闪烁图案的频率：越大亮点越密；对应 lilToon `_GemParticleLoop`（默认 8）。
 */
uniform float gem_particle_loop : hint_range(0.1, 40.0, 0.1) = 8.0;

group_uniforms;
