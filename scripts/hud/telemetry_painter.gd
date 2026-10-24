class_name TelemetryPainter
extends RefCounted

## Paints the concept F telemetry drawer onto a CanvasItem (call from its `_draw`): slanted manga panels
## on a dark gutter tinted by the team accent, a top-down X-ray car with live tyres, brake discs, ERS
## flow, G arrow and tank, the pedal trace, the driver panel, the story caption and the onomatopoeia.
## Everything animates from `state.clock` (never wall time); `reduce_motion` drops shake, flicker and
## shimmer. The accent only skins the chrome: heat, pedals, ERS, gear and DRS colours are fixed.

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const MARKER = preload("res://assets/fonts/PermanentMarker.ttf")

const INK := Color("#050505")
const GUTTER := Color("#151b29")
const PANEL := Color("#0b0f18")
const HERO := Color("#080b12")
const WELL := Color(1.0, 1.0, 1.0, 0.07)
const LIME := Color("#CCFF00")
const CYAN := Color("#00F0FF")
const YELLOW := Color("#FFE600")
const CRIMSON := Color("#FF1E56")
const PURPLE := Color("#D946EF")
const MUTED := Color("#7D8AA0")
const SIZE := Vector2(312.0, 496.0)
const TOP_SPEED_KMH: float = 330.0
const KICK_S: float = 0.3
const CAR_TOP: float = 139.0
const POP_SPOTS: Dictionary = {
	"brake": [Vector2(66.0, 236.0), -0.15, CRIMSON], "shift": [Vector2(152.0, 112.0), 0.12, YELLOW],
	"drs": [Vector2(50.0, 60.0), -0.1, CYAN], "tyre": [Vector2(104.0, 286.0), 0.08, CRIMSON],
	"ers": [Vector2(232.0, 206.0), -0.08, PURPLE],
}
## Right half of the car outline from the nose down, mirrored for the left half.
const CAR_HALF: Array[Vector2] = [
	Vector2(12.0, 0.0), Vector2(24.0, 14.0), Vector2(33.0, 40.0), Vector2(36.0, 70.0), Vector2(31.0, 100.0),
	Vector2(33.0, 135.0), Vector2(40.0, 168.0), Vector2(40.0, 200.0), Vector2(30.0, 224.0), Vector2(0.0, 226.0),
]
const WHEEL_CODE: Array[String] = ["FL", "FR", "RL", "RR"]


static func paint(canvas: CanvasItem, state: TelemetryState, accent: Color, on_accent: Color, reduce_motion: bool) -> void:
	var clock: float = state.clock
	var gutter: Color = GUTTER.lerp(accent, 0.07)
	canvas.draw_rect(Rect2(Vector2.ZERO, SIZE), INK)
	canvas.draw_rect(Rect2(3.0, 3.0, SIZE.x - 6.0, SIZE.y - 6.0), gutter)
	canvas.draw_rect(Rect2(4.5, 4.5, SIZE.x - 9.0, SIZE.y - 9.0), Color(accent, 0.55), false, 1.0)
	_slanted(canvas, Rect2(8.0, 6.0, 130.0, 26.0), 8.0, accent)
	canvas.draw_string(UI.DISPLAY, Vector2(22.0, 27.0), "TELEMETRY", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, on_accent)
	canvas.draw_string(UI.MONO, Vector2(102.0, 24.0), state.header_text, HORIZONTAL_ALIGNMENT_RIGHT, 200.0, 11, accent)
	_speed_panel(canvas, state, accent, clock, reduce_motion)
	_gear_panel(canvas, state, clock)
	_hero_panel(canvas, state, accent, clock, reduce_motion)
	_pedal_panel(canvas, state, accent)
	_driver_panel(canvas, state, accent, clock)
	_caption_panel(canvas, state, accent, clock)
	_pops(canvas, state, clock, reduce_motion)


# --- panels --------------------------------------------------------------------------------------------------

static func _panel(canvas: CanvasItem, points: PackedVector2Array, fill: Color, edge: Color) -> void:
	canvas.draw_colored_polygon(points, fill)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, INK, 3.0)
	canvas.draw_polyline(outline, Color(edge, 0.6), 1.0)


static func _rect_poly(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


static func _slanted(canvas: CanvasItem, rect: Rect2, skew: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(rect.position.x + skew, rect.position.y), Vector2(rect.end.x + skew, rect.position.y),
		Vector2(rect.end.x, rect.end.y), Vector2(rect.position.x, rect.end.y)]), color)


## A line clipped to the panel polygon (Geometry2D), so shimmer never leaves its panel.
static func _clipped_line(canvas: CanvasItem, from: Vector2, to: Vector2, polygon: PackedVector2Array, color: Color, width: float) -> void:
	for piece: PackedVector2Array in Geometry2D.clip_polyline_with_polygon(PackedVector2Array([from, to]), polygon):
		canvas.draw_polyline(piece, color, width)


static func _text_centered(canvas: CanvasItem, font: Font, text: String, center: Vector2, font_size: int, color: Color, outline: int = 0) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var baseline: float = center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var at := Vector2(center.x - width * 0.5, baseline)
	if outline > 0:
		canvas.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, outline, INK)
	canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


static func _speed_panel(canvas: CanvasItem, state: TelemetryState, accent: Color, clock: float, reduce_motion: bool) -> void:
	var polygon := PackedVector2Array([Vector2(8.0, 38.0), Vector2(192.0, 38.0), Vector2(180.0, 118.0), Vector2(8.0, 118.0)])
	_panel(canvas, polygon, PANEL, accent)
	var speed: float = clampf(state.speed_kmh / TOP_SPEED_KMH, 0.0, 1.0)
	var center := Vector2(94.0, 78.0)
	for index: int in range(30):
		var angle: float = float(index) / 30.0 * TAU
		var shimmer: float = 0.0 if reduce_motion else 5.0 * sin(clock * 22.0 + float(index) * 5.0)
		var inner: float = 30.0 + (1.0 - speed) * 40.0 + shimmer
		var dir := Vector2(cos(angle), sin(angle) * 0.6)
		_clipped_line(canvas, center + dir * inner, center + dir * 160.0, polygon, Color(accent, 0.1 + 0.25 * speed), 1.2)
	for gx: int in range(9):
		for gy: int in range(5):
			var reach: float = Vector2(float(gx) * 8.0, float(4 - gy) * 8.0).length() / 60.0
			var radius: float = maxf(0.0, (1.0 - reach) * 3.0 * speed)
			if radius > 0.2:
				canvas.draw_circle(Vector2(14.0 + float(gx) * 8.0, 112.0 - float(gy) * 8.0), radius, Color(accent, 0.3))
	_text_centered(canvas, UI.DISPLAY, str(roundi(state.speed_kmh)), Vector2(96.0, 72.0), 52, Color.WHITE, 6)
	_text_centered(canvas, MARKER, "KM/H", Vector2(96.0, 105.0), 16, accent)
	_drs_chip(canvas, state.drs, clock)


static func _drs_chip(canvas: CanvasItem, drs: int, clock: float) -> void:
	var chip := Rect2(16.0, 44.0, 48.0, 16.0)
	if drs == 0:
		canvas.draw_rect(chip, WELL)
		_text_centered(canvas, UI.HEADER, "DRS", chip.get_center(), 12, MUTED)
	elif drs == 1:
		var pulse: float = 0.5 + 0.5 * sin(clock * 8.0)
		canvas.draw_rect(chip, Color(YELLOW, 0.12 + 0.18 * pulse))
		canvas.draw_rect(chip, YELLOW, false, 1.5)
		_text_centered(canvas, UI.HEADER, "DRS", chip.get_center(), 12, YELLOW)
	else:
		canvas.draw_rect(chip, CYAN)
		var shift: float = fposmod(clock * 60.0, 14.0)
		for index: int in range(4):
			var x: float = chip.position.x + float(index) * 14.0 + shift - 14.0
			if x >= chip.position.x and x + 8.0 <= chip.end.x:
				canvas.draw_string(UI.HEADER, Vector2(x, chip.end.y - 3.0), "»", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(INK, 0.22))
		_text_centered(canvas, UI.HEADER, "DRS", chip.get_center(), 12, INK)


static func _kick(state: TelemetryState) -> float:
	return clampf(1.0 - (state.clock - state.shift_time) / KICK_S, 0.0, 1.0)


static func _gear_panel(canvas: CanvasItem, state: TelemetryState, clock: float) -> void:
	var flash: bool = state.limiter and int(clock * 11.0) % 2 == 0
	var polygon := PackedVector2Array([Vector2(214.0, 38.0), Vector2(304.0, 38.0), Vector2(304.0, 118.0), Vector2(202.0, 118.0)])
	_panel(canvas, polygon, Color("#2A0F33") if flash else PANEL, PURPLE if flash else YELLOW)
	var kick: float = _kick(state)
	var scale: float = 1.0 + 0.35 * kick
	canvas.draw_set_transform(Vector2(256.0, 76.0), 0.0, Vector2(scale, scale))
	if kick > 0.05:
		_text_centered(canvas, UI.DISPLAY, str(state.gear), Vector2(-3.0 * kick, 0.0), 72, CYAN)
		_text_centered(canvas, UI.DISPLAY, str(state.gear), Vector2(3.0 * kick, 0.0), 72, CRIMSON)
	_text_centered(canvas, UI.DISPLAY, str(state.gear), Vector2.ZERO, 72, Color.WHITE if kick > 0.2 else YELLOW)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	canvas.draw_string(UI.HEADER, Vector2(214.0, 52.0), "GEAR", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, YELLOW)
	var lit: int = ceili(state.rpm * 12.0 - 0.0001)
	for index: int in range(12):
		var share: float = float(index) / 12.0
		var height: float = 4.0 + float(index) * 1.1
		var tint: Color = PURPLE if flash else (LIME if share < 0.6 else (YELLOW if share < 0.82 else CRIMSON))
		canvas.draw_rect(Rect2(220.0 + float(index) * 6.17, 114.0 - height, 5.5, height), tint if index < lit else WELL)


# --- hero car --------------------------------------------------------------------------------------------------

static func _hero_panel(canvas: CanvasItem, state: TelemetryState, accent: Color, clock: float, reduce_motion: bool) -> void:
	var rect := Rect2(8.0, 122.0, 296.0, 256.0)
	var polygon: PackedVector2Array = _rect_poly(rect)
	_panel(canvas, polygon, HERO, accent)
	var speed: float = clampf(state.speed_kmh / TOP_SPEED_KMH, 0.0, 1.0)
	var braking: bool = state.brake[state.brake.size() - 1] > 0.5
	var jitter: float = sin(clock * 80.0) * 1.2 if braking and not reduce_motion else 0.0
	canvas.draw_set_transform(Vector2(jitter, 0.0), 0.0, Vector2.ONE)
	var center := Vector2(156.0, 250.0)
	for index: int in range(36):
		var angle: float = float(index) / 36.0 * TAU
		var shimmer: float = 0.0 if reduce_motion else 6.0 * sin(clock * 18.0 + float(index) * 3.0)
		var inner: float = 70.0 + (1.0 - speed) * 70.0 + shimmer
		_clipped_line(canvas, center + Vector2(cos(angle) * inner * 1.5, sin(angle) * inner), center + Vector2(cos(angle) * 300.0, sin(angle) * 200.0),
			polygon, Color(accent, 0.04 + 0.1 * speed), 1.0)
	if state.stress > 0.05:
		for gx: int in range(9):
			var radius: float = state.stress * 3.0 * (1.0 - float(gx) / 9.0)
			if radius < 0.4:
				continue
			for gy: int in range(32):
				canvas.draw_circle(Vector2(12.0 + float(gx) * 8.0, 374.0 - float(gy) * 8.0), radius, Color(CRIMSON, 0.22))
				canvas.draw_circle(Vector2(300.0 - float(gx) * 8.0, 374.0 - float(gy) * 8.0), radius, Color(CRIMSON, 0.22))
	canvas.draw_set_transform(Vector2(156.0 + jitter, CAR_TOP), 0.0, Vector2.ONE)
	_car(canvas, state, accent, clock, reduce_motion)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _car_outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	for point: Vector2 in CAR_HALF:
		points.append(point)
	for index: int in range(CAR_HALF.size() - 2, -1, -1):
		points.append(Vector2(-CAR_HALF[index].x, CAR_HALF[index].y))
	return points


static func _disc_color(temp: float) -> Color:
	var heat: float = clampf((temp - 250.0) / 550.0, 0.0, 1.0)
	if heat > 0.6:
		return Color("#FF731A").lerp(Color.WHITE, (heat - 0.6) * 1.8)
	return Color("#401A0D").lerp(Color("#FF731A"), minf(heat * 1.6, 1.0))


## Local coordinates: x = 0 is the car centre line, y = 0 the nose.
static func _car(canvas: CanvasItem, state: TelemetryState, accent: Color, clock: float, reduce_motion: bool) -> void:
	var outline: PackedVector2Array = _car_outline()
	canvas.draw_colored_polygon(outline, Color(1.0, 1.0, 1.0, 0.05))
	var closed: PackedVector2Array = outline.duplicate()
	closed.append(outline[0])
	canvas.draw_polyline(closed, Color(accent, 0.55), 1.5)
	canvas.draw_rect(Rect2(-15.0, 88.0, 30.0, 50.0), Color(accent, 0.08))
	canvas.draw_rect(Rect2(-15.0, 88.0, 30.0, 50.0), Color(accent, 0.4), false, 1.0)
	canvas.draw_rect(Rect2(-40.0, 214.0, 80.0, 6.0), Color(1.0, 1.0, 1.0, 0.14))
	canvas.draw_rect(Rect2(-22.0, 4.0, 44.0, 3.0), Color(1.0, 1.0, 1.0, 0.14))
	_ers_spine(canvas, state.ers_mode, clock, reduce_motion)
	_tank(canvas, state.fuel, clock, reduce_motion)
	if state.damage > 0.05:
		var mark: Color = CRIMSON if int(clock * 3.0) % 2 == 0 else Color("#FF7A1A")
		canvas.draw_line(Vector2(24.0, 54.0), Vector2(32.0, 62.0), mark, 2.0)
		canvas.draw_line(Vector2(32.0, 54.0), Vector2(24.0, 62.0), mark, 2.0)
	for index: int in range(4):
		_tyre(canvas, state, index, clock, reduce_motion)
	_g_arrow(canvas, state)


## Dashes flow up the car for DEPLOY and OVERTAKE (fast), down for HARVEST, stand dim for NEUTRAL.
static func _ers_spine(canvas: CanvasItem, ers_mode: int, clock: float, reduce_motion: bool) -> void:
	var idle: bool = ers_mode == GtTypes.ErsMode.NEUTRAL
	var tint: Color = Color(1.0, 1.0, 1.0, 0.12) if idle else [CYAN, WELL, PURPLE, CRIMSON][ers_mode]
	var speed: float = 90.0 if ers_mode == GtTypes.ErsMode.OVERTAKE else 42.0
	var direction: float = -1.0 if ers_mode == GtTypes.ErsMode.HARVEST else 1.0
	var offset: float = 0.0 if (idle or reduce_motion) else fposmod(clock * speed * direction, 14.0)
	var start: float = offset - 14.0
	while start < 196.0:
		var from: float = maxf(start, 0.0)
		var to: float = minf(start + 6.0, 196.0)
		if to > from:
			canvas.draw_line(Vector2(0.0, 210.0 - from), Vector2(0.0, 210.0 - to), tint, 3.0)
		start += 14.0


static func _tank(canvas: CanvasItem, fuel: float, clock: float, reduce_motion: bool) -> void:
	var tank := Rect2(-22.0, 150.0, 44.0, 52.0)
	canvas.draw_rect(tank, Color(0.0, 0.0, 0.0, 0.45))
	var level: float = tank.size.y * clampf(fuel, 0.0, 1.0)
	var tint: Color = CRIMSON if fuel < 0.12 else LIME
	for column: int in range(0, 44, 2):
		var wobble: float = 0.0 if reduce_motion else sin(clock * 3.0 + float(column) * 0.4) * 1.2
		canvas.draw_rect(Rect2(tank.position.x + float(column), tank.end.y - level + wobble, 2.0, maxf(level - wobble, 0.0)), tint)
	canvas.draw_rect(tank, INK, false, 2.0)
	_text_centered(canvas, UI.MONO, "FUEL", tank.get_center(), 10, INK)


static func _tyre(canvas: CanvasItem, state: TelemetryState, index: int, clock: float, reduce_motion: bool) -> void:
	var left: bool = index % 2 == 0
	var center_x: float = -56.0 if left else 56.0
	var center_y: float = 34.0 if index < 2 else 176.0
	var rect := Rect2(center_x - 12.0, center_y - 22.0, 24.0, 44.0)
	var temp: float = state.heat[index]
	var tint: Color = state.heat_tint[index]
	var critical: bool = temp > 125.0
	if temp > 105.0:
		var pulse: float = 0.5 + 0.5 * sin(clock * (10.0 if critical else 4.0) + float(index))
		var glow: float = ((0.35 if critical else 0.18) * pulse + 0.06)
		for ring: int in range(3):
			canvas.draw_circle(Vector2(center_x, center_y), 44.0 - float(ring) * 14.0, Color(tint, glow * (0.2 + 0.3 * float(ring))))
	canvas.draw_rect(rect, WELL)
	var height: float = rect.size.y * clampf((temp - 40.0) / 100.0, 0.06, 1.0)
	var blink: bool = critical and not reduce_motion and int(clock * 5.0) % 2 == 0
	for column: int in range(0, 24, 3):
		var wobble: float = 0.0 if (temp <= 105.0 or reduce_motion) else sin(clock * 7.0 + float(column) * 0.5 + float(index)) * 1.5
		canvas.draw_rect(Rect2(rect.position.x + float(column), rect.end.y - height - wobble, 3.0, height + wobble), Color(tint, 0.5 if blink else 1.0))
	if state.blister[index] > 25.0:
		for dash: int in range(3):
			var dy: float = rect.position.y + 4.0 + float(dash) * 12.0
			canvas.draw_line(Vector2(rect.position.x + 3.0, dy + 5.0), Vector2(rect.end.x - 3.0, dy), INK, 2.0)
	canvas.draw_rect(rect, INK, false, 2.0)
	if index == state.blown:
		canvas.draw_line(rect.position, rect.end, INK, 3.0)
		canvas.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), INK, 3.0)
	var disc: Color = _disc_color(state.disc_temp[index])
	var disc_heat: float = clampf((state.disc_temp[index] - 300.0) / 500.0, 0.0, 1.0)
	var disc_x: float = center_x + 14.0 if left else center_x - 18.0
	canvas.draw_rect(Rect2(disc_x - 2.0, rect.position.y + 6.0, 8.0, 32.0), Color(disc, 0.3 * disc_heat))
	canvas.draw_rect(Rect2(disc_x, rect.position.y + 8.0, 4.0, 28.0), disc)
	var label_x: float = center_x - 26.0 if left else center_x + 26.0
	var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT if left else HORIZONTAL_ALIGNMENT_LEFT
	var box_x: float = label_x - 80.0 if left else label_x
	canvas.draw_string(UI.MONO, Vector2(box_x, center_y - 8.0), WHEEL_CODE[index], align, 80.0, 11, MUTED)
	canvas.draw_string(UI.MONO, Vector2(box_x, center_y + 10.0), "%d°" % roundi(temp), align, 80.0, 19, tint)
	var life: int = ceili(state.tread * 6.0 - 0.0001)
	for block: int in range(6):
		canvas.draw_rect(Rect2((label_x - 42.0 if left else label_x) + float(block) * 7.0, center_y + 16.0, 5.0, 4.0), LIME if block < life else WELL)


static func _g_arrow(canvas: CanvasItem, state: TelemetryState) -> void:
	var origin := Vector2(0.0, 112.0)
	var count: int = state.g_trail.size()
	for index: int in range(maxi(0, count - 30), count):
		var fade: float = float(index - (count - 30)) / 30.0
		var g: Vector2 = state.g_trail[index]
		canvas.draw_rect(Rect2(origin.x + clampf(g.x, -4.0, 4.0) * 15.0 - 1.5, origin.y - clampf(g.y, -4.0, 4.0) * 15.0 - 1.5, 3.0, 3.0), Color(CYAN, 0.1 + 0.4 * fade))
	if count == 0:
		return
	var now: Vector2 = state.g_trail[count - 1]
	var tip := origin + Vector2(clampf(now.x, -4.0, 4.0) * 15.0, -clampf(now.y, -4.0, 4.0) * 15.0)
	var tint: Color = CRIMSON if now.length() > 2.5 else LIME
	canvas.draw_line(origin, tip, tint, 3.0)
	canvas.draw_rect(Rect2(tip - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), INK)
	canvas.draw_rect(Rect2(tip - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), tint)
	canvas.draw_string(UI.MONO, origin + Vector2(6.0, -8.0), "G", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, MUTED)


# --- pedals, driver, caption, pops ---------------------------------------------------------------------------------

static func _pedal_panel(canvas: CanvasItem, state: TelemetryState, accent: Color) -> void:
	var rect := Rect2(8.0, 382.0, 296.0, 36.0)
	_panel(canvas, _rect_poly(rect), INK, accent)
	for quarter: int in range(1, 4):
		canvas.draw_rect(Rect2(rect.position.x + 2.0, rect.position.y + rect.size.y * float(quarter) / 4.0, rect.size.x - 4.0, 1.0), WELL)
	var samples: int = state.throttle.size()
	var column: float = (rect.size.x - 4.0) / float(samples)
	for index: int in range(samples):
		var x: float = rect.position.x + 2.0 + float(index) * column
		var throttle_h: float = (rect.size.y - 4.0) * state.throttle[index]
		var brake_h: float = (rect.size.y - 4.0) * state.brake[index]
		canvas.draw_rect(Rect2(x, rect.end.y - 2.0 - throttle_h, column + 0.5, throttle_h), Color(LIME, 0.85))
		canvas.draw_rect(Rect2(x, rect.end.y - 2.0 - brake_h, column + 0.5, brake_h), Color(CRIMSON, 0.95))


static func _mood_bar(canvas: CanvasItem, rect: Rect2, stress: float, confidence: float) -> void:
	canvas.draw_rect(rect, INK)
	var half: float = rect.size.x * 0.5
	var block: float = (half - 5.0 - 2.0 * 9.0) / 10.0
	for index: int in range(10):
		var step: float = float(index + 1) / 10.0
		var offset: float = 3.0 + float(index) * (block + 2.0)
		canvas.draw_rect(Rect2(rect.position.x + half - 3.0 - offset - block + 3.0, rect.position.y + 2.0, block, rect.size.y - 4.0), CRIMSON if stress >= step - 0.05 else WELL)
		canvas.draw_rect(Rect2(rect.position.x + half + offset, rect.position.y + 2.0, block, rect.size.y - 4.0), LIME if confidence >= step - 0.05 else WELL)
	canvas.draw_rect(Rect2(rect.position.x + half - 1.0, rect.position.y, 2.0, rect.size.y), Color.WHITE)


static func _driver_panel(canvas: CanvasItem, state: TelemetryState, accent: Color, clock: float) -> void:
	_panel(canvas, _rect_poly(Rect2(8.0, 422.0, 296.0, 34.0)), PANEL, accent)
	_mood_bar(canvas, Rect2(14.0, 428.0, 150.0, 10.0), state.stress, state.confidence)
	var ecg := Rect2(14.0, 440.0, 150.0, 14.0)
	canvas.draw_rect(ecg, INK)
	var base_y: float = ecg.position.y + ecg.size.y * 0.62
	canvas.draw_rect(Rect2(ecg.position.x + 2.0, base_y, ecg.size.x - 4.0, 1.0), WELL)
	var rate: float = maxf(state.heart_rate, 40.0) / 60.0
	var trace := PackedVector2Array()
	for x: int in range(2, int(ecg.size.x) - 2, 2):
		var seen: float = clock - (ecg.size.x - float(x)) / 70.0
		trace.append(Vector2(ecg.position.x + float(x), base_y - TelemetryDrawer.heartbeat(fposmod(seen * rate, 1.0)) * ecg.size.y * 0.5))
	if trace.size() > 1:
		canvas.draw_polyline(trace, LIME.lerp(CRIMSON, state.stress), 2.0)
	var beat: float = maxf(TelemetryDrawer.heartbeat(fposmod(clock * rate, 1.0)), 0.0)
	var scale: float = 1.0 + 0.35 * beat
	canvas.draw_set_transform(Vector2(180.0, 440.0), 0.0, Vector2(scale, scale))
	var heart: Color = LIME.lerp(CRIMSON, state.stress)
	canvas.draw_circle(Vector2(-3.0, -2.0), 3.4, heart)
	canvas.draw_circle(Vector2(3.0, -2.0), 3.4, heart)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-6.4, -0.5), Vector2(6.4, -0.5), Vector2(0.0, 7.0)]), heart)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	canvas.draw_string(UI.MONO, Vector2(190.0, 451.0), str(roundi(state.heart_rate)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color.WHITE)
	canvas.draw_string(UI.MONO, Vector2(196.0, 433.0), "STRESS %d%%" % roundi(state.stress * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 100.0, 10, CRIMSON)
	canvas.draw_string(UI.MONO, Vector2(196.0, 448.0), "CONF %d%%" % roundi(state.confidence * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 100.0, 10, LIME)


static func _caption_panel(canvas: CanvasItem, state: TelemetryState, accent: Color, clock: float) -> void:
	_panel(canvas, _rect_poly(Rect2(8.0, 460.0, 296.0, 30.0)), PANEL, accent)
	var shown: String = state.caption.substr(0, floori(state.caption_chars))
	canvas.draw_string(UI.HEADER, Vector2(16.0, 480.0), shown, HORIZONTAL_ALIGNMENT_LEFT, 272.0, 15, accent)
	if int(clock * 3.0) % 2 == 0:
		var width: float = UI.HEADER.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15).x
		canvas.draw_rect(Rect2(minf(16.0 + width + 2.0, 292.0), 469.0, 5.0, 12.0), accent)


static func _pops(canvas: CanvasItem, state: TelemetryState, clock: float, reduce_motion: bool) -> void:
	for pop: Dictionary in state.pops:
		var spot: Array = POP_SPOTS[String(pop["kind"])]
		var age: float = clock - float(pop["born"])
		var scale: float = 1.9 - (age / 0.14) * 0.9 if age < 0.14 else 1.0 + 0.04 * sin(age * 30.0)
		var alpha: float = (1.6 - age) / 0.4 if age > 1.2 else 1.0
		var shake: float = 0.0 if reduce_motion or age >= 0.5 else sin(age * 50.0) * 1.5
		canvas.draw_set_transform(spot[0] + Vector2(shake, 0.0), float(spot[1]), Vector2(scale, scale))
		var tint: Color = spot[2]
		_text_centered(canvas, MARKER, String(pop["text"]), Vector2.ZERO, 26, Color(tint, alpha), 7)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
