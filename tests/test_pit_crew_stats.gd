extends SceneTree

## Fase 32 Task 11: a pit stop takes as long as the team's crew makes it: a mean from its speed rating and now and
## then an error from its consistency rating, both from the team's own hash stream, so a seed replays the same stops.
## The pit wall's loss estimate uses the team's mean. Run: godot --headless --path . -s res://tests/test_pit_crew_stats.gd

const TrackScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const Types := preload("res://scripts/gt/gt_types.gd")

const DRY: int = WeatherScript.Archetype.DRY_SUNNY
const SAMPLES: int = 200

var failures: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _extreme(values: Array[float], highest: bool) -> int:
	var pick: int = 0
	for index: int in range(values.size()):
		if (values[index] > values[pick]) == highest and values[index] != values[pick]:
			pick = index
	return pick


func _mean_time(team: int) -> float:
	var total: float = 0.0
	for serial: int in range(SAMPLES):
		total += GtTeamStats.pit_stop_time(team, 5, serial)
	return total / float(SAMPLES)


func _error_stops(team: int) -> int:
	var errors: int = 0
	for serial: int in range(SAMPLES):
		if GtTeamStats.pit_stop_time(team, 5, serial) > GtTeamStats.mean_stop_time(team) + 0.3:
			errors += 1
	return errors


func _run() -> void:
	var fast: int = _extreme(GtTeamStats.CREW_SPEED, true)
	var slow: int = _extreme(GtTeamStats.CREW_SPEED, false)
	var steady: int = _extreme(GtTeamStats.CREW_CONSISTENCY, true)
	var shaky: int = _extreme(GtTeamStats.CREW_CONSISTENCY, false)
	check(_mean_time(slow) - _mean_time(fast) >= 0.8, "the slowest crew stands at least 0.8 s longer than the fastest on average (%.2f s vs %.2f s)" % [_mean_time(slow), _mean_time(fast)])
	var floor_ok: bool = true
	for team: int in range(GtData.TEAM_NAMES.size()):
		for serial: int in range(SAMPLES):
			floor_ok = floor_ok and GtTeamStats.pit_stop_time(team, 5, serial) >= 2.0
	check(floor_ok, "no stop is shorter than 2.0 s")
	check(is_equal_approx(GtTeamStats.pit_stop_time(3, 5, 7), GtTeamStats.pit_stop_time(3, 5, 7)), "same team, seed and serial give the same time")
	check(_error_stops(steady) < _error_stops(shaky), "the most consistent crew errs less often than the least (%d vs %d of %d)" % [_error_stops(steady), _error_stops(shaky), SAMPLES])
	check(_error_stops(shaky) > 0, "an inconsistent crew does make errors")

	var ribbon: Node = TrackScene.instantiate()
	ribbon.road_half_width_m = 7.0
	root.add_child(ribbon)
	var track := TrackScript.new(ribbon, 14.0)
	var race := RaceScript.new(track, 15, 5, DRY, 20)
	race.incidents_enabled = false
	var car: GtCar = race.cars[0]
	car.lap = 3
	var needed: float = GtFuelPlan.refuel_target_kg(float(race.laps - car.lap + 1), car.fuel_use)
	car.fuel = needed
	car.damage = 0.0
	race._driving.enter_pit_lane(car, Types.Compound.MEDIUM)
	var expected: float = GtTeamStats.pit_stop_time(car.team_id, race.race_seed, car.id * 16 + car.stops)
	check(is_equal_approx(car.pit.duration, expected), "a stop lasts the team's crew time (%.2f s vs %.2f s)" % [car.pit.duration, expected])
	var lap_s: float = track.length / 45.0
	check(GtStrategy.pit_loss_s(race, lap_s, fast) < GtStrategy.pit_loss_s(race, lap_s, slow), "the pit wall's loss estimate is smaller for the faster crew")
	var classic: float = GtStrategy.pit_loss_s(race, lap_s)
	check(is_equal_approx(classic, GtStrategy.pit_loss_s(race, lap_s, -1)), "no team given keeps the old constant stop time")
	var penalty: float = race.mandatory_penalty_s()
	check(penalty >= Types.MANDATORY_PENALTY_PIT_LOSS_MULT * GtStrategy.pit_loss_s(race, lap_s, slow), "the mandatory-stop penalty beats 1.5 losses of the slowest crew (%.1f s)" % penalty)
	race.dispose()
	ribbon.queue_free()
	await process_frame
	quit(1 if failures else 0)
