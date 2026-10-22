class_name WeatherRadarWidget
extends Control

## Pit wall ribbon weather mini-radar: status line, wetness gauge with the 35%
## wet-crossover tick, a 5-lap forecast bar chart and its text form. Display only;
## it renders the dictionary RaceControl.get_status() gives it.

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")
const WeatherScript = preload("res://scripts/core/weather_manager.gd")

const STATUS_ICONS: Array[String] = ["☀️", "🌦️", "🌧️", "🌤️"]
const STATE_COLORS: Array[Color] = [T.ACCENT_ACID_LIME, T.ACCENT_ELECTRIC_CYAN, T.ACCENT_ANIME_CRIMSON, T.ACCENT_CYBER_YELLOW]
## Bar height per state in the forecast chart: how much water to expect.
const FORECAST_BAR_PX: Array[float] = [3.0, 8.0, 14.0, 6.0]

const GAUGE_RECT := Rect2(0, 33, 84, 9)
const FORECAST_X: float = 96.0
const FORECAST_BAR_W: float = 10.0
const FORECAST_BAR_GAP: float = 4.0
const FORECAST_BASE_Y: float = 47.0
const FORECAST_LABEL_X: float = 168.0

var status_label: Label
var forecast_label: Label

var _wetness_pct: float = 0.0
var _forecast: Array[int] = []
var _state: int = 0


func _init() -> void:
	custom_minimum_size = Vector2(350, 56)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label = UI.label("☀️ DRY", 15, T.ACCENT_ELECTRIC_CYAN)
	status_label.position = Vector2(0, 5)
	add_child(status_label)
	forecast_label = UI.label("", 10, T.TEXT_SECONDARY)
	forecast_label.position = Vector2(FORECAST_LABEL_X, 32)
	add_child(forecast_label)


## "L+2: DRIZZLE | L+4: HEAVY RAIN" - only the laps where the weather changes.
static func format_forecast(current_state: int, forecast: Array[int]) -> String:
	var parts: PackedStringArray = []
	var previous: int = current_state
	for index: int in range(forecast.size()):
		if forecast[index] != previous:
			parts.append("L+%d: %s" % [index + 1, WeatherScript.STATE_NAMES[forecast[index]]])
			previous = forecast[index]
	if parts.is_empty():
		return "L+1..%d: %s" % [forecast.size(), WeatherScript.STATE_NAMES[current_state]]
	return " | ".join(parts)


static func format_status(state: int, wetness_pct: float, ambient_c: float) -> String:
	var name: String = WeatherScript.STATE_NAMES[state]
	if state == WeatherScript.WeatherState.HEAVY_DOWNPOUR:
		name = "RAIN (WET %d%%)" % roundi(wetness_pct * 100.0)
	return "%s %s  %d°C" % [STATUS_ICONS[state], name, roundi(ambient_c)]


func update_status(status: Dictionary) -> void:
	_state = int(status["state"])
	_wetness_pct = float(status["wetness_pct"])
	_forecast.assign(status["forecast"])
	status_label.text = format_status(_state, _wetness_pct, float(status["ambient_c"]))
	status_label.add_theme_color_override("font_color", STATE_COLORS[_state])
	forecast_label.text = format_forecast(_state, _forecast)
	queue_redraw()


func _draw() -> void:
	draw_rect(GAUGE_RECT, T.SURFACE_PANEL_DARK)
	var fill := Rect2(GAUGE_RECT.position, Vector2(GAUGE_RECT.size.x * _wetness_pct, GAUGE_RECT.size.y))
	draw_rect(fill, STATE_COLORS[WeatherScript.WeatherState.LIGHT_DRIZZLE])
	var crossover_x: float = GAUGE_RECT.position.x + GAUGE_RECT.size.x * WeatherScript.WET_CROSSOVER_MM
	draw_line(Vector2(crossover_x, GAUGE_RECT.position.y - 3), Vector2(crossover_x, GAUGE_RECT.end.y + 3), T.ACCENT_CYBER_YELLOW, 2.0)
	draw_rect(GAUGE_RECT, T.TEXT_SECONDARY, false, 1.0)
	for index: int in range(_forecast.size()):
		var state: int = _forecast[index]
		var height: float = FORECAST_BAR_PX[state]
		var x: float = FORECAST_X + float(index) * (FORECAST_BAR_W + FORECAST_BAR_GAP) - 0.0
		draw_rect(Rect2(x, FORECAST_BASE_Y - height, FORECAST_BAR_W, height), STATE_COLORS[state])
