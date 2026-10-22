// La Voiture - FASE 10 anime mountain silhouette with atmospheric depth haze.
// Authorship: Genex / La Voiture. Purpose: shades one ridge layer of the horizon ring with
// a flat layer colour, a sunlit band near the crest and haze that thickens toward the base
// and with distance (each layer carries its own haze), blended to the live sky horizon
// colour so the ring melts into the sky at every time of day.
// Target: Forward+, spatial, unshaded. Budget: a few ALU ops, no texture reads, no branches.
// Vertex alpha carries the height fraction (0 = buried base, 1 = crest).
shader_type spatial;
render_mode unshaded, cull_disabled;

group_uniforms layer;
uniform vec3 layer_color : source_color = vec3(0.35, 0.5, 0.65);
// Share of the haze colour this layer always carries (far layers are hazier).
uniform float layer_haze : hint_range(0.0, 1.0) = 0.3;
group_uniforms;

group_uniforms sky;
// Driven by CircuitLightingController from the sky horizon colour and the sun.
uniform vec3 haze_color : source_color = vec3(0.78, 0.86, 0.95);
uniform float haze_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec3 ridge_light : source_color = vec3(1.0, 0.98, 0.9);
uniform float ridge_light_amount : hint_range(0.0, 1.0) = 0.35;
// 1 = daylight, lower at dusk and night.
uniform float brightness : hint_range(0.0, 1.5) = 1.0;
group_uniforms;

// Height fraction above which the cel highlight band starts, and the haze added at the base.
const float RIDGE_BAND_START = 0.72;
const float RIDGE_BAND_SOFT = 0.03;
const float BASE_HAZE = 0.4;

void fragment() {
	float height = COLOR.a;
	float lit = smoothstep(RIDGE_BAND_START - RIDGE_BAND_SOFT, RIDGE_BAND_START + RIDGE_BAND_SOFT, height);
	vec3 rock = mix(layer_color, ridge_light, lit * ridge_light_amount) * brightness;
	float haze = clamp((layer_haze + (1.0 - height) * BASE_HAZE) * haze_strength, 0.0, 1.0);
	ALBEDO = mix(rock, haze_color, haze);
}
