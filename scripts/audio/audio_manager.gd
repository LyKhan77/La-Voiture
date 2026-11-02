class_name AudioManager
extends Node

## Global audio hub (FASE 6): registered as the `Audio` autoload. It owns the UI, radio and
## music players, makes sure the five buses of default_bus_layout.tres exist, and plays the
## UI click, warning siren, FIA start beeps and the green lights-out buzzer. Every sound it
## starts is also logged (`play_counts`, `play_log`) and announced on `sound_played`, so the
## HUD, the gantry and the tests can see what was triggered even on the headless audio driver.
## Callers go through `AudioManager.of(node)`, which also builds the hub when the autoload is
## missing (a bare test tree).

signal sound_played(sound: StringName)
## A music track was selected (also on the headless driver, where it does not really play).
signal track_started(context: StringName, title: String)

const LAYOUT := "res://default_bus_layout.tres"
const AUTOLOAD_NAME := "Audio"
const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"
const BUS_RADIO := &"Radio"
const REQUIRED_BUSES: Array[StringName] = [BUS_MASTER, BUS_MUSIC, BUS_SFX, BUS_UI, BUS_RADIO]

const CLICK := &"click_snap"
const WARNING := &"warning_siren"
const START_BEEP := &"start_beep"
const LIGHTS_OUT := &"lights_out"
const SQUELCH_IN := &"squelch_in"
const SQUELCH_OUT := &"squelch_out"
const STEWARD_INVESTIGATION := &"steward_investigation"
const STEWARD_PENALTY := &"steward_penalty"

const STREAMS: Dictionary = {
	STEWARD_INVESTIGATION: preload("res://assets/audio/sfx/steward_investigation.wav"),
	STEWARD_PENALTY: preload("res://assets/audio/sfx/steward_penalty.wav"),
	CLICK: preload("res://assets/audio/ui/click_snap.wav"),
	WARNING: preload("res://assets/audio/ui/warning_siren.wav"),
	START_BEEP: preload("res://assets/audio/ui/start_beep.wav"),
	LIGHTS_OUT: preload("res://assets/audio/ui/lights_out.wav"),
	SQUELCH_IN: preload("res://assets/audio/radio/squelch_in.wav"),
	SQUELCH_OUT: preload("res://assets/audio/radio/squelch_out.wav"),
}
const TRACK_MENU := &"menu"
const TRACK_GARAGE := &"garage"
const TRACK_RACE := &"race"
const TRACK_RACE_RAIN := &"race_rain"
const TRACK_PODIUM := &"podium"
## Music per context, each entry [path, trim dB]. A context with more than one entry is a playlist: its
## tracks play once each and advance on `finished`; a single-entry context loops. The trim is a static
## mastering offset so the one Music slider gives the same loudness on every track, measured with
## `ffmpeg -i <file> -af ebur128 -f null -` against streetwear_synth.ogg (-11.9 LUFS): podium_rock_anthem -9.7,
## menu_acid_jazz -13.5, garage_lofi -14.3, race_dnb -12.3, race_rain -13.3 LUFS. Measure again if a track is replaced.
const PLAYLISTS: Dictionary = {
	TRACK_MENU: [["res://assets/audio/music/streetwear_synth.ogg", 0.0], ["res://assets/audio/music/menu_acid_jazz.mp3", 1.6]],
	TRACK_GARAGE: [["res://assets/audio/music/garage_lofi.mp3", 2.4]],
	TRACK_RACE: [["res://assets/audio/music/race_dnb.mp3", 0.4]],
	TRACK_RACE_RAIN: [["res://assets/audio/music/race_rain.mp3", 1.4]],
	TRACK_PODIUM: [["res://assets/audio/music/podium_rock_anthem.mp3", -2.2]],
}
## Race music sits under the cars and the radio: AMBIENT plays it this far below the track trim, the final lap lifts it.
const RACE_AMBIENT_DB: float = -8.0
const FINAL_LAP_LIFT_DB: float = 4.0
## Behind the safety car the music goes muffled through a low-pass on the Music bus.
const SC_CUTOFF_HZ: float = 700.0
## A rain shower must hold this long before the race music swaps to the rain track, so a threshold flicker cannot ping-pong.
const WEATHER_SWAP_HOLD_S: float = 12.0
const FADE_IN_S: float = 0.8

## Each of the five start lights climbs a semitone-ish step, so the countdown reads as rising.
const START_BEEP_PITCH_STEP: float = 0.09
const LOG_LIMIT: int = 64
const CLICK_VOICES: int = 4

static var _fallback: AudioManager

var play_counts: Dictionary = {} # sound name -> times played
var play_log: Array[StringName] = []
var last_start_beep_pitch: float = 1.0
## Which music the hub is set to play. Tracked apart from playback so headless tests can read it.
var music_track: StringName = TRACK_MENU
var podium_stream: AudioStreamMP3
## Index of the playing entry in each context's playlist.
var playlist_index: Dictionary = {}
## Race mood the world last reported; read by tests.
var race_wet: bool = false
var race_safety_car: bool = false
var race_final_lap: bool = false
## True from the first start light to lights out: the beeps play over silence.
var holding_for_lights: bool = false
## Title of the track that started last, for the NOW PLAYING toast.
var now_playing: String = ""

var _streams: Dictionary = {} # context -> Array[AudioStream]
var _wet_pending_s: float = 0.0
var _fade: Tween

var _ui_players: Array[AudioStreamPlayer] = []
var _next_ui_voice: int = 0
var _radio_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer


## Trim of the first track of a context.
static func track_trim_db(track: StringName) -> float:
	var entries: Array = PLAYLISTS.get(track, [])
	return float(entries[0][1]) if not entries.is_empty() else 0.0


## "race_dnb.mp3" reads "RACE DNB".
static func title_of(path: String) -> String:
	return path.get_file().get_basename().replace("_", " ").to_upper()


## The hub for any node in the tree: the autoload, or one built on first use.
static func of(node: Node) -> AudioManager:
	if not node.is_inside_tree():
		return null
	var tree: SceneTree = node.get_tree()
	var found := tree.root.get_node_or_null(AUTOLOAD_NAME) as AudioManager
	if found == null:
		# Deferred add: the root may be busy setting up its children. Keep the one hub until it lands.
		if _fallback == null or not is_instance_valid(_fallback):
			_fallback = AudioManager.new()
			_fallback.name = AUTOLOAD_NAME
			tree.root.add_child.call_deferred(_fallback)
		found = _fallback
	return found


## Click from any UI control that is in the tree.
static func click(node: Node) -> void:
	var hub: AudioManager = of(node)
	if hub != null:
		hub.play_ui_click()


## Click with a pitch per action, so each deck control answers in its own voice.
static func click_pitched(node: Node, pitch: float) -> void:
	var hub: AudioManager = of(node)
	if hub != null:
		hub.play_ui_click_pitched(pitch)


## --headless has no output device; playback there only leaves stream references behind at quit.
static func has_output() -> bool:
	return DisplayServer.get_name() != "headless"


## Applies the project bus layout when the running server lacks one of the five buses.
static func ensure_buses() -> void:
	for bus: StringName in REQUIRED_BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.set_bus_layout(load(LAYOUT) as AudioBusLayout)
			return


func _init() -> void:
	for context: StringName in PLAYLISTS:
		var entries: Array = PLAYLISTS[context]
		var streams: Array[AudioStream] = []
		for entry: Array in entries:
			var stream: AudioStream = (load(String(entry[0])) as AudioStream).duplicate()
			# Playlists advance on `finished`, which a looping stream never emits.
			stream.set("loop", entries.size() == 1)
			streams.append(stream)
		_streams[context] = streams
		playlist_index[context] = 0
	podium_stream = _streams[TRACK_PODIUM][0] as AudioStreamMP3


func _enter_tree() -> void:
	ensure_buses()


func _ready() -> void:
	for index: int in range(CLICK_VOICES):
		_ui_players.append(_make_player(BUS_UI))
	_radio_player = _make_player(BUS_RADIO)
	_music_player = _make_player(BUS_MUSIC)
	_music_player.finished.connect(_on_music_finished)
	_ensure_sc_filter()
	# A track requested before the players existed (the fallback hub is added deferred) lands now.
	_music_player.stream = _current_stream()
	_music_player.volume_db = _target_db()
	now_playing = title_of(String(PLAYLISTS[music_track][int(playlist_index[music_track])][0]))


## Quits leave no stream playing, so the resources are free at shutdown.
func _exit_tree() -> void:
	var voices: Array[AudioStreamPlayer] = _ui_players.duplicate()
	voices.append(_radio_player)
	voices.append(_music_player)
	for player: AudioStreamPlayer in voices:
		if player != null:
			player.stop()
			player.stream = null


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


# --- UI sounds ---------------------------------------------------------------------------------

func play_ui_click() -> void:
	_play_ui(CLICK, 1.0)


func play_ui_click_pitched(pitch: float) -> void:
	_play_ui(CLICK, pitch)


## Emergency alarm: BOX call, critical tyres, urgent radio.
func play_warning() -> void:
	_play_ui(WARNING, 1.0)


## Stewards: a short beep when an incident goes under investigation, the gavel and buzzer for a time penalty.
func play_steward_investigation() -> void:
	_play_ui(STEWARD_INVESTIGATION, 1.0)


func play_steward_penalty() -> void:
	_play_ui(STEWARD_PENALTY, 1.0)


## Light pair `pair` (1..5) of the FIA start sequence; each pair beeps a step higher.
func play_start_beep(pair: int = 1) -> void:
	last_start_beep_pitch = 1.0 + START_BEEP_PITCH_STEP * float(clampi(pair, 1, 5) - 1)
	_play_ui(START_BEEP, last_start_beep_pitch)
	# The countdown plays over silence; the race track drops in on lights out.
	if is_race_track(music_track) and not holding_for_lights:
		holding_for_lights = true
		if _music_player != null:
			_kill_fade()
			_music_player.stop()


## Lights out: the green buzzer.
func play_lights_out() -> void:
	_play_ui(LIGHTS_OUT, 1.0)
	if holding_for_lights:
		holding_for_lights = false
		_set_track(music_track)


## Walkie-talkie key-up (true) or key-down (false), on the filtered Radio bus.
func play_squelch(key_up: bool) -> void:
	var sound: StringName = SQUELCH_IN if key_up else SQUELCH_OUT
	_log(sound)
	if _radio_player != null and is_inside_tree() and has_output():
		_radio_player.stream = STREAMS[sound]
		_radio_player.play()


func _play_ui(sound: StringName, pitch: float) -> void:
	_log(sound)
	if _ui_players.is_empty() or not is_inside_tree() or not has_output():
		return
	var player: AudioStreamPlayer = _ui_players[_next_ui_voice]
	_next_ui_voice = (_next_ui_voice + 1) % _ui_players.size()
	player.stream = STREAMS[sound]
	player.pitch_scale = pitch
	player.play()


func _log(sound: StringName) -> void:
	play_counts[sound] = int(play_counts.get(sound, 0)) + 1
	play_log.append(sound)
	if play_log.size() > LOG_LIMIT:
		play_log.pop_front()
	sound_played.emit(sound)


func count_of(sound: StringName) -> int:
	return int(play_counts.get(sound, 0))


# --- music and volume ------------------------------------------------------------------------------

## Menu screens: keeps the menu playlist going, or brings it back from any other context.
func start_music() -> void:
	play_context(TRACK_MENU)


## Winning scene anthem. Replaces whatever music is running.
func play_podium_music() -> void:
	_set_track(TRACK_PODIUM)


## Back to the menu playlist. start_music() does not restart a track that is already playing, so every
## exit from the podium must come through here or the anthem would carry on into the next race.
func play_menu_music() -> void:
	_set_track(TRACK_MENU)


## Switches to `context` unless it is already the one playing; a running track is never restarted.
func play_context(context: StringName) -> void:
	if context != music_track or holding_for_lights:
		holding_for_lights = false
		_set_track(context)
	elif _music_player != null and not _music_player.playing and is_inside_tree() and has_output():
		_music_player.play()


## The race world calls this once when it is built: race or rain track, faded under the cars.
func play_race_music(wet: bool) -> void:
	race_wet = wet
	race_safety_car = false
	race_final_lap = false
	_wet_pending_s = 0.0
	holding_for_lights = false
	_set_track(TRACK_RACE_RAIN if wet else TRACK_RACE)


## The race world reports its mood a few times a second. Rain swaps the track once the shower holds;
## the safety car muffles it; the final lap lifts it.
func set_race_mood(wet: bool, safety_car: bool, final_lap: bool, delta: float) -> void:
	if not is_race_track(music_track):
		return
	if safety_car != race_safety_car:
		race_safety_car = safety_car
		_apply_sc_filter()
	if final_lap != race_final_lap:
		race_final_lap = final_lap
		_apply_level()
	if wet == race_wet:
		_wet_pending_s = 0.0
		return
	_wet_pending_s += delta
	if _wet_pending_s >= WEATHER_SWAP_HOLD_S:
		_wet_pending_s = 0.0
		race_wet = wet
		if not holding_for_lights:
			_set_track(TRACK_RACE_RAIN if wet else TRACK_RACE)
		else:
			music_track = TRACK_RACE_RAIN if wet else TRACK_RACE


static func is_race_track(context: StringName) -> bool:
	return context == TRACK_RACE or context == TRACK_RACE_RAIN


## Menu only: the next playlist track now.
func skip_track() -> void:
	var entries: Array = PLAYLISTS.get(music_track, [])
	if entries.size() > 1:
		playlist_index[music_track] = (int(playlist_index[music_track]) + 1) % entries.size()
		_set_track(music_track)


func _on_music_finished() -> void:
	skip_track()


func _current_stream() -> AudioStream:
	var streams: Array = _streams.get(music_track, [])
	return streams[int(playlist_index.get(music_track, 0))] if not streams.is_empty() else null


## Track trim, plus the race level and final-lap lift on race tracks.
func _target_db() -> float:
	var entries: Array = PLAYLISTS.get(music_track, [])
	var db: float = float(entries[int(playlist_index.get(music_track, 0))][1]) if not entries.is_empty() else 0.0
	if is_race_track(music_track) and PresentationSettings.race_music == PresentationSettings.RaceMusic.AMBIENT:
		db += RACE_AMBIENT_DB + (FINAL_LAP_LIFT_DB if race_final_lap else 0.0)
	return db


func _apply_level() -> void:
	if _music_player != null:
		_kill_fade()
		_music_player.volume_db = _target_db()


func _set_track(track: StringName) -> void:
	music_track = track
	_apply_sc_filter()
	if _music_player == null:
		return
	_kill_fade()
	_music_player.stop()
	_music_player.stream = _current_stream()
	_music_player.volume_db = _target_db()
	var entries: Array = PLAYLISTS.get(track, [])
	now_playing = title_of(String(entries[int(playlist_index[track])][0])) if not entries.is_empty() else ""
	track_started.emit(track, now_playing)
	if is_race_track(track) and PresentationSettings.race_music == PresentationSettings.RaceMusic.OFF:
		return
	if is_inside_tree() and has_output() and not holding_for_lights:
		_music_player.volume_db = _target_db() - 24.0
		_music_player.play()
		_fade = create_tween()
		_fade.tween_property(_music_player, "volume_db", _target_db(), FADE_IN_S)


func _kill_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null


## A disabled low-pass on the Music bus, switched on behind the safety car.
func _ensure_sc_filter() -> void:
	var bus: int = AudioServer.get_bus_index(BUS_MUSIC)
	if bus < 0 or _sc_filter_index() >= 0:
		return
	var filter := AudioEffectLowPassFilter.new()
	filter.cutoff_hz = SC_CUTOFF_HZ
	AudioServer.add_bus_effect(bus, filter)
	AudioServer.set_bus_effect_enabled(bus, AudioServer.get_bus_effect_count(bus) - 1, false)


func _sc_filter_index() -> int:
	var bus: int = AudioServer.get_bus_index(BUS_MUSIC)
	if bus < 0:
		return -1
	for index: int in range(AudioServer.get_bus_effect_count(bus)):
		if AudioServer.get_bus_effect(bus, index) is AudioEffectLowPassFilter:
			return index
	return -1


func _apply_sc_filter() -> void:
	var index: int = _sc_filter_index()
	if index >= 0:
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(BUS_MUSIC), index, race_safety_car and is_race_track(music_track))


## Is the safety-car low-pass on the Music bus switched on?
func is_music_muffled() -> bool:
	var index: int = _sc_filter_index()
	return index >= 0 and AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index(BUS_MUSIC), index)


## The Race Music setting changed mid-race: stop, start or re-level the race track.
func refresh_race_music() -> void:
	if not is_race_track(music_track) or _music_player == null:
		return
	if PresentationSettings.race_music == PresentationSettings.RaceMusic.OFF:
		_kill_fade()
		_music_player.stop()
	elif not _music_player.playing and not holding_for_lights:
		_set_track(music_track)
	else:
		_apply_level()


func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()


func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing


func set_bus_volume(bus: StringName, volume_db: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, volume_db)


func get_bus_volume(bus: StringName) -> float:
	var index: int = AudioServer.get_bus_index(bus)
	return AudioServer.get_bus_volume_db(index) if index >= 0 else 0.0
