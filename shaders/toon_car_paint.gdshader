shader_type spatial;
render_mode diffuse_toon, specular_toon;

// La Voiture - cel-shaded car paint with shine and relief. Forward+, desktop; budget: 3 texture reads, no loops, no branches on texture data.
// Same 2-step lighting and uniforms as anime_cel_shaded.gdshader, so the team livery tint in GtCarActor (base_color) keeps working.
//   shine  : a hard clear-coat highlight band, strength from the baked roughness (orm texture, G channel)
//   emboss : the baked normal map shapes the highlight and the rim light only; the diffuse bands use the smooth geometric normal,
//            so the relief reads as raised panel lines and vents without turning the cel steps into blotches
//   ao     : baked ambient occlusion (orm texture, R channel) darkens cavities and panel gaps
// orm_texture is packed like the Porsche ORM: R = occlusion, G = roughness, B = metallic (unused here).

group_uniforms albedo;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 base_color : source_color = vec4(0.95, 0.95, 0.95, 1.0);

group_uniforms cel_shading;
uniform vec4 shadow_tint : source_color = vec4(0.14, 0.16, 0.24, 1.0);
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float shadow_smoothness : hint_range(0.001, 0.1) = 0.015;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.65;
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.4;
uniform vec4 rim_color : source_color = vec4(0.8, 1.0, 0.0, 1.0);

group_uniforms emboss;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_disable;
uniform bool use_normal_map = true;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform sampler2D orm_texture : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.7;

group_uniforms shine;
uniform vec4 spec_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float gloss_strength : hint_range(0.0, 2.0) = 1.0;
uniform float spec_size : hint_range(0.9, 0.9999) = 0.985; // cosine of the highlight half-angle: higher = smaller highlight
uniform float spec_smoothness : hint_range(0.0005, 0.05) = 0.006;

varying vec3 geo_normal;
varying float ao_term;
varying float gloss_term;

void fragment() {
	vec4 col = base_color;
	if (textureSize(albedo_texture, 0).x > 4) {
		col *= texture(albedo_texture, UV);
	}
	geo_normal = NORMAL;
	if (use_normal_map && textureSize(normal_texture, 0).x > 4) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	vec3 orm = texture(orm_texture, UV).rgb;
	ao_term = mix(1.0, orm.r, ao_strength);
	gloss_term = (1.0 - orm.g) * gloss_strength;
	ALBEDO = col.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
}

void light() {
	// 2-tone stepped diffuse on the geometric normal
	float n_dot_l = dot(geo_normal, LIGHT);
	float stepped_light = smoothstep(shadow_threshold - shadow_smoothness,
	                                 shadow_threshold + shadow_smoothness,
	                                 n_dot_l);
	vec3 shadow_component = mix(shadow_tint.rgb * ALBEDO, ALBEDO, 0.25);
	vec3 diffuse_light = mix(shadow_component, ALBEDO * LIGHT_COLOR, stepped_light) * ao_term;

	// hard rim light on the relief normal
	float n_dot_v = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	float rim = step(rim_threshold, n_dot_v * max(0.0, n_dot_l));
	vec3 rim_term = rim * rim_color.rgb * rim_intensity;

	// clear-coat highlight band on the relief normal, only where the surface faces the light
	float n_dot_h = max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0);
	float band = smoothstep(spec_size - spec_smoothness, spec_size + spec_smoothness, n_dot_h) * step(0.0, n_dot_l);

	DIFFUSE_LIGHT += (diffuse_light + rim_term) * ATTENUATION;
	SPECULAR_LIGHT += band * gloss_term * spec_color.rgb * LIGHT_COLOR * ATTENUATION;
}
