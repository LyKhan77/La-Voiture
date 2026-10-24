class_name WeatherTrackMap
extends Control

## A small circuit outline for the weather deck: three sectors (thirds of the outline) tinted by how much water
## they carry, and a white dry line whose strength follows the sim's drying line. The sim has no water per
## sector; the deck passes the track water with a fixed offset per sector, so this is a display heuristic.

const SIZE := Vector2(170.0, 104.0)
const DRY := Color("#7D8AA0")
const DAMP := Color("#00C2D1")
const WET := Color("#2979FF")
const FLOODED := Color("#4B3CFF")
const SECTORS: int = 3
const DRY_LINE_FULL_PCT: float = 65.0

var points: PackedVector2Array = PackedVector2Array()

var _water: Array[float] = [0.0, 0.0, 0.0]
var _dry_line_pct: float = 0.0


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func water_color(water_pct: float) -> Color:
	if water_pct < 10.0:
		return DRY
	if water_pct < 25.0:
		return DAMP
	return WET if water_pct < 45.0 else FLOODED


## Outline points already fitted to the map's own 170x104 box.
func set_points(outline: PackedVector2Array) -> void:
	points = outline
	queue_redraw()


func set_wetness(sector_water: Array[float], drying_line_pct: float) -> void:
	_water = sector_water.duplicate()
	_dry_line_pct = drying_line_pct
	queue_redraw()


func sector_colors() -> Array[Color]:
	var found: Array[Color] = []
	for index: int in range(SECTORS):
		found.append(water_color(_water[index] if index < _water.size() else 0.0))
	return found


func _draw() -> void:
	if points.size() < SECTORS * 2:
		return
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color.BLACK, 13.0)
	var colors: Array[Color] = sector_colors()
	var per_sector: int = points.size() / SECTORS
	for sector: int in range(SECTORS):
		var first: int = sector * per_sector
		var last: int = points.size() if sector == SECTORS - 1 else first + per_sector
		var piece := PackedVector2Array()
		for index: int in range(first, mini(last + 1, points.size())):
			piece.append(points[index])
		if sector == SECTORS - 1:
			piece.append(points[0])
		draw_polyline(piece, colors[sector], 8.0)
	var strength: float = clampf(_dry_line_pct / DRY_LINE_FULL_PCT, 0.0, 1.0)
	if strength > 0.0:
		draw_polyline(closed, Color(1, 1, 1, 0.8 * strength), 1.5)
