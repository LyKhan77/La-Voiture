class_name SafetyCarChassis
extends ModularCarAssembler

## The official FIA safety car: the Porsche body in a silver livery with SAFETY CAR lettering, hazard chevron tape down both
## sides and a roof lightbar. The lightbar strobes amber while the car leads the field and holds green on its in lap.

enum StrobeMode { OFF, AMBER, GREEN }

const STROBE_HZ: float = 12.0
const HAZARD_YELLOW := Color("#ffd400")
const HAZARD_INK := Color("#14161c")
## Chassis-local x of the door skin (0.91 to 0.93 m off the centre line); decals float 1 cm proud of it.
const DOOR_X: float = 0.94
const LETTERING: String = "SAFETY CAR"
## Hazard tape: V bands pointing at the nose, alternating yellow and ink, between the two wheel arches.
const TAPE_Z_FROM: float = -0.8
const TAPE_BANDS: int = 16
const TAPE_BAND_W: float = 0.1
const TAPE_APEX: float = 0.06
const TAPE_Y_LOW: float = 0.4
const TAPE_Y_MID: float = 0.46
const TAPE_Y_HIGH: float = 0.52

var strobe_mode: StrobeMode = StrobeMode.OFF
## Roof LEDs in order along the bar: even indices flash together, odd indices flash against them.
var amber_leds: Array[MeshInstance3D] = []
var green_leds: Array[MeshInstance3D] = []
## One behind each side of the grille; left flashes with the even roof LEDs, right with the odd ones.
var grille_leds: Array[MeshInstance3D] = []

var _clock: float = 0.0

@onready var lightbar: MeshInstance3D = $RooftopLightbar


func _ready() -> void:
	super()
	for index: int in range(4):
		amber_leds.append(lightbar.get_node("AmberLed%d" % index))
	for index: int in range(2):
		green_leds.append(lightbar.get_node("GreenLed%d" % index))
	grille_leds.append(get_node("GrilleStrobeL"))
	grille_leds.append(get_node("GrilleStrobeR"))
	_build_livery()
	set_process(false)
	_apply_strobe()


## Idempotent: the VFX layer calls this every frame with the phase it sees, and only a change restarts the flash cycle.
func set_strobe_mode(mode: StrobeMode) -> void:
	if mode == strobe_mode:
		return
	strobe_mode = mode
	_clock = 0.0
	set_process(mode == StrobeMode.AMBER)
	_apply_strobe()


## Steps the strobe clock; _process calls it with the frame time, tests call it directly.
func advance(dt: float) -> void:
	_clock += dt
	_apply_strobe()


func _process(delta: float) -> void:
	advance(delta)


func _apply_strobe() -> void:
	var amber: bool = strobe_mode == StrobeMode.AMBER
	var first_pair_lit: bool = fposmod(_clock * STROBE_HZ, 1.0) < 0.5
	for index: int in range(amber_leds.size()):
		amber_leds[index].visible = amber and first_pair_lit == (index % 2 == 0)
	for index: int in range(grille_leds.size()):
		grille_leds[index].visible = amber and first_pair_lit == (index % 2 == 0)
	for led: MeshInstance3D in green_leds:
		led.visible = strobe_mode == StrobeMode.GREEN


# --- livery ------------------------------------------------------------------------------------

func _build_livery() -> void:
	var door_y: float = 0.64
	add_child(_lettering("LetteringDoorR", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(DOOR_X, door_y, -0.12))))
	add_child(_lettering("LetteringDoorL", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-DOOR_X, door_y, -0.12))))
	# The bonnet is flat across its width only near z 1.15 (it dips in the middle further forward) and falls away to the nose
	# at about 10 degrees there: lay the text on that slope.
	add_child(_lettering("LetteringBonnet", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-80.0)), Vector3(0.0, 0.848, 1.15))))
	var tape: ArrayMesh = _hazard_tape_mesh()
	for side: float in [1.0, -1.0]:
		var strip := MeshInstance3D.new()
		strip.name = "ChevronStripR" if side > 0.0 else "ChevronStripL"
		strip.mesh = tape
		strip.position = Vector3(side * (DOOR_X + 0.005), 0.0, 0.0)
		strip.scale = Vector3(side, 1.0, 1.0)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(strip)


func _lettering(node_name: String, placement: Transform3D) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = LETTERING
	label.font_size = 64
	label.pixel_size = 0.0025
	label.modulate = HAZARD_INK
	label.outline_modulate = HAZARD_YELLOW
	label.outline_size = 10
	label.transform = placement
	return label


## Flat unlit tape: the bands tile the strip with no overlap, so there is nothing to z-fight.
func _hazard_tape_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band: int in range(TAPE_BANDS):
		var z: float = TAPE_Z_FROM + float(band) * TAPE_BAND_W
		surface.set_color(HAZARD_YELLOW if band % 2 == 0 else HAZARD_INK)
		var lower: Array[Vector3] = [Vector3(0.0, TAPE_Y_LOW, z), Vector3(0.0, TAPE_Y_MID, z + TAPE_APEX), Vector3(0.0, TAPE_Y_HIGH, z)]
		for arm: int in range(2):
			var a: Vector3 = lower[arm]
			var b: Vector3 = lower[arm + 1]
			var ahead := Vector3(0.0, 0.0, TAPE_BAND_W)
			for corner: Vector3 in [a, b, b + ahead, a, b + ahead, a + ahead]:
				surface.add_vertex(corner)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true # the tape colours are sRGB hex values; read as linear the ink would turn grey
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(material)
	return surface.commit()
