class_name RaceSetupMenu
extends Control

## Exhibition configuration (spec §2.3), Concept 01 "hero map" layout: the Apex Ring map fills the
## left of the screen (traced live from the race world's own circuit curve, with sectors, the real
## DRS zones and numbered corners), a strip of venue cards sits under it (Apex Ring selected, the
## other two COMING SOON), and laps / weather / time are skewed chips on the right. Choices are
## written straight into RaceConfigData, so leaving for the garage and coming back keeps them.
## CONTINUE opens the team garage; BACK returns to the main menu without resetting the draft.

const UI := preload("res://scripts/ui/pit_wall_ui.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const ConfigData := preload("res://scripts/core/race_config_data.gd")
const MapView := preload("res://scripts/ui/track_map.gd")
const SettingsScript := preload("res://scripts/core/presentation_settings.gd")
const StreetStyle := preload("res://scripts/ui/street_style.gd")
const ChipRow := preload("res://scripts/ui/chip_row.gd")
const TITLE_LOGO := preload("res://assets/ui/title/game-title-logo-la-voiture-with-a-clear-cmvkjm70.png")
const HEADER := preload("res://assets/fonts/BarlowCondensed.ttf")
const MONO := preload("res://assets/fonts/JetBrainsMono.ttf")
const DISPLAY := preload("res://assets/fonts/Anton.ttf")

const MAIN_SCENE := "res://scenes/main.tscn"
const GARAGE_SCENE := "res://scenes/ui/garage_team_select.tscn"
const STAGE := Vector2(1920.0, 1080.0)

const LAPS: Array[int] = [3, 5, 10]
const LAP_NAMES: Array[String] = [
	"QUICK SPRINT // 3 LAPS", "STANDARD // 5 LAPS", "ENDURANCE // 10 LAPS",
]
## Chip captions, in the same order as LAPS / WEATHER_NAMES / TIME_NAMES.
const LAP_CHIPS: Array[String] = ["3", "5", "10"]
const WEATHER_CHIPS: Array[String] = ["SUNNY", "RAIN?", "WET", "MONSOON"]
const TIME_CHIPS: Array[String] = ["DAY", "SUNSET", "NIGHT"]
const WEATHER_NAMES: Array[String] = [
	"SUNNY DRY // 100% GRIP", "THREATENING RAIN // 60% SHOWER", "DYNAMIC WET // DAMP LINE",
	"FULL MONSOON // LOW VISIBILITY",
]
const TIME_NAMES: Array[String] = ["DAYLIGHT", "GOLDEN HOUR SUNSET", "NIGHT CIRCUIT"]
const RECORD_LAP_S: float = 79.6

var config: ConfigData
var stage: Control
var radar: MapView
var lap_select: ChipRow
var weather_select: ChipRow
var time_select: ChipRow
var summary_label: Label
var continue_button: Button
var back_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	config = ConfigData.get_config()
	_build_backdrop()
	_build_header()
	_build_map_card()
	_build_venue_strip()
	_build_parameters()
	_build_actions()
	get_viewport().size_changed.connect(fit)
	fit()
	_sync_from_config()
	lap_select.focus_selected() # after the saved choice is shown, so the keyboard starts on it
	SettingsScript.apply_to_tree(self)
	AudioManager.of(self).start_music()


func fit() -> void:
	if stage == null or not is_inside_tree():
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var factor: float = minf(view.x / STAGE.x, view.y / STAGE.y)
	stage.scale = Vector2(factor, factor)
	stage.position = (view - STAGE * factor) * 0.5


# --- public setup API ----------------------------------------------------------------------------

## 3, 5 or 10; anything else falls back to Standard.
func select_laps(laps: int) -> void:
	var index: int = LAPS.find(laps)
	if index < 0:
		index = 1
	lap_select.press(index)


## GtWeather preset index: 0 sunny, 1 threatening, 2 dynamic wet, 3 monsoon.
func select_weather(index: int) -> void:
	var clamped: int = clampi(index, 0, WEATHER_NAMES.size() - 1)
	weather_select.press(clamped)


## 0 daylight, 1 golden hour, 2 night.
func select_time_of_day(index: int) -> void:
	var clamped: int = clampi(index, 0, TIME_NAMES.size() - 1)
	time_select.press(clamped)


# --- build ---------------------------------------------------------------------------------------

func _build_backdrop() -> void:
	stage = Control.new()
	stage.name = "Stage"
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var canvas := ColorRect.new()
	canvas.color = T.BG_CANVAS_DEEP
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(canvas)
	var bar := ColorRect.new()
	bar.color = Color(T.ACCENT_ELECTRIC_CYAN, 0.05)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(-140.0, 120.0)
	bar.size = Vector2(2200.0, 210.0)
	bar.rotation = -0.045
	stage.add_child(bar)


func _build_header() -> void:
	var logo := TextureRect.new()
	logo.name = "TitleLogo"
	logo.texture = TITLE_LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.position = Vector2(30.0, -40.0)
	logo.size = Vector2(520.0, 290.0)
	stage.add_child(logo)
	var title := UI.label("/// EXHIBITION RACE // SETUP", 30, T.ACCENT_ELECTRIC_CYAN, MONO)
	title.name = "ScreenTitle"
	title.position = Vector2(570.0, 74.0)
	stage.add_child(title)
	var subtitle := UI.label("STEP 01 OF 03  //  PICK THE CIRCUIT, THEN LAPS, WEATHER AND TIME", 16, T.TEXT_SECONDARY, MONO)
	subtitle.position = Vector2(574.0, 122.0)
	stage.add_child(subtitle)
	var step: Control = UI.header("01 SETUP  /  02 GARAGE  /  03 GRID", T.ACCENT_ACID_LIME)
	step.position = Vector2(1450.0, 56.0)
	step.size = Vector2(380.0, 40.0)
	stage.add_child(step)


## The hero: the circuit map on a ground plate, tagged with the venue name.
func _build_map_card() -> void:
	var card := _card(Rect2(60.0, 196.0, 1140.0, 650.0), T.ACCENT_ACID_LIME)
	radar = MapView.new()
	radar.name = "CircuitRadar"
	radar.position = Vector2(14.0, 18.0)
	radar.size = Vector2(1112.0, 614.0)
	card.add_child(radar)
	var tag := StreetStyle.badge("CIRCUIT  //  APEX RING INTERNATIONAL")
	tag.name = "CircuitTag"
	tag.position = Vector2(-18.0, -22.0)
	card.add_child(tag)
	var active := StreetStyle.badge("ACTIVE", T.ACCENT_ACID_LIME, 20)
	active.position = Vector2(1012.0, -18.0)
	card.add_child(active)
	var legend := UI.label("S1  S2  S3 SECTORS   //   LIME DOTS = DRS ZONES   //   T1.. CORNERS   //   CHEQUERED = START / FINISH", 13, T.TEXT_MUTED, MONO)
	legend.position = Vector2(30.0, 620.0)
	card.add_child(legend)


## The venue strip under the map: Apex Ring is selected, the others are COMING SOON.
func _build_venue_strip() -> void:
	var header := UI.label("CIRCUIT SELECT", 14, T.TEXT_MUTED, MONO)
	header.position = Vector2(66.0, 868.0)
	stage.add_child(header)
	_venue_card(Vector2(60.0, 892.0), "APEX RING", "CircuitCardAPEX", true)
	_venue_card(Vector2(448.0, 892.0), "SUZUKA TOUGE NIGHT", "ComingSoonSUZUKA", false)
	_venue_card(Vector2(836.0, 892.0), "MACAU GUIA CIRCUIT", "ComingSoonMACAU", false)


func _venue_card(at: Vector2, venue: String, node_name: String, active: bool) -> void:
	var card := UI.button(venue, T.ACCENT_ACID_LIME if active else T.TEXT_MUTED)
	card.name = node_name
	StreetStyle.skin(card, 3, Vector2(4.0, 4.0), 24)
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_theme_font_override("font", DISPLAY)
	card.add_theme_font_size_override("font_size", 19)
	card.position = at
	card.size = Vector2(364.0, 62.0)
	card.focus_mode = Control.FOCUS_NONE
	if active:
		# The selected venue wears the hot lime face for good.
		var hot: StyleBox = card.get_theme_stylebox("pressed")
		for state: String in ["normal", "hover", "disabled"]:
			card.add_theme_stylebox_override(state, hot)
		for state: String in ["font_color", "font_hover_color"]:
			card.add_theme_color_override(state, T.INK_BORDER_BLACK)
	else:
		card.disabled = true
		card.add_theme_color_override("font_disabled_color", T.TEXT_MUTED)
	stage.add_child(card)
	if not active:
		var strip := _hazard(Vector2(150.0, 30.0))
		strip.position = Vector2(196.0, 16.0)
		card.add_child(strip)
		var soon := UI.label("COMING SOON", 16, T.TEXT_PRIMARY, HEADER)
		soon.add_theme_color_override("font_outline_color", T.INK_BORDER_BLACK)
		soon.add_theme_constant_override("outline_size", 5)
		soon.position = Vector2(214.0, 19.0)
		card.add_child(soon)


## Laps / weather / time chips, the circuit numbers and the summary plate.
func _build_parameters() -> void:
	var header: Control = UI.header("RACE PARAMETERS", T.ACCENT_ELECTRIC_CYAN)
	header.position = Vector2(1240.0, 196.0)
	header.size = Vector2(620.0, 40.0)
	stage.add_child(header)
	lap_select = _chips("lap_select", "LAP DISTANCE", LAP_CHIPS, 262.0, 24)
	lap_select.item_selected.connect(_on_laps_selected)
	weather_select = _chips("weather_select", "WEATHER", WEATHER_CHIPS, 374.0, 21)
	weather_select.item_selected.connect(_on_weather_selected)
	time_select = _chips("time_select", "TIME OF RACE", TIME_CHIPS, 486.0, 22)
	time_select.item_selected.connect(_on_time_selected)

	var stats: Dictionary = radar.stats()
	_number(1240.0, 590.0, "LENGTH", "%.2f KM" % (float(stats["length_m"]) / 1000.0), T.TEXT_PRIMARY)
	_number(1470.0, 590.0, "CORNERS", str(int(stats["corners"])), T.ACCENT_CYBER_YELLOW)
	_number(1640.0, 590.0, "LAP RECORD", "%d:%06.3f" % [int(RECORD_LAP_S / 60.0), fmod(RECORD_LAP_S, 60.0)], T.ACCENT_ELECTRIC_CYAN)
	var facts := UI.label(
		"%s  //  ELEVATION %.1f m  //  %d DRS ZONES" % [String(stats["direction"]), float(stats["elevation_delta"]), radar.drs_zones.size()],
		14, T.TEXT_MUTED, MONO
	)
	facts.position = Vector2(1240.0, 666.0)
	stage.add_child(facts)

	var box := Control.new()
	box.position = Vector2(1240.0, 712.0)
	box.size = Vector2(620.0, 134.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(box)
	UI.surface(box, T.ACCENT_ACID_LIME)
	var box_title := UI.label("SETUP SUMMARY", 16, T.ACCENT_ACID_LIME, HEADER)
	box_title.position = Vector2(18.0, 12.0)
	box.add_child(box_title)
	summary_label = UI.label("", 17, T.TEXT_PRIMARY, MONO)
	summary_label.name = "SetupSummary"
	summary_label.position = Vector2(18.0, 42.0)
	summary_label.size = Vector2(584.0, 84.0)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary_label)


func _chips(node_name: String, caption: String, labels: Array[String], y: float, font_size: int) -> ChipRow:
	var label := UI.label(caption, 15, T.TEXT_SECONDARY, MONO)
	label.position = Vector2(1244.0, y)
	stage.add_child(label)
	var row := ChipRow.new()
	row.name = node_name
	row.position = Vector2(1240.0, y + 28.0)
	row.size = Vector2(620.0, 56.0)
	stage.add_child(row)
	row.setup(labels, font_size)
	return row


func _number(x: float, y: float, caption: String, value: String, accent: Color) -> void:
	var label := UI.label(caption, 14, T.TEXT_MUTED, MONO)
	label.position = Vector2(x, y)
	stage.add_child(label)
	var number := UI.label(value, 34, accent, DISPLAY)
	number.name = "Stat" + caption.replace(" ", "")
	number.position = Vector2(x, y + 20.0)
	stage.add_child(number)


func _build_actions() -> void:
	back_button = UI.button("/// BACK TO MAIN MENU", T.ACCENT_ANIME_CRIMSON)
	back_button.name = "BackButton"
	StreetStyle.skin(back_button, 4, Vector2(6.0, 6.0), 24)
	back_button.position = Vector2(60.0, 988.0)
	back_button.size = Vector2(380.0, 58.0)
	back_button.pressed.connect(_on_back_pressed)
	stage.add_child(back_button)
	continue_button = UI.button("/// CONTINUE: TEAM GARAGE", T.ACCENT_ACID_LIME)
	continue_button.name = "ContinueButton"
	StreetStyle.skin(continue_button, 4, Vector2(8.0, 8.0), 30)
	var hot: StyleBox = continue_button.get_theme_stylebox("pressed")
	continue_button.add_theme_stylebox_override("normal", hot) # the call to action always wears the lime face
	continue_button.add_theme_color_override("font_color", T.INK_BORDER_BLACK)
	continue_button.add_theme_color_override("font_hover_color", T.INK_BORDER_BLACK)
	continue_button.position = Vector2(1240.0, 970.0)
	continue_button.size = Vector2(620.0, 78.0)
	continue_button.pressed.connect(_on_continue_pressed)
	stage.add_child(continue_button)
	var hint := UI.label("ENTRY RETAINED WHILE YOU PICK A TEAM  //  ESC BACK", 13, T.TEXT_MUTED, MONO)
	hint.position = Vector2(480.0, 1008.0)
	stage.add_child(hint)
	_focus_ring()


func _focus_ring() -> void:
	var chain: Array[Control] = [lap_select.first_chip(), weather_select.first_chip(), time_select.first_chip(), back_button, continue_button]
	for index: int in range(chain.size()):
		chain[index].focus_next = chain[(index + 1) % chain.size()].get_path()
		chain[index].focus_previous = chain[(index + chain.size() - 1) % chain.size()].get_path()
	lap_select.focus_selected()


func _card(rect: Rect2, accent: Color) -> Control:
	var card := Control.new()
	card.position = rect.position
	card.size = rect.size
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(card)
	UI.surface(card, accent)
	return card


## Diagonal yellow/black hazard ribbon, clipped to its rect.
func _hazard(size_px: Vector2) -> Control:
	var strip := Control.new()
	strip.size = size_px
	strip.custom_minimum_size = size_px
	strip.clip_contents = true
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.draw.connect(func() -> void:
		strip.draw_rect(Rect2(Vector2.ZERO, strip.size), T.INK_BORDER_BLACK, true)
		var width: float = 12.0
		var gap: float = 10.0
		var x: float = -strip.size.y
		while x < strip.size.x + strip.size.y:
			strip.draw_colored_polygon(PackedVector2Array([
				Vector2(x, strip.size.y),
				Vector2(x + width, strip.size.y),
				Vector2(x + width + strip.size.y, 0.0),
				Vector2(x + strip.size.y, 0.0),
			]), T.ACCENT_CYBER_YELLOW)
			x += width + gap
	)
	strip.resized.connect(strip.queue_redraw)
	return strip


# --- state ---------------------------------------------------------------------------------------

func _sync_from_config() -> void:
	var lap_index: int = maxi(LAPS.find(config.total_laps), 1)
	lap_select.select(lap_index)
	weather_select.select(clampi(config.weather_preset, 0, WEATHER_NAMES.size() - 1))
	time_select.select(clampi(config.time_of_day, 0, TIME_NAMES.size() - 1))
	_refresh_summary()


func _refresh_summary() -> void:
	summary_label.text = "%d LAPS  //  %s\n%s  //  %s" % [
		config.total_laps,
		WEATHER_NAMES[clampi(config.weather_preset, 0, WEATHER_NAMES.size() - 1)].split(" // ")[0],
		TIME_NAMES[clampi(config.time_of_day, 0, TIME_NAMES.size() - 1)],
		"TEAM GARAGE NEXT",
	]


func _on_laps_selected(index: int) -> void:
	config.total_laps = LAPS[clampi(index, 0, LAPS.size() - 1)]
	_refresh_summary()
	AudioManager.click(self)


func _on_weather_selected(index: int) -> void:
	config.weather_preset = clampi(index, 0, WEATHER_NAMES.size() - 1)
	_refresh_summary()
	AudioManager.click(self)


func _on_time_selected(index: int) -> void:
	config.time_of_day = clampi(index, 0, TIME_NAMES.size() - 1)
	_refresh_summary()
	AudioManager.click(self)


func _on_back_pressed() -> void:
	AudioManager.click(self)
	_go(MAIN_SCENE)


func _on_continue_pressed() -> void:
	AudioManager.click(self)
	_go(GARAGE_SCENE)


func _go(path: String) -> void:
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("RaceSetupMenu: cannot open %s (%s)" % [path, error_string(error)])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		_on_back_pressed()
