extends SceneTree

## Native 1080p captures of the podium with the new idle and victory standees (Fase 31 evidence).
## godot --rendering-driver d3d12 --resolution 1920x1080 --path . -s res://scratch/capture_podium_poses.gd
const Studio := preload("res://scripts/ui/winning_scene.gd")
const Settings := preload("res://scripts/core/presentation_settings.gd")
const Roster := preload("res://scripts/ui/garage_roster.gd")
const OUT := "res://executor-report/screenshots/phases/phase-31/"
const Cut := WinningCutDirector.Cut
var studio: Node3D
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])


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
	# Ren (P1), Rossi (P2), Takahashi (P3): three of the drivers whose art was rebuilt.
	await _open(_results([1, 21, 25]))
	await _at_cut(Cut.INTRO, "1-intro-idle", 0.9)
	await _at_cut(Cut.FOCUS_P3, "2-focus-p3-pose", 1.0)
	await _at_cut(Cut.FOCUS_P2, "3-focus-p2-pose", 1.0)
	await _at_cut(Cut.FOCUS_P1, "4-focus-p1-pose", 1.0)
	await _at_cut(Cut.FINAL, "5-final-all-poses", 1.2)
	# Reduce motion lands straight on the final with every pose struck and no tilt left over.
	Settings.reduce_motion = true
	await _open(_results([0, 10, 24]))
	await create_timer(1.0).timeout
	await _save("6-reduce-motion-final")
	for panel: WinningPanel in studio.triptych.panels:
		check(panel.is_celebrating and is_zero_approx(panel.standee.rotation_degrees), "Reduce motion: pose struck, no tilt")
	print("CAPTURES: %d FAIL" % failures)
	quit(0 if failures == 0 else 1)
