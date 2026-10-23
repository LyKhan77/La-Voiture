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
## Keys: M fold the deck, T telemetry, Tab tower columns, H hide the HUD, E ERS overtake,
## [ and ] pace down / up, N next car of the player team.

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")
const DirectorScript := preload("res://scripts/world/race_weekend_director.gd")
const TowerScene := preload("res://scenes/pit_wall/timing_tower.tscn")
const RadarScene := preload("res://scenes/pit_wall/circuit_radar_2d.tscn")
const RadioScene := preload("res://scenes/pit_wall/anime_radio_cutin.tscn")
const PORTRAIT := preload("res://assets/original-manga-racing-driver-portrait-he-cmvgxpt8.png")
const ENGINEER_PORTRAIT := preload("res://assets/manga-race-engineer-portrait.png")
const CutInScript := preload("res://scripts/ui/anime_radio_cutin.gd")
const RadioAudioScript := preload("res://scripts/audio/radio_audio_director.gd")

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
const SPEEDLINES_LAYER: int = 5
## Rays appear at 200 km/h and are full at 280: 240 km/h already reads at 0.5.
const SPEEDLINES_FROM_KMH: float = 200.0
const SPEEDLINES_FULL_KMH: float = 280.0
const SPEEDLINES_ALPHA: float = 0.8
const SPEEDLINES_MIN_VISIBLE: float = 0.02

var world: Node3D
var race: GtRace
var stage: Control
var tower: Control
var radar: Control
var weather_widget: WeatherRadarWidget
var drawer: TelemetryDrawer
var deck: TacticalDeck
## Driver calls cut in at the bottom left, the pit wall engineer at the bottom right.
var radio: CanvasLayer
var engineer_radio: CanvasLayer
var radio_audio: RadioAudioScript
var tape: CautionTape
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
	drawer = TelemetryDrawer.new()
	drawer.name = "TelemetryDrawer"
	stage.add_child(drawer)
	drawer.position = Vector2(1598.0, 372.0)
	_build_card()
	_build_marquee()
	_build_speedlines()
	tape = CautionTape.new()
	tape.name = "CautionTape"
	stage.add_child(tape)
	tape.position = Vector2(650.0, 84.0)
	tape.visible = false
	radio_audio = RadioAudioScript.new()
	radio_audio.name = "RadioAudioDirector"
	add_child(radio_audio)
	radio = _make_cut_in("AnimeRadioCutIn", CutInScript.Role.DRIVER, "DRIVER", PORTRAIT)
	engineer_radio = _make_cut_in("EngineerRadioCutIn", CutInScript.Role.ENGINEER, "ENGINEER", ENGINEER_PORTRAIT)
	race.radio_message.connect(_on_radio)
	race.flag_changed.connect(_on_flag_changed)
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
	return cut_in


func fit() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var factor: float = minf(view.x / STAGE.x, view.y / STAGE.y)
	stage.scale = Vector2(factor, factor)
	stage.position = (view - STAGE * factor) * 0.5
	var dock := Rect2(stage.position + RADIO_DOCK.position * factor, RADIO_DOCK.size * factor)
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
	_text(ribbon, "LA VOITURE", Vector2(20.0, 8.0), 32, T.ACCENT_ACID_LIME, UI.DISPLAY)
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
	card_title = _text(card, "", Vector2(16.0, 10.0), 24, T.ACCENT_CYBER_YELLOW, UI.HEADER)
	card_text = _text(card, "", Vector2(16.0, 42.0), 14, T.TEXT_PRIMARY, UI.RADIO)
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
	bar.color = T.ACCENT_ACID_LIME
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bar)
	bar.position = Vector2(0.0, 1032.0)
	bar.size = Vector2(1920.0, 48.0)
	_text(bar, "RACE CONTROL", Vector2(32.0, 10.0), 23, T.INK_BORDER_BLACK, UI.HEADER)
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(clip)
	clip.position = Vector2(226.0, 0.0)
	clip.size = Vector2(TICKER_VIEW_W, 48.0)
	ticker = _text(clip, "LIVE TIMING ONLINE   //   GREEN FLAG   //   %d LAPS   //   [M] DECK  [T] TELEMETRY  [TAB] TOWER  [N] NEXT CAR  [E] ERS  [ ] PACE  [H] HIDE" % race.laps, Vector2(0.0, 12.0), 20, T.INK_BORDER_BLACK, UI.RADIO)


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
	material.set_shader_parameter("ray_count", 72.0)
	material.set_shader_parameter("inner", 0.35)
	material.set_shader_parameter("outer", 0.95)
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
	if speedlines_rect.visible:
		(speedlines_rect.material as ShaderMaterial).set_shader_parameter("line_color", Color(0.04, 0.04, 0.06, SPEEDLINES_ALPHA * speedlines_intensity))


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


## Shows or hides the whole HUD, the radio banner (a layer of its own) included.
func set_shown(shown: bool) -> void:
	stage.visible = shown
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
	if urgent or bool(message.get("rival", false)) or (car != null and car.team_id == race.player_team_id):
		var cut_in: CanvasLayer = engineer_radio if String(message["speaker"]) == "engineer" else radio
		if String(message["speaker"]) == "driver":
			var portrait_path: String = GarageRoster.portrait_path(int(message["car_id"]))
			cut_in.set_portrait(load(portrait_path) as Texture2D if ResourceLoader.exists(portrait_path) else PORTRAIT)
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


func _on_flag_changed(flag: int, message: String) -> void:
	_set_ticker("%s  //  %s   //   %s" % [GtTypes.FLAG_NAME[flag], message, ticker.text])


func _on_suggestion(suggestion: Dictionary) -> void:
	card.visible = not suggestion.is_empty()
	if suggestion.is_empty():
		return
	card_title.text = String(suggestion["title"])
	card_text.text = String(suggestion["description"])


func _set_ticker(text: String) -> void:
	ticker.text = text.substr(0, 400)
	_ticker_x = TICKER_VIEW_W


# --- per-frame mirror -------------------------------------------------------------------------

## One frame; the tower, panels and weather refresh on their own cadence.
func update(delta: float) -> void:
	if race == null:
		return
	_frame += 1
	_update_speedlines()
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


## The GT weather in the shape the pit wall radar widget draws (dry / drizzle / heavy / drying).
func weather_status() -> Dictionary:
	var weather: GtWeather = race.weather
	var forecast: Array[int] = []
	var lap: int = maxi(1, floori(1.0 + maxf(0.0, race.standings()[0].s) / world.track.length))
	var last: Dictionary = weather.forecast[weather.forecast.size() - 1]
	for ahead: int in range(1, 6):
		var point: Dictionary = last
		for candidate: Dictionary in weather.forecast:
			if int(candidate["lap"]) == lap + ahead:
				point = candidate
		forecast.append(weather_state(float(point["rain_intensity"]), float(point["water_pct"])))
	return {
		"state": weather_state(weather.rain_intensity, weather.track_water_pct),
		"wetness_pct": clampf(weather.track_water_pct / 100.0, 0.0, 1.0),
		"forecast": forecast,
		"ambient_c": weather.air_temp,
	}


## 0 dry, 1 drizzle, 2 heavy rain, 3 drying (wet track, no rain).
static func weather_state(rain: float, water_pct: float) -> int:
	if rain > 0.55:
		return 2
	if rain > 0.08:
		return 1
	return 3 if water_pct > 8.0 else 0
