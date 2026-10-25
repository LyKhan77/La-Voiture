shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform vec4 team_color : source_color = vec4(0.85, 0.15, 0.2, 1.0);
uniform vec4 accent_color : source_color = vec4(0.95, 0.95, 0.95, 1.0);
uniform float suit_color_strength : hint_range(0.0, 1.0) = 0.65;
uniform vec4 shadow_tint : source_color = vec4(0.12, 0.14, 0.22, 1.0);
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.42;
uniform float shadow_smoothness : hint_range(0.001, 0.1) = 0.02;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.60;
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.45;
uniform vec4 rim_color : source_color = vec4(0.85, 1.0, 0.0, 1.0); // Acid lime manga rim light

void fragment() {
	vec4 base_tex = texture(albedo_texture, UV);
	
	// Luminance of base texture
	float lum = dot(base_tex.rgb, vec3(0.299, 0.587, 0.114));
	
	// Suit fabric areas are mid-tones to light tones (lum between 0.22 and 0.85).
	// Very dark areas (lum < 0.2) are black boots, knee pads, gloves, dark harness belts, and visor.
	// Very bright areas (lum > 0.88) are white racing stripes.
	float is_dark_gear = 1.0 - smoothstep(0.16, 0.24, lum);
	float is_stripe = smoothstep(0.86, 0.94, lum);
	float is_suit = (1.0 - is_dark_gear) * (1.0 - is_stripe);
	
	// Tint suit fabric with team color
	vec3 tinted_suit = mix(base_tex.rgb, team_color.rgb * lum * 1.35, suit_color_strength);
	vec3 final_rgb = mix(tinted_suit, base_tex.rgb, is_dark_gear);
	final_rgb = mix(final_rgb, accent_color.rgb, is_stripe * 0.8);
	
	ALBEDO = final_rgb;
	ROUGHNESS = mix(0.75, 0.1, is_dark_gear * step(0.6, 1.0 - lum)); // Visor is glossy
	SPECULAR = mix(0.1, 0.8, is_dark_gear);
	
	if (textureSize(normal_texture, 0).x > 4) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
	}
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	float stepped_light = smoothstep(shadow_threshold - shadow_smoothness, 
	                                 shadow_threshold + shadow_smoothness, 
	                                 n_dot_l);
	
	vec3 shadow_component = mix(shadow_tint.rgb * ALBEDO, ALBEDO, 0.25);
	vec3 diffuse_light = mix(shadow_component, ALBEDO * LIGHT_COLOR, stepped_light);
	
	// Manga hard rim light
	float n_dot_v = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	float rim = step(rim_threshold, n_dot_v * max(0.0, n_dot_l));
	vec3 rim_term = rim * rim_color.rgb * rim_intensity;
	
	DIFFUSE_LIGHT += (diffuse_light + rim_term) * ATTENUATION;
}
