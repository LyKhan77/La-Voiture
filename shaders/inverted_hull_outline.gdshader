shader_type spatial;
render_mode cull_front, unshaded;

uniform float outline_width : hint_range(0.001, 0.05) = 0.018; // Ketebalan garis tinta
uniform vec4 outline_color : source_color = vec4(0.02, 0.02, 0.02, 1.0); // #050505 Ink Black

void vertex() {
	// Ekstrusi vertex sepanjang normal untuk menghasilkan inverted hull
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
