extends SceneTree

## Exhibition Race Setup overhaul (FASE 12.2): seeded DYNAMIC weather, RANDOM time of race, a rerollable
## seed, GP (5 / 10 / 15 laps) versus Sprint (locked 3 laps) lap rules, race dynamics, and the new
## hero-map sidebar, meteo radar strip and unified calendar carousel.
## Run: godot --headless --path . -s res://tests/test_race_setup_overhaul.gd

const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const MenuScene := preload("res://scenes/ui/race_setup_menu.tscn")
const TrackScene := preload("res://scenes/race_world/track_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")

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


## True only when `row` has the ChipRow lock API and the chip is locked; a missing API fails the check
## instead of aborting the run.
func _locked(row: Object, index: int) -> bool:
	return row != null and row.has_method("is_chip_disabled") and bool(row.call("is_chip_disabled", index))


func _open(row: Object, index: int) -> bool:
	return row != null and row.has_method("is_chip_disabled") and not bool(row.call("is_chip_disabled", index))


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
		var w: GtWeather = cfg.make_weather()
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
	var new_seed: int = int(cfg.call("reroll_seed")) if cfg.has_method("reroll_seed") else old_seed
	check(new_seed != old_seed and cfg.race_seed == new_seed, "reroll_seed() generates and assigns a new race_seed")

	# 4. Race dynamics reach the sim: CLEAN has no incidents, STANDARD is the stock rate, CHAOS raises it
	var ribbon: Node = TrackScene.instantiate()
	root.add_child(ribbon)
	await process_frame
	var track := TrackScript.new(ribbon, 14.0)
	var outcomes: Array[String] = []
	for dynamics: int in [0, 1, 2]:
		cfg.set("race_dynamics", dynamics) # set(): a missing field fails the check below instead of aborting the run
		var race := RaceScript.new(track, 3, 77, 0)
		cfg.apply_to_race(race)
		var rate: Variant = race.get("incident_rate") # null until the sim has the knob
		outcomes.append("%s@%.1f" % [race.incidents_enabled, float(rate) if rate != null else -1.0])
	check(outcomes == ["false@1.0", "true@1.0", "true@2.5"],
		"RACE DYNAMICS CLEAN / STANDARD / CHAOS set incidents_enabled and incident_rate (%s)" % ", ".join(outcomes))
	ribbon.queue_free()

	# 5. UI Menu GP (5/10/15) vs Sprint (Locked 3 Laps) & Unified Carousel
	var menu: Control = MenuScene.instantiate()
	root.add_child(menu)
	await process_frame

	# Select Round 01 Apex Ring (GP)
	menu.call("select_circuit", "apex_ring")
	await process_frame
	var laps: Object = menu.get("lap_select")
	check(_open(laps, 1) and _open(laps, 2) and _open(laps, 3) and _locked(laps, 0),
		"GP circuit (Apex Ring) unlocks 5, 10, and 15 lap chips")
	menu.call("select_laps", 15)
	check(cfg.total_laps == 15, "GP circuit allows selecting 15 Laps Endurance GP")

	# Select Round 02 Neo-Wangan (SPRINT)
	menu.call("select_circuit", "neo_wangan")
	await process_frame
	check(cfg.total_laps == 3 and laps.selected == 0,
		"Selecting a SPRINT circuit (Neo-Wangan) automatically locks total_laps to 3")
	check(_locked(laps, 1) and _locked(laps, 2) and _locked(laps, 3),
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
