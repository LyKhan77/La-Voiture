class_name MainGrandstand
extends Node3D

## Main grandstand opposite the pit lane on the start straight (FASE 10): three raked tiers
## over a concrete frame, a curved titanium cantilever roof on steel trusses, LED ad boards,
## a crowd of 1 400+ low-poly spectators in one MultiMesh and the Jumbotron on the roof edge.
## Local axes follow the ribbon at CENTRE_S: the stand is on the LEFT of travel (-X), -Z is
## the direction of travel. The merged structure is one cel surface (a few draw calls).

const ToonMaterials := preload("res://scripts/world/toon_materials.gd")
const MeshBatchScript := preload("res://scripts/world/mesh_batch.gd")
const JumbotronScript := preload("res://scripts/world/paddock/jumbotron.gd")

## Arc distance of the middle of the stand; the scene is placed on the centreline here.
const CENTRE_S: float = 125.0
const LENGTH_M: float = 240.0
## Distance from the centreline to the front of the first tier, and the depth of all three.
const FRONT_X_M: float = 19.0
const DEPTH_M: float = 38.0
const TIERS: int = 3
const GROUND_RISE_M: float = 2.2
const TIER_RISE_M: float = 3.2
const SECTION_M: float = 20.0
const BACK_WALL_M: float = 0.6

const ROOF_BACK := Vector2(58.0, 27.0) # (distance from centreline, height) of the rear edge
const ROOF_CONTROL := Vector2(40.0, 30.5)
const ROOF_FRONT := Vector2(12.5, 19.2)
const ROOF_THICKNESS_M: float = 0.6
const ROOF_SEGMENTS: int = 10
const TRUSS_STEP_M: float = 20.0
const TRUSS_DEPTH_BACK_M: float = 3.2
const TRUSS_DEPTH_FRONT_M: float = 0.7

const SCREEN_SIZE := Vector2(22.0, 8.4)
const SCREEN_BASE_ABOVE_ROOF_M: float = 1.6

const CROWD_SEED: int = 1010
const CROWD_ROWS_PER_TIER: int = 6
const CROWD_STEP_M: float = 2.0
const CROWD_FILL: float = 0.68

const CONCRETE_COLOR := Color("#b9bdc7")
const CONCRETE_DARK_COLOR := Color("#6b6f7a")
const ROOF_COLOR := Color("#8f95a3")
const STEEL_COLOR := Color("#5d6370")
const SEAT_COLORS: Array[Color] = [Color("#e0212e"), Color("#2f6fe0"), Color("#ffd400"), Color("#f4f5f7"), Color("#26b36b"), Color("#ff7a1a")]
const AD_COLORS: Array[Color] = [Color("#00f0ff"), Color("#ff2a6d"), Color("#ffd400"), Color("#f4f5f7")]
## Alpha 0.3 marks the ad boards as self-lit (glow_energy at night).
const AD_GLOW_ALPHA: float = 0.3
const SHIRT_COLORS: Array[Color] = [Color("#ff5a5f"), Color("#4fb3ff"), Color("#ffd54a"), Color("#ffffff"), Color("#6ad48a"), Color("#ff9a3c"), Color("#c58cff")]

var structure: MeshInstance3D
var jumbotron: JumbotronScript
var crowd_instance: MultiMeshInstance3D
## Height of the rear edge of each tier's seating deck.
var tier_heights: Array[float] = []
var crowd_count: int = 0


func _ready() -> void:
	if structure == null:
		build()


func build() -> void:
	var batch := MeshBatchScript.new()
	var cel: ShaderMaterial = ToonMaterials.vertex_colored(true)
	_build_tiers(batch, cel)
	_build_roof(batch, cel)
	_build_ad_boards(batch, cel)
	_build_screen_frame(batch, cel)
	structure = MeshInstance3D.new()
	structure.name = "Structure"
	structure.mesh = batch.commit()
	add_child(structure)
	_build_jumbotron()
	_build_crowd()


## Height of the seating ramp at distance x from the centreline (x grows away from the track).
func deck_height_at(x: float) -> float:
	var progress: float = clampf((x - FRONT_X_M) / DEPTH_M, 0.0, 1.0)
	return GROUND_RISE_M + TIER_RISE_M * float(TIERS) * progress


func _build_tiers(batch: MeshBatchScript, cel: ShaderMaterial) -> void:
	var tier_depth: float = DEPTH_M / float(TIERS)
	for tier: int in range(TIERS):
		var x0: float = FRONT_X_M + tier_depth * float(tier)
		var x1: float = x0 + tier_depth
		var y0: float = deck_height_at(x0)
		var y1: float = deck_height_at(x1)
		tier_heights.append(y1)
		# Concrete wedge under the tier (profile in local X/Y: counter-clockwise, extruded along the stand).
		var wedge := PackedVector2Array([Vector2(-x0, 0.0), Vector2(-x1, 0.0), Vector2(-x1, y1), Vector2(-x0, y0)])
		batch.extrude(cel, CONCRETE_COLOR, Transform3D.IDENTITY, wedge, LENGTH_M, true)
		# Seats: one slightly raised strip per section, coloured in blocks.
		var sections: int = roundi(LENGTH_M / SECTION_M)
		for section: int in range(sections):
			var z: float = -LENGTH_M * 0.5 + SECTION_M * (float(section) + 0.5)
			var color: Color = SEAT_COLORS[(section + tier * 2) % SEAT_COLORS.size()]
			var strip := PackedVector2Array([Vector2(-x0 - 0.3, y0 + 0.02), Vector2(-x1 + 0.3, y1 + 0.02), Vector2(-x1 + 0.3, y1 + 0.22), Vector2(-x0 - 0.3, y0 + 0.22)])
			batch.extrude(cel, color, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, z)), strip, SECTION_M - 1.4, true)
		# Tier edge fascia and gangway rail.
		batch.box(cel, CONCRETE_DARK_COLOR, Transform3D(Basis.IDENTITY, Vector3(-x0 - 0.05, y0 + 0.5, 0.0)), Vector3(0.12, 0.9, LENGTH_M))
	var back_x: float = FRONT_X_M + DEPTH_M
	batch.box(cel, CONCRETE_DARK_COLOR, Transform3D(Basis.IDENTITY, Vector3(-back_x - BACK_WALL_M * 0.5, deck_height_at(back_x) * 0.5, 0.0)), Vector3(BACK_WALL_M, deck_height_at(back_x), LENGTH_M))
	# Support piers every section, under the front tier.
	for section: int in range(roundi(LENGTH_M / SECTION_M) + 1):
		var z: float = -LENGTH_M * 0.5 + SECTION_M * float(section)
		batch.box(cel, STEEL_COLOR, Transform3D(Basis.IDENTITY, Vector3(-FRONT_X_M - 0.4, GROUND_RISE_M * 0.5, z)), Vector3(0.7, GROUND_RISE_M, 0.9))


## Curved cantilever roof (a thick arc extruded along the stand), steel trusses that follow its
## underside and thin out toward the tip, rear columns and back stays.
func _build_roof(batch: MeshBatchScript, cel: ShaderMaterial) -> void:
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for index: int in range(ROOF_SEGMENTS + 1):
		var point: Vector2 = _roof_point(float(index) / float(ROOF_SEGMENTS))
		top.append(Vector2(-point.x, point.y))
		bottom.append(Vector2(-point.x, point.y - ROOF_THICKNESS_M))
	bottom.reverse()
	batch.extrude(cel, ROOF_COLOR, Transform3D.IDENTITY, top + bottom, LENGTH_M + 2.0, true)
	var frames: int = roundi(LENGTH_M / TRUSS_STEP_M)
	for frame: int in range(frames + 1):
		var z: float = -LENGTH_M * 0.5 + TRUSS_STEP_M * float(frame)
		var previous_top := Vector3.ZERO
		var previous_bottom := Vector3.ZERO
		for index: int in range(ROOF_SEGMENTS + 1):
			var t: float = float(index) / float(ROOF_SEGMENTS)
			var under: Vector2 = _roof_point(t)
			var depth: float = lerpf(TRUSS_DEPTH_BACK_M, TRUSS_DEPTH_FRONT_M, t)
			var chord_top := Vector3(-under.x, under.y - ROOF_THICKNESS_M, z)
			var chord_bottom := Vector3(-under.x, under.y - ROOF_THICKNESS_M - depth, z)
			batch.strut(cel, STEEL_COLOR, chord_top, chord_bottom, 0.16)
			if index > 0:
				batch.strut(cel, STEEL_COLOR, previous_top, chord_top, 0.2)
				batch.strut(cel, STEEL_COLOR, previous_bottom, chord_bottom, 0.2)
				batch.strut(cel, STEEL_COLOR, previous_bottom, chord_top, 0.12)
			previous_top = chord_top
			previous_bottom = chord_bottom
		var column_top := Vector3(-ROOF_BACK.x - 0.5, ROOF_BACK.y - ROOF_THICKNESS_M, z)
		batch.box(cel, STEEL_COLOR, Transform3D(Basis.IDENTITY, Vector3(column_top.x, column_top.y * 0.5, z)), Vector3(1.4, column_top.y, 1.4))
		# Back stay: a tie from the column head down to the rear apron.
		batch.strut(cel, STEEL_COLOR, column_top, Vector3(column_top.x - 7.0, 0.0, z), 0.3)


## Point on the roof's top arc, t = 0 at the rear edge and 1 at the front tip: (distance from centreline, height).
func _roof_point(t: float) -> Vector2:
	return ROOF_BACK.lerp(ROOF_CONTROL, t).lerp(ROOF_CONTROL.lerp(ROOF_FRONT, t), t)

## LED advertising boards along the front wall, lit at night.
func _build_ad_boards(batch: MeshBatchScript, cel: ShaderMaterial) -> void:
	var sections: int = roundi(LENGTH_M / SECTION_M) * 2
	var width: float = LENGTH_M / float(sections)
	for index: int in range(sections):
		var z: float = -LENGTH_M * 0.5 + width * (float(index) + 0.5)
		var color: Color = AD_COLORS[index % AD_COLORS.size()]
		batch.box(cel, Color(color, AD_GLOW_ALPHA), Transform3D(Basis.IDENTITY, Vector3(-FRONT_X_M + 0.2, 1.1, z)), Vector3(0.12, 0.9, width - 0.3))


## Steel frame and the two roof-tip posts the Jumbotron hangs on (merged into the structure mesh).
func _build_screen_frame(batch: MeshBatchScript, cel: ShaderMaterial) -> void:
	var base_y: float = ROOF_FRONT.y + SCREEN_BASE_ABOVE_ROOF_M
	var centre_y: float = base_y + SCREEN_SIZE.y * 0.5
	var x: float = _screen_x()
	batch.box(cel, STEEL_COLOR, Transform3D(Basis.IDENTITY, Vector3(x - 0.15, centre_y, 0.0)), Vector3(0.3, SCREEN_SIZE.y + 0.8, SCREEN_SIZE.x + 0.8))
	# Two posts stand on the roof tip and carry the frame.
	var post_bottom: float = ROOF_FRONT.y - 0.4
	for side: float in [-1.0, 1.0]:
		batch.box(cel, STEEL_COLOR, Transform3D(Basis.IDENTITY, Vector3(x - 0.4, (post_bottom + base_y + 0.6) * 0.5, side * (SCREEN_SIZE.x * 0.5 - 1.5))), Vector3(0.9, base_y + 0.6 - post_bottom, 0.9))


func _screen_x() -> float:
	return -ROOF_FRONT.x - 1.2


## The LED screen itself, facing the track from the roof edge.
func _build_jumbotron() -> void:
	var centre_y: float = ROOF_FRONT.y + SCREEN_BASE_ABOVE_ROOF_M + SCREEN_SIZE.y * 0.5
	jumbotron = JumbotronScript.new()
	jumbotron.name = "Jumbotron"
	add_child(jumbotron)
	jumbotron.build(SCREEN_SIZE)
	# The quad faces +Z; turn it toward the track (+X) and hang it on the roof edge.
	jumbotron.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(_screen_x() + 0.02, centre_y, 0.0))

func _build_crowd() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = CROWD_SEED
	var poses: Array[Transform3D] = []
	var colors: Array[Color] = []
	var tier_depth: float = DEPTH_M / float(TIERS)
	var row_depth: float = tier_depth / float(CROWD_ROWS_PER_TIER)
	var columns: int = int(LENGTH_M / CROWD_STEP_M)
	for tier: int in range(TIERS):
		for row: int in range(CROWD_ROWS_PER_TIER):
			var x: float = FRONT_X_M + tier_depth * float(tier) + row_depth * (float(row) + 0.5)
			for column: int in range(columns):
				if rng.randf() > CROWD_FILL:
					continue
				var z: float = -LENGTH_M * 0.5 + CROWD_STEP_M * (float(column) + 0.5) + rng.randf_range(-0.3, 0.3)
				var scale: float = rng.randf_range(0.9, 1.15)
				# Spectators face the track (+X).
				poses.append(Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * scale), Vector3(-x, deck_height_at(x) + 0.22, z)))
				colors.append(SHIRT_COLORS[rng.randi() % SHIRT_COLORS.size()])
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true # must be set while the instance count is still 0
	multimesh.mesh = _spectator_mesh()
	multimesh.instance_count = poses.size()
	for index: int in range(poses.size()):
		multimesh.set_instance_transform(index, poses[index])
		multimesh.set_instance_color(index, colors[index])
	crowd_count = poses.size()
	crowd_instance = MultiMeshInstance3D.new()
	crowd_instance.name = "Crowd"
	crowd_instance.multimesh = multimesh
	add_child(crowd_instance)


## A seated spectator: body block and head block; the instance colour tints the shirt.
func _spectator_mesh() -> ArrayMesh:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	var batch := MeshBatchScript.new()
	batch.box(material, Color.WHITE, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.32, 0.0)), Vector3(0.28, 0.62, 0.42))
	batch.box(material, Color("#f2cfae"), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.8, 0.0)), Vector3(0.24, 0.26, 0.24))
	return batch.commit()
