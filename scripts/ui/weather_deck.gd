class_name WeatherDeck
extends Control

## The weather deck: a dropdown under the ribbon chip (click the chip or [W]). A chart of the track water for the
## live lap and the 10 laps after it (rain bars, the water line, a cone that widens with distance, the sim's inter
## and wet lines, the tyre each lap asks for, a blinking BOX WINDOW bracket), the track map, the air, track,
## humidity and wind numbers, the next change with its confidence, and a button that picks the tyres for the next
## box call. It draws GtWeatherOutlook rows and never changes the sim; the button only emits `tyres_chosen`.

signal tyres_chosen(compound: int, box_k: int)

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")

const SIZE := Vector2(560.0, 264.0)
const MAP_MARGIN: float = 12.0
const MAP_POINTS: int = 90
const COMPASS: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
## Display offsets of the water per sector (the sim has none per sector).
const SECTOR_OFFSET: Array[float] = [0.0, 10.0, -8.0]

var is_open: bool = false
var chart: WeatherChart
var map: WeatherTrackMap
var next_label: Label
var action_button: Button
var info_labels: Dictionary = {}

var _summary: Dictionary = {}
var _phase: float = 0.0


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 15
	UI.surface(self)
	var title := UI.label("WEATHER DECK  //  TRACK WATER, NEXT 10 LAPS   [W] CLOSE", 14, T.TEXT_PRIMARY, UI.HEADER)
	add_child(title)
	title.position = Vector2(12.0, 8.0)
	chart = WeatherChart.new()
	add_child(chart)
	chart.position = Vector2(8.0, 34.0)
	var hint := UI.label("white line = water on track | blue bars = rain | cone = how unsure the forecast is", 9, T.TEXT_MUTED)
	add_child(hint)
	hint.position = Vector2(12.0, 246.0)
	var map_title := UI.label("TRACK STATE", 11, T.TEXT_SECONDARY, UI.HEADER)
	add_child(map_title)
	map_title.position = Vector2(382.0, 34.0)
	map = WeatherTrackMap.new()
	add_child(map)
	map.position = Vector2(380.0, 50.0)
	var column: int = 0
	for key: String in ["AIR", "TRACK", "HUMIDITY", "WIND"]:
		var label := UI.label(key, 10, T.TEXT_PRIMARY)
		add_child(label)
		label.position = Vector2(382.0 + float(column % 2) * 86.0, 158.0 + float(column / 2) * 14.0)
		info_labels[key] = label
		column += 1
	next_label = UI.label("", 11, T.TEXT_PRIMARY, UI.HEADER)
	next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_label.custom_minimum_size.x = 168.0
	add_child(next_label)
	next_label.position = Vector2(382.0, 190.0)
	next_label.size = Vector2(168.0, 34.0)
	action_button = UI.button("")
	action_button.add_theme_font_size_override("font_size", 12)
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.visible = false
	action_button.pressed.connect(_on_action)
	add_child(action_button)
	action_button.position = Vector2(380.0, 226.0)
	action_button.size = Vector2(172.0, 28.0)
	set_process(false)


func set_open(value: bool) -> void:
	is_open = value
	visible = value
	_sync_process()


func toggle() -> void:
	set_open(not is_open)


## The circuit outline, sampled from the track ribbon and fitted into the map's box.
func set_ribbon(ribbon: TrackRibbon, length_m: float) -> void:
	var raw := PackedVector2Array()
	var bounds := Rect2()
	for index: int in range(MAP_POINTS):
		var origin: Vector3 = ribbon.get_point_on_ribbon(length_m * float(index) / float(MAP_POINTS), 1).origin
		var point := Vector2(origin.x, origin.z)
		raw.append(point)
		bounds = Rect2(point, Vector2.ZERO) if index == 0 else bounds.expand(point)
	var inner: Vector2 = WeatherTrackMap.SIZE - Vector2.ONE * MAP_MARGIN * 2.0
	var fit: float = minf(inner.x / maxf(bounds.size.x, 0.001), inner.y / maxf(bounds.size.y, 0.001))
	var offset: Vector2 = WeatherTrackMap.SIZE * 0.5 - bounds.get_center() * fit
	var fitted := PackedVector2Array()
	for point: Vector2 in raw:
		fitted.append(point * fit + offset)
	map.set_points(fitted)


## `rows`: GtWeatherOutlook.ahead(..., 10, ...); `snapshot`: air, track, humidity, wind_kmh, wind_dir (radians), water, drying_line.
func update_outlook(rows: Array[Dictionary], summary: Dictionary, snapshot: Dictionary) -> void:
	_summary = summary
	chart.rows = rows
	chart.box_k = int(summary["box_k"])
	chart.queue_redraw()
	info_labels["AIR"].text = "AIR %d°C" % roundi(float(snapshot["air"]))
	info_labels["TRACK"].text = "TRACK %d°C" % roundi(float(snapshot["track"]))
	info_labels["HUMIDITY"].text = "HUMIDITY %d%%" % roundi(float(snapshot["humidity"]))
	var heading: int = posmod(roundi(float(snapshot["wind_dir"]) / TAU * 8.0), 8)
	info_labels["WIND"].text = "WIND %d km/h %s" % [roundi(float(snapshot["wind_kmh"])), COMPASS[heading]]
	var water: float = float(snapshot["water"])
	var sectors: Array[float] = []
	for offset: float in SECTOR_OFFSET:
		sectors.append(clampf(water + offset, 0.0, 100.0))
	map.set_wetness(sectors, float(snapshot["drying_line"]))
	_update_next(rows, summary)
	_sync_process()


func _update_next(rows: Array[Dictionary], summary: Dictionary) -> void:
	var next: Dictionary = summary["state_change"]
	var change: Dictionary = summary["tyre_change"]
	var box_k: int = int(summary["box_k"])
	var confidence: int = roundi(float(summary["confidence"]) * 100.0)
	if next.is_empty():
		var flag_cuts: bool = false
		for row: Dictionary in rows:
			flag_cuts = flag_cuts or bool(row["past_finish"])
		next_label.text = "%s\nconfidence %d%%" % ["NO CHANGE BEFORE THE FLAG" if flag_cuts else "NO CHANGE IN %d LAPS" % GtWeatherOutlook.CHART_LAPS, confidence]
	else:
		var laps: int = int(next["k"])
		var crossover: String = "none in %dL" % GtWeatherOutlook.CHART_LAPS if change.is_empty() \
				else "> %s at L+%d" % [GtTypes.COMPOUND_NAME[int(change["tyre"])], int(change["k"])]
		next_label.text = "%s IN ~%d LAP%s\nconfidence %d%% | crossover %s" % [
			GtWeatherOutlook.state_name(int(next["state"])), laps, "S" if laps > 1 else "", confidence, crossover]
	action_button.visible = box_k > 0
	if box_k > 0:
		action_button.text = "SET TYRES  L+%d > %s" % [box_k, GtTypes.COMPOUND_NAME[int(change["tyre"])]]


func _on_action() -> void:
	var change: Dictionary = _summary.get("tyre_change", {})
	if change.is_empty():
		return
	AudioManager.click_pitched(self, 1.1)
	tyres_chosen.emit(int(change["tyre"]), int(_summary["box_k"]))


func _sync_process() -> void:
	set_process(is_open and chart.box_k > 0 and not PresentationSettings.reduce_motion)


func _process(delta: float) -> void:
	_phase += delta
	chart.phase = _phase
	chart.queue_redraw()


## The 11 lap chart (k = 0..10), drawn in one _draw().
class WeatherChart extends Control:
	const UI = preload("res://scripts/ui/pit_wall_ui.gd")
	const T = preload("res://scripts/ui/ui_theme_tokens.gd")
	const SIZE := Vector2(366.0, 208.0)
	const PLOT := Rect2(30.0, 22.0, 326.0, 100.0)
	const LINE_COLOR := Color.WHITE
	const RAIN_COLOR := Color("#2979FF")
	const BOX_COLOR := Color("#FF1744")

	var rows: Array[Dictionary] = []
	var box_k: int = 0
	var phase: float = 0.0

	func _init() -> void:
		custom_minimum_size = SIZE
		size = SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _y(water_pct: float) -> float:
		return PLOT.end.y - clampf(water_pct / 100.0, 0.0, 1.0) * PLOT.size.y

	func _draw() -> void:
		draw_rect(PLOT, Color(1, 1, 1, 0.04))
		var font: Font = UI.MONO
		for line: Array in [[GtForecast.WET_WATER_PCT, "WET > 45%", Color("#2979FF")], [GtForecast.INTER_WATER_PCT, "INTER > 18%", Color("#00E676")]]:
			var y: float = _y(float(line[0]))
			draw_line(Vector2(PLOT.position.x, y), Vector2(PLOT.end.x, y), line[2], 1.0)
			draw_string(font, Vector2(PLOT.end.x - 2.0, y - 3.0), String(line[1]), HORIZONTAL_ALIGNMENT_RIGHT, 120.0, 8, line[2])
		if rows.size() < 2:
			return
		var step: float = PLOT.size.x / float(rows.size() - 1)
		var upper := PackedVector2Array()
		var lower := PackedVector2Array()
		for index: int in range(rows.size()):
			var spread: float = GtWeatherOutlook.cone_spread(index)
			var water: float = float(rows[index]["water"])
			upper.append(Vector2(PLOT.position.x + float(index) * step, _y(water + spread)))
			lower.append(Vector2(PLOT.position.x + float(index) * step, _y(maxf(0.0, water - spread))))
		lower.reverse()
		upper.append_array(lower)
		var pulse: float = 0.8 if PresentationSettings.reduce_motion else 0.7 + 0.3 * sin(phase * 2.6)
		draw_colored_polygon(upper, Color(T.ACCENT_ACID_LIME, 0.2 * pulse))
		var line := PackedVector2Array()
		for index: int in range(rows.size()):
			var x: float = PLOT.position.x + float(index) * step
			var rain: float = float(rows[index]["rain"])
			var bar: float = clampf(rain, 0.0, 1.0) * PLOT.size.y * 0.9
			draw_rect(Rect2(x - step * 0.26, PLOT.end.y - bar, step * 0.52, bar), Color(RAIN_COLOR, 0.75))
			line.append(Vector2(x, _y(float(rows[index]["water"]))))
		draw_polyline(line, LINE_COLOR, 2.5)
		for point: Vector2 in line:
			draw_circle(point, 3.0, LINE_COLOR)
		if box_k > 0:
			var blink: float = 1.0 if PresentationSettings.reduce_motion else 0.35 + 0.65 * absf(sin(phase * 3.1))
			var bx: float = PLOT.position.x + float(box_k) * step - step * 0.45
			draw_rect(Rect2(bx, PLOT.position.y - 12.0, step * 1.4, PLOT.size.y + 62.0), Color(BOX_COLOR, blink), false, 2.0)
			draw_string(font, Vector2(bx, PLOT.position.y - 15.0), "BOX WINDOW", HORIZONTAL_ALIGNMENT_LEFT, 90.0, 9, Color(BOX_COLOR, blink))
		draw_rect(Rect2(PLOT.position.x - 2.0, PLOT.position.y, 3.0, PLOT.size.y + 44.0), T.ACCENT_ACID_LIME)
		for index: int in range(rows.size()):
			var x: float = PLOT.position.x + float(index) * step
			var past: bool = bool(rows[index]["past_finish"])
			var alpha: float = 0.25 if past else 1.0
			var tyre: int = int(rows[index]["tyre"])
			draw_string(font, Vector2(x - 14.0, PLOT.end.y + 12.0), "NOW" if index == 0 else "L+%d" % index, HORIZONTAL_ALIGNMENT_CENTER, 28.0, 8, Color(T.TEXT_SECONDARY, alpha))
			draw_rect(Rect2(x - 11.0, PLOT.end.y + 16.0, 22.0, 14.0), Color(GtTypes.COMPOUND_COLOR[tyre], alpha))
			draw_string(font, Vector2(x - 11.0, PLOT.end.y + 27.0), GtTypes.COMPOUND_LABEL[tyre], HORIZONTAL_ALIGNMENT_CENTER, 22.0, 10, Color(T.INK_BORDER_BLACK, alpha))
