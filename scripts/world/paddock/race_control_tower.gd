class_name RaceControlTower
extends Node3D

## Race control tower beyond Pit Exit (FASE 10): four floors of raw neo-brutalist concrete -
## a lobby, a cantilevered timing floor, a 360-degree glass race-control floor under a heavy
## roof slab and a rotated TV pod with a mast and beacon. Local axes follow the ribbon at
## CENTRE_S: +X is right of travel (the pit side, away from the track), -Z is forward.
## The structure is one merged cel surface; the glass is a second, so lights can warm it at night.

const ToonMaterials := preload("res://scripts/world/toon_materials.gd")
const MeshBatchScript := preload("res://scripts/world/mesh_batch.gd")

## Arc distance of the tower's centre, just beyond the Pit Exit line (s = 150 m).
const CENTRE_S: float = 195.0
## Lateral distance of the tower's centre from the racing line.
const CENTRE_X_M: float = 24.0
## Floor tops, ground to roof. The lobby is tall so nothing hangs below 6 m over the cars' corridor.
const FLOOR_TOPS_M: Array[float] = [6.2, 10.2, 14.2, 17.7]
const LOBBY_SIZE := Vector2(12.0, 12.0) # (across, along)
const TIMING_SIZE := Vector2(13.5, 16.0)
const TIMING_OVERHANG_M: float = 2.0 # toward the track, beyond the lobby
const GLASS_FLOOR_SIZE := Vector2(9.0, 11.0)
const ROOF_SLAB_SIZE := Vector2(14.0, 17.0)
const ROOF_SLAB_THICKNESS_M: float = 0.7
const POD_SIZE: float = 8.0
const MAST_HEIGHT_M: float = 8.5
const FIN_HEIGHT_M: float = 9.0

const CONCRETE_COLOR := Color("#8d9199")
const CONCRETE_DARK_COLOR := Color("#5d6270")
const SLIT_COLOR := Color("#14161c")
const ACCENT_YELLOW := Color("#ffd400")
const ACCENT_MAGENTA := Color("#ff2a6d")
const INTERIOR_COLOR := Color("#1d2430")
## Alpha 0 marks the beacon as fully self-lit (glow_energy).
const BEACON_COLOR := Color(1.0, 0.18, 0.18, 0.0)

var structure: MeshInstance3D
var glass: MeshInstance3D
var floor_count: int = FLOOR_TOPS_M.size()


@export var accent_color: Color = ACCENT_YELLOW


func _ready() -> void:
	if structure == null:
		build()


func build() -> void:
	var batch := MeshBatchScript.new()
	var cel: ShaderMaterial = ToonMaterials.vertex_colored(true)
	var glass_batch := MeshBatchScript.new()
	var x: float = CENTRE_X_M
	_lobby(batch, cel, x)
	_timing_floor(batch, cel, x)
	_race_control_floor(batch, glass_batch, cel, x)
	_tv_pod(batch, glass_batch, cel, x)
	structure = _add_mesh("Structure", batch.commit())
	glass = _add_mesh("Glass", glass_batch.commit())
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_sign(x)


func _lobby(batch: MeshBatchScript, cel: ShaderMaterial, x: float) -> void:
	var height: float = FLOOR_TOPS_M[0]
	batch.box(cel, CONCRETE_COLOR, Transform3D(Basis.IDENTITY, Vector3(x, height * 0.5, 0.0)), Vector3(LOBBY_SIZE.x, height, LOBBY_SIZE.y))
	batch.box(cel, CONCRETE_DARK_COLOR, Transform3D(Basis.IDENTITY, Vector3(x, 0.3, 0.0)), Vector3(LOBBY_SIZE.x + 0.8, 0.6, LOBBY_SIZE.y + 0.8))
	# Recessed entrance on the track face, and a heavy diagonal buttress on the back.
	batch.box(cel, SLIT_COLOR, Transform3D(Basis.IDENTITY, Vector3(x - LOBBY_SIZE.x * 0.5 - 0.05, 2.0, 0.0)), Vector3(0.3, 3.6, 3.4))
	var fin := PackedVector2Array([Vector2(0.0, 0.0), Vector2(5.0, 0.0), Vector2(0.0, FIN_HEIGHT_M)])
	batch.extrude(cel, CONCRETE_DARK_COLOR, Transform3D(Basis.IDENTITY, Vector3(x + LOBBY_SIZE.x * 0.5, 0.0, 0.0)), fin, 2.4, true)


## Second floor: a wide block that overhangs the track side, with long slit windows and yellow bands.
func _timing_floor(batch: MeshBatchScript, cel: ShaderMaterial, x: float) -> void:
	var bottom: float = FLOOR_TOPS_M[0]
	var height: float = FLOOR_TOPS_M[1] - bottom
	var centre_x: float = x - TIMING_OVERHANG_M * 0.5
	var width: float = TIMING_SIZE.x
	batch.box(cel, CONCRETE_COLOR, Transform3D(Basis.IDENTITY, Vector3(centre_x, bottom + height * 0.5, 0.0)), Vector3(width, height, TIMING_SIZE.y))
	var track_face: float = centre_x - width * 0.5
	for index: int in range(5):
		var z: float = -TIMING_SIZE.y * 0.5 + TIMING_SIZE.y * (float(index) + 0.5) / 5.0
		batch.box(cel, SLIT_COLOR, Transform3D(Basis.IDENTITY, Vector3(track_face - 0.04, bottom + height * 0.55, z)), Vector3(0.12, 1.1, 2.2))
	batch.box(cel, accent_color, Transform3D(Basis.IDENTITY, Vector3(track_face - 0.06, bottom + 0.25, 0.0)), Vector3(0.14, 0.3, TIMING_SIZE.y))


## Third floor: glass on all four sides between concrete corner piers, under the roof slab.
func _race_control_floor(batch: MeshBatchScript, glass_batch: MeshBatchScript, cel: ShaderMaterial, x: float) -> void:
	var bottom: float = FLOOR_TOPS_M[1]
	var top: float = FLOOR_TOPS_M[2]
	var height: float = top - bottom
	batch.box(cel, INTERIOR_COLOR, Transform3D(Basis.IDENTITY, Vector3(x, bottom + height * 0.5, 0.0)), Vector3(GLASS_FLOOR_SIZE.x - 0.4, height, GLASS_FLOOR_SIZE.y - 0.4))
	var half_x: float = GLASS_FLOOR_SIZE.x * 0.5
	var half_z: float = GLASS_FLOOR_SIZE.y * 0.5
	for pier_x: float in [-1.0, 1.0]:
		for pier_z: float in [-1.0, 1.0]:
			batch.box(cel, CONCRETE_COLOR, Transform3D(Basis.IDENTITY, Vector3(x + pier_x * half_x, bottom + height * 0.5, pier_z * half_z)), Vector3(0.9, height, 0.9))
	var glass_material: Material = ToonMaterials.glass()
	var y0: float = bottom + 0.4
	var y1: float = top - 0.3
	for side: float in [-1.0, 1.0]:
		glass_batch.quad(glass_material, Color.WHITE, Vector3(x + side * half_x, y0, -half_z), Vector3(x + side * half_x, y1, -half_z), Vector3(x + side * half_x, y1, half_z), Vector3(x + side * half_x, y0, half_z), Vector3(side, 0.0, 0.0))
		glass_batch.quad(glass_material, Color.WHITE, Vector3(x - half_x, y0, side * half_z), Vector3(x - half_x, y1, side * half_z), Vector3(x + half_x, y1, side * half_z), Vector3(x + half_x, y0, side * half_z), Vector3(0.0, 0.0, side))
	batch.box(cel, CONCRETE_DARK_COLOR, Transform3D(Basis.IDENTITY, Vector3(x, top + ROOF_SLAB_THICKNESS_M * 0.5, 0.0)), Vector3(ROOF_SLAB_SIZE.x, ROOF_SLAB_THICKNESS_M, ROOF_SLAB_SIZE.y))


## Fourth floor: a TV pod turned 45 degrees on the roof slab, a wedge roof, mast and a red beacon.
func _tv_pod(batch: MeshBatchScript, glass_batch: MeshBatchScript, cel: ShaderMaterial, x: float) -> void:
	var bottom: float = FLOOR_TOPS_M[2] + ROOF_SLAB_THICKNESS_M
	var top: float = FLOOR_TOPS_M[3]
	var height: float = top - bottom
	var turn := Basis(Vector3.UP, PI * 0.25)
	batch.box(cel, CONCRETE_COLOR, Transform3D(turn, Vector3(x, bottom + height * 0.5, 0.0)), Vector3(POD_SIZE, height, POD_SIZE))
	batch.box(cel, ACCENT_MAGENTA, Transform3D(turn, Vector3(x, bottom + height * 0.5, 0.0)), Vector3(POD_SIZE + 0.16, 0.35, POD_SIZE + 0.16))
	# Tilted wedge roof: low toward the track, high at the back.
	var wedge := PackedVector2Array([Vector2(-POD_SIZE * 0.55, 0.0), Vector2(POD_SIZE * 0.55, 0.0), Vector2(POD_SIZE * 0.55, 1.4), Vector2(-POD_SIZE * 0.55, 0.45)])
	batch.extrude(cel, CONCRETE_DARK_COLOR, Transform3D(Basis.IDENTITY, Vector3(x, top, 0.0)), wedge, POD_SIZE * 1.1, true)
	var glass_material: Material = ToonMaterials.glass()
	var half: float = POD_SIZE * 0.5 + 0.04
	var y0: float = bottom + 0.6
	var y1: float = top - 0.25
	var corner_a: Vector3 = turn * Vector3(-half, 0.0, -half) + Vector3(x, 0.0, 0.0)
	var corner_b: Vector3 = turn * Vector3(half, 0.0, -half) + Vector3(x, 0.0, 0.0)
	var corner_c: Vector3 = turn * Vector3(half, 0.0, half) + Vector3(x, 0.0, 0.0)
	var corner_d: Vector3 = turn * Vector3(-half, 0.0, half) + Vector3(x, 0.0, 0.0)
	for edge: Array in [[corner_a, corner_b], [corner_b, corner_c], [corner_c, corner_d], [corner_d, corner_a]]:
		var a: Vector3 = edge[0]
		var b: Vector3 = edge[1]
		var outward: Vector3 = ((a + b) * 0.5 - Vector3(x, 0.0, 0.0)).normalized()
		glass_batch.quad(glass_material, Color.WHITE, Vector3(a.x, y0, a.z), Vector3(a.x, y1, a.z), Vector3(b.x, y1, b.z), Vector3(b.x, y0, b.z), outward)
	var mast_base: Vector3 = Vector3(x + 1.5, top + 1.2, 1.5)
	batch.cylinder(cel, CONCRETE_DARK_COLOR, Transform3D(Basis.IDENTITY, mast_base), 0.2, 0.12, MAST_HEIGHT_M, 8)
	batch.cylinder(cel, BEACON_COLOR, Transform3D(Basis.IDENTITY, mast_base + Vector3(0.0, MAST_HEIGHT_M, 0.0)), 0.28, 0.0, 0.7, 8)


## "RACE CONTROL" lettering on the track face of the timing floor.
func _add_sign(x: float) -> void:
	var label := Label3D.new()
	label.name = "RaceControlSign"
	label.text = "RACE CONTROL"
	label.font_size = 96
	label.pixel_size = 0.0075
	label.modulate = accent_color
	label.outline_size = 8
	label.outline_modulate = Color("#14161c")
	label.position = Vector3(x - TIMING_OVERHANG_M * 0.5 - TIMING_SIZE.x * 0.5 - 0.2, FLOOR_TOPS_M[0] + (FLOOR_TOPS_M[1] - FLOOR_TOPS_M[0]) * 0.18, 0.0)
	label.rotation.y = -PI * 0.5 # faces the track, -X
	add_child(label)


func _add_mesh(node_name: String, mesh: ArrayMesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	add_child(instance)
	return instance
