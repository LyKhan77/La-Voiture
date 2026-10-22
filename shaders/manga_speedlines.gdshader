shader_type canvas_item;
render_mode unshaded;

// Comic action lines stamped over the cut-in panels: radial ink rays that get denser
// away from the centre, so the panels read as speeding in.

uniform vec4 line_color : source_color = vec4(0.02, 0.02, 0.03, 0.6);
uniform float ray_count = 64.0;
uniform float inner : hint_range(0.0, 1.0) = 0.10;
uniform float outer : hint_range(0.0, 1.5) = 0.85;

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.000001);
	vec2 p = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
	float angle = atan(p.y, p.x);
	float jitter = sin(angle * 7.0) * 0.55 + sin(angle * 23.0) * 0.2;
	float rays = sin(angle * ray_count + jitter);
	float mask = smoothstep(0.82, 0.99, rays);
	float reach = smoothstep(inner, outer, length(p));
	COLOR = vec4(line_color.rgb, line_color.a * mask * reach);
}
