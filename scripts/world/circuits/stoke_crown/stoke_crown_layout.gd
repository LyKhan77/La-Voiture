class_name StokeCrownLayout
extends RefCounted

## Single source of pitch/paddock numbers for the Stoke Crown Route 2 build.
## Every value comes from designs/stoke_crown/final/blueprint.track.json (pit block)
## and the accepted procedural-spec.md sections 2-5 (frozen geometry hash
## sha256:5b8aaf2e6e71ad67ba7272cbe427db03146ebd510139e21f2f03e2c2e581dd1a).

const CIRCUIT_ID := "stoke_crown"
const LENGTH_M := 5200.0
const ROAD_HALF_M := 7.0
const ROADBED_DROP_M := 0.16

const PIT_ENTRY_S := 5020.0
const PIT_EXIT_S := 240.0
const PIT_SIDE := 1.0
const PIT_FAST_LANE_M := 8.5
const PIT_LANE_HALF_M := 2.3
const PIT_LANE_LENGTH_M := 420.0
const PIT_STALL_COUNT := 10
const PIT_STALL_PITCH_M := 20.0
const PIT_LANE_OUTER_X := 13.1
const PIT_SERVICE_X := 16.5
const PIT_APRON_LIFT_M := 0.07

## Hero Crown Wing pit building (spec s = 120) replaces the generic kit pit
## block; the 10 open garage bays live inside crown_wing_paddock.glb
## (footprint 180 x 22 x 16 m, facade at the kit garage front).
const PIT_BUILDING_CENTRE_S := 120.0
const PIT_FACADE_X := 20.6
const PIT_BUILDING_SPAN_M := 205.0
const PIT_SERVICE_BAY := 5
const PIT_SERVICE_STATION_S := 130.0
const PIT_STOP_SECONDS := 3.0

## Builder refinement (Ardennes precedent): the spec anchor s = 150 sits inside
## the Crown Wing footprint (s = 30..210 at lateral 25..47 m), so the kit tower
## lands past the garage end instead: s = 232, centre lateral 32 m (the tower
## mesh carries its own 24 m internal offset).
const CONTROL_TOWER_S := 232.0
const CONTROL_TOWER_X := 32.0

const GRANDSTAND_ANCHOR_S := 90.0

const WATER_LEVEL_M := -6.0

## Hero Tier B landmarks (procedural-spec.md section 5) -> builds/stoke_crown/assets/.
const LANDMARK_WING_S := 120.0
const LANDMARK_WING_OFFSET_M := 25.0
const LANDMARK_SPITFIRE_S := 1450.0
const LANDMARK_SPITFIRE_OFFSET_M := 26.0
const LANDMARK_ARENA_S := 2150.0
const LANDMARK_ARENA_OFFSET_M := 32.0
const LANDMARK_FLYOVER_S := 3650.0
const LANDMARK_FLYOVER_OFFSET_M := 16.0
const LANDMARK_HANGAR_S := 4250.0
const LANDMARK_HANGAR_OFFSET_M := 45.0

const TERRAIN_STEP_M := 16.0
const TERRAIN_MIN_X := -1000.0
const TERRAIN_MAX_X := 1500.0
const TERRAIN_MIN_Z := -1100.0
const TERRAIN_MAX_Z := 1000.0

const TURN_NAMES := [
	"T01 Abbey High-Speed Right", "T02 Farm Curve", "T03 Village Arena Right",
	"T04 The Loop Hairpin", "T05 Aintree Launch", "T06 Brooklands Sweeper",
	"T07 Luffield Carousel", "T08 Woodcote Acceleration", "T09 Copse Flat-Out",
	"T10 Maggotts High-G Entry", "T11 Becketts Rapid Right", "T12 Becketts Apex Left",
	"T13 Becketts Exit Right", "T14 Chapel Opening", "T15 Stowe Heavy Braking",
	"T16 Vale Chicane Entry", "T17 Vale Chicane Flick", "T18 Club Corner Carousel",
]
const TURN_LABELS := [
	"T01 Abbey", "T02 Farm", "T03 Village", "T04 The Loop", "T05 Aintree",
	"T06 Brooklands", "T07 Luffield", "T08 Woodcote", "T09 Copse", "T10 Maggotts",
	"T11 Becketts", "T12 Becketts Apex", "T13 Becketts Exit", "T14 Chapel",
	"T15 Stowe", "T16 Vale Entry", "T17 Vale Flick", "T18 Club",
]
## Plan-space turn vertices from blueprint alignment.vertices (S/F at origin).
const TURN_VERTICES := [
	Vector2(377.4, 0.0), Vector2(542.5, 106.1), Vector2(636.9, 259.5),
	Vector2(542.5, 401.0), Vector2(401.0, 330.2), Vector2(-283.0, 424.5),
	Vector2(-448.2, 330.2), Vector2(-483.5, 141.5), Vector2(-448.2, -259.5),
	Vector2(-283.0, -448.2), Vector2(-118.0, -542.5), Vector2(47.2, -554.3),
	Vector2(188.7, -518.9), Vector2(353.8, -448.2), Vector2(896.3, -259.5),
	Vector2(235.9, -188.7), Vector2(-212.3, -176.9), Vector2(-306.7, 0.0),
]

## Timing sectors: even thirds of the 5.2 km lap.
const SECTOR_BOUNDS := [0.0, 1733.333, 3466.667, 5200.0]


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
