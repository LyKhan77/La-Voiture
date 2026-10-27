// La Voiture - Neo-Wangan (FASE 12) low-poly Tokyo skyline.
// Purpose: window grids on the night skyline without textures — one box per tower, one draw call
// for the whole ring. Windows are cut in world space on the vertical faces, so the same mesh works
// at every building scale, and they glow cyan or warm amber like a Shuto-night city block.
shader_type spatial;
render_mode cull_back;

uniform vec3 building_color = vec3(0.035, 0.04, 0.055);
uniform vec3 window_cool = vec3(0.0, 0.94, 1.0);
uniform vec3 window_warm = vec3(1.0, 0.55, 0.2);
uniform float window_energy : hint_range(0.0, 8.0) = 1.8;
uniform vec2 window_cell = vec2(4.6, 3.2);
uniform float lit_fraction : hint_range(0.0, 1.0) = 0.3;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 abs_normal = abs(NORMAL);
	// Roofs and floors are dark: windows only exist on the four vertical faces.
	float wall = step(abs_normal.y, 0.5);
	vec2 uv = abs_normal.x > abs_normal.z ? world_pos.zy : world_pos.xy;
	vec2 cells = uv / window_cell;
	vec2 cell = floor(cells);
	vec2 local = fract(cells);
	float pane = step(0.24, local.x) * step(local.x, 0.76) * step(0.3, local.y) * step(local.y, 0.72);
	float lit = step(lit_fraction, hash21(cell));
	float warm = step(0.8, hash21(cell + 17.0));
	vec3 glow = mix(window_cool, window_warm, warm) * window_energy * lit * pane * wall;
	ALBEDO = building_color;
	EMISSION = glow;
	ROUGHNESS = 0.45;
	SPECULAR = 0.3;
}
