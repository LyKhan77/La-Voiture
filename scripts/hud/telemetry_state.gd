class_name TelemetryState
extends RefCounted

## Everything the concept F telemetry drawer shows, as plain data: the live values of the followed car,
## the scrolling pedal and G traces, the onomatopoeia raised by rising edges (hard braking, an upshift,
## DRS opening, a tyre passing 125 C, ERS overtake) and the one-line story caption. No nodes: the
## drawer paints from this, and tests read it headless. Call `update` at a steady rate (one trace
## sample per call) and `advance` every frame.

const T = preload("res://scripts/ui/ui_theme_tokens.gd")

const PEDAL_SAMPLES: int = 96
const G_TRAIL: int = 40
const POP_LIFETIME_S: float = 1.6
const MAX_POPS: int = 2
const RPM_IDLE: float = 4000.0
const RPM_LIMIT: float = 8800.0
const LIMITER_FROM: float = 0.96
const BRAKE_EDGE: float = 0.55
const BRAKE_STORY: float = 0.5
const CRITICAL_TEMP: float = 125.0
const STRESS_STORY: float = 80.0
const POP_TEXT: Dictionary = {"brake": "GUOOO!!", "shift": "KACHA!", "drs": "VWOOOM!", "tyre": "JIRI JIRI", "ers": "DON!!"}
const TYPE_CPS: float = 42.0
const WHEEL_CODE: Array[String] = ["FL", "FR", "RL", "RR"]

var car_id: int = -1
var header_text: String = ""
var gear: int = 1
var speed_kmh: float = 0.0
var rpm: float = 0.0 # 0..1 between idle and the limiter
var limiter: bool = false
var drs: int = 0 # 0 off, 1 eligible, 2 open
var throttle: PackedFloat32Array = PackedFloat32Array()
var brake: PackedFloat32Array = PackedFloat32Array()
var g_trail: Array[Vector2] = [] # (lateral G, longitudinal G): braking is positive
var heat: PackedFloat64Array = PackedFloat64Array([90.0, 90.0, 90.0, 90.0]) # FL FR RL RR
var heat_tint: Array[Color] = []
var blown: int = -1
var tread: float = 1.0 # life left, 0..1
var blister: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var disc_temp: PackedFloat64Array = PackedFloat64Array([350.0, 350.0, 350.0, 350.0])
var ers_mode: int = GtTypes.ErsMode.NEUTRAL
var ers_charge: float = 1.0
var stress: float = 0.0
var confidence: float = 1.0
var heart_rate: float = 125.0
var damage: float = 0.0
var fuel: float = 1.0 # laps of fuel left over the race length, 0..1
var caption: String = ""
## Characters of the caption shown so far (typewriter); restarts when the story changes.
var caption_chars: float = 0.0
## {"text": String, "kind": String, "born": float (clock)}, oldest first, at most MAX_POPS.
var pops: Array[Dictionary] = []
var clock: float = 0.0
## Clock value of the last upshift (the gear numeral kicks for 0.3 s after it).
var shift_time: float = -10.0

var _prev: Dictionary = {}
var _typed: String = ""


## Reads one sample from the car. A different car starts with fresh traces, no pops and no edge memory.
func update(car: GtCar, laps: int) -> void:
	var fresh: bool = car.id != car_id
	if fresh:
		car_id = car.id
		throttle.resize(PEDAL_SAMPLES)
		throttle.fill(0.0)
		brake.resize(PEDAL_SAMPLES)
		brake.fill(0.0)
		g_trail.clear()
		pops.clear()
		_prev.clear()
	header_text = "#%02d %s // LIVE 60Hz" % [car.number, car.code]
	gear = car.gear
	speed_kmh = car.speed_kmh()
	rpm = clampf((car.rpm - RPM_IDLE) / (RPM_LIMIT - RPM_IDLE), 0.0, 1.0)
	limiter = rpm > LIMITER_FROM
	drs = 2 if car.drs_active else (1 if car.drs_eligible else 0)
	_push(throttle, car.throttle)
	_push(brake, car.brake)
	g_trail.append(Vector2(car.lateral_g, car.longitudinal_g))
	if g_trail.size() > G_TRAIL:
		g_trail.pop_front()
	heat = car.wheel_temp.duplicate()
	blown = car.punctured_wheel if car.is_punctured else -1
	heat_tint.clear()
	for index: int in range(WHEEL_CODE.size()):
		heat_tint.append(T.ACCENT_ANIME_CRIMSON if index == blown else TelemetryWidgets.tyre_tint(heat[index]))
	tread = clampf(1.0 - car.wear, 0.0, 1.0)
	blister = car.wheel_blister_pct.duplicate()
	disc_temp = car.wheel_brake_temp.duplicate()
	ers_mode = car.ers_mode
	ers_charge = clampf(car.ers_battery / 100.0, 0.0, 1.0)
	stress = clampf(car.driver_stress / 100.0, 0.0, 1.0)
	confidence = clampf(car.driver_confidence / 100.0, 0.0, 1.0)
	heart_rate = maxf(car.driver_heart_rate, 0.0)
	damage = clampf(car.damage / 100.0, 0.0, 1.0)
	fuel = clampf(car.fuel / maxf(car.fuel_burn_rate, 0.01) / float(maxi(laps, 1)), 0.0, 1.0)
	caption = caption_for(car)
	if caption != _typed:
		_typed = caption
		caption_chars = 0.0
	_raise_pops(car)


## Advances the animation clock and drops onomatopoeia older than POP_LIFETIME_S.
func advance(delta: float) -> void:
	clock += delta
	caption_chars = minf(float(caption.length()), caption_chars + TYPE_CPS * delta)
	for index: int in range(pops.size() - 1, -1, -1):
		if clock - float(pops[index]["born"]) > POP_LIFETIME_S:
			pops.remove_at(index)


## The one-line story, by priority: driver at the limit, a critical tyre, ERS overtake, hard braking,
## DRS open, otherwise a clean lap.
static func caption_for(car: GtCar) -> String:
	if car.driver_stress >= STRESS_STORY:
		return "HEART RACING — DRIVER AT THE LIMIT…"
	var hottest: int = 0
	for index: int in range(1, WHEEL_CODE.size()):
		if car.wheel_temp[index] > car.wheel_temp[hottest]:
			hottest = index
	if car.wheel_temp[hottest] > CRITICAL_TEMP:
		return "%s TYRE %d°C — GRIP FADING AT THE %s…" % [WHEEL_CODE[hottest], roundi(car.wheel_temp[hottest]), "REAR" if hottest >= 2 else "FRONT"]
	if car.ers_mode == GtTypes.ErsMode.OVERTAKE:
		return "OVERTAKE DEPLOYED — ALL ENERGY, ALL IN!"
	if car.brake > BRAKE_STORY:
		return "HARD ON THE BRAKES — DISCS GLOWING…"
	if car.drs_active:
		return "DRS OPEN — FULL SEND DOWN THE STRAIGHT."
	return "CLEAN LAP. PACE STEADY, TYRES IN THE WINDOW."


static func _push(samples: PackedFloat32Array, value: float) -> void:
	samples.remove_at(0)
	samples.append(clampf(value, 0.0, 1.0))


## Onomatopoeia on rising edges only; the first sample of a car just records the edge memory.
func _raise_pops(car: GtCar) -> void:
	var braking: bool = car.brake > BRAKE_EDGE
	var overtaking: bool = car.ers_mode == GtTypes.ErsMode.OVERTAKE
	var critical: Array[bool] = []
	for index: int in range(WHEEL_CODE.size()):
		critical.append(car.wheel_temp[index] > CRITICAL_TEMP)
	if not _prev.is_empty():
		if braking and not bool(_prev["braking"]):
			_add_pop("brake")
		if car.gear > int(_prev["gear"]):
			_add_pop("shift")
		if car.drs_active and not bool(_prev["drs"]):
			_add_pop("drs")
		if overtaking and not bool(_prev["overtaking"]):
			_add_pop("ers")
		var was_critical: Array = _prev["critical"]
		var newly_critical: bool = false
		for index: int in range(critical.size()):
			newly_critical = newly_critical or (critical[index] and not bool(was_critical[index]))
		if newly_critical:
			_add_pop("tyre") # one call-out per sample, even when two tyres cross together
	_prev = {"braking": braking, "gear": car.gear, "drs": car.drs_active, "overtaking": overtaking, "critical": critical}


func _add_pop(kind: String) -> void:
	if kind == "shift":
		shift_time = clock
	pops.append({"text": String(POP_TEXT[kind]), "kind": kind, "born": clock})
	while pops.size() > MAX_POPS:
		pops.pop_front()
