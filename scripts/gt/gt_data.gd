class_name GtData
extends RefCounted

## The 10 teams x 2 drivers of the GT sim: La Voiture names and liveries with the
## reference's car and driver stats (gt-manager `teams.ts`, same order of strength).

const Liveries := preload("res://scripts/car/team_liveries.gd")

const TEAM_NAMES: Array[String] = [
	"Apex Racing", "Neon Drift", "Kurogane GT", "Vanta Motors", "Razorline",
	"Zero Hour", "Oni Works", "Static Speed", "Chrome Syndicate", "Night Shift",
]
const DRIVER_NAMES: Array[String] = [
	"K. Ryu", "S. Ren", "M. Ito", "A. Vale", "J. Cruz",
	"N. Sato", "L. Moreau", "R. Silva", "T. Kade", "E. Novak",
	"H. Mori", "D. Reyes", "V. Sokol", "P. Aoki", "G. Alves",
	"C. Weiss", "B. Tanaka", "F. Duval", "I. Petrov", "O. Mbeki",
]

## Broadcast codes, one per driver slot (unique).
const DRIVER_CODES: Array[String] = [
	"RYU", "REN", "ITO", "VAL", "CRU", "SAT", "MOR", "SIL", "KAD", "NOV",
	"MRI", "REY", "SOK", "AOK", "ALV", "WEI", "TAN", "DUV", "PET", "MBE",
]

## Per team: top speed (m/s), cornering grip, tyre wear rate, fuel kg per lap. Top
## speeds are the reference's scaled so a GT3 tops out near 290 km/h.
const TOP_SPEED: Array[float] = [79.0, 81.5, 78.0, 80.5, 79.5, 81.5, 77.0, 80.5, 79.0, 79.5]
const GRIP: Array[float] = [1.010, 0.985, 1.025, 1.005, 0.995, 0.980, 1.030, 0.990, 1.020, 1.022]
const TYRE_WEAR: Array[float] = [0.98, 1.08, 0.96, 1.02, 0.95, 1.06, 0.88, 1.02, 0.92, 0.99]
const FUEL_USE: Array[float] = [2.9, 3.3, 3.0, 3.2, 2.9, 3.4, 2.7, 3.1, 2.8, 3.0]

## Per driver (team * 2 + slot): skill, consistency, wet skill.
const SKILL: Array[float] = [
	1.012, 1.004, 1.010, 1.002, 1.015, 1.008, 1.014, 1.011, 1.016, 1.006,
	1.009, 1.005, 1.012, 1.003, 1.008, 1.006, 1.017, 1.010, 1.009, 1.005,
]
const CONSISTENCY: Array[float] = [
	0.92, 0.91, 0.89, 0.92, 0.94, 0.90, 0.93, 0.91, 0.95, 0.90,
	0.93, 0.91, 0.94, 0.89, 0.91, 0.92, 0.93, 0.92, 0.90, 0.92,
]
const WET_SKILL: Array[float] = [
	0.93, 0.90, 0.92, 0.88, 0.91, 0.94, 0.89, 0.92, 0.95, 0.91,
	0.90, 0.89, 0.93, 0.88, 0.90, 0.92, 0.96, 0.92, 0.89, 0.91,
]


## Fills `car` with the identity and stats of field slot `slot` (0..19).
static func apply_entry(car: GtCar, slot: int) -> void:
	var team: int = slot / 2
	car.id = slot
	car.team_id = team
	car.team_name = TEAM_NAMES[team]
	car.driver_name = DRIVER_NAMES[slot]
	car.number = slot + 1
	car.code = DRIVER_CODES[slot]
	car.color = Liveries.color_for(team)
	car.skill = SKILL[slot]
	car.consistency = CONSISTENCY[slot]
	car.wet_skill = WET_SKILL[slot]
	car.top_speed = TOP_SPEED[team]
	car.grip = GRIP[team]
	car.tyre_wear_rate = TYRE_WEAR[team]
	car.fuel_use = FUEL_USE[team]
