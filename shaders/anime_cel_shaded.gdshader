shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform sampler2D livery_texture : source_color, filter_nearest;
uniform bool use_livery = false;
uniform vec4 base_color : source_color = vec4(0.95, 0.95, 0.95, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.14, 0.16, 0.24, 1.0); // Bayangan manga beraksen biru-gelap
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float shadow_smoothness : hint_range(0.001, 0.1) = 0.015; // Batas tegas anime (Zero Softness)
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.65;
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.4;
uniform vec4 rim_color : source_color = vec4(0.8, 1.0, 0.0, 1.0); // Aksen rim light Acid Lime

void fragment() {
	vec4 col = base_color;
	if (textureSize(albedo_texture, 0).x > 4) {
		col *= texture(albedo_texture, UV);
	}
	if (use_livery && textureSize(livery_texture, 0).x > 4) {
		vec4 liv = texture(livery_texture, UV);
		col.rgb = mix(col.rgb, liv.rgb, liv.a);
	}
	
	ALBEDO = col.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
}

void light() {
	// 2-Tone Stepped Diffuse Lighting
	float n_dot_l = dot(NORMAL, LIGHT);
	float stepped_light = smoothstep(shadow_threshold - shadow_smoothness, 
	                                 shadow_threshold + shadow_smoothness, 
	                                 n_dot_l);
	
	vec3 shadow_component = mix(shadow_tint.rgb * ALBEDO, ALBEDO, 0.25);
	vec3 diffuse_light = mix(shadow_component, ALBEDO * LIGHT_COLOR, stepped_light);
	
	// Anime Hard Rim Light (Glow tepi kontur komik)
	float n_dot_v = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	float rim = step(rim_threshold, n_dot_v * max(0.0, n_dot_l));
	vec3 rim_term = rim * rim_color.rgb * rim_intensity;
	
	DIFFUSE_LIGHT += (diffuse_light + rim_term) * ATTENUATION;
}
