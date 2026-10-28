// La Voiture - FASE 10 cel shader for merged set dressing (buildings, towers, furniture).
// Authorship: Genex / La Voiture. Purpose: the same 2-tone anime lighting as
// anime_cel_shaded.gdshader, but the albedo comes from vertex colours so a whole
// building or tower is ONE surface (one draw call) instead of one material per colour.
// Vertex alpha is a glow mask: 1.0 = plain paint, 0.0 = fully self-lit (floodlight lenses),
// in between = dim self-lit (office windows). `glow_energy` is driven by the circuit
// lighting controller (0 by day, up at night), so every building lights up together.
// Target: Forward+, spatial. Budget: no texture reads, no branches.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

group_uniforms look;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 albedo_floor = vec3(0.0);
uniform vec4 shadow_tint : source_color = vec4(0.14, 0.16, 0.24, 1.0);
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float shadow_smoothness : hint_range(0.001, 0.1) = 0.015;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.65;
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.15;
uniform vec4 rim_color : source_color = vec4(0.8, 1.0, 0.0, 1.0);
group_uniforms;

group_uniforms glow;
// Emission multiplier for glow-masked vertices; windows and lenses light up at night.
uniform float glow_energy : hint_range(0.0, 16.0) = 0.0;
group_uniforms;

const float ROUGHNESS_VALUE = 0.85;
const float SPECULAR_VALUE = 0.15;
const float SHADOW_ALBEDO_MIX = 0.25;

void fragment() {
	ALBEDO = max(COLOR.rgb * tint.rgb, albedo_floor);
	EMISSION = ALBEDO * (1.0 - COLOR.a) * glow_energy;
	ROUGHNESS = ROUGHNESS_VALUE;
	SPECULAR = SPECULAR_VALUE;
}

void light() {
	// 2-tone stepped diffuse, identical to the car/set shader.
	float n_dot_l = dot(NORMAL, LIGHT);
	float stepped_light = smoothstep(shadow_threshold - shadow_smoothness, shadow_threshold + shadow_smoothness, n_dot_l);
	vec3 shadow_component = mix(shadow_tint.rgb * ALBEDO, ALBEDO, SHADOW_ALBEDO_MIX);
	vec3 diffuse_light = mix(shadow_component, ALBEDO * LIGHT_COLOR, stepped_light);
	float n_dot_v = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	float rim = step(rim_threshold, n_dot_v * max(0.0, n_dot_l));
	DIFFUSE_LIGHT += (diffuse_light + rim * rim_color.rgb * rim_intensity) * ATTENUATION;
}
