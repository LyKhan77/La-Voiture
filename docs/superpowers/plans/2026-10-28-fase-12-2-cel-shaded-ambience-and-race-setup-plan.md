# Fase 12.2: Neo-Wangan Cel-Shaded Ambience & Exhibition Race Setup Overhaul Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade Neo-Wangan's visual shaders and sky/wind ambience to 100% authentic Cel-Shaded Anime with living night sky elements (Anime Moon, 900 Stars, Wind-Drifting Clouds, Wind-Waving Banners, Toon Water without PBR specular blobs, Toon Outlined Skyline, and Kanji Street Billboards), and overhaul the Exhibition Race Setup screen (`RaceSetupMenu` + `RaceConfigData`) with the Unified 12-Round Carousel, Artwork + Track Demand Profile, GP (`5/10/15` Laps) vs Sprint (`3` Laps Locked) rules, Seeded `DYNAMIC` Weather + Live Meteo Radar Strip, `RANDOM` Time of Race, and `RACE DYNAMICS` selector.

**Architecture:**
1. **Neo-Wangan Cel-Shaded Shaders & `SkyAmbienceRoot`**: Replace the flat pixel-box skyline shader, plain 3-bar billboards, and PBR `StandardMaterial3D` water in `NeoWanganEnvironment` with dedicated `diffuse_toon` / `unshaded` anime shaders (`neo_wangan_skyline.gdshader`, `neo_wangan_water.gdshader`, `neo_wangan_billboard.gdshader`, `neo_wangan_clouds.gdshader`), and add `SkyAmbienceRoot` (`AnimeMoon`, `NightStars` 900-instance MultiMesh, `AnimeNightClouds` 28-instance MultiMesh) plus `WindBannersMM` driven live by `race.weather.wind_speed` in `NeoWanganEnvironment.update(delta, race)`.
2. **Exhibition Race Setup & `RaceConfigData` Overhaul**: Extend `RaceConfigData` backward-compatibly (`LAPS = [3, 5, 10, 15]`, `weather_preset = 4` for `DYNAMIC`, `time_of_day = 3` for `RANDOM`, `race_dynamics = 0..2`, `reroll_seed()`), and refactor `scripts/ui/race_setup_menu.gd` to unify the 12-round carousel under the map, add the right-hand Artwork & Track Demand sidebar inside the map card, enforce Sprint 3-lap locking vs GP 5/10/15-lap selection, and display the live lap-by-lap Meteo Radar Forecast strip.

**Tech Stack:** Godot Engine 4.7.2 stable, GDScript 2.0 (strict static typing), Godot Shading Language (`.gdshader`).

---

## File Structure & Responsibilities

| File Path | Action | Responsibility |
| :--- | :--- | :--- |
| `shaders/neo_wangan_skyline.gdshader` | Modify | Add `diffuse_toon, specular_toon`, halftone screentone window glow, roofline neon rim, and vertical night gradient. |
| `shaders/neo_wangan_water.gdshader` | Create | Cel-shaded bay water shader with stepped toon reflections and wind-driven ripple bands (`wind_speed_kph`), eliminating the harsh PBR specular blob. |
| `shaders/neo_wangan_billboard.gdshader` | Create | Procedural Japanese Kanji/Katakana block glyph + halftone screentone + comic frame shader for `StreetBillboardMM`. |
| `shaders/neo_wangan_clouds.gdshader` | Create | Stylized 2-tone cel-shaded night cloud shader with silver/cyan rim lighting and wind-driven UV/world drift. |
| `shaders/neo_wangan_wind_banner.gdshader` | Create | Vertex-waving vertical street banner shader whose wave frequency and amplitude scale with `wind_speed_kph`. |
| `scripts/world/circuits/neo_wangan/neo_wangan_environment.gd` | Modify | Build `SkyAmbienceRoot` (`AnimeMoon`, `NightStars`, `AnimeNightClouds`), `WindBannersMM`, wire the new toon water/skyline/billboard shaders, and drive cloud drift, water ripples, and banner wave from `race.weather.wind_speed` in `update(delta, race)`. |
| `scripts/core/race_config_data.gd` | Modify | Support `total_laps` in `[3, 5, 10, 15]`, `weather_preset = 4` (`DYNAMIC` seeded forecast weighted by `circuit.rain_probability`), `time_of_day = 3` (`RANDOM` seeded roll), `race_dynamics = 0..2` (`CLEAN`, `STANDARD`, `CHAOS`), and `reroll_seed()`. |
| `scripts/ui/chip_row.gd` | Modify | Add `set_chip_disabled(index: int, disabled: bool)` helper so individual chips (e.g., `5/10/15` on Sprint or `3` on GP) can be locked/unlocked in the UI. |
| `scripts/ui/race_setup_menu.gd` | Modify | Replace dual selector with Unified 12-Round Carousel, add Artwork + Track Demand Sidebar in Map Card, enforce GP vs Sprint lap locking, add `DYNAMIC` weather + `MeteoRadarStrip`, `RANDOM` time, `RACE DYNAMICS` row, and `RerollSeedButton`. |
| `tests/test_neo_wangan_cel_ambience.gd` | Create | Headless test verifying `SkyAmbienceRoot` (`AnimeMoon`, `NightStars`, `AnimeNightClouds`), `WindBannersMM`, toon water shader, outlined skyline, kanji billboard shader, and live `wind_speed` response. |
| `tests/test_race_setup_overhaul.gd` | Create | Headless test verifying GP (5/10/15) vs Sprint (locked 3) lap rules, `DYNAMIC` weather seed divergence (`reroll_seed()`), `RANDOM` time of day resolution, `RACE DYNAMICS` application, and Unified 12-Round Carousel. |

---

### Task 1: Upgrade Neo-Wangan Shaders to Authentic Cel-Shaded Anime (Skyline, Water, Billboards, Clouds, Wind Banners)

**Files:**
- Create: `tests/test_neo_wangan_cel_ambience.gd`
- Modify: `shaders/neo_wangan_skyline.gdshader`
- Create: `shaders/neo_wangan_water.gdshader`
- Create: `shaders/neo_wangan_billboard.gdshader`
- Create: `shaders/neo_wangan_clouds.gdshader`
- Create: `shaders/neo_wangan_wind_banner.gdshader`
- Modify: `scripts/world/circuits/neo_wangan/neo_wangan_environment.gd`

- [ ] **Step 1: Write the failing test `tests/test_neo_wangan_cel_ambience.gd`**

Create `tests/test_neo_wangan_cel_ambience.gd`:
```gdscript
extends SceneTree

const CircuitScene := preload("res://scenes/race_world/neo_wangan_circuit.tscn")

var failures: int = 0
var assertions: int = 0

func check(ok: bool, msg: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + msg)
	print("[%s] %s" % ["PASS" if ok else "FAIL", msg])

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var circuit: Node3D = CircuitScene.instantiate()
	root.add_child(circuit)
	await process_frame

	var env: Node3D = circuit.get_node_or_null("Environment")
	check(env != null, "Environment node exists on Neo-Wangan circuit")

	# 1. SkyAmbienceRoot: AnimeMoon, NightStars, AnimeNightClouds
	var sky_root: Node3D = env.get_node_or_null("SkyAmbienceRoot") as Node3D
	check(sky_root != null, "SkyAmbienceRoot exists in NeoWanganEnvironment")
	if sky_root != null:
		var moon := sky_root.get_node_or_null("AnimeMoon") as MeshInstance3D
		var stars := sky_root.get_node_or_null("NightStars") as MultiMeshInstance3D
		var clouds := sky_root.get_node_or_null("AnimeNightClouds") as MultiMeshInstance3D
		check(moon != null and moon.mesh != null, "AnimeMoon mesh exists in SkyAmbienceRoot")
		check(stars != null and stars.multimesh != null and stars.multimesh.instance_count >= 600, "NightStars MultiMesh has >= 600 stars")
		check(clouds != null and clouds.multimesh != null and clouds.multimesh.instance_count >= 20, "AnimeNightClouds MultiMesh has >= 20 cloud clusters")

	# 2. WindBannersMM
	var banners := env.find_child("WindBannersMM", true, false) as MultiMeshInstance3D
	check(banners != null and banners.multimesh != null and banners.multimesh.instance_count >= 16, "WindBannersMM MultiMesh has >= 16 wind-reactive street banners")

	# 3. Cel-shaded water shader (not StandardMaterial3D PBR)
	var water := env.get_node_or_null("Water") as MeshInstance3D
	check(water != null and water.material_override is ShaderMaterial, "Bay Water uses custom cel-shaded ShaderMaterial instead of PBR StandardMaterial3D")

	# 4. Skyline uses toon shader + outline next_pass
	var skyline := env.get_node_or_null("Skyline") as MultiMeshInstance3D
	check(skyline != null and skyline.material_override is ShaderMaterial and skyline.material_override.next_pass != null, "Skyline uses ShaderMaterial with inverted-hull outline next_pass")

	# 5. StreetBillboardMM uses kanji/halftone ShaderMaterial
	var billboards := env.find_child("StreetBillboardMM", true, false) as MultiMeshInstance3D
	check(billboards != null and billboards.material_override is ShaderMaterial, "StreetBillboardMM uses custom Kanji/Halftone ShaderMaterial")

	# 6. Wind responsiveness in update(delta, race)
	var mock_weather := {"wind_speed": 38.0, "wind_direction": 1.2}
	var mock_race := {"weather": mock_weather}
	if env.has_method("apply_wind_ambience"):
		env.call("apply_wind_ambience", 0.5, 38.0, 1.2)
		check(float(env.get("current_wind_kph")) == 38.0, "NeoWanganEnvironment tracks live wind_speed from weather")
	else:
		check(false, "NeoWanganEnvironment implements apply_wind_ambience(delta, wind_kph, wind_dir)")

	# 7. Render budget stays within <= 160 draw calls and <= 320,000 tris
	var st: Dictionary = env.call("stats")
	check(int(st["draw_calls"]) <= 160 and int(st["triangles"]) <= 320000,
		"Render budget respected with sky/wind ambience: %d draw calls, %d tris" % [int(st["draw_calls"]), int(st["triangles"])])

	circuit.queue_free()
	await process_frame
	print("NEO-WANGAN CEL AMBIENCE: %d assertions, %d failure(s)" % [assertions, failures])
	quit(0 if failures == 0 else 1)
```

- [ ] **Step 2: Run the test to confirm it fails (RED)**

Run:
```powershell
godot --headless --path . -s res://tests/test_neo_wangan_cel_ambience.gd
```
Expected: FAIL because `SkyAmbienceRoot`, `WindBannersMM`, `neo_wangan_water.gdshader`, `neo_wangan_billboard.gdshader`, and `apply_wind_ambience` do not exist yet.

- [ ] **Step 3: Create the 4 new shaders and upgrade `shaders/neo_wangan_skyline.gdshader`**

1. Update `shaders/neo_wangan_skyline.gdshader` to include `render_mode cull_back, diffuse_toon, specular_toon;`, a vertical night gradient, rooftop neon trim on the top 3% of each tower face, and a halftone dot pattern inside lit windows:
```glsl
shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon;

uniform vec3 building_color = vec3(0.045, 0.055, 0.085);
uniform vec3 building_top_tint = vec3(0.09, 0.12, 0.20);
uniform vec3 window_cool = vec3(0.0, 0.94, 1.0);
uniform vec3 window_warm = vec3(1.0, 0.62, 0.22);
uniform vec3 roof_neon_color = vec3(1.0, 0.12, 0.46);
uniform float window_energy : hint_range(0.0, 8.0) = 1.9;
uniform vec2 window_cell = vec2(4.6, 3.2);
uniform float lit_fraction : hint_range(0.0, 1.0) = 0.32;

varying vec3 world_pos;
varying float local_y;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_y = VERTEX.y + 0.5;
}

void fragment() {
	vec3 abs_normal = abs(NORMAL);
	float wall = step(abs_normal.y, 0.5);
	vec2 uv = abs_normal.x > abs_normal.z ? world_pos.zy : world_pos.xy;
	vec2 cells = uv / window_cell;
	vec2 cell = floor(cells);
	vec2 local = fract(cells);
	float pane = step(0.20, local.x) * step(local.x, 0.80) * step(0.26, local.y) * step(local.y, 0.76);
	// Halftone screen modulation inside windows for manga feel
	vec2 dot_uv = fract(local * vec2(3.0, 2.0)) - vec2(0.5);
	float halftone = step(length(dot_uv), 0.62);
	float lit = step(lit_fraction, hash21(cell));
	float warm = step(0.76, hash21(cell + 17.0));
	float roof_band = step(0.965, local_y) * wall;
	vec3 win_col = mix(window_cool, window_warm, warm) * (0.7 + 0.3 * halftone);
	vec3 glow = win_col * window_energy * lit * pane * wall + roof_neon_color * roof_band * 2.2;
	ALBEDO = mix(building_color, building_top_tint, clamp(local_y, 0.0, 1.0));
	EMISSION = glow;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
}
```

2. Create `shaders/neo_wangan_water.gdshader` (unshaded/cel-stepped anime water with wind-driven wave lines, zero harsh PBR specular blob):
```glsl
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_disabled;

uniform vec3 deep_color : source_color = vec3(0.025, 0.065, 0.125);
uniform vec3 band_color : source_color = vec3(0.05, 0.16, 0.28);
uniform vec3 neon_ripple_cyan : source_color = vec3(0.0, 0.90, 1.0);
uniform vec3 neon_ripple_magenta : source_color = vec3(1.0, 0.18, 0.46);
uniform float wind_speed_kph : hint_range(0.0, 60.0) = 14.0;
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float time_s = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 dir = normalize(wind_dir + vec2(0.0001));
	float speed = 0.35 + (wind_speed_kph / 45.0) * 1.45;
	vec2 p = world_pos.xz * 0.085;
	float wave_a = sin(dot(p, dir) * 3.2 - time_s * speed * 2.4 + sin(p.x * 1.7 + time_s * 0.8));
	float wave_b = cos(dot(p.yx, dir) * 2.5 - time_s * speed * 1.8);
	float combined = (wave_a + wave_b) * 0.5;
	// Stepped cel bands instead of smooth PBR gradients
	float band = step(0.28, combined);
	float crest = step(0.74, combined);
	float neon_pick = step(0.0, sin(world_pos.x * 0.03 + world_pos.z * 0.02));
	vec3 crest_col = mix(neon_ripple_cyan, neon_ripple_magenta, neon_pick);
	ALBEDO = mix(deep_color, band_color, band);
	EMISSION = band_color * 0.25 + crest_col * crest * 0.55;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}
```

3. Create `shaders/neo_wangan_billboard.gdshader` (procedural stylized Japanese Kanji/Katakana stroke blocks + halftone screentone dots + comic ink border using `COLOR` instance color):
```glsl
shader_type spatial;
render_mode cull_back, unshaded;

varying vec3 inst_color;
varying vec2 face_uv;
varying float is_front_or_back;

float hash21(vec2 p) {
	p = fract(p * vec2(234.17, 512.83));
	p += dot(p, p + 33.7);
	return fract(p.x * p.y);
}

void vertex() {
	inst_color = COLOR.rgb;
	face_uv = VERTEX.xy / vec2(10.0, 5.5) + vec2(0.5);
	is_front_or_back = step(0.5, abs(NORMAL.z));
}

void fragment() {
	if (is_front_or_back < 0.5) {
		ALBEDO = vec3(0.06, 0.08, 0.13);
	} else {
		vec2 uv = clamp(face_uv, 0.0, 1.0);
		float border = step(0.05, uv.x) * step(uv.x, 0.95) * step(0.08, uv.y) * step(uv.y, 0.92);
		// Halftone diagonal gradient background
		vec2 dot_grid = fract(uv * vec2(28.0, 16.0)) - vec2(0.5);
		float dots = step(length(dot_grid), (1.0 - uv.y) * 0.42);
		// Procedural Kanji / Streetwear glyph cells (4 character blocks across the sign)
		vec2 char_space = vec2(uv.x * 5.0 - 0.5, (uv.y - 0.24) * 2.1);
		float in_char_row = step(0.0, char_space.x) * step(char_space.x, 4.0) * step(0.0, char_space.y) * step(char_space.y, 1.0);
		vec2 c_id = floor(vec2(char_space.x, 0.0));
		vec2 c_uv = fract(char_space);
		// 5x5 stroke matrix per Kanji block
		vec2 stroke_cell = floor(c_uv * 5.0);
		float pad = step(0.12, c_uv.x) * step(c_uv.x, 0.88) * step(0.10, c_uv.y) * step(c_uv.y, 0.90);
		float h_bar = step(abs(stroke_cell.y - 1.0), 0.1) + step(abs(stroke_cell.y - 3.0), 0.1);
		float v_bar = step(abs(stroke_cell.x - 2.0), 0.1);
		float rand_stroke = step(0.42, hash21(stroke_cell + c_id * 7.0 + floor(inst_color.rg * 13.0)));
		float kanji_glyph = clamp(h_bar * 0.6 + v_bar * 0.6 + rand_stroke, 0.0, 1.0) * pad * in_char_row;
		// Bottom sub-banner stripe
		float sub_stripe = step(0.12, uv.x) * step(uv.x, 0.88) * step(0.12, uv.y) * step(uv.y, 0.19);
		vec3 bg = mix(inst_color * 0.85, inst_color * 0.45, dots * 0.5);
		vec3 dark_ink = vec3(0.04, 0.06, 0.10);
		vec3 face = mix(bg, dark_ink, clamp(kanji_glyph + sub_stripe, 0.0, 1.0));
		// Bright white/neon kanji highlight on dark ink
		float inner_glyph = kanji_glyph * step(0.22, fract(c_uv.x * 5.0)) * step(0.22, fract(c_uv.y * 5.0));
		face = mix(face, vec3(0.98, 0.99, 1.0), inner_glyph * 0.85);
		ALBEDO = mix(dark_ink, face, border);
	}
}
```

4. Create `shaders/neo_wangan_clouds.gdshader` (cel-shaded anime night clouds with moonlight silver/cyan rim and dark indigo base):
```glsl
shader_type spatial;
render_mode cull_back, unshaded;

uniform vec3 cloud_shadow : source_color = vec3(0.07, 0.09, 0.17);
uniform vec3 cloud_mid : source_color = vec3(0.15, 0.20, 0.34);
uniform vec3 cloud_rim : source_color = vec3(0.58, 0.78, 0.98);

varying float height_factor;

void vertex() {
	height_factor = clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0);
}

void fragment() {
	float top_band = step(0.55, height_factor);
	float rim_band = step(0.82, height_factor);
	vec3 col = mix(cloud_shadow, cloud_mid, top_band);
	col = mix(col, cloud_rim, rim_band);
	ALBEDO = col;
}
```

5. Create `shaders/neo_wangan_wind_banner.gdshader` (vertex-animated vertical flag/banner that waves with `wind_speed_kph`):
```glsl
shader_type spatial;
render_mode cull_disabled, unshaded;

uniform float wind_speed_kph : hint_range(0.0, 60.0) = 14.0;
uniform float time_s = 0.0;

varying vec3 banner_col;
varying vec2 uv_coord;

void vertex() {
	banner_col = COLOR.rgb;
	uv_coord = UV;
	float free_edge = clamp((VERTEX.x + 0.45) / 0.9, 0.0, 1.0);
	float freq = 3.5 + (wind_speed_kph / 45.0) * 6.5;
	float amp = 0.06 + (wind_speed_kph / 45.0) * 0.24;
	float wave = sin(time_s * freq + VERTEX.y * 2.8 + float(INSTANCE_ID) * 1.7) * amp * free_edge;
	VERTEX.z += wave;
}

void fragment() {
	float stripe = step(0.68, fract(uv_coord.y * 3.0));
	ALBEDO = mix(banner_col, vec3(0.05, 0.07, 0.11), stripe * 0.7);
}
```

- [ ] **Step 4: Integrate `SkyAmbienceRoot`, `WindBannersMM`, and live wind updates in `scripts/world/circuits/neo_wangan/neo_wangan_environment.gd`**

In `scripts/world/circuits/neo_wangan/neo_wangan_environment.gd`:
1. Preload the new shaders:
   - `const WaterShader := preload("res://shaders/neo_wangan_water.gdshader")`
   - `const BillboardShader := preload("res://shaders/neo_wangan_billboard.gdshader")`
   - `const CloudShader := preload("res://shaders/neo_wangan_clouds.gdshader")`
   - `const WindBannerShader := preload("res://shaders/neo_wangan_wind_banner.gdshader")`
2. Add properties:
   - `var sky_ambience_root: Node3D`
   - `var cloud_instance: MultiMeshInstance3D`
   - `var star_instance: MultiMeshInstance3D`
   - `var moon_instance: MeshInstance3D`
   - `var wind_banner_instance: MultiMeshInstance3D`
   - `var _water_shader_mat: ShaderMaterial`
   - `var _banner_shader_mat: ShaderMaterial`
   - `var _cloud_base_poses: Array[Transform3D] = []`
   - `var _cloud_drift_m: float = 0.0`
   - `var current_wind_kph: float = 12.0`
3. In `build()`:
   - Create `sky_ambience_root = _layer("SkyAmbienceRoot")` and call `_build_sky_ambience()` and `_build_wind_banners()`.
   - In `_water_material()`: return a `ShaderMaterial` using `WaterShader` stored in `_water_shader_mat`.
   - In `_build_skyline()`: attach an `OutlineShader` `next_pass` (`outline_width = 0.18`, `outline_color = Color(0.02, 0.03, 0.05)`) to `_window_material`.
   - In `_build_street_corridor()`: build `StreetBillboardMM` with a single `BoxMesh` (`Vector3(10.0, 5.5, 0.45)`) and assign a `ShaderMaterial` with `BillboardShader` as `material_override`!
4. Implement `_build_sky_ambience()`:
   - **`AnimeMoon`**: Create a `SphereMesh` (`radius = 85.0, height = 170.0, radial_segments = 16, rings = 8`) with an unshaded `ShaderMaterial` or `StandardMaterial3D` (`SHADING_MODE_UNSHADED`, `albedo_color = Color("#fff8d6")`, `disable_fog = true`) positioned at `Vector3(-650.0, 780.0, -1100.0)` under `sky_ambience_root`, `cast_shadow = OFF`.
   - **`NightStars`**: Create a 900-instance `MultiMeshInstance3D` on a hemisphere (`R = 2400.0`, elevation $5^\circ\text{..}88^\circ$) with unshaded billboard quads (`disable_fog = true`, `cast_shadow = OFF`).
   - **`AnimeNightClouds`**: Create a 28-instance `MultiMeshInstance3D` using a merged cluster of 3 flattened spheres/boxes per cloud (`CloudShader`, `cast_shadow = OFF`) distributed around a ring (`R = 450..1200 m`, `Y = 240..380 m`), storing `_cloud_base_poses`.
5. Implement `_build_wind_banners()`:
   - Place 24 vertical banners (`BoxMesh` `Vector3(0.9, 2.4, 0.04)`) attached to streetlight poles along the bridge and harbor (`WindBannerShader` in `_banner_shader_mat`, `use_colors = true` with Cyan/Magenta/Lime team accent colors, `cast_shadow = OFF`) under `hero_landmarks_root`.
6. Implement `apply_wind_ambience(delta: float, wind_kph: float, wind_dir: float) -> void` and call it from `update(delta, race)`:
   - Read `var wind_kph: float = float(race.weather.wind_speed) if race != null and race.get("weather") != null else 14.0` and `var wind_dir: float = float(race.weather.wind_direction) if race != null and race.get("weather") != null else 0.6`.
   - Update `current_wind_kph = wind_kph`.
   - Update `_water_shader_mat` uniforms (`time_s = _clock_s`, `wind_speed_kph = wind_kph`, `wind_dir = Vector2(cos(wind_dir), sin(wind_dir))`).
   - Update `_banner_shader_mat` uniforms (`time_s = _clock_s`, `wind_speed_kph = wind_kph`).
   - Advance `_cloud_drift_m = fmod(_cloud_drift_m + delta * (3.0 + wind_kph * 0.45), 2400.0)` and rotate/translate `cloud_instance` slowly around the Y axis (`cloud_instance.rotation.y = _clock_s * (0.004 + wind_kph * 0.00035)`) so the clouds visibly drift across the moon and skyline!

- [ ] **Step 5: Run `test_neo_wangan_cel_ambience.gd` and `test_neo_wangan_circuit.gd` (GREEN)**

Run:
```powershell
godot --headless --path . -s res://tests/test_neo_wangan_cel_ambience.gd
godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd
```
Expected: 100% PASS (0 FAIL). Commit Task 1.

---

### Task 2: Extend `RaceConfigData` & `ChipRow` for GP/Sprint Lap Rules, Seeded `DYNAMIC` Weather, `RANDOM` Time, and `RACE DYNAMICS`

**Files:**
- Create: `tests/test_race_setup_overhaul.gd`
- Modify: `scripts/core/race_config_data.gd`
- Modify: `scripts/ui/chip_row.gd`

- [ ] **Step 1: Write the failing test `tests/test_race_setup_overhaul.gd`**

Create `tests/test_race_setup_overhaul.gd`:
```gdscript
extends SceneTree

const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const MenuScene := preload("res://scenes/ui/race_setup_menu.tscn")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")

var failures: int = 0
var assertions: int = 0

func check(ok: bool, msg: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + msg)
	print("[%s] %s" % ["PASS" if ok else "FAIL", msg])

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var cfg: RefCounted = ConfigScript.reset()

	# 1. Dynamic weather (preset 4) uses race_seed and diverges across seeds
	cfg.selected_circuit_id = "neo_wangan"
	cfg.total_laps = 10
	cfg.weather_preset = 4 # DYNAMIC
	var seen_archetypes: Dictionary = {}
	var seen_forecasts: Dictionary = {}
	for s: int in [101, 202, 303, 404, 505, 606, 707, 808]:
		cfg.race_seed = s
		var w = cfg.make_weather()
		seen_archetypes[w.archetype] = true
		var sig: String = ""
		for entry: Dictionary in w.forecast:
			sig += "%d:%.2f," % [int(entry["lap"]), float(entry["rain_intensity"])]
		seen_forecasts[sig] = true
	check(seen_archetypes.size() >= 2 and seen_forecasts.size() >= 4,
		"DYNAMIC weather (preset 4) produces seed-dependent archetypes (%d) and lap-by-lap forecasts (%d)" % [seen_archetypes.size(), seen_forecasts.size()])

	# 2. Random Time of Day (time_of_day = 3) resolves deterministically to 0, 1, or 2 per seed
	cfg.time_of_day = 3
	var seen_tod: Dictionary = {}
	for s: int in [11, 22, 33, 44, 55, 66, 77, 88, 99]:
		cfg.race_seed = s
		var tod_mode: int = int(cfg.make_weather().time_of_day["mode"])
		check(tod_mode >= 0 and tod_mode <= 2, "RANDOM time_of_day resolves to valid mode 0..2 (got %d)" % tod_mode)
		seen_tod[tod_mode] = true
	check(seen_tod.size() >= 2, "RANDOM time_of_day rolls different times across seeds")

	# 3. reroll_seed() changes race_seed
	var old_seed: int = cfg.race_seed
	var new_seed: int = int(cfg.call("reroll_seed"))
	check(new_seed != old_seed and cfg.race_seed == new_seed, "reroll_seed() generates and assigns a new race_seed")

	# 4. UI Menu GP (5/10/15) vs Sprint (Locked 3 Laps) & Unified Carousel
	var menu: Control = MenuScene.instantiate()
	root.add_child(menu)
	await process_frame

	# Select Round 01 Apex Ring (GP)
	menu.call("select_circuit", "apex_ring")
	await process_frame
	check(not menu.lap_select.is_chip_disabled(1) and not menu.lap_select.is_chip_disabled(2) and not menu.lap_select.is_chip_disabled(3),
		"GP circuit (Apex Ring) unlocks 5, 10, and 15 lap chips")
	menu.call("select_laps", 15)
	check(cfg.total_laps == 15, "GP circuit allows selecting 15 Laps Endurance GP")

	# Select Round 02 Neo-Wangan (SPRINT)
	menu.call("select_circuit", "neo_wangan")
	await process_frame
	check(cfg.total_laps == 3 and menu.lap_select.selected == 0,
		"Selecting a SPRINT circuit (Neo-Wangan) automatically locks total_laps to 3")
	check(menu.lap_select.is_chip_disabled(1) and menu.lap_select.is_chip_disabled(2) and menu.lap_select.is_chip_disabled(3),
		"SPRINT circuit disables 5, 10, and 15 lap chips in UI")

	# Verify Unified Carousel cards & Artwork/Demand sidebar nodes exist
	check(menu.find_child("VenuePreviewArt", true, false) != null, "VenuePreviewArt exists in Hero Map Card")
	check(menu.find_child("TrackDemandPanel", true, false) != null, "TrackDemandPanel exists in Hero Map Card")
	check(menu.find_child("MeteoRadarStrip", true, false) != null, "MeteoRadarStrip exists for live weather forecast preview")
	check(menu.find_child("RerollSeedButton", true, false) != null, "RerollSeedButton exists in Race Setup")
	check(menu.find_child("dynamics_select", true, false) != null, "Race Dynamics selector (Opsi A) exists in Race Setup")

	menu.queue_free()
	await process_frame
	print("RACE SETUP OVERHAUL: %d assertions, %d failure(s)" % [assertions, failures])
	quit(0 if failures == 0 else 1)
```

- [ ] **Step 2: Run `test_race_setup_overhaul.gd` to confirm it fails (RED)**

Run:
```powershell
godot --headless --path . -s res://tests/test_race_setup_overhaul.gd
```
Expected: FAIL.

- [ ] **Step 3: Update `scripts/ui/chip_row.gd` and `scripts/core/race_config_data.gd`**

1. In `scripts/ui/chip_row.gd`, add `set_chip_disabled(index: int, is_disabled: bool)` and `is_chip_disabled(index: int) -> bool`:
```gdscript
func set_chip_disabled(index: int, is_disabled: bool) -> void:
	if index < 0 or index >= buttons.size():
		return
	buttons[index].disabled = is_disabled
	buttons[index].focus_mode = Control.FOCUS_NONE if is_disabled else Control.FOCUS_ALL

func is_chip_disabled(index: int) -> bool:
	if index < 0 or index >= buttons.size():
		return false
	return buttons[index].disabled
```

2. In `scripts/core/race_config_data.gd`:
   - Add `var race_dynamics: int = 1` (`0 = CLEAN PACE`, `1 = FIA STANDARD`, `2 = STREET CHAOS`).
   - Add `func reroll_seed() -> int`:
     ```gdscript
     func reroll_seed() -> int:
     	var next_seed: int = randi_range(1, 2147483647)
     	if next_seed == race_seed:
     		next_seed = (race_seed % 2147483640) + 1
     	race_seed = next_seed
     	return race_seed
     ```
   - Add `func resolved_time_of_day() -> int`:
     ```gdscript
     func resolved_time_of_day() -> int:
     	if time_of_day == 3:
     		return Rng.new(race_seed + 77).range_int(0, 2)
     	return clampi(time_of_day, 0, 2)
     ```
   - Update `weather_archetype(seed_value: int) -> int`:
     * When `weather_preset == 4` (`DYNAMIC`), use `Rng.new(seed_value + 31)` and `get_active_circuit().rain_probability`:
       ```gdscript
       	if weather_preset == 4:
       		var rng := Rng.new(seed_value + 31)
       		var rain_prob: float = get_active_circuit().rain_probability
       		var roll: float = rng.next()
       		if roll < rain_prob * 0.45:
       			return Weather.Archetype.DRY_TO_STORM
       		elif roll < rain_prob * 0.85:
       			return Weather.Archetype.PASSING_SHOWERS
       		elif roll < rain_prob * 1.15:
       			return Weather.Archetype.WET_DRYING
       		elif roll < rain_prob + 0.25:
       			return Weather.Archetype.OVERCAST_GUSTY
       		return Weather.Archetype.DRY_SUNNY
       ```
   - In `apply_weather(weather: GtWeather)`:
     * Only run the static `if weather_preset >= 2:` flattening block when `weather_preset == 2 or weather_preset == 3`! When `weather_preset == 4` (`DYNAMIC`), leave `weather.forecast` untouched so `GtWeather`'s authentic lap-by-lap curve is preserved!
     * Use `resolved_time_of_day()` in `Weather.compute_time_of_day(resolved_time_of_day(), 0.0)`.
   - In `apply_to_race(race: GtRace)`:
     * Apply `race.incidents_enabled = (race_dynamics != 0)`.
     * When `weather.track_water_pct > 15.0` at race start (including `weather_preset == 2, 3` or a wet `DYNAMIC` start), fit AI rivals with `WET` (>50%) or `INTERMEDIATE` (>15%).

---

### Task 3: Overhaul `scripts/ui/race_setup_menu.gd` (Unified Carousel, Artwork + Demand Sidebar, GP/Sprint Lap Lock, Meteo Radar Strip, Random Time & Race Dynamics)

**Files:**
- Modify: `scripts/ui/race_setup_menu.gd`

- [ ] **Step 1: Update constants and layout in `scripts/ui/race_setup_menu.gd`**

In `scripts/ui/race_setup_menu.gd`:
1. Update constants:
   - `const LAPS: Array[int] = [3, 5, 10, 15]`
   - `const LAP_CHIPS: Array[String] = ["3", "5", "10", "15"]`
   - `const WEATHER_CHIPS: Array[String] = ["SUNNY", "RAIN?", "WET", "MONSOON", "DYNAMIC"]`
   - `const WEATHER_NAMES: Array[String] = ["SUNNY DRY // 100% GRIP", "THREATENING RAIN // 60% SHOWER", "DYNAMIC WET // DAMP LINE", "FULL MONSOON // LOW VISIBILITY", "DYNAMIC RADAR // LIVE FORECAST"]`
   - `const TIME_CHIPS: Array[String] = ["DAY", "SUNSET", "NIGHT", "RANDOM"]`
   - `const TIME_NAMES: Array[String] = ["DAYLIGHT", "GOLDEN HOUR SUNSET", "NIGHT CIRCUIT", "RANDOM // SEED ROLL"]`
   - `const DYNAMICS_CHIPS: Array[String] = ["CLEAN", "STANDARD", "CHAOS"]`
   - `const DYNAMICS_NAMES: Array[String] = ["CLEAN PACE", "FIA STANDARD", "STREET CHAOS"]`
2. In `_build_map_card()`:
   - Narrow `radar` inside the `1140 × 640` card to `Vector2(780.0, 604.0)` on the left, and build the right-hand sidebar (`x = 804..1124`) containing:
     * `VenuePreviewArt` (`TextureRect` loading `selected.preview_image_path` if `ResourceLoader.exists(selected.preview_image_path)`, or a stylized fallback preview texture).
     * `TrackDemandPanel` (`Control` with 3 `ProgressBar`s: `TOP SPEED`, `CORNERING GRIP`, `TYRE STRESS` computed deterministically from `selected.length_km`, `selected.turns_count`, `selected.elevation_delta_m`).
     * `VenueNotesLabel` (`Label` showing `selected.notes`).
   - Store the top-right status badge in `var status_badge: Label` so `_show_circuit()` updates it between `"ACTIVE // READY"` (Acid Lime) and `"IN PREPARATION"` (Cyber Yellow).
3. Replace `_build_venue_strip()` + `_build_track_selector()` with the **Unified 12-Round Interactive Carousel** (`y = 852..956`) directly beneath the Hero Map Card (`x = 60..1200`):
   - `TrackPrevButton` (`<` at `x = 60, y = 876, size = 52×76`) and `TrackNextButton` (`>` at `x = 1148, y = 876, size = 52×76`).
   - 4 interactive `Button` cards (`CarouselCard0..3`, width `246`, height `76`, gap `10`) showing a sliding 4-round window of `CircuitRegistry.get_all_circuits()` centered/starting around the active round, where clicking any card immediately calls `select_circuit(card_circuit.circuit_id)`.
   - Keep the official metadata labels (`CircuitRoundLabel`, `CircuitNameLabel`, `CircuitTypeLabel`, `CircuitLengthLabel`, `CircuitTurnsLabel`) cleanly positioned in the carousel header bar (`y = 846`) so both the user and `tests/test_track_selector_ui.gd` read the exact active circuit metadata!
4. In `_build_parameters()` (`x = 1240..1860`):
   - Add `RerollSeedButton` (`"🎲 SEED #%d" % config.race_seed`) on the right side of the `RACE PARAMETERS` header bar. Clicking it calls `config.reroll_seed()`, updates the button text, refreshes `MeteoRadarStrip`, and updates `SetupSummary`.
   - Build compact `ChipRow`s for:
     * `lap_select` (`y = 244`, chips `["3", "5", "10", "15"]`) + `LapRuleBadge` label (`"SPRINT LOCKED: 3 LAPS"` vs `"GP FORMAT: 5 / 10 / 15 LAPS"`).
     * `weather_select` (`y = 332`, chips `["SUNNY", "RAIN?", "WET", "MONSOON", "DYNAMIC"]`) + `MeteoRadarStrip` (`y = 408, h = 44`) showing 6 lap forecast cells (`L1..L6`) with dry/rain percentages from `config.make_weather().forecast`.
     * `time_select` (`y = 460`, chips `["DAY", "SUNSET", "NIGHT", "RANDOM"]`).
     * `dynamics_select` (`y = 544`, chips `["CLEAN", "STANDARD", "CHAOS"]`).
   - Position `stat_length`, `stat_corners`, `stat_record`, `circuit_facts_label` at `y = 632..695` and `SetupSummary` box at `y = 718..846`.
5. In `_show_circuit(selected: CircuitDataScript)`:
   - Enforce **GP vs Sprint Lap Rule**:
     * If `selected.is_sprint()`:
       - `config.total_laps = 3`
       - `lap_select.select(0)`
       - `lap_select.set_chip_disabled(0, false)`
       - `for i in [1, 2, 3]: lap_select.set_chip_disabled(i, true)`
     * Else (Grand Prix):
       - `lap_select.set_chip_disabled(0, true)`
       - `for i in [1, 2, 3]: lap_select.set_chip_disabled(i, false)`
       - If `config.total_laps == 3`: `config.total_laps = 5`; `lap_select.select(1)`

- [ ] **Step 2: Run all UI & Overhaul tests (GREEN)**

Run:
```powershell
godot --headless --path . -s res://tests/test_race_setup_overhaul.gd
godot --headless --path . -s res://tests/test_track_selector_ui.gd
godot --headless --path . -s res://tests/test_main_menu_flow.gd
```
Expected: 100% PASS (0 FAIL). Commit Task 2 & Task 3.

---

### Task 4: Re-Render 6-Camera Visual Gate, Capture Race Setup Screenshots, Run Full 50-Test Suite & Write Official Report

**Files:**
- Modify: `scratch/capture_phase12_views.gd` (ensure sky/moon/clouds/billboards/water are visible in the 6 camera angles)
- Create: `executor-report/reports/FASE-12-2-CEL-SHADED-AMBIENCE-AND-RACE-SETUP-REPORT.md`
- Modify: `ROADMAP.md`

- [ ] **Step 1: Render the 6 Neo-Wangan Camera Gates + 2 Race Setup Screenshots (GP vs Sprint)**
  - Render `executor-report/screenshots/phases/phase-12-2-cam1..6-*.png` (1920×1080) and `phase-12-2-race-setup-gp.png` + `phase-12-2-race-setup-sprint.png`.
  - Visually inspect every PNG with `read_file` to verify:
    1. `AnimeMoon`, `NightStars`, and `AnimeNightClouds` are visible in the night sky.
    2. `Water` under the Shuto Bay Bridge shows cel-shaded wind ripple bands with **zero harsh white PBR specular blob**.
    3. `Skyline` has stepped toon shading, rooftop neon trim, halftone windows, and outline ink.
    4. `StreetBillboardMM` displays crisp Japanese Kanji block graphics + halftone dots instead of 3 plain bars.
    5. `RaceSetupMenu` shows the unified 12-round carousel, artwork + demand bars, Meteo Radar strip, and locked 3 laps on Sprint vs 5/10/15 laps on GP.

- [ ] **Step 2: Run the complete headless test suite (50 suites)**
  - Run all `tests/test_*.gd` suites and verify **50/50 PASS (0 FAIL)**.
  - Write `executor-report/reports/FASE-12-2-CEL-SHADED-AMBIENCE-AND-RACE-SETUP-REPORT.md` and update `ROADMAP.md`.
