class_name GtContacts
extends RefCounted

## Match collider and incidents of the GT sim (reference `resolveCarCollisions`,
## `handleCarCollisionIncident`, `handleSoloIncident`). Every pair of cars on track
## (20 x 19 / 2 = 190) is checked each tick on the cyclic longitudinal distance and the
## lateral distance; overlapping cars are pushed apart and keep their new lateral lines.

var race: GtRace
var contact_cooldowns: Dictionary = {} # "a_b" -> last contact time
var pairs_checked_last: int = 0
var contacts_last: int = 0

var _kappa: PackedFloat64Array = PackedFloat64Array()


func _init(p_race: GtRace) -> void:
	race = p_race


## Two relaxation passes so three-wide contacts settle without crushing a car on the wall.
func resolve(racing: Array[GtCar], dt: float) -> void:
	var length: float = race.track.length
	pairs_checked_last = 0
	contacts_last = 0
	_kappa.resize(racing.size())
	for index: int in range(racing.size()):
		_kappa[index] = race.track.curvature_at(racing[index].s)
	for pass_index: int in range(2):
		for i: int in range(racing.size()):
			var car_a: GtCar = racing[i]
			if car_a.is_dnf or car_a.pit != null:
				continue
			for j: int in range(i + 1, racing.size()):
				var car_b: GtCar = racing[j]
				if car_b.is_dnf or car_b.pit != null:
					continue
				if pass_index == 0:
					pairs_checked_last += 1
				var ds: float = signed_gap(car_a.s, car_b.s, length)
				var d_lat: float = car_a.lateral - car_b.lateral
				# On a bend a meter of ribbon is a different length of road at another lateral
				# position, and cars face slightly different ways (bend, steering into a line change):
				# scale the gap, widen the width.
				var kappa: float = (_kappa[i] + _kappa[j]) * 0.5
				var scale: float = clampf(1.0 - kappa * (car_a.lateral + car_b.lateral) * 0.5, 0.6, 1.4)
				# The contact itself yaws both cars by 0.045 rad, so that is counted before it happens.
				var yaw_extra: float = absf(sin(car_a.yaw_offset)) + absf(sin(car_b.yaw_offset)) + 0.09
				var width: float = GtTypes.CAR_WIDTH_M + GtTypes.CAR_LENGTH_M * 0.5 * (sin(minf(absf(kappa * ds), 0.5)) + yaw_extra)
				var reach: float = GtTypes.CAR_LENGTH_M + GtTypes.CAR_WIDTH_M * 0.5 * (yaw_extra + sin(minf(absf(kappa * ds), 0.5)))
				if absf(ds) * scale < reach and absf(d_lat) < width:
					if pass_index == 0:
						contacts_last += 1
					_resolve_pair(car_a, car_b, ds, d_lat, pass_index, dt, scale, width, reach)


## Signed cyclic distance a - b in [-L/2, L/2]; positive when a is ahead of b.
static func signed_gap(s_a: float, s_b: float, length: float) -> float:
	var ds: float = fposmod(s_a, length) - fposmod(s_b, length)
	if ds > length * 0.5:
		ds -= length
	elif ds < -length * 0.5:
		ds += length
	return ds


func _resolve_pair(car_a: GtCar, car_b: GtCar, ds: float, d_lat: float, pass_index: int, dt: float, scale: float, width: float, reach: float) -> void:
	var track: GtTrack = race.track
	var abs_ds: float = absf(ds) * scale
	var abs_d_lat: float = absf(d_lat)
	var pen_s: float = (reach - abs_ds) / scale
	var pen_lat: float = width - abs_d_lat
	var dir: float = signf(d_lat) if abs_d_lat > 0.01 else (1.0 if car_a.id < car_b.id else -1.0)
	if abs_ds > 2.35 and abs_d_lat < 1.35 and pen_s < pen_lat * 1.4:
		# Nose to tail: the rear car is held back, a touch of bump draft goes to the front.
		var front: GtCar = car_a if ds >= 0.0 else car_b
		var rear: GtCar = car_b if ds >= 0.0 else car_a
		if pass_index == 0:
			# Reported before the hold-back below trims the closing speed.
			race.stewards.report_nose_to_tail(rear, front, rear.v - front.v)
		var sep_s: float = pen_s + 0.08
		rear.s -= sep_s * 0.85
		front.s += sep_s * 0.15
		if pass_index == 0:
			front.v = minf(front.top_speed + 4.0, front.v + 0.35)
			rear.v = maxf(16.0, minf(rear.v, front.v * 0.96))
			var dodge: float = -1.0 if rear.lateral >= 0.0 else 1.0
			rear.lane_offset = track.clamp_to_width(front.lateral + dodge * 2.5)
			rear.collision_hold_timer = 1.1
			rear.v_lat += dodge * 1.8
	else:
		# Wheel to wheel: push the doors apart and keep the new lines.
		var half_push: float = pen_lat * 0.55 + 0.04
		car_a.lateral = track.clamp_to_width(car_a.lateral + dir * half_push)
		car_b.lateral = track.clamp_to_width(car_b.lateral - dir * half_push)
		var post_diff: float = absf(car_a.lateral - car_b.lateral)
		if post_diff < width:
			# One car is on the wall: the other gives the rest of the room.
			var deficit: float = width - post_diff + 0.04
			var try_a: float = track.clamp_to_width(car_a.lateral + dir * deficit)
			if absf(try_a - car_b.lateral) >= width - 0.02:
				car_a.lateral = try_a
			else:
				car_b.lateral = track.clamp_to_width(car_b.lateral - dir * deficit)
		if pass_index == 0:
			car_a.lane_offset = track.clamp_to_width(car_a.lateral + dir * 0.45)
			car_b.lane_offset = track.clamp_to_width(car_b.lateral - dir * 0.45)
			car_a.collision_hold_timer = maxf(car_a.collision_hold_timer, 1.1)
			car_b.collision_hold_timer = maxf(car_b.collision_hold_timer, 1.1)
			car_a.target_lateral = track.clamp_to_width(maxf(car_a.target_lateral, car_b.lateral + dir * 2.35))
			if dir < 0.0:
				car_a.target_lateral = track.clamp_to_width(minf(car_a.target_lateral, car_b.lateral - 2.35))
				car_b.target_lateral = track.clamp_to_width(maxf(car_b.target_lateral, car_a.lateral + 2.35))
			else:
				car_b.target_lateral = track.clamp_to_width(minf(car_b.target_lateral, car_a.lateral - 2.35))
			car_a.v_lat = dir * 2.1
			car_b.v_lat = -dir * 2.1
			car_a.yaw_offset += dir * 0.045
			car_b.yaw_offset -= dir * 0.045
			# The car with its nose behind scrubs more speed, which breaks side-by-side locks.
			var a_ahead: bool = ds > 0.02 or (abs_ds <= 0.02 and car_a.id < car_b.id)
			var lead: GtCar = car_a if a_ahead else car_b
			var trail: GtCar = car_b if a_ahead else car_a
			var base_loss: float = minf(lead.v * 0.015, 0.8 * dt)
			lead.v = maxf(16.0, lead.v - base_loss * 0.35)
			trail.v = maxf(16.0, trail.v - maxf(0.35, base_loss * 2.4))
	if pass_index == 0:
		car_a.impact_jolt = minf(1.0, car_a.impact_jolt + 0.38)
		car_a.impact_side = dir
		car_b.impact_jolt = minf(1.0, car_b.impact_jolt + 0.38)
		car_b.impact_side = -dir
		_note_contact(car_a, car_b, ds, d_lat, abs_ds)


func _note_contact(car_a: GtCar, car_b: GtCar, ds: float, d_lat: float, abs_ds: float) -> void:
	var key: String = "%d_%d" % [mini(car_a.id, car_b.id), maxi(car_a.id, car_b.id)]
	var last: float = float(contact_cooldowns.get(key, -999.0))
	if race.time - last <= 6.0 or car_a.incident_cooldown > 0.0 or car_b.incident_cooldown > 0.0 or race.time - race.last_incident_time <= 50.0:
		return
	contact_cooldowns[key] = race.time
	var closing: float = absf(car_a.v - car_b.v)
	var tyre_risk: float = maxf(0.0, car_a.wear - 0.6) + maxf(0.0, car_b.wear - 0.6)
	var wet_risk: float = 1.5 if race.weather.track_water_pct > 30.0 else 1.0
	var risk: float = (2.0 - car_a.consistency - car_b.consistency) * 0.045 * (1.0 + tyre_risk * 0.8) * wet_risk * race.incident_rate
	var mid_s: float = car_a.s - ds * 0.5
	var contact_lat: float = car_b.lateral + d_lat * 0.5
	if race.incidents_enabled and race.rng.next() < risk and (closing > 2.8 or abs_ds < 1.6):
		_collision_incident(car_a, car_b, mid_s, contact_lat)
	else:
		_emit_collision(GtTypes.CollisionKind.RUB, car_a.code, car_b.code, mid_s, contact_lat)
		announce_rub(car_a, car_b)


## A light rub reaches the player team's driver as an urgent call; one call per car every
## GtRace.DRIVER_RADIO_COOLDOWN_S so a pack battle does not flood the banner.
func announce_rub(car_a: GtCar, car_b: GtCar) -> void:
	for pair: Array in [[car_a, car_b], [car_b, car_a]]:
		var car: GtCar = pair[0]
		if car.team_id == race.player_team_id and race.can_push_driver_radio(car.id):
			race.push_radio(car, "driver", "We touched with %s! Check the telemetry!" % (pair[1] as GtCar).code, true)
			race.driver_radio_cooldown[car.id] = GtRace.DRIVER_RADIO_COOLDOWN_S


func _emit_collision(kind: int, code_a: String, code_b: String, s: float, lateral: float) -> void:
	race.latest_collision = {"type": kind, "car_a": code_a, "car_b": code_b, "s": s, "lateral": lateral, "time": race.time}
	race.collision_event.emit(race.latest_collision)


func _sector_of(car: GtCar) -> int:
	return car.current_sector + 1


func _radio_to_player(car: GtCar, text: String) -> void:
	for other: GtCar in race.cars:
		if other.team_id == race.player_team_id:
			race.push_radio(other, "engineer", text, true)
			return


func _collision_incident(car_a: GtCar, car_b: GtCar, s: float, lateral: float) -> void:
	race.last_incident_time = race.time
	car_a.incident_cooldown = 45.0
	car_b.incident_cooldown = 45.0
	race.stewards.report_racing_incident(car_a, car_b)
	var roll: float = race.rng.next()
	var sector: int = _sector_of(car_a)
	var victim: GtCar = car_a if race.rng.next() < 0.5 else car_b
	var other: GtCar = car_b if victim == car_a else car_a
	if roll < 0.68:
		victim.damage = minf(100.0, victim.damage + 12.0 + floorf(race.rng.next() * 12.0))
		victim.error_timer = 2.0
		victim.impact_jolt = 1.0
		_emit_collision(GtTypes.CollisionKind.MINOR, car_a.code, car_b.code, s, lateral)
		if victim.team_id == race.player_team_id:
			race.push_radio(victim, "driver", "We touched with %s! Front wing damage!" % other.code, true)
	elif roll < 0.92:
		victim.start_spin(4.0)
		victim.error_timer = 4.5
		victim.damage = minf(100.0, victim.damage + 20.0)
		victim.wear = minf(1.0, victim.wear + 0.08)
		victim.impact_jolt = 1.0
		_emit_collision(GtTypes.CollisionKind.MINOR, car_a.code, car_b.code, s, lateral)
		race.set_flag(GtTypes.Flag.YELLOW, sector, "YELLOW FLAG (SEC %d) - CONTACT %s & %s" % [sector, car_a.code, car_b.code], 14.0)
		if victim.team_id == race.player_team_id:
			race.push_radio(victim, "driver", "I spun after contact with %s! Tyres cooked!" % other.code, true)
		else:
			_radio_to_player(car_a, "Yellow Flag Sector %d. Contact between %s and %s." % [sector, car_a.code, car_b.code])
	else:
		victim.is_dnf = true
		victim.dnf_reason = "Collision with %s" % other.code
		victim.finished_at = race.time
		victim.v = 0.0
		victim.damage = 100.0
		victim.lateral = 7.4 if victim.lateral >= 0.0 else -7.4
		victim.impact_jolt = 1.0
		_emit_collision(GtTypes.CollisionKind.HEAVY, car_a.code, car_b.code, s, lateral)
		race.set_flag(GtTypes.Flag.SC, sector, "SAFETY CAR DEPLOYED - CRASH SEC %d (%s)" % [sector, victim.code], 32.0)
		if victim.team_id == race.player_team_id:
			race.push_radio(victim, "driver", "Heavy crash! I'm out of the race, suspension sheared off!", true)
		else:
			_radio_to_player(car_a, "Safety Car deployed! %s is stopped on track. Cheap pit stop window open!" % victim.code)


## A driver error without any other car: spin, barrier tap or a heavy wall hit.
func solo_incident(car: GtCar) -> void:
	race.last_incident_time = race.time
	car.incident_cooldown = 45.0
	var sector: int = _sector_of(car)
	var roll: float = race.rng.next()
	if roll < 0.78:
		car.start_spin(3.6)
		car.error_timer = 4.0
		car.impact_jolt = 0.9
		car.wear = minf(1.0, car.wear + 0.06)
		race.set_flag(GtTypes.Flag.YELLOW, sector, "YELLOW FLAG (SEC %d) - CAR #%d SPUN OUT" % [sector, car.number], 12.0)
		if car.team_id == race.player_team_id:
			race.push_radio(car, "driver", "I lost the rear at Turn %d! Spun out, tyres flat-spotted!" % (sector * 4 + 1), true)
		else:
			_radio_to_player(car, "Yellow Flag Sector %d. Car #%d (%s) spun out." % [sector, car.number, car.code])
	elif roll < 0.94:
		car.damage = minf(100.0, car.damage + 25.0 + floorf(race.rng.next() * 15.0))
		car.start_spin(4.0)
		car.error_timer = 4.5
		car.impact_jolt = 1.0
		_emit_collision(GtTypes.CollisionKind.MINOR, car.code, "BARRIER", car.s, car.lateral)
		race.set_flag(GtTypes.Flag.VSC, sector, "VIRTUAL SAFETY CAR - DEBRIS IN SECTOR %d" % sector, 18.0)
		if car.team_id == race.player_team_id:
			race.push_radio(car, "driver", "Hit the barrier! Front wing is broken, handling like a boat!", true)
		else:
			_radio_to_player(car, "Virtual Safety Car deployed! Debris in Sector %d. Reduce delta." % sector)
	else:
		car.is_dnf = true
		car.finished_at = race.time
		car.v = 0.0
		car.damage = 100.0
		car.dnf_reason = "Heavy Barrier Impact T%d" % (sector * 4 + 2)
		car.lateral = 7.4 if car.lateral >= 0.0 else -7.4
		car.impact_jolt = 1.0
		_emit_collision(GtTypes.CollisionKind.HEAVY, car.code, "WALL", car.s, car.lateral)
		race.set_flag(GtTypes.Flag.SC, sector, "SAFETY CAR DEPLOYED - CRASH SEC %d (#%d)" % [sector, car.number], 32.0)
		if car.team_id == race.player_team_id:
			race.push_radio(car, "driver", "Massive crash! I'm into the wall, car is destroyed!", true)
		else:
			_radio_to_player(car, "Safety Car deployed! #%d (%s) heavily in the wall. Cheap pit stop window open!" % [car.number, car.code])
