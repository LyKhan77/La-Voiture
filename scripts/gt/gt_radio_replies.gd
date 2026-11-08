class_name GtRadioReplies
extends RefCounted

## What the race engineer answers to a driver's call, from the car's own state at the moment the answer is
## due (tyre life, the track water): the answer reports facts and leaves the box call to the pit wall desk,
## so it also fits MANUAL mode. "" means the call has no answer.


static func reply_for(text: String, car: GtCar, water_pct: float) -> String:
	var life: int = roundi((1.0 - car.wear) * 100.0)
	if text.begins_with("Had a snap of oversteer"):
		return "Copy %s, stay on it. Rear tyres at %d%%, watch the exit." % [car.code, life]
	if text.begins_with("Tyres are cooked"):
		return "Copy %s, tyres at %d%%. Manage the pace, the box call is yours." % [car.code, life]
	if text.begins_with("Track is flooding"):
		return "Understood %s, water at %d%%. Box for WETS when you are ready." % [car.code, roundi(water_pct)]
	if text.begins_with("Puncture"):
		return "Copy %s, limp it back to the pits, box box box." % car.code
	return ""


## Own random stream for the choice between two ways of saying the same thing: the race's stream is never touched.
const ACK_SALT: int = 0x6A09E667

const ACK_BOX: Array[String] = ["Copy, box this lap.", "Understood, coming in."]
const ACK_LAST_LAP: Array[String] = ["Last lap, copy. Bringing it home.", "Copy. Everything I have left."]
const ACK_FUEL: String = "Copy, fuel is tight. Coming in."
const ACK_MISSED: String = "Understood. We take the penalty."
const ACK_STOP_OK: String = "Copy, the stop counts."
const ACK_STOP_NO: String = "Understood. I need another stop."
const ACK_STEWARD: String = "Copy. I will serve it in the pits."
const ACK_BATTERY: String = "Copy, harvesting."
const ACK_PENALTY_NOTE: String = "Understood. I should have boxed."
const FINISH_WIN: String = "Yes! We did it! Thank you, team!"
const FINISH_PODIUM: String = "Podium! Great job, everyone!"
const FINISH_OTHER: String = "Chequered flag. Good effort, team."


## What the driver says back to an engineer call, "" when the call needs no answer. `key` (the radio counter) only
## picks between equivalent wordings, from a stream of its own so one seed always gives the same race.
static func driver_ack(text: String, car: GtCar, race_seed: int, key: int) -> String:
	if text.begins_with("Box this lap, confirm") or text.begins_with("Window closes in two laps"):
		return _pick(ACK_BOX, car, race_seed, key)
	if text.begins_with("Last lap."):
		return _pick(ACK_LAST_LAP, car, race_seed, key)
	if text.begins_with("Fuel is short."):
		return ACK_FUEL
	if text.begins_with("Window missed."):
		return ACK_MISSED
	if text.begins_with("Stop counts."):
		return ACK_STOP_OK
	if text.begins_with("That stop does not count"):
		return ACK_STOP_NO
	if text.begins_with("Steward penalty:"):
		return ACK_STEWARD
	if text.begins_with("Battery is low."):
		return ACK_BATTERY
	if text.begins_with("Penalty added for the missed mandatory stop"):
		return ACK_PENALTY_NOTE
	if text.begins_with("Chequered flag! P") and car.mandatory_penalty_s <= 0.0:
		var place: int = int(text.get_slice("P", 1).get_slice(".", 0))
		if place == 1:
			return FINISH_WIN
		return FINISH_PODIUM if place <= 3 else FINISH_OTHER
	return ""


## Every line a driver can answer with, for the voice generator and the clip test.
static func ack_texts() -> Array[String]:
	var all: Array[String] = []
	all.append_array(ACK_BOX)
	all.append_array(ACK_LAST_LAP)
	all.append_array([ACK_FUEL, ACK_MISSED, ACK_STOP_OK, ACK_STOP_NO, ACK_STEWARD, ACK_BATTERY, ACK_PENALTY_NOTE, FINISH_WIN, FINISH_PODIUM, FINISH_OTHER])
	return all


static func _pick(options: Array[String], car: GtCar, race_seed: int, key: int) -> String:
	var stream := GtRng.new(((race_seed * 1103515245) ^ ((car.id * 977 + key + 1) * 0x9E3779B1) ^ ACK_SALT) & 0x7FFFFFFF)
	return options[stream.range_int(0, options.size() - 1)]
