extends SceneTree

## Which part of RaceWeekendWorld.step() makes a frame slow? Native run (needs a GPU):
##   godot --path . --resolution 1920x1080 --script res://scratch/profile_world_step.gd -- <circuit_id> [seconds] [pits]
## Takes over the world's physics-process step, runs its sections by hand in step()'s own order with a microsecond
## timer around each (at the 60 Hz the real step runs at), and reports mean / p95 / max per section, split by frames
## that ran a sim tick and frames that did not. Keep the section list in sync with RaceWeekendWorld.step().

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const Types := preload("res://scripts/gt/gt_types.gd")

const SECTIONS: Array[String] = [
	"director", "run_ticks", "flag_panels", "actors.present (20)", "present_pit (20)", "pit_crews", "podium", "vfx.update",
	"cameras", "environment.update", "hud.update", "TOTAL",
]

var world: Node3D
var tick_rows: Array[Dictionary] = []
var idle_rows: Array[Dictionary] = []
var actor_times: Array[float] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var circuit: String = args[0] if args.size() > 0 else "brianza"
	var seconds: float = float(args[1]) if args.size() > 1 else 25.0
	var pits: bool = args.size() > 2 and args[2] == "pits"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	var config := ConfigScript.get_config()
	config.selected_circuit_id = circuit
	config.total_laps = 3
	config.time_of_day = 0
	config.weather_preset = 0
	config.selected_team_id = 0
	config.race_seed = 19220903
	world = WorldScene.instantiate()
	root.add_child(world)
	world.finish_grid_intro()
	await process_frame
	world.set_physics_process(false)
	for _i: int in range(180):
		_timed_step(1.0 / 60.0, false)
		await process_frame
	if pits:
		for index: int in range(6):
			world.race.request_pit(world.race.cars[index * 3].id, 1)
		# Fast-forward until the lane is busy, then measure at 1x.
		world.set_time_scale(8.0)
		var guard: int = 0
		while _cars_in_lane() < 3 and guard < 6000:
			_timed_step(1.0 / 60.0, false)
			await process_frame
			guard += 1
		world.set_time_scale(1.0)
	var begin: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - begin) < seconds * 1000.0 and not world.race.is_finished():
		_timed_step(1.0 / 60.0, true)
		await process_frame
	_report(circuit, pits)
	world.queue_free()
	quit(0)


func _cars_in_lane() -> int:
	var count: int = 0
	for car in world.race.cars:
		count += 1 if car.pit != null else 0
	return count


func _timed_step(delta: float, record: bool) -> void:
	var race = world.race
	var row: Dictionary = {}
	var begin: int = Time.get_ticks_usec()
	var t: int = begin
	var time_before: float = float(race.time)
	world.director.advance(delta)
	world.director.update_race(int(race.race_control["flag"]) == Types.Flag.SC, race.is_finished())
	t = _mark(row, "director", t)
	if world.director.is_racing():
		world._run_ticks(delta)
	t = _mark(row, "run_ticks", t)
	world._update_flag_panels()
	t = _mark(row, "flag_panels", t)
	var alpha: float = clampf(world._tick_accumulator / Types.TICK_DT, 0.0, 1.0)
	var spin_scale: float = minf(world.time_scale, 2.0)
	var audible: bool = world.time_scale <= world.AUDIBLE_MAX_TIME_SCALE and not world._celebration_requested
	var present_us: int = 0
	var pit_us: int = 0
	for actor in world.actors:
		var one: int = Time.get_ticks_usec()
		actor.present(alpha, delta, spin_scale, audible)
		var two: int = Time.get_ticks_usec()
		world._present_pit(actor)
		present_us += two - one
		pit_us += Time.get_ticks_usec() - two
		if record:
			actor_times.append(float(two - one) / 1000.0)
	row["actors.present (20)"] = float(present_us) / 1000.0
	row["present_pit (20)"] = float(pit_us) / 1000.0
	t = Time.get_ticks_usec()
	world._update_pit_crews(delta)
	t = _mark(row, "pit_crews", t)
	world._update_podium(delta)
	t = _mark(row, "podium", t)
	world.vfx.update(delta, alpha)
	t = _mark(row, "vfx.update", t)
	world._update_cameras(delta)
	t = _mark(row, "cameras", t)
	world.environment.update(delta, race)
	t = _mark(row, "environment.update", t)
	world.hud.update(delta)
	t = _mark(row, "hud.update", t)
	row["TOTAL"] = float(Time.get_ticks_usec() - begin) / 1000.0
	if record:
		if float(race.time) > time_before:
			tick_rows.append(row)
		else:
			idle_rows.append(row)


func _mark(row: Dictionary, key: String, start: int) -> int:
	var now: int = Time.get_ticks_usec()
	row[key] = float(now - start) / 1000.0
	return now


func _report(circuit: String, pits: bool) -> void:
	print("WORLD STEP PROFILE %s %s (ms per 60 Hz step)" % [circuit, "6 cars pitting" if pits else "normal race"])
	for label: String in ["with a sim tick", "without a sim tick"]:
		var rows: Array[Dictionary] = tick_rows if label == "with a sim tick" else idle_rows
		print("  -- steps %s: %d" % [label, rows.size()])
		for key: String in SECTIONS:
			var values: Array[float] = []
			for row: Dictionary in rows:
				values.append(float(row.get(key, 0.0)))
			if values.is_empty():
				continue
			values.sort()
			var total: float = 0.0
			for value: float in values:
				total += value
			print("    %-22s mean %6.3f  p95 %6.3f  max %6.3f" % [key, total / float(values.size()), values[int(values.size() * 0.95)], values[values.size() - 1]])
	actor_times.sort()
	if not actor_times.is_empty():
		print("  one car's present(): mean %.3f ms, p95 %.3f ms, max %.3f ms" % [_mean(actor_times), actor_times[int(actor_times.size() * 0.95)], actor_times[actor_times.size() - 1]])


func _mean(values: Array[float]) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(maxi(values.size(), 1))
