class_name GtPit
extends RefCounted

## Pit visit of one car (reference `PitState`).

var phase: int = GtTypes.PitPhase.ENTRY
var start_s: float = 0.0
var box_s: float = 0.0
var timer: float = 0.0
var compound: int = GtTypes.Compound.SOFT
var duration: float = GtTypes.PIT_STOP_TIME
var lift_y: float = 0.0
var wheel_swap_progress: float = 0.0
var repairing_damage: bool = false
var initial_damage: float = 0.0
var initial_fuel: float = 0.0
## Total race time the car spent from entry to exit, for the pit wall.
var elapsed: float = 0.0
