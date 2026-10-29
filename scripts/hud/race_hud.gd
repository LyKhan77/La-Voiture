class_name RaceHud
extends CanvasLayer

## The La Voiture race HUD (FASE 5.8): the gt-manager tactical deck and telemetry fused
## with the pit wall dashboard. A 1920x1080 stage scaled to the window holds Zone A (series,
## lap, flag, weather radar, sim rate, camera), the live timing tower (INT / GAP / LAST),
## the circuit radar with the session records, the telemetry drawer, the tactical deck, the
## hybrid suggestion card, a caution tape strip for yellow / VSC / safety car and the race
## control marquee. Team radio cuts in through the anime banner. It reads the GT sim and
## the world and writes only through the sim's own tactic calls.
##
## Keys: B request the box, Esc dismiss the card / cancel the box, Enter accept the card, M fold the
## deck, T telemetry, Tab tower columns, H hide the HUD, E ERS overtake, [ and ] pace down / up,
## N next car of the player team.

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")
const DirectorScript := preload("res://scripts/world/race_weekend_director.gd")
const TowerScene := preload("res://scenes/pit_wall/timing_tower.tscn")
const RadarScene := preload("res://scenes/pit_wall/circuit_radar_2d.tscn")
const RadioScene := preload("res://scenes/pit_wall/anime_radio_cutin.tscn")
const PORTRAIT := preload("res://assets/original-manga-racing-driver-portrait-he-cmvgxpt8.png")
const ENGINEER_PORTRAIT := preload("res://assets/manga-race-engineer-portrait.png")
const CutInScript := preload("res://scripts/ui/anime_radio_cutin.gd")
const GarageStyleScript := preload("res://scripts/ui/manga/garage_style.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const RadioAudioScript := preload("res://scripts/audio/radio_audio_director.gd")
const SafetyCarBannerScript := preload("res://scripts/hud/safety_car_banner.gd")
const StewardBannerScript := preload("res://scripts/hud/steward_banner.gd")

const STAGE := Vector2(1920.0, 1080.0)
## Free viewport between the tower, the telemetry drawer, the ribbon and the deck (stage pixels):
## the radio banners dock to its top edge, over the sky, so no readout is covered.
const RADIO_DOCK := Rect2(352.0, 88.0, 1230.0, 790.0)
const TIME_SCALES: Array[float] = [1.0, 2.0, 4.0, 8.0, 16.0]
const TOWER_MODES: Array[String] = ["INT", "GAP", "LAST"]
const TOWER_REFRESH_FRAMES: int = 6
const PANEL_REFRESH_FRAMES: int = 3
const WEATHER_REFRESH_FRAMES: int = 30
const TICKER_SPEED: float = 45.0
const TICKER_VIEW_W: float = 1664.0
const SpeedlinesShader := preload("res://shaders/manga_speedlines.gdshader")
## The suggestion card burns down over GtRace.SUGGESTION_WINDOW_S and goes critical (flashing) under 3 s.
const CARD_CRITICAL_S: float = 3.0
const CARD_BLINK_FRAMES: int = 6
const BURN_ORANGE := Color("#FF6D00")
const SPEEDLINES_LAYER: int = 5
const WEATHER_LAYER: int = 31
## Rays appear at 200 km/h and are full at 280: 240 km/h already reads at 0.5.
const SPEEDLINES_FROM_KMH: float = 200.0
const SPEEDLINES_FULL_KMH: float = 280.0
const SPEEDLINES_ALPHA: float = 0.8
const SPEEDLINES_MIN_VISIBLE: float = 0.02
## The rays hug the car: clear around it up to the first radius, full by the second, gone by the third
## (screen heights), and clipped to the HUD-free window so no panel is ever crossed.
const SPEEDLINES_CLEAR_RADIUS: float = 0.16
const SPEEDLINES_FULL_RADIUS: float = 0.34
const SPEEDLINES_END_RADIUS: float = 0.62
const SPEEDLINES_EDGE_FADE: float = 0.06
const SPEEDLINES_CAR_LIFT_M: float = 0.7
const SPEEDLINES_PAINT_SHARE: float = 0.2
const SPEEDLINES_TONE: float = 0.75
const SPEEDLINES_SECTORS: float = 54.0
const SPEEDLINES_REROLL_HZ: float = 12.0

var world: Node3D
var race: GtRace
var stage: Control
var tower: Control
var radar: Control
var weather_widget: WeatherRadarWidget
var weather_deck: WeatherDeck
var weather_layer: CanvasLayer
## Driver portraits by car id, loaded once at bind.
var _portraits: Dictionary = {}
var drawer: TelemetryDrawer
## Team accent of the HUD skin (logo, marquee, deck header, drawer): the player team's livery colour.
var style: GarageStyleScript
var logo_label: Label
var marquee_bar: ColorRect
var marquee_texts: Array[Label] = []
var deck: TacticalDeck
## Driver calls cut in at the bottom left, the pit wall engineer at the bottom right.
var radio: CanvasLayer
var engineer_radio: CanvasLayer
var radio_audio: RadioAudioScript
var tape: CautionTape
var sc_banner: SafetyCarBannerScript
var steward_banner: StewardBannerScript
var _last_sc_phase: int = GtTypes.SafetyCarPhase.HIDDEN
var rate_row: ModeRow
var lap_label: Label
var flag_label: Label
var cam_label: Label
var drs_label: Label
var records_label: Label
var ticker: Label
var card: Control
var card_title: Label
var card_text: Label
var accept_button: Button
var dismiss_button: Button
## Burn bar along the top of the card, the seconds left, and whether the last 3 s are running.
var burn_fill: ColorRect
var card_timer: Label
var card_critical: bool = false
var tower_mode: int = 0
var last_radio: Dictionary = {}

## Full-screen ink rays (shaders/manga_speedlines.gdshader) that thicken with speed and during ERS overtake.
var speedlines_rect: ColorRect
var speedlines_intensity: float = 0.0

var _frame: int = 0
var _ticker_x: float = 0.0
var _last_ers_mode: int = GtTypes.ErsMode.NEUTRAL
var _tower_column: Label


## Builds the HUD around a race weekend world (needs world.race, director, camera_director).
func bind(p_world: Node3D) -> void:
	world = p_world
	race = p_world.race
	style = GarageStyleScript.new()
	style.set_accent(Liveries.color_for(race.player_team_id))
	stage = Control.new()
	stage.name = "Stage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = STAGE
	add_child(stage)
	_build_ribbon()
	_build_tower_and_radar()
	deck = TacticalDeck.new()
	deck.name = "TacticalDeck"
	stage.add_child(deck)
	deck.position = Vector2(16.0, 880.0)
	deck.bind(world)
	deck.car_picked.connect(_on_car_picked)
	deck.set_accent(style.accent, style.on_accent)
	drawer = TelemetryDrawer.new()
	drawer.name = "TelemetryDrawer"
	drawer.style = style
	stage.add_child(drawer)
	drawer.position = Vector2(1598.0, 372.0)
	weather_deck = WeatherDeck.new()
	weather_deck.name = "WeatherDeck"
	# A layer of its own above the radio banners (layer 30), which would cover it inside the stage.
	weather_layer = CanvasLayer.new()
	weather_layer.name = "WeatherLayer"
	weather_layer.layer = WEATHER_LAYER
	add_child(weather_layer)
	weather_layer.add_child(weather_deck)
	weather_deck.position = Vector2(1006.0, 76.0)
	weather_deck.set_ribbon(world.ribbon, world.ribbon.length_m)
	weather_deck.tyres_chosen.connect(_on_weather_tyres)
	weather_widget.clicked.connect(toggle_weather_deck)
	_build_card()
	_build_marquee()
	style.changed.connect(_on_style_changed)
	_build_speedlines()
	tape = CautionTape.new()
	tape.name = "CautionTape"
	stage.add_child(tape)
	tape.position = Vector2(650.0, 84.0)
	tape.visible = false
	sc_banner = SafetyCarBannerScript.new()
	sc_banner.name = "SafetyCarBanner"
	stage.add_child(sc_banner)
	sc_banner.position = Vector2(570.0, 90.0)
	steward_banner = StewardBannerScript.new()
	steward_banner.name = "StewardBanner"
	stage.add_child(steward_banner)
	steward_banner.position = Vector2(580.0, 196.0)
	radio_audio = RadioAudioScript.new()
	radio_audio.name = "RadioAudioDirector"
	add_child(radio_audio)
	radio = _make_cut_in("AnimeRadioCutIn", CutInScript.Role.DRIVER, "DRIVER", PORTRAIT)
	engineer_radio = _make_cut_in("EngineerRadioCutIn", CutInScript.Role.ENGINEER, "ENGINEER", ENGINEER_PORTRAIT)
	_paint_engineer_card()
	# The first radio call of a race stalled 13-48 ms on first-use costs: warm the cards and the voice manifest now.
	radio.prewarm()
	engineer_radio.prewarm()
	RadioVoice.entries()
	for car: GtCar in race.cars:
		_portraits[car.id] = _load_portrait(car.id)
	race.radio_message.connect(_on_radio)
	race.flag_changed.connect(_on_flag_changed)
	race.steward_event.connect(_on_steward_event)
	race.suggestion_changed.connect(_on_suggestion)
	get_viewport().size_changed.connect(fit)
	fit()
	_on_suggestion(race.latest_suggestion)
	refresh_all()


func _make_cut_in(node_name: String, role: int, title: String, portrait: Texture2D) -> CanvasLayer:
	var cut_in: CanvasLayer = RadioScene.instantiate()
	cut_in.name = node_name
	cut_in.role = role
	cut_in.role_title = title
	add_child(cut_in)
	cut_in.set_portrait(portrait)
	cut_in.transmission_shown.connect(radio_audio.on_transmission_shown.bind(cut_in))
	cut_in.transmission_finished.connect(radio_audio.on_transmission_finished.bind(cut_in))
	cut_in.transmission_finished.connect(_on_cut_in_finished.bind(cut_in))
	return cut_in


func fit() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var factor: float = minf(view.x / STAGE.x, view.y / STAGE.y)
	stage.scale = Vector2(factor, factor)
	stage.position = (view - STAGE * factor) * 0.5
	if weather_layer != null:
		weather_layer.transform = Transform2D(0.0, Vector2(factor, factor), 0.0, stage.position)
	var dock := Rect2(stage.position + RADIO_DOCK.position * factor, RADIO_DOCK.size * factor)
	if speedlines_rect != null:
		var window := Rect2(dock.position / view, dock.size / view)
		(speedlines_rect.material as ShaderMaterial).set_shader_parameter("safe_rect", Vector4(window.position.x, window.position.y, window.end.x, window.end.y))
	for cut_in: CanvasLayer in [radio, engineer_radio]:
		if cut_in != null:
			cut_in.set_dock(dock, factor)


# --- construction ----------------------------------------------------------------------

func _panel(at: Vector2, extent: Vector2, accent: Color = Color(1.0, 1.0, 1.0, 0.2)) -> Control:
	var panel := Control.new()
	panel.custom_minimum_size = extent
	panel.size = extent
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(panel)
	panel.position = at
	UI.surface(panel, accent)
	return panel


func _text(parent: Control, text: String, at: Vector2, font_size: int, color: Color, font: Font = UI.MONO) -> Label:
	var label := UI.label(text, font_size, color, font)
	parent.add_child(label)
	label.position = at
	return label


func _build_ribbon() -> void:
	var ribbon: Control = _panel(Vector2(16.0, 12.0), Vector2(1888.0, 60.0))
	ribbon.name = "ZoneARibbon"
	logo_label = _text(ribbon, "LA VOITURE", Vector2(20.0, 8.0), 32, style.accent, UI.DISPLAY)
	lap_label = _text(ribbon, "LAP 01/%d" % race.laps, Vector2(236.0, 14.0), 24, T.TEXT_PRIMARY, UI.HEADER)
	flag_label = _text(ribbon, "", Vector2(420.0, 12.0), 28, T.ACCENT_ACID_LIME, UI.DISPLAY)
	flag_label.size = Vector2(540.0, 36.0)
	flag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weather_widget = WeatherRadarWidget.new()
	ribbon.add_child(weather_widget)
	weather_widget.position = Vector2(990.0, 2.0)
	var rate_labels: Array[String] = ["1x", "2x", "4x", "8x", "16x"]
	rate_row = ModeRow.new(rate_labels, [T.ACCENT_ACID_LIME], 14)
	rate_row.selected.connect(_on_rate)
	ribbon.add_child(rate_row)
	rate_row.position = Vector2(1362.0, 14.0)
	rate_row.size = Vector2(250.0, 32.0)
	cam_label = _text(ribbon, "", Vector2(1640.0, 10.0), 13, T.TEXT_SECONDARY)
	drs_label = _text(ribbon, "", Vector2(1640.0, 32.0), 13, T.TEXT_SECONDARY)


func _build_tower_and_radar() -> void:
	tower = TowerScene.instantiate()
	tower.name = "TimingTower"
	stage.add_child(tower)
	tower.position = Vector2(16.0, 88.0)
	tower.size = Vector2(320.0, 780.0)
	tower.driver_selected.connect(_on_car_picked)
	_tower_column = tower.get_node("Body/ColHeader/Int") as Label
	var radar_panel: Control = _panel(Vector2(1598.0, 82.0), Vector2(312.0, 212.0))
	radar_panel.name = "RadarPanel"
	radar = RadarScene.instantiate()
	stage.add_child(radar)
	radar.position = Vector2(1604.0, 88.0)
	radar.set_ribbon(world.ribbon, world.track.length)
	var records: Control = _panel(Vector2(1598.0, 306.0), Vector2(312.0, 60.0))
	records.name = "SessionRecords"
	records_label = _text(records, "", Vector2(12.0, 8.0), 12, T.TEXT_SECONDARY)


func _build_card() -> void:
	card = _panel(Vector2(656.0, 690.0), Vector2(608.0, 136.0), T.ACCENT_CYBER_YELLOW)
	card.name = "SuggestionCard"
	var burn_track := ColorRect.new()
	burn_track.color = T.SURFACE_PANEL_DARK
	burn_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(burn_track)
	burn_track.position = Vector2(4.0, 4.0)
	burn_track.size = Vector2(card.size.x - 8.0, 10.0)
	burn_fill = ColorRect.new()
	burn_fill.color = T.ACCENT_CYBER_YELLOW
	burn_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burn_track.add_child(burn_fill)
	burn_fill.size = burn_track.size
	card_title = _text(card, "", Vector2(16.0, 16.0), 24, T.ACCENT_CYBER_YELLOW, UI.HEADER)
	card_timer = _text(card, "10.0s", Vector2(card.size.x - 100.0, 16.0), 22, T.ACCENT_CYBER_YELLOW, UI.HEADER)
	card_timer.size = Vector2(84.0, 28.0)
	card_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card_text = _text(card, "", Vector2(16.0, 46.0), 14, T.TEXT_PRIMARY, UI.RADIO)
	card_text.size = Vector2(576.0, 44.0)
	card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	accept_button = UI.button("ACCEPT")
	accept_button.focus_mode = Control.FOCUS_NONE
	accept_button.pressed.connect(_on_accept)
	card.add_child(accept_button)
	accept_button.position = Vector2(16.0, 92.0)
	accept_button.size = Vector2(288.0, 34.0)
	dismiss_button = UI.button("DISMISS")
	dismiss_button.focus_mode = Control.FOCUS_NONE
	dismiss_button.pressed.connect(_on_dismiss)
	card.add_child(dismiss_button)
	dismiss_button.position = Vector2(320.0, 92.0)
	dismiss_button.size = Vector2(272.0, 34.0)
	card.visible = false


func _build_marquee() -> void:
	var bar := ColorRect.new()
	bar.name = "RaceControlMarquee"
	bar.color = style.accent
	marquee_bar = bar
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bar)
	bar.position = Vector2(0.0, 1032.0)
	bar.size = Vector2(1920.0, 48.0)
	marquee_texts.append(_text(bar, "RACE CONTROL", Vector2(32.0, 10.0), 23, style.on_accent, UI.HEADER))
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(clip)
	clip.position = Vector2(226.0, 0.0)
	clip.size = Vector2(TICKER_VIEW_W, 48.0)
	ticker = _text(clip, "LIVE TIMING ONLINE   //   GREEN FLAG   //   %d LAPS   //   [B] REQUEST BOX  [ESC] CANCEL BOX  [M] DECK  [T] TELEMETRY  [TAB] TOWER  [N] NEXT CAR  [E] ERS  [ ] PACE  [H] HIDE" % race.laps, Vector2(0.0, 12.0), 20, style.on_accent, UI.RADIO)
	marquee_texts.append(ticker)


func _build_speedlines() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SpeedlinesLayer"
	layer.layer = SPEEDLINES_LAYER
	add_child(layer)
	speedlines_rect = ColorRect.new()
	speedlines_rect.name = "MangaSpeedlines"
	speedlines_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speedlines_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = SpeedlinesShader
	material.set_shader_parameter("inner", SPEEDLINES_CLEAR_RADIUS)
	material.set_shader_parameter("outer", SPEEDLINES_FULL_RADIUS)
	material.set_shader_parameter("ring_end", SPEEDLINES_END_RADIUS)
	material.set_shader_parameter("safe_fade", SPEEDLINES_EDGE_FADE)
	# Hand-inked and lopsided: uneven rays, a share painted lime / cyan / crimson, halftone wedges.
	material.set_shader_parameter("variation", 1.0)
	material.set_shader_parameter("accent_share", SPEEDLINES_PAINT_SHARE)
	material.set_shader_parameter("tone", SPEEDLINES_TONE)
	material.set_shader_parameter("ray_count", SPEEDLINES_SECTORS)
	speedlines_rect.material = material
	speedlines_rect.visible = false
	layer.add_child(speedlines_rect)


## 0 below 200 km/h, 1 from 280 km/h, and 1 for as long as the ERS overtake burns.
static func speedlines_for(speed_mps: float, ers_mode: int) -> float:
	var by_speed: float = clampf((speed_mps * 3.6 - SPEEDLINES_FROM_KMH) / (SPEEDLINES_FULL_KMH - SPEEDLINES_FROM_KMH), 0.0, 1.0)
	return 1.0 if ers_mode == GtTypes.ErsMode.OVERTAKE else by_speed


func _update_speedlines() -> void:
	var followed: GtCar = race.get_car(world.followed_id)
	if followed == null:
		return
	# Boost warp: the followed car just switched to overtake, so the lens kicks wide for a moment.
	if followed.ers_mode == GtTypes.ErsMode.OVERTAKE and _last_ers_mode != GtTypes.ErsMode.OVERTAKE:
		world.camera_director.punch_fov()
	_last_ers_mode = followed.ers_mode
	speedlines_intensity = speedlines_for(followed.v, followed.ers_mode)
	speedlines_rect.visible = speedlines_intensity > SPEEDLINES_MIN_VISIBLE
	if not speedlines_rect.visible:
		return
	var material := speedlines_rect.material as ShaderMaterial
	material.set_shader_parameter("line_color", Color(0.04, 0.04, 0.06, SPEEDLINES_ALPHA * speedlines_intensity))
	material.set_shader_parameter("reroll_rate", 0.0 if PresentationSettings.reduce_motion else SPEEDLINES_REROLL_HZ)
	# The rays radiate from where the car is on screen.
	var actor: Node3D = world.actor_of(followed.id)
	var camera: Camera3D = world.camera
	var anchor: Vector3 = actor.global_position + Vector3.UP * SPEEDLINES_CAR_LIFT_M
	if not camera.is_position_behind(anchor):
		material.set_shader_parameter("center", camera.unproject_position(anchor) / get_viewport().get_visible_rect().size)


# --- input ---------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and handle_key(key.keycode):
		get_viewport().set_input_as_handled()


## Returns true when the HUD consumed the key.
func handle_key(keycode: Key) -> bool:
	if keycode == KEY_H:
		set_shown(not stage.visible)
		return true
	if not stage.visible:
		return false
	match keycode:
		KEY_B:
			deck.press_box()
		KEY_ENTER, KEY_KP_ENTER:
			if not card.visible:
				return false
			_on_accept()
		KEY_W:
			toggle_weather_deck()
		KEY_ESCAPE:
			if weather_deck.is_open:
				weather_deck.set_open(false)
			elif card.visible:
				_on_dismiss()
			elif _deck_box_called():
				deck.cancel_box()
			else:
				return false
		KEY_M:
			deck.toggle_collapsed()
		KEY_T:
			AudioManager.click(self)
			drawer.visible = not drawer.visible
		KEY_TAB:
			set_tower_mode((tower_mode + 1) % TOWER_MODES.size())
		KEY_E:
			deck.toggle_ers_overtake()
		KEY_BRACKETLEFT:
			deck.step_pace(-1)
		KEY_BRACKETRIGHT:
			deck.step_pace(1)
		KEY_N:
			_next_player_car()
		_:
			return false
	return true


## True while the deck car has a box call out that has not reached the pit lane.
func _deck_box_called() -> bool:
	var car: GtCar = race.get_car(deck.deck_car_id)
	return car != null and car.pit_request >= 0 and car.pit == null


## Shows or hides the whole HUD, the radio banner (a layer of its own) included.
func set_shown(shown: bool) -> void:
	stage.visible = shown
	if not shown:
		weather_deck.set_open(false)
	radio.visible = shown
	engineer_radio.visible = shown


func set_tower_mode(mode: int) -> void:
	tower_mode = clampi(mode, 0, TOWER_MODES.size() - 1)
	_tower_column.text = TOWER_MODES[tower_mode]
	_update_tower()


func _next_player_car() -> void:
	var cars: Array[GtCar] = deck.player_cars()
	if cars.is_empty():
		return
	var next: int = 0
	for index: int in range(cars.size()):
		if cars[index].id == world.followed_id:
			next = (index + 1) % cars.size()
	_on_car_picked(cars[next].id)


func _on_car_picked(car_id: int) -> void:
	world.followed_id = car_id
	_update_panels()


func _on_rate(index: int) -> void:
	world.set_time_scale(TIME_SCALES[index])


## Switches the HUD skin to another team's livery colour (data colours never follow it).
func set_team_accent(team_id: int) -> void:
	style.set_accent(Liveries.color_for(team_id))


func _on_style_changed() -> void:
	logo_label.add_theme_color_override("font_color", style.accent)
	marquee_bar.color = style.accent
	for label: Label in marquee_texts:
		label.add_theme_color_override("font_color", style.on_accent)
	deck.set_accent(style.accent, style.on_accent)
	_paint_engineer_card()


## The engineer's card is in the colour that complements the team's.
func _paint_engineer_card() -> void:
	if engineer_radio != null:
		engineer_radio.set_base_color(style.engineer)


## Portraits of all drivers are loaded once at bind, so no file is read while the radio is talking.
func _load_portrait(car_id: int) -> Texture2D:
	var path: String = GarageRoster.portrait_path(car_id)
	return load(path) as Texture2D if ResourceLoader.exists(path) else PORTRAIT


func _portrait_for(car_id: int) -> Texture2D:
	return _portraits.get(car_id, PORTRAIT)


## One card speaks, the other (if it is up) dims; when a card is done the other recovers.
func _on_cut_in_finished(cut_in: CanvasLayer) -> void:
	var other: CanvasLayer = engineer_radio if cut_in == radio else radio
	if other != null:
		other.set_dimmed(false)


func _on_accept() -> void:
	AudioManager.click(self)
	race.accept_suggestion()


func _on_dismiss() -> void:
	AudioManager.click(self)
	race.dismiss_suggestion()


# --- sim events ----------------------------------------------------------------------------

func _on_radio(message: Dictionary) -> void:
	last_radio = message
	deck.set_radio("%s: %s" % [String(message["code"]), String(message["text"])])
	var car: GtCar = race.get_car(int(message["car_id"]))
	var urgent: bool = bool(message["urgent"])
	var cut_in: CanvasLayer = engineer_radio if String(message["speaker"]) == "engineer" else radio
	# A routine call waits (ticker only) while an urgent card of the same speaker is still up.
	var blocked: bool = not urgent and cut_in.is_urgent()
	if (urgent or bool(message.get("rival", false)) or (car != null and car.team_id == race.player_team_id)) and not blocked:
		var other: CanvasLayer = radio if cut_in == engineer_radio else engineer_radio
		if other.is_present():
			other.set_dimmed(true)
		cut_in.set_dimmed(false)
		if String(message["speaker"]) == "driver":
			cut_in.set_base_color(message["team_color"])
			cut_in.set_portrait(_portrait_for(int(message["car_id"])))
		else:
			cut_in.set_portrait(ENGINEER_PORTRAIT)
		var clip: Dictionary = RadioVoice.find(String(message["speaker"]), String(message["text"]), int(message["car_id"]))
		var hold: float = 0.0
		if not clip.is_empty():
			hold = radio_audio.queue_voice(cut_in, clip)
		elif urgent:
			AudioManager.of(self).play_warning() # a spoken call needs no siren over the voice
		cut_in.play_radio(int(message["car_id"]), String(message["text"]), urgent, hold)
	_set_ticker("%s %s: %s   //   %s" % [String(message["code"]), String(message["speaker"]).to_upper(), String(message["text"]), ticker.text])


## The stewards' banner, with a beep for an investigation and the gavel for a penalty (no action is silent).
func _on_steward_event(event: Dictionary) -> void:
	steward_banner.show_event(event)
	var audio: AudioManager = AudioManager.of(self)
	if String(event.get("phase", "")) != "verdict":
		audio.play_steward_investigation()
	elif int(event.get("verdict", 0)) == GtStewards.Verdict.PENALTY:
		audio.play_steward_penalty()


func _on_flag_changed(flag: int, message: String) -> void:
	sc_banner.trigger(flag, message)
	_set_ticker("%s  //  %s   //   %s" % [GtTypes.FLAG_NAME[flag], message, ticker.text])


func _on_suggestion(suggestion: Dictionary) -> void:
	card.visible = not suggestion.is_empty()
	if suggestion.is_empty():
		card_critical = false
		return
	card_title.text = String(suggestion["title"])
	card_text.text = String(suggestion["description"])
	_update_burn()


func _set_ticker(text: String) -> void:
	ticker.text = text.substr(0, 400)
	_ticker_x = TICKER_VIEW_W


# --- per-frame mirror -------------------------------------------------------------------------

## One frame; the tower, panels and weather refresh on their own cadence.
func update(delta: float) -> void:
	if race == null:
		return
	sc_banner.advance(delta)
	steward_banner.advance(delta)
	var sc_phase: int = int(race.safety_car["phase"])
	if sc_phase != _last_sc_phase and sc_phase == GtTypes.SafetyCarPhase.IN_THIS_LAP:
		sc_banner.trigger(GtTypes.Flag.SC, "IN THIS LAP")
	_last_sc_phase = sc_phase
	_frame += 1
	_update_speedlines()
	_update_burn()
	if _frame % TOWER_REFRESH_FRAMES == 0:
		_update_tower()
	if _frame % PANEL_REFRESH_FRAMES == 0:
		_update_panels()
	if _frame % WEATHER_REFRESH_FRAMES == 0:
		_update_weather()
	_ticker_x -= delta * TICKER_SPEED
	if _ticker_x < -ticker.size.x - 30.0:
		_ticker_x = TICKER_VIEW_W
	ticker.position.x = _ticker_x


## Everything at once, for the first frame and for tests.
func refresh_all() -> void:
	_update_tower()
	_update_panels()
	_update_weather()
	_update_burn()


## Flame stage of the burn bar: yellow, then orange from two thirds, crimson in the last third.
static func burn_color(fraction: float) -> Color:
	if fraction >= 0.66:
		return T.ACCENT_CYBER_YELLOW
	if fraction >= 0.33:
		return BURN_ORANGE
	return T.ACCENT_ANIME_CRIMSON


static func burn_text(remaining: float) -> String:
	return "%04.1fs" % maxf(remaining, 0.0)


## The suggestion card burns down with the sim's own window (race seconds), so AUTO and the bar agree.
func _update_burn() -> void:
	if not card.visible:
		card_critical = false
		return
	var remaining: float = race.suggestion_remaining()
	var fraction: float = clampf(remaining / GtRace.SUGGESTION_WINDOW_S, 0.0, 1.0)
	card_critical = remaining < CARD_CRITICAL_S
	var flash: bool = card_critical and not PresentationSettings.reduce_motion and (_frame / CARD_BLINK_FRAMES) % 2 == 0
	burn_fill.size.x = (card.size.x - 8.0) * fraction
	burn_fill.color = burn_color(fraction)
	burn_fill.modulate.a = 0.55 if flash else 1.0
	card_timer.text = burn_text(remaining)
	card_timer.add_theme_color_override("font_color", (T.TEXT_PRIMARY if flash else T.ACCENT_ANIME_CRIMSON) if card_critical else T.ACCENT_CYBER_YELLOW)


func _update_tower() -> void:
	var entries: Array[Dictionary] = race.standings_entries()
	for entry: Dictionary in entries:
		var car: GtCar = race.get_car(int(entry["car_id"]))
		var mine: bool = car.team_id == race.player_team_id
		entry["driver_name"] = "%s#%02d %s" % ["*" if mine else "", int(entry["number"]), String(entry["code"])]
		entry["compound_letter"] = GtTypes.COMPOUND_LABEL[int(entry["compound"])]
		entry["compound_color"] = GtTypes.COMPOUND_COLOR[int(entry["compound"])]
		_tower_right_text(entry)
	tower.update_standings(entries)
	tower.select_car(world.followed_id)
	# A clicked row keeps the keyboard focus, which lights it like a selection. When the
	# followed car changes any other way (N, arrows, deck tab) the old row must go dark.
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null and tower.is_ancestor_of(focus) and int(focus.get_parent().car_id) != world.followed_id:
		focus.release_focus()


func _tower_right_text(entry: Dictionary) -> void:
	var text: String
	var tint: Color = T.TEXT_SECONDARY
	if bool(entry["is_dnf"]):
		text = "DNF"
		tint = T.ACCENT_ANIME_CRIMSON
	elif bool(entry["is_finished"]):
		text = "FIN"
		tint = T.ACCENT_ACID_LIME
	elif bool(entry["in_pit"]):
		text = "PIT"
		tint = T.ACCENT_ELECTRIC_CYAN
	else:
		var leader: bool = int(entry["position"]) <= 1
		match tower_mode:
			0:
				text = "LEAD" if leader else "+%.1f" % float(entry["interval_s"])
			1:
				text = "LEAD" if leader else "+%.1f" % float(entry["gap_s"])
			_:
				text = lap_text(float(entry["last_lap_time"]))
		if bool(entry["drs"]):
			tint = T.ACCENT_ACID_LIME
	entry["right_text"] = text
	entry["right_color"] = tint


## 83.456 -> "1:23.456", no lap yet -> "--".
static func lap_text(seconds: float) -> String:
	if seconds <= 0.0:
		return "--"
	return "%d:%06.3f" % [int(seconds / 60.0), fmod(seconds, 60.0)]


func _update_panels() -> void:
	var order: Array[GtCar] = race.standings()
	var leader: GtCar = order[0]
	lap_label.text = "LAP %02d/%02d" % [clampi(leader.lap + 1, 1, race.laps), race.laps]
	_update_flag_banner()
	rate_row.set_active(TIME_SCALES.find(world.time_scale))
	cam_label.text = String(world.camera_director.get_mode_name()).to_upper()
	var drs_on: bool = bool(race.race_control["drs_enabled"])
	drs_label.text = "DRS ENABLED" if drs_on else "DRS OFF"
	drs_label.add_theme_color_override("font_color", T.ACCENT_ACID_LIME if drs_on else T.TEXT_MUTED)
	var cars: Array[Dictionary] = []
	var fastest: GtCar = null
	var trap: GtCar = null
	for car: GtCar in race.cars:
		cars.append({
			"car_id": car.id, "team_id": car.team_id, "spline_distance": fposmod(car.s, world.track.length),
			"number": car.number, "position": order.find(car) + 1, "followed": car.id == world.followed_id,
			"player": car.team_id == race.player_team_id, "in_pit": car.pit != null, "retired": car.is_dnf,
		})
		if car.best_lap > 0.0 and (fastest == null or car.best_lap < fastest.best_lap):
			fastest = car
		if car.speed_trap_speed > 0.0 and (trap == null or car.speed_trap_speed > trap.speed_trap_speed):
			trap = car
	var watched: GtCar = race.get_car(world.followed_id)
	var yellow_sector: int = int(race.race_control["sector"]) if int(race.race_control["flag"]) == GtTypes.Flag.YELLOW else 0
	radar.update_snapshot({
		"cars": cars, "yellow_sector": yellow_sector,
		"sector_colors": watched.sector_colors if watched != null else [], "sector": watched.current_sector if watched != null else -1,
		"followed_text": "#%d %s" % [watched.number, watched.code] if watched != null else "",
	})
	records_label.text = "FASTEST LAP  %s\nSPEED TRAP   %s\nTRACK %d°C   AIR %d°C" % [
		"%s %s" % [fastest.code, lap_text(fastest.best_lap)] if fastest != null else "--",
		"%s %d KM/H" % [trap.code, roundi(trap.speed_trap_speed)] if trap != null else "--",
		roundi(race.weather.track_temp), roundi(race.weather.air_temp),
	]
	deck.refresh()
	var followed: GtCar = race.get_car(world.followed_id)
	if followed != null:
		if followed.team_id == race.player_team_id:
			deck.deck_car_id = followed.id
		if drawer.visible:
			drawer.show_car(followed, race.laps)


func _update_flag_banner() -> void:
	var director: DirectorScript = world.director
	var flag: int = race.race_control["flag"]
	var text: String
	var tint: Color = T.ACCENT_ACID_LIME
	match director.state:
		DirectorScript.State.GRID_LINEUP:
			text = "GRID  //  %d CARS READY" % race.cars.size()
		DirectorScript.State.LIGHTS_COUNTDOWN, DirectorScript.State.LIGHTS_HOLD:
			text = "LIGHTS  %s" % "●".repeat(director.lights_on())
			tint = T.ACCENT_ANIME_CRIMSON
		_:
			if race.is_finished():
				text = "CHEQUERED FLAG"
				tint = T.TEXT_PRIMARY
			elif flag != GtTypes.Flag.GREEN:
				text = "%s FLAG" % GtTypes.FLAG_NAME[flag]
				tint = T.ACCENT_CYBER_YELLOW
			elif race.time < 2.0:
				text = "LIGHTS OUT!"
			else:
				text = "GREEN FLAG"
	flag_label.text = text
	flag_label.add_theme_color_override("font_color", tint)
	var caution: bool = flag != GtTypes.Flag.GREEN and not race.is_finished() and director.is_racing()
	tape.visible = caution
	if caution:
		tape.set_message("%s  //  %s" % [GtTypes.FLAG_NAME[flag], String(race.race_control["message"]).to_upper()])


func _update_weather() -> void:
	weather_widget.update_status(weather_status())
	var weather: GtWeather = race.weather
	var rows: Array[Dictionary] = GtWeatherOutlook.ahead(weather, leader_lap(), GtWeatherOutlook.CHART_LAPS, race.laps)
	var summary: Dictionary = GtWeatherOutlook.summary(rows)
	weather_widget.update_outlook(rows.slice(0, GtWeatherOutlook.LADDER_LAPS), summary, weather.air_temp, weather.track_temp)
	if weather_deck.is_open:
		weather_deck.update_outlook(rows, summary, {
			"air": weather.air_temp, "track": weather.track_temp, "humidity": weather.humidity, "wind_kmh": weather.wind_speed,
			"wind_dir": weather.wind_direction, "water": weather.track_water_pct, "drying_line": weather.drying_line_pct,
		})


## The chip and [W] open and close the weather deck, which is refreshed as it opens.
func toggle_weather_deck() -> void:
	AudioManager.click(self)
	weather_deck.toggle()
	if weather_deck.is_open:
		_update_weather()


## The weather deck's button: the engineer's tyre for the next box call, shown on the chips and the wheel.
func _on_weather_tyres(compound: int, _box_k: int) -> void:
	deck.pit_compound = compound
	deck.tyre_row.set_active(compound + 1)
	deck.wheel.set_compound(compound + 1, true)
	deck.apply_click_feedback(deck.wheel, "TYRES", 1.1)
	deck.refresh()


## The GT weather in the shape the pit wall radar widget draws (dry / drizzle / heavy / drying).
func weather_status() -> Dictionary:
	var weather: GtWeather = race.weather
	var forecast: Array[int] = []
	var rows: Array[Dictionary] = GtWeatherOutlook.ahead(weather, leader_lap(), 5)
	for index: int in range(1, rows.size()):
		forecast.append(int(rows[index]["state"]))
	return {
		"state": weather_state(weather.rain_intensity, weather.track_water_pct),
		"wetness_pct": clampf(weather.track_water_pct / 100.0, 0.0, 1.0),
		"forecast": forecast,
		"ambient_c": weather.air_temp,
	}


## 0 dry, 1 drizzle, 2 heavy rain, 3 drying (wet track, no rain).
static func weather_state(rain: float, water_pct: float) -> int:
	return GtWeatherOutlook.state_of(rain, water_pct)


## The lap the leader is on, which the weather forecast is indexed by.
func leader_lap() -> int:
	return GtWeatherOutlook.leader_lap(race, world.track.length)
