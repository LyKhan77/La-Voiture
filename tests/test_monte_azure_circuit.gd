extends SceneTree

## Headless suite for Monte Azure Marina (Round 04, SPRINT, FASE 15): the closed street spline built from the frozen
## mapgen blueprint (geometry_hash sha256:f495332f...), its elevation, the numbered turns, and the calendar entry.
## Run: godot --headless --path . -s res://tests/test_monte_azure_circuit.gd

const ScenePath := "res://scenes/race_world/circuits/monte_azure/monte_azure_circuit.tscn"
const BuilderPath := "res://scripts/world/circuits/monte_azure/monte_azure_circuit_builder.gd"
const RegistryScript := preload("res://scripts/core/circuit_calendar_registry.gd")
const GEOMETRY_HASH := "sha256:f495332f4668c70d53272037c1b0ca939e7795adf6eee4d46cd1781981eda5f0"
## Turn names as played: the blueprint's, except T7/T8/T11/T12 (developer ruling 2026-10-30, SPEC 4.2).
const TURN_NAMES: Array[String] = [
	"Sainte Devote", "Beau Rivage", "Casino Chicane In", "Casino Chicane Out", "Place du Casino", "Casino Sweep",
	"Tunnel In", "Tunnel Out", "Portier", "Portier Drift", "Marina Sweep", "Yacht Club", "Nouvelle Chicane", "Tabac",
	"Piscine Chicane", "Rascasse In", "Rascasse Out", "Church Bend", "Anthony Noghes",
]
## +1 right, -1 left, from the blueprint.
const TURN_DIRECTIONS: Array[int] = [1, 1, 1, -1, -1, 1, 1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 1, -1, 1]

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	print("--- Running Monte Azure Marina circuit suite ---")
	var circuit_data = RegistryScript.get_circuit("monte_azure")
	check(circuit_data != null, "#M1 'monte_azure' is in the calendar registry")
	if circuit_data != null:
		check(circuit_data.scene_path == ScenePath, "#M2 the registry points at the circuits/monte_azure module scene (got %s)" % circuit_data.scene_path)
		check(circuit_data.is_playable(), "#M3 Monte Azure is playable once its scene exists")
		check(circuit_data.round_number == 4 and circuit_data.circuit_type == 1 and absf(circuit_data.length_km - 2.85) < 0.001, "#M4 round 4, SPRINT, 2.85 km")
	var builder_script := load(BuilderPath) as Script
	check(builder_script != null, "#M5 MonteAzureCircuitBuilder script exists at %s" % BuilderPath)
	var scene := load(ScenePath) as PackedScene
	check(scene != null, "#M6 the circuit scene loads")
	if scene == null or builder_script == null:
		_finish()
		return

	var instance := scene.instantiate() as Node3D
	root.add_child(instance)
	await process_frame
	var builder = instance
	check(instance.get_script() == builder_script, "#M7 the scene root is the MonteAzureCircuitBuilder")
	var ribbon = builder.ribbon_node()
	check(ribbon != null and ribbon.curve != null, "#M8 TrackRibbon and its Curve3D exist")
	check(String(builder.GEOMETRY_HASH) == GEOMETRY_HASH, "#M9 the builder records the frozen blueprint geometry_hash")

	var length: float = ribbon.curve.get_baked_length()
	check(absf(length - 2850.0) <= 15.0, "#M10 baked length is 2850 m +-15 (got %.2f)" % length)
	check(absf(length - 2850.0) <= 0.05 and float(builder.plan_length_m) < 2850.0 and float(builder.plan_length_m) > 2840.0,
		"#M11 the 3D ribbon is exactly 2850 m so every blueprint station is a ribbon distance; the flat plan is ~2.3 m shorter (ribbon %.3f, plan %.2f)" % [length, builder.plan_length_m])
	check(is_equal_approx(float(ribbon.road_half_width_m), 5.5), "#M12 road is 11 m wide (half width %.2f)" % ribbon.road_half_width_m)
	check(float(builder.plan_scale) > 1.099 and float(builder.plan_scale) < 1.1007, "#M13 plan_scale is ~1.0997, the 1.1006 flat scale less the climb (got %.6f)" % builder.plan_scale)
	var first: Vector3 = ribbon.curve.get_point_position(0)
	var last: Vector3 = ribbon.curve.get_point_position(ribbon.curve.point_count - 1)
	check(first.is_equal_approx(last), "#M14 the ribbon is closed (first point repeated last)")

	_check_turns(builder)
	_check_elevation(builder, ribbon)
	_check_sectors(builder)

	instance.queue_free()
	await process_frame
	await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "#M26 tearing the circuit down leaves no orphan nodes")
	_finish()


func _check_turns(builder) -> void:
	var turns: Array = builder.turns
	check(turns.size() == 19, "#M15 19 numbered turns (got %d)" % turns.size())
	var names_ok: bool = turns.size() == TURN_NAMES.size()
	var directions_ok: bool = turns.size() == TURN_DIRECTIONS.size()
	var ordered: bool = true
	var previous_s: float = -1.0
	for index: int in range(mini(turns.size(), TURN_NAMES.size())):
		var turn: Dictionary = turns[index]
		names_ok = names_ok and String(turn["name"]) == TURN_NAMES[index] and int(turn["number"]) == index + 1
		directions_ok = directions_ok and int(turn["direction"]) == TURN_DIRECTIONS[index]
		ordered = ordered and float(turn["s"]) > previous_s
		previous_s = float(turn["s"])
	check(names_ok, "#M16 turn names are the blueprint's with T7 Tunnel In, T8 Tunnel Out, T11 Marina Sweep, T12 Yacht Club")
	check(directions_ok, "#M17 turn directions follow the blueprint (+1 right, -1 left)")
	check(ordered, "#M18 turns are numbered in travel order")
	check(turns.size() == 19 and absf(float(turns[0]["s"]) - 658.0) <= 15.0, "#M19 Sainte Devote sits at s~658 (got %.0f)" % float(turns[0]["s"]))
	check(float(builder.min_turn_radius_m) >= 23.0, "#M20 tightest world radius is >= 23 m (got %.2f)" % builder.min_turn_radius_m)
	var kerbed: int = 0
	var has_angle: bool = true
	for turn: Dictionary in turns:
		has_angle = has_angle and turn.has("angle_deg")
		if has_angle and float(turn["angle_deg"]) >= float(builder.KERB_MIN_ANGLE_DEG):
			kerbed += 1
	check(has_angle and kerbed == 16, "#M21 16 of the 19 turns turn >= %.0f deg and take kerbs and braking boards (got %d)" % [builder.KERB_MIN_ANGLE_DEG, kerbed])


func _check_elevation(builder, ribbon) -> void:
	var delta: float = float(builder.max_elevation_m) - float(builder.min_elevation_m)
	check(float(builder.min_elevation_m) >= 0.0, "#M22 the lowest point is at or above sea level (%.2f m)" % builder.min_elevation_m)
	check(float(builder.max_elevation_m) >= 41.5 and delta >= 41.0, "#M23 peak >= 41.5 m and delta >= 41 m (peak %.1f, delta %.1f)" % [builder.max_elevation_m, delta])
	var worst: float = 0.0
	var s: float = 0.0
	var step: float = 5.0
	var previous_y: float = ribbon.get_point_at_offset(0.0, 0.0).origin.y
	while s < ribbon.length_m:
		s += step
		var y: float = ribbon.get_point_at_offset(s, 0.0).origin.y
		worst = maxf(worst, absf(y - previous_y) / step)
		previous_y = y
	check(worst <= 0.12, "#M24 steepest grade is <= 12 %% (got %.1f %%)" % (worst * 100.0))


func _check_sectors(builder) -> void:
	var sectors: Array = builder.sectors
	var thirds: bool = sectors.size() == 3
	if thirds:
		thirds = absf(float(sectors[0]["end_s"]) - 950.0) < 1.0 and absf(float(sectors[1]["end_s"]) - 1900.0) < 1.0 and absf(float(sectors[2]["end_s"]) - 2850.0) < 1.0
	check(thirds, "#M25 three sectors split the lap in thirds (950 / 1900 / 2850)")


func _finish() -> void:
	print("MONTE AZURE CIRCUIT TEST SUITE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
