extends SceneTree

## What the town and the vegetation of Monte Azure placed, and why candidates were turned down:
##   godot --headless --path . -s res://scratch/probe_monte_dressing.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/race_world/circuits/monte_azure/monte_azure_circuit.tscn") as PackedScene
	var circuit := scene.instantiate() as Node3D
	root.add_child(circuit)
	await process_frame
	var env = circuit.get_node("Environment")
	print("buildings %d, rejections %s" % [env.districts.buildings.size(), env.districts.rejections])
	var counts: Dictionary = {}
	for entry: Dictionary in env.foliage.poses:
		counts[entry["kind"]] = int(counts.get(entry["kind"], 0)) + 1
	print("foliage %s" % counts)
	print("stats %s" % env.stats())
	quit(0)
