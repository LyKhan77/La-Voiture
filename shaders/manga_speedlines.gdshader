shader_type canvas_item;
render_mode unshaded;

// Comic action lines: ink rays radiating from `center`. Forward+ / desktop; no texture reads, one
// loop-free fragment pass (budget: ~40 ALU, full-screen rect).
// Two looks, switched by `variation`:
//  - 0 (default, radio cut-in panels): even rays that thicken away from the centre.
//  - >0 (race HUD): hand-inked, deliberately uneven. Every sector gets its own random presence, width,
//    start and end radius; rays crowd toward `lean` and thin out opposite it; a share of them are
//    painted lime / cyan / crimson instead of ink; some carry a halftone screentone wedge; and the
//    whole set re-rolls 12 times a second like frames of a drawn animation.
// The HUD keeps rays in a ring around the car (inner..outer, gone by `ring_end`) and `safe_rect`
// keeps them off the HUD panels.

group_uniforms ink;
uniform vec4 line_color : source_color = vec4(0.02, 0.02, 0.03, 0.6);
uniform vec4 accent_a : source_color = vec4(0.847, 1.0, 0.0, 1.0);   // acid lime
uniform vec4 accent_b : source_color = vec4(0.0, 0.941, 1.0, 1.0);   // punk cyan
uniform vec4 accent_c : source_color = vec4(1.0, 0.102, 0.294, 1.0); // anime crimson
uniform float accent_share : hint_range(0.0, 1.0) = 0.0;

group_uniforms rays;
uniform float ray_count = 64.0;
uniform float inner : hint_range(0.0, 1.0) = 0.10;
uniform float outer : hint_range(0.0, 1.5) = 0.85;
uniform float variation : hint_range(0.0, 1.0) = 0.0;
uniform vec2 lean = vec2(-0.5, 0.85);
uniform float seed = 0.0;
// How many times a second the ray set is re-drawn; 0 freezes it (reduce motion).
uniform float reroll_rate : hint_range(0.0, 30.0) = 12.0;
uniform float tone : hint_range(0.0, 1.0) = 0.0;
uniform float tone_dots = 90.0;

group_uniforms placement;
uniform vec2 center = vec2(0.5, 0.5);
// Screen-UV window (x, y, right, bottom) the rays may appear in; the default is the whole screen.
uniform vec4 safe_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float safe_fade : hint_range(0.001, 0.2) = 0.001;
// Distance (in screen heights) where the ring has faded out; 10 keeps the old unbounded behaviour.
uniform float ring_end = 10.0;

const float TWO_PI = 6.28318530718;

float hash(float n) {
	return fract(sin(n * 127.1 + seed * 17.3) * 43758.5453);
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.000001);
	vec2 p = (SCREEN_UV - center) * vec2(aspect, 1.0);
	float angle = atan(p.y, p.x);
	float dist = length(p);
	vec3 rgb = line_color.rgb;
	float mask;
	float reach;

	if (variation <= 0.001) {
		float jitter = sin(angle * 7.0) * 0.55 + sin(angle * 23.0) * 0.2;
		mask = smoothstep(0.82, 0.99, sin(angle * ray_count + jitter));
		reach = smoothstep(inner, outer, dist) * (1.0 - smoothstep(ring_end - 0.25, ring_end, dist));
	} else {
		float sector = floor((angle / TWO_PI + 0.5) * ray_count);
		float across = fract((angle / TWO_PI + 0.5) * ray_count);
		float frame = floor(TIME * reroll_rate);
		float r_presence = hash(sector);
		float r_width = hash(sector + 31.0);
		float r_start = hash(sector + 67.0);
		float r_end = hash(sector + 101.0 + frame * 0.37); // the length re-rolls each drawn frame
		float r_paint = hash(sector + 149.0);
		float r_tone = hash(sector + 211.0);
		float r_pos = hash(sector + 263.0);

		// Rays crowd toward `lean` and thin out on the far side.
		float facing = 0.5 + 0.5 * dot(normalize(p + vec2(0.0001)), normalize(lean));
		float present = step(mix(0.62, 0.18, facing * variation), r_presence);

		// Tapered: fat at the outer end, a hairline at the inner tip.
		float start_r = inner + r_start * 0.14;
		float end_r = ring_end - r_end * 0.22 * variation;
		float along = clamp((dist - start_r) / max(end_r - start_r, 0.001), 0.0, 1.0);
		float half_width = mix(0.04, 0.34, r_width) * (0.15 + 0.85 * along);
		float centre = 0.25 + 0.5 * r_pos;
		mask = (1.0 - smoothstep(half_width * 0.7, half_width, abs(across - centre))) * present;
		reach = smoothstep(start_r, start_r + 0.04, dist) * (1.0 - smoothstep(end_r - 0.05, end_r, dist));

		// A share of the rays are painted instead of inked.
		if (r_paint > 1.0 - accent_share) {
			float pick = fract(r_paint * 37.0) * 3.0;
			rgb = pick < 1.0 ? accent_a.rgb : (pick < 2.0 ? accent_b.rgb : accent_c.rgb);
		}

		// A halftone wedge rides beside some rays: a screentone patch that grows toward the outside.
		float wedge_side = centre + half_width + 0.04;
		float in_wedge = step(wedge_side, across) * (1.0 - step(wedge_side + 0.22, across)) * step(0.62, r_tone) * present;
		vec2 cell = fract(SCREEN_UV * vec2(aspect, 1.0) * tone_dots) - 0.5;
		float dot_mask = 1.0 - smoothstep(0.0, 0.5, length(cell) / max(0.12 + 0.4 * along, 0.01));
		mask = max(mask, in_wedge * dot_mask * tone * 0.8);
	}

	vec2 inside = smoothstep(safe_rect.xy, safe_rect.xy + vec2(safe_fade), SCREEN_UV)
		* (1.0 - smoothstep(safe_rect.zw - vec2(safe_fade), safe_rect.zw, SCREEN_UV));
	COLOR = vec4(rgb, line_color.a * mask * reach * inside.x * inside.y);
}
