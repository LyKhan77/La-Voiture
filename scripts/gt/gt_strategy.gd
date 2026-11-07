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


## The strategist of `team_id`: its Engineer rating and personality, constant per team (GtTeamStats). Before Fase 32
## this was drawn from the race seed; `race_seed` stays in the signature so callers do not change, and no longer matters.
static func profile(_race_seed: int, team_id: int) -> Dictionary:
	return GtTeamStats.engineer_profile(team_id)


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
	var stop_cost: float = pit_loss_s(race, lap_s, car.team_id) + stint_cost(car, fresh, 0.0, beliefs, lap_s)
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
## `team_id` >= 0 uses that team's mean crew time (GtTeamStats), -1 the constant GtTypes.PIT_STOP_TIME.
static func pit_loss_s(race: GtRace, lap_s: float, team_id: int = -1) -> float:
	var lane: float = fposmod(float(race.pit_layout["exit_s"]) - float(race.pit_layout["entry_s"]), race.track.length)
	var race_speed: float = race.track.length / maxf(lap_s, 1.0)
	var stop_s: float = GtTypes.PIT_STOP_TIME if team_id < 0 else GtTeamStats.mean_stop_time(team_id)
	return lane / GtTypes.PIT_SPEED - lane / race_speed + stop_s + PIT_SLOW_IN_OUT_S


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


# --- pace, fuel and ERS: the one chooser rivals and the AUTO desk share (Fase 32) -----------------------------------

## The attitude AUTO takes: every rival's profile is a variation of this one (same keys, same function reads them).
const NEUTRAL_TACTIC: Dictionary = {"aggression": 0.5, "fuel_save": 0.5, "ers_greed": 0.5, "cover_gap_s": 2.0, "stop_bias": 0.0}
## Seconds behind a car (or in front of one) that counts as a fight.
const BATTLE_GAP_S: float = 1.5
## Road distance within which another car counts as ahead or behind.
const NEIGHBOUR_RANGE_M: float = 200.0


## The attitude of `team_id` for this race seed, from its own hash stream (never the race rng): how hard it pushes
## (`aggression`), how much fuel it saves (`fuel_save`), how freely it spends the battery (`ers_greed`), how close
## behind a stopping rival it covers (`cover_gap_s`) and whether it stops early (-1) or late (+1) (`stop_bias`).
static func tactic_profile(race_seed: int, team_id: int) -> Dictionary:
	var rng := GtRng.new(((race_seed * 1103515245) ^ ((team_id + 1) * 0x9E3779B1) ^ 0x2B7E1516) & 0x7FFFFFFF)
	return {
		"aggression": rng.next(), "fuel_save": rng.next(), "ers_greed": rng.next(),
		"cover_gap_s": lerpf(1.0, 3.0, rng.next()), "stop_bias": lerpf(-1.0, 1.0, rng.next()),
	}


## Seconds to the nearest racing car ahead of `car` within NEIGHBOUR_RANGE_M of road; INF when there is none.
static func gap_ahead_s(race: GtRace, car: GtCar) -> float:
	return _neighbour_gap_s(race, car, true)


## Seconds to the nearest racing car behind `car` within NEIGHBOUR_RANGE_M of road; INF when there is none.
static func gap_behind_s(race: GtRace, car: GtCar) -> float:
	return _neighbour_gap_s(race, car, false)


static func _neighbour_gap_s(race: GtRace, car: GtCar, ahead: bool) -> float:
	var length: float = race.track.length
	var nearest: float = INF
	for other: GtCar in race.cars:
		if other == car or other.is_dnf or other.pit != null or other.finished_at >= 0.0:
			continue
		var distance: float = fposmod(other.s - car.s, length) if ahead else fposmod(car.s - other.s, length)
		if distance > 0.01 and distance < NEIGHBOUR_RANGE_M and distance < nearest:
			nearest = distance
	return INF if nearest == INF else nearest / maxf(car.v, 25.0)


## Laps the current tyres and fuel have to last: to the finish, or only to the middle of the stop window while the
## mandatory stop is still ahead.
static func stint_laps_left(race: GtRace, car: GtCar) -> float:
	var left: float = GtForecast.laps_left(race, car)
	var progress: float = race.race_progress(car)
	if race.mandatory_stop_required() and not car.mandatory_stop_done and progress < GtTypes.STOP_WINDOW_CLOSE - 0.05:
		var to_mid_window: float = maxf(1.0, (0.5 * (GtTypes.STOP_WINDOW_OPEN + GtTypes.STOP_WINDOW_CLOSE) - progress) * float(race.laps))
		return minf(left, to_mid_window)
	return left


## Wear multiplier a wall budgets for running hot: AGGRESSIVE and ATTACK sit past 112 C where GtDriving wears tyres 1.4
## times faster (measured: ATTACK 0.195 a lap against the table's 0.135). The deck's GtForecast leaves it out.
const HOT_PACE_WEAR_FACTOR: float = 1.5


## Tyre life (0..1) left after `laps` laps at `pace_mode`, with the heat of AGGRESSIVE and ATTACK counted.
static func tyre_life_at_finish(car: GtCar, pace_mode: int, laps: float) -> float:
	var hot: float = HOT_PACE_WEAR_FACTOR if pace_mode >= GtTypes.PaceMode.AGGRESSIVE else 1.0
	return clampf(1.0 - car.wear - GtForecast.wear_per_lap(car, pace_mode) * hot * laps, 0.0, 1.0)


## Pace, fuel and ERS mode for `car` as a pit wall with attitude `tp` would set them now:
## {"pace": PaceMode, "fuel": FuelMode, "ers": ErsMode}. Tyres that cannot take a push are never pushed.
static func choose_modes(race: GtRace, car: GtCar, tp: Dictionary) -> Dictionary:
	var stint: float = stint_laps_left(race, car)
	var left: float = GtForecast.laps_left(race, car)
	var ahead_s: float = gap_ahead_s(race, car)
	var behind_s: float = gap_behind_s(race, car)
	var battling: bool = ahead_s < BATTLE_GAP_S
	var aggression: float = float(tp["aggression"])
	var pace: int = GtTypes.PaceMode.STANDARD
	if tyre_life_at_finish(car, GtTypes.PaceMode.STANDARD, stint) < GtForecast.TYRE_WATCH_LIFE:
		pace = GtTypes.PaceMode.LIGHT
	elif battling and aggression > 0.5 and tyre_life_at_finish(car, GtTypes.PaceMode.AGGRESSIVE, stint) >= GtForecast.TYRE_WATCH_LIFE:
		pace = GtTypes.PaceMode.AGGRESSIVE
	if left <= 2.0 and aggression > 0.7 and tyre_life_at_finish(car, GtTypes.PaceMode.ATTACK, left) >= GtForecast.TYRE_DANGER_LIFE \
			and GtForecast.fuel_margin_laps(car, GtTypes.PaceMode.ATTACK, GtTypes.FuelMode.STANDARD, left) >= 0.3:
		pace = GtTypes.PaceMode.ATTACK
	var margin: float = GtForecast.fuel_margin_laps(car, pace, GtTypes.FuelMode.STANDARD, stint)
	var fuel: int = GtTypes.FuelMode.STANDARD
	if margin < 0.3:
		fuel = GtTypes.FuelMode.CONSERVE
	elif battling and margin > 1.0 and float(tp["fuel_save"]) < 0.5:
		fuel = GtTypes.FuelMode.PUSH
	var battery_floor: float = 35.0 - (float(tp["ers_greed"]) - 0.5) * 20.0
	var ers: int = GtTypes.ErsMode.NEUTRAL
	if ahead_s <= 1.2 and car.ers_battery > battery_floor:
		ers = GtTypes.ErsMode.OVERTAKE
	elif behind_s <= 0.8 and car.ers_battery > battery_floor:
		ers = GtTypes.ErsMode.DEPLOY
	elif car.ers_battery < battery_floor - 5.0 and not battling:
		ers = GtTypes.ErsMode.HARVEST
	return {"pace": pace, "fuel": fuel, "ers": ers}


# --- the mandatory stop: when a wall calls it, covers a rival's stop, pits under caution (Fase 32) ---------------------

## Fuel laps under which a car with its stop still ahead is called in (the pit entry can be up to a lap away).
const STOP_FUEL_DUE_LAPS: float = 2.2
## Wear above which a stop under caution is always taken.
const CAUTION_WEAR_STOP: float = 0.45
## Chance a team with its stop still ahead uses a safety car or VSC for it.
const CAUTION_STOP_CHANCE: float = 0.7


static func _fresh_for(race: GtRace, car: GtCar) -> int:
	var lap_s: float = car.best_lap if car.best_lap > 0.0 else race.track.length / 45.0
	var laps_after: int = maxi(1, race.laps - car.lap - 1)
	return best_fresh_compound(car, [race.weather.track_water_pct], laps_after, lap_s)


## The tyre to fit when `car` is due its mandatory stop, -1 when it is not: inside the laps whose calls count (GtRace.
## stop_window_laps), once the wall's planned share of the distance (attitude `tp`, 25 to 45 %) is run, or the fuel will
## not last to a later stop, or only two laps of the window are left. Never after the window has closed: a stop then no
## longer counts (a car that needs fuel is called by `fuel_call`).
static func mandatory_call(race: GtRace, car: GtCar, tp: Dictionary) -> int:
	if not race.mandatory_stop_required() or car.mandatory_stop_done or car.pit != null or car.pit_request >= 0 \
			or car.is_dnf or car.finished_at >= 0.0 or car.is_punctured:
		return -1
	var window: Vector2i = race.stop_window_laps()
	var lap_number: int = maxi(car.lap, 0) + 1
	if lap_number < window.x or lap_number > window.y:
		return -1
	var planned: float = lerpf(0.25, 0.45, (float(tp["stop_bias"]) + 1.0) * 0.5)
	var burn: float = maxf(GtForecast.burn_per_lap(car, car.pace_mode, car.fuel_mode), 0.01)
	if race.race_progress(car) < planned and car.fuel / burn >= STOP_FUEL_DUE_LAPS and lap_number < window.y - 1:
		return -1
	return _fresh_for(race, car)


## The tyre to fit when `car` will not reach the flag on the fuel it has, -1 otherwise.
static func fuel_call(race: GtRace, car: GtCar) -> int:
	if car.pit != null or car.pit_request >= 0 or car.is_dnf or car.finished_at >= 0.0 or car.is_punctured:
		return -1
	var left: float = GtForecast.laps_left(race, car)
	var burn: float = maxf(GtForecast.burn_per_lap(car, car.pace_mode, car.fuel_mode), 0.01)
	if left > 1.0 and car.fuel / burn < STOP_FUEL_DUE_LAPS and GtForecast.fuel_margin_laps(car, car.pace_mode, car.fuel_mode, left) < 0.0:
		return _fresh_for(race, car)
	return -1


## Whether `car` should answer a stop of the car just behind it (within the wall's cover gap) by boxing too: its own
## stop is still ahead, the window is open and its tyres are three laps old or more.
static func should_cover(race: GtRace, car: GtCar, tp: Dictionary) -> bool:
	if not race.mandatory_stop_required() or car.mandatory_stop_done or car.pit_request >= 0 or car.pit != null or car.tyre_age_laps < 3:
		return false
	var window: Vector2i = race.stop_window_laps()
	var lap_number: int = maxi(car.lap, 0) + 1
	if lap_number < window.x or lap_number > window.y - 1:
		return false
	for other: GtCar in race.cars:
		if other == car or other.pit == null or other.is_dnf:
			continue
		var behind_m: float = fposmod(car.s - other.s, race.track.length)
		if behind_m > 0.0 and behind_m / maxf(car.v, 25.0) <= float(tp["cover_gap_s"]):
			return true
	return false


## The tyre to fit when a safety car or VSC is out and this team uses it for a stop, -1 otherwise: a worn car always
## does, a car with its mandatory stop ahead does with CAUTION_STOP_CHANCE (a roll from its own hash stream, the same for
## the whole caution).
static func caution_call(race: GtRace, car: GtCar) -> int:
	var flag: int = int(race.race_control["flag"])
	if (flag != GtTypes.Flag.SC and flag != GtTypes.Flag.VSC) or car.pit != null or car.pit_request >= 0 or car.is_punctured:
		return -1
	if race.laps - car.lap - 1 < 2:
		return -1
	var wants: bool = car.wear > CAUTION_WEAR_STOP
	if not wants and race.mandatory_stop_required() and not car.mandatory_stop_done:
		var window: Vector2i = race.stop_window_laps()
		var lap_number: int = maxi(car.lap, 0) + 1
		if lap_number >= window.x and lap_number <= window.y:
			var rng := GtRng.new(((race.race_seed * 1103515245) ^ ((car.team_id + 1) * 0x9E3779B1) ^ (race.sc_serial() * 0x85EBCA6B) ^ 0x3C6EF372) & 0x7FFFFFFF)
			wants = rng.next() < CAUTION_STOP_CHANCE
	return _fresh_for(race, car) if wants else -1


## A rival wall's stop call this sector, -1 for none: the mandatory stop when due, a cover, or a stop under caution.
static func rival_stop_call(race: GtRace, car: GtCar, tp: Dictionary) -> int:
	var due: int = mandatory_call(race, car, tp)
	if due >= 0:
		return due
	if should_cover(race, car, tp):
		return _fresh_for(race, car)
	var cautious: int = caution_call(race, car)
	if cautious >= 0:
		return cautious
	return fuel_call(race, car)
