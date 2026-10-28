// La Voiture - FASE 13.1 Brianza distant vista ring (forest line, Montevecchia hills, Alps).
// Authorship: Genex / La Voiture. Same idea as mountain_haze.gdshader but tuned for a ring 4.3 - 4.55 km
// out: the haze is blended to the sky horizon colour here, so scene fog is switched off for this
// surface (fog on top of it washed the whole ring to white), the base haze is lighter, and the
// highest crests can carry a snow cap. Vertex alpha is the height fraction (0 = buried base, 1 = crest).
// Target: Forward+, spatial, unshaded. Budget: a few ALU ops, no texture reads, no branches.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

group_uniforms layer;
uniform vec3 layer_color : source_color = vec3(0.35, 0.5, 0.65);
// Share of the haze colour this layer always carries (far layers are hazier).
uniform float layer_haze : hint_range(0.0, 1.0) = 0.3;
// 0 = bare rock, 1 = full snow cap on the top of the crest.
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
group_uniforms;

group_uniforms sky;
// Driven by BrianzaEnvironment.apply_time_of_day() from the sky profile.
uniform vec3 haze_color : source_color = vec3(0.86, 0.91, 0.96);
uniform float haze_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec3 ridge_light : source_color = vec3(1.0, 0.95, 0.85);
uniform float ridge_light_amount : hint_range(0.0, 1.0) = 0.3;
// 1 = daylight, lower at dusk and night.
uniform float brightness : hint_range(0.0, 1.5) = 1.0;
group_uniforms;

const float RIDGE_BAND_START = 0.72;
const float RIDGE_BAND_SOFT = 0.03;
const float SNOW_LINE = 0.86;
const float BASE_HAZE = 0.22;
const vec3 SNOW_COLOR = vec3(0.93, 0.96, 1.0);

void fragment() {
	float height = COLOR.a;
	float lit = smoothstep(RIDGE_BAND_START - RIDGE_BAND_SOFT, RIDGE_BAND_START + RIDGE_BAND_SOFT, height);
	float snow = smoothstep(SNOW_LINE, SNOW_LINE + RIDGE_BAND_SOFT, height) * snow_amount;
	vec3 rock = mix(layer_color, ridge_light, lit * ridge_light_amount);
	rock = mix(rock, SNOW_COLOR * ridge_light, snow) * brightness;
	float haze = clamp((layer_haze + (1.0 - height) * BASE_HAZE) * haze_strength, 0.0, 1.0);
	ALBEDO = mix(rock, haze_color, haze);
}
