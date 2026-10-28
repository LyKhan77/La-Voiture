// La Voiture - Neo-Wangan (FASE 12.2) skyline ink hull.
// Purpose: inverted-hull outline for unit boxes scaled per instance. The shared
// inverted_hull_outline.gdshader extrudes in model space, which on a 30 x 145 x 30 m tower would
// inflate the line by the tower's own scale; here the instance scale is divided out so the ink is
// outline_width_m wide in the world on every face, whatever the size of the building.
shader_type spatial;
render_mode cull_front, unshaded;

uniform float outline_width_m : hint_range(0.01, 4.0) = 0.9;
uniform vec4 outline_color : source_color = vec4(0.02, 0.03, 0.05, 1.0);

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	VERTEX += NORMAL * outline_width_m / scale;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
