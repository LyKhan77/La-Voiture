extends SceneTree

## Fase 12.3 TDD: Reusable SharedCelSkyController + Neo-Wangan & Apex Ring DAY / SUNSET / NIGHT support.
## Run: godot --headless --path . -s res://tests/test_reusable_sky_and_time_of_day.gd

const WanganScene := preload("res://scenes/race_world/neo_wangan_circuit.tscn")
const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const SharedSkyPath := "res://scripts/world/shared/shared_cel_sky_controller.gd"


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
	if env == null or not env.has_method("apply_time_of_day"):
		print("REUSABLE SKY & TIME OF DAY: %d assertions, %d failure(s)" % [assertions, failures])
		quit(1)
		return

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

	# 1b. Inside the race world the circuit's own night WorldEnvironment must not shadow the world's sky
	var config := ConfigScript.get_config()
	config.selected_circuit_id = "neo_wangan"
	config.time_of_day = 0
	config.weather_preset = 0
	var wangan_world: Node3D = WorldScene.instantiate()
	root.add_child(wangan_world)
	wangan_world.set_physics_process(false)
	wangan_world.set_process(false)
	await process_frame
	for _i: int in range(3):
		wangan_world.environment.update(0.25, wangan_world.race)
	await process_frame
	var skies: Array[Node] = wangan_world.find_children("*", "WorldEnvironment", true, false)
	check(skies.size() == 1, "Neo-Wangan race world keeps a single WorldEnvironment (got %d)" % skies.size())
	var day_sky: ProceduralSkyMaterial = null
	if not skies.is_empty():
		var day_env: Environment = (skies[0] as WorldEnvironment).environment
		day_sky = day_env.sky.sky_material as ProceduralSkyMaterial if day_env != null and day_env.sky != null else null
	check(day_sky != null and day_sky.sky_top_color.b > 0.6 and day_sky.sky_top_color.r < 0.4,
		"Neo-Wangan DAY race world renders a blue day sky (top %s)" % (day_sky.sky_top_color if day_sky != null else Color.BLACK))
	wangan_world.race.dispose()
	wangan_world.queue_free()
	for _i: int in range(3):
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
