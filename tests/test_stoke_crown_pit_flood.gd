extends SceneTree

const Circuit := preload("res://scenes/race_world/circuits/stoke_crown/stoke_crown_circuit.tscn")
const Track := preload("res://scripts/gt/gt_track.gd")
const Flood := preload("res://tests/pit_flood_checks.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var circuit := Circuit.instantiate() as Node3D
	root.add_child(circuit)
	await process_frame
	var ribbon: TrackRibbon = circuit.get_node("TrackRibbon")
	var checks := Flood.new(Track.new(ribbon, 14.0), circuit.get_node("PitLane").sim_layout())
	checks.run_all("Stoke Crown")
	circuit.free()
	await process_frame
	quit(1 if checks.failures else 0)
