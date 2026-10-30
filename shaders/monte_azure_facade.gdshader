// La Voiture - FASE 15 Monte Azure Marina: cel-shaded Riviera facade.
// Authorship: Genex / La Voiture. Purpose: the apartment and hotel blocks of the harbour town as unit boxes scaled per
// instance, one draw call per district: a painted wall (the instance colour), a plinth, cream cornice, terracotta roof,
// and a grid of shuttered windows cut in the block's own metres, so a 12 m and a 45 m block carry the same 3.4 m windows.
// By day the panes are dark glass between teal shutters; at night `night` lights a share of them warm.
// Target: Forward+, spatial, MultiMesh instanced with custom data (rgb = wall colour). Budget: ~30 ALU ops per fragment,
// no texture reads, no loops, no dynamic branches (step/mix only). The ink hull is the next_pass (neo_wangan_skyline_outline).
shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon;

group_uniforms palette;
uniform vec3 roof_color : source_color = vec3(0.70, 0.33, 0.22);
// Sheds and warehouses (instance custom alpha 1) carry a flat grey roof instead of terracotta tiles.
uniform vec3 flat_roof_color : source_color = vec3(0.55, 0.57, 0.60);
uniform vec3 cornice_color : source_color = vec3(0.96, 0.93, 0.85);
uniform vec3 plinth_color : source_color = vec3(0.58, 0.55, 0.50);
uniform vec3 glass_color : source_color = vec3(0.16, 0.26, 0.40);
uniform vec3 shutter_color : source_color = vec3(0.22, 0.48, 0.50);
group_uniforms;

group_uniforms layout;
// One window bay in metres (across, up); the block is cut into bays along each wall.
uniform vec2 window_cell = vec2(3.6, 3.3);
uniform float plinth_height_m : hint_range(0.0, 8.0) = 3.3;
uniform float cornice_height_m : hint_range(0.0, 3.0) = 0.8;
group_uniforms;

group_uniforms night;
// 0 by day, 1 at night: lights `lit_fraction` of the panes with `window_warm`.
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float window_energy : hint_range(0.0, 8.0) = 1.7;
uniform float lit_fraction : hint_range(0.0, 1.0) = 0.55;
uniform vec3 window_warm : source_color = vec3(1.0, 0.72, 0.36);
group_uniforms;

// Window bay proportions (fractions of one bay): the pane, and a shutter either side of it.
const float PANE_X0 = 0.30;
const float PANE_X1 = 0.70;
const float PANE_Y0 = 0.22;
const float PANE_Y1 = 0.78;
const float SHUTTER_X = 0.12;
// Hash constants for the lit-window pattern.
const float HASH_A = 123.34;
const float HASH_B = 456.21;
const float HASH_C = 45.32;
const float BLOCK_SEED = 97.0;

varying vec3 local_pos;
varying vec3 local_normal;
varying vec3 wall_tint;
varying float block_height;
varying float roof_style;

float hash21(vec2 p) {
	p = fract(p * vec2(HASH_A, HASH_B));
	p += dot(p, p + HASH_C);
	return fract(p.x * p.y);
}

void vertex() {
	// Metres in the block's own frame (the instance scale is the block's size), measured from its base.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_pos = (VERTEX + vec3(0.0, 0.5, 0.0)) * scale;
	local_normal = NORMAL;
	wall_tint = INSTANCE_CUSTOM.rgb;
	roof_style = INSTANCE_CUSTOM.a;
	block_height = scale.y;
}

void fragment() {
	float roof = step(0.5, local_normal.y);
	float wall = 1.0 - roof;
	// Which wall: faces turned along x run along z, the others along x.
	float along_z = step(abs(local_normal.z), abs(local_normal.x));
	float across = mix(local_pos.x, local_pos.z, along_z);
	vec2 cells = vec2(across, local_pos.y) / window_cell;
	vec2 cell = floor(cells);
	vec2 inside = fract(cells);
	float above_plinth = step(plinth_height_m, local_pos.y);
	float pane = step(PANE_X0, inside.x) * step(inside.x, PANE_X1) * step(PANE_Y0, inside.y) * step(inside.y, PANE_Y1);
	float shutter = (step(SHUTTER_X, inside.x) * step(inside.x, PANE_X0) + step(PANE_X1, inside.x) * step(inside.x, 1.0 - SHUTTER_X))
		* step(PANE_Y0, inside.y) * step(inside.y, PANE_Y1);
	float lit = step(1.0 - lit_fraction, hash21(cell + floor(wall_tint.r * BLOCK_SEED)));
	float cornice = step(block_height - cornice_height_m, local_pos.y);
	vec3 albedo = wall_tint;
	albedo = mix(albedo, shutter_color, shutter * above_plinth);
	albedo = mix(albedo, glass_color, pane * above_plinth);
	albedo = mix(plinth_color, albedo, above_plinth);
	albedo = mix(albedo, cornice_color, cornice * wall);
	albedo = mix(albedo, mix(roof_color, flat_roof_color, roof_style), roof);
	ALBEDO = albedo;
	// Lit windows at night; roofs, plinths and cornices stay dark.
	EMISSION = window_warm * window_energy * night * lit * pane * above_plinth * wall * (1.0 - cornice);
	ROUGHNESS = 0.85;
	SPECULAR = 0.12;
}
