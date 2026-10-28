extends SceneTree

## Neo-Wangan cel-shaded ambience (FASE 12.2): living night sky (moon, stars, wind-drifting clouds),
## wind-waving street banners, stepped toon water, outlined skyline and Kanji billboards, all inside
## the 160 draw call / 320 000 triangle budget.
## Run: godot --headless --path . -s res://tests/test_neo_wangan_cel_ambience.gd

const CircuitScene := preload("res://scenes/race_world/neo_wangan_circuit.tscn")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")


## Just enough race for NeoWanganEnvironment.update(): it only reads `weather`.
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


## -1 while the property does not exist, so a missing feature fails the check instead of hanging the run.
func _wind(env: Node) -> float:
	var kph: Variant = env.get("current_wind_kph")
	return float(kph) if kph != null else -1.0


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

	# 6. Wind responsiveness: the direct hook, then the real per-frame update(delta, race) path
	if env.has_method("apply_wind_ambience"):
		env.call("apply_wind_ambience", 0.5, 38.0, 1.2)
		check(_wind(env) == 38.0, "NeoWanganEnvironment tracks live wind_speed from weather")
	else:
		check(false, "NeoWanganEnvironment implements apply_wind_ambience(delta, wind_kph, wind_dir)")
	var race := StubRace.new()
	race.weather = WeatherScript.new(5, 1234, WeatherScript.Archetype.DRY_SUNNY)
	race.weather.wind_speed = 21.0
	env.call("update", 0.1, race)
	check(_wind(env) == 21.0, "update(delta, race) feeds race.weather.wind_speed into the ambience")

	# 7. Render budget stays within <= 160 draw calls and <= 320,000 tris
	var st: Dictionary = env.call("stats")
	check(int(st["draw_calls"]) <= 160 and int(st["triangles"]) <= 320000,
		"Render budget respected with sky/wind ambience: %d draw calls, %d tris" % [int(st["draw_calls"]), int(st["triangles"])])

	circuit.queue_free()
	await process_frame
	print("NEO-WANGAN CEL AMBIENCE: %d assertions, %d failure(s)" % [assertions, failures])
	quit(0 if failures == 0 else 1)
