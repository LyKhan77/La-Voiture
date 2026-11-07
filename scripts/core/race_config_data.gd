class_name RaceConfigData
extends RefCounted

## One exhibition draft, retained across scene changes; direct race scenes stay standalone.
const Weather := preload("res://scripts/gt/gt_weather.gd")
const Rng := preload("res://scripts/gt/gt_rng.gd")
const CircuitRegistry := preload("res://scripts/core/circuit_calendar_registry.gd")
const CircuitDataScript := preload("res://scripts/core/circuit_data.gd")
## STREET CHAOS multiplies every incident roll by this (GtRace.incident_rate).
const CHAOS_INCIDENT_RATE: float = 2.5
static var current: RaceConfigData

var selected_team_id: int = 0
var track_id: String = "apex_ring"
## Round of the 12-month calendar this exhibition runs on (see CircuitCalendarRegistry).
var selected_circuit_id: String = "apex_ring"
## 3 (Sprint rounds only), 5, 10 or 15 (Grand Prix rounds); the setup screen enforces which.
var total_laps: int = 5
## 0 sunny, 1 rain?, 2 dynamic wet, 3 monsoon, 4 DYNAMIC (seeded, circuit-weighted forecast).
var weather_preset: int = 0
## 0 day, 1 sunset, 2 night, 3 RANDOM (rolled from race_seed, see resolved_time_of_day()).
var time_of_day: int = 0
## 0 CLEAN PACE (no incidents), 1 FIA STANDARD, 2 STREET CHAOS (more incidents); AI pace is never touched.
var race_dynamics: int = 1
var car1_starting_compound: int = 0
var car2_starting_compound: int = 1
## Start fuel of each player car in kg; negative means "take the crew pick" (GtFuelPlan.crew_pick_kg).
var car1_start_fuel_kg: float = -1.0
var car2_start_fuel_kg: float = -1.0
## New exhibitions roll independently; restarts retain the exact same simulation.
var race_seed: int = randi_range(1, 2147483647)

static func get_config() -> RaceConfigData:
	if current == null:
		current = RaceConfigData.new()
	return current

static func reset() -> RaceConfigData:
	current = RaceConfigData.new()
	return current


## The selected calendar round; an unknown id falls back to Round 01 instead of failing the race.
func get_active_circuit() -> CircuitDataScript:
	var circuit: CircuitDataScript = CircuitRegistry.get_circuit(selected_circuit_id)
	if circuit == null:
		circuit = CircuitRegistry.get_circuit(CircuitRegistry.DEFAULT_CIRCUIT_ID)
	return circuit

## WET (2) and MONSOON (3) start on a flattened wet forecast; DYNAMIC (4) starts wherever its seed says.
func is_wet_preset() -> bool:
	return weather_preset == 2 or weather_preset == 3


## Rerolls the exhibition seed, so the DYNAMIC forecast and a RANDOM time of race change; returns it.
func reroll_seed() -> int:
	var next_seed: int = randi_range(1, 2147483647)
	if next_seed == race_seed:
		next_seed = (race_seed % 2147483640) + 1
	race_seed = next_seed
	return race_seed


## The time of race the weather is built with: RANDOM (3) is rolled from the seed, so a restart repeats it.
func resolved_time_of_day() -> int:
	if time_of_day == 3:
		return Rng.new(race_seed + 77).range_int(0, 2)
	return clampi(time_of_day, 0, 2)


## Circuit-weighted pick for the DYNAMIC preset: a wetter circuit favours the wetter archetypes.
func _dynamic_archetype(seed_value: int) -> int:
	var rain_probability: float = get_active_circuit().rain_probability
	var roll: float = Rng.new(seed_value + 31).next()
	if roll < rain_probability * 0.45:
		return Weather.Archetype.DRY_TO_STORM
	if roll < rain_probability * 0.85:
		return Weather.Archetype.PASSING_SHOWERS
	if roll < rain_probability * 1.15:
		return Weather.Archetype.WET_DRYING
	if roll < rain_probability + 0.25:
		return Weather.Archetype.OVERCAST_GUSTY
	return Weather.Archetype.DRY_SUNNY


func weather_archetype(seed_value: int) -> int:
	match weather_preset:
		4:
			return _dynamic_archetype(seed_value)
		1:
			return Weather.Archetype.DRY_TO_STORM if Rng.new(seed_value).next() < 0.6 else Weather.Archetype.DRY_SUNNY
		2:
			return Weather.Archetype.WET_DRYING
		3:
			return Weather.Archetype.LATE_MONSOON
	return Weather.Archetype.DRY_SUNNY

## Start fuel of player car `car_slot` (0 or 1) for a car burning `fuel_use` kg per lap: the pick, or the crew pick.
func start_fuel_for(car_slot: int, fuel_use: float) -> float:
	var pick: float = car1_start_fuel_kg if car_slot == 0 else car2_start_fuel_kg
	if pick < 0.0:
		return GtFuelPlan.crew_pick_kg(total_laps, fuel_use)
	return GtFuelPlan.clamp_kg(pick)

func apply_to_race(race: GtRace) -> void:
	race.set_player_team(selected_team_id)
	# Qualifying sorts the grid; ids, not array indices, identify the teammates.
	var car1: GtCar = race.get_car(selected_team_id * 2)
	if car1 != null:
		car1.compound = car1_starting_compound
		car1.fuel = start_fuel_for(0, car1.fuel_use)
	var car2: GtCar = race.get_car(selected_team_id * 2 + 1)
	if car2 != null:
		car2.compound = car2_starting_compound
		car2.fuel = start_fuel_for(1, car2.fuel_use)
	var weather: GtWeather = race.weather
	apply_weather(weather)
	race.incidents_enabled = race_dynamics != 0
	race.incident_rate = CHAOS_INCIDENT_RATE if race_dynamics == 2 else 1.0
	# Rivals read the radar too: every wall picks its start tyre with its own strategist, so a marginal grid splits.
	if weather.track_water_pct > 0.0 or is_wet_preset():
		for car: GtCar in race.cars:
			if car.team_id == selected_team_id:
				continue
			var pick: int = GtStrategy.start_compound(weather, total_laps, car, race.strategy_profile(car.team_id))
			# A slick call keeps the grid's own slick choice; only the wet/dry decision is the wall's.
			if not (GtTypes.is_slick(pick) and GtTypes.is_slick(car.compound)):
				car.compound = pick

func make_weather() -> GtWeather:
	var weather := Weather.new(total_laps, race_seed, weather_archetype(race_seed))
	apply_weather(weather)
	return weather

## Shared by the garage forecast and actual grid, including the wet-start overrides.
func apply_weather(weather: GtWeather) -> void:
	# The wet presets flatten the forecast; DYNAMIC (4) keeps GtWeather's own lap-by-lap curve.
	if is_wet_preset():
		for index: int in range(weather.forecast.size()):
			var progress: float = minf(1.0, float(index) / maxf(1.0, float(total_laps - 1)))
			var entry: Dictionary = weather.forecast[index]
			entry["rain_intensity"] = lerpf(0.85, 0.98, progress) if weather_preset == 3 else lerpf(0.18, 0.55, progress)
			entry["water_pct"] = lerpf(72.0, 95.0, progress) if weather_preset == 3 else lerpf(20.0, 55.0, progress)
			entry["cloud_cover"] = 1.0 if weather_preset == 3 else 0.88
			entry["wind_speed"] = 40.0 if weather_preset == 3 else 18.0
		# The live weather follows GtWeather.truth: a reshaped forecast must become the outlook the truth strays from.
		weather.rebase_outlook()
	elif weather_preset == 1 and weather.archetype == Weather.Archetype.DRY_SUNNY:
		# An overcast but genuinely dry 40% branch; no archetype-driven squalls.
		for entry: Dictionary in weather.forecast:
			entry["rain_intensity"] = 0.0
			entry["water_pct"] = 0.0
			entry["cloud_cover"] = 0.8
			entry["wind_speed"] = 20.0
		weather.rebase_outlook()
	var first: Dictionary = weather.forecast[0]
	weather.rain_intensity = first["rain_intensity"]
	weather.track_water_pct = first["water_pct"]
	weather.cloud_cover = first["cloud_cover"]
	weather.wind_speed = first["wind_speed"]
	weather.drying_line_pct = 0.0
	weather.condition_label = Weather.classify_condition(weather.rain_intensity, weather.track_water_pct, weather.cloud_cover)
	weather.time_of_day = Weather.compute_time_of_day(resolved_time_of_day(), 0.0)
