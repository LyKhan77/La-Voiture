extends RefCounted

## Pacific Corkscrew pit-building detail: closes the shared PitBuilding's open
## garage shells (floor, rear/end walls, bay partitions, ceiling, door frames),
## fills every bay with the shared PitKit equipment and engineers, lights each
## bay, and gives the 200 m block its canopy columns, diagonal braces, fascia,
## parapet, LED roof strip, lit lounge windows and occupied terrace.
##
## Translated from the approved Route 2 `paddock_detail.gd`; the Fase 0 pit
## revision moves it from 10 x 14 m to 10 x 20 m (span s = 30..210).

const Layout := preload("res://scripts/world/circuits/pacific_corkscrew/pacific_corkscrew_layout.gd")
const PitKit := preload("res://scripts/world/shared/pit_kit.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const MeshBatch := preload("res://scripts/world/shared/mesh_batch.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")

const FRONT_X := Layout.PIT_FACADE_X
const REAR_X := Layout.PIT_BUILDING_REAR_X
const GARAGE_TOP_Y := Layout.PIT_GARAGE_HEIGHT_M
const LOUNGE_TOP_Y := Layout.PIT_LOUNGE_TOP_Y
const KIT_ROOF_TOP := Layout.PIT_ROOF_TOP_Y
const BAYS := Layout.PIT_STALL_COUNT
const PITCH := Layout.PIT_STALL_PITCH_M
const LENGTH := Layout.PIT_BUILDING_SPAN_M

const FLOOR := Color("#3f434b")
const WALL := Color("#b9b6ab")
const PARTITION := Color("#a9a69b")
const CEILING := Color("#8c919a")
const STEEL := Color("#6d7480")
const DARK := Color("#414852")
const DOOR_FRAME := Color("#d2cfc4")


static func build(root: Node3D, ribbon: Node3D, lighting: Node3D) -> Dictionary:
	var batch := MeshBatch.new()
	var flat: ShaderMaterial = Toon.vertex_colored(false)
	var frame: Transform3D = ribbon.get_point_at_offset(Layout.PIT_BUILDING_CENTRE_S, 0.0)
	var mid_x := (FRONT_X + REAR_X) * 0.5

	# Ground floor envelope: floor slab, rear wall, end walls, ceiling soffit.
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
		var z := -PITCH * (float(bay) - float(BAYS - 1) * 0.5)
		var team_color: Color = Liveries.color_for(bay)
		# Team stripe and a tool wall inside every bay.
		_box(batch, flat, team_color, frame, Vector3(REAR_X - 0.33, 3.0, z), Vector3(0.05, 0.9, 7.4))
		_box(batch, flat, DARK, frame, Vector3(REAR_X - 0.9, 1.1, z), Vector3(0.8, 2.0, 6.2))
		_box(batch, flat, Color("#8a8f99"), frame, Vector3(REAR_X - 1.35, 1.02, z), Vector3(0.7, 0.1, 5.8))
		_box(batch, flat, Color("#5b606a"), frame, Vector3(REAR_X - 1.32, 1.85, z), Vector3(0.05, 0.9, 5.2))
		# Shared PitKit equipment, one merged mesh per bay in garage-local coordinates.
		var props := MeshBatch.new()
		PitKit.garage_props(props, flat, team_color)
		var props_node := MeshInstance3D.new()
		props_node.name = "GarageEquipment%02d" % bay
		props_node.mesh = props.commit()
		props_node.transform = Transform3D(frame.basis, frame.origin + frame.basis * Vector3(FRONT_X, 0.1, z))
		props_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(props_node)

	# End walls run the full height, and rear pilasters pick up the roof edge so
	# the aerial gate reads a supported building instead of a floating slab.
	for side: float in [-1.0, 1.0]:
		_box(batch, flat, WALL, frame, Vector3(mid_x, LOUNGE_TOP_Y * 0.5, side * (LENGTH * 0.5 + 0.15)), Vector3(REAR_X - FRONT_X, LOUNGE_TOP_Y, 0.35))
		_box(batch, flat, Color("#5d6370"), frame, Vector3(FRONT_X - 1.75, LOUNGE_TOP_Y * 0.5, side * (LENGTH * 0.5 + 0.34)), Vector3(0.35, LOUNGE_TOP_Y, 0.12))
	for boundary in range(BAYS + 1):
		var z := -LENGTH * 0.5 + PITCH * float(boundary)
		_box(batch, flat, Color("#5d6370"), frame, Vector3(REAR_X + 0.52, KIT_ROOF_TOP * 0.5, z), Vector3(0.38, KIT_ROOF_TOP, 0.38))
		_box(batch, flat, Color("#5d6370"), frame, Vector3(REAR_X + 0.3, KIT_ROOF_TOP - 0.45, z), Vector3(0.55, 0.22, 0.22))
	_box(batch, flat, Color("#5d6370"), frame, Vector3(REAR_X + 0.3, KIT_ROOF_TOP + 0.15, 0.0), Vector3(0.3, 0.28, LENGTH + 0.6))

	# Rear facade: service doors, team bands, rear windows and downpipes.
	for bay in range(BAYS):
		var z := -PITCH * (float(bay) - float(BAYS - 1) * 0.5)
		var team_color: Color = Liveries.color_for(bay)
		_box(batch, flat, Color("#5a6068"), frame, Vector3(REAR_X + 0.06, 1.35, z), Vector3(0.12, 2.7, 2.4))
		_box(batch, flat, Color("#2f4f6f"), frame, Vector3(REAR_X + 0.07, 2.75, z + 3.0), Vector3(0.06, 0.8, 1.4))
		_box(batch, flat, team_color, frame, Vector3(REAR_X + 0.08, 3.65, z), Vector3(0.05, 0.38, 8.0))
	for boundary in range(1, BAYS):
		var z := -LENGTH * 0.5 + PITCH * float(boundary)
		_box(batch, flat, Color("#7a8088"), frame, Vector3(REAR_X + 0.1, GARAGE_TOP_Y * 0.5, z), Vector3(0.12, GARAGE_TOP_Y, 0.12))
	_box(batch, flat, Color("#4f6b3a"), frame, Vector3(REAR_X + 1.3, 0.5, 0.0), Vector3(1.2, 1.0, LENGTH))

	# Pit-apron equipment at the bay edges, so the working lane reads live.
	for bay in range(BAYS):
		var z := -PITCH * (float(bay) - float(BAYS - 1) * 0.5)
		var team_color: Color = Liveries.color_for(bay)
		_box(batch, flat, Color("#2f333a"), frame, Vector3(18.55, 0.45, z - 4.1), Vector3(0.8, 0.9, 0.6))
		_box(batch, flat, team_color, frame, Vector3(18.55, 0.95, z - 4.1), Vector3(0.82, 0.12, 0.62))
		_box(batch, flat, Color("#9aa1ae"), frame, Vector3(19.15, 0.45, z + 4.2), Vector3(0.9, 0.9, 0.8))
		_box(batch, flat, team_color, frame, Vector3(19.15, 0.95, z + 4.2), Vector3(0.92, 0.14, 0.82))
		_box(batch, flat, Color("#4a505c"), frame, Vector3(18.9, 0.35, z + 2.0), Vector3(0.7, 0.7, 1.0))
		_box(batch, flat, Color("#ffd400"), frame, Vector3(18.52, 0.55, z + 2.0), Vector3(0.06, 0.5, 0.8))

	# Lounge terrace spectators, so the upper floor is visibly occupied.
	for index in range(20):
		var z := -LENGTH * 0.5 + 5.0 + float(index) * 10.0
		var pose := Transform3D(frame.basis * Basis(Vector3.UP, PI * 0.5), frame.origin + frame.basis * Vector3(FRONT_X - 1.25, GARAGE_TOP_Y + 0.2, z))
		_terrace_figure(batch, flat, pose, index)

	# Upper floor is carried by a column line along the terrace edge, plus a
	# visible fascia beam under the canopy.
	for column in range(21):
		var z := -LENGTH * 0.5 + 10.0 * float(column)
		_box(batch, flat, STEEL, frame, Vector3(FRONT_X - 2.25, 6.58, z), Vector3(0.28, 4.22, 0.28))
	_box(batch, flat, Color("#5d6370"), frame, Vector3(FRONT_X - 2.42, KIT_ROOF_TOP - 0.05, 0.0), Vector3(0.5, 0.55, LENGTH + 1.0))
	_box(batch, flat, DOOR_FRAME, frame, Vector3(FRONT_X - 2.42, GARAGE_TOP_Y + 0.18, 0.0), Vector3(0.5, 0.36, LENGTH + 0.8))
	_box(batch, flat, Color("#5d6370"), frame, Vector3(REAR_X - 0.35, KIT_ROOF_TOP - 0.05, 0.0), Vector3(0.5, 0.55, LENGTH + 1.0))
	for side: float in [-1.0, 1.0]:
		_box(batch, flat, Color("#5d6370"), frame, Vector3(25.6, KIT_ROOF_TOP - 0.05, side * (LENGTH * 0.5 + 0.25)), Vector3(12.6, 0.55, 0.5))

	# Two stair/lift cores at the building ends, so the block has a silhouette.
	for side: float in [-1.0, 1.0]:
		var z := side * (LENGTH * 0.5 + 2.2)
		_box(batch, flat, WALL, frame, Vector3(FRONT_X + 1.4, LOUNGE_TOP_Y * 0.5, z), Vector3(3.2, LOUNGE_TOP_Y, 3.6))
		_box(batch, flat, STEEL, frame, Vector3(FRONT_X - 0.25, 1.2, z), Vector3(0.06, 2.4, 1.4))
		_box(batch, flat, DOOR_FRAME, frame, Vector3(FRONT_X + 1.4, LOUNGE_TOP_Y + 0.2, z), Vector3(3.5, 0.4, 3.9))

	# Pit-building roof detail: skylight strips and HVAC packs break the long slab.
	_box(batch, flat, Color("#6d7682"), frame, Vector3(25.65, KIT_ROOF_TOP + 0.03, 0.0), Vector3(12.05, 0.05, LENGTH + 0.6))
	for index in range(6):
		var z := -LENGTH * 0.5 + 15.0 + float(index) * 34.0
		_box(batch, flat, Color("#6fa8c9"), frame, Vector3(25.4, KIT_ROOF_TOP + 0.1, z), Vector3(5.0, 0.08, 7.0))
	for index in range(4):
		var z := -LENGTH * 0.5 + 30.0 + float(index) * 46.0
		_box(batch, flat, Color("#9aa1ae"), frame, Vector3(28.6, KIT_ROOF_TOP + 0.68, z), Vector3(2.4, 1.2, 3.2))

	# Visible diagonal braces tie the canopy edge back to the garage fascia.
	for brace in range(15):
		var z := -LENGTH * 0.5 + 7.0 + 13.5 * float(brace)
		var top := frame.origin + frame.basis * Vector3(FRONT_X - 2.4, KIT_ROOF_TOP - 0.2, z)
		var foot := frame.origin + frame.basis * Vector3(FRONT_X - 0.55, GARAGE_TOP_Y + 0.25, z)
		batch.strut(flat, Color("#5d6370"), top, foot, 0.18)

	# Roof parapet: a raised perimeter gives the slab a readable thickness.
	for edge_x: float in [FRONT_X - 2.3, REAR_X + 0.3]:
		_box(batch, flat, DOOR_FRAME, frame, Vector3(edge_x, KIT_ROOF_TOP + 0.45, 0.0), Vector3(0.6, 0.9, LENGTH + 0.8))
	for side: float in [-1.0, 1.0]:
		_box(batch, flat, DOOR_FRAME, frame, Vector3(25.6, KIT_ROOF_TOP + 0.45, side * (LENGTH * 0.5 + 0.3)), Vector3(12.6, 0.9, 0.6))

	# Grandstand roof edge trim: dark steel fascia along the cantilever tip.
	var stand_frame: Transform3D = ribbon.get_point_at_offset(Layout.GRANDSTAND_ANCHOR_S, 0.0)
	_box(batch, flat, Color("#5d6370"), stand_frame, Vector3(-12.5, 19.2, 0.0), Vector3(0.5, 0.6, Layout.GRANDSTAND_LENGTH_M))
	_box(batch, flat, Color("#8f95a3"), stand_frame, Vector3(-12.5, 19.55, 0.0), Vector3(0.7, 0.12, Layout.GRANDSTAND_LENGTH_M))

	var mesh: ArrayMesh = batch.commit()
	var node := MeshInstance3D.new()
	node.name = "PaddockDetail"
	node.mesh = mesh
	node.material_override = flat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(node)

	# Lit lounge/hospitality windows behind the tinted glass.
	var lit := MeshBatch.new()
	var lit_material := StandardMaterial3D.new()
	lit_material.albedo_color = Color("#fff2c8")
	lit_material.emission_enabled = true
	lit_material.emission = Color("#ffd889")
	lit_material.emission_energy_multiplier = 0.45
	lit_material.roughness = 1.0
	for bay in range(BAYS):
		var z := -PITCH * (float(bay) - float(BAYS - 1) * 0.5)
		for pane in range(5):
			var pane_z := z - 4.8 + float(pane) * 2.4
			lit.box(lit_material, Color("#fff2c8"), Transform3D(frame.basis, frame.origin + frame.basis * Vector3(FRONT_X + 0.02, 6.5, pane_z)), Vector3(0.05, 1.8, 1.35))
			lit.box(lit_material, Color("#ffe6b0"), Transform3D(frame.basis, frame.origin + frame.basis * Vector3(REAR_X + 0.04, 6.5, pane_z)), Vector3(0.05, 1.8, 1.35))
	var led := MeshBatch.new()
	var led_material := StandardMaterial3D.new()
	led_material.albedo_color = Color("#2fd3e0")
	led_material.emission_enabled = true
	led_material.emission = Color("#2fd3e0")
	led_material.emission_energy_multiplier = 0.8
	led_material.roughness = 1.0
	for edge_x: float in [FRONT_X - 2.3, REAR_X + 0.3]:
		led.box(led_material, Color("#2fd3e0"), Transform3D(frame.basis, frame.origin + frame.basis * Vector3(edge_x, KIT_ROOF_TOP + 0.92, 0.0)), Vector3(0.1, 0.1, LENGTH + 0.8))
	for side: float in [-1.0, 1.0]:
		led.box(led_material, Color("#2fd3e0"), Transform3D(frame.basis, frame.origin + frame.basis * Vector3(25.6, KIT_ROOF_TOP + 0.92, side * (LENGTH * 0.5 + 0.3))), Vector3(12.6, 0.1, 0.1))
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

	# Warm working light in every bay.
	for bay in range(BAYS):
		var z := -PITCH * (float(bay) - float(BAYS - 1) * 0.5)
		var lamp := OmniLight3D.new()
		lamp.name = "GarageLight_%02d" % bay
		lamp.position = frame.origin + frame.basis * Vector3(mid_x - 1.0, 3.95, z)
		lamp.omni_range = 12.0
		lamp.light_energy = 1.3
		lamp.light_color = Color("#fff0d6")
		lamp.shadow_enabled = false
		lighting.add_child(lamp)

	return {
		"garage_bays": BAYS,
		"garage_walls": 1,
		"garage_partitions": BAYS + 1,
		"garage_lights": BAYS,
		"canopy_columns": 21,
	}


static func _terrace_figure(batch: MeshBatch, material: Material, pose: Transform3D, index: int) -> void:
	var roles: Array = PitKit.standby_roles()
	PitKit.FigureScript.add(batch, material, pose, int(roles[index % roles.size()]), Liveries.color_for(index % 10))


static func _box(batch: MeshBatch, material: Material, color: Color, frame: Transform3D, centre: Vector3, size: Vector3) -> void:
	batch.box(material, color, Transform3D(frame.basis, frame.origin + frame.basis * centre), size)
