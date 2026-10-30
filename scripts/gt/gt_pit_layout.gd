class_name GtPitLayout
extends RefCounted

## The pit lane layout a GtRace is raced with when its circuit does not publish one, plus the garage setback the pit
## crew choreography falls back on. These are the Apex Ring's own 410 m lane: ApexPitComplex builds its lane from these
## constants, so the sim never has to know a circuit's scripts.

const ENTRY_S: float = 3900.0
const EXIT_S: float = 150.0
const STALL_FIRST_S: float = 3925.0
const STALL_PITCH_M: float = 14.0
const STALL_LANE_M: float = 17.0
const FAST_LANE_M: float = 11.6
const EDGE_LATERAL_M: float = 5.2
const QUEUE_GAP_M: float = 8.0
const RAMP_IN_M: float = 80.0
const RAMP_OUT_M: float = 90.0
## How far the garage front stands from the racing line.
const GARAGE_FRONT_M: float = 20.6


static func default_layout() -> Dictionary:
	return {
		"entry_s": ENTRY_S,
		"exit_s": EXIT_S,
		"stall_first_s": STALL_FIRST_S,
		"stall_pitch_m": STALL_PITCH_M,
		"stall_lane_m": STALL_LANE_M,
		"fast_lane_m": FAST_LANE_M,
		"edge_lateral_m": EDGE_LATERAL_M,
		"queue_gap_m": QUEUE_GAP_M,
		"lane_ramp_in_m": RAMP_IN_M,
		"lane_ramp_out_m": RAMP_OUT_M,
	}
