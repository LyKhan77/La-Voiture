class_name SeverityMark
extends Control

## A 14 px verdict mark drawn as shapes, never as font glyphs: a tick (OK), a triangle (WATCH) or a cross
## (DANGER). The shape carries the meaning, so it reads without colour.

const OK_COLOR := Color("#6DFF9C")
const WATCH_COLOR := Color("#FFE600")
const DANGER_COLOR := Color("#FF6B86")
const INK := Color("#050505")

var severity: int = 0


func _init() -> void:
	custom_minimum_size = Vector2(14.0, 14.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_severity(value: int) -> void:
	if value == severity:
		return
	severity = value
	queue_redraw()


static func color_of(value: int) -> Color:
	match value:
		1:
			return WATCH_COLOR
		2:
			return DANGER_COLOR
	return OK_COLOR


func _draw() -> void:
	match severity:
		1:
			draw_colored_polygon(PackedVector2Array([Vector2(7.0, 0.5), Vector2(13.5, 12.5), Vector2(0.5, 12.5)]), WATCH_COLOR)
			draw_line(Vector2(7.0, 4.5), Vector2(7.0, 8.5), INK, 1.8)
			draw_circle(Vector2(7.0, 10.6), 0.9, INK)
		2:
			draw_line(Vector2(2.0, 2.0), Vector2(12.0, 12.0), DANGER_COLOR, 2.6)
			draw_line(Vector2(12.0, 2.0), Vector2(2.0, 12.0), DANGER_COLOR, 2.6)
		_:
			draw_polyline(PackedVector2Array([Vector2(2.0, 7.5), Vector2(5.5, 11.0), Vector2(12.0, 3.0)]), OK_COLOR, 2.6)
