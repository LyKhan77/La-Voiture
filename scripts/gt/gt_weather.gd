class_name GtWeather
extends RefCounted

## Weather of the GT sim (reference `buildWeatherProfile` + `updateWeather`): a lap by lap
## forecast from one of seven archetypes, live rain, track water, drying groove,
## temperatures and a time of day. Rain and water are the picture's inputs too.

signal advisory(text: String)

enum Archetype { DRY_SUNNY, OVERCAST_GUSTY, DRY_TO_STORM, WET_DRYING, PASSING_SHOWERS, LATE_MONSOON, VARIABLE_CHAOS }
enum TimeOfDay { DAY, SUNSET, NIGHT, TWILIGHT_TRANSITION }

const ARCHETYPE_NAMES: Array[String] = [
	"DRY SUNNY", "OVERCAST GUSTY", "DRY TO STORM", "WET DRYING", "PASSING SHOWERS", "LATE MONSOON", "VARIABLE CHAOS",
]
## Order the seed picks from, as in the reference.
const ARCHETYPE_ORDER: Array[int] = [
	Archetype.DRY_TO_STORM, Archetype.OVERCAST_GUSTY, Archetype.PASSING_SHOWERS, Archetype.WET_DRYING,
	Archetype.LATE_MONSOON, Archetype.VARIABLE_CHAOS, Archetype.DRY_SUNNY,
]

var archetype: int = Archetype.DRY_SUNNY
var condition_label: String = "CLEAR"
var time_of_day: Dictionary = {}
var track_water_pct: float = 0.0
var drying_line_pct: float = 0.0
var rain_intensity: float = 0.0
var cloud_cover: float = 0.2
var wind_speed: float = 10.0
var wind_direction: float = 0.0
var humidity: float = 50.0
var air_temp: float = 24.0
var track_temp: float = 30.0
var lightning_flash: float = 0.0
var forecast: Array[Dictionary] = [] # {lap, rain_intensity, water_pct, cloud_cover, wind_speed}

var base_air_temp: float = 24.0
var phase: float = 0.0

var _last_rain_warning_lap: int = -1
var _last_alert_state: String = ""
var _last_lightning_time: float = -999.0


## `archetype_override` < 0 lets the seed choose.
func _init(laps: int = 10, seed_value: int = 1, archetype_override: int = -1) -> void:
	var rng := GtRng.new(((seed_value * 2654435761) ^ 0x5F3759DF) & 0xFFFFFFFF)
	archetype = archetype_override if archetype_override >= 0 else ARCHETYPE_ORDER[absi(seed_value - 1) % ARCHETYPE_ORDER.size()]
	phase = rng.next() * TAU
	wind_direction = rng.next() * TAU
	var sim_water: float = 0.0
	var total_laps: int = maxi(6, laps + 5)
	var storm_start: int = maxi(2, roundi(float(laps) * (0.25 + rng.next() * 0.25)))
	var storm_duration: int = maxi(2, roundi(float(laps) * (0.30 + rng.next() * 0.25)))
	var storm_peak: float = 0.55 + rng.next() * 0.42
	var shower_1: int = maxi(2, roundi(float(laps) * (0.20 + rng.next() * 0.15)))
	var shower_2: int = maxi(shower_1 + 3, roundi(float(laps) * (0.62 + rng.next() * 0.18)))
	var monsoon_start: int = maxi(3, roundi(float(laps) * (0.55 + rng.next() * 0.18)))

	match archetype:
		Archetype.DRY_SUNNY:
			base_air_temp = roundf(26.0 + rng.next() * 5.0)
		Archetype.OVERCAST_GUSTY:
			base_air_temp = roundf(18.0 + rng.next() * 4.0)
		Archetype.DRY_TO_STORM:
			base_air_temp = roundf(21.0 + rng.next() * 4.0)
		Archetype.WET_DRYING:
			base_air_temp = roundf(16.0 + rng.next() * 4.0)
			sim_water = roundf(32.0 + rng.next() * 34.0)
		Archetype.PASSING_SHOWERS:
			base_air_temp = roundf(19.0 + rng.next() * 4.0)
		Archetype.LATE_MONSOON:
			base_air_temp = roundf(23.0 + rng.next() * 4.0)
		Archetype.VARIABLE_CHAOS:
			base_air_temp = roundf(17.0 + rng.next() * 5.0)
			sim_water = roundf(8.0 + rng.next() * 14.0)

	for l: int in range(1, total_laps + 1):
		var rain: float = 0.0
		var cloud: float = 0.2
		var wind: float = 10.0
		match archetype:
			Archetype.DRY_SUNNY:
				cloud = 0.12 + 0.18 * sin(float(l) * 0.6 + phase) * 0.5 + 0.08
				wind = 7.0 + roundf(rng.next() * 8.0)
			Archetype.OVERCAST_GUSTY:
				cloud = 0.74 + sin(float(l) * 0.7 + phase) * 0.14
				wind = 20.0 + roundf(sin(float(l) * 0.9) * 6.0 + rng.next() * 8.0)
				var mid_lap: int = maxi(2, roundi(float(laps) * 0.45))
				if absi(l - mid_lap) <= 1:
					rain = 0.10 + rng.next() * 0.14
			Archetype.DRY_TO_STORM:
				if l >= storm_start and l < storm_start + storm_duration:
					var p: float = (float(l - storm_start) + 0.5) / float(storm_duration)
					rain = minf(1.0, sin(p * PI) * storm_peak)
					cloud = minf(1.0, 0.78 + rain * 0.22)
					wind = roundf(18.0 + rain * 24.0 + rng.next() * 5.0)
				elif l < storm_start:
					var approach: float = maxf(0.0, 1.0 - float(storm_start - l) / float(maxi(1, storm_start)))
					cloud = 0.32 + approach * 0.48
					wind = roundf(10.0 + approach * 12.0)
				else:
					var clear_prog: float = minf(1.0, float(l - (storm_start + storm_duration)) / 4.0)
					cloud = maxf(0.30, 0.85 - clear_prog * 0.45)
					wind = roundf(16.0 - clear_prog * 6.0)
			Archetype.WET_DRYING:
				if l == 1:
					rain = 0.16 + rng.next() * 0.18
					cloud = 0.88
					wind = 18.0 + roundf(rng.next() * 8.0)
				elif l == 2 and rng.next() > 0.45:
					rain = 0.06 + rng.next() * 0.08
					cloud = 0.76
					wind = 16.0 + roundf(rng.next() * 6.0)
				else:
					var dry_prog: float = minf(1.0, float(l - 2) / maxf(3.0, float(laps) * 0.6))
					cloud = maxf(0.22, 0.72 - dry_prog * 0.48)
					wind = roundf(14.0 + (1.0 - dry_prog) * 8.0)
			Archetype.PASSING_SHOWERS:
				var d1: float = absf(float(l - shower_1))
				var d2: float = absf(float(l - shower_2))
				if d1 <= 1.2:
					rain = (1.0 - d1 / 1.6) * (0.45 + rng.next() * 0.30)
				elif d2 <= 1.4:
					rain = (1.0 - d2 / 1.8) * (0.50 + rng.next() * 0.38)
				cloud = minf(1.0, 0.52 + rain * 0.45 + sin(float(l) * 0.8) * 0.12)
				wind = roundf(16.0 + rain * 20.0 + rng.next() * 6.0)
			Archetype.LATE_MONSOON:
				if l < monsoon_start:
					var build_up: float = maxf(0.0, 1.0 - float(monsoon_start - l) / float(maxi(2, monsoon_start)))
					cloud = 0.25 + build_up * 0.58
					wind = roundf(9.0 + build_up * 16.0)
				else:
					var into_storm: float = minf(1.0, float(l - monsoon_start + 1) / 2.5)
					rain = minf(1.0, (0.68 + rng.next() * 0.30) * into_storm)
					cloud = minf(1.0, 0.88 + into_storm * 0.12)
					wind = roundf(28.0 + rain * 20.0)
			_:
				var wave: float = sin(float(l) * 1.15 + phase) * 0.5 + cos(float(l) * 0.55 - phase) * 0.4
				rain = clampf((wave + 0.25) * 0.68, 0.0, 0.88)
				cloud = clampf(0.62 + wave * 0.32, 0.38, 1.0)
				wind = roundf(15.0 + absf(wave) * 22.0)
		rain = snappedf(clampf(rain, 0.0, 1.0), 0.01)
		cloud = snappedf(clampf(cloud, 0.05, 1.0), 0.01)
		if l == 1 and archetype == Archetype.WET_DRYING:
			sim_water = clampf(sim_water, 28.0, 100.0)
		elif rain > 0.03:
			sim_water = minf(100.0, roundf(sim_water * 0.55 + rain * 78.0 + 8.0))
		else:
			sim_water = maxf(0.0, sim_water - roundf(14.0 + (1.0 - cloud) * 10.0 + wind * 0.35))
		forecast.append({"lap": l, "rain_intensity": rain, "water_pct": roundf(sim_water), "cloud_cover": cloud, "wind_speed": wind})

	var first: Dictionary = forecast[0]
	track_water_pct = first["water_pct"]
	rain_intensity = first["rain_intensity"]
	cloud_cover = first["cloud_cover"]
	wind_speed = first["wind_speed"]
	air_temp = base_air_temp
	var solar: float = (1.0 - cloud_cover * 0.78) * 14.5
	var cool: float = track_water_pct / 100.0 * 9.5 + rain_intensity * 4.5
	track_temp = maxf(base_air_temp + 1.0, base_air_temp + solar - cool)
	humidity = minf(98.0, roundf(42.0 + cloud_cover * 32.0 + rain_intensity * 24.0))
	drying_line_pct = 22.0 if track_water_pct > 10.0 and rain_intensity < 0.15 else 0.0
	var mode: int = TimeOfDay.DAY
	if seed_value % 4 == 0:
		mode = TimeOfDay.NIGHT
	elif archetype == Archetype.LATE_MONSOON or archetype == Archetype.VARIABLE_CHAOS:
		mode = TimeOfDay.TWILIGHT_TRANSITION
	elif seed_value % 3 == 0:
		mode = TimeOfDay.SUNSET
	time_of_day = compute_time_of_day(mode, 0.0)
	condition_label = classify_condition(rain_intensity, track_water_pct, cloud_cover)


static func classify_condition(rain: float, water_pct: float, cloud: float) -> String:
	if rain > 0.68:
		return "THUNDERSTORM"
	if rain > 0.38:
		return "HEAVY RAIN"
	if rain > 0.14:
		return "RAIN SHOWER"
	if rain > 0.03:
		return "LIGHT DRIZZLE"
	if water_pct > 12.0:
		return "DRYING TRACK"
	if cloud > 0.68:
		return "OVERCAST"
	if cloud > 0.32:
		return "PARTLY CLOUDY"
	return "CLEAR"


## Sun, sky and light levels for a mode at a lap progress 0..1.
static func compute_time_of_day(mode: int, lap_progress: float) -> Dictionary:
	var sun_altitude: float = 0.95
	match mode:
		TimeOfDay.DAY:
			sun_altitude = maxf(0.65, 0.95 - lap_progress * 0.15)
		TimeOfDay.SUNSET:
			sun_altitude = maxf(0.12, 0.28 - lap_progress * 0.12)
		TimeOfDay.NIGHT:
			sun_altitude = 0.02
		_:
			sun_altitude = maxf(0.02, 0.32 - lap_progress * 0.32)
	var is_night: bool = sun_altitude < 0.16
	var is_sunset: bool = sun_altitude >= 0.16 and sun_altitude <= 0.4
	var result: Dictionary = {
		"mode": mode, "sun_altitude": sun_altitude, "sky_color": Color("#9ec3e6"), "sun_color": Color("#fffaed"),
		"sun_intensity": 1.15, "hemi_color": Color("#ddeeff"), "ground_color": Color("#3d6634"), "hemi_intensity": 0.55,
		"ambient_exposure": 0.82, "stars_opacity": 0.0, "floodlights": 0.0, "headlights": 0.0,
	}
	if is_night:
		var night_prog: float = minf(1.0, (0.16 - sun_altitude) / 0.14)
		result["sky_color"] = Color("#080c18")
		result["sun_color"] = Color("#94a3b8")
		result["sun_intensity"] = 0.75 + (1.0 - night_prog) * 0.20
		result["hemi_color"] = Color("#829ab1")
		result["ground_color"] = Color("#1f2937")
		result["hemi_intensity"] = 0.65
		result["ambient_exposure"] = 1.05
		result["stars_opacity"] = minf(1.0, night_prog * 1.2)
		result["floodlights"] = 1.0
		result["headlights"] = 1.0
	elif is_sunset:
		var sunset_prog: float = (0.4 - sun_altitude) / 0.24
		result["sky_color"] = Color("#ff7a45")
		result["sun_color"] = Color("#ff6622")
		result["sun_intensity"] = 0.85 - sunset_prog * 0.45
		result["hemi_color"] = Color("#ff9966")
		result["ground_color"] = Color("#2d4424")
		result["hemi_intensity"] = 0.42
		result["ambient_exposure"] = 0.85
		result["stars_opacity"] = maxf(0.0, (sunset_prog - 0.5) * 2.0)
		result["floodlights"] = clampf((sunset_prog - 0.2) * 1.3, 0.0, 1.0)
		result["headlights"] = clampf((sunset_prog - 0.1) * 1.2, 0.0, 1.0)
	return result


## One sim step. `moving_cars_ratio` is the share of the field running above 15 m/s,
## `leader_lap` the leader's continuous lap (1 + s / L), `target_car_code` names the
## radio addressee. Advisories are emitted as `advisory` signals.
func step(dt: float, time: float, moving_cars_ratio: float, leader_lap: float, laps: int) -> void:
	var current_lap: int = maxi(1, floori(leader_lap))
	var lap_frac: float = clampf(leader_lap - float(current_lap), 0.0, 1.0)
	var smooth_u: float = lap_frac * lap_frac * (3.0 - 2.0 * lap_frac)
	var f0: Dictionary = _forecast_for(current_lap)
	if f0.is_empty():
		f0 = forecast[0]
	var f1: Dictionary = _forecast_for(current_lap + 1)
	if f1.is_empty():
		f1 = f0
	var base_rain: float = lerpf(f0["rain_intensity"], f1["rain_intensity"], smooth_u)
	var base_cloud: float = lerpf(f0["cloud_cover"], f1["cloud_cover"], smooth_u)
	var base_wind: float = lerpf(f0["wind_speed"], f1["wind_speed"], smooth_u)

	var squall: float = sin(time * 0.065 + phase) * 0.09 + cos(time * 0.14 + phase * 1.7) * 0.05
	var target_rain: float = 0.0
	if base_rain > 0.02:
		target_rain = clampf(base_rain + squall * (0.45 + base_rain * 0.55), 0.0, 1.0)
	elif (archetype == Archetype.OVERCAST_GUSTY or archetype == Archetype.VARIABLE_CHAOS) and base_cloud > 0.65 and squall > 0.095:
		target_rain = (squall - 0.09) * 2.2
	rain_intensity += (target_rain - rain_intensity) * minf(1.0, 0.32 * dt)
	if rain_intensity < 0.004 and target_rain == 0.0:
		rain_intensity = 0.0

	var target_cloud: float = clampf(maxf(base_cloud, rain_intensity * 0.94) + squall * 0.45, 0.05, 1.0)
	cloud_cover += (target_cloud - cloud_cover) * minf(1.0, 0.25 * dt)
	var gust: float = sin(time * 0.24 + phase) * 3.8 + cos(time * 0.58 - phase) * 2.1
	var target_wind: float = maxf(3.0, base_wind + rain_intensity * 14.0 + gust)
	wind_speed += (target_wind - wind_speed) * minf(1.0, 0.45 * dt)
	wind_direction = fposmod(wind_direction + sin(time * 0.035 + phase) * 0.04 * dt, TAU)

	var rain_inflow: float = pow(rain_intensity, 0.85) * 4.4 if rain_intensity > 0.015 else 0.0
	var gravity_drainage: float = (track_water_pct - 55.0) * 0.028 if track_water_pct > 55.0 else 0.0
	var evap: float = 0.34 + maxf(0.0, track_temp - 18.0) * 0.026 + wind_speed * 0.014 + (1.0 - cloud_cover) * 0.28
	var displacement: float = moving_cars_ratio * (0.48 + track_water_pct / 100.0 * 0.55)
	var drying_factor: float = 1.0 if rain_intensity < 0.12 else 0.32
	var net_rate: float = rain_inflow - (gravity_drainage + (evap + displacement) * drying_factor)
	track_water_pct = clampf(track_water_pct + net_rate * dt, 0.0, 100.0)

	if track_water_pct > 6.0:
		if rain_intensity < 0.28:
			var groove: float = moving_cars_ratio * (2.6 - rain_intensity * 6.5) + (1.0 - cloud_cover) * 0.8
			drying_line_pct = clampf(drying_line_pct + groove * dt, 0.0, 65.0)
		else:
			drying_line_pct = clampf(drying_line_pct - (rain_intensity - 0.25) * 8.5 * dt, 0.0, 65.0)
	else:
		drying_line_pct = maxf(0.0, drying_line_pct - 5.0 * dt)

	var target_air: float = base_air_temp - cloud_cover * 2.6 - rain_intensity * 4.0 + sin(time * 0.02 + phase) * 0.7
	air_temp += (target_air - air_temp) * minf(1.0, 0.12 * dt)
	var solar: float = (1.0 - cloud_cover * 0.78) * 14.5
	var quench: float = track_water_pct / 100.0 * 9.5 + rain_intensity * 4.5
	var wind_cooling: float = maxf(0.0, wind_speed - 12.0) * 0.08
	var target_track: float = maxf(air_temp + 0.8, air_temp + solar - quench - wind_cooling)
	track_temp += (target_track - track_temp) * minf(1.0, 0.16 * dt)
	var target_humidity: float = clampf(40.0 + cloud_cover * 32.0 + rain_intensity * 26.0, 32.0, 99.0)
	humidity += (target_humidity - humidity) * minf(1.0, 0.2 * dt)

	lightning_flash = maxf(0.0, lightning_flash - 3.4 * dt)
	if rain_intensity > 0.58 and time - _last_lightning_time > 9.0:
		if sin(time * 3.7 + phase) * cos(time * 2.3) > 0.86:
			lightning_flash = 1.0
			_last_lightning_time = time

	f0["water_pct"] = roundf(track_water_pct)
	f0["rain_intensity"] = snappedf(rain_intensity, 0.01)
	condition_label = classify_condition(rain_intensity, track_water_pct, cloud_cover)
	_radio_advisories(time, current_lap, f1)
	var lap_progress: float = clampf((leader_lap - 1.0) / float(maxi(1, laps)), 0.0, 1.0)
	time_of_day = compute_time_of_day(int(time_of_day["mode"]), lap_progress)


func _forecast_for(lap: int) -> Dictionary:
	for point: Dictionary in forecast:
		if int(point["lap"]) == lap:
			return point
	return {}


func _radio_advisories(time: float, current_lap: int, f1: Dictionary) -> void:
	if time <= 5.0:
		return
	if rain_intensity > 0.25 and current_lap != _last_rain_warning_lap:
		_last_rain_warning_lap = current_lap
		_last_alert_state = "raining"
		advisory.emit("Weather radar alert: %s hitting the circuit! Track water %d%%, track temp %d C." % [
			condition_label, roundi(track_water_pct), roundi(track_temp)
		])
	elif track_water_pct < 12.0 and rain_intensity < 0.05 and float(f1["rain_intensity"]) >= 0.28 and _last_alert_state != "incoming-%d" % current_lap:
		_last_alert_state = "incoming-%d" % current_lap
		advisory.emit("Radar update: rain front approaching in about 1 lap (wind %d km/h). Prepare INTERMEDIATE tyres." % roundi(wind_speed))
	elif _last_alert_state == "raining" and rain_intensity < 0.04 and track_water_pct < 15.0 and drying_line_pct > 20.0:
		_last_alert_state = "drying_crossover"
		advisory.emit("Dry racing line has formed (%d%% water, track %d C). Slick crossover window is OPEN!" % [roundi(track_water_pct), roundi(track_temp)])
