class_name ModeRow
extends HBoxContainer

## A row of exclusive hard-edged buttons (pace, fuel mix, ERS, tyre, tactic mode). The
## active one snaps to the inverted surface with an acid outline, the rest sit on the
## elevated panel colour. Emits selected(index) on a click; set_active() is silent.

signal selected(index: int)

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")

var buttons: Array[Button] = []
var active: int = -1

var _tints: Array[Color] = []


func _init(labels: Array[String], tints: Array[Color] = [], font_size: int = 14) -> void:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index: int in range(labels.size()):
		var button := UI.button(labels[index])
		button.add_theme_font_size_override("font_size", font_size)
		button.custom_minimum_size = Vector2(0, 28)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			var box := button.get_theme_stylebox(state) as StyleBoxFlat
			box.set_content_margin_all(3)
		button.pressed.connect(_on_pressed.bind(index))
		add_child(button)
		buttons.append(button)
		_tints.append(tints[index] if index < tints.size() else T.ACCENT_ACID_LIME)


func set_active(index: int) -> void:
	if index == active:
		return
	active = index
	for i: int in range(buttons.size()):
		var on: bool = i == index
		var tint: Color = _tints[i]
		buttons[i].add_theme_stylebox_override("normal", _box(T.SURFACE_SNAP_INVERT, tint) if on else _box(T.SURFACE_PANEL_ELEVATED))
		buttons[i].add_theme_color_override("font_color", T.INK_BORDER_BLACK if on else T.TEXT_PRIMARY)


func _on_pressed(index: int) -> void:
	AudioManager.click(self)
	set_active(index)
	selected.emit(index)


static func _box(fill: Color, border: Color = T.INK_BORDER_BLACK) -> StyleBoxFlat:
	var box := UI.style(fill, border)
	box.set_content_margin_all(3)
	return box
