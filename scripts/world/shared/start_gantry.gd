class_name StartGantry
extends Node3D

## Steel double-truss bridge over the start/finish line with the five FIA red-light pairs
## (FASE 5.5, rebuilt in FASE 10). The span covers the whole track and, through the pit wing,
## the pit lane too; the pylons stand outside the road edge on the left and beyond the pit
## lane on the right. Local axes follow the ribbon: -Z is the direction of travel, the lamps
## face +Z toward the approaching grid. The steel is one merged cel surface (MeshBatch); the
## ten lamps stay separate nodes so each can swap its material.

const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")
const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")

const LIGHT_PAIRS: int = 5
## Span over the racing surface (-SPAN/2 .. +SPAN/2); the pit wing continues it to the right.
const SPAN_M: float = 16.0
## The wing reaches this far beyond the right-hand pylon line, clear of the pit lane's outer edge (16 m).
const WING_M: float = 10.3
const BEAM_HEIGHT_M: float = 7.2
## The two truss planes stand this far apart (along the direction of travel).
const TRUSS_GAP_M: float = 1.8
const TRUSS_DEPTH_M: float = 1.0
const TRUSS_BAY_M: float = 1.2
const CHORD_M: float = 0.2
const PYLON_SIZE := Vector3(1.0, BEAM_HEIGHT_M, 3.0)
const FOOT_SIZE := Vector3(1.2, 0.3, 3.6)
const LAMP_SPACING_M: float = 1.3
const LAMP_RADIUS_M: float = 0.24
const LAMP_ON_ENERGY: float = 3.0
const PANEL_HEIGHT_M: float = 1.5
const STEEL_COLOR := Color("#7d8493")
const PANEL_COLOR := Color("#14161c")
const SIGN_COLOR := Color("#f4f5f7")
const LAMP_OFF_COLOR := Color("#3a0a0e")
const LAMP_ON_COLOR := Color("#ff0a12")
const TIMING_COLOR := Color("#00f0ff")

var lamps: Array[MeshInstance3D] = [] # two per pair: upper then lower, pair by pair
var lit_pairs: int = 0
var structure: MeshInstance3D
var timing_display: MeshInstance3D

var _on_material: StandardMaterial3D
var _off_material: StandardMaterial3D
var _glow: OmniLight3D


func _ready() -> void:
	if lamps.is_empty():
		build()


func build() -> void:
	var batch := MeshBatchScript.new()
	var steel: ShaderMaterial = ToonMaterials.vertex_colored(true)
	var left: float = -SPAN_M * 0.5
	var right: float = SPAN_M * 0.5 + WING_M
	var panel_z: float = TRUSS_GAP_M * 0.5 + 0.45 # in front of the front truss, so no lamp hides behind a diagonal
	_build_pylons(batch, steel, left, right)
	_build_trusses(batch, steel, left, right)
	_build_panel(batch, steel, panel_z)
	_build_wing_sign(batch, steel, panel_z)
	structure = MeshInstance3D.new()
	structure.name = "Structure"
	structure.mesh = batch.commit()
	add_child(structure)
	_build_timing_display(panel_z)
	_build_lamps(panel_z)


func _build_pylons(batch: MeshBatchScript, steel: ShaderMaterial, left: float, right: float) -> void:
	for x: float in [left, right]:
		batch.box(steel, STEEL_COLOR, Transform3D(Basis.IDENTITY, Vector3(x, BEAM_HEIGHT_M * 0.5, 0.0)), PYLON_SIZE)
		batch.box(steel, STEEL_COLOR, Transform3D(Basis.IDENTITY, Vector3(x, FOOT_SIZE.y * 0.5, 0.0)), FOOT_SIZE)


## Two parallel lattice trusses tied together across the direction of travel.
func _build_trusses(batch: MeshBatchScript, steel: ShaderMaterial, left: float, right: float) -> void:
	var bays: int = roundi((right - left) / TRUSS_BAY_M)
	for z: float in [-TRUSS_GAP_M * 0.5, TRUSS_GAP_M * 0.5]:
		batch.truss(steel, STEEL_COLOR, Vector3(left, BEAM_HEIGHT_M, z), Vector3(right, BEAM_HEIGHT_M, z), Vector3.UP, TRUSS_DEPTH_M, bays, CHORD_M)
	for bay: int in range(0, bays + 1, 2):
		var x: float = lerpf(left, right, float(bay) / float(bays))
		for y: float in [BEAM_HEIGHT_M + TRUSS_DEPTH_M * 0.5, BEAM_HEIGHT_M - TRUSS_DEPTH_M * 0.5]:
			batch.strut(steel, STEEL_COLOR, Vector3(x, y, -TRUSS_GAP_M * 0.5), Vector3(x, y, TRUSS_GAP_M * 0.5), 0.1)


## Dark light panel hung under the lower chord over the racing line.
func _build_panel(batch: MeshBatchScript, steel: ShaderMaterial, panel_z: float) -> void:
	var y: float = BEAM_HEIGHT_M - TRUSS_DEPTH_M * 0.5 - PANEL_HEIGHT_M * 0.5 - 0.1
	batch.box(steel, PANEL_COLOR, Transform3D(Basis.IDENTITY, Vector3(0.0, y, panel_z)), Vector3(LAMP_SPACING_M * float(LIGHT_PAIRS) + 0.8, PANEL_HEIGHT_M, 0.35))
	for hanger: float in [-1.0, 1.0]:
		batch.strut(steel, STEEL_COLOR, Vector3(hanger * LAMP_SPACING_M * 2.4, BEAM_HEIGHT_M - TRUSS_DEPTH_M * 0.5, panel_z - 0.2), Vector3(hanger * LAMP_SPACING_M * 2.4, y + PANEL_HEIGHT_M * 0.5, panel_z), 0.08)


## Series board over the pit wing, facing the approaching cars.
func _build_wing_sign(batch: MeshBatchScript, steel: ShaderMaterial, panel_z: float) -> void:
	var centre_x: float = SPAN_M * 0.5 + WING_M * 0.5 + 0.5
	var y: float = BEAM_HEIGHT_M - 0.5
	batch.box(steel, SIGN_COLOR, Transform3D(Basis.IDENTITY, Vector3(centre_x, y, panel_z - 0.05)), Vector3(7.4, 1.7, 0.18))
	batch.box(steel, TIMING_COLOR, Transform3D(Basis.IDENTITY, Vector3(centre_x, y - 0.95, panel_z - 0.05)), Vector3(7.4, 0.12, 0.2))
	for label_data: Array in [["LA VOITURE GT", 0.22, 90, 0.011], ["APEX RING INTERNATIONAL", -0.5, 48, 0.0075]]:
		var label := Label3D.new()
		label.name = "Sign%s" % str(label_data[0]).replace(" ", "")
		label.text = label_data[0]
		label.font_size = label_data[2]
		label.pixel_size = label_data[3]
		label.modulate = PANEL_COLOR
		label.outline_size = 0
		label.position = Vector3(centre_x, y + float(label_data[1]), panel_z + 0.06)
		add_child(label)


## Digital lap-time display over the racing line, left of the light panel.
func _build_timing_display(panel_z: float) -> void:
	timing_display = ToonMaterials.box(self, "TimingDisplay", Vector3(4.4, 0.95, 0.14), Vector3(-5.0, BEAM_HEIGHT_M - 0.9, panel_z + 0.05), ToonMaterials.emissive(TIMING_COLOR, 1.4))
	var label := Label3D.new()
	label.name = "TimingText"
	label.text = "LAP 0:00.000"
	label.font_size = 48
	label.pixel_size = 0.0085
	label.modulate = PANEL_COLOR
	label.outline_size = 0
	label.position = Vector3(-5.0, BEAM_HEIGHT_M - 0.9, panel_z + 0.13)
	add_child(label)


func _build_lamps(panel_z: float) -> void:
	_off_material = ToonMaterials.emissive(LAMP_OFF_COLOR, 0.0)
	_on_material = ToonMaterials.emissive(LAMP_ON_COLOR, LAMP_ON_ENERGY)
	var lens := SphereMesh.new()
	lens.radius = LAMP_RADIUS_M
	lens.height = LAMP_RADIUS_M * 2.0
	lens.radial_segments = 12
	lens.rings = 6
	var panel_y: float = BEAM_HEIGHT_M - TRUSS_DEPTH_M * 0.5 - PANEL_HEIGHT_M * 0.5 - 0.1
	for pair: int in range(LIGHT_PAIRS):
		var x: float = (float(pair) - float(LIGHT_PAIRS - 1) * 0.5) * LAMP_SPACING_M
		for row: int in range(2):
			var lamp := MeshInstance3D.new()
			lamp.name = "Lamp%d_%d" % [pair + 1, row]
			lamp.mesh = lens
			lamp.position = Vector3(x, panel_y + (0.38 if row == 0 else -0.38), panel_z + 0.22)
			lamp.material_override = _off_material
			add_child(lamp)
			lamps.append(lamp)
	_glow = OmniLight3D.new()
	_glow.name = "Glow"
	_glow.light_color = LAMP_ON_COLOR
	_glow.omni_range = 14.0
	_glow.light_energy = 0.0
	_glow.position = Vector3(0.0, panel_y, panel_z + 2.5)
	add_child(_glow)


## Lights the first `pairs` red-light pairs and darkens the rest; 0 is lights out.
func set_lights(pairs: int) -> void:
	var before: int = lit_pairs
	lit_pairs = clampi(pairs, 0, LIGHT_PAIRS)
	_sound_lights(before, lit_pairs)
	for index: int in range(lamps.size()):
		lamps[index].material_override = _on_material if index / 2 < lit_pairs else _off_material
	if _glow != null:
		_glow.light_energy = 0.7 * float(lit_pairs)


## One beep per red pair that comes on (a step higher each time), the green buzzer when they go dark.
func _sound_lights(before: int, now: int) -> void:
	var hub: AudioManager = AudioManager.of(self)
	if hub == null:
		return
	if now > before:
		hub.play_start_beep(now)
	elif now == 0 and before > 0:
		hub.play_lights_out()


func lit_lamp_count() -> int:
	var count: int = 0
	for lamp: MeshInstance3D in lamps:
		if lamp.material_override == _on_material:
			count += 1
	return count
