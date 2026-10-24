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
const FLAG_NAME: Array[String] = ["GREEN", "YELLOW", "VSC", "SC"]
const FUEL_STAGE_NAME: Array[String] = ["OPTIMAL", "WARNING", "SPUTTER", "LIMP", "FLAMEOUT"]

## Fixed sim tick. The reference runs 20 Hz; the world interpolates between ticks.
const TICK_DT: float = 0.05
const TICK_RATE: int = 20

const ACCEL: float = 6.8
const BRAKE: float = 16.5
const PIT_SPEED: float = 22.0 # 80 km/h limiter
const PIT_STOP_TIME: float = 3.2
const FOLLOW_GAP: float = 18.0

const CAR_LENGTH_M: float = 4.45
const CAR_WIDTH_M: float = 2.08


static func is_slick(compound: int) -> bool:
	return compound <= Compound.HARD
