// Authored for the La Voiture winning triptych. Target: Forward+ desktop, canvas_item; one pass, no texture reads,
// about 30 ALU per pixel over a ~730x940 px polygon.
shader_type canvas_item;
render_mode unshaded;

// Manga burst behind a podium finisher: alternating rays in the rank colour fanning from `center` (a fraction of
// the panel), darkened towards the edges, with a halftone screentone over everything. Put it on a Polygon2D whose
// polygon is in panel pixels; `panel_px` is the panel size, so the dots stay the same size whatever the panel width.
uniform vec4 base_color : source_color = vec4(0.17, 0.2, 0.0, 1.0);
uniform vec4 ray_color : source_color = vec4(0.37, 0.44, 0.0, 1.0);
uniform vec2 center = vec2(0.5, 0.62);
uniform float ray_count = 64.0;
uniform vec2 panel_px = vec2(730.0, 940.0);
uniform float dot_spacing = 12.0;
uniform float dot_alpha : hint_range(0.0, 1.0) = 0.35;

varying vec2 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec2 from_center = v_local - center * panel_px;
	float ray = step(0.5, fract(atan(from_center.y, from_center.x) / TAU * ray_count));
	vec3 col = mix(base_color.rgb, ray_color.rgb, ray);
	float reach = length(from_center) / length(panel_px);
	col *= 1.0 - 0.6 * smoothstep(0.16, 1.0, reach);
	vec2 cell = mod(v_local, dot_spacing) - 0.5 * dot_spacing;
	col *= 1.0 - dot_alpha * step(length(cell), 1.8);
	COLOR = vec4(col, 1.0);
}
