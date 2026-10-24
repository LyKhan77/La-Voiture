class_name ZonedGauge
extends Control

## A vertical gauge of 12 blocks coloured by zone (bottom block first): lit up to the value, the rest dim,
## a white line at the limit that matters (tyre cliff, fuel flag, low battery) and a dashed "ghost" line
## where the value is predicted to be at the finish for the option under the cursor.

const BLOCKS: int = 12
const GAP: float = 2.0
const LIME := Color("#CCFF00")

var value: float = 0.0
var tick: float = 0.0
var ghost: float = -1.0
var ghost_color: Color = Color.WHITE
var zone_colors: Array[Color] = []


func _init() -> void:
	custom_minimum_size = Vector2(22.0, 96.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _i: int in range(BLOCKS):
		zone_colors.append(LIME)


func set_state(p_value: float, p_tick: float) -> void:
	value = clampf(p_value, 0.0, 1.0)
	tick = clampf(p_tick, 0.0, 1.0)
	queue_redraw()


## `p_ghost` < 0 hides the ghost line.
func set_ghost(p_ghost: float, color: Color) -> void:
	ghost = clampf(p_ghost, 0.0, 1.0) if p_ghost >= 0.0 else -1.0
	ghost_color = color
	queue_redraw()


func lit_blocks() -> int:
	return ceili(value * float(BLOCKS) - 0.0001)


func ghost_visible() -> bool:
	return ghost >= 0.0


func _draw() -> void:
	var block_h: float = (size.y - GAP * float(BLOCKS - 1)) / float(BLOCKS)
	var lit: int = lit_blocks()
	for index: int in range(BLOCKS):
		var zone: Color = zone_colors[index]
		var y: float = size.y - float(index + 1) * block_h - float(index) * GAP
		draw_rect(Rect2(0.0, y, size.x, block_h), zone if index < lit else Color(zone, 0.18))
	draw_rect(Rect2(-3.0, size.y - tick * size.y - 1.0, size.x + 6.0, 2.0), Color.WHITE)
	if ghost_visible():
		var gy: float = size.y - ghost * size.y
		var x: float = -6.0
		while x < size.x + 6.0:
			draw_line(Vector2(x, gy), Vector2(x + 3.0, gy), ghost_color, 3.0)
			x += 6.0
