extends SceneTree

## Native smoke + performance gate of a race weekend with a busy pit lane (needs a GPU, not --headless):
##   godot --path . --resolution 1920x1080 --script res://scratch/smoke_pit_race.gd -- brianza
## Three laps of 20 cars. After warm-up six cars are called to box at once; frame time is measured at 1x with
## vsync off while the lane is busy (draw calls of the circuit environment are sampled too), then the race is
## sped to the flag and the podium and orphan nodes are checked.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const WinningStudio := preload("res://scripts/ui/winning_scene.gd")

const MEASURE_FRAMES: int = 600
const WARMUP_FRAMES: int = 40
const SAMPLE_EVERY: int = 60
const SETTLE_FRAMES: int = 8
const PIT_CALLERS: int = 6

var world: Node
var frame_times: Array[float] = []
var env_draw_calls: Array[int] = []
var env_tris: Array[int] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var circuit: String = args[0] if args.size() > 0 else "brianza"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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
	for _i: int in range(150):
		await process_frame
	for index: int in range(PIT_CALLERS):
		world.race.request_pit(world.race.cars[index * 3].id, 1)
	# Run fast until the lane is busy, then measure at 1x.
	world.set_time_scale(8.0)
	var wait_guard: int = 0
	while _cars_in_lane() < 3 and wait_guard < 6000 and not world.race.is_finished():
		await process_frame
		wait_guard += 1
	world.set_time_scale(1.0)
	for _i: int in range(60):
		await process_frame
	var last_usec: int = Time.get_ticks_usec()
	var measured: int = 0
	var peak_in_lane: int = 0
	while measured < MEASURE_FRAMES and not world.race.is_finished():
		await process_frame
		var now: int = Time.get_ticks_usec()
		var delta_ms: float = float(now - last_usec) / 1000.0
		last_usec = now
		if measured > WARMUP_FRAMES:
			frame_times.append(delta_ms)
		measured += 1
		peak_in_lane = maxi(peak_in_lane, _cars_in_lane())
		if measured % SAMPLE_EVERY == 0:
			await _sample_environment_cost()
			# Hiding and showing the environment disturbs the next frames: let them settle, off the record.
			for _settle: int in range(SETTLE_FRAMES):
				await process_frame
			last_usec = Time.get_ticks_usec()
	world.set_time_scale(16.0)
	var guard: int = 0
	while not world.race.is_finished() and guard < 12000:
		await process_frame
		guard += 1
	world.set_time_scale(1.0)
	var finished: int = 0
	var stops: int = 0
	for car in world.race.cars:
		finished += 1 if car.finished_at >= 0.0 else 0
		stops += car.stops
	print("SMOKE %s race finished=%s cars_finished=%d stops=%d peak_in_lane=%d ticks_guard=%d" % [circuit, str(world.race.is_finished()), finished, stops, peak_in_lane, guard])
	var mean: float = 0.0
	for value: float in frame_times:
		mean += value
	mean /= maxf(1.0, float(frame_times.size()))
	var sorted := frame_times.duplicate()
	sorted.sort()
	var p95: float = sorted[clampi(int(float(sorted.size()) * 0.95), 0, sorted.size() - 1)] if not sorted.is_empty() else 0.0
	var worst: float = sorted[sorted.size() - 1] if not sorted.is_empty() else 0.0
	print("SMOKE frame_ms mean=%.2f p95=%.2f worst=%.2f frames=%d fps=%.1f" % [mean, p95, worst, frame_times.size(), 1000.0 / maxf(mean, 0.001)])
	print("SMOKE environment draw_calls=%s tris=%s" % [str(env_draw_calls), str(env_tris)])
	world.show_podium()
	var frames: int = 0
	while not (current_scene is WinningStudio) and frames < 600:
		await process_frame
		frames += 1
	print("SMOKE podium=%s" % str(current_scene is WinningStudio))
	if current_scene != null:
		current_scene.queue_free()
	if is_instance_valid(world):
		world.queue_free()
	for _i: int in range(10):
		await process_frame
	print("SMOKE orphans_after_free=%d" % int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))
	quit(0)


func _cars_in_lane() -> int:
	var count: int = 0
	for car in world.race.cars:
		count += 1 if car.pit != null else 0
	return count


## Draw calls and triangles the environment node adds to the current view: frame totals with and without it.
func _sample_environment_cost() -> void:
	var environment: Node3D = world.get("environment")
	for _i: int in range(2):
		await process_frame
	var with_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var with_tris: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	environment.visible = false
	for _i: int in range(2):
		await process_frame
	var without_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var without_tris: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	environment.visible = true
	env_draw_calls.append(with_calls - without_calls)
	env_tris.append(with_tris - without_tris)
