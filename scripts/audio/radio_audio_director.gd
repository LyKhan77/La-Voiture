class_name RadioAudioDirector
extends Node

## Team radio sound (FASE 6). A transmission keys up with a squelch, ducks the Music bus 8 dB
## in 150 ms for the length of the message, keys down with a second squelch and lets the music
## back to its normal level in 500 ms. The HUD wires it to the anime radio cut-ins: a banner
## showing starts a transmission, the banner leaving the screen ends it. Driver and engineer
## can talk at once; each key-up and key-down squelches, and the music comes back only when
## the last one is over. A call with a recorded voice line (RadioVoice) speaks it right after the
## key-up squelch, on the filtered Radio bus, and the banner holds for the clip.

signal ducking_changed(active: bool)
signal voice_started(clip_id: String)

const DUCK_DB: float = -8.0
const DUCK_TIME_S: float = 0.15
const RESTORE_TIME_S: float = 0.50
## Squelch chirp before the words, the breath after them, and the shortest time a banner is read.
const VOICE_LEAD_S: float = 0.22
const VOICE_TAIL_S: float = 0.35
const VOICE_MIN_HOLD_S: float = 2.6
const VOICE_EVENT := &"voice"

var transmitting: bool = false # any source live
## Squelches in the order they were keyed (&"squelch_in", &"voice", &"squelch_out").
var events: Array[StringName] = []
## Ids of the voice clips spoken so far.
var voice_log: Array[String] = []
## Resting level of the Music bus, read from the bus layout; the duck is relative to it.
var music_base_db: float = 0.0

var _sources: Dictionary = {} # instance id of each live source (0 = none given)
var _queued: Dictionary = {} # source id -> clip waiting for its transmission to start
var _voices: Dictionary = {} # source id -> AudioStreamPlayer on the Radio bus
var _voice_tokens: Dictionary = {} # source id -> counter that voids a clip that was replaced
var _tween: Tween


func _ready() -> void:
	AudioManager.ensure_buses()
	var index: int = AudioServer.get_bus_index(AudioManager.BUS_MUSIC)
	if index >= 0:
		music_base_db = AudioServer.get_bus_volume_db(index)


func on_transmission_shown(_car_id: int = 0, _message: String = "", source: Object = null) -> void:
	start_transmission(source)


func on_transmission_finished(source: Object = null) -> void:
	end_transmission(source)


## Call before the cut-in shows its banner: remembers the clip for that overlay and returns how
## long the banner has to stay up so the clip finishes before it leaves.
func queue_voice(source: Object, clip: Dictionary) -> float:
	_queued[_key(source)] = clip
	return maxf(VOICE_MIN_HOLD_S, VOICE_LEAD_S + float(clip["length"]) + VOICE_TAIL_S)


## A message replacing a banner that is still up squelches again but counts as one source.
func start_transmission(source: Object = null) -> void:
	events.append(AudioManager.SQUELCH_IN)
	AudioManager.of(self).play_squelch(true)
	var key: int = _key(source)
	_sources[key] = true
	_stop_voice(key)
	if _queued.has(key):
		_speak(key, _queued[key])
		_queued.erase(key)
	if not transmitting:
		transmitting = true
		duck_music(true)


func end_transmission(source: Object = null) -> void:
	var key: int = _key(source)
	if not _sources.erase(key):
		return
	_stop_voice(key)
	events.append(AudioManager.SQUELCH_OUT)
	AudioManager.of(self).play_squelch(false)
	if _sources.is_empty():
		transmitting = false
		duck_music(false)


func _key(source: Object) -> int:
	return source.get_instance_id() if source != null else 0


## The words start after the squelch chirp, unless the call was replaced or ended meanwhile.
func _speak(key: int, clip: Dictionary) -> void:
	var token: int = int(_voice_tokens.get(key, 0)) + 1
	_voice_tokens[key] = token
	if is_inside_tree():
		await get_tree().create_timer(VOICE_LEAD_S).timeout
	if int(_voice_tokens.get(key, 0)) != token or not _sources.has(key):
		return
	events.append(VOICE_EVENT)
	voice_log.append(String(clip["id"]))
	voice_started.emit(String(clip["id"]))
	if not AudioManager.has_output():
		return
	if not _voices.has(key):
		var player := AudioStreamPlayer.new()
		player.bus = AudioManager.BUS_RADIO
		add_child(player)
		_voices[key] = player
	(_voices[key] as AudioStreamPlayer).stream = clip["stream"]
	(_voices[key] as AudioStreamPlayer).play()


func _stop_voice(key: int) -> void:
	_voice_tokens[key] = int(_voice_tokens.get(key, 0)) + 1
	if _voices.has(key):
		(_voices[key] as AudioStreamPlayer).stop()


## Music bus 8 dB under its resting level (150 ms), or back up to it (500 ms).
func duck_music(active: bool) -> void:
	var music_bus_idx: int = AudioServer.get_bus_index(AudioManager.BUS_MUSIC)
	if music_bus_idx < 0:
		return
	var target_db: float = music_base_db + DUCK_DB if active else music_base_db
	var duration: float = DUCK_TIME_S if active else RESTORE_TIME_S
	if _tween != null and _tween.is_valid():
		_tween.kill()
	ducking_changed.emit(active)
	if not is_inside_tree():
		AudioServer.set_bus_volume_db(music_bus_idx, target_db)
		return
	_tween = create_tween()
	_tween.tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(music_bus_idx, db), AudioServer.get_bus_volume_db(music_bus_idx), target_db, duration)
