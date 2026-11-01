extends SceneTree

## Run: godot --headless --path . -s res://tests/test_winning_scene_and_standee.gd
## The winning screen: results snapshot, the triptych populated from it, the five-cut timeline, input, the timing
## tower making room, and the scene lifecycle (restart, exit, no orphans).
const SCENE := "res://scenes/ui/winning_scene.tscn"
const TrackScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const Track := preload("res://scripts/gt/gt_track.gd")
const Race := preload("res://scripts/gt/gt_race.gd")
const Roster := preload("res://scripts/ui/garage_roster.gd")
const Cut := WinningCutDirector.Cut
var failures: int = 0
var assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])


func _run() -> void:
	var settings: Script = load("res://scripts/core/presentation_settings.gd")
	settings.reduce_motion = false
	if not ResourceLoader.exists(SCENE):
		check(false, "Dedicated winning studio can be loaded")
		quit(1)
		return
	var studio_script: Script = load("res://scripts/ui/winning_scene.gd")
	var ribbon: Node3D = TrackScene.instantiate()
	root.add_child(ribbon)
	var race: GtRace = Race.new(Track.new(ribbon, 14.0), 3, 1, 0)
	for i: int in range(race.cars.size()):
		var car: GtCar = race.get_car(i)
		car.finished_at = 300.0 + float(i) * 2.0
		car.s = race.track.length * 3.0
		car.best_lap = 90.0 + float(i)
	race.get_car(0).penalty_owed_s = 5.0
	race.get_car(19).is_dnf = true
	race.get_car(19).best_lap = 80.0
	var results: Dictionary = studio_script.capture_results(race)
	check(results.order[0].id == 1 and results.order[2].id == 0 and results.order[2].time == 305.0,
		"Snapshot uses classified order and includes unserved finish penalties")
	check(results.order[19].points == 0 and results.fastest_lap.bonus == 0,
		"Retirement outside top ten earns no fastest lap bonus")
	race.get_car(19).best_lap = 100.0
	race.get_car(2).best_lap = 81.0
	results = studio_script.capture_results(race)
	check(results.order[1].points == 19 and results.team_points[1] == 31,
		"Fastest eligible finisher earns exactly one bonus and constructor sum includes both drivers")
	var original_name: String = results.order[0].driver_name
	race.get_car(1).driver_name = "CHANGED AFTER SNAPSHOT"
	check(results.order[0].driver_name == original_name, "Results snapshot owns values, not mutable simulation objects")
	race.dispose()
	race = null
	ribbon.queue_free()
	await process_frame
	for slot: int in range(20):
		var path: String = studio_script.standee_path(slot)
		var image: Image = (load(path) as Texture2D).get_image()
		check(image != null and image.get_format() == Image.FORMAT_RGBA8 and image.detect_alpha() != Image.ALPHA_NONE,
			"Driver %02d has a genuine transparent RGBA cutout" % slot)

	var studio: Node3D = load(SCENE).instantiate()
	studio.setup_celebration(results)
	root.add_child(studio)
	await process_frame
	check(studio.triptych.panels.size() == 3 and studio.standees.size() == 3 and studio.order.size() == 20,
		"Three finishers populate the triptych from the twenty-car snapshot")
	for place: int in range(3):
		var entry: Dictionary = results.order[place]
		var panel: WinningPanel = studio.triptych.panels[place]
		var standee: TextureRect = studio.standees[place]
		check(standee == panel.standee and standee.texture.resource_path == studio_script.standee_path(int(entry.id))
			and float(standee.material.get_shader_parameter("outline_px")) > 0.0,
			"P%d standee shows its own driver with the die-cut outline" % (place + 1))
		check(panel.car.texture.resource_path == Roster.podium_sprite_path(int(entry.team_id)),
			"P%d car is the finisher's own team sprite" % (place + 1))
		check(panel.bubble.texture.resource_path == Roster.portrait_path(int(entry.id)),
			"P%d bubble carries the driver portrait" % (place + 1))
		check(panel.standee.texture != null and panel.car.texture != null and panel.bubble.texture != null,
			"P%d has every texture loaded before the first cut" % (place + 1))
		check(studio.name_labels[place].text.contains(String(entry.driver_name).to_upper()) and studio.name_labels[place].text.contains("#%02d" % int(entry.number)),
			"P%d tag names the real finisher and number" % (place + 1))
	check(studio.time_labels[2].text.contains("+3.000s") and studio.time_labels[2].text.contains("15 PTS"), "The P3 plate carries gap and points")
	check(studio.find_children("*", "MeshInstance3D", true, false).is_empty() and studio.find_children("*", "Camera3D", true, false).is_empty()
		and studio.get_node_or_null("HeroSet") == null, "The scene holds no 3D car, set or camera")
	check(AudioManager.of(studio).music_track == &"podium", "The winning scene plays the podium anthem")

	await _test_cuts(studio)
	var closing: WeakRef = weakref(studio)
	studio.queue_free()
	await process_frame
	await process_frame
	check(closing.get_ref() == null, "Closing the studio releases its entire owned tree")
	await _test_edge_cases(results)
	await _test_input_and_motion(results, settings)
	await _test_tower_and_focus(results)
	await _test_lifecycle(results)
	print("WINNING SCENE: %d assertions, %d FAIL" % [assertions, failures])
	quit(0 if failures == 0 else 1)


## One bar per cut: intro, then P3, P2, P1 take the focus, then the panels settle equal.
func _test_cuts(studio: Node3D) -> void:
	var tri: WinningTriptych = studio.triptych
	check(studio.director.current_cut == Cut.INTRO and tri.focus_place == -1 and tri.panels[0].detail_amount == 0.0,
		"The finale opens on the intro: equal panels, no details")
	studio.director.tick(1.65)
	check(studio.director.current_cut == Cut.FOCUS_P3 and tri.focus_place == 2, "The second cut focuses P3")
	studio.director.tick(1.65)
	check(studio.director.current_cut == Cut.FOCUS_P2 and tri.focus_place == 1, "The third cut focuses P2")
	studio.director.tick(1.65)
	check(studio.director.current_cut == Cut.FOCUS_P1 and tri.focus_place == 0, "The fourth cut focuses P1")
	studio.director.tick(1.65)
	await create_timer(1.0).timeout
	check(studio.director.is_final() and tri.focus_place == -1 and tri.panels[2].detail_amount == 1.0
		and absf(tri.panels[0].size.x - tri.panels[2].size.x) < 1.0, "The final settles the panels equal with every detail shown")
	check(studio.current_cut() == Cut.FINAL, "current_cut() follows the director")


func _spawn(snapshot: Dictionary) -> Node3D:
	var node: Node3D = load(SCENE).instantiate()
	node.setup_celebration(snapshot)
	root.add_child(node)
	await process_frame
	return node


## Retired finisher, fewer than three finishers, nobody, and a name too long for its tag.
func _test_edge_cases(results: Dictionary) -> void:
	var dnf: Dictionary = results.duplicate(true)
	dnf.order[2].is_dnf = true
	dnf.order[2].points = 0
	var other: Node3D = await _spawn(dnf)
	check(other.time_labels[2].text.contains("DNF") and other.time_labels[2].text.contains("0 PTS") and not other.time_labels[2].text.contains("+"),
		"A retired P3 shows DNF and 0 PTS")
	other.queue_free()
	var two: Dictionary = results.duplicate(true)
	two.order = results.order.slice(0, 2)
	other = await _spawn(two)
	other.director.tick(1.65)
	check(other.triptych.panels.size() == 2 and other.director.current_cut == Cut.FOCUS_P2, "With two finishers the P3 focus is skipped")
	other.queue_free()
	var none: Dictionary = results.duplicate(true)
	none.order = []
	none.winner_car = ""
	other = await _spawn(none)
	check(other.director.is_final() and other.triptych.panels.is_empty() and other.standees.is_empty(),
		"With no finishers the studio goes straight to the final without panels or a crash")
	other.queue_free()
	var long_name: Dictionary = results.duplicate(true)
	long_name.order[1].driver_name = "MAXIMILIAN-ALEXANDER FEATHERSTONEHAUGH"
	other = await _spawn(long_name)
	check(other.triptych.panels[1].name_label.size.x <= WinningPanel.NAME_MAX_WIDTH, "A very long driver name still fits its tag")
	other.queue_free()
	await process_frame


## Skip keys, a click on a panel or on empty stage, TAB mid-cut, the arrow keys, and reduce_motion landing on the final.
func _test_input_and_motion(results: Dictionary, settings: Script) -> void:
	var studio: Node3D = await _spawn(results)
	check(not studio.director.is_final(), "A fresh finale plays its cuts")
	_key(KEY_RIGHT)
	await process_frame
	check(not studio.director.is_final() and studio.triptych.focus_place == -1, "Arrow keys do nothing before the final")
	_key(KEY_ENTER)
	await process_frame
	check(studio.director.is_final() and studio.triptych.focus_place == -1, "Enter skips to the final")
	studio.queue_free()

	studio = await _spawn(results)
	_key(KEY_SPACE)
	await process_frame
	check(studio.director.is_final(), "Space skips to the final")
	studio.queue_free()

	studio = await _spawn(results)
	_click_stage(studio, Vector2(20.0, 20.0))
	await process_frame
	check(studio.director.is_final(), "A click on empty stage skips to the final")
	studio.queue_free()

	studio = await _spawn(results)
	_click_stage(studio, Vector2(960.0, 540.0))
	await process_frame
	check(studio.director.is_final() and studio.triptych.focus_place == -1, "A real click on a panel before the final skips instead of focusing")
	await create_timer(1.2).timeout # the intro keeps sliding the panels in after a skip
	_click_stage(studio, Vector2(960.0, 540.0))
	await process_frame
	check(studio.triptych.focus_place == 0, "A real click on the P1 panel after the final focuses P1")
	studio.queue_free()

	studio = await _spawn(results)
	studio.triptych.panels[1].background.gui_input.emit(_press())
	await process_frame
	check(studio.director.is_final() and studio.triptych.focus_place == -1, "A click on a panel before the final skips instead of focusing")
	studio.queue_free()

	studio = await _spawn(results)
	var finals: Array[int] = []
	studio.director.cut_changed.connect(func(cut: int) -> void:
		if cut == Cut.FINAL:
			finals.append(cut))
	for i: int in range(10):
		_key(KEY_ENTER)
	await process_frame
	check(finals.size() == 1, "Mashing skip announces the final exactly once")
	studio.queue_free()

	studio = await _spawn(results)
	_key(KEY_TAB)
	await create_timer(0.4).timeout
	check(studio.director.is_final() and studio.is_leaderboard_open, "TAB mid-cut skips to the final and opens the tower")
	studio.queue_free()

	studio = await _spawn(results)
	studio.skip_cuts()
	var walk: Array[int] = []
	for i: int in range(4):
		_key(KEY_RIGHT)
		await process_frame
		walk.append(studio.triptych.focus_place)
	check(walk == ([1, 0, 2, -1] as Array[int]), "Right arrow after the final focuses P2, P1, P3, then equal (%s)" % str(walk))
	_key(KEY_LEFT)
	await process_frame
	check(studio.triptych.focus_place == 2, "Left arrow walks the cycle backwards")
	studio.triptych.set_focus(-1, true)
	studio.triptych.panels[1].background.gui_input.emit(_press())
	check(studio.triptych.focus_place == 1, "Clicking a panel after the final focuses it")
	studio.triptych.panels[1].background.gui_input.emit(_press())
	check(studio.triptych.focus_place == -1, "Clicking the focused panel returns to equal")
	studio.queue_free()
	await process_frame

	var normal: Node3D = await _spawn(results)
	var with_motion: int = get_processed_tweens().size()
	normal.queue_free()
	await process_frame
	await process_frame
	settings.reduce_motion = true
	var calm: Node3D = await _spawn(results)
	check(calm.director.is_final(), "Reduce motion lands on the final")
	check(get_processed_tweens().size() < with_motion and calm.triptych.panels[0].standee.scale == Vector2.ONE,
		"Reduce motion starts no drip or breathing tweens")
	_key(KEY_RIGHT)
	await process_frame
	check(is_equal_approx(calm.triptych.panels[1].size.x, calm.triptych.panels[1].size.x) and calm.triptych.focus_place == 1
		and is_equal_approx(calm.triptych.panels[1].size.x / calm.triptych.panels[0].size.x, WinningTriptych.FOCUS_WEIGHT),
		"Reduce motion applies a focus change at once")
	settings.reduce_motion = false
	calm.queue_free()
	await process_frame


func _outer(control: Control) -> Rect2:
	return control.get_global_transform() * Rect2(Vector2.ZERO, control.size)


## The tower slides in over the right edge; the triptych narrows so no panel, tag or plate sits under it.
func _test_tower_and_focus(results: Dictionary) -> void:
	var studio: Node3D = await _spawn(results)
	studio.skip_cuts()
	_key(KEY_TAB)
	await create_timer(0.5).timeout
	check(studio.is_leaderboard_open and is_equal_approx(studio.leaderboard.position.x, 1280.0), "TAB opens the timing panel even with button focus")
	var tower: Rect2 = _outer(studio.leaderboard)
	var clear: bool = true
	for place: int in range(3):
		clear = clear and not _outer(studio.triptych.panels[place]).intersects(tower)
		clear = clear and not _outer(studio.name_labels[place]).intersects(tower) and not _outer(studio.time_labels[place]).intersects(tower)
	check(clear, "With the timing tower open no panel, tag or plate sits under it")
	check(is_equal_approx(studio.leaderboard.rotation_degrees, 1.2), "The tower slides in as a slightly tilted poster")
	check(studio.timing_rows[0].get_theme_color("font_color").get_luminance() < 0.2, "Timing rows are inked dark so they read on the paper poster")
	studio.toggle_leaderboard()
	studio.toggle_leaderboard()
	studio.toggle_leaderboard()
	await create_timer(0.5).timeout
	check(not studio.is_leaderboard_open and not studio.leaderboard.visible, "Rapid TAB reversals end fully closed without a stale tween")
	check(_outer(studio.triptych.panels[2]).end.x > 1900.0 * studio._stage.scale.x, "Closing the tower gives the triptych its full width back")
	studio.toggle_leaderboard()
	await create_timer(0.5).timeout
	check(studio.timing_rows.size() == 20 and studio.team_labels.size() == 10,
		"Expanded timing contains all twenty finishers and all ten constructors")
	check(studio.timing_rows[1].text.contains("+1 PT") and studio.timing_rows[19].text.contains("DNF"),
		"Timing distinguishes the awarded fastest lap bonus from a retired result")
	studio.toggle_leaderboard()
	await create_timer(0.5).timeout
	studio.triptych.set_focus(2)
	studio.toggle_leaderboard()
	await create_timer(1.2).timeout
	check(studio.triptych.focus_place == 2 and not _outer(studio.triptych.panels[2]).intersects(_outer(studio.leaderboard)),
		"Opening the tower while a focus tween runs still ends clear of it")
	studio.queue_free()
	await process_frame


func _test_lifecycle(results: Dictionary) -> void:
	# Exercise restart through the real manga transition and configured grid.
	var studio: Node3D = load(SCENE).instantiate()
	studio.setup_celebration(results)
	root.add_child(studio)
	current_scene = studio
	var studio_ref: WeakRef = weakref(studio)
	var config_script: Script = load("res://scripts/core/race_config_data.gd")
	var config: RefCounted = config_script.reset()
	config.total_laps = 3
	config.selected_team_id = 8
	config.race_seed = 1234
	# The race world's preload graph is cyclic (car actor, chassis scenes, HUD scenes). Entering it first
	# from the transition's loader thread intermittently fails to compile; compile it on the main thread.
	load("res://scenes/race_weekend_world.tscn")
	_key(KEY_R)
	await scene_changed
	check(studio_ref.get_ref() == null and config_script.current.race_seed == 1234,
		"Restart frees the old studio without changing the configured seed")
	check(AudioManager.of(root).music_track == &"menu", "Restart hands the music back to the menu loop so the anthem cannot leak into the race")
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 30000:
		await process_frame
		if current_scene != null and current_scene.name == "RaceWeekendWorld" and not current_scene.pre_grid_hold:
			break
	var restarted: Node = current_scene
	check(restarted != null and restarted.name == "RaceWeekendWorld"
		and restarted.race.laps == 3 and restarted.race.player_team_id == 8,
		"Restart reaches the selected team's real three-lap grid")
	if restarted == null or restarted.name != "RaceWeekendWorld":
		quit(1)
		return
	var world_ref: WeakRef = weakref(restarted)
	restarted.show_podium()
	await scene_changed
	check(world_ref.get_ref() == null and current_scene.scene_file_path == SCENE,
		"Race-to-studio handoff releases the race and consumes its snapshot")
	studio = current_scene
	studio_ref = weakref(studio)
	_key(KEY_ESCAPE)
	await scene_changed
	await process_frame
	check(studio_ref.get_ref() == null and current_scene.scene_file_path == "res://scenes/main.tscn",
		"EXIT TO HQ frees the studio and reaches the real main scene")
	check(AudioManager.of(root).music_track == &"menu", "EXIT TO HQ returns to the menu music")
	current_scene.queue_free()
	await process_frame
	# A directly launched race has no menu draft; restarting must still replay that race.
	config_script.current = null
	var standalone: Node3D = load("res://scenes/race_weekend_world.tscn").instantiate()
	standalone.total_laps = 7
	standalone.race_seed = 7331
	standalone.director_seed = 19
	root.add_child(standalone)
	current_scene = standalone
	standalone.set_process(false)
	standalone.show_podium()
	await scene_changed
	_key(KEY_R)
	await scene_changed
	check(current_scene.name == "RaceWeekendWorld" and current_scene.total_laps == 7
		and current_scene.race_seed == 7331 and current_scene.director_seed == 19
		and config_script.current == null,
		"Standalone restart retains laps, simulation seed and start-light seed without inventing a menu draft")
	current_scene.show_podium()
	await scene_changed
	_key(KEY_ESCAPE)
	await scene_changed
	current_scene.queue_free()
	for i: int in range(5):
		await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Exit leaves zero orphan nodes")
	load("res://scripts/world/shared/toon_materials.gd")._cache.clear()
	load("res://scripts/car/gt_car_actor.gd")._paint_cache.clear()


func _press() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(300.0, 500.0)
	return click


## A left click on a point of the 1920x1080 stage, pushed through the real GUI picking (canvas coordinates).
func _click_stage(studio: Node3D, stage_point: Vector2) -> void:
	var click: InputEventMouseButton = _press()
	click.position = studio._stage.get_global_transform() * stage_point
	root.push_input(click, true)
	var release: InputEventMouseButton = click.duplicate()
	release.pressed = false
	root.push_input(release, true)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
