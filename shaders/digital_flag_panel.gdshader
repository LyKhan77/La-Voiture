// La Voiture - FASE 11 Langkah 6 FIA digital trackside flag panel.
// Authorship: Genex / La Voiture. Purpose: a dot-matrix LED face for every flag panel of the circuit as ONE
// MultiMesh draw call. Instance custom data x = state: 0 green (dim, steady), 1 yellow (4 Hz chevrons),
// 2 safety car (alternating yellow / orange "SC").
// Target: Forward+, spatial. Budget: no texture reads, a handful of integer bit tests per pixel.
shader_type spatial;
render_mode cull_disabled;

group_uniforms look;
uniform vec3 green_led : source_color = vec3(0.0, 0.878, 0.541);
uniform vec3 yellow_led : source_color = vec3(1.0, 0.902, 0.0);
uniform vec3 orange_led : source_color = vec3(1.0, 0.45, 0.0);
uniform float green_energy : hint_range(0.0, 4.0) = 0.2;
uniform float yellow_energy : hint_range(0.0, 8.0) = 2.5;
uniform float unlit_energy : hint_range(0.0, 0.2) = 0.015;
uniform float blink_hz : hint_range(0.5, 8.0) = 4.0;
group_uniforms;

const vec2 GRID = vec2(30.0, 20.0);
// 5x7 glyph rows, bit 4 = leftmost LED; drawn at 2x so "SC" is 22 x 14 LEDs.
const int GLYPH_S[7] = int[7](0x0E, 0x11, 0x10, 0x0E, 0x01, 0x11, 0x0E);
const int GLYPH_C[7] = int[7](0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E);
const ivec2 GLYPH_ORIGIN = ivec2(4, 3);

varying flat float state;

void vertex() {
	state = INSTANCE_CUSTOM.x;
}

// 1 where the LED at `id` belongs to the 2x scaled glyph whose left edge is `left`.
float glyph_pixel(int rows[7], ivec2 id, int left) {
	ivec2 g = (id - ivec2(left, GLYPH_ORIGIN.y)) / 2;
	if (id.x < left || id.y < GLYPH_ORIGIN.y || g.x > 4 || g.y > 6) {
		return 0.0;
	}
	// The LED rows count up from the bottom of the face while the glyph tables list the top row first.
	return float((rows[6 - g.y] >> (4 - g.x)) & 1);
}

void fragment() {
	vec2 cell = vec2(UV.x, 1.0 - UV.y) * GRID;
	ivec2 id = ivec2(floor(cell));
	float led = 1.0 - smoothstep(0.30, 0.42, length(fract(cell) - vec2(0.5)));
	int mode = int(state + 0.5);
	vec3 colour = vec3(0.0);
	float lit = 0.0;
	if (mode == 0) {
		colour = green_led * green_energy;
		lit = 1.0;
	} else if (mode == 1) {
		// Two right-pointing chevrons; the whole face blinks.
		float arm = abs(float(id.y) - 9.5);
		float chevron = 0.0;
		for (int index = 0; index < 2; index++) {
			chevron = max(chevron, 1.0 - step(1.2, abs(float(id.x) - (13.0 + float(index) * 8.0 - arm * 0.9))));
		}
		lit = chevron * step(fract(TIME * blink_hz), 0.5);
		colour = yellow_led * yellow_energy;
	} else {
		float phase = step(fract(TIME * blink_hz * 0.5), 0.5);
		lit = max(glyph_pixel(GLYPH_S, id, GLYPH_ORIGIN.x), glyph_pixel(GLYPH_C, id, GLYPH_ORIGIN.x + 12));
		colour = mix(yellow_led, orange_led, phase) * yellow_energy;
	}
	ALBEDO = vec3(0.01);
	ROUGHNESS = 0.4;
	EMISSION = (colour * lit + vec3(unlit_energy)) * led;
}
