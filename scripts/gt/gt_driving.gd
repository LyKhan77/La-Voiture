class_name GtDriving
extends RefCounted

## Per-car driving of the GT sim (reference `updateCar`): pace and power modes, DRS,
## slipstream, tyre and fuel models, the racecraft AI (follow, attack, defend, yield,
## blue flag, racing room, side-by-side breaker), the pit lane, lateral steering and
## the chassis angles the 3D car shows. Reads and writes GtCar; rules live in GtRace.

const PitLaneScript := preload("res://scripts/world/pit_lane_complex.gd")

var race: GtRace

# Working values of the car being updated.
var _target: float = 0.0
var _target_lateral: float = 0.0
var _teammate_ahead: GtCar = null
var _blue_flagged: bool = false


func _init(p_race: GtRace) -> void:
	race = p_race


# --- traffic context -----------------------------------------------------------

## For every racing car: the nearest car ahead within 65 m, the nearest behind within
## 18 m, and the cars alongside (within 4.4 m longitudinally and 3.6 m laterally).
func build_contexts(racing: Array[GtCar]) -> Dictionary:
	var contexts: Dictionary = {}
	var length: float = race.track.length
	for car: GtCar in racing:
		var s_a: float = fposmod(car.s, length)
		var closest: float = INF
		var lead_car: GtCar = null
		var closest_behind: float = INF
		var behind_car: GtCar = null
		var side: Array[Dictionary] = []
		for other: GtCar in racing:
			if other == car:
				continue
			var s_b: float = fposmod(other.s, length)
			var signed_ds: float = s_b - s_a
			if signed_ds > length * 0.5:
				signed_ds -= length
			elif signed_ds < -length * 0.5:
				signed_ds += length
			if absf(signed_ds) < 4.4 and absf(other.lateral - car.lateral) < 3.6:
				side.append({"car": other, "signed_ds": signed_ds})
			var dist_ahead: float = s_b - s_a
			if dist_ahead < 0.0:
				dist_ahead += length
			if dist_ahead > 0.01 and dist_ahead < closest and dist_ahead < 65.0:
				closest = dist_ahead
				lead_car = other
			var dist_behind: float = s_a - s_b
			if dist_behind < 0.0:
				dist_behind += length
			if dist_behind > 0.01 and dist_behind < closest_behind and dist_behind < 18.0:
				closest_behind = dist_behind
				behind_car = other
		var lead: Dictionary = {}
		if lead_car != null:
			var lap_diff: int = roundi((lead_car.s - car.s) / length)
			lead = {"car": lead_car, "dist": closest, "lapped_ahead": lap_diff < 0, "lapping_us": lap_diff > 0}
		var behind: Dictionary = {}
		if behind_car != null:
			behind = {"car": behind_car, "dist": closest_behind, "lapping_us": (behind_car.s - car.s) > length - 40.0}
		contexts[car] = {"lead": lead, "behind": behind, "side": side}
	return contexts


# --- tyres ---------------------------------------------------------------------

func tyre_factor(car: GtCar) -> float:
	var w: float = car.wear
	var cliff: float = 0.0
	if w > 0.75:
		cliff = pow((w - 0.75) / 0.25, 1.8) * 0.55
	var base: float = GtTypes.COMPOUND_GRIP[car.compound] * (1.0 - 0.25 * w * w - maxf(0.0, w - 0.7) * 0.6 - cliff)
	if car.is_punctured:
		base *= 0.22
	base = maxf(0.10, base)
	var track: GtTrack = race.track
	var weather: GtWeather = race.weather
	var off_line: float = absf(car.lateral - track.ideal_lateral_at(car.s))
	var water: float = weather.track_water_pct
	if water > 8.0 and car.pit == null and car.side_by_side_timer <= 0.15 and car.collision_hold_timer <= 0.0:
		if off_line < 1.6:
			water = maxf(0.0, water * (1.0 - weather.drying_line_pct / 100.0 * 0.32))
		elif off_line > 1.85:
			water = minf(100.0, water * 1.10)
	var mult: float = 1.0
	match car.compound:
		GtTypes.Compound.SOFT, GtTypes.Compound.MEDIUM, GtTypes.Compound.HARD:
			if water > 12.0:
				mult = maxf(0.40, 1.0 - (water - 12.0) / 60.0 * 0.70)
		GtTypes.Compound.INTERMEDIATE:
			if water < 12.0:
				mult = 0.86
			elif water <= 55.0:
				mult = 1.05 + (car.wet_skill - 0.9) * 0.18
			else:
				mult = maxf(0.68, 1.0 - (water - 55.0) / 45.0 * 0.38)
		_:
			if water < 22.0:
				mult = 0.78
			elif water >= 45.0:
				mult = 1.08 + (car.wet_skill - 0.9) * 0.25
			else:
				mult = 0.94
	if car.tyre_temp < 78.0:
		base *= 0.94
	elif car.tyre_temp > 112.0:
		base *= maxf(0.85, 1.0 - (car.tyre_temp - 112.0) / 25.0 * 0.15)
	return base * mult


# --- the update ------------------------------------------------------------------

func update_car(car: GtCar, ctx: Variant, dt: float) -> void:
	var track: GtTrack = race.track
	var lead: Dictionary = {}
	var behind: Dictionary = {}
	var side_cars: Array = []
	if ctx != null:
		lead = ctx["lead"]
		behind = ctx["behind"]
		side_cars = ctx["side"]
	var finish_s: float = float(race.laps) * track.length

	car.prev_s = car.s
	car.prev_lateral = car.lateral
	var s_in_lap: float = fposmod(car.s, track.length)
	if car.lap < 0:
		car.current_sector = 0

	# Terminal damage retires the car.
	if not car.is_dnf and car.damage >= 95.0:
		car.is_dnf = true
		if car.dnf_reason.is_empty():
			car.dnf_reason = "Terminal Suspension/Aero Damage"
		car.finished_at = race.time
		car.v = 0.0
		car.v_lat = 0.0
		car.lateral = 7.4 if car.lateral >= 0.0 else -7.4
		car.impact_jolt = 1.0
		var terminal_sector: int = car.current_sector + 1
		race.set_flag(GtTypes.Flag.SC, terminal_sector, "SAFETY CAR DEPLOYED - TERMINAL DAMAGE (#%d %s)" % [car.number, car.code], 28.0)
	if car.is_dnf:
		car.v = 0.0
		car.v_lat = 0.0
		car.dnf_timer += dt
		if car.dnf_timer >= 24.0:
			car.is_cleared = true
		return

	if car.incident_cooldown > 0.0:
		car.incident_cooldown -= dt
	if car.collision_hold_timer > 0.0:
		car.collision_hold_timer -= dt
	car.impact_jolt = maxf(0.0, car.impact_jolt - 3.2 * dt)

	if car.spin_timer > 0.0:
		_spin_recovery(car, dt)
		return

	_driver_errors(car, dt)

	# --- pace, fuel and ERS modes
	var pace_mult: float = 1.0
	var wear_rate_mult: float = 1.0
	var fuel_burn_mult: float = 1.0
	var target_temp: float = 92.0
	match car.pace_mode:
		GtTypes.PaceMode.CONSERVE:
			pace_mult = 0.948
			wear_rate_mult = 0.45
			fuel_burn_mult = 0.85
			target_temp = 80.0
		GtTypes.PaceMode.LIGHT:
			pace_mult = 0.978
			wear_rate_mult = 0.72
			fuel_burn_mult = 0.93
			target_temp = 86.0
		GtTypes.PaceMode.AGGRESSIVE:
			pace_mult = 1.025
			wear_rate_mult = 1.45
			fuel_burn_mult = 1.12
			target_temp = 104.0
		GtTypes.PaceMode.ATTACK:
			pace_mult = 1.048
			wear_rate_mult = 2.1
			fuel_burn_mult = 1.25
			target_temp = 116.0
	var top_speed_bonus: float = 0.0
	var accel_bonus: float = 0.0
	if car.fuel_mode == GtTypes.FuelMode.CONSERVE:
		top_speed_bonus -= 2.2
		accel_bonus -= 0.9
		fuel_burn_mult *= 0.80
	elif car.fuel_mode == GtTypes.FuelMode.PUSH:
		top_speed_bonus += 2.6
		accel_bonus += 1.5
		fuel_burn_mult *= 1.25
	var deploying: bool = (car.ers_mode == GtTypes.ErsMode.DEPLOY or car.ers_mode == GtTypes.ErsMode.OVERTAKE) and car.ers_battery > 0.0 and car.v > 12.0 and car.pit == null
	if deploying:
		var drain_rate: float = 24.0 if car.ers_mode == GtTypes.ErsMode.OVERTAKE else 12.0
		car.ers_battery -= minf(car.ers_battery, drain_rate * dt)
		if car.ers_mode == GtTypes.ErsMode.OVERTAKE:
			top_speed_bonus += 6.0
			accel_bonus += 4.5
		else:
			top_speed_bonus += 3.5
			accel_bonus += 2.4
		if car.ers_battery <= 0.0:
			car.ers_mode = GtTypes.ErsMode.NEUTRAL
	elif car.ers_mode == GtTypes.ErsMode.HARVEST:
		top_speed_bonus -= 2.5
		accel_bonus -= 1.2
		car.ers_battery = minf(100.0, car.ers_battery + 4.0 * dt)

	# --- DRS and slipstream
	var was_in_drs: bool = not track.drs_zone_at(car.prev_s).is_empty()
	var in_drs: bool = not track.drs_zone_at(car.s).is_empty()
	if was_in_drs and not in_drs:
		car.drs_eligible = false
		car.drs_active = false
	if in_drs and car.drs_eligible and bool(race.race_control["drs_enabled"]) and car.brake < 0.15 and car.v > 26.0 and car.pit == null:
		car.drs_active = true
		top_speed_bonus += 4.5
		accel_bonus += 1.8
	else:
		car.drs_active = false
	var curv_now: float = track.curvature_at(car.s)
	var under_caution: bool = race.is_under_caution(car)
	car.slipstream_factor = 0.0
	if not under_caution and car.pit == null and not lead.is_empty() and float(lead["dist"]) > 1.8 and float(lead["dist"]) < 25.0 and car.v > 30.0:
		var lead_car: GtCar = lead["car"]
		var lat_align: float = absf(lead_car.lateral - car.lateral)
		if lat_align < 2.2 and absf(curv_now) < 0.009:
			var tow: float = maxf(0.0, (1.0 - absf(float(lead["dist"]) - 9.0) / 16.0) * (1.0 - lat_align / 2.2))
			car.slipstream_factor = tow
			top_speed_bonus += tow * 2.8
			accel_bonus += tow * 1.1
	if car.damage > 0.0:
		top_speed_bonus -= car.damage / 100.0 * 10.0
		fuel_burn_mult *= 1.0 + car.damage / 100.0 * 0.15

	# --- target speed
	var fuel_factor: float = 1.0 - 0.0004 * car.fuel
	var error_factor: float = 0.85 if car.error_timer > 0.0 else 1.0
	var damage_factor: float = 1.0 - car.damage / 100.0 * 0.22
	var pace: float = car.grip * car.skill * tyre_factor(car) * fuel_factor * error_factor * damage_factor * pace_mult
	_target = minf(car.top_speed + top_speed_bonus, track.speed_limit_at(car.s) * pace)
	if car.fuel <= 0.0:
		_target = 0.0
	elif car.fuel_stage == GtTypes.FuelStage.LIMP:
		_target = minf(_target, 20.0)
	elif car.fuel_stage == GtTypes.FuelStage.SPUTTER:
		_target *= 0.75
	if car.is_punctured:
		_target = minf(_target, 15.2)
	if race.weather.track_water_pct > 40.0:
		_target *= maxf(0.70, 1.0 - (race.weather.track_water_pct - 40.0) * 0.004)

	var ideal_lateral: float = track.ideal_lateral_at(car.s)
	_target_lateral = ideal_lateral
	_blue_flagged = false
	var off_line: float = absf(car.lateral - ideal_lateral)
	if absf(curv_now) > 0.006 and off_line > 1.2 and car.pit == null:
		_target *= 1.0 - minf(0.045, (off_line - 1.2) * 0.01)

	_apply_flags(car, lead, ideal_lateral)
	if not under_caution and car.pit == null and car.finished_at < 0.0:
		_defend_and_race(car, lead, behind, curv_now, ideal_lateral, dt)
	if car.overtake_phase == GtTypes.Overtake.YIELDING and not _blue_flagged:
		_target_lateral = ideal_lateral
		if not lead.is_empty() and float(lead["dist"]) > 1.8:
			var ahead_car: GtCar = lead["car"]
			if absf(ahead_car.lateral - car.lateral) < 2.05:
				_target = minf(_target, maxf(0.0, ahead_car.v * 0.99))
	if car.collision_hold_timer > 0.0 and car.pit == null:
		var hold: float = minf(1.0, car.collision_hold_timer / 0.8)
		_target_lateral = _target_lateral * (1.0 - hold) + car.lane_offset * hold
	_racing_room(car, side_cars, dt)
	_pit_logic(car, dt)

	if car.pit == null:
		_target_lateral = track.clamp_to_width(_target_lateral)
		# Clamping to the wall can push the target into a neighbour: shift away from it.
		for entry: Dictionary in side_cars:
			var other: GtCar = entry["car"]
			var diff: float = _target_lateral - other.target_lateral
			if absf(diff) < 2.2:
				var push_dir: float = 1.0 if car.lateral >= other.lateral else -1.0
				var candidate: float = track.clamp_to_width(other.target_lateral + push_dir * 2.25)
				if absf(candidate - other.target_lateral) >= 2.15:
					_target_lateral = candidate
				else:
					other.target_lateral = track.clamp_to_width(_target_lateral - push_dir * 2.25)
	car.target_lateral = _target_lateral
	if car.finished_at >= 0.0:
		_target = minf(_target, 30.0)

	# --- longitudinal step
	var effective_accel: float = GtTypes.ACCEL + accel_bonus
	var brake_rate: float = 38.0 if car.pit != null else GtTypes.BRAKE
	var is_braking: bool = car.v > _target
	var previous_v: float = car.v
	if car.v < _target:
		car.v = minf(_target, car.v + effective_accel * dt)
	else:
		car.v = maxf(_target, car.v - brake_rate * dt)
	var a_long: float = (car.v - previous_v) / maxf(dt, 1.0e-4)
	var ds: float = car.v * dt
	car.s += ds
	if car.pit != null and _teammate_ahead != null and car.pit.phase != GtTypes.PitPhase.OUT and car.pit.phase != GtTypes.PitPhase.EXIT:
		if car.s > _teammate_ahead.s - 7.5:
			car.s = _teammate_ahead.s - 7.5
			car.v = minf(car.v, _teammate_ahead.v)

	_drs_detection(car, lead)
	if is_braking and not deploying and car.ers_battery < 100.0:
		car.ers_battery = minf(100.0, car.ers_battery + (14.0 if car.ers_mode == GtTypes.ErsMode.HARVEST else 8.5) * dt)
	_wear_and_fuel(car, ds, wear_rate_mult, fuel_burn_mult, target_temp, is_braking, curv_now, dt)

	_update_transmission(car)
	_steer_laterally(car, dt)
	_chassis_dynamics(car, curv_now, a_long, dt)
	_pedals_and_telemetry(car, curv_now, is_braking, a_long, dt)

	race.track_laps(car)
	race.update_sector_and_speed_trap(car)
	if car.finished_at < 0.0 and car.s >= finish_s:
		race.mark_finished(car)
		if car.team_id == race.player_team_id:
			race.push_radio(car, "engineer", "Chequered flag! P%d. Solid job today." % (race.standings().find(car) + 1))


# --- parts of the update -------------------------------------------------------------

func _spin_recovery(car: GtCar, dt: float) -> void:
	var track: GtTrack = race.track
	car.spin_timer -= dt
	car.v = maxf(0.0, car.v - 20.0 * dt)
	car.spin_angle += (14.0 - (4.0 - car.spin_timer) * 2.6) * dt
	car.s += car.v * dt
	var slide_dir: float = 1.0 if car.lateral >= 0.0 else -1.0
	car.v_lat = slide_dir * 2.2
	car.lateral = track.clamp_to_width(car.lateral + car.v_lat * dt, 0.4)
	car.yaw_offset = car.spin_angle
	car.chassis_roll = sin(car.spin_angle * 2.0) * 0.12
	car.chassis_pitch = 0.03
	race.track_laps(car)
	race.update_sector_and_speed_trap(car)


func _driver_errors(car: GtCar, dt: float) -> void:
	if race.incidents_enabled and car.error_timer <= 0.0 and car.incident_cooldown <= 0.0 and race.time - race.last_incident_time > 50.0 \
			and car.pit == null and car.finished_at < 0.0 and car.lap >= 0:
		var worn_risk: float = maxf(0.0, car.wear - 0.65) * 3.2
		var wet_mismatch: float = 0.0
		if not (car.compound == GtTypes.Compound.INTERMEDIATE or car.compound == GtTypes.Compound.WET) and race.weather.track_water_pct > 25.0:
			wet_mismatch = (race.weather.track_water_pct - 25.0) / 18.0
		var attack_risk: float = 2.0 if car.pace_mode == GtTypes.PaceMode.ATTACK else (1.4 if car.pace_mode == GtTypes.PaceMode.AGGRESSIVE else 1.0)
		var probability: float = (1.0 - car.consistency) * 0.00045 * attack_risk * (1.0 + worn_risk + wet_mismatch) * dt
		if race.rng.next() < probability:
			race.contacts.solo_incident(car)
	var mistake_risk: float = (1.0 - car.consistency) * (1.5 if race.weather.track_water_pct > 30.0 else 1.0)
	if car.error_timer > 0.0:
		car.error_timer -= dt
	elif race.incidents_enabled and race.rng.next() < mistake_risk * 0.035 * dt:
		car.error_timer = 2.5
		if car.team_id == race.player_team_id and race.time - race.last_radio_time > 30.0 and race.rng.next() < 0.25:
			race.push_radio(car, "driver", "Had a snap of oversteer! Lost some time.")


## Flag speed limits: VSC, safety car queue, yellow sector.
func _apply_flags(car: GtCar, lead: Dictionary, ideal_lateral: float) -> void:
	var flag: int = race.race_control["flag"]
	if flag == GtTypes.Flag.VSC:
		_target = minf(_target, 28.0)
		car.pass_timer = 0.0
		car.defend_timer = 0.0
		car.overtake_phase = GtTypes.Overtake.NONE
	elif flag == GtTypes.Flag.SC:
		_target = minf(_target, 31.0)
		car.pass_timer = 0.0
		car.defend_timer = 0.0
		car.overtake_phase = GtTypes.Overtake.NONE
		_target_lateral = ideal_lateral * 0.35
		var gap_to_sc: float = float(race.safety_car["s"]) - car.s
		if gap_to_sc > -5.0 and gap_to_sc < 24.0:
			_target = minf(_target, maxf(0.0, float(race.safety_car["v"]) * 0.90) if gap_to_sc < 11.0 else float(race.safety_car["v"]))
		if not lead.is_empty() and float(lead["dist"]) < 14.0:
			var ahead: GtCar = lead["car"]
			_target = minf(_target, maxf(0.0, ahead.v * 0.94) if float(lead["dist"]) < 8.5 else ahead.v)
	elif flag == GtTypes.Flag.YELLOW and car.current_sector + 1 == int(race.race_control["sector"]):
		_target *= 0.82
		car.pass_timer = 0.0
		car.defend_timer = 0.0
		car.overtake_phase = GtTypes.Overtake.NONE
		if not lead.is_empty() and float(lead["dist"]) < 10.0:
			var ahead: GtCar = lead["car"]
			if ahead.spin_timer <= 0.0 and not ahead.is_dnf:
				_target = minf(_target, maxf(0.0, ahead.v * 0.98))


## Defending, attacking, yielding and following under green.
func _defend_and_race(car: GtCar, lead: Dictionary, behind: Dictionary, curv_now: float, ideal_lateral: float, dt: float) -> void:
	var track: GtTrack = race.track
	# One-move defending: a faster car closing from 4-16 m behind gets ONE inside line.
	if not behind.is_empty() and float(behind["dist"]) > 3.8 and float(behind["dist"]) < 16.0 and car.defend_timer <= 0.0 and car.pass_timer <= 0.0:
		var chaser: GtCar = behind["car"]
		if chaser.v > car.v + 0.5 or chaser.overtake_phase == GtTypes.Overtake.ATTACKING:
			var inside_dir: float = 1.0 if track.curvature_at(car.s + 35.0) >= 0.0 else -1.0
			car.defend_timer = 3.8
			car.defend_target_lateral = track.clamp_to_width(ideal_lateral + inside_dir * 1.6)
			car.overtake_phase = GtTypes.Overtake.DEFENDING
	if car.defend_timer > 0.0:
		car.defend_timer -= dt
		if car.pass_timer <= 0.0:
			car.overtake_phase = GtTypes.Overtake.DEFENDING
			_target_lateral = car.defend_target_lateral
	# Blue flag: a lapped car with the leader on its tail gives way and eases off 10 %.
	if not behind.is_empty() and bool(behind["lapping_us"]) and float(behind["dist"]) < 15.0:
		var leader: GtCar = behind["car"]
		car.overtake_phase = GtTypes.Overtake.YIELDING
		_blue_flagged = true
		var away: float = signf(car.lateral - leader.lateral)
		if away == 0.0:
			away = 1.0 if ideal_lateral >= 0.0 else -1.0
		_target_lateral = track.clamp_to_width(ideal_lateral + away * 3.0)
		_target *= 0.90
		return
	if lead.is_empty():
		if car.defend_timer <= 0.0:
			car.overtake_phase = GtTypes.Overtake.NONE
		return
	var ahead: GtCar = lead["car"]
	var gap: float = lead["dist"]
	if bool(lead["lapping_us"]):
		car.overtake_phase = GtTypes.Overtake.YIELDING
		_target_lateral = -3.8 if ideal_lateral >= 0.0 else 3.8
		_target = minf(_target, 28.0)
	elif bool(lead["lapped_ahead"]):
		car.overtake_phase = GtTypes.Overtake.ATTACKING
		var alt_line: float = ideal_lateral - 2.8 if ideal_lateral >= 0.0 else ideal_lateral + 2.8
		_target_lateral = ideal_lateral if absf(ahead.lateral - ideal_lateral) > 2.1 else alt_line
	elif car.pass_timer > 0.0:
		car.pass_timer -= dt
		car.overtake_phase = GtTypes.Overtake.ATTACKING
		var inside_sign: float = 1.0 if track.curvature_at(car.s + 30.0) >= 0.0 else -1.0
		var inside_candidate: float = track.clamp_to_width(ideal_lateral + inside_sign * 2.2)
		var outside_candidate: float = track.clamp_to_width(ideal_lateral - inside_sign * 2.6)
		if absf(ahead.lateral - inside_candidate) >= 2.25:
			_target_lateral = inside_candidate
		elif absf(ahead.lateral - outside_candidate) >= 2.25:
			_target_lateral = outside_candidate
		else:
			var side_sign: float = 1.0 if car.lateral >= ahead.lateral else -1.0
			_target_lateral = track.clamp_to_width(ahead.lateral + side_sign * 2.6)
		# The defender holds the line it has (one move).
		if ahead.overtake_phase == GtTypes.Overtake.NONE and ahead.defend_timer <= 0.0:
			ahead.defend_timer = 2.8
			ahead.defend_target_lateral = ahead.lateral
			ahead.overtake_phase = GtTypes.Overtake.DEFENDING
		# No dive-bomb into a tight corner without an overlap.
		if absf(curv_now) > 0.012 and gap > 3.8 and absf(car.lateral - ahead.lateral) < 1.8:
			car.pass_timer = 0.0
			car.overtake_phase = GtTypes.Overtake.YIELDING
		if car.s > ahead.s + 2.2:
			car.pass_timer = 0.0
			car.overtake_phase = GtTypes.Overtake.NONE
			ahead.overtake_phase = GtTypes.Overtake.YIELDING
	elif gap < GtTypes.FOLLOW_GAP and ahead.v < _target:
		var advantage: float = _target - ahead.v
		if race.rng.next() < minf(0.68, advantage / 7.5) * dt:
			car.pass_timer = 4.8
			car.overtake_phase = GtTypes.Overtake.ATTACKING
			if car.ers_battery > 25.0 and race.rng.next() < 0.35:
				car.ers_mode = GtTypes.ErsMode.OVERTAKE
			if car.team_id == race.player_team_id and race.time - race.last_radio_time > 25.0 and race.rng.next() < 0.3:
				race.push_radio(car, "engineer", "Passing %s! Excellent drive." % ahead.code)
		else:
			# Pace behind the car only when in its corridor, not when side by side.
			var same_corridor: bool = absf(ahead.lateral - car.lateral) < 2.05
			if same_corridor and gap > 1.8:
				_target = minf(_target, maxf(0.0, ahead.v * 0.98) if gap < 6.0 else ahead.v)
			if car.defend_timer <= 0.0:
				car.overtake_phase = GtTypes.Overtake.NONE
	elif car.defend_timer <= 0.0:
		car.overtake_phase = GtTypes.Overtake.NONE


## Racing room: never steer into the car alongside; the car with its nose behind lifts.
func _racing_room(car: GtCar, side_cars: Array, dt: float) -> void:
	if car.pit != null:
		return
	if side_cars.is_empty():
		car.side_by_side_timer = maxf(0.0, car.side_by_side_timer - 2.0 * dt)
		return
	car.side_by_side_timer += dt
	for entry: Dictionary in side_cars:
		var other: GtCar = entry["car"]
		var signed_ds: float = entry["signed_ds"]
		var d_lat_now: float = car.lateral - other.lateral
		var side_dir: float = signf(d_lat_now) if absf(d_lat_now) > 0.01 else (1.0 if car.id < other.id else -1.0)
		var required: float = 2.4
		if side_dir > 0.0:
			var min_allowed: float = maxf(other.lateral, other.target_lateral) + required * 0.52
			_target_lateral = maxf(_target_lateral, maxf(other.lateral + required, min_allowed))
		else:
			var max_allowed: float = minf(other.lateral, other.target_lateral) - required * 0.52
			_target_lateral = minf(_target_lateral, minf(other.lateral - required, max_allowed))
		var other_ahead: bool = signed_ds > 0.03 or (absf(signed_ds) <= 0.03 and car.id > other.id)
		if other_ahead and (car.side_by_side_timer > 0.6 or (car.pass_timer <= 0.0 and other.pass_timer <= 0.0)):
			_target *= 0.91 if car.side_by_side_timer > 1.4 else 0.955
		elif not other_ahead:
			_target *= 1.015


func _drs_detection(car: GtCar, lead: Dictionary) -> void:
	var track: GtTrack = race.track
	if bool(race.race_control["drs_enabled"]) and car.pit == null and car.lap >= 0:
		for zone: Dictionary in track.drs_zones:
			var norm_prev: float = fposmod(car.prev_s, track.length)
			var norm_cur: float = fposmod(car.s, track.length)
			var detection: float = zone["detection_s"]
			var crossed: bool = false
			if norm_cur >= norm_prev:
				crossed = norm_prev < detection and norm_cur >= detection
			else:
				crossed = norm_prev < detection or norm_cur >= detection
			if crossed:
				if not lead.is_empty():
					car.drs_eligible = float(lead["dist"]) / maxf(15.0, car.v) <= 1.0
				else:
					car.drs_eligible = false
				break
	elif not bool(race.race_control["drs_enabled"]):
		car.drs_eligible = false


func _wear_and_fuel(car: GtCar, ds: float, wear_rate_mult: float, fuel_burn_mult: float, target_temp: float, is_braking: bool, curv_now: float, dt: float) -> void:
	# After the chequered flag the car only rolls around: nothing wears, nothing burns.
	if car.finished_at >= 0.0:
		return
	var track: GtTrack = race.track
	var weather: GtWeather = race.weather
	var laps_driven: float = ds / track.length
	var wear_inc: float = GtTypes.COMPOUND_WEAR_PER_LAP[car.compound] * car.tyre_wear_rate * laps_driven * wear_rate_mult
	var blister_rate: float = 0.0
	if car.tyre_temp > 115.0:
		blister_rate += (car.tyre_temp - 115.0) * 0.35 * dt
		wear_inc *= 3.5
	var wet_on_dry: bool = (car.compound == GtTypes.Compound.INTERMEDIATE or car.compound == GtTypes.Compound.WET) and weather.track_water_pct < 15.0
	if wet_on_dry:
		blister_rate += 1.2 * dt
		wear_inc *= 3.5
	if car.tyre_temp > 112.0:
		wear_inc *= 1.4
	car.wear = minf(1.0, car.wear + wear_inc)
	car.fuel = maxf(0.0, car.fuel - car.fuel_use * laps_driven * fuel_burn_mult)
	car.fuel_burn_rate = snappedf(car.fuel_use * fuel_burn_mult, 0.01)
	if car.fuel <= 0.0:
		car.fuel_stage = GtTypes.FuelStage.FLAMEOUT
		if not car.is_dnf:
			car.is_dnf = true
			car.dnf_reason = "Out of Fuel"
			car.finished_at = race.time
			race.push_radio(car, "driver", "Engine died! No fuel, no fuel! I'm stopping on the grass!", true)
			var sector: int = car.current_sector + 1
			race.set_flag(GtTypes.Flag.YELLOW, sector, "YELLOW FLAG (SEC %d) - CAR #%d STOPPED (OUT OF FUEL)" % [sector, car.number], 15.0)
		car.v = maxf(0.0, car.v - 8.5 * dt)
	elif car.fuel < 0.4:
		if car.fuel_stage != GtTypes.FuelStage.LIMP and car.fuel_stage != GtTypes.FuelStage.FLAMEOUT:
			race.push_radio(car, "engineer", "ECU Limp Mode active! Conserve what's left to reach the pit box!")
		car.fuel_stage = GtTypes.FuelStage.LIMP
	elif car.fuel < 1.2 and absf(curv_now) > 0.008:
		car.fuel_stage = GtTypes.FuelStage.SPUTTER
	elif car.fuel < 3.0:
		if car.fuel_stage == GtTypes.FuelStage.OPTIMAL:
			race.push_radio(car, "engineer", "Fuel critical! Switch to CONSERVE immediately or we won't see the chequered flag!")
		car.fuel_stage = GtTypes.FuelStage.WARNING
	else:
		car.fuel_stage = GtTypes.FuelStage.OPTIMAL

	# Tyre blow-out: worn out, or cooked at speed.
	if not car.is_punctured and car.pit == null and car.finished_at < 0.0 and not car.is_dnf:
		var overheated: bool = car.wear > 0.85 and car.tyre_temp > 120.0 and car.v > 40.0
		if car.wear >= 0.95 or overheated:
			car.is_punctured = true
			car.punctured_wheel = GtTypes.Wheel.FL if curv_now > 0.0 else GtTypes.Wheel.FR
			car.puncture_distance_driven = 0.0
			race.push_radio(car, "driver", "Puncture! The tyre has delaminated!", true)
			if car.v > 45.0 and race.rng.next() < 0.75:
				car.spin_timer = 1.8
				car.spin_angle = PI * 0.9
				race.push_radio(car, "driver", "I'm spinning! Tyre blew out on the high speed section!", true)
	if car.is_punctured:
		car.puncture_distance_driven += ds
		if car.puncture_distance_driven > track.length and not car.is_dnf:
			car.is_dnf = true
			car.dnf_reason = "Suspension Failure"
			car.finished_at = race.time
			race.push_radio(car, "driver", "Suspension has snapped from the flat tyre! I can't steer, retiring the car!", true)
			var sector: int = car.current_sector + 1
			race.set_flag(GtTypes.Flag.YELLOW, sector, "YELLOW FLAG (SEC %d) - CAR #%d STOPPED (SUSPENSION FAILURE)" % [sector, car.number], 18.0)

	var track_offset: float = (weather.track_temp - 30.0) * 0.35
	var wet_on_dry_heat: float = 9.0 if wet_on_dry and weather.track_water_pct < 12.0 else 0.0
	var water_cooling: float = weather.track_water_pct / 100.0 * 14.0
	var heat: float = car.v / 65.0 * 4.0 + (6.0 if is_braking else 0.0) + track_offset + wet_on_dry_heat - water_cooling
	car.tyre_temp += (target_temp + heat - car.tyre_temp) * minf(1.0, 0.22 * dt)
	car.wheel_blister_pct[0] = minf(100.0, car.wheel_blister_pct[0] + blister_rate)


func _update_transmission(car: GtCar) -> void:
	var kmh: float = car.v * 3.6
	if kmh < 45.0:
		car.gear = 1
		car.rpm = 4000.0 + kmh / 45.0 * 4500.0
	elif kmh < 85.0:
		car.gear = 2
		car.rpm = 4800.0 + (kmh - 45.0) / 40.0 * 4000.0
	elif kmh < 135.0:
		car.gear = 3
		car.rpm = 5000.0 + (kmh - 85.0) / 50.0 * 3800.0
	elif kmh < 185.0:
		car.gear = 4
		car.rpm = 5200.0 + (kmh - 135.0) / 50.0 * 3600.0
	elif kmh < 235.0:
		car.gear = 5
		car.rpm = 5400.0 + (kmh - 185.0) / 50.0 * 3400.0
	else:
		car.gear = 6
		car.rpm = 5600.0 + minf(3200.0, (kmh - 235.0) / 70.0 * 3200.0)


## Lateral velocity follows the target line with a speed limit and a steering gain.
func _steer_laterally(car: GtCar, dt: float) -> void:
	var track: GtTrack = race.track
	var d_lat: float = _target_lateral - car.lateral
	var max_steer: float = 3.8
	if car.spin_timer > 0.0:
		max_steer = 1.2
	elif car.pit != null:
		max_steer = 26.0 if car.pit.phase == GtTypes.PitPhase.ENTRY else 9.5
	elif car.overtake_phase == GtTypes.Overtake.ATTACKING:
		max_steer = 5.2
	var steer_gain: float = 10.0 if car.pit != null else 6.0
	var desired: float = clampf(d_lat * steer_gain, -max_steer, max_steer)
	car.v_lat += (desired - car.v_lat) * minf(1.0, 15.0 * dt)
	car.lateral += car.v_lat * dt
	if car.pit == null:
		var clamped: float = track.clamp_to_width(car.lateral)
		if clamped != car.lateral:
			car.lateral = clamped
			car.v_lat *= 0.2


func _chassis_dynamics(car: GtCar, curv_now: float, a_long: float, dt: float) -> void:
	var heading_yaw: float = atan2(car.v_lat, maxf(10.0, car.v)) if car.v > 2.0 else 0.0
	var slip_yaw: float = (sin(race.time * 14.0) * 0.055 if car.error_timer > 0.0 else 0.0) \
		+ (car.impact_side * car.impact_jolt * 0.075 if car.impact_jolt > 0.02 else 0.0)
	var target_yaw: float = heading_yaw * 1.15 + slip_yaw
	car.yaw_offset += (target_yaw - car.yaw_offset) * minf(1.0, 16.0 * dt)
	car.steer_angle = clampf(curv_now * 14.0 + heading_yaw * 1.35, -0.42, 0.42)
	var centripetal: float = curv_now * car.v * car.v + car.v_lat * 2.2
	var target_roll: float = clampf(centripetal * 0.0022, -0.085, 0.085) \
		+ (sin(race.time * 28.0) * car.impact_jolt * car.impact_side * 0.065 if car.impact_jolt > 0.01 else 0.0)
	car.chassis_roll += (target_roll - car.chassis_roll) * minf(1.0, 14.0 * dt)
	var target_pitch: float = clampf(-a_long * 0.0026, -0.038, 0.052)
	car.chassis_pitch += (target_pitch - car.chassis_pitch) * minf(1.0, 14.0 * dt)


func _pedals_and_telemetry(car: GtCar, curv_now: float, is_braking: bool, a_long: float, dt: float) -> void:
	if car.is_dnf or car.v <= 0.1:
		car.throttle = 0.0
		car.brake = 1.0
	elif car.v < _target - 0.5:
		car.throttle = minf(1.0, maxf(0.2, (_target - car.v) / 8.0))
		car.brake = 0.0
	elif car.v > _target + 0.8:
		car.brake = minf(1.0, maxf(0.2, (car.v - _target) / 10.0))
		car.throttle = 0.0
	else:
		car.throttle = 0.45
		car.brake = 0.0
	if car.brake >= 0.15:
		car.drs_active = false
	car.lateral_g = snappedf(car.v * car.v * curv_now / 9.81, 0.01)
	car.longitudinal_g = snappedf(clampf(a_long / 9.81, -5.0, 2.5), 0.01)

	var base_t: float = car.tyre_temp
	var base_b: float = car.brake_temp
	var lat_load: float = curv_now * 18.0
	var brake_load: float = 6.0 if is_braking else 0.0
	var fl: float = roundf(base_t + (-lat_load * 0.4 if lat_load > 0.0 else -lat_load) + brake_load)
	var fr: float = roundf(base_t + (lat_load * 0.4 if lat_load < 0.0 else lat_load) + brake_load)
	var rl: float = roundf(base_t * 0.96 + (-lat_load * 0.3 if lat_load > 0.0 else -lat_load * 0.7))
	var rr: float = roundf(base_t * 0.96 + (lat_load * 0.3 if lat_load < 0.0 else lat_load * 0.7))
	car.wheel_temp = PackedFloat64Array([fl, fr, rl, rr])
	car.wheel_pressure_psi = PackedFloat64Array([
		snappedf(27.5 + (fl - 90.0) * 0.07, 0.1), snappedf(27.5 + (fr - 90.0) * 0.07, 0.1),
		snappedf(26.8 + (rl - 88.0) * 0.07, 0.1), snappedf(26.8 + (rr - 88.0) * 0.07, 0.1),
	])
	var cooling: float = -15.0 * dt
	var braking_add: float = 25.0 if is_braking else cooling
	var rear_add: float = 18.0 if is_braking else cooling
	car.wheel_brake_temp = PackedFloat64Array([
		roundf(base_b + braking_add), roundf(base_b + braking_add), roundf(base_b * 0.85 + rear_add), roundf(base_b * 0.85 + rear_add),
	])
	var blister: float = car.wheel_blister_pct[0]
	car.wheel_blister_pct = PackedFloat64Array([blister, blister, blister, blister])

	var stress: float = 20.0
	if car.wear > 0.75:
		stress += (car.wear - 0.75) * 80.0
	if car.fuel < 3.0:
		stress += (3.0 - car.fuel) * 15.0
	if car.damage > 0.0:
		stress += car.damage * 0.35
	if car.side_by_side_timer > 0.0:
		stress += 25.0
	if car.is_punctured:
		stress = 100.0
	car.driver_stress = minf(100.0, roundf(stress))
	var confidence: float = 85.0
	if car.damage > 0.0:
		confidence -= car.damage * 0.4
	if car.wear > 0.75:
		confidence -= (car.wear - 0.75) * 60.0
	if car.spin_timer > 0.0:
		confidence -= 35.0
	if car.is_punctured:
		confidence = 10.0
	car.driver_confidence = clampf(roundf(confidence), 5.0, 100.0)
	car.driver_heart_rate = roundf(115.0 + car.v / 75.0 * 35.0 + car.driver_stress / 100.0 * 35.0)


# --- pit lane ------------------------------------------------------------------------

## Distance along the pit lane from Pit Entry; negative on the approach.
func pit_u(car_s: float) -> float:
	return fposmod(car_s - PitLaneScript.ENTRY_S + 300.0, race.track.length) - 300.0


func pit_length() -> float:
	return fposmod(PitLaneScript.EXIT_S - PitLaneScript.ENTRY_S, race.track.length)


func stall_offset(team_id: int) -> float:
	return PitLaneScript.STALL_FIRST_S - PitLaneScript.ENTRY_S + PitLaneScript.STALL_PITCH_M * float(team_id)


## Lateral of the pit lane path at `u`: off the right half of the circuit, along the fast lane and back.
## The cars never aim at the racing line; the same curve shapes the pit lane asphalt.
func fast_lane_at(u: float) -> float:
	return PitLaneScript.lane_lateral_at(u, pit_length())


func enter_pit_lane(car: GtCar, compound: int = -1) -> void:
	var chosen: int = compound if compound >= 0 else (car.pit_request if car.pit_request >= 0 else car.compound)
	var u: float = pit_u(car.s)
	var pit := GtPit.new()
	pit.phase = GtTypes.PitPhase.ENTRY
	pit.start_s = car.s - u # absolute s of the Pit Entry line on this lap
	pit.box_s = pit.start_s + stall_offset(car.team_id)
	pit.compound = chosen
	var has_damage: bool = car.damage > 0.0
	var extra: float = minf(4.2, 1.4 + car.damage / 100.0 * 3.0) if has_damage else 0.0
	pit.duration = GtTypes.PIT_STOP_TIME + extra
	pit.repairing_damage = has_damage
	pit.initial_damage = car.damage
	pit.initial_fuel = car.fuel
	car.pit = pit
	car.pit_request = -1


## Reference `beginPitStop`.
func begin_pit_stop(car: GtCar, compound: int) -> void:
	car.pit_request = compound
	enter_pit_lane(car, compound)


func _pit_logic(car: GtCar, dt: float) -> void:
	_teammate_ahead = null
	var u: float = pit_u(car.s)
	if car.pit_request >= 0 and car.pit == null and car.finished_at < 0.0 and car.lap >= 0:
		# Slow to the limiter before the line and commit 120 m out.
		for other: GtCar in race.cars:
			if other != car and other.team_id == car.team_id and other.pit != null and other.s > car.s - 10.0 and other.s - car.s < 16.0:
				_target = minf(_target, maxf(12.0, other.v * 0.85))
		if u >= -120.0 and u < 0.0:
			enter_pit_lane(car)
		elif u >= -300.0 and u < -120.0:
			car.pass_timer = 0.0
			car.overtake_phase = GtTypes.Overtake.NONE
			_target_lateral = PitLaneScript.EDGE_LATERAL_M
			_target = minf(_target, 38.0)
	var pit: GtPit = car.pit
	if pit == null:
		return
	pit.elapsed += dt
	var rel: float = car.s - pit.start_s
	var dist_to_box: float = pit.box_s - car.s
	for other: GtCar in race.cars:
		if other != car and other.team_id == car.team_id and other.pit != null and other.s >= car.s \
				and (other.pit.phase == GtTypes.PitPhase.ENTRY or other.pit.phase == GtTypes.PitPhase.IN or other.pit.phase == GtTypes.PitPhase.BOX):
			_teammate_ahead = other
			break
	match pit.phase:
		GtTypes.PitPhase.ENTRY:
			# Limiter envelope down to 80 km/h at the line, then onto the lane.
			var to_line: float = maxf(-rel - 1.5, 0.0)
			_target = minf(_target, sqrt(GtTypes.PIT_SPEED * GtTypes.PIT_SPEED + 2.0 * GtTypes.BRAKE * to_line))
			_target_lateral = PitLaneScript.EDGE_LATERAL_M
			if rel >= 0.0:
				pit.phase = GtTypes.PitPhase.IN
		GtTypes.PitPhase.IN:
			_target = minf(_target, GtTypes.PIT_SPEED)
			_target_lateral = fast_lane_at(rel)
			if _teammate_ahead != null:
				# Double stack: hold 8 m behind the stall until the teammate is released.
				var to_queue: float = minf(pit.box_s - PitLaneScript.QUEUE_GAP_M - car.s, _teammate_ahead.s - PitLaneScript.QUEUE_GAP_M - car.s)
				if to_queue <= 24.0:
					_target_lateral = PitLaneScript.STALL_LANE_M + 0.6
					if to_queue > 0.6:
						_target = minf(GtTypes.PIT_SPEED, maxf(1.0, to_queue * 1.3))
					else:
						_target = 0.0
						car.v = 0.0
						car.v_lat = 0.0
			elif dist_to_box <= 18.0:
				pit.phase = GtTypes.PitPhase.BOX
		GtTypes.PitPhase.BOX:
			if _teammate_ahead != null:
				var to_queue: float = minf(pit.box_s - PitLaneScript.QUEUE_GAP_M - car.s, _teammate_ahead.s - PitLaneScript.QUEUE_GAP_M - car.s)
				_target_lateral = PitLaneScript.STALL_LANE_M + 0.6
				if to_queue > 0.6:
					_target = minf(GtTypes.PIT_SPEED, maxf(1.0, to_queue * 1.3))
				else:
					_target = 0.0
					car.v = 0.0
					car.v_lat = 0.0
			else:
				var pull_in: float = 1.0 - clampf((dist_to_box - 1.5) / 16.5, 0.0, 1.0)
				_target_lateral = lerpf(fast_lane_at(rel), PitLaneScript.STALL_LANE_M, pull_in)
				if dist_to_box > 0.4:
					_target = minf(GtTypes.PIT_SPEED, maxf(0.9, dist_to_box * 1.6))
				else:
					_target = 0.0
					if car.v < 0.8:
						_service_car(car, pit, dt)
		GtTypes.PitPhase.OUT:
			_target = GtTypes.PIT_SPEED
			var pull_out: float = clampf((car.s - pit.box_s) / 16.0, 0.0, 1.0)
			_target_lateral = lerpf(PitLaneScript.STALL_LANE_M, fast_lane_at(rel), pull_out)
			if car.s - pit.box_s > 20.0:
				pit.phase = GtTypes.PitPhase.EXIT
		GtTypes.PitPhase.EXIT:
			# The limiter holds to the Pit Exit line; the lane merges back over its last 90 m onto the
			# right half of the circuit, never across the racing line.
			_target = GtTypes.PIT_SPEED
			_target_lateral = fast_lane_at(rel)
			if rel >= pit_length():
				car.pit = null
	# Cars on the fast lane follow the car ahead; the stall lane is never blocked by them.
	if car.pit != null and car.pit.phase != GtTypes.PitPhase.BOX:
		for other: GtCar in race.cars:
			if other == car or other.pit == null or other.s <= car.s or other.s - car.s > 14.0:
				continue
			if absf(other.lateral - car.lateral) < 2.4:
				_target = minf(_target, maxf(0.0, minf(other.v, (other.s - car.s - 6.5) * 1.3)))


## Stopped in the box: tyre swap, fuel and repair run on the stop timer.
func _service_car(car: GtCar, pit: GtPit, dt: float) -> void:
	car.v = 0.0
	car.v_lat = 0.0
	car.s = pit.box_s # parked exactly on the stall
	car.lateral = PitLaneScript.STALL_LANE_M
	pit.timer += dt
	var progress: float = minf(1.0, pit.timer / maxf(0.1, pit.duration))
	pit.wheel_swap_progress = progress
	if progress >= 0.55:
		car.compound = pit.compound
	car.damage = maxf(0.0, pit.initial_damage * (1.0 - progress))
	var needed: float = minf(110.0, maxf(pit.initial_fuel, float(race.laps - car.lap + 1) * car.fuel_use * 1.08))
	car.fuel = pit.initial_fuel + (needed - pit.initial_fuel) * progress
	if pit.timer < pit.duration - 0.4:
		pit.lift_y = minf(0.15, pit.timer * 0.45)
	else:
		pit.lift_y = minf(0.15, maxf(0.0, (pit.duration - pit.timer) * 0.45))
	if pit.timer >= pit.duration:
		car.compound = pit.compound
		car.wear = 0.0
		car.tyre_age_laps = 0
		car.tyre_temp = 85.0
		car.is_punctured = false
		car.punctured_wheel = -1
		car.puncture_distance_driven = 0.0
		var had_damage: bool = pit.repairing_damage or pit.initial_damage > 0.0
		car.damage = 0.0
		car.fuel = needed
		car.fuel_stage = GtTypes.FuelStage.OPTIMAL
		car.stops += 1
		pit.lift_y = 0.0
		pit.wheel_swap_progress = 1.0
		pit.phase = GtTypes.PitPhase.OUT
		race.push_radio(car, "engineer", "Good stop: %.1fs.%s Out now, watch pit exit." % [pit.timer, " Wing replaced," if had_damage else ""])
