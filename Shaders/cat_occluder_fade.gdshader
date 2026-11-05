shader_type spatial;

// The material stays visually opaque outside the mask.  Fragments inside the
// mask use alpha blending instead, so the cat (already drawn behind it) shows
// through without hiding the rest of the mesh.
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

// Center and radius are in screen UV coordinates.  This keeps the opening
// circular from the camera's perspective even on an angled wall or a tree.
uniform vec2 hole_center = vec2(0.5);
uniform float hole_radius : hint_range(0.001, 1.0) = 0.12;
uniform float hole_softness : hint_range(0.001, 1.0) = 0.025;
uniform float hole_amount : hint_range(0.0, 1.0) = 0.0;
uniform float hole_opacity : hint_range(0.0, 1.0) = 0.0;
uniform float viewport_aspect : hint_range(0.1, 4.0) = 1.0;

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

	float distance_from_cat = length((SCREEN_UV - hole_center) * vec2(viewport_aspect, 1.0));
	float circular_mask = 1.0 - smoothstep(hole_radius - hole_softness, hole_radius, distance_from_cat);
	float opacity = mix(1.0, hole_opacity, circular_mask * hole_amount);
	ALPHA = base.a * opacity;
}
