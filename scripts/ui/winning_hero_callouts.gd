extends RefCounted

## Marker-pen callouts glued to the hero car: engine and rear wing on the hero cut, front wheel and
## splitter on the detail cut. Anchor points are fractions of the model's own bounds, so any of the
## ten GT3 bodies gets sensible dots without per-car coordinates; the notes follow the turntable by
## projecting the anchors through the live camera every frame.

const Kit := preload("res://scripts/ui/graffiti_kit.gd")

const STAGE := Vector2(1920.0, 1080.0)
const NOTE_KEYS: Array[StringName] = [&"engine", &"wing", &"wheel", &"splitter"]
const HERO_KEYS: Array[StringName] = [&"engine", &"wing"]
const DETAIL_KEYS: Array[StringName] = [&"wheel", &"splitter"]
## Where each anchor sits inside the model bounds (fraction of x, y, z; +z is the nose).
const FRACTIONS: Dictionary = {
	&"engine": Vector3(0.5, 0.62, 0.72), &"wing": Vector3(0.5, 0.95, 0.06),
	&"wheel": Vector3(0.92, 0.2, 0.78), &"splitter": Vector3(0.5, 0.05, 1.0),
}
## Note placement relative to its projected anchor (stage px), and the stage margin notes keep from the edges.
const OFFSETS: Dictionary = {
	&"engine": Vector2(-330.0, -170.0), &"wing": Vector2(140.0, -230.0),
	&"wheel": Vector2(150.0, -210.0), &"splitter": Vector2(-480.0, 90.0),
}
const MARGIN_MIN := Vector2(40.0, 110.0)
const MARGIN_MAX := Vector2(1440.0, 960.0)


## The turntable spins, so "the" front wheel is whichever side faces the camera right now.
static func _near_side(anchor: Vector3, bounds: AABB, model: Node3D, camera: Camera3D) -> Vector3:
	var mirrored := Vector3(bounds.position.x * 2.0 + bounds.size.x - anchor.x, anchor.y, anchor.z)
	var here: float = model.to_global(anchor).distance_squared_to(camera.global_position)
	var there: float = model.to_global(mirrored).distance_squared_to(camera.global_position)
	return anchor if here <= there else mirrored


static func anchors(bounds: AABB) -> Dictionary:
	var points: Dictionary = {}
	for key: StringName in NOTE_KEYS:
		points[key] = bounds.position + bounds.size * (FRACTIONS[key] as Vector3)
	return points


## All four notes and arrows, hidden. `engine` is the layout string only (no power figures).
static func build(car_name: String, engine: String) -> Control:
	var root := Control.new()
	root.name = "HeroCallouts"
	root.size = STAGE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	var notes: Dictionary = {
		&"engine": Kit.marker_note(engine, car_name.to_upper()),
		&"wing": Kit.marker_note("SWAN-NECK WING"),
		&"wheel": Kit.marker_note("BBS FI-R", "FORGED"),
		&"splitter": Kit.marker_note("CARBON SPLITTER"),
	}
	for key: StringName in NOTE_KEYS:
		var arrow := Line2D.new()
		arrow.name = "Arrow_%s" % key
		arrow.width = 7.0
		arrow.default_color = Kit.LIME
		arrow.joint_mode = Line2D.LINE_JOINT_ROUND
		arrow.visible = false
		root.add_child(arrow)
		var note: Control = notes[key]
		note.name = "Note_%s" % key
		note.visible = false
		root.add_child(note)
	return root


## Shows the notes of `cut` (hero or detail) and pins them to the projected anchors; hides everything otherwise.
static func place(root: Control, camera: Camera3D, model: Node3D, bounds: AABB, view: Vector2, cut: int) -> void:
	var keys: Array[StringName] = []
	if cut == WinningCutDirector.Cut.HERO:
		keys = HERO_KEYS
	elif cut == WinningCutDirector.Cut.DETAIL:
		keys = DETAIL_KEYS
	root.visible = not keys.is_empty()
	if keys.is_empty():
		return
	var factor: float = minf(view.x / STAGE.x, view.y / STAGE.y)
	var origin: Vector2 = (view - STAGE * factor) * 0.5
	var points: Dictionary = anchors(bounds)
	for key: StringName in NOTE_KEYS:
		var shown: bool = keys.has(key)
		var note: Control = root.get_node("Note_%s" % key)
		var arrow: Line2D = root.get_node("Arrow_%s" % key)
		note.visible = shown
		arrow.visible = shown
		if not shown:
			continue
		var anchor: Vector3 = points[key]
		if key == &"wheel":
			anchor = _near_side(anchor, bounds, model, camera)
		var target: Vector2 = (camera.unproject_position(model.to_global(anchor)) - origin) / factor
		note.position = (target + (OFFSETS[key] as Vector2)).clamp(MARGIN_MIN, MARGIN_MAX)
		var body: Vector2 = (note.get_node("Body") as Control).get_combined_minimum_size()
		arrow.points = Kit.arrow_points(note.position + Vector2(body.x * 0.5, body.y), target)
