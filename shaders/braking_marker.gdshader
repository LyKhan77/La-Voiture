// La Voiture - FASE 10 braking distance board face (150 / 100 / 50 m).
// Authorship: Genex / La Voiture. Purpose: draws the distance as 7-segment digits from
// the per-instance custom data, so every board of every corner is ONE MultiMesh draw
// call instead of one text node each. Instance custom data x = distance in meters.
// Target: Forward+, spatial. Budget: no texture reads, a handful of rectangle tests.
shader_type spatial;
render_mode unshaded;

group_uniforms look;
uniform vec3 board_color : source_color = vec3(0.96, 0.96, 0.94);
uniform vec3 digit_color : source_color = vec3(0.04, 0.04, 0.05);
// Boards are retro-reflective, so they stay readable at night; 1 = daylight white.
uniform float board_brightness : hint_range(0.05, 1.5) = 1.0;
group_uniforms;

// Segment bits a..g of digits 0..9 (bit 0 = a top, 1 = b upper right, 2 = c lower right,
// 3 = d bottom, 4 = e lower left, 5 = f upper left, 6 = g middle).
const int SEGMENTS[10] = int[10](0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F);
const float HALF_THICKNESS = 0.09;
const float HALF_LONG = 0.22;
// Digits use this much of their slot, leaving a margin around the board edge.
const vec2 SLOT_FILL = vec2(0.8, 0.72);

varying flat float distance_m;

float seg_rect(vec2 p, vec2 centre, vec2 half_size) {
	vec2 d = abs(p - centre) - half_size;
	return step(max(d.x, d.y), 0.0);
}

float digit(vec2 p, int value) {
	int mask = SEGMENTS[value];
	float on = 0.0;
	on += float(mask & 1) * seg_rect(p, vec2(0.5, 0.9), vec2(HALF_LONG + 0.06, HALF_THICKNESS));
	on += float((mask >> 1) & 1) * seg_rect(p, vec2(0.82, 0.7), vec2(HALF_THICKNESS, HALF_LONG));
	on += float((mask >> 2) & 1) * seg_rect(p, vec2(0.82, 0.3), vec2(HALF_THICKNESS, HALF_LONG));
	on += float((mask >> 3) & 1) * seg_rect(p, vec2(0.5, 0.1), vec2(HALF_LONG + 0.06, HALF_THICKNESS));
	on += float((mask >> 4) & 1) * seg_rect(p, vec2(0.18, 0.3), vec2(HALF_THICKNESS, HALF_LONG));
	on += float((mask >> 5) & 1) * seg_rect(p, vec2(0.18, 0.7), vec2(HALF_THICKNESS, HALF_LONG));
	on += float((mask >> 6) & 1) * seg_rect(p, vec2(0.5, 0.5), vec2(HALF_LONG + 0.06, HALF_THICKNESS));
	return clamp(on, 0.0, 1.0);
}

void vertex() {
	distance_m = INSTANCE_CUSTOM.x;
}

void fragment() {
	int number = int(distance_m + 0.5);
	int count = number >= 100 ? 3 : 2;
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float slot = floor(uv.x * float(count));
	int place = count - 1 - int(slot);
	int divisor = place == 2 ? 100 : (place == 1 ? 10 : 1);
	int value = (number / divisor) % 10;
	vec2 local = vec2(fract(uv.x * float(count)), uv.y);
	vec2 p = (local - vec2(0.5)) / SLOT_FILL + vec2(0.5);
	float ink = digit(p, value) * step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0);
	ALBEDO = mix(board_color, digit_color, ink) * board_brightness;
}
