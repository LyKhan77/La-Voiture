class_name ChipGrid
extends GridContainer

## A grid of colour chips (the tyre compounds), two lines each ("S" over "SOFT"). Same shape as ModeRow
## (`buttons`, `active`, `set_active`, `selected`); the active chip is full strength, the others dimmed.

signal selected(index: int)
signal hovered(index: int)
signal unhovered

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")

const DIM_ALPHA: float = 0.55

var buttons: Array[Button] = []
var active: int = -1


func _init(labels: Array[String], words: Array[String], colors: Array[Color], chip: Vector2 = Vector2(72.0, 46.0), column_count: int = 3) -> void:
	columns = column_count
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index: int in range(labels.size()):
		var button := UI.button("%s\n%s" % [labels[index], words[index]])
		button.add_theme_font_size_override("font_size", 13)
		button.custom_minimum_size = chip
		button.focus_mode = Control.FOCUS_NONE
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			var box := UI.style(colors[index] if state != "hover" else colors[index].lightened(0.25))
			box.set_content_margin_all(2)
			button.add_theme_stylebox_override(state, box)
		for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(color_name, T.INK_BORDER_BLACK)
		button.pressed.connect(_on_pressed.bind(index))
		button.mouse_entered.connect(hovered.emit.bind(index))
		button.mouse_exited.connect(unhovered.emit)
		button.modulate.a = DIM_ALPHA
		add_child(button)
		buttons.append(button)


func set_active(index: int) -> void:
	if index == active:
		return
	active = index
	for i: int in range(buttons.size()):
		buttons[i].modulate.a = 1.0 if i == index else DIM_ALPHA


func _on_pressed(index: int) -> void:
	set_active(index)
	selected.emit(index)
