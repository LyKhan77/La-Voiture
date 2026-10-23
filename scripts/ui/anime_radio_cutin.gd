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

const BANNER_WIDTH := 460.0
const BANNER_MIN_HEIGHT := 150.0
const TICKER_OFFSET := 84.0
const SLIDE_X := 32.0
const SLIDE_IN_SEC := 0.22
const HOLD_SEC := 3.5
const SLIDE_OUT_SEC := 0.18
const PORTRAIT_SIZE := 104.0
const PORTRAIT_X := 18.0
const SPEAKER_SIZE := 15
const SPEECH_SIZE := 22
const SPEAKER_Y := 12.0
const SPEECH_Y := 38.0
const TEXT_RIGHT_PAD := 30.0
const SKEW_DEG := 10.0
## The mirrored banner leans toward the window edge; keep that corner on screen.
const MIRROR_EDGE_PAD := 30.0
## Docked placement: margin to the free area edge, and how far the banner drops while fading in.
const DOCK_MARGIN := 28.0
const DOCK_DROP := 36.0
## Manga soundwave equalizer: bar count and size, harmonics (Hz) and how fast the bars chase
## their target while talking and fall back to the baseline when idle.
const WAVE_BARS := 14
const WAVE_BAR_W := 7.0
const WAVE_GAP := 3.0
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
var _message := ""
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
	_portrait.offset_left = 4.0
	_portrait.offset_top = 4.0
	_portrait.offset_right = -4.0
	_portrait.offset_bottom = -4.0
	_accent = T.ACCENT_ACID_LIME if role == Role.DRIVER else T.ACCENT_ELECTRIC_CYAN
	_radio_font = _make_radio_font()
	_wave_bars.resize(WAVE_BARS)
	_apply_fonts()
	_ignore_mouse(banner)
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
		banner.scale = Vector2(factor, factor)
		_refresh_layout()


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
	_hold = hold if hold > 0.0 else HOLD_SEC
	_accent = T.ACCENT_ANIME_CRIMSON if urgent else (T.ACCENT_ACID_LIME if role == Role.DRIVER else T.ACCENT_ELECTRIC_CYAN)
	_speaker.text = "CAR #%02d // %s" % [car_id + 1, role_title]
	if urgent:
		_speaker.text += " // URGENT"
	speech.text = message
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


## Docked: fade down from DOCK_DROP above the resting spot, hold, then fade back up.
func _fade_in_docked(was_present: bool) -> void:
	var shown: Vector2 = _dock_shown()
	var hidden: Vector2 = shown - Vector2(0.0, DOCK_DROP * _dock_scale)
	banner.position = shown if was_present else hidden
	banner.modulate.a = 1.0 if was_present else 0.0
	_tween = create_tween()
	if not was_present:
		_tween.tween_property(banner, "position:y", shown.y, SLIDE_IN_SEC).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(banner, "modulate:a", 1.0, SLIDE_IN_SEC)
	_tween.tween_interval(_hold)
	_tween.tween_property(banner, "position:y", hidden.y, SLIDE_OUT_SEC).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(banner, "modulate:a", 0.0, SLIDE_OUT_SEC)
	_tween.tween_callback(_hide_banner)


## Top-left of the docked banner in window pixels: driver at the left end of the free area,
## engineer at the right end (leaving room for the mirrored lean).
func _dock_shown() -> Vector2:
	var y: float = _dock_rect.position.y + DOCK_MARGIN * _dock_scale
	var x: float = _dock_rect.position.x + DOCK_MARGIN * _dock_scale
	if role == Role.ENGINEER:
		x = _dock_rect.end.x - (DOCK_MARGIN + MIRROR_EDGE_PAD) * _dock_scale - _banner_w * _dock_scale
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
	var box := UI.style(T.INK_BORDER_BLACK, _accent, Color.BLACK)
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
	var text_x := (PORTRAIT_X + PORTRAIT_SIZE + 20.0) if has_portrait else 22.0
	var text_w := _banner_w - text_x - TEXT_RIGHT_PAD
	if role == Role.ENGINEER:
		# Mirrored: the portrait sits at the right end, the text starts at the left.
		text_x = 34.0
		text_w = _banner_w - text_x - ((PORTRAIT_X + PORTRAIT_SIZE + 20.0) if has_portrait else TEXT_RIGHT_PAD)
	_speaker.position = Vector2(text_x, SPEAKER_Y)
	_speaker.size = Vector2(text_w, _radio_font.get_height(SPEAKER_SIZE) + 4.0)
	speech.position = Vector2(text_x, SPEECH_Y)
	speech.size = Vector2(text_w, _radio_font.get_height(SPEECH_SIZE))
	var measured := _radio_font.get_multiline_string_size(
		_message, HORIZONTAL_ALIGNMENT_LEFT, text_w, SPEECH_SIZE)
	_wave_x = text_x
	var needed := SPEECH_Y + maxf(measured.y + 6.0, _radio_font.get_height(SPEECH_SIZE)) + 14.0 + WAVE_STRIP
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
	var portrait_x: float = PORTRAIT_X if role == Role.DRIVER else _banner_w - PORTRAIT_X - PORTRAIT_SIZE
	_portrait_frame.position = Vector2(portrait_x, (_banner_h - PORTRAIT_SIZE) * 0.5)
	_portrait_frame.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	if not _present:
		if _docked:
			banner.position = _dock_shown() - Vector2(0.0, DOCK_DROP * _dock_scale)
		else:
			banner.position.x = _hidden_x()
	_redraw_all()


func _draw_backdrop() -> void:
	var w := _backdrop.size.x
	var h := _backdrop.size.y
	if w <= 6.0 or h <= 6.0:
		return
	var slant := tan(deg_to_rad(SKEW_DEG)) * (1.0 if role == Role.DRIVER else -1.0)
	var skew := Transform2D(Vector2(1.0, 0.0), Vector2(-slant, 1.0), Vector2.ZERO)
	_backdrop.draw_set_transform_matrix(
		Transform2D(Vector2(1.0, 0.0), Vector2(-slant, 1.0), Vector2(8.0, 8.0)))
	_backdrop.draw_rect(Rect2(0.0, 0.0, w, h), Color.BLACK)
	_backdrop.draw_set_transform_matrix(skew)
	_backdrop.draw_rect(Rect2(-2.0, -2.0, w + 4.0, h + 4.0), _accent)
	_backdrop.draw_rect(Rect2(0.0, 0.0, w, h), T.INK_BORDER_BLACK)
	_backdrop.draw_rect(Rect2(3.0, 3.0, w - 6.0, h - 6.0), _accent)
	_draw_halftone(w, h)
	_draw_speed_lines(w, h)


## Equalizer bars on a strip along the bottom edge, under the speech: ink outline, paper fill,
## an ink cap on each peak, and a 2 px ink baseline that the bars fall back to when idle.
func _draw_manga_soundwave() -> void:
	var h := _wave_layer.size.y
	var base_y := h - 14.0
	var step := WAVE_BAR_W + WAVE_GAP
	var span := step * float(WAVE_BARS) - WAVE_GAP
	_wave_layer.draw_rect(Rect2(_wave_x, base_y - 2.0, span, 2.0), T.INK_BORDER_BLACK)
	for index: int in range(WAVE_BARS):
		var height: float = 2.0 + _wave_bars[index] * (WAVE_MAX_H - 2.0)
		if height <= 2.5:
			continue
		var x := _wave_x + float(index) * step
		var top := base_y - height
		_wave_layer.draw_rect(Rect2(x, top, WAVE_BAR_W, height), T.INK_BORDER_BLACK)
		_wave_layer.draw_rect(Rect2(x + 2.0, top + 3.0, WAVE_BAR_W - 4.0, maxf(height - 3.0, 0.0)), Color("#F4F5F7"))
		_wave_layer.draw_rect(Rect2(x - 1.0, top - 2.0, WAVE_BAR_W + 2.0, 3.0), T.INK_BORDER_BLACK)


## Staggered ink dots, painted as one tiled texture (the 16x16 tile below) rather than a circle per dot:
## a thousand draw_circle polygons repainted every frame cost 30+ ms while the radio was speaking.
func _draw_halftone(w: float, h: float) -> void:
	_backdrop.draw_texture_rect(_halftone_tile(), Rect2(8.0, 6.0, w - 16.0, h - 12.0), true)


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


func _draw_speed_lines(w: float, h: float) -> void:
	var ink := Color(T.INK_BORDER_BLACK, 0.22)
	for i: int in range(7):
		if role == Role.DRIVER:
			var x := 10.0 + float(i) * 14.0
			_backdrop.draw_line(Vector2(x, 6.0), Vector2(x + 34.0, h - 6.0), ink, 3.0)
		else:
			var x := w - 10.0 - float(i) * 14.0
			_backdrop.draw_line(Vector2(x, 6.0), Vector2(x - 34.0, h - 6.0), ink, 3.0)


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
