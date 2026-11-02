class_name PacificCorkscrewLayout
extends RefCounted

## Single source of pitch/paddock numbers for the Pacific Coast Corkscrew.
## Geometry comes from the approved Route 2 package (frozen hash
## sha256:1dcf0b856091ba429c6b7bfbd53a17286a3e0ba4091f65b4600c45256a77d3c2 after the
## Fase 0 pit-pitch revision: 14 m boxes failed the repo whole-field flood gate,
## so core/patch.gd raised pit.stall_pitch_m to 20 m; ten bays now s = 30..210 and
## service bay 5 stands at s = 130). The track alignment, radii and elevation are
## unchanged from the approved package. No other circuit module is borrowed.

const CIRCUIT_ID := "pacific_corkscrew"
const LENGTH_M := 4100.0
const ROAD_HALF_M := 6.5
const ROADBED_DROP_M := 0.16

const PIT_ENTRY_S := 3900.0
const PIT_EXIT_S := 220.0
const PIT_SIDE := 1.0
## The sim's fast-lane lateral is the lane centre, 10.8 m: the approved 8.5 m
## inner edge plus the 2.3 m half-lane (same convention as Stoke and the sandbox
## DummyCar, whose centre sits at 10.8). A car at 8.5 would clip the pit wall.
const PIT_FAST_LANE_M := 10.8
const PIT_LANE_HALF_M := 2.3
const PIT_LANE_LENGTH_M := 420.0
const PIT_STALL_COUNT := 10
const PIT_STALL_PITCH_M := 20.0
const PIT_STALL_FIRST_S := 30.0
const PIT_LANE_OUTER_X := 13.1
const PIT_SERVICE_X := 16.5
const PIT_APRON_LIFT_M := 0.07

## Ten-bay 2F FIA pit building on the main straight, centre s = 120.
const PIT_BUILDING_CENTRE_S := 120.0
const PIT_FACADE_X := 20.6
const PIT_BUILDING_SPAN_M := 200.0
const PIT_BUILDING_REAR_X := 30.6
const PIT_GARAGE_HEIGHT_M := 4.5
const PIT_LOUNGE_TOP_Y := 8.45
const PIT_ROOF_TOP_Y := 8.75
const PIT_SERVICE_BAY := 5
const PIT_STOP_SECONDS := 3.0
const PIT_ENTRY_BLEND_M := 80.0
const PIT_EXIT_BLEND_M := 30.0

## Race control tower: the approved s = 150 anchor sits inside the 200 m pit
## building (s = 20..220), so it lands past the garage end instead. The kit mesh
## carries its own 24 m lateral offset, hence the node offset of 8 m.
const CONTROL_TOWER_S := 222.0
const CONTROL_TOWER_X := 32.0
const CONTROL_TOWER_NODE_X := 8.0

const GRANDSTAND_ANCHOR_S := 90.0
const GRANDSTAND_LENGTH_M := 240.0

## Kerb livery: blue-white through Pacific Ridge / Corkscrew, red-white elsewhere.
const KERB_BLUE_S0 := 2100.0
const KERB_BLUE_S1 := 3148.0

## Hero Tier B landmarks (procedural-spec.md section 4) -> assets/tracks/pacific_corkscrew/models.
const LANDMARK_OAK_S := 2750.0
const LANDMARK_OAK_OFFSET_M := 18.0
const LANDMARK_ARCH_S := 320.0
const LANDMARK_ARCH_OFFSET_M := 12.0
const LANDMARK_AMPHITHEATRE_S := 2850.0
const LANDMARK_AMPHITHEATRE_OFFSET_M := 35.0

const TERRAIN_STEP_M := 12.0
const TERRAIN_MIN_X := -1250.0
const TERRAIN_MAX_X := 1350.0
const TERRAIN_MIN_Z := -800.0
const TERRAIN_MAX_Z := 1250.0

## Corkscrew bowl: the natural amphitheatre terraces sit on solid ground.
const CORKSCREW_BOWL_CENTRE := Vector2(-880.0, 470.0)
const CORKSCREW_BOWL_RADIUS_M := 300.0
const CORKSCREW_BOWL_HEIGHT_M := 10.5

const TURN_NAMES := [
	"T01 Pacific Gateway Kink", "T02 Andretti Double-Apex", "T03 Coastal Ridge Entry",
	"T04 South Amphitheater Curve", "T05 The Mountain Ascent", "T06 Rahal Skyline Crest",
	"T07 Pacific Vista Ridge Sweeper", "T08 The Corkscrew Apex Left",
	"T09 The Corkscrew Plunge Right", "T10 Rainey Curve Downhill",
	"T11 Final Laguna Hook",
]
const TURN_LABELS := [
	"T01 Pacific Gateway", "T02 Andretti", "T03 Coastal Ridge", "T04 South Amphitheatre",
	"T05 Mountain Ascent", "T06 Rahal Crest", "T07 Vista Ridge", "T08 Corkscrew",
	"T09 Corkscrew Plunge", "T10 Rainey Downhill", "T11 Laguna Hook",
]
## Plan-space turn vertices from blueprint alignment.vertices (S/F at origin).
const TURN_VERTICES := [
	Vector2(559.0, 0.0), Vector2(860.0, 186.3), Vector2(802.7, 516.0),
	Vector2(530.3, 659.3), Vector2(129.0, 688.0), Vector2(-401.3, 645.0),
	Vector2(-716.7, 458.7), Vector2(-774.0, 157.7), Vector2(-630.7, 14.3),
	Vector2(-501.7, -179.2), Vector2(-473.0, 0.0),
]

## Timing sectors: even thirds of the 4.1 km lap.
const SECTOR_BOUNDS := [0.0, 1366.667, 2733.333, 4100.0]


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
