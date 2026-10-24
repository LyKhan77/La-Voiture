extends Control
## The Critical Strategy Override modal: a wheatpaste street poster (taped paper, thick ink border,
## lime + crimson offset slabs, a yellow shout) that stops LAUNCH TO GRID when a car starts on the
## wrong rubber for the weather. It fixes its own looks and strings; the garage only calls
## `present()` and listens to the three buttons.
const StreetStyle := preload("res://scripts/ui/street_style.gd")
const HazardStripe := preload("res://scripts/ui/manga/hazard_stripe.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const FONT_MONO := preload("res://assets/fonts/JetBrainsMono.ttf")
const FONT_HEADER := preload("res://assets/fonts/BarlowCondensed.ttf")
const FONT_DISPLAY := preload("res://assets/fonts/Anton.ttf")
const FONT_MARKER := preload("res://assets/fonts/PermanentMarker.ttf")
const INK := Color("#050505")
const PAPER := Color("#F5F2E8")
const LIME := Color("#CCFF00")
const CRIMSON := Color("#FF1E56")
const YELLOW := Color("#FFE600")
const PAPER_SIZE := Vector2(640.0, 800.0)
const PAPER_AT := Vector2(640.0, 150.0)
const TILT: float = -0.035
const BORDER_PX: float = 6.0
const CELL_SIZE := Vector2(274.0, 170.0)
const CELL_GAP: float = 12.0
## [label, value, note, colour] per penalty cell, per hazard.
const SLICKS_CELLS: Array = [
	["CORNERING SPEED LIMIT", "-45% SLOW", "Grip lateral ambruk total di tikungan.", CRIMSON],
	["BRAKING DISTANCE", "3.0x LONGER", "Roda terkunci & meluncur tak terkendali.", YELLOW],
	["STRAIGHT-LINE HEADROOM", "100% TOPSPEED", "Kecepatan lurus tetap tinggi (wheelspin awal).", LIME],
	["SOLO SPIN RISK", "500% (5x LIPAT)", "Peluang melintir mandiri di tiap tikungan.", CRIMSON],
]
const WETS_CELLS: Array = [
	["CORNERING SPEED LIMIT", "-30% SLOW", "Tapak lunak melepuh, grip tikungan turun.", CRIMSON],
	["TYRE TEMPERATURE", ">130 C SIZZLE", "Karet mendidih di atas aspal kering.", YELLOW],
	["TYRE WEAR RATE", "5-6x FASTER", "Tapak habis dalam hitungan lap.", CRIMSON],
	["PUNCTURE WINDOW", "LAP 2-3", "Ban meletus bila tidak segera masuk pit.", CRIMSON],
]
static var _grain: ImageTexture
var title: Label
var desc: Label
var hazard_code: Label
var override_button: Button
var apply_button: Button
var cancel_button: Button
var _cell_labels: Array = [] # [value Label, note Label] per cell
var _cell_heads: Array[Label] = []
var _paper: Control
func _init() -> void:
	name = "MismatchModal"
	position = Vector2.ZERO
	size = Vector2(1920.0, 1080.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.size = size
	backdrop.color = Color(0.03, 0.04, 0.06, 0.78)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	_paper = Control.new()
	_paper.name = "Poster"
	_paper.position = PAPER_AT
	_paper.size = PAPER_SIZE
	_paper.pivot_offset = PAPER_SIZE * 0.5
	_paper.rotation = TILT
	_paper.mouse_filter = Control.MOUSE_FILTER_STOP
	_paper.draw.connect(_draw_paper)
	add_child(_paper)
	_tape(Vector2(-62.0, 30.0), -0.73)
	_tape(Vector2(592.0, 30.0), 0.73)
	var shout := _plate(" 「アホか！？」ARE YOU CRAZY?! ", FONT_MARKER, 28, YELLOW, INK)
	shout.name = "ComicBubble"
	shout.position = Vector2(PAPER_SIZE.x + 22.0 - shout.size.x, -40.0)
	shout.rotation = 0.087
	shout.z_index = 2
	var alert := _plate("CRITICAL MISMATCH ALERT", FONT_MONO, 15, CRIMSON, Color.WHITE)
	alert.position = Vector2(40.0, 36.0)
	hazard_code = _label(_paper, "", FONT_MONO, 15, CRIMSON, Vector2(300.0, 40.0), Vector2(300.0, 22.0), HORIZONTAL_ALIGNMENT_RIGHT)
	var stripe := HazardStripe.new(INK, CRIMSON)
	stripe.position = Vector2(40.0, 86.0)
	stripe.size = Vector2(560.0, 12.0)
	_paper.add_child(stripe)
	title = _label(_paper, "", FONT_DISPLAY, 54, Color(0.04, 0.05, 0.08), Vector2(40.0, 110.0), Vector2(560.0, 64.0))
	desc = _label(_paper, "", FONT_HEADER, 21, Color(0.07, 0.09, 0.13), Vector2(40.0, 182.0), Vector2(560.0, 84.0))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index: int in range(4):
		_cell(index)
	override_button = _button("FORCE OVERRIDE\n[DEATH WISH]", CRIMSON, Color.WHITE, Rect2(40.0, 650.0, 290.0, 84.0), 26)
	override_button.name = "OverrideButton"
	apply_button = _button("SLAP WETS ON\n[CREW REC]", LIME, INK, Rect2(346.0, 650.0, 254.0, 84.0), 26)
	apply_button.name = "ApplyButton"
	cancel_button = Button.new()
	cancel_button.name = "CancelButton"
	cancel_button.text = "CANCEL [ESC]"
	cancel_button.flat = true
	cancel_button.position = Vector2(220.0, 756.0)
	cancel_button.size = Vector2(200.0, 24.0)
	cancel_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel_button.add_theme_font_override("font", FONT_MONO)
	cancel_button.add_theme_font_size_override("font_size", 12)
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		cancel_button.add_theme_color_override(state, Color(0.3, 0.3, 0.32))
	cancel_button.add_theme_color_override("font_hover_color", INK)
	_paper.add_child(cancel_button)
## Fills the poster for `hazard_type` ("SLICKS_ON_WET" | "WETS_ON_DRY") and shows it.
func present(hazard_type: String, water_pct: float, track_temp: float, which_cars: String) -> void:
	var slicks: bool = hazard_type == "SLICKS_ON_WET"
	title.text = "SLICKS ON MONSOON RAIN!" if slicks else "WET TYRES ON BONE DRY TRACK!"
	title.add_theme_font_size_override("font_size", 54 if slicks else 44)
	hazard_code.text = "HAZARD CODE: 994-AQUAPLANE" if slicks else "HAZARD CODE: 138-BLISTER"
	if slicks:
		desc.text = "Lintasan basah %d%% namun %s memakai ban SLICK tanpa alur air! Mobil tidak akan mampu memecah lapisan air di atas aspal:" % [roundi(water_pct), which_cars]
		apply_button.text = "SLAP WETS ON\n[CREW REC]"
	else:
		desc.text = "Lintasan kering, aspal %.0f C, namun %s memakai ban WET! Karet lunak akan mendidih dan melepuh di atas aspal panas:" % [track_temp, which_cars]
		apply_button.text = "SLAP SLICKS ON\n[CREW REC]"
	var cells: Array = SLICKS_CELLS if slicks else WETS_CELLS
	for index: int in range(4):
		var entry: Array = cells[index]
		_cell_heads[index].text = entry[0]
		var labels: Array = _cell_labels[index]
		(labels[0] as Label).text = entry[1]
		(labels[0] as Label).add_theme_color_override("font_color", entry[3])
		(labels[1] as Label).text = entry[2]
	visible = true
	apply_button.grab_focus()
func _draw_paper() -> void:
	_paper.draw_rect(Rect2(Vector2(-14.0, 0.0), PAPER_SIZE), LIME)
	_paper.draw_rect(Rect2(Vector2(14.0, 14.0), PAPER_SIZE), CRIMSON)
	_paper.draw_rect(Rect2(Vector2.ZERO, PAPER_SIZE), PAPER)
	_paper.draw_texture_rect(_grain_texture(), Rect2(Vector2.ZERO, PAPER_SIZE), true)
	_paper.draw_rect(Rect2(Vector2.ONE * BORDER_PX * 0.5, PAPER_SIZE - Vector2.ONE * BORDER_PX), INK, false, BORDER_PX)
static func _grain_texture() -> ImageTexture:
	if _grain == null:
		var image := Image.create(7, 7, false, Image.FORMAT_RGBA8)
		image.set_pixel(3, 3, Color(0.0, 0.0, 0.0, 0.09))
		image.set_pixel(4, 3, Color(0.0, 0.0, 0.0, 0.09))
		_grain = ImageTexture.create_from_image(image)
	return _grain
func _cell(index: int) -> void:
	var cell := Panel.new()
	cell.name = "PenaltyCell%d" % (index + 1)
	cell.position = Vector2(40.0 + float(index % 2) * (CELL_SIZE.x + CELL_GAP), 272.0 + float(index / 2) * (CELL_SIZE.y + CELL_GAP))
	cell.size = CELL_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color.BLACK
	cell.add_theme_stylebox_override("panel", box)
	_paper.add_child(cell)
	var head := _label(cell, "", FONT_MONO, 12, Color("#9aa3b8"), Vector2(16.0, 12.0), Vector2(250.0, 18.0))
	_cell_heads.append(head)
	var value := _label(cell, "", FONT_DISPLAY, 32, Color.WHITE, Vector2(16.0, 34.0), Vector2(250.0, 44.0))
	var note := _label(cell, "", FONT_HEADER, 15, Color("#aab0c0"), Vector2(16.0, 88.0), Vector2(242.0, 70.0))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cell_labels.append([value, note])
func _tape(at: Vector2, tilt: float) -> void:
	var tape := ColorRect.new()
	tape.name = "DuctTape"
	tape.position = at
	tape.size = Vector2(120.0, 32.0)
	tape.pivot_offset = tape.size * 0.5
	tape.rotation = tilt
	tape.color = Color(0.78, 0.8, 0.85, 0.55)
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tape.z_index = 2
	_paper.add_child(tape)
## A skewed street plate holding one line of type (the shout, the alert tag).
func _plate(text: String, font: Font, font_size: int, fill: Color, ink: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	var box := StreetStyle.plate(fill, Color.BLACK, Vector2(4.0, 4.0), 3 if font_size < 20 else 4)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	label.add_theme_stylebox_override("normal", box)
	_paper.add_child(label)
	label.size = label.get_minimum_size()
	return label
func _label(parent: Control, text: String, font: Font, font_size: int, color: Color, at: Vector2, label_size: Vector2,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = label_size
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
func _button(text: String, fill: Color, ink: Color, rect: Rect2, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", FONT_HEADER)
	button.add_theme_font_size_override("font_size", font_size)
	var rest := StreetStyle.plate(fill, Color.BLACK, Vector2(6.0, 6.0), 4)
	var hover := StreetStyle.plate(fill.lightened(0.18), Color.BLACK, Vector2(6.0, 6.0), 4)
	var focus := StreetStyle.plate(fill, Color.BLACK, Vector2(6.0, 6.0), 4, Color.WHITE)
	button.add_theme_stylebox_override("normal", rest)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", focus)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	_paper.add_child(button)
	return button
