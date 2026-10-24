extends CanvasLayer

## Comic radio cut-in banner (Layer 3 / Z:30).
## Decorative and input-transparent: every node is MOUSE_FILTER_IGNORE.
## The ENGINEER role is the same banner mirrored to the right edge, in cyan, so the driver
## and the pit wall can be on screen at the same time (set role before adding to the tree).
## Default placement is the bottom strip of the window (pit wall dashboard). set_dock() instead
## parks the banner at the top of a free area, at the HUD scale, and fades it down into place.

enum Role { DRIVER, ENGINEER }

signal transmission_shown(car_id: int, message: String)
## The banner has left the screen: the message is over.
signal transmission_finished

const T = preload("res://scripts/ui/ui_theme_tokens.gd")
const UI = preload("res://scripts/ui/pit_wall_ui.gd")

const BANNER_WIDTH := 470.0
const BANNER_MIN_HEIGHT := 190.0
const TICKER_OFFSET := 84.0
const SLIDE_X := 32.0
const SLIDE_IN_SEC := 0.22
const HOLD_SEC := 3.5
const SLIDE_OUT_SEC := 0.18
const PORTRAIT_SIZE := 96.0
## The portrait is a die-cut sticker that sticks out of the outer top corner of the card.
const STICKER_OVERHANG := Vector2(30.0, 26.0)
const STICKER_TILT_DEG := 6.0
## Text starts after the sticker on the driver card, mirrored on the engineer card.
const TEXT_NEAR_X := 84.0
const SPEAKER_SIZE := 15
const SPEECH_SIZE := 30
const SPEAKER_Y := 10.0
const SPEECH_Y := 32.0
const TEXT_RIGHT_PAD := 24.0
## R2 card: tilt at rest (driver, engineer), the dark sheet behind it, the listener's dim state.
const REST_TILT_DEG: Array[float] = [-2.0, 1.6]
const SHADOW_TILT_DEG := 2.5
const SHADOW_COLOR := Color("#0A0C14")
const TAPE_COLOR := Color(1.0, 0.9, 0.47, 0.82)
const TAPE_SIZE := Vector2(78.0, 24.0)
const DIM_ALPHA := 0.6
const DIM_TINT := 0.75
const DIM_SCALE := 0.95
const SLAP_SEC := 0.45
const SLAP_SCALE := 1.55
const SLAP_START_DEG := 9.0
## The engineer card sits this far down the dock (0..1), below the driver card.
const ENGINEER_DOCK_Y := 0.42
const FADE_OUT_SEC := 1.8
## Torn paper outline, percent of the card size.
const PAPER_POINTS: Array[Vector2] = [
	Vector2(2, 6), Vector2(10, 1), Vector2(24, 5), Vector2(38, 0), Vector2(58, 5), Vector2(78, 1), Vector2(96, 6),
	Vector2(100, 30), Vector2(97, 52), Vector2(100, 78), Vector2(95, 98), Vector2(74, 94), Vector2(52, 100),
	Vector2(30, 95), Vector2(10, 99), Vector2(0, 90), Vector2(3, 62), Vector2(0, 36),
]
## The mirrored banner leans toward the window edge; keep that corner on screen.
const MIRROR_EDGE_PAD := 30.0
## Docked placement: margin to the free area edge, and how far the banner drops while fading in.
const DOCK_MARGIN := 28.0
const DOCK_DROP := 36.0
## Manga soundwave equalizer: bar count and size, harmonics (Hz) and how fast the bars chase
## their target while talking and fall back to the baseline when idle.
const WAVE_BARS := 12
const WAVE_BAR_W := 6.0
const WAVE_GAP := 4.0
const WAVE_MAX_H := 22.0
const WAVE_STRIP := 28.0
const WAVE_HARMONICS: Array[float] = [8.0, 14.0, 22.0]
const WAVE_ATTACK := 30.0
const WAVE_DECAY := 8.0

@onready var banner: Control = $Banner
@onready var speech: Label = $Banner/Speech
@onready var _speaker: Label = $Banner/Speaker
@onready var _backdrop: Control = $Banner/Backdrop
@onready var _portrait_frame: Panel = $Banner/PortraitFrame
@onready var _portrait: TextureRect = $Banner/PortraitFrame/Portrait

## Which side and colour the banner takes, and the title in its speaker line.
var role: int = Role.DRIVER
var role_title: String = "TEAM RADIO"

var _radio_font: FontVariation
var _portrait_texture: Texture2D
var _accent: Color = T.ACCENT_ACID_LIME
## Paper colour of a routine call; urgent calls are crimson.
var base_color: Color = T.ACCENT_ACID_LIME
## The listener of a two-way exchange: dimmed and a little smaller while the other card speaks.
var dimmed: bool = false
## The headline: capitalised, keywords as ink blocks. `speech` keeps the plain text.
var rich: RichTextLabel
var _message := ""
var _urgent := false
var _banner_h := BANNER_MIN_HEIGHT
var _banner_w := BANNER_WIDTH
var _present := false
var _hold := HOLD_SEC # how long the banner stays up for the message on screen
var _tween: Tween
## The equaliser bars: a layer of their own, so only these ~30 rects repaint while the radio speaks.
var _wave_layer: Control
static var halftone_tile: Texture2D # shared by the driver and engineer banners, built on first use
var _pending: Array = []
var _docked := false
var _dock_rect := Rect2()
var _dock_scale := 1.0

## True while a transmission is on screen: the soundwave bars pulse.
var soundwave_active: bool = false
var _soundwave_time: float = 0.0
var _wave_bars := PackedFloat32Array() # 0..1 height per bar
var _wave_x := 0.0 # left edge of the bars inside the banner


func _ready() -> void:
	var authored_width := banner.offset_right - banner.offset_left
	_banner_w = authored_width if authored_width > 100.0 else BANNER_WIDTH
	banner.anchor_left = 0.0
	banner.anchor_right = 0.0
	banner.anchor_top = 1.0
	banner.anchor_bottom = 1.0
	banner.offset_left = SLIDE_X
	banner.offset_right = SLIDE_X + _banner_w
	if _docked:
		banner.anchor_top = 0.0
		banner.anchor_bottom = 0.0
		banner.scale = Vector2(_dock_scale, _dock_scale)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.offset_left = 5.0
	_portrait.offset_top = 5.0
	_portrait.offset_right = -5.0
	_portrait.offset_bottom = -5.0
	base_color = T.ACCENT_ACID_LIME if role == Role.DRIVER else T.ACCENT_ELECTRIC_CYAN
	_accent = base_color
	_radio_font = _make_radio_font()
	_wave_bars.resize(WAVE_BARS)
	_apply_fonts()
	speech.self_modulate.a = 0.0
	rich = RichTextLabel.new()
	rich.name = "Headline"
	rich.bbcode_enabled = true
	rich.scroll_active = false
	rich.fit_content = false
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.add_theme_font_override("normal_font", UI.DISPLAY)
	rich.add_theme_font_override("bold_font", UI.DISPLAY)
	rich.add_theme_font_size_override("normal_font_size", SPEECH_SIZE)
	rich.add_theme_font_size_override("bold_font_size", SPEECH_SIZE)
	rich.add_theme_constant_override("line_separation", 0)
	banner.add_child(rich)
	_ignore_mouse(banner)
	_backdrop.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_backdrop.draw.connect(_draw_backdrop)
	_wave_layer = Control.new()
	_wave_layer.name = "SoundWave"
	_wave_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.add_child(_wave_layer)
	banner.move_child(_wave_layer, _backdrop.get_index() + 1)
	_wave_layer.draw.connect(_draw_manga_soundwave)
	banner.resized.connect(_on_banner_resized)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_portrait()
	_update_accent()
	_refresh_layout()
	banner.visible = false
	if _pending.size() == 4:
		var queued: Array = _pending
		_pending = []
		_play(int(queued[0]), str(queued[1]), bool(queued[2]), float(queued[3]))


func _process(delta: float) -> void:
	if not soundwave_active and soundwave_energy() < 0.0005:
		return
	if soundwave_active:
		_soundwave_time += delta
	for index: int in range(WAVE_BARS):
		var target: float = _wave_target(index) if soundwave_active else 0.0
		var rate: float = WAVE_ATTACK if target > _wave_bars[index] else WAVE_DECAY
		_wave_bars[index] = lerpf(_wave_bars[index], target, 1.0 - exp(-rate * delta))
	_wave_layer.queue_redraw()


## Layout or accent changed: repaint the static art and the bars. Never called per frame.
func _redraw_all() -> void:
	_backdrop.queue_redraw()
	if _wave_layer != null:
		_wave_layer.queue_redraw()


## Mean bar height, 0 (flat) to 1.
func soundwave_energy() -> float:
	if _wave_bars.is_empty():
		return 0.0
	var total := 0.0
	for height: float in _wave_bars:
		total += height
	return total / float(_wave_bars.size())


## Three sine harmonics per bar, each bar on its own phase: A = base + amplitude * |sin|.
func _wave_target(index: int) -> float:
	var phase := float(index) * 1.7
	var mix := 0.0
	for harmonic: int in range(WAVE_HARMONICS.size()):
		var weight: float = [0.5, 0.3, 0.2][harmonic]
		mix += weight * absf(sin(TAU * WAVE_HARMONICS[harmonic] * _soundwave_time + phase * float(harmonic + 1)))
	return clampf(0.18 + 0.82 * mix * 1.25, 0.0, 1.0)


## Docks the banner to the top of `free_rect` (window pixels), the driver at its left end and
## the engineer at its right end, drawn at `factor` times its authored size.
func set_dock(free_rect: Rect2, factor: float) -> void:
	_docked = true
	_dock_rect = free_rect
	_dock_scale = factor
	if is_node_ready():
		banner.anchor_top = 0.0
		banner.anchor_bottom = 0.0
		_apply_scale()
		_refresh_layout()


## The listener of a two-way exchange dims while the other card speaks (state, not motion).
func set_dimmed(value: bool) -> void:
	dimmed = value
	if not is_node_ready():
		return
	banner.modulate = Color(DIM_TINT, DIM_TINT, DIM_TINT, DIM_ALPHA) if dimmed else Color.WHITE
	_apply_scale()


func set_base_color(color: Color) -> void:
	base_color = color


func _rest_alpha() -> float:
	return DIM_ALPHA if dimmed else 1.0


func _apply_scale() -> void:
	var base: float = _dock_scale if _docked else 1.0
	banner.scale = Vector2.ONE * base * (DIM_SCALE if dimmed else 1.0)


## Torn paper outline fitted to `extent`.
func paper_polygon(extent: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for percent: Vector2 in PAPER_POINTS:
		points.append(percent * 0.01 * extent)
	return points


## The two strips of yellow tape holding the card, before their small tilt.
func tape_rects() -> Array[Rect2]:
	return [Rect2(Vector2(200.0, -10.0), TAPE_SIZE), Rect2(Vector2(_banner_w - 108.0, _banner_h - 16.0), TAPE_SIZE)]


## `hold` is how long the banner stays up (a voiced call holds for its clip); 0 means the default.
func play_radio(car_id: int, message: String, urgent: bool = false, hold: float = 0.0) -> void:
	if not is_node_ready():
		_pending = [car_id, message, urgent, hold]
		return
	_play(car_id, message, urgent, hold)


func set_portrait(texture: Texture2D) -> void:
	_portrait_texture = texture
	if not is_node_ready():
		return
	_apply_portrait()
	_refresh_layout()


func _play(car_id: int, message: String, urgent: bool, hold: float) -> void:
	_message = message
	_urgent = urgent
	_hold = hold if hold > 0.0 else HOLD_SEC
	_accent = T.ACCENT_ANIME_CRIMSON if urgent else base_color
	_speaker.text = "CAR #%02d // %s" % [car_id + 1, role_title]
	if urgent:
		_speaker.text += " // URGENT"
	speech.text = message
	var ink: Color = RadioMarkup.ink_for(_accent)
	rich.add_theme_color_override("default_color", ink)
	_speaker.add_theme_color_override("font_color", ink)
	rich.text = RadioMarkup.highlight(message.to_upper(), _accent, ink)
	_update_accent()
	_refresh_layout()
	_show_banner()
	soundwave_active = true
	transmission_shown.emit(car_id, message)


func _show_banner() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var was_present := _present
	_present = true
	banner.visible = true
	if _docked:
		_fade_in_docked(was_present)
		return
	var hidden_x: float = _hidden_x()
	banner.position.x = _shown_x() if was_present else hidden_x
	_tween = create_tween()
	if not was_present:
		var enter := _tween.tween_property(banner, "position:x", _shown_x(), SLIDE_IN_SEC)
		enter.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(_hold)
	var exit := _tween.tween_property(banner, "position:x", hidden_x, SLIDE_OUT_SEC)
	exit.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_hide_banner)


## Docked: the card slaps in (scale x1.55 and a 9 degree turn settle to the rest pose in SLAP_SEC), holds, then
## fades out over FADE_OUT_SEC. A card that is already up just takes the new text. Reduce motion shows and hides
## the card at its rest pose without moving.
func _fade_in_docked(was_present: bool) -> void:
	_tween = create_tween()
	if was_present or PresentationSettings.reduce_motion:
		_rest_pose()
	else:
		var tilt: float = REST_TILT_DEG[role]
		var start_tilt: float = -SLAP_START_DEG if role == Role.DRIVER else SLAP_START_DEG
		_apply_slap(0.0, start_tilt)
		banner.modulate.a = 0.0
		_tween.set_parallel(true)
		_tween.tween_method(_apply_slap.bind(start_tilt), 0.0, 1.0, SLAP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(banner, "modulate:a", _rest_alpha(), SLAP_SEC * 0.55)
		_tween.set_parallel(false)
	_tween.tween_interval(_hold)
	if not PresentationSettings.reduce_motion:
		_tween.tween_property(banner, "modulate:a", 0.0, FADE_OUT_SEC)
	_tween.tween_callback(_hide_banner)


## The slap pose at progress `t` (1 = rest): scale and turn around the card's centre, which stays where the rest
## pose puts it, so the card lands exactly on its dock position.
func _apply_slap(t: float, start_tilt: float) -> void:
	var rest_scale: float = _dock_scale * (DIM_SCALE if dimmed else 1.0)
	var tilt: float = REST_TILT_DEG[role]
	var half := Vector2(_banner_w, _banner_h) * 0.5
	var rest_centre: Vector2 = _dock_shown() + half.rotated(deg_to_rad(tilt)) * rest_scale
	var scale_now: float = lerpf(rest_scale * SLAP_SCALE, rest_scale, t)
	var turn: float = lerpf(start_tilt, tilt, t)
	banner.scale = Vector2.ONE * scale_now
	banner.rotation_degrees = turn
	banner.position = rest_centre - (half * scale_now).rotated(deg_to_rad(turn))


func _rest_pose() -> void:
	banner.position = _dock_shown()
	banner.rotation_degrees = REST_TILT_DEG[role]
	_apply_scale()
	banner.modulate.a = _rest_alpha()


func is_present() -> bool:
	return _present


## True while an urgent call is on screen: a routine one should not replace it.
func is_urgent() -> bool:
	return _present and _urgent


## Test hook: jumps the entrance animation to the rest pose and keeps the card up.
func _settle() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_rest_pose()


## Top-left of the docked banner in window pixels: the driver at the top-left of the free area, the engineer at
## its right end a little below the middle (leaving room for the sticker that sticks out).
func _dock_shown() -> Vector2:
	var y: float = _dock_rect.position.y + DOCK_MARGIN * _dock_scale
	var x: float = _dock_rect.position.x + DOCK_MARGIN * _dock_scale
	if role == Role.ENGINEER:
		x = _dock_rect.end.x - (DOCK_MARGIN + MIRROR_EDGE_PAD) * _dock_scale - _banner_w * _dock_scale
		y = _dock_rect.position.y + _dock_rect.size.y * ENGINEER_DOCK_Y
	return Vector2(x, y)


## Left edge of the banner on screen, and parked off the nearest side of the window.
func _shown_x() -> float:
	return SLIDE_X if role == Role.DRIVER else get_viewport().get_visible_rect().size.x - SLIDE_X - MIRROR_EDGE_PAD - _banner_w


func _hidden_x() -> float:
	return -1.25 * _banner_w if role == Role.DRIVER else get_viewport().get_visible_rect().size.x + 0.25 * _banner_w


func _hide_banner() -> void:
	banner.visible = false
	_present = false
	soundwave_active = false
	transmission_finished.emit()


func _apply_portrait() -> void:
	var shown := _portrait_texture != null
	_portrait.texture = _portrait_texture
	_portrait_frame.visible = shown
	_portrait.visible = shown


func _update_accent() -> void:
	# The portrait is a die-cut sticker: white edge, hard shadow.
	var box := UI.style(Color("#050505"), Color("#F4F5F7"), Color.BLACK)
	box.set_border_width_all(5)
	box.set_content_margin_all(0)
	box.shadow_offset = Vector2(4, 4)
	_portrait_frame.add_theme_stylebox_override("panel", box)
	_redraw_all()


func _apply_fonts() -> void:
	for node: Label in [_speaker, speech]:
		node.add_theme_font_override("font", _radio_font)
		node.add_theme_color_override("font_color", T.INK_BORDER_BLACK)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker.add_theme_font_size_override("font_size", SPEAKER_SIZE)
	speech.add_theme_font_size_override("font_size", SPEECH_SIZE)
	speech.add_theme_constant_override("line_spacing", 2)
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.clip_text = false


func _make_radio_font() -> FontVariation:
	var font := FontVariation.new()
	font.base_font = UI.RADIO
	font.variation_embolden = 1.0
	font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.22, 1.0), Vector2.ZERO)
	return font


func _refresh_layout() -> void:
	if not is_node_ready():
		return
	var has_portrait := _portrait_texture != null
	_portrait_frame.visible = has_portrait
	_portrait.visible = has_portrait
	var text_x: float = TEXT_NEAR_X if role == Role.DRIVER else TEXT_RIGHT_PAD
	var text_w: float = _banner_w - TEXT_NEAR_X - TEXT_RIGHT_PAD
	_speaker.position = Vector2(text_x, SPEAKER_Y)
	_speaker.size = Vector2(text_w, _radio_font.get_height(SPEAKER_SIZE) + 4.0)
	var line_h: float = UI.DISPLAY.get_height(SPEECH_SIZE)
	speech.position = Vector2(text_x, SPEECH_Y)
	var measured := UI.DISPLAY.get_multiline_string_size(_message.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, text_w, SPEECH_SIZE)
	_wave_x = text_x
	var needed := SPEECH_Y + maxf(measured.y + 6.0, line_h) + 14.0 + WAVE_STRIP
	var viewport_h := get_viewport().get_visible_rect().size.y
	var limit := maxf(viewport_h - TICKER_OFFSET - 24.0, BANNER_MIN_HEIGHT)
	_banner_h = clampf(needed, BANNER_MIN_HEIGHT, limit)
	if _docked:
		banner.offset_left = 0.0
		banner.offset_right = _banner_w
		banner.offset_top = 0.0
		banner.offset_bottom = _banner_h
	else:
		banner.offset_top = -TICKER_OFFSET - _banner_h
		banner.offset_bottom = -TICKER_OFFSET
	speech.size = Vector2(text_w, _banner_h - SPEECH_Y - 12.0)
	rich.position = speech.position
	rich.size = speech.size
	var sticker_x: float = -STICKER_OVERHANG.x if role == Role.DRIVER else _banner_w - PORTRAIT_SIZE + STICKER_OVERHANG.x
	_portrait_frame.position = Vector2(sticker_x, -STICKER_OVERHANG.y)
	_portrait_frame.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait_frame.pivot_offset = _portrait_frame.size * 0.5
	_portrait_frame.rotation_degrees = -STICKER_TILT_DEG if role == Role.DRIVER else STICKER_TILT_DEG
	if not _present:
		if _docked:
			banner.position = _dock_shown() - Vector2(0.0, DOCK_DROP * _dock_scale)
		else:
			banner.position.x = _hidden_x()
	_redraw_all()


## R2 card: a dark sheet turned 2.5 degrees behind, the torn paper in the speaker's colour with halftone and a
## diagonal sheen, and two strips of tape.
func _draw_backdrop() -> void:
	var w := _backdrop.size.x
	var h := _backdrop.size.y
	if w <= 6.0 or h <= 6.0:
		return
	var poly: PackedVector2Array = paper_polygon(Vector2(w, h))
	var centre := Vector2(w, h) * 0.5
	var shifted := PackedVector2Array()
	for point: Vector2 in poly:
		shifted.append(point - centre)
	_backdrop.draw_set_transform(centre + Vector2(10.0, 8.0), deg_to_rad(SHADOW_TILT_DEG), Vector2.ONE)
	_backdrop.draw_colored_polygon(shifted, SHADOW_COLOR)
	_backdrop.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_backdrop.draw_colored_polygon(poly, _accent)
	var uvs := PackedVector2Array()
	for point: Vector2 in poly:
		uvs.append(point / 16.0)
	_backdrop.draw_colored_polygon(poly, Color.WHITE, uvs, _halftone_tile())
	var strip := PackedVector2Array([Vector2(w * 0.40, 0.0), Vector2(w * 0.56, 0.0), Vector2(w * 0.56 - h * 0.3, h), Vector2(w * 0.40 - h * 0.3, h)])
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(poly, strip):
		_backdrop.draw_colored_polygon(piece, Color(1.0, 1.0, 1.0, 0.22))
	var tilts: Array[float] = [-4.0, 5.0]
	var tapes: Array[Rect2] = tape_rects()
	for index: int in range(tapes.size()):
		_backdrop.draw_set_transform(tapes[index].get_center(), deg_to_rad(tilts[index]), Vector2.ONE)
		_backdrop.draw_rect(Rect2(-TAPE_SIZE * 0.5 + Vector2(0.0, 2.0), TAPE_SIZE), Color(0.0, 0.0, 0.0, 0.4))
		_backdrop.draw_rect(Rect2(-TAPE_SIZE * 0.5, TAPE_SIZE), TAPE_COLOR)
	_backdrop.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Equalizer teeth on a strip along the bottom edge, under the headline: ink triangles that rise and fall with
## the voice, and a 2 px ink baseline that they fall back to when idle.
func _draw_manga_soundwave() -> void:
	var ink: Color = RadioMarkup.ink_for(_accent)
	var h := _wave_layer.size.y
	var base_y := h - 14.0
	var step := WAVE_BAR_W + WAVE_GAP
	var span := step * float(WAVE_BARS) - WAVE_GAP
	_wave_layer.draw_rect(Rect2(_wave_x, base_y - 2.0, span, 2.0), ink)
	for index: int in range(WAVE_BARS):
		var height: float = 2.0 + _wave_bars[index] * (WAVE_MAX_H - 2.0)
		if height <= 2.5:
			continue
		var x := _wave_x + float(index) * step
		_wave_layer.draw_colored_polygon(PackedVector2Array([
			Vector2(x, base_y), Vector2(x + WAVE_BAR_W * 0.5, base_y - height), Vector2(x + WAVE_BAR_W, base_y)]), ink)


static func _halftone_tile() -> Texture2D:
	if halftone_tile != null:
		return halftone_tile
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var ink := Color(T.INK_BORDER_BLACK, 0.16)
	for dot: Vector2i in [Vector2i(0, 6), Vector2i(8, 6), Vector2i(4, 14), Vector2i(12, 14)]:
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				image.set_pixel(posmod(dot.x + dx, 16), posmod(dot.y + dy, 16), ink)
	halftone_tile = ImageTexture.create_from_image(image)
	return halftone_tile


func _on_banner_resized() -> void:
	_redraw_all()


func _on_viewport_resized() -> void:
	if is_node_ready():
		_refresh_layout()


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)
