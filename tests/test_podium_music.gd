extends SceneTree

## Run: godot --headless --path . -s res://tests/test_podium_music.gd
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
	var hub := AudioManager.new()
	root.add_child(hub)
	await process_frame
	check(hub.music_track == &"menu", "A fresh hub starts on the menu track")
	hub.play_podium_music()
	check(hub.music_track == &"podium", "play_podium_music selects the podium track")
	check(hub.podium_stream is AudioStreamMP3 and (hub.podium_stream as AudioStreamMP3).loop,
		"The podium anthem is a looping MP3")
	check(hub._music_player.stream == hub.podium_stream, "The music player carries the podium stream")
	hub.play_menu_music()
	check(hub.music_track == &"menu" and hub._music_player.stream is AudioStreamOggVorbis,
		"play_menu_music restores the looping menu ogg")
	check(not hub.is_music_playing(), "Headless has no output device, so nothing really plays")
	hub.queue_free()

	# Called before the hub is in the tree (the fallback hub is added deferred).
	var early := AudioManager.new()
	early.play_podium_music()
	root.add_child(early)
	await process_frame
	check(early.music_track == &"podium" and early._music_player.stream == early.podium_stream,
		"A podium request made before the hub is ready is applied once it is")
	early.queue_free()
	await process_frame
	print("PODIUM MUSIC: %d assertions, %d FAIL" % [assertions, failures])
	quit(0 if failures == 0 else 1)
