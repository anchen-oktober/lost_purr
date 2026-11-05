shader_type spatial;

// This temporary per-instance material preserves the source StandardMaterial3D
// appearance while its owning obstacle smoothly becomes semitransparent.
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, hint_default_white;
uniform bool use_albedo_texture = false;
uniform float metallic = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_energy = 0.0;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform bool use_normal_texture = false;
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;

uniform float transparency_amount : hint_range(0.0, 0.95) = 0.60;
uniform float fade_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base = albedo_color;
	if (use_albedo_texture) {
		base *= texture(albedo_texture, UV);
	}

	ALBEDO = base.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	EMISSION = emission_color.rgb * emission_energy;
	if (use_normal_texture) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}

	float opacity = mix(1.0, 1.0 - transparency_amount, fade_amount);
	ALPHA = base.a * opacity;
}
