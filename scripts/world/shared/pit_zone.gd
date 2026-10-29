class_name PitZone
extends RefCounted

static func from_layout(layout: Dictionary, lap_length_m: float, lead_m: float = 20.0, trail_m: float = 40.0) -> Dictionary:
	var entry: float = float(layout["entry_s"])
	var exit: float = float(layout["exit_s"])
	var lane: float = float(layout.get("lane_length_m", fposmod(exit - entry, lap_length_m)))
	return {"start_s": fposmod(entry - lead_m, lap_length_m), "length_m": lane + lead_m + trail_m, "entry_s": entry, "exit_s": exit}

static func contains(zone: Dictionary, s: float, lap_length_m: float) -> bool:
	return not zone.is_empty() and fposmod(s - float(zone["start_s"]), lap_length_m) < float(zone["length_m"])

static func outside_ranges(zone: Dictionary, lap_length_m: float) -> Array[Vector2]:
	if zone.is_empty():
		return [Vector2(0.0, lap_length_m)]
	var length: float = float(zone["length_m"])
	if length >= lap_length_m:
		return []
	var start: float = fposmod(float(zone["start_s"]), lap_length_m)
	var end: float = start + length
	if end <= lap_length_m:
		return [Vector2(0.0, start), Vector2(end, lap_length_m)]
	return [Vector2(end - lap_length_m, start)]
