// La Voiture - Neo-Wangan (FASE 12.2) anime night clouds.
// Purpose: three flat tones by how squarely each surface faces the moon: indigo shadow, slate body
// and a silver-cyan rim on the moon-facing edge. The sky is seen from below, so lighting from the
// moon (not from straight up) is what puts a bright ink edge on the underside silhouettes. Unshaded
// and fog-free, so a cloud keeps its flat look at any distance; the environment script drifts the
// whole ring with the wind.
shader_type spatial;
render_mode cull_back, unshaded, fog_disabled;

uniform vec3 cloud_shadow : source_color = vec3(0.12, 0.15, 0.27);
uniform vec3 cloud_mid : source_color = vec3(0.25, 0.32, 0.52);
uniform vec3 cloud_rim : source_color = vec3(0.72, 0.88, 1.0);
// World-space direction towards the moon (normalised MOON_OFFSET of neo_wangan_environment.gd).
uniform vec3 moon_dir = vec3(-0.434, 0.521, -0.735);
uniform float body_threshold : hint_range(0.0, 1.0) = 0.46;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.78;

varying float moon_facing;

void vertex() {
	vec3 world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// 0 = turned away from the moon, 1 = facing it.
	moon_facing = clamp(dot(world_normal, normalize(moon_dir)) * 0.5 + 0.5, 0.0, 1.0);
}

void fragment() {
	float body_band = step(body_threshold, moon_facing);
	float rim_band = step(rim_threshold, moon_facing);
	vec3 col = mix(cloud_shadow, cloud_mid, body_band);
	col = mix(col, cloud_rim, rim_band);
	ALBEDO = col;
}
