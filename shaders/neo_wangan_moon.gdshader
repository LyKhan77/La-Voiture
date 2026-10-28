// La Voiture - Neo-Wangan (FASE 12.2) anime moon.
// Purpose: one camera-facing quad that paints the whole moon: a flat pale-yellow disc, a halftone
// screentone shadow limb with crater dots, and two stepped halo rings in silver-cyan. Unshaded and
// fog-free so it sits behind the haze of the city at any camera angle.
shader_type spatial;
render_mode blend_mix, unshaded, fog_disabled, depth_draw_never, cull_disabled;

uniform vec3 moon_color : source_color = vec3(1.0, 0.973, 0.84);
uniform vec3 moon_shade : source_color = vec3(0.78, 0.82, 0.74);
uniform vec3 halo_color : source_color = vec3(0.62, 0.86, 1.0);
// Disc radius as a fraction of the quad (0.5 = quad edge); the halo rings fill the rest.
uniform float disc_radius : hint_range(0.1, 0.5) = 0.30;
uniform float halo_inner_alpha : hint_range(0.0, 1.0) = 0.38;
uniform float halo_outer_alpha : hint_range(0.0, 1.0) = 0.16;
uniform float crater_density : hint_range(0.0, 1.0) = 0.34;

float hash21(vec2 p) {
	p = fract(p * vec2(197.31, 311.77));
	p += dot(p, p + 27.13);
	return fract(p.x * p.y);
}

void vertex() {
	// Camera-facing billboard that keeps the quad's own scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	float disc = step(r, disc_radius);
	float ring_inner = step(r, disc_radius * 1.28) * (1.0 - disc);
	float ring_outer = step(r, disc_radius * 1.62) * (1.0 - step(r, disc_radius * 1.28));
	// Shadow limb: the lower-right of the disc is screened with halftone dots instead of a gradient.
	float limb = step(0.12, dot(p / disc_radius, normalize(vec2(0.7, 0.7))));
	vec2 dot_cell = fract(p * 70.0) - vec2(0.5);
	float screen = step(length(dot_cell), 0.34);
	// Craters: a handful of dark discs picked by hash on a coarse grid.
	vec2 crater_grid = p * 9.0;
	vec2 crater_id = floor(crater_grid);
	vec2 crater_local = fract(crater_grid) - vec2(0.5);
	float crater = step(1.0 - crater_density, hash21(crater_id)) * step(length(crater_local), 0.26);
	vec3 face = mix(moon_color, moon_shade, max(crater, limb * screen));
	vec3 col = mix(halo_color, face, disc);
	float alpha = disc + ring_inner * halo_inner_alpha + ring_outer * halo_outer_alpha;
	ALBEDO = col;
	ALPHA = alpha;
}
