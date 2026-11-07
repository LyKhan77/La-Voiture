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


## The crew's start load: the full distance in a race too short for a mandatory stop, otherwise a light start that
## carries the car to the middle of the stop window (the stop then tops it up for the rest).
static func crew_pick_kg(total_laps: int, fuel_use: float) -> float:
	var laps_carried: float = float(total_laps)
	if total_laps >= GtTypes.MANDATORY_MIN_LAPS:
		laps_carried *= 0.5
	return clamp_kg(laps_carried * fuel_use * MARGIN)


## The load a stop fills to for `laps_left` laps still to run (including the one in progress).
static func refuel_target_kg(laps_left: float, fuel_use: float) -> float:
	return minf(GtTypes.TANK_CAP_KG, laps_left * fuel_use * MARGIN)
