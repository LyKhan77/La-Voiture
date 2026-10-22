shader_type canvas_item;
render_mode unshaded;

// Screentone ink with a growing halftone hole: the comic wipe that hands the screen over
// to the pre-grid fly-through. Progress 0 is a solid ink sheet, 1 is fully open.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float ink_alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec4 ink : source_color = vec4(0.055, 0.06, 0.08, 1.0);
uniform float dot_spacing : hint_range(4.0, 32.0) = 12.0;
uniform vec2 center = vec2(0.52, 0.44);
uniform float edge_band = 0.18;
uniform float dot_angle = 0.42;

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.000001);
	vec2 offset = (SCREEN_UV - center) * vec2(aspect, 1.0);
	float reach = length(vec2(aspect, 1.0)) * 0.5 + edge_band + 0.12;
	float radius = progress * reach;
	float dist = length(offset);
	float edge = smoothstep(radius - edge_band, radius + edge_band * 0.2, dist);
	// Rotated screen-pixel cells, so the dots keep one size however the screen is stretched.
	float ca = cos(dot_angle);
	float sa = sin(dot_angle);
	vec2 grid = vec2(FRAGCOORD.x * ca - FRAGCOORD.y * sa, FRAGCOORD.x * sa + FRAGCOORD.y * ca) / dot_spacing;
	vec2 cell = fract(grid) - 0.5;
	float dot_radius = mix(0.0, 0.74, edge);
	float dots = 1.0 - smoothstep(dot_radius - 0.07, dot_radius + 0.07, length(cell));
	float solid = smoothstep(radius + edge_band * 0.3, radius + edge_band, dist);
	float cover = mix(1.0, max(dots, solid), smoothstep(0.0, 0.04, progress));
	COLOR = vec4(ink.rgb, cover * ink_alpha);
}
