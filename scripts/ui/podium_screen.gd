class_name PodiumScreen
extends CanvasLayer

## Race weekend finale (FASE 6): the podium of the first three finishers on a three-step
## neo-brutalist stage, a trophy and confetti, the purple FASTEST LAP stamp, the FIA GT3
## points table with the constructors' haul, and the RESTART RACE / EXIT TO HQ buttons.
## A 1920 x 1080 stage scaled to the window, in the pit wall language (ink borders, hard
## offset shadows, screentone). present(race) fills it from the final standings; the world
## shows it when the chequered flag falls.

signal restart_requested
signal exit_requested

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")

const STAGE := Vector2(1920.0, 1080.0)
## FIA GT3 championship points for P1..P10, plus one for the fastest lap.
const POINTS: Array[int] = [25, 18, 15, 12, 10, 8, 6, 4, 2, 1]
const FASTEST_LAP_BONUS: int = 1
const REVEAL_S: float = 1.6
const CONFETTI_COUNT: int = 160
const CONSTRUCTOR_ROWS: int = 5
const GOLD := Color("#FFD23F")
const SILVER := Color("#D8DCE6")
const BRONZE := Color("#D9803A")
## Step rectangles by finishing place: P1 centre and tallest, P2 left, P3 right.
const STEP_RECTS: Array[Rect2] = [
	Rect2(520.0, 580.0, 360.0, 300.0),
	Rect2(150.0, 660.0, 360.0, 220.0),
	Rect2(890.0, 720.0, 360.0, 160.0),
]
const STEP_TINT: Array[Color] = [GOLD, SILVER, BRONZE]
const CARD_H: float = 140.0
const CARD_GAP: float = 12.0

var race: GtRace
var order: Array[GtCar] = []
## The first three finishers, P1 first.
var winners: Array[GtCar] = []
var fastest_car: GtCar
var driver_points: Dictionary = {} # car id -> points scored this race
var team_points: Dictionary = {} # team id -> points scored this race
## Per finishing place (P1 first): the cards' name, time labels and the step panels.
var name_labels: Array[Label] = []
var time_labels: Array[Label] = []
var steps: Array[Control] = []
var cards: Array[Control] = []
var points_labels: Array[Label] = [] # one row per points place, P1 first
var constructor_labels: Array[Label] = []
var stamp: Control
var restart_button: Button
var exit_button: Button
var stage: Control

var _reveal: float = 0.0
var _confetti: Confetti
var _built: bool = false


func _ready() -> void:
	layer = 20
	visible = false
	get_viewport().size_changed.connect(fit)


## Points for a finishing place (1-based); 0 outside the points.
static func points_for(place: int) -> int:
	return POINTS[place - 1] if place >= 1 and place <= POINTS.size() else 0


## The car with the quickest lap of the race, or null before anybody finished one.
static func fastest_lap_car(cars: Array[GtCar]) -> GtCar:
	var best: GtCar = null
	for car: GtCar in cars:
		if car.best_lap > 0.0 and (best == null or car.best_lap < best.best_lap):
			best = car
	return best


## {"drivers": car id -> points, "teams": team id -> points} for a final order. The fastest
## lap earns its bonus point only from inside the top ten, as in the FIA tables.
static func award_points(final_order: Array[GtCar], fastest: GtCar) -> Dictionary:
	var drivers: Dictionary = {}
	var teams: Dictionary = {}
	for index: int in range(final_order.size()):
		var car: GtCar = final_order[index]
		var scored: int = 0 if car.is_dnf else points_for(index + 1)
		if car == fastest and scored > 0:
			scored += FASTEST_LAP_BONUS
		drivers[car.id] = scored
		teams[car.team_id] = int(teams.get(car.team_id, 0)) + scored
	return {"drivers": drivers, "teams": teams}


## 4292.481 -> "1:11:32.481", 83.4 -> "1:23.400".
static func format_time(seconds: float) -> String:
	var hours: int = int(seconds / 3600.0)
	var minutes: int = int(fmod(seconds, 3600.0) / 60.0)
	var rest: float = fmod(seconds, 60.0)
	if hours > 0:
		return "%d:%02d:%06.3f" % [hours, minutes, rest]
	return "%d:%06.3f" % [minutes, rest]


## Fills the screen from a finished race and shows it.
func present(p_race: GtRace) -> void:
	race = p_race
	order = race.standings()
	winners.clear()
	for index: int in range(mini(3, order.size())):
		winners.append(order[index])
	fastest_car = fastest_lap_car(race.cars)
	var awards: Dictionary = award_points(order, fastest_car)
	driver_points = awards["drivers"]
	team_points = awards["teams"]
	_build()
	_reveal = 0.0
	_apply_reveal()
	visible = true
	fit()


func fit() -> void:
	if stage == null or not is_inside_tree():
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var factor: float = minf(view.x / STAGE.x, view.y / STAGE.y)
	stage.scale = Vector2(factor, factor)
	stage.position = (view - STAGE * factor) * 0.5


func _process(delta: float) -> void:
	step(delta)


## One frame: the steps rise, the cards drop in, the confetti falls.
func step(delta: float) -> void:
	if not _built:
		return
	if _reveal < 1.0:
		_reveal = minf(1.0, _reveal + delta / REVEAL_S)
		_apply_reveal()
	_confetti.step(delta)


func is_revealed() -> bool:
	return _reveal >= 1.0


# --- construction --------------------------------------------------------------------------

func _build() -> void:
	if stage != null:
		stage.queue_free()
		get_node("Backdrop").queue_free()
	name_labels.clear()
	time_labels.clear()
	steps.clear()
	cards.clear()
	points_labels.clear()
	constructor_labels.clear()
	# The backdrop covers the whole window, the stage is the letterboxed 16:9 frame inside it.
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = T.BG_CANVAS_DEEP
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = Control.new()
	stage.name = "Stage"
	stage.size = STAGE
	add_child(stage)
	_build_title()
	for place: int in range(winners.size()):
		_build_step(place, winners[place])
	_build_trophy()
	_build_points_table()
	_build_constructors()
	_build_stamp()
	_build_buttons()
	_confetti = Confetti.new()
	_confetti.name = "Confetti"
	_confetti.size = STAGE
	stage.add_child(_confetti)
	_confetti.scatter(CONFETTI_COUNT)
	_built = true


func _panel(at: Vector2, extent: Vector2, accent: Color = Color(1.0, 1.0, 1.0, 0.2)) -> Control:
	var panel := Control.new()
	panel.size = extent
	panel.custom_minimum_size = extent
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(panel)
	panel.position = at
	UI.surface(panel, accent)
	return panel


func _text(parent: Control, text: String, at: Vector2, font_size: int, color: Color, font: Font = UI.MONO) -> Label:
	var label := UI.label(text, font_size, color, font)
	parent.add_child(label)
	label.position = at
	return label


func _build_title() -> void:
	var bar: Control = _panel(Vector2(16.0, 16.0), Vector2(1888.0, 100.0), T.ACCENT_ACID_LIME)
	bar.name = "TitleBar"
	_text(bar, "CHEQUERED FLAG  //  PODIUM", Vector2(28.0, 8.0), 72, T.ACCENT_ACID_LIME, UI.DISPLAY)
	var detail: String = "LA VOITURE GRAND PRIX  //  %d LAPS" % race.laps
	var sub: Label = _text(bar, detail, Vector2(1100.0, 34.0), 26, T.TEXT_SECONDARY, UI.HEADER)
	sub.size = Vector2(760.0, 34.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _build_step(place: int, car: GtCar) -> void:
	var rect: Rect2 = STEP_RECTS[place]
	var tint: Color = Liveries.color_for(car.team_id)
	var step_panel: Control = _panel(rect.position, rect.size, STEP_TINT[place])
	step_panel.name = "Step%d" % (place + 1)
	var block := ColorRect.new()
	block.color = STEP_TINT[place]
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	step_panel.add_child(block)
	block.position = Vector2(8.0, 8.0)
	block.size = rect.size - Vector2(16.0, 16.0)
	var stripe := ColorRect.new()
	stripe.color = tint
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	step_panel.add_child(stripe)
	stripe.position = Vector2(8.0, 8.0)
	stripe.size = Vector2(rect.size.x - 16.0, 22.0)
	var numeral: Label = _text(step_panel, str(place + 1), Vector2(0.0, 20.0), int(minf(190.0, rect.size.y * 0.6)), T.INK_BORDER_BLACK, UI.DISPLAY)
	numeral.size = Vector2(rect.size.x, rect.size.y - 20.0)
	numeral.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	numeral.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	steps.append(step_panel)
	# Driver card above the step.
	var card: Control = _panel(Vector2(rect.position.x, rect.position.y - CARD_H - CARD_GAP), Vector2(rect.size.x, CARD_H), tint)
	card.name = "Card%d" % (place + 1)
	var badge := ColorRect.new()
	badge.color = tint
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge)
	badge.position = Vector2(14.0, 14.0)
	badge.size = Vector2(76.0, 76.0)
	var number: Label = _text(badge, "%02d" % car.number, Vector2(0.0, 0.0), 54, T.INK_BORDER_BLACK, UI.DISPLAY)
	number.size = badge.size
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var driver: Label = _text(card, car.driver_name.to_upper(), Vector2(104.0, 10.0), 34, T.TEXT_PRIMARY, UI.DISPLAY)
	driver.size = Vector2(rect.size.x - 116.0, 44.0)
	driver.clip_text = true
	_text(card, "%s  //  %s" % [car.code, car.team_name.to_upper()], Vector2(104.0, 58.0), 17, tint, UI.HEADER)
	_text(card, "P%d" % (place + 1), Vector2(104.0, 82.0), 15, T.TEXT_MUTED)
	var time_label: Label = _text(card, format_time(car.finished_at), Vector2(14.0, 102.0), 24, T.ACCENT_ACID_LIME)
	time_label.size = Vector2(rect.size.x - 28.0, 30.0)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_labels.append(driver)
	time_labels.append(time_label)
	cards.append(card)


func _build_trophy() -> void:
	var trophy := Trophy.new()
	trophy.name = "Trophy"
	stage.add_child(trophy)
	var centre: float = STEP_RECTS[0].position.x + STEP_RECTS[0].size.x * 0.5
	trophy.size = Vector2(180.0, 190.0)
	trophy.position = Vector2(centre - 90.0, STEP_RECTS[0].position.y - CARD_H - CARD_GAP - 200.0)


func _build_points_table() -> void:
	var panel: Control = _panel(Vector2(1290.0, 140.0), Vector2(614.0, 520.0), T.ACCENT_ELECTRIC_CYAN)
	panel.name = "PointsTable"
	var header := UI.header("FIA GT3  //  CHAMPIONSHIP POINTS", T.ACCENT_ELECTRIC_CYAN)
	panel.add_child(header)
	header.position = Vector2(8.0, 8.0)
	header.size = Vector2(598.0, 30.0)
	for index: int in range(POINTS.size()):
		var car: GtCar = order[index] if index < order.size() else null
		var scored: int = int(driver_points.get(car.id, 0)) if car != null else 0
		var row_y: float = 52.0 + 44.0 * float(index)
		var tint: Color = Liveries.color_for(car.team_id) if car != null else T.TEXT_MUTED
		var strip := ColorRect.new()
		strip.color = tint if index < 3 else Color(tint, 0.5)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(strip)
		strip.position = Vector2(14.0, row_y + 4.0)
		strip.size = Vector2(6.0, 32.0)
		_text(panel, "P%d" % (index + 1), Vector2(30.0, row_y + 4.0), 24, STEP_TINT[index] if index < 3 else T.TEXT_PRIMARY, UI.HEADER)
		var who: String = "#%02d %s" % [car.number, car.code] if car != null else "--"
		_text(panel, who, Vector2(100.0, row_y + 6.0), 20, T.TEXT_PRIMARY)
		var pts: Label = _text(panel, "%d PTS" % scored, Vector2(380.0, row_y + 2.0), 28, T.ACCENT_ACID_LIME, UI.DISPLAY)
		pts.size = Vector2(212.0, 34.0)
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		points_labels.append(pts)


func _build_constructors() -> void:
	var panel: Control = _panel(Vector2(1290.0, 684.0), Vector2(614.0, 300.0), T.ACCENT_CYBER_YELLOW)
	panel.name = "Constructors"
	var header := UI.header("CONSTRUCTORS  //  THIS RACE", T.ACCENT_CYBER_YELLOW)
	panel.add_child(header)
	header.position = Vector2(8.0, 8.0)
	header.size = Vector2(598.0, 30.0)
	var teams: Array = team_points.keys()
	teams.sort_custom(func(a: int, b: int) -> bool:
		var pa: int = int(team_points[a])
		var pb: int = int(team_points[b])
		return pa > pb if pa != pb else a < b)
	for index: int in range(mini(CONSTRUCTOR_ROWS, teams.size())):
		var team_id: int = teams[index]
		var row_y: float = 50.0 + 48.0 * float(index)
		var strip := ColorRect.new()
		strip.color = Liveries.color_for(team_id)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(strip)
		strip.position = Vector2(14.0, row_y + 4.0)
		strip.size = Vector2(6.0, 34.0)
		_text(panel, "%d" % (index + 1), Vector2(30.0, row_y + 4.0), 24, T.TEXT_SECONDARY, UI.HEADER)
		_text(panel, _team_name(team_id).to_upper(), Vector2(64.0, row_y + 4.0), 24, T.TEXT_PRIMARY, UI.HEADER)
		var pts: Label = _text(panel, "%d PTS" % int(team_points[team_id]), Vector2(400.0, row_y + 2.0), 28, T.ACCENT_CYBER_YELLOW, UI.DISPLAY)
		pts.size = Vector2(192.0, 34.0)
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		constructor_labels.append(pts)


func _team_name(team_id: int) -> String:
	for car: GtCar in race.cars:
		if car.team_id == team_id:
			return car.team_name
	return "TEAM %d" % team_id


## The purple graffiti stamp, crooked on its hard shadow.
func _build_stamp() -> void:
	if fastest_car == null:
		return
	stamp = _panel(Vector2(140.0, 150.0), Vector2(520.0, 108.0), T.ACCENT_PURPLE_SECTOR)
	stamp.name = "FastestLapStamp"
	var fill := ColorRect.new()
	fill.color = T.ACCENT_PURPLE_SECTOR
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.add_child(fill)
	fill.position = Vector2(6.0, 6.0)
	fill.size = Vector2(508.0, 96.0)
	var title: Label = _text(stamp, "★ FASTEST LAP // +%d PT BONUS" % FASTEST_LAP_BONUS, Vector2(0.0, 4.0), 40, T.INK_BORDER_BLACK, UI.DISPLAY)
	title.size = Vector2(520.0, 60.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lap: Label = _text(stamp, "#%02d %s  %s" % [fastest_car.number, fastest_car.code, _lap_text(fastest_car.best_lap)], Vector2(0.0, 70.0), 22, T.INK_BORDER_BLACK, UI.HEADER)
	lap.size = Vector2(520.0, 28.0)
	lap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.pivot_offset = stamp.size * 0.5
	stamp.rotation = deg_to_rad(-6.0)


func _lap_text(seconds: float) -> String:
	return "%d:%06.3f" % [int(seconds / 60.0), fmod(seconds, 60.0)]


func _build_buttons() -> void:
	restart_button = UI.button("RESTART RACE")
	restart_button.add_theme_font_size_override("font_size", 30)
	restart_button.focus_mode = Control.FOCUS_NONE
	restart_button.pressed.connect(_on_restart)
	stage.add_child(restart_button)
	restart_button.position = Vector2(150.0, 940.0)
	restart_button.size = Vector2(540.0, 70.0)
	exit_button = UI.button("EXIT TO HQ", T.ACCENT_ANIME_CRIMSON)
	exit_button.add_theme_font_size_override("font_size", 30)
	exit_button.focus_mode = Control.FOCUS_NONE
	exit_button.pressed.connect(_on_exit)
	stage.add_child(exit_button)
	exit_button.position = Vector2(710.0, 940.0)
	exit_button.size = Vector2(540.0, 70.0)


func _on_restart() -> void:
	AudioManager.click(self)
	restart_requested.emit()


func _on_exit() -> void:
	AudioManager.click(self)
	exit_requested.emit()


## Steps rise from the floor, then the cards drop onto them and the stamp slaps down.
func _apply_reveal() -> void:
	for place: int in range(steps.size()):
		var rect: Rect2 = STEP_RECTS[place]
		var rise: float = ease(clampf(_reveal / 0.6, 0.0, 1.0), -2.0)
		var height: float = rect.size.y * rise
		steps[place].position.y = rect.position.y + rect.size.y - height
		steps[place].size.y = maxf(height, 1.0)
		steps[place].clip_contents = true
		var drop: float = ease(clampf((_reveal - 0.45) / 0.4, 0.0, 1.0), -2.0)
		cards[place].modulate.a = drop
		cards[place].position.y = rect.position.y - CARD_H - CARD_GAP - 40.0 * (1.0 - drop)
	if stamp != null:
		stamp.modulate.a = clampf((_reveal - 0.8) / 0.2, 0.0, 1.0)


# --- drawn pieces --------------------------------------------------------------------------------

## Falling paper in the palette; seeded so a capture is repeatable.
class Confetti extends Control:
	const COLORS: Array[Color] = [
		Color("#CCFF00"), Color("#00F0FF"), Color("#FFE600"), Color("#FF1E56"), Color("#D946EF"), Color("#F4F5F7"),
	]
	var pieces: Array[Dictionary] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func scatter(count: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 6
		pieces.clear()
		for index: int in range(count):
			pieces.append({
				"pos": Vector2(rng.randf_range(0.0, 1920.0), rng.randf_range(-100.0, 1080.0)),
				"fall": rng.randf_range(90.0, 220.0),
				"sway": rng.randf_range(0.5, 2.2),
				"phase": rng.randf_range(0.0, TAU),
				"rot": rng.randf_range(0.0, TAU),
				"spin": rng.randf_range(-6.0, 6.0),
				"size": Vector2(rng.randf_range(10.0, 20.0), rng.randf_range(6.0, 11.0)),
				"color": COLORS[index % COLORS.size()],
			})
		queue_redraw()

	func step(delta: float) -> void:
		for piece: Dictionary in pieces:
			var pos: Vector2 = piece["pos"]
			piece["phase"] = float(piece["phase"]) + delta * float(piece["sway"])
			pos.y += float(piece["fall"]) * delta
			pos.x += sin(float(piece["phase"])) * 40.0 * delta
			if pos.y > 1100.0:
				pos.y = -20.0
			piece["pos"] = pos
			piece["rot"] = float(piece["rot"]) + float(piece["spin"]) * delta
		queue_redraw()

	func _draw() -> void:
		for piece: Dictionary in pieces:
			var extent: Vector2 = piece["size"]
			draw_set_transform(piece["pos"], float(piece["rot"]))
			draw_rect(Rect2(-extent * 0.5, extent), Color.BLACK)
			draw_rect(Rect2(-extent * 0.5 + Vector2.ONE, extent - Vector2(2.0, 2.0)), piece["color"])


## A gold cup: bowl, two handles, stem and a plinth, on an ink outline and a hard shadow.
class Trophy extends Control:
	const INK := Color("#050505")
	const GOLD_DARK := Color("#C9962B")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cx: float = size.x * 0.5
		var gold := Color("#FFD23F")
		_shape(PackedVector2Array([Vector2(cx - 62.0, 10.0), Vector2(cx + 62.0, 10.0), Vector2(cx + 46.0, 100.0), Vector2(cx + 14.0, 124.0), Vector2(cx - 14.0, 124.0), Vector2(cx - 46.0, 100.0)]), gold)
		for side: float in [-1.0, 1.0]:
			_shape(PackedVector2Array([Vector2(cx + side * 60.0, 24.0), Vector2(cx + side * 92.0, 30.0), Vector2(cx + side * 90.0, 70.0), Vector2(cx + side * 52.0, 88.0), Vector2(cx + side * 56.0, 72.0), Vector2(cx + side * 74.0, 60.0), Vector2(cx + side * 74.0, 42.0), Vector2(cx + side * 60.0, 40.0)]), gold)
		_shape(PackedVector2Array([Vector2(cx - 12.0, 122.0), Vector2(cx + 12.0, 122.0), Vector2(cx + 18.0, 156.0), Vector2(cx - 18.0, 156.0)]), GOLD_DARK)
		_shape(PackedVector2Array([Vector2(cx - 48.0, 156.0), Vector2(cx + 48.0, 156.0), Vector2(cx + 48.0, 182.0), Vector2(cx - 48.0, 182.0)]), INK.lerp(gold, 0.15))
		draw_rect(Rect2(cx - 40.0, 26.0, 12.0, 54.0), Color(1.0, 1.0, 1.0, 0.55))

	func _shape(points: PackedVector2Array, fill: Color) -> void:
		var shadow := PackedVector2Array()
		for point: Vector2 in points:
			shadow.append(point + Vector2(6.0, 6.0))
		draw_colored_polygon(shadow, INK)
		draw_colored_polygon(points, fill)
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, INK, 4.0)
