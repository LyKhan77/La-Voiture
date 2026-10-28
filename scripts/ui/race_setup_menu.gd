class_name RaceSetupMenu
extends Control

## Exhibition configuration (spec §2.3), Concept 01 "hero map" layout: the selected round's own
## circuit map fills the left of the screen (traced live from that circuit's spline, with sectors,
## the real DRS zones and numbered corners) beside the venue artwork and the track's demand bars. One
## carousel under the map walks the 12-round championship calendar (arrows, or click a round), and
## laps / weather / time / race dynamics are skewed chips on the right. Sprint rounds lock the race to
## 3 laps, Grand Prix rounds offer 5 / 10 / 15. DYNAMIC weather shows its lap-by-lap radar strip and
## the seed can be rerolled. Choices are written straight into RaceConfigData, so leaving for the
## garage and coming back keeps them. CONTINUE opens the team garage; BACK returns to the main menu
## without resetting the draft.

const UI := preload("res://scripts/ui/pit_wall_ui.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const ConfigData := preload("res://scripts/core/race_config_data.gd")
const CircuitDataScript := preload("res://scripts/core/circuit_data.gd")
const CircuitRegistry := preload("res://scripts/core/circuit_calendar_registry.gd")
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

## Sprint rounds are always this long; the other lap chips are Grand Prix distances.
const SPRINT_LAPS: int = 3
const DEFAULT_GP_LAPS: int = 5
const LAPS: Array[int] = [3, 5, 10, 15]
const LAP_NAMES: Array[String] = [
	"SPRINT // 3 LAPS", "SHORT GP // 5 LAPS", "STANDARD GP // 10 LAPS", "ENDURANCE GP // 15 LAPS",
]
## Chip captions, in the same order as LAPS / WEATHER_NAMES / TIME_NAMES / DYNAMICS_NAMES.
const LAP_CHIPS: Array[String] = ["3", "5", "10", "15"]
const WEATHER_CHIPS: Array[String] = ["SUNNY", "RAIN?", "WET", "MONSOON", "DYNAMIC"]
const TIME_CHIPS: Array[String] = ["DAY", "SUNSET", "NIGHT", "RANDOM"]
const DYNAMICS_CHIPS: Array[String] = ["CLEAN", "STANDARD", "CHAOS"]
const WEATHER_NAMES: Array[String] = [
	"SUNNY DRY // 100% GRIP", "THREATENING RAIN // 60% SHOWER", "DYNAMIC WET // DAMP LINE",
	"FULL MONSOON // LOW VISIBILITY", "DYNAMIC RADAR // LIVE FORECAST",
]
const TIME_NAMES: Array[String] = ["DAYLIGHT", "GOLDEN HOUR SUNSET", "NIGHT CIRCUIT", "RANDOM // SEED ROLL"]
const DYNAMICS_NAMES: Array[String] = ["CLEAN PACE", "FIA STANDARD", "STREET CHAOS"]
const NIGHT_TIME_INDEX: int = 2
const RANDOM_TIME_INDEX: int = 3
const DYNAMIC_WEATHER_INDEX: int = 4

## The calendar carousel shows this many rounds at once, paged by the active round.
const CAROUSEL_SLOTS: int = 4
const CARD_SIZE := Vector2(246.0, 76.0)
const CARD_GAP: float = 10.0
const CAROUSEL_Y: float = 876.0
const CAROUSEL_X: float = 122.0
## Radar forecast cells, sampled evenly over the race distance.
const METEO_CELLS: int = 6
## Rain share below which a lap reads as dry on the radar, and above which it reads as wet.
const METEO_DRY_BELOW: float = 0.05
const METEO_WET_ABOVE: float = 0.35
const DEMAND_NAMES: Array[String] = ["TOP SPEED", "TECHNICALITY", "TIRE ABRASION", "OVERTAKING"]
const DEMAND_COLORS: Array[Color] = [T.ACCENT_ELECTRIC_CYAN, T.ACCENT_PURPLE_SECTOR, T.ACCENT_ANIME_CRIMSON, T.ACCENT_ACID_LIME]

var config: ConfigData
var stage: Control
var radar: MapView
var lap_select: ChipRow
var weather_select: ChipRow
var time_select: ChipRow
var dynamics_select: ChipRow
var summary_label: Label
var continue_button: Button
var back_button: Button
var reroll_button: Button
## The round the setup screen is pointed at, and the carousel that changes it.
var circuit: CircuitDataScript
var track_prev_button: Button
var track_next_button: Button
var carousel_cards: Array[Button] = []
var circuit_name_label: Label
var circuit_type_label: Label
var circuit_length_label: Label
var circuit_turns_label: Label
var circuit_round_label: Label
var map_tag: Label
var status_badge: Label
var stat_length: Label
var stat_corners: Label
var stat_record: Label
var circuit_facts_label: Label
var venue_art: TextureRect
var venue_art_fallback: Label
var venue_notes_label: Label
var demand_bars: Array[ProgressBar] = []
var lap_rule_badge: Label
var meteo_strip: Control

var _art_cache: Dictionary = {} # preview path -> Texture2D, so paging the calendar never reloads a file


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	config = ConfigData.get_config()
	_build_backdrop()
	_build_header()
	_build_map_card()
	_build_carousel()
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

## 3, 5, 10 or 15; anything else falls back to the short GP. The chip lock only guards clicks, so a
## caller can still ask for any listed distance.
func select_laps(laps: int) -> void:
	var index: int = LAPS.find(laps)
	if index < 0:
		index = 1
	lap_select.press(index)


## GtWeather preset index: 0 sunny, 1 threatening, 2 dynamic wet, 3 monsoon, 4 dynamic radar.
func select_weather(index: int) -> void:
	var clamped: int = clampi(index, 0, WEATHER_NAMES.size() - 1)
	weather_select.press(clamped)


## 0 daylight, 1 golden hour, 2 night, 3 random (rolled from the seed).
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
	var subtitle := UI.label("STEP 01 OF 03  //  PICK THE CIRCUIT, THEN LAPS, WEATHER, TIME AND DYNAMICS", 16, T.TEXT_SECONDARY, MONO)
	subtitle.position = Vector2(574.0, 122.0)
	stage.add_child(subtitle)
	var step: Control = UI.header("01 SETUP  /  02 GARAGE  /  03 GRID", T.ACCENT_ACID_LIME)
	step.position = Vector2(1450.0, 56.0)
	step.size = Vector2(380.0, 40.0)
	stage.add_child(step)


## The hero: the circuit map on a ground plate, tagged with the venue name, and beside it the venue
## artwork, what the track demands of a car and the round's one-line note.
func _build_map_card() -> void:
	var card := _card(Rect2(60.0, 196.0, 1140.0, 640.0), T.ACCENT_ACID_LIME)
	radar = MapView.new()
	radar.name = "CircuitRadar"
	radar.position = Vector2(14.0, 18.0)
	radar.size = Vector2(780.0, 604.0)
	card.add_child(radar)
	map_tag = StreetStyle.badge("CIRCUIT  //  APEX RING INTERNATIONAL")
	map_tag.name = "CircuitTag"
	map_tag.position = Vector2(-18.0, -22.0)
	card.add_child(map_tag)
	status_badge = StreetStyle.badge("ACTIVE // READY", T.ACCENT_ACID_LIME, 20)
	status_badge.name = "CircuitStatusBadge"
	status_badge.position = Vector2(900.0, -18.0)
	card.add_child(status_badge)
	var legend := UI.label("S1 S2 S3 SECTORS  //  LIME DOTS = DRS  //  T1.. CORNERS  //  CHEQUERED = START", 12, T.TEXT_MUTED, MONO)
	legend.position = Vector2(30.0, 614.0)
	card.add_child(legend)
	_build_venue_sidebar(card)


func _build_venue_sidebar(card: Control) -> void:
	var left: float = 812.0
	var width: float = 306.0
	var frame := Panel.new()
	frame.name = "VenueArtFrame"
	frame.position = Vector2(left, 18.0)
	frame.size = Vector2(width, 172.0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", UI.style(T.SURFACE_PANEL_ELEVATED, T.INK_BORDER_BLACK))
	card.add_child(frame)
	venue_art = TextureRect.new()
	venue_art.name = "VenuePreviewArt"
	venue_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	venue_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	venue_art.clip_contents = true
	venue_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	venue_art.position = Vector2(3.0, 3.0)
	venue_art.size = Vector2(width - 6.0, 166.0)
	frame.add_child(venue_art)
	venue_art_fallback = UI.label("", 22, T.TEXT_MUTED, DISPLAY)
	venue_art_fallback.name = "VenueArtFallback"
	venue_art_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	venue_art_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	venue_art_fallback.size = frame.size
	frame.add_child(venue_art_fallback)

	var demand := Control.new()
	demand.name = "TrackDemandPanel"
	demand.position = Vector2(left, 210.0)
	demand.size = Vector2(width, 190.0)
	demand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(demand)
	var demand_title := UI.label("TRACK DEMAND PROFILE", 14, T.ACCENT_ELECTRIC_CYAN, MONO)
	demand.add_child(demand_title)
	for index: int in range(DEMAND_NAMES.size()):
		demand_bars.append(_demand_row(demand, DEMAND_NAMES[index], 28.0 + float(index) * 40.0, DEMAND_COLORS[index], width))

	venue_notes_label = UI.label("", 14, T.TEXT_SECONDARY, MONO)
	venue_notes_label.name = "VenueNotesLabel"
	venue_notes_label.position = Vector2(left, 416.0)
	venue_notes_label.size = Vector2(width, 190.0)
	venue_notes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(venue_notes_label)


func _demand_row(parent: Control, caption: String, y: float, accent: Color, width: float) -> ProgressBar:
	var label := UI.label(caption, 13, T.TEXT_SECONDARY, MONO)
	label.position = Vector2(0.0, y)
	parent.add_child(label)
	var bar := ProgressBar.new()
	bar.name = "Demand" + caption.replace(" ", "")
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(0.0, y + 20.0)
	bar.custom_minimum_size = Vector2(width, 12.0)
	bar.size = Vector2(width, 12.0)
	bar.add_theme_stylebox_override("background", _bar_box(T.SURFACE_PANEL_ELEVATED))
	bar.add_theme_stylebox_override("fill", _bar_box(accent))
	parent.add_child(bar)
	return bar


func _bar_box(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_border_width_all(2)
	box.border_color = T.INK_BORDER_BLACK
	box.set_content_margin_all(0.0)
	return box


## The championship calendar carousel under the map: arrows walk Round 01..12 one at a time, the four
## cards show the active page of rounds and pick one with a click. The metadata plate above them names
## the active round, its type, length and corner count. Selecting a round writes it into
## RaceConfigData at once.
func _build_carousel() -> void:
	circuit_round_label = UI.label("", 14, T.ACCENT_CYBER_YELLOW, MONO)
	circuit_round_label.name = "CircuitRoundLabel"
	circuit_round_label.position = Vector2(66.0, 848.0)
	stage.add_child(circuit_round_label)
	circuit_name_label = UI.label("", 20, T.TEXT_PRIMARY, DISPLAY)
	circuit_name_label.name = "CircuitNameLabel"
	circuit_name_label.position = Vector2(262.0, 842.0)
	stage.add_child(circuit_name_label)
	circuit_type_label = StreetStyle.badge("GRAND PRIX", T.ACCENT_ANIME_CRIMSON, 15)
	circuit_type_label.name = "CircuitTypeLabel"
	circuit_type_label.position = Vector2(620.0, 842.0)
	stage.add_child(circuit_type_label)
	circuit_length_label = UI.label("", 16, T.ACCENT_ELECTRIC_CYAN, MONO)
	circuit_length_label.name = "CircuitLengthLabel"
	circuit_length_label.position = Vector2(800.0, 848.0)
	stage.add_child(circuit_length_label)
	circuit_turns_label = UI.label("", 16, T.TEXT_SECONDARY, MONO)
	circuit_turns_label.name = "CircuitTurnsLabel"
	circuit_turns_label.position = Vector2(920.0, 848.0)
	stage.add_child(circuit_turns_label)
	track_prev_button = _arrow("TrackPrevButton", "<", Vector2(60.0, CAROUSEL_Y))
	track_prev_button.pressed.connect(func() -> void: _select_neighbour(-1))
	track_next_button = _arrow("TrackNextButton", ">", Vector2(1148.0, CAROUSEL_Y))
	track_next_button.pressed.connect(func() -> void: _select_neighbour(1))
	for slot: int in range(CAROUSEL_SLOTS):
		var card := UI.button("", T.ACCENT_ACID_LIME)
		card.name = "CarouselCard%d" % slot
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.clip_text = true
		card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.position = Vector2(CAROUSEL_X + float(slot) * (CARD_SIZE.x + CARD_GAP), CAROUSEL_Y)
		card.size = CARD_SIZE
		card.focus_mode = Control.FOCUS_NONE # the arrows are the keyboard route through the calendar
		card.pressed.connect(_on_card_pressed.bind(slot))
		stage.add_child(card)
		carousel_cards.append(card)


func _arrow(node_name: String, text: String, at: Vector2) -> Button:
	var button := UI.button(text, T.ACCENT_ACID_LIME)
	button.name = node_name
	StreetStyle.skin(button, 3, Vector2(4.0, 4.0), 22)
	button.position = at
	button.size = Vector2(52.0, CARD_SIZE.y)
	button.focus_mode = Control.FOCUS_ALL # the calendar is reachable from the keyboard too
	stage.add_child(button)
	return button


## Laps / weather / time / dynamics chips, the circuit numbers and the summary plate.
func _build_parameters() -> void:
	var header: Control = UI.header("RACE PARAMETERS", T.ACCENT_ELECTRIC_CYAN)
	header.position = Vector2(1240.0, 196.0)
	header.size = Vector2(620.0, 40.0)
	stage.add_child(header)
	reroll_button = UI.button("", T.ACCENT_CYBER_YELLOW)
	reroll_button.name = "RerollSeedButton"
	StreetStyle.skin(reroll_button, 3, Vector2(3.0, 3.0), 15)
	reroll_button.position = Vector2(1620.0, 196.0)
	reroll_button.size = Vector2(240.0, 40.0)
	reroll_button.pressed.connect(_on_reroll_pressed)
	stage.add_child(reroll_button)

	lap_select = _chips("lap_select", "LAP DISTANCE", LAP_CHIPS, 250.0, 24)
	lap_select.item_selected.connect(_on_laps_selected)
	lap_rule_badge = StreetStyle.badge("", T.ACCENT_CYBER_YELLOW, 14)
	lap_rule_badge.name = "LapRuleBadge"
	lap_rule_badge.position = Vector2(1500.0, 244.0)
	stage.add_child(lap_rule_badge)
	weather_select = _chips("weather_select", "WEATHER", WEATHER_CHIPS, 342.0, 19)
	weather_select.item_selected.connect(_on_weather_selected)
	var radar_caption := UI.label("METEO RADAR // RAIN PER LAP", 13, T.TEXT_MUTED, MONO)
	radar_caption.position = Vector2(1560.0, 346.0)
	stage.add_child(radar_caption)
	meteo_strip = Control.new()
	meteo_strip.name = "MeteoRadarStrip"
	meteo_strip.position = Vector2(1240.0, 432.0)
	meteo_strip.size = Vector2(620.0, 44.0)
	meteo_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(meteo_strip)
	time_select = _chips("time_select", "TIME OF RACE", TIME_CHIPS, 486.0, 22)
	time_select.item_selected.connect(_on_time_selected)
	dynamics_select = _chips("dynamics_select", "RACE DYNAMICS", DYNAMICS_CHIPS, 580.0, 22)
	dynamics_select.item_selected.connect(_on_dynamics_selected)
	var skill_matrix := StreetStyle.badge("AI PACE: 26-DRIVER SKILL MATRIX", T.ACCENT_ELECTRIC_CYAN, 13)
	skill_matrix.name = "SkillMatrixBadge"
	skill_matrix.position = Vector2(1560.0, 574.0)
	stage.add_child(skill_matrix)

	var stats: Dictionary = radar.stats()
	stat_length = _number(1240.0, 680.0, "LENGTH", "%.2f KM" % (float(stats["length_m"]) / 1000.0), T.TEXT_PRIMARY)
	stat_corners = _number(1470.0, 680.0, "CORNERS", str(int(stats["corners"])), T.ACCENT_CYBER_YELLOW)
	stat_record = _number(1640.0, 680.0, "LAP RECORD", "--:--.---", T.ACCENT_ELECTRIC_CYAN)
	circuit_facts_label = UI.label("", 14, T.TEXT_MUTED, MONO)
	circuit_facts_label.name = "CircuitFactsLabel"
	circuit_facts_label.position = Vector2(1240.0, 746.0)
	stage.add_child(circuit_facts_label)

	var box := Control.new()
	box.position = Vector2(1240.0, 780.0)
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


func _number(x: float, y: float, caption: String, value: String, accent: Color) -> Label:
	var label := UI.label(caption, 14, T.TEXT_MUTED, MONO)
	label.position = Vector2(x, y)
	stage.add_child(label)
	var number := UI.label(value, 34, accent, DISPLAY)
	number.name = "Stat" + caption.replace(" ", "")
	number.position = Vector2(x, y + 20.0)
	stage.add_child(number)
	return number


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


## Keyboard route: arrows, one chip per row, the seed, back, continue. Locked chips cannot take focus,
## so each row enters at its first open chip; rebuilt whenever the lap lock changes.
func _focus_ring() -> void:
	var chain: Array[Control] = [
		track_prev_button, track_next_button,
		_first_open_chip(lap_select), _first_open_chip(weather_select), _first_open_chip(time_select),
		_first_open_chip(dynamics_select), reroll_button, back_button, continue_button,
	]
	for index: int in range(chain.size()):
		chain[index].focus_next = chain[(index + 1) % chain.size()].get_path()
		chain[index].focus_previous = chain[(index + chain.size() - 1) % chain.size()].get_path()


func _first_open_chip(row: ChipRow) -> Control:
	for index: int in range(row.get_item_count()):
		if not row.is_chip_disabled(index):
			return row.chip_at(index)
	return row.first_chip()


func _card(rect: Rect2, accent: Color) -> Control:
	var card := Control.new()
	card.position = rect.position
	card.size = rect.size
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(card)
	UI.surface(card, accent)
	return card


# --- state ---------------------------------------------------------------------------------------

func _sync_from_config() -> void:
	var lap_index: int = LAPS.find(config.total_laps)
	lap_select.select(lap_index if lap_index >= 0 else 1)
	weather_select.select(clampi(config.weather_preset, 0, WEATHER_NAMES.size() - 1))
	time_select.select(clampi(config.time_of_day, 0, TIME_NAMES.size() - 1))
	dynamics_select.select(clampi(config.race_dynamics, 0, DYNAMICS_NAMES.size() - 1))
	circuit = config.get_active_circuit()
	_show_circuit(circuit)
	_refresh_summary()


## Walks the calendar by `step` rounds (wrapping) and points the whole screen at the result.
func _select_neighbour(step: int) -> void:
	var next: CircuitDataScript = CircuitRegistry.neighbour(config.selected_circuit_id, step)
	if next == null:
		return
	circuit = next
	config.selected_circuit_id = next.circuit_id
	_show_circuit(next)
	_refresh_summary()
	AudioManager.click(self)


## Public API for other screens and tests: select a round by id.
func select_circuit(circuit_id: String) -> bool:
	var target: CircuitDataScript = CircuitRegistry.get_circuit(circuit_id)
	if target == null:
		return false
	circuit = target
	config.selected_circuit_id = target.circuit_id
	_show_circuit(target)
	_refresh_summary()
	return true


func _show_circuit(selected: CircuitDataScript) -> void:
	if selected == null:
		return
	circuit_name_label.text = selected.display_name
	circuit_round_label.text = "ROUND %02d // %s // %s" % [selected.round_number, selected.month_label, selected.country_code]
	circuit_type_label.text = selected.type_label()
	circuit_length_label.text = selected.length_label()
	circuit_turns_label.text = "%d TURNS" % selected.turns_count
	map_tag.text = "CIRCUIT  //  %s" % selected.display_name.to_upper()
	if selected.night_race and config.time_of_day != NIGHT_TIME_INDEX and config.time_of_day != RANDOM_TIME_INDEX:
		# A floodlit street round opens on the night chip; the player can still change it (or roll RANDOM).
		time_select.press(NIGHT_TIME_INDEX)
	radar.load_circuit(selected)
	var stats: Dictionary = radar.stats()
	stat_length.text = "%.2f KM" % (float(stats["length_m"]) / 1000.0)
	stat_corners.text = str(int(stats["corners"]))
	stat_record.text = selected.lap_record_label()
	circuit_facts_label.text = "%s  //  ELEVATION %.1f m  //  %d DRS ZONES" % [
		String(stats["direction"]), float(stats["elevation_delta"]), radar.drs_zones.size()
	]
	var ready: bool = selected.is_playable()
	continue_button.disabled = not ready
	continue_button.text = "/// CONTINUE: TEAM GARAGE" if ready else "/// %s // IN PREPARATION" % selected.display_name.to_upper()
	_set_badge_fill(status_badge, T.ACCENT_ACID_LIME if ready else T.ACCENT_CYBER_YELLOW)
	status_badge.text = "ACTIVE // READY" if ready else "IN PREPARATION"
	_show_venue(selected)
	_apply_lap_rule(selected)
	_update_carousel(selected)
	_refresh_meteo()


## The artwork, the demand bars and the note of the round.
func _show_venue(selected: CircuitDataScript) -> void:
	var art: Texture2D = _preview_texture(selected)
	venue_art.texture = art
	venue_art_fallback.visible = art == null
	venue_art_fallback.text = "ROUND %02d\n%s" % [selected.round_number, selected.display_name.to_upper()]
	var profile: Array[float] = demand_profile(selected)
	for index: int in range(demand_bars.size()):
		demand_bars[index].value = profile[index]
	venue_notes_label.text = selected.notes


func _preview_texture(selected: CircuitDataScript) -> Texture2D:
	var path: String = selected.preview_image_path
	if path == "" or not FileAccess.file_exists(path):
		return null
	if not _art_cache.has(path):
		_art_cache[path] = _decode_image(path)
	return _art_cache[path]


## Decodes venue artwork from the file's own bytes. The reference concept art is JPEG data saved with a
## .png name, which Godot's importer rejects (valid=false), so ResourceLoader cannot be trusted here.
## A round with no readable art simply shows the fallback plate.
static func _decode_image(path: String) -> Texture2D:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var image := Image.new()
	var error: Error = ERR_FILE_UNRECOGNIZED
	if bytes.size() > 4 and bytes[0] == 0xFF and bytes[1] == 0xD8:
		error = image.load_jpg_from_buffer(bytes)
	elif bytes.size() > 4 and bytes[0] == 0x89 and bytes[1] == 0x50:
		error = image.load_png_from_buffer(bytes)
	if error != OK:
		return null
	return ImageTexture.create_from_image(image)


## What a round asks of a car, each 0..1, in DEMAND_NAMES order, from its length, corner density and
## elevation alone: long and flowing is top speed and overtaking, tight and steep is technical, and a
## lap with many corners wears the tyres. Pure function of the circuit data, so it is stable and testable.
static func demand_profile(selected: CircuitDataScript) -> Array[float]:
	var density: float = float(selected.turns_count) / maxf(selected.length_km, 0.1)
	var top_speed: float = clampf(inverse_lerp(2.0, 6.0, selected.length_km) * 0.6 + clampf(1.0 - float(selected.turns_count) / 24.0, 0.0, 1.0) * 0.4, 0.0, 1.0)
	var technical: float = clampf(inverse_lerp(1.0, 7.5, density) * 0.75 + clampf(selected.elevation_delta_m / 120.0, 0.0, 1.0) * 0.25, 0.0, 1.0)
	var abrasion: float = clampf(0.25 + float(selected.turns_count) / 24.0 * 0.45 + clampf(selected.length_km / 6.0, 0.0, 1.0) * 0.3, 0.0, 1.0)
	var overtaking: float = clampf(top_speed * 0.6 + (1.0 - technical) * 0.4, 0.0, 1.0)
	return [top_speed, technical, abrasion, overtaking]


## Sprint rounds are locked to 3 laps; Grand Prix rounds offer 5 / 10 / 15 and keep 3 for programmatic callers.
func _apply_lap_rule(selected: CircuitDataScript) -> void:
	if selected.is_sprint():
		config.total_laps = SPRINT_LAPS
		lap_select.select(0)
		lap_select.set_chip_disabled(0, false)
		for index: int in [1, 2, 3]:
			lap_select.set_chip_disabled(index, true)
		lap_rule_badge.text = "SPRINT LOCKED: 3 LAPS"
		_set_badge_fill(lap_rule_badge, T.ACCENT_ANIME_CRIMSON)
	else:
		lap_select.set_chip_disabled(0, true)
		for index: int in [1, 2, 3]:
			lap_select.set_chip_disabled(index, false)
		if config.total_laps == SPRINT_LAPS:
			config.total_laps = DEFAULT_GP_LAPS
		lap_select.select(maxi(LAPS.find(config.total_laps), 1))
		lap_rule_badge.text = "GP FORMAT: 5 / 10 / 15 LAPS"
		_set_badge_fill(lap_rule_badge, T.ACCENT_CYBER_YELLOW)
	_focus_ring()


## Pages the four cards to the round's page of the calendar and marks the active one with the lime face.
func _update_carousel(active: CircuitDataScript) -> void:
	var rounds: Array[CircuitDataScript] = CircuitRegistry.get_all_circuits()
	var active_index: int = maxi(rounds.find(active), 0)
	var first: int = (active_index / CAROUSEL_SLOTS) * CAROUSEL_SLOTS
	for slot: int in range(carousel_cards.size()):
		var card: Button = carousel_cards[slot]
		var index: int = first + slot
		card.visible = index < rounds.size()
		if not card.visible:
			continue
		var round_data: CircuitDataScript = rounds[index]
		card.set_meta(&"circuit_id", round_data.circuit_id)
		card.text = "%02d  %s\n%s  //  %s" % [
			round_data.round_number, round_data.display_name.to_upper(), round_data.type_label(),
			round_data.length_label() if round_data.is_playable() else "IN PREPARATION",
		]
		StreetStyle.skin(card, 3, Vector2(4.0, 4.0), 18)
		if round_data == active:
			# The selected round wears the hot lime face for good.
			var hot: StyleBox = card.get_theme_stylebox("pressed")
			for state: String in ["normal", "hover", "disabled"]:
				card.add_theme_stylebox_override(state, hot)
			for state: String in ["font_color", "font_hover_color"]:
				card.add_theme_color_override(state, T.INK_BORDER_BLACK)


## One cell per sampled lap of the forecast the race will really run (same seed, same weather).
func _refresh_meteo() -> void:
	for child: Node in meteo_strip.get_children():
		meteo_strip.remove_child(child)
		child.queue_free()
	# GtWeather forecasts a few laps past the flag; the strip only shows the laps that will be raced.
	var forecast: Array[Dictionary] = []
	for entry: Dictionary in config.make_weather().forecast:
		if int(entry["lap"]) <= config.total_laps:
			forecast.append(entry)
	if forecast.is_empty():
		return
	var cells: int = mini(METEO_CELLS, forecast.size())
	var gap: float = 6.0
	var width: float = (meteo_strip.size.x - gap * float(cells - 1)) / float(cells)
	for cell: int in range(cells):
		var lap_index: int = roundi(float(cell) * float(forecast.size() - 1) / float(maxi(cells - 1, 1)))
		var entry: Dictionary = forecast[lap_index]
		var rain: float = clampf(float(entry["rain_intensity"]), 0.0, 1.0)
		var tone: Color = T.ACCENT_ACID_LIME if rain < METEO_DRY_BELOW else (T.ACCENT_CYBER_YELLOW if rain < METEO_WET_ABOVE else T.ACCENT_ELECTRIC_CYAN)
		var plate := Panel.new()
		plate.name = "MeteoCell%d" % cell
		plate.position = Vector2(float(cell) * (width + gap), 0.0)
		plate.size = Vector2(width, meteo_strip.size.y)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_theme_stylebox_override("panel", UI.style(Color(tone, 0.18), tone))
		var reading: String = "DRY" if rain < METEO_DRY_BELOW else "%d%%" % roundi(rain * 100.0)
		var text := UI.label("L%d\n%s" % [int(entry["lap"]), reading], 13, T.TEXT_PRIMARY, MONO)
		text.position = Vector2(10.0, 3.0)
		plate.add_child(text)
		meteo_strip.add_child(plate)


## Recolours a StreetStyle.badge in place (its plate is a per-label stylebox override).
func _set_badge_fill(badge: Label, fill: Color) -> void:
	var box := StreetStyle.plate(fill, Color.BLACK, Vector2(4.0, 4.0), 3)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	badge.add_theme_stylebox_override("normal", box)
	badge.add_theme_color_override("font_color", T.TEXT_PRIMARY if fill == T.ACCENT_ANIME_CRIMSON else T.INK_BORDER_BLACK)


func _refresh_summary() -> void:
	var round_text: String = "ROUND %02d" % circuit.round_number if circuit != null else "ROUND --"
	var time_text: String = TIME_NAMES[clampi(config.time_of_day, 0, TIME_NAMES.size() - 1)]
	if config.time_of_day == RANDOM_TIME_INDEX:
		time_text = "RANDOM: %s" % TIME_NAMES[config.resolved_time_of_day()]
	summary_label.text = "%s  //  %s\n%d LAPS  //  %s  //  %s\n%s  //  SEED #%d" % [
		round_text,
		circuit.display_name.to_upper() if circuit != null else "",
		config.total_laps,
		WEATHER_NAMES[clampi(config.weather_preset, 0, WEATHER_NAMES.size() - 1)].split(" // ")[0],
		time_text,
		DYNAMICS_NAMES[clampi(config.race_dynamics, 0, DYNAMICS_NAMES.size() - 1)],
		config.race_seed,
	]
	reroll_button.text = "REROLL SEED #%d" % config.race_seed


func _on_card_pressed(slot: int) -> void:
	var id: String = String(carousel_cards[slot].get_meta(&"circuit_id", ""))
	if select_circuit(id):
		AudioManager.click(self)


func _on_laps_selected(index: int) -> void:
	config.total_laps = LAPS[clampi(index, 0, LAPS.size() - 1)]
	_refresh_summary()
	_refresh_meteo()
	AudioManager.click(self)


func _on_weather_selected(index: int) -> void:
	config.weather_preset = clampi(index, 0, WEATHER_NAMES.size() - 1)
	_refresh_summary()
	_refresh_meteo()
	AudioManager.click(self)


func _on_time_selected(index: int) -> void:
	config.time_of_day = clampi(index, 0, TIME_NAMES.size() - 1)
	_refresh_summary()
	AudioManager.click(self)


func _on_dynamics_selected(index: int) -> void:
	config.race_dynamics = clampi(index, 0, DYNAMICS_NAMES.size() - 1)
	_refresh_summary()
	AudioManager.click(self)


## A new seed rolls a new DYNAMIC forecast and, on RANDOM, a new time of race.
func _on_reroll_pressed() -> void:
	config.reroll_seed()
	_refresh_summary()
	_refresh_meteo()
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
