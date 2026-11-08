extends SceneTree

## Fase 32 follow-up: the 3 lap Sprint rounds (Neo-Wangan, Monte Azure). A 3 lap race has no mandatory stop and every car
## carries the full distance plus 8%, so fuel is the only price of aggression: the AI must not spend it on a pace it
## cannot afford (it used to pit ten cars for a 0.1 lap shortfall), and the field must finish without stops or DNFs.
## Run: godot --headless --path . -s res://tests/test_sprint_balance.gd

const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const Types := preload("res://scripts/gt/gt_types.gd")

const DRY: int = WeatherScript.Archetype.DRY_SUNNY
const CIRCUITS: Array[String] = ["res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn", "res://scenes/race_world/circuits/neo_wangan/neo_wangan_circuit.tscn", "res://scenes/race_world/circuits/monte_azure/monte_azure_circuit.tscn"]

var failures: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for path: String in CIRCUITS:
		await _test_field(path)
	_test_aggression_needs_fuel()
	quit(1 if failures else 0)


func _track_of(inst: Node) -> Array:
	var rib: Node = inst.get_node_or_null("TrackRibbon")
	if rib == null:
		rib = inst
		rib.road_half_width_m = 7.0
	var pit: Node = inst.get_node_or_null("PitLane")
	var layout: Dictionary = pit.sim_layout() if pit != null else {}
	return [TrackScript.new(rib, rib.road_half_width_m * 2.0), layout]


func _test_field(path: String) -> void:
	var inst: Node = (load(path) as PackedScene).instantiate()
	root.add_child(inst)
	await process_frame
	var built: Array = _track_of(inst)
	var race := RaceScript.new(built[0], 3, 5, DRY, 20, built[1])
	race.incidents_enabled = false
	var ticks: int = 0
	while not race.is_finished() and ticks < 60000:
		race.step()
		ticks += 1
	var stops: int = 0
	var dnf: int = 0
	for car: GtCar in race.cars:
		stops += car.stops
		dnf += 1 if car.is_dnf else 0
	var order: Array[GtCar] = race.standings()
	var spread: float = race.classified_time(order[order.size() - 1]) - race.classified_time(order[0])
	var name: String = path.get_file().get_basename()
	check(race.is_finished(), "%s: the 3 lap field finishes" % name)
	check(stops == 0, "%s: nobody pits in a 3 lap sprint (%d stops)" % [name, stops])
	check(dnf == 0, "%s: nobody retires (%d DNF)" % [name, dnf])
	check(spread < 30.0, "%s: the field stays together, winner to last %.1f s" % [name, spread])
	race.dispose()
	inst.queue_free()
	await process_frame


## The mode chooser lets a battling aggressive team go AGGRESSIVE only while the tank can pay for it.
func _test_aggression_needs_fuel() -> void:
	var inst: Node = (load(CIRCUITS[0]) as PackedScene).instantiate()
	root.add_child(inst)
	var built: Array = _track_of(inst)
	var race := RaceScript.new(built[0], 3, 5, DRY, 20, built[1])
	race.incidents_enabled = false
	var car: GtCar = race.cars[5]
	var ahead: GtCar = race.cars[4]
	car.s = ahead.s - 5.0 # inside the battle gap
	var fierce: Dictionary = GtStrategy.NEUTRAL_TACTIC.duplicate()
	fierce["aggression"] = 1.0
	car.fuel = GtFuelPlan.preset_kg(GtFuelPlan.Preset.FULL, 3, car.fuel_use)
	var tight: Dictionary = GtStrategy.choose_modes(race, car, fierce)
	check(int(tight["pace"]) != Types.PaceMode.AGGRESSIVE and int(tight["pace"]) != Types.PaceMode.ATTACK, "a full 3 lap tank (+8 %%) does not pay for aggressive pace (pace %d)" % int(tight["pace"]))
	car.fuel = 3.0 * car.fuel_use * 1.8
	var rich: Dictionary = GtStrategy.choose_modes(race, car, fierce)
	check(int(rich["pace"]) == Types.PaceMode.AGGRESSIVE, "a tank with margin to spare lets a battling team go AGGRESSIVE (pace %d)" % int(rich["pace"]))
	race.dispose()
	inst.queue_free()
