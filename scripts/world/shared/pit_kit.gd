extends RefCounted

## What every circuit's pit complex shares, so no circuit has to borrow it from another: the road asphalt, the
## 13-person standby crew line-up, the painted pit box with its number, and the equipment inside a garage. The
## circuits (apex_ring, brianza, neo_wangan) own their lane and garage geometry; this holds only what is identical.

const FigureScript := preload("res://scripts/car/pit_crew_figure.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const RoadShader := preload("res://shaders/road_asphalt.gdshader")

## The painted box: half width across the lane, length along it, the white line width, and the paint's height.
const BOX_HALF_WIDTH_M: float = 1.65
const BOX_LENGTH_M: float = 6.4
const BOX_LINE_M: float = 0.12
const PAINT_Y: float = 0.035
const PAINT_WHITE := Color("#f4f5f7")
const PAINT_YELLOW := Color("#ffd400")
## The garage the props are laid out for (the ceiling light bars hang at this height); every circuit's garage matches it.
const GARAGE_HEIGHT_M: float = 4.2


static var _asphalt_material: ShaderMaterial


## The asphalt both pit lane and road share: the track's own weather shader, dark asphalt vertex colour.
static func asphalt_material() -> ShaderMaterial:
	if _asphalt_material == null:
		_asphalt_material = ShaderMaterial.new()
		_asphalt_material.shader = RoadShader
	return _asphalt_material


## The roles of the crew standing by, in the order they line up across the garage mouth.
static func standby_roles() -> Array:
	return [
		FigureScript.Role.FIRE, FigureScript.Role.JACK, FigureScript.Role.GUNNER, FigureScript.Role.GUNNER, FigureScript.Role.HANDLER,
		FigureScript.Role.HANDLER, FigureScript.Role.LOLLIPOP, FigureScript.Role.HANDLER, FigureScript.Role.HANDLER,
		FigureScript.Role.GUNNER, FigureScript.Role.GUNNER, FigureScript.Role.JACK, FigureScript.Role.FUELER,
	]


## Where crew member `slot` stands inside the garage (garage frame: +x away from the lane).
static func standby_spot(slot: int) -> Vector3:
	var count: int = standby_roles().size()
	return Vector3(1.5, 0.0, (float(slot) - float(count - 1) * 0.5) * 0.88)


## A box-local offset (x across the lane, z along it) in the pit lane's own frame.
static func local(pose: Transform3D, offset: Vector3) -> Transform3D:
	return Transform3D(pose.basis, pose * offset)


## The team's pit box: coloured pad, white outline, yellow nose line and the box number. `pose` is the box in the frame
## the batch is built in and `lane_m` its lateral on the circuit; the box is also recorded in `markings`.
static func paint_box(batch: MeshBatchScript, material: Material, stall: Dictionary, pose: Transform3D, lane_m: float, markings: Array[Dictionary]) -> void:
	var team: int = int(stall.get("team", 0))
	var half_w: float = BOX_HALF_WIDTH_M
	var half_l: float = BOX_LENGTH_M * 0.5
	var color: Color = Liveries.color_for(team)
	# Local box frame: x across the lane (toward the garage), z along it (- forward).
	batch.box(material, color, local(pose, Vector3(0.0, PAINT_Y - 0.004, 0.0)), Vector3(half_w * 2.0 - 0.3, 0.012, BOX_LENGTH_M - 0.3))
	for edge: float in [-1.0, 1.0]:
		batch.box(material, PAINT_WHITE, local(pose, Vector3(edge * half_w, PAINT_Y, 0.0)), Vector3(BOX_LINE_M, 0.014, BOX_LENGTH_M))
		batch.box(material, PAINT_WHITE, local(pose, Vector3(0.0, PAINT_Y, edge * half_l)), Vector3(half_w * 2.0, 0.014, BOX_LINE_M))
	# Where the nose goes (the sim parks the car's centre on the box): a short yellow bar.
	batch.box(material, PAINT_YELLOW, local(pose, Vector3(0.0, PAINT_Y + 0.002, -(half_l - 0.55))), Vector3(1.5, 0.014, 0.16))
	paint_number(batch, material, pose, team + 1)
	markings.append({"team": team, "number": team + 1, "lateral": lane_m, "half_width": half_w, "length": BOX_LENGTH_M})


## Seven-segment numerals laid on the ground beside the box, readable from the fast lane.
static func paint_number(batch: MeshBatchScript, material: Material, pose: Transform3D, number: int) -> void:
	var digits: Array[int] = []
	for character: String in str(number):
		digits.append(int(character))
	var segments: Array[int] = [0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F]
	var width: float = 0.5
	var height: float = 0.9
	var thickness: float = 0.1
	# Per segment a..g: (offset along the text's up, offset across, size along up, size across).
	var layout: Array[Vector4] = [
		Vector4(height * 0.5, 0.0, thickness, width), Vector4(height * 0.25, width * 0.5, height * 0.5, thickness),
		Vector4(-height * 0.25, width * 0.5, height * 0.5, thickness), Vector4(-height * 0.5, 0.0, thickness, width),
		Vector4(-height * 0.25, -width * 0.5, height * 0.5, thickness), Vector4(height * 0.25, -width * 0.5, height * 0.5, thickness),
		Vector4(0.0, 0.0, thickness, width),
	]
	for place: int in range(digits.size()):
		# Text up = toward the garage (+x), advancing along +z.
		var origin := Vector3(-(BOX_HALF_WIDTH_M + 0.9), PAINT_Y, (float(place) - float(digits.size() - 1) * 0.5) * (width + 0.25))
		var mask: int = segments[digits[place]]
		for bit: int in range(7):
			if (mask >> bit) & 1 == 0:
				continue
			var segment: Vector4 = layout[bit]
			batch.box(material, PAINT_WHITE, local(pose, origin + Vector3(segment.x, 0.0, segment.y)), Vector3(segment.z, 0.014, segment.w))


## Tyre stacks, wheel guns, jacks, fuel rig, extinguishers, the monitor desk with its engineers and the
## lights, in garage coordinates. Returns what was placed, for the equipment check.
static func garage_props(batch: MeshBatchScript, material: Material, team_color: Color) -> Dictionary:
	var tyre := Color("#17181c")
	var compounds: Array[Color] = [Color("#e0212e"), Color("#ffd400"), Color("#f4f5f7"), Color("#2f6fe0")] # soft, medium, hard, wet
	for stack: int in range(4):
		var z: float = -5.3 + 1.05 * float(stack)
		for layer: int in range(4):
			batch.cylinder(material, tyre, Transform3D(Basis.IDENTITY, Vector3(7.9, 0.02 + 0.3 * float(layer), z)), 0.33, 0.33, 0.3, 10, true, false)
		batch.cylinder(material, compounds[stack], Transform3D(Basis.IDENTITY, Vector3(7.9, 1.23, z)), 0.27, 0.27, 0.025, 10, true, false)
	# Wheel guns on a rack against the back wall, with their air hoses.
	batch.box(material, Color("#4a505c"), Transform3D(Basis.IDENTITY, Vector3(8.5, 0.45, 4.6)), Vector3(0.5, 0.9, 1.5))
	for gun: int in range(4):
		batch.box(material, FigureScript.GUN_COLOR, Transform3D(Basis.IDENTITY, Vector3(8.45, 0.98, 4.1 + 0.33 * float(gun))), Vector3(0.12, 0.12, 0.26))
		batch.box(material, FigureScript.HOSE_COLOR, Transform3D(Basis.IDENTITY, Vector3(8.85, 0.7, 4.1 + 0.33 * float(gun))), Vector3(0.05, 0.05, 0.3))
	# Two hydraulic jack carts.
	for jack: int in range(2):
		var z: float = 2.6 + 1.1 * float(jack)
		batch.box(material, FigureScript.GUN_COLOR, Transform3D(Basis.IDENTITY, Vector3(3.4, 0.14, z)), Vector3(0.9, 0.2, 0.5))
		batch.box(material, FigureScript.GUN_COLOR, Transform3D(Basis.IDENTITY, Vector3(3.2, 0.48, z)), Vector3(0.12, 0.7, 0.12))
		batch.box(material, FigureScript.HOSE_COLOR, Transform3D(Basis.IDENTITY, Vector3(3.9, 0.62, z)), Vector3(0.6, 0.05, 0.05))
	# Fuel rig: tank on a trolley with a hose and nozzle.
	batch.cylinder(material, Color("#9aa1ae"), Transform3D(Basis.IDENTITY, Vector3(4.2, 0.2, -5.4)), 0.3, 0.3, 0.9, 10)
	batch.box(material, Color("#4a505c"), Transform3D(Basis.IDENTITY, Vector3(4.2, 0.1, -5.4)), Vector3(0.9, 0.12, 0.7))
	batch.box(material, FigureScript.HOSE_COLOR, Transform3D(Basis.IDENTITY, Vector3(3.2, 0.5, -5.4)), Vector3(1.8, 0.05, 0.05))
	batch.box(material, Color("#c9cdd6"), Transform3D(Basis.IDENTITY, Vector3(2.2, 0.55, -5.4)), Vector3(0.3, 0.1, 0.1))
	# Extinguishers at both sides of the garage mouth.
	for side: float in [-1.0, 1.0]:
		batch.cylinder(material, FigureScript.EXTINGUISHER_COLOR, Transform3D(Basis.IDENTITY, Vector3(0.7, 0.0, side * 5.95)), 0.1, 0.1, 0.6, 8)
	# Monitor desk with three screens and two engineers.
	batch.box(material, Color("#3a3f4a"), Transform3D(Basis.IDENTITY, Vector3(6.0, 0.4, 0.0)), Vector3(0.9, 0.8, 2.6))
	for monitor: int in range(3):
		batch.box(material, Color(0.2, 0.7, 1.0, 0.3), Transform3D(Basis(Vector3.UP, 0.12 * float(monitor - 1)), Vector3(5.8, 1.08, (float(monitor) - 1.0) * 0.8)), Vector3(0.06, 0.5, 0.7))
	for engineer: int in range(2):
		FigureScript.add(batch, material, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(6.9, 0.0, (float(engineer) - 0.5) * 1.1)), FigureScript.Role.ENGINEER, team_color)
	# A tool chest, a pennant in the team colour, and three light bars under the roof.
	batch.box(material, FigureScript.EXTINGUISHER_COLOR, Transform3D(Basis.IDENTITY, Vector3(8.4, 0.55, 1.3)), Vector3(0.6, 1.1, 1.0))
	batch.box(material, team_color, Transform3D(Basis.IDENTITY, Vector3(8.78, 2.8, 0.0)), Vector3(0.05, 1.4, 3.6))
	for bar: int in range(3):
		batch.box(material, Color(1.0, 0.97, 0.88, 0.0), Transform3D(Basis.IDENTITY, Vector3(2.0 + 2.6 * float(bar), GARAGE_HEIGHT_M - 0.08, 0.0)), Vector3(0.14, 0.06, 7.0))
	return {"tyre_stacks": 4, "wheel_guns": 4, "jacks": 2, "fuel_rigs": 1, "extinguishers": 2, "monitors": 3, "light_bars": 3, "engineers": 2}


# --- signs ------------------------------------------------------------------------------------------------
