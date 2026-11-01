extends SceneTree

## Run: godot --headless --path . -s res://tests/test_music_single_config.gd
## Every music track is governed by the single Music slider in Settings (PresentationSettings.volumes[&"Music"]).
const Settings := preload("res://scripts/core/presentation_settings.gd")
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


func _music_index() -> int:
	return AudioServer.get_bus_index(&"Music")


func _music_db() -> float:
	return AudioServer.get_bus_volume_db(_music_index())


func _run() -> void:
	AudioManager.ensure_buses()
	var hub := AudioManager.new()
	root.add_child(hub)
	await process_frame

	hub.play_menu_music()
	var menu_on_music: bool = hub._music_player.bus == &"Music"
	hub.play_podium_music()
	check(menu_on_music and hub._music_player.bus == &"Music", "Menu and podium tracks both play on the Music bus")

	Settings.set_volume(&"Music", 0.4)
	hub.play_menu_music()
	var menu_db: float = _music_db()
	hub.play_podium_music()
	check(is_equal_approx(menu_db, linear_to_db(0.4)) and is_equal_approx(_music_db(), linear_to_db(0.4)),
		"One Music slider value gives the same bus level for both tracks")

	check(Settings.BUS_LABELS[Settings.BUSES.find(&"Music")] == "MUSIC", "Music slider caption reads MUSIC")

	# The podium anthem measures 2.2 LU louder than the menu loop (ffmpeg ebur128: -9.7 vs -11.9 LUFS), so it is trimmed.
	var gap: float = AudioManager.track_trim_db(&"menu") - AudioManager.track_trim_db(&"podium")
	check(absf(gap - 2.2) < 0.05, "Track trims differ by the measured 2.2 dB")
	check(AudioManager.track_trim_db(&"unknown") == 0.0, "An unknown track gets no trim")
	hub.play_podium_music()
	var podium_trim: float = hub._music_player.volume_db
	hub.play_menu_music()
	check(is_equal_approx(podium_trim, AudioManager.track_trim_db(&"podium")) and is_equal_approx(hub._music_player.volume_db, AudioManager.track_trim_db(&"menu")),
		"The music player level follows the active track's trim")
	var early := AudioManager.new()
	early.play_podium_music()
	root.add_child(early)
	await process_frame
	check(is_equal_approx(early._music_player.volume_db, AudioManager.track_trim_db(&"podium")),
		"A podium request made before the hub is ready still gets its trim")
	early.queue_free()

	# Ducking is an offset from the Music config, not from a level cached when the director was built.
	var director := RadioAudioDirector.new()
	Settings.set_volume(&"Music", 0.63)
	director.duck_music(true)
	check(is_equal_approx(_music_db(), linear_to_db(0.63) + RadioAudioDirector.DUCK_DB),
		"Ducking sits DUCK_DB under the Music config")
	Settings.set_volume(&"Music", 0.2)
	director.duck_music(false)
	check(is_equal_approx(_music_db(), linear_to_db(0.2)),
		"Releasing the duck returns to the current Music config, not the level seen at start")
	Settings.set_volume(&"Music", 0.0)
	director.duck_music(true)
	var muted_while_ducked: bool = AudioServer.is_bus_mute(_music_index())
	director.duck_music(false)
	check(muted_while_ducked and AudioServer.is_bus_mute(_music_index()), "Ducking never unmutes a muted Music bus")
	director.free()

	Settings.set_volume(&"Music", 0.63)
	hub.queue_free()
	await process_frame
	print("MUSIC SINGLE CONFIG: %d assertions, %d FAIL" % [assertions, failures])
	quit(0 if failures == 0 else 1)
