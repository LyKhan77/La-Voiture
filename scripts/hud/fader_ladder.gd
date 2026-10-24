class_name FaderLadder
extends VBoxContainer

## A vertical "fader": one button per option with the strongest option on top (the console reads
## "up = more"). Same shape as ModeRow (`buttons` in option order, `active`, `set_active`, `selected`) so
## the code and tests that drive a ModeRow drive this too. Risky options carry a SeverityMark on their
## right edge; nothing is ever disabled.

signal selected(index: int)
signal hovered(index: int)
signal unhovered

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")

const GAP: int = 2
const WIDTH: float = 104.0

var buttons: Array[Button] = []
var active: int = -1

var _tints: Array[Color] = []
var _marks: Array[SeverityMark] = []


func _init(labels: Array[String], tints: Array[Color], total_height: float = 96.0, font_size: int = 12) -> void:
	add_theme_constant_override("separation", GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, total_height)
	size = custom_minimum_size
	var count: int = labels.size()
	var height: float = floorf((total_height - float(GAP * (count - 1))) / float(count))
	for index: int in range(count):
		var button := UI.button(labels[index])
		button.add_theme_font_size_override("font_size", font_size)
		button.custom_minimum_size = Vector2(0.0, height)
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, _box(T.SURFACE_PANEL_ELEVATED))
		button.pressed.connect(_on_pressed.bind(index))
		button.mouse_entered.connect(hovered.emit.bind(index))
		button.mouse_exited.connect(unhovered.emit)
		var mark := SeverityMark.new()
		mark.visible = false
		button.add_child(mark)
		button.resized.connect(func() -> void: mark.position = Vector2(button.size.x - 19.0, (button.size.y - 14.0) * 0.5))
		buttons.append(button)
		_marks.append(mark)
		_tints.append(tints[index] if index < tints.size() else T.ACCENT_ACID_LIME)
	for index: int in range(count - 1, -1, -1):
		add_child(buttons[index])


func set_active(index: int) -> void:
	if index == active:
		return
	active = index
	for i: int in range(buttons.size()):
		var on: bool = i == index
		buttons[i].add_theme_stylebox_override("normal", _box(_tints[i] if on else T.SURFACE_PANEL_ELEVATED))
		buttons[i].add_theme_color_override("font_color", T.INK_BORDER_BLACK if on else T.TEXT_PRIMARY)


## 0 OK, 1 WATCH, 2 DANGER per option; a mark shows only above 0.
func set_marks(severities: Array[int]) -> void:
	for index: int in range(_marks.size()):
		var severity: int = severities[index] if index < severities.size() else 0
		_marks[index].set_severity(severity)
		_marks[index].visible = severity > 0


func marks() -> Array[int]:
	var found: Array[int] = []
	for mark: SeverityMark in _marks:
		found.append(mark.severity if mark.visible else 0)
	return found


func is_mark_visible(index: int) -> bool:
	return _marks[index].visible


func _box(fill: Color) -> StyleBoxFlat:
	var box := UI.style(fill)
	box.content_margin_left = 8.0
	box.content_margin_right = 22.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	return box


func _on_pressed(index: int) -> void:
	set_active(index)
	selected.emit(index)
