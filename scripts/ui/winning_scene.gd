class_name WinningScene
extends Node3D

## Dedicated, simulation-independent finale. Only value snapshots survive race teardown.
## The screen is a 2D triptych (WinningTriptych): P2 | P1 | P3 panels, each with the finisher's standee, a baked
## sprite of their car and a manga character card. WinningCutDirector runs five one-bar cuts over it: the panels
## come in, the focus visits P3, P2 and P1 in turn, then every panel settles at equal width. The root stays a
## Node3D so the race world's hand-off and the tests can keep treating it as the finale scene.
signal restart_requested
signal exit_requested

const UI := preload("res://scripts/ui/pit_wall_ui.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const Roster := preload("res://scripts/ui/garage_roster.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const Kit := preload("res://scripts/ui/graffiti_kit.gd")
const INK_PURPLE := Color("#7A2BC9")
const Config := preload("res://scripts/core/race_config_data.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
const POINTS: Array[int] = [25, 18, 15, 12, 10, 8, 6, 4, 2, 1]
const MEDALS: Array[Color] = [Color("#FFD23F"), Color("#D8DCE6"), Color("#D9803A")]
const STAGE := Vector2(1920, 1080)
## Visible width the panels share while the timing tower (x = 1280) is open.
const NARROW_WIDTH: float = 1215.0
const PATH := "res://scenes/ui/winning_scene.tscn"

## Single-use handoff: copied into the new scene then cleared immediately.
static var pending_results: Dictionary = {}
static var pending_frame: ImageTexture
var results: Dictionary = {}
var order: Array = []
var triptych: WinningTriptych
## The finishers' standees (P1, P2, P3), owned by the triptych's panels.
var standees: Array[TextureRect] = []
var name_labels: Array[Label] = []
var time_labels: Array[Label] = []
var timing_rows: Array[Label] = []
var team_labels: Array[Label] = []
var leaderboard: Control
var toggle_button: Button
var restart_button: Button
var exit_button: Button
var fastest_label: Label
var is_leaderboard_open: bool = false
var director: WinningCutDirector
var _stage: Control
var _slide: Tween
var _cut: int = WinningCutDirector.Cut.FINAL
var _cut_label: Label
var _leaving: bool = false
var _built: bool = false
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


## `pose` is "" for the idle standee and "win" for the victory pose (assets/characters/standees/<driver>_win.png).
static func standee_path(slot: int, pose: String = "") -> String:
	var slug: String = Roster.DRIVER_SLUGS[slot].replace("-", "_")
	if slug == "arthur_sterling_jr":
		slug = "arthur_sterling"
	return "res://assets/characters/standees/%s%s.png" % [slug, "" if pose.is_empty() else "_" + pose]


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
	_build_ui()
	_built = true
	_populate()
	get_viewport().size_changed.connect(_fit)
	_fit()
	Settings.apply_to_tree(self)
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


func _input(event: InputEvent) -> void:
	# TAB must not be consumed by Control focus traversal before reaching this screen.
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _leaving:
		return
	var skipping: bool = not director.is_final() and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE)
	var arrow: bool = director.is_final() and (key.keycode == KEY_LEFT or key.keycode == KEY_RIGHT)
	if not skipping and not arrow and key.keycode != KEY_TAB and key.keycode != KEY_R and key.keycode != KEY_ESCAPE:
		return
	# A successful scene change immediately detaches this node and its viewport.
	get_viewport().set_input_as_handled()
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			skip_cuts()
		KEY_LEFT:
			focus_step(-1)
		KEY_RIGHT:
			focus_step(1)
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


## Jumps to the final composition.
func skip_cuts() -> void:
	director.skip_to_final()


## Moves the spotlight between the panels (equal, P2, P1, P3, equal ...); only once the cuts are over.
func focus_step(step: int) -> void:
	if director.is_final():
		triptych.cycle_focus(step)


## Before the final a click on a panel skips like a click on empty stage; after it, it focuses that panel.
func _on_panel_pressed(place: int) -> void:
	if _leaving:
		return
	if not director.is_final():
		skip_cuts()
	else:
		triptych.set_focus(-1 if triptych.focus_place == place else place)


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
	triptych.set_available_width(NARROW_WIDTH if is_leaderboard_open else STAGE.x)
	if not is_leaderboard_open:
		_slide.tween_callback(leaderboard.hide)


## Builds the cut timeline for the current results and plays it (or lands on the final when motion is reduced).
func start_cuts() -> void:
	director = WinningCutDirector.new(WinningCutDirector.playlist_for(mini(order.size(), 3)))
	director.cut_changed.connect(_show_cut)
	director.start(Settings.reduce_motion)


func current_cut() -> int:
	return _cut


func _show_cut(cut: int) -> void:
	_cut = cut
	match cut:
		WinningCutDirector.Cut.INTRO:
			triptych.play_intro()
		WinningCutDirector.Cut.FOCUS_P3:
			triptych.set_focus(2)
			_celebrate(2, true)
		WinningCutDirector.Cut.FOCUS_P2:
			triptych.set_focus(1)
			_celebrate(1, true)
		WinningCutDirector.Cut.FOCUS_P1:
			triptych.set_focus(0)
			_celebrate(0, true)
		_:
			triptych.set_focus(-1)
			for place: int in range(triptych.panels.size()):
				_celebrate(place, false)
	_cut_label.text = director.label()


## The focused finisher strikes the victory pose on the cut and keeps it; a skip to the final lands everyone in it.
func _celebrate(place: int, animate: bool) -> void:
	if place < triptych.panels.size():
		triptych.panels[place].set_celebrating(true, animate and not Settings.reduce_motion)


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
	# Concrete-grey wall behind the panels: a flat tone with the halftone screentone over it.
	var wall := ColorRect.new()
	wall.name = "Wall"
	wall.color = Color("#23252D")
	wall.size = STAGE
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(wall)
	var halftone := ColorRect.new()
	halftone.name = "WallHalftone"
	halftone.size = STAGE
	halftone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dots := ShaderMaterial.new()
	dots.shader = UI.DOTS
	dots.set_shader_parameter("dot_color", Color(0.0, 0.0, 0.0, 0.35))
	dots.set_shader_parameter("dot_spacing", 12.0)
	halftone.material = dots
	_stage.add_child(halftone)
	triptych = WinningTriptych.new()
	triptych.name = "Triptych"
	triptych.panel_pressed.connect(_on_panel_pressed)
	_stage.add_child(triptych)
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


func _gap(row: Dictionary, winner: Dictionary) -> String:
	if row.is_dnf:
		return "DNF"
	if float(row.time) < 0.0:
		return "RUNNING"
	var laps_down: int = int(winner.laps) - int(row.laps)
	if laps_down > 0:
		return "+%d LAP" % laps_down
	return format_time(float(row.time)) if int(row.id) == int(winner.id) else "+%.3fs" % maxf(0.0, float(row.time) - float(winner.time))


func _optional_texture(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## The three images one panel draws, loaded now rather than while the first cut plays.
func _panel_textures(entry: Dictionary) -> Dictionary:
	return {
		"standee": _optional_texture(standee_path(int(entry.id))),
		"standee_win": _optional_texture(standee_path(int(entry.id), "win")),
		"car": _optional_texture(Roster.podium_sprite_path(int(entry.team_id))),
		"portrait": _optional_texture(Roster.portrait_path(int(entry.id))),
	}


func _populate() -> void:
	standees.clear()
	name_labels.clear()
	time_labels.clear()
	for row: Label in timing_rows:
		row.queue_free()
	timing_rows.clear()
	for label: Label in team_labels:
		label.queue_free()
	team_labels.clear()
	var entries: Array = []
	var gaps: Array[String] = []
	var textures: Array[Dictionary] = []
	var bonus_ids: Array[int] = []
	var fastest: Dictionary = results.get("fastest_lap", {})
	if not order.is_empty():
		var winner: Dictionary = order[0]
		var winner_color: Color = Liveries.color_for(int(winner.team_id))
		for state: String in ["hover", "pressed", "focus"]:
			toggle_button.add_theme_stylebox_override(state, UI.style(T.SURFACE_SNAP_INVERT, winner_color))
			restart_button.add_theme_stylebox_override(state, UI.style(T.SURFACE_SNAP_INVERT, T.ACCENT_ACID_LIME))
			exit_button.add_theme_stylebox_override(state, UI.style(T.SURFACE_SNAP_INVERT, T.ACCENT_ANIME_CRIMSON))
		for place: int in range(mini(3, order.size())):
			var entry: Dictionary = order[place]
			entries.append(entry)
			gaps.append(_gap(entry, winner))
			textures.append(_panel_textures(entry))
		if int(fastest.get("bonus", 0)) == 1:
			bonus_ids.append(int(fastest.id))
	triptych.reduce_motion = Settings.reduce_motion
	triptych.setup(entries, gaps, bonus_ids, textures, not Settings.reduce_motion)
	for panel: WinningPanel in triptych.panels:
		standees.append(panel.standee)
	name_labels.assign(triptych.name_labels)
	time_labels.assign(triptych.time_labels)
	if order.is_empty():
		start_cuts()
		return
	var winner_row: Dictionary = order[0]
	for i: int in range(order.size()):
		var entry: Dictionary = order[i]
		var best: bool = int(fastest.get("id", -1)) == int(entry.id)
		var suffix: String = " +1 PT" if best and int(fastest.get("bonus", 0)) == 1 else (" FL" if best else "")
		var text: String = "%02d %-3s %-12s %10s %2d%s" % [i + 1, entry.code, entry.driver_name, _gap(entry, winner_row), entry.points, suffix]
		timing_rows.append(_text(leaderboard, text, Vector2(20, 98 + i * 23), 16, INK_PURPLE if best else Kit.INK))
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
