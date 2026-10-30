extends SceneTree

## Track Selector in the Race Setup screen (FASE 12, Task 5): the championship calendar can be
## walked with the arrows, every round names itself (round, country, type, length, corners), the
## choice is written straight into RaceConfigData, and the hero map re-traces the new circuit's own
## spline. The HUD radar is checked to follow whichever ribbon it is handed, so Neo-Wangan draws its
## own shape instead of the Apex Ring's.
## Run: godot --headless --path . -s res://tests/test_track_selector_ui.gd

const MenuScene := preload("res://scenes/ui/race_setup_menu.tscn")
const RadarScene := preload("res://scenes/pit_wall/circuit_radar_2d.tscn")
const NeoCircuitScene := preload("res://scenes/race_world/circuits/neo_wangan/neo_wangan_circuit.tscn")
const ApexScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const Registry := preload("res://scripts/core/circuit_calendar_registry.gd")
const TrackMapView := preload("res://scripts/ui/track_map.gd")
const RADAR_RECT := Rect2(0.0, 0.0, 300.0, 200.0)

var failures: int = 0
var assertions: int = 0
var menu: Control
var config: RefCounted


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	ConfigScript.reset()
	menu = MenuScene.instantiate()
	root.add_child(menu)
	await process_frame
	config = ConfigScript.get_config()
	_test_default_round()
	await _test_neo_wangan_round()
	await _test_reserved_rounds_and_wrap()
	await _test_public_api_and_summary()
	await _test_radar_follows_circuit()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("TRACK SELECTOR UI: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	menu.queue_free()
	quit(0 if failures == 0 else 1)


func _label(node_name: String) -> String:
	var label := menu.find_child(node_name, true, false) as Label
	return label.text if label != null else "<missing %s>" % node_name


func _radar() -> TrackMapView:
	return menu.get("radar") as TrackMapView


func _press(node_name: String) -> void:
	var button := menu.find_child(node_name, true, false) as Button
	if button != null:
		button.pressed.emit()


func _test_default_round() -> void:
	var radar: TrackMapView = _radar()
	var length: float = float(radar.stats()["length_m"])
	var stats_ok: bool = absf(length - 4158.8) <= 1.0 and int(radar.stats()["corners"]) >= 5
	var continue_button := menu.get("continue_button") as Button
	check(_label("CircuitNameLabel") == "Apex Ring International"
			and _label("CircuitTypeLabel") == "GRAND PRIX"
			and _label("CircuitRoundLabel").begins_with("ROUND 01")
			and _label("CircuitLengthLabel").contains("4.16")
			and config.get("selected_circuit_id") == "apex_ring"
			and stats_ok and not continue_button.disabled,
		"#S1 the screen opens on Round 01, Apex Ring International (GRAND PRIX, 4.16 km), with the real Apex map traced (%.0f m, %d corners) and Continue live" % [length, int(radar.stats()["corners"])])


func _test_neo_wangan_round() -> void:
	_press("TrackNextButton")
	await process_frame
	var radar: TrackMapView = _radar()
	var stats: Dictionary = radar.stats()
	var length: float = float(stats["length_m"])
	var continue_button := menu.get("continue_button") as Button
	check(_label("CircuitNameLabel") == "Neo-Wangan Shuto Express"
			and _label("CircuitTypeLabel") == "SPRINT"
			and _label("CircuitRoundLabel").contains("ROUND 02")
			and _label("CircuitLengthLabel").to_lower().contains("3.15")
			and _label("CircuitTurnsLabel") == "12 TURNS"
			and config.get("selected_circuit_id") == "neo_wangan"
			and not continue_button.disabled,
		"#S2 the right arrow selects Round 02, Neo-Wangan Shuto Express (SPRINT, 3.15 km, 12 turns), and it is written into RaceConfigData")
	check(absf(length - 3150.0) <= 25.0 and absf(float(stats["elevation_delta"]) - 9.7) <= 0.3 and int(stats["corners"]) == 12 \
			and radar.circuit_id == "neo_wangan",
		"#S3 the hero map re-traces Neo-Wangan itself: %.0f m, %d corners, %.1f m of elevation" % [length, int(stats["corners"]), float(stats["elevation_delta"])])


func _test_reserved_rounds_and_wrap() -> void:
	# Step 1: Round 03, Autodromo di Brianza is now PLAYABLE!
	_press("TrackNextButton")
	await process_frame
	var radar: TrackMapView = _radar()
	var continue_button := menu.get("continue_button") as Button
	var brianza_ok: bool = _label("CircuitNameLabel") == "Autodromo di Brianza" \
		and _label("CircuitTypeLabel") == "GRAND PRIX" \
		and absf(float(radar.stats()["length_m"]) - 5790.0) <= 25.0 and radar.circuit_id == "brianza" \
		and not continue_button.disabled
	check(brianza_ok,
		"#S4 Round 03, Autodromo di Brianza is now fully built and playable (GP, 5.79 km, Continue enabled)")

	# Step 2: Round 04, Monte Azure Marina is built (FASE 15): a 2.85 km Sprint street circuit.
	_press("TrackNextButton")
	await process_frame
	var monte_ok: bool = _label("CircuitNameLabel") == "Monte Azure Marina" \
		and _label("CircuitTypeLabel") == "SPRINT" \
		and absf(float(radar.stats()["length_m"]) - 2850.0) <= 25.0 and radar.circuit_id == "monte_azure" \
		and not continue_button.disabled
	check(monte_ok,
		"#S4b Round 04, Monte Azure Marina is fully built and playable (Sprint, 2.85 km, Continue enabled)")

	# Step 3: Round 05, Ardennes Valley Ring is a reserved round that is not built yet.
	_press("TrackNextButton")
	await process_frame
	var reserved_ok: bool = _label("CircuitNameLabel") == "Ardennes Valley Ring" \
		and _label("CircuitTypeLabel") == "GRAND PRIX" \
		and float(radar.stats()["length_m"]) == 0.0 and radar.circuit_id == "ardennes" \
		and continue_button.disabled and continue_button.text.contains("IN PREPARATION")
	check(reserved_ok,
		"#S4c a round whose layout is not built yet (Round 05, Ardennes) says so: the map is empty and Continue is disabled")

	# Return to Apex Ring
	_press("TrackPrevButton")
	_press("TrackPrevButton")
	_press("TrackPrevButton")
	_press("TrackPrevButton")
	await process_frame
	var back_ok: bool = _label("CircuitNameLabel") == "Apex Ring International" and config.get("selected_circuit_id") == "apex_ring"
	# Ten steps around the calendar return to the start, wrapping October back into January.
	for _step: int in range(10):
		_press("TrackNextButton")
	await process_frame
	var wrapped: bool = _label("CircuitNameLabel") == "Apex Ring International" and int(Registry.round_of(config.get("selected_circuit_id"))) == 1
	check(back_ok and wrapped,
		"#S5 the arrows walk the calendar both ways and ten steps wrap October back to January")


func _test_public_api_and_summary() -> void:
	var selected: bool = bool(menu.call("select_circuit", "neo_wangan"))
	await process_frame
	var summary := menu.find_child("SetupSummary", true, false) as Label
	var summary_ok: bool = summary != null and summary.text.contains("ROUND 02") and summary.text.contains("NEO-WANGAN")
	var invalid: bool = not bool(menu.call("select_circuit", "not_a_round"))
	check(selected and summary_ok and invalid and config.get("selected_circuit_id") == "neo_wangan",
		"#S6 select_circuit() is the public entry point (other screens and the career use it) and the summary names Round 02; an unknown id is refused")


## The HUD radar is circuit-agnostic: hand it Neo-Wangan's ribbon and it draws that shape, fitted
## inside its 300x200 footprint; the Apex Ring traces a different shape with the same rule.
func _test_radar_follows_circuit() -> void:
	var circuit = NeoCircuitScene.instantiate()
	root.add_child(circuit)
	var neo_ribbon = circuit.ribbon
	var radar: Control = RadarScene.instantiate()
	root.add_child(radar)
	radar.set_ribbon(neo_ribbon, neo_ribbon.length_m)
	await process_frame
	var neo_points: PackedVector2Array = (radar.get_node("Track") as Line2D).points
	var neo_bounds := Rect2(neo_points[0], Vector2.ZERO)
	for point: Vector2 in neo_points:
		neo_bounds = neo_bounds.expand(point)
	var inside: bool = RADAR_RECT.grow(-4.0).encloses(neo_bounds)
	var bands: Array = radar.get("bands")
	var marks_ok: bool = bands.size() == 3
	radar.update_snapshot({"cars": [{"car_id": 0, "team_id": 0, "spline_distance": 10.0}]})
	var mark: Dictionary = (radar.get("marks") as Array)[0]
	marks_ok = marks_ok and RADAR_RECT.has_point(mark["at"]) and bool((radar.get_node("Track") as Line2D).closed)

	var apex := ApexScene.instantiate()
	root.add_child(apex)
	radar.set_ribbon(apex, apex.length_m)
	await process_frame
	var apex_points: PackedVector2Array = (radar.get_node("Track") as Line2D).points
	var same_size: bool = apex_points.size() == neo_points.size()
	var diverged: float = 0.0
	for index: int in range(mini(apex_points.size(), neo_points.size())):
		diverged = maxf(diverged, apex_points[index].distance_to(neo_points[index]))
	check(neo_points.size() > 40 and inside and marks_ok and not same_size and diverged > 20.0,
		"#S7 the 2D radar redraws whichever circuit it is handed: Neo-Wangan (%d points, %.0f px wide) fits the panel, and the Apex Ring traces a different shape" % [neo_points.size(), neo_bounds.size.x])
	radar.queue_free()
	apex.queue_free()
	circuit.queue_free()
	await process_frame
