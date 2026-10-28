// La Voiture - Neo-Wangan (FASE 12.2) toon bay water.
// Purpose: replaces the PBR water that threw one huge white specular blob under the bridge. Two
// stepped tones in wavy bands that run across the wind, and thin broken neon crest lines on the
// band edges (cyan or magenta by region). No specular at all, and the wind speeds the swell up.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_disabled;

uniform vec3 deep_color : source_color = vec3(0.025, 0.065, 0.125);
uniform vec3 band_color : source_color = vec3(0.05, 0.16, 0.28);
uniform vec3 neon_ripple_cyan : source_color = vec3(0.0, 0.90, 1.0);
uniform vec3 neon_ripple_magenta : source_color = vec3(1.0, 0.18, 0.46);
uniform float wind_speed_kph : hint_range(0.0, 60.0) = 14.0;
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float time_s = 0.0;
// World metres per ripple band, and the share of each band that carries the neon crest line.
uniform float band_length_m : hint_range(2.0, 40.0) = 9.0;
uniform float crest_share : hint_range(0.01, 0.3) = 0.07;
uniform float crest_dash_gap : hint_range(0.0, 0.9) = 0.38;
uniform float band_emission : hint_range(0.0, 1.0) = 0.25;
uniform float crest_emission : hint_range(0.0, 2.0) = 0.70;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 dir = normalize(wind_dir + vec2(0.0001));
	vec2 across = vec2(-dir.y, dir.x);
	float speed = 0.35 + (wind_speed_kph / 45.0) * 1.45;
	vec2 p = world_pos.xz / band_length_m;
	// Phase along the wind, wobbled sideways so the bands meander like hand-inked waves.
	float phase = dot(p, dir) - time_s * speed * 0.35 + 0.35 * sin(dot(p, across) * 2.3 + time_s * 0.6);
	float stripe = fract(phase);
	float band = step(0.5, stripe);
	// Crest line on the leading edge of each band, broken into dashes along the crest.
	float crest_line = step(0.5, stripe) * (1.0 - step(0.5 + crest_share, stripe));
	float dash = step(crest_dash_gap, fract(dot(p, across) * 0.9 + floor(phase) * 0.37));
	float neon_pick = step(0.0, sin(world_pos.x * 0.03 + world_pos.z * 0.02));
	vec3 crest_col = mix(neon_ripple_cyan, neon_ripple_magenta, neon_pick);
	ALBEDO = mix(deep_color, band_color, band);
	EMISSION = band_color * band_emission + crest_col * crest_line * dash * crest_emission;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}
