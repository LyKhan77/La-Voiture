shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;
uniform vec2 panel_size_m = vec2(4.0, 1.65);
uniform float cell_m = 0.12;
uniform float wire_m = 0.012;
void fragment() {
	vec2 cell = abs(fract(UV * panel_size_m / cell_m) - 0.5) * cell_m;
	float wire = max(step(cell_m * 0.5 - wire_m, cell.x), step(cell_m * 0.5 - wire_m, cell.y));
	ALPHA = wire;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = vec3(0.24, 0.28, 0.32);
	ROUGHNESS = 0.9;
}
