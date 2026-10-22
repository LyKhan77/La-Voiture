// La Voiture - FASE 5 road spray puff: a flat cel-shaded blob with an ink border
// and one hard shade crescent, animated "on fours" (4 frames per particle life)
// like hand-drawn anime effects instead of a smooth fade.
// Authorship: Genex / La Voiture. Target: Forward+/Mobile, spatial, unshaded,
// billboard. Budget: one atan + a few steps per pixel, no texture reads.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

group_uniforms look;
uniform vec4 spray_color : source_color = vec4(0.95, 0.97, 1.0, 1.0);
uniform vec4 shade_color : source_color = vec4(0.58, 0.66, 0.80, 1.0);
uniform vec4 ink_color : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform float ink_width : hint_range(0.0, 0.4) = 0.14;
uniform float opacity : hint_range(0.0, 1.0) = 0.9;
group_uniforms;

group_uniforms animation;
uniform float frame_count : hint_range(2.0, 12.0) = 4.0;
uniform float start_scale : hint_range(0.1, 2.0) = 0.45;
uniform float end_scale : hint_range(0.1, 4.0) = 1.5;
group_uniforms;

varying float v_frame_age;
varying float v_seed;

void vertex() {
	// INSTANCE_CUSTOM.y is the particle's normalised age.
	v_frame_age = floor(clamp(INSTANCE_CUSTOM.y, 0.0, 0.999) * frame_count) / frame_count;
	v_seed = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]
	);
	VERTEX.xy *= mix(start_scale, end_scale, v_frame_age) * mix(0.8, 1.25, v_seed);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = atan(p.y, p.x);
	// Lumpy outline, different per puff.
	float radius = 0.80 + 0.12 * sin(angle * 3.0 + v_seed * TAU) + 0.06 * sin(angle * 5.0 - v_seed * 9.0);
	float r = length(p);
	float inside = step(r, radius);
	float body = step(r, radius - ink_width);
	// Light comes from the upper left: shade the lower right.
	float shade = step(0.25, dot(p, vec2(0.55, -0.65)));
	vec3 fill = mix(spray_color.rgb, shade_color.rgb, shade);
	ALBEDO = mix(ink_color.rgb, fill, body);
	ALPHA = inside * opacity * (1.0 - 0.85 * v_frame_age);
}
