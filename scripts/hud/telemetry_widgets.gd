class_name TelemetryWidgets
extends RefCounted

## Small hard-edged instruments for the telemetry drawer. Every one is a Control that draws
## itself from a few pushed values: a shift-light strip, a scrolling pedal trace, a square
## G-force box with a trail, a top-down tyre heat matrix, an ERS charge meter with flow
## chevrons, a stress / confidence diverging bar and a heartbeat trace. No round gauges.

const INK := Color("#050505")
const WELL := Color(1.0, 1.0, 1.0, 0.07)
const LIME := Color("#CCFF00")
const CYAN := Color("#00F0FF")
const YELLOW := Color("#FFE600")
const CRIMSON := Color("#FF1E56")
const PURPLE := Color("#D946EF")


## Heat colour of a tyre: cold cyan, ideal lime, hot yellow, critical crimson.
static func tyre_tint(temp: float) -> Color:
	if temp < 70.0:
		return CYAN
	if temp <= 105.0:
		return LIME
	if temp <= 125.0:
		return YELLOW
	return CRIMSON


## Row of LED blocks like a shift-light bar: lime, then yellow, then crimson, purple at the limiter.
class RpmStrip extends Control:
	var value: float = 0.0
	var count: int = 16

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(p_value: float) -> void:
		value = clampf(p_value, 0.0, 1.0)
		queue_redraw()

	func lit_blocks() -> int:
		return clampi(ceili(value * float(count) - 0.0001), 0, count)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), INK)
		var block_w: float = (size.x - 4.0 - 2.0 * float(count - 1)) / float(count)
		var limiter: bool = value > 0.96 and int(Time.get_ticks_msec() / 90) % 2 == 0
		for index: int in range(count):
			var share: float = float(index) / float(count)
			var tint: Color = LIME if share < 0.6 else (YELLOW if share < 0.82 else CRIMSON)
			if limiter:
				tint = PURPLE
			var rect := Rect2(2.0 + float(index) * (block_w + 2.0), 2.0, block_w, size.y - 4.0)
			draw_rect(rect, tint if index < lit_blocks() else WELL)


## Last few seconds of throttle (lime) and brake (crimson) as hard pillars.
class PedalTrace extends Control:
	const SAMPLES: int = 96

	var throttle: PackedFloat32Array = PackedFloat32Array()
	var brake: PackedFloat32Array = PackedFloat32Array()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		throttle.resize(SAMPLES)
		brake.resize(SAMPLES)

	func push(p_throttle: float, p_brake: float) -> void:
		throttle.remove_at(0)
		throttle.append(clampf(p_throttle, 0.0, 1.0))
		brake.remove_at(0)
		brake.append(clampf(p_brake, 0.0, 1.0))
		queue_redraw()

	func clear() -> void:
		throttle.fill(0.0)
		brake.fill(0.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), INK)
		var inner := Rect2(2.0, 2.0, size.x - 4.0, size.y - 4.0)
		for quarter: int in range(1, 4):
			var y: float = inner.position.y + inner.size.y * float(quarter) / 4.0
			draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), WELL, 1.0)
		var column_w: float = inner.size.x / float(SAMPLES)
		for index: int in range(SAMPLES):
			var x: float = inner.position.x + float(index) * column_w
			var t_h: float = inner.size.y * throttle[index]
			var b_h: float = inner.size.y * brake[index]
			draw_rect(Rect2(x, inner.end.y - t_h, column_w + 0.5, t_h), Color(LIME, 0.85))
			draw_rect(Rect2(x, inner.end.y - b_h, column_w + 0.5, b_h), Color(CRIMSON, 0.95))


## Square G-force box: rings at 1, 2 and 3 G, a crosshair, a fading trail and the live dot.
## Right turn moves the dot right, braking moves it up.
class GBall extends Control:
	const TRAIL: int = 40
	const RANGE_G: float = 4.0

	var trail: Array[Vector2] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func push(lateral_g: float, longitudinal_g: float) -> void:
		trail.append(Vector2(lateral_g, longitudinal_g))
		if trail.size() > TRAIL:
			trail.pop_front()
		queue_redraw()

	func clear() -> void:
		trail.clear()
		queue_redraw()

	func _to_screen(g: Vector2) -> Vector2:
		var half: Vector2 = size * 0.5
		var clamped := Vector2(clampf(g.x, -RANGE_G, RANGE_G), clampf(g.y, -RANGE_G, RANGE_G))
		return half + Vector2(clamped.x, clamped.y) * (half.x - 3.0) / RANGE_G

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), INK)
		var half: Vector2 = size * 0.5
		for ring: int in range(1, 4):
			var radius: float = (half.x - 3.0) * float(ring) / RANGE_G
			draw_rect(Rect2(half - Vector2(radius, radius), Vector2(radius, radius) * 2.0), WELL if ring < 3 else Color(CRIMSON, 0.3), false, 1.0)
		draw_line(Vector2(half.x, 3.0), Vector2(half.x, size.y - 3.0), WELL, 1.0)
		draw_line(Vector2(3.0, half.y), Vector2(size.x - 3.0, half.y), WELL, 1.0)
		for index: int in range(trail.size()):
			var fade: float = float(index + 1) / float(TRAIL)
			var at: Vector2 = _to_screen(trail[index])
			draw_rect(Rect2(at - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), Color(CYAN, 0.12 + 0.5 * fade))
		if not trail.is_empty():
			var now: Vector2 = trail[trail.size() - 1]
			var at: Vector2 = _to_screen(now)
			draw_rect(Rect2(at - Vector2(4.5, 4.5), Vector2(9.0, 9.0)), INK)
			draw_rect(Rect2(at - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), CRIMSON if now.length() > 2.5 else LIME)


## Top-down tyre heat matrix: each tyre is a well filled from the bottom by its temperature in
## the heat colour, with a tread column beside it, a brake disc strip by the body, a
## blister warning and a red cross on a blown tyre. Index order FL, FR, RL, RR.
class TyreMatrix extends Control:
	const CELL := Vector2(34.0, 46.0)
	const TEMP_MIN: float = 40.0
	const TEMP_MAX: float = 140.0

	var temps: PackedFloat64Array = PackedFloat64Array([90.0, 90.0, 90.0, 90.0])
	var brakes: PackedFloat64Array = PackedFloat64Array([350.0, 350.0, 350.0, 350.0])
	var blisters: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	var tread: float = 1.0 # 0..1 life left
	var blown: int = -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(p_temps: PackedFloat64Array, p_brakes: PackedFloat64Array, p_blisters: PackedFloat64Array, p_tread: float, p_blown: int) -> void:
		temps = p_temps
		brakes = p_brakes
		blisters = p_blisters
		tread = clampf(p_tread, 0.0, 1.0)
		blown = p_blown
		queue_redraw()

	## Heat colour a tyre is drawn in; crimson when blown.
	func heat_of(index: int) -> Color:
		return CRIMSON if index == blown else TelemetryWidgets.tyre_tint(temps[index])

	func _cell_rect(index: int) -> Rect2:
		var x: float = 4.0 if index % 2 == 0 else size.x - 4.0 - CELL.x
		var y: float = 6.0 if index < 2 else size.y - 6.0 - CELL.y
		return Rect2(x, y, CELL.x, CELL.y)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), INK)
		# Chassis between the tyres: nose cone, cockpit, tail.
		var mid: float = size.x * 0.5
		draw_rect(Rect2(mid - 3.0, 10.0, 6.0, size.y - 20.0), WELL)
		draw_rect(Rect2(mid - 9.0, 8.0, 18.0, 5.0), WELL)
		draw_rect(Rect2(mid - 11.0, size.y - 14.0, 22.0, 6.0), WELL)
		for index: int in range(4):
			var cell: Rect2 = _cell_rect(index)
			var inside_left: bool = index % 2 == 0
			draw_rect(cell, WELL)
			var tread_w: float = 6.0
			var well := Rect2(cell.position.x + (tread_w + 2.0 if inside_left else 0.0), cell.position.y, cell.size.x - tread_w - 2.0, cell.size.y)
			var heat: float = clampf((temps[index] - TEMP_MIN) / (TEMP_MAX - TEMP_MIN), 0.06, 1.0)
			var heat_h: float = well.size.y * (1.0 if index == blown else heat)
			draw_rect(Rect2(well.position.x, well.end.y - heat_h, well.size.x, heat_h), heat_of(index))
			# Tread column on the outside edge: blocks of remaining life.
			var tread_rect := Rect2(cell.position.x if inside_left else cell.end.x - tread_w, cell.position.y, tread_w, cell.size.y)
			var blocks: int = 6
			var lit: int = ceili(tread * float(blocks) - 0.0001)
			for block: int in range(blocks):
				var block_h: float = (tread_rect.size.y - float(blocks - 1) * 2.0) / float(blocks)
				var y: float = tread_rect.end.y - float(block + 1) * block_h - float(block) * 2.0
				var worn_tint: Color = LIME if tread > 0.3 else CRIMSON
				draw_rect(Rect2(tread_rect.position.x, y, tread_rect.size.x, block_h), worn_tint if block < lit else WELL)
			# Brake disc strip towards the body: dark to orange to white-hot.
			var heat_brake: float = clampf((brakes[index] - 250.0) / 550.0, 0.0, 1.0)
			var disc_x: float = cell.end.x + 2.0 if inside_left else cell.position.x - 6.0
			var disc_color: Color = Color(0.25, 0.1, 0.05).lerp(Color(1.0, 0.45, 0.1), minf(heat_brake * 1.6, 1.0)).lerp(Color.WHITE, maxf(0.0, heat_brake - 0.6) * 1.8)
			draw_rect(Rect2(disc_x, cell.position.y + 6.0, 4.0, cell.size.y - 12.0), disc_color)
			if blisters[index] > 25.0:
				for dash: int in range(3):
					var dy: float = cell.position.y + 4.0 + float(dash) * 6.0
					draw_line(Vector2(well.position.x + 3.0, dy + 5.0), Vector2(well.end.x - 3.0, dy), INK, 2.0)
			if index == blown:
				draw_line(cell.position, cell.end, INK, 3.0)
				draw_line(Vector2(cell.end.x, cell.position.y), Vector2(cell.position.x, cell.end.y), INK, 3.0)
			draw_rect(cell, INK, false, 2.0)


## Battery blocks with flow chevrons: harvest points back, deploy forward, overtake doubles up.
class ErsMeter extends Control:
	var charge: float = 1.0
	var mode: int = GtTypes.ErsMode.NEUTRAL

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(p_charge: float, p_mode: int) -> void:
		charge = clampf(p_charge, 0.0, 1.0)
		mode = p_mode
		queue_redraw()

	func chevron_count() -> int:
		match mode:
			GtTypes.ErsMode.HARVEST, GtTypes.ErsMode.DEPLOY:
				return 1
			GtTypes.ErsMode.OVERTAKE:
				return 3
		return 0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), INK)
		var tint: Color = [CYAN, WELL, PURPLE, CRIMSON][mode]
		var direction: float = -1.0 if mode == GtTypes.ErsMode.HARVEST else 1.0
		var chevrons: int = chevron_count()
		for index: int in range(3):
			var x: float = 6.0 + float(index) * 9.0
			var lit: bool = index < chevrons
			var tip: float = 5.0 * direction
			var base: float = x + (5.0 if direction < 0.0 else 0.0)
			var points := PackedVector2Array([
				Vector2(base, 3.0), Vector2(base + tip, size.y * 0.5), Vector2(base, size.y - 3.0),
				Vector2(base + tip * 0.4, size.y - 3.0), Vector2(base + tip * 1.4, size.y * 0.5), Vector2(base + tip * 0.4, 3.0),
			])
			draw_colored_polygon(points, tint if lit else Color(1.0, 1.0, 1.0, 0.08))
		var blocks: int = 16
		var origin_x: float = 38.0
		var block_w: float = (size.x - origin_x - 3.0 - 2.0 * float(blocks - 1)) / float(blocks)
		var lit_blocks: int = ceili(charge * float(blocks) - 0.0001)
		for index: int in range(blocks):
			var rect := Rect2(origin_x + float(index) * (block_w + 2.0), 3.0, block_w, size.y - 6.0)
			var low: bool = charge <= 0.2 and int(Time.get_ticks_msec() / 160) % 2 == 0
			draw_rect(rect, (Color(CRIMSON, 0.4) if low else (PURPLE if charge > 0.2 else CRIMSON)) if index < lit_blocks else WELL)


## Stress grows left from the centre line (crimson), confidence grows right (lime).
class MoodBar extends Control:
	var stress: float = 0.0
	var confidence: float = 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(p_stress: float, p_confidence: float) -> void:
		stress = clampf(p_stress, 0.0, 1.0)
		confidence = clampf(p_confidence, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), INK)
		var half: float = size.x * 0.5
		var blocks: int = 10
		var block_w: float = (half - 5.0 - 2.0 * float(blocks - 1)) / float(blocks)
		for index: int in range(blocks):
			var step: float = float(index + 1) / float(blocks)
			var offset: float = 3.0 + float(index) * (block_w + 2.0)
			draw_rect(Rect2(half - 3.0 - offset - block_w + 3.0, 2.0, block_w, size.y - 4.0), CRIMSON if stress >= step - 0.05 else WELL)
			draw_rect(Rect2(half + offset, 2.0, block_w, size.y - 4.0), LIME if confidence >= step - 0.05 else WELL)
		draw_rect(Rect2(half - 1.0, 0.0, 2.0, size.y), Color.WHITE)


## Heartbeat trace: an ECG line scrolling left, one beat per heart period, redder when stressed.
## Samples are laid down at a fixed spacing as time passes, so a changing heart rate never
## reshuffles the beats already on the line.
class PulseTrace extends Control:
	const SCROLL_PX_S: float = 70.0
	const STEP_PX: float = 2.0

	var heart_rate: float = 120.0
	var stress: float = 0.0
	var samples: PackedFloat32Array = PackedFloat32Array()
	var _phase: float = 0.0
	var _carry: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		samples.resize(150)

	func set_state(p_heart_rate: float, p_stress: float) -> void:
		heart_rate = maxf(p_heart_rate, 40.0)
		stress = clampf(p_stress, 0.0, 1.0)

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_carry += SCROLL_PX_S * delta
		while _carry >= STEP_PX:
			_carry -= STEP_PX
			_phase = fposmod(_phase + heart_rate / 60.0 * STEP_PX / SCROLL_PX_S, 1.0)
			samples.remove_at(0)
			samples.append(beat(_phase))
		queue_redraw()

	## One beat from phase 0..1: P bump, QRS spike, T bump; value -1..1.
	static func beat(phase: float) -> float:
		if phase < 0.10:
			return 0.0
		if phase < 0.20:
			return sin((phase - 0.10) / 0.10 * PI) * 0.18
		if phase < 0.30:
			return 0.0
		if phase < 0.33:
			return -0.25 * sin((phase - 0.30) / 0.03 * PI)
		if phase < 0.38:
			return sin((phase - 0.33) / 0.05 * PI) * 1.0
		if phase < 0.42:
			return -0.35 * sin((phase - 0.38) / 0.04 * PI)
		if phase < 0.58:
			return 0.0
		if phase < 0.74:
			return sin((phase - 0.58) / 0.16 * PI) * 0.3
		return 0.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), INK)
		var base: float = size.y * 0.62
		var amp: float = size.y * 0.5
		var points := PackedVector2Array()
		for index: int in range(samples.size()):
			var x: float = 2.0 + float(index) * STEP_PX - _carry
			if x >= 2.0 and x <= size.x - 2.0:
				points.append(Vector2(x, base - samples[index] * amp))
		draw_line(Vector2(2.0, base), Vector2(size.x - 2.0, base), WELL, 1.0)
		if points.size() > 1:
			draw_polyline(points, LIME.lerp(CRIMSON, stress), 2.0)
