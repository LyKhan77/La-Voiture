extends SceneTree

## The whole field boxes at once on the Apex Ring's pit lane (the sim default layout, 20 m boxes on the start straight).
## Measurement and thresholds: tests/pit_flood_checks.gd (story in tests/test_monte_azure_pit_flood.gd).
## Run: godot --headless --path . -s res://tests/test_apex_pit_flood.gd

const CircuitScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const FloodChecks := preload("res://tests/pit_flood_checks.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var circuit := CircuitScene.instantiate() as Node3D
	circuit.road_half_width_m = 7.0
	root.add_child(circuit)
	await process_frame
	var checks := FloodChecks.new(TrackScript.new(circuit, 14.0), RaceScript.default_pit_layout())
	checks.run_all("Apex Ring")
	circuit.queue_free()
	await process_frame
	quit(1 if checks.failures else 0)
