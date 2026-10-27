extends SceneTree

## Native smoke test of the Neo-Wangan race weekend (needs a GPU, not --headless):
##   godot --path . --resolution 1920x1080 --script res://temp/smoke_wangan_race.gd
## Runs three laps behind the real scene, measures rendered frame time at 1x with vsync off, then
## speeds to the flag, opens the podium and reports orphan nodes.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const WinningStudio := preload("res://scripts/ui/winning_scene.gd")

const MEASURE_FRAMES: int = 240
const SHOTS := "res://executor-report/screenshots/phases/"

var world: Node3D
var frame_times: Array[float] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var config := ConfigScript.get_config()
	config.selected_circuit_id = "neo_wangan"
	config.total_laps = 3
	config.time_of_day = 2
	config.weather_preset = 0
	config.selected_team_id = 0
	config.race_seed = 12022026
	world = WorldScene.instantiate()
	root.add_child(world)
	world.finish_grid_intro()
	for _i: int in range(150):
		await process_frame
	await _capture("01-start-lights")
	var last_usec: int = Time.get_ticks_usec()
	var measured: int = 0
	while measured < MEASURE_FRAMES and not world.race.is_finished():
		await process_frame
		var now: int = Time.get_ticks_usec()
		var delta_ms: float = float(now - last_usec) / 1000.0
		last_usec = now
		if measured > 30: # skip the first frames (shader warm-up)
			frame_times.append(delta_ms)
		measured += 1
		if measured == 120:
			await _capture("02-racing-pack")
		if measured == 200:
			await _capture("03-night-city")
	world.set_time_scale(16.0)
	var guard: int = 0
	while not world.race.is_finished() and guard < 6000:
		await process_frame
		guard += 1
		if guard == 120:
			await _capture("04-bridge-at-speed")
		if guard == 260:
			await _capture("05-underpass")
	world.set_time_scale(1.0)
	await _capture("06-finish")
	var finished: int = 0
	for car in world.race.cars:
		if car.finished_at >= 0.0:
			finished += 1
	print("SMOKE race finished=%s cars_finished=%d ticks_guard=%d" % [str(world.race.is_finished()), finished, guard])
	var mean: float = 0.0
	for value: float in frame_times:
		mean += value
	mean /= maxf(1.0, float(frame_times.size()))
	var sorted := frame_times.duplicate()
	sorted.sort()
	var p95: float = sorted[clampi(int(float(sorted.size()) * 0.95), 0, sorted.size() - 1)] if not sorted.is_empty() else 0.0
	var worst: float = sorted[sorted.size() - 1] if not sorted.is_empty() else 0.0
	print("SMOKE frame_ms mean=%.2f p95=%.2f worst=%.2f frames=%d fps=%.1f" % [mean, p95, worst, frame_times.size(), 1000.0 / maxf(mean, 0.001)])
	print("SMOKE draw_calls=%d tris=%d orphans=%d" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])
	world.show_podium()
	var frames: int = 0
	while not (current_scene is WinningStudio) and frames < 600:
		await process_frame
		frames += 1
	await _capture("07-podium")
	var studio: WinningStudio = current_scene as WinningStudio
	print("SMOKE podium=%s" % str(studio != null))
	await process_frame
	print("SMOKE orphans_after_podium=%d" % int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))
	quit(0)


func _capture(label: String) -> void:
	for _i: int in range(3):
		await process_frame
	var image: Image = root.get_texture().get_image()
	var path: String = "%sphase-12-smoke-%s.png" % [SHOTS, label]
	image.save_png(path)
	print("saved ", path)
