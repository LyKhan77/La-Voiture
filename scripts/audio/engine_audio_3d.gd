class_name EngineAudio3D
extends AudioStreamPlayer3D

## Spatial engine note of one GT3 (FASE 6, per-family in Fase 21.3). This player is the
## on-throttle loop of the car's EngineProfile; children carry the overrun loop, the turbo
## whistle (twin-turbo families) and one-shots: an upshift crack and, on a lift at speed, an
## exhaust crackle (NA) or the blow-off valve (turbo). Each car is detuned a little and starts
## its loops at its own offset so a pack does not phase into one drone; Doppler is on.
## Drive it with update_engine_audio() every frame and on_gear_changed() with the sim gear.

signal backfire_triggered

## Still used by the garage and the race transition for their single rev.
const ENGINE_STREAM := preload("res://assets/audio/engine/gt3_engine_loop.wav")
const UPSHIFT_STREAM := preload("res://assets/audio/engine/profiles/upshift_crack.wav")
const OVERRUN_STREAM := preload("res://assets/audio/engine/profiles/overrun_crackle.wav")
const BLOW_OFF_STREAM := preload("res://assets/audio/engine/profiles/blow_off.wav")
const TURBO_STREAM := preload("res://assets/audio/engine/profiles/turbo_whistle.wav")

const VOLUME_BASE_DB: float = -18.0
const VOLUME_THROTTLE_DB: float = 12.0
const VOLUME_SPEED_DB: float = 6.0
const VOLUME_MIN_DB: float = -30.0
const VOLUME_MAX_DB: float = 4.0
const SPEED_MAX_MPS: float = 76.0
const HEARING_RANGE_M: float = 80.0
const SILENT_DB: float = -80.0
## Per-car pitch spread (±3 %).
const DETUNE: float = 0.03
## The car the camera follows sits this far above the pack.
const FOCUS_DB: float = 3.0
## The overrun loop is quieter than the drive loop.
const OFF_LAYER_DB: float = -4.0
const TURBO_DB: float = -14.0
## Turbo whistle pitch at the sim redline; it follows the RPM down from there.
const TURBO_PITCH_MAX: float = 1.25
const ONE_SHOT_DB: float = -4.0
## Per-frame smoothing of the throttle that drives the crossfade.
## shortcut: frame-rate dependent (tuned at 60 FPS); pass delta if the crossfade must hold at 30 FPS.
const THROTTLE_SMOOTHING: float = 0.2
## A lift: the throttle drops below LIFT_LOW from above LIFT_HIGH at speed; re-armed above LIFT_HIGH.
const LIFT_HIGH: float = 0.7
const LIFT_LOW: float = 0.3
const LIFT_MIN_SPEED_MPS: float = 25.0
const LAYER_MIN_WEIGHT: float = 0.03

var profile: EngineProfile
var focused: bool = false
var pops_triggered: int = 0
var lifts_triggered: int = 0
var off_layer: AudioStreamPlayer3D
var turbo_layer: AudioStreamPlayer3D
var one_shot: AudioStreamPlayer3D

static var _turbo_loop: AudioStreamWAV

var _detune: float = 1.0
var _offset_fraction: float = 0.0
var _throttle: float = 1.0
var _lift_armed: bool = false
var _last_gear: int = -1


func _ready() -> void:
	_setup(self)
	off_layer = _child("OverrunLoop")
	turbo_layer = _child("TurboWhistle")
	if _turbo_loop == null:
		_turbo_loop = looped(TURBO_STREAM)
	turbo_layer.stream = _turbo_loop
	one_shot = _child("ExhaustOneShot")
	one_shot.volume_db = ONE_SHOT_DB
	if profile == null:
		set_voice(EngineProfile.for_family(EngineProfile.DEFAULT_FAMILY), 0)


func _setup(player: AudioStreamPlayer3D) -> void:
	player.bus = &"SFX"
	player.max_distance = HEARING_RANGE_M
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP


func _child(child_name: String) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = child_name
	_setup(player)
	add_child(player)
	return player


## The engine family and the car's voice id (its field index): the id fixes the detune and loop offset.
func set_voice(p_profile: EngineProfile, voice_id: int) -> void:
	profile = p_profile
	stream = profile.on_stream
	if off_layer != null:
		off_layer.stream = profile.off_stream
		off_layer.stop()
	if playing:
		stop()
	# Golden-ratio steps spread the ids evenly over [-1, 1) and [0, 1) without a shared RNG.
	_detune = 1.0 + DETUNE * (fposmod(voice_id * 0.618034, 1.0) * 2.0 - 1.0)
	_offset_fraction = fposmod(voice_id * 0.381966, 1.0)


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


## Share of the on-throttle loop in the crossfade, 0..1.
func on_weight() -> float:
	return _throttle


## `near` is false for a car far from the camera: it keeps only its main loop (voice budget).
func update_engine_audio(rpm: float, throttle: float, speed_mps: float, near: bool = true) -> void:
	_throttle = lerpf(_throttle, clampf(throttle, 0.0, 1.0), THROTTLE_SMOOTHING)
	var pitch: float = profile.pitch_for(rpm) * _detune
	var level_db: float = volume_for(throttle, speed_mps) + (FOCUS_DB if focused else 0.0)
	pitch_scale = pitch
	# Equal-power crossfade; a far car keeps its drive loop at full weight so it does not fade out.
	volume_db = level_db + profile.on_gain_db + (linear_to_db(sqrt(maxf(_throttle, LAYER_MIN_WEIGHT))) if near else 0.0)
	_play_from_offset(self)
	var off_weight: float = 1.0 - _throttle
	if near and off_weight > LAYER_MIN_WEIGHT:
		off_layer.pitch_scale = pitch
		off_layer.volume_db = level_db + profile.off_gain_db + OFF_LAYER_DB + linear_to_db(sqrt(off_weight))
		_play_from_offset(off_layer)
	else:
		_mute(off_layer)
	var spooled: float = _throttle * clampf(inverse_lerp(EngineProfile.SIM_IDLE_RPM, EngineProfile.SIM_REDLINE_RPM, rpm), 0.0, 1.0)
	if near and profile.turbo and spooled > LAYER_MIN_WEIGHT:
		turbo_layer.pitch_scale = lerpf(0.6, TURBO_PITCH_MAX, spooled) * _detune
		turbo_layer.volume_db = level_db + TURBO_DB + linear_to_db(spooled)
		_play_from_offset(turbo_layer)
	else:
		_mute(turbo_layer)
	_check_lift(throttle, speed_mps, near)


func _mute(player: AudioStreamPlayer3D) -> void:
	player.volume_db = SILENT_DB
	if player.playing:
		player.stop()


func _play_from_offset(player: AudioStreamPlayer3D) -> void:
	if not player.playing and player.is_inside_tree() and player.stream != null:
		player.play(_offset_fraction * player.stream.get_length())


func _check_lift(throttle: float, speed_mps: float, near: bool) -> void:
	if throttle > LIFT_HIGH:
		_lift_armed = true
	elif throttle < LIFT_LOW and _lift_armed:
		_lift_armed = false
		if near and speed_mps > LIFT_MIN_SPEED_MPS:
			lifts_triggered += 1
			_fire(BLOW_OFF_STREAM if profile.turbo else OVERRUN_STREAM)


## Feed the sim gear every frame; a higher gear than last time is an upshift and cracks the exhaust.
func on_gear_changed(gear: int) -> void:
	if _last_gear >= 0 and gear > _last_gear:
		trigger_backfire()
	_last_gear = gear


func trigger_backfire() -> void:
	pops_triggered += 1
	backfire_triggered.emit()
	_fire(UPSHIFT_STREAM)


func _fire(one_shot_stream: AudioStream) -> void:
	if one_shot == null:
		return
	one_shot.stream = one_shot_stream
	one_shot.pitch_scale = _detune
	if one_shot.is_inside_tree():
		one_shot.play()


func silence() -> void:
	for player: AudioStreamPlayer3D in [self, off_layer, turbo_layer]:
		if player != null and player.playing:
			player.stop()
