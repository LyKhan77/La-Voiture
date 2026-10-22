extends Control

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")
const Session = preload("res://scripts/ui/race_control_session.gd")
const WeatherWidget = preload("res://scripts/ui/weather_radar_widget.gd")
const Workspace = preload("res://scripts/ui/circuit_workspace.gd")
const TowerScene = preload("res://scenes/pit_wall/timing_tower.tscn")
const DeckScene = preload("res://scenes/pit_wall/driver_strategy_deck.tscn")
const RadioScene = preload("res://scenes/pit_wall/anime_radio_cutin.tscn")
const PORTRAIT = preload("res://assets/original-manga-racing-driver-portrait-he-cmvgxpt8.png")
var session: Node
var tower: Control
var deck: Control
var workspace: Control
var radio: CanvasLayer
var selected_car_id := 0
var _ribbon_lap: Label
var _ribbon_weather: Label
var _weather_widget: Control
var _ribbon_flag: Label
var _ticker: Label
var _speed_buttons: Array[Button] = []
var _workspace_root: Control
var _ticker_x := 0.0
var _shake: Tween
var _base_transform := Transform2D.IDENTITY

func _ready() -> void:
	_build_backdrop()
	_build_workspace()
	_build_events()
	session = Session.new()
	session.name = "Session"
	session.telemetry_updated.connect(_on_snapshot)
	session.radio_transmission.connect(_on_radio)
	add_child(session)
	tower.driver_selected.connect(_select_focus)
	deck.car_selected.connect(_select_team_car)
	deck.pace_requested.connect(session.set_pace)
	deck.fuel_requested.connect(session.set_fuel)
	deck.box_requested.connect(session.request_box)
	deck.impact_requested.connect(_impact)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_select_team_car(0)
	session.publish()

func _root_on(layer: CanvasLayer, node_name: String) -> Control:
	var root := Control.new()
	root.name = node_name
	root.size = Vector2(1920,1080)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	return root

func _build_backdrop() -> void:
	var root := _root_on($BackdropLayer, "Backdrop")
	var background := ColorRect.new()
	background.color = T.BG_CANVAS_DEEP
	background.size = root.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var dots := ColorRect.new()
	dots.size = root.size
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = UI.DOTS
	mat.set_shader_parameter("dot_color", Color(T.ACCENT_ACID_LIME, .14))
	mat.set_shader_parameter("dot_spacing",16.0)
	dots.material = mat
	root.add_child(dots)
	var hollow := UI.label("PIT_WALL // 作戦", 164, T.BG_CANVAS_DEEP, UI.DISPLAY)
	hollow.add_theme_color_override("font_outline_color",Color("#353c3e"))
	hollow.add_theme_constant_override("outline_size",2)
	hollow.position = Vector2(25,57)
	root.add_child(hollow)
	var meta := UI.label("LA VOITURE / MOTORSPORT OPERATIONS", 12,T.ACCENT_ACID_LIME)
	meta.position = Vector2(36,161)
	root.add_child(meta)
	var right := UI.label("LIVE SESSION     //     COMMAND CENTER  02",12,T.TEXT_SECONDARY)
	right.position = Vector2(1393,161)
	root.add_child(right)

func _build_workspace() -> void:
	_workspace_root = _root_on($WorkspaceLayer,"Workspace")
	var ribbon := Control.new()
	ribbon.name = "SessionRibbon"
	ribbon.position = Vector2(0,0)
	ribbon.size = Vector2(1920,56)
	_workspace_root.add_child(ribbon)
	UI.surface(ribbon)
	var series := UI.label("■  GT SERIES // RD.04",25,T.ACCENT_ACID_LIME,UI.HEADER)
	series.position = Vector2(32,11)
	ribbon.add_child(series)
	_ribbon_lap = UI.label("LAP 01 / 50",19)
	_ribbon_lap.position = Vector2(340,15)
	ribbon.add_child(_ribbon_lap)
	_weather_widget = WeatherWidget.new()
	_weather_widget.name = "WeatherRadar"
	_weather_widget.position = Vector2(590,0)
	ribbon.add_child(_weather_widget)
	_ribbon_weather = _weather_widget.status_label
	_ribbon_flag = UI.label("■ GREEN FLAG",17,T.ACCENT_ACID_LIME,UI.HEADER)
	_ribbon_flag.position = Vector2(945,17)
	ribbon.add_child(_ribbon_flag)
	var time_label := UI.label("SIM RATE",12,T.TEXT_SECONDARY)
	time_label.position = Vector2(1260,19)
	ribbon.add_child(time_label)
	for i: int in range(5):
		var speed: float = pow(2,i)
		var button := UI.button("%dx" % int(speed))
		button.name = "Speed%dx" % int(speed)
		button.position = Vector2(1370 + i * 100,8)
		button.size = Vector2(88,40)
		button.pressed.connect(func(): session.set_speed(speed))
		ribbon.add_child(button)
		_speed_buttons.append(button)
	tower = TowerScene.instantiate()
	tower.name = "TimingTower"
	tower.position = Vector2(32,208)
	tower.size = Vector2(320,784)
	_workspace_root.add_child(tower)
	workspace = Control.new()
	workspace.set_script(Workspace)
	workspace.name = "CircuitWorkspace"
	workspace.position = Vector2(376,208)
	workspace.size = Vector2(1128,784)
	_workspace_root.add_child(workspace)
	deck = DeckScene.instantiate()
	deck.name = "DriverStrategyDeck"
	deck.position = Vector2(1528,208)
	deck.size = Vector2(360,784)
	_workspace_root.add_child(deck)

func _build_events() -> void:
	var root := _root_on($ReactiveLayer,"Events")
	var bar := ColorRect.new()
	bar.name = "EventMarquee"
	bar.color = T.ACCENT_ACID_LIME
	bar.position = Vector2(0,1016)
	bar.size = Vector2(1920,64)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var title := UI.label("RACE CONTROL",23,T.INK_BORDER_BLACK,UI.HEADER)
	title.position = Vector2(32,1033)
	root.add_child(title)
	var clip := Control.new()
	clip.position = Vector2(226,1016)
	clip.size = Vector2(1664,64)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(clip)
	_ticker = UI.label("LIVE TIMING ONLINE   //   APEX RACING: TWO CARS, ONE STRATEGY   //   SELECT DRIVER TO FOCUS   //   BOX COMMANDS ARMED",20,T.INK_BORDER_BLACK,UI.RADIO)
	_ticker.position = Vector2(0,18)
	clip.add_child(_ticker)
	radio = RadioScene.instantiate()
	radio.name = "AnimeRadioCutIn"
	add_child(radio)
	radio.set_portrait(PORTRAIT)

func _on_snapshot(snapshot: Dictionary) -> void:
	tower.update_standings(snapshot.standings)
	workspace.update_snapshot(snapshot)
	for entry: Dictionary in snapshot.cars:
		if int(entry.car_id) == int(deck.selected_car_id):
			deck.update_telemetry(entry)
			break
	_ribbon_lap.text = "LAP %02d / %02d" % [snapshot.lap,snapshot.total_laps]
	var status: Dictionary = session.control.get_status()
	_weather_widget.update_status(status)
	if snapshot.finished:
		_ribbon_flag.text = "■ CHEQUERED"
	elif status.safety_car:
		_ribbon_flag.text = "■ YELLOW FLAG // SAFETY CAR"
	else:
		_ribbon_flag.text = "■ GREEN FLAG"
	_ribbon_flag.add_theme_color_override("font_color",T.ACCENT_CYBER_YELLOW if status.safety_car and not snapshot.finished else T.ACCENT_ACID_LIME)
	for i: int in range(_speed_buttons.size()):
		var active: bool = is_equal_approx(float(snapshot.time_scale),pow(2,i))
		_speed_buttons[i].add_theme_stylebox_override("normal",UI.style(T.SURFACE_SNAP_INVERT if active else T.SURFACE_PANEL_ELEVATED,T.ACCENT_ACID_LIME if active else T.INK_BORDER_BLACK))
		_speed_buttons[i].add_theme_color_override("font_color",T.INK_BORDER_BLACK if active else T.TEXT_PRIMARY)

func _select_focus(car_id: int) -> void:
	selected_car_id = car_id
	tower.select_car(car_id)
	workspace.select_car(car_id)
	if car_id < 2:
		deck.select_car(car_id)
	if session:
		_on_snapshot(session.snapshot)

func _select_team_car(car_id: int) -> void:
	deck.select_car(car_id)
	_select_focus(car_id)

func _on_radio(car_id: int, message: String, urgent: bool) -> void:
	radio.play_radio(car_id,message,urgent)
	_ticker.text = "CAR #%02d // %s   //   LIVE TELEMETRY ONLINE" % [car_id + 1,message]
	_ticker_x = 0

func _process(delta: float) -> void:
	if _ticker:
		_ticker_x -= delta * 45
		if _ticker_x < -_ticker.size.x - 30:
			_ticker_x = 1664
		_ticker.position.x = _ticker_x

func _fit() -> void:
	var viewport_size := get_viewport_rect().size
	var factor: float = minf(viewport_size.x / 1920,viewport_size.y / 1080)
	var offset: Vector2 = (viewport_size - Vector2(1920,1080) * factor) * .5
	_base_transform = Transform2D(0,Vector2(factor,factor),0,offset)
	$BackdropLayer.transform = _base_transform
	$WorkspaceLayer.transform = _base_transform
	$ReactiveLayer.transform = _base_transform
	# Radio uses its own bottom anchoring so it inherits the engine canvas scaling.

func _impact() -> void:
	if _shake and _shake.is_valid():
		_shake.kill()
	_workspace_root.position = Vector2.ZERO
	_shake = create_tween()
	for offset: Vector2 in [Vector2(3,-2),Vector2(-3,2),Vector2(2,1),Vector2(-1,-1),Vector2.ZERO]:
		_shake.tween_property(_workspace_root,"position",offset,.035)
