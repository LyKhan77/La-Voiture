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
## Steward penalty taken on arrival in the box: the stopped car waits this long before the crew starts work.
var penalty_hold_s: float = 0.0
var penalty_taken: bool = false
## Total race time the car spent from entry to exit, for the pit wall.
var elapsed: float = 0.0
## Seconds the finished stop waited for the fast lane behind to clear before the car pulled out.
var release_wait_s: float = 0.0
## True while the finished stop waits in the box for the lane to clear: the crew holds the lollipop red.
var holding_release: bool = false
## Seconds the car sat still with nothing but traffic to blame; past the failsafe it stops yielding.
var stalled_s: float = 0.0
