extends SceneTree

## What does one 20 Hz sim tick spend its time on? Headless (CPU only):
##   godot --headless --path . -s res://scratch/profile_sim_step.gd -- <circuit_id> [sim_seconds] [pits]
## Runs the real race of a RaceWeekendWorld but drives GtRace.step()'s phases by hand, in step()'s own order, with a
## microsecond timer around each, and reports mean / p95 / max per phase. `pits` calls six cars to box at once.
## Keep the phase list in sync with GtRace.step().

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const CarScript := preload("res://scripts/gt/gt_car.gd")

const PHASES: Array[String] = [
	"radio+replies", "weather", "race_control", "build_contexts", "update_car (20)", "contacts.resolve", "stewards+advisor",
	"standings+positions", "TOTAL",
]

var samples: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var circuit: String = args[0] if args.size() > 0 else "brianza"
	var sim_seconds: float = float(args[1]) if args.size() > 1 else 150.0
	var pits: bool = args.size() > 2 and args[2] == "pits"
	var config := ConfigScript.get_config()
	config.selected_circuit_id = circuit
	config.total_laps = 3
	config.time_of_day = 0
	config.weather_preset = 0
	config.selected_team_id = 0
	config.race_seed = 19220903
	var world: Node3D = WorldScene.instantiate()
	root.add_child(world)
	world.finish_grid_intro()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	var race = world.race
	for key: String in PHASES:
		samples[key] = []
	# Warm up: 40 s of racing so the field has spread out.
	for _i: int in range(int(40.0 / Types.TICK_DT)):
		race.step()
	if pits:
		for index: int in range(6):
			race.request_pit(race.cars[index * 3].id, 1)
	var per_car: Array[float] = []
	var car_total: Dictionary = {}
	for _i: int in range(int(sim_seconds / Types.TICK_DT)):
		_timed_step(race, per_car, car_total)
	print("SIM PROFILE %s %s ticks=%d (ms per tick)" % [circuit, "6 cars pitting" if pits else "normal race", int(sim_seconds / Types.TICK_DT)])
	for key: String in PHASES:
		var values: Array = samples[key]
		values.sort()
		var total: float = 0.0
		for value: float in values:
			total += value
		print("  %-22s mean %6.3f  p95 %6.3f  p99 %6.3f  max %6.3f" % [key, total / float(values.size()), values[int(values.size() * 0.95)], values[int(values.size() * 0.99)], values[values.size() - 1]])
	var worst: Array = car_total.keys()
	worst.sort_custom(func(a: int, b: int) -> bool: return float(car_total[a]) > float(car_total[b]))
	var rows: Array[String] = []
	for car_id: int in worst.slice(0, 4):
		rows.append("car %d %.3f ms/tick" % [car_id, float(car_total[car_id]) / float(sim_seconds / Types.TICK_DT)])
	print("  slowest update_car: %s" % ", ".join(rows))
	world.free()
	quit(0)


func _mark(key: String, start: int) -> int:
	var now: int = Time.get_ticks_usec()
	(samples[key] as Array).append(float(now - start) / 1000.0)
	return now


func _timed_step(race, _per_car: Array[float], car_total: Dictionary) -> void:
	var dt: float = Types.TICK_DT
	var begin: int = Time.get_ticks_usec()
	var t: int = begin
	race.tick_count += 1
	race._tick_driver_radio_cooldowns(dt)
	race._flush_replies()
	t = _mark("radio+replies", t)
	race._step_weather(dt)
	t = _mark("weather", t)
	race._update_race_control(dt)
	t = _mark("race_control", t)
	var racing: Array[CarScript] = []
	for car in race.cars:
		if car.is_racing():
			racing.append(car)
	var contexts: Dictionary = race._driving.build_contexts(racing)
	t = _mark("build_contexts", t)
	var cars_start: int = t
	for car in race.cars:
		var one: int = Time.get_ticks_usec()
		race._driving.update_car(car, contexts.get(car), dt)
		car_total[car.id] = float(car_total.get(car.id, 0.0)) + float(Time.get_ticks_usec() - one) / 1000.0
	t = _mark("update_car (20)", cars_start)
	var active: Array[CarScript] = []
	for car in race.cars:
		if car.is_racing():
			active.append(car)
	race.contacts.resolve(active, dt)
	if race.contacts.contacts_last > 0:
		race._protect_caution_order(active, contexts)
	t = _mark("contacts.resolve", t)
	race.stewards.step()
	if race.is_finished():
		race.stewards.close_all()
	race._check_advisor_tactics()
	race._expire_suggestion()
	race._check_flood_radio()
	race.time += dt
	race._update_wreck_fade()
	t = _mark("stewards+advisor", t)
	var order: Array = race.standings()
	for index: int in range(order.size()):
		order[index].position = index + 1
	t = _mark("standings+positions", t)
	(samples["TOTAL"] as Array).append(float(Time.get_ticks_usec() - begin) / 1000.0)

