shader_type canvas_item;
render_mode unshaded;

// One-frame manga impact (DESIGN.md 4.3): the screen collapses to a hard black-and-white negative
// for ~80 ms on every cut of the winning scene. Screen-texture variant of manga_snapshot_invert:
// that one inverts a stored snapshot, this one inverts whatever is on screen right now.
// Target: Forward+ canvas, one full-screen ColorRect, one screen-texture read.

group_uniforms impact;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float luma_threshold : hint_range(0.05, 0.95) = 0.42;

void fragment() {
	vec3 frame = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(frame, vec3(0.2126, 0.7152, 0.0722));
	// Bright areas drop to ink, dark areas flash to paper: the negative reads as a comic frame.
	COLOR = vec4(vec3(1.0 - step(luma_threshold, luma)), 1.0);
}
