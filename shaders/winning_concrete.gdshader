shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Raw brutalist concrete for the winning scene walls and floors: cast panel seams, form-tie holes
// and a two-octave value-noise grain, all procedural in world space (no textures), so a wall quad
// of any size and the floor tile identically. Walls use world XY, floors world XZ.
// Target: Forward+, one hash-noise evaluation per octave, no texture reads.

group_uniforms concrete;
uniform vec4 base_color : source_color = vec4(0.17, 0.18, 0.21, 1.0);
uniform vec4 seam_color : source_color = vec4(0.04, 0.04, 0.055, 1.0);
uniform float grain_amount : hint_range(0.0, 0.5) = 0.22;

group_uniforms panels;
uniform float seam_spacing : hint_range(0.5, 10.0) = 3.0;
uniform float seam_width : hint_range(0.005, 0.2) = 0.03;
uniform float tie_spacing : hint_range(0.5, 5.0) = 1.6;
uniform float tie_radius : hint_range(0.01, 0.2) = 0.045;

varying vec3 world_position;
varying vec3 world_normal;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Floors (normal up) tile on XZ, walls on XY.
	float is_floor = step(0.5, abs(world_normal.y));
	vec2 plane = mix(world_position.xy, world_position.xz, is_floor);

	float grain = value_noise(plane * 18.0) * 0.5 + value_noise(plane * 4.0) * 0.5;
	vec3 color = base_color.rgb * (1.0 - grain_amount + grain_amount * 2.0 * grain);

	// Vertical cast seams; distance to the nearest seam line in metres.
	float seam_distance = abs(fract(plane.x / seam_spacing + 0.5) - 0.5) * seam_spacing;
	float seam = 1.0 - smoothstep(seam_width * 0.5, seam_width, seam_distance);
	color = mix(color, seam_color.rgb, seam * 0.85);

	// Form-tie holes: a dark pit with a pale rim on a regular grid.
	vec2 tie_offset = (fract(plane / tie_spacing) - 0.5) * tie_spacing;
	float tie = length(tie_offset);
	float pit = 1.0 - smoothstep(tie_radius * 0.8, tie_radius, tie);
	float rim = smoothstep(tie_radius, tie_radius * 1.25, tie) * (1.0 - smoothstep(tie_radius * 1.25, tie_radius * 1.6, tie));
	color = mix(color, seam_color.rgb * 0.5, pit);
	color += vec3(0.08) * rim;

	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
