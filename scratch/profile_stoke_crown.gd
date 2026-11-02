extends SceneTree

## Continuous busy-pit performance sample; no visibility toggles or captures disturb measured frames.
## godot --rendering-driver d3d12 --resolution 1920x1080 --path . -s scratch/profile_stoke_crown.gd
const World := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
var world: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native renderer required for performance evidence")
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	Settings.set_quality(Settings.Quality.HIGH)
	var config := Config.get_config()
	config.selected_circuit_id = "stoke_crown"
	config.selected_team_id = 4
	config.race_seed = 19220903
	config.total_laps = 3
	config.weather_preset = 3
	config.time_of_day = 2
	world = World.instantiate()
	root.add_child(world)
	world.finish_grid_intro()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for i: int in range(150):
		await process_frame
	for i: int in range(6):
		world.race.request_pit(world.race.cars[i * 3].id, 1)
	world.set_time_scale(8.0)
	var guard: int = 0
	while _in_lane() < 6 and guard < 9000 and not world.race.is_finished():
		await process_frame
		guard += 1
	world.set_time_scale(1.0)
	for i: int in range(120):
		await process_frame
	var samples: Array[float] = []
	var cpu_ms: float = 0.0
	var peak_lane: int = 0
	var previous := Time.get_ticks_usec()
	for i: int in range(1200):
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
		cpu_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		peak_lane = maxi(peak_lane, _in_lane())
	var sum: float = 0.0
	for sample: float in samples:
		sum += sample
	samples.sort()
	var mean := sum / float(samples.size())
	var p95 := samples[int(float(samples.size()) * 0.95)]
	var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	print("CONTINUOUS STOKE High1080p storm/night20cars6pit: mean=%.3fms fps=%.2f p95=%.3fms worst=%.3fms cpu_mean=%.3fms peak_lane=%d vram=%.1fMB" % [mean, 1000.0 / mean, p95, samples[-1], cpu_ms / float(samples.size()), peak_lane, vram])
	var passed := mean <= 16.6667 and p95 <= 16.6667 and peak_lane >= 6 and vram <= 2048.0
	print("[%s] Continuous render capacity supports60Hz with6carsinpit" % ["PASS" if passed else "FAIL"])
	world.free()
	for i: int in range(10):
		await process_frame
	print("CONTINUOUS orphans=%d" % Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	quit(0 if passed else 1)

func _in_lane() -> int:
	var count: int = 0
	for car in world.race.cars:
		count += 1 if car.pit != null else 0
	return count
