extends SceneTree

## The ten pit boxes (and so the building behind them) stand on a straight of the circuit. A box row that runs into a bend
## still simulates well (the sim measures along the lane) but the building, drawn as a straight box, and the garages stop
## following the lane: Apex's 20 m layout was good in the flood test and drew boxes 4000..4180 into a 90 degree bend.
## Run: godot --headless --path . -s res://tests/test_pit_straightness.gd

const RaceScript := preload("res://scripts/gt/gt_race.gd")
const SCENES := {
	"Apex Ring": "res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn",
	"Brianza": "res://scenes/race_world/circuits/brianza/brianza_circuit.tscn",
	"Neo-Wangan": "res://scenes/race_world/circuits/neo_wangan/neo_wangan_circuit.tscn",
	"Monte Azure": "res://scenes/race_world/circuits/monte_azure/monte_azure_circuit.tscn",
}
const TEAM_COUNT: int = 10
## Past the first and last box centre: the building tails (a few metres of Brianza's runs onto the lap-closure bend) are not the box row.
const MARGIN_M: float = 0.0
const STEP_M: float = 4.0
## Total heading change allowed along the box row: a straight reads 0, the bend that spoiled Apex 90.
const MAX_HEADING_CHANGE_DEG: float = 1.5

var failures: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for circuit_name: String in SCENES:
		var circuit := (load(SCENES[circuit_name]) as PackedScene).instantiate() as Node3D
		if circuit_name == "Apex Ring":
			circuit.set("road_half_width_m", 7.0)
		root.add_child(circuit)
		await process_frame
		var ribbon = circuit if circuit_name == "Apex Ring" else circuit.get_node("TrackRibbon")
		var layout: Dictionary = RaceScript.default_pit_layout() if circuit_name == "Apex Ring" else (circuit.get_node("PitLane") as Node).sim_layout()
		_check_circuit(circuit_name, ribbon, layout)
		circuit.queue_free()
		await process_frame
	print("PIT STRAIGHTNESS: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check_circuit(circuit_name: String, ribbon, layout: Dictionary) -> void:
	var pitch: float = float(layout["stall_pitch_m"])
	var first: float = float(layout["stall_first_s"]) - MARGIN_M
	var last: float = float(layout["stall_first_s"]) + pitch * float(TEAM_COUNT - 1) + MARGIN_M
	var length: float = ribbon.length_m
	var total_change: float = 0.0
	var previous: float = NAN
	var s: float = first
	while s <= last:
		var forward: Vector3 = -ribbon.get_point_at_offset(fposmod(s, length), 0.0).basis.z
		var heading: float = rad_to_deg(atan2(forward.x, forward.z))
		if not is_nan(previous):
			total_change += absf(wrapf(heading - previous, -180.0, 180.0))
		previous = heading
		s += STEP_M
	check(total_change <= MAX_HEADING_CHANGE_DEG, "%s: the ten boxes (s %.0f..%.0f, %.0f m) stand on a straight (heading change %.1f deg)" % [circuit_name, fposmod(first, length), fposmod(last, length), last - first, total_change])
