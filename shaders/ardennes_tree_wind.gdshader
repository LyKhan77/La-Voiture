shader_type spatial;
render_mode diffuse_toon, specular_toon;

// Ardennes biome wind: the vertex-colour cel shader plus a height-weighted sway so
// the MultiMesh pine canopy breathes without a per-tree CPU cost.

group_uniforms look;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 albedo_floor = vec3(0.0);
uniform vec4 shadow_tint : source_color = vec4(0.44, 0.54, 0.48, 1.0);
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float shadow_smoothness : hint_range(0.001, 0.1) = 0.015;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.65;
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.12;
uniform vec4 rim_color : source_color = vec4(0.72, 0.88, 0.78, 1.0);
group_uniforms;

group_uniforms wind;
uniform float wind_strength = 0.35;
uniform float wind_speed = 1.35;
uniform float sway_height_m = 16.0;
group_uniforms;

const float ROUGHNESS_VALUE = 0.9;
const float SPECULAR_VALUE = 0.05;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height = clamp(VERTEX.y / sway_height_m, 0.0, 1.0);
	height *= height;
	float phase = world.x * 0.045 + world.z * 0.031;
	VERTEX.x += sin(TIME * wind_speed + phase) * wind_strength * height;
	VERTEX.z += cos(TIME * wind_speed * 0.77 + phase * 1.31) * wind_strength * 0.7 * height;
}

void fragment() {
	ALBEDO = max(COLOR.rgb * tint.rgb, albedo_floor);
	ROUGHNESS = ROUGHNESS_VALUE;
	SPECULAR = SPECULAR_VALUE;
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	float stepped = smoothstep(shadow_threshold - shadow_smoothness, shadow_threshold + shadow_smoothness, n_dot_l);
	vec3 shadow_component = mix(shadow_tint.rgb * ALBEDO, ALBEDO, 0.25);
	vec3 diffuse_light = mix(shadow_component, ALBEDO * LIGHT_COLOR, stepped);
	float n_dot_v = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	float rim = step(rim_threshold, n_dot_v * max(0.0, n_dot_l));
	DIFFUSE_LIGHT += (diffuse_light + rim * rim_color.rgb * rim_intensity) * ATTENUATION;
}
