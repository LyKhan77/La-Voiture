extends HBoxContainer

## A row of skewed street-plate chips where exactly one is selected: the Race Setup's laps, weather and
## time pickers. It answers the OptionButton calls the setup screen and its tests already use
## (`selected`, `select()`, `get_item_count()`, `item_selected`), plus `press()` for a click.

signal item_selected(index: int)

const StreetStyle := preload("res://scripts/ui/street_style.gd")

var selected: int = 0

var _buttons: Array[Button] = []
var _group := ButtonGroup.new()


## Builds one chip per label; `font_size` shrinks the type for the wide four-chip row.
func setup(labels: Array[String], font_size: int = 22) -> void:
	add_theme_constant_override("separation", 12)
	for index: int in range(labels.size()):
		var chip := Button.new()
		chip.text = labels[index]
		chip.toggle_mode = true
		chip.button_group = _group
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		chip.custom_minimum_size = Vector2(0.0, 52.0)
		StreetStyle.skin(chip, 3, Vector2(4.0, 4.0), font_size)
		chip.pressed.connect(_on_chip.bind(index))
		add_child(chip)
		_buttons.append(chip)
	select(0)


func get_item_count() -> int:
	return _buttons.size()


## Marks a chip without announcing it (the OptionButton.select() contract).
func select(index: int) -> void:
	selected = clampi(index, 0, _buttons.size() - 1)
	for chip_index: int in range(_buttons.size()):
		_buttons[chip_index].set_pressed_no_signal(chip_index == selected)


## What a click does: select the chip and announce it.
func press(index: int) -> void:
	select(index)
	item_selected.emit(selected)


func focus_selected() -> void:
	if not _buttons.is_empty():
		_buttons[selected].grab_focus()


func first_chip() -> Button:
	return _buttons[0] if not _buttons.is_empty() else null


func _on_chip(index: int) -> void:
	selected = index
	item_selected.emit(index)
