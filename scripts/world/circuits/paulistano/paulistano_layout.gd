class_name PaulistanoLayout
extends RefCounted

## Single source of pitch/paddock/landmark numbers for the Paulistano Speed Arena.
## Every value comes from designs/paulistano/final/blueprint.track.json (pit block,
## alignment, elevation) and the accepted procedural-spec.md sections 2-4 (frozen
## geometry hash sha256:e7e318e7536e714cc6ed9979d1e26caac821890d8d2e9b70c7d06822284990cb).
## Laterals are magnitudes; PIT_SIDE puts the pit complex on the driver's left.

const CIRCUIT_ID := "paulistano"
const LENGTH_M := 4310.0
const ROAD_HALF_M := 6.75
const ROAD_WIDTH_M := 13.5
const ROADBED_DROP_M := 0.16
const CURVE_PATH := "res://assets/tracks/paulistano/data/paulistano_curve.tres"

## Pit complex: inside left of the counter-clockwise lap (spec section 3). The sim
## gets signed laterals (PIT_SIDE * magnitude), see PaulistanoPitComplex.sim_layout.
const PIT_ENTRY_S := 4060.0
const PIT_EXIT_S := 160.0
const PIT_SIDE := -1.0
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
## First visible bay centre on the lap (bay i = 27 + 14 i).
const PIT_STALL_FIRST_S := 27.0
const PIT_LANE_OUTER_X := 13.1
const PIT_SERVICE_X := 16.5
const PIT_APRON_LIFT_M := 0.07

## Paddock apron slabs, the one source the environment slab and the terrain pad both read:
## [side, s0, s1, lateral from, lateral to]. The slab rides 0.02 m over the road grade (flat
## across); the terrain pad sits PADDOCK_PAD_UNDER_M under it, and a berm falls away from every edge.
const PADDOCK_APRON_SPECS: Array = [[-1.0, 4060.0, 4310.0, 6.8, 44.0], [-1.0, 0.0, 300.0, 6.8, 44.0], [1.0, 0.0, 300.0, 8.0, 66.0], [1.0, 4240.0, 4310.0, 8.0, 66.0]]
const PADDOCK_APRON_LIFT_M := 0.02
const PADDOCK_PAD_UNDER_M := 0.06
## Laterite bank from a pad edge down to the natural ground.
const PADDOCK_BERM_M := 36.0

## Ten-bay FIA pit building: 10 stalls x 14 m pitch = 140 m span, centred on the
## main straight so the lane wraps 4060 -> 160 through s = 90.
const PIT_BUILDING_CENTRE_S := 90.0
const PIT_FACADE_X := 20.6
const PIT_BUILDING_SPAN_M := 140.0
const PIT_SERVICE_BAY := 5
const PIT_SERVICE_STATION_S := 97.0
const PIT_STOP_SECONDS := 3.0

## Spec anchors: control tower s = 20 offset 25 on the pit side; the shared
## RaceControlTower mesh centres itself 24 m out in its own frame, so the node
## stands 1 m off the racing line. Grandstand anchor s = 50 on the right side.
const CONTROL_TOWER_S := 20.0
const CONTROL_TOWER_X := 25.0
const CONTROL_TOWER_NODE_X := 1.0
const GRANDSTAND_ANCHOR_S := 50.0
const GRANDSTAND_LENGTH_M := 240.0

## Hero Tier B landmarks (procedural-spec.md section 4) -> assets/tracks/paulistano/models/.
const LANDMARK_SENNA_S := 300.0
const LANDMARK_SENNA_OFFSET_M := 78.0
const LANDMARK_KARTODROMO_S := 1000.0
const LANDMARK_KARTODROMO_OFFSET_M := 210.0
const LANDMARK_RESERVOIR_S := 1800.0
const LANDMARK_RESERVOIR_OFFSET_M := 32.0
const LANDMARK_TOWER_S := 4220.0
const LANDMARK_TOWER_OFFSET_M := 46.0

const TERRAIN_STEP_M := 12.0
const TERRAIN_MIN_X := -1250.0
const TERRAIN_MAX_X := 1300.0
const TERRAIN_MIN_Z := -1500.0
const TERRAIN_MAX_Z := 700.0

## Paulistano massing, all derived from the frozen elevation profile at runtime:
## the Guarapiranga basin sits at the measured 0.0 m low point (s = 1980) on the
## outside of T5-T6; the kartodromo plateau fills the infield around s = 1000;
## the Senna amphitheatre terrace is cut outside T1; laterite ridges close the
## horizon behind the cliff bands.
const LAKE_STATION_S := 1800.0
const LAKE_WATER_DROP_M := 2.2
## Guarapiranga basin: a superellipse aligned with the reservoir GLB (heading at LAKE_STATION_S).
## The near shore runs straight under the seawall at LAKE_NEAR_LATERAL_M; the far shore and both
## ends are rounded and noise-wobbled. Depth shelves from 0.4 m to LAKE_DEPTH_M over 45 m, and a
## LAKE_BANK_M bank rises from the waterline to the natural relief.
const LAKE_NEAR_LATERAL_M := 46.0
const LAKE_HALF_WIDTH_M := 150.0
const LAKE_HALF_LENGTH_M := 300.0
const LAKE_DEPTH_M := 3.8
const LAKE_BANK_M := 80.0
## The reservoir GLB promenade top stands this far over the waterline (hull and pontoon waterline
## at local y -7.2..-7.3).
const RESERVOIR_WATERLINE_DEPTH_M := 7.25
const KART_STATION_S := 1000.0
const KART_INSET_M := 210.0
const KART_RADIUS_M := 150.0
const KART_PLATEAU_M := 3.5
const SENNA_HILL_STATION_S := 300.0
const SENNA_HILL_OFFSET_M := 150.0
const SENNA_HILL_RADIUS_M := 180.0
const SENNA_HILL_HEIGHT_M := 10.0

const TURN_COUNT := 15
const TURN_NAMES := [
	"T01 Drop Braking", "T02 Stadium S", "T03 Arena Loop", "T04 Colosseum Exit",
	"T05 Descida", "T06 Lakefront", "T07 Band. Chicane 1", "T08 Band. Chicane 2",
	"T09 Grandstand In", "T10 Grandstand Out", "T11 Pinheirinho", "T12 Bico de Pato",
	"T13 Mergulho", "T14 Square Juncao", "T15 Amphitheater",
]
const TURN_LABELS := TURN_NAMES
## Plan-space turn vertices from blueprint alignment.vertices (T1..T15; the
## closing start/finish vertex (0, 0) is the sixteenth entry and not a turn).
const TURN_VERTICES := [
	Vector2(319.0, 0.0), Vector2(449.5, -116.0), Vector2(580.0, -87.0),
	Vector2(551.0, -406.0), Vector2(232.0, -652.5), Vector2(-145.0, -725.0),
	Vector2(-377.0, -580.0), Vector2(-348.0, -406.0), Vector2(-507.5, -319.0),
	Vector2(-406.0, -203.0), Vector2(-203.0, -261.0), Vector2(-116.0, -145.0),
	Vector2(-261.0, -72.5), Vector2(-406.0, -87.0), Vector2(-493.0, 0.0),
]

## Timing sectors: even thirds of the 4.31 km lap.
const SECTOR_BOUNDS := [0.0, 1436.667, 2873.333, 4310.0]


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


## Box frame on the pit side for things laid out across the lane with -Z still the direction
## of travel (the stopped car, its crew): on the left the X axis is mirrored so +X still
## points to the garages. Text or any one-sided mesh must use side_frame instead.
static func box_frame(ribbon: Node3D, s: float, lateral: float) -> Transform3D:
	var frame: Transform3D = ribbon.call("get_point_at_offset", fposmod(s, LENGTH_M), PIT_SIDE * lateral)
	if PIT_SIDE < 0.0:
		frame.basis.x = -frame.basis.x
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
