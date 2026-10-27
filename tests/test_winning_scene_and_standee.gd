extends SceneTree

## Run: godot --headless --path . -s res://tests/test_winning_scene_and_standee.gd
const SCENE := "res://scenes/ui/winning_scene.tscn"
const TrackScene := preload("res://scenes/race_world/track_circuit.tscn")
const Track := preload("res://scripts/gt/gt_track.gd")
const Race := preload("res://scripts/gt/gt_race.gd")
const Roster := preload("res://scripts/ui/garage_roster.gd")
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
	check(studio.standees.size() == 3 and studio.order.size() == 20, "Three finishers populate the studio from the twenty-car snapshot")
	for place: int in range(3):
		var standee: Node3D = studio.standees[place]
		check(standee.mesh_instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and is_equal_approx(standee.position.y, 0.0),
			"P%d silhouette casts real shadows with feet on the stage floor" % (place + 1))
		check(standee.material.get_shader_parameter("albedo_texture").resource_path == studio_script.standee_path(int(results.order[place].id)),
			"P%d displays its own driver's art, not another winner's cutout" % (place + 1))
		check(float(standee.material.get_shader_parameter("outline_width")) > 0.0,
			"P%d standee wears the white die-cut sticker outline" % (place + 1))
	await create_timer(0.7).timeout
	var breathing_quad: MeshInstance3D = studio.standees[0].mesh_instance
	var sole: Vector3 = breathing_quad.transform * Vector3(0, -0.925, 0)
	check(breathing_quad.scale.y > 1.001 and absf(sole.y) < 0.00001,
		"Breathing grows the torso while the soles remain anchored to the podium")
	await _test_cuts(studio_script, results, studio)
	await _test_hero_cuts(results)
	await _test_final_hud(results, studio)
	await _test_input_and_motion(results, settings)
	check(studio.car_slot.get_child(0).scene_file_path == Roster.car_path(0), "P1 turntable loads the actual winner team's full GLB")
	var before: float = studio.turntable.rotation.y
	studio._process(1.0)
	check(is_equal_approx(studio.turntable.rotation.y - before, 0.18), "Hero car turntable rotates at 0.18 rad/s")
	var camera_before: Vector3 = studio.camera.position
	studio._process(1.0)
	check(not studio.camera.position.is_equal_approx(camera_before), "Clean photo mode advances the slow orbit dolly")
	check(studio.get_node_or_null("HeroSet") != null and studio.wall_stations.size() == 2
		and studio.get_node_or_null("PodiumP1") == null and studio.find_child("ChampionshipTrophy", true, false) == null,
		"The classic podium and trophy are gone; a hero set and two wall stations replace them")
	check(is_equal_approx(absf(studio.standees[1].position.x), 30.0) and is_equal_approx(absf(studio.standees[2].position.x), 30.0)
		and studio.standees[1].position.x * studio.standees[2].position.x < 0.0
		and studio.standees[0].position.is_equal_approx(studio.P1_STANDEE_POS),
		"P2 and P3 stand at opposite wall stations; P1 stands beside the car")
	var widest: float = 0.0
	for step: int in range(300):
		studio._process(0.1)
		widest = maxf(widest, absf(studio._cam_orbit_angle()))
	check(widest > 0.05 and widest <= 0.106, "The final-cut orbit sweeps but never beyond 6 degrees")
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.pressed = true
	root.push_input(event)
	await create_timer(0.3).timeout
	check(studio.is_leaderboard_open and is_equal_approx(studio.leaderboard.position.x, 1280.0), "TAB opens the timing panel even with button focus")
	check(not studio.name_labels[1].get_global_rect().intersects(studio.leaderboard.get_global_rect())
		and not studio.name_labels[2].get_global_rect().intersects(studio.leaderboard.get_global_rect())
		and not studio.name_labels[0].get_global_rect().intersects(studio.leaderboard.get_global_rect()),
		"With the timing tower open none of the podium plates sit under it")
	check(studio.camera.h_offset > 0.5 and is_equal_approx(studio.leaderboard.rotation_degrees, 1.2),
		"The tower slides in as a slightly tilted poster while the camera makes room")
	check(studio.timing_rows[0].get_theme_color("font_color").get_luminance() < 0.2,
		"Timing rows are inked dark so they read on the paper poster")
	camera_before = studio.camera.position
	studio._process(1.0)
	check(studio.camera.position.is_equal_approx(camera_before), "Expanded timing freezes the orbit for reading")
	# Reversal before the first tween settles must converge to the latest input.
	studio.toggle_leaderboard()
	studio.toggle_leaderboard()
	studio.toggle_leaderboard()
	await create_timer(0.3).timeout
	check(not studio.is_leaderboard_open and not studio.leaderboard.visible, "Rapid TAB reversals end fully closed without a stale tween")
	studio.toggle_leaderboard()
	await create_timer(0.3).timeout
	check(studio.timing_rows.size() == 20 and studio.team_labels.size() == 10,
		"Expanded timing contains all twenty finishers and all ten constructors")
	check(studio.timing_rows[1].text.contains("+1 PT") and studio.timing_rows[19].text.contains("DNF"),
		"Timing distinguishes the awarded fastest lap bonus from a retired result")
	var studio_ref: WeakRef = weakref(studio)
	studio.queue_free()
	await process_frame
	await process_frame
	check(studio_ref.get_ref() == null, "Closing studio releases its entire owned 3D tree")
	# Exercise restart through the real manga transition and configured grid.
	studio = load(SCENE).instantiate()
	studio.setup_celebration(results)
	root.add_child(studio)
	current_scene = studio
	studio_ref = weakref(studio)
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
	standalone.set_physics_process(false)
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
	load("res://scripts/world/toon_materials.gd")._cache.clear()
	load("res://scripts/car/gt_car_actor.gd")._paint_cache.clear()
	print("WINNING SCENE: %d assertions, %d FAIL" % [assertions, failures])
	quit(0 if failures == 0 else 1)

## The cut timeline: wall cuts for P3 and P2 alternate with hero cuts, then the final. Leaves `studio` on
## the final cut so the camera and orbit assertions that follow run on the settled composition.
func _test_cuts(studio_script: Script, results: Dictionary, studio: Node3D) -> void:
	var Cut := WinningCutDirector.Cut
	check(studio.director.current_cut == Cut.P3_TAG, "The finale opens on the P3 wall cut")
	check(absf(studio.camera.position.x - 30.0) < 1.0 and studio._wall_huds[2].visible and not studio._wall_huds[1].visible,
		"The P3 wall cut films the P3 station head-on with only the P3 graffiti showing")
	var tag: Label = studio._wall_huds[2].get_node("Tag")
	var gap: Label = studio._wall_huds[2].get_node("GapPlate")
	check(tag.text == String(results.order[2].driver_name).to_upper(), "The P3 tag spells the real P3 driver")
	check(gap.text.contains("+3.000s") and gap.text.contains("15 PTS"), "The P3 plate carries the gap and points")
	studio.director.tick(1.95)
	check(studio.director.current_cut == Cut.HERO and absf(studio.camera.position.x) < 1.0 and not studio._wall_huds[2].visible,
		"The hero cut returns the camera to the car set")
	studio.director.tick(1.95)
	check(studio.director.current_cut == Cut.P2_TAG and absf(studio.camera.position.x + 30.0) < 1.0 and studio._wall_huds[1].visible,
		"The P2 wall cut films the P2 station")

	var dnf: Dictionary = results.duplicate(true)
	dnf.order[2].is_dnf = true
	dnf.order[2].points = 0
	var other: Node3D = await _spawn(dnf)
	check(other._wall_huds[2].get_node("GapPlate").text.contains("DNF") and other._wall_huds[2].get_node("GapPlate").text.contains("0 PTS")
		and not other._wall_huds[2].get_node("GapPlate").text.contains("+"), "A retired P3 shows DNF and no points")
	other.queue_free()
	var two: Dictionary = results.duplicate(true)
	two.order = results.order.slice(0, 2)
	other = await _spawn(two)
	check(other.director.current_cut == Cut.HERO and not other._wall_huds.has(2), "With two finishers the P3 wall cut is skipped")
	other.queue_free()
	var none: Dictionary = results.duplicate(true)
	none.order = []
	none.winner_car = ""
	other = await _spawn(none)
	check(other.director.is_final() and other.standees.size() == 0, "With no finishers the studio goes straight to the final without crashing")
	other.queue_free()
	var long_name: Dictionary = results.duplicate(true)
	long_name.order[1].driver_name = "MAXIMILIAN-ALEXANDER FEATHERSTONEHAUGH"
	other = await _spawn(long_name)
	check(other._wall_huds[1].get_node("Tag").get_minimum_size().x <= 760.0, "A very long driver name still fits its wall")
	other.queue_free()
	await process_frame
	studio.director.skip_to_final()
	check(studio.director.is_final() and absf(studio.camera.position.x) < 1.0, "Skipping lands on the hero-set final")


## Hero and detail cuts: engine/wing notes then wheel/splitter notes, engine text from the winner's car,
## and a real camera dolly into the detail pose.
func _test_hero_cuts(results: Dictionary) -> void:
	var Callouts: GDScript = load("res://scripts/ui/winning_hero_callouts.gd")
	var box := AABB(Vector3(-1.0, 0.0, -2.3), Vector3(2.0, 1.2, 4.6))
	var points: Dictionary = Callouts.anchors(box)
	var inside: bool = true
	for key: StringName in points:
		inside = inside and box.has_point(points[key])
	check(points.size() == 4 and inside, "The four callout anchors sit inside the car's bounds")

	var studio: Node3D = await _spawn(results)
	studio.director.tick(1.95)
	studio._process(0.016)
	var callouts: Control = studio.hero_callouts
	check(callouts.visible and callouts.get_node("Note_engine").visible and callouts.get_node("Note_wing").visible
		and not callouts.get_node("Note_wheel").visible, "The hero cut shows the engine and wing notes only")
	check(callouts.get_node("Note_engine/Body/Text").text == Roster.CAR_ENGINES[0]
		and callouts.get_node("Note_engine/Body/Sub").text == Roster.CAR_NAMES[0].to_upper(),
		"The engine note carries the winner's engine layout and car name")
	var no_power: bool = true
	for key: String in ["engine", "wing", "wheel", "splitter"]:
		for label: Node in callouts.get_node("Note_%s" % key).find_children("*", "Label", true, false):
			no_power = no_power and not (label as Label).text.contains("HP")
	check(no_power, "No note invents a horsepower figure")
	studio.director.tick(1.95)
	studio.director.tick(1.95)
	check(studio.director.current_cut == WinningCutDirector.Cut.DETAIL, "The fourth cut is the detail cut")
	await create_timer(0.9).timeout
	check(callouts.get_node("Note_wheel").visible and not callouts.get_node("Note_engine").visible, "The detail cut swaps to the wheel and splitter notes")
	var wheel_at: Vector2 = callouts.get_node("Note_wheel").position
	check(wheel_at.x >= 0.0 and wheel_at.y >= 0.0 and wheel_at.x <= 1920.0 and wheel_at.y <= 1080.0 and wheel_at != Vector2.ZERO,
		"The wheel note stays on the stage")
	check(studio.camera.position.distance_to(studio.DETAIL_CAMERA_POS) < 0.05 and absf(studio._cam_orbit_angle()) < 0.0001,
		"The camera has dollied into the detail pose and no longer orbits")
	studio.queue_free()

	# The dolly starts from the hero pose even when the previous cut was a wall 30 m away.
	studio = await _spawn(results)
	studio.director.tick(1.95)
	studio.director.tick(1.95)
	studio.director.tick(1.95)
	studio._process(0.016)
	check(studio.director.current_cut == WinningCutDirector.Cut.DETAIL and absf(studio.camera.position.x) < 3.0,
		"Entering the detail cut from the P2 wall dollies out of the hero set, not across the whole stage (camera x %.1f)" % studio.camera.position.x)
	studio.queue_free()
	await process_frame

	var audi: Dictionary = results.duplicate(true)
	audi.winner_car = "audi_r8"
	studio = await _spawn(audi)
	studio.director.tick(1.95)
	studio._process(0.016)
	check(studio.hero_callouts.get_node("Note_engine/Body/Text").text == "5.2L V10 NA", "Another winner's car brings its own engine layout")
	studio.queue_free()
	await process_frame


## Final cut HUD: the podium plates carry the real finishers, the headline names the winning make, and
## the whole layer hides while a wall cut is on screen.
func _test_final_hud(results: Dictionary, studio: Node3D) -> void:
	check(studio.final_hud.visible, "The final plates show on the final cut")
	for place: int in range(3):
		var entry: Dictionary = results.order[place]
		check(studio.name_labels[place].text.contains(String(entry.driver_name).to_upper())
			and studio.name_labels[place].text.contains("#%02d" % int(entry.number)),
			"P%d plate names the real finisher and number" % (place + 1))
	check(studio.time_labels[2].text.contains("+3.000s") and studio.time_labels[2].text.contains("15 PTS"), "The P3 plate carries gap and points")
	check(studio.headline.text == "MERCEDES-AMG\nTAKES IT", "The headline names the winning make")
	var audi: Dictionary = results.duplicate(true)
	audi.winner_car = "audi_r8"
	var other: Node3D = await _spawn(audi)
	check(other.headline.text == "AUDI\nTAKES IT" and not other.final_hud.visible, "Another make rewrites the headline; the plates wait for the final")
	other.queue_free()
	await process_frame


## Skip keys, TAB mid-cut, the 80 ms impact frame, the anthem, and reduce_motion landing straight on the final.
func _test_input_and_motion(results: Dictionary, settings: Script) -> void:
	var studio: Node3D = await _spawn(results)
	check(AudioManager.of(studio).music_track == &"podium", "The winning scene plays the podium anthem")
	check(not studio.director.is_final(), "A fresh finale plays its cuts")
	_key(KEY_ENTER)
	await process_frame
	check(studio.director.is_final() and not studio._impact.visible, "Enter skips to the final without an impact flash")
	studio.queue_free()

	studio = await _spawn(results)
	_key(KEY_SPACE)
	await process_frame
	check(studio.director.is_final(), "Space skips to the final")
	studio.queue_free()

	studio = await _spawn(results)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(960.0, 540.0)
	root.push_input(click)
	await process_frame
	check(studio.director.is_final(), "A click on empty stage skips to the final")
	studio.queue_free()

	studio = await _spawn(results)
	var finals: Array[int] = []
	studio.director.cut_changed.connect(func(cut: int) -> void:
		if cut == WinningCutDirector.Cut.FINAL:
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
	studio.director.tick(1.95)
	check(studio._impact.visible, "A cut change flashes the manga impact frame")
	await create_timer(0.25).timeout
	check(not studio._impact.visible, "The impact frame lasts about 80 ms")
	studio.queue_free()
	await process_frame

	var normal: Node3D = await _spawn(results)
	var with_motion: int = get_processed_tweens().size()
	normal.queue_free()
	await process_frame
	await process_frame
	settings.reduce_motion = true
	var calm: Node3D = await _spawn(results)
	check(calm.director.is_final() and not calm._impact.visible, "Reduce motion lands on the final with no flash")
	check(get_processed_tweens().size() < with_motion, "Reduce motion starts no drip tweens")
	var held: Vector3 = calm.camera.position
	calm._process(1.0)
	check(calm.camera.position.is_equal_approx(held), "Reduce motion keeps the camera still")
	settings.reduce_motion = false
	calm.queue_free()
	await process_frame


func _spawn(snapshot: Dictionary) -> Node3D:
	var node: Node3D = load(SCENE).instantiate()
	node.setup_celebration(snapshot)
	root.add_child(node)
	await process_frame
	return node


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
