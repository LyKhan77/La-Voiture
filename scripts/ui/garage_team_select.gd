class_name GarageTeamSelect
extends Node3D
## Pre-race team garage: a ten-stall 3D paddock with a dolly/orbit camera and the
## team-principal overlay, the driver duo cards, the independent starting compounds for
## both cars, the weather forecast and LAUNCH TO GRID. The environment is built once on
## entry; selecting a team only slides the camera and swaps labels, never loads a model.
## The overlay speaks the street-manga language of the menus and takes the selected team's
## livery colour as its accent (see manga/garage_style.gd).
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const EnvironmentScript := preload("res://scripts/world/garage_environment_builder.gd")
const OrbitScript := preload("res://scripts/ui/garage_car_orbit.gd")
const Roster := preload("res://scripts/ui/garage_roster.gd")
const Gt := preload("res://scripts/gt/gt_data.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const StreetStyle := preload("res://scripts/ui/street_style.gd")
const GarageStyle := preload("res://scripts/ui/manga/garage_style.gd")
const MangaPanel := preload("res://scripts/ui/manga/manga_panel.gd")
const TyreWheelButton := preload("res://scripts/ui/manga/tyre_wheel_button.gd")
const DriverSeatCard := preload("res://scripts/ui/manga/driver_seat_card.gd")
const WheatpastePoster := preload("res://scripts/ui/manga/wheatpaste_poster.gd")
const HazardStripe := preload("res://scripts/ui/manga/hazard_stripe.gd")
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
## Compound colours are fixed (they mean rubber, not team): crimson, yellow, white, cyan, lime.
const COMPOUND_COLORS: Array[Color] = [
	Color("#FF1E56"), Color("#FFE600"), Color("#F8FAFC"), Color("#00F0FF"), Color("#CCFF00"),
]
## Tread drawn on each wheel: 0 slick, 1 intermediate, 2 wet.
const COMPOUND_TREAD: Array[int] = [0, 0, 0, 1, 2]
const COMPOUND_NOTES: Array[String] = [
	"Grip kering maksimum, aus tercepat. Butuh trek kering.",
	"Seimbang antara grip dan keausan. Pilihan aman balapan kering.",
	"Paling awet, grip awal paling rendah. Cocok untuk stint panjang.",
	"Alur dangkal untuk genangan tipis dan trek lembap.",
	"Alur penuh membuang air dalam jumlah besar. Anti-aquaplaning.",
]
## Kanji stamps exist only for the drivers the roster document gives one (field slot -> stamp).
const DRIVER_KANJI: Dictionary = {0: "「疾風」"}
const WHEEL_X: float = 236.0
const WHEEL_STEP: float = 108.0
const ROW_Y: float = 42.0
const ROW_STEP: float = 106.0
const PLATE_DARK := Color("#141722")
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
var style: GarageStyle = GarageStyle.new()
var _portraits: Array[Texture2D] = []
@onready var camera: Camera3D = $Camera3D
@onready var environment: EnvironmentScript = $GarageEnvironment
@onready var orbit: OrbitScript = $Orbit
var _built: bool = false
var _launching: bool = false
var _active_car: int = 0
var _accent_tween: Tween
var _team_name: Label
var _principal: Label
var _car_name: Label
var _stall_label: Label
var _race_line: Label
var _perf_bars: Array = []
var _perf_values: Array[Label] = []
var _seat_cards: Array = []
var _driver_bars: Array = [[], []]
var _driver_compounds: Array[Label] = []
var _car_row_labels: Array[Label] = []
var _compatibility_labels: Array[Label] = []
var _inspect_box: Control
var _inspect_name: Label
var _inspect_status: Label
var _inspect_note: Label
var _inspect_meta: Label
var _inspect_border: Color = Color("#2a3856")
var _mismatch_modal: Control
var _mismatch_title: Label
var _mismatch_desc: Label
var _mismatch_apply_btn: Button
var _mismatch_override_btn: Button
var _mismatch_cancel_btn: Button
var _forecast_state: Label
var _forecast_detail: Label
var _forecast_laps: Label
var _forecast_radar: ForecastRadar
var _forecast_weather: GtWeather
var _engine_player: AudioStreamPlayer
## A row of skewed ink segments (the performance matrix).
class SegmentBar extends Control:
	const TOKENS = preload("res://scripts/ui/ui_theme_tokens.gd")
	const LEAN: float = 0.213
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
		var gap: float = 3.0
		var lean: float = LEAN * size.y
		var usable: float = maxf(0.0, size.x - lean - gap * float(segment_count - 1))
		var block: float = usable / float(segment_count)
		var lit: int = int(round(value * float(segment_count)))
		for index: int in range(segment_count):
			var x: float = float(index) * (block + gap)
			draw_colored_polygon(PackedVector2Array([
				Vector2(x + lean, 0.0), Vector2(x + block + lean, 0.0), Vector2(x + block, size.y), Vector2(x, size.y),
			]), tint if index < lit else Color("#222a3b"))
func get_optimal_compound() -> int:
	if _forecast_weather == null:
		return Types.Compound.MEDIUM
	var water: float = _forecast_weather.track_water_pct
	if water >= 40.0 or (config != null and config.weather_preset == 3):
		return Types.Compound.WET
	elif water >= 18.0 or (config != null and config.weather_preset == 2):
		return Types.Compound.INTERMEDIATE
	else:
		return Types.Compound.MEDIUM
func _ready() -> void:
	config = ConfigScript.get_config()
	_forecast_weather = config.make_weather()
	selected_team = posmod(config.selected_team_id, Roster.TEAM_SLUGS.size())
	config.selected_team_id = selected_team
	# Weather-adaptive auto-default for starting compounds
	var optimal: int = get_optimal_compound()
	if config.is_wet_preset():
		if config.car1_starting_compound in [Types.Compound.SOFT, Types.Compound.MEDIUM, Types.Compound.HARD]:
			config.car1_starting_compound = optimal
		if config.car2_starting_compound in [Types.Compound.SOFT, Types.Compound.MEDIUM, Types.Compound.HARD]:
			config.car2_starting_compound = optimal
	elif config.weather_preset == 0:
		if config.car1_starting_compound == Types.Compound.WET:
			config.car1_starting_compound = optimal
		if config.car2_starting_compound == Types.Compound.WET:
			config.car2_starting_compound = optimal
	config.car1_starting_compound = clampi(config.car1_starting_compound, 0, Types.Compound.WET)
	config.car2_starting_compound = clampi(config.car2_starting_compound, 0, Types.Compound.WET)
	# Warm all duo assets at entry, never perform disk/GPU texture loads during a dolly.
	for slot: int in range(Roster.DRIVER_SLUGS.size()):
		_portraits.append(load(Roster.portrait_path(slot)) as Texture2D)
	style.set_accent(Liveries.color_for(selected_team))
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
	_active_car = slot
	_refresh_compounds()
	if _built:
		AudioManager.click(self)
func launch(force: bool = false) -> void:
	if _launching or not is_inside_tree():
		return
	if _mismatch_modal != null and _mismatch_modal.visible and not force:
		return
	if not force:
		var mismatch: Dictionary = _check_critical_mismatch()
		if mismatch.get("is_mismatch", false):
			_show_mismatch_modal(mismatch)
			return
	_do_launch()
func _do_launch() -> void:
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
	if _mismatch_modal != null and _mismatch_modal.visible:
		if key.keycode == KEY_ESCAPE:
			_hide_mismatch_modal()
			get_viewport().set_input_as_handled()
			return
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
	style.changed.connect(_on_accent_changed)
func _build_top_bar() -> void:
	var bar := _panel(stage, "TopBar", Rect2(40, 26, 1840, 66), "LA VOITURE // TEAM GARAGE", 0.0, 40.0, 26)
	_race_line = _text(bar, "RaceLine", "EXHIBITION DRAFT", Vector2(20, 44), Vector2(620, 18), FONT_MONO, 12, T.TEXT_SECONDARY)
	prev_button = _chip("PrevTeamButton", "PREV TEAM", false, Vector2(690, 13), Vector2(170, 40), 3, 22)
	prev_button.tooltip_text = "Previous team (A or Left arrow)"
	prev_button.pressed.connect(func() -> void: select_team(selected_team - 1))
	bar.add_child(prev_button)
	next_button = _chip("NextTeamButton", "NEXT TEAM", true, Vector2(880, 13), Vector2(170, 40), 3, 22)
	next_button.tooltip_text = "Next team (D or Right arrow)"
	next_button.pressed.connect(func() -> void: select_team(selected_team + 1))
	bar.add_child(next_button)
	_stall_label = _badge(bar, "Stall", "STALL 01 / 10", Vector2(1400, 18), 22, true)
func _build_team_panel() -> void:
	var panel := _panel(stage, "TeamPanel", Rect2(40, 112, 470, 490), "TEAM // PRINCIPAL", 10.0)
	_team_name = _text(panel, "TeamName", "APEX RACING", Vector2(38, 54), Vector2(420, 58), FONT_DISPLAY, 46, T.TEXT_PRIMARY)
	_team_name.add_theme_constant_override("shadow_offset_x", 4)
	_team_name.add_theme_constant_override("shadow_offset_y", 4)
	style.tint(_team_name, "font_shadow_color", "shadow")
	_principal = _text(panel, "Principal", "PRINCIPAL // --", Vector2(38, 116), Vector2(420, 24), FONT_HEADER, 19, T.TEXT_SECONDARY)
	_car_name = _badge(panel, "CarName", "GT3 // --", Vector2(38, 150), 20, true)
	_divider(panel, Vector2(38, 200), 400)
	_badge(panel, "MatrixHeader", "PERFORMANCE MATRIX", Vector2(38, 214), 17, true)
	var labels: Array[String] = ["TOP SPEED", "CORNERING DOWNFORCE", "TYRE WEAR EFFICIENCY"]
	for row: int in range(labels.size()):
		var y: float = 268.0 + float(row) * 56.0
		_text(panel, "PerfLabel%d" % row, labels[row], Vector2(38, y), Vector2(280, 18), FONT_MONO, 12, T.TEXT_SECONDARY)
		var value := _text(panel, "PerfValue%d" % row, "0", Vector2(342, y), Vector2(96, 18), FONT_MONO, 13, T.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_RIGHT)
		_perf_values.append(value)
		var bar := SegmentBar.new(12)
		bar.name = "PerfBar%d" % row
		bar.position = Vector2(38, y + 24)
		bar.size = Vector2(400, 12)
		panel.add_child(bar)
		_perf_bars.append(bar)
	_text(panel, "Hint", "DRAG ORBIT  /  A-D TEAM  /  TAB FOCUS  /  ESC BACK", Vector2(38, 440), Vector2(420, 20), FONT_MONO, 12, T.TEXT_MUTED)
	var tape := ColorRect.new()
	tape.name = "DuctTape"
	tape.position = Vector2(430, 22)
	tape.size = Vector2(110, 30)
	tape.pivot_offset = tape.size * 0.5
	tape.rotation = 0.66
	tape.color = Color(0.78, 0.8, 0.85, 0.5)
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(tape)
func _build_driver_cards() -> void:
	for car_slot: int in range(2):
		var card := DriverSeatCard.new(style)
		card.name = "DriverCard%d" % (car_slot + 1)
		card.position = Vector2(1450, 112.0 + float(car_slot) * 344.0)
		card.lead = car_slot == 0
		stage.add_child(card)
		_seat_cards.append(card)
		_driver_bars[car_slot] = card.axes
		_driver_compounds.append(card.tyre_line)
		driver_cards.append({"panel": card})
func _build_strategy_deck() -> void:
	var deck := _panel(stage, "StrategyDeck", Rect2(40, 798, 1840, 252), "TYRE STRATEGY // STARTING COMPOUND")
	for car_slot: int in range(2):
		var row_y: float = ROW_Y + float(car_slot) * ROW_STEP
		var row_label := _badge(deck, "CarRow%d" % (car_slot + 1), "CAR %d // --" % (car_slot + 1), Vector2(28, row_y + 6.0), 20, car_slot == 0)
		_car_row_labels.append(row_label)
		var compat_label := _text(deck, "CarCompat%d" % (car_slot + 1), "", Vector2(28, row_y + 52.0),
			Vector2(200, 18), FONT_MONO, 11, T.ACCENT_ACID_LIME)
		_compatibility_labels.append(compat_label)
		for compound: int in range(COMPOUND_NAMES.size()):
			var wheel := TyreWheelButton.new()
			wheel.name = "Car%dCompound%s" % [car_slot + 1, COMPOUND_BUTTON_NAMES[compound]]
			wheel.style = style
			wheel.tyre_name = COMPOUND_NAMES[compound]
			wheel.tyre_color = COMPOUND_COLORS[compound]
			wheel.tread = COMPOUND_TREAD[compound]
			wheel.text = COMPOUND_NAMES[compound]
			wheel.tooltip_text = "Car %d starting tyre: %s" % [car_slot + 1, COMPOUND_NAMES[compound]]
			wheel.position = Vector2(WHEEL_X + float(compound) * WHEEL_STEP, row_y)
			wheel.pressed.connect(select_compound.bind(car_slot, compound))
			wheel.mouse_entered.connect(_inspect.bind(compound, car_slot))
			wheel.focus_entered.connect(_inspect.bind(compound, car_slot))
			wheel.mouse_exited.connect(_inspect_chosen)
			wheel.focus_exited.connect(_inspect_chosen)
			deck.add_child(wheel)
			compound_buttons[car_slot].append(wheel)
	_build_inspect_box(deck)
	_text(deck, "ForecastHeader", "RACE FORECAST // TEAM PRINCIPAL DECK", Vector2(1150, 46), Vector2(340, 14), FONT_MONO, 11, T.TEXT_MUTED)
	_forecast_state = _text(deck, "ForecastState", "SUNNY DRY", Vector2(1150, 60), Vector2(340, 40), FONT_DISPLAY, 32, T.ACCENT_CYBER_YELLOW)
	_forecast_detail = _text(deck, "ForecastDetail", "", Vector2(1150, 102), Vector2(340, 16), FONT_MONO, 11, T.TEXT_SECONDARY)
	_forecast_radar = ForecastRadar.new()
	_forecast_radar.name = "ForecastRadar"
	_forecast_radar.position = Vector2(1150, 126)
	deck.add_child(_forecast_radar)
	_forecast_laps = _text(deck, "ForecastLaps", "", Vector2(1150, 190), Vector2(340, 34), FONT_MONO, 11, T.TEXT_SECONDARY)
	_forecast_laps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var stripe := HazardStripe.new(T.INK_BORDER_BLACK, T.ACCENT_CYBER_YELLOW)
	stripe.name = "HazardStripe"
	stripe.position = Vector2(1524, 36)
	stripe.size = Vector2(300, 12)
	deck.add_child(stripe)
	launch_button = _chip("LaunchButton", "LAUNCH TO GRID ///", true, Vector2(1520, 58), Vector2(300, 100), 4, 38)
	launch_button.add_theme_font_override("font", FONT_HEADER)
	launch_button.tooltip_text = "Start the race with this team and tyre strategy"
	launch_button.pressed.connect(launch)
	deck.add_child(launch_button)
	back_button = _chip("BackButton", "/// BACK TO SETUP", false, Vector2(1520, 178), Vector2(300, 48), 3, 22)
	back_button.tooltip_text = "Return to the race setup (Esc)"
	back_button.pressed.connect(_back)
	deck.add_child(back_button)
## The dashed "TYRE INSPECT" readout of whichever wheel is hovered, focused or chosen.
func _build_inspect_box(deck: Control) -> void:
	_inspect_box = Control.new()
	_inspect_box.name = "TyreInspect"
	_inspect_box.position = Vector2(804, 50)
	_inspect_box.size = Vector2(326, 184)
	_inspect_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_box.draw.connect(_draw_inspect_box)
	deck.add_child(_inspect_box)
	_text(_inspect_box, "InspectHeader", "TYRE INSPECT // HOVER A WHEEL", Vector2(16, 10), Vector2(300, 14), FONT_MONO, 11, T.TEXT_MUTED)
	_inspect_name = _text(_inspect_box, "InspectName", "", Vector2(16, 28), Vector2(310, 40), FONT_DISPLAY, 30, T.TEXT_PRIMARY)
	_inspect_status = _text(_inspect_box, "InspectStatus", "", Vector2(16, 72), Vector2(310, 18), FONT_MONO, 12, T.ACCENT_ACID_LIME)
	_inspect_note = _text(_inspect_box, "InspectNote", "", Vector2(16, 96), Vector2(310, 52), FONT_MONO, 11, Color("#c4cbe0"))
	_inspect_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_meta = _text(_inspect_box, "InspectMeta", "", Vector2(16, 154), Vector2(310, 16), FONT_MONO, 10, T.TEXT_SECONDARY)
func _draw_inspect_box() -> void:
	var box: Rect2 = Rect2(Vector2.ZERO, _inspect_box.size)
	_inspect_box.draw_rect(box, Color("#090c13"))
	var corners: Array[Vector2] = [box.position, Vector2(box.end.x, 0.0), box.end, Vector2(0.0, box.end.y)]
	for index: int in range(4):
		_inspect_box.draw_dashed_line(corners[index], corners[(index + 1) % 4], _inspect_border, 3.0, 8.0)
# --- refresh -------------------------------------------------------------------------------
func _refresh_team() -> void:
	var team: int = selected_team
	var accent: Color = Liveries.color_for(team)
	_set_accent(accent)
	_team_name.text = Gt.TEAM_NAMES[team].to_upper()
	_principal.text = "PRINCIPAL // %s" % Roster.PRINCIPALS[team]
	_set_badge(_car_name, "GT3 // %s" % Roster.CAR_NAMES[team].to_upper())
	_set_badge(_stall_label, "STALL %02d / %02d  //  %s" % [team + 1, Roster.TEAM_SLUGS.size(), Gt.TEAM_NAMES[team].to_upper()], 1816.0)
	_refresh_performance(team)
	_refresh_drivers(team)
	for row: int in range(2):
		var slot: int = team * 2 + row
		_set_badge(_car_row_labels[row], "CAR %d // #%02d %s" % [row + 1, slot + 1, Gt.DRIVER_CODES[slot]])
	_inspect_chosen()
## The team colour fades in over a quarter second; shadow and ink follow the destination.
func _set_accent(color: Color) -> void:
	if _accent_tween != null:
		_accent_tween.kill()
	if not _built or not is_inside_tree():
		style.set_accent(color)
		return
	var from: Color = style.accent
	_accent_tween = create_tween()
	_accent_tween.tween_method(func(t: float) -> void: style.blend_accent(from.lerp(color, t), color), 0.0, 1.0, 0.25)
func _on_accent_changed() -> void:
	for bar: SegmentBar in _perf_bars:
		bar.tint = style.accent
		bar.queue_redraw()
func _refresh_performance(team: int) -> void:
	var values: Array[float] = [
		_norm(Gt.TOP_SPEED[team], 76.0, 82.0),
		_norm(Gt.GRIP[team], 0.97, 1.035),
		_norm(1.10 - Gt.TYRE_WEAR[team], 0.0, 1.10 - 0.86),
	]
	for row: int in range(values.size()):
		(_perf_bars[row] as SegmentBar).set_state(values[row], style.accent)
		_perf_values[row].text = "%d" % roundi(values[row] * 100.0)
func _refresh_drivers(team: int) -> void:
	var shorts: Array[String] = ["PACE", "TIRE", "WET"]
	for car_slot: int in range(2):
		var slot: int = team * 2 + car_slot
		var card: DriverSeatCard = _seat_cards[car_slot]
		card.portrait = _portraits[slot]
		card.code = Gt.DRIVER_CODES[slot]
		card.seat_label = "#%02d %s" % [slot + 1, Gt.DRIVER_NAMES[slot]]
		card.kanji = DRIVER_KANJI.get(slot, "")
		var stats: Array[float] = [Gt.SKILL[slot] / 1.02, Gt.CONSISTENCY[slot], Gt.WET_SKILL[slot]]
		for stat: int in range(stats.size()):
			card.axes[stat].short = shorts[stat]
			card.axes[stat].value = stats[stat]
			card.axes[stat].text = "%.3fx" % Gt.SKILL[slot] if stat == 0 else "%d" % roundi(stats[stat] * 100.0)
		card.active = car_slot == _active_car
		card.refresh()
## "SLICKS_ON_WET", "WETS_ON_DRY" or "" for a starting compound on this race's track.
func _hazard_for(compound: int) -> String:
	var water_known: bool = _forecast_weather != null
	var is_wet_track: bool = (water_known and _forecast_weather.track_water_pct >= 35.0) or (config != null and config.is_wet_preset())
	var is_dry_track: bool = (water_known and _forecast_weather.track_water_pct <= 12.0) and (config != null and config.weather_preset == 0)
	if is_wet_track and compound in [Types.Compound.SOFT, Types.Compound.MEDIUM, Types.Compound.HARD]:
		return "SLICKS_ON_WET"
	if is_dry_track and compound == Types.Compound.WET:
		return "WETS_ON_DRY"
	return ""
func _chosen_compound(car_slot: int) -> int:
	return clampi(config.car1_starting_compound if car_slot == 0 else config.car2_starting_compound, 0, COMPOUND_NAMES.size() - 1)
func _refresh_compounds() -> void:
	if compound_buttons[0].is_empty():
		return
	var optimal: int = get_optimal_compound()
	for car_slot: int in range(2):
		var chosen: int = _chosen_compound(car_slot)
		var hazard: String = _hazard_for(chosen)
		for compound: int in range(COMPOUND_NAMES.size()):
			var wheel := compound_buttons[car_slot][compound] as TyreWheelButton
			wheel.chosen = compound == chosen
			wheel.crew_pick = compound == optimal
			wheel.hazard = compound == chosen and not hazard.is_empty()
			wheel.text = "%s ★" % COMPOUND_NAMES[compound] if compound == optimal else COMPOUND_NAMES[compound]
		var compat: Label = _compatibility_labels[car_slot]
		if not hazard.is_empty():
			compat.text = "CRITICAL MISMATCH!"
			compat.add_theme_color_override("font_color", TyreWheelButton.HAZARD)
		elif chosen == optimal:
			compat.text = "OPTIMAL // 100% MATCH"
			compat.add_theme_color_override("font_color", T.ACCENT_ACID_LIME)
		else:
			compat.text = "STRATEGY VARIATION"
			compat.add_theme_color_override("font_color", T.ACCENT_ELECTRIC_CYAN)
		var line: Label = _driver_compounds[car_slot]
		if not hazard.is_empty():
			line.text = "STARTING TYRE // %s [CRITICAL HAZARD!]" % COMPOUND_NAMES[chosen]
			line.add_theme_color_override("font_color", TyreWheelButton.HAZARD)
		elif chosen == optimal:
			line.text = "STARTING TYRE // %s [★ CREW PICK]" % COMPOUND_NAMES[chosen]
			line.add_theme_color_override("font_color", COMPOUND_COLORS[chosen])
		else:
			line.text = "STARTING TYRE // %s" % COMPOUND_NAMES[chosen]
			line.add_theme_color_override("font_color", COMPOUND_COLORS[chosen])
		(_seat_cards[car_slot] as DriverSeatCard).active = car_slot == _active_car
		(_seat_cards[car_slot] as DriverSeatCard).refresh()
	_inspect_chosen()
func _inspect_chosen() -> void:
	_inspect(_chosen_compound(_active_car), _active_car)
## Shows `compound` as it would behave on car `car_slot` at this race's weather.
func _inspect(compound: int, car_slot: int) -> void:
	if _inspect_name == null or config == null:
		return
	var hazard: String = _hazard_for(compound)
	var driver: String = Gt.DRIVER_NAMES[selected_team * 2 + car_slot]
	_inspect_name.text = "%s  //  GRIP %.2f  WEAR %.1f%%/LAP" % [COMPOUND_NAMES[compound],
		Types.COMPOUND_GRIP[compound], Types.COMPOUND_WEAR_PER_LAP[compound] * 100.0]
	_inspect_name.add_theme_font_size_override("font_size", 20)
	_inspect_name.add_theme_color_override("font_color", COMPOUND_COLORS[compound])
	var cornering: String = "+0%"
	var braking: String = "1.0x"
	if hazard == "SLICKS_ON_WET":
		_inspect_status.text = "CRITICAL MISMATCH (HAZARD!)"
		_inspect_note.text = "Slick tanpa alur: aquaplaning, grip lateral ambruk, jarak rem hingga 3x lebih panjang."
		cornering = "-45%"
		braking = "3.0x"
	elif hazard == "WETS_ON_DRY":
		_inspect_status.text = "CRITICAL MISMATCH (HAZARD!)"
		_inspect_note.text = "Ban basah di aspal kering: suhu >130 C, aus 5-6x lebih cepat, puncture dalam 2-3 lap."
		cornering = "-30%"
	elif compound == get_optimal_compound():
		_inspect_status.text = "OPTIMAL (100% MATCH) // CREW PICK"
		_inspect_note.text = COMPOUND_NOTES[compound]
	else:
		_inspect_status.text = "OK // STRATEGY VARIATION"
		_inspect_note.text = COMPOUND_NOTES[compound]
	var risky: bool = not hazard.is_empty()
	_inspect_status.add_theme_color_override("font_color", TyreWheelButton.HAZARD if risky else T.ACCENT_ACID_LIME)
	_inspect_border = TyreWheelButton.HAZARD if risky else Color("#2a3856")
	_inspect_meta.text = "CAR %d // %s // CORNER %s // BRAKE %s" % [car_slot + 1, driver, cornering, braking]
	_inspect_box.queue_redraw()
func _refresh_forecast() -> void:
	# RANDOM time and DYNAMIC weather are settled by the seed, so show what this race will actually run.
	var time_name: String = ["DAYLIGHT", "GOLDEN HOUR", "NIGHT CIRCUIT"][config.resolved_time_of_day()]
	_forecast_state.text = ["SUNNY DRY", "THREATENING RAIN", "DYNAMIC WET", "FULL MONSOON", "DYNAMIC RADAR"][config.weather_preset]
	_forecast_detail.text = "RAIN CHANCE %d%% // INITIAL WATER %d%%" % [
		[0, 60, 100, 100, roundi(config.get_active_circuit().rain_probability * 100.0)][config.weather_preset],
		roundi(_forecast_weather.track_water_pct),
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
func _panel(parent: Control, node_name: String, rect: Rect2, header: String = "", spine: float = 0.0,
		header_height: float = 38.0, header_font_size: int = 20) -> MangaPanel:
	var panel := MangaPanel.new(style)
	panel.name = node_name
	panel.position = rect.position
	panel.size = rect.size
	panel.header = header
	panel.header_height = header_height
	panel.header_font_size = header_font_size
	panel.spine_width = spine
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
	line.size = Vector2(width, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
## A tilted street plate with one line of type: team-coloured, or dark when `accent_face` is off.
func _badge(parent: Control, node_name: String, text: String, position: Vector2, font_size: int,
		accent_face: bool) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = position
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT_HEADER)
	label.add_theme_font_size_override("font_size", font_size)
	label.rotation = StreetStyle.SLANT_RAD * 0.25
	var box := StreetStyle.plate(style.accent if accent_face else PLATE_DARK, Color.BLACK, Vector2(4.0, 4.0), 3)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	label.add_theme_stylebox_override("normal", box)
	if accent_face:
		style.face(box)
		style.tint(label, "font_color", "on")
	else:
		label.add_theme_color_override("font_color", T.TEXT_PRIMARY)
	parent.add_child(label)
	_set_badge(label, text)
	return label
## Re-fits a badge to its text; a positive `right_edge` pins its right side instead of its left.
func _set_badge(label: Label, text: String, right_edge: float = -1.0) -> void:
	label.text = text
	label.size = label.get_minimum_size()
	if right_edge > 0.0:
		label.position.x = right_edge - label.size.x
## The garage's button: a street plate that is dark until hovered, or `hot` (team-coloured) always.
func _chip(node_name: String, text: String, hot: bool, position: Vector2, button_size: Vector2,
		border_px: int, font_size: int) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.position = position
	button.size = button_size
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", FONT_HEADER)
	button.add_theme_font_size_override("font_size", font_size)
	var offset: Vector2 = Vector2(8.0, 8.0) if font_size >= 30 else Vector2(4.0, 4.0)
	var dark := StreetStyle.plate(StreetStyle.PLATE_FILL, Color.BLACK, offset, border_px)
	var lit := style.shade(style.face(StreetStyle.plate(style.accent, style.shadow, offset, border_px)))
	var lit_hover := style.shade(style.face(StreetStyle.plate(style.accent, style.shadow, offset, border_px), 0.16))
	if hot:
		button.add_theme_stylebox_override("normal", lit)
		button.add_theme_stylebox_override("hover", lit_hover)
		button.add_theme_stylebox_override("focus", lit_hover)
	else:
		button.add_theme_stylebox_override("normal", dark)
		button.add_theme_stylebox_override("hover", style.border(StreetStyle.plate(StreetStyle.HOVER_FILL, Color.BLACK, offset, border_px)))
		button.add_theme_stylebox_override("focus", lit)
	button.add_theme_stylebox_override("pressed", lit)
	button.add_theme_stylebox_override("disabled", dark)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		if hot or state == "font_pressed_color" or state == "font_focus_color":
			style.tint(button, state, "on")
		elif state == "font_hover_color":
			style.tint(button, state, "accent")
		else:
			button.add_theme_color_override(state, T.TEXT_PRIMARY)
	return button
# --- Critical Mismatch Detection & Alert Modal (street-manga wheatpaste poster) ---
func _check_critical_mismatch() -> Dictionary:
	var car1_hazard: String = _hazard_for(config.car1_starting_compound) if config != null else ""
	var car2_hazard: String = _hazard_for(config.car2_starting_compound) if config != null else ""
	return {
		"is_mismatch": not car1_hazard.is_empty() or not car2_hazard.is_empty(),
		"hazard_type": car1_hazard if not car1_hazard.is_empty() else car2_hazard,
		"car1_mismatch": not car1_hazard.is_empty(),
		"car2_mismatch": not car2_hazard.is_empty(),
		"optimal_compound": get_optimal_compound(),
	}
func _build_mismatch_modal() -> void:
	var poster := WheatpastePoster.new()
	stage.add_child(poster)
	_mismatch_modal = poster
	_mismatch_title = poster.title
	_mismatch_desc = poster.desc
	_mismatch_override_btn = poster.override_button
	_mismatch_apply_btn = poster.apply_button
	_mismatch_cancel_btn = poster.cancel_button
	_mismatch_override_btn.tooltip_text = "Launch with chosen high-risk tyre strategy"
	_mismatch_override_btn.pressed.connect(func() -> void:
		_hide_mismatch_modal()
		_do_launch()
	)
	_mismatch_apply_btn.tooltip_text = "Equip optimal weather tyres and launch immediately"
	_mismatch_apply_btn.pressed.connect(func() -> void:
		_apply_recommended_compounds()
		_hide_mismatch_modal()
		_do_launch()
	)
	_mismatch_cancel_btn.tooltip_text = "Return to garage to adjust strategy manually"
	_mismatch_cancel_btn.pressed.connect(_hide_mismatch_modal)
func _show_mismatch_modal(mismatch: Dictionary) -> void:
	if _mismatch_modal == null:
		_build_mismatch_modal()
	var cars: String = "CAR 1 & CAR 2"
	if not mismatch.get("car2_mismatch", false):
		cars = "CAR 1"
	elif not mismatch.get("car1_mismatch", false):
		cars = "CAR 2"
	var water: float = _forecast_weather.track_water_pct if _forecast_weather != null else 80.0
	var temp: float = _forecast_weather.track_temp if _forecast_weather != null else 35.0
	(_mismatch_modal as WheatpastePoster).present(mismatch.get("hazard_type", ""), water, temp, cars)
	AudioManager.click(self)
func _hide_mismatch_modal() -> void:
	if _mismatch_modal != null:
		_mismatch_modal.visible = false
	if launch_button != null:
		launch_button.grab_focus()
	AudioManager.click(self)
func _apply_recommended_compounds() -> void:
	var optimal: int = get_optimal_compound()
	var mismatch: Dictionary = _check_critical_mismatch()
	if mismatch.get("car1_mismatch", false):
		config.car1_starting_compound = optimal
	if mismatch.get("car2_mismatch", false):
		config.car2_starting_compound = optimal
	_refresh_compounds()
