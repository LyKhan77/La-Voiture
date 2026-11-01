// Podium sticker outline: white die-cut border and hard shadow around a sprite's alpha silhouette.
// Target: Forward+ desktop, canvas_item. Budget: 17 texture reads per pixel over a ~400x700 px quad (standee) or
// ~760x470 px (car), no loops. Authored for the La Voiture winning triptych.
shader_type canvas_item;

// Sticker look for a flat sprite: white die-cut border and a hard offset shadow around the alpha silhouette.
// The quad grows by pad_px on every side (vertex) and the UV grows with it, so the border and the shadow are not
// cut off by the TextureRect's own rect. rect_px must be the TextureRect size in pixels.
uniform vec2 rect_px = vec2(100.0, 100.0);
uniform float outline_px : hint_range(0.0, 16.0) = 5.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 shadow_offset = vec2(16.0, 20.0);
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.62);
uniform float pad_px = 40.0;

varying vec4 v_modulate;

// Alpha of the sprite at uv, 0 outside the texture (branch-free: the read is clamped, the result masked), and the
// silhouette grown by s in the eight compass directions. Macros, not functions: the built-in TEXTURE is only readable
// inside the processor functions.
#define COVER(uv) (texture(TEXTURE, clamp((uv), 0.0, 1.0)).a * step(0.0, (uv).x) * step((uv).x, 1.0) * step(0.0, (uv).y) * step((uv).y, 1.0))
#define DILATED(uv, s) max(max(max(COVER(uv), COVER((uv) + vec2((s).x, 0.0))), max(COVER((uv) - vec2((s).x, 0.0)), COVER((uv) + vec2(0.0, (s).y)))), max(max(COVER((uv) - vec2(0.0, (s).y)), COVER((uv) + (s))), max(COVER((uv) - (s)), max(COVER((uv) + vec2((s).x, -(s).y)), COVER((uv) + vec2(-(s).x, (s).y))))))

vec4 over(vec4 top, vec4 bottom) {
	float a = top.a + bottom.a * (1.0 - top.a);
	vec3 rgb = (top.rgb * top.a + bottom.rgb * bottom.a * (1.0 - top.a)) / max(a, 0.0001);
	return vec4(rgb, a);
}

void vertex() {
	vec2 grow = UV * 2.0 - 1.0;
	VERTEX += grow * pad_px;
	UV += grow * pad_px / rect_px;
	v_modulate = COLOR;
}

void fragment() {
	vec2 step_uv = vec2(outline_px) / rect_px;
	vec2 sprite_inside = step(vec2(0.0), UV) * step(UV, vec2(1.0));
	vec4 sprite = texture(TEXTURE, clamp(UV, 0.0, 1.0)) * sprite_inside.x * sprite_inside.y;
	float ring = DILATED(UV, step_uv);
	float cast = DILATED(UV - shadow_offset / rect_px, step_uv);
	vec4 col = vec4(shadow_color.rgb, shadow_color.a * cast);
	col = over(vec4(outline_color.rgb, outline_color.a * ring), col);
	col = over(sprite, col);
	COLOR = col * v_modulate;
}
