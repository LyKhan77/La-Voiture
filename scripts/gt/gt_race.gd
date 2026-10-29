class_name GtRace
extends RefCounted

## The GT race sim: a GDScript port of gt-manager's `Race` (race.ts). Cars are points
## with a continuous `s` and `lateral` (no lanes), driven by an AI with overtaking,
## defending, side-by-side and blue-flag rules, DRS / ERS / slipstream, tyre and fuel
## models, incidents, FIA flags with a safety car, a pit lane and a manual / auto tactic desk.
## Per tick: weather, race control, every car (GtDriving), the contact resolver, tactics.
## GtRace owns state and rules the world and the HUD read; the heavy per-car logic is
## in gt_driving.gd, contacts and incidents in gt_contacts.gd.

signal radio_message(message: Dictionary)
signal collision_event(event: Dictionary)
signal flag_changed(flag: int, message: String)
signal suggestion_changed(suggestion: Dictionary)
## Steward banner events: {"phase": "investigation" | "verdict", "case_id", "car_id", "text", ...} (see GtStewards).
signal steward_event(event: Dictionary)

const GRID_ROW_M: float = 8.0
const PitLaneScript := preload("res://scripts/world/circuits/apex_ring/apex_pit_complex.gd")
const SC_QUEUE_GAP_M: float = 46.0
const SC_PICKUP_GAP_M: float = 50.0
const GRID_COLUMN_M: float = 2.5
## Race seconds a suggestion card stays open: MANUAL closes it, AUTO executes it when the window ends.
const SUGGESTION_WINDOW_S: float = 10.0

var track: GtTrack
var laps: int = 10
var time: float = 0.0
var tick_count: int = 0
var cars: Array[GtCar] = []
var weather: GtWeather
var rng: GtRng
var best_session_sectors: Array[float] = [-1.0, -1.0, -1.0]
var speed_trap_max: Dictionary = {}
var radio_history: Array[Dictionary] = []
var latest_radio: Dictionary = {}
var tactic_mode: int = GtTypes.TacticMode.MANUAL
var player_team_id: int = 0
var active_teams: Array[int] = []
var race_seed: int = 1
var latest_suggestion: Dictionary = {}
var latest_collision: Dictionary = {}
## Rare solo spins, barrier taps and contact incidents. Tests that need a quiet field turn it off.
var incidents_enabled: bool = true
## Scales every incident roll (contacts, solo spins, mistakes): 1.0 is the stock rate, the setup's STREET CHAOS raises it.
var incident_rate: float = 1.0

var race_control: Dictionary = {
	"flag": GtTypes.Flag.GREEN, "sector": 1, "message": "TRACK CLEAR - GREEN FLAG",
	"timer": 0.0, "sc_laps_remaining": 0, "drs_enabled": false,
}
var safety_car: Dictionary = {
	"active": false, "phase": GtTypes.SafetyCarPhase.HIDDEN, "s": 0.0, "v": 0.0, "lateral": 0.0, "lights_on": false,
}

var last_incident_time: float = -999.0
## Race time at which the winner took the flag; every other car finishes at its next line crossing.
var flag_time: float = -1.0
var last_radio_time: float = -999.0
## Seconds before a car may make another routine call to the pit wall, by car id. Urgent calls ignore it.
const DRIVER_RADIO_COOLDOWN_S: float = 15.0
var driver_radio_cooldown: Dictionary = {}
## The engineer answers a driver call of the player team this many seconds of sim time later.
const RADIO_REPLY_DELAY_S: float = 2.5

var _radio_counter: int = 0
var _pending_replies: Array[Dictionary] = [] # {"due", "car_id", "reply_to", "driver_text"}
var _flood_called: Dictionary = {} # car id -> true while a flood episode has been called
var _suggestion_cooldowns: Dictionary = {} # "car-type" -> time
var contacts: GtContacts
var stewards: GtStewards

var _driving: GtDriving
## The pit lane this race is run with. The Apex Ring's lane is the default; the street circuits hand
## their own entry/exit distances, fast lane lateral and stall pitch (see RaceWeekendWorld).
var pit_layout: Dictionary = {}


## The Apex Ring pit lane, exactly as ApexPitComplex builds it.
static func default_pit_layout() -> Dictionary:
	return {
		"entry_s": PitLaneScript.ENTRY_S,
		"exit_s": PitLaneScript.EXIT_S,
		"stall_first_s": PitLaneScript.STALL_FIRST_S,
		"stall_pitch_m": PitLaneScript.STALL_PITCH_M,
		"stall_lane_m": PitLaneScript.STALL_LANE_M,
		"fast_lane_m": PitLaneScript.FAST_LANE_M,
		"edge_lateral_m": PitLaneScript.EDGE_LATERAL_M,
		"queue_gap_m": PitLaneScript.QUEUE_GAP_M,
		"lane_ramp_in_m": PitLaneScript.RAMP_IN_M,
		"lane_ramp_out_m": PitLaneScript.RAMP_OUT_M,
	}


## Lateral of the pit path at `u` metres from Pit Entry: off the right edge, onto the fast lane, and
## back. `length` is the lane's own length (Pit Exit minus Pit Entry).
static func lane_lateral_at(u: float, length: float, layout: Dictionary) -> float:
	var blend: float = minf(
		smoothstep(0.0, float(layout["lane_ramp_in_m"]), u),
		smoothstep(length, length - float(layout["lane_ramp_out_m"]), u)
	)
	return lerpf(float(layout["edge_lateral_m"]), float(layout["fast_lane_m"]), blend)


## `weather_override` < 0 lets the seed choose the weather.
func _init(p_track: GtTrack, p_laps: int = 10, seed_value: int = 1, weather_override: int = -1, car_count: int = 20, p_pit_layout: Dictionary = {}) -> void:
	pit_layout = p_pit_layout.duplicate() if not p_pit_layout.is_empty() else default_pit_layout()
	track = p_track
	laps = maxi(1, p_laps)
	race_seed = seed_value
	rng = GtRng.new(seed_value)
	weather = GtWeather.new(laps, seed_value, weather_override)
	weather.advisory.connect(_on_weather_advisory)
	_driving = GtDriving.new(self)
	contacts = GtContacts.new(self)
	stewards = GtStewards.new(self)
	# Keep the reference's deterministic qualifying offset in the stream.
	if rng.next() > 0.35:
		rng.next()
		rng.next()
		rng.next()
	_build_grid(clampi(car_count, 1, 20), seed_value)


## Breaks the reference cycles between the race and its helpers so it can be freed.
func dispose() -> void:
	if _driving != null:
		_driving.race = null
	if contacts != null:
		contacts.race = null
	_driving = null
	contacts = null
	if stewards != null:
		stewards.race = null
	stewards = null
	if weather != null and weather.advisory.is_connected(_on_weather_advisory):
		weather.advisory.disconnect(_on_weather_advisory)


func stall_index_for_team(team_id: int) -> int:
	var idx: int = active_teams.find(team_id)
	return idx if idx >= 0 else posmod(team_id, 10)


func _build_grid(count: int, _seed_value: int, target_teams: Array[int] = []) -> void:
	cars.clear()
	var total_teams: int = GtData.TEAM_NAMES.size()
	var needed_teams: int = clampi((count + 1) / 2, 1, total_teams)
	if target_teams.is_empty():
		active_teams.clear()
		for t: int in range(needed_teams):
			active_teams.append(t)
	else:
		active_teams = target_teams.duplicate()
	var entries: Array[Dictionary] = []
	for team_id: int in active_teams:
		for d: int in range(2):
			var slot: int = team_id * 2 + d
			var car := GtCar.new()
			GtData.apply_entry(car, slot)
			entries.append({"car": car, "pace": car.grip * car.skill + (rng.next() - 0.5) * 0.02})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["pace"]) > float(b["pace"]))
	var initial_water: float = weather.track_water_pct
	for index: int in range(count):
		var car: GtCar = entries[index]["car"]
		var compound: int = GtTypes.Compound.SOFT
		if initial_water > 50.0:
			compound = GtTypes.Compound.WET
		elif initial_water > 15.0:
			compound = GtTypes.Compound.INTERMEDIATE
		else:
			compound = rng.range_int(0, 2)
		car.compound = compound
		car.s = -GRID_ROW_M - float(index) * GRID_ROW_M
		car.prev_s = car.s
		var lat: float = -GRID_COLUMN_M if index % 2 == 0 else GRID_COLUMN_M
		car.lateral = lat
		car.prev_lateral = lat
		car.target_lateral = lat
		car.defend_target_lateral = lat
		car.fuel = car.fuel_use * float(laps) * 1.05
		car.fuel_burn_rate = car.fuel_use
		car.position = index + 1
		cars.append(car)
	# Grid slots follow qualifying pace; the car ids stay the field slots.
	for index: int in range(cars.size()):
		cars[index].position = index + 1


## Takes the chequered flag; the first car to do it ends the race for the rest of the field.
func mark_finished(car: GtCar) -> void:
	car.finished_at = time
	if flag_time < 0.0:
		flag_time = time


func is_finished() -> bool:
	for car: GtCar in cars:
		if car.finished_at < 0.0 and not car.is_dnf:
			return false
	return true


func get_car(car_id: int) -> GtCar:
	for car: GtCar in cars:
		if car.id == car_id:
			return car
	return null


## Cars in official race order: running first by distance, finished by finish time,
## retired cars at the bottom.
func standings() -> Array[GtCar]:
	var ordered: Array[GtCar] = cars.duplicate()
	ordered.sort_custom(_standing_before)
	return ordered


func _standing_before(a: GtCar, b: GtCar) -> bool:
	if a.is_dnf and not b.is_dnf:
		return false
	if not a.is_dnf and b.is_dnf:
		return true
	if a.is_dnf and b.is_dnf:
		return a.s > b.s
	if a.finished_at >= 0.0 and b.finished_at >= 0.0:
		# Laps first (a lapped car can cross the line before a lead-lap car), then time.
		var laps_a: int = floori(a.s / track.length)
		var laps_b: int = floori(b.s / track.length)
		if laps_a != laps_b:
			return laps_a > laps_b
		return classified_time(a) < classified_time(b)
	if a.finished_at >= 0.0:
		return true
	if b.finished_at >= 0.0:
		return false
	return a.s > b.s


## Time over the line plus the steward penalty the car never served in the pits.
func classified_time(car: GtCar) -> float:
	return car.finished_at + car.penalty_owed_s


## Rows for the timing tower and the pit wall, in race order. `interval_s` and `gap_s`
## are distance over speed (never below 25 m/s), as in the reference.
func standings_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var order: Array[GtCar] = standings()
	var leader: GtCar = order[0] if not order.is_empty() else null
	for index: int in range(order.size()):
		var car: GtCar = order[index]
		var gap_s: float = 0.0
		var interval_s: float = 0.0
		if leader != null and car != leader:
			gap_s = (leader.s - car.s) / maxf(car.v, 25.0)
		if index > 0:
			interval_s = (order[index - 1].s - car.s) / maxf(car.v, 25.0)
		entries.append({
			"position": index + 1, "car_id": car.id, "team_id": car.team_id, "team_name": car.team_name,
			"driver_name": car.driver_name, "code": car.code, "number": car.number, "compound": car.compound,
			"lap_number": maxi(car.lap, 0), "last_lap_time": maxf(car.last_lap, 0.0), "best_lap_time": maxf(car.best_lap, 0.0),
			"gap_s": gap_s, "interval_s": interval_s, "wear_avg": car.wear, "fuel_kg": car.fuel,
			"in_pit": car.pit != null, "is_dnf": car.is_dnf, "is_finished": car.finished_at >= 0.0 and not car.is_dnf,
			"drs": car.drs_active, "sector_colors": car.sector_colors.duplicate(), "speed_kmh": car.v * 3.6,
		})
	return entries


## One fixed tick of GtTypes.TICK_DT.
func step(dt: float = GtTypes.TICK_DT) -> void:
	if _driving == null:
		return # disposed: a late frame must not call into the freed driver
	tick_count += 1
	_tick_driver_radio_cooldowns(dt)
	_flush_replies()
	_step_weather(dt)
	_update_race_control(dt)
	var racing: Array[GtCar] = []
	for car: GtCar in cars:
		if car.is_racing():
			racing.append(car)
	var contexts: Dictionary = _driving.build_contexts(racing)
	for car: GtCar in cars:
		_driving.update_car(car, contexts.get(car), dt)
	var active: Array[GtCar] = []
	for car: GtCar in cars:
		if car.is_racing():
			active.append(car)
	contacts.resolve(active, dt)
	if contacts.contacts_last > 0:
		_protect_caution_order(active, contexts)
	stewards.step()
	if is_finished():
		stewards.close_all()
	_check_advisor_tactics()
	_expire_suggestion()
	_check_flood_radio()
	time += dt
	_update_wreck_fade()
	var order: Array[GtCar] = standings()
	for index: int in range(order.size()):
		order[index].position = index + 1


## Steps `count` ticks.
func step_ticks(count: int) -> void:
	for _i: int in range(count):
		step()


# --- weather -----------------------------------------------------------------

func _step_weather(dt: float) -> void:
	var leader: GtCar = null
	for car: GtCar in standings():
		if not car.is_dnf:
			leader = car
			break
	var continuous_lap: float = 1.0
	if leader != null:
		continuous_lap = maxf(1.0, 1.0 + maxf(0.0, leader.s) / track.length)
	var moving: int = 0
	for car: GtCar in cars:
		if not car.is_dnf and car.finished_at < 0.0 and car.pit == null and car.v > 15.0:
			moving += 1
	weather.step(dt, time, float(moving) / float(maxi(1, cars.size())), continuous_lap, laps)


func _on_weather_advisory(text: String) -> void:
	var target: GtCar = _player_car()
	if target != null:
		push_radio(target, "engineer", text, true)


func _player_car() -> GtCar:
	for car: GtCar in cars:
		if car.team_id == player_team_id and not car.is_dnf:
			return car
	return cars[0] if not cars.is_empty() else null


# --- race control ------------------------------------------------------------

const _FLAG_SEVERITY: Array[int] = [0, 1, 2, 3]


func set_flag(flag: int, sector: int = 1, message: String = "", duration: float = 14.0) -> void:
	var current: int = race_control["flag"]
	var current_active: bool = current != GtTypes.Flag.GREEN and (float(race_control["timer"]) > 0.0 or int(race_control["sc_laps_remaining"]) > 0 or bool(safety_car["active"]))
	if flag != GtTypes.Flag.GREEN and current_active and _FLAG_SEVERITY[flag] < _FLAG_SEVERITY[current]:
		# FIA priority: a yellow never downgrades an active VSC or safety car.
		race_control["timer"] = maxf(float(race_control["timer"]), duration)
		return
	var was_sc: bool = current == GtTypes.Flag.SC and current_active
	race_control = {
		"flag": flag, "sector": sector, "message": message, "timer": duration,
		"sc_laps_remaining": maxi(1 if laps <= 3 else 2, int(race_control["sc_laps_remaining"])) if flag == GtTypes.Flag.SC else 0,
		"drs_enabled": false if flag != GtTypes.Flag.GREEN else bool(race_control["drs_enabled"]),
	}
	if flag == GtTypes.Flag.SC:
		for car: GtCar in cars:
			car.sc_restart_line_s = -1.0
	if flag == GtTypes.Flag.SC and not was_sc:
		var leader: GtCar = null
		for car: GtCar in standings():
			if not car.is_dnf and car.finished_at < 0.0:
				leader = car
				break
		var leader_s: float = leader.s if leader != null else 0.0
		var lap_base: float = floorf(leader_s / track.length) * track.length
		var spawn_s: float = lap_base + float(pit_layout["exit_s"]) - 60.0
		if spawn_s <= leader_s:
			spawn_s += track.length
		safety_car = {
			"active": true, "phase": GtTypes.SafetyCarPhase.DEPLOYED, "s": spawn_s,
			"prev_s": spawn_s, "prev_lateral": sc_pit_exit_lateral_in(fposmod(spawn_s, track.length), pit_layout),
			"v": 20.0, "lateral": sc_pit_exit_lateral_in(fposmod(spawn_s, track.length), pit_layout),
			"lights_on": true, "just_deployed": true,
			"exit_end_s": floorf(spawn_s / track.length) * track.length + float(pit_layout["exit_s"]) + 70.0,
			"entry_start_s": -1.0, "restart_s": -1.0,
			"picked_up": false, "leader_id": leader.id if leader != null else -1, "wave_by": false,
			"finish_under_caution": leader != null and leader.s >= float(laps - 1) * track.length,
		}
	elif flag == GtTypes.Flag.SC and int(safety_car["phase"]) == GtTypes.SafetyCarPhase.IN_THIS_LAP:
		safety_car["phase"] = GtTypes.SafetyCarPhase.DEPLOYED
		safety_car["lights_on"] = true
		if float(safety_car["s"]) < float(safety_car["entry_start_s"]):
			safety_car["entry_start_s"] = -1.0
			safety_car["restart_s"] = -1.0
	elif flag == GtTypes.Flag.GREEN:
		safety_car["active"] = false
		safety_car["phase"] = GtTypes.SafetyCarPhase.HIDDEN
		safety_car["lights_on"] = false
	flag_changed.emit(flag, message)


## Zero lateral slope at both ends of each blend segment.
static func sc_pit_exit_lateral(s_lap: float) -> float:
	return sc_pit_exit_lateral_in(s_lap, default_pit_layout())


static func sc_pit_exit_lateral_in(s_lap: float, layout: Dictionary) -> float:
	var s_rel: float = s_lap - float(layout["exit_s"])
	var fast: float = float(layout["fast_lane_m"])
	var edge: float = float(layout["edge_lateral_m"])
	if s_rel <= -60.0:
		return fast
	if s_rel <= 0.0:
		return lerpf(fast, edge, smoothstep(-60.0, 0.0, s_rel))
	return lerpf(edge, 0.0, smoothstep(0.0, 70.0, s_rel))


static func sc_pit_entry_lateral(s_lap: float) -> float:
	return sc_pit_entry_lateral_in(s_lap, default_pit_layout())


static func sc_pit_entry_lateral_in(s_lap: float, layout: Dictionary) -> float:
	var s_rel: float = s_lap - float(layout["entry_s"])
	var fast: float = float(layout["fast_lane_m"])
	var edge: float = float(layout["edge_lateral_m"])
	if s_rel <= -80.0:
		return 0.0
	if s_rel <= 0.0:
		return lerpf(0.0, edge, smoothstep(-80.0, 0.0, s_rel))
	return lerpf(edge, fast, smoothstep(0.0, 60.0, s_rel))


func restart_pending(car: GtCar) -> bool:
	return car.sc_restart_line_s >= 0.0 and car.s < car.sc_restart_line_s and car.finished_at < 0.0 and not car.is_dnf


## Contact position corrections must not bypass the no-pass rule enforced by driving.
func _protect_caution_order(active: Array[GtCar], contexts: Dictionary) -> void:
	for car: GtCar in active:
		if is_under_caution(car):
			car.s = maxf(car.s, car.prev_s)
	for pass_index: int in range(active.size()):
		var changed: bool = false
		for car: GtCar in active:
			if not is_under_caution(car):
				continue
			var lead: Dictionary = contexts[car]["lead"]
			if lead.is_empty():
				continue
			var ahead: GtCar = lead["car"]
			if not ahead.is_racing():
				continue
			var minimum: float = GtTypes.CAR_LENGTH_M + 1.0 if absf(ahead.lateral - car.lateral) < GtTypes.CAR_WIDTH_M + 0.1 else 0.01
			var gap: float = float(lead["dist"]) + ahead.s - float(lead["start_s"]) - (car.s - car.prev_s)
			if gap < minimum:
				ahead.s += minimum - gap
				changed = true
		if not changed:
			break


func _sc_leader() -> GtCar:
	for car: GtCar in standings():
		if not car.is_dnf and car.pit == null:
			return car
	return null


## Minimal pickup permission, not an unlapping procedure; race-car order remains protected.
func sc_may_pass(car: GtCar) -> bool:
	return int(race_control["flag"]) == GtTypes.Flag.SC and int(safety_car["phase"]) == GtTypes.SafetyCarPhase.DEPLOYED and not bool(safety_car.get("picked_up", false)) and car.id != int(safety_car.get("leader_id", -1))


func sc_blocks_car(car: GtCar) -> bool:
	if int(race_control["flag"]) != GtTypes.Flag.SC or not bool(safety_car["active"]) or sc_may_pass(car):
		return false
	if int(safety_car["phase"]) == GtTypes.SafetyCarPhase.DEPLOYED:
		return true
	return int(safety_car["phase"]) == GtTypes.SafetyCarPhase.IN_THIS_LAP and float(safety_car["s"]) < float(safety_car["entry_start_s"]) + 80.0


func _sc_track_clear() -> bool:
	for car: GtCar in cars:
		if (car.is_dnf and not car.is_cleared) or (not car.is_dnf and car.spin_timer > 0.0):
			return false
	return true


## Seconds a recovered wreck takes to fade out of the picture.
const WRECK_FADE_S: float = 2.0


## The safety car announces its in-lap: the marshals have cleared the track, so every retired car begins to fade
## and race control tells the pit wall.
func _start_wreck_evacuation() -> void:
	var cleared_sector: int = -1
	var latest_retirement: float = -INF
	for car: GtCar in cars:
		if car.is_dnf and car.evac_started_at < 0.0:
			car.evac_started_at = time
			# The call names the wreck that brought the safety car out: the most recent retirement.
			if car.finished_at > latest_retirement:
				latest_retirement = car.finished_at
				cleared_sector = car.current_sector + 1
	var player: GtCar = _player_car()
	if cleared_sector > 0 and player != null:
		push_radio(player, "engineer", "Track clear in Sector %d. Recovery complete, Safety Car in this lap." % cleared_sector, true)


func _update_wreck_fade() -> void:
	for car: GtCar in cars:
		if car.evac_started_at >= 0.0:
			car.wreck_alpha = clampf(1.0 - (time - car.evac_started_at) / WRECK_FADE_S, 0.0, 1.0)


func _sc_queue_ready(leader: GtCar) -> bool:
	if leader == null or not bool(safety_car.get("picked_up", false)):
		return false
	var gaps: Array[float] = []
	for car: GtCar in cars:
		if not car.is_dnf and car.finished_at < 0.0 and car.pit == null:
			gaps.append(fposmod(float(safety_car["s"]) - car.s, track.length))
	gaps.sort()
	var previous: float = 0.0
	for gap: float in gaps:
		if gap - previous > SC_QUEUE_GAP_M:
			return false
		previous = gap
	return not gaps.is_empty()


func _update_race_control(dt: float) -> void:
	var flag: int = race_control["flag"]
	if flag == GtTypes.Flag.YELLOW or flag == GtTypes.Flag.VSC:
		race_control["timer"] = float(race_control["timer"]) - dt
		if float(race_control["timer"]) <= 0.0:
			race_control["flag"] = GtTypes.Flag.GREEN
			race_control["message"] = "TRACK CLEAR - GREEN FLAG"
			flag_changed.emit(GtTypes.Flag.GREEN, race_control["message"])
	elif flag == GtTypes.Flag.SC:
		if dt > 0.0:
			safety_car["prev_s"] = safety_car["s"]
			safety_car["prev_lateral"] = safety_car["lateral"]
		race_control["timer"] = float(race_control["timer"]) - dt
		var leader: GtCar = _sc_leader()
		safety_car["active"] = true
		var gap_to_leader: float = fposmod(float(safety_car["s"]) - leader.s, track.length) if leader != null else track.length
		if leader != null and int(safety_car.get("leader_id", -1)) != leader.id:
			safety_car["picked_up"] = false
		if leader != null:
			safety_car["leader_id"] = leader.id
		var leader_first: bool = leader != null and gap_to_leader <= SC_PICKUP_GAP_M
		safety_car["wave_by"] = false
		for car: GtCar in cars:
			if car == leader or not car.is_racing():
				continue
			var gap: float = fposmod(float(safety_car["s"]) - car.s, track.length)
			if gap < gap_to_leader:
				leader_first = false
			if gap <= SC_PICKUP_GAP_M and sc_may_pass(car):
				safety_car["wave_by"] = true
		if leader_first:
			safety_car["picked_up"] = true
			safety_car["leader_id"] = leader.id
			safety_car["wave_by"] = false
		var entry_start: float = floorf(float(safety_car["s"]) / track.length) * track.length + float(pit_layout["entry_s"]) - 80.0
		var complete_approach: bool = float(safety_car["s"]) <= entry_start - 30.0 and float(safety_car["s"]) > float(safety_car.get("exit_end_s", 0.0))
		if int(race_control["sc_laps_remaining"]) <= 0 and float(race_control["timer"]) <= 0.0 and _sc_track_clear() and _sc_queue_ready(leader) and complete_approach and int(safety_car["phase"]) != GtTypes.SafetyCarPhase.IN_THIS_LAP:
			safety_car["phase"] = GtTypes.SafetyCarPhase.IN_THIS_LAP
			safety_car["lights_on"] = false
			safety_car["wave_by"] = false
			safety_car["entry_start_s"] = entry_start
			safety_car["restart_s"] = (floorf(entry_start / track.length) + 1.0) * track.length
			for car: GtCar in cars:
				var lap_offset: float = floorf((float(safety_car["s"]) - car.s) / track.length)
				car.sc_restart_line_s = float(safety_car["restart_s"]) - lap_offset * track.length if car.pit == null else -1.0
			race_control["message"] = "SAFETY CAR IN THIS LAP - PREPARE FOR RESTART"
			_start_wreck_evacuation()
		var pit_start: float = float(safety_car.get("entry_start_s", -1.0))
		var pit_exit: float = float(safety_car.get("restart_s", -1.0)) + float(pit_layout["exit_s"]) - 60.0
		if int(safety_car["phase"]) == GtTypes.SafetyCarPhase.DEPLOYED and pit_start >= 0.0 and float(safety_car["s"]) >= pit_exit:
			# Renewed caution after peel-off must finish the pit route before merging again.
			safety_car["entry_start_s"] = -1.0
			safety_car["restart_s"] = -1.0
			safety_car["exit_end_s"] = pit_exit + 130.0
			pit_start = -1.0
		var peeling: bool = pit_start >= 0.0 and float(safety_car["s"]) >= pit_start
		var target_v: float = 25.0 if gap_to_leader > 28.0 else 27.0
		if not bool(safety_car.get("picked_up", false)):
			target_v = 18.0
		if peeling and float(safety_car["lateral"]) >= float(pit_layout["edge_lateral_m"]):
			target_v = 80.0 / 3.6
		safety_car["v"] = move_toward(float(safety_car["v"]), target_v, (3.0 if target_v > float(safety_car["v"]) else 4.5) * dt)
		safety_car["s"] = float(safety_car["s"]) + float(safety_car["v"]) * dt
		if int(safety_car["phase"]) == GtTypes.SafetyCarPhase.IN_THIS_LAP and float(safety_car["s"]) >= pit_exit:
			# Wait at the standby ramp instead of driving off the pit asphalt before the restart.
			safety_car["s"] = pit_exit
			safety_car["v"] = 0.0
		var sc_s: float = float(safety_car["s"])
		entry_start = float(safety_car.get("entry_start_s", -1.0))
		var exit_end: float = float(safety_car.get("exit_end_s", 0.0))
		if entry_start >= 0.0 and sc_s >= entry_start:
			# Unwrapped progress keeps the car inside the pit lane across start/finish.
			safety_car["lateral"] = sc_pit_entry_lateral_in(float(pit_layout["entry_s"]) - 80.0 + sc_s - entry_start, pit_layout)
		elif sc_s <= exit_end:
			safety_car["lateral"] = sc_pit_exit_lateral(fposmod(sc_s, track.length))
		else:
			var line_blend: float = smoothstep(exit_end, exit_end + 30.0, sc_s)
			if entry_start >= 0.0:
				line_blend *= 1.0 - smoothstep(entry_start - 30.0, entry_start, sc_s)
			safety_car["lateral"] = track.ideal_lateral_at(sc_s) * 0.35 * line_blend
		var ready_for_green: bool = int(race_control["sc_laps_remaining"]) <= 0 and float(race_control["timer"]) <= 0.0 and entry_start >= 0.0 and sc_s >= entry_start + 140.0 and leader != null and leader.s >= float(safety_car["restart_s"]) and float(safety_car["restart_s"]) < float(laps) * track.length
		if leader != null and leader.s >= float(laps - 1) * track.length and not ready_for_green:
			safety_car["finish_under_caution"] = true
		if ready_for_green and not bool(safety_car.get("finish_under_caution", false)):
			race_control["flag"] = GtTypes.Flag.GREEN
			race_control["message"] = "SAFETY CAR IN - GREEN FLAG RESTART"
			safety_car["active"] = false
			safety_car["phase"] = GtTypes.SafetyCarPhase.HIDDEN
			safety_car["lights_on"] = false
			flag_changed.emit(GtTypes.Flag.GREEN, race_control["message"])

	# DRS: dry track, green flag, from the leader's second lap.
	var is_dry: bool = weather.track_water_pct <= 20.0 and weather.rain_intensity <= 0.08
	var is_green: bool = int(race_control["flag"]) == GtTypes.Flag.GREEN
	var leader_lap: int = -1
	for car: GtCar in standings():
		if not car.is_dnf:
			leader_lap = car.lap
			break
	var should_enable: bool = is_dry and is_green and leader_lap >= 1
	if should_enable and not bool(race_control["drs_enabled"]):
		race_control["drs_enabled"] = true
		var ref_car: GtCar = _player_car()
		if ref_car != null:
			push_radio(ref_car, "engineer", "Race Control: DRS has been ENABLED.", true)
	elif not should_enable and bool(race_control["drs_enabled"]):
		race_control["drs_enabled"] = false
		var ref_car: GtCar = _player_car()
		if ref_car != null:
			push_radio(ref_car, "engineer", "Race Control: DRS DISABLED - %s." % ("WET TRACK" if not is_dry else "SAFETY PROTOCOL"), true)
		for car: GtCar in cars:
			car.drs_active = false
			car.drs_eligible = false


func is_under_caution(car: GtCar) -> bool:
	var flag: int = race_control["flag"]
	return restart_pending(car) or flag == GtTypes.Flag.SC or flag == GtTypes.Flag.VSC or (flag == GtTypes.Flag.YELLOW and car.current_sector + 1 == int(race_control["sector"]))


# --- radio and tactics -------------------------------------------------------

## True when the car has not made a routine driver call in the last DRIVER_RADIO_COOLDOWN_S.
func can_push_driver_radio(car_id: int) -> bool:
	return float(driver_radio_cooldown.get(car_id, 0.0)) <= 0.0


func _tick_driver_radio_cooldowns(dt: float) -> void:
	for car_id: int in driver_radio_cooldown.keys():
		var left: float = float(driver_radio_cooldown[car_id]) - dt
		if left <= 0.0:
			driver_radio_cooldown.erase(car_id)
		else:
			driver_radio_cooldown[car_id] = left


## `rival` lets a car outside the player's team speak because the call is about one of the player's cars.
func push_radio(car: GtCar, speaker: String, text: String, force: bool = false, rival: bool = false, reply_to: int = -1) -> void:
	if not force and not rival and car.team_id != player_team_id:
		return
	if speaker == "driver" and not force:
		driver_radio_cooldown[car.id] = DRIVER_RADIO_COOLDOWN_S
	last_radio_time = time
	_radio_counter += 1
	var message: Dictionary = {
		"id": _radio_counter, "car_id": car.id, "code": car.code, "driver_name": car.driver_name,
		"team_color": car.color, "speaker": speaker, "text": text, "time": time, "urgent": force, "rival": rival, "reply_to": reply_to,
	}
	radio_history.append(message)
	if radio_history.size() > 60:
		radio_history.pop_front()
	latest_radio = message
	if speaker == "driver" and not rival and car.team_id == player_team_id and GtRadioReplies.reply_for(text, car, weather.track_water_pct) != "":
		_pending_replies.append({"due": time + RADIO_REPLY_DELAY_S, "car_id": car.id, "reply_to": _radio_counter, "driver_text": text})
	radio_message.emit(message)


## Sends the engineer answers that fell due; the text is made now, from the car as it is now.
func _flush_replies() -> void:
	var waiting: Array[Dictionary] = []
	for reply: Dictionary in _pending_replies:
		if time < float(reply["due"]):
			waiting.append(reply)
			continue
		var car: GtCar = get_car(int(reply["car_id"]))
		if car != null:
			var text: String = GtRadioReplies.reply_for(String(reply["driver_text"]), car, weather.track_water_pct)
			if text != "":
				push_radio(car, "engineer", text, false, false, int(reply["reply_to"]))
	_pending_replies = waiting


## A car of the player team on slicks calls the flooded track once per episode (water over the wet line, until it drops below the inter line).
func _check_flood_radio() -> void:
	var water: float = weather.track_water_pct
	if water < GtForecast.INTER_WATER_PCT:
		_flood_called.clear()
		return
	if water <= GtForecast.WET_WATER_PCT:
		return
	# One call per episode for the whole team: the first eligible car speaks, its team mates are marked as told,
	# so two calls (and two replies) never land in the same tick on the two radio cards.
	var speaker: GtCar = null
	for car: GtCar in cars:
		if car.team_id != player_team_id or car.is_dnf or car.finished_at >= 0.0 or not GtTypes.is_slick(car.compound):
			continue
		if _flood_called.has(car.id):
			continue
		if speaker == null and can_push_driver_radio(car.id):
			speaker = car
		if speaker != null:
			_flood_called[car.id] = true
	if speaker != null:
		push_radio(speaker, "driver", "Track is flooding, aquaplaning heavily!")


func set_tactic_mode(mode: int) -> void:
	tactic_mode = mode


func set_player_team(team_id: int) -> void:
	player_team_id = team_id
	if not active_teams.has(team_id) or active_teams.size() < 10:
		var total_teams: int = GtData.TEAM_NAMES.size()
		var needed_teams: int = 10
		var selected_teams: Array[int] = [team_id]
		var rivals: Array[int] = []
		for t: int in range(total_teams):
			if t != team_id:
				rivals.append(t)
		var shuffle_rng := RandomNumberGenerator.new()
		shuffle_rng.seed = race_seed + 777
		for i: int in range(rivals.size() - 1, 0, -1):
			var j: int = shuffle_rng.randi_range(0, i)
			var tmp: int = rivals[i]
			rivals[i] = rivals[j]
			rivals[j] = tmp
		for t: int in rivals:
			if selected_teams.size() >= needed_teams:
				break
			selected_teams.append(t)
		_build_grid(20, race_seed, selected_teams)


func request_pit(car_id: int, compound: int) -> void:
	var car: GtCar = get_car(car_id)
	if car != null and car.finished_at < 0.0 and car.pit == null:
		car.pit_request = compound
		push_radio(car, "engineer", "Box this lap, confirm %s tyres." % GtTypes.COMPOUND_NAME[compound], true)


## Withdraws a box call before the car commits to the pit lane (`pit` is set 120 m out). No penalty: the
## pit approach pace only holds while `pit_request` is set. A repeat BOX suggestion waits 30 s.
func cancel_pit(car_id: int) -> bool:
	var car: GtCar = get_car(car_id)
	if car == null or car.pit != null or car.pit_request < 0 or car.finished_at >= 0.0:
		return false
	car.pit_request = -1
	_suggestion_cooldowns["%d-%d" % [car.id, GtTypes.TacticType.PIT]] = time + 30.0
	push_radio(car, "engineer", "Stay out, stay out! Box call cancelled.", true)
	# An explicit cancel beats a BOX card still open for this car, or AUTO would re-box it at the window end.
	if not latest_suggestion.is_empty() and int(latest_suggestion["car_id"]) == car.id and int(latest_suggestion["type"]) == GtTypes.TacticType.PIT:
		dismiss_suggestion()
	return true


func set_pace_mode(car_id: int, mode: int) -> void:
	var car: GtCar = get_car(car_id)
	if car != null:
		car.pace_mode = clampi(mode, 0, GtTypes.PaceMode.ATTACK)


func set_fuel_mode(car_id: int, mode: int) -> void:
	var car: GtCar = get_car(car_id)
	if car != null:
		car.fuel_mode = clampi(mode, 0, GtTypes.FuelMode.PUSH)


func set_ers_mode(car_id: int, mode: int) -> void:
	var car: GtCar = get_car(car_id)
	if car != null:
		car.ers_mode = clampi(mode, 0, GtTypes.ErsMode.OVERTAKE)


func suggest_tactic(car: GtCar, type: int, action_value: int, action_label: String, description: String) -> void:
	var key: String = "%d-%d" % [car.id, type]
	if time < float(_suggestion_cooldowns.get(key, 0.0)):
		return
	_suggestion_cooldowns[key] = time + 25.0
	_radio_counter += 1
	latest_suggestion = {
		"id": _radio_counter, "car_id": car.id, "code": car.code, "type": type,
		"title": "%s: %s" % [car.code, action_label], "description": description,
		"action_label": action_label, "action_value": action_value, "time": time,
		"deadline": time + SUGGESTION_WINDOW_S,
	}
	push_radio(car, "engineer", description, true)
	suggestion_changed.emit(latest_suggestion)


## Race seconds left on the open suggestion card, 0.0 when there is none.
func suggestion_remaining() -> float:
	if latest_suggestion.is_empty():
		return 0.0
	return maxf(0.0, float(latest_suggestion["deadline"]) - time)


## Window over: AUTO executes the card (unless its car is already boxing), MANUAL just closes it.
func _expire_suggestion() -> void:
	if latest_suggestion.is_empty() or time < float(latest_suggestion["deadline"]):
		return
	var car: GtCar = get_car(int(latest_suggestion["car_id"]))
	var boxing: bool = car == null or car.pit != null or car.pit_request >= 0
	var is_pit: bool = int(latest_suggestion["type"]) == GtTypes.TacticType.PIT
	if tactic_mode == GtTypes.TacticMode.AUTO and not (is_pit and boxing):
		accept_suggestion()
	else:
		dismiss_suggestion()


func accept_suggestion() -> void:
	if latest_suggestion.is_empty():
		return
	var suggestion: Dictionary = latest_suggestion
	var car: GtCar = get_car(int(suggestion["car_id"]))
	if car != null:
		match int(suggestion["type"]):
			GtTypes.TacticType.PIT:
				request_pit(car.id, int(suggestion["action_value"]))
			GtTypes.TacticType.PACE:
				set_pace_mode(car.id, int(suggestion["action_value"]))
			GtTypes.TacticType.FUEL:
				set_fuel_mode(car.id, int(suggestion["action_value"]))
			GtTypes.TacticType.ERS:
				set_ers_mode(car.id, int(suggestion["action_value"]))
		push_radio(car, "engineer", "Affirmative, executing %s." % suggestion["action_label"], true)
	_suggestion_cooldowns["%d-%d" % [suggestion["car_id"], suggestion["type"]]] = time + 40.0
	latest_suggestion = {}
	suggestion_changed.emit(latest_suggestion)


func dismiss_suggestion() -> void:
	if latest_suggestion.is_empty():
		return
	_suggestion_cooldowns["%d-%d" % [latest_suggestion["car_id"], latest_suggestion["type"]]] = time + 30.0
	latest_suggestion = {}
	suggestion_changed.emit(latest_suggestion)


## Strategy desk: at a lap line, rivals decide pit calls themselves; the player's calls become suggestion
## cards (MANUAL closes the card when its window ends, AUTO executes it).
func decide_strategy(car: GtCar) -> void:
	if car.pit != null or car.finished_at >= 0.0:
		return
	var laps_left: int = laps - car.lap
	if laps_left <= 0:
		return
	var is_player: bool = car.team_id == player_team_id
	var water: float = weather.track_water_pct
	var slick: bool = GtTypes.is_slick(car.compound)
	var target: int = -1
	var reason: String = ""
	if water > 45.0 and car.compound != GtTypes.Compound.WET:
		target = GtTypes.Compound.WET
		reason = "Heavy rain on track (%d%% water)." % roundi(water)
	elif water > 18.0 and slick:
		target = GtTypes.Compound.INTERMEDIATE
		reason = "Track is damp (%d%% water)." % roundi(water)
	elif water < 12.0 and not slick:
		target = GtTypes.Compound.HARD if laps_left > 8 else GtTypes.Compound.SOFT
		reason = "Track drying rapidly (%d%% water)." % roundi(water)
	elif car.wear > 0.62 and laps_left > 2 and car.pit_request < 0:
		target = GtTypes.Compound.HARD if laps_left > 12 else (GtTypes.Compound.MEDIUM if laps_left > 6 else GtTypes.Compound.SOFT)
		reason = "Tyre wear critical (%d%%)." % roundi(car.wear * 100.0)
	if target < 0:
		return
	if is_player:
		suggest_tactic(car, GtTypes.TacticType.PIT, target, "BOX FOR %s" % GtTypes.COMPOUND_NAME[target],
			"%s Suggest box this lap for %s tyres." % [reason, GtTypes.COMPOUND_NAME[target]])
	else:
		car.pit_request = target


## The engineer watches the player's cars in every desk mode and raises suggestion cards.
func _check_advisor_tactics() -> void:
	var leader_lap: int = 0
	var order: Array[GtCar] = standings()
	if not order.is_empty():
		leader_lap = order[0].lap
	var laps_left: int = maxi(0, laps - leader_lap)
	var water: float = weather.track_water_pct
	var flag: int = race_control["flag"]
	for car: GtCar in cars:
		if car.team_id != player_team_id or car.finished_at >= 0.0 or car.pit != null or car.is_dnf or car.lap < 0:
			continue
		var slick: bool = GtTypes.is_slick(car.compound)
		if (flag == GtTypes.Flag.SC or flag == GtTypes.Flag.VSC) and car.pit_request < 0 and laps_left > 2 and (car.wear > 0.35 or car.damage > 15.0):
			var compound: int = GtTypes.Compound.HARD if laps_left > 8 else GtTypes.Compound.SOFT
			suggest_tactic(car, GtTypes.TacticType.PIT, compound, "BOX (%s) UNDER SC" % GtTypes.COMPOUND_NAME[compound],
				"Safety Car deployed! Cheap pit stop window open. Suggest box for %s tyres." % GtTypes.COMPOUND_NAME[compound])
			continue
		if car.damage > 20.0 and car.pit_request < 0 and laps_left > 2:
			var compound: int = GtTypes.Compound.HARD if laps_left > 8 else GtTypes.Compound.SOFT
			suggest_tactic(car, GtTypes.TacticType.PIT, compound, "REPAIR WING (%s)" % GtTypes.COMPOUND_NAME[compound],
				"Front wing aero damage (%d%%). Suggest box this lap to replace wing and tyres." % roundi(car.damage))
			continue
		if water > 45.0 and car.compound != GtTypes.Compound.WET and car.pit_request < 0:
			suggest_tactic(car, GtTypes.TacticType.PIT, GtTypes.Compound.WET, "BOX FOR FULL WET",
				"Standing water critical (%d%%). Suggest box immediately for Full WET tyres!" % roundi(water))
			continue
		if water > 18.0 and slick and car.pit_request < 0:
			suggest_tactic(car, GtTypes.TacticType.PIT, GtTypes.Compound.INTERMEDIATE, "BOX FOR INTERMEDIATE",
				"Track damp (%d%% water). Suggest box for Intermediate tyres." % roundi(water))
			continue
		if water < 12.0 and not slick and weather.rain_intensity < 0.04 and car.pit_request < 0 and laps_left > 1:
			var dry: int = GtTypes.Compound.HARD if laps_left > 8 else (GtTypes.Compound.MEDIUM if laps_left > 4 else GtTypes.Compound.SOFT)
			suggest_tactic(car, GtTypes.TacticType.PIT, dry, "BOX FOR %s (DRY LINE)" % GtTypes.COMPOUND_NAME[dry],
				"Track is dry (%d%% water, groove %d%%). Switch to %s slicks!" % [roundi(water), roundi(weather.drying_line_pct), GtTypes.COMPOUND_NAME[dry]])
			continue
		if car.wear > 0.62 and car.pit_request < 0 and laps_left > 1:
			var compound: int = GtTypes.Compound.HARD if laps_left > 8 else GtTypes.Compound.SOFT
			suggest_tactic(car, GtTypes.TacticType.PIT, compound, "BOX FOR %s" % GtTypes.COMPOUND_NAME[compound],
				"Tyre wear at %d%%. Suggest box for %s tyres." % [roundi(car.wear * 100.0), GtTypes.COMPOUND_NAME[compound]])
			continue
		if car.tyre_temp > 114.0 and car.pace_mode != GtTypes.PaceMode.CONSERVE and car.pace_mode != GtTypes.PaceMode.LIGHT:
			suggest_tactic(car, GtTypes.TacticType.PACE, GtTypes.PaceMode.LIGHT, "PACE: LIGHT",
				"Tyre temps critical (%d C). Suggest switching pace to LIGHT to cool tyres." % roundi(car.tyre_temp))
			continue
		if is_under_caution(car):
			continue
		for other: GtCar in cars:
			if other != car and other.finished_at < 0.0 and other.pit == null and not other.is_dnf and other.s > car.s and other.s - car.s < 14.0:
				if car.ers_battery > 35.0 and car.ers_mode != GtTypes.ErsMode.OVERTAKE and car.ers_mode != GtTypes.ErsMode.DEPLOY:
					suggest_tactic(car, GtTypes.TacticType.ERS, GtTypes.ErsMode.OVERTAKE, "DEPLOY OVERTAKE",
						"DRS slipstream behind %s (%.1f m)! Deploy OVERTAKE ERS to pass?" % [other.code, other.s - car.s])
				break


# --- timing --------------------------------------------------------------------

func record_sector_split(car: GtCar, previous_sector: int) -> void:
	var split: float = time - car.sector_entry_time
	car.current_lap_sectors[previous_sector] = split
	car.sector_times[previous_sector] = split
	var best_session: float = best_session_sectors[previous_sector]
	var personal: float = car.personal_best_sectors[previous_sector]
	if best_session < 0.0 or split < best_session:
		best_session_sectors[previous_sector] = split
		car.personal_best_sectors[previous_sector] = split if personal < 0.0 or split < personal else personal
		car.sector_colors[previous_sector] = GtTypes.SectorColor.PURPLE
	elif personal < 0.0 or split < personal:
		car.personal_best_sectors[previous_sector] = split
		car.sector_colors[previous_sector] = GtTypes.SectorColor.GREEN
	else:
		car.sector_colors[previous_sector] = GtTypes.SectorColor.YELLOW


func update_sector_and_speed_trap(car: GtCar) -> void:
	if car.lap < 0:
		return
	var in_lap: float = fposmod(car.s, track.length)
	# Speed trap on the start straight, 480-520 m after the line.
	if in_lap >= 480.0 and in_lap <= 520.0 and car.v > 40.0:
		var kmh: float = snappedf(car.v * 3.6, 0.1)
		car.speed_trap_speed = kmh
		if speed_trap_max.is_empty() or kmh > float(speed_trap_max["speed"]):
			speed_trap_max = {"speed": kmh, "code": car.code, "number": car.number, "team_id": car.team_id}
	var new_sector: int = mini(2, floori(in_lap / track.length * 3.0))
	if new_sector > car.current_sector:
		for sector: int in range(car.current_sector, new_sector):
			record_sector_split(car, sector)
		car.sector_entry_time = time
		car.current_sector = new_sector
	elif new_sector < car.current_sector and floori(car.s / track.length) <= car.lap:
		car.current_sector = new_sector


func track_laps(car: GtCar) -> void:
	var lap_index: int = floori(car.s / track.length)
	if lap_index <= car.lap:
		return
	if car.lap >= 0:
		record_sector_split(car, 2)
		car.last_lap_sectors = car.current_lap_sectors.duplicate()
		car.current_lap_sectors = [-1.0, -1.0, -1.0]
		car.sector_colors = [GtTypes.SectorColor.NONE, GtTypes.SectorColor.NONE, GtTypes.SectorColor.NONE]
		car.sector_entry_time = time
		car.current_sector = 0
		var lap_time: float = time - car.lap_start_time
		car.last_lap = lap_time
		car.best_lap = lap_time if car.best_lap < 0.0 else minf(car.best_lap, lap_time)
		car.tyre_age_laps += 1
		if int(race_control["flag"]) == GtTypes.Flag.SC and standings()[0] == car:
			if int(race_control["sc_laps_remaining"]) > 0:
				race_control["sc_laps_remaining"] = int(race_control["sc_laps_remaining"]) - 1
	else:
		car.sector_entry_time = time
		car.current_sector = 0
	car.lap = lap_index
	car.lap_start_time = time
	if flag_time >= 0.0 and car.finished_at < 0.0 and not car.is_dnf:
		mark_finished(car)
		return
	decide_strategy(car)
