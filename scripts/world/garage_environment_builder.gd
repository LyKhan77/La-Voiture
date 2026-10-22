class_name GarageEnvironmentBuilder
extends Node3D

## Procedural 10-stall pit garage for the team-select screen. Each stall is spaced
## STALL_SPACING metres apart along +X, opens to +Z (the pit lane) and carries the team's
## real `*_full.glb` car, a glossy epoxy floor, hazard chevrons, floor typography, steel
## partitions with team-coloured LED strips, a tyre rack, a toolbox and a hanging
## telemetry monitor. The car instances are the imported GLB roots themselves: bounds are
## read from the meshes, never from the shared asset, and each root is normalised onto the
## floor inside its stall.

const Roster := preload("res://scripts/ui/garage_roster.gd")
const Gt := preload("res://scripts/gt/gt_data.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const ToonMaterials := preload("res://scripts/world/toon_materials.gd")

const STALL_SPACING: float = 14.0
const STALL_HALF_WIDTH: float = 6.1
const STALL_DEPTH: float = 16.0
const STALL_FRONT_Z: float = 5.35
const PARTITION_FRONT_Z: float = 3.5
const WALL_HEIGHT: float = 4.6
const CAR_TARGET_LENGTH_M: float = 4.55
const CAR_MAX_WIDTH_M: float = 2.6
const CAR_MAX_HEIGHT_M: float = 1.8

const EPOXY_COLOR := Color("#232833")
const WALL_COLOR := Color("#2c3240")
const STEEL_COLOR := Color("#39404e")
const STEEL_LIGHT := Color("#737c8e")
const HAZARD_YELLOW := Color("#ffd400")
const HAZARD_INK := Color("#101218")
const SCREEN_COLOR := Color("#00c2ff")

const COMPOUND_COLORS: Array[Color] = [
	Color("#e0212e"), Color("#ffd400"), Color("#f4f5f7"), Color("#2fbf71"), Color("#00c2ff"),
]

var stalls: Array[Node3D] = []
var cars: Array[Node3D] = []
## Local-space bounds of each imported car before it was fitted into its stall.
var car_bounds: Array[AABB] = []

var _unit_box: BoxMesh
var _epoxy: StandardMaterial3D
var _steel: ShaderMaterial
var _steel_light: ShaderMaterial
var _wall: ShaderMaterial
var _hazard_mesh: ArrayMesh
var _stall_count: int = 0


## Builds `team_count` stalls (1 for the menu showroom, 10 for the garage screen).
func build(team_count: int = 10) -> void:
	_clear()
	_stall_count = clampi(team_count, 1, Roster.CAR_SLUGS.size())
	_unit_box = BoxMesh.new()
	_unit_box.size = Vector3.ONE
	_epoxy = _make_epoxy()
	_steel = ToonMaterials.make(STEEL_COLOR)
	_steel_light = ToonMaterials.make(STEEL_LIGHT)
	_wall = ToonMaterials.make(WALL_COLOR)
	_hazard_mesh = _build_hazard_mesh()
	_build_floor()
	_build_back_wall()
	for team: int in range(_stall_count):
		var stall := Node3D.new()
		stall.name = "Stall%02d" % (team + 1)
		stall.position = Vector3(float(team) * STALL_SPACING, 0.0, 0.0)
		add_child(stall)
		stalls.append(stall)
		_build_stall(stall, team)
		var car: Node3D = _instantiate_car(team)
		stall.add_child(car)
		cars.append(car)
	_build_partitions()
	_build_ceiling_lights()
	_build_reflection_probe()


## World position the camera should look at for a stall: the car centre, a little above the floor.
func focus_point(team: int) -> Vector3:
	if stalls.is_empty():
		return Vector3.ZERO
	return stalls[posmod(team, stalls.size())].global_position + Vector3(0.0, 0.9, 0.0)


# --- construction --------------------------------------------------------------------------

func _clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	stalls.clear()
	cars.clear()
	car_bounds.clear()


func _make_epoxy() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = EPOXY_COLOR
	material.metallic = 0.45
	material.roughness = 0.16
	material.metallic_specular = 0.8
	return material


func _build_floor() -> void:
	var width: float = float(_stall_count) * STALL_SPACING + 4.0
	var center_x: float = (float(_stall_count - 1) * STALL_SPACING) * 0.5
	var floor_instance := _box(self, "EpoxyFloor", Vector3(width, 0.2, STALL_DEPTH + 2.0), Vector3(center_x, -0.1, 0.0), _epoxy)
	floor_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for team: int in range(_stall_count):
		var x: float = float(team) * STALL_SPACING
		var hazard := MeshInstance3D.new()
		hazard.name = "Hazard%02d" % (team + 1)
		hazard.mesh = _hazard_mesh
		hazard.position = Vector3(x, 0.012, 0.0)
		hazard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hazard)
		var floor_text := Label3D.new()
		floor_text.name = "StallType%02d" % (team + 1)
		floor_text.text = "// STALL %02d: %s" % [team + 1, Gt.TEAM_NAMES[team].to_upper()]
		floor_text.font = load("res://assets/fonts/BarlowCondensed.ttf")
		floor_text.font_size = 48
		floor_text.pixel_size = 0.0062
		floor_text.modulate = Color("#7c8494")
		floor_text.outline_size = 0
		floor_text.shaded = false
		floor_text.position = Vector3(x, 0.018, -3.45)
		floor_text.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		add_child(floor_text)


func _build_hazard_mesh() -> ArrayMesh:
	var yellow := SurfaceTool.new()
	var ink := SurfaceTool.new()
	for surface: SurfaceTool in [yellow, ink]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_normal(Vector3.UP)
	var index: int = 0
	var x: float = -6.4
	while x < 6.4:
		var stripe: SurfaceTool = yellow if index % 2 == 0 else ink
		var stripe_width: float = 0.58
		var slant: float = 0.55
		var z0: float = 2.62
		var z1: float = 3.42
		for vertex: Vector3 in [
			Vector3(x, 0.0, z0), Vector3(x + slant, 0.0, z1), Vector3(x + stripe_width + slant, 0.0, z1),
			Vector3(x, 0.0, z0), Vector3(x + stripe_width + slant, 0.0, z1), Vector3(x + stripe_width, 0.0, z0),
		]:
			stripe.add_vertex(vertex)
		x += 0.95
		index += 1
	var mesh := ArrayMesh.new()
	yellow.commit(mesh)
	mesh.surface_set_material(0, ToonMaterials.make(HAZARD_YELLOW))
	ink.commit(mesh)
	mesh.surface_set_material(1, ToonMaterials.make(HAZARD_INK))
	return mesh


func _build_back_wall() -> void:
	var width: float = float(_stall_count) * STALL_SPACING + 2.0
	var center_x: float = (float(_stall_count - 1) * STALL_SPACING) * 0.5
	_box(self, "BackWall", Vector3(width, WALL_HEIGHT, 0.3), Vector3(center_x, WALL_HEIGHT * 0.5, -STALL_DEPTH * 0.5), _wall)
	_box(self, "BackWallCap", Vector3(width, 0.18, 0.6), Vector3(center_x, WALL_HEIGHT - 0.09, -STALL_DEPTH * 0.5), _steel)
	for team: int in range(_stall_count):
		var x: float = float(team) * STALL_SPACING
		_box(self, "WallBand%02d" % (team + 1), Vector3(11.4, 0.14, 0.05),
			Vector3(x, 4.28, -STALL_DEPTH * 0.5 + 0.18), ToonMaterials.emissive(Liveries.color_for(team), 1.4))


func _build_stall(stall: Node3D, team: int) -> void:
	var accent: Color = Liveries.color_for(team)
	# Rear wall panel seams and the pit-lane header above the open front.
	for side: float in [-1.0, 1.0]:
		_box(stall, "RearPillar%s" % ("L" if side < 0.0 else "R"), Vector3(0.16, WALL_HEIGHT, 0.2),
			Vector3(side * (STALL_HALF_WIDTH - 0.16), WALL_HEIGHT * 0.5, -STALL_DEPTH * 0.5 + 0.24), _steel)
	_box(stall, "HeaderBeam", Vector3(11.9, 0.9, 0.22), Vector3(0.0, 4.0, STALL_FRONT_Z), _steel)
	for side: float in [-1.0, 1.0]:
		_box(stall, "FrontPost%s" % ("L" if side < 0.0 else "R"), Vector3(0.14, 4.0, 0.14),
			Vector3(side * (STALL_HALF_WIDTH - 0.1), 2.0, STALL_FRONT_Z), _steel)
	var header_text := Label3D.new()
	header_text.name = "StallHeader"
	header_text.text = "STALL %02d // %s" % [team + 1, Gt.TEAM_NAMES[team].to_upper()]
	header_text.font = load("res://assets/fonts/Anton.ttf")
	header_text.font_size = 72
	header_text.pixel_size = 0.0082
	header_text.modulate = accent
	header_text.outline_size = 0
	header_text.shaded = false
	header_text.position = Vector3(0.0, 4.0, STALL_FRONT_Z + 0.13)
	stall.add_child(header_text)
	# Number plate on the rear wall.
	var rear_sign := Label3D.new()
	rear_sign.name = "TeamPlate"
	rear_sign.text = "%02d\n%s" % [team + 1, Gt.TEAM_NAMES[team].to_upper()]
	rear_sign.font = load("res://assets/fonts/Anton.ttf")
	rear_sign.font_size = 72
	rear_sign.pixel_size = 0.006
	rear_sign.modulate = accent.darkened(0.12)
	rear_sign.outline_size = 8
	rear_sign.outline_modulate = Color(0.02, 0.02, 0.02)
	rear_sign.shaded = false
	rear_sign.position = Vector3(-2.8, 3.2, -STALL_DEPTH * 0.5 + 0.2)
	stall.add_child(rear_sign)
	_build_tyre_rack(stall)
	_build_toolbox(stall, accent)
	_build_monitor(stall)
	var light := OmniLight3D.new()
	light.name = "StallLight"
	light.position = Vector3(0.0, 3.4, 1.0)
	light.light_color = accent.lerp(Color.WHITE, 0.55)
	light.light_energy = 1.7
	light.omni_range = 12.0
	light.shadow_enabled = false
	stall.add_child(light)


func _build_tyre_rack(stall: Node3D) -> void:
	var rack := Node3D.new()
	rack.name = "TyreRack"
	rack.position = Vector3(-4.55, 0.0, -5.65)
	stall.add_child(rack)
	for side: float in [-1.0, 1.0]:
		_box(rack, "Upright%s" % ("L" if side < 0.0 else "R"), Vector3(0.13, 2.15, 0.85),
			Vector3(side * 1.28, 1.075, 0.0), _steel)
	for level: int in range(3):
		var y: float = 0.55 + float(level) * 0.64
		_box(rack, "Shelf%d" % level, Vector3(2.85, 0.08, 0.9), Vector3(0.0, y, 0.0), _steel_light)
		for side: float in [-1.0, 1.0]:
			var tyre := MeshInstance3D.new()
			tyre.name = "Tyre%d%s" % [level, "L" if side < 0.0 else "R"]
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.36
			cylinder.bottom_radius = 0.36
			cylinder.height = 0.25
			cylinder.radial_segments = 18
			cylinder.rings = 1
			tyre.mesh = cylinder
			tyre.material_override = ToonMaterials.make(Color("#17181c"))
			tyre.position = Vector3(side * 0.72, y + 0.17, 0.0)
			rack.add_child(tyre)
			var compound: int = (level * 2 + (1 if side > 0.0 else 0)) % COMPOUND_COLORS.size()
			var band := MeshInstance3D.new()
			band.name = "CompoundBand"
			var hub := CylinderMesh.new()
			hub.top_radius = 0.18
			hub.bottom_radius = 0.18
			hub.height = 0.27
			hub.radial_segments = 14
			band.mesh = hub
			band.material_override = ToonMaterials.make(COMPOUND_COLORS[compound])
			band.position = Vector3(0.0, 0.0, 0.0)
			tyre.add_child(band)


func _build_toolbox(stall: Node3D, accent: Color) -> void:
	var toolbox := Node3D.new()
	toolbox.name = "Toolbox"
	toolbox.position = Vector3(4.35, 0.0, -5.75)
	stall.add_child(toolbox)
	_box(toolbox, "Cabinet", Vector3(1.9, 1.05, 0.72), Vector3(0.0, 0.525, 0.0), ToonMaterials.make(Color("#0d0e12")))
	for drawer: int in range(4):
		_box(toolbox, "Drawer%d" % drawer, Vector3(1.68, 0.018, 0.03),
			Vector3(0.0, 0.22 + float(drawer) * 0.2, 0.37), _steel_light)
	_box(toolbox, "TeamStripe", Vector3(1.4, 0.06, 0.035), Vector3(0.0, 0.96, 0.37),
		ToonMaterials.emissive(accent, 1.2))


func _build_monitor(stall: Node3D) -> void:
	var mount := Node3D.new()
	mount.name = "Telemetry"
	mount.position = Vector3(3.1, 0.0, -5.55)
	stall.add_child(mount)
	_box(mount, "Hanger", Vector3(0.08, 1.4, 0.08), Vector3(0.0, 3.9, 0.0), _steel)
	var frame := Node3D.new()
	frame.name = "ScreenFrame"
	frame.position = Vector3(0.0, 3.0, 0.0)
	frame.rotation_degrees = Vector3(-14.0, 0.0, 0.0)
	mount.add_child(frame)
	_box(frame, "Frame", Vector3(1.95, 1.1, 0.1), Vector3.ZERO, _steel)
	_box(frame, "Screen", Vector3(1.72, 0.88, 0.02), Vector3(0.0, 0.0, 0.06),
		ToonMaterials.emissive(SCREEN_COLOR.darkened(0.55), 1.6))
	var screen_text := Label3D.new()
	screen_text.name = "ScreenText"
	screen_text.text = "TELEMETRY // LIVE"
	screen_text.font = load("res://assets/fonts/JetBrainsMono.ttf")
	screen_text.font_size = 42
	screen_text.pixel_size = 0.006
	screen_text.modulate = SCREEN_COLOR
	screen_text.outline_size = 0
	screen_text.shaded = false
	screen_text.position = Vector3(0.0, 0.05, 0.08)
	frame.add_child(screen_text)


func _build_partitions() -> void:
	var depth: float = STALL_DEPTH * 0.5 + PARTITION_FRONT_Z
	var center_z: float = (PARTITION_FRONT_Z - STALL_DEPTH * 0.5) * 0.5
	for boundary: int in range(_stall_count + 1):
		var x: float = float(boundary) * STALL_SPACING - STALL_SPACING * 0.5
		_box(self, "Partition%02d" % boundary, Vector3(0.34, WALL_HEIGHT, depth),
			Vector3(x, WALL_HEIGHT * 0.5, center_z), _wall)
		_box(self, "PartitionCap%02d" % boundary, Vector3(0.5, 0.16, depth),
			Vector3(x, WALL_HEIGHT - 0.08, center_z), _steel)
		for side: float in [-1.0, 1.0]:
			var team: int = boundary - 1 if side < 0.0 else boundary
			if team < 0 or team >= _stall_count:
				continue
			_box(self, "Led%02d%s" % [boundary, "L" if side < 0.0 else "R"],
				Vector3(0.06, 3.1, 0.14), Vector3(x + side * 0.2, 1.95, PARTITION_FRONT_Z - 0.15),
				ToonMaterials.emissive(Liveries.color_for(team), 2.2))


func _build_ceiling_lights() -> void:
	for team: int in range(_stall_count):
		var x: float = float(team) * STALL_SPACING
		_box(self, "RoofBeam%02d" % (team + 1), Vector3(12.0, 0.18, 0.3),
			Vector3(x, WALL_HEIGHT + 0.05, 0.0), _steel)
		_box(self, "LightBar%02d" % (team + 1), Vector3(8.4, 0.06, 0.32),
			Vector3(x, WALL_HEIGHT - 0.06, 0.0), ToonMaterials.emissive(Color("#dfe8f5"), 3.0))
		_box(self, "LightBarRear%02d" % (team + 1), Vector3(6.4, 0.05, 0.22),
			Vector3(x, WALL_HEIGHT - 0.06, -2.8), ToonMaterials.emissive(Color("#cfe0f5"), 2.2))
		_box(self, "LightBarFront%02d" % (team + 1), Vector3(6.4, 0.05, 0.22),
			Vector3(x, WALL_HEIGHT - 0.06, 2.8), ToonMaterials.emissive(Color("#cfe0f5"), 2.2))


func _build_reflection_probe() -> void:
	var width: float = float(_stall_count) * STALL_SPACING + 6.0
	var center_x: float = (float(_stall_count - 1) * STALL_SPACING) * 0.5
	var probe := ReflectionProbe.new()
	probe.name = "EpoxyReflections"
	probe.position = Vector3(center_x, 1.8, 0.0)
	probe.size = Vector3(width, 8.0, STALL_DEPTH + 3.0)
	probe.box_projection = true
	probe.interior = false
	probe.intensity = 0.7
	probe.max_distance = 45.0
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)


func _instantiate_car(team: int) -> Node3D:
	var path: String = Roster.car_path(team)
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("Garage car missing: %s" % path)
		var placeholder := Node3D.new()
		placeholder.name = "Car%02d" % (team + 1)
		return placeholder
	var instance: Node = packed.instantiate()
	var car: Node3D = instance as Node3D
	if car == null:
		car = Node3D.new()
		car.add_child(instance)
	car.name = "Car%02d" % (team + 1)
	_fit_car(car)
	return car


## Bounds are measured from the imported meshes, then the instance root is rotated and
## uniformly scaled onto the stall floor. The PackedScene and its meshes stay untouched.
func _fit_car(car: Node3D) -> void:
	var original := car.transform
	var found: Array[AABB] = []
	_collect_bounds(car, original, found)
	if found.is_empty():
		car_bounds.append(AABB())
		return
	var bounds: AABB = found[0]
	for index: int in range(1, found.size()):
		bounds = bounds.merge(found[index])
	car_bounds.append(bounds)
	var size: Vector3 = bounds.size
	var fit: float = CAR_TARGET_LENGTH_M / maxf(maxf(size.x, size.z), 0.01)
	fit = minf(fit, CAR_MAX_WIDTH_M / maxf(minf(size.x, size.z), 0.01))
	fit = minf(fit, CAR_MAX_HEIGHT_M / maxf(size.y, 0.01))
	var turn := Basis.IDENTITY
	if size.x > size.z:
		turn = Basis(Vector3.UP, PI * 0.5)
	var fitted := turn.scaled(Vector3.ONE * fit)
	var origin: Vector3 = Vector3(0.0, size.y * fit * 0.5, 0.0) - fitted * bounds.get_center()
	car.transform = Transform3D(fitted, origin) * original


func _collect_bounds(node: Node, parent_xform: Transform3D, out: Array[AABB]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			out.append(parent_xform * mesh_instance.mesh.get_aabb())
	for child: Node in node.get_children():
		var xform: Transform3D = parent_xform
		if child is Node3D:
			xform = parent_xform * (child as Node3D).transform
		_collect_bounds(child, xform, out)


func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = _unit_box
	instance.material_override = material
	instance.position = position
	instance.scale = size
	parent.add_child(instance)
	return instance
