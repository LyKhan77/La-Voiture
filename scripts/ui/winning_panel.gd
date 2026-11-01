class_name WinningPanel
extends Control

## One panel of the winning triptych: a finisher's standee and car sprite breaking out of a slanted manga panel,
## with the manga character card around them (rank stencil, kanji box, close-up bubble, spray tag, result plate and,
## when the panel is in focus, the epithet box, car/engine plate and sound effect). The panel Control holds the
## content; `background` (the slanted burst) is a separate node that WinningTriptych keeps in a lower layer so a
## car can burst over its neighbour's background without being painted over by it.

const Kit := preload("res://scripts/ui/graffiti_kit.gd")
const Roster := preload("res://scripts/ui/garage_roster.gd")
const UI := preload("res://scripts/ui/pit_wall_ui.gd")
const DIECUT := preload("res://shaders/diecut_sprite.gdshader")
const BURST := preload("res://shaders/winning_panel_burst.gdshader")
const KANJI_FONT := preload("res://assets/fonts/DelaGothicOne-Podium.ttf")

const SLANT_PX: float = 90.0
const INK_PX: float = 16.0
const PANEL_HEIGHT: float = 940.0
const NAME_MAX_WIDTH: float = 380.0
const NAME_FONT_PX: int = 80
const CAR_WIDTH_FRACTION: float = 0.76
const CAR_MAX_WIDTH: float = 760.0
const CAR_FLOOR_GAP: float = 34.0
const STANDEE_HEIGHT: float = 640.0
const BUBBLE_PX: float = 230.0
const OUTLINE_PX: float = 5.0
const STICKER_PAD_PX: float = 40.0
const BREATH_PERIOD: float = 2.4
const BREATH_SCALE: float = 0.015
const DIM_BRIGHTNESS: float = 0.5
## Rank colours (index = place), their dark burst base and the lighter ray tint.
const COLORS: Array[Color] = [Color("#D8FF00"), Color("#00F0FF"), Color("#FF6B00")]
const DARK: Array[Color] = [Color("#2C3300"), Color("#00343A"), Color("#3A1900")]
const TINT: Array[Color] = [Color("#5E7000"), Color("#006D75"), Color("#7A3500")]
const INK := Color("#050505")

## 0 = P1, 1 = P2, 2 = P3.
var place: int = 0
var background: Control
var rank_label: Label
var kanji_label: Label
var name_label: Label
var result_label: Label
var epithet_box: Control
var engine_plate: Control
var sfx_label: Label
var crown: Control
var standee: TextureRect
var car: TextureRect
var bubble: TextureRect

## 0 hides the focus-only details (epithet, car/engine plate, sound effect), 1 shows them.
var detail_amount: float = 1.0:
	set(value):
		detail_amount = clampf(value, 0.0, 1.0)
		for detail: Control in [epithet_box, engine_plate, sfx_label]:
			if detail != null:
				detail.modulate.a = detail_amount
## 1 darkens the panel and its background to DIM_BRIGHTNESS (the panels that are not in focus).
var dim_amount: float = 0.0:
	set(value):
		dim_amount = clampf(value, 0.0, 1.0)
		var level: float = lerpf(1.0, DIM_BRIGHTNESS, dim_amount)
		modulate = Color(level, level, level, 1.0)
		if background != null:
			background.modulate = Color(level, level, level, 1.0)

var _animate: bool = false
var _breath: Tween
var _fill: Polygon2D
var _ink: Line2D
var _ghost: Label
var _bubble_layers: Array[Control] = []
var _kanji_box: Control
var _name_tag_color: Color


## `textures` holds "standee", "car" and "portrait" (any may be null: that element is simply not drawn).
func setup(finisher_place: int, entry: Dictionary, gap_text: String, fastest_bonus: bool, textures: Dictionary, animate: bool) -> void:
	place = clampi(finisher_place, 0, 2)
	_animate = animate
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color: Color = COLORS[place]
	_build_background(color)

	rank_label = Kit.stencil_numeral("P%d" % (place + 1), color, 170)
	add_child(rank_label)
	_build_kanji_box(color)
	_build_bubble(color, textures.get("portrait") as Texture2D)
	standee = _sticker(textures.get("standee") as Texture2D)
	add_child(standee)
	car = _sticker(textures.get("car") as Texture2D)
	add_child(car)
	if place == 0:
		crown = Kit.crown()
		crown.pivot_offset = Vector2(crown.size.x * 0.5, crown.size.y)
		crown.scale = Vector2(0.7, 0.7)
		crown.rotation_degrees = 5.0
		add_child(crown)

	_name_tag_color = color
	name_label = Kit.spray_tag(String(entry.driver_name).to_upper(), color, NAME_MAX_WIDTH, NAME_FONT_PX, animate)
	name_label.pivot_offset = name_label.size * 0.5
	name_label.rotation_degrees = -4.0
	add_child(name_label)

	var points_text: String = "%s // %d PTS" % [gap_text, int(entry.points)]
	if fastest_bonus:
		points_text += " +1 FL"
	result_label = Kit.plate(points_text, color, 30)
	result_label.size = result_label.get_minimum_size()
	add_child(result_label)

	_build_details(entry, color)
	detail_amount = 1.0
	dim_amount = 0.0
	relayout(Vector2(730.0, PANEL_HEIGHT))


func _ready() -> void:
	if _animate:
		start_breathing()


func _exit_tree() -> void:
	stop_breathing()


## Lays every element out for a panel `panel_size` big (the triptych changes the width while it focuses).
func relayout(panel_size: Vector2) -> void:
	size = panel_size
	var polygon: PackedVector2Array = background_polygon()
	_fill.polygon = polygon
	var uv := PackedVector2Array()
	for point: Vector2 in polygon:
		uv.append(Vector2(point.x / panel_size.x, point.y / panel_size.y))
	_fill.uv = uv
	(_fill.material as ShaderMaterial).set_shader_parameter("panel_px", panel_size)
	var closed: PackedVector2Array = polygon.duplicate()
	closed.append(polygon[0])
	_ink.points = closed
	_ghost.position = Vector2(110.0, panel_size.y - 470.0)
	background.size = panel_size
	(background as PanelBackground).polygon = polygon

	rank_label.position = Vector2(140.0, 6.0)
	_kanji_box.position = Vector2(150.0, 190.0)
	var bubble_at := Vector2(panel_size.x - 64.0 - BUBBLE_PX, 22.0)
	for layer: Control in _bubble_layers:
		layer.position = bubble_at + layer.get_meta(&"offset", Vector2.ZERO) as Vector2

	if standee.texture != null:
		var standee_size := Vector2(STANDEE_HEIGHT * _aspect(standee.texture), STANDEE_HEIGHT)
		_fit_sticker(standee, standee_size, Vector2((panel_size.x - standee_size.x) * 0.5, panel_size.y - STANDEE_HEIGHT))
		standee.pivot_offset = Vector2(standee_size.x * 0.5, standee_size.y)
	if car.texture != null:
		var car_width: float = minf(panel_size.x * CAR_WIDTH_FRACTION, CAR_MAX_WIDTH)
		var car_size := Vector2(car_width, car_width / _aspect(car.texture))
		_fit_sticker(car, car_size, Vector2((panel_size.x - car_width) * 0.5, panel_size.y - CAR_FLOOR_GAP - car_size.y))
	if crown != null:
		crown.position = Vector2(panel_size.x * 0.5 - 40.0 - crown.size.x * 0.5 + 40.0, panel_size.y - STANDEE_HEIGHT - crown.size.y + 24.0)

	name_label.position = Vector2(panel_size.x - 36.0 - name_label.size.x, 262.0)
	result_label.position = Vector2(120.0, panel_size.y - 70.0)
	epithet_box.position = Vector2(130.0, 410.0)
	engine_plate.position = Vector2(panel_size.x - 30.0 - engine_plate.size.x, 352.0)
	sfx_label.position = Vector2(panel_size.x - 44.0 - sfx_label.size.x, 450.0)


## The slanted panel shape in panel space: top edge inset by the slant on the left, bottom edge on the right.
func background_polygon() -> PackedVector2Array:
	return PackedVector2Array([Vector2(SLANT_PX, 0.0), Vector2(size.x, 0.0), Vector2(size.x - SLANT_PX, size.y), Vector2(0.0, size.y)])


func start_breathing() -> void:
	stop_breathing()
	if standee == null or not is_inside_tree():
		return
	_breath = create_tween().set_loops()
	_breath.tween_property(standee, "scale:y", 1.0 + BREATH_SCALE, BREATH_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath.tween_property(standee, "scale:y", 1.0, BREATH_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func stop_breathing() -> void:
	if _breath != null and _breath.is_valid():
		_breath.kill()
	_breath = null
	if standee != null:
		standee.scale = Vector2.ONE


func _aspect(texture: Texture2D) -> float:
	var texture_size: Vector2 = texture.get_size()
	return texture_size.x / maxf(texture_size.y, 1.0)


func _sticker(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	var material := ShaderMaterial.new()
	material.shader = DIECUT
	material.set_shader_parameter("outline_px", OUTLINE_PX)
	material.set_shader_parameter("pad_px", STICKER_PAD_PX)
	rect.material = material
	rect.visible = texture != null
	return rect


func _fit_sticker(rect: TextureRect, rect_size: Vector2, at: Vector2) -> void:
	rect.size = rect_size
	rect.position = at
	(rect.material as ShaderMaterial).set_shader_parameter("rect_px", rect_size)


func _build_background(color: Color) -> void:
	background = PanelBackground.new()
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	_fill = Polygon2D.new()
	var burst := ShaderMaterial.new()
	burst.shader = BURST
	burst.set_shader_parameter("base_color", DARK[place])
	burst.set_shader_parameter("ray_color", TINT[place])
	_fill.material = burst
	background.add_child(_fill)
	_ghost = Kit.stencil_numeral(str(place + 1), color, 560)
	_ghost.label_settings.outline_size = 0
	_ghost.label_settings.shadow_size = 0
	_ghost.modulate = Color(1.0, 1.0, 1.0, 0.2)
	background.add_child(_ghost)
	_ink = Line2D.new()
	_ink.width = INK_PX
	_ink.default_color = INK
	_ink.joint_mode = Line2D.LINE_JOINT_SHARP
	background.add_child(_ink)


## A white box with a vertical column of rank kanji, hard-shadowed in the rank colour.
func _build_kanji_box(color: Color) -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kanji: String = Roster.RANK_KANJI[place]
	var column: PackedStringArray = PackedStringArray()
	for index: int in range(kanji.length()):
		column.append(kanji[index])
	kanji_label = Label.new()
	kanji_label.text = "\n".join(column)
	kanji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kanji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kanji_label.add_theme_font_override("font", KANJI_FONT)
	kanji_label.add_theme_font_size_override("font_size", 52)
	kanji_label.add_theme_color_override("font_color", INK)
	kanji_label.add_theme_constant_override("line_spacing", -4)
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.set_border_width_all(5)
	box.border_color = INK
	box.shadow_color = color
	box.shadow_size = 1
	box.shadow_offset = Vector2(7.0, 7.0)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	kanji_label.add_theme_stylebox_override("normal", box)
	kanji_label.size = kanji_label.get_minimum_size()
	holder.add_child(kanji_label)
	_kanji_box = holder
	add_child(holder)


## Round close-up: portrait clipped to a circle, an ink ring, a rank-coloured hard shadow and an ink edge under it.
func _build_bubble(color: Color, portrait: Texture2D) -> void:
	var circle_size := Vector2(BUBBLE_PX, BUBBLE_PX)
	var edge: Panel = _circle(circle_size, INK, false)
	edge.set_meta(&"offset", Vector2(11.0, 11.0))
	var shadow: Panel = _circle(circle_size, color, false)
	shadow.set_meta(&"offset", Vector2(8.0, 8.0))
	var frame: Panel = _circle(circle_size, INK, true)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	bubble = TextureRect.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.texture = portrait
	bubble.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bubble.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bubble.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(bubble)
	for layer: Panel in [edge, shadow, frame]:
		_bubble_layers.append(layer)
		add_child(layer)


func _circle(circle_size: Vector2, fill: Color, ringed: bool) -> Panel:
	var disc := Panel.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.size = circle_size
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(int(circle_size.x * 0.5))
	if ringed:
		style.set_border_width_all(8)
		style.border_color = INK
	disc.add_theme_stylebox_override("panel", style)
	return disc


func _build_details(entry: Dictionary, color: Color) -> void:
	var epithet: String = Roster.epithet(int(entry.id))
	epithet_box = Control.new()
	epithet_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var epithet_text := Label.new()
	epithet_text.text = epithet.to_upper()
	epithet_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	epithet_text.add_theme_font_override("font", UI.MONO)
	epithet_text.add_theme_font_size_override("font_size", 20)
	epithet_text.add_theme_color_override("font_color", INK)
	var narration := StyleBoxFlat.new()
	narration.bg_color = Color.WHITE
	narration.set_border_width_all(5)
	narration.border_color = INK
	narration.shadow_color = color
	narration.shadow_size = 1
	narration.shadow_offset = Vector2(6.0, 6.0)
	narration.content_margin_left = 14.0
	narration.content_margin_right = 14.0
	narration.content_margin_top = 6.0
	narration.content_margin_bottom = 6.0
	epithet_text.add_theme_stylebox_override("normal", narration)
	epithet_text.size = epithet_text.get_minimum_size()
	epithet_box.add_child(epithet_text)
	epithet_box.size = epithet_text.size
	epithet_box.visible = epithet != ""
	add_child(epithet_box)

	var team: int = int(entry.team_id)
	engine_plate = Control.new()
	engine_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var engine_text := Label.new()
	engine_text.text = "%s\n%s" % [Roster.CAR_NAMES[posmod(team, Roster.CAR_NAMES.size())].to_upper(), Roster.CAR_ENGINES[posmod(team, Roster.CAR_ENGINES.size())]]
	engine_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	engine_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	engine_text.add_theme_font_override("font", UI.MONO)
	engine_text.add_theme_font_size_override("font_size", 17)
	engine_text.add_theme_color_override("font_color", color)
	var plate := StyleBoxFlat.new()
	plate.bg_color = INK
	plate.content_margin_left = 12.0
	plate.content_margin_right = 12.0
	plate.content_margin_top = 4.0
	plate.content_margin_bottom = 4.0
	engine_text.add_theme_stylebox_override("normal", plate)
	engine_text.size = engine_text.get_minimum_size()
	engine_plate.add_child(engine_text)
	engine_plate.size = engine_text.size
	add_child(engine_plate)

	sfx_label = Label.new()
	sfx_label.text = Roster.RANK_SFX[place]
	sfx_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var settings := LabelSettings.new()
	settings.font = KANJI_FONT
	settings.font_size = 104
	settings.font_color = color
	settings.outline_size = 7
	settings.outline_color = INK
	settings.shadow_size = 0
	settings.shadow_color = INK
	settings.shadow_offset = Vector2(9.0, 9.0)
	sfx_label.label_settings = settings
	sfx_label.size = sfx_label.get_minimum_size()
	sfx_label.pivot_offset = sfx_label.size * 0.5
	sfx_label.rotation_degrees = 8.0
	add_child(sfx_label)


## The slanted background keeps its own hit shape, so a click lands on the panel it visibly belongs to.
class PanelBackground extends Control:
	var polygon: PackedVector2Array = PackedVector2Array()

	func _has_point(point: Vector2) -> bool:
		return polygon.size() >= 3 and Geometry2D.is_point_in_polygon(point, polygon)
