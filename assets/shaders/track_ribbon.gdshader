// La Voiture - FASE 5 wet asphalt for the 3D track ribbon (PRD 01 wetness grip).
// Authorship: Genex / La Voiture. Purpose: drives the ribbon road mesh from the
// WeatherManager so a rising `track_wetness` darkens the asphalt and turns it
// into a mirror, with puddles that join up as it gets wetter.
// Target: Forward+, spatial, one road mesh. Budget: 2-octave hash noise, no
// texture reads, no branches. Vertex colors carry the lane/edge/start-line paint
// (same data the StandardMaterial3D used), so they are kept as albedo.
shader_type spatial;
render_mode cull_disabled;

group_uniforms wetness;
// 0 = bone dry, 1 = fully wet. Set from WeatherManager.get_wetness_pct().
uniform float track_wetness : hint_range(0.0, 1.0) = 0.0;
uniform float dry_roughness : hint_range(0.0, 1.0) = 0.85;
// Mirror finish at full wetness (spec: 0.85 dry -> 0.15 wet).
uniform float wet_roughness : hint_range(0.0, 1.0) = 0.15;
uniform float wet_darkening : hint_range(0.0, 1.0) = 0.45;
group_uniforms;

group_uniforms puddles;
// Puddle size: noise cells per meter of track.
uniform float puddle_scale : hint_range(0.01, 1.0) = 0.08;
// How far a damp (non-puddle) patch is from a puddle at the same wetness.
uniform float damp_floor : hint_range(0.0, 1.0) = 0.45;
uniform float puddle_edge : hint_range(0.01, 0.5) = 0.10;
group_uniforms;

group_uniforms rain;
// 0 = no rain falling, 1 = downpour: how many drops land per second.
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float ripple_cell_m : hint_range(0.5, 6.0) = 2.0;
uniform float ripple_max_radius_m : hint_range(0.1, 1.2) = 0.32;
uniform float ripple_cycle_hz : hint_range(0.2, 4.0) = 1.4;
uniform float ripple_frames : hint_range(2.0, 8.0) = 4.0;
uniform float ripple_line_m : hint_range(0.01, 0.2) = 0.03;
group_uniforms;

const float DRY_SPECULAR = 0.5;
const float WET_SPECULAR = 1.0;
const vec3 RIPPLE_COLOR = vec3(0.96, 0.97, 1.0);
const vec3 RIPPLE_GLOW = vec3(0.0, 0.94, 1.0); // UI electric cyan
const float RIPPLE_GLOW_STRENGTH = 0.12;
// Ripples need a film of water to show; they fade in over this wetness range.
const float RIPPLE_MIN_WETNESS = 0.02;
const float RIPPLE_FULL_WETNESS = 0.2;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Bilinear value noise, smoothed so puddle edges have no grid creases.
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

float hash11(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// One splash ring per grid cell, drawn on the road surface in world space so it
// is perspective-correct. Animated "on fours" (hard frames, like hand-drawn anime
// rain) with a hard-edged ring; the cell only rains when `rain_intensity` beats
// its own random threshold, so a drizzle has fewer drops than a downpour.
float splash_ring(vec2 p, float cell_m, float seed) {
	vec2 cell = floor(p / cell_m);
	float id = cell.x * 127.1 + cell.y * 311.7 + seed;
	vec2 local = p - cell * cell_m;
	// Keep the ring centre far enough from the cell edge that it never gets cut.
	vec2 centre = cell_m * vec2(0.5) + (vec2(hash11(id + 1.0), hash11(id + 2.0)) - 0.5) * (cell_m - 2.0 * ripple_max_radius_m);
	float phase = fract(TIME * ripple_cycle_hz * mix(0.7, 1.3, hash11(id + 3.0)) + hash11(id + 4.0));
	float frame = floor(phase * ripple_frames);
	float radius = ripple_max_radius_m * (frame + 1.0) / ripple_frames;
	float ring = step(abs(length(local - centre) - radius), ripple_line_m * (1.0 - 0.5 * frame / ripple_frames));
	return ring * step(hash11(id + 5.0), rain_intensity);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * puddle_scale;
	float noise = 0.65 * value_noise(uv) + 0.35 * value_noise(uv * 2.7 + 17.0);
	// Wetter track -> lower threshold -> more of the noise field is puddle.
	float threshold = 1.0 - track_wetness * 1.2;
	float puddle = smoothstep(threshold - puddle_edge, threshold + puddle_edge, noise);
	float wet_amount = track_wetness * mix(damp_floor, 1.0, puddle);

	float splash = max(splash_ring(world_pos.xz, ripple_cell_m, 0.0), splash_ring(world_pos.xz + 7.3, ripple_cell_m * 0.7, 91.0));
	splash *= smoothstep(RIPPLE_MIN_WETNESS, RIPPLE_FULL_WETNESS, track_wetness);

	ALBEDO = mix(COLOR.rgb * (1.0 - wet_darkening * wet_amount), RIPPLE_COLOR, splash);
	EMISSION = RIPPLE_GLOW * RIPPLE_GLOW_STRENGTH * splash;
	ROUGHNESS = mix(dry_roughness, wet_roughness, wet_amount);
	SPECULAR = mix(DRY_SPECULAR, WET_SPECULAR, wet_amount);
	METALLIC = 0.0;
}
