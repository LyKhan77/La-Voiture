extends SceneTree

## FASE 11 Langkah 4 native smoke test (GPU needed, not --headless). Runs the real 60 Hz game path at 1080p:
## a 3-lap, 20-car night-storm race at the HIGH preset, a real pit request for the followed team, a bounded
## 1x sample of the crew being active (frame times, memory, VRAM, draw calls), then fast-forward to the
## winning studio and out through the studio's real exit button.
##   godot --path . --fullscreen --resolution 1920x1080 --script res://scratch/smoke_pitcrew_visual.gd
##
## Honesty rules: the sim is never stepped by hand; everything runs through SceneTree.process_frame at 60 Hz.
## The project caps at run/max_fps=60, so this prints min/avg/p95/p99/max and how many frames MISS the cap
## instead of claiming a locked 60 fps. A timeout or a wrong scene after the real exit fails with exit code 1.

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const WinningStudio := preload("res://scripts/ui/winning_scene.gd")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const PS := preload("res://scripts/core/presentation_settings.gd")
const PitLaneScript := preload("res://scripts/world/circuits/apex_ring/apex_pit_complex.gd")
const ChoreographerScript := preload("res://scripts/car/pitstop_choreographer.gd")

const HQ_SCENE := "res://scenes/main.tscn"
const WARMUP_S: float = 10.0
const SAMPLE_MAX_S: float = 30.0
const FAST_SCALE: float = 8.0
const TIMEOUT_WALL_S: float = 900.0
const STUDIO_TIMEOUT_S: float = 300.0
const PIT_ENTRY_WINDOW_M: float = 330.0
const OVER_18_MS: float = 18.5
const OVER_33_MS: float = 33.4

var world: RaceWeekendWorld
var _wall_start_ms: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_wall_start_ms = Time.get_ticks_msec()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	PS.set_quality(PS.Quality.HIGH)
	var baseline_orphans: int = _orphans()
	print("GPU: %s  window: %s  quality: %s  engine max_fps: %d  orphans at start: %d" % [
		RenderingServer.get_video_adapter_name(), DisplayServer.window_get_size(), PS.QUALITY_NAMES[PS.quality],
		int(ProjectSettings.get_setting("application/run/max_fps", 60)), baseline_orphans,
	])

	var config: RaceConfigData = ConfigScript.reset()
	config.total_laps = 3
	config.weather_preset = 3 # the heaviest preset, as the langkah 2 smoke race
	config.time_of_day = 2 # night: headlight beams and tail trails on
	world = WorldScene.instantiate() as RaceWeekendWorld
	if world == null:
		_fail("could not instantiate res://scenes/race_weekend_world.tscn")
		return
	world.race_config = config
	root.add_child(world)
	current_scene = world
	PS.apply_to_tree(world)
	await process_frame
	var viewport_size: Vector2i = root.get_texture().get_image().get_size()
	if viewport_size != Vector2i(1920, 1080) or not is_equal_approx(root.scaling_3d_scale, 1.0):
		_fail("native 1080p required; viewport=%s render scale=%.2f" % [viewport_size, root.scaling_3d_scale])
		return
	print("RENDER WORKLOAD: viewport=%s scale=%.2f" % [viewport_size, root.scaling_3d_scale])
	if world.race == null or world.race.cars.size() != 20:
		_fail("the race did not build 20 cars (%d)" % (world.race.cars.size() if world.race != null else -1))
		return
	if config.total_laps != 3:
		_fail("the race is not configured for 3 laps (%d)" % config.total_laps)
		return
	print("RACE: cars=%d laps=%d weather=%s time_of_day=%d" % [
		world.race.cars.size(), config.total_laps, world.race.weather.condition_label, config.time_of_day,
	])

	# Warm up in real time so the shaders and the start countdown settle; no timing is recorded here.
	var warm_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - warm_start < int(WARMUP_S * 1000.0):
		await process_frame
		if _timed_out():
			_fail("timed out during the warm-up")
			return

	var followed: GtCar = world.race.get_car(world.followed_id)
	if followed == null:
		_fail("followed car id %d is missing" % world.followed_id)
		return
	var target: GtCar = null
	if world.request_pit(followed.id):
		target = followed
	else:
		var teammate_id: int = followed.id + 1 if followed.id % 2 == 0 else followed.id - 1
		var teammate: GtCar = world.race.get_car(teammate_id)
		if teammate != null and teammate.team_id == followed.team_id and world.request_pit(teammate.id):
			target = teammate
	if target == null:
		_fail("no real world.request_pit() was accepted for team %d" % followed.team_id)
		return
	world.followed_id = target.id
	print("PIT REQUEST: car #%d team %d -> true (real world.request_pit path), pit_request=%d" % [
		target.id, target.team_id, target.pit_request,
	])
	var stops_before: int = target.stops

	# Wait at 1x until this car is at its pit entry and its crew is really out. No timing recorded while waiting.
	var wait_start: int = Time.get_ticks_msec()
	while not _crew_sample_ready(target):
		await process_frame
		if _timed_out():
			_fail("timed out waiting for the pit crew to go active")
			return
		if Time.get_ticks_msec() - wait_start > 300000:
			_fail("the requested car did not reach its pit crew within 300 s")
			return
	print("CREW ACTIVE: crew for team %d is out after %.1f s wall since the request, car #%d pit=%s u=%.0f m" % [
		target.team_id, float(Time.get_ticks_msec() - wait_start) / 1000.0, target.id,
		target.pit != null, _pit_u(target),
	])

	var frames: Array[float] = []
	var start_ms: int = Time.get_ticks_msec()
	var last: int = Time.get_ticks_usec()
	var memory_start: float = _mem_mb()
	var memory_peak: float = memory_start
	var vram_start: float = _vram_mb()
	var vram_peak: float = vram_start
	var nodes_start: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objects_start: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var draw_peak: int = 0
	var process_ms_sum: float = 0.0
	var physics_ms_sum: float = 0.0
	var job_frames: int = 0
	var job_seen: bool = false
	var saw_walking: bool = false
	var saw_ready: bool = false
	var crew_back: bool = false

	while true:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
		memory_peak = maxf(memory_peak, _mem_mb())
		vram_peak = maxf(vram_peak, _vram_mb())
		draw_peak = maxi(draw_peak, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
		process_ms_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0

		var elapsed: float = float(Time.get_ticks_msec() - start_ms) / 1000.0
		var state: int = world.choreographer.crew_state(target.team_id)
		saw_walking = saw_walking or state == ChoreographerScript.CrewState.WALKING_OUT
		saw_ready = saw_ready or state == ChoreographerScript.CrewState.READY
		var job: PitstopChoreographer.Job = world.choreographer.get_job(target.id)
		if job != null:
			job_frames += 1
			if not job_seen:
				job_seen = true
				print("PIT JOB: car #%d boxed after %.2f s of sampling (phase %d, timer %.2f/%.2f, lift %.2f, progress %.2f)" % [
					target.id, elapsed, job.phase,
					target.pit.timer if target.pit != null else -1.0,
					target.pit.duration if target.pit != null else -1.0,
					job.lift_m, target.pit.wheel_swap_progress if target.pit != null else -1.0,
				])
		if job_seen and job == null and state == ChoreographerScript.CrewState.STANDBY:
			crew_back = true
			break
		if elapsed >= SAMPLE_MAX_S:
			break
		if _timed_out():
			_fail("timed out during the 1x crew sample")
			return

	if not job_seen:
		_fail("the crew was active for %.1f s but the car never took its pit job" % (float(Time.get_ticks_msec() - start_ms) / 1000.0))
		return
	if world.choreographer.get_job(target.id) != null or target.stops <= stops_before:
		_fail("the sampled pit service did not complete at 1x before the %.0f s ceiling" % SAMPLE_MAX_S)
		return
	var sample_s: float = float(Time.get_ticks_msec() - start_ms) / 1000.0
	print("PIT CREW SAMPLE: %.2f s wall, %d frames, job active for %d frames; walking_out=%s ready=%s, crew back in the garage=%s" % [
		sample_s, frames.size(), job_frames, saw_walking, saw_ready, crew_back,
	])
	print("PIT RESULT: car #%d team %d stops=%d compound=%d, in pit=%s, sim progress=%.2f, race time %.0f s" % [
		target.id, target.team_id, target.stops, target.compound, target.pit != null,
		target.pit.wheel_swap_progress if target.pit != null else 1.0, world.race.time,
	])

	_report("RACE 1x PIT CREW", frames, process_ms_sum, physics_ms_sum, sample_s)
	print("MEMORY/VRAM: static %.1f -> %.1f MB (peak %.1f)  VRAM %.1f -> %.1f MB (peak %.1f)  draw calls peak %d" % [
		memory_start, _mem_mb(), memory_peak, vram_start, _vram_mb(), vram_peak, draw_peak,
	])
	print("OBJECTS: nodes %d -> %d  objects %d -> %d" % [
		nodes_start, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		objects_start, int(Performance.get_monitor(Performance.OBJECT_COUNT)),
	])

	# Only now accelerate: the honest 1x measurement above is finished.
	world.set_time_scale(FAST_SCALE)
	var studio_start: int = Time.get_ticks_msec()
	var studio: WinningStudio = null
	var race_time_s: float = 0.0
	var car_count: int = 0
	var finished_cars: int = 0
	var winner_number: int = 0
	var winner_lap: int = 0
	while studio == null:
		await process_frame
		studio = _studio()
		if studio == null and is_instance_valid(world) and not world.is_queued_for_deletion():
			var live: Array = world.race.standings()
			race_time_s = world.race.time
			car_count = live.size()
			finished_cars = 0
			for entry: GtCar in live:
				finished_cars += 1 if entry.finished_at >= 0.0 else 0
			winner_number = live[0].number
			winner_lap = live[0].lap
		if studio != null:
			break
		if _timed_out():
			_fail("timed out waiting for the winning studio")
			return
		if Time.get_ticks_msec() - studio_start > int(STUDIO_TIMEOUT_S * 1000.0):
			_fail("the winning studio did not appear within %.0f s" % STUDIO_TIMEOUT_S)
			return
	print("STUDIO: reached after %.1f s wall at %.0fx, race time %.0f s, %d of %d cars classified, winner #%d on lap %d" % [
		float(Time.get_ticks_msec() - studio_start) / 1000.0, FAST_SCALE, race_time_s,
		finished_cars, car_count, winner_number, winner_lap,
	])
	if studio == null:
		_fail("the winning studio is missing after the wait")
		return

	# The real finale button path: exit_button drives the studio's own HQ transition.
	studio.exit_button.pressed.emit()
	var exit_guard: int = 0
	while current_scene == null or current_scene.scene_file_path != HQ_SCENE:
		await process_frame
		exit_guard += 1
		if _timed_out() or exit_guard > 1200:
			_fail("the winning studio exit button did not return to %s (current scene: %s)" % [
				HQ_SCENE, current_scene.scene_file_path if current_scene != null else "<none>",
			])
			return
	print("BACK AT: %s (real winning studio exit button)" % current_scene.scene_file_path)
	var menu: Node = current_scene
	menu.queue_free()
	for _i: int in range(20):
		await process_frame
	var remaining_orphans: int = _orphans()
	print("ORPHAN NODES: baseline %d, after the race, winning studio and menu are freed %d" % [baseline_orphans, remaining_orphans])
	quit(0 if baseline_orphans == 0 and remaining_orphans == 0 else 1)


# --- live pit helpers ------------------------------------------------------

func _studio() -> WinningStudio:
	if is_instance_valid(current_scene) and current_scene.scene_file_path == WinningStudio.PATH:
		return current_scene as WinningStudio
	return null


func _pit_u(car: GtCar) -> float:
	return fposmod(car.s - PitLaneScript.ENTRY_S + 300.0, world.race.track.length) - 300.0


func _crew_sample_ready(car: GtCar) -> bool:
	if world.choreographer.crew_state(car.team_id) == ChoreographerScript.CrewState.STANDBY:
		return false
	if car.pit != null:
		return true
	var u: float = _pit_u(car)
	return u >= -PIT_ENTRY_WINDOW_M and u < 0.0


# --- reporting -------------------------------------------------------------

func _orphans() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


func _mem_mb() -> float:
	return float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0


func _vram_mb() -> float:
	return float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / 1048576.0


func _timed_out() -> bool:
	return Time.get_ticks_msec() - _wall_start_ms > int(TIMEOUT_WALL_S * 1000.0)


func _fail(message: String) -> void:
	printerr("FAIL: " + message)
	quit(1)


func _report(label: String, frames: Array[float], process_ms_sum: float, physics_ms_sum: float, wall_s: float) -> void:
	print("NOTE: application/run/max_fps=%d caps the engine; miss counts below are the honest drops, not a locked-60 claim." % int(ProjectSettings.get_setting("application/run/max_fps", 60)))
	if frames.is_empty():
		print("%s: no frames sampled" % label)
		return
	var sorted: Array[float] = frames.duplicate()
	sorted.sort()
	var count: int = sorted.size()
	var total: float = 0.0
	var over_18: int = 0
	var over_33: int = 0
	var over_budget: int = 0
	for ms: float in sorted:
		total += ms
		if ms > 1000.0 / 60.0:
			over_budget += 1
		if ms > OVER_18_MS:
			over_18 += 1
		if ms > OVER_33_MS:
			over_33 += 1
	var average: float = total / float(count)
	var p95: float = sorted[mini(count - 1, int(float(count) * 0.95))]
	var p99: float = sorted[mini(count - 1, int(float(count) * 0.99))]
	print("%s: %d frames over %.2f s  min %.2f ms  avg %.2f ms (%.1f fps)  median %.2f  p95 %.2f  p99 %.2f  max %.2f  >18.5 ms: %d (%.2f%%)  >33.4 ms: %d (%.2f%%)" % [
		label, count, wall_s, sorted[0], average, 1000.0 / maxf(average, 0.001), sorted[count / 2], p95, p99, sorted[count - 1],
		over_18, 100.0 * float(over_18) / float(count), over_33, 100.0 * float(over_33) / float(count),
	])
	print("COST: _process %.2f ms/frame  physics %.2f ms/frame" % [
		process_ms_sum / float(count), physics_ms_sum / float(count),
	])
	print("STRICT 60 FPS BUDGET: %d/%d wall frames exceeded 16.667 ms (18.5/33.4 ms counters above are separate outlier buckets)" % [over_budget, count])
