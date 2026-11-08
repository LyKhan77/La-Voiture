class_name GtFuelPlan
extends RefCounted

## What a start load and a refuel are worth: the crew's suggested start fuel (shown in the garage, used by every
## rival), the clamp every chosen load goes through, and the target a pit stop fills to. Fuel is kilograms; burn is
## `GtCar.fuel_use` kg per lap.

## Safety margin on every fuel figure the crew works out (the pit stop has always filled to laps left x 1.08).
const MARGIN: float = 1.08


## A load the tank can hold; anything non-finite is an empty tank.
static func clamp_kg(kg: float) -> float:
	if not is_finite(kg):
		return 0.0
	return clampf(kg, 0.0, GtTypes.TANK_CAP_KG)


## The three start loads the player picks from in the garage. In a race too short for a mandatory stop there is nothing to
## choose: every preset is the full distance.
enum Preset { LIGHT, BALANCED, FULL }

const PRESET_LABEL: Array[String] = ["LIGHT", "BALANCED", "FULL"]
## Share of the race distance each preset carries (FULL carries all of it); BALANCED reaches the middle of the stop window.
const LIGHT_DISTANCE: float = 0.30
const BALANCED_DISTANCE: float = 0.50


## The preset that is really in force: out-of-range values clamp, and a race without a mandatory stop is always FULL.
static func effective_preset(preset: int, total_laps: int) -> int:
	if total_laps < GtTypes.MANDATORY_MIN_LAPS:
		return Preset.FULL
	return clampi(preset, Preset.LIGHT, Preset.FULL)


## The load of `preset` for a race of `total_laps` and a car burning `fuel_use` kg per lap.
static func preset_kg(preset: int, total_laps: int, fuel_use: float) -> float:
	var laps_carried: float = float(total_laps)
	match effective_preset(preset, total_laps):
		Preset.LIGHT:
			laps_carried *= LIGHT_DISTANCE
		Preset.BALANCED:
			laps_carried *= BALANCED_DISTANCE
	return clamp_kg(laps_carried * fuel_use * MARGIN)


## What the crew recommends the player (the star in the garage and the default of both cars): the whole distance, so a
## driver who never stops for fuel cannot run dry. The mandatory stop is still owed.
static func crew_preset(_total_laps: int) -> int:
	return Preset.FULL


## The load every AI team carries: a light start that reaches the middle of the stop window (their stop tops it up),
## the full distance below the mandatory-stop length. Their stop plan is built on it (GtStrategy), so it is not the
## player's default. A car that forgets its stop is told to box for fuel in time (GtRace._check_stop_reminders).
static func crew_pick_kg(total_laps: int, fuel_use: float) -> float:
	return preset_kg(Preset.BALANCED, total_laps, fuel_use)


## The load a stop fills to for `laps_left` laps still to run (including the one in progress).
static func refuel_target_kg(laps_left: float, fuel_use: float) -> float:
	return minf(GtTypes.TANK_CAP_KG, laps_left * fuel_use * MARGIN)
