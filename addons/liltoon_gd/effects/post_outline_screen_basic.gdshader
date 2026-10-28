shader_type spatial;
// liltoon_gd - 后处理描边降级版：仅深度差，用于 Mobile / Compatibility（不支持法线粗糙度纹理）。
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float thickness : hint_range(1.0, 6.0, 0.5) = 2.0;
uniform float depth_threshold : hint_range(0.01, 1.0, 0.01) = 0.08;
uniform vec4 outline_color : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float outline_alpha : hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = 1.0 / VIEWPORT_SIZE;
	float depth_center = texture(depth_texture, uv).r;
	float denom = max(depth_center, 0.0001);

	float edge = 0.0;
	vec2 directions[8] = vec2[8](
		vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
		vec2(1.0, 1.0), vec2(-1.0, 1.0), vec2(1.0, -1.0), vec2(-1.0, -1.0)
	);
	for (int i = 0; i < 8; i++) {
		float depth_sample = texture(depth_texture, uv + directions[i] * thickness * texel).r;
		float diff = abs(depth_sample - depth_center) / denom;
		edge = max(edge, step(depth_threshold, diff));
	}

	ALBEDO = outline_color.rgb;
	ALPHA = edge * outline_color.a * outline_alpha;
}
