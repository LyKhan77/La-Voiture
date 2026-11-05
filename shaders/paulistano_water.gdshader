// La Voiture - Paulistano (FASE 26) Guarapiranga reservoir water, cel style.
// The water mesh carries the depth under every vertex in COLOR.r (0 = shoreline, 1 = 4 m and
// deeper), so the colour shelves from a sandy-green shallow to the deep reservoir blue and a
// broken white foam line laps at the shore, without a depth-texture read (works on every renderer).
// Two stepped tones in soft bands drift with the wind; no specular, so no white sun blob.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_disabled;

uniform vec3 deep_color : source_color = vec3(0.04, 0.24, 0.30);
uniform vec3 shallow_color : source_color = vec3(0.24, 0.48, 0.42);
uniform vec3 band_color : source_color = vec3(0.10, 0.36, 0.42);
uniform vec3 foam_color : source_color = vec3(0.93, 0.96, 0.94);
uniform float wind_speed_kph : hint_range(0.0, 60.0) = 12.0;
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float time_s = 0.0;
uniform float band_length_m : hint_range(2.0, 40.0) = 26.0;
uniform float band_strength : hint_range(0.0, 1.0) = 0.22;
// Depth (0..1 of 4 m) the foam reaches, and how far it breathes in and out.
uniform float foam_depth : hint_range(0.0, 0.3) = 0.04;
uniform float foam_swell : hint_range(0.0, 0.1) = 0.03;
uniform float glow : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;
varying float depth01;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	depth01 = COLOR.r;
}

void fragment() {
	vec2 dir = normalize(wind_dir + vec2(0.0001));
	vec2 across = vec2(-dir.y, dir.x);
	float speed = 0.25 + (wind_speed_kph / 45.0) * 1.1;
	vec2 p = world_pos.xz / band_length_m;
	// Two crossing swells at different scales, so the bands break up instead of reading as a stripe pattern.
	float phase = dot(p, dir) - time_s * speed * 0.3 + 0.55 * sin(dot(p, across) * 1.3 + time_s * 0.5) + 0.3 * sin(dot(p, dir + across) * 2.7 - time_s * 0.4);
	float band = step(0.62, fract(phase)) * band_strength;
	// Cel-stepped shelf: shallow, mid, deep in three hard tones.
	float shelf = floor(clamp(depth01 * 2.6, 0.0, 2.0) + 0.5) / 2.0;
	vec3 water = mix(shallow_color, deep_color, shelf);
	water = mix(water, band_color, band * (0.35 + 0.65 * shelf));
	// Foam: a broken line that breathes with the swell where the water meets the bank.
	float reach = foam_depth + foam_swell * sin(time_s * 1.3 + dot(world_pos.xz, vec2(0.11, 0.07)));
	// Long foam runs with short gaps (a lapping shoreline, not a dashed road line).
	float broken = step(0.12, fract(dot(world_pos.xz, across) * 0.035 + 0.5 * sin(dot(world_pos.xz, dir) * 0.05) + time_s * 0.03));
	float foam = (1.0 - step(reach, depth01)) * broken;
	ALBEDO = mix(water, foam_color, foam);
	EMISSION = (water * 0.12 + foam_color * foam * 0.15) * (1.0 + glow * 2.0);
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}
