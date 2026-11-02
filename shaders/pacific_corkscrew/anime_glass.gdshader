shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_toon, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.12, 0.27, 0.36, 0.65);
uniform float glow_energy = 0.0;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// World-space Ben-Day dots fade before they can shimmer in distant windows.
	vec2 cell = fract(vec2(world_pos.x + world_pos.z, world_pos.y) * 5.0) - 0.5;
	float dot_mask = 1.0 - step(0.19, length(cell));
	float fade = 1.0 - smoothstep(20.0, 65.0, -VERTEX.z);
	ALBEDO = base_color.rgb * (1.0 - 0.22 * dot_mask * fade);
	EMISSION = vec3(1.0, 0.72, 0.38) * glow_energy * (0.8 + dot_mask * 0.2);
	ALPHA = base_color.a;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
