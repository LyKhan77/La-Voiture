class_name WinningScene
extends Node3D

## Dedicated, simulation-independent finale. Only value snapshots survive race teardown.
signal restart_requested
signal exit_requested

const UI := preload("res://scripts/ui/pit_wall_ui.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const Roster := preload("res://scripts/ui/garage_roster.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const Standee := preload("res://scripts/ui/kinetic_standee_3d.gd")
const WallCut := preload("res://scripts/ui/winning_wall_cut.gd")
const Callouts := preload("res://scripts/ui/winning_hero_callouts.gd")
const FinalHud := preload("res://scripts/ui/winning_final_hud.gd")
const Kit := preload("res://scripts/ui/graffiti_kit.gd")
const INK_PURPLE := Color("#7A2BC9")
const DOLLY_SECONDS: float = 0.7
const IMPACT_SECONDS: float = 0.08
const IMPACT_SHADER := preload("res://shaders/winning_impact_frame.gdshader")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const POINTS: Array[int] = [25, 18, 15, 12, 10, 8, 6, 4, 2, 1]
const MEDALS: Array[Color] = [Color("#FFD23F"), Color("#D8DCE6"), Color("#D9803A")]
## Hero set: a turntable at the origin, filmed from a low three-quarter angle; P1 stands beside it.
const TURNTABLE_SPEED: float = 0.18
const ORBIT_MAX_RAD: float = 0.105
const ORBIT_RATE: float = 0.35
const HERO_CAMERA_POS := Vector3(0.0, 1.3, 6.4)
const HERO_CAMERA_TARGET := Vector3(0.0, 1.0, 0.0)
const DETAIL_CAMERA_POS := Vector3(2.4, 0.9, 3.6)
const DETAIL_CAMERA_TARGET := Vector3(0.9, 0.6, 1.8)
const P1_STANDEE_POS := Vector3(2.7, 0.0, 1.4)
## Wall stations: P3 and P2 each get a concrete wall far to the side, filmed head-on and locked.
const STATION_X: Dictionary = {2: 30.0, 1: -30.0}
const STATION_CAMERA_OFFSET := Vector3(0.0, 1.0, 3.6)
const STATION_TARGET_OFFSET := Vector3(0.0, 0.95, 0.0)
const CONCRETE := preload("res://shaders/winning_concrete.gdshader")
const STAGE := Vector2(1920, 1080)
const PATH := "res://scenes/ui/winning_scene.tscn"

## Single-use handoff: copied into the new scene then cleared immediately.
static var pending_results: Dictionary = {}
static var pending_frame: ImageTexture
var results: Dictionary = {}
var order: Array = []
var standees: Array[Node3D] = []
var hero_set: Node3D
var wall_stations: Dictionary = {} # place index (1 = P2, 2 = P3) -> Node3D
var name_labels: Array[Label] = []
var time_labels: Array[Label] = []
var timing_rows: Array[Label] = []
var team_labels: Array[Label] = []
var turntable: Node3D
var car_slot: Node3D
var camera: Camera3D
var confetti: GPUParticles3D
var leaderboard: Control
var toggle_button: Button
var restart_button: Button
var exit_button: Button
var fastest_label: Label
var is_leaderboard_open: bool = false
var _stage: Control
var _winner_label: Label
var _slide: Tween
var _orbit_time: float = 0.0
var _cam_pos: Vector3 = HERO_CAMERA_POS
var _cam_target: Vector3 = HERO_CAMERA_TARGET
var _cut: int = WinningCutDirector.Cut.FINAL
var director: WinningCutDirector
var _wall_huds: Dictionary = {} # place index (1 = P2, 2 = P3) -> Control
var _wall_layer: Control
var _cut_label: Label
var final_hud: Control
var headline: Label
var crown: Control
var hero_callouts: Control
var _car_model: Node3D
var _car_box: AABB
var _cam_tween: Tween
var _impact: ColorRect
var _impact_tween: Tween
var _suppress_flash: bool = false
var _cut_seen: bool = false
var _leaving: bool = false
var _built: bool = false
var _speedlines: ColorRect
var _audio_hub: AudioManager


static func points_for(place: int) -> int:
	return POINTS[place - 1] if place >= 1 and place <= POINTS.size() else 0


static func fastest_lap_car(cars: Array[GtCar]) -> GtCar:
	var best: GtCar
	for car: GtCar in cars:
		if car.best_lap > 0.0 and (best == null or car.best_lap < best.best_lap):
			best = car
	return best


static func award_points(final_order: Array[GtCar], fastest: GtCar) -> Dictionary:
	var drivers: Dictionary = {}
	var teams: Dictionary = {}
	for i: int in range(final_order.size()):
		var car: GtCar = final_order[i]
		var score: int = 0 if car.is_dnf else points_for(i + 1)
		if car == fastest and score > 0:
			score += 1
		drivers[car.id] = score
		teams[car.team_id] = int(teams.get(car.team_id, 0)) + score
	return {"drivers": drivers, "teams": teams}


static func format_time(seconds: float) -> String:
	var hours: int = int(seconds / 3600.0)
	var minutes: int = int(fmod(seconds, 3600.0) / 60.0)
	var rest: float = fmod(seconds, 60.0)
	return "%d:%02d:%06.3f" % [hours, minutes, rest] if hours > 0 else "%d:%06.3f" % [minutes, rest]


static func standee_path(slot: int) -> String:
	var slug: String = Roster.DRIVER_SLUGS[slot].replace("-", "_")
	if slug == "arthur_sterling_jr":
		slug = "arthur_sterling"
	return "res://assets/characters/standees/%s.png" % slug


static func capture_results(race: GtRace) -> Dictionary:
	var final_order: Array[GtCar] = race.standings()
	var fastest: GtCar = fastest_lap_car(race.cars)
	var awards: Dictionary = award_points(final_order, fastest)
	var rows: Array[Dictionary] = []
	for car: GtCar in final_order:
		rows.append({"id": car.id, "team_id": car.team_id, "driver_name": car.driver_name,
			"team_name": car.team_name, "number": car.number, "code": car.code,
			"time": race.classified_time(car), "best_lap": car.best_lap,
			"laps": floori(car.s / race.track.length), "is_dnf": car.is_dnf,
			"points": awards.drivers[car.id]})
	var fastest_data: Dictionary = {}
	if fastest != null:
		fastest_data = {"id": fastest.id, "code": fastest.code, "time": fastest.best_lap,
			"bonus": 1 if not fastest.is_dnf and final_order.find(fastest) < 10 else 0}
	return {"order": rows, "winner_car": Roster.CAR_SLUGS[final_order[0].team_id] if not rows.is_empty() else "",
		"team_points": awards.teams, "fastest_lap": fastest_data}


static func capture_departure(viewport: Viewport) -> void:
	if DisplayServer.get_name() != "headless" and not Settings.reduce_motion:
		pending_frame = ImageTexture.create_from_image(viewport.get_texture().get_image())


func _reveal_departure() -> void:
	if pending_frame == null:
		return
	var overlay := CanvasLayer.new()
	overlay.name = "DepartureWipe"
	overlay.layer = 50
	add_child(overlay)
	var wipe := ColorRect.new()
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(wipe)
	wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/winning_reveal.gdshader")
	material.set_shader_parameter("snapshot", pending_frame)
	wipe.material = material
	pending_frame = null
	await RenderingServer.frame_post_draw
	material.set_shader_parameter("negative_snap", false)
	material.set_shader_parameter("snapshot", null)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("progress", value), 0.0, 1.01, 0.55)
	tween.tween_callback(overlay.queue_free)


func setup_celebration(snapshot: Dictionary) -> void:
	results = snapshot.duplicate(true)
	order = results.get("order", [])
	if _built:
		_populate()


func _ready() -> void:
	if results.is_empty() and not pending_results.is_empty():
		setup_celebration(pending_results)
	pending_results.clear()
	_build_studio()
	_build_ui()
	_built = true
	_populate()
	get_viewport().size_changed.connect(_fit)
	_fit()
	Settings.apply_to_tree(self)
	for light: Node in find_children("*", "Light3D", true, false):
		(light as Light3D).shadow_blur = 0.0
	toggle_button.grab_focus()
	var hub: AudioManager = AudioManager.of(self)
	if hub != null:
		_audio_hub = hub
		hub.play_podium_music()
	_reveal_departure()


func _exit_tree() -> void:
	_hand_back_music()


func _process(delta: float) -> void:
	if _leaving:
		return
	director.tick(delta)
	if hero_callouts != null and _car_model != null:
		Callouts.place(hero_callouts, camera, _car_model, _car_box, get_viewport().get_visible_rect().size, _cut)
	if _cut == WinningCutDirector.Cut.DETAIL:
		_apply_camera()
	if _cut == WinningCutDirector.Cut.FINAL and not standees.is_empty():
		crown.rotation_degrees = 10.0
		crown.position = _stage_point(standees[0].global_position + Vector3(0.0, 1.92, 0.0)) - Vector2(crown.size.x * 0.5, crown.size.y)
	if Settings.reduce_motion:
		return
	turntable.rotation.y += TURNTABLE_SPEED * delta
	# Only the 3D hero shots sweep; the wall cuts are locked head-on, and reading the timing tower freezes the orbit.
	if not is_leaderboard_open and (_cut == WinningCutDirector.Cut.HERO or _cut == WinningCutDirector.Cut.FINAL):
		_orbit_time += delta
		_apply_camera()


## Horizontal sweep of the camera around its current focus, never more than ORBIT_MAX_RAD.
func _cam_orbit_angle() -> float:
	return sin(_orbit_time * ORBIT_RATE) * ORBIT_MAX_RAD


func _apply_camera() -> void:
	camera.position = _cam_target + Basis(Vector3.UP, _cam_orbit_angle()) * (_cam_pos - _cam_target)
	camera.look_at(_cam_target)


func _input(event: InputEvent) -> void:
	# TAB must not be consumed by Control focus traversal before reaching this screen.
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _leaving:
		return
	var skipping: bool = not director.is_final() and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE)
	if not skipping and key.keycode != KEY_TAB and key.keycode != KEY_R and key.keycode != KEY_ESCAPE:
		return
	# A successful scene change immediately detaches this node and its viewport.
	get_viewport().set_input_as_handled()
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			skip_cuts()
		KEY_TAB:
			if not director.is_final():
				skip_cuts()
			toggle_leaderboard()
		KEY_R:
			_restart()
		KEY_ESCAPE:
			_exit_to_hq()
		_:
			return


## A click on empty stage (buttons and the tower consume their own clicks) skips the cut timeline.
func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and not _leaving and not director.is_final():
		get_viewport().set_input_as_handled()
		skip_cuts()


## Jumps to the final composition. A skip is a decision, not a cut, so it does not flash.
func skip_cuts() -> void:
	_suppress_flash = true
	director.skip_to_final()
	_suppress_flash = false


func _flash_cut() -> void:
	if Settings.reduce_motion or _suppress_flash:
		return
	if _impact_tween != null and _impact_tween.is_valid():
		_impact_tween.kill()
	_impact.visible = true
	_impact_tween = create_tween()
	_impact_tween.tween_callback(_impact.hide).set_delay(IMPACT_SECONDS)


## start_music() does not restart a running track, so the anthem must be replaced before leaving.
func _hand_back_music() -> void:
	var hub: AudioManager = AudioManager.of(self) if is_inside_tree() else _audio_hub
	if hub == null:
		hub = _audio_hub
	if hub != null and is_instance_valid(hub):
		hub.play_menu_music()


func toggle_leaderboard() -> void:
	is_leaderboard_open = not is_leaderboard_open
	if _slide != null:
		_slide.kill()
	leaderboard.visible = true
	leaderboard.mouse_filter = Control.MOUSE_FILTER_STOP if is_leaderboard_open else Control.MOUSE_FILTER_IGNORE
	toggle_button.text = "[TAB] /// HIDE LEADERBOARD" if is_leaderboard_open else "[TAB] /// SHOW LEADERBOARD"
	_slide = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_slide.tween_property(leaderboard, "position:x", 1280.0 if is_leaderboard_open else 1940.0,
		0.0 if Settings.reduce_motion else 0.25)
	_slide.parallel().tween_property(camera, "h_offset", 1.1 if is_leaderboard_open else 0.0,
		0.0 if Settings.reduce_motion else 0.25)
	if not is_leaderboard_open:
		_slide.tween_callback(leaderboard.hide)


## Builds the cut timeline for the current results and plays it (or lands on the final when motion is reduced).
func start_cuts() -> void:
	director = WinningCutDirector.new(WinningCutDirector.playlist_for(mini(order.size(), 3)))
	director.cut_changed.connect(_show_cut)
	_cut_seen = false
	director.start(Settings.reduce_motion)


func current_cut() -> int:
	return _cut


func _show_cut(cut: int) -> void:
	if _cut_seen:
		_flash_cut()
	_cut_seen = true
	_cut = cut
	_orbit_time = 0.0
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	match cut:
		WinningCutDirector.Cut.P3_TAG:
			_focus_station(2)
		WinningCutDirector.Cut.P2_TAG:
			_focus_station(1)
		WinningCutDirector.Cut.DETAIL:
			if Settings.reduce_motion:
				_cam_pos = DETAIL_CAMERA_POS
				_cam_target = DETAIL_CAMERA_TARGET
			else:
				# Dolly in from the hero pose, never from wherever the previous cut left the camera (a wall 30 m away).
				_cam_pos = HERO_CAMERA_POS
				_cam_target = HERO_CAMERA_TARGET
				_cam_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				_cam_tween.tween_property(self, "_cam_pos", DETAIL_CAMERA_POS, DOLLY_SECONDS)
				_cam_tween.tween_property(self, "_cam_target", DETAIL_CAMERA_TARGET, DOLLY_SECONDS)
		_:
			_cam_pos = HERO_CAMERA_POS
			_cam_target = HERO_CAMERA_TARGET
	_apply_camera()
	if _speedlines != null:
		_speedlines.visible = (cut == WinningCutDirector.Cut.DETAIL) and not Settings.reduce_motion
	for place: int in _wall_huds.keys():
		var show_wall: bool = (cut == WinningCutDirector.Cut.P3_TAG and place == 2) \
			or (cut == WinningCutDirector.Cut.P2_TAG and place == 1)
		var hud: Control = _wall_huds[place] as Control
		hud.visible = show_wall
		if show_wall and not Settings.reduce_motion:
			hud.pivot_offset = Vector2(960.0, 540.0)
			hud.scale = Vector2(0.90, 0.90)
			var pop: Tween = hud.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pop.tween_property(hud, "scale", Vector2.ONE, 0.35)
	var show_final: bool = (cut == WinningCutDirector.Cut.FINAL)
	final_hud.visible = show_final
	if show_final and not Settings.reduce_motion:
		final_hud.pivot_offset = Vector2(960.0, 540.0)
		final_hud.scale = Vector2(0.92, 0.92)
		var pop: Tween = final_hud.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(final_hud, "scale", Vector2.ONE, 0.4)
	_cut_label.text = director.label()


func _focus_station(place: int) -> void:
	var origin: Vector3 = (wall_stations[place] as Node3D).position
	_cam_pos = origin + STATION_CAMERA_OFFSET
	_cam_target = origin + STATION_TARGET_OFFSET


func _restart() -> void:
	if _leaving:
		return
	_leaving = true
	_hand_back_music()
	restart_requested.emit()
	var restart: Dictionary = results.get("restart", {})
	if bool(restart.get("standalone", false)):
		Config.current = null
		var world_script: Script = load("res://scripts/world/weekend/race_weekend_world.gd")
		world_script.pending_restart = restart.duplicate()
		get_tree().change_scene_to_file("res://scenes/race_weekend_world.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/manga_race_transition.tscn")


func _exit_to_hq() -> void:
	if _leaving:
		return
	_leaving = true
	_hand_back_music()
	exit_requested.emit()
	Config.current = null
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _fit() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var factor: float = minf(view.x / STAGE.x, view.y / STAGE.y)
	_stage.scale = Vector2.ONE * factor
	_stage.position = (view - STAGE * factor) * 0.5


func _material(color: Color, emission: float = 0.0) -> Material:
	return Toon.emissive(color, emission) if emission > 0.0 else Toon.make(color, true)


func _mesh(parent: Node3D, node_name: String, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, node_name: String, extent: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = extent
	return _mesh(parent, node_name, mesh, at, material)


func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 64
	return _mesh(parent, node_name, mesh, at, material)


func _concrete(tint: Color = Color("#2B2D36")) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CONCRETE
	material.set_shader_parameter("base_color", tint)
	return material


func _build_studio() -> void:
	var world := WorldEnvironment.new()
	world.name = "StudioEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#090D18")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#DCE3F2")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.002
	env.volumetric_fog_length = 24.0
	env.volumetric_fog_albedo = Color("#66738D")
	world.environment = env
	add_child(world)
	hero_set = Node3D.new()
	hero_set.name = "HeroSet"
	add_child(hero_set)
	var concrete := _concrete()
	# Wide enough that the side stations, the detail dolly and the wall cuts never see past the edge of the set.
	_box(hero_set, "StudioFloor", Vector3(100, 0.1, 28), Vector3(0, -0.05, -3), concrete)
	_box(hero_set, "ConcreteBackdrop", Vector3(100, 16, 0.3), Vector3(0, 7.5, -9.0), concrete)
	var ink := ShaderMaterial.new()
	ink.shader = Toon.OutlineShader
	ink.set_shader_parameter("outline_width", 0.018)
	var plinth := _concrete(Color("#1E2028"))
	plinth.next_pass = ink
	turntable = Node3D.new()
	turntable.name = "HeroTurntable"
	turntable.position = Vector3(0, 0.05, 0)
	turntable.rotation.y = -0.5
	hero_set.add_child(turntable)
	_cylinder(turntable, "ConcretePlinth", 3.25, 0.2, Vector3(0, 0.1, 0), plinth)
	_cylinder(turntable, "LimeTurntableRim", 3.27, 0.035, Vector3(0, 0.08, 0), _material(T.ACCENT_ACID_LIME, 0.8))
	car_slot = Node3D.new()
	car_slot.name = "CarSlot"
	car_slot.position.y = 0.2
	turntable.add_child(car_slot)
	for place: int in STATION_X.keys():
		_build_station(place)
	var sun := DirectionalLight3D.new()
	sun.name = "StudioKey"
	sun.rotation_degrees = Vector3(-38, -26, 0)
	sun.light_color = Color.WHITE
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	var spot := SpotLight3D.new()
	spot.name = "HeroSpot"
	spot.position = Vector3(0.0, 8.0, 1.0)
	spot.light_color = Color("#F2F6FF")
	spot.light_energy = 2.4
	spot.spot_range = 14.0
	spot.spot_angle = 24.0
	spot.light_volumetric_fog_energy = 1.5
	spot.shadow_enabled = true
	hero_set.add_child(spot)
	spot.look_at(Vector3(0, 0.6, 0))
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2, 3.2, -5)
	rim.light_color = Color("#55C9FF")
	rim.light_energy = 1.0
	rim.omni_range = 8.0
	rim.set_meta(&"no_shadow", true)
	hero_set.add_child(rim)
	camera = Camera3D.new()
	camera.name = "StudioCamera"
	camera.position = HERO_CAMERA_POS
	camera.fov = 38.0
	camera.current = true
	add_child(camera)
	camera.look_at(HERO_CAMERA_TARGET)
	_build_confetti()
	var sign := Label3D.new()
	sign.name = "StudioWordmark"
	sign.text = "LA VOITURE"
	sign.font = UI.DISPLAY
	sign.font_size = 160
	sign.pixel_size = 0.008
	sign.position = Vector3(0, 4.6, -8.8)
	sign.modulate = Color(0.33, 0.39, 0.48, 0.35)
	hero_set.add_child(sign)


## One head-on concrete wall with its own key light, far to the side of the hero set.
func _build_station(place: int) -> void:
	var station := Node3D.new()
	station.name = "WallStationP%d" % (place + 1)
	station.position = Vector3(float(STATION_X[place]), 0.0, 0.0)
	add_child(station)
	var concrete := _concrete()
	_box(station, "Wall", Vector3(9, 5.5, 0.3), Vector3(0, 2.5, -1.2), concrete)
	_box(station, "Floor", Vector3(9, 0.1, 7), Vector3(0, -0.05, 2.0), concrete)
	var key := SpotLight3D.new()
	key.name = "StationSpot"
	key.position = Vector3(1.6, 4.6, 4.2)
	key.light_color = MEDALS[place].lerp(Color.WHITE, 0.7)
	key.light_energy = 2.0
	key.spot_range = 14.0
	key.spot_angle = 34.0
	key.shadow_enabled = true
	station.add_child(key)
	key.look_at(station.position + Vector3(0, 1.0, 0))
	wall_stations[place] = station


func _build_confetti() -> void:
	confetti = GPUParticles3D.new()
	confetti.name = "GoldConfetti"
	confetti.position = Vector3(0, 6.0, -1)
	confetti.amount = 180
	confetti.lifetime = 6.0
	confetti.preprocess = 3.0
	confetti.visibility_aabb = AABB(Vector3(-8, -8, -5), Vector3(16, 10, 10))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(5, 0.15, 3)
	process.direction = Vector3.DOWN
	process.spread = 30
	process.initial_velocity_min = 0.35
	process.initial_velocity_max = 0.8
	process.gravity = Vector3(0.1, -0.55, 0)
	process.angular_velocity_min = -120.0
	process.angular_velocity_max = 120.0
	process.scale_min = 0.5
	process.scale_max = 1.2
	confetti.process_material = process
	var paper := QuadMesh.new()
	paper.size = Vector2(0.045, 0.09)
	var material := Toon.emissive(MEDALS[0], 0.3)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.material = material
	confetti.draw_pass_1 = paper
	add_child(confetti)


func _text(parent: Control, text: String, at: Vector2, size_px: int, color: Color = Color.WHITE, font: Font = UI.MONO) -> Label:
	var label: Label = UI.label(text, size_px, color, font)
	parent.add_child(label)
	label.position = at
	return label


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "VictoryHUD"
	add_child(canvas)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.size = STAGE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_stage)
	var speedlines := ColorRect.new()
	speedlines.name = "DetailSpeedlines"
	speedlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speedlines.size = STAGE
	var speedlines_mat := ShaderMaterial.new()
	speedlines_mat.shader = preload("res://shaders/manga_speedlines.gdshader")
	speedlines_mat.set_shader_parameter("line_color", Color(0.04, 0.04, 0.06, 0.75))
	speedlines_mat.set_shader_parameter("accent_a", T.ACCENT_ACID_LIME)
	speedlines_mat.set_shader_parameter("accent_b", Color("#00F0FF"))
	speedlines_mat.set_shader_parameter("accent_c", T.ACCENT_ANIME_CRIMSON)
	speedlines_mat.set_shader_parameter("accent_share", 0.3)
	speedlines_mat.set_shader_parameter("variation", 0.85)
	speedlines_mat.set_shader_parameter("inner", 0.16)
	speedlines_mat.set_shader_parameter("outer", 0.95)
	speedlines_mat.set_shader_parameter("center", Vector2(0.55, 0.52))
	speedlines_mat.set_shader_parameter("ray_count", 52.0)
	speedlines_mat.set_shader_parameter("reroll_rate", 12.0)
	speedlines.material = speedlines_mat
	speedlines.visible = false
	_stage.add_child(speedlines)
	_speedlines = speedlines
	_wall_layer = Control.new()
	_wall_layer.name = "WallCuts"
	_wall_layer.size = STAGE
	_wall_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_wall_layer)
	var parts: Dictionary = FinalHud.build(not Settings.reduce_motion)
	final_hud = parts.root
	headline = parts.headline
	_winner_label = parts.winner_label
	crown = parts.crown
	name_labels.assign(parts.name_labels)
	time_labels.assign(parts.time_labels)
	_stage.add_child(final_hud)
	var tape_top: Control = Kit.caution_tape(STAGE.x)
	tape_top.name = "TapeTop"
	_stage.add_child(tape_top)
	var tape_bottom: Control = Kit.caution_tape(STAGE.x)
	tape_bottom.name = "TapeBottom"
	tape_bottom.position.y = STAGE.y - 60.0
	_stage.add_child(tape_bottom)
	var banner: Label = Kit.plate("RACE COMPLETE // LA VOITURE CHAMPIONSHIP", T.ACCENT_ACID_LIME, 26)
	banner.position = Vector2(60.0, 10.0)
	_stage.add_child(banner)
	_cut_label = Kit.plate("", T.ACCENT_ANIME_CRIMSON, 26)
	_cut_label.position = Vector2(1500.0, 10.0)
	_stage.add_child(_cut_label)
	var actions := HBoxContainer.new()
	actions.position = Vector2(580, 1018)
	actions.add_theme_constant_override("separation", 16)
	_stage.add_child(actions)
	toggle_button = UI.button("[TAB] /// SHOW LEADERBOARD", MEDALS[0])
	restart_button = UI.button("[R] /// RESTART RACE", MEDALS[0])
	exit_button = UI.button("[ESC] /// EXIT TO HQ", MEDALS[0])
	for button: Button in [toggle_button, restart_button, exit_button]:
		button.custom_minimum_size = Vector2(0, 44)
		actions.add_child(button)
	toggle_button.pressed.connect(toggle_leaderboard)
	restart_button.pressed.connect(_restart)
	exit_button.pressed.connect(_exit_to_hq)
	leaderboard = Control.new()
	leaderboard.name = "TimingTower"
	leaderboard.size = Vector2(580, 850)
	leaderboard.position = Vector2(1940, 100)
	_stage.add_child(leaderboard)
	# A wheatpaste poster slapped on the wall, tilted a hair; the constructors block sits on an ink band.
	leaderboard.pivot_offset = leaderboard.size * 0.5
	leaderboard.rotation_degrees = 1.2
	var paper := Panel.new()
	paper.name = "Paper"
	paper.size = leaderboard.size
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sheet := StyleBoxFlat.new()
	sheet.bg_color = Kit.PAPER
	sheet.set_border_width_all(4)
	sheet.border_color = Kit.INK
	sheet.shadow_color = Color.BLACK
	sheet.shadow_size = 1
	sheet.shadow_offset = Vector2(12.0, 12.0)
	paper.add_theme_stylebox_override("panel", sheet)
	leaderboard.add_child(paper)
	var band := ColorRect.new()
	band.name = "InkBand"
	band.color = Kit.INK
	band.position = Vector2(4.0, 620.0)
	band.size = Vector2(leaderboard.size.x - 8.0, leaderboard.size.y - 624.0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leaderboard.add_child(band)
	_text(leaderboard, "/// CLASSIFICATION", Vector2(20, 16), 34, T.ACCENT_ANIME_CRIMSON, UI.HEADER)
	_text(leaderboard, "POS / DRIVER             GAP          PTS", Vector2(20, 65), 16, Color("#444444"))
	fastest_label = _text(leaderboard, "NO TIMED LAP", Vector2(20, 582), 16, INK_PURPLE)
	_text(leaderboard, "/// CONSTRUCTORS' HAUL", Vector2(20, 632), 25, T.ACCENT_ACID_LIME, UI.HEADER)
	leaderboard.hide()
	var flash_layer := CanvasLayer.new()
	flash_layer.name = "ImpactLayer"
	flash_layer.layer = 40
	add_child(flash_layer)
	_impact = ColorRect.new()
	_impact.name = "ImpactFrame"
	_impact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_impact.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var impact_material := ShaderMaterial.new()
	impact_material.shader = IMPACT_SHADER
	_impact.material = impact_material
	_impact.visible = false
	flash_layer.add_child(_impact)


func _gap(row: Dictionary, winner: Dictionary) -> String:
	if row.is_dnf:
		return "DNF"
	if float(row.time) < 0.0:
		return "RUNNING"
	var laps_down: int = int(winner.laps) - int(row.laps)
	if laps_down > 0:
		return "+%d LAP" % laps_down
	return format_time(float(row.time)) if int(row.id) == int(winner.id) else "+%.3fs" % maxf(0.0, float(row.time) - float(winner.time))


func _populate() -> void:
	for standee: Node3D in standees:
		standee.queue_free()
	standees.clear()
	for model: Node in car_slot.get_children():
		model.queue_free()
	_car_model = null
	if hero_callouts != null:
		hero_callouts.queue_free()
		hero_callouts = null
	for hud: Control in _wall_huds.values():
		hud.queue_free()
	_wall_huds.clear()
	for row: Label in timing_rows:
		row.queue_free()
	timing_rows.clear()
	for label: Label in team_labels:
		label.queue_free()
	team_labels.clear()
	if order.is_empty():
		headline.text = "RACE
COMPLETE"
		start_cuts()
		return
	var winner: Dictionary = order[0]
	var winner_color: Color = Liveries.color_for(int(winner.team_id))
	if confetti != null and confetti.draw_pass_1 != null:
		var confetti_mat := Toon.emissive(winner_color if winner_color != Color.WHITE else MEDALS[0], 0.35)
		confetti_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		(confetti.draw_pass_1 as QuadMesh).material = confetti_mat
	if toggle_button != null:
		for state: String in ["hover", "pressed", "focus"]:
			toggle_button.add_theme_stylebox_override(state, UI.style(T.SURFACE_SNAP_INVERT, winner_color))
	if restart_button != null:
		for state: String in ["hover", "pressed", "focus"]:
			restart_button.add_theme_stylebox_override(state, UI.style(T.SURFACE_SNAP_INVERT, T.ACCENT_ACID_LIME))
	if exit_button != null:
		for state: String in ["hover", "pressed", "focus"]:
			exit_button.add_theme_stylebox_override(state, UI.style(T.SURFACE_SNAP_INVERT, T.ACCENT_ANIME_CRIMSON))
	_winner_label.text = "#%02d %s  /  %s  /  %s" % [winner.number, String(winner.driver_name).to_upper(), winner.team_name, format_time(float(winner.time))]
	for place: int in range(mini(3, order.size())):
		var entry: Dictionary = order[place]
		var standee: Node3D = Standee.new()
		standee.name = "FinisherP%d" % (place + 1)
		standee.configure(load(standee_path(int(entry.id))) as Texture2D, Liveries.color_for(int(entry.team_id)), place == 0)
		standee.position = P1_STANDEE_POS if place == 0 else Vector3(float(STATION_X[place]), 0.0, 0.0)
		add_child(standee)
		standees.append(standee)
		var full_name: String = String(entry.driver_name).to_upper()
		name_labels[place].text = "#%02d %s\n%s" % [entry.number, full_name, entry.team_name]
		if place == 0 and full_name.length() > 16:
			name_labels[0].add_theme_font_size_override("font_size", 34)
		elif place > 0 and full_name.length() > 16:
			name_labels[place].add_theme_font_size_override("font_size", 24)
		time_labels[place].text = "%s   //   %d PTS" % [_gap(entry, winner), entry.points]
	for place: int in [1, 2]:
		if place < mini(3, order.size()):
			var finisher: Dictionary = order[place]
			var hud: Control = WallCut.build(place, finisher, _gap(finisher, winner), not Settings.reduce_motion)
			hud.visible = false
			_wall_layer.add_child(hud)
			_wall_huds[place] = hud
	var slug: String = results.get("winner_car", "")
	if slug in Roster.CAR_SLUGS:
		var car_scene := load("res://assets/cars/%s/%s_full.glb" % [slug, slug]) as PackedScene
		var model: Node3D = car_scene.instantiate()
		_apply_hero_toon(model, slug)
		car_slot.add_child(model)
		_light_hero_car(model)
		_car_model = model
		_car_box = _car_bounds(model)
		var team: int = Roster.CAR_SLUGS.find(slug)
		headline.text = "%s\nTAKES IT" % Roster.CAR_NAMES[team].split(" ")[0].to_upper()
		hero_callouts = Callouts.build(Roster.CAR_NAMES[team], Roster.CAR_ENGINES[team])
		_stage.add_child(hero_callouts)
	for i: int in range(order.size()):
		var entry: Dictionary = order[i]
		var fastest: Dictionary = results.get("fastest_lap", {})
		var best: bool = int(fastest.get("id", -1)) == int(entry.id)
		var suffix: String = " +1 PT" if best and int(fastest.get("bonus", 0)) == 1 else (" FL" if best else "")
		var text: String = "%02d %-3s %-12s %10s %2d%s" % [i + 1, entry.code, entry.driver_name, _gap(entry, winner), entry.points, suffix]
		timing_rows.append(_text(leaderboard, text, Vector2(20, 98 + i * 23), 16, INK_PURPLE if best else Kit.INK))
	var fastest: Dictionary = results.get("fastest_lap", {})
	if not fastest.is_empty():
		fastest_label.text = "FL %s / %s / %s" % [fastest.code, format_time(float(fastest.time)), "+1 PT BONUS" if int(fastest.bonus) == 1 else "NO BONUS"]
	var team_points: Dictionary = results.get("team_points", {})
	var competing_teams: Array = team_points.keys()
	competing_teams.sort()
	if competing_teams.is_empty():
		for t: int in range(mini(10, GtData.TEAM_NAMES.size())):
			competing_teams.append(t)
	for i: int in range(competing_teams.size()):
		var team: int = int(competing_teams[i])
		team_labels.append(_text(leaderboard, "%s  %d" % [GtData.TEAM_NAMES[team], int(team_points.get(team, 0))],
			Vector2(20 + (i % 2) * 280, 679 + (i / 2) * 28), 16, Liveries.color_for(team)))
	start_cuts()


func _apply_hero_toon(model: Node3D, slug: String) -> void:
	# Full GLBs bypass the chassis scene's material overrides; restore its canonical livery.
	var paint := load("res://materials/%s_toon_body.tres" % slug) as Material
	var carbon := preload("res://materials/toon_carbon_aero.tres")
	var wheel_materials: Dictionary = {}
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var source := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null:
				continue
			if source.resource_name.ends_with("_Paint"):
				instance.set_surface_override_material(surface, paint)
			elif source.resource_name == "FenderLinerMat":
				instance.set_surface_override_material(surface, carbon)
			else:
				if not wheel_materials.has(source):
					var cel := Toon.make(source.albedo_color).duplicate() as ShaderMaterial
					cel.set_shader_parameter("albedo_texture", source.albedo_texture)
					var outline := ShaderMaterial.new()
					outline.shader = Toon.OutlineShader
					outline.set_shader_parameter("outline_width", 0.006)
					cel.next_pass = outline
					wheel_materials[source] = cel
				instance.set_surface_override_material(surface, wheel_materials[source])


## Stage (1920x1080 HUD) position of a world point, through the live camera and the letterboxed stage.
func _stage_point(world: Vector3) -> Vector2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var factor: float = minf(view.x / STAGE.x, view.y / STAGE.y)
	return (camera.unproject_position(world) - (view - STAGE * factor) * 0.5) / factor


## Bounds of every mesh in `model`, expressed in the model's own space.
func _car_bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first: bool = true
	for instance: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := instance as MeshInstance3D
		var local: Transform3D = model.global_transform.affine_inverse() * mesh.global_transform
		var box: AABB = local * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _light_hero_car(model: Node3D) -> void:
	# Same body-bound lamp placement convention as GtCarActor, evaluated once per winner.
	var bounds: AABB = _car_bounds(model)
	for side: float in [-1.0, 1.0]:
		var head := SpotLight3D.new()
		head.name = "StudioHeadlight"
		head.position = Vector3(side * bounds.size.x * 0.24, bounds.position.y + bounds.size.y * 0.3, bounds.end.z - 0.05)
		head.rotation.y = PI
		head.light_color = Color("#D7EEFF")
		head.light_energy = 3.0
		head.spot_range = 7.0
		head.spot_angle = 24.0
		head.set_meta(&"no_shadow", true)
		model.add_child(head)
		var tail := OmniLight3D.new()
		tail.name = "StudioTaillight"
		tail.position = Vector3(side * bounds.size.x * 0.24, bounds.position.y + bounds.size.y * 0.42, bounds.position.z)
		tail.light_color = Color("#FF2244")
		tail.light_energy = 1.0
		tail.omni_range = 1.5
		tail.set_meta(&"no_shadow", true)
		model.add_child(tail)
