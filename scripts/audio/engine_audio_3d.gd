class_name EngineAudio3D
extends AudioStreamPlayer3D

## Spatial engine note of one GT3 (FASE 6). The loop is pitched by RPM and its level follows
## the throttle and the speed; an upshift fires the exhaust pop through a second player.
## Drive it with update_engine_audio() every frame and on_gear_changed() with the sim gear.

signal backfire_triggered

const ENGINE_STREAM := preload("res://assets/audio/engine/gt3_engine_loop.wav")
const POP_STREAM := preload("res://assets/audio/engine/gearshift_pop.wav")

const IDLE_RPM: float = 1200.0
const REDLINE_RPM: float = 8500.0
const PITCH_IDLE: float = 0.65
const PITCH_SPAN: float = 1.20
const PITCH_CURVE: float = 0.85
const VOLUME_BASE_DB: float = -18.0
const VOLUME_THROTTLE_DB: float = 12.0
const VOLUME_SPEED_DB: float = 6.0
const VOLUME_MIN_DB: float = -30.0
const VOLUME_MAX_DB: float = 4.0
const SPEED_MAX_MPS: float = 76.0
const HEARING_RANGE_M: float = 80.0
const POP_VOLUME_DB: float = -4.0

var pops_triggered: int = 0

var _pop_player: AudioStreamPlayer3D
var _last_gear: int = -1


func _ready() -> void:
	bus = &"SFX"
	max_distance = HEARING_RANGE_M
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	stream = looped(ENGINE_STREAM)
	_pop_player = AudioStreamPlayer3D.new()
	_pop_player.name = "ExhaustPop"
	_pop_player.bus = &"SFX"
	_pop_player.max_distance = HEARING_RANGE_M
	_pop_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_pop_player.volume_db = POP_VOLUME_DB
	_pop_player.stream = POP_STREAM
	add_child(_pop_player)


## Pitch for an RPM: 0.65 at idle (1200) up to 1.85 at the 8500 redline.
static func pitch_for(rpm: float) -> float:
	var normalized_rpm: float = clampf((rpm - IDLE_RPM) / (REDLINE_RPM - IDLE_RPM), 0.0, 1.0)
	return PITCH_IDLE + PITCH_SPAN * pow(normalized_rpm, PITCH_CURVE)


static func volume_for(throttle: float, speed_mps: float) -> float:
	var target_db: float = VOLUME_BASE_DB + VOLUME_THROTTLE_DB * throttle + VOLUME_SPEED_DB * (speed_mps / SPEED_MAX_MPS)
	return clampf(target_db, VOLUME_MIN_DB, VOLUME_MAX_DB)


## A copy of a WAV set to loop over its whole length (the shared import stays untouched).
static func looped(source: AudioStreamWAV) -> AudioStreamWAV:
	var copy := source.duplicate() as AudioStreamWAV
	var bytes_per_frame: int = (2 if copy.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if copy.stereo else 1)
	copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
	copy.loop_begin = 0
	copy.loop_end = copy.data.size() / bytes_per_frame
	return copy


func update_engine_audio(rpm: float, throttle: float, speed_mps: float) -> void:
	pitch_scale = pitch_for(rpm)
	volume_db = volume_for(throttle, speed_mps)
	if not playing and is_inside_tree():
		play()


## Feed the sim gear every frame; a higher gear than last time is an upshift and pops.
func on_gear_changed(gear: int) -> void:
	if _last_gear >= 0 and gear > _last_gear:
		trigger_backfire()
	_last_gear = gear


func trigger_backfire() -> void:
	pops_triggered += 1
	backfire_triggered.emit()
	if _pop_player != null and _pop_player.is_inside_tree():
		_pop_player.play()


func silence() -> void:
	if playing:
		stop()
