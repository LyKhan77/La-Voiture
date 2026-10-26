class_name GtStewards
extends RefCounted

## Steward penalty lite: GtContacts reports the contacts that matter, a case stays open for INVESTIGATION_S and
## then ends in a +5 s time penalty for the car that caused it or no further action. Deterministic: it draws no
## random numbers, so one race seed always gives the same cases. The penalty is served in the box (GtDriving holds
## the stopped car before the crew works) or, if the car never pits again, added to its time on the podium.

enum Kind { AT_FAULT, RACING_INCIDENT }
enum Verdict { PENDING, NO_ACTION, PENALTY }

const INVESTIGATION_S: float = 10.0
const PENALTY_S: float = 5.0
## Closing speed above which a nose-to-tail hit is the rear car's fault; at or below it is a racing incident.
const AT_FAULT_CLOSING_MPS: float = 2.8
## The same pair is not investigated again for this long.
const PAIR_COOLDOWN_S: float = 20.0
## No cases while the field is still sorting itself out after the standing start (the pack concertinas there).
const START_GRACE_S: float = 45.0
## The same car is not investigated again for this long, however often the pack bunches up behind it.
const OFFENDER_COOLDOWN_S: float = 60.0

var race: GtRace
## One entry per case: {id, kind, verdict, offender_id, other_id, opened_at, verdict_at, text}.
var cases: Array[Dictionary] = []

var _counter: int = 0
var _pair_last: Dictionary = {} # "a_b" -> race time of the last case
var _offender_last: Dictionary = {} # car id -> race time of the last case against it


func _init(p_race: GtRace) -> void:
	race = p_race


## The car behind hit the car in front nose to tail at `closing` m/s (positive = closing). Only a hit harder than
## AT_FAULT_CLOSING_MPS is looked at; a touch is not an incident.
func report_nose_to_tail(rear: GtCar, front: GtCar, closing: float) -> void:
	if closing <= AT_FAULT_CLOSING_MPS or front.spin_timer > 0.0 or front.is_punctured or _under_caution():
		return
	_open(Kind.AT_FAULT, rear, front)


## Safety car and virtual safety car bunch the field up; a hit there is not judged as a racing offence.
func _under_caution() -> bool:
	var flag: int = int(race.race_control["flag"])
	return flag == GtTypes.Flag.SC or flag == GtTypes.Flag.VSC


## A heavy contact that is nobody's rear-end hit (door to door): stewards look, and take no action.
func report_racing_incident(car_a: GtCar, car_b: GtCar) -> void:
	_open(Kind.RACING_INCIDENT, car_a, car_b)


func _open(kind: int, offender: GtCar, other: GtCar) -> void:
	var key: String = "%d_%d" % [mini(offender.id, other.id), maxi(offender.id, other.id)]
	if race.time < START_GRACE_S or race.time - float(_pair_last.get(key, -999.0)) < PAIR_COOLDOWN_S \
			or race.time - float(_offender_last.get(offender.id, -999.0)) < OFFENDER_COOLDOWN_S:
		return
	_pair_last[key] = race.time
	_offender_last[offender.id] = race.time
	_counter += 1
	var text: String
	if kind == Kind.AT_FAULT:
		text = "/// STEWARDS: INCIDENT INVOLVING CAR #%d UNDER INVESTIGATION" % offender.number
	else:
		text = "/// STEWARDS: INCIDENT INVOLVING CARS #%d & #%d UNDER INVESTIGATION" % [offender.number, other.number]
	var case_file: Dictionary = {
		"id": _counter, "kind": kind, "verdict": Verdict.PENDING, "offender_id": offender.id, "other_id": other.id,
		"opened_at": race.time, "verdict_at": race.time + INVESTIGATION_S, "text": text,
	}
	cases.append(case_file)
	race.steward_event.emit({"phase": "investigation", "case_id": _counter, "kind": kind, "car_id": offender.id, "text": text, "time": race.time})


## Closes the cases whose investigation time is up. Called once per race tick.
func step() -> void:
	for case_file: Dictionary in cases:
		if int(case_file["verdict"]) == Verdict.PENDING and race.time >= float(case_file["verdict_at"]):
			_decide(case_file)


## The race is over: every case still open gets its verdict now, before the order is read.
func close_all() -> void:
	for case_file: Dictionary in cases:
		if int(case_file["verdict"]) == Verdict.PENDING:
			_decide(case_file)


func _decide(case_file: Dictionary) -> void:
	var offender: GtCar = race.get_car(int(case_file["offender_id"]))
	var text: String = "NO FURTHER ACTION - RACING INCIDENT"
	case_file["verdict"] = Verdict.NO_ACTION
	if int(case_file["kind"]) == Kind.AT_FAULT and offender != null:
		offender.penalty_owed_s += PENALTY_S
		case_file["verdict"] = Verdict.PENALTY
		text = "+%ds TIME PENALTY // CAR #%d: CAUSING A COLLISION" % [int(PENALTY_S), offender.number]
	case_file["text"] = text
	race.steward_event.emit({
		"phase": "verdict", "case_id": case_file["id"], "kind": case_file["kind"], "verdict": case_file["verdict"],
		"car_id": int(case_file["offender_id"]), "text": text, "time": race.time,
	})
