extends SceneTree

## Splits every frame into: _physics_process callbacks, _process callbacks, and the rest (physics server step,
## render submission, waiting on the GPU, the frame limiter). Probe nodes at the extreme process priorities
## timestamp the start and end of each callback phase. Native run (needs a GPU):
##   godot --path . --resolution 1920x1080 --script res://scratch/profile_frame_buckets.gd -- <circuit_id> [seconds] [capped|uncapped]
## Reports mean / p95 / max of each bucket for frames with and without a sim tick.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const Types := preload("res://scripts/gt/gt_types.gd")


class Probe extends Node:
	var stamp: int = 0
	var first: bool = true
	var hook: Callable

	func _ready() -> void:
		process_priority = -100000 if first else 100000
		process_physics_priority = -100000 if first else 100000

	func _process(_delta: float) -> void:
		hook.call(&"process", first)

	func _physics_process(_delta: float) -> void:
		hook.call(&"physics", first)


var world: Node3D
var phys_start: int = 0
var phys_total: int = 0
var proc_start: int = 0
var proc_total: int = 0
var rows: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _hook(kind: StringName, is_first: bool) -> void:
	var now: int = Time.get_ticks_usec()
	if kind == &"physics":
		if is_first:
			phys_start = now
		else:
			phys_total += now - phys_start
	else:
		if is_first:
			proc_start = now
		else:
			proc_total += now - proc_start


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var circuit: String = args[0] if args.size() > 0 else "brianza"
	var seconds: float = float(args[1]) if args.size() > 1 else 25.0
	var capped: bool = args.size() > 2 and args[2] == "capped"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60 if capped else 0
	var config := ConfigScript.get_config()
	config.selected_circuit_id = circuit
	config.total_laps = 3
	config.time_of_day = 0
	config.weather_preset = 0
	config.selected_team_id = 0
	config.race_seed = 19220903
	world = WorldScene.instantiate()
	root.add_child(world)
	for first: bool in [true, false]:
		var probe := Probe.new()
		probe.first = first
		probe.hook = _hook
		root.add_child(probe)
	world.finish_grid_intro()
	for _i: int in range(240):
		await process_frame
	var last_usec: int = Time.get_ticks_usec()
	var last_time: float = float(world.race.time)
	var begin: int = Time.get_ticks_msec()
	phys_total = 0
	proc_total = 0
	while float(Time.get_ticks_msec() - begin) < seconds * 1000.0 and not world.race.is_finished():
		await process_frame
		var now: int = Time.get_ticks_usec()
		var frame: float = float(now - last_usec) / 1000.0
		var race_time: float = float(world.race.time)
		rows.append({
			"frame": frame,
			"physics": float(phys_total) / 1000.0,
			"process": float(proc_total) / 1000.0,
			"rest": frame - float(phys_total + proc_total) / 1000.0,
			"tick": race_time > last_time,
		})
		phys_total = 0
		proc_total = 0
		last_usec = now
		last_time = race_time
	_report(circuit, capped)
	world.queue_free()
	quit(0)


func _report(circuit: String, capped: bool) -> void:
	print("FRAME BUCKETS %s %s frames=%d (ms)" % [circuit, "capped60" if capped else "uncapped", rows.size()])
	for label: String in ["frames with a sim tick", "frames without a sim tick"]:
		var want: bool = label == "frames with a sim tick"
		var subset: Array[Dictionary] = rows.filter(func(row: Dictionary) -> bool: return bool(row["tick"]) == want)
		print("  -- %s: %d" % [label, subset.size()])
		for key: String in ["frame", "physics", "process", "rest"]:
			var values: Array[float] = []
			for row: Dictionary in subset:
				values.append(float(row[key]))
			if values.is_empty():
				continue
			values.sort()
			var total: float = 0.0
			for value: float in values:
				total += value
			print("    %-8s mean %7.2f  p50 %7.2f  p95 %7.2f  max %7.2f" % [key, total / float(values.size()), values[int(values.size() * 0.5)], values[int(values.size() * 0.95)], values[values.size() - 1]])
