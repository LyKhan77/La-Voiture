extends SceneTree

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const Types := preload("res://scripts/gt/gt_types.gd")

var service_started: bool = false
var service_finished: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var config = Config.get_config()
	config.selected_circuit_id = "brianza"
	config.selected_team_id = 4
	config.total_laps = 3
	config.race_seed = 19220903
	var world = WorldScene.instantiate()
	root.add_child(world)
	world.finish_grid_intro()
	var car = world.race.get_car(8)
	var entered: bool = false
	var boxed: bool = false
	var exited: bool = false
	var started: Callable = func(id: int) -> void:
		if id == 8:
			service_started = true
	var finished: Callable = func(id: int) -> void:
		if id == 8:
			service_finished = true
	world.choreographer.stop_started.connect(started)
	world.choreographer.job_finished.connect(finished)
	var requested: bool = world.request_pit(8)
	world.set_time_scale(8.0)
	var frames: int = 0
	while not world.race.is_finished() and frames < 18000:
		await process_frame
		frames += 1
		if car.pit != null:
			entered = true
			boxed = boxed or car.pit.phase == Types.PitPhase.BOX
		elif boxed:
			exited = true
	var done: bool = world.race.is_finished()
	print("PHASE13_2 requested=%s entered=%s boxed=%s crew_started=%s crew_finished=%s exited=%s race_finished=%s frames=%d" % [requested, entered, boxed, service_started, service_finished, exited, done, frames])
	world.queue_free()
	await process_frame
	quit(0 if requested and entered and boxed and service_started and service_finished and exited and done else 1)
