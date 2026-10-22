class_name PitBuilding
extends Node3D

## Pit building and VIP Paddock Club (FASE 10): the second storey over the ten garages
## of PitLaneComplex plus roll-up shutters on the ground floor. Local axes follow the ribbon
## at CENTRE_S: +X is right of travel (away from the lane), -Z is the direction of travel.
## All steel and concrete is one merged cel surface, the tinted lounge glass a second one,
## so the whole building is a handful of draw calls.

const PitLaneScript := preload("res://scripts/world/pit_lane_complex.gd")
const ToonMaterials := preload("res://scripts/world/toon_materials.gd")
const MeshBatchScript := preload("res://scripts/world/mesh_batch.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")

## Arc distance of the middle of the ten stalls; the scene is placed on the centreline here.
const CENTRE_S: float = PitLaneScript.STALL_FIRST_S + PitLaneScript.STALL_PITCH_M * (float(PitLaneScript.TEAM_COUNT) - 1.0) * 0.5
const LENGTH_M: float = PitLaneScript.STALL_PITCH_M * float(PitLaneScript.TEAM_COUNT)

## Front face of the garage fascia; the lounge sits on the garage roofs behind it.
const FRONT_X: float = PitLaneScript.GARAGE_FRONT_M - 0.5
const DEPTH_M: float = 10.0
const GARAGE_TOP_Y: float = PitLaneScript.GARAGE_HEIGHT_M + 0.3
const LOUNGE_HEIGHT_M: float = 3.9
const ROOF_THICKNESS_M: float = 0.35
## The canopy reaches out over the terrace; the lowest edge stays well above the pit crews.
const CANOPY_FRONT_X: float = FRONT_X - 2.0
const TERRACE_FRONT_X: float = FRONT_X - 1.1
const COLUMN_STEP_M: float = 17.5
const MULLION_STEP_M: float = 3.5
const FLAG_COUNT: int = 5
const POLE_HEIGHT_M: float = 7.0
const FLAG_SIZE := Vector2(2.4, 1.4)
const DOOR_WIDTH_M: float = 9.2
const SLAT_COUNT: int = 5

const CONCRETE_COLOR := Color("#b9bdc7")
const CONCRETE_DARK_COLOR := Color("#6b6f7a")
const INTERIOR_COLOR := Color("#1d2430")
const STEEL_COLOR := Color("#8f95a3")
const SHUTTER_COLORS: Array[Color] = [Color("#4a4e5a"), Color("#5a5e6b")]
const FLAG_COLORS: Array[Color] = [Color("#e0212e"), Color("#2f6fe0"), Color("#ffd400"), Color("#f4f5f7"), Color("#26b36b")]
## Alpha 0.45 marks the lit office windows: dim self-light at night through glow_energy.
const WINDOW_GLOW_ALPHA: float = 0.45

var structure: MeshInstance3D
var glass: MeshInstance3D
var floor_count: int = 2


func _ready() -> void:
	if structure == null:
		build()


func build() -> void:
	var batch := MeshBatchScript.new()
	var cel: ShaderMaterial = ToonMaterials.vertex_colored(true)
	_build_shutters(batch, cel)
	_build_lounge(batch, cel)
	_build_terrace(batch, cel)
	_build_canopy(batch, cel)
	_build_roof_top(batch, cel)
	structure = _add_mesh("Structure", batch.commit())
	glass = _add_mesh("LoungeGlass", _glass_mesh())
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## One roll-up shutter drum and a half-lowered door per garage, striped in the team colour.
func _build_shutters(batch: MeshBatchScript, cel: ShaderMaterial) -> void:
	var door_x: float = FRONT_X - 0.1
	for team: int in range(PitLaneScript.TEAM_COUNT):
		var z: float = -(PitLaneScript.STALL_FIRST_S + PitLaneScript.STALL_PITCH_M * float(team) - CENTRE_S)
		var drum := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(door_x, PitLaneScript.GARAGE_HEIGHT_M - 1.15, z - DOOR_WIDTH_M * 0.5))
		batch.cylinder(cel, CONCRETE_DARK_COLOR, drum, 0.2, 0.2, DOOR_WIDTH_M, 10)
		batch.box(cel, Liveries.color_for(team), Transform3D(Basis.IDENTITY, Vector3(door_x, PitLaneScript.GARAGE_HEIGHT_M - 1.45, z)), Vector3(0.08, 0.2, DOOR_WIDTH_M))
		for slat: int in range(SLAT_COUNT):
			var y: float = PitLaneScript.GARAGE_HEIGHT_M - 1.7 - 0.14 * float(slat)
			batch.box(cel, SHUTTER_COLORS[slat % 2], Transform3D(Basis.IDENTITY, Vector3(door_x, y, z)), Vector3(0.06, 0.13, DOOR_WIDTH_M - 0.2))


## The lounge block, sill and header bands and the glass mullions.
func _build_lounge(batch: MeshBatchScript, cel: ShaderMaterial) -> void:
	var centre_x: float = FRONT_X + 0.5 + DEPTH_M * 0.5
	var centre_y: float = GARAGE_TOP_Y + LOUNGE_HEIGHT_M * 0.5
	batch.box(cel, INTERIOR_COLOR, Transform3D(Basis.IDENTITY, Vector3(centre_x, centre_y, 0.0)), Vector3(DEPTH_M, LOUNGE_HEIGHT_M, LENGTH_M))
	var front_x: float = FRONT_X + 0.5
	batch.box(cel, CONCRETE_COLOR, Transform3D(Basis.IDENTITY, Vector3(front_x - 0.1, GARAGE_TOP_Y + 0.35, 0.0)), Vector3(0.5, 0.7, LENGTH_M))
	batch.box(cel, CONCRETE_COLOR, Transform3D(Basis.IDENTITY, Vector3(front_x - 0.1, GARAGE_TOP_Y + LOUNGE_HEIGHT_M - 0.3, 0.0)), Vector3(0.5, 0.6, LENGTH_M))
	var mullions: int = roundi(LENGTH_M / MULLION_STEP_M)
	for index: int in range(mullions + 1):
		var z: float = -LENGTH_M * 0.5 + LENGTH_M * float(index) / float(mullions)
		batch.box(cel, STEEL_COLOR, Transform3D(Basis.IDENTITY, Vector3(front_x - 0.15, centre_y, z)), Vector3(0.18, LOUNGE_HEIGHT_M - 1.2, 0.14))
	# Lit office windows on the rear face, dim at night.
	var windows: int = 14
	for index: int in range(windows):
		var z: float = -LENGTH_M * 0.5 + LENGTH_M * (float(index) + 0.5) / float(windows)
		batch.box(cel, Color(1.0, 0.82, 0.5, WINDOW_GLOW_ALPHA), Transform3D(Basis.IDENTITY, Vector3(FRONT_X + 0.5 + DEPTH_M + 0.02, centre_y, z)), Vector3(0.05, 1.4, LENGTH_M / float(windows) - 1.6))


## Observation terrace in front of the lounge, with a rail.
func _build_terrace(batch: MeshBatchScript, cel: ShaderMaterial) -> void:
	var width: float = FRONT_X + 0.5 - TERRACE_FRONT_X
	batch.box(cel, CONCRETE_DARK_COLOR, Transform3D(Basis.IDENTITY, Vector3(TERRACE_FRONT_X + width * 0.5, GARAGE_TOP_Y + 0.06, 0.0)), Vector3(width, 0.12, LENGTH_M))
	var rail_x: float = TERRACE_FRONT_X + 0.06
	var posts: int = roundi(LENGTH_M / 2.8)
	for index: int in range(posts + 1):
		var z: float = -LENGTH_M * 0.5 + LENGTH_M * float(index) / float(posts)
		batch.box(cel, STEEL_COLOR, Transform3D(Basis.IDENTITY, Vector3(rail_x, GARAGE_TOP_Y + 0.62, z)), Vector3(0.06, 1.0, 0.06))
	batch.box(cel, STEEL_COLOR, Transform3D(Basis.IDENTITY, Vector3(rail_x, GARAGE_TOP_Y + 1.12, 0.0)), Vector3(0.07, 0.07, LENGTH_M))


## Roof slab that doubles as the canopy over the terrace, held by slim columns.
func _build_canopy(batch: MeshBatchScript, cel: ShaderMaterial) -> void:
	var roof_y: float = GARAGE_TOP_Y + LOUNGE_HEIGHT_M + ROOF_THICKNESS_M * 0.5
	var back_x: float = FRONT_X + 0.5 + DEPTH_M + 0.3
	batch.box(cel, STEEL_COLOR, Transform3D(Basis.IDENTITY, Vector3((CANOPY_FRONT_X + back_x) * 0.5, roof_y, 0.0)), Vector3(back_x - CANOPY_FRONT_X, ROOF_THICKNESS_M, LENGTH_M + 1.0))
	batch.box(cel, CONCRETE_COLOR, Transform3D(Basis.IDENTITY, Vector3(CANOPY_FRONT_X + 0.1, roof_y + 0.01, 0.0)), Vector3(0.22, ROOF_THICKNESS_M + 0.2, LENGTH_M + 1.0))
	var columns: int = roundi(LENGTH_M / COLUMN_STEP_M)
	for index: int in range(columns + 1):
		var z: float = -LENGTH_M * 0.5 + LENGTH_M * float(index) / float(columns)
		var height: float = LOUNGE_HEIGHT_M
		batch.box(cel, STEEL_COLOR, Transform3D(Basis.IDENTITY, Vector3(TERRACE_FRONT_X + 0.3, GARAGE_TOP_Y + height * 0.5, z)), Vector3(0.3, height, 0.3))


## Flag poles with national colours, plus a few service units on the roof.
func _build_roof_top(batch: MeshBatchScript, cel: ShaderMaterial) -> void:
	var roof_top: float = GARAGE_TOP_Y + LOUNGE_HEIGHT_M + ROOF_THICKNESS_M
	var pole_x: float = FRONT_X + DEPTH_M - 0.5
	for index: int in range(FLAG_COUNT):
		var z: float = -LENGTH_M * 0.4 + LENGTH_M * 0.8 * float(index) / float(FLAG_COUNT - 1)
		batch.cylinder(cel, STEEL_COLOR, Transform3D(Basis.IDENTITY, Vector3(pole_x, roof_top, z)), 0.07, 0.05, POLE_HEIGHT_M, 6)
		var top: float = roof_top + POLE_HEIGHT_M
		var tip := Vector3(pole_x, top - 0.1, z)
		var flag_a: Vector3 = tip
		var flag_b: Vector3 = tip + Vector3(0.0, 0.0, FLAG_SIZE.x)
		var flag_c: Vector3 = flag_b - Vector3(0.0, FLAG_SIZE.y, 0.0)
		var flag_d: Vector3 = tip - Vector3(0.0, FLAG_SIZE.y, 0.0)
		batch.quad(cel, FLAG_COLORS[index % FLAG_COLORS.size()], flag_a, flag_b, flag_c, flag_d, Vector3.LEFT)
		batch.quad(cel, FLAG_COLORS[index % FLAG_COLORS.size()], flag_a, flag_b, flag_c, flag_d, Vector3.RIGHT)
	for index: int in range(8):
		var z: float = -LENGTH_M * 0.5 + LENGTH_M * (float(index) + 0.5) / 8.0
		batch.box(cel, CONCRETE_DARK_COLOR, Transform3D(Basis.IDENTITY, Vector3(FRONT_X + 6.0, roof_top + 0.5, z)), Vector3(2.4, 1.0, 1.6))


## One tinted pane the length of the lounge, in front of the interior.
func _glass_mesh() -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var x: float = FRONT_X + 0.5 - 0.05
	var y0: float = GARAGE_TOP_Y + 0.7
	var y1: float = GARAGE_TOP_Y + LOUNGE_HEIGHT_M - 0.6
	var z: float = LENGTH_M * 0.5
	batch.quad(ToonMaterials.glass(), Color.WHITE, Vector3(x, y0, -z), Vector3(x, y1, -z), Vector3(x, y1, z), Vector3(x, y0, z), Vector3.LEFT)
	return batch.commit()


func _add_mesh(node_name: String, mesh: ArrayMesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	add_child(instance)
	return instance
