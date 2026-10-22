class_name GarageTeamSelect
extends Node3D

## Pre-race team garage: a ten-stall 3D paddock with a dolly/orbit camera and the
## team-principal overlay, the driver duo portraits, the independent starting compounds for
## both cars, the weather forecast and LAUNCH TO GRID. The environment is built once on
## entry; selecting a team only slides the camera and swaps labels, never loads a model.

const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const EnvironmentScript := preload("res://scripts/world/garage_environment_builder.gd")
const OrbitScript := preload("res://scripts/ui/garage_car_orbit.gd")
const Roster := preload("res://scripts/ui/garage_roster.gd")
const Gt := preload("res://scripts/gt/gt_data.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const UI := preload("res://scripts/ui/pit_wall_ui.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const EngineAudio := preload("res://scripts/audio/engine_audio_3d.gd")
const SettingsScript := preload("res://scripts/core/presentation_settings.gd")
const ForecastRadar := preload("res://scripts/ui/weather_radar_widget.gd")

const FONT_MONO := preload("res://assets/fonts/JetBrainsMono.ttf")
const FONT_HEADER := preload("res://assets/fonts/BarlowCondensed.ttf")
const FONT_DISPLAY := preload("res://assets/fonts/Anton.ttf")

const BACK_SCENE := "res://scenes/ui/race_setup_menu.tscn"
const NEXT_SCENE := "res://scenes/ui/manga_race_transition.tscn"
const TRANSITION_SCRIPT := "res://scripts/ui/manga_race_transition.gd"
const STAGE := Vector2(1920.0, 1080.0)

const COMPOUND_NAMES: Array[String] = ["SOFT", "MEDIUM", "HARD", "INTER", "WET"]
const COMPOUND_BUTTON_NAMES: Array[String] = ["Soft", "Medium", "Hard", "Inter", "Wet"]
const COMPOUND_COLORS: Array[Color] = [
	Color("#e0212e"), Color("#ffd400"), Color("#f4f5f7"), Color("#2fbf71"), Color("#00c2ff"),
]

## Test/integration surface.
var config: ConfigScript
var selected_team: int = 0
var stage: Control
var launch_button: Button
var back_button: Button
var next_button: Button
var prev_button: Button
var driver_cards: Array[Dictionary] = []
var compound_buttons: Array = [[], []]
var _portraits: Array[Texture2D] = []

@onready var camera: Camera3D = $Camera3D
@onready var environment: EnvironmentScript = $GarageEnvironment
@onready var orbit: OrbitScript = $Orbit

var _built: bool = false
var _launching: bool = false

var _team_name: Label
var _principal: Label
var _car_name: Label
var _team_accent: ColorRect
var _stall_label: Label
var _race_line: Label
var _compound_line: Label
var _perf_bars: Array = []
var _perf_values: Array[Label] = []
var _driver_codes: Array[Label] = []
var _driver_names: Array[Label] = []
var _driver_bars: Array = [[], []]
var _driver_values: Array = [[], []]
var _driver_portraits: Array[TextureRect] = []
var _driver_accents: Array[ColorRect] = []
var _driver_compounds: Array[Label] = []
var _car_row_labels: Array[Label] = []
var _forecast_state: Label
var _forecast_detail: Label
var _forecast_laps: Label
var _forecast_radar: ForecastRadar
var _forecast_weather: GtWeather
var _engine_player: AudioStreamPlayer


class SegmentBar extends Control:
	const TOKENS = preload("res://scripts/ui/ui_theme_tokens.gd")

	var value: float = 0.0
	var tint: Color = TOKENS.ACCENT_ACID_LIME
	var segment_count: int = 10

	func _init(count: int = 10) -> void:
		segment_count = maxi(1, count)
		custom_minimum_size = Vector2(0, 12)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func set_state(p_value: float, p_tint: Color) -> void:
		value = clampf(p_value, 0.0, 1.0)
		tint = p_tint
		queue_redraw()

	func _draw() -> void:
		var gap: float = 2.0
		var usable: float = maxf(0.0, size.x - gap * float(segment_count - 1))
		var block: float = usable / float(segment_count)
		var lit: int = int(round(value * float(segment_count)))
		for index: int in range(segment_count):
			var rect := Rect2(float(index) * (block + gap), 0.0, block, size.y)
			draw_rect(rect, tint if index < lit else TOKENS.SURFACE_PANEL_ELEVATED)


func _ready() -> void:
	config = ConfigScript.get_config()
	_forecast_weather = config.make_weather()
	selected_team = posmod(config.selected_team_id, Roster.TEAM_SLUGS.size())
	config.selected_team_id = selected_team
	config.car1_starting_compound = clampi(config.car1_starting_compound, 0, Types.Compound.WET)
	config.car2_starting_compound = clampi(config.car2_starting_compound, 0, Types.Compound.WET)
	# Warm all duo assets at entry, never perform disk/GPU texture loads during a dolly.
	for slot: int in range(Roster.DRIVER_SLUGS.size()):
		_portraits.append(load(Roster.portrait_path(slot)) as Texture2D)
	_build_ui()
	environment.build(Roster.TEAM_SLUGS.size())
	orbit.setup(camera)
	orbit.focus(environment.cars[selected_team], true)
	_refresh_team()
	_refresh_compounds()
	_refresh_forecast()
	_built = true
	_fit()
	get_viewport().size_changed.connect(_fit)
	launch_button.grab_focus()
	SettingsScript.apply_to_tree(self)
	AudioManager.of(self).start_music()


## Selects a stall (wraps around the ten teams); the camera dollies, nothing reloads.
func select_team(index: int) -> void:
	if config == null:
		config = ConfigScript.get_config()
	selected_team = posmod(index, Roster.TEAM_SLUGS.size())
	config.selected_team_id = selected_team
	if not _built:
		return
	_refresh_team()
	orbit.focus(environment.cars[selected_team])
	AudioManager.click(self)


## Starting tyre for car 1 (slot 0) or car 2 (slot 1); the two choices stay independent.
func select_compound(car_slot: int, compound: int) -> void:
	if config == null:
		config = ConfigScript.get_config()
	var slot: int = clampi(car_slot, 0, 1)
	var tyre: int = clampi(compound, 0, Types.Compound.WET)
	if slot == 0:
		config.car1_starting_compound = tyre
	else:
		config.car2_starting_compound = tyre
	_refresh_compounds()
	if _built:
		AudioManager.click(self)


func launch() -> void:
	if _launching or not is_inside_tree():
		return
	if config == null:
		config = ConfigScript.get_config()
	config.selected_team_id = selected_team
	_launching = true
	_play_launch_rev()
	if AudioManager.has_output():
		await get_tree().create_timer(0.35).timeout
	var transition: Variant = load(TRANSITION_SCRIPT)
	if transition == null:
		push_error("Garage launch: transition script missing at %s" % TRANSITION_SCRIPT)
		_launching = false
		return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		transition.capture_snapshot(get_viewport())
	var error: Error = get_tree().change_scene_to_file(NEXT_SCENE)
	if error != OK:
		push_error("Garage launch: cannot open %s (error %d)" % [NEXT_SCENE, error])
		_launching = false


func _back() -> void:
	if _launching:
		return
	AudioManager.click(self)
	var error: Error = get_tree().change_scene_to_file(BACK_SCENE)
	if error != OK:
		push_error("Garage back: cannot open %s (error %d)" % [BACK_SCENE, error])


func _play_launch_rev() -> void:
	if _engine_player == null:
		_engine_player = AudioStreamPlayer.new()
		_engine_player.name = "LaunchRev"
		_engine_player.bus = &"SFX"
		add_child(_engine_player)
	_engine_player.stream = EngineAudio.looped(EngineAudio.ENGINE_STREAM)
	_engine_player.volume_db = -3.0
	_engine_player.pitch_scale = 1.55
	if AudioManager.has_output():
		_engine_player.play()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			_back()
			get_viewport().set_input_as_handled()
		KEY_LEFT, KEY_A:
			select_team(selected_team - 1)
			get_viewport().set_input_as_handled()
		KEY_RIGHT, KEY_D:
			select_team(selected_team + 1)
			get_viewport().set_input_as_handled()


# --- UI construction -----------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Overlay"
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	stage = Control.new()
	stage.name = "Stage"
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stage)
	_build_top_bar()
	_build_team_panel()
	_build_driver_cards()
	_build_strategy_deck()


func _build_top_bar() -> void:
	var bar := _panel(stage, "TopBar", Rect2(40, 26, 1840, 66), Color(0.035, 0.043, 0.062, 0.94))
	var title := _text(bar, "Title", "LA VOITURE // TEAM GARAGE", Vector2(18, 8), Vector2(560, 32), FONT_DISPLAY, 27, T.ACCENT_ACID_LIME)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_race_line = _text(bar, "RaceLine", "EXHIBITION DRAFT", Vector2(20, 40), Vector2(620, 20), FONT_MONO, 12, T.TEXT_SECONDARY)
	prev_button = UI.button("PREV TEAM", T.ACCENT_ELECTRIC_CYAN)
	prev_button.name = "PrevTeamButton"
	prev_button.tooltip_text = "Previous team (A or Left arrow)"
	prev_button.position = Vector2(690, 13)
	prev_button.size = Vector2(150, 40)
	prev_button.add_theme_font_size_override("font_size", 16)
	prev_button.pressed.connect(func() -> void: select_team(selected_team - 1))
	bar.add_child(prev_button)
	next_button = UI.button("NEXT TEAM", T.ACCENT_ACID_LIME)
	next_button.name = "NextTeamButton"
	next_button.tooltip_text = "Next team (D or Right arrow)"
	next_button.position = Vector2(852, 13)
	next_button.size = Vector2(150, 40)
	next_button.add_theme_font_size_override("font_size", 16)
	next_button.pressed.connect(func() -> void: select_team(selected_team + 1))
	bar.add_child(next_button)
	_stall_label = _text(bar, "Stall", "STALL 01 / 10", Vector2(1360, 18), Vector2(456, 30), FONT_MONO, 18, T.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_RIGHT)
	_stall_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _build_team_panel() -> void:
	var panel := _panel(stage, "TeamPanel", Rect2(40, 112, 470, 490))
	_team_accent = ColorRect.new()
	_team_accent.name = "TeamAccent"
	_team_accent.position = Vector2(0, 0)
	_team_accent.size = Vector2(8, 490)
	_team_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_team_accent)
	_text(panel, "Eyebrow", "TEAM // PRINCIPAL", Vector2(24, 14), Vector2(250, 18), FONT_MONO, 12, T.TEXT_MUTED)
	_team_name = _text(panel, "TeamName", "APEX RACING", Vector2(24, 34), Vector2(420, 52), FONT_DISPLAY, 38, T.TEXT_PRIMARY)
	_team_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_principal = _text(panel, "Principal", "PRINCIPAL // --", Vector2(24, 90), Vector2(420, 22), FONT_HEADER, 18, T.TEXT_SECONDARY)
	_car_name = _text(panel, "CarName", "GT3 // --", Vector2(24, 116), Vector2(420, 26), FONT_HEADER, 21, T.ACCENT_ELECTRIC_CYAN)
	_divider(panel, Vector2(24, 152), 420)
	_text(panel, "MatrixHeader", "PERFORMANCE MATRIX", Vector2(24, 168), Vector2(260, 18), FONT_MONO, 12, T.TEXT_MUTED)
	var labels: Array[String] = ["TOP SPEED", "CORNERING DOWNFORCE", "TYRE WEAR EFFICIENCY"]
	for row: int in range(labels.size()):
		var y: float = 196.0 + float(row) * 62.0
		_text(panel, "PerfLabel%d" % row, labels[row], Vector2(24, y), Vector2(280, 18), FONT_MONO, 12, T.TEXT_SECONDARY)
		var value := _text(panel, "PerfValue%d" % row, "0", Vector2(344, y), Vector2(96, 18), FONT_MONO, 13, T.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_RIGHT)
		_perf_values.append(value)
		var bar := SegmentBar.new(12)
		bar.name = "PerfBar%d" % row
		bar.position = Vector2(24, y + 22)
		bar.size = Vector2(416, 12)
		panel.add_child(bar)
		_perf_bars.append(bar)
	_divider(panel, Vector2(24, 386), 420)
	_compound_line = _text(panel, "CompoundLine", "CAR 1: MEDIUM // CAR 2: MEDIUM", Vector2(24, 400), Vector2(420, 22), FONT_MONO, 12, T.TEXT_SECONDARY)
	_text(panel, "Hint", "DRAG ORBIT  /  A-D TEAM  /  TAB FOCUS  /  ESC BACK", Vector2(24, 442), Vector2(420, 20), FONT_MONO, 12, T.TEXT_MUTED)


func _build_driver_cards() -> void:
	for car_slot: int in range(2):
		var y: float = 112.0 + float(car_slot) * 344.0
		var panel := _panel(stage, "DriverCard%d" % (car_slot + 1), Rect2(1450, y, 430, 324))
		var accent := ColorRect.new()
		accent.name = "Accent"
		accent.position = Vector2(0, 0)
		accent.size = Vector2(430, 5)
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(accent)
		_driver_accents.append(accent)
		var frame := Panel.new()
		frame.name = "PortraitFrame"
		frame.position = Vector2(16, 26)
		frame.size = Vector2(168, 168)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(frame)
		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.position = Vector2(5, 5)
		portrait.size = Vector2(158, 158)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.clip_contents = true
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(portrait)
		_driver_portraits.append(portrait)
		var code := _text(panel, "Code", "--", Vector2(198, 20), Vector2(220, 40), FONT_DISPLAY, 30, T.TEXT_PRIMARY)
		_driver_codes.append(code)
		var driver_name := _text(panel, "DriverName", "--", Vector2(198, 60), Vector2(220, 22), FONT_HEADER, 18, T.TEXT_SECONDARY)
		_driver_names.append(driver_name)
		var stat_names: Array[String] = ["PACE", "TIRE CARE", "WET SKILL"]
		var bars: Array = []
		var values: Array[Label] = []
		for stat: int in range(stat_names.size()):
			var stat_y: float = 98.0 + float(stat) * 56.0
			_text(panel, "StatLabel%d" % stat, stat_names[stat], Vector2(198, stat_y), Vector2(150, 16), FONT_MONO, 12, T.TEXT_MUTED)
			var value := _text(panel, "StatValue%d" % stat, "0", Vector2(340, stat_y), Vector2(72, 16), FONT_MONO, 12, T.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_RIGHT)
			values.append(value)
			var bar := SegmentBar.new(10)
			bar.name = "StatBar%d" % stat
			bar.position = Vector2(198, stat_y + 18)
			bar.size = Vector2(214, 10)
			panel.add_child(bar)
			bars.append(bar)
		_driver_bars[car_slot] = bars
		_driver_values[car_slot] = values
		var starting := _text(panel, "StartingTyre", "STARTING TYRE // --", Vector2(198, 272), Vector2(214, 22), FONT_MONO, 12, T.TEXT_SECONDARY)
		_driver_compounds.append(starting)
		driver_cards.append({"panel": panel, "frame": frame, "portrait": portrait})


func _build_strategy_deck() -> void:
	var deck := _panel(stage, "StrategyDeck", Rect2(40, 798, 1840, 252), Color(0.035, 0.043, 0.062, 0.95))
	for car_slot: int in range(2):
		var row_y: float = 24.0 + float(car_slot) * 92.0
		var row_label := _text(deck, "CarRow%d" % (car_slot + 1), "CAR %d // --" % (car_slot + 1),
			Vector2(20, row_y), Vector2(196, 26), FONT_HEADER, 20, T.TEXT_PRIMARY)
		_car_row_labels.append(row_label)
		for compound: int in range(COMPOUND_NAMES.size()):
			var button := Button.new()
			button.name = "Car%dCompound%s" % [car_slot + 1, COMPOUND_BUTTON_NAMES[compound]]
			button.text = COMPOUND_NAMES[compound]
			button.tooltip_text = "Car %d starting tyre: %s" % [car_slot + 1, COMPOUND_NAMES[compound]]
			button.focus_mode = Control.FOCUS_ALL
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button.add_theme_font_override("font", FONT_HEADER)
			button.add_theme_font_size_override("font_size", 15)
			button.position = Vector2(220.0 + float(compound) * 150.0, row_y + 24.0)
			button.size = Vector2(140, 44)
			button.pressed.connect(select_compound.bind(car_slot, compound))
			deck.add_child(button)
			compound_buttons[car_slot].append(button)
	_forecast_state = _text(deck, "ForecastState", "SUNNY DRY", Vector2(1000, 26), Vector2(420, 34), FONT_DISPLAY, 26, T.ACCENT_CYBER_YELLOW)
	_forecast_detail = _text(deck, "ForecastDetail", "", Vector2(1000, 66), Vector2(420, 40), FONT_MONO, 12, T.TEXT_SECONDARY)
	_forecast_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_forecast_laps = _text(deck, "ForecastLaps", "", Vector2(1000, 176), Vector2(420, 60), FONT_MONO, 12, T.TEXT_SECONDARY)
	_forecast_laps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text(deck, "ForecastHeader", "RACE FORECAST // TEAM PRINCIPAL DECK", Vector2(1000, 6), Vector2(420, 16), FONT_MONO, 11, T.TEXT_MUTED)
	_forecast_radar = ForecastRadar.new()
	_forecast_radar.name = "ForecastRadar"
	_forecast_radar.position = Vector2(1000, 108)
	deck.add_child(_forecast_radar)

	launch_button = UI.button("LAUNCH TO GRID", T.ACCENT_ACID_LIME)
	launch_button.name = "LaunchButton"
	launch_button.position = Vector2(1460, 24)
	launch_button.size = Vector2(360, 124)
	launch_button.add_theme_font_override("font", FONT_DISPLAY)
	launch_button.add_theme_font_size_override("font_size", 26)
	launch_button.tooltip_text = "Start the race with this team and tyre strategy"
	launch_button.pressed.connect(launch)
	deck.add_child(launch_button)

	back_button = UI.button("BACK TO SETUP", T.ACCENT_ELECTRIC_CYAN)
	back_button.name = "BackButton"
	back_button.position = Vector2(1460, 160)
	back_button.size = Vector2(360, 52)
	back_button.add_theme_font_size_override("font_size", 17)
	back_button.tooltip_text = "Return to the race setup (Esc)"
	back_button.pressed.connect(_back)
	deck.add_child(back_button)


# --- refresh -------------------------------------------------------------------------------

func _refresh_team() -> void:
	var team: int = selected_team
	var accent: Color = Liveries.color_for(team)
	_team_accent.color = accent
	_team_name.text = Gt.TEAM_NAMES[team].to_upper()
	_principal.text = "PRINCIPAL // %s" % Roster.PRINCIPALS[team]
	_car_name.text = "GT3 // %s" % Roster.CAR_NAMES[team].to_upper()
	_car_name.add_theme_color_override("font_color", accent)
	_stall_label.text = "STALL %02d / %02d  //  %s" % [team + 1, Roster.TEAM_SLUGS.size(), Gt.TEAM_NAMES[team].to_upper()]
	_refresh_performance(team, accent)
	_refresh_drivers(team, accent)
	for row: int in range(2):
		var slot: int = team * 2 + row
		_car_row_labels[row].text = "CAR %d // #%02d %s" % [row + 1, slot + 1, Gt.DRIVER_CODES[slot]]
		_car_row_labels[row].add_theme_color_override("font_color", accent)


func _refresh_performance(team: int, accent: Color) -> void:
	var values: Array[float] = [
		_norm(Gt.TOP_SPEED[team], 76.0, 82.0),
		_norm(Gt.GRIP[team], 0.97, 1.035),
		_norm(1.10 - Gt.TYRE_WEAR[team], 0.0, 1.10 - 0.86),
	]
	for row: int in range(values.size()):
		(_perf_bars[row] as SegmentBar).set_state(values[row], accent)
		_perf_values[row].text = "%d" % roundi(values[row] * 100.0)


func _refresh_drivers(team: int, accent: Color) -> void:
	for car_slot: int in range(2):
		var slot: int = team * 2 + car_slot
		_driver_portraits[car_slot].texture = _portraits[slot]
		_driver_codes[car_slot].text = "#%02d %s" % [slot + 1, Gt.DRIVER_CODES[slot]]
		_driver_names[car_slot].text = Gt.DRIVER_NAMES[slot]
		var bars: Array = _driver_bars[car_slot]
		var values: Array[Label] = _driver_values[car_slot]
		var stats: Array[float] = [
			Gt.SKILL[slot] / 1.02,
			Gt.CONSISTENCY[slot],
			Gt.WET_SKILL[slot],
		]
		for stat: int in range(stats.size()):
			(bars[stat] as SegmentBar).set_state(stats[stat], accent)
			values[stat].text = "%.3fx" % Gt.SKILL[slot] if stat == 0 else "%d" % roundi(stats[stat] * 100.0)
		_driver_accents[car_slot].color = accent
		var frame := driver_cards[car_slot]["frame"] as Panel
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.02, 0.023, 0.03, 1.0)
		box.set_border_width_all(3)
		box.border_color = accent
		box.shadow_color = T.INK_BORDER_BLACK
		box.shadow_offset = Vector2(4, 4)
		frame.add_theme_stylebox_override("panel", box)


func _refresh_compounds() -> void:
	if compound_buttons[0].is_empty():
		return
	for car_slot: int in range(2):
		var chosen: int = clampi(config.car1_starting_compound if car_slot == 0 else config.car2_starting_compound, 0, COMPOUND_NAMES.size() - 1)
		for compound: int in range(COMPOUND_NAMES.size()):
			_style_compound(compound_buttons[car_slot][compound] as Button, COMPOUND_COLORS[compound], compound == chosen)
		if _driver_compounds.size() == 2:
			_driver_compounds[car_slot].text = "STARTING TYRE // %s" % COMPOUND_NAMES[chosen]
			_driver_compounds[car_slot].add_theme_color_override("font_color", COMPOUND_COLORS[chosen])
	if _compound_line != null and config != null:
		_compound_line.text = "CAR 1: %s  //  CAR 2: %s" % [
			COMPOUND_NAMES[clampi(config.car1_starting_compound, 0, COMPOUND_NAMES.size() - 1)],
			COMPOUND_NAMES[clampi(config.car2_starting_compound, 0, COMPOUND_NAMES.size() - 1)],
		]


func _refresh_forecast() -> void:
	var time_name: String = ["DAYLIGHT", "GOLDEN HOUR", "NIGHT CIRCUIT"][config.time_of_day]
	_forecast_state.text = ["SUNNY DRY", "THREATENING RAIN", "DYNAMIC WET", "FULL MONSOON"][config.weather_preset]
	_forecast_detail.text = "RAIN CHANCE %d%% // INITIAL WATER %d%%" % [
		[0, 60, 100, 100][config.weather_preset], roundi(_forecast_weather.track_water_pct),
	]
	var states: Array[int] = []
	for index: int in range(mini(config.total_laps, 5)):
		var entry: Dictionary = _forecast_weather.forecast[index]
		states.append(2 if float(entry["rain_intensity"]) > 0.38 else (1 if float(entry["rain_intensity"]) > 0.03 else (3 if float(entry["water_pct"]) > 12.0 else 0)))
	_forecast_radar.update_status({
		"state": states[0], "wetness_pct": _forecast_weather.track_water_pct / 100.0,
		"forecast": states, "ambient_c": _forecast_weather.air_temp,
	})
	_forecast_laps.text = "%d LAPS // APEX RING INTERNATIONAL\n%s // AIR %.0fC // TRACK %.0fC" % [
		config.total_laps, time_name, _forecast_weather.air_temp, _forecast_weather.track_temp,
	]
	_race_line.text = "EXHIBITION DRAFT // APEX RING // %d LAPS // %s" % [config.total_laps, time_name]


# --- helpers -------------------------------------------------------------------------------

func _fit() -> void:
	if stage == null or not is_inside_tree():
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var factor: float = minf(view.x / STAGE.x, view.y / STAGE.y)
	stage.scale = Vector2(factor, factor)
	stage.position = (view - STAGE * factor) * 0.5


static func _norm(value: float, low: float, high: float) -> float:
	return clampf((value - low) / maxf(high - low, 0.000001), 0.0, 1.0)


func _panel(parent: Control, node_name: String, rect: Rect2, fill: Color = Color(0.055, 0.066, 0.094, 0.94)) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_border_width_all(3)
	box.border_color = T.INK_BORDER_BLACK
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	box.shadow_offset = Vector2(6, 6)
	panel.add_theme_stylebox_override("panel", box)
	parent.add_child(panel)
	return panel


func _text(parent: Control, node_name: String, text: String, position: Vector2, size: Vector2,
		font: Font, font_size: int, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = position
	label.size = size
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _divider(parent: Control, position: Vector2, width: float) -> void:
	var line := ColorRect.new()
	line.name = "Divider"
	line.color = T.HAIRLINE_DIVIDER
	line.position = position
	line.size = Vector2(width, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _style_compound(button: Button, color: Color, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = color if selected else Color(0.07, 0.08, 0.11, 1.0)
	normal.set_border_width_all(3)
	normal.border_color = color
	normal.set_content_margin_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.darkened(0.18) if selected else Color(0.12, 0.14, 0.18, 1.0)
	var focus := hover.duplicate() as StyleBoxFlat
	focus.set_border_width_all(4)
	focus.border_color = T.TEXT_PRIMARY
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.25)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box: StyleBoxFlat = {"normal": normal, "hover": hover, "pressed": pressed, "focus": focus}[state]
		button.add_theme_stylebox_override(state, box)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, T.TEXT_INVERTED if selected else color)
