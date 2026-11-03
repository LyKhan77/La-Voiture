class_name EifelForestLayout
extends RefCounted

## Single source of pitch/paddock/landmark numbers for the Eifel Forest Ring.
## Every value comes from
## designs/eifel_forest/final/blueprint.track.json (pit block, alignment,
## elevation) and the accepted procedural-spec.md sections 2-4 (frozen geometry
## hash sha256:8de6956c723c4f4037054e1c8317e103e12ff7704f285ea89e6a18ed951eaa3c,
## revised 2026-11-03: T13 fillet 54.0 -> 110.0 m for the FASE 18 kink gate).

const CIRCUIT_ID := "eifel_forest"
const LENGTH_M := 5150.0
const ROAD_HALF_M := 6.5
const ROAD_WIDTH_M := 13.0
const ROADBED_DROP_M := 0.16
const CURVE_PATH := "res://assets/tracks/eifel_forest/data/eifel_forest_curve.tres"

const PIT_ENTRY_S := 4950.0
const PIT_EXIT_S := 210.0
const PIT_SIDE := 1.0
## Blueprint fast lane: 8.5 m inner edge and 4.6 m width, so the sim's lane
## centre (the lateral cars drive) is 10.8 m and its outer edge is 13.1 m.
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
## First visible bay centre on the lap (bay i = 57 + 14 i, wrapping at 5150).
const PIT_STALL_FIRST_S := 57.0
const PIT_LANE_OUTER_X := 13.1
const PIT_SERVICE_X := 16.5
const PIT_APRON_LIFT_M := 0.07

## Ten-bay FIA pit building (spec section 3): 10 stalls at 14 m pitch, centre on
## the main straight so the lane wraps 4950 -> 210 through s = 120.
const PIT_BUILDING_CENTRE_S := 120.0
const PIT_FACADE_X := 20.6
const PIT_BUILDING_SPAN_M := 140.0
const PIT_SERVICE_BAY := 5
const PIT_SERVICE_STATION_S := 127.0
const PIT_STOP_SECONDS := 3.0

## Spec anchors (environment_strip.json): tower s = 25 offset 25, grandstand
## s = 120 offset 22. The kit tower mesh carries its own 24 m lateral offset.
const CONTROL_TOWER_S := 25.0
const CONTROL_TOWER_X := 25.0
## The shared RaceControlTower mesh centres itself 24 m out in its own frame, so
## the node stands 1 m off the racing line to put the tower centre at 25 m.
const CONTROL_TOWER_NODE_X := 1.0
const GRANDSTAND_ANCHOR_S := 120.0
const GRANDSTAND_LENGTH_M := 240.0

## Hero Tier B landmarks (procedural-spec.md section 4) -> assets/tracks/eifel_forest/models/.
const LANDMARK_CASTLE_S := 2750.0
const LANDMARK_CASTLE_OFFSET_M := 120.0
const LANDMARK_ARENA_S := 850.0
const LANDMARK_ARENA_OFFSET_M := 35.0
const LANDMARK_BRIDGE_S := 1580.0
const LANDMARK_BRIDGE_OFFSET_M := 0.0
const LANDMARK_ARCHWAY_S := 350.0
const LANDMARK_ARCHWAY_OFFSET_M := 45.0

const TERRAIN_STEP_M := 12.0
const TERRAIN_MIN_X := -1250.0
const TERRAIN_MAX_X := 1450.0
const TERRAIN_MIN_Z := -400.0
const TERRAIN_MAX_Z := 1600.0

## Eifel massing (all derived from the frozen elevation profile at runtime):
## the low basin sits at the measured 0.0 m station (s = 1850, between T5 and
## T6); the Burg Nürburg crag rises behind the +30.0 m crest at s = 2750; the
## natural arena bowl backs the Mercedes-Arena at T2-T4.
const VALLEY_STATION_S := 1850.0
const VALLEY_INSET_M := 40.0
const VALLEY_RADIUS_M := 300.0
const VALLEY_DEPTH_M := 5.5
const CASTLE_HILL_STATION_S := 2750.0
const CASTLE_HILL_OFFSET_M := 190.0
const CASTLE_HILL_RADIUS_M := 360.0
const CASTLE_HILL_HEIGHT_M := 30.0
const ARENA_HILL_STATION_S := 850.0
const ARENA_HILL_OFFSET_M := 210.0
const ARENA_HILL_RADIUS_M := 280.0
const ARENA_HILL_HEIGHT_M := 16.0

const TURN_COUNT := 16
const TURN_NAMES := [
	"T01 Castrol-S", "T02 Arena Entry", "T03 Arena Hairpin", "T04 Arena Exit",
	"T05 Kurve 5", "T06 Fordkurve", "T07 Dunlop Kehre", "T08 Schumacher-S",
	"T09 Schumacher-S", "T10 RTL-Kurve", "T11 Bit-Kurve", "T12 Veedol-Bogen",
	"T13 NGK Chicane", "T14 NGK Chicane", "T15 Coca-Cola 1", "T16 Coca-Cola 2",
]
const TURN_LABELS := TURN_NAMES
## Plan-space turn vertices from blueprint alignment.vertices (T1..T16; the
## start/finish vertex (0, 0) closes the loop and is not a turn).
const TURN_VERTICES := [
	Vector2(771.0, 0.0), Vector2(925.2, 308.4), Vector2(1105.1, 269.9),
	Vector2(976.6, 488.3), Vector2(796.7, 616.8), Vector2(668.2, 899.5),
	Vector2(488.3, 1259.3), Vector2(231.3, 1028.0), Vector2(115.7, 719.6),
	Vector2(-102.8, 514.0), Vector2(-334.1, 642.5), Vector2(-616.8, 539.7),
	Vector2(-719.6, 257.0), Vector2(-745.3, 154.2), Vector2(-822.4, 57.8),
	Vector2(-616.8, 0.0),
]

## Timing sectors: even thirds of the 5.15 km lap.
const SECTOR_BOUNDS := [0.0, 1716.667, 3433.333, 5150.0]


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
static func side_frame(ribbon: Node3D, s: float, side: float, lateral: float) -> Transform3D:
	var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(s, LENGTH_M), side * lateral)
	if side < 0.0:
		frame.basis = frame.basis.rotated(Vector3.UP, PI)
	return frame


static func frame_at(ribbon: Node3D, s: float, lateral: float) -> Transform3D:
	return ribbon.call("get_point_at_offset", fposmod(s, LENGTH_M), lateral)


## Station of each turn: nearest compiled centreline point to its plan vertex.
static func turn_stations(points: PackedVector3Array) -> Array[float]:
	var stations: Array[float] = []
	for vertex: Vector2 in TURN_VERTICES:
		var best := 0
		var best_d := INF
		for i in range(points.size()):
			var d := Vector2(points[i].x, points[i].z).distance_squared_to(vertex)
			if d < best_d:
				best_d = d
				best = i
		stations.append(float(best) / float(maxi(1, points.size() - 1)) * LENGTH_M)
	return stations
