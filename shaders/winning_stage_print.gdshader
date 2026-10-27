shader_type spatial;
render_mode unshaded, cull_disabled;

// Screen-printed stage panels: hard ink, acid tape and Ben-Day dots, not reflective scenery.
void fragment() {
	float diagonal = UV.x + UV.y * 0.22;
	vec3 paper = vec3(0.025, 0.032, 0.052);
	if (diagonal > 0.12 && diagonal < 0.78) {
		paper = vec3(0.055, 0.065, 0.095);
	}
	float dots = 1.0 - step(0.19, length(fract(UV * vec2(180.0, 100.0)) - 0.5));
	paper += dots * 0.028;
	if (abs(diagonal - 0.12) < 0.006 || abs(diagonal - 0.78) < 0.006) {
		paper = vec3(0.002);
	}
	if (diagonal > 0.76 && diagonal < 0.775) {
		paper = vec3(0.60, 0.90, 0.0);
	}
	ALBEDO = paper;
}
