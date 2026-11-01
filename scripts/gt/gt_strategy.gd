class_name GtStrategy
extends RefCounted

## The pit wall's tyre call, made the way a race strategist makes it: for the few laps after this one, what does
## staying out cost against boxing for each other tyre, with the track water each lap is believed to bring? The
## lap cost comes from the sim's own grip tables (GtDriving.worn_grip / compound_water_mult), so the wall and
## the physics agree on which tyre is faster. A rain tyre that would cook to a blow-out before the pit entry is
## boxed at once (the reflex), whatever the forecast says.
##
## Every team has its own strategist (`profile`): how much it trusts the forecast over the track it sees, how it
## leans (+ reads the track wetter and keeps rain tyres longer, - gambles on slicks early), how many sector calls
## it waits before acting, how well it reads the radar and how much it follows the field. Profiles come from a hash
## of the race seed, never the race rng, so a seed still replays the same race.

## Laps after the current one the wall looks ahead.
const HORIZON_LAPS: int = 3
## Share of a lap spent cornering, where grip turns into lap time.
const CORNER_SHARE: float = 0.5
## Seconds a stop must win over the horizon before a wall calls it, so near-ties do not flip the call.
const CALL_MARGIN_S: float = 3.0
## Wear at which a hot tyre lets go (GtDriving: over 85 % and over 120 C), the line the reflex guards.
const BURST_WEAR: float = 0.85
## A stint is over past this wear: box for fresh tyres when two or more laps remain.
const WORN_OUT_WEAR: float = 0.62
## Extra wear of a rain tyre cooking on a dry line below 12 % water, on top of GtDriving.water_wear_mult: full wets
## pass 115 C (x3.5) and 112 C (x1.4); inters run warm (x1.4). Index = compound.
const DRY_LINE_HEAT_WEAR: Array[float] = [1.0, 1.0, 1.0, 1.4, 4.9]
const DRY_LINE_HEAT_WATER_PCT: float = 12.0
## Water points a wall's reading can be swayed by the field (all on rain tyres = +, all on slicks = -).
const HERD_WATER_PCT: float = 10.0
## Seconds slowing to the limiter and back up to speed costs on top of the lane and the stop.
const PIT_SLOW_IN_OUT_S: float = 4.0


## Water points a wall's lean can move its reading either way.
const MAX_RISK_BIAS_PCT: float = 8.0
## A wall that reads the published forecast as it is and leans nowhere (the garage CREW PICK).
const NEUTRAL_PROFILE: Dictionary = {"forecast_trust": 1.0, "risk_bias": 0.0, "reaction_sectors": 0, "read_noise": 0.0, "herd": 0.0}
## Lap time used when no lap has been run (only the ratio of the tyre costs matters to a start choice).
const REFERENCE_LAP_S: float = 90.0


## The strategist of `team_id` for this race seed, from its own rng stream (hashing the ids directly gave teams
## next to each other near-identical strategists).
static func profile(race_seed: int, team_id: int) -> Dictionary:
	var rng := GtRng.new(((race_seed * 1103515245) ^ ((team_id + 1) * 0x9E3779B1) ^ 0x51ED270B) & 0x7FFFFFFF)
	return {
		"forecast_trust": lerpf(0.45, 1.0, rng.next()),
		"risk_bias": lerpf(-MAX_RISK_BIAS_PCT, MAX_RISK_BIAS_PCT, rng.next()),
		"reaction_sectors": mini(2, int(rng.next() * 3.0)),
		"read_noise": rng.next(),
		"herd": rng.next(),
	}


## The tyre call for `car`: {"compound" (-1 = stay out), "urgent", "kind" (why: "cooking", "dry", "easing", "damp",
## "rain" or "wear"; GtRace words the radio call from it), "gain_s" (seconds the stop wins over the horizon)}.
static func plan(race: GtRace, car: GtCar, prof: Dictionary) -> Dictionary:
	var stay: Dictionary = {"compound": -1, "urgent": false, "kind": "", "gain_s": 0.0}
	var laps_after: int = race.laps - car.lap - 1
	if laps_after <= 0 or car.is_dnf or car.finished_at >= 0.0:
		return stay
	var length: float = race.track.length
	var lap_s: float = car.best_lap if car.best_lap > 0.0 else length / 45.0
	var live: float = race.weather.track_water_pct
	var beliefs: Array[float] = []
	for k: int in range(1, mini(HORIZON_LAPS, laps_after) + 1):
		beliefs.append(believed_water(race, car, k, prof))

	# Reflex: a rain tyre that would reach the burst line before the pit entry comes in now.
	var to_line: float = fposmod(float(race.pit_layout["entry_s"]) - fposmod(car.s, length), length)
	var to_entry: float = to_line + (length if to_line < 120.0 else 0.0) # too late to commit: the next entry is a lap on
	var wear_at_entry: float = car.wear + wear_per_lap(car, car.compound, live) * to_entry / length
	var fresh: int = best_fresh_compound(car, beliefs, laps_after, lap_s)
	if not GtTypes.is_slick(car.compound) and wear_at_entry >= BURST_WEAR:
		return {"compound": fresh if fresh != car.compound else _slick_for(laps_after), "urgent": true, "kind": "cooking", "gain_s": 0.0}

	# Weather: staying out against each other tyre over the horizon (the current lap is run either way).
	var wear_next: float = car.wear + wear_per_lap(car, car.compound, live) * to_line / length
	var stay_cost: float = stint_cost(car, car.compound, wear_next, beliefs, lap_s)
	var stop_cost: float = pit_loss_s(race, lap_s) + stint_cost(car, fresh, 0.0, beliefs, lap_s)
	# Slick to slick is a wear call, not a weather call.
	var weather_change: bool = fresh != car.compound and not (GtTypes.is_slick(fresh) and GtTypes.is_slick(car.compound))
	if weather_change and stay_cost - stop_cost > CALL_MARGIN_S:
		var kind: String = "dry"
		if fresh == GtTypes.Compound.WET:
			kind = "rain"
		elif fresh == GtTypes.Compound.INTERMEDIATE:
			kind = "damp" if GtTypes.is_slick(car.compound) else "easing"
		return {"compound": fresh, "urgent": false, "kind": kind, "gain_s": stay_cost - stop_cost}

	# A worn-out stint: fresh tyres for the conditions when two or more laps remain.
	if car.wear > WORN_OUT_WEAR and laps_after >= 2:
		return {"compound": fresh, "urgent": false, "kind": "wear", "gain_s": 0.0}
	return stay


## The tyre to start the race on: the fastest from new over the opening laps as `prof` reads the forecast. The
## garage CREW PICK asks NEUTRAL_PROFILE with a stock car; each rival wall asks with its own profile and car.
static func start_compound(weather: GtWeather, total_laps: int, car: GtCar, prof: Dictionary) -> int:
	var live: float = weather.track_water_pct
	var lean: float = float(prof["risk_bias"])
	var beliefs: Array[float] = [clampf(live + lean, 0.0, 100.0)]
	for k: int in range(1, mini(HORIZON_LAPS, total_laps)):
		var point: Dictionary = GtWeatherOutlook._point(weather, 1 + k)
		var ahead: float = live if point.is_empty() else float(point["water_pct"])
		beliefs.append(clampf(lerpf(live, ahead, float(prof["forecast_trust"])) + lean, 0.0, 100.0))
	return best_fresh_compound(car, beliefs, total_laps, REFERENCE_LAP_S)


## The tyre that runs the believed conditions (non-empty) fastest from new; a slick choice follows the laps left.
static func best_fresh_compound(car: GtCar, beliefs: Array[float], laps_after: int, lap_s: float) -> int:
	var best: int = _slick_for(laps_after)
	var best_cost: float = stint_cost(car, best, 0.0, beliefs, lap_s)
	for compound: int in [GtTypes.Compound.INTERMEDIATE, GtTypes.Compound.WET]:
		var cost: float = stint_cost(car, compound, 0.0, beliefs, lap_s)
		if cost < best_cost:
			best = compound
			best_cost = cost
	return best


static func _slick_for(laps_after: int) -> int:
	if laps_after > 8:
		return GtTypes.Compound.HARD
	return GtTypes.Compound.MEDIUM if laps_after > 4 else GtTypes.Compound.SOFT


## Seconds lost to an ideal tyre over the believed laps, plus a blow-out if the tyre will not last them.
static func stint_cost(car: GtCar, compound: int, start_wear: float, beliefs: Array[float], lap_s: float) -> float:
	var wear: float = start_wear
	var cost: float = 0.0
	for water: float in beliefs:
		var grip: float = GtDriving.worn_grip(compound, wear) * GtDriving.compound_water_mult(compound, water, car.wet_skill)
		if GtTypes.is_slick(compound):
			grip *= lerpf(1.0, GtDriving.aquaplane_brake_mult(water), 0.5)
		cost += lap_s * CORNER_SHARE * (1.0 / maxf(grip, 0.1) - 1.0)
		wear += wear_per_lap(car, compound, water)
		if wear >= BURST_WEAR and not GtTypes.is_slick(compound) and water < DRY_LINE_HEAT_WATER_PCT:
			return cost + lap_s * 2.0 # cooked to a blow-out: a crawl home and a stop anyway
		if wear >= 0.95:
			return cost + lap_s * 2.0
	return cost


## Wear a lap of `water` puts on `compound`, with the dry-line scrub and heat of rain tyres.
static func wear_per_lap(car: GtCar, compound: int, water: float) -> float:
	var rate: float = GtTypes.COMPOUND_WEAR_PER_LAP[compound] * car.tyre_wear_rate * GtDriving.water_wear_mult(compound, water)
	if water < DRY_LINE_HEAT_WATER_PCT:
		rate *= DRY_LINE_HEAT_WEAR[compound]
	return rate


## Seconds a stop costs against staying out: the lane at the limiter instead of racing speed, the stop, in and out.
static func pit_loss_s(race: GtRace, lap_s: float) -> float:
	var lane: float = fposmod(float(race.pit_layout["exit_s"]) - float(race.pit_layout["entry_s"]), race.track.length)
	var race_speed: float = race.track.length / maxf(lap_s, 1.0)
	return lane / GtTypes.PIT_SPEED - lane / race_speed + GtTypes.PIT_STOP_TIME + PIT_SLOW_IN_OUT_S


## Track water this wall believes `k` laps ahead: the forecast weighed against the track now by its trust, read
## with an error that widens with the forecast cone, leaned by its risk and swayed by the field.
static func believed_water(race: GtRace, car: GtCar, k: int, prof: Dictionary) -> float:
	var live: float = race.weather.track_water_pct
	var ahead: float = _forecast_water(race, k)
	var belief: float = lerpf(live, ahead, float(prof["forecast_trust"]))
	var lap: int = GtWeatherOutlook.leader_lap(race, race.track.length) + k
	var sign: float = 1.0 if (hash("%d:%d:%d" % [race.race_seed, car.team_id, lap]) & 1) == 0 else -1.0
	belief += sign * GtWeatherOutlook.cone_spread(k) * float(prof["read_noise"]) * (1.0 - float(prof["forecast_trust"]))
	belief += float(prof["risk_bias"])
	belief += float(prof["herd"]) * (_field_rain_share(race) - 0.5) * 2.0 * HERD_WATER_PCT
	return clampf(belief, 0.0, 100.0)


## The published forecast's water `k` laps after the leader's lap; the live water when there is no row.
static func _forecast_water(race: GtRace, k: int) -> float:
	var point: Dictionary = GtWeatherOutlook._point(race.weather, GtWeatherOutlook.leader_lap(race, race.track.length) + k)
	return race.weather.track_water_pct if point.is_empty() else float(point["water_pct"])


## Share of the running field on rain tyres.
static func _field_rain_share(race: GtRace) -> float:
	var running: int = 0
	var rain: int = 0
	for other: GtCar in race.cars:
		if other.is_dnf or other.finished_at >= 0.0:
			continue
		running += 1
		if not GtTypes.is_slick(other.compound):
			rain += 1
	return 0.5 if running == 0 else float(rain) / float(running)
