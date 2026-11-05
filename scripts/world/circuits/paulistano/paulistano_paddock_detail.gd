extends RefCounted

## Builder-local paddock detail for the Paulistano Speed Arena review build.
##
## The vendored PitBuilding is a facade + lounge: it ships the garages as open
## shells (shutters only), which reads as an empty, floating block in the visual
## gate. This module closes the building and fills it: floor, back/end walls,
## bay partitions, door frames, canopy columns, a real interior (tyres, guns,
## jacks, fuel rig, monitors, engineers via the shared PitKit) and warm garage
## lights, so the second storey is visibly carried by the ground floor.

const Layout := preload("res://scripts/world/circuits/paulistano/paulistano_layout.gd")
const PitKit := preload("res://scripts/world/shared/pit_kit.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const MeshBatch := preload("res://scripts/world/shared/mesh_batch.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")

const FRONT_X := 20.6
const REAR_X := 30.6
const GARAGE_TOP_Y := 4.42
const LOUNGE_TOP_Y := 8.45
const KIT_ROOF_TOP := 8.75
const BAYS := 10
const PITCH := 14.0
const LENGTH := 140.0

const FLOOR := Color("#3f434b")
const WALL := Color("#b9b6ab")
const PARTITION := Color("#a9a69b")
const CEILING := Color("#8c919a")
const STEEL := Color("#6d7480")
const DARK := Color("#414852")
const DOOR_FRAME := Color("#d2cfc4")


## `teams[i]` is the team seated in box i (bay i): its stripes, carts and engineers wear that livery;
## a bay nobody races in stays neutral grey.
static func build(root: Node3D, ribbon: Node3D, terrain, teams: Array = []) -> Dictionary:
	var batch := MeshBatch.new()
	var flat: ShaderMaterial = Toon.vertex_colored(false)
	# Pit side is the driver's left: the kit turn puts local +X away from the track, so bay i (box i,
	# s rising) runs toward local +Z.
	var frame: Transform3D = Layout.side_frame(ribbon, Layout.PIT_BUILDING_CENTRE_S, Layout.PIT_SIDE, 0.0)
	var mid_x := (FRONT_X + REAR_X) * 0.5

	# Ground floor envelope: floor slab, rear wall, end walls, ceiling soffit.
	# The pit building is closed to the apron by the floor slab and the front/end
	# walls below; no separate plinth (it would cover the garage floor and crew feet).
	_box(batch, flat, FLOOR, frame, Vector3(mid_x, 0.04, 0.0), Vector3(REAR_X - FRONT_X, 0.08, LENGTH))
	_box(batch, flat, WALL, frame, Vector3(REAR_X - 0.15, GARAGE_TOP_Y * 0.5, 0.0), Vector3(0.3, GARAGE_TOP_Y, LENGTH))
	_box(batch, flat, WALL, frame, Vector3(mid_x, GARAGE_TOP_Y * 0.5, -LENGTH * 0.5), Vector3(REAR_X - FRONT_X, GARAGE_TOP_Y, 0.3))
	_box(batch, flat, WALL, frame, Vector3(mid_x, GARAGE_TOP_Y * 0.5, LENGTH * 0.5), Vector3(REAR_X - FRONT_X, GARAGE_TOP_Y, 0.3))
	_box(batch, flat, CEILING, frame, Vector3(mid_x, GARAGE_TOP_Y - 0.09, 0.0), Vector3(REAR_X - FRONT_X, 0.18, LENGTH))

	# Bay partitions and door-frame posts; header beam ties the upper floor down.
	for boundary in range(1, BAYS):
		var z := -LENGTH * 0.5 + PITCH * float(boundary)
		_box(batch, flat, PARTITION, frame, Vector3(mid_x, GARAGE_TOP_Y * 0.5, z), Vector3(REAR_X - FRONT_X, GARAGE_TOP_Y, 0.18))
		_box(batch, flat, DOOR_FRAME, frame, Vector3(FRONT_X - 0.12, GARAGE_TOP_Y * 0.5, z), Vector3(0.5, GARAGE_TOP_Y, 0.55))
	for bay in range(BAYS):
		var z := -Layout.PIT_SIDE * PITCH * (float(bay) - float(BAYS - 1) * 0.5)
		var team_color: Color = _bay_color(teams, bay)
		# Team stripe and a tool wall inside every bay.
		_box(batch, flat, team_color, frame, Vector3(REAR_X - 0.33, 3.0, z), Vector3(0.05, 0.9, 7.4))
		_box(batch, flat, DARK, frame, Vector3(REAR_X - 0.9, 1.1, z), Vector3(0.8, 2.0, 6.2))
		_box(batch, flat, Color("#8a8f99"), frame, Vector3(REAR_X - 1.35, 1.02, z), Vector3(0.7, 0.1, 5.8))
		_box(batch, flat, Color("#5b606a"), frame, Vector3(REAR_X - 1.32, 1.85, z), Vector3(0.05, 0.9, 5.2))
		# Shared PitKit interior: four tyre stacks, four wheel guns, two jacks,
		# fuel rig, extinguishers, monitor desk + two engineers, light bars.
		var pose := Transform3D(frame.basis, frame.origin + frame.basis * Vector3(FRONT_X, 0.1, z))
		# The shared props use a garage-local frame; replay them in this bay.
		_garage_props_at(batch, flat, pose, team_color)

	# End walls run the full height, and rear pilasters pick up the roof edge so
	# the aerial gate reads a supported building instead of a floating slab.
	for side: float in [-1.0, 1.0]:
		_box(batch, flat, WALL, frame, Vector3(mid_x, LOUNGE_TOP_Y * 0.5, side * (LENGTH * 0.5 + 0.15)), Vector3(REAR_X - FRONT_X, LOUNGE_TOP_Y, 0.35))
		_box(batch, flat, Color("#5d6370"), frame, Vector3(18.35, LOUNGE_TOP_Y * 0.5, side * (LENGTH * 0.5 + 0.34)), Vector3(0.35, LOUNGE_TOP_Y, 0.12))
	for boundary in range(BAYS + 1):
		var z := -LENGTH * 0.5 + PITCH * float(boundary)
		_box(batch, flat, Color("#5d6370"), frame, Vector3(REAR_X + 0.52, KIT_ROOF_TOP * 0.5, z), Vector3(0.38, KIT_ROOF_TOP, 0.38))
		_box(batch, flat, Color("#5d6370"), frame, Vector3(REAR_X + 0.3, KIT_ROOF_TOP - 0.45, z), Vector3(0.55, 0.22, 0.22))
	_box(batch, flat, Color("#5d6370"), frame, Vector3(REAR_X + 0.3, KIT_ROOF_TOP + 0.15, 0.0), Vector3(0.3, 0.28, LENGTH + 0.6))

	# Rear facade: service doors, team bands, rear windows and downpipes, so the
	# side seen from the paddock boulevard is not a blank wall under the roof.
	for bay in range(BAYS):
		var z := -Layout.PIT_SIDE * PITCH * (float(bay) - float(BAYS - 1) * 0.5)
		var team_color: Color = _bay_color(teams, bay)
		_box(batch, flat, Color("#5a6068"), frame, Vector3(REAR_X + 0.06, 1.35, z), Vector3(0.12, 2.7, 2.4))
		_box(batch, flat, Color("#2f4f6f"), frame, Vector3(REAR_X + 0.07, 2.75, z + 3.0), Vector3(0.06, 0.8, 1.4))
		_box(batch, flat, team_color, frame, Vector3(REAR_X + 0.08, 3.65, z), Vector3(0.05, 0.38, 8.0))
	for boundary in range(1, BAYS):
		var z := -LENGTH * 0.5 + PITCH * float(boundary)
		_box(batch, flat, Color("#7a8088"), frame, Vector3(REAR_X + 0.1, GARAGE_TOP_Y * 0.5, z), Vector3(0.12, GARAGE_TOP_Y, 0.12))
	_box(batch, flat, Color("#4f6b3a"), frame, Vector3(REAR_X + 1.3, 0.5, 0.0), Vector3(1.2, 1.0, LENGTH))

	# Pit-apron equipment: tyre warmers, tool carts and generators at the bay
	# edges, so the working lane reads as a live F1 pit lane rather than a slab.
	for bay in range(BAYS):
		var z := -Layout.PIT_SIDE * PITCH * (float(bay) - float(BAYS - 1) * 0.5)
		var team_color: Color = _bay_color(teams, bay)
		_box(batch, flat, Color("#2f333a"), frame, Vector3(18.55, 0.45, z - 4.1), Vector3(0.8, 0.9, 0.6))
		_box(batch, flat, team_color, frame, Vector3(18.55, 0.95, z - 4.1), Vector3(0.82, 0.12, 0.62))
		_box(batch, flat, Color("#9aa1ae"), frame, Vector3(19.15, 0.45, z + 4.2), Vector3(0.9, 0.9, 0.8))
		_box(batch, flat, team_color, frame, Vector3(19.15, 0.95, z + 4.2), Vector3(0.92, 0.14, 0.82))
		_box(batch, flat, Color("#4a505c"), frame, Vector3(18.9, 0.35, z + 2.0), Vector3(0.7, 0.7, 1.0))
		_box(batch, flat, Color("#ffd400"), frame, Vector3(18.52, 0.55, z + 2.0), Vector3(0.06, 0.5, 0.8))

	# Lounge terrace spectators, so the upper floor is visibly occupied from the track.
	for index in range(20):
		var z := -LENGTH * 0.5 + 4.0 + float(index) * 7.1
		var pose := Transform3D(frame.basis * Basis(Vector3.UP, PI * 0.5), frame.origin + frame.basis * Vector3(19.35, 4.62, z))
		_terrace_figure(batch, flat, pose, index)

	# Upper floor is carried by a column line along the terrace edge, plus a
	# visible fascia beam under the canopy (repairs the "floating roof" read).
	for column in range(21):
		var z := -LENGTH * 0.5 + 7.0 * float(column)
		_box(batch, flat, STEEL, frame, Vector3(18.35, 6.58, z), Vector3(0.28, 4.22, 0.28))
	_box(batch, flat, Color("#5d6370"), frame, Vector3(18.18, KIT_ROOF_TOP - 0.05, 0.0), Vector3(0.5, 0.55, LENGTH + 1.0))
	_box(batch, flat, DOOR_FRAME, frame, Vector3(18.18, GARAGE_TOP_Y + 0.18, 0.0), Vector3(0.5, 0.36, LENGTH + 0.8))
	_box(batch, flat, Color("#5d6370"), frame, Vector3(30.25, KIT_ROOF_TOP - 0.05, 0.0), Vector3(0.5, 0.55, LENGTH + 1.0))
	for side: float in [-1.0, 1.0]:
		_box(batch, flat, Color("#5d6370"), frame, Vector3(24.2, KIT_ROOF_TOP - 0.05, side * (LENGTH * 0.5 + 0.25)), Vector3(12.6, 0.55, 0.5))

	# Two stair/lift cores at the building ends, so the block has a silhouette.
	for side: float in [-1.0, 1.0]:
		var z := side * (LENGTH * 0.5 + 2.2)
		_box(batch, flat, WALL, frame, Vector3(FRONT_X + 1.4, LOUNGE_TOP_Y * 0.5, z), Vector3(3.2, LOUNGE_TOP_Y, 3.6))
		_box(batch, flat, STEEL, frame, Vector3(FRONT_X - 0.25, 1.2, z), Vector3(0.06, 2.4, 1.4))
		_box(batch, flat, DOOR_FRAME, frame, Vector3(FRONT_X + 1.4, LOUNGE_TOP_Y + 0.2, z), Vector3(3.5, 0.4, 3.9))

	# Pit-building roof detail: skylight strips and HVAC packs break the long slab
	# when seen from the aerial gate.
	_box(batch, flat, Color("#6d7682"), frame, Vector3(24.25, KIT_ROOF_TOP + 0.03, 0.0), Vector3(12.05, 0.05, LENGTH + 0.6))
	for index in range(6):
		var z := -LENGTH * 0.5 + 12.0 + float(index) * 22.0
		_box(batch, flat, Color("#6fa8c9"), frame, Vector3(24.0, KIT_ROOF_TOP + 0.1, z), Vector3(5.0, 0.08, 7.0))
	for index in range(4):
		var z := -LENGTH * 0.5 + 24.0 + float(index) * 30.0
		_box(batch, flat, Color("#9aa1ae"), frame, Vector3(27.2, KIT_ROOF_TOP + 0.68, z), Vector3(2.4, 1.2, 3.2))

	# Visible diagonal braces tie the canopy edge back to the garage fascia, so the
	# lounge roof cannot read as a floating slab from the track or the aerial.
	for brace in range(11):
		var z := -LENGTH * 0.5 + 7.0 + 14.0 * float(brace)
		var top := frame.origin + frame.basis * Vector3(18.22, KIT_ROOF_TOP - 0.2, z)
		var foot := frame.origin + frame.basis * Vector3(20.05, GARAGE_TOP_Y + 0.25, z)
		batch.strut(flat, Color("#5d6370"), top, foot, 0.18)

	# Roof parapet: a raised perimeter gives the slab a readable thickness from
	# any angle and keeps the canopy from reading as a floating plane.
	for edge_x: float in [18.3, 30.3]:
		_box(batch, flat, DOOR_FRAME, frame, Vector3(edge_x, KIT_ROOF_TOP + 0.45, 0.0), Vector3(0.6, 0.9, LENGTH + 0.8))
	for side: float in [-1.0, 1.0]:
		_box(batch, flat, DOOR_FRAME, frame, Vector3(24.3, KIT_ROOF_TOP + 0.45, side * (LENGTH * 0.5 + 0.3)), Vector3(12.6, 0.9, 0.6))

	# Grandstand roof edge trim: a dark steel fascia along the cantilever tip so
	# the 240 m roof reads as a supported structure, not a floating plane.
	var stand_frame: Transform3D = ribbon.get_point_at_offset(Layout.GRANDSTAND_ANCHOR_S, 0.0)
	stand_frame.basis = stand_frame.basis.rotated(stand_frame.basis.y, PI)
	# Solid foundation under the whole 38 x 240 m stand: its base and rear seats are
	# carried by a continuous plinth, never a floating tier over the apron.
	_box(batch, flat, Color("#5d6370"), stand_frame, Vector3(-38.0, -0.30, 0.0), Vector3(38.0, 0.70, 241.0))
	_box(batch, flat, Color("#8f95a3"), stand_frame, Vector3(-38.0, 0.06, 0.0), Vector3(38.4, 0.06, 241.4))
	_box(batch, flat, Color("#5d6370"), stand_frame, Vector3(-12.5, 19.2, 0.0), Vector3(0.5, 0.6, 240.0))
	_box(batch, flat, Color("#8f95a3"), stand_frame, Vector3(-12.5, 19.55, 0.0), Vector3(0.7, 0.12, 240.0))

	var mesh: ArrayMesh = batch.commit()
	var node := MeshInstance3D.new()
	node.name = "PaddockDetail"
	node.mesh = mesh
	node.material_override = flat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(node)

	# Lit lounge/hospitality windows behind the tinted glass, so the second storey
	# reads as occupied instead of a dark band under a floating roof.
	var lit := MeshBatch.new()
	var lit_material := StandardMaterial3D.new()
	lit_material.albedo_color = Color("#fff2c8")
	lit_material.emission_enabled = true
	lit_material.emission = Color("#ffd889")
	lit_material.emission_energy_multiplier = 0.45
	lit_material.roughness = 1.0
	for bay in range(BAYS):
		var z := -Layout.PIT_SIDE * PITCH * (float(bay) - float(BAYS - 1) * 0.5)
		for pane in range(5):
			var pane_z := z - 4.8 + float(pane) * 2.4
			lit.box(lit_material, Color("#fff2c8"), Transform3D(frame.basis, frame.origin + frame.basis * Vector3(20.42, 6.5, pane_z)), Vector3(0.05, 1.8, 1.35))
			lit.box(lit_material, Color("#ffe6b0"), Transform3D(frame.basis, frame.origin + frame.basis * Vector3(REAR_X + 0.04, 6.5, pane_z)), Vector3(0.05, 1.8, 1.35))
	var led := MeshBatch.new()
	var led_material := StandardMaterial3D.new()
	led_material.albedo_color = Color("#2fd3e0")
	led_material.emission_enabled = true
	led_material.emission = Color("#2fd3e0")
	led_material.emission_energy_multiplier = 0.8
	led_material.roughness = 1.0
	for edge_x: float in [18.3, 30.3]:
		led.box(led_material, Color("#2fd3e0"), Transform3D(frame.basis, frame.origin + frame.basis * Vector3(edge_x, KIT_ROOF_TOP + 0.92, 0.0)), Vector3(0.1, 0.1, LENGTH + 0.8))
	for side: float in [-1.0, 1.0]:
		led.box(led_material, Color("#2fd3e0"), Transform3D(frame.basis, frame.origin + frame.basis * Vector3(24.3, KIT_ROOF_TOP + 0.92, side * (LENGTH * 0.5 + 0.3))), Vector3(12.6, 0.1, 0.1))
	var led_mesh: ArrayMesh = led.commit()
	if led_mesh != null:
		var led_node := MeshInstance3D.new()
		led_node.name = "PaddockRoofLED"
		led_node.mesh = led_mesh
		led_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(led_node)

	var lit_mesh: ArrayMesh = lit.commit()
	if lit_mesh != null:
		var lit_node := MeshInstance3D.new()
		lit_node.name = "PaddockLoungeGlow"
		lit_node.mesh = lit_mesh
		lit_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lit_node)

	# Warm working light in every bay (visible through the glass and open doors).
	for bay in range(BAYS):
		var z := -Layout.PIT_SIDE * PITCH * (float(bay) - float(BAYS - 1) * 0.5)
		var lamp := OmniLight3D.new()
		lamp.name = "GarageLight_%02d" % bay
		lamp.position = frame.origin + frame.basis * Vector3(mid_x - 1.0, 3.95, z)
		lamp.omni_range = 12.0
		lamp.light_energy = 1.3
		lamp.light_color = Color("#fff0d6")
		lamp.shadow_enabled = false
		root.add_child(lamp)

	return {
		"garage_bays": BAYS,
		"garage_walls": 1,
		"garage_partitions": BAYS + 1,
		"garage_lights": BAYS,
		"canopy_columns": 21,
	}


## The shared `PitKit.garage_props` has no pose argument, so this mirrors its
## layout through the same public helpers, transformed into this bay's frame.
static func _garage_props_at(batch, material: Material, pose: Transform3D, team_color: Color) -> void:
	var figure = load("res://scripts/car/pit_crew_figure.gd")
	var tyre := Color("#17181c")
	var compounds: Array[Color] = [Color("#e0212e"), Color("#ffd400"), Color("#f4f5f7"), Color("#2f6fe0")]
	for stack in range(4):
		var z: float = -5.3 + 1.05 * float(stack)
		for layer in range(4):
			batch.cylinder(material, tyre, _local(pose, Vector3(7.9, 0.02 + 0.3 * float(layer), z)), 0.33, 0.33, 0.3, 10, true, false)
		batch.cylinder(material, compounds[stack], _local(pose, Vector3(7.9, 1.23, z)), 0.27, 0.27, 0.025, 10, true, false)
	batch.box(material, Color("#4a505c"), _local(pose, Vector3(8.5, 0.45, 4.6)), Vector3(0.5, 0.9, 1.5))
	for gun in range(4):
		batch.box(material, Color("#e6b23c"), _local(pose, Vector3(8.45, 0.98, 4.1 + 0.33 * float(gun))), Vector3(0.12, 0.12, 0.26))
		batch.box(material, Color("#2f6fe0"), _local(pose, Vector3(8.85, 0.7, 4.1 + 0.33 * float(gun))), Vector3(0.05, 0.05, 0.3))
	for jack in range(2):
		var z: float = 2.6 + 1.1 * float(jack)
		batch.box(material, Color("#e6b23c"), _local(pose, Vector3(3.4, 0.14, z)), Vector3(0.9, 0.2, 0.5))
		batch.box(material, Color("#e6b23c"), _local(pose, Vector3(3.2, 0.48, z)), Vector3(0.12, 0.7, 0.12))
		batch.box(material, Color("#2f6fe0"), _local(pose, Vector3(3.9, 0.62, z)), Vector3(0.6, 0.05, 0.05))
	batch.cylinder(material, Color("#9aa1ae"), _local(pose, Vector3(4.2, 0.2, -5.4)), 0.3, 0.3, 0.9, 10)
	batch.box(material, Color("#4a505c"), _local(pose, Vector3(4.2, 0.1, -5.4)), Vector3(0.9, 0.12, 0.7))
	batch.box(material, Color("#2f6fe0"), _local(pose, Vector3(3.2, 0.5, -5.4)), Vector3(1.8, 0.05, 0.05))
	for side: float in [-1.0, 1.0]:
		batch.cylinder(material, Color("#d94f3d"), _local(pose, Vector3(0.7, 0.0, side * 5.95)), 0.1, 0.1, 0.6, 8)
	batch.box(material, Color("#3a3f4a"), _local(pose, Vector3(6.0, 0.4, 0.0)), Vector3(0.9, 0.8, 2.6))
	for monitor in range(3):
		batch.box(material, Color(0.2, 0.7, 1.0, 0.3), _local(pose, Vector3(5.8, 1.08, (float(monitor) - 1.0) * 0.8)), Vector3(0.06, 0.5, 0.7))
	for engineer in range(2):
		figure.add(batch, material, Transform3D(pose.basis * Basis(Vector3.UP, -PI * 0.5), pose * Vector3(6.9, 0.0, (float(engineer) - 0.5) * 1.1)), figure.Role.ENGINEER, team_color)
	batch.box(material, Color("#d94f3d"), _local(pose, Vector3(8.4, 0.55, 1.3)), Vector3(0.6, 1.1, 1.0))
	batch.box(material, team_color, _local(pose, Vector3(8.78, 2.8, 0.0)), Vector3(0.05, 1.4, 3.6))
	for bar in range(3):
		batch.box(material, Color("#f4f5f7"), _local(pose, Vector3(2.0 + 2.6 * float(bar), PitKit.GARAGE_HEIGHT_M - 0.08, 0.0)), Vector3(0.14, 0.06, 7.0))


static func _terrace_figure(batch, material: Material, pose: Transform3D, index: int) -> void:
	var figure = load("res://scripts/car/pit_crew_figure.gd")
	var roles: Array = PitKit.standby_roles()
	figure.add(batch, material, pose, int(roles[index % roles.size()]), Liveries.color_for(index % 10))


static func _local(pose: Transform3D, offset: Vector3) -> Transform3D:
	return Transform3D(pose.basis, pose * offset)


static func _box(batch, material: Material, color: Color, frame: Transform3D, centre: Vector3, size: Vector3) -> void:
	batch.box(material, color, Transform3D(frame.basis, frame.origin + frame.basis * centre), size)


static func _bay_color(teams: Array, bay: int) -> Color:
	if teams.is_empty():
		return Liveries.color_for(bay)
	var team: int = int(teams[bay]) if bay < teams.size() else -1
	return Liveries.color_for(team) if team >= 0 else Color("#8a8f99")
