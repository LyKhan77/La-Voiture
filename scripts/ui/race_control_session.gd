class_name RaceControlSession
extends "res://scripts/ui/pit_wall_session.gd"

## PitWallSession plus FASE 5 race control: weather, safety car and rival pit-wall
## AI tick with the sim, and their radio calls reach the pit wall. The base
## session and engine are untouched; this only swaps who steps the engine.

const RaceControlScript := preload("res://scripts/core/race_control.gd")

var control: RaceControlScript


func _ready() -> void:
	# Before super(): its first publish() already reaches the dashboard.
	control = RaceControlScript.new(engine)
	control.weather.set_schedule(RaceControlScript.DEMO_SCHEDULE)
	control.radio.connect(_on_control_radio)
	super()


func _process(delta: float) -> void:
	if not paused:
		control.process_frame(delta)
	_elapsed += delta
	if _elapsed >= 0.1:
		_elapsed = 0.0
		publish()


func _on_control_radio(message: String, urgent: bool) -> void:
	# Team-wide calls go out on the lead car's channel.
	radio_transmission.emit(0, message, urgent)
