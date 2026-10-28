// La Voiture - Neo-Wangan (FASE 12.2) cel-shaded Tokyo skyline.
// Purpose: window grids on the night skyline without textures — one box per tower, one draw call
// for the whole ring. Windows are cut in world space on the vertical faces, so the same mesh works
// at every building scale. Toon diffuse, a night gradient up each tower, halftone-screened glass and
// a neon roofline make the towers read as inked manga backgrounds; the ink hull is the next_pass.
shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon;

uniform vec3 building_color = vec3(0.045, 0.055, 0.085);
uniform vec3 building_top_tint = vec3(0.09, 0.12, 0.20);
uniform vec3 window_cool = vec3(0.0, 0.94, 1.0);
uniform vec3 window_warm = vec3(1.0, 0.62, 0.22);
uniform vec3 roof_neon_color = vec3(1.0, 0.12, 0.46);
uniform float window_energy : hint_range(0.0, 8.0) = 1.9;
uniform vec2 window_cell = vec2(4.6, 3.2);
uniform float lit_fraction : hint_range(0.0, 1.0) = 0.32;

varying vec3 world_pos;
varying float local_y;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The tower is a unit box scaled per instance: -0.5..0.5 becomes 0 (base) .. 1 (roof).
	local_y = VERTEX.y + 0.5;
}

void fragment() {
	vec3 abs_normal = abs(NORMAL);
	// Roofs and floors are dark: windows only exist on the four vertical faces.
	float wall = step(abs_normal.y, 0.5);
	vec2 uv = abs_normal.x > abs_normal.z ? world_pos.zy : world_pos.xy;
	vec2 cells = uv / window_cell;
	vec2 cell = floor(cells);
	vec2 local = fract(cells);
	float pane = step(0.20, local.x) * step(local.x, 0.80) * step(0.26, local.y) * step(local.y, 0.76);
	// Halftone screen inside each lit pane, for the manga feel.
	vec2 dot_uv = fract(local * vec2(3.0, 2.0)) - vec2(0.5);
	float halftone = step(length(dot_uv), 0.62);
	float lit = step(lit_fraction, hash21(cell));
	float warm = step(0.76, hash21(cell + 17.0));
	float roof_band = step(0.965, local_y) * wall;
	vec3 win_col = mix(window_cool, window_warm, warm) * (0.7 + 0.3 * halftone);
	vec3 glow = win_col * window_energy * lit * pane * wall + roof_neon_color * roof_band * 2.2;
	ALBEDO = mix(building_color, building_top_tint, clamp(local_y, 0.0, 1.0));
	EMISSION = glow;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
}
