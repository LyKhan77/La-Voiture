extends SceneTree

## Paulistano pit-drive gate, the production equivalent of the approved sandbox
## test_pit_drive.gd (25 checks there): the real GT sim enters the LEFT-hand lane at s = 4060
## under the 80 km/h limiter, stops on service bay 5 at s = 97 / lateral -16.5, serves 3.0 s,
## merges at s = 160, then runs a clean lap through all 15 turns.
## Run: godot --headless --path . -s res://tests/test_paulistano_pit_drive.gd

const Circuit := preload("res://scenes/race_world/circuits/paulistano/paulistano_circuit.tscn")
const TrackScript := preload("res://scripts/gt/gt_track.gd")
const RaceScript := preload("res://scripts/gt/gt_race.gd")
const CarScript := preload("res://scripts/gt/gt_car.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const WeatherScript := preload("res://scripts/gt/gt_weather.gd")

const DT: float = Types.TICK_DT
const GUARD_S: float = 240.0
const ENTRY_S: float = 4060.0
const EXIT_S: float = 160.0
const SERVICE_S: float = 97.0
const LATERAL_M: float = -16.5

var failures: int = 0
var checks: int = 0


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var circuit := Circuit.instantiate() as Node3D
	root.add_child(circuit)
	await process_frame
	var ribbon: TrackRibbon = circuit.get_node("TrackRibbon")
	var pit: CircuitPitComplex = circuit.get_node("PitLane")
	var track := TrackScript.new(ribbon, 13.5)
	var race := RaceScript.new(track, 3, 31, WeatherScript.Archetype.DRY_SUNNY, 20, pit.sim_layout())
	race.incidents_enabled = false
	var car: CarScript = null
	for candidate: CarScript in race.cars:
		if candidate.team_id == 5:
			car = candidate
			break
	assert(car != null, "team 5 must be on the grid")
	var start_s: float = ENTRY_S - 150.0
	car.s = start_s
	car.prev_s = start_s
	car.v = 70.0
	car.lateral = 0.0
	car.prev_lateral = 0.0
	car.target_lateral = 0.0
	car.lap = 1
	race.request_pit(car.id, Types.Compound.MEDIUM)

	var entry_station: float = -1.0
	var entry_kmh: float = -1.0
	var lane_max_kmh: float = 0.0
	var lane_max_lateral: float = -INF
	var stop_station: float = -1.0
	var stop_lateral: float = INF
	var stop_time: float = -1.0
	var service_time: float = -1.0
	var exit_station: float = -1.0
	var exit_kmh: float = -1.0
	var off_asphalt: int = 0
	var was_in_pit: bool = false
	var box_seen: bool = false
	var ticks: int = 0
	while ticks < int(GUARD_S / DT):
		race.step()
		ticks += 1
		_drive_hits += 1 if _overlaps(car, pit) else 0
		if car.pit != null:
			was_in_pit = true
			if car.pit.phase == Types.PitPhase.IN and entry_station < 0.0:
				entry_station = fposmod(car.pit.start_s, track.length)
				entry_kmh = car.v * 3.6
			if car.pit.phase != Types.PitPhase.ENTRY:
				lane_max_kmh = maxf(lane_max_kmh, car.v * 3.6)
				lane_max_lateral = maxf(lane_max_lateral, car.lateral)
			if car.pit.phase == Types.PitPhase.BOX:
				box_seen = true
				if stop_station < 0.0 and car.v < 0.1 and absf(car.pit.box_s - car.s) <= 0.5:
					stop_station = fposmod(car.s, track.length)
					stop_lateral = car.lateral
					stop_time = race.time
			elif box_seen and car.pit.phase == Types.PitPhase.OUT and service_time < 0.0:
				service_time = race.time - stop_time
		elif was_in_pit and exit_station < 0.0:
			exit_station = fposmod(car.s, track.length)
			exit_kmh = car.v * 3.6
		if car.stops >= 1 and car.pit == null:
			if absf(car.lateral) > ribbon.road_half_width_m + 0.01:
				off_asphalt += 1
			break
	var lap_start: float = car.s
	var guard: int = 0
	while guard < int(200.0 / DT) and car.lap < 2:
		race.step()
		guard += 1
		if car.pit == null and absf(car.lateral) > ribbon.road_half_width_m + 0.01:
			off_asphalt += 1
	check(car.stops >= 1, "the GT car is serviced once")
	check(entry_station >= 0.0 and absf(entry_station - ENTRY_S) <= 2.0, "pit entry fires at s = 4060 (%.3f)" % entry_station)
	check(entry_kmh >= 0.0 and entry_kmh <= 80.5, "entry speed respects the 80 km/h limiter (%.1f km/h)" % entry_kmh)
	check(lane_max_kmh <= 80.5, "no in-lane tick exceeds 80 km/h (max %.1f)" % lane_max_kmh)
	check(lane_max_lateral < 0.0, "the whole lane runs off the left of the circuit (max lateral %.2f m)" % lane_max_lateral)
	check(stop_station >= 0.0 and absf(stop_station - SERVICE_S) <= 2.0, "car stops on service bay 5 at s = 97 (%.3f)" % stop_station)
	check(is_finite(stop_lateral) and absf(stop_lateral - LATERAL_M) <= 1.5, "car stops on the left box line, lateral -16.5 m (%.3f)" % stop_lateral)
	check(service_time >= 2.9 and service_time <= 3.4, "service lasts 3.0 s of sim time (%.3f s)" % service_time)
	check(exit_station >= 0.0 and absf(exit_station - EXIT_S) <= 10.0, "release merges at s = 160 (%.3f)" % exit_station)
	check(exit_kmh > 60.0, "the car leaves the lane at racing speed (%.1f km/h)" % exit_kmh)
	check(off_asphalt == 0, "0 frames off the 13.5 m asphalt on the in/out and the lap (%d)" % off_asphalt)
	check(car.lateral <= ribbon.road_half_width_m + 0.01, "the car never crosses the right barrier line (lateral %.2f m)" % car.lateral)
	check(car.lap >= 2, "the car completes a full racing lap after the stop (lap %d)" % car.lap)
	check(absf(track.length - 4313.035) <= 50.0, "lap length within 4.310 m +- 50 m (%.3f m)" % track.length)
	check(circuit.turns.size() == 15, "all 15 turns are exposed on the lap")
	var ordered: bool = true
	var previous: float = -1.0
	for turn: Dictionary in circuit.turns:
		var station: float = float(turn["s"])
		ordered = ordered and station > previous and station < track.length
		previous = station
	check(ordered, "the 15 turn stations are ordered around the lap")
	check(lap_start > 0.0, "the pit exit leaves the car on the racing surface")
	check(_drive_hits == 0, "the serviced car never touches the pit wall (%d car-ticks)" % _drive_hits)
	race.dispose()
	check(_bunched_wall_hits(pit, track) == 0, "twenty cars boxing bunched never touch the pit wall (entry blend, queue or exit)")
	circuit.free()
	await process_frame
	print("%d checks, %d failure(s)" % [checks, failures])
	quit(1 if failures else 0)


## Car-ticks whose body (car width) overlaps the pit wall line (cap width) along the walled stretch.
func _overlaps(car, pit: Node) -> bool:
	if car.pit == null:
		return false
	var span_u: Vector2 = pit.get_meta("pit_wall_span_u")
	var wall_abs: float = absf(float(pit.get_meta("pit_wall_lateral_m")))
	var u: float = car.s - car.pit.start_s
	if u < span_u.x or u > span_u.y:
		return false
	var half: float = Types.CAR_WIDTH_M * 0.5
	return absf(car.lateral) - half < wall_abs + 0.12 and absf(car.lateral) + half > wall_abs - 0.12


var _drive_hits: int = 0


func _bunched_wall_hits(pit: Node, track) -> int:
	var race := RaceScript.new(track, 12, 31, WeatherScript.Archetype.DRY_SUNNY, 20, pit.sim_layout())
	race.incidents_enabled = false
	for index: int in range(race.cars.size()):
		var car: CarScript = race.cars[index]
		var s: float = fposmod(ENTRY_S - 150.0 - float(index) * 20.0, track.length) + track.length
		car.s = s
		car.prev_s = s
		car.v = 32.0
		car.lap = 1
		race.request_pit(car.id, Types.Compound.MEDIUM)
	var hits: int = 0
	for _tick: int in range(int(140.0 / DT)):
		race.step()
		for car: CarScript in race.cars:
			hits += 1 if _overlaps(car, pit) else 0
	race.dispose()
	print("  bunched pit wall overlap car-ticks: %d" % hits)
	return hits
