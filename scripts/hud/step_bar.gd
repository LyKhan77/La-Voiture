class_name StepBar
extends Control

## Stepped telemetry bar (DESIGN.md C): separate blocks with a 2 px gap in a black frame,
## never a rounded or smooth bar. Colour follows the value unless `fixed_tint` is set:
## above 60 % acid lime, 30-60 % cyber yellow, 30 % and below crimson that blinks.

const T = preload("res://scripts/ui/ui_theme_tokens.gd")

@export var blocks: int = 10
@export var gap_px: float = 2.0

var value: float = 1.0 # 0..1
var fixed_tint: Color = Color(0, 0, 0, 0) # alpha 0 = automatic by value
## Optional white tick at 0..1 (fuel needed to the flag); negative = none.
var marker: float = -1.0
var invert_scale: bool = false # true: high value is bad (temperatures, stress)


func _init(p_blocks: int = 10) -> void:
	blocks = p_blocks
	custom_minimum_size = Vector2(60, 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(p_value: float, p_tint: Color = Color(0, 0, 0, 0)) -> void:
	value = clampf(p_value, 0.0, 1.0)
	fixed_tint = p_tint
	queue_redraw()


## Colour a value would have, for tests and for neighbouring labels.
func tint_for(p_value: float) -> Color:
	if fixed_tint.a > 0.0:
		return fixed_tint
	var health: float = 1.0 - p_value if invert_scale else p_value
	if health > 0.6:
		return T.ACCENT_ACID_LIME
	if health > 0.3:
		return T.ACCENT_CYBER_YELLOW
	return T.ACCENT_ANIME_CRIMSON


func lit_blocks() -> int:
	return clampi(ceili(value * float(blocks) - 0.0001), 0, blocks)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), T.INK_BORDER_BLACK)
	var inner := Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
	var block_w: float = (inner.size.x - gap_px * float(blocks - 1)) / float(blocks)
	var tint: Color = tint_for(value)
	var health: float = 1.0 - value if invert_scale else value
	if fixed_tint.a <= 0.0 and health <= 0.3 and int(Time.get_ticks_msec() / 160) % 2 == 0:
		tint = tint.darkened(0.45) # glitch blink while critical
	for index: int in range(blocks):
		var x: float = inner.position.x + float(index) * (block_w + gap_px)
		var lit: bool = index < lit_blocks()
		draw_rect(Rect2(x, inner.position.y, block_w, inner.size.y), tint if lit else Color(1, 1, 1, 0.08))
	if marker >= 0.0:
		draw_rect(Rect2(inner.position.x + inner.size.x * marker - 1.5, 0.0, 3.0, size.y), Color.WHITE)
