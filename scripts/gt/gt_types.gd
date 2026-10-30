class_name GtTypes
extends RefCounted

## Enums and constants of the GT sim, a GDScript port of gt-manager's `types.ts`
## and the constants at the top of `race.ts`. Names are La Voiture's, numbers are the
## reference's unless a comment says otherwise.

enum Compound { SOFT, MEDIUM, HARD, INTERMEDIATE, WET }
enum PaceMode { CONSERVE, LIGHT, STANDARD, AGGRESSIVE, ATTACK }
enum FuelMode { CONSERVE, STANDARD, PUSH }
enum ErsMode { HARVEST, NEUTRAL, DEPLOY, OVERTAKE }
enum TacticMode { MANUAL, AUTO }
enum Flag { GREEN, YELLOW, VSC, SC }
enum FuelStage { OPTIMAL, WARNING, SPUTTER, LIMP, FLAMEOUT }
enum Overtake { NONE, ATTACKING, DEFENDING, YIELDING }
enum PitPhase { ENTRY, IN, BOX, OUT, EXIT }
enum SafetyCarPhase { HIDDEN, DEPLOYED, IN_THIS_LAP }
enum SectorColor { NONE, PURPLE, GREEN, YELLOW }
enum CollisionKind { RUB, MINOR, HEAVY }
enum TacticType { PIT, PACE, FUEL, ERS }
enum Wheel { FL, FR, RL, RR }

const COMPOUND_GRIP: Array[float] = [1.0, 0.97, 0.94, 0.91, 0.87]
const COMPOUND_WEAR_PER_LAP: Array[float] = [0.045, 0.032, 0.022, 0.028, 0.024]
const COMPOUND_LABEL: Array[String] = ["S", "M", "H", "I", "W"]
const COMPOUND_NAME: Array[String] = ["SOFT", "MEDIUM", "HARD", "INTERMEDIATE", "WET"]
const COMPOUND_COLOR: Array[Color] = [
	Color("#f85149"), Color("#e3b341"), Color("#f0f6fc"), Color("#3fb950"), Color("#38bdf8"),
]
const PACE_NAME: Array[String] = ["CONSERVE", "LIGHT", "STANDARD", "AGGRESSIVE", "ATTACK"]
const FUEL_NAME: Array[String] = ["CONSERVE", "STANDARD", "PUSH"]
const ERS_NAME: Array[String] = ["HARVEST", "NEUTRAL", "DEPLOY", "OVERTAKE"]
## Multipliers by PaceMode (CONSERVE..ATTACK): speed, tyre wear, fuel burn, and the tyre temperature the pace aims at.
const PACE_SPEED_MULT: Array[float] = [0.948, 0.978, 1.0, 1.025, 1.048]
const PACE_WEAR_MULT: Array[float] = [0.45, 0.72, 1.0, 1.45, 2.1]
const PACE_FUEL_MULT: Array[float] = [0.85, 0.93, 1.0, 1.12, 1.25]
const PACE_TARGET_TEMP: Array[float] = [80.0, 86.0, 92.0, 104.0, 116.0]
## Fuel burn multiplier by FuelMode (CONSERVE, STANDARD, PUSH).
const FUEL_MODE_BURN_MULT: Array[float] = [0.80, 1.0, 1.25]
## ERS battery per second while deploying (index ErsMode: DEPLOY and OVERTAKE only), and harvest charge per second.
const ERS_DRAIN_PER_S: Array[float] = [0.0, 0.0, 12.0, 24.0]
const ERS_HARVEST_PER_S: float = 4.0
## Tyre wear past which grip falls off a cliff (and the driver calls it).
const TYRE_CLIFF_WEAR: float = 0.75
const FLAG_NAME: Array[String] = ["GREEN", "YELLOW", "VSC", "SC"]
const FUEL_STAGE_NAME: Array[String] = ["OPTIMAL", "WARNING", "SPUTTER", "LIMP", "FLAMEOUT"]

## Fixed sim tick. The reference runs 20 Hz; the world interpolates between ticks.
const TICK_DT: float = 0.05
const TICK_RATE: int = 20

const ACCEL: float = 6.8
const BRAKE: float = 16.5
const PIT_SPEED: float = 22.0 # 80 km/h limiter
const PIT_STOP_TIME: float = 3.2
## Braking a car plans for on the pit lane: queues slow down like traffic, they never stop dead.
const PIT_COMFORT_DECEL: float = 5.0
## Hardest braking a pit car ever applies (a firm stop, not the old instant one).
const PIT_BRAKE_MAX: float = 9.0
## Bumper-to-bumper room a pit car keeps to the car ahead; teammates stack on a centre-to-centre gap.
const PIT_FOLLOW_GAP_M: float = 2.0
const PIT_TEAMMATE_GAP_M: float = 8.0
## A pit car already inside its following gap slows this many m/s below the car ahead per metre of deficit.
const PIT_GAP_RECOVERY_GAIN: float = 1.5
## A box release waits at most this long for the fast lane behind to clear; a car held still this long
## by traffic stops yielding to it (nothing may keep a pit scene stuck).
const PIT_RELEASE_WAIT_MAX_S: float = 12.0
## Nothing holds a serviced car in its box longer than this, not even a stream of cars on the fast lane.
const PIT_RELEASE_HARD_CAP_S: float = 20.0
## A car pulling out waits this long, outside the fast lane's band, for the cars on it to pass before it merges anyway.
const PIT_MERGE_WAIT_MAX_S: float = 12.0
const PIT_STALL_FAILSAFE_S: float = 15.0
const FOLLOW_GAP: float = 18.0

const CAR_LENGTH_M: float = 4.45
const CAR_WIDTH_M: float = 2.08


static func is_slick(compound: int) -> bool:
	return compound <= Compound.HARD
