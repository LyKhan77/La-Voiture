// La Voiture - FASE 5 manga rain, 3D. One hard-edged ink-and-white streak per
// GPU particle. Authorship: Genex / La Voiture. Purpose: rain as real world
// geometry (parallax, occlusion by cars and road) drawn like manga speed lines.
// Each quad is stretched along the particle's velocity RELATIVE TO THE CAMERA,
// so a fast chase camera turns the rain into streaks that radiate from the
// vanishing point, and a stopped camera sees plain vertical rain.
// Target: Forward+/Mobile, spatial, unshaded. Budget: one hash + a handful of
// steps per vertex/pixel, no texture reads, no loops. Hard `step()` edges on
// purpose (cel-shaded, zero softness); an ink border keeps white streaks
// readable on both the bright sky and the dark road.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

group_uniforms motion;
// World-space velocity of a raindrop and of the camera; set by MangaRain3D.
uniform vec3 rain_velocity = vec3(0.0, -25.0, 0.0);
uniform vec3 camera_velocity = vec3(0.0);
// Exposure time: streak length = relative speed * shutter, clamped below.
uniform float shutter_s : hint_range(0.005, 0.2) = 0.045;
uniform float min_length_m : hint_range(0.1, 2.0) = 0.6;
uniform float max_length_m : hint_range(1.0, 20.0) = 3.5;
group_uniforms;

group_uniforms look;
uniform float width_m : hint_range(0.005, 0.2) = 0.02;
// Streaks widen with distance so far rain never shrinks below a readable line.
uniform float width_per_meter : hint_range(0.0, 0.05) = 0.004;
uniform float opacity : hint_range(0.0, 1.0) = 0.85;
// Share of the half-width taken by the ink border, 0 = no ink.
uniform float ink_width : hint_range(0.0, 0.8) = 0.34;
uniform vec4 streak_color : source_color = vec4(0.96, 0.97, 1.0, 1.0);
// Accent streaks echo the UI's electric cyan (#00F0FF).
uniform vec4 accent_color : source_color = vec4(0.0, 0.94, 1.0, 1.0);
uniform float accent_share : hint_range(0.0, 1.0) = 0.12;
uniform vec4 ink_color : source_color = vec4(0.02, 0.02, 0.03, 1.0);
group_uniforms;

const float NEAR_FADE_START_M = 3.0;
const float NEAR_FADE_END_M = 9.0;
const float FAR_FADE_START_M = 55.0;
const float FAR_FADE_END_M = 78.0;
const float TAIL_LENGTH_FRACTION = 0.8;
const float HEAD_LENGTH_FRACTION = 0.1;

varying float v_t;
varying float v_x;
varying float v_fade;
varying float v_accent;

float hash11(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	float id = float(INSTANCE_ID);
	float len_rnd = hash11(id);
	float accent_rnd = hash11(id + 71.0);

	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 to_camera = CAMERA_POSITION_WORLD - centre;
	float dist = length(to_camera);
	to_camera /= max(dist, 0.001);

	vec3 relative = rain_velocity - camera_velocity;
	float speed = length(relative);
	vec3 dir = speed > 0.001 ? relative / speed : vec3(0.0, -1.0, 0.0);
	// Quad width axis: perpendicular to both the streak and the view ray.
	vec3 side = cross(dir, to_camera);
	float side_len = length(side);
	side = side_len > 0.0001 ? side / side_len : vec3(1.0, 0.0, 0.0);

	float length_m = clamp(speed * shutter_s, min_length_m, max_length_m) * mix(0.7, 1.3, len_rnd);
	float half_width = 0.5 * (width_m + width_per_meter * dist) * mix(0.8, 1.2, hash11(id + 13.0));
	// VERTEX is the unit quad, x and y in [-0.5, 0.5].
	vec3 world = centre + dir * (VERTEX.y * length_m) + side * (VERTEX.x * 2.0 * half_width);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);

	v_t = VERTEX.y + 0.5;
	v_x = VERTEX.x * 2.0;
	v_fade = smoothstep(NEAR_FADE_START_M, NEAR_FADE_END_M, dist) * (1.0 - smoothstep(FAR_FADE_START_M, FAR_FADE_END_M, dist));
	v_accent = step(1.0 - accent_share, accent_rnd);
}

void fragment() {
	// Pointed tail, short pointed head: a brush stroke, not a pill.
	float profile = clamp(v_t / TAIL_LENGTH_FRACTION, 0.0, 1.0) * clamp((1.0 - v_t) / HEAD_LENGTH_FRACTION, 0.0, 1.0);
	float inside = step(abs(v_x), profile);
	float core = step(abs(v_x), profile - ink_width);
	vec3 fill = mix(streak_color.rgb, accent_color.rgb, v_accent);
	ALBEDO = mix(ink_color.rgb, fill, core);
	ALPHA = inside * v_fade * opacity;
}
