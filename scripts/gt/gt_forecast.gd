class_name GtForecast
extends RefCounted

## What a pace, fuel or ERS choice (or a tyre choice) will do to the followed car, from the sim's own
## numbers (the multiplier tables in GtTypes that gt_driving.gd reads): tyre life at the finish against the
## 75 % wear cliff, laps of fuel spare, seconds of deploying the battery lasts, and whether a tyre fits the
## weather. The tactical deck turns these into the OK / WATCH / DANGER marks and the tooltips. A verdict
## never locks an option: it only says what the pilot is buying. Not modelled: the extra wear when the
## tyres run over 112 C (x1.4) or 115 C (x3.5) and the fuel burn added by damage.

const OK: int = 0
const WATCH: int = 1
const DANGER: int = 2
const TYRE_DANGER_LIFE: float = 0.15
const TYRE_WATCH_LIFE: float = 0.25
const FUEL_WATCH_LAPS: float = 0.5
const ERS_WATCH_S: float = 6.0
const ERS_DANGER_S: float = 2.0
const MAX_MARGIN_LAPS: float = 99.9
## Same thresholds as GtRace.decide_strategy: wet over 45 % water, intermediate over 18 %.
const WET_WATER_PCT: float = 45.0
const WET_RAIN: float = 0.55
const INTER_WATER_PCT: float = 18.0
const AQUAPLANE_LOOKAHEAD_LAPS: int = 4


static func wear_per_lap(car: GtCar, pace_mode: int) -> float:
	return GtTypes.COMPOUND_WEAR_PER_LAP[car.compound] * car.tyre_wear_rate * GtTypes.PACE_WEAR_MULT[pace_mode]


## Fuel burned per lap in kg.
static func burn_per_lap(car: GtCar, pace_mode: int, fuel_mode: int) -> float:
	return car.fuel_use * GtTypes.PACE_FUEL_MULT[pace_mode] * GtTypes.FUEL_MODE_BURN_MULT[fuel_mode]


## Tyre life (0..1) left when the race ends, driving `laps_left` laps at `pace_mode`.
static func tyre_life_at_finish(car: GtCar, pace_mode: int, laps_left: float) -> float:
	return clampf(1.0 - car.wear - wear_per_lap(car, pace_mode) * laps_left, 0.0, 1.0)


## Laps of fuel left over at the finish (negative = running dry first).
static func fuel_margin_laps(car: GtCar, pace_mode: int, fuel_mode: int, laps_left: float) -> float:
	var burn: float = maxf(burn_per_lap(car, pace_mode, fuel_mode), 0.01)
	return minf(car.fuel / burn - laps_left, MAX_MARGIN_LAPS)


## Seconds of deploying the battery lasts in `ers_mode`; INF when the mode does not deploy.
static func ers_seconds(battery: float, ers_mode: int) -> float:
	var drain: float = GtTypes.ERS_DRAIN_PER_S[ers_mode]
	return INF if drain <= 0.0 else battery / drain


static func laps_left(race: GtRace, car: GtCar) -> float:
	return maxf(0.0, float(race.laps - maxi(car.lap, 0)))


static func recommended_compound(water_pct: float, rain: float) -> int:
	if water_pct > WET_WATER_PCT or rain > WET_RAIN:
		return GtTypes.Compound.WET
	if water_pct > INTER_WATER_PCT:
		return GtTypes.Compound.INTERMEDIATE
	return GtTypes.Compound.MEDIUM


## The tyre a box call without a choice fits: wets or inters by the track water, otherwise the next slick
## in the S-M-H rotation (a wet tyre in the dry goes to MEDIUM). The one rule RaceWeekendWorld.request_pit uses.
static func auto_compound(car: GtCar, water_pct: float) -> int:
	if water_pct > WET_WATER_PCT:
		return GtTypes.Compound.WET
	if water_pct > INTER_WATER_PCT:
		return GtTypes.Compound.INTERMEDIATE
	return (car.compound + 1) % 3 if GtTypes.is_slick(car.compound) else GtTypes.Compound.MEDIUM


## The verdict of option `index` of `kind` ("pace", "fuel" or "ers") against the car as it is now: a
## pace option is judged with the car's fuel mode kept, a fuel option with its pace kept.
## Returns {"severity": OK / WATCH / DANGER, "text": String, "projected": float 0..1 or laps for fuel}.
static func verdict(kind: String, index: int, car: GtCar, laps: float) -> Dictionary:
	match kind:
		"pace":
			return _pace_verdict(index, car, laps)
		"fuel":
			return _fuel_verdict(index, car, laps)
	return _ers_verdict(index, car)


static func _pace_verdict(index: int, car: GtCar, laps: float) -> Dictionary:
	var life: float = tyre_life_at_finish(car, index, laps)
	var rate: float = wear_per_lap(car, index)
	if life < TYRE_DANGER_LIFE:
		if car.wear >= GtTypes.TYRE_CLIFF_WEAR:
			return {"severity": DANGER, "projected": life, "text": "Tyres are already past the cliff (25%): grip is falling."}
		var until: int = maxi(1, roundi((GtTypes.TYRE_CLIFF_WEAR - car.wear) / maxf(rate, 0.0001)))
		return {"severity": DANGER, "projected": life,
			"text": "Tyres pass the cliff (25%%) about %d %s from now, well before the finish." % [until, "lap" if until == 1 else "laps"]}
	if life < TYRE_WATCH_LIFE:
		return {"severity": WATCH, "projected": life, "text": "Tyres end at ~%d%%: right at the cliff (25%%) by the finish." % roundi(life * 100.0)}
	return {"severity": OK, "projected": life, "text": "Tyres end at ~%d%%: above the cliff." % roundi(life * 100.0)}


static func _fuel_verdict(index: int, car: GtCar, laps: float) -> Dictionary:
	var margin: float = fuel_margin_laps(car, car.pace_mode, index, laps)
	if margin < 0.0:
		return {"severity": DANGER, "projected": margin, "text": "Short by %.1f laps of fuel: you will not finish without a stop." % absf(margin)}
	if margin < FUEL_WATCH_LAPS:
		return {"severity": WATCH, "projected": margin, "text": "Only +%.1f laps of fuel spare at the finish. Very tight." % margin}
	return {"severity": OK, "projected": margin, "text": "+%.1f laps of fuel spare at the finish." % margin}


static func _ers_verdict(index: int, car: GtCar) -> Dictionary:
	var drain: float = GtTypes.ERS_DRAIN_PER_S[index]
	var after: float = clampf(car.ers_battery - drain * 3.0, 0.0, 100.0) / 100.0
	if drain <= 0.0:
		var harvesting: bool = index == GtTypes.ErsMode.HARVEST
		return {"severity": OK, "projected": minf(1.0, car.ers_battery / 100.0 + (GtTypes.ERS_HARVEST_PER_S * 3.0 / 100.0 if harvesting else 0.0)),
			"text": "Recharges while you drive." if harvesting else "Battery stays level."}
	var seconds: float = ers_seconds(car.ers_battery, index)
	if seconds < 1.0:
		return {"severity": DANGER, "projected": after, "text": "Battery nearly empty: no boost left."}
	var severity: int = DANGER if seconds < ERS_DANGER_S else (WATCH if seconds < ERS_WATCH_S else OK)
	var text: String = "Battery lasts ~%.0f s of deploying: save it for a pass." % seconds if severity != OK else "Battery lasts ~%.0f s of deploying." % seconds
	return {"severity": severity, "projected": after, "text": text}


## A tyre choice against the weather. `index` 0 is AUTO, 1..5 is `Compound + 1`; `forecast` lists the coming
## laps in order ({"rain_intensity", "water_pct"}, the first entry is one lap ahead).
static func tyre_verdict(index: int, water_pct: float, rain: float, forecast: Array) -> Dictionary:
	var fit: int = recommended_compound(water_pct, rain)
	if index == 0:
		var word: String = "a dry tyre" if fit == GtTypes.Compound.MEDIUM else ("INTERS" if fit == GtTypes.Compound.INTERMEDIATE else "WETS")
		return {"severity": OK, "projected": 0.0, "text": "Auto will fit %s for the weather at your stop." % word}
	var compound: int = index - 1
	if GtTypes.is_slick(compound):
		if fit != GtTypes.Compound.MEDIUM:
			return {"severity": DANGER, "projected": 0.0, "text": "Water on the track now: slicks will aquaplane (3x braking distance)."}
		for ahead: int in range(mini(forecast.size(), AQUAPLANE_LOOKAHEAD_LAPS)):
			var entry: Dictionary = forecast[ahead]
			if recommended_compound(float(entry["water_pct"]), float(entry["rain_intensity"])) != GtTypes.Compound.MEDIUM:
				return {"severity": DANGER, "projected": 0.0, "text": "Water arrives in %d laps: slicks will aquaplane (3x braking distance)." % (ahead + 1)}
		return {"severity": OK, "projected": 0.0, "text": "Fits the current dry forecast."}
	if compound == GtTypes.Compound.INTERMEDIATE:
		if fit == GtTypes.Compound.WET:
			return {"severity": WATCH, "projected": 0.0, "text": "Water is over 45%: WET is the better choice."}
		if fit == GtTypes.Compound.MEDIUM:
			return {"severity": WATCH, "projected": 0.0, "text": "Track is dry: inters will overheat."}
		return {"severity": OK, "projected": 0.0, "text": "Matches the weather now."}
	if fit == GtTypes.Compound.WET:
		return {"severity": OK, "projected": 0.0, "text": "Matches the heavy-rain weather."}
	return {"severity": WATCH, "projected": 0.0, "text": "Not needed yet: wets overheat when the track is not flooded."}
