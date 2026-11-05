extends SceneTree

## The whole field boxes at once on Paulistano's own LEFT-hand 14 m pitch lane (the sim
## drives it at negative laterals): every car is serviced, none stands still in the lane
## for long, the lane clears in a reasonable time and the cars do not run into each other.
## Measurement and thresholds: tests/pit_flood_checks.gd.
##
## Recorded deviation (FASE 0, approved by the developer on 2026-11-04): on seed 31 the
## "box 3-9 s apart" scenario holds one serviced car 7.9 s for the lane (bound 7 s). The
## trace shows every second is a correct hold: two cars passing on the fast lane, then the
## stacked second car of the next box swinging in 14 m ahead. Moving the building (s 62..90)
## changes nothing and the shared release rules were tried and reverted (no effect); seeds
## 7, 13, 101 and 2024 stay at or under 5.0 s. The bound is 8 s for this lane only.
## Before the left-side sim fix this suite also failed "bunched 20 m apart" (23 deep-overlap
## ticks), which is the regression it guards.
## Run: godot --headless --path . -s res://tests/test_paulistano_pit_flood.gd

const CircuitScene := preload("res://scenes/race_world/circuits/paulistano/paulistano_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const FloodChecks := preload("res://tests/pit_flood_checks.gd")

const RELEASE_DEVIATION_MAX_S: float = 8.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var circuit := CircuitScene.instantiate() as Node3D
	root.add_child(circuit)
	await process_frame
	var ribbon = circuit.get_node("TrackRibbon")
	var layout: Dictionary = (circuit.get_node("PitLane") as Node).sim_layout()
	var checks := FloodChecks.new(TrackScript.new(ribbon, ribbon.road_half_width_m * 2.0), layout)
	checks.release_max_s = RELEASE_DEVIATION_MAX_S
	checks.check(float(layout["stall_lane_m"]) < 0.0 and float(layout["fast_lane_m"]) < 0.0 and float(layout["edge_lateral_m"]) < 0.0,
		"Paulistano: the sim drives the pit lane on the left (negative laterals)")
	checks.run_all("Paulistano Speed Arena")
	circuit.queue_free()
	await process_frame
	quit(1 if checks.failures else 0)
