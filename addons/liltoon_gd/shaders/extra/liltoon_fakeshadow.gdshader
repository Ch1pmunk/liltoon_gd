shader_type spatial;
// liltoon_gd - 假阴影（对齐 lilToon 的 lts_fakeshadow.shader）。
// 用法：把本材质挂在一张平铺在地面的四边形上，阴影贴图会沿光照方向在屏幕上整体偏移，
//       与真实光照/阴影无关，适合在低配或不需要真实投影的场合补一个"落地影"。
// 与原版差异：Unity 在顶点阶段直接读主方向光；Godot 顶点阶段拿不到光照，
//       因此用 `light_direction` uniform，并附 `fakeshadow_lab.gd` 演示脚本每帧同步。
render_mode unshaded, cull_back, depth_prepass_alpha, blend_mix;

/**
 * 阴影颜色与不透明度；RGB 与阴影贴图相乘，A 控制整体浓度。
 * 默认对应 lilToon `_Color` 的 (0.925, 0.7, 0.74, 1)。
 */
uniform vec4 shadow_color : source_color = vec4(0.925, 0.7, 0.74, 1.0);
/**
 * 阴影贴图；通常是一张中心实、边缘渐隐的圆形/椭圆灰度图。
 * 对应 lilToon `_MainTex`。
 */
uniform sampler2D shadow_texture : source_color, filter_linear_mipmap, repeat_enable;
/** 阴影贴图 UV 缩放；对应 lilToon `_MainTex_ST.xy`。 */
uniform vec2 shadow_uv_scale = vec2(1.0, 1.0);
/**
 * X/Y/Z：物体空间的附加投影方向，长度作为权重（0 表示只用光照方向）；
 * W：沿光照方向的偏移距离（世界单位），对应 lilToon `_FakeShadowVector`（默认 W=0.05）。
 */
uniform vec4 fake_shadow_vector = vec4(0.0, 0.0, 0.0, 0.05);
/**
 * 光照方向（世界空间，由物体指向光源）。
 * 没有脚本同步时保持此固定值；演示场景每帧从主方向光写入。
 */
uniform vec3 light_direction = vec3(0.4, 0.8, 0.4);
/** 是否隐藏阴影；对应 lilToon `_Invisible`，用于整体开关。 */
uniform bool invisible = false;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (invisible) {
		// 移到裁剪空间外，等价于不绘制（POSITION 为裁剪空间坐标）。
		clip = vec4(2.0, 2.0, 2.0, 1.0);
	} else {
		vec3 extra = fake_shadow_vector.xyz;
		vec3 extra_world = (MODEL_MATRIX * vec4(extra, 0.0)).xyz;
		// 长度为 0 时给一个固定方向，避免 normalize(0) 产生 NaN。
		vec3 extra_dir = length(extra) > 0.00001 ? normalize(extra_world) : vec3(0.0, 1.0, 0.0);
		vec3 dir = normalize(light_direction + length(extra) * extra_dir);
		// 方向用 w=0 变换，等价于原版 mul(MATRIX_VP, float4(lightDirection * W, 0))。
		clip -= PROJECTION_MATRIX * (VIEW_MATRIX * vec4(dir * fake_shadow_vector.w, 0.0));
	}
	POSITION = clip;
}

void fragment() {
	vec4 tex = texture(shadow_texture, UV * shadow_uv_scale);
	ALBEDO = tex.rgb * shadow_color.rgb;
	ALPHA = tex.a * shadow_color.a;
}
