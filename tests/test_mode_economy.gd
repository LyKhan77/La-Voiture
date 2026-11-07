extends SceneTree

## Fase 32 Task 6: every deck option buys something and costs something. On a clean lap of a fresh MEDIUM solo car:
## fuel PUSH and ERS DEPLOY are worth real lap time, ATTACK is a short push (faster than AGGRESSIVE, no blow-out in
## two laps), and no pace or fuel option is dominated by STANDARD or dominates it.
## Run: godot --headless --path . -s res://tests/test_mode_economy.gd

const TrackScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const Types := preload("res://scripts/gt/gt_types.gd")

const DRY: int = WeatherScript.Archetype.DRY_SUNNY
const P := Types.PaceMode
const F := Types.FuelMode
const E := Types.ErsMode

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
	var std: Dictionary = _stint(P.STANDARD, F.STANDARD, E.NEUTRAL, 1)
	var aggressive: Dictionary = _stint(P.AGGRESSIVE, F.STANDARD, E.NEUTRAL, 1)
	var attack: Dictionary = _stint(P.ATTACK, F.STANDARD, E.NEUTRAL, 1)
	var push: Dictionary = _stint(P.STANDARD, F.PUSH, E.NEUTRAL, 1)
	var deploy: Dictionary = _stint(P.STANDARD, F.STANDARD, E.DEPLOY, 1)
	print("std %.2f s  aggressive %.2f  attack %.2f  push %.2f  deploy %.2f" % [std["lap_s"], aggressive["lap_s"], attack["lap_s"], push["lap_s"], deploy["lap_s"]])
	check(float(push["lap_s"]) <= float(std["lap_s"]) - 0.4, "fuel PUSH is at least 0.4 s a lap faster (%.2f s)" % (float(std["lap_s"]) - float(push["lap_s"])))
	check(float(push["fuel_kg"]) >= 1.2 * float(std["fuel_kg"]), "and burns at least 1.2 times the fuel")
	check(float(deploy["lap_s"]) <= float(std["lap_s"]) - 0.3, "ERS DEPLOY is at least 0.3 s a lap faster (%.2f s)" % (float(std["lap_s"]) - float(deploy["lap_s"])))
	var gain: float = float(std["lap_s"]) - float(aggressive["lap_s"])
	check(gain >= 0.7 and gain <= 1.2, "pace AGGRESSIVE stays 0.7 to 1.2 s a lap faster (%.2f s)" % gain)
	check(float(attack["lap_s"]) <= float(aggressive["lap_s"]) - 0.5, "pace ATTACK is at least 0.5 s a lap faster than AGGRESSIVE (%.2f s)" % (float(aggressive["lap_s"]) - float(attack["lap_s"])))
	var attack_two: Dictionary = _stint(P.ATTACK, F.STANDARD, E.NEUTRAL, 2)
	check(not bool(attack_two["punctured"]) and float(attack_two["wear"]) <= 0.85, "ATTACK survives two laps without a blow-out (wear %.2f)" % float(attack_two["wear"]))
	var cheap: Array = [[P.CONSERVE, F.STANDARD], [P.LIGHT, F.STANDARD], [P.STANDARD, F.CONSERVE]]
	for option: Array in cheap:
		var lap: Dictionary = _stint(option[0], option[1], E.NEUTRAL, 1)
		var cheaper: bool = float(lap["wear"]) < float(std["wear"]) or float(lap["fuel_kg"]) < float(std["fuel_kg"])
		check(float(lap["lap_s"]) > float(std["lap_s"]) and cheaper, "pace %s / fuel %s trades lap time for savings (%.2f s, wear %.4f, fuel %.2f kg)" % [Types.PACE_NAME[option[0]], Types.FUEL_NAME[option[1]], lap["lap_s"], lap["wear"], lap["fuel_kg"]])
	var options: Array = [
		[P.CONSERVE, F.STANDARD], [P.LIGHT, F.STANDARD], [P.AGGRESSIVE, F.STANDARD], [P.ATTACK, F.STANDARD],
		[P.STANDARD, F.CONSERVE], [P.STANDARD, F.PUSH],
	]
	for option: Array in options:
		var lap: Dictionary = _stint(option[0], option[1], E.NEUTRAL, 1)
		var dominated: bool = _no_worse(std, lap) and _differs(std, lap)
		var dominating: bool = _no_worse(lap, std) and _differs(lap, std)
		check(not dominated and not dominating, "pace %s / fuel %s is neither dominated by STANDARD nor dominates it" % [Types.PACE_NAME[option[0]], Types.FUEL_NAME[option[1]]])
	ribbon.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _no_worse(a: Dictionary, b: Dictionary) -> bool:
	return float(a["lap_s"]) <= float(b["lap_s"]) and float(a["wear"]) <= float(b["wear"]) and float(a["fuel_kg"]) <= float(b["fuel_kg"])


func _differs(a: Dictionary, b: Dictionary) -> bool:
	return float(a["lap_s"]) < float(b["lap_s"]) - 0.02 or float(a["wear"]) < float(b["wear"]) - 0.0005 or float(a["fuel_kg"]) < float(b["fuel_kg"]) - 0.02


## A solo fresh MEDIUM car on `laps` clean laps from the start of lap 1, full battery: seconds per lap, wear and fuel burned
## over them, and whether a tyre let go. The ERS mode is re-armed whenever the battery has charge.
func _stint(pace: int, fuel: int, ers: int, laps: int) -> Dictionary:
	var race := RaceScript.new(track, 6, 5, DRY, 1)
	race.incidents_enabled = false
	var car: GtCar = race.cars[0]
	car.compound = Types.Compound.MEDIUM
	car.pace_mode = pace
	car.fuel_mode = fuel
	var armed: bool = false
	var t0: float = 0.0
	var wear0: float = 0.0
	var fuel0: float = 0.0
	var out: Dictionary = {"lap_s": 999.0, "wear": 1.0, "fuel_kg": 99.0, "punctured": car.is_punctured}
	var ticks: int = 0
	while car.finished_at < 0.0 and not car.is_dnf and ticks < 40000:
		if car.lap == 1 and not armed:
			armed = true
			t0 = race.time
			wear0 = car.wear
			fuel0 = car.fuel
			car.ers_battery = 100.0
		if car.lap >= 1 and ers != E.NEUTRAL and car.ers_battery > 0.5:
			car.ers_mode = ers
		race.step()
		ticks += 1
		if armed and (car.is_punctured or car.lap >= 1 + laps):
			out = {"lap_s": (race.time - t0) / float(laps), "wear": car.wear - wear0, "fuel_kg": (fuel0 - car.fuel) / float(laps), "punctured": car.is_punctured}
			break
	race.dispose()
	return out
