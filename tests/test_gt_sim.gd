extends SceneTree

## FASE 5.6 acceptance: the GT sim (GDScript port of gt-manager `race.ts`) on the 3D
## ribbon. Run: Godot --headless --path . -s res://tests/test_gt_sim.gd

const TrackScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const RibbonScript := preload("res://scripts/car/track_ribbon.gd")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const CarScript := preload("res://scripts/gt/gt_car.gd")
const DataScript := preload("res://scripts/gt/gt_data.gd")
const RngScript := preload("res://scripts/gt/gt_rng.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const PitLaneScript := preload("res://scripts/world/circuits/apex_ring/apex_pit_complex.gd")

const DRY: int = WeatherScript.Archetype.DRY_SUNNY

var failures: int = 0
var assertions: int = 0
var ribbon: RibbonScript
var track: TrackScript


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	ribbon = TrackScene.instantiate()
	ribbon.road_half_width_m = 7.0
	root.add_child(ribbon)
	track = TrackScript.new(ribbon, 14.0)
	_test_rng_and_data()
	_test_track()
	_test_weather()
	_test_full_race()
	_test_determinism()
	_test_contacts_and_racecraft()
	_test_race_control()
	_test_power_and_aero()
	_test_tyres_and_fuel()
	_test_pit_lane()
	_test_tactics()
	_test_chassis_and_telemetry()
	ribbon.queue_free()
	await process_frame
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 5.6 GT SIM: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


# --- helpers -----------------------------------------------------------------------

## A field without random incidents, so a scenario only sees what it sets up.
func _quiet_race(laps: int = 10, seed_value: int = 5, weather: int = DRY) -> RaceScript:
	var race := RaceScript.new(track, laps, seed_value, weather)
	race.incidents_enabled = false
	return race


## Moves every car but `keep` far behind the grid so it cannot interfere.
func _park_others(race: RaceScript, keep: Array) -> void:
	for index: int in range(race.cars.size()):
		if not keep.has(race.cars[index]):
			race.cars[index].s = -400.0 - float(index) * 30.0
			race.cars[index].prev_s = race.cars[index].s


func _place(car: CarScript, s: float, v: float, lateral: float, lap: int = 1) -> void:
	car.s = s
	car.prev_s = s
	car.v = v
	car.lateral = lateral
	car.prev_lateral = lateral
	car.target_lateral = lateral
	car.lap = lap


func _free(race: RaceScript) -> void:
	race.dispose()


# --- rng, data, track ------------------------------------------------------------

func _test_rng_and_data() -> void:
	var a := RngScript.new(7)
	var b := RngScript.new(7)
	var c := RngScript.new(8)
	var same: bool = true
	var differs: bool = false
	var in_range: bool = true
	for _i: int in range(200):
		var x: float = a.next()
		same = same and x == b.next()
		differs = differs or x != c.next()
		in_range = in_range and x >= 0.0 and x < 1.0
	check(same and differs and in_range, "rng: same seed gives the same stream, another seed differs, values stay in [0, 1)")
	var codes: Dictionary = {}
	var cars: Array[CarScript] = []
	for slot: int in range(20):
		var car := CarScript.new()
		DataScript.apply_entry(car, slot)
		cars.append(car)
		codes[car.code] = true
	check(cars.size() == 20 and codes.size() == 20 and cars[0].team_id == 0 and cars[19].team_id == 9 and cars[4].team_name == "Kurogane GT",
		"data: 20 cars in 10 teams, unique broadcast codes, La Voiture team names")


func _test_track() -> void:
	var a: Transform3D = track.point_at(10.0)
	var b: Transform3D = track.point_at(10.0 + track.length)
	check(track.length > 3500.0 and track.length < 4500.0 and a.origin.distance_to(b.origin) < 1.0e-3,
		"track: ~4.2 km loop (%.0f m) and distance wraps" % track.length)
	var avg: float = track.average_speed()
	var tightest: float = INF
	var fastest: float = 0.0
	var s: float = 0.0
	var ideal_ok: bool = true
	while s < track.length:
		tightest = minf(tightest, track.speed_limit_at(s))
		fastest = maxf(fastest, track.speed_limit_at(s))
		ideal_ok = ideal_ok and absf(track.ideal_lateral_at(s)) <= 3.2 + 1.0e-6
		s += 5.0
	check(avg > 30.0 and avg < 76.0 and tightest < 35.0 and fastest > 70.0,
		"track: speed profile averages %.1f m/s, slowest %.1f m/s in the hairpin, fastest %.1f m/s" % [avg, tightest, fastest])
	check(ideal_ok and is_equal_approx(track.clamp_to_width(99.0), 5.4) and is_equal_approx(track.clamp_to_width(-99.0), -5.4),
		"track: racing line within +-3.2 m, lateral clamps to the usable 5.4 m")
	check(track.drs_zones.size() == 2 and not track.drs_zone_at(500.0).is_empty() and track.drs_zone_at(2000.0).is_empty(),
		"track: two DRS zones, one on the start straight")


# --- weather ------------------------------------------------------------------------

func _test_weather() -> void:
	var wet := RaceScript.new(track, 10, 4)
	var dry := RaceScript.new(track, 10, 7)
	var wet_tyres: bool = true
	for car: CarScript in wet.cars:
		wet_tyres = wet_tyres and (car.compound == Types.Compound.INTERMEDIATE or car.compound == Types.Compound.WET)
	var slicks: bool = true
	for car: CarScript in dry.cars:
		slicks = slicks and Types.is_slick(car.compound)
	check(wet.weather.archetype == WeatherScript.Archetype.WET_DRYING and wet.weather.track_water_pct > 25.0 and wet_tyres
		and dry.weather.archetype == WeatherScript.Archetype.DRY_SUNNY and dry.weather.track_water_pct == 0.0 and slicks
		and wet.weather.forecast.size() == 15,
		"weather: seed picks the archetype, a wet grid starts on intermediates / wets, a dry one on slicks, forecast has laps + 5 entries")
	var water_before: float = wet.weather.track_water_pct
	wet.step_ticks(20 * 25)
	check(not is_nan(wet.weather.track_temp) and not is_nan(wet.weather.air_temp) and wet.weather.track_water_pct != water_before and wet.weather.condition_label != "",
		"weather: water, temperatures and the condition label evolve during the race (%.0f%% -> %.0f%% water)" % [water_before, wet.weather.track_water_pct])
	var kinds: Dictionary = {}
	for archetype: int in range(7):
		var w := WeatherScript.new(10, 3, archetype)
		kinds[w.archetype] = w.forecast.size()
	var storm := WeatherScript.new(10, 3, WeatherScript.Archetype.DRY_TO_STORM)
	var peak_rain: float = 0.0
	for point: Dictionary in storm.forecast:
		peak_rain = maxf(peak_rain, point["rain_intensity"])
	check(kinds.size() == 7 and peak_rain > 0.4 and wet.weather.time_of_day["sun_altitude"] > 0.0,
		"weather: all 7 archetypes build, the storm archetype peaks at %.2f rain, time of day is set" % peak_rain)
	wet.dispose()
	dry.dispose()


# --- a full race: pace, lanes, lap times --------------------------------------------

func _test_full_race() -> void:
	var race := RaceScript.new(track, 3, 3, DRY)
	var ticks: int = 0
	var overlap_ticks: int = 0
	var sbs: Dictionary = {}
	var longest_pair: int = 0
	var abreast3: int = 0
	var longest_abreast3: int = 0
	var max_speed: float = 0.0
	var nan_found: bool = false
	while not race.is_finished() and ticks < 20 * 60 * 15:
		race.step()
		ticks += 1
		var racing: Array[CarScript] = []
		for car: CarScript in race.cars:
			if car.is_racing():
				racing.append(car)
			max_speed = maxf(max_speed, car.v)
			nan_found = nan_found or is_nan(car.s) or is_nan(car.v) or is_nan(car.lateral)
		var any_three: bool = false
		for i: int in range(racing.size()):
			var near: int = 1
			for j: int in range(racing.size()):
				if i == j:
					continue
				var ds: float = absf(race.contacts.signed_gap(racing[i].s, racing[j].s, track.length))
				var dl: float = absf(racing[i].lateral - racing[j].lateral)
				if ds < Types.CAR_LENGTH_M - 0.2 and dl < Types.CAR_WIDTH_M - 0.2:
					overlap_ticks += 1
				if ds < 3.0 and dl < 3.6 and racing[i].v > 20.0:
					near += 1
					if j > i:
						var key: int = racing[i].id * 100 + racing[j].id
						sbs[key] = int(sbs.get(key, 0)) + 1
						longest_pair = maxi(longest_pair, int(sbs[key]))
				elif j > i:
					sbs[racing[i].id * 100 + racing[j].id] = 0
			if near >= 3:
				any_three = true
		abreast3 = abreast3 + 1 if any_three else 0
		longest_abreast3 = maxi(longest_abreast3, abreast3)
	var best: float = INF
	var worst: float = 0.0
	var all_finished: bool = true
	var wear_ok: bool = true
	for car: CarScript in race.cars:
		all_finished = all_finished and car.finished_at >= 0.0
		wear_ok = wear_ok and car.wear >= 0.0 and car.wear <= 1.0
		if car.best_lap > 0.0:
			best = minf(best, car.best_lap)
			worst = maxf(worst, car.best_lap)
	check(race.is_finished() and all_finished and not nan_found and wear_ok,
		"race: a 3 lap race finishes for all 20 cars with no NaN and wear in 0..1 (%d ticks)" % ticks)
	check(best > 60.0 and worst < 105.0 and worst - best > 0.5,
		"pace: best laps run %.1f s to %.1f s on %.2f km (avg %.0f km/h), cars differ by team" % [best, worst, track.length / 1000.0, track.length / best * 3.6])
	check(max_speed > 65.0 and max_speed < 90.0,
		"pace: top speed in the race %.0f km/h" % (max_speed * 3.6))
	check(overlap_ticks == 0,
		"contact: no two car boxes overlap by more than 0.2 m in %d ticks (%d pair-ticks)" % [ticks, overlap_ticks])
	check(float(longest_pair) * Types.TICK_DT < 6.0 and float(longest_abreast3) * Types.TICK_DT < 3.0,
		"lanes: longest side-by-side pair %.1f s, longest three abreast %.1f s (no stacked rows)" % [
			float(longest_pair) * Types.TICK_DT, float(longest_abreast3) * Types.TICK_DT
		])
	_free(race)


func _test_determinism() -> void:
	var a: Array[String] = _run_signature(7)
	var b: Array[String] = _run_signature(7)
	var c: Array[String] = _run_signature(8)
	check(a == b and a != c, "determinism: the same seed gives the same race, another seed a different one")


func _run_signature(seed_value: int) -> Array[String]:
	var race := RaceScript.new(track, 1, seed_value, DRY)
	var guard: int = 0
	while not race.is_finished() and guard < 20 * 400:
		race.step()
		guard += 1
	var result: Array[String] = []
	for car: CarScript in race.standings():
		result.append("%d:%.3f" % [car.id, car.finished_at])
	race.dispose()
	return result


# --- contacts and racecraft ---------------------------------------------------------

func _test_contacts_and_racecraft() -> void:
	# Contact pushes overlapping cars apart.
	var race := _quiet_race()
	var a: CarScript = race.cars[0]
	var b: CarScript = race.cars[1]
	_park_others(race, [a, b])
	_place(a, 300.0, 45.0, 0.5)
	_place(b, 301.0, 45.0, 0.6)
	var before: float = absf(a.lateral - b.lateral)
	race.step()
	check(absf(a.lateral - b.lateral) > before and a.impact_jolt > 0.0 and b.impact_jolt > 0.0,
		"contact: overlapping cars are pushed apart laterally (%.2f -> %.2f m) with an impact jolt" % [before, absf(a.lateral - b.lateral)])
	_free(race)

	# The 190 pairs are all looked at.
	race = _quiet_race()
	for car: CarScript in race.cars:
		_place(car, 100.0 + float(car.position) * 30.0, 40.0, float(car.position % 3 - 1) * 2.5, 1)
	race.step()
	check(race.cars.size() == 20 and race.contacts.pairs_checked_last == 190,
		"contact: all 190 pairs of the 20 cars are checked each tick (%d)" % race.contacts.pairs_checked_last)
	_free(race)

	# A lapped car and its leader on the same piece of track still collide.
	race = _quiet_race()
	a = race.cars[0]
	b = race.cars[race.cars.size() - 1]
	_park_others(race, [a, b])
	_place(a, track.length + 400.0, 45.0, 0.2, 2)
	_place(b, 401.0, 42.0, 0.3, 1)
	before = absf(a.lateral - b.lateral)
	race.step()
	check(absf(a.lateral - b.lateral) > before and a.impact_jolt > 0.0,
		"contact: the cyclic distance catches cars a lap apart that share the same road")
	_free(race)

	# Equal cars side by side do not stay locked.
	race = _quiet_race(10, 21)
	a = race.cars[0]
	b = race.cars[1]
	_park_others(race, [a, b])
	b.top_speed = a.top_speed
	b.grip = a.grip
	b.skill = a.skill
	b.compound = a.compound
	_place(a, 500.0, 50.0, -0.3)
	_place(b, 500.05, 50.0, 0.3)
	var kept_apart: bool = true
	for step_index: int in range(70):
		race.step()
		if step_index == 4 and absf(a.s - b.s) < 4.2:
			kept_apart = kept_apart and absf(a.target_lateral - b.target_lateral) >= 2.0
	check(kept_apart and absf(a.s - b.s) > 2.0,
		"racecraft: equal cars side by side do not steer back into each other and one pulls ahead (%.1f m)" % absf(a.s - b.s))
	_free(race)

	# Racing room: alongside without a pass called, the targets are 2.1 m apart.
	race = _quiet_race(10, 22)
	a = race.cars[0]
	b = race.cars[1]
	_park_others(race, [a, b])
	_place(a, 420.0, 48.0, -1.2)
	_place(b, 419.2, 48.0, 1.2)
	race.step()
	check(absf(a.target_lateral - b.target_lateral) >= 2.1,
		"racecraft: alongside, both cars leave racing room (targets %.2f m apart)" % absf(a.target_lateral - b.target_lateral))
	_free(race)

	# One-move defending: a faster car closing from behind gets one defensive line.
	race = _quiet_race(10, 23)
	a = race.cars[0]
	b = race.cars[1]
	_park_others(race, [a, b])
	_place(a, 300.0, 50.0, 0.0)
	_place(b, 290.0, 56.0, 0.0)
	race.step()
	var first_timer: float = a.defend_timer
	var first_target: float = a.defend_target_lateral
	for _i: int in range(10):
		race.step()
	check(first_timer > 3.0 and a.overtake_phase == Types.Overtake.DEFENDING and is_equal_approx(a.defend_target_lateral, first_target),
		"racecraft: the car being caught commits to ONE defensive line (%.2f m) and holds it" % first_target)
	_free(race)

	# Blue flag: the lapped car moves off the line and eases off.
	race = _quiet_race(10, 24)
	a = race.cars[0]
	b = race.cars[1]
	_park_others(race, [a, b])
	_place(a, 800.0, 60.0, 0.0, 1) # lapped car
	_place(b, 800.0 + track.length - 10.0, 62.0, 0.0, 2) # leader a lap up, 10 m behind it on track
	for _i: int in range(40):
		race.step()
	check(a.overtake_phase == Types.Overtake.YIELDING and absf(a.target_lateral) > 2.0,
		"racecraft: a lapped car with the leader 10 m behind yields off the racing line (target %.1f m)" % a.target_lateral)
	_free(race)


# --- race control ---------------------------------------------------------------------

func _test_race_control() -> void:
	var race := _quiet_race(10, 12)
	var car: CarScript = race.cars[0]
	_park_others(race, [car])
	_place(car, 600.0, 50.0, 0.0)
	race.step()
	var normal: float = car.v
	race.set_flag(Types.Flag.SC, 1, "SAFETY CAR DEPLOYED", 20.0)
	for _i: int in range(120):
		race.step()
	check(normal > 45.0 and car.v <= 32.0 and car.v < normal,
		"flags: the safety car caps the field at about 110 km/h (%.0f -> %.0f km/h)" % [normal * 3.6, car.v * 3.6])
	_free(race)

	race = _quiet_race(10, 24)
	race.set_flag(Types.Flag.SC, 2, "SAFETY CAR DEPLOYED", 30.0)
	race.set_flag(Types.Flag.YELLOW, 1, "YELLOW FLAG SEC 1", 12.0)
	var lead: CarScript = race.cars[0]
	var trailing: CarScript = race.cars[1]
	_park_others(race, [lead, trailing])
	_place(lead, 600.0, 25.0, 0.0)
	_place(trailing, 590.0, 31.0, 0.0)
	for _i: int in range(40):
		race.step()
	check(int(race.race_control["flag"]) == Types.Flag.SC and trailing.pass_timer == 0.0 and trailing.overtake_phase != Types.Overtake.ATTACKING,
		"flags: a yellow cannot downgrade an active safety car, and nobody overtakes under caution")
	_free(race)

	race = _quiet_race(10, 28)
	var leader: CarScript = race.cars[0]
	var p2: CarScript = race.cars[1]
	_park_others(race, [leader, p2])
	_place(leader, 900.0, 68.0, 0.0)
	_place(p2, 860.0, 70.0, 0.0)
	race.set_flag(Types.Flag.SC, 2, "SAFETY CAR DEPLOYED", 25.0)
	var passed_sc: bool = false
	for _i: int in range(200):
		race.step()
		passed_sc = passed_sc or leader.s >= float(race.safety_car["s"])
	check(bool(race.safety_car["active"]) and bool(race.safety_car["lights_on"]) and not passed_sc and leader.s - p2.s < 25.0 and absf(leader.target_lateral) < 1.8,
		"flags: a physical safety car leads, the leader never passes it and the field bunches single file (%.0f m gap)" % (leader.s - p2.s))
	_free(race)

	race = _quiet_race(10, 25)
	car = race.cars[0]
	_park_others(race, [car])
	_place(car, 800.0, 50.0, 0.0)
	car.damage = 96.0
	race.step()
	var retired: bool = car.is_dnf and not car.dnf_reason.is_empty() and not car.is_cleared
	race.step_ticks(20 * 30)
	check(retired and car.is_cleared, "incidents: terminal damage retires a car and the marshals clear it after 24 s")
	_free(race)

	race = _quiet_race(6, 8)
	var running: CarScript = race.cars[0]
	var crashed: CarScript = race.cars[1]
	running.s = 2000.0
	crashed.s = 2200.0
	crashed.is_dnf = true
	crashed.dnf_reason = "Barrier Impact"
	crashed.finished_at = race.time
	var order: Array[CarScript] = race.standings()
	check(order[0] != crashed and order[order.size() - 1] == crashed,
		"standings: retired cars are ranked at the bottom (FIA)")
	_free(race)


# --- DRS, ERS, slipstream ---------------------------------------------------------------

func _test_power_and_aero() -> void:
	var race := _quiet_race(5, 42)
	var disabled_lap_1: bool = not bool(race.race_control["drs_enabled"])
	var guard: int = 0
	while race.cars[0].lap < 1 and guard < 20 * 150:
		race.step()
		guard += 1
	var enabled_lap_2: bool = bool(race.race_control["drs_enabled"])
	_free(race)
	race = _quiet_race(5, 42)
	race.weather.track_water_pct = 60.0
	race.cars[0].lap = 1
	race.step()
	var wet_disabled: bool = not bool(race.race_control["drs_enabled"])
	_free(race)
	check(disabled_lap_1 and enabled_lap_2 and wet_disabled, "drs: off on lap 1, enabled from lap 2 on a dry green track, disabled when the track is wet")

	# Detection: gap under 1 s at the detection line makes a car eligible, brakes close the flap.
	race = _quiet_race(5, 42)
	race.race_control["drs_enabled"] = true
	var zone: Dictionary = track.drs_zones[0]
	var detection: float = zone["detection_s"]
	var leader: CarScript = race.cars[0]
	var chaser: CarScript = race.cars[1]
	_park_others(race, [leader, chaser])
	_place(leader, detection + 15.0, 50.0, 0.0)
	_place(chaser, detection - 1.0, 50.0, 0.0)
	race.step()
	var eligible: bool = chaser.drs_eligible
	_place(chaser, float(zone["start_s"]) + 400.0, 50.0, 0.0)
	chaser.drs_eligible = true
	chaser.brake = 0.0
	race.step()
	var opened: bool = chaser.drs_active
	chaser.brake = 0.3
	chaser.v = 80.0
	race.step()
	check(eligible and opened and not chaser.drs_active,
		"drs: gap < 1 s at the detection line makes a car eligible, the flap opens in the zone and snaps shut on the brakes")
	_free(race)

	# Slipstream behind a car on a straight.
	race = _quiet_race(5, 3)
	leader = race.cars[0]
	chaser = race.cars[1]
	_park_others(race, [leader, chaser])
	_place(leader, 300.0, 60.0, 0.0)
	_place(chaser, 290.0, 60.0, 0.0)
	race.step()
	check(chaser.slipstream_factor > 0.3, "slipstream: a car 10 m behind another on the straight gets a tow (%.2f)" % chaser.slipstream_factor)
	_free(race)

	# ERS overtake adds speed.
	race = _quiet_race(5, 3)
	leader = race.cars[0]
	_park_others(race, [leader])
	_place(leader, 200.0, 70.0, 0.0)
	leader.ers_mode = Types.ErsMode.NEUTRAL
	for _i: int in range(10):
		race.step()
	var neutral_speed: float = leader.v
	_place(leader, 200.0, 70.0, 0.0)
	leader.ers_mode = Types.ErsMode.OVERTAKE
	leader.ers_battery = 100.0
	for _i: int in range(10):
		race.step()
	check(leader.v >= neutral_speed and leader.ers_battery < 100.0,
		"ers: overtake mode drains the battery and never lowers the speed (%.1f vs %.1f m/s)" % [leader.v, neutral_speed])
	_free(race)


# --- tyres and fuel -------------------------------------------------------------------------

func _test_tyres_and_fuel() -> void:
	var race := _quiet_race(10, 101)
	var car: CarScript = race.cars[0]
	_park_others(race, [car])
	race.step_ticks(20)
	var full_tank: bool = car.fuel_stage == Types.FuelStage.OPTIMAL
	car.fuel = 2.5
	race.step()
	var warning: bool = car.fuel_stage == Types.FuelStage.WARNING
	car.fuel = 0.3
	race.step_ticks(60)
	var limp: bool = car.fuel_stage == Types.FuelStage.LIMP and car.v <= 21.0
	car.fuel = 0.0
	race.step()
	var flameout: bool = car.fuel_stage == Types.FuelStage.FLAMEOUT and car.is_dnf and car.dnf_reason == "Out of Fuel"
	race.step_ticks(120)
	check(full_tank and warning and limp and flameout and car.v <= 0.1,
		"fuel: OPTIMAL, warning below 3 kg, ECU limp at 20 m/s below 0.4 kg, flameout DNF at 0 and the car rolls to a stop")
	_free(race)

	race = _quiet_race(10, 202)
	car = race.cars[0]
	_park_others(race, [car])
	race.step_ticks(40)
	car.wear = 0.70
	var grip_before: float = race._driving.tyre_factor(car)
	car.wear = 0.85
	var grip_after: float = race._driving.tyre_factor(car)
	car.wear = 0.96
	race.step()
	var punctured: bool = car.is_punctured and car.punctured_wheel >= 0
	race.step_ticks(100)
	var limp_speed: bool = car.v <= 16.0
	car.wear = 0.5 # keep the pace at the limp cap for the long drive
	car.team_id = race.player_team_id
	race.set_tactic_mode(Types.TacticMode.MANUAL)
	var guard: int = 0
	while not car.is_dnf and guard < 20 * 400:
		car.pit_request = -1
		race.step()
		guard += 1
	check(grip_after < grip_before and punctured and limp_speed and car.is_dnf and car.dnf_reason == "Suspension Failure",
		"tyres: grip falls off the cliff past 75 %% wear, a worn tyre bursts, the car limps at 55 km/h and fails after a lap")
	_free(race)


# --- pit lane ----------------------------------------------------------------------------------

func _test_pit_lane() -> void:
	var entry: float = PitLaneScript.ENTRY_S
	var race := _quiet_race(10, 26)
	var car: CarScript = race.cars[0]
	_park_others(race, [car])
	_place(car, entry - 250.0 + track.length, 45.0, 5.2)
	car.wear = 0.4
	race.request_pit(car.id, Types.Compound.MEDIUM)
	var max_lane_speed: float = 0.0
	var saw_swap: bool = false
	var saw_lift: bool = false
	var box_gap: float = INF
	var guard: int = 0
	while guard < 20 * 120 and not (car.stops >= 1 and car.pit == null):
		race.step()
		guard += 1
		if car.pit != null:
			if car.s - car.pit.start_s >= 0.0:
				max_lane_speed = maxf(max_lane_speed, car.v)
			if car.pit.phase == Types.PitPhase.BOX and car.pit.wheel_swap_progress > 0.2 and car.pit.wheel_swap_progress < 0.8:
				saw_swap = true
				box_gap = minf(box_gap, absf(car.s - car.pit.box_s))
			saw_lift = saw_lift or car.pit.lift_y >= 0.14
	check(car.stops == 1 and car.compound == Types.Compound.MEDIUM and car.wear < 0.02 and saw_swap and saw_lift and box_gap < 1.0,
		"pit: the boxed car stops on its stall (%.2f m), lifts 15 cm, swaps to MEDIUM and leaves on fresh tyres" % box_gap)
	check(max_lane_speed <= Types.PIT_SPEED + 0.6,
		"pit: the limiter holds the lane at 80 km/h (peak %.1f m/s)" % max_lane_speed)
	_free(race)

	# Damage repair lengthens the stop and is fixed after it.
	race = _quiet_race(8, 7)
	car = race.cars[0]
	_park_others(race, [car])
	_place(car, entry - 100.0 + track.length, 40.0, 0.0)
	car.damage = 30.0
	race._driving.begin_pit_stop(car, Types.Compound.HARD)
	var duration: float = car.pit.duration
	guard = 0
	while guard < 20 * 120 and not (car.stops >= 1 and car.pit == null):
		race.step()
		guard += 1
	check(duration > Types.PIT_STOP_TIME and car.damage == 0.0 and car.stops == 1 and car.fuel > 20.0,
		"pit: a damaged car gets a longer stop (%.1f s), the wing is replaced and the tank is filled" % duration)
	_free(race)

	# Two teammates: the second waits behind the stall until the first leaves.
	race = _quiet_race(10, 27)
	var car_a: CarScript = race.cars[0]
	var car_b: CarScript = null
	for other: CarScript in race.cars:
		if other != car_a and other.team_id == car_a.team_id:
			car_b = other
	_park_others(race, [car_a, car_b])
	_place(car_a, entry - 118.0 + track.length, 35.0, -3.0)
	_place(car_b, entry - 131.0 + track.length, 35.0, -3.0)
	car_a.damage = 25.0
	race.request_pit(car_a.id, Types.Compound.HARD)
	race.request_pit(car_b.id, Types.Compound.MEDIUM)
	var min_gap: float = INF
	var queued: bool = false
	var a_done_at: float = -1.0
	var b_done_at: float = -1.0
	guard = 0
	while guard < 20 * 150 and not (car_a.stops >= 1 and car_b.stops >= 1 and car_a.pit == null and car_b.pit == null):
		race.step()
		guard += 1
		if car_a.pit != null and car_b.pit != null:
			min_gap = minf(min_gap, absf(car_a.s - car_b.s))
			if car_b.v < 1.0 and car_a.pit.phase == Types.PitPhase.BOX and car_b.s < car_a.pit.box_s - 5.0:
				queued = true
		if car_a.stops >= 1 and a_done_at < 0.0:
			a_done_at = race.time
		if car_b.stops >= 1 and b_done_at < 0.0:
			b_done_at = race.time
	check(queued and min_gap >= 5.5 and car_a.stops == 1 and car_b.stops == 1 and b_done_at > a_done_at and car_a.damage == 0.0,
		"pit: the second teammate queues behind the stall (closest %.1f m) and is serviced after the first" % min_gap)
	_free(race)


# --- tactics -----------------------------------------------------------------------------------------

func _player_of(race: RaceScript) -> CarScript:
	for car: CarScript in race.cars:
		if car.team_id == race.player_team_id:
			return car
	return null


func _test_tactics() -> void:
	var race := _quiet_race(10, 31)
	var player: CarScript = _player_of(race)
	_park_others(race, [player])
	_place(player, 400.0, 50.0, 0.0)
	race.set_tactic_mode(Types.TacticMode.MANUAL)
	player.wear = 0.7
	race.step()
	var offered: bool = not race.latest_suggestion.is_empty() and int(race.latest_suggestion["type"]) == Types.TacticType.PIT
	race.accept_suggestion()
	var accepted: bool = player.pit_request >= 0 and race.latest_suggestion.is_empty()
	_free(race)

	race = _quiet_race(10, 31)
	player = _player_of(race)
	_park_others(race, [player])
	_place(player, 400.0, 50.0, 0.0)
	player.wear = 0.7
	race.set_tactic_mode(Types.TacticMode.AUTO)
	race.decide_strategy(player)
	var auto_card: bool = not race.latest_suggestion.is_empty() and player.pit_request < 0
	race.time += RaceScript.SUGGESTION_WINDOW_S + 0.1
	race.step()
	var auto_calls: bool = player.pit_request >= 0 and race.latest_suggestion.is_empty()
	check(offered and accepted and auto_card and auto_calls,
		"tactics: MANUAL and AUTO both raise a BOX card at 70 %% wear; accept calls the stop; AUTO calls it itself when the 10 s window ends")
	race.set_pace_mode(player.id, Types.PaceMode.ATTACK)
	race.set_fuel_mode(player.id, Types.FuelMode.PUSH)
	race.set_ers_mode(player.id, Types.ErsMode.HARVEST)
	check(player.pace_mode == Types.PaceMode.ATTACK and player.fuel_mode == Types.FuelMode.PUSH and player.ers_mode == Types.ErsMode.HARVEST,
		"tactics: pace (5 levels), fuel mix (3) and ERS (4) can be set per car")
	_free(race)


# --- chassis angles and telemetry -------------------------------------------------------------------------

func _test_chassis_and_telemetry() -> void:
	var race := RaceScript.new(track, 4, 42, DRY)
	race.incidents_enabled = false
	var saw_right: bool = false
	var saw_left: bool = false
	var steer_hits: int = 0
	var steer_samples: int = 0
	var roll_hits: int = 0
	var roll_samples: int = 0
	var pitch_brake_hits: int = 0
	var pitch_brake_samples: int = 0
	var pitch_power_hits: int = 0
	var pitch_power_samples: int = 0
	var finite_ok: bool = true
	for _tick: int in range(20 * 130):
		race.step()
		for car: CarScript in race.cars:
			if car.v > 25.0:
				var curv: float = track.curvature_at(car.s)
				if absf(curv) > 0.006:
					saw_right = saw_right or curv > 0.0
					saw_left = saw_left or curv < 0.0
					steer_samples += 1
					steer_hits += 1 if signf(car.steer_angle) == signf(curv) else 0
					roll_samples += 1
					roll_hits += 1 if signf(car.chassis_roll) == signf(curv) else 0
				if car.brake > 0.6:
					pitch_brake_samples += 1
					pitch_brake_hits += 1 if car.chassis_pitch > 0.0 else 0
				if car.throttle > 0.9:
					pitch_power_samples += 1
					pitch_power_hits += 1 if car.chassis_pitch < 0.0 else 0
			finite_ok = finite_ok and not is_nan(car.chassis_roll) and not is_nan(car.chassis_pitch) and not is_nan(car.yaw_offset) and not is_nan(car.v_lat)
	check(saw_right and saw_left and steer_samples > 100 and float(steer_hits) / float(steer_samples) > 0.9,
		"chassis: front wheels steer into the corner, + for right and - for left (%d of %d samples)" % [steer_hits, steer_samples])
	check(finite_ok and float(roll_hits) / float(maxi(1, roll_samples)) > 0.9 and float(pitch_brake_hits) / float(maxi(1, pitch_brake_samples)) > 0.9
		and float(pitch_power_hits) / float(maxi(1, pitch_power_samples)) > 0.9,
		"chassis: the body rolls with the corner (%d of %d), dives under braking (+pitch, %d of %d), squats under power (-pitch, %d of %d), all angles finite" % [
			roll_hits, roll_samples, pitch_brake_hits, pitch_brake_samples, pitch_power_hits, pitch_power_samples
		])
	var car: CarScript = race.cars[0]
	var wheels_ok: bool = car.wheel_temp.size() == 4
	for index: int in range(4):
		wheels_ok = wheels_ok and car.wheel_temp[index] > 60.0 and car.wheel_temp[index] < 160.0 \
			and car.wheel_pressure_psi[index] > 25.0 and car.wheel_pressure_psi[index] < 35.0 and car.wheel_brake_temp[index] > 100.0
	check(wheels_ok and car.driver_stress >= 0.0 and car.driver_stress <= 100.0 and car.driver_heart_rate >= 100.0 and car.driver_heart_rate <= 200.0
		and car.throttle >= 0.0 and car.throttle <= 1.0 and car.brake >= 0.0 and car.brake <= 1.0,
		"telemetry: 4-wheel temperature, pressure and brake temperature, pedals, G-forces and driver biometrics are live")
	var trap_ok: bool = not race.speed_trap_max.is_empty() and float(race.speed_trap_max["speed"]) > 200.0
	var sector_ok: bool = false
	for other: CarScript in race.cars:
		sector_ok = sector_ok or (other.current_lap_sectors[0] >= 0.0 or other.last_lap_sectors[0] >= 0.0)
	check(trap_ok and sector_ok, "timing: sector splits are recorded and the speed trap logs %s km/h" % race.speed_trap_max.get("speed", 0))
	_free(race)
