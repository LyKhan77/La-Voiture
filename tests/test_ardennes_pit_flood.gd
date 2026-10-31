extends SceneTree

## The whole field boxes at once on Ardennes' own pit lane (its published sim layout, 20 m boxes).
## Measurement and thresholds: tests/pit_flood_checks.gd (story in tests/test_monte_azure_pit_flood.gd).
## Run: godot --headless --path . -s res://tests/test_ardennes_pit_flood.gd

const CircuitScene := preload("res://scenes/race_world/circuits/ardennes/ardennes_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const FloodChecks := preload("res://tests/pit_flood_checks.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var circuit := CircuitScene.instantiate() as Node3D
	root.add_child(circuit)
	await process_frame
	var ribbon = circuit.get_node("TrackRibbon")
	var layout: Dictionary = (circuit.get_node("PitLane") as Node).sim_layout()
	var checks := FloodChecks.new(TrackScript.new(ribbon, ribbon.road_half_width_m * 2.0), layout)
	checks.run_all("Ardennes")
	circuit.queue_free()
	await process_frame
	quit(1 if checks.failures else 0)
