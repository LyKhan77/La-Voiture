extends SceneTree

## The whole field boxes at once on Eifel Forest Ring's own 14 m pitch lane:
## every car is serviced, none stands still in the lane for long, the lane clears
## in a reasonable time and the cars do not run into each other.
## Measurement and thresholds: tests/pit_flood_checks.gd.
## Run: godot --headless --path . -s res://tests/test_eifel_forest_pit_flood.gd

const CircuitScene := preload("res://scenes/race_world/circuits/eifel_forest/eifel_forest_circuit.tscn")
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
	checks.run_all("Eifel Forest")
	circuit.queue_free()
	await process_frame
	quit(1 if checks.failures else 0)
