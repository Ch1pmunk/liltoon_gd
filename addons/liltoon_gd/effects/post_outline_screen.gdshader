shader_type spatial;
// liltoon_gd - 后处理描边（屏幕空间）：对深度纹理做 8 方向采样，相对深度差超过阈值即描边。
// 2026-10-29 定位并修复：此前的 `depth_texture 恒为 0` 不是 D3D12/硬件问题。
// 根因是 lilToon 的 opaque shader 在若干分支里写 ALPHA（alpha mask / dither / 溶解 / 毛发），
// Godot 据此把材质判为透明，主渲染通道不写深度，深度纹理里没有这些物体。
// 修复：三个 opaque 变体加 `depth_prepass_alpha`（与 cutout/transparent 变体一致）。
// 修复后本机 D3D12 Forward+ 实测描边正常，见 docs/evidence/阶段9/outline_postprocess_fixed.png。
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;
uniform float thickness : hint_range(1.0, 6.0, 0.5) = 2.0;
uniform float depth_threshold : hint_range(0.01, 1.0, 0.01) = 0.08;
/**
 * 是否把法线变化也作为描边依据（折角边）。
 * 默认关闭：normal_roughness_texture 在部分环境取不到有效值，会污染 edge 计算。
 * 开启前请确认当前渲染器支持 `hint_normal_roughness_texture`（仅 Forward+）。
 */
uniform bool use_normal_edge = false;
/** 法线敏感度：值越小越容易在折角处描边，仅在 use_normal_edge 开启时生效。 */
uniform float normal_threshold : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform vec4 outline_color : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float outline_alpha : hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = 1.0 / VIEWPORT_SIZE;
	float depth_center = texture(depth_texture, uv).r;
	vec2 normal_center = texture(normal_roughness_texture, uv).rg;
	float denom = max(depth_center, 0.0001);

	float edge = 0.0;
	vec2 directions[8] = vec2[8](
		vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
		vec2(1.0, 1.0), vec2(-1.0, 1.0), vec2(1.0, -1.0), vec2(-1.0, -1.0)
	);
	for (int i = 0; i < 8; i++) {
		vec2 sample_uv = uv + directions[i] * thickness * texel;
		float depth_sample = texture(depth_texture, sample_uv).r;
		float diff = abs(depth_sample - depth_center) / denom;
		edge = max(edge, step(depth_threshold, diff));
		// 法线边：折角处深度可能连续，但法线变化明显，需要单独判断。
		// 默认关闭——normal_roughness_texture 在部分环境返回无效值，会让 normal_diff 变成
		// NaN 并沿 max() 传染，导致整个 quad 不渲染。开启前请确认该渲染器支持法线纹理。
		if (use_normal_edge) {
			vec2 normal_sample = texture(normal_roughness_texture, sample_uv).rg;
			float normal_diff = length(normal_sample - normal_center);
			// NaN 保护：NaN != NaN，此时按 0 处理
			normal_diff = (normal_diff == normal_diff) ? normal_diff : 0.0;
			edge = max(edge, step(normal_threshold, normal_diff));
		}
	}

	ALBEDO = outline_color.rgb;
	ALPHA = edge * outline_color.a * outline_alpha;
}