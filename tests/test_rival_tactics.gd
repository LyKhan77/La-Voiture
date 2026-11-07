extends SceneTree

## Fase 32 Task 8: rivals and the AUTO desk choose pace, fuel and ERS with one function (GtStrategy.choose_modes);
## they differ only by a hash-seeded profile. Rivals use the whole deck, MANUAL player cars are left alone, no car
## is put on a mode its tyres cannot take, and a seed replays the same mode sequence.
## Run: godot --headless --path . -s res://tests/test_rival_tactics.gd

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
	_test_profiles()
	_test_parity_between_auto_and_rivals()
	_test_manual_player_is_left_alone()
	_test_never_a_mode_the_tyres_cannot_take()
	_test_attack_is_judged_with_the_heat_wear()
	_test_field_run_uses_the_deck()
	_test_seed_replays_the_same_sequence()
	ribbon.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _race(laps: int, seed_value: int = 5) -> RaceScript:
	var race := RaceScript.new(track, laps, seed_value, DRY, 20)
	race.incidents_enabled = false
	return race


## Puts `car` mid-race at `progress` with `wear`, and (when gap_ahead_s > 0) another car that many seconds ahead of it.
func _stage(race: RaceScript, car: GtCar, progress: float, wear: float, gap_ahead_s: float) -> void:
	for other: GtCar in race.cars:
		if other != car:
			other.is_dnf = true # parked: not a neighbour of anyone
			other.s = -500.0 - float(other.id) * 30.0
			other.prev_s = other.s
	car.s = progress * float(race.laps) * track.length
	car.prev_s = car.s
	car.lap = floori(car.s / track.length)
	car.v = 50.0
	car.wear = wear
	car.compound = Types.Compound.MEDIUM
	car.tyre_wear_rate = 1.0
	car.ers_battery = 100.0
	car.mandatory_stop_done = false
	if gap_ahead_s > 0.0:
		var ahead: GtCar = race.cars[1] if car != race.cars[1] else race.cars[2]
		ahead.is_dnf = false
		ahead.s = car.s + gap_ahead_s * car.v
		ahead.prev_s = ahead.s
		ahead.lap = floori(ahead.s / track.length)
		ahead.v = 50.0


func _test_profiles() -> void:
	var a: Dictionary = GtStrategy.tactic_profile(5, 3)
	var b: Dictionary = GtStrategy.tactic_profile(5, 3)
	var in_range: bool = true
	var distinct: Dictionary = {}
	for team: int in range(13):
		var tp: Dictionary = GtStrategy.tactic_profile(5, team)
		distinct[snappedf(float(tp["aggression"]), 0.001)] = true
		in_range = in_range and float(tp["aggression"]) >= 0.0 and float(tp["aggression"]) <= 1.0 and float(tp["fuel_save"]) >= 0.0 and float(tp["fuel_save"]) <= 1.0 \
				and float(tp["ers_greed"]) >= 0.0 and float(tp["ers_greed"]) <= 1.0 and float(tp["cover_gap_s"]) >= 1.0 and float(tp["cover_gap_s"]) <= 3.0 \
				and float(tp["stop_bias"]) >= -1.0 and float(tp["stop_bias"]) <= 1.0
	check(a == b, "a team's tactic profile is the same for the same seed")
	check(in_range, "every profile value is inside its range")
	check(distinct.size() > 6, "teams do not share one attitude (%d distinct aggressions of 13)" % distinct.size())
	check(GtStrategy.NEUTRAL_TACTIC["aggression"] == 0.5 and GtStrategy.NEUTRAL_TACTIC["cover_gap_s"] == 2.0, "the AUTO profile is the fixed neutral one")


func _test_parity_between_auto_and_rivals() -> void:
	var race: RaceScript = _race(10)
	var mine: GtCar = race.get_car(race.player_team_id * 2)
	var rival: GtCar = null
	for car: GtCar in race.cars:
		if car.team_id != race.player_team_id:
			rival = car
			break
	_stage(race, mine, 0.30, 0.70, 0.0)
	var expected: Dictionary = GtStrategy.choose_modes(race, mine, GtStrategy.NEUTRAL_TACTIC)
	check(int(expected["pace"]) == P.LIGHT, "worn tyres on a long stint ask for LIGHT pace")
	race.set_tactic_mode(Types.TacticMode.AUTO)
	race.decide_modes(mine)
	check(mine.pace_mode == int(expected["pace"]) and mine.fuel_mode == int(expected["fuel"]), "AUTO applies exactly what choose_modes says (pace %d, fuel %d)" % [mine.pace_mode, mine.fuel_mode])
	race.dispose()
	race = _race(10)
	rival = null
	for car: GtCar in race.cars:
		if car.team_id != race.player_team_id:
			rival = car
			break
	_stage(race, rival, 0.30, 0.70, 0.0)
	var neutral_choice: Dictionary = GtStrategy.choose_modes(race, rival, GtStrategy.NEUTRAL_TACTIC)
	check(int(neutral_choice["pace"]) == P.LIGHT, "a rival in the same state gets the same call from the same function")
	race.decide_modes(rival)
	check(rival.pace_mode == P.LIGHT, "a rival's modes are set by the sim, not left on STANDARD")
	race.dispose()


func _test_manual_player_is_left_alone() -> void:
	var race: RaceScript = _race(10)
	var mine: GtCar = race.get_car(race.player_team_id * 2)
	_stage(race, mine, 0.30, 0.70, 0.0)
	mine.pace_mode = P.AGGRESSIVE
	mine.fuel_mode = F.PUSH
	mine.ers_mode = E.HARVEST
	race.set_tactic_mode(Types.TacticMode.MANUAL)
	race.decide_modes(mine)
	check(mine.pace_mode == P.AGGRESSIVE and mine.fuel_mode == F.PUSH and mine.ers_mode == E.HARVEST, "a MANUAL player car keeps the modes the player set")
	race.dispose()


func _test_never_a_mode_the_tyres_cannot_take() -> void:
	var violations: int = 0
	var checked: int = 0
	var race: RaceScript = _race(10)
	var car: GtCar = race.cars[0]
	for progress: float in [0.1, 0.3, 0.5, 0.7, 0.9]:
		for wear: float in [0.0, 0.2, 0.4, 0.55, 0.7]:
			for aggression: float in [0.0, 0.6, 0.9]:
				for gap: float in [0.0, 0.8]:
					_stage(race, car, progress, wear, gap)
					var tp: Dictionary = GtStrategy.NEUTRAL_TACTIC.duplicate()
					tp["aggression"] = aggression
					var call: Dictionary = GtStrategy.choose_modes(race, car, tp)
					var stint: float = GtStrategy.stint_laps_left(race, car)
					var left: float = GtForecast.laps_left(race, car)
					checked += 1
					if int(call["pace"]) == P.AGGRESSIVE and GtStrategy.tyre_life_at_finish(car, P.AGGRESSIVE, stint) < GtForecast.TYRE_WATCH_LIFE:
						violations += 1
					if int(call["pace"]) == P.ATTACK and GtStrategy.tyre_life_at_finish(car, P.ATTACK, left) < GtForecast.TYRE_DANGER_LIFE:
						violations += 1
	check(violations == 0, "no state puts a car on AGGRESSIVE or ATTACK its tyres cannot take (%d of %d states)" % [violations, checked])
	race.dispose()


## ATTACK and AGGRESSIVE run the tyres hot (x1.4 wear past 112 C): the deck's table forecast is not enough to send a worn
## MEDIUM into the last two laps on ATTACK (the table says 18 % life left, the heat makes it 5 %).
func _test_attack_is_judged_with_the_heat_wear() -> void:
	var race: RaceScript = _race(10)
	var car: GtCar = race.cars[0]
	_stage(race, car, 0.85, 0.55, 0.0)
	var tp: Dictionary = GtStrategy.NEUTRAL_TACTIC.duplicate()
	tp["aggression"] = 0.9
	var left: float = GtForecast.laps_left(race, car)
	check(GtForecast.tyre_life_at_finish(car, P.ATTACK, left) >= GtForecast.TYRE_DANGER_LIFE, "the deck's table forecast alone would allow ATTACK here")
	check(GtStrategy.tyre_life_at_finish(car, P.ATTACK, left) < GtForecast.TYRE_DANGER_LIFE, "the heat-corrected life is under the danger line")
	check(int(GtStrategy.choose_modes(race, car, tp)["pace"]) != P.ATTACK, "so the chooser does not send this car out on ATTACK")
	_stage(race, car, 0.85, 0.25, 0.0)
	check(int(GtStrategy.choose_modes(race, car, tp)["pace"]) == P.ATTACK, "a car with fresh tyres still gets ATTACK for the last two laps")
	race.dispose()


## Collects every (pace, fuel) pair the rivals have run and whether any retired for fuel, over a 6 lap dry race.
func _field_log(seed_value: int) -> Dictionary:
	var race: RaceScript = _race(6, seed_value)
	var pairs: Dictionary = {}
	var trace: Array[String] = []
	var ticks: int = 0
	while not race.is_finished() and ticks < 60000:
		race.step()
		ticks += 1
		for car: GtCar in race.cars:
			if car.team_id == race.player_team_id:
				continue
			pairs["%d/%d" % [car.pace_mode, car.fuel_mode]] = true
			if ticks % 100 == 0:
				trace.append("%d:%d:%d:%d:%d" % [car.id, car.pace_mode, car.fuel_mode, car.ers_mode, floori(car.s)])
	var dry: int = 0
	for car: GtCar in race.cars:
		if car.is_dnf and car.dnf_reason == "Out of Fuel":
			dry += 1
	var out: Dictionary = {"pairs": pairs.size(), "dry": dry, "trace_hash": hash("|".join(trace)), "order": ",".join(race.standings().map(func(c: GtCar) -> String: return str(c.id)))}
	race.dispose()
	return out


func _test_field_run_uses_the_deck() -> void:
	var log: Dictionary = _field_log(5)
	check(int(log["pairs"]) >= 3, "rivals use at least three different pace/fuel combinations over a race (%d)" % int(log["pairs"]))
	check(int(log["dry"]) == 0, "no rival runs out of fuel in a race it was loaded for")


func _test_seed_replays_the_same_sequence() -> void:
	var first: Dictionary = _field_log(9)
	var second: Dictionary = _field_log(9)
	check(first["trace_hash"] == second["trace_hash"] and first["order"] == second["order"], "the same seed replays the same mode sequence and finishing order")
