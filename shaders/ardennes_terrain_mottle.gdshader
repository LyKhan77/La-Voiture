shader_type spatial;
render_mode diffuse_toon, specular_toon;

// Ardennes terrain surface: vertex-colour cel terrain with a stepped world-space
// mottle so the flat verges and large hills read as grass/rock instead of a pale
// flat plane. No texture reads; one draw call for the whole heightfield.

group_uniforms look;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 albedo_floor = vec3(0.0);
uniform vec4 shadow_tint : source_color = vec4(0.34, 0.44, 0.40, 1.0);
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float shadow_smoothness : hint_range(0.001, 0.1) = 0.015;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.65;
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.0;
uniform vec4 rim_color : source_color = vec4(0.8, 1.0, 0.8, 1.0);
group_uniforms;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n1 = value_noise(world_pos.xz * 0.055);
	float n2 = value_noise(world_pos.xz * 0.42 + 11.0);
	float n = 0.62 * n1 + 0.38 * n2;
	// Cel steps: three grass tones, never a smooth gradient.
	float band = floor(n * 3.0) / 2.0;
	vec3 grass_tint = mix(vec3(0.82, 0.94, 0.80), vec3(1.07, 1.04, 0.94), band);
	ALBEDO = max(COLOR.rgb * tint.rgb * grass_tint, albedo_floor);
	ROUGHNESS = 0.9;
	SPECULAR = 0.05;
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	float stepped_light = smoothstep(shadow_threshold - shadow_smoothness, shadow_threshold + shadow_smoothness, n_dot_l);
	vec3 shadow_component = mix(shadow_tint.rgb * ALBEDO, ALBEDO, 0.25);
	vec3 diffuse_light = mix(shadow_component, ALBEDO * LIGHT_COLOR, stepped_light);
	float n_dot_v = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	float rim = step(rim_threshold, n_dot_v * max(0.0, n_dot_l));
	DIFFUSE_LIGHT += (diffuse_light + rim * rim_color.rgb * rim_intensity) * ATTENUATION;
}
