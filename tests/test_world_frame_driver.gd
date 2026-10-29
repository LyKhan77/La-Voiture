extends SceneTree

## The race weekend world presents on render frames, not physics frames. Its step moves 20 cars, the camera, the HUD
## and the VFX; run from _physics_process at a fixed 60 Hz it beats against the 60 FPS limiter, so some render frames
## step twice and others not at all (22% of frames over budget on Brianza, 2.5% when stepped from _process).
## Run: godot --headless --path . -s res://tests/test_world_frame_driver.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")

var failures: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var config = Config.get_config()
	config.selected_circuit_id = "apex_ring"
	config.race_seed = 19220903
	var world = WorldScene.instantiate()
	root.add_child(world)
	world.finish_grid_intro()
	await process_frame
	check(world.is_processing(), "the world steps from _process (every render frame)")
	check(not world.is_physics_processing(), "the world does not step from _physics_process")
	# The start lights take a few real seconds; then the 20 Hz ticks must run off process frames.
	var before: float = float(world.race.time)
	var waited_ms: int = 0
	var begin: int = Time.get_ticks_msec()
	while float(world.race.time) <= before and waited_ms < 40000:
		await process_frame
		waited_ms = Time.get_ticks_msec() - begin
	check(float(world.race.time) > before, "the race advances on process frames alone (%d ms)" % waited_ms)
	# A frame can still reach the world after its race was disposed (a test or a scene teardown); stepping a disposed
	# race must do nothing instead of calling into the freed driver.
	var disposed = world.race
	disposed.dispose()
	var ticks_before: int = int(disposed.tick_count)
	disposed.step()
	check(int(disposed.tick_count) == ticks_before, "stepping a disposed race does nothing")
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
