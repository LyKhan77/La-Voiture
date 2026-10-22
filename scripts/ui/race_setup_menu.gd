class_name RaceSetupMenu
extends Control

## Exhibition configuration (spec §2.3): the Apex Ring card with a radar traced from the
## race world's own circuit curve, the two COMING SOON venues, and the lap / weather /
## time parameters. Choices are written straight into RaceConfigData, so leaving for the
## garage and coming back keeps them. CONTINUE opens the team garage; BACK returns to
## the main menu without resetting the draft.

const UI := preload("res://scripts/ui/pit_wall_ui.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const ConfigData := preload("res://scripts/core/race_config_data.gd")
const MapView := preload("res://scripts/ui/track_map.gd")
const SettingsScript := preload("res://scripts/core/presentation_settings.gd")
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
const WEATHER_NAMES: Array[String] = [
	"SUNNY DRY // 100% GRIP", "THREATENING RAIN // 60% SHOWER", "DYNAMIC WET // DAMP LINE",
	"FULL MONSOON // LOW VISIBILITY",
]
const TIME_NAMES: Array[String] = ["DAYLIGHT", "GOLDEN HOUR SUNSET", "NIGHT CIRCUIT"]
const RECORD_LAP_S: float = 79.6

var config: ConfigData
var stage: Control
var radar: MapView
var lap_select: OptionButton
var weather_select: OptionButton
var time_select: OptionButton
var summary_label: Label
var continue_button: Button
var back_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	config = ConfigData.get_config()
	_build_backdrop()
	_build_header()
	_build_circuit_card()
	_build_parameters_card()
	_build_coming_soon()
	_build_actions()
	get_viewport().size_changed.connect(fit)
	fit()
	_sync_from_config()
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
	lap_select.select(index)
	_on_laps_selected(index)


## GtWeather preset index: 0 sunny, 1 threatening, 2 dynamic wet, 3 monsoon.
func select_weather(index: int) -> void:
	var clamped: int = clampi(index, 0, WEATHER_NAMES.size() - 1)
	weather_select.select(clamped)
	_on_weather_selected(clamped)


## 0 daylight, 1 golden hour, 2 night.
func select_time_of_day(index: int) -> void:
	var clamped: int = clampi(index, 0, TIME_NAMES.size() - 1)
	time_select.select(clamped)
	_on_time_selected(clamped)


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
	var title := UI.label("EXHIBITION RACE // SETUP", 58, T.TEXT_PRIMARY, DISPLAY)
	title.name = "ScreenTitle"
	title.position = Vector2(90.0, 42.0)
	stage.add_child(title)
	var subtitle := UI.label(
		"APEX RING INTERNATIONAL  //  NEO-BRUTALIST GT3  //  STEP 01 OF 03",
		16, T.TEXT_SECONDARY, MONO
	)
	subtitle.position = Vector2(94.0, 116.0)
	stage.add_child(subtitle)
	var step: Control = UI.header("01 SETUP  /  02 GARAGE  /  03 GRID", T.ACCENT_ACID_LIME)
	step.position = Vector2(1450.0, 56.0)
	step.size = Vector2(380.0, 40.0)
	stage.add_child(step)


func _build_circuit_card() -> void:
	var card := _card(Rect2(90.0, 168.0, 1010.0, 700.0), T.ACCENT_ACID_LIME)
	var header: Control = UI.header("CIRCUIT // APEX RING INTERNATIONAL", T.ACCENT_ACID_LIME)
	header.position = Vector2(28.0, 22.0)
	header.size = Vector2(950.0, 40.0)
	card.add_child(header)
	var tag_bg := ColorRect.new()
	tag_bg.color = T.ACCENT_ACID_LIME
	tag_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_bg.position = Vector2(846.0, 24.0)
	tag_bg.size = Vector2(128.0, 34.0)
	card.add_child(tag_bg)
	var tag := UI.label("ACTIVE", 18, T.INK_BORDER_BLACK, HEADER)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.position = Vector2(846.0, 24.0)
	tag.size = Vector2(128.0, 34.0)
	card.add_child(tag)

	radar = MapView.new()
	radar.name = "CircuitRadar"
	radar.position = Vector2(28.0, 82.0)
	radar.size = Vector2(950.0, 470.0)
	card.add_child(radar)

	var stats: Dictionary = radar.stats()
	var row_y: float = 578.0
	_stat(card, 28.0, row_y, "VENUE LENGTH", "3.840 KM", T.ACCENT_ELECTRIC_CYAN)
	_stat(card, 238.0, row_y, "VENUE TURNS", "14", T.ACCENT_CYBER_YELLOW)
	_stat(card, 438.0, row_y, "VENUE DIRECTION", "CLOCKWISE", T.TEXT_PRIMARY)
	_stat(card, 686.0, row_y, "LAP RECORD", "%d:%06.3f" % [int(RECORD_LAP_S / 60.0), fmod(RECORD_LAP_S, 60.0)], T.ACCENT_ANIME_CRIMSON)
	var sectors := UI.label(
		"LIVE RADAR // %.2f KM // %d BENDS // %s // ELEVATION %.1f m" % [float(stats["length_m"]) / 1000.0, int(stats["corners"]), String(stats["direction"]), float(stats["elevation_delta"])],
		14, T.TEXT_MUTED, MONO
	)
	sectors.position = Vector2(28.0, 664.0)
	sectors.size = Vector2(900.0, 22.0)
	card.add_child(sectors)


func _stat(card: Control, x: float, y: float, caption: String, value: String, accent: Color) -> void:
	var label := UI.label(caption, 14, T.TEXT_MUTED, MONO)
	label.position = Vector2(x, y)
	card.add_child(label)
	var number := UI.label(value, 34, accent, DISPLAY)
	number.name = "Stat" + caption.replace(" ", "")
	number.position = Vector2(x, y + 20.0)
	card.add_child(number)


func _build_parameters_card() -> void:
	var card := _card(Rect2(1140.0, 168.0, 690.0, 700.0), T.ACCENT_ELECTRIC_CYAN)
	var header: Control = UI.header("RACE PARAMETERS", T.ACCENT_ELECTRIC_CYAN)
	header.position = Vector2(28.0, 22.0)
	header.size = Vector2(630.0, 40.0)
	card.add_child(header)

	lap_select = _option(LAP_NAMES, "lap_select", card, 122.0, "LAP DISTANCE")
	lap_select.item_selected.connect(_on_laps_selected)
	weather_select = _option(WEATHER_NAMES, "weather_select", card, 246.0, "WEATHER PRESET")
	weather_select.item_selected.connect(_on_weather_selected)
	time_select = _option(TIME_NAMES, "time_select", card, 370.0, "TIME OF RACE")
	time_select.item_selected.connect(_on_time_selected)

	var box := Control.new()
	box.position = Vector2(28.0, 492.0)
	box.size = Vector2(630.0, 166.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	UI.surface(box, T.ACCENT_ACID_LIME)
	var box_title := UI.label("SETUP SUMMARY", 16, T.ACCENT_ACID_LIME, HEADER)
	box_title.position = Vector2(18.0, 14.0)
	box.add_child(box_title)
	summary_label = UI.label("", 17, T.TEXT_PRIMARY, MONO)
	summary_label.name = "SetupSummary"
	summary_label.position = Vector2(18.0, 48.0)
	summary_label.size = Vector2(590.0, 100.0)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary_label)


func _option(items: Array, node_name: String, parent: Control, y: float, caption: String) -> OptionButton:
	var label := UI.label(caption, 15, T.TEXT_SECONDARY, MONO)
	label.position = Vector2(28.0, y)
	parent.add_child(label)
	var option := OptionButton.new()
	option.name = node_name
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	option.add_theme_font_override("font", HEADER)
	option.add_theme_font_size_override("font_size", 21)
	for state: String in ["normal", "disabled"]:
		option.add_theme_stylebox_override(state, UI.style(T.SURFACE_PANEL_ELEVATED))
	for state: String in ["hover", "pressed", "focus"]:
		option.add_theme_stylebox_override(state, UI.style(T.SURFACE_SNAP_INVERT, T.ACCENT_ELECTRIC_CYAN))
	for state: String in ["hover", "pressed", "focus"]:
		option.add_theme_color_override("font_" + state + "_color", T.INK_BORDER_BLACK)
	option.add_theme_color_override("font_color", T.TEXT_PRIMARY)
	option.position = Vector2(28.0, y + 24.0)
	option.size = Vector2(630.0, 56.0)
	for item: String in items:
		option.add_item(item)
	parent.add_child(option)
	return option


func _build_coming_soon() -> void:
	_coming_soon_card(Vector2(90.0, 884.0), "SUZUKA TOUGE NIGHT")
	_coming_soon_card(Vector2(604.0, 884.0), "MACAU GP GUIA CIRCUIT")


func _coming_soon_card(at: Vector2, venue: String) -> void:
	var card := UI.button(venue, T.TEXT_MUTED)
	card.name = "ComingSoon" + venue.split(" ")[0]
	card.disabled = true
	card.focus_mode = Control.FOCUS_NONE
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_theme_font_override("font", DISPLAY)
	card.add_theme_font_size_override("font_size", 20)
	card.add_theme_color_override("font_disabled_color", T.TEXT_MUTED)
	card.position = at
	card.size = Vector2(496.0, 66.0)
	stage.add_child(card)
	var strip := _hazard(Vector2(178.0, 34.0))
	strip.position = Vector2(304.0, 16.0)
	card.add_child(strip)
	var soon := UI.label("COMING SOON", 18, T.TEXT_PRIMARY, HEADER)
	soon.add_theme_color_override("font_outline_color", T.INK_BORDER_BLACK)
	soon.add_theme_constant_override("outline_size", 5)
	soon.position = Vector2(318.0, 21.0)
	card.add_child(soon)


func _build_actions() -> void:
	back_button = UI.button("BACK TO MAIN MENU", T.ACCENT_ANIME_CRIMSON)
	back_button.name = "BackButton"
	back_button.position = Vector2(90.0, 980.0)
	back_button.size = Vector2(360.0, 62.0)
	back_button.pressed.connect(_on_back_pressed)
	stage.add_child(back_button)
	continue_button = UI.button("CONTINUE TO TEAM GARAGE  >>", T.ACCENT_ACID_LIME)
	continue_button.name = "ContinueButton"
	continue_button.position = Vector2(1180.0, 968.0)
	continue_button.size = Vector2(650.0, 80.0)
	continue_button.add_theme_font_size_override("font_size", 26)
	continue_button.pressed.connect(_on_continue_pressed)
	stage.add_child(continue_button)
	var hint := UI.label(
		"ENTRY RETAINED WHILE YOU PICK A TEAM  //  ESC BACK",
		13, T.TEXT_MUTED, MONO
	)
	hint.position = Vector2(480.0, 1004.0)
	stage.add_child(hint)
	_focus_ring()


func _focus_ring() -> void:
	var chain: Array[Control] = [lap_select, weather_select, time_select, back_button, continue_button]
	for index: int in range(chain.size()):
		chain[index].focus_next = chain[(index + 1) % chain.size()].get_path()
		chain[index].focus_previous = chain[(index + chain.size() - 1) % chain.size()].get_path()
	lap_select.grab_focus()


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
