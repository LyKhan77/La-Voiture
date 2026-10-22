class_name CautionTape
extends Control

## Diagonal yellow-black caution strip (DESIGN.md 4.3) with a message on a hard panel.
## Shown while a yellow flag, VSC or the safety car is out; the stripes run like a marquee.

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")

const STRIPE_W: float = 14.0
const TAPE_H: float = 10.0

var label: Label
var _offset: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(620, 44)
	size = custom_minimum_size
	label = UI.label("", 18, T.INK_BORDER_BLACK, UI.HEADER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_top = 12.0
	add_child(label)


func set_message(text: String, tint: Color = T.ACCENT_CYBER_YELLOW) -> void:
	label.text = text
	modulate = Color.WHITE
	_tint = tint
	queue_redraw()


var _tint: Color = T.ACCENT_CYBER_YELLOW


func _process(delta: float) -> void:
	if visible:
		_offset = fmod(_offset + delta * 40.0, STRIPE_W * 2.0)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _tint)
	draw_rect(Rect2(Vector2.ZERO, size), T.INK_BORDER_BLACK, false, 3.0)
	for edge_y: float in [0.0, size.y - TAPE_H]:
		draw_rect(Rect2(0.0, edge_y, size.x, TAPE_H), T.INK_BORDER_BLACK)
		var x: float = -STRIPE_W * 2.0 + _offset
		while x < size.x + STRIPE_W:
			var stripe := PackedVector2Array([
				Vector2(x, edge_y + TAPE_H), Vector2(x + STRIPE_W, edge_y + TAPE_H),
				Vector2(x + STRIPE_W + TAPE_H, edge_y), Vector2(x + TAPE_H, edge_y),
			])
			draw_colored_polygon(stripe, _tint)
			x += STRIPE_W * 2.0
