shader_type canvas_item;
render_mode unshaded;

// Comic action lines: radial ink rays that get denser away from `center`. Two uses:
//  - the radio cut-in panels: defaults, rays fill the whole rect around the middle.
//  - the race HUD: `center` follows the car on screen, the rays live in a ring around it
//    (inner..outer, gone by `ring_end`) and `safe_rect` keeps them off the HUD panels.

uniform vec4 line_color : source_color = vec4(0.02, 0.02, 0.03, 0.6);
uniform float ray_count = 64.0;
uniform float inner : hint_range(0.0, 1.0) = 0.10;
uniform float outer : hint_range(0.0, 1.5) = 0.85;
uniform vec2 center = vec2(0.5, 0.5);
// Screen-UV window (x, y, right, bottom) the rays may appear in; the default is the whole screen.
uniform vec4 safe_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float safe_fade : hint_range(0.001, 0.2) = 0.001;
// Distance (in screen heights) where the ring has faded out; 10 keeps the old unbounded behaviour.
uniform float ring_end = 10.0;

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.000001);
	vec2 p = (SCREEN_UV - center) * vec2(aspect, 1.0);
	float angle = atan(p.y, p.x);
	float jitter = sin(angle * 7.0) * 0.55 + sin(angle * 23.0) * 0.2;
	float rays = sin(angle * ray_count + jitter);
	float mask = smoothstep(0.82, 0.99, rays);
	float dist = length(p);
	float reach = smoothstep(inner, outer, dist) * (1.0 - smoothstep(ring_end - 0.25, ring_end, dist));
	vec2 inside = smoothstep(safe_rect.xy, safe_rect.xy + vec2(safe_fade), SCREEN_UV)
		* (1.0 - smoothstep(safe_rect.zw - vec2(safe_fade), safe_rect.zw, SCREEN_UV));
	COLOR = vec4(line_color.rgb, line_color.a * mask * reach * inside.x * inside.y);
}
