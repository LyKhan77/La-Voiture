extends SceneTree

## The whole field boxes at once on the Apex Ring's pit lane (the sim default layout, 14 m boxes).
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
	# The pit straight is only ~145 m (s 3920..4065) before a 90 degree bend, so 20 m boxes and a 100 m run-up do not fit
	# (tried in Fase 15.1: boxes and building ended up in the bend). These are the measured limits of the 14 m layout, a
	# ratchet against getting worse, not the Monte targets (90 s, 0.05 m): lane clear 93-95 s, a late car overshoots the
	# first box (25 m after the entry line) by 13.15 m and is snapped back.
	checks.flush_max_s = 100.0
	checks.teleport_max_m = 14.0
	checks.run_all("Apex Ring")
	circuit.queue_free()
	await process_frame
	quit(1 if checks.failures else 0)
