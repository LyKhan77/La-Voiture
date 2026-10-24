class_name GtWeatherOutlook
extends RefCounted

## The coming laps of the weather, as rows the HUD draws: rain, track water, the tyre the sim's own thresholds
## ask for (GtForecast.recommended_compound) and a weather state, for the live lap and the laps after it. The
## summary finds the first lap the tyre or the weather changes and the ideal box lap. Pure reading of
## GtWeather: nothing here touches the sim.

const LADDER_LAPS: int = 8
const CHART_LAPS: int = 10
const STATE_NAME: Array[String] = ["DRY", "DRIZZLE", "HEAVY RAIN", "DRYING"]
const DRIZZLE_RAIN: float = 0.08
const HEAVY_RAIN: float = 0.55
const DRYING_WATER_PCT: float = 8.0
const MIN_CONFIDENCE: float = 0.3
const CONFIDENCE_LOSS_PER_LAP: float = 0.085
const STABLE_CONFIDENCE: float = 0.95
## Water points either side of the line at confidence 0: a display heuristic, not a sim probability.
const CONE_WIDTH_PCT: float = 38.0


## The lap the leader is on, which GtWeather.forecast is indexed by.
static func leader_lap(race: GtRace, track_length_m: float) -> int:
	return maxi(1, floori(1.0 + maxf(0.0, race.standings()[0].s) / track_length_m))


## 0 dry, 1 drizzle, 2 heavy rain, 3 drying (wet track, no rain).
static func state_of(rain: float, water_pct: float) -> int:
	if rain > HEAVY_RAIN:
		return 2
	if rain > DRIZZLE_RAIN:
		return 1
	return 3 if water_pct > DRYING_WATER_PCT else 0


static func state_name(state: int) -> String:
	return STATE_NAME[clampi(state, 0, STATE_NAME.size() - 1)]


## How far the forecast `k` laps ahead can be trusted (a display heuristic).
static func confidence(k: int) -> float:
	return maxf(MIN_CONFIDENCE, 1.0 - CONFIDENCE_LOSS_PER_LAP * float(k))


static func cone_spread(k: int) -> float:
	return (1.0 - confidence(k)) * CONE_WIDTH_PCT


## `count + 1` rows for the leader lap `lap` and the laps after it. Row k = 0 is the live weather; rows past the
## last forecast lap repeat the last forecast lap. With `race_laps` > 0, rows after the chequered flag are marked.
static func ahead(weather: GtWeather, lap: int, count: int, race_laps: int = 0) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for k: int in range(count + 1):
		var rain: float = weather.rain_intensity
		var water: float = weather.track_water_pct
		if k > 0:
			var point: Dictionary = _point(weather, lap + k)
			if not point.is_empty():
				rain = float(point["rain_intensity"])
				water = float(point["water_pct"])
		rows.append({
			"k": k, "lap": lap + k, "rain": rain, "water": water,
			"tyre": GtForecast.recommended_compound(water, rain), "state": state_of(rain, water),
			"past_finish": race_laps > 0 and lap + k > race_laps,
		})
	return rows


## {"now", "tyre_change", "state_change" ({} when none), "box_k" (0 when none), "confidence"}. Rows after the
## flag and the live row are not candidates for a change.
static func summary(rows: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {"now": {}, "tyre_change": {}, "state_change": {}, "box_k": 0, "confidence": STABLE_CONFIDENCE}
	if rows.is_empty():
		return result
	var now: Dictionary = rows[0]
	result["now"] = now
	for row: Dictionary in rows:
		if int(row["k"]) == 0 or bool(row["past_finish"]):
			continue
		if (result["tyre_change"] as Dictionary).is_empty() and int(row["tyre"]) != int(now["tyre"]):
			result["tyre_change"] = row
		if (result["state_change"] as Dictionary).is_empty() and int(row["state"]) != int(now["state"]):
			result["state_change"] = row
	if not (result["tyre_change"] as Dictionary).is_empty():
		result["box_k"] = maxi(1, int(result["tyre_change"]["k"]) - 1)
	if not (result["state_change"] as Dictionary).is_empty():
		result["confidence"] = confidence(int(result["state_change"]["k"]))
	return result


## The forecast entry of `target_lap`; the last entry when the forecast ends sooner; {} before the first entry.
static func _point(weather: GtWeather, target_lap: int) -> Dictionary:
	var last: Dictionary = {}
	for entry: Dictionary in weather.forecast:
		if int(entry["lap"]) == target_lap:
			return entry
		if last.is_empty() or int(entry["lap"]) > int(last["lap"]):
			last = entry
	if not last.is_empty() and target_lap > int(last["lap"]):
		return last
	return {}
