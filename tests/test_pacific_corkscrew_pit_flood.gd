extends SceneTree

## The whole field boxes at once on Pacific Corkscrew's own 20 m pitch lane:
## every car is serviced, none stands still in the lane for long, the lane clears
## in a reasonable time and the cars do not run into each other.

const Circuit := preload("res://scenes/race_world/circuits/pacific_corkscrew/pacific_corkscrew_circuit.tscn")
const Track := preload("res://scripts/gt/gt_track.gd")
const Flood := preload("res://tests/pit_flood_checks.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var circuit := Circuit.instantiate() as Node3D
	root.add_child(circuit)
	await process_frame
	var ribbon: TrackRibbon = circuit.get_node("TrackRibbon")
	var checks := Flood.new(Track.new(ribbon, 13.0), circuit.get_node("PitLane").sim_layout())
	checks.run_all("Pacific Corkscrew")
	circuit.free()
	await process_frame
	quit(1 if checks.failures else 0)
