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
const MUSIC_STREAM := preload("res://assets/audio/music/streetwear_synth.ogg")
const PODIUM_MUSIC_STREAM := preload("res://assets/audio/music/podium_rock_anthem.mp3")
const TRACK_MENU := &"menu"
const TRACK_PODIUM := &"podium"

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
var _menu_stream: AudioStream

var _ui_players: Array[AudioStreamPlayer] = []
var _next_ui_voice: int = 0
var _radio_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer


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
	podium_stream = PODIUM_MUSIC_STREAM.duplicate() as AudioStreamMP3
	podium_stream.loop = true


func _enter_tree() -> void:
	ensure_buses()


func _ready() -> void:
	for index: int in range(CLICK_VOICES):
		_ui_players.append(_make_player(BUS_UI))
	_radio_player = _make_player(BUS_RADIO)
	_music_player = _make_player(BUS_MUSIC)
	_menu_stream = MUSIC_STREAM.duplicate()
	(_menu_stream as AudioStreamOggVorbis).loop = true
	# A track requested before the players existed (the fallback hub is added deferred) lands now.
	_music_player.stream = podium_stream if music_track == TRACK_PODIUM else _menu_stream


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


## Lights out: the green buzzer.
func play_lights_out() -> void:
	_play_ui(LIGHTS_OUT, 1.0)


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

func start_music() -> void:
	if _music_player != null and not _music_player.playing and is_inside_tree() and has_output():
		_music_player.play()


## Winning scene anthem. Replaces whatever music is running.
func play_podium_music() -> void:
	_set_track(TRACK_PODIUM)


## Back to the menu loop. start_music() does not restart a track that is already playing, so every
## exit from the podium must come through here or the anthem would carry on into the next race.
func play_menu_music() -> void:
	_set_track(TRACK_MENU)


func _set_track(track: StringName) -> void:
	music_track = track
	if _music_player == null:
		return
	_music_player.stop()
	_music_player.stream = podium_stream if track == TRACK_PODIUM else _menu_stream
	if is_inside_tree() and has_output():
		_music_player.play()


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
