extends Control

## 300x200 px circuit radar (PRD 01 §5.2), made readable after the FASE 10 feedback. The track is a Line2D
## traced from the ribbon's racing line, fitted to the panel, with three coloured sector bands laid over it
## (S1 / S2 / S3 labels, a start line tick and two sector boundary ticks). Each car is a team-coloured dot
## carrying its race number; the followed car is the biggest dot with a white ring and a halo, the player's
## team wears a yellow ring, a car in the pit lane a cyan one. A strip under the map shows the followed car's
## three sector results (purple / green / yellow, the sector it is in outlined) and its number and code.
## A yellow flag lights its sector band and chip yellow.
## The drawing reads plain data (marks, bands, ticks, chips) that update_snapshot() and set_ribbon() build, so
## it can be checked without a rendered frame.
##
## Snapshot: {"cars": [{"car_id", "team_id", "spline_distance"} + optional "number", "position", "followed",
## "player", "in_pit", "retired"], optional "sector_colors" [3 GtTypes.SectorColor], "sector" (0-based
## sector of the followed car), "yellow_sector" (1-based, 0 = none), "followed_text"}. Callers that send only the
## three required fields still get numbered dots (number = car_id + 1).

const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const UI := preload("res://scripts/ui/pit_wall_ui.gd")

const RADAR_SIZE := Vector2(300.0, 200.0)
const MARGIN_SIDE_PX: float = 22.0
const MARGIN_TOP_PX: float = 18.0
const MARGIN_BOTTOM_PX: float = 36.0
const TRACK_POINT_SPACING_M: float = 25.0
const TRACK_CASING_PX: float = 7.0
const BAND_WIDTH_PX: float = 3.5
const BAND_POINTS: int = 28
const SECTOR_COUNT: int = 3
const DOT_DIAMETER_PX: float = 16.0
const FOLLOWED_DIAMETER_PX: float = 22.0
const DOT_OUTLINE_PX: float = 1.5
const NUMBER_FONT_PX: int = 11
const FOLLOWED_FONT_PX: int = 14
const LABEL_FONT_PX: int = 13
const LABEL_PUSH_PX: float = 14.0
const TICK_HALF_LENGTH_PX: float = 7.0
const CHIP_SIZE := Vector2(40.0, 16.0)
const CHIP_GAP_PX: float = 4.0
const CHIP_ORIGIN := Vector2(8.0, 176.0)
## Index = GtTypes.SectorColor (NONE, PURPLE, GREEN, YELLOW).
const STATUS_COLORS: Array[Color] = [Color("#2A2F3A"), Color("#D946EF"), Color("#CCFF00"), Color("#FFE600")]
const SECTOR_COLORS: Array[Color] = [Color("#00F0FF"), Color("#F4F5F7"), Color("#FF9A3D")]
const YELLOW_FLAG := Color("#FFE600")
const PLAYER_RING := Color("#FFE600")
const PIT_RING := Color("#00F0FF")
const FOLLOWED_RING := Color("#F4F5F7")
const CASING_COLOR := Color("#171B26")
const RETIRED_FILL := Color(0.32, 0.34, 0.38, 0.7)

var _ribbon: TrackRibbonScript
var _distance_scale: float = 1.0
var _sim_length_m: float = 1.0
var _fit_scale: float = 1.0
var _fit_offset := Vector2.ZERO
var _map_centre := Vector2.ZERO
var _cars: Array = []

## Drawing data, rebuilt by set_ribbon() / update_snapshot().
var marks: Array[Dictionary] = [] # one per car, in draw order (the followed car last)
var bands: Array[Dictionary] = [] # {sector, path, color, label, label_at, yellow}
var ticks: Array[Dictionary] = [] # {kind: "start" | "sector", from, to}
var chips: Array[Dictionary] = [] # {sector, text, rect, fill, ink, current, flagged}
var followed_text: String = ""

var _sectors: Control
var _legend: Control

@onready var _track: Line2D = $Track
@onready var _dots: Control = $Dots


func _ready() -> void:
	_track.default_color = CASING_COLOR
	_track.width = TRACK_CASING_PX
	_sectors = _layer("Sectors", _track.get_index() + 1)
	_sectors.draw.connect(_draw_sectors)
	_dots.draw.connect(_draw_dots)
	_legend = _layer("Legend", _dots.get_index() + 1)
	_legend.draw.connect(_draw_legend)
	_build_chips({})


func _layer(layer_name: String, index: int) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.size = RADAR_SIZE
	add_child(layer)
	move_child(layer, index)
	return layer


## `sim_track_length_m` maps the sim's spline_distance onto the ribbon.
func set_ribbon(ribbon: TrackRibbonScript, sim_track_length_m: float) -> void:
	_ribbon = ribbon
	_sim_length_m = sim_track_length_m
	_distance_scale = ribbon.length_m / sim_track_length_m
	var count: int = ceili(ribbon.length_m / TRACK_POINT_SPACING_M)
	var raw := PackedVector2Array()
	var bounds := Rect2()
	for i: int in range(count):
		var origin: Vector3 = ribbon.get_point_on_ribbon(ribbon.length_m * float(i) / float(count), 1).origin
		var p := Vector2(origin.x, origin.z)
		raw.append(p)
		bounds = Rect2(p, Vector2.ZERO) if i == 0 else bounds.expand(p)
	var inner: Vector2 = RADAR_SIZE - Vector2(MARGIN_SIDE_PX * 2.0, MARGIN_TOP_PX + MARGIN_BOTTOM_PX)
	_fit_scale = minf(inner.x / bounds.size.x, inner.y / bounds.size.y)
	_map_centre = Vector2(RADAR_SIZE.x * 0.5, MARGIN_TOP_PX + inner.y * 0.5)
	_fit_offset = _map_centre - bounds.get_center() * _fit_scale
	var mapped := PackedVector2Array()
	for p: Vector2 in raw:
		mapped.append(p * _fit_scale + _fit_offset)
	_track.points = mapped
	_track.closed = true
	_build_bands()
	_redraw()


## Accepts the pit wall snapshot (see the header).
func update_snapshot(snapshot: Dictionary) -> void:
	_cars = snapshot.get("cars", [])
	_build_marks()
	_build_chips(snapshot)
	var yellow: int = int(snapshot.get("yellow_sector", 0))
	for band: Dictionary in bands:
		band["yellow"] = int(band["sector"]) == yellow
	_redraw()


## Radar-space position of a sim spline_distance on the racing line.
func project(spline_distance: float) -> Vector2:
	var origin: Vector3 = _ribbon.get_point_on_ribbon(spline_distance * _distance_scale, 1).origin
	return Vector2(origin.x, origin.z) * _fit_scale + _fit_offset


func _redraw() -> void:
	for layer: Control in [_sectors, _dots, _legend]:
		if layer != null:
			layer.queue_redraw()


# --- data ----------------------------------------------------------------------------------

## The lap split in thirds of the sim track (the sim's own sector rule), with ticks at the boundaries.
func _build_bands() -> void:
	bands.clear()
	ticks.clear()
	for sector: int in range(SECTOR_COUNT):
		var path := PackedVector2Array()
		for step: int in range(BAND_POINTS + 1):
			path.append(project(_sim_length_m * (float(sector) + float(step) / float(BAND_POINTS)) / float(SECTOR_COUNT)))
		var middle: Vector2 = project(_sim_length_m * (float(sector) + 0.5) / float(SECTOR_COUNT))
		var outward: Vector2 = (middle - _map_centre).normalized()
		var label_at: Vector2 = (middle + outward * LABEL_PUSH_PX).clamp(Vector2(14.0, 12.0), Vector2(RADAR_SIZE.x - 14.0, RADAR_SIZE.y - 40.0))
		bands.append({
			"sector": sector + 1, "path": path, "color": SECTOR_COLORS[sector],
			"label": "S%d" % (sector + 1), "label_at": label_at, "yellow": false,
		})
		var boundary: float = _sim_length_m * float(sector) / float(SECTOR_COUNT)
		var at: Vector2 = project(boundary)
		var tangent: Vector2 = (project(boundary + 12.0) - project(boundary - 12.0)).normalized()
		var across: Vector2 = tangent.orthogonal() * TICK_HALF_LENGTH_PX
		ticks.append({"kind": "start" if sector == 0 else "sector", "from": at - across, "to": at + across})


## One dot per car, the followed car on top; drawn back to front so the leaders stay visible in a pack.
func _build_marks() -> void:
	marks.clear()
	for car: Dictionary in _cars:
		var car_id: int = int(car.get("car_id", 0))
		var number: int = int(car.get("number", car_id + 1))
		var followed: bool = bool(car.get("followed", false))
		var fill: Color = Liveries.color_for(int(car.get("team_id", 0)))
		var retired: bool = bool(car.get("retired", false))
		marks.append({
			"car_id": car_id, "number": number, "text": str(number),
			"at": project(float(car.get("spline_distance", 0.0))),
			"radius": (FOLLOWED_DIAMETER_PX if followed else DOT_DIAMETER_PX) * 0.5,
			"font_size": FOLLOWED_FONT_PX if followed else NUMBER_FONT_PX,
			"fill": RETIRED_FILL if retired else fill,
			"ink": T.TEXT_PRIMARY if retired or fill.get_luminance() < 0.45 else T.INK_BORDER_BLACK,
			"followed": followed, "player": bool(car.get("player", false)), "player_ring": bool(car.get("player", false)),
			"in_pit": bool(car.get("in_pit", false)), "retired": retired, "position": int(car.get("position", 99)),
		})
	marks.sort_custom(_draws_before)


static func _draws_before(a: Dictionary, b: Dictionary) -> bool:
	var rank_a: int = (2 if a["followed"] else (1 if a["player"] else 0))
	var rank_b: int = (2 if b["followed"] else (1 if b["player"] else 0))
	if rank_a != rank_b:
		return rank_a < rank_b
	return int(a["position"]) > int(b["position"])


## The three sector chips under the map and the followed car's caption.
func _build_chips(snapshot: Dictionary) -> void:
	chips.clear()
	var results: Array = snapshot.get("sector_colors", [])
	var current: int = int(snapshot.get("sector", -1))
	var yellow: int = int(snapshot.get("yellow_sector", 0))
	for sector: int in range(SECTOR_COUNT):
		var status: int = clampi(int(results[sector]), 0, STATUS_COLORS.size() - 1) if sector < results.size() else 0
		var fill: Color = STATUS_COLORS[status]
		chips.append({
			"sector": sector + 1, "text": "S%d" % (sector + 1), "status": status,
			"rect": Rect2(CHIP_ORIGIN + Vector2(float(sector) * (CHIP_SIZE.x + CHIP_GAP_PX), 0.0), CHIP_SIZE),
			"fill": fill, "ink": T.TEXT_PRIMARY if status <= 1 else T.INK_BORDER_BLACK,
			"current": sector == current, "flagged": sector + 1 == yellow,
		})
	followed_text = str(snapshot.get("followed_text", ""))


# --- drawing -------------------------------------------------------------------------------

func _draw_sectors() -> void:
	if _ribbon == null:
		return
	var font: Font = UI.HEADER
	for band: Dictionary in bands:
		var color: Color = YELLOW_FLAG if band["yellow"] else band["color"]
		_sectors.draw_polyline(band["path"], color, BAND_WIDTH_PX + (1.5 if band["yellow"] else 0.0), true)
	for tick: Dictionary in ticks:
		var start: bool = tick["kind"] == "start"
		_sectors.draw_line(tick["from"], tick["to"], T.INK_BORDER_BLACK, 5.0)
		_sectors.draw_line(tick["from"], tick["to"], T.TEXT_PRIMARY, 3.0)
		if start:
			# Chequered start line: dark blocks on the white tick.
			var along: Vector2 = (tick["to"] as Vector2) - (tick["from"] as Vector2)
			for block: int in range(1, 6, 2):
				var spot: Vector2 = (tick["from"] as Vector2) + along * (float(block) / 6.0)
				_sectors.draw_circle(spot, 1.1, T.INK_BORDER_BLACK)
	for band: Dictionary in bands:
		var at: Vector2 = band["label_at"]
		var color: Color = YELLOW_FLAG if band["yellow"] else band["color"]
		var text: String = String(band["label"]) + ("!" if band["yellow"] else "")
		var baseline := Vector2(at.x - 12.0, at.y + (font.get_ascent(LABEL_FONT_PX) - font.get_descent(LABEL_FONT_PX)) * 0.5)
		_sectors.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, 24.0, LABEL_FONT_PX, 4, T.INK_BORDER_BLACK)
		_sectors.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, 24.0, LABEL_FONT_PX, color)


func _draw_dots() -> void:
	if _ribbon == null:
		return
	var font: Font = UI.HEADER
	for mark: Dictionary in marks:
		var at: Vector2 = mark["at"]
		var radius: float = mark["radius"]
		if mark["followed"]:
			_dots.draw_circle(at, radius + 6.0, Color(FOLLOWED_RING, 0.22))
		if mark["player"]:
			_dots.draw_arc(at, radius + 2.2, 0.0, TAU, 28, PLAYER_RING, 2.0, true)
		if mark["in_pit"]:
			for dash: int in range(4):
				_dots.draw_arc(at, radius + 4.4, TAU * float(dash) / 4.0, TAU * (float(dash) + 0.6) / 4.0, 8, PIT_RING, 1.8, true)
		_dots.draw_circle(at, radius + DOT_OUTLINE_PX, FOLLOWED_RING if mark["followed"] else T.INK_BORDER_BLACK)
		_dots.draw_circle(at, radius, mark["fill"])
		var font_px: int = mark["font_size"]
		var baseline := Vector2(at.x - radius, at.y + (font.get_ascent(font_px) - font.get_descent(font_px)) * 0.5)
		_dots.draw_string(font, baseline, mark["text"], HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_px, mark["ink"])


func _draw_legend() -> void:
	var font: Font = UI.HEADER
	for chip: Dictionary in chips:
		var rect: Rect2 = chip["rect"]
		_legend.draw_rect(rect, chip["fill"])
		if chip["flagged"]:
			_legend.draw_rect(rect.grow(-1.0), YELLOW_FLAG, false, 2.0)
		if chip["current"]:
			_legend.draw_rect(rect, T.TEXT_PRIMARY, false, 2.0)
		else:
			_legend.draw_rect(rect, T.INK_BORDER_BLACK, false, 1.0)
		var baseline := Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5 + (font.get_ascent(13) - font.get_descent(13)) * 0.5)
		_legend.draw_string(font, baseline, chip["text"], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, chip["ink"])
	if followed_text != "":
		var rect: Rect2 = chips[2]["rect"] if chips.size() == 3 else Rect2(CHIP_ORIGIN, CHIP_SIZE)
		var left: float = rect.end.x + 10.0
		var baseline := Vector2(left, CHIP_ORIGIN.y + CHIP_SIZE.y * 0.5 + (font.get_ascent(15) - font.get_descent(15)) * 0.5)
		_legend.draw_string(font, baseline, followed_text, HORIZONTAL_ALIGNMENT_RIGHT, RADAR_SIZE.x - left - 8.0, 15, T.TEXT_PRIMARY)
