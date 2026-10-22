// La Voiture - FASE 10 LED video wall for the grandstand Jumbotron.
// Authorship: Genex / La Voiture. Purpose: draws a live race leaderboard (ten team-coloured
// rows with a position chip and a gap bar) on a dot-matrix LED grid with an animated
// scan sweep, from two uniform arrays the game refreshes about twice a second.
// Target: Forward+, spatial, unshaded emissive. Budget: no texture reads and no loops; the
// row index is computed from the UV and looked up, with two uniform-layout branches.
shader_type spatial;
render_mode unshaded, cull_disabled;

const int ROWS = 10;

group_uniforms leaderboard;
uniform vec4 row_colors[ROWS] : source_color;
uniform float row_values[ROWS];
group_uniforms;

group_uniforms look;
uniform vec3 screen_back : source_color = vec3(0.02, 0.025, 0.04);
uniform vec3 header_color : source_color = vec3(0.0, 0.94, 1.0);
// Pixels of the LED grid across the screen width.
uniform float grid_columns : hint_range(40.0, 400.0) = 220.0;
uniform float grid_rows : hint_range(20.0, 200.0) = 84.0;
uniform float brightness : hint_range(0.0, 1.5) = 1.0;
uniform float scan_speed : hint_range(0.0, 2.0) = 0.35;
group_uniforms;

// Layout in screen UV (0..1, y down): a header band, then ROWS rows.
const float HEADER_HEIGHT = 0.12;
const float MARGIN = 0.03;
const float CHIP_START = 0.04;
const float CHIP_END = 0.115;
const float BAR_START = 0.14;
const float BAR_MAX = 0.8;
const float BAR_HEIGHT_SHARE = 0.55;
const float LED_RADIUS = 0.42;
const float SCAN_WIDTH = 0.08;
const float LEADER_BOOST = 1.35;

void fragment() {
	vec2 cell = floor(UV * vec2(grid_columns, grid_rows));
	vec2 local = fract(UV * vec2(grid_columns, grid_rows)) - 0.5;
	float led = smoothstep(LED_RADIUS, LED_RADIUS - 0.12, length(local));
	vec2 uv = (cell + 0.5) / vec2(grid_columns, grid_rows);

	vec3 colour = screen_back;
	if (uv.y < HEADER_HEIGHT) {
		// Header: a bright band with a moving highlight.
		float sweep = smoothstep(SCAN_WIDTH, 0.0, abs(fract(uv.x - TIME * scan_speed) - 0.5) - 0.4);
		colour = mix(header_color * 0.35, header_color, sweep);
	} else {
		float body = (uv.y - HEADER_HEIGHT - MARGIN) / (1.0 - HEADER_HEIGHT - 2.0 * MARGIN);
		int row = int(floor(body * float(ROWS)));
		if (body >= 0.0 && row >= 0 && row < ROWS) {
			float in_row = fract(body * float(ROWS));
			float inside_row = step(abs(in_row - 0.5), BAR_HEIGHT_SHARE * 0.5);
			vec3 team = row_colors[row].rgb;
			float boost = row == 0 ? LEADER_BOOST : 1.0;
			float chip = step(CHIP_START, uv.x) * step(uv.x, CHIP_END);
			float bar = step(BAR_START, uv.x) * step(uv.x, BAR_START + BAR_MAX * clamp(row_values[row], 0.0, 1.0));
			colour = mix(colour, team * boost, inside_row * max(chip, bar * 0.7));
		}
	}
	// Faint scan line over everything.
	float scan = 0.88 + 0.12 * sin((UV.y - TIME * scan_speed) * 60.0);
	ALBEDO = colour * led * scan * brightness;
	EMISSION = ALBEDO;
}
