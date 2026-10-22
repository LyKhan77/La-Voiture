// La Voiture - FASE 10 cel-shaded foliage with soft wind sway.
// Authorship: Genex / La Voiture. Purpose: the same two-tone anime lighting as the rest of
// the set dressing, with vertex colour albedo and a vertex-shader sway driven by the world
// wind. Vertex alpha is the sway weight (0 = trunk base, 1 = crest), so trunks stand still
// and canopies lean and flutter. The wind direction is world space and every tree is phased
// by its own position, so gusts sweep across the circuit instead of the forest nodding together.
// Target: Forward+, spatial, MultiMesh instanced. Budget: ~20 ALU ops per vertex, no texture reads.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

group_uniforms wind;
// Sway of the crest in meters at weight 1; the lighting controller scales it with the weather.
uniform float wind_amplitude : hint_range(0.0, 1.0) = 0.12;
uniform float wind_speed : hint_range(0.0, 8.0) = 1.6;
uniform vec2 wind_direction = vec2(1.0, 0.4);
// Spatial frequency of gusts across the world (rad per meter along the wind).
uniform float gust_scale : hint_range(0.001, 0.2) = 0.018;
uniform float flutter : hint_range(0.0, 1.0) = 0.25;
group_uniforms;

group_uniforms look;
uniform vec4 shadow_tint : source_color = vec4(0.12, 0.17, 0.22, 1.0);
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float shadow_smoothness : hint_range(0.001, 0.1) = 0.015;
group_uniforms;

const float GUST_SECOND_HARMONIC = 2.3;
const float FLUTTER_SPEED = 5.0;
const float DIP_SHARE = 0.25;

void vertex() {
	float weight = COLOR.a;
	vec3 anchor = MODEL_MATRIX[3].xyz;
	vec2 dir = normalize(wind_direction);
	float phase = dot(anchor.xz, dir) * gust_scale * 6.2831853;
	float gust = 0.7 * sin(TIME * wind_speed + phase) + 0.3 * sin(TIME * wind_speed * GUST_SECOND_HARMONIC + phase * 1.7);
	// World wind direction brought into the instance's local space (uniform scale assumed).
	vec3 local_dir = transpose(mat3(MODEL_MATRIX)) * vec3(dir.x, 0.0, dir.y);
	local_dir /= dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz);
	float push = gust * wind_amplitude * weight;
	VERTEX += vec3(local_dir.x, 0.0, local_dir.z) * push;
	VERTEX.y -= abs(push) * DIP_SHARE;
	// Per-vertex leaf flutter on top of the lean.
	float jitter = sin(TIME * wind_speed * FLUTTER_SPEED + VERTEX.y * 3.1 + anchor.x) * flutter * wind_amplitude * 0.3 * weight;
	VERTEX.x += jitter;
	VERTEX.z -= jitter;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	float stepped = smoothstep(shadow_threshold - shadow_smoothness, shadow_threshold + shadow_smoothness, n_dot_l);
	vec3 shadow_part = mix(shadow_tint.rgb * ALBEDO, ALBEDO, 0.25);
	DIFFUSE_LIGHT += mix(shadow_part, ALBEDO * LIGHT_COLOR, stepped) * ATTENUATION;
}
