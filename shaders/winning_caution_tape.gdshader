shader_type canvas_item;
render_mode unshaded;

// Diagonal caution tape for the winning scene (DESIGN.md 4.3): -45 degree yellow/ink stripes in the
// control's own pixel space, so the stripe width stays 26 px at any stage scale.
// Target: Forward+ canvas, one ColorRect per strip, no texture reads.

group_uniforms tape;
uniform vec4 tape_color : source_color = vec4(1.0, 0.902, 0.0, 1.0);
uniform vec4 ink_color : source_color = vec4(0.027, 0.027, 0.039, 1.0);
uniform float stripe_px : hint_range(4.0, 80.0) = 26.0;

varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

void fragment() {
	// x - y is constant along a -45 degree line; the period holds one yellow and one ink stripe.
	float phase = mod(local_px.x - local_px.y, stripe_px * 2.0);
	COLOR = mix(tape_color, ink_color, step(stripe_px, phase));
}
