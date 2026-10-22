class_name SpatialCarAudio
extends Node3D

## The three 3D voices of one car (FASE 6), mounted on GtCarActor: engine note, tyre squeal
## and kerb rumble on the SFX bus. The actor calls update_from_car() once per frame.

const KERB_STREAM := preload("res://assets/audio/sfx/kerb_rumble.wav")

## Past this offset from the racing line the wheels are on the kerb.
const KERB_LATERAL_M: float = 5.2
const KERB_MIN_SPEED_MPS: float = 20.0
const KERB_VOLUME_DB: float = -10.0
const PARKED_SPEED_MPS: float = 0.5

@onready var engine: EngineAudio3D = $Engine
@onready var tire: TireAudio3D = $Tire
@onready var kerb: AudioStreamPlayer3D = $Kerb


func _ready() -> void:
	kerb.bus = &"SFX"
	kerb.max_distance = 60.0
	kerb.volume_db = KERB_VOLUME_DB
	kerb.stream = EngineAudio3D.looped(KERB_STREAM)


## `audible` is false at high time scales, where a field of 20 squealing cars is just noise.
func update_from_car(car: GtCar, audible: bool = true) -> void:
	if not audible or car.is_dnf:
		engine.silence()
		tire.update_tire_audio(0.0, false)
		kerb.stop()
		return
	var parked: bool = car.v < PARKED_SPEED_MPS
	engine.update_engine_audio(EngineAudio3D.IDLE_RPM if parked else car.rpm, 0.0 if parked else car.throttle, car.v)
	engine.on_gear_changed(car.gear)
	tire.update_tire_audio(car.lateral_g, TireAudio3D.is_lockup(car))
	var on_kerb: bool = absf(car.lateral) > KERB_LATERAL_M and car.v > KERB_MIN_SPEED_MPS and car.pit == null
	if on_kerb and not kerb.playing:
		kerb.play()
	elif not on_kerb and kerb.playing:
		kerb.stop()
