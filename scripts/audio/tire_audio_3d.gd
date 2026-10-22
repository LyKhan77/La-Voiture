class_name TireAudio3D
extends AudioStreamPlayer3D

## Spatial tyre squeal of one GT3 (FASE 6): it sounds while the car pulls more than 1.8 G
## sideways or has a locked wheel, louder the harder it pushes, and stops on a relaxed drive.

const SCREECH_STREAM := preload("res://assets/audio/sfx/tire_screech.wav")

const LATERAL_G_LIMIT: float = 1.8
const VOLUME_BASE_DB: float = -24.0
const VOLUME_PER_G_DB: float = 12.0
const VOLUME_MIN_DB: float = -28.0
const VOLUME_MAX_DB: float = 0.0
const HEARING_RANGE_M: float = 80.0
## Same test as the tyre smoke: full brake at speed.
const LOCKUP_BRAKE: float = 0.95
const LOCKUP_MIN_SPEED_MPS: float = 35.0

var screeching: bool = false


func _ready() -> void:
	bus = &"SFX"
	max_distance = HEARING_RANGE_M
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	stream = EngineAudio3D.looped(SCREECH_STREAM)


static func is_lockup(car: GtCar) -> bool:
	return (car.brake > LOCKUP_BRAKE and car.v > LOCKUP_MIN_SPEED_MPS) or car.spin_timer > 0.0


static func volume_for(lateral_g: float) -> float:
	return clampf(VOLUME_BASE_DB + (absf(lateral_g) - LATERAL_G_LIMIT) * VOLUME_PER_G_DB, VOLUME_MIN_DB, VOLUME_MAX_DB)


func update_tire_audio(lateral_g: float, is_locked: bool) -> void:
	if absf(lateral_g) > LATERAL_G_LIMIT or is_locked:
		screeching = true
		if not playing:
			play()
		volume_db = volume_for(lateral_g)
	else:
		screeching = false
		if playing:
			stop()
