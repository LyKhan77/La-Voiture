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
