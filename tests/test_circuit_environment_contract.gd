extends SceneTree

## Every circuit's environment is a CircuitEnvironment and honours its contract: it knows its circuit id, reports it is
## built, measures what it submits, takes DAY / SUNSET / NIGHT and wind, runs update() with the live race, and answers
## ground_y_at(). A circuit without trackside furniture simply leaves `furniture` null.
## Run: godot --headless --path . -s res://tests/test_circuit_environment_contract.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const Config := preload("res://scripts/core/race_config_data.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const CIRCUITS: Array[String] = ["apex_ring", "neo_wangan", "brianza"]
const STATS_KEYS: Array[String] = ["circuit_id", "built", "draw_calls", "triangles", "multimeshes"]

var failures: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for circuit: String in CIRCUITS:
		await _audit(circuit)
	quit(1 if failures else 0)


func _audit(circuit: String) -> void:
	var config = Config.get_config()
	config.selected_circuit_id = circuit
	config.selected_team_id = 4
	config.race_seed = 19220903
	var world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	var env = world.environment
	var is_env: bool = env is CircuitEnvironment
	check(is_env, "%s: the environment is a CircuitEnvironment" % circuit)
	if not is_env:
		world.queue_free()
		await process_frame
		return
	check(env.circuit_id == circuit, "%s: the environment knows its circuit id (%s)" % [circuit, env.circuit_id])
	check(env.built and env.ribbon != null, "%s: the environment reports it is built against a ribbon" % circuit)
	var stats: Dictionary = env.stats()
	var keys_ok: bool = true
	for key: String in STATS_KEYS:
		keys_ok = keys_ok and stats.has(key)
	check(keys_ok and stats["circuit_id"] == circuit and bool(stats["built"]), "%s: stats() carries the common keys and this circuit's id" % circuit)
	check(int(stats["draw_calls"]) > 0 and int(stats["triangles"]) > 0, "%s: the set measures what it submits (%d draw calls, %d triangles)" % [circuit, int(stats["draw_calls"]), int(stats["triangles"])])
	# DAY, SUNSET and NIGHT (GtWeather's own time-of-day dictionaries), a storm gloom and the wind run on every circuit,
	# in any order, and the set still measures afterwards.
	for mode: int in [WeatherScript.TimeOfDay.DAY, WeatherScript.TimeOfDay.SUNSET, WeatherScript.TimeOfDay.NIGHT, WeatherScript.TimeOfDay.DAY]:
		env.apply_time_of_day(WeatherScript.compute_time_of_day(mode, 0.0), 0.0)
	env.apply_time_of_day(WeatherScript.compute_time_of_day(WeatherScript.TimeOfDay.DAY, 0.0), 0.6)
	env.apply_wind(0.016, 24.0, 1.0)
	var after: Dictionary = env.stats()
	check(int(after["draw_calls"]) > 0 and str(after["circuit_id"]) == circuit, "%s: the set still measures after mood, gloom and wind changes (%d draw calls)" % [circuit, int(after["draw_calls"])])
	var ground: float = env.ground_y_at(Vector3(3.0, 7.0, -4.0))
	check(is_finite(ground), "%s: ground_y_at answers with a number" % circuit)
	for _i: int in range(40):
		await process_frame
	# The world calls update() every frame with the live race; any error in it would show up as a SCRIPT ERROR.
	check(env.built and int(env.stats()["draw_calls"]) > 0, "%s: the environment is still built and measuring after 40 frames of update()" % circuit)
	world.queue_free()
	await process_frame
