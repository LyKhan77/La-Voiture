shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, diffuse_toon, specular_toon;

// 2.5D manga standee for the winning podium. A camera-facing alpha cutout on a 1.05 x 1.85 m
// QuadMesh: hard two-tone cel diffuse, a neon rim read from the portrait's own alpha edge, and
// micro hair/cloth sway. Feet stay pinned (sway weight is zero at VERTEX.y = -height / 2), and
// ALPHA + ALPHA_SCISSOR_THRESHOLD keeps the material in the shadow-casting opaque path, so the
// podium receives the character's real silhouette instead of a rectangle.

group_uniforms albedo;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 team_color : source_color = vec4(0.847, 1.0, 0.0, 1.0);
uniform float team_tint : hint_range(0.0, 1.0) = 0.12;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.45;

group_uniforms rim;
uniform vec4 rim_color : source_color = vec4(1.0, 0.82, 0.15, 1.0);
uniform float rim_intensity : hint_range(0.0, 4.0) = 1.0;
uniform float rim_width : hint_range(0.0005, 0.02) = 0.004;

group_uniforms cel;
uniform vec4 shadow_tint : source_color = vec4(0.24, 0.22, 0.34, 1.0);
uniform float light_step : hint_range(0.0, 1.0) = 0.36;
uniform float light_softness : hint_range(0.001, 0.2) = 0.02;

group_uniforms motion;
uniform float sway_amount : hint_range(0.0, 0.05) = 0.012;
uniform float standee_height = 1.85;
uniform float standee_width = 1.05;

group_uniforms sticker;
// Die-cut sticker contour: transparent pixels within this many metres of the silhouette become a
// solid outline. 0 disables it (and its 8 extra texture reads).
uniform float outline_width : hint_range(0.0, 0.05) = 0.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying float height01;

void vertex() {
	// 0 at the soles, 1 at the crown. Motion weights vanish at 0, so the standee never lifts off.
	height01 = clamp(VERTEX.y / standee_height + 0.5, 0.0, 1.0);
	float hair = smoothstep(0.72, 1.0, height01);
	float cloth = smoothstep(0.12, 0.42, height01) * (1.0 - smoothstep(0.55, 0.90, height01));
	float wave = sin(TIME * 1.9 + height01 * 5.0) * 0.65 + sin(TIME * 3.3 + VERTEX.x * 2.7) * 0.35;
	VERTEX.x += wave * sway_amount * (hair + cloth * 0.6);
	VERTEX.y += wave * sway_amount * 0.15 * hair;
}

void fragment() {
	vec2 tex_size = vec2(textureSize(albedo_texture, 0));
	vec4 tex = vec4(1.0);
	if (tex_size.x > 1.0) {
		tex = texture(albedo_texture, UV);
	}

	ALBEDO = tex.rgb * mix(vec3(1.0), team_color.rgb, team_tint);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ROUGHNESS = 0.95;
	SPECULAR = 0.0;

	// Sticker outline: a clear pixel with an opaque neighbour on any of 8 directions at the contour
	// radius is part of the white border. Unrolled (no texture reads inside a loop); radius is metres
	// converted per axis so the border is the same width left-right and top-bottom.
	bool is_outline = false;
	if (outline_width > 0.0 && tex_size.x > 1.0 && tex.a < alpha_cutoff) {
		vec2 r = vec2(outline_width / standee_width, outline_width / standee_height);
		vec2 d = r * 0.7071;
		float near = textureLod(albedo_texture, UV + vec2(r.x, 0.0), 0.0).a;
		near = max(near, textureLod(albedo_texture, UV - vec2(r.x, 0.0), 0.0).a);
		near = max(near, textureLod(albedo_texture, UV + vec2(0.0, r.y), 0.0).a);
		near = max(near, textureLod(albedo_texture, UV - vec2(0.0, r.y), 0.0).a);
		near = max(near, textureLod(albedo_texture, UV + d, 0.0).a);
		near = max(near, textureLod(albedo_texture, UV - d, 0.0).a);
		near = max(near, textureLod(albedo_texture, UV + vec2(d.x, -d.y), 0.0).a);
		near = max(near, textureLod(albedo_texture, UV + vec2(-d.x, d.y), 0.0).a);
		if (near >= alpha_cutoff) {
			ALBEDO = outline_color.rgb;
			ALPHA = 1.0;
			is_outline = true;
		}
	}

	// The cutout's alpha edge is the character silhouette. An alpha difference ring around it is
	// the manga rim: it hugs hair, shoulders and elbows instead of the quad's rectangular border.
	float edge = 0.0;
	if (tex_size.x > 1.0) {
		// Base mip so the rim stays a constant body-width instead of dissolving with minification.
		float edge_alpha = textureLod(albedo_texture, UV, 0.0).a;
		vec2 step_uv = vec2(rim_width);
		edge += abs(textureLod(albedo_texture, UV + vec2(step_uv.x, 0.0), 0.0).a - edge_alpha);
		edge += abs(textureLod(albedo_texture, UV - vec2(step_uv.x, 0.0), 0.0).a - edge_alpha);
		edge += abs(textureLod(albedo_texture, UV + vec2(0.0, step_uv.y), 0.0).a - edge_alpha);
		edge += abs(textureLod(albedo_texture, UV - vec2(0.0, step_uv.y), 0.0).a - edge_alpha);
	}
	edge = clamp(edge * 2.0, 0.0, 1.0);
	float key = 0.62 + 0.38 * height01; // studio key light overhead: the crown glows hardest
	// The sticker border glows with its own colour, not with the character rim.
	EMISSION = is_outline ? outline_color.rgb * 0.6 : rim_color.rgb * rim_intensity * edge * key;
}

void light() {
	// Two-tone cel step, no specular lobe: flat manga paper lit by the stage spotlights.
	float ndl = dot(NORMAL, LIGHT);
	float cel = smoothstep(light_step - light_softness, light_step + light_softness, ndl);
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), 0.22);
	DIFFUSE_LIGHT += mix(shade, vec3(1.0), cel) * LIGHT_COLOR * ATTENUATION / PI;
}
