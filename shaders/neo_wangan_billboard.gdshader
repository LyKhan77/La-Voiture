// La Voiture - Neo-Wangan (FASE 12.2) street billboards.
// Purpose: one box per sign, tinted by its MultiMesh instance colour. The face is painted in the
// shader: a halftone screentone gradient, four Kanji-style stroke blocks on dark ink, a sub-banner
// stripe and a thick comic frame. Front and back faces carry the sign; the box edges stay dark ink.
shader_type spatial;
render_mode cull_back, unshaded;

// Size of the BoxMesh the sign is drawn on (x, y), used to turn vertex position into face UV.
const vec2 BOARD_SIZE = vec2(10.0, 5.5);
const vec3 DARK_INK = vec3(0.04, 0.06, 0.10);

varying vec3 inst_color;
varying vec2 face_uv;
varying float is_front_or_back;

float hash21(vec2 p) {
	p = fract(p * vec2(234.17, 512.83));
	p += dot(p, p + 33.7);
	return fract(p.x * p.y);
}

void vertex() {
	inst_color = COLOR.rgb;
	face_uv = VERTEX.xy / BOARD_SIZE + vec2(0.5);
	is_front_or_back = step(0.5, abs(NORMAL.z));
}

void fragment() {
	if (is_front_or_back < 0.5) {
		ALBEDO = vec3(0.06, 0.08, 0.13);
	} else {
		vec2 uv = clamp(face_uv, 0.0, 1.0);
		float border = step(0.05, uv.x) * step(uv.x, 0.95) * step(0.08, uv.y) * step(uv.y, 0.92);
		// Halftone diagonal gradient background.
		vec2 dot_grid = fract(uv * vec2(28.0, 16.0)) - vec2(0.5);
		float dots = step(length(dot_grid), (1.0 - uv.y) * 0.42);
		// Procedural Kanji / streetwear glyph cells (4 character blocks across the sign).
		vec2 char_space = vec2(uv.x * 5.0 - 0.5, (uv.y - 0.24) * 2.1);
		float in_char_row = step(0.0, char_space.x) * step(char_space.x, 4.0) * step(0.0, char_space.y) * step(char_space.y, 1.0);
		vec2 c_id = floor(vec2(char_space.x, 0.0));
		vec2 c_uv = fract(char_space);
		// 5x5 stroke matrix per Kanji block.
		vec2 stroke_cell = floor(c_uv * 5.0);
		float pad = step(0.12, c_uv.x) * step(c_uv.x, 0.88) * step(0.10, c_uv.y) * step(c_uv.y, 0.90);
		float h_bar = step(abs(stroke_cell.y - 1.0), 0.1) + step(abs(stroke_cell.y - 3.0), 0.1);
		float v_bar = step(abs(stroke_cell.x - 2.0), 0.1);
		float rand_stroke = step(0.42, hash21(stroke_cell + c_id * 7.0 + floor(inst_color.rg * 13.0)));
		float kanji_glyph = clamp(h_bar * 0.6 + v_bar * 0.6 + rand_stroke, 0.0, 1.0) * pad * in_char_row;
		// Bottom sub-banner stripe.
		float sub_stripe = step(0.12, uv.x) * step(uv.x, 0.88) * step(0.12, uv.y) * step(uv.y, 0.19);
		vec3 bg = mix(inst_color * 0.85, inst_color * 0.45, dots * 0.5);
		vec3 face = mix(bg, DARK_INK, clamp(kanji_glyph + sub_stripe, 0.0, 1.0));
		// Bright white kanji highlight on the dark ink.
		float inner_glyph = kanji_glyph * step(0.22, fract(c_uv.x * 5.0)) * step(0.22, fract(c_uv.y * 5.0));
		face = mix(face, vec3(0.98, 0.99, 1.0), inner_glyph * 0.85);
		ALBEDO = mix(DARK_INK, face, border);
	}
}
