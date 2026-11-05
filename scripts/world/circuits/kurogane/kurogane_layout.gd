class_name KuroganeLayout
extends RefCounted

## Single source of pitch/paddock/landmark numbers for the Kurogane Twin-Cross GP.
## Every value comes from designs/kurogane/final/blueprint.track.json (pit block,
## alignment, elevation, turns) and environment_strip.json, measured on the frozen
## centreline (geometry hash sha256:051118ec509272cf1dce82348ec5c153f784c82487dfee6e1dc3c26f13be77cd).
## Laterals are magnitudes; PIT_SIDE puts the pit complex on the driver's right.

const CIRCUIT_ID := "kurogane"
const LENGTH_M := 5800.0
const ROAD_HALF_M := 6.75
const ROAD_WIDTH_M := 13.5
const ROADBED_DROP_M := 0.16
const CURVE_PATH := "res://assets/tracks/kurogane/data/kurogane_curve.tres"

## Pit: entry 5600 m, exit 210 m -> 410 m lane through the start line, right of
## travel, 10 stalls @ 14 m. Blueprint fast lane: 8.5 m inner edge and 4.6 m width,
## so the sim's lane centre is 10.8 m and its outer edge 13.1 m.
const PIT_ENTRY_S := 5600.0
const PIT_EXIT_S := 210.0
const PIT_SIDE := 1.0
const PIT_FAST_LANE_INNER_M := 8.5
const PIT_FAST_LANE_M := 10.8
const PIT_EDGE_LATERAL_M := 5.2
const PIT_QUEUE_GAP_M := 8.0
const PIT_LANE_HALF_M := 2.3
const PIT_LANE_LENGTH_M := 410.0
const PIT_LANE_RAMP_IN_M := 80.0
const PIT_LANE_RAMP_OUT_M := 30.0
const PIT_STALL_COUNT := 10
const PIT_STALL_PITCH_M := 14.0
## First visible bay centre on the lap (bay i = 37 + 14 i).
const PIT_STALL_FIRST_S := 37.0
const PIT_LANE_OUTER_X := 13.1
const PIT_SERVICE_X := 16.5
const PIT_APRON_LIFT_M := 0.07

## Ten-bay FIA pit building: 10 stalls x 14 m pitch = 140 m span, centred on s = 100.
const PIT_BUILDING_CENTRE_S := 100.0
const PIT_FACADE_X := 20.6
const PIT_BUILDING_SPAN_M := 140.0
const PIT_SERVICE_BAY := 5
const PIT_SERVICE_STATION_S := 107.0
const PIT_STOP_SECONDS := 3.0

## Spec anchors (environment_strip.json): control tower s = 20 offset 25 on the pit
## side, grandstand s = 100 offset 22 on the left. The shared RaceControlTower mesh
## centres itself 24 m out in its own frame, so the node stands 1 m off the line.
const CONTROL_TOWER_S := 20.0
const CONTROL_TOWER_X := 25.0
const CONTROL_TOWER_NODE_X := 1.0
const GRANDSTAND_ANCHOR_S := 100.0
const GRANDSTAND_LENGTH_M := 240.0

## The compiled centreline crosses itself at plan (-260, 722): the Back Straight
## (s ~3924, y 37.8) flies 26 m above the climbing 200R/Spoon approach (s ~2752,
## y 11.6) at a 74 degree crossing angle. The blueprint's grade_separated_crossover
## s-ranges are stale metadata; these are the measured stations.
const CROSS_LOWER_S := 2752.0
const CROSS_UPPER_S := 3924.0
const CROSS_LOWER_RANGE := Vector2(2600.0, 2900.0)
const CROSS_UPPER_RANGE := Vector2(3800.0, 4150.0)
const TRENCH_HALF_FLAT_M := 20.0
const TRENCH_BLEND_M := 8.0

## Hero landmark stations (procedural-spec section 4, measured against the turn table).
const LANDMARK_BRIDGE_S := 3924.0
const LANDMARK_FERRIS_S := 1480.0
const LANDMARK_FERRIS_SIDE := -1.0
const LANDMARK_FERRIS_LATERAL_M := 175.0
const LANDMARK_TOWER_S := 4830.0
const LANDMARK_TOWER_SIDE := -1.0
const LANDMARK_TOWER_LATERAL_M := 62.0
const LANDMARK_SHRINE_S := 3800.0
const LANDMARK_SHRINE_SIDE := -1.0
const LANDMARK_SHRINE_LATERAL_M := 120.0
## The truss GLB is authored 100 m long; the model is scaled to the measured gap.
## The truss deck window the handoff measured on the frozen centreline (69 m): the stretch of the Back
## Straight the trench leaves without ground. The terrain reports its own measurement beside it.
const BRIDGE_SPAN_S := Vector2(3888.0, 3957.0)
const BRIDGE_MODEL_SPAN_M := 100.0
## Measured on the GLB (model space, before the span scale): the steel deck plate is 21.5 m wide, the two
## concrete piers stand 23.7-28.3 m either side of the middle, 21 m wide and 27 m deep.
const BRIDGE_DECK_HALF_M := 10.9
const BRIDGE_PIER_HALF_WIDTH_M := 10.5
const BRIDGE_PIER_Z := Vector2(23.7, 28.3)
const BRIDGE_PIER_DEPTH_M := 27.0

## Terrain: 12 m heightfield over the circuit plus a hillside backdrop.
const TERRAIN_STEP_M := 12.0
const TERRAIN_MIN_X := -940.0
const TERRAIN_MAX_X := 980.0
const TERRAIN_MIN_Z := -260.0
const TERRAIN_MAX_Z := 1340.0
const FIELD_STEP_M := 30.0
const COARSE_STEP_M := 16.0
const CORRIDOR_FLAT_M := 24.0
const CORRIDOR_BLEND_M := 46.0
const CORRIDOR_BLEND_END_M := 72.0

const TURN_COUNT := 20
const TURN_NAMES := [
	"T01 First Turn Entry", "T02 First Turn Apex", "T03 Ryu no Senkai 1", "T04 Ryu no Senkai 2",
	"T05 Ryu no Senkai 3", "T06 Ryu no Senkai 4", "T07 Dunlop Sweeper", "T08 Degner 1",
	"T09 Degner 2", "T10 Underpass Trench Approach", "T11 Kurogane Hairpin", "T12 200R Sweeper",
	"T13 Spoon Entry", "T14 Spoon Apex", "T15 Spoon Launch", "T16 130R Ultra Sweeper",
	"T17 Casio Chicane In", "T18 Casio Chicane Out", "T19 Final Corner In", "T20 Final Corner Out",
]
## Station (compiled 1 m index) of each fillet arc's midpoint, measured with the frozen compiler
## (blueprint alignment x 1.19646 plan-to-homologated scale). The plan vertices sit up to 190 m
## outside their fillets and the figure-8 brings other stretches of track right next to them, so
## stations are baked from the arcs, never matched back from the vertices.
const TURN_STATIONS := [
	501.6, 736.7, 925.4, 1120.5, 1302.2, 1487.9, 1720.8, 1989.8, 2174.4, 2388.4,
	2637.9, 2875.3, 3123.2, 3349.4, 3544.9, 4513.8, 4764.3, 4898.0, 5256.8, 5470.5,
]

## Timing sectors (sandbox HUD): even thirds of the 5.8 km lap.
const SECTOR_BOUNDS := [0.0, 1933.333, 3866.667, 5800.0]


static func bay_station(index: int) -> float:
	return fposmod(PIT_BUILDING_CENTRE_S + PIT_STALL_PITCH_M * (float(index) - float(PIT_STALL_COUNT - 1) * 0.5), LENGTH_M)


static func service_station() -> float:
	return bay_station(PIT_SERVICE_BAY)


static func sector_index(s: float) -> int:
	var wrapped := fposmod(s, LENGTH_M)
	if wrapped < SECTOR_BOUNDS[1]:
		return 0
	if wrapped < SECTOR_BOUNDS[2]:
		return 1
	return 2


## Ribbon frame with the origin pushed `lateral` metres to `side` (+1 right, -1 left).
## Left-side buildings get the kit's 180-degree turn so local +X points away from the track.
## The turn is about the track's own up vector: about world UP on a graded straight it flips
## the pitch, and the building would follow the slope backwards.
static func side_frame(ribbon: Node3D, s: float, side: float, lateral: float) -> Transform3D:
	var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(s, LENGTH_M), side * lateral)
	if side < 0.0:
		frame.basis = frame.basis.rotated(frame.basis.y, PI)
	return frame


static func frame_at(ribbon: Node3D, s: float, lateral: float) -> Transform3D:
	return ribbon.call("get_point_at_offset", fposmod(s, LENGTH_M), lateral)


## Box frame on the pit side for things laid out across the lane with -Z still the direction
## of travel (the stopped car, its crew). The pit is on the right, so no mirror is needed.
static func box_frame(ribbon: Node3D, s: float, lateral: float) -> Transform3D:
	return ribbon.call("get_point_at_offset", fposmod(s, LENGTH_M), PIT_SIDE * lateral)
