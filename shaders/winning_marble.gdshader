shader_type spatial;
render_mode specular_disabled;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * 7.0;
	float warp = noise(p * 0.7) * 2.5 + noise(p * 2.2) * 0.35;
	float vein = step(0.91, 1.0 - abs(sin(p.x * 2.0 + p.y + warp)));
	float dots = 1.0 - step(0.17, length(fract(UV * 95.0) - 0.5));
	ALBEDO = mix(vec3(0.055, 0.067, 0.095), vec3(0.20, 0.24, 0.32), vein);
	ALBEDO *= 1.0 - dots * 0.22;
	ROUGHNESS = 1.0;
}

void light() {
	float band = step(0.45, dot(NORMAL, LIGHT));
	float shadow = step(0.5, ATTENUATION);
	vec3 tone = mix(vec3(0.30, 0.34, 0.48), vec3(1.0), band * shadow);
	DIFFUSE_LIGHT += tone * LIGHT_COLOR / PI;
}
