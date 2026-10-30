extends SceneTree

## A pit stop through the real race weekend world (sim, PitstopChoreographer, crew): nothing sticks once a car is in its box.
## The crew starts work right after the car parks, every stop swaps four wheels, a serviced car that must wait for the fast
## lane shows a red board and idle crew (never the green "go"), the wait is bounded, the job closes as the car leaves, and every
## crew walks home to its garage. Scenarios: one car, two cars of one team sharing a box, six cars at once (forces holds).
## Run: godot --headless --path . -s res://tests/test_pit_stop_in_world.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const Types := preload("res://scripts/gt/gt_types.gd")

const TIME_SCALE: float = 4.0
const GUARD_FRAMES: int = 12000
## The crew works within this long of a car sitting still in its box with the penalty served.
const JOB_OPEN_MAX_S: float = 1.0
## The job closes within this long of the car leaving its box.
const JOB_CLOSE_MAX_S: float = 1.0
const CREW_HOME_MAX_S: float = 90.0
const WHEELS_PER_STOP: int = 4
const HOLD_RED := Color("#e0212e")

var failures: int = 0
var world: Node
var wheel_swaps: Dictionary = {}


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _scenario("apex_ring", "one car", func(cars: Array) -> Array: return [cars[0].id], false)
	await _scenario("apex_ring", "two teammates share a box", func(cars: Array) -> Array: return _teammates(cars), false)
	await _scenario("apex_ring", "six cars box at once", func(cars: Array) -> Array: return [cars[0].id, cars[3].id, cars[6].id, cars[9].id, cars[12].id, cars[15].id], true)
	await _scenario("neo_wangan", "six cars box at once", func(cars: Array) -> Array: return [cars[0].id, cars[3].id, cars[6].id, cars[9].id, cars[12].id, cars[15].id], true)
	await _scenario("brianza", "six cars box at once", func(cars: Array) -> Array: return [cars[0].id, cars[3].id, cars[6].id, cars[9].id, cars[12].id, cars[15].id], true)
	await _scenario("monte_azure", "six cars box at once", func(cars: Array) -> Array: return [cars[0].id, cars[3].id, cars[6].id, cars[9].id, cars[12].id, cars[15].id], true)
	quit(1 if failures else 0)


func _teammates(cars: Array) -> Array:
	for car in cars:
		for other in cars:
			if other.id != car.id and other.team_id == car.team_id:
				return [car.id, other.id]
	return []


func _scenario(circuit: String, label: String, pick: Callable, expect_hold: bool) -> void:
	var tag: String = "%s, %s" % [circuit, label]
	var config := ConfigScript.get_config()
	config.selected_circuit_id = circuit
	config.total_laps = 6
	config.time_of_day = 0
	config.weather_preset = 0
	config.selected_team_id = 0
	config.race_seed = 19220903
	world = WorldScene.instantiate()
	root.add_child(world)
	world.finish_grid_intro()
	for _i: int in range(60):
		await process_frame
	var choreographer: PitstopChoreographer = world.choreographer
	wheel_swaps.clear()
	choreographer.wheel_swapped.connect(func(car_id: int, _corner: int, _compound: int) -> void: wheel_swaps[car_id] = int(wheel_swaps.get(car_id, 0)) + 1)
	var ids: Array = pick.call(world.race.cars)
	check(not ids.is_empty(), "%s: scenario has cars to send" % tag)
	for id: int in ids:
		world.race.request_pit(id, 1)
	world.set_time_scale(TIME_SCALE)
	var rec: Dictionary = {}
	for id: int in ids:
		rec[id] = {"ready": -1.0, "job": -1.0, "out": -1.0, "closed": -1.0, "exit": -1.0, "hold_frames": 0, "hold_wrong": 0, "green_while_held": 0, "release_wait": 0.0}
	var done_at: float = -1.0
	var frames: int = 0
	while frames < GUARD_FRAMES:
		await process_frame
		frames += 1
		var t: float = world.race.time
		var all_done: bool = true
		for id: int in ids:
			_sample(rec[id], id, t, choreographer)
			all_done = all_done and float(rec[id]["exit"]) >= 0.0 and float(rec[id]["closed"]) >= 0.0
		if all_done and done_at < 0.0:
			done_at = t
		if done_at >= 0.0 and _crews_home(ids):
			break
		if done_at >= 0.0 and t - done_at > CREW_HOME_MAX_S:
			break
	var total_holds: int = 0
	for id: int in ids:
		var r: Dictionary = rec[id]
		total_holds += int(r["hold_frames"])
		check(float(r["job"]) >= 0.0 and float(r["exit"]) >= 0.0, "%s: car %d is serviced and leaves the lane" % [tag, id])
		check(float(r["job"]) - float(r["ready"]) <= JOB_OPEN_MAX_S, "%s: car %d: the crew works within %.1f s of the car sitting in its box (%.2f s)" % [tag, id, JOB_OPEN_MAX_S, float(r["job"]) - float(r["ready"])])
		check(int(wheel_swaps.get(id, 0)) == WHEELS_PER_STOP, "%s: car %d gets %d wheels swapped (%d)" % [tag, id, WHEELS_PER_STOP, int(wheel_swaps.get(id, 0))])
		check(float(r["closed"]) - float(r["out"]) <= JOB_CLOSE_MAX_S, "%s: car %d: the job closes within %.1f s of the car leaving its box (%.2f s)" % [tag, id, JOB_CLOSE_MAX_S, float(r["closed"]) - float(r["out"])])
		check(float(r["release_wait"]) <= Types.PIT_RELEASE_HARD_CAP_S + 0.1, "%s: car %d is never held in its box past %.0f s (%.1f s)" % [tag, id, Types.PIT_RELEASE_HARD_CAP_S, float(r["release_wait"])])
		check(int(r["hold_wrong"]) == 0 and int(r["green_while_held"]) == 0, "%s: car %d: while held the job is in HOLD with a red board (%d frames off, %d green)" % [tag, id, int(r["hold_wrong"]), int(r["green_while_held"])])
	if expect_hold:
		check(total_holds > 0, "%s: at least one serviced car had to wait for the lane (%d held frames), so the hold animation was exercised" % [tag, total_holds])
	check(choreographer.jobs.is_empty(), "%s: no job is left open" % tag)
	check(choreographer.finished_ids.size() == ids.size(), "%s: every stop is recorded as finished (%d of %d)" % [tag, choreographer.finished_ids.size(), ids.size()])
	check(_crews_home(ids), "%s: every crew is back in its garage" % tag)
	world.queue_free()
	for _i: int in range(5):
		await process_frame


func _sample(r: Dictionary, id: int, t: float, choreographer: PitstopChoreographer) -> void:
	var car: Variant = _car(id)
	var job: PitstopChoreographer.Job = choreographer.get_job(id)
	if car.pit != null:
		var pit: GtPit = car.pit
		var sitting: bool = pit.phase == Types.PitPhase.BOX and car.v < 0.1 and pit.penalty_taken and pit.penalty_hold_s <= 0.0
		if sitting and float(r["ready"]) < 0.0:
			r["ready"] = t
		if pit.phase == Types.PitPhase.OUT and float(r["out"]) < 0.0:
			r["out"] = t
		r["release_wait"] = maxf(float(r["release_wait"]), pit.release_wait_s)
		if pit.holding_release and job == null:
			r["hold_wrong"] = int(r["hold_wrong"]) + 1
		elif pit.holding_release:
			r["hold_frames"] = int(r["hold_frames"]) + 1
			if job.phase != PitstopChoreographer.Phase.HOLD:
				r["hold_wrong"] = int(r["hold_wrong"]) + 1
			var disc := job.lollipop_disc.material_override as StandardMaterial3D
			if disc == null or not disc.albedo_color.is_equal_approx(HOLD_RED):
				r["green_while_held"] = int(r["green_while_held"]) + 1
	elif float(r["out"]) >= 0.0 and float(r["exit"]) < 0.0:
		r["exit"] = t
	if job != null and float(r["job"]) < 0.0:
		r["job"] = t
	if float(r["job"]) >= 0.0 and job == null and float(r["closed"]) < 0.0:
		r["closed"] = t


func _crews_home(ids: Array) -> bool:
	for id: int in ids:
		if world.choreographer.crew_state(_car(id).team_id) != PitstopChoreographer.CrewState.STANDBY:
			return false
	return true


func _car(id: int) -> Variant:
	for car in world.race.cars:
		if car.id == id:
			return car
	return null
