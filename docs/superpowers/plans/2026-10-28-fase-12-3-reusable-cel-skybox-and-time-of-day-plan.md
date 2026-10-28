# Fase 12.3: Shared Reusable Cel-Skybox & Multi-Time-of-Day (`DAY / SUNSET / NIGHT`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify the skybox and time-of-day ambience across circuits into a reusable `SharedCelSkyController` (`scripts/world/shared_cel_sky_controller.gd`) and upgrade `NeoWanganEnvironment` + `TrackEnvironmentBuilder` so both circuits render cohesive Cel-Shaded **Day (`0`)**, **Sunset (`1`)**, and **Night (`2`)** environments while keeping all 51 headless test suites 100% green.

**Architecture:**
1. **`SharedCelSkyController` (`scripts/world/shared_cel_sky_controller.gd`)**: Builds and drives `SkyAmbienceRoot` (`AnimeMoon` acting as Cel-Shaded Sun in Day/Sunset and Halftone Moon in Night, `NightStars` fading with `stars_opacity`, and `AnimeNightClouds` 28-puff 3D cel clouds rotating with `wind_speed` and retinting for Day/Sunset/Night + storm gloom).
2. **`NeoWanganEnvironment` (`scripts/world/neo_wangan_environment.gd`)**: Delegates sky dome creation/updates to `SharedCelSkyController` and implements `apply_time_of_day(tod: Dictionary, gloom: float = 0.0)` to adapt the ProceduralSky, Fog, `Skyline` shader (`window_energy`, `roof_neon_energy`, daytime concrete/steel palette vs sunset vs midnight), `Water` shader (`deep_color`, `band_color`, `crest_emission`), and `StreetlightHeads` / `StreetlightPools` (OFF during clear `DAY`, ON during `SUNSET`/`NIGHT` or heavy storm gloom, while underground `TunnelNeon` stays ON).
3. **`TrackEnvironmentBuilder` (`scripts/world/track_environment_builder.gd`)**: Attaches `SharedCelSkyController` (`include_stars = false` so `MountainVista`'s existing `Stars` node remains the single starfield for `test_track_environment.gd`) and updates it from `TrackEnvironmentBuilder.update(delta, race)` so Apex Ring also gets the Cel Sun/Moon and wind-driven 3D Anime Clouds across Day, Sunset, and Night.

**Tech Stack:** Godot Engine 4.7.2 stable, GDScript 2.0 (strict static typing), Godot Shading Language (`.gdshader`).

---

## File Map

| File | Action | Purpose |
| :--- | :--- | :--- |
| `shaders/neo_wangan_stars.gdshader` | Modify | Add `uniform float star_opacity : hint_range(0.0, 1.0) = 1.0;` to fade stars in Sunset/Day |
| `shaders/neo_wangan_skyline.gdshader` | Modify | Add `uniform float roof_neon_energy : hint_range(0.0, 4.0) = 2.2;` so roof neon turns off in Day |
| `shaders/neo_wangan_water.gdshader` | Modify | Add `uniform float band_emission = 0.25;` and `uniform float crest_emission = 0.70;` for Day/Sunset/Night water |
| `scripts/world/shared_cel_sky_controller.gd` | Create | Reusable Cel-Skybox builder & Day/Sunset/Night + Wind updater (`SkyAmbienceRoot`, `AnimeMoon`, `NightStars`, `AnimeNightClouds`) |
| `scripts/world/neo_wangan_environment.gd` | Modify | Use `SharedCelSkyController` and add `apply_time_of_day(tod, gloom)` called by `update(delta, race)` |
| `scripts/world/track_environment_builder.gd` | Modify | Attach `SharedCelSkyController` (`include_stars = false`) and update it in `update(delta, race)` |
| `tests/test_reusable_sky_and_time_of_day.gd` | Create | Headless TDD suite verifying `SharedCelSkyController`, Neo-Wangan `DAY`/`SUNSET`/`NIGHT` transitions, and Apex Ring sky integration |
| `scratch/capture_phase12_3_views.gd` | Create | Native 1920×1080 screenshot capture for Neo-Wangan Day, Sunset, Night, and Apex Ring Cel-Sky |

---

## Task 1: Upgrade Shaders & Create `SharedCelSkyController` (TDD)

**Files:**
- Create: `tests/test_reusable_sky_and_time_of_day.gd`
- Modify: `shaders/neo_wangan_stars.gdshader`
- Modify: `shaders/neo_wangan_skyline.gdshader`
- Modify: `shaders/neo_wangan_water.gdshader`
- Create: `scripts/world/shared_cel_sky_controller.gd`

- [ ] **Step 1: Write the failing test `tests/test_reusable_sky_and_time_of_day.gd`**

```gdscript
extends SceneTree

## Fase 12.3 TDD: Reusable SharedCelSkyController + Neo-Wangan & Apex Ring DAY / SUNSET / NIGHT support.
## Run: godot --headless --path . -s res://tests/test_reusable_sky_and_time_of_day.gd

const WanganScene := preload("res://scenes/race_world/neo_wangan_circuit.tscn")
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const SharedSkyPath := "res://scripts/world/shared_cel_sky_controller.gd"


class StubRace extends RefCounted:
	var weather: GtWeather


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
	check(ResourceLoader.exists(SharedSkyPath), "SharedCelSkyController script exists at " + SharedSkyPath)

	# 1. Neo-Wangan DAY vs SUNSET vs NIGHT transitions
	var circuit: Node3D = WanganScene.instantiate()
	root.add_child(circuit)
	await process_frame

	var env: Node3D = circuit.get_node_or_null("Environment")
	check(env != null and env.has_method("apply_time_of_day"), "NeoWanganEnvironment implements apply_time_of_day(tod, gloom)")

	var sky_root := env.get_node_or_null("SkyAmbienceRoot") as Node3D
	var moon := sky_root.get_node_or_null("AnimeMoon") as MeshInstance3D if sky_root != null else null
	var stars := sky_root.get_node_or_null("NightStars") as MultiMeshInstance3D if sky_root != null else null
	var clouds := sky_root.get_node_or_null("AnimeNightClouds") as MultiMeshInstance3D if sky_root != null else null
	var skyline := env.get_node_or_null("Skyline") as MultiMeshInstance3D
	var pools := env.get_node_or_null("StreetlightPools") as MultiMeshInstance3D
	var tunnel_neon := env.get_node_or_null("TunnelNeon") as MultiMeshInstance3D

	# Test DAY (mode 0)
	var race := StubRace.new()
	race.weather = WeatherScript.new(5, 101, WeatherScript.Archetype.DRY_SUNNY)
	race.weather.time_of_day = WeatherScript.compute_time_of_day(WeatherScript.TimeOfDay.DAY, 0.0)
	env.call("update", 0.1, race)

	var day_win_energy: float = float((skyline.material_override as ShaderMaterial).get_shader_parameter("window_energy")) if skyline != null else -1.0
	var day_craters: float = float((moon.material_override as ShaderMaterial).get_shader_parameter("crater_density")) if moon != null else -1.0
	check(stars != null and not stars.visible, "Neo-Wangan DAY: NightStars are hidden in daytime")
	check(is_zero_approx(day_win_energy), "Neo-Wangan DAY: Skyline neon window_energy is 0.0 in daytime (got %.2f)" % day_win_energy)
	check(is_zero_approx(day_craters) and moon.position.y >= 850.0, "Neo-Wangan DAY: Celestial disc acts as high Anime Sun with 0 craters")
	check(pools != null and not pools.visible, "Neo-Wangan DAY: Streetlight asphalt pools are turned off in clear daytime")
	check(tunnel_neon != null and tunnel_neon.visible, "Neo-Wangan DAY: Underground tunnel neon remains visible in daytime")

	# Test SUNSET (mode 1)
	race.weather.time_of_day = WeatherScript.compute_time_of_day(WeatherScript.TimeOfDay.SUNSET, 0.5)
	env.call("update", 0.1, race)
	var sunset_win_energy: float = float((skyline.material_override as ShaderMaterial).get_shader_parameter("window_energy")) if skyline != null else -1.0
	var sunset_cloud_rim: Color = (clouds.material_override as ShaderMaterial).get_shader_parameter("cloud_rim") if clouds != null else Color.BLACK
	check(sunset_win_energy > 0.2 and sunset_win_energy < 1.5, "Neo-Wangan SUNSET: Skyline windows glow at dusk intensity (got %.2f)" % sunset_win_energy)
	check(sunset_cloud_rim.r > sunset_cloud_rim.b, "Neo-Wangan SUNSET: Anime clouds have warm golden-crimson rim (%s)" % sunset_cloud_rim)
	check(moon != null and moon.position.y < 500.0, "Neo-Wangan SUNSET: Setting sun sits low near horizon (y=%.1f)" % (moon.position.y if moon != null else -1.0))

	# Test NIGHT (mode 2)
	race.weather.time_of_day = WeatherScript.compute_time_of_day(WeatherScript.TimeOfDay.NIGHT, 0.0)
	env.call("update", 0.1, race)
	var night_win_energy: float = float((skyline.material_override as ShaderMaterial).get_shader_parameter("window_energy")) if skyline != null else -1.0
	var night_craters: float = float((moon.material_override as ShaderMaterial).get_shader_parameter("crater_density")) if moon != null else 0.0
	check(stars != null and stars.visible, "Neo-Wangan NIGHT: 900 NightStars are visible at night")
	check(night_win_energy > 1.5, "Neo-Wangan NIGHT: Skyline windows glow at full night energy (got %.2f)" % night_win_energy)
	check(night_craters > 0.2, "Neo-Wangan NIGHT: Celestial disc shows halftone Moon craters (got %.2f)" % night_craters)
	check(pools != null and pools.visible, "Neo-Wangan NIGHT: Streetlight asphalt pools are visible at night")

	circuit.queue_free()
	await process_frame

	# 2. Apex Ring (TrackEnvironmentBuilder) shares SkyAmbienceRoot via SharedCelSkyController
	ConfigScript.current = null
	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	await process_frame
	world.step(1.0 / 60.0)

	var apex_sky := world.environment.get_node_or_null("SkyAmbienceRoot") as Node3D
	check(apex_sky != null, "Apex Ring TrackEnvironmentBuilder also mounts reusable SkyAmbienceRoot")
	if apex_sky != null:
		var apex_disc := apex_sky.get_node_or_null("AnimeMoon") as MeshInstance3D
		var apex_clouds := apex_sky.get_node_or_null("AnimeNightClouds") as MultiMeshInstance3D
		check(apex_disc != null and apex_clouds != null and apex_clouds.multimesh.instance_count >= 20,
			"Apex Ring shares AnimeMoon/Sun disc and 28 wind-driven 3D AnimeNightClouds")

	world.race.dispose()
	world.queue_free()
	for _i: int in range(3):
		await process_frame

	print("REUSABLE SKY & TIME OF DAY: %d assertions, %d failure(s)" % [assertions, failures])
	quit(0 if failures == 0 else 1)
```

- [ ] **Step 2: Run the test to confirm RED state**

Run:
```powershell
godot --headless --path . -s res://tests/test_reusable_sky_and_time_of_day.gd
```
Expected: Fails because `shared_cel_sky_controller.gd` and `apply_time_of_day` do not exist yet.

- [ ] **Step 3: Update `shaders/neo_wangan_stars.gdshader`, `shaders/neo_wangan_skyline.gdshader`, and `shaders/neo_wangan_water.gdshader`**

In `shaders/neo_wangan_stars.gdshader`, add `uniform float star_opacity : hint_range(0.0, 1.0) = 1.0;` and set `ALPHA = shape * star_opacity;`:
```glsl
uniform float twinkle_speed : hint_range(0.0, 8.0) = 1.6;
uniform float min_brightness : hint_range(0.0, 1.0) = 0.25;
uniform float star_opacity : hint_range(0.0, 1.0) = 1.0;
```
And on the final line of `fragment()`:
```glsl
	ALBEDO = COLOR.rgb * level;
	ALPHA = shape * star_opacity;
```

In `shaders/neo_wangan_skyline.gdshader`, add `uniform float roof_neon_energy : hint_range(0.0, 4.0) = 2.2;` and use it on line 49:
```glsl
uniform float window_energy : hint_range(0.0, 8.0) = 1.9;
uniform float roof_neon_energy : hint_range(0.0, 4.0) = 2.2;
```
And in `fragment()`:
```glsl
	vec3 glow = win_col * window_energy * lit * pane * wall + roof_neon_color * roof_band * roof_neon_energy;
```

In `shaders/neo_wangan_water.gdshader`, add `uniform float band_emission : hint_range(0.0, 1.0) = 0.25;` and `uniform float crest_emission : hint_range(0.0, 2.0) = 0.70;` and use them on line 41:
```glsl
uniform float band_emission : hint_range(0.0, 1.0) = 0.25;
uniform float crest_emission : hint_range(0.0, 2.0) = 0.70;
```
And in `fragment()`:
```glsl
	ALBEDO = mix(deep_color, band_color, band);
	EMISSION = band_color * band_emission + crest_col * crest_line * dash * crest_emission;
```

- [ ] **Step 4: Create `scripts/world/shared_cel_sky_controller.gd`**

```gdscript
class_name SharedCelSkyController
extends RefCounted

## Reusable Cel-Shaded Skybox & Wind Ambience controller (FASE 12.3).
## Builds and drives SkyAmbienceRoot (AnimeMoon/Sun disc, 900 twinkling NightStars, and 28
## wind-drifting 3D cel-shaded cloud clusters) across DAY, SUNSET, and NIGHT for any circuit.

const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const MoonShader := preload("res://shaders/neo_wangan_moon.gdshader")
const StarShader := preload("res://shaders/neo_wangan_stars.gdshader")
const CloudShader := preload("res://shaders/neo_wangan_clouds.gdshader")

const DAY_SUN_OFFSET := Vector3(-520.0, 960.0, -980.0)
const SUNSET_SUN_OFFSET := Vector3(-720.0, 340.0, -1100.0)
const NIGHT_MOON_OFFSET := Vector3(-650.0, 780.0, -1100.0)
const MOON_QUAD_M: float = 285.0

const STAR_COUNT: int = 900
const STAR_DOME_RADIUS_M: float = 2400.0
const STAR_MIN_ELEVATION_DEG: float = 5.0
const STAR_MAX_ELEVATION_DEG: float = 88.0
const STAR_QUAD_M: float = 9.0

const CLOUD_COUNT: int = 28
const CLOUD_MIN_RADIUS_M: float = 450.0
const CLOUD_MAX_RADIUS_M: float = 1200.0
const CLOUD_MIN_HEIGHT_M: float = 260.0
const CLOUD_MAX_HEIGHT_M: float = 420.0
const CLOUD_BASE_RATE: float = 0.004
const CLOUD_WIND_RATE: float = 0.00035

var sky_ambience_root: Node3D
var moon_instance: MeshInstance3D
var star_instance: MultiMeshInstance3D
var cloud_instance: MultiMeshInstance3D
var moon_material: ShaderMaterial
var star_material: ShaderMaterial
var cloud_material: ShaderMaterial
var cloud_angle: float = 0.0
var current_wind_kph: float = 14.0


func build(parent: Node3D, ribbon: TrackRibbonScript, seed_value: int = 20260240, include_stars: bool = true) -> Node3D:
	sky_ambience_root = parent.get_node_or_null("SkyAmbienceRoot") as Node3D
	if sky_ambience_root == null:
		sky_ambience_root = Node3D.new()
		sky_ambience_root.name = "SkyAmbienceRoot"
		parent.add_child(sky_ambience_root)
	sky_ambience_root.position = _circuit_centre(ribbon)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_build_moon()
	if include_stars:
		_build_stars(rng)
	_build_clouds(rng)
	return sky_ambience_root


func apply_wind(delta: float, wind_kph: float) -> void:
	current_wind_kph = wind_kph
	cloud_angle = fposmod(cloud_angle + delta * (CLOUD_BASE_RATE + wind_kph * CLOUD_WIND_RATE), TAU)
	if cloud_instance != null:
		cloud_instance.rotation.y = cloud_angle


func apply_time_of_day(tod: Dictionary, gloom: float = 0.0) -> void:
	var night_factor: float = clampf(float(tod.get("floodlights", 1.0)), 0.0, 1.0)
	var stars_opacity: float = clampf(float(tod.get("stars_opacity", night_factor)) * (1.0 - gloom * 0.85), 0.0, 1.0)
	var mode: int = int(tod.get("mode", 2 if night_factor >= 0.7 else (1 if night_factor >= 0.15 else 0)))

	if star_instance != null and star_material != null:
		star_instance.visible = stars_opacity > 0.02
		star_material.set_shader_parameter("star_opacity", stars_opacity)

	if moon_instance != null and moon_material != null:
		if mode == 0 and night_factor < 0.15:
			moon_instance.position = DAY_SUN_OFFSET
			moon_material.set_shader_parameter("moon_color", Color("#fffef5"))
			moon_material.set_shader_parameter("moon_shade", Color("#ffe885"))
			moon_material.set_shader_parameter("halo_color", Color("#b3ecff"))
			moon_material.set_shader_parameter("crater_density", 0.0)
			moon_material.set_shader_parameter("halo_inner_alpha", 0.42 * (1.0 - gloom * 0.7))
			moon_material.set_shader_parameter("halo_outer_alpha", 0.18 * (1.0 - gloom * 0.7))
		elif mode == 1 or (night_factor >= 0.15 and night_factor < 0.7):
			moon_instance.position = SUNSET_SUN_OFFSET
			moon_material.set_shader_parameter("moon_color", Color("#ffb838"))
			moon_material.set_shader_parameter("moon_shade", Color("#ff3d1f"))
			moon_material.set_shader_parameter("halo_color", Color("#ff7043"))
			moon_material.set_shader_parameter("crater_density", 0.0)
			moon_material.set_shader_parameter("halo_inner_alpha", 0.46 * (1.0 - gloom * 0.6))
			moon_material.set_shader_parameter("halo_outer_alpha", 0.22 * (1.0 - gloom * 0.6))
		else:
			moon_instance.position = NIGHT_MOON_OFFSET
			moon_material.set_shader_parameter("moon_color", Color("#fff8d6"))
			moon_material.set_shader_parameter("moon_shade", Color("#c7d1bd"))
			moon_material.set_shader_parameter("halo_color", Color("#9edbff"))
			moon_material.set_shader_parameter("crater_density", 0.34)
			moon_material.set_shader_parameter("halo_inner_alpha", 0.38 * (1.0 - gloom * 0.5))
			moon_material.set_shader_parameter("halo_outer_alpha", 0.16 * (1.0 - gloom * 0.5))

	if cloud_material != null:
		if mode == 0 and night_factor < 0.15:
			cloud_material.set_shader_parameter("cloud_rim", Color("#ffffff").lerp(Color("#aeb8c7"), gloom * 0.65))
			cloud_material.set_shader_parameter("cloud_mid", Color("#dcebfa").lerp(Color("#6c788c"), gloom * 0.70))
			cloud_material.set_shader_parameter("cloud_shadow", Color("#93b4db").lerp(Color("#3d4657"), gloom * 0.75))
			cloud_material.set_shader_parameter("moon_dir", DAY_SUN_OFFSET.normalized())
		elif mode == 1 or (night_factor >= 0.15 and night_factor < 0.7):
			cloud_material.set_shader_parameter("cloud_rim", Color("#ffb057").lerp(Color("#8c6b7a"), gloom * 0.65))
			cloud_material.set_shader_parameter("cloud_mid", Color("#bd5e7a").lerp(Color("#52435c"), gloom * 0.70))
			cloud_material.set_shader_parameter("cloud_shadow", Color("#4a2c56").lerp(Color("#2a2438"), gloom * 0.75))
			cloud_material.set_shader_parameter("moon_dir", SUNSET_SUN_OFFSET.normalized())
		else:
			cloud_material.set_shader_parameter("cloud_rim", Color("#b8e0ff").lerp(Color("#546885"), gloom * 0.60))
			cloud_material.set_shader_parameter("cloud_mid", Color("#405285").lerp(Color("#25304d"), gloom * 0.60))
			cloud_material.set_shader_parameter("cloud_shadow", Color("#1f2645").lerp(Color("#12172b"), gloom * 0.60))
			cloud_material.set_shader_parameter("moon_dir", NIGHT_MOON_OFFSET.normalized())


static func _circuit_centre(ribbon: TrackRibbonScript) -> Vector3:
	if ribbon == null:
		return Vector3.ZERO
	var centre := Vector3.ZERO
	var samples: int = 0
	var s: float = 0.0
	while s < ribbon.length_m:
		centre += ribbon.get_point_at_offset(s, 0.0).origin
		samples += 1
		s += 100.0
	centre /= float(maxi(samples, 1))
	centre.y = 0.0
	return centre


func _build_moon() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(MOON_QUAD_M, MOON_QUAD_M)
	moon_material = ShaderMaterial.new()
	moon_material.shader = MoonShader
	moon_instance = MeshInstance3D.new()
	moon_instance.name = "AnimeMoon"
	moon_instance.mesh = quad
	moon_instance.material_override = moon_material
	moon_instance.position = NIGHT_MOON_OFFSET
	moon_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon_instance.extra_cull_margin = MOON_QUAD_M
	sky_ambience_root.add_child(moon_instance)


func _build_stars(rng: RandomNumberGenerator) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(STAR_QUAD_M, STAR_QUAD_M)
	star_material = ShaderMaterial.new()
	star_material.shader = StarShader
	var low: float = sin(deg_to_rad(STAR_MIN_ELEVATION_DEG))
	var high: float = sin(deg_to_rad(STAR_MAX_ELEVATION_DEG))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = STAR_COUNT
	var tints: Array[Color] = [Color.WHITE, Color("#bfe6ff"), Color("#ffe2c4")]
	for index: int in range(STAR_COUNT):
		var up: float = rng.randf_range(low, high)
		var ring: float = sqrt(1.0 - up * up)
		var azimuth: float = rng.randf_range(0.0, TAU)
		var at := Vector3(cos(azimuth) * ring, up, sin(azimuth) * ring) * STAR_DOME_RADIUS_M
		var size_scale: float = rng.randf_range(0.6, 1.5)
		multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * size_scale), at))
		multimesh.set_instance_color(index, tints[index % tints.size()])
	star_instance = MultiMeshInstance3D.new()
	star_instance.name = "NightStars"
	star_instance.multimesh = multimesh
	star_instance.material_override = star_material
	star_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky_ambience_root.add_child(star_instance)


func _build_clouds(rng: RandomNumberGenerator) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _cloud_mesh()
	multimesh.instance_count = CLOUD_COUNT
	for index: int in range(CLOUD_COUNT):
		var azimuth: float = (float(index) + rng.randf_range(-0.3, 0.3)) / float(CLOUD_COUNT) * TAU
		var radius: float = rng.randf_range(CLOUD_MIN_RADIUS_M, CLOUD_MAX_RADIUS_M)
		var at := Vector3(cos(azimuth) * radius, rng.randf_range(CLOUD_MIN_HEIGHT_M, CLOUD_MAX_HEIGHT_M), sin(azimuth) * radius)
		var orientation := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.7))
		multimesh.set_instance_transform(index, Transform3D(orientation, at))
	cloud_material = ShaderMaterial.new()
	cloud_material.shader = CloudShader
	cloud_instance = MultiMeshInstance3D.new()
	cloud_instance.name = "AnimeNightClouds"
	cloud_instance.multimesh = multimesh
	cloud_instance.material_override = cloud_material
	cloud_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky_ambience_root.add_child(cloud_instance)


static func _cloud_mesh() -> ArrayMesh:
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 10
	puff.rings = 5
	var puffs: Array[Transform3D] = [
		Transform3D(Basis.from_scale(Vector3(62.0, 20.0, 34.0)), Vector3.ZERO),
		Transform3D(Basis.from_scale(Vector3(36.0, 17.0, 26.0)), Vector3(-44.0, 5.0, 4.0)),
		Transform3D(Basis.from_scale(Vector3(30.0, 14.0, 22.0)), Vector3(48.0, 2.0, -6.0)),
	]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pose: Transform3D in puffs:
		tool.append_from(puff, 0, pose)
	return tool.commit()
```

---

## Task 2: Wire `SharedCelSkyController` & `DAY / SUNSET / NIGHT` into `NeoWanganEnvironment` and `TrackEnvironmentBuilder`

**Files:**
- Modify: `scripts/world/neo_wangan_environment.gd`
- Modify: `scripts/world/track_environment_builder.gd`

- [ ] **Step 1: Update `scripts/world/neo_wangan_environment.gd` to use `SharedCelSkyController` and implement `apply_time_of_day(tod, gloom)`**

1. Preload `const SharedSkyScript := preload("res://scripts/world/shared_cel_sky_controller.gd")` and `const WeatherScript := preload("res://scripts/gt/gt_weather.gd")`.
2. Add `var sky_controller: SharedSkyScript` and `var streetlight_pools_instance: MultiMeshInstance3D` and `var _street_pool_material: ShaderMaterial` and `var _current_tod: Dictionary = {}` and `var _current_gloom: float = 0.0`.
3. In `_build_light_pools()`, store `_street_pool_material = material` and `streetlight_pools_instance = _multimesh("StreetlightPools", quad, pools, material, laterals)`.
4. Replace `_build_sky_ambience()`, `_build_moon()`, `_build_stars()`, `_build_clouds()`, and `_cloud_mesh()` with delegating to `sky_controller`:
```gdscript
func _build_sky_ambience() -> void:
	sky_controller = SharedSkyScript.new()
	sky_ambience_root = sky_controller.build(self, ribbon, SKYLINE_SEED + 13, true)
	moon_instance = sky_controller.moon_instance
	star_instance = sky_controller.star_instance
	cloud_instance = sky_controller.cloud_instance
	_current_tod = WeatherScript.compute_time_of_day(WeatherScript.TimeOfDay.NIGHT, 0.0)
```
5. In `apply_wind_ambience(delta: float, wind_kph: float, wind_dir: float)`:
   Call `if sky_controller != null: sky_controller.apply_wind(delta, wind_kph)` (and keep `_cloud_angle = sky_controller.cloud_angle`).
6. Add `apply_time_of_day(tod: Dictionary, gloom: float = 0.0) -> void` and call it from `update(delta, race)` (when `race != null and race.get("weather") != null`, pass `race.weather.time_of_day` and `gloom = maxf(clampf(sqrt(race.weather.rain_intensity), 0.0, 1.0), race.weather.track_water_pct / 100.0)`):
```gdscript
func apply_time_of_day(tod: Dictionary, gloom: float = 0.0) -> void:
	_current_tod = tod
	_current_gloom = gloom
	if sky_controller != null:
		sky_controller.apply_time_of_day(tod, gloom)
	var night_factor: float = clampf(float(tod.get("floodlights", 1.0)), 0.0, 1.0)
	var mode: int = int(tod.get("mode", 2 if night_factor >= 0.7 else (1 if night_factor >= 0.15 else 0)))
	var pulse: float = 0.86 + 0.14 * sin(_clock_s * 2.1)

	# 1. Skyline facade, windows & roof neon
	if _window_material != null:
		if mode == 0 and night_factor < 0.15:
			_window_material.set_shader_parameter("building_color", Color("#4a5a75"))
			_window_material.set_shader_parameter("building_top_tint", Color("#788cab"))
			_window_material.set_shader_parameter("window_cool", Color("#8cb8d9"))
			_window_material.set_shader_parameter("window_warm", Color("#b0d4eb"))
			_window_material.set_shader_parameter("window_energy", 0.0)
			_window_material.set_shader_parameter("roof_neon_energy", 0.0)
		elif mode == 1 or (night_factor >= 0.15 and night_factor < 0.7):
			_window_material.set_shader_parameter("building_color", Color("#28233d"))
			_window_material.set_shader_parameter("building_top_tint", Color("#6e4263"))
			_window_material.set_shader_parameter("window_cool", Color("#ffaa44"))
			_window_material.set_shader_parameter("window_warm", Color("#ff5577"))
			_window_material.set_shader_parameter("window_energy", 0.95 * pulse)
			_window_material.set_shader_parameter("roof_neon_energy", 1.2)
		else:
			_window_material.set_shader_parameter("building_color", Color("#0b0e16"))
			_window_material.set_shader_parameter("building_top_tint", Color("#171f33"))
			_window_material.set_shader_parameter("window_cool", Color("#00f0ff"))
			_window_material.set_shader_parameter("window_warm", Color("#ff9e38"))
			_window_material.set_shader_parameter("window_energy", 1.8 * pulse)
			_window_material.set_shader_parameter("roof_neon_energy", 2.2)

	# 2. Stepped toon bay water
	if _water_shader_mat != null:
		if mode == 0 and night_factor < 0.15:
			_water_shader_mat.set_shader_parameter("deep_color", Color("#124878"))
			_water_shader_mat.set_shader_parameter("band_color", Color("#2474b5"))
			_water_shader_mat.set_shader_parameter("neon_ripple_cyan", Color("#d9f7ff"))
			_water_shader_mat.set_shader_parameter("neon_ripple_magenta", Color("#8ce3ff"))
			_water_shader_mat.set_shader_parameter("band_emission", 0.08)
			_water_shader_mat.set_shader_parameter("crest_emission", 0.25)
		elif mode == 1 or (night_factor >= 0.15 and night_factor < 0.7):
			_water_shader_mat.set_shader_parameter("deep_color", Color("#26193b"))
			_water_shader_mat.set_shader_parameter("band_color", Color("#6b3252"))
			_water_shader_mat.set_shader_parameter("neon_ripple_cyan", Color("#ffaa3b"))
			_water_shader_mat.set_shader_parameter("neon_ripple_magenta", Color("#ff2e6e"))
			_water_shader_mat.set_shader_parameter("band_emission", 0.18)
			_water_shader_mat.set_shader_parameter("crest_emission", 0.55)
		else:
			_water_shader_mat.set_shader_parameter("deep_color", Color("#061020"))
			_water_shader_mat.set_shader_parameter("band_color", Color("#0d2947"))
			_water_shader_mat.set_shader_parameter("neon_ripple_cyan", Color("#00e6ff"))
			_water_shader_mat.set_shader_parameter("neon_ripple_magenta", Color("#ff2e75"))
			_water_shader_mat.set_shader_parameter("band_emission", 0.25)
			_water_shader_mat.set_shader_parameter("crest_emission", 0.70)

	# 3. Streetlights & asphalt pools (off in clear Day, on in Sunset/Night or heavy storm gloom)
	var lamp_level: float = maxf(night_factor, gloom * 0.7 if gloom > 0.55 else 0.0)
	var lamps_on: bool = lamp_level > 0.05
	if _lamp_material != null:
		_lamp_material.emission_energy_multiplier = 2.6 * lamp_level
	if streetlight_pools_instance != null:
		streetlight_pools_instance.visible = lamps_on
	if _street_pool_material != null:
		_street_pool_material.set_shader_parameter("intensity", 0.5 * lamp_level)

	# 4. Sky & Fog on WorldEnvironment
	_apply_sky_for_tod(mode, night_factor, gloom)
```
And implement `_apply_sky_for_tod(mode: int, night_factor: float, gloom: float)` so `_world_environment` and `_sun` cleanly reflect `DAY` (`#2673d6` / `#99d6ff`), `SUNSET` (`#2d1b4e` / `#ff6b3d`), or `NIGHT` (`#060a18` / `#2a1a3e`).

- [ ] **Step 2: Attach `SharedCelSkyController` in `scripts/world/track_environment_builder.gd` (Apex Ring)**

In `scripts/world/track_environment_builder.gd`:
1. Preload `const SharedSkyScript := preload("res://scripts/world/shared_cel_sky_controller.gd")`.
2. Add `var sky_controller: SharedSkyScript` and `var sky_ambience_root: Node3D`.
3. In `build(p_ribbon, p_line)` after `_build_vista()`:
```gdscript
	sky_controller = SharedSkyScript.new()
	sky_ambience_root = sky_controller.build(self, ribbon, 20260240, false)
```
4. In `update(delta: float, race: GtRace)`:
```gdscript
	if sky_controller != null and race != null and race.weather != null:
		var weather: GtWeather = race.weather
		var gloom: float = maxf(clampf(sqrt(weather.rain_intensity), 0.0, 1.0), weather.track_water_pct / 100.0)
		sky_controller.apply_wind(delta, weather.wind_speed)
		sky_controller.apply_time_of_day(weather.time_of_day, gloom)
```

- [ ] **Step 3: Run `test_reusable_sky_and_time_of_day.gd`, `test_neo_wangan_cel_ambience.gd`, and `test_track_environment.gd`**

Run:
```powershell
godot --headless --path . -s res://tests/test_reusable_sky_and_time_of_day.gd
godot --headless --path . -s res://tests/test_neo_wangan_cel_ambience.gd
godot --headless --path . -s res://tests/test_track_environment.gd
```
Expected: 100% PASS (0 FAIL).

---

## Task 3: Capture Native Visual Verification Screenshots & Run Full 51-Suite Regression Gate

**Files:**
- Create: `scratch/capture_phase12_3_views.gd`
- Create: `executor-report/reports/FASE-12-3-REUSABLE-CEL-SKYBOX-AND-DAY-SUNSET-NIGHT-REPORT.md`
- Modify: `ROADMAP.md`

- [ ] **Step 1: Create `scratch/capture_phase12_3_views.gd` and capture 4 verification screenshots (1920×1080)**

Capture native screenshots into `executor-report/screenshots/phases/`:
1. `phase-12-3-wangan-day-bridge.png` — Neo-Wangan in **DAY** mode (`TimeOfDay.DAY`): bright blue sky, high Anime Sun, white/cream 3D cel clouds, daytime steel-blue skyline towers with unlit glass, blue stepped bay water with white-cyan seafoam crests, streetlights off.
2. `phase-12-3-wangan-sunset-skyline.png` — Neo-Wangan in **SUNSET** mode (`TimeOfDay.SUNSET`): golden-crimson horizon, low Anime Setting Sun, golden-violet 3D cel clouds, warm dusk skyline & sunset bay water.
3. `phase-12-3-wangan-night-skyline.png` — Neo-Wangan in **NIGHT** mode (`TimeOfDay.NIGHT`): halftone Moon with dual halo, 900 twinkling stars, midnight neon skyline & bay water.
4. `phase-12-3-apex-ring-cel-sky.png` — Apex Ring International with `SharedCelSkyController` (`AnimeMoon`/`Sun` + 28 3D cel clouds over the mountain vista).

- [ ] **Step 2: Run all 51 headless test suites**

```powershell
Get-ChildItem tests\test_*.gd | ForEach-Object {
    if ($_.Name -eq "test_race_world.gd") {
        godot --headless --fixed-fps 60 --path . -s "res://tests/$($_.Name)"
    } else {
        godot --headless --path . -s "res://tests/$($_.Name)"
    }
}
```
Expected: 51/51 test suites PASS (0 FAIL, 0 orphan nodes).

- [ ] **Step 3: Write `executor-report/reports/FASE-12-3-REUSABLE-CEL-SKYBOX-AND-DAY-SUNSET-NIGHT-REPORT.md` and update `ROADMAP.md`**
