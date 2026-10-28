// La Voiture - Neo-Wangan (FASE 12.2) twinkling night stars.
// Purpose: 900 stars as one MultiMesh of camera-facing diamonds. Each instance twinkles on its own
// phase (hash of INSTANCE_ID) and snaps between three brightness steps, so the sky blinks like
// inked sparkle marks instead of fading smoothly. Additive and fog-free.
shader_type spatial;
render_mode blend_add, unshaded, fog_disabled, depth_draw_never, cull_disabled;

uniform float twinkle_speed : hint_range(0.0, 8.0) = 1.6;
uniform float min_brightness : hint_range(0.0, 1.0) = 0.25;

varying float phase;

void vertex() {
	// Hash the instance index into a stable 0..1 phase and speed multiplier.
	phase = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = abs(UV - vec2(0.5)) * 2.0;
	// Diamond with thin cross arms: a four-point sparkle.
	float diamond = step(p.x + p.y, 0.7);
	float arms = step(min(p.x, p.y), 0.08) * step(max(p.x, p.y), 1.0);
	float shape = max(diamond, arms);
	float wave = 0.5 + 0.5 * sin(TIME * twinkle_speed * (0.6 + phase) + phase * 40.0);
	// Three cel steps: dim, mid, full.
	float level = min_brightness + (1.0 - min_brightness) * floor(wave * 3.0) / 2.0;
	ALBEDO = COLOR.rgb * level;
	ALPHA = shape;
}
