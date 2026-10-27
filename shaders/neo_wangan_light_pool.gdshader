// La Voiture - Neo-Wangan (FASE 12) pooled light on the asphalt.
// Purpose: the warm ellipse a Shuto expressway lamp throws on the road, and the cyan wash under the
// underpass neon, as one additive unshaded quad per lamp. Cheap night readability: no real lights.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 pool_color : source_color = vec4(1.0, 0.82, 0.55, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 0.55;
uniform float falloff_power : hint_range(0.5, 4.0) = 2.2;
uniform bool clip_to_road = false;
varying flat float centre_lateral;

void vertex() {
	centre_lateral = INSTANCE_CUSTOM.r;
}

void fragment() {
	vec2 local = UV * 2.0 - 1.0;
	// Quad longitudinal axis is 9 m; its 5.5 m cross-axis is clipped to asphalt edges.
	// 0.75 m edge margin also contains the pool on the tightest 22.7 m-radius curve.
	if (clip_to_road && abs(centre_lateral + local.y * 2.75) > 5.0) {
		discard;
	}
	float radius = length(local);
	float falloff = pow(clamp(1.0 - radius, 0.0, 1.0), falloff_power);
	ALBEDO = pool_color.rgb * intensity * falloff;
	ALPHA = 1.0;
}
