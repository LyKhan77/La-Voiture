// La Voiture - Neo-Wangan (FASE 12.2) wind banners.
// Purpose: a vertical street banner pinned to a lamp pole along its left edge. The free edge waves
// with a vertex sine whose frequency and amplitude grow with wind_speed_kph (race.weather); each
// instance gets its own phase from INSTANCE_ID so a row of banners never flaps in lockstep.
shader_type spatial;
render_mode cull_disabled, unshaded;

uniform float wind_speed_kph : hint_range(0.0, 60.0) = 14.0;
uniform float time_s = 0.0;

// BoxMesh banner is 0.9 m wide: x runs -0.45 (pole edge) .. 0.45 (free edge).
const float BANNER_HALF_WIDTH = 0.45;
// Wind at which the flap reaches its full storm frequency and amplitude.
const float STORM_KPH = 45.0;

varying vec3 banner_col;
varying float banner_y;

void vertex() {
	banner_col = COLOR.rgb;
	banner_y = VERTEX.y;
	float free_edge = clamp((VERTEX.x + BANNER_HALF_WIDTH) / (BANNER_HALF_WIDTH * 2.0), 0.0, 1.0);
	float gust = wind_speed_kph / STORM_KPH;
	float freq = 3.5 + gust * 6.5;
	float amp = 0.06 + gust * 0.24;
	float wave = sin(time_s * freq + VERTEX.y * 2.8 + float(INSTANCE_ID) * 1.7) * amp * free_edge;
	VERTEX.z += wave;
}

void fragment() {
	// Dark cross stripes every 0.8 m, the cel shorthand for a printed pennant.
	float stripe = step(0.68, fract(banner_y * 1.25 + 0.5));
	ALBEDO = mix(banner_col, vec3(0.05, 0.07, 0.11), stripe * 0.7);
}
