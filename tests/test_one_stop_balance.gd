extends SceneTree

## Fase 32 Task 7: with a mandatory stop the one-stop plans a team principal would really consider stay within a few
## seconds of each other at 10 and 15 laps, the best one changes with the race length, nothing beats stopping, and
## a heavy start does not beat a light one (or lose to it) by a margin that settles the choice.
## Run: godot --headless --path . -s res://tests/test_one_stop_balance.gd

const TrackScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const Types := preload("res://scripts/gt/gt_types.gd")

const DRY: int = WeatherScript.Archetype.DRY_SUNNY
const S := Types.Compound.SOFT
const M := Types.Compound.MEDIUM
const H := Types.Compound.HARD
## name, first tyre, second tyre, share of the distance at which the stop is called.
const PLANS: Array = [
	["SOFT>HARD @35", S, H, 0.35], ["MEDIUM>MEDIUM @45", M, M, 0.45], ["HARD>SOFT @55", H, S, 0.55],
	["SOFT>HARD @25 (early)", S, H, 0.25], ["HARD>SOFT @65 (late)", H, S, 0.65],
]
const MAX_SPREAD_S: float = 6.0
const NO_STOP_MARGIN_S: float = 5.0
const FUEL_CHOICE_MARGIN_S: float = 3.0

var failures: int = 0
var track: TrackScript


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ribbon: Node = TrackScene.instantiate()
	ribbon.road_half_width_m = 7.0
	root.add_child(ribbon)
	track = TrackScript.new(ribbon, 14.0)
	var best_plan: Dictionary = {}
	for laps: int in [10, 15]:
		var burn: float = GtData.FUEL_USE[0]
		var best: float = INF
		var worst: float = 0.0
		for plan: Array in PLANS:
			# Fuel for the stop plus the lap the pit entry takes plus a lap in hand.
			var fuel_kg: float = minf(Types.TANK_CAP_KG, (float(plan[3]) * float(laps) + 2.2) * burn)
			var time_s: float = _plan_time(laps, plan[1], plan[2], float(plan[3]), fuel_kg)
			print("  %d laps %-24s %.1f s" % [laps, plan[0], time_s])
			if time_s < best:
				best = time_s
				best_plan[laps] = plan[0]
			worst = maxf(worst, time_s)
		check(worst - best <= MAX_SPREAD_S, "%d laps: the five one-stop plans finish within %.0f s of each other (%.1f s)" % [laps, MAX_SPREAD_S, worst - best])
		var no_stop: float = _plan_time(laps, M, M, -1.0, 80.0)
		check(no_stop >= best + NO_STOP_MARGIN_S, "%d laps: never stopping is not profitable (%.1f s behind the best plan)" % [laps, no_stop - best])
		var heavy: float = _plan_time(laps, M, M, 0.45, minf(Types.TANK_CAP_KG, float(laps) * burn * 1.08))
		var light: float = _plan_time(laps, M, M, 0.45, (0.45 * float(laps) + 2.2) * burn)
		check(absf(heavy - light) < FUEL_CHOICE_MARGIN_S, "%d laps: a heavy and a light start are within %.0f s (heavy - light = %.1f s)" % [laps, FUEL_CHOICE_MARGIN_S, heavy - light])
	check(best_plan[10] != best_plan[15], "the best plan changes with the race length (%s at 10 laps, %s at 15)" % [best_plan[10], best_plan[15]])
	ribbon.queue_free()
	await process_frame
	quit(1 if failures else 0)


## A solo race: start on `first`, call a stop to `second` once `frac` of the distance is run (frac < 0: never stop),
## start on `fuel_kg`. Returns the classified time (flag time plus any penalty); 99999 for a car that retired.
func _plan_time(laps: int, first: int, second: int, frac: float, fuel_kg: float) -> float:
	var race := RaceScript.new(track, laps, 5, DRY, 1)
	race.incidents_enabled = false
	var car: GtCar = race.cars[0]
	car.compound = first
	car.fuel = fuel_kg
	var asked: bool = false
	var ticks: int = 0
	while not car.is_dnf and car.finished_at < 0.0 and ticks < 90000:
		if frac >= 0.0 and not asked and race.race_progress(car) >= frac:
			race.request_pit(car.id, second)
			asked = true
		race.step()
		ticks += 1
	var time_s: float = 99999.0 if car.is_dnf else race.classified_time(car)
	race.dispose()
	return time_s
