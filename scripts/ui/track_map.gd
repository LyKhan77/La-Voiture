class_name TrackMapView
extends Control

## The circuit map of the race setup screen, traced live from the round's own scene instead of a
## hand-drawn picture: the real length, the real corners numbered from curvature, three sector
## colours and the real elevation profile. It follows whichever round the Track Selector picks —
## Apex Ring, Neo-Wangan, or a calendar round whose layout is not built yet (then it says so).

const CircuitScene := preload("res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn")
const CircuitDataScript := preload("res://scripts/core/circuit_data.gd")
const DEFAULT_SCENE_PATH := "res://scenes/race_world/circuits/apex_ring/apex_circuit.tscn"
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const DISPLAY := preload("res://assets/fonts/Anton.ttf")
const MONO := preload("res://assets/fonts/JetBrainsMono.ttf")

const SAMPLE_STEP_M: float = 2.0
const MARGIN_PX: float = 34.0
const ELEVATION_STRIP_H: float = 74.0
const TURN_LABEL_SIZE: int = 17
const CORNER_TURN_RAD: float = 0.25
const CORNER_STEP_RAD: float = 0.02
const CORNER_MERGE_M: float = 26.0
const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
## Broadcast sector colours (the ink plate keeps lime for the DRS zones).
const SECTOR_COLORS: Array[Color] = [
	Color("#00F0FF"), Color("#FFE600"), Color("#FF1A4B"),
]
const CASING_PX: float = 28.0
const ASPHALT_PX: float = 20.0
const ASPHALT_COLOR := Color("#2A2C33")
const BAND_PX: float = 6.0
const BADGE_OFFSET_PX: float = 30.0
const BADGE_SIZE := Vector2(34.0, 26.0)

var length_m: float = 0.0
## Corner apexes in travel order: {"s": arc metres, "angle": signed radians}.
var turns: Array[Dictionary] = []
## The real DRS zones of the circuit: {"start_s", "end_s"} in arc metres.
var drs_zones: Array[Dictionary] = []
var min_elevation: float = 0.0
var max_elevation: float = 0.0
## Which calendar round the map is showing, and the scene it was traced from.
var circuit_id: String = "apex_ring"
var scene_path: String = DEFAULT_SCENE_PATH
## The circuit's own numbered turns, when its scene publishes them (empty for the Apex Ring).
var official_turns: Array[Dictionary] = []

var _raw := PackedVector2Array() # XZ metres, evenly spaced along the baked curve
var _elevation := PackedFloat32Array()
var _total_turn: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_load_track()


## Live numbers for the setup card.
func stats() -> Dictionary:
	return {
		"length_m": length_m,
		"corners": turns.size(),
		"direction": "CLOCKWISE" if _total_turn > 0.0 else "ANTICLOCKWISE",
		"elevation_delta": max_elevation - min_elevation,
		"sectors": SECTOR_COLORS.size(),
	}


## Traces another round on the card. A round whose layout is not built yet clears the map.
func load_circuit(circuit: CircuitDataScript) -> void:
	if circuit == null:
		return
	circuit_id = circuit.circuit_id
	if circuit.scene_path == scene_path and length_m > 0.0:
		queue_redraw()
		return
	scene_path = circuit.scene_path
	_load_track()


func _load_track() -> void:
	length_m = 0.0
	min_elevation = 0.0
	max_elevation = 0.0
	_total_turn = 0.0
	turns.clear()
	official_turns.clear()
	drs_zones.clear()
	_raw = PackedVector2Array()
	_elevation = PackedFloat32Array()
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		queue_redraw()
		return
	var node: Node = (load(scene_path) as PackedScene).instantiate()
	var ribbon := node as TrackRibbonScript
	add_child(node) # the ribbon builds its sample table when it enters the tree
	if ribbon == null:
		ribbon = node.get_node_or_null("TrackRibbon") as TrackRibbonScript
	if ribbon == null:
		remove_child(node)
		node.free()
		queue_redraw()
		return
	var curve: Curve3D = ribbon.curve.duplicate() as Curve3D
	drs_zones = GtTrack.new(ribbon).drs_zones
	# A circuit that ships its own numbered turn list (Neo-Wangan) is drawn from that list, so the
	# map and the circuit's official turn numbers never disagree.
	var official: Variant = node.get("turns")
	if official is Array and not (official as Array).is_empty():
		official_turns.clear()
		for entry: Dictionary in official:
			official_turns.append({"s": float(entry["s"]), "angle": -float(entry["direction"])})
	remove_child(node)
	node.free()
	if curve == null:
		return
	curve.bake_interval = SAMPLE_STEP_M
	length_m = curve.get_baked_length()
	var count: int = maxi(24, ceili(length_m / SAMPLE_STEP_M))
	_raw.resize(count)
	_elevation.resize(count)
	for i: int in range(count):
		var at: Vector3 = curve.sample_baked(length_m * float(i) / float(count), true)
		_raw[i] = Vector2(at.x, at.z)
		_elevation[i] = at.y
	min_elevation = _elevation[0]
	max_elevation = _elevation[0]
	for value: float in _elevation:
		min_elevation = minf(min_elevation, value)
		max_elevation = maxf(max_elevation, value)
	_detect_corners()
	if not official_turns.is_empty():
		turns = official_turns.duplicate()
	queue_redraw()


## Corners from the heading change along the baked line: contiguous turning stretches whose
## accumulated angle passes CORNER_TURN_RAD become one numbered apex.
func _detect_corners() -> void:
	var count: int = _raw.size()
	if count < 8:
		return
	var heading := PackedFloat32Array()
	heading.resize(count)
	_total_turn = 0.0
	for i: int in range(count):
		var step: Vector2 = _raw[(i + 1) % count] - _raw[i]
		heading[i] = step.angle()
	var delta := PackedFloat32Array()
	delta.resize(count)
	for i: int in range(count):
		delta[i] = wrapf(heading[(i + 1) % count] - heading[i], -PI, PI)
		_total_turn += delta[i]
	# Start scanning from the straightest sample so a corner across the seam stays whole.
	var origin: int = 0
	for i: int in range(count):
		if absf(delta[i] + delta[posmod(i - 1, count)]) < absf(delta[origin] + delta[posmod(origin - 1, count)]):
			origin = i
	var spacing: float = length_m / float(count)
	var found: Array[Dictionary] = []
	var start_index: int = -1
	var total: float = 0.0
	for step: int in range(count + 1):
		var i: int = (origin + step) % count
		var rate: float = absf(delta[i]) + absf(delta[posmod(i + 1, count)])
		if rate > CORNER_STEP_RAD:
			if start_index < 0:
				start_index = step
				total = 0.0
			total += delta[i]
		elif start_index >= 0:
			if absf(total) > CORNER_TURN_RAD:
				var s: float = float((origin + start_index) % count) * spacing
				found.append({"s": s, "angle": total})
			start_index = -1
	if start_index >= 0 and absf(total) > CORNER_TURN_RAD:
		found.append({"s": float((origin + start_index) % count) * spacing, "angle": total})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))
	turns.clear()
	for corner: Dictionary in found:
		if not turns.is_empty():
			var previous: Dictionary = turns.back()
			var gap: float = float(corner["s"]) - float(previous["s"])
			if gap < CORNER_MERGE_M:
				previous["angle"] = float(previous["angle"]) + float(corner["angle"])
				continue
		turns.append(corner)


# --- drawing -------------------------------------------------------------------------------------

func _draw() -> void:
	if _raw.size() < 4:
		draw_string(MONO, Vector2(18.0, 34.0), "LAYOUT RESERVED // COMING SOON", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, T.ACCENT_ANIME_CRIMSON)
		return
	var map_rect := Rect2(0.0, 0.0, size.x, maxf(60.0, size.y - ELEVATION_STRIP_H))
	var fitted := _fit(map_rect, MARGIN_PX)
	_draw_grid(map_rect)
	_draw_track(fitted)
	_draw_start_line(fitted)
	_draw_turn_numbers(fitted)
	_draw_elevation(Rect2(MARGIN_PX, size.y - ELEVATION_STRIP_H + 8.0, size.x - MARGIN_PX * 2.0, ELEVATION_STRIP_H - 18.0))


func _fit(rect: Rect2, margin: float) -> PackedVector2Array:
	var bounds := Rect2(_raw[0], Vector2.ZERO)
	for point: Vector2 in _raw:
		bounds = bounds.expand(point)
	var inner := Vector2(rect.size.x - margin * 2.0, rect.size.y - margin * 2.0)
	var scale: float = minf(
		inner.x / maxf(bounds.size.x, 0.001),
		inner.y / maxf(bounds.size.y, 0.001)
	)
	var offset: Vector2 = rect.get_center() - bounds.get_center() * scale
	var fitted := PackedVector2Array()
	fitted.resize(_raw.size())
	for i: int in range(_raw.size()):
		fitted[i] = _raw[i] * scale + offset
	return fitted


func _draw_grid(rect: Rect2) -> void:
	var line := Color(1.0, 1.0, 1.0, 0.05)
	var step: float = 74.0
	var x: float = MARGIN_PX
	while x < rect.size.x - MARGIN_PX:
		draw_line(Vector2(x, 8.0), Vector2(x, rect.size.y - 8.0), line, 1.0)
		x += step
	var y: float = 12.0
	while y < rect.size.y - 8.0:
		draw_line(Vector2(MARGIN_PX, y), Vector2(rect.size.x - MARGIN_PX, y), line, 1.0)
		y += step


func _draw_track(fitted: PackedVector2Array) -> void:
	var closed := _closed(fitted)
	draw_polyline(closed, T.INK_BORDER_BLACK, CASING_PX, true)
	draw_polyline(closed, ASPHALT_COLOR, ASPHALT_PX, true)
	draw_polyline(closed, Color(1.0, 1.0, 1.0, 0.22), 1.5, true)
	var per_sector: float = length_m / float(SECTOR_COLORS.size())
	var last: int = SECTOR_COLORS.size() - 1
	for sector: int in range(SECTOR_COLORS.size()):
		var run_start: float = per_sector * float(sector)
		var run_end: float = per_sector * float(sector + 1)
		var run := PackedVector2Array()
		for i: int in range(fitted.size()):
			var s: float = length_m * float(i) / float(fitted.size())
			if sector == last:
				if s >= run_start:
					run.append(fitted[i])
			elif s >= run_start and s <= run_end:
				run.append(fitted[i])
		# The last sector closes over the start/finish seam.
		if sector == last and not run.is_empty():
			run.append(fitted[0])
		if run.size() >= 2:
			draw_polyline(run, SECTOR_COLORS[sector], BAND_PX, true)
		_draw_sector_tag(fitted, sector, per_sector)
	_draw_drs(fitted)


## The DRS zones as a lime dotted stripe laid over the sector band.
func _draw_drs(fitted: PackedVector2Array) -> void:
	for zone: Dictionary in drs_zones:
		var from_s: float = float(zone["start_s"])
		var to_s: float = float(zone["end_s"])
		if to_s < from_s:
			to_s += length_m
		var s: float = from_s
		while s <= to_s:
			var index: int = int(fposmod(s, length_m) / maxf(length_m, 1.0) * float(fitted.size())) % fitted.size()
			draw_circle(fitted[index], 3.4, T.ACCENT_ACID_LIME)
			s += 14.0


func _draw_sector_tag(fitted: PackedVector2Array, sector: int, per_sector: float) -> void:
	var s: float = per_sector * (float(sector) + 0.5)
	var index: int = clampi(int(s / maxf(length_m, 1.0) * float(fitted.size())), 0, fitted.size() - 1)
	var at: Vector2 = fitted[index] + Vector2(0.0, -26.0)
	draw_string(MONO, at - Vector2(10.0, 0.0), "S%d" % (sector + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, SECTOR_COLORS[sector])


func _draw_start_line(fitted: PackedVector2Array) -> void:
	var at: Vector2 = fitted[0]
	var dir: Vector2 = (fitted[1] - fitted[fitted.size() - 1]).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var half: float = CASING_PX * 0.5
	# A chequered gate across the road: two rows of four squares, ink and white.
	for row: int in range(2):
		for col: int in range(4):
			var corner: Vector2 = at + dir * (float(row) - 1.0) * 5.0 + normal * (float(col) - 2.0) * (half / 2.0)
			var quad := PackedVector2Array([corner, corner + dir * 5.0, corner + dir * 5.0 + normal * (half / 2.0), corner + normal * (half / 2.0)])
			draw_colored_polygon(quad, T.TEXT_PRIMARY if (row + col) % 2 == 0 else T.INK_BORDER_BLACK)
	draw_polyline(PackedVector2Array([at - normal * half - dir * 5.0, at + normal * half - dir * 5.0, at + normal * half + dir * 5.0, at - normal * half + dir * 5.0, at - normal * half - dir * 5.0]), T.INK_BORDER_BLACK, 2.0)


## Numbered corners as skewed lime tags set just outside the bend, so the road stays readable.
func _draw_turn_numbers(fitted: PackedVector2Array) -> void:
	var centre := Vector2.ZERO
	for point: Vector2 in fitted:
		centre += point
	centre /= float(fitted.size())
	for index: int in range(turns.size()):
		var corner: Dictionary = turns[index]
		var s: float = float(corner["s"])
		var at_index: int = clampi(int(s / maxf(length_m, 1.0) * float(fitted.size())), 0, fitted.size() - 1)
		var apex: Vector2 = fitted[at_index]
		var away: Vector2 = (apex - centre).normalized()
		var at: Vector2 = apex + away * BADGE_OFFSET_PX
		var half := BADGE_SIZE * 0.5
		var lean: float = half.y * 0.21 * 2.0
		var tag := PackedVector2Array([
			at + Vector2(-half.x + lean, -half.y), at + Vector2(half.x + lean, -half.y),
			at + Vector2(half.x - lean, half.y), at + Vector2(-half.x - lean, half.y),
		])
		draw_colored_polygon(tag, T.ACCENT_ACID_LIME)
		draw_polyline(PackedVector2Array([tag[0], tag[1], tag[2], tag[3], tag[0]]), T.INK_BORDER_BLACK, 3.0)
		var label := "T%d" % (index + 1)
		var width: float = DISPLAY.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, TURN_LABEL_SIZE).x
		draw_string(DISPLAY, at + Vector2(-width * 0.5, TURN_LABEL_SIZE * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, TURN_LABEL_SIZE, T.INK_BORDER_BLACK)


func _draw_elevation(strip: Rect2) -> void:
	draw_string(
		MONO, strip.position + Vector2(0.0, 12.0),
		"ELEVATION // Δ %.1f m" % (max_elevation - min_elevation),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, T.TEXT_SECONDARY
	)
	var plot := Rect2(strip.position + Vector2(0.0, 20.0), Vector2(strip.size.x, strip.size.y - 22.0))
	draw_rect(plot, Color(1.0, 1.0, 1.0, 0.04), true)
	var range_m: float = maxf(max_elevation - min_elevation, 0.5)
	var flat: bool = max_elevation - min_elevation < 0.5
	var profile := PackedVector2Array()
	profile.resize(_elevation.size())
	for i: int in range(_elevation.size()):
		var x: float = plot.position.x + plot.size.x * float(i) / float(_elevation.size())
		var y: float = plot.position.y + plot.size.y * 0.5
		if not flat:
			y = plot.position.y + plot.size.y - plot.size.y * ((_elevation[i] - min_elevation) / range_m)
		profile[i] = Vector2(x, y)
	draw_polyline(profile, T.ACCENT_ELECTRIC_CYAN, 2.0, true)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if points.size() > 0:
		out.append(points[0])
	return out
