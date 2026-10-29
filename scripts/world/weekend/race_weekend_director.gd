class_name RaceWeekendDirector
extends RefCounted

## Race weekend flow (FASE 5.5): grid line-up, the five red lights, lights out,
## green racing, safety car, chequered flag and podium. Time-driven by
## advance(dt) so a test or the 3D world steps it the same way. The director
## never touches the sim; the world holds the engine until is_racing() and
## reads lights_on() to drive the gantry.

signal state_changed(state: int)
signal light_lit(count: int) # 1..5 as each red light comes on
signal lights_out

enum State { GRID_LINEUP, LIGHTS_COUNTDOWN, LIGHTS_HOLD, GREEN_RACING, SAFETY_CAR, CHEQUERED_FLAG, PODIUM }

const STATE_NAMES: Array[String] = [
	"GRID LINE-UP", "LIGHTS COUNTDOWN", "LIGHTS HOLD", "GREEN FLAG", "SAFETY CAR", "CHEQUERED FLAG", "PODIUM",
]
const LIGHT_COUNT: int = 5
const LIGHT_INTERVAL_S: float = 1.0
const HOLD_MIN_S: float = 0.5
const HOLD_MAX_S: float = 2.0
const GRID_LINEUP_S: float = 3.0
const PODIUM_DELAY_S: float = 8.0

## Grid slot layout: two columns staggered along the track, like the sim's grid.
const GRID_ROW_SPACING_M: float = 10.0
const GRID_COLUMN_OFFSET_M: float = 2.5

var state: int = State.GRID_LINEUP
var state_time_s: float = 0.0
var lights_lit: int = 0
var hold_duration_s: float = 0.0
var race_started_at_s: float = -1.0 # seconds since the director was created
var clock_s: float = 0.0
var rng := RandomNumberGenerator.new()


func _init(p_seed: int = 0) -> void:
	if p_seed != 0:
		rng.seed = p_seed
	else:
		rng.randomize()


## Starts the countdown early; GRID_LINEUP otherwise runs its own timer.
func begin_countdown() -> void:
	if state == State.GRID_LINEUP:
		_enter(State.LIGHTS_COUNTDOWN)


func advance(dt: float) -> void:
	clock_s += dt
	state_time_s += dt
	match state:
		State.GRID_LINEUP:
			if state_time_s >= GRID_LINEUP_S:
				_enter(State.LIGHTS_COUNTDOWN)
		State.LIGHTS_COUNTDOWN:
			var due: int = mini(LIGHT_COUNT, int(state_time_s / LIGHT_INTERVAL_S + 1.0e-6))
			while lights_lit < due:
				lights_lit += 1
				light_lit.emit(lights_lit)
			if lights_lit >= LIGHT_COUNT:
				hold_duration_s = rng.randf_range(HOLD_MIN_S, HOLD_MAX_S)
				_enter(State.LIGHTS_HOLD)
		State.LIGHTS_HOLD:
			if state_time_s >= hold_duration_s:
				lights_lit = 0
				race_started_at_s = clock_s
				lights_out.emit()
				_enter(State.GREEN_RACING)
		State.CHEQUERED_FLAG:
			if state_time_s >= PODIUM_DELAY_S:
				_enter(State.PODIUM)


## Called by the world every frame with what the race control reports.
func update_race(safety_car_active: bool, race_finished: bool) -> void:
	if race_finished:
		if state != State.CHEQUERED_FLAG and state != State.PODIUM:
			_enter(State.CHEQUERED_FLAG)
	elif safety_car_active and state == State.GREEN_RACING:
		_enter(State.SAFETY_CAR)
	elif not safety_car_active and state == State.SAFETY_CAR:
		_enter(State.GREEN_RACING)


## True from LIGHTS OUT until the chequered flag: the engine may run.
func is_racing() -> bool:
	return state == State.GREEN_RACING or state == State.SAFETY_CAR


## Lamps lit right now, 0..5 (all dark once the lights are out).
func lights_on() -> int:
	return lights_lit


func get_state_name() -> String:
	return STATE_NAMES[state]


## Grid slot for car `index`: distance behind the line and lateral offset
## (negative = left of the racing line), alternating columns.
static func grid_slot(index: int) -> Dictionary:
	return {
		"distance_m": -GRID_ROW_SPACING_M * float(index + 1),
		"lateral_m": -GRID_COLUMN_OFFSET_M if index % 2 == 0 else GRID_COLUMN_OFFSET_M,
	}


func _enter(next: int) -> void:
	state = next
	state_time_s = 0.0
	state_changed.emit(state)
