class_name WeatherRadarWidget
extends Control

## Pit wall ribbon weather chip. Row 1: the status line and the next change. Row 2: the ladder of the live lap
## and the 7 laps after it (rain bar, the tyre the weather asks for, tags NOW / BOX, a pulse on the lap the tyre
## changes) and a wet tube with the sim's inter and wet ticks. Display only: it draws what update_outlook() is
## given (GtWeatherOutlook rows) or, for the older pit wall dashboard, the plain 5-lap bars of update_status().
## A click on the chip emits `clicked` (the HUD opens the weather deck).

signal clicked

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

const LADDER_COLUMNS: int = 8
const COLUMN_W: float = 30.0
const COLUMN_GAP: float = 3.0
const TAG_BASE_Y: float = 28.0
const BAR_TOP_Y: float = 30.0
const BAR_H: float = 13.0
const CHIP_TOP_Y: float = 44.0
const CHIP_H: float = 12.0
const TUBE_RECT := Rect2(304.0, 24.0, 16.0, 30.0)
const RAIN_ON: float = 0.08
const DIM_ALPHA: float = 0.25
const NOW_COLOR := Color("#CCFF00")
const BOX_COLOR := Color("#FF1E56")
const RAIN_COLOR := Color("#2979FF")

var status_label: Label
var forecast_label: Label
## One entry per ladder column: {"tyre": Compound, "rain": float, "tag": "NOW" / "BOX" / "", "crossover": bool, "dim": bool}.
var columns: Array[Dictionary] = []

var _wetness_pct: float = 0.0
var _forecast: Array[int] = []
var _state: int = 0
var _water_pct: float = 0.0
var _phase: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(350, 56)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	status_label = UI.label("☀️ DRY", 15, T.ACCENT_ELECTRIC_CYAN)
	status_label.position = Vector2(0, 5)
	add_child(status_label)
	forecast_label = UI.label("", 10, T.TEXT_SECONDARY)
	forecast_label.position = Vector2(FORECAST_LABEL_X, 32)
	add_child(forecast_label)
	set_process(false)


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


## The ladder: `rows` are GtWeatherOutlook.ahead() rows k = 0..7, `summary` is GtWeatherOutlook.summary(rows).
func update_outlook(rows: Array[Dictionary], summary: Dictionary, _air_c: float, track_c: float) -> void:
	var box_k: int = int(summary["box_k"])
	var change: Dictionary = summary["tyre_change"]
	var next: Dictionary = summary["state_change"]
	columns.clear()
	for index: int in range(mini(rows.size(), LADDER_COLUMNS)):
		var row: Dictionary = rows[index]
		var past: bool = bool(row["past_finish"])
		var tag: String = ""
		if index == 0:
			tag = "NOW"
		elif index == box_k and not past:
			tag = "BOX"
		columns.append({
			"tyre": int(row["tyre"]), "rain": float(row["rain"]), "tag": tag, "dim": past,
			"crossover": not past and not change.is_empty() and int(change["k"]) == index,
		})
	_water_pct = float(rows[0]["water"]) if not rows.is_empty() else 0.0
	status_label.position = Vector2(0, 1)
	forecast_label.position = Vector2(150, 5)
	forecast_label.text = "> %s L+%d   TRK %d°C" % [GtWeatherOutlook.state_name(int(next["state"])), int(next["k"]), roundi(track_c)] \
			if not next.is_empty() else "> STABLE %dL   TRK %d°C" % [GtWeatherOutlook.CHART_LAPS, roundi(track_c)]
	var moving: bool = not change.is_empty()
	for column: Dictionary in columns:
		moving = moving or float(column["rain"]) > RAIN_ON
	set_process(moving and not PresentationSettings.reduce_motion)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()


func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()


func _draw() -> void:
	if columns.is_empty():
		_draw_plain()
		return
	var font: Font = UI.MONO
	for index: int in range(columns.size()):
		var column: Dictionary = columns[index]
		var x: float = float(index) * (COLUMN_W + COLUMN_GAP)
		var alpha: float = DIM_ALPHA if bool(column["dim"]) else 1.0
		var rain: float = float(column["rain"])
		var tyre: int = int(column["tyre"])
		var tag: String = String(column["tag"])
		if bool(column["crossover"]):
			var pulse: float = 0.5 if PresentationSettings.reduce_motion else 0.5 + 0.5 * sin(_phase * 6.0)
			draw_rect(Rect2(x - 1.0, TAG_BASE_Y - 8.0, COLUMN_W + 2.0, CHIP_TOP_Y + CHIP_H - TAG_BASE_Y + 9.0), Color(T.ACCENT_CYBER_YELLOW, 0.25 + 0.35 * pulse))
		if tag != "":
			var tag_color: Color = NOW_COLOR if tag == "NOW" else BOX_COLOR
			draw_string(font, Vector2(x, TAG_BASE_Y), tag, HORIZONTAL_ALIGNMENT_LEFT, COLUMN_W, 9, tag_color)
			if tag == "BOX":
				draw_rect(Rect2(x - 1.0, TAG_BASE_Y - 9.0, COLUMN_W + 2.0, CHIP_TOP_Y + CHIP_H - TAG_BASE_Y + 10.0), tag_color, false, 1.5)
		draw_rect(Rect2(x, BAR_TOP_Y, COLUMN_W, BAR_H), Color(T.SURFACE_PANEL_DARK, alpha))
		var height: float = maxf(2.0, minf(1.0, rain) * BAR_H)
		draw_rect(Rect2(x, BAR_TOP_Y + BAR_H - height, COLUMN_W, height), Color(RAIN_COLOR, 0.75 * alpha))
		if rain > RAIN_ON and not PresentationSettings.reduce_motion and alpha == 1.0:
			for drop: int in range(3):
				var y: float = BAR_TOP_Y + fposmod(_phase * 30.0 + float(drop * 5 + index * 3), BAR_H)
				draw_line(Vector2(x + 6.0 + float(drop) * 9.0, y), Vector2(x + 6.0 + float(drop) * 9.0, minf(y + 3.0, BAR_TOP_Y + BAR_H)), Color(1, 1, 1, 0.7), 1.0)
		draw_rect(Rect2(x, CHIP_TOP_Y, COLUMN_W, CHIP_H), Color(GtTypes.COMPOUND_COLOR[tyre], alpha))
		draw_string(font, Vector2(x, CHIP_TOP_Y + CHIP_H - 2.0), GtTypes.COMPOUND_LABEL[tyre], HORIZONTAL_ALIGNMENT_CENTER, COLUMN_W, 10, Color(T.INK_BORDER_BLACK, alpha))
	_draw_tube(font)


func _draw_tube(font: Font) -> void:
	draw_string(font, Vector2(TUBE_RECT.position.x - 2.0, TUBE_RECT.position.y - 3.0), "WET", HORIZONTAL_ALIGNMENT_LEFT, 24.0, 8, T.TEXT_SECONDARY)
	draw_rect(TUBE_RECT, T.SURFACE_PANEL_DARK)
	var fill: float = clampf(_water_pct / 100.0, 0.0, 1.0) * TUBE_RECT.size.y
	draw_rect(Rect2(TUBE_RECT.position.x, TUBE_RECT.end.y - fill, TUBE_RECT.size.x, fill), T.ACCENT_ELECTRIC_CYAN)
	for threshold: float in [GtForecast.INTER_WATER_PCT, GtForecast.WET_WATER_PCT]:
		var y: float = TUBE_RECT.end.y - threshold / 100.0 * TUBE_RECT.size.y
		draw_line(Vector2(TUBE_RECT.position.x - 3.0, y), Vector2(TUBE_RECT.end.x + 3.0, y), T.ACCENT_CYBER_YELLOW, 2.0)
	draw_rect(TUBE_RECT, T.TEXT_SECONDARY, false, 1.0)


## The plain look of the older pit wall dashboard: wetness gauge and 5 lap bars.
func _draw_plain() -> void:
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
