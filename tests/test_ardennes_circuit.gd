extends SceneTree

## Headless suite for Ardennes Valley Ring (Round 05, GRAND_PRIX, FASE 16): the closed GP spline built from the frozen
## mapgen blueprint (geometry_hash sha256:fea86645...), its 104 m climb, the numbered turns, and the calendar entry.
## Run: godot --headless --path . -s res://tests/test_ardennes_circuit.gd

const ScenePath := "res://scenes/race_world/circuits/ardennes/ardennes_circuit.tscn"
const BuilderPath := "res://scripts/world/circuits/ardennes/ardennes_circuit_builder.gd"
const RegistryScript := preload("res://scripts/core/circuit_calendar_registry.gd")
const GEOMETRY_HASH := "sha256:fea86645c41b985de3d0b7987a90785d62a319e0507796e98656275c3bed98d4"
## The blueprint's turn names without their "Tn " prefix (the HUD and the minimap print the number separately).
const TURN_NAMES: Array[String] = [
	"Arena Gateway Hairpin", "Outer Crescent Arc 1", "Outer Crescent Arc 2", "Ridge Panorama Sweeper",
	"North Summit Climb Arc", "North Summit Crest Turn", "Mountain Crest Carousel 1", "Mountain Crest Carousel 2",
	"Infield Stadium Drop", "Amphitheater Chute", "Infield Bowl Entry", "Stadium Inner Carousel Apex 1",
	"Stadium Inner Carousel Apex 2", "Stadium Lower Bowl Sweeper", "Grandstand S-Transition", "Arena West Hook In",
	"Arena West Hook Out", "West Ridge High-Speed Exit", "Stadium Chicane In", "Stadium Chicane Out",
]
## +1 right, -1 left, from the blueprint.
const TURN_DIRECTIONS: Array[int] = [1, -1, 1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, 1, 1, -1, 1, 1]

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	print("--- Running Ardennes Valley Ring circuit suite ---")
	var circuit_data = RegistryScript.get_circuit("ardennes")
	check(circuit_data != null, "#A1 'ardennes' is in the calendar registry")
	if circuit_data != null:
		check(circuit_data.scene_path == ScenePath, "#A2 the registry points at the circuits/ardennes module scene (got %s)" % circuit_data.scene_path)
		check(circuit_data.is_playable(), "#A3 Ardennes is playable once its scene exists")
		check(circuit_data.round_number == 5 and circuit_data.circuit_type == 0 and absf(circuit_data.length_km - 5.40) < 0.001, "#A4 round 5, GRAND_PRIX, 5.40 km")
	var builder_script := load(BuilderPath) as Script
	check(builder_script != null, "#A5 ArdennesCircuitBuilder script exists at %s" % BuilderPath)
	var scene := load(ScenePath) as PackedScene
	check(scene != null, "#A6 the circuit scene loads")
	if scene == null or builder_script == null:
		_finish()
		return

	var instance := scene.instantiate() as Node3D
	root.add_child(instance)
	await process_frame
	var builder = instance
	check(instance.get_script() == builder_script, "#A7 the scene root is the ArdennesCircuitBuilder")
	var ribbon = builder.ribbon_node()
	check(ribbon != null and ribbon.curve != null, "#A8 TrackRibbon and its Curve3D exist")
	check(String(builder.GEOMETRY_HASH) == GEOMETRY_HASH, "#A9 the builder records the frozen blueprint geometry_hash")

	var length: float = ribbon.curve.get_baked_length()
	check(absf(length - 5400.0) <= 15.0, "#A10 baked length is 5400 m +-15 (got %.2f)" % length)
	check(absf(length - 5400.0) <= 0.05 and float(builder.plan_length_m) < 5400.0 and float(builder.plan_length_m) > 5380.0,
		"#A11 the 3D ribbon is exactly 5400 m so every blueprint station (pit 5220 / 240) is a ribbon distance; the flat plan is a few metres shorter (ribbon %.3f, plan %.2f)" % [length, builder.plan_length_m])
	check(is_equal_approx(float(ribbon.road_half_width_m), 7.0), "#A12 road is 14 m wide (half width %.2f)" % ribbon.road_half_width_m)
	check(float(builder.plan_scale) > 1.000 and float(builder.plan_scale) < 1.0027, "#A13 plan_scale is under the 1.002666 flat scale because the 104 m climb lengthens the 3D curve (got %.6f)" % builder.plan_scale)
	var first: Vector3 = ribbon.curve.get_point_position(0)
	var last: Vector3 = ribbon.curve.get_point_position(ribbon.curve.point_count - 1)
	check(first.is_equal_approx(last), "#A14 the ribbon is closed (first point repeated last)")

	_check_turns(builder)
	_check_elevation(builder, ribbon)
	_check_sectors(builder)

	instance.queue_free()
	await process_frame
	await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "#A26 tearing the circuit down leaves no orphan nodes")
	_finish()


func _check_turns(builder) -> void:
	var turns: Array = builder.turns
	check(turns.size() == 20, "#A15 20 numbered turns (got %d)" % turns.size())
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
	check(names_ok, "#A16 turn names are the blueprint's, T1 to T20")
	check(directions_ok, "#A17 turn directions follow the blueprint (+1 right, -1 left)")
	check(ordered, "#A18 turns are numbered in travel order")
	check(turns.size() == 20 and absf(float(turns[0]["s"]) - 387.0) <= 15.0, "#A19 Arena Gateway Hairpin sits at s~387 (got %.0f)" % float(turns[0]["s"]))
	check(float(builder.min_turn_radius_m) >= 38.0, "#A20 tightest world radius is >= 38 m (got %.2f)" % builder.min_turn_radius_m)
	var kerbed: int = 0
	var has_angle: bool = true
	for turn: Dictionary in turns:
		has_angle = has_angle and turn.has("angle_deg")
		if has_angle and float(turn["angle_deg"]) >= float(builder.KERB_MIN_ANGLE_DEG):
			kerbed += 1
	check(has_angle and kerbed == 16, "#A21 16 of the 20 turns turn >= %.0f deg and take kerbs and braking boards; T2, T3, T4 and T11 are kinks (got %d)" % [builder.KERB_MIN_ANGLE_DEG, kerbed])


func _check_elevation(builder, ribbon) -> void:
	var delta: float = float(builder.max_elevation_m) - float(builder.min_elevation_m)
	check(float(builder.min_elevation_m) >= -0.01 and float(builder.min_elevation_m) <= 0.5, "#A22 the lowest point is the stadium floor at ~0 m (%.2f m)" % builder.min_elevation_m)
	check(float(builder.max_elevation_m) >= 103.5 and delta >= 103.5, "#A23 peak >= 103.5 m and delta >= 103.5 m (peak %.1f, delta %.1f)" % [builder.max_elevation_m, delta])
	var worst: float = 0.0
	var s: float = 0.0
	var step: float = 5.0
	var previous_y: float = ribbon.get_point_at_offset(0.0, 0.0).origin.y
	while s < ribbon.length_m:
		s += step
		var y: float = ribbon.get_point_at_offset(s, 0.0).origin.y
		worst = maxf(worst, absf(y - previous_y) / step)
		previous_y = y
	# The blueprint keys joined by smoothstep peak at 1.5x the mean grade: 13.5 % on the 45 m drop over s=2800-3300.
	check(worst <= 0.14, "#A24 steepest grade is <= 14 %% (got %.1f %%)" % (worst * 100.0))


func _check_sectors(builder) -> void:
	var sectors: Array = builder.sectors
	var thirds: bool = sectors.size() == 3
	if thirds:
		thirds = absf(float(sectors[0]["end_s"]) - 1800.0) < 1.0 and absf(float(sectors[1]["end_s"]) - 3600.0) < 1.0 and absf(float(sectors[2]["end_s"]) - 5400.0) < 1.0
	check(thirds, "#A25 three sectors split the lap in thirds (1800 / 3600 / 5400)")


func _finish() -> void:
	print("ARDENNES CIRCUIT TEST SUITE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
