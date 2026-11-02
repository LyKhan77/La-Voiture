extends SceneTree

## Run: godot --headless --path . -s res://tests/test_race_music.gd
## Fase 21 music: menu playlist, garage track, and the race music that sits under the cars (silence over the
## start lights, rain track, safety-car low-pass, final-lap lift, Race Music setting).
const PS := preload("res://scripts/core/presentation_settings.gd")

var failures: int = 0
var assertions: int = 0
var started: Array[StringName] = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])


func _trim(context: StringName, index: int) -> float:
	return float(AudioManager.PLAYLISTS[context][index][1])


func _run() -> void:
	var saved_race_music: int = PS.race_music
	PS.race_music = PS.RaceMusic.AMBIENT
	var hub := AudioManager.new()
	root.add_child(hub)
	await process_frame
	hub.track_started.connect(func(context: StringName, _title: String) -> void: started.append(context))

	# Every listed track is a real imported stream.
	var all_load: bool = true
	for context: StringName in AudioManager.PLAYLISTS:
		for entry: Array in AudioManager.PLAYLISTS[context]:
			all_load = all_load and load(String(entry[0])) is AudioStream
	check(all_load, "Every playlist entry loads as an AudioStream")
	check(AudioManager.PLAYLISTS[AudioManager.TRACK_MENU].size() >= 2, "The menu has a playlist of at least two tracks")

	# Menu playlist: skip advances, wraps, and each track keeps its own trim.
	hub.play_menu_music()
	hub.skip_track()
	check(int(hub.playlist_index[AudioManager.TRACK_MENU]) == 1 and is_equal_approx(hub._music_player.volume_db, _trim(AudioManager.TRACK_MENU, 1)),
		"skip_track moves to the second menu track at its own trim")
	check(hub.now_playing == "MENU ACID JAZZ", "now_playing names the menu track: %s" % hub.now_playing)
	for i: int in range(AudioManager.PLAYLISTS[AudioManager.TRACK_MENU].size() - 1):
		hub.skip_track()
	check(int(hub.playlist_index[AudioManager.TRACK_MENU]) == 0, "The menu playlist wraps back to the first track")
	check(not (hub._current_stream().get("loop") as bool), "Menu playlist tracks do not loop, so `finished` advances them")

	# Garage: own track, and asking again does not restart it.
	hub.play_context(AudioManager.TRACK_GARAGE)
	started.clear()
	hub.play_context(AudioManager.TRACK_GARAGE)
	check(hub.music_track == AudioManager.TRACK_GARAGE and started.is_empty(), "The garage track is not restarted when the garage asks again")
	hub.start_music()
	check(hub.music_track == AudioManager.TRACK_MENU, "Back on a menu screen, start_music returns to the menu playlist")

	# Race: ambient level, start-light silence, lights out.
	hub.play_race_music(false)
	check(hub.music_track == AudioManager.TRACK_RACE, "A dry race plays the race track")
	check(is_equal_approx(hub._music_player.volume_db, _trim(AudioManager.TRACK_RACE, 0) + AudioManager.RACE_AMBIENT_DB),
		"AMBIENT race music sits RACE_AMBIENT_DB under the track trim")
	hub.play_start_beep(1)
	check(hub.holding_for_lights, "The first start light silences the race music")
	started.clear()
	hub.play_lights_out()
	check(not hub.holding_for_lights and started == [AudioManager.TRACK_RACE], "Lights out drops the race track back in")

	# Safety car muffles, the final lap lifts.
	hub.set_race_mood(false, true, false, 0.5)
	check(hub.is_music_muffled(), "The safety car switches the Music bus low-pass on")
	hub.set_race_mood(false, false, false, 0.5)
	check(not hub.is_music_muffled(), "Green again switches the low-pass off")
	hub.set_race_mood(false, false, true, 0.5)
	check(is_equal_approx(hub._music_player.volume_db, _trim(AudioManager.TRACK_RACE, 0) + AudioManager.RACE_AMBIENT_DB + AudioManager.FINAL_LAP_LIFT_DB),
		"The final lap lifts the race music by FINAL_LAP_LIFT_DB")

	# Rain swaps only once it holds.
	hub.set_race_mood(true, false, true, 5.0)
	hub.set_race_mood(true, false, true, 5.0)
	check(hub.music_track == AudioManager.TRACK_RACE, "A shower shorter than WEATHER_SWAP_HOLD_S keeps the dry track")
	hub.set_race_mood(false, false, true, 0.5)
	hub.set_race_mood(true, false, true, 5.0)
	check(hub.music_track == AudioManager.TRACK_RACE, "A dry moment resets the rain hold")
	hub.set_race_mood(true, false, true, 8.0)
	check(hub.music_track == AudioManager.TRACK_RACE_RAIN, "Rain that holds swaps to the rain track")

	# The safety-car filter never follows the music out of the race.
	hub.set_race_mood(true, true, true, 0.5)
	hub.play_podium_music()
	check(not hub.is_music_muffled(), "The podium anthem is never muffled by a safety car left over from the race")

	# FULL plays race music at the track trim.
	PS.race_music = PS.RaceMusic.FULL
	hub.play_race_music(false)
	check(is_equal_approx(hub._music_player.volume_db, _trim(AudioManager.TRACK_RACE, 0)), "FULL race music plays at the track trim")
	PS.race_music = PS.RaceMusic.OFF
	hub.refresh_race_music()
	check(not hub.is_music_playing(), "OFF keeps the race silent")

	PS.race_music = saved_race_music
	hub.queue_free()
	await process_frame
	print("RACE MUSIC: %d assertions, %d FAIL" % [assertions, failures])
	quit(0 if failures == 0 else 1)
