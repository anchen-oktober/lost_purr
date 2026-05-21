shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix;

uniform sampler2D cat_texture : source_color, filter_linear_mipmap;
uniform vec4 outline_color : source_color = vec4(1.0, 0.72, 0.22, 0.85);
uniform float outline_pixels = 5.0;
uniform float glow_pixels = 12.0;
uniform float alpha_threshold = 0.08;

float sample_alpha(vec2 uv, vec2 direction, float distance, vec2 texel_size) {
	return texture(cat_texture, uv + direction * distance * texel_size).a;
}

void fragment() {
	vec4 cat = texture(cat_texture, UV);
	vec2 texel_size = 1.0 / vec2(textureSize(cat_texture, 0));

	float edge_alpha = 0.0;
	float glow_alpha = 0.0;

	edge_alpha = max(edge_alpha, sample_alpha(UV, vec2(1.0, 0.0), outline_pixels, texel_size));
	edge_alpha = max(edge_alpha, sample_alpha(UV, vec2(-1.0, 0.0), outline_pixels, texel_size));
	edge_alpha = max(edge_alpha, sample_alpha(UV, vec2(0.0, 1.0), outline_pixels, texel_size));
	edge_alpha = max(edge_alpha, sample_alpha(UV, vec2(0.0, -1.0), outline_pixels, texel_size));
	edge_alpha = max(edge_alpha, sample_alpha(UV, vec2(0.707, 0.707), outline_pixels, texel_size));
	edge_alpha = max(edge_alpha, sample_alpha(UV, vec2(-0.707, 0.707), outline_pixels, texel_size));
	edge_alpha = max(edge_alpha, sample_alpha(UV, vec2(0.707, -0.707), outline_pixels, texel_size));
	edge_alpha = max(edge_alpha, sample_alpha(UV, vec2(-0.707, -0.707), outline_pixels, texel_size));

	glow_alpha = max(glow_alpha, sample_alpha(UV, vec2(1.0, 0.0), glow_pixels, texel_size));
	glow_alpha = max(glow_alpha, sample_alpha(UV, vec2(-1.0, 0.0), glow_pixels, texel_size));
	glow_alpha = max(glow_alpha, sample_alpha(UV, vec2(0.0, 1.0), glow_pixels, texel_size));
	glow_alpha = max(glow_alpha, sample_alpha(UV, vec2(0.0, -1.0), glow_pixels, texel_size));
	glow_alpha = max(glow_alpha, sample_alpha(UV, vec2(0.707, 0.707), glow_pixels, texel_size));
	glow_alpha = max(glow_alpha, sample_alpha(UV, vec2(-0.707, 0.707), glow_pixels, texel_size));
	glow_alpha = max(glow_alpha, sample_alpha(UV, vec2(0.707, -0.707), glow_pixels, texel_size));
	glow_alpha = max(glow_alpha, sample_alpha(UV, vec2(-0.707, -0.707), glow_pixels, texel_size));

	float outline_mask = smoothstep(alpha_threshold, 0.45, edge_alpha) * (1.0 - smoothstep(0.02, 0.2, cat.a));
	float glow_mask = smoothstep(alpha_threshold, 0.3, glow_alpha) * (1.0 - smoothstep(0.02, 0.35, cat.a));
	float final_alpha = max(outline_mask * outline_color.a, glow_mask * outline_color.a * 0.28);

	ALBEDO = outline_color.rgb;
	EMISSION = outline_color.rgb * 1.5;
	ALPHA = final_alpha;
}
