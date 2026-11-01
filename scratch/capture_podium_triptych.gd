extends SceneTree

## Native 1080p captures of the podium triptych for several podiums (Fase 20 evidence).
## godot --rendering-driver d3d12 --resolution 1920x1080 --path . -s res://scratch/capture_podium_triptych.gd
const Studio := preload("res://scripts/ui/winning_scene.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
const Roster := preload("res://scripts/ui/garage_roster.gd")
const OUT := "res://executor-report/screenshots/phases/phase-20/"
const Cut := WinningCutDirector.Cut
var studio: Node3D
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])


## A twenty-car result with `podium` (three driver slots) on the top three places.
func _results(podium: Array[int]) -> Dictionary:
	var slots: Array[int] = podium.duplicate()
	for slot: int in range(20):
		if slot not in slots:
			slots.append(slot)
	var rows: Array[Dictionary] = []
	var team_points: Dictionary = {}
	for place: int in range(20):
		var slot: int = slots[place]
		var points: int = Studio.points_for(place + 1)
		rows.append({"id": slot, "team_id": slot / 2, "driver_name": GtData.DRIVER_NAMES[slot], "team_name": GtData.TEAM_NAMES[slot / 2],
			"number": slot + 1, "code": GtData.DRIVER_CODES[slot], "time": 300.0 + float(place) * 1.7, "best_lap": 92.0 + float(place) * 0.2,
			"laps": 3, "is_dnf": false, "points": points + (1 if place == 1 else 0)})
		team_points[slot / 2] = int(team_points.get(slot / 2, 0)) + int(rows[place].points)
	return {"order": rows, "winner_car": Roster.CAR_SLUGS[int(rows[0].team_id)], "team_points": team_points,
		"fastest_lap": {"id": int(rows[1].id), "code": rows[1].code, "time": 92.2, "bonus": 1}}


func _open(snapshot: Dictionary) -> void:
	if studio != null:
		studio.queue_free()
		await process_frame
	studio = load(Studio.PATH).instantiate()
	studio.setup_celebration(snapshot)
	root.add_child(studio)
	current_scene = studio
	await process_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.get_size() == Vector2i(1920, 1080) and image.save_png(OUT + file_name + ".png") == OK, "Captured " + file_name)


func _at_cut(cut: int, file_name: String, settle: float) -> void:
	var started: int = Time.get_ticks_msec()
	while studio.director.current_cut != cut and Time.get_ticks_msec() - started < 15000:
		await process_frame
	await create_timer(settle).timeout
	await _save(file_name)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	root.push_input(event)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("Native renderer required")
		quit(1)
		return
	root.content_scale_size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	Settings.set_quality(Settings.Quality.HIGH)
	Settings.reduce_motion = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	# Podium A: Mercedes-AMG, Audi, Aston Martin. All five cuts, then the tower.
	await _open(_results([0, 2, 8]))
	await _at_cut(Cut.INTRO, "a-1-intro", 0.9)
	await _at_cut(Cut.FOCUS_P3, "a-2-focus-p3", 1.0)
	await _at_cut(Cut.FOCUS_P2, "a-3-focus-p2", 1.0)
	await _at_cut(Cut.FOCUS_P1, "a-4-focus-p1", 1.0)
	await _at_cut(Cut.FINAL, "a-5-final", 1.2)
	_key(KEY_TAB)
	await create_timer(0.6).timeout
	await _save("a-6-final-with-tower")
	# Podium B: BMW, Corvette, Lexus.
	await _open(_results([6, 10, 14]))
	studio.skip_cuts()
	await create_timer(1.6).timeout
	await _save("b-final")
	studio.triptych.set_focus(2, true)
	await create_timer(0.4).timeout
	await _save("b-focus-p3")
	# Podium C: Honda, McLaren, Toyota.
	await _open(_results([12, 16, 24]))
	studio.skip_cuts()
	await create_timer(1.6).timeout
	await _save("c-final")
	studio.triptych.set_focus(1, true)
	await create_timer(0.4).timeout
	await _save("c-focus-p2")
	# A retired P3 and a name far too long for its tag.
	var edge: Dictionary = _results([0, 2, 8])
	edge.order[2].is_dnf = true
	edge.order[2].points = 0
	edge.order[1].driver_name = "MAXIMILIAN-ALEXANDER FEATHERSTONEHAUGH"
	await _open(edge)
	studio.skip_cuts()
	await create_timer(1.6).timeout
	await _save("d-dnf-p3-and-long-name")
	print("CAPTURES: %d FAIL" % failures)
	quit(0 if failures == 0 else 1)
