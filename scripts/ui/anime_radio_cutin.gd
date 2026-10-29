extends CanvasLayer

## Comic radio cut-in (Layer 3 / Z:30): a manga speech balloon with a jagged ink outline (the convention for an
## electronic voice), a die-cut round portrait ringed by concentration lines, a static SFX in the corner and an
## equaliser of ink teeth. Compact (about 258 x 92) so two of them fit the lower corners of the free area.
## Decorative and input-transparent: every node is MOUSE_FILTER_IGNORE.
## The ENGINEER role is the same balloon mirrored to the right edge, in cyan, so the driver
## and the pit wall can be on screen at the same time (set role before adding to the tree).
## Default placement is the bottom strip of the window (pit wall dashboard). set_dock() instead
## parks the balloon in the bottom corner of a free area, at the HUD scale, and pops it in.

enum Role { DRIVER, ENGINEER }

signal transmission_shown(car_id: int, message: String)
## The banner has left the screen: the message is over.
signal transmission_finished

const T = preload("res://scripts/ui/ui_theme_tokens.gd")
const UI = preload("res://scripts/ui/pit_wall_ui.gd")

const BANNER_WIDTH := 258.0
const BANNER_MIN_HEIGHT := 92.0
const TICKER_OFFSET := 84.0
const SLIDE_X := 32.0
const SLIDE_IN_SEC := 0.22
const HOLD_SEC := 3.5
## What `prewarm` lays the card out with, and how many frames it lets the hidden card draw.
const PREWARM_TEXT := "ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 !?:;.,'#%/-() THE ENGINEER SAYS CHECK THE TELEMETRY"
const PREWARM_FRAMES: int = 2
const SLIDE_OUT_SEC := 0.18
const PORTRAIT_SIZE := 62.0
const PORTRAIT_RING := 4.0
## The balloon: width, top inside the banner, minimum height, jagged outline (tooth pitch and depth) and the hard
## ink shadow offset. The portrait overlaps its near end.
const BALLOON_W := 218.0
const BALLOON_TOP := 8.0
const BALLOON_MIN_H := 80.0
const TOOTH_STEP := 12.0
const TOOTH_DEPTH := 4.0
const INK_INSET := 4.0
const SHADOW_OFFSET := Vector2(4.0, 5.0)
## Text: padding on the portrait side and on the far side, rows inside the balloon, size and line count.
const TEXT_NEAR := 36.0 # clears the portrait overlap and the lightning tail
const TEXT_FAR := 14.0
const SPEAKER_Y := 7.0
const SPEECH_Y := 22.0
const SPEAKER_SIZE := 11
const SPEECH_SIZE := 16
const LINE_TIGHTEN := 2.0
const MAX_LINES := 3
const WAVE_STRIP := 24.0
## Papers: off-white for a routine call, a pink for an urgent one (the accent turns crimson).
const PAPER_COLORS: Array[Color] = [Color("#FFFDF4"), Color("#F2FDFF")]
const URGENT_PAPER := Color("#FFE3EA")
const INK := Color("#050505")
## Concentration lines ring the portrait, between these radii, and flicker between two phases.
const RAY_COUNT := 40
const RAY_WIDTH_DEG := 3.0
const RAY_INNER := 33.0
const RAY_OUTER := 47.0
const RAY_ALT_DEG := 4.5
const RAY_DARKEN := 0.45
## The outline shivers "on twos": 12 poses a second from this cycle, at most 2 px.
const JITTER_HZ := 12.0
const JITTER: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(1.5, -1.0), Vector2(-1.0, 1.5), Vector2(1.0, 1.0)]
## The lightning tail between portrait and balloon, in a 34 x 40 box, drawn for the driver (mirrored for the engineer).
const TAIL_POINTS: Array[Vector2] = [
	Vector2(2, 20), Vector2(14, 12), Vector2(12, 19), Vector2(24, 11), Vector2(21, 20), Vector2(32, 18), Vector2(22, 24), Vector2(24, 30), Vector2(12, 26), Vector2(14, 33),
]
const TAIL_WIDTH := 34.0
const TAIL_TOP := 14.0
const SFX_ROUTINE := "ザザッ"
const SFX_URGENT := "ガガッ!"
const SFX_SIZE := 17
const SFX_TILT_DEG := 6.0
const SFX_OUTLINE := 6
## Entry pop: scale and turn settle to rest in SLAP_SEC around the bottom centre; the listener of a two-way exchange dims.
const REST_TILT_DEG: Array[float] = [0.0, 0.0]
const DIM_ALPHA := 0.6
const DIM_TINT := 0.75
const DIM_SCALE := 0.95
const SLAP_SEC := 0.4
const SLAP_SCALE := 1.4
const SLAP_START_DEG := 6.0
const FADE_OUT_SEC := 1.4
## The mirrored banner keeps this much off the window edge when it is not docked.
const MIRROR_EDGE_PAD := 8.0
## Docked placement: margin to the free area's left edge (driver) and its bottom edge.
const DOCK_MARGIN_X := 8.0
const DOCK_MARGIN_BOTTOM := 10.0
const DOCK_DROP := 24.0
## Equaliser: eight ink teeth at the balloon's lower right, their size, the harmonics (Hz) that drive them and
## how fast they chase their target while talking and fall back when idle.
const WAVE_BARS := 8
const WAVE_BAR_W := 5.0
const WAVE_GAP := 2.0
const WAVE_MAX_H := 14.0
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
## Accent of a routine call; urgent calls are crimson.
var base_color: Color = T.ACCENT_ACID_LIME
## The listener of a two-way exchange: dimmed and a little smaller while the other balloon speaks.
var dimmed: bool = false
## The headline: capitalised, keywords as accent blocks. `speech` keeps the plain text.
var rich: RichTextLabel
## True while an urgent call is up: the portrait sweats and the SFX shouts.
var sweating: bool = false
var _sfx: Label
var _message := ""
var _prewarm_frames: int = 0
var _prewarm_kept: Array = []
var _urgent := false
var _balloon_h := BALLOON_MIN_H
var _banner_h := BANNER_MIN_HEIGHT
var _banner_w := BANNER_WIDTH
var _present := false
var _hold := HOLD_SEC # how long the banner stays up for the message on screen
var _tween: Tween
## Progress of the pop-in (0 -> 1) and of the fade-out (1 -> 0); alpha is this times the rest alpha.
var _fade := 1.0
## The concentration lines, the equaliser teeth and the portrait's emotion marks: layers of their own, so only
## these few shapes repaint while the radio speaks.
var _lines_layer: Control
var _wave_layer: Control
var _emotion_layer: Control
static var halftone_tile: Texture2D # shared by the driver and engineer banners, built on first use
var _pending: Array = []
var _docked := false
var _dock_rect := Rect2()
var _dock_scale := 1.0

## True while a transmission is on screen: the soundwave bars pulse.
var soundwave_active: bool = false
var _soundwave_time: float = 0.0
var _wave_bars := PackedFloat32Array() # 0..1 height per bar
var _jitter_clock := 0.0
var _jitter_step := 0
var _ray_phase := 0


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
	_portrait.offset_left = PORTRAIT_RING
	_portrait.offset_top = PORTRAIT_RING
	_portrait.offset_right = -PORTRAIT_RING
	_portrait.offset_bottom = -PORTRAIT_RING
	_portrait_frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW # the portrait is a disc
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
	rich.add_theme_font_override("normal_font", UI.HEADER)
	rich.add_theme_font_override("bold_font", UI.DISPLAY)
	rich.add_theme_font_size_override("normal_font_size", SPEECH_SIZE)
	rich.add_theme_font_size_override("bold_font_size", SPEECH_SIZE)
	rich.add_theme_constant_override("line_separation", -int(LINE_TIGHTEN))
	banner.add_child(rich)
	_sfx = Label.new()
	_sfx.name = "Sfx"
	_sfx.add_theme_font_override("font", UI.DISPLAY)
	_sfx.add_theme_font_size_override("font_size", SFX_SIZE)
	_sfx.add_theme_constant_override("outline_size", SFX_OUTLINE)
	_sfx.add_theme_color_override("font_outline_color", INK)
	banner.add_child(_sfx)
	_lines_layer = _make_layer("ConcentrationLines", _draw_concentration_lines)
	_wave_layer = _make_layer("SoundWave", _draw_manga_soundwave)
	_emotion_layer = _make_layer("Emotion", _draw_emotion)
	_ignore_mouse(banner)
	_backdrop.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_backdrop.draw.connect(_draw_backdrop)
	# Back to front: lines, balloon, teeth, portrait, its emotion marks, then the type and the SFX.
	banner.move_child(_lines_layer, 0)
	banner.move_child(_backdrop, 1)
	banner.move_child(_wave_layer, 2)
	banner.move_child(_portrait_frame, 3)
	banner.move_child(_emotion_layer, 4)
	banner.move_child(_speaker, 5)
	banner.move_child(speech, 6)
	banner.move_child(rich, 7)
	banner.move_child(_sfx, 8)
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


func _make_layer(layer_name: String, painter: Callable) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.add_child(layer)
	layer.draw.connect(painter)
	return layer


func _process(delta: float) -> void:
	_update_jitter(delta)
	if not soundwave_active and soundwave_energy() < 0.0005:
		return
	if soundwave_active:
		_soundwave_time += delta
	for index: int in range(WAVE_BARS):
		var target: float = _wave_target(index) if soundwave_active else 0.0
		var rate: float = WAVE_ATTACK if target > _wave_bars[index] else WAVE_DECAY
		_wave_bars[index] = lerpf(_wave_bars[index], target, 1.0 - exp(-rate * delta))
	_wave_layer.queue_redraw()


## While the voice is on the air the outline shivers and the concentration lines flicker, a new pose twelve times a
## second (animation on twos); at rest, or with reduce motion, everything is still.
func _update_jitter(delta: float) -> void:
	if soundwave_active and not PresentationSettings.reduce_motion:
		_jitter_clock += delta
		var step: int = int(_jitter_clock * JITTER_HZ)
		if step != _jitter_step:
			_jitter_step = step
			_backdrop.position = jitter_for(step)
			_ray_phase = step % 2
			_lines_layer.queue_redraw()
	elif _backdrop.position != Vector2.ZERO or _ray_phase != 0:
		_backdrop.position = Vector2.ZERO
		_ray_phase = 0
		_lines_layer.queue_redraw()


## Outline offset of pose `step`; always zero under reduce motion.
func jitter_for(step: int) -> Vector2:
	if PresentationSettings.reduce_motion:
		return Vector2.ZERO
	return JITTER[posmod(step, JITTER.size())]


## Layout or accent changed: repaint the static art and the bars. Never called per frame.
func _redraw_all() -> void:
	_backdrop.queue_redraw()
	if _wave_layer != null:
		_wave_layer.queue_redraw()
		_lines_layer.queue_redraw()
		_emotion_layer.queue_redraw()


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


## Docks the banner into the bottom corner of `free_rect` (window pixels), the driver at its left end and
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
		if _present:
			_place_rest() # a balloon that is up follows a window resize at once; its fade keeps running


## The listener of a two-way exchange dims while the other balloon speaks (state, not motion). Safe while this
## balloon is popping in or fading out: the tint changes now, the alpha follows the animation's own progress.
func set_dimmed(value: bool) -> void:
	dimmed = value
	if not is_node_ready():
		return
	_apply_alpha()
	_apply_scale()


func set_base_color(color: Color) -> void:
	base_color = color


func _rest_alpha() -> float:
	return DIM_ALPHA if dimmed else 1.0


## Alpha = how far the pop / fade has got (`_fade`, 0..1) times the rest alpha of this balloon; the tint is the dim.
func _apply_alpha() -> void:
	var tint: float = DIM_TINT if dimmed else 1.0
	banner.modulate = Color(tint, tint, tint, _fade * _rest_alpha())


func _set_fade(value: float) -> void:
	_fade = value
	_apply_alpha()


func _apply_scale() -> void:
	var base: float = _dock_scale if _docked else 1.0
	banner.scale = Vector2.ONE * base * (DIM_SCALE if dimmed else 1.0)


## Jagged ink outline of a balloon of `extent`, `inset` px in from its edge: the rectangle's edges pushed in by
## TOOTH_DEPTH on every other point. The same count for every inset, so the paper (inset INK_INSET) nests in the ink.
func balloon_polygon(extent: Vector2, inset: float) -> PackedVector2Array:
	var rect := Rect2(Vector2(inset, inset), extent - Vector2(inset, inset) * 2.0)
	var across: int = maxi(2, roundi(extent.x / TOOTH_STEP))
	var down: int = maxi(2, roundi(extent.y / TOOTH_STEP))
	var depth: float = TOOTH_DEPTH - inset * 0.25
	var points := PackedVector2Array()
	for index: int in range(across + 1):
		points.append(Vector2(rect.position.x + rect.size.x * float(index) / float(across), rect.position.y + (depth if index % 2 == 1 else 0.0)))
	for index: int in range(1, down + 1):
		points.append(Vector2(rect.end.x - (depth if index % 2 == 1 else 0.0), rect.position.y + rect.size.y * float(index) / float(down)))
	for index: int in range(across - 1, -1, -1):
		points.append(Vector2(rect.position.x + rect.size.x * float(index) / float(across), rect.end.y - (depth if index % 2 == 1 else 0.0)))
	for index: int in range(down - 1, 0, -1):
		points.append(Vector2(rect.position.x + (depth if index % 2 == 1 else 0.0), rect.position.y + rect.size.y * float(index) / float(down)))
	return points


## Paper colour of the balloon.
func paper_color() -> Color:
	return URGENT_PAPER if _urgent else PAPER_COLORS[role]


## The static SFX in the corner of the balloon.
func sfx_text() -> String:
	return SFX_URGENT if _urgent else SFX_ROUTINE


## `hold` is how long the banner stays up (a voiced call holds for its clip); 0 means the default.
func play_radio(car_id: int, message: String, urgent: bool = false, hold: float = 0.0) -> void:
	if not is_node_ready():
		_pending = [car_id, message, urgent, hold]
		return
	_play(car_id, message, urgent, hold)


## Lays the card out once with a full alphabet and lets it draw offscreen for a couple of frames, then puts it back.
## Without it the first real call of a race stalls for 13-48 ms shaping the font's glyphs and building the first draw
## lists, a hitch right after the lights go out. A real call that arrives meanwhile owns the card and is left alone.
func prewarm() -> void:
	if not is_node_ready():
		if not ready.is_connected(prewarm): # built before its parent is in the tree: warm up once it is
			ready.connect(prewarm, CONNECT_ONE_SHOT)
		return
	if _present or _prewarm_frames > 0:
		return
	_prewarm_kept = [_message, _speaker.text, _sfx.text]
	_message = PREWARM_TEXT
	_speaker.text = PREWARM_TEXT.left(30)
	_sfx.text = SFX_URGENT + " " + SFX_ROUTINE
	# The first colour override on a label builds its font's theme cache (about 11 ms for the SFX label), so the
	# calls `_play` makes are made here once too.
	_speaker.add_theme_color_override("font_color", INK)
	rich.add_theme_color_override("default_color", INK)
	_sfx.add_theme_color_override("font_color", _accent)
	_refresh_layout() # a card that is not present sits offscreen
	banner.visible = true
	_prewarm_frames = PREWARM_FRAMES
	get_tree().process_frame.connect(_on_prewarm_frame, CONNECT_ONE_SHOT)


func _on_prewarm_frame() -> void:
	_prewarm_frames -= 1
	if _prewarm_frames > 0:
		get_tree().process_frame.connect(_on_prewarm_frame, CONNECT_ONE_SHOT)
		return
	if _present:
		return
	_message = String(_prewarm_kept[0])
	_speaker.text = String(_prewarm_kept[1])
	_sfx.text = String(_prewarm_kept[2])
	banner.visible = false
	_refresh_layout()


func set_portrait(texture: Texture2D) -> void:
	_portrait_texture = texture
	if not is_node_ready():
		return
	_apply_portrait()
	_refresh_layout()


func _play(car_id: int, message: String, urgent: bool, hold: float) -> void:
	_message = message
	_urgent = urgent
	sweating = urgent
	_hold = hold if hold > 0.0 else HOLD_SEC
	_accent = T.ACCENT_ANIME_CRIMSON if urgent else base_color
	_speaker.text = "CAR #%02d // %s" % [car_id + 1, role_title]
	if urgent:
		_speaker.text += " // URGENT"
	speech.text = message
	_speaker.add_theme_color_override("font_color", INK)
	rich.add_theme_color_override("default_color", INK)
	_sfx.text = sfx_text()
	_sfx.add_theme_color_override("font_color", _accent)
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


## Docked: the balloon pops in (scale x1.4 and a 6 degree turn settle to the rest pose in SLAP_SEC), holds, then
## fades out over FADE_OUT_SEC. A balloon that is already up just takes the new text. Reduce motion shows and hides
## it at its rest pose without moving.
func _fade_in_docked(was_present: bool) -> void:
	_tween = create_tween()
	if was_present or PresentationSettings.reduce_motion:
		_rest_pose()
	else:
		var start_tilt: float = -SLAP_START_DEG if role == Role.DRIVER else SLAP_START_DEG
		_apply_slap(0.0, start_tilt)
		_set_fade(0.0)
		_tween.set_parallel(true)
		_tween.tween_method(_apply_slap.bind(start_tilt), 0.0, 1.0, SLAP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_method(_set_fade, 0.0, 1.0, SLAP_SEC * 0.55)
		_tween.set_parallel(false)
	_tween.tween_interval(_hold)
	if not PresentationSettings.reduce_motion:
		_tween.tween_method(_set_fade, 1.0, 0.0, FADE_OUT_SEC)
	_tween.tween_callback(_hide_banner)


## The pop pose at progress `t` (1 = rest): scale and turn around the balloon's bottom centre, which stays where the
## rest pose puts it, so the balloon grows upward and lands exactly on its dock position.
func _apply_slap(t: float, start_tilt: float) -> void:
	var rest_scale: float = _dock_scale * (DIM_SCALE if dimmed else 1.0)
	var tilt: float = REST_TILT_DEG[role]
	var anchor_local := Vector2(_banner_w * 0.5, _banner_h)
	var rest_anchor: Vector2 = _dock_shown() + anchor_local.rotated(deg_to_rad(tilt)) * rest_scale
	var scale_now: float = lerpf(rest_scale * SLAP_SCALE, rest_scale, t)
	var turn: float = lerpf(start_tilt, tilt, t)
	banner.scale = Vector2.ONE * scale_now
	banner.rotation_degrees = turn
	banner.position = rest_anchor - (anchor_local * scale_now).rotated(deg_to_rad(turn))


func _rest_pose() -> void:
	_place_rest()
	_set_fade(1.0)


## Position, turn and scale of the docked rest pose (the alpha is the fade's business).
func _place_rest() -> void:
	banner.position = _dock_shown()
	banner.rotation_degrees = REST_TILT_DEG[role]
	_apply_scale()


func is_present() -> bool:
	return _present


## True while an urgent call is on screen: a routine one should not replace it.
func is_urgent() -> bool:
	return _present and _urgent


## Test hook: jumps the entrance animation to the rest pose and keeps the balloon up.
func _settle() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_rest_pose()


## Top-left of the docked banner in window pixels: the driver in the bottom-left corner of the free area, the
## engineer on the same baseline at its right end; both sit above the deck and either side of the card.
func _dock_shown() -> Vector2:
	var y: float = _dock_rect.end.y - (DOCK_MARGIN_BOTTOM + _banner_h) * _dock_scale
	var x: float = _dock_rect.position.x + DOCK_MARGIN_X * _dock_scale
	if role == Role.ENGINEER:
		x = _dock_rect.end.x - _banner_w * _dock_scale
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
	# The portrait is a disc with a thick ink ring.
	var box := StyleBoxFlat.new()
	box.bg_color = _accent
	box.border_color = INK
	box.set_border_width_all(int(PORTRAIT_RING))
	box.set_corner_radius_all(int(PORTRAIT_SIZE * 0.5))
	box.set_content_margin_all(0)
	_portrait_frame.add_theme_stylebox_override("panel", box)
	if _sfx != null:
		_sfx.add_theme_color_override("font_color", _accent)
	_redraw_all()


func _apply_fonts() -> void:
	for node: Label in [_speaker, speech]:
		node.add_theme_font_override("font", _radio_font)
		node.add_theme_color_override("font_color", INK)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker.add_theme_font_size_override("font_size", SPEAKER_SIZE)
	speech.add_theme_font_size_override("font_size", SPEECH_SIZE)
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.clip_text = false


func _make_radio_font() -> FontVariation:
	var font := FontVariation.new()
	font.base_font = UI.DISPLAY
	font.spacing_glyph = 1
	return font


func _line_height() -> float:
	return UI.HEADER.get_height(SPEECH_SIZE) - LINE_TIGHTEN


func _count_lines(text: String, width: float) -> int:
	var measured: Vector2 = UI.HEADER.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, SPEECH_SIZE)
	return maxi(1, roundi(measured.y / UI.HEADER.get_height(SPEECH_SIZE)))


## The call as shown: at most MAX_LINES lines, cut at a word with an ellipsis (`speech.text` keeps the whole call).
## A little width is held back for the keyword blocks, which are set in the wider display face.
func _fit_message(text: String, width: float) -> String:
	var words: PackedStringArray = text.split(" ")
	var candidate: String = text
	while _count_lines(candidate, width - 8.0) > MAX_LINES and words.size() > 1:
		words.remove_at(words.size() - 1)
		candidate = " ".join(words) + "…"
	return candidate


func _balloon_x() -> float:
	return _banner_w - BALLOON_W if role == Role.DRIVER else 0.0


func _text_x() -> float:
	return _balloon_x() + (TEXT_NEAR if role == Role.DRIVER else TEXT_FAR)


func _portrait_x() -> float:
	return 0.0 if role == Role.DRIVER else _banner_w - PORTRAIT_SIZE


func _portrait_centre() -> Vector2:
	return Vector2(_portrait_x() + PORTRAIT_SIZE * 0.5, BALLOON_TOP + 2.0 + PORTRAIT_SIZE * 0.5)


func _refresh_layout() -> void:
	if not is_node_ready():
		return
	var has_portrait := _portrait_texture != null
	_portrait_frame.visible = has_portrait
	_portrait.visible = has_portrait
	var text_w: float = BALLOON_W - TEXT_NEAR - TEXT_FAR
	var shown: String = _fit_message(_message.to_upper(), text_w)
	var lines: int = _count_lines(shown, text_w - 8.0)
	_balloon_h = maxf(BALLOON_MIN_H, SPEECH_Y + float(lines) * _line_height() + WAVE_STRIP)
	_banner_h = maxf(BANNER_MIN_HEIGHT, BALLOON_TOP + _balloon_h + 4.0)
	rich.text = RadioMarkup.highlight(shown, INK, _accent, true)
	var text_x: float = _text_x()
	_speaker.position = Vector2(text_x + 12.0, BALLOON_TOP + SPEAKER_Y - 2.0)
	_speaker.size = Vector2(text_w - 12.0, _radio_font.get_height(SPEAKER_SIZE) + 4.0)
	speech.position = Vector2(text_x, BALLOON_TOP + SPEECH_Y)
	speech.size = Vector2(text_w, float(lines) * _line_height() + 4.0)
	rich.position = speech.position
	rich.size = speech.size
	if _docked:
		banner.offset_left = 0.0
		banner.offset_right = _banner_w
		banner.offset_top = 0.0
		banner.offset_bottom = _banner_h
	else:
		banner.offset_top = -TICKER_OFFSET - _banner_h
		banner.offset_bottom = -TICKER_OFFSET
	_portrait_frame.position = Vector2(_portrait_x(), BALLOON_TOP + 2.0)
	_portrait_frame.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_sfx.size = Vector2(80.0, 24.0)
	_sfx.pivot_offset = _sfx.size * 0.5
	var near_end: float = _balloon_x() + BALLOON_W - 6.0 - 52.0 if role == Role.DRIVER else _balloon_x() + 6.0
	_sfx.position = Vector2(near_end, BALLOON_TOP - 20.0)
	_sfx.rotation_degrees = SFX_TILT_DEG if role == Role.DRIVER else -SFX_TILT_DEG
	if not _present:
		if _docked:
			banner.position = _dock_shown() + Vector2(0.0, DOCK_DROP * _dock_scale)
		else:
			banner.position.x = _hidden_x()
	_redraw_all()


## The balloon: a hard ink shadow, the jagged ink outline, flat paper inset into it, a hard-edged screentone on the
## shadow side, the lightning tail toward the portrait and a recording dot at the head of the speaker line.
func _draw_backdrop() -> void:
	var extent := Vector2(BALLOON_W, _balloon_h)
	var origin := Vector2(_balloon_x(), BALLOON_TOP)
	var outer: PackedVector2Array = _offset_polygon(balloon_polygon(extent, 0.0), origin)
	var inner: PackedVector2Array = _offset_polygon(balloon_polygon(extent, INK_INSET), origin)
	_backdrop.draw_colored_polygon(_offset_polygon(outer, SHADOW_OFFSET), INK)
	_backdrop.draw_colored_polygon(outer, INK)
	_backdrop.draw_colored_polygon(inner, paper_color())
	var tone_corner: float = 1.0 if role == Role.DRIVER else 0.0
	var tone := PackedVector2Array([
		origin + Vector2(extent.x * lerpf(0.65, 0.35, tone_corner), extent.y), origin + Vector2(extent.x * tone_corner, extent.y * 0.30),
		origin + Vector2(extent.x * tone_corner, extent.y), ])
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(inner, tone):
		var uvs := PackedVector2Array()
		for point: Vector2 in piece:
			uvs.append(point / 16.0)
		_backdrop.draw_colored_polygon(piece, Color.WHITE, uvs, _halftone_tile())
	_draw_tail()
	var dot := Vector2(_text_x() + 4.0, origin.y + SPEAKER_Y + 5.0)
	_backdrop.draw_circle(dot, 5.0, INK)
	_backdrop.draw_circle(dot, 3.0, _accent)


func _draw_tail() -> void:
	var driver: bool = role == Role.DRIVER
	var x0: float = _balloon_x() if driver else _balloon_x() + BALLOON_W - TAIL_WIDTH
	var points := PackedVector2Array()
	for point: Vector2 in TAIL_POINTS:
		var local_x: float = point.x if driver else TAIL_WIDTH - point.x
		points.append(Vector2(x0 + local_x, BALLOON_TOP + TAIL_TOP + point.y))
	_backdrop.draw_colored_polygon(points, paper_color())
	var outline := points.duplicate()
	outline.append(points[0])
	_backdrop.draw_polyline(outline, INK, 2.5, true)


func _offset_polygon(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for point: Vector2 in points:
		moved.append(point + by)
	return moved


## Concentration lines around the portrait, in a dark shade of the accent; they flicker between two phases.
func _draw_concentration_lines() -> void:
	var centre: Vector2 = _portrait_centre()
	var shade: Color = _accent.darkened(RAY_DARKEN)
	for index: int in range(RAY_COUNT):
		var start: float = deg_to_rad(float(index) * 360.0 / float(RAY_COUNT) + float(_ray_phase) * RAY_ALT_DEG)
		var end: float = start + deg_to_rad(RAY_WIDTH_DEG)
		_lines_layer.draw_colored_polygon(PackedVector2Array([
			centre + Vector2.from_angle(start) * RAY_INNER, centre + Vector2.from_angle(start) * RAY_OUTER,
			centre + Vector2.from_angle(end) * RAY_OUTER, centre + Vector2.from_angle(end) * RAY_INNER]), shade)


## Manga emotion marks on the portrait: while the call is urgent a sweat drop and three shock lines.
func _draw_emotion() -> void:
	if not sweating or _portrait_texture == null:
		return
	var side: float = 1.0 if role == Role.DRIVER else -1.0
	var centre: Vector2 = _portrait_centre() + Vector2(side * 26.0, -28.0)
	var drop := PackedVector2Array([
		centre + Vector2(0, -11), centre + Vector2(5, -3), centre + Vector2(7, 3), centre + Vector2(5, 8),
		centre + Vector2(0, 10), centre + Vector2(-5, 8), centre + Vector2(-7, 3), centre + Vector2(-5, -3)])
	_emotion_layer.draw_colored_polygon(drop, Color("#CFEFFF"))
	var outline := drop.duplicate()
	outline.append(drop[0])
	_emotion_layer.draw_polyline(outline, INK, 2.5, true)
	for tick: Array in [[Vector2(-12, -8), Vector2(-17, -12)], [Vector2(-13, 0), Vector2(-19, 0)], [Vector2(-12, 8), Vector2(-17, 12)]]:
		_emotion_layer.draw_line(centre + (tick[0] as Vector2) * side, centre + (tick[1] as Vector2) * side, INK, 2.5, true)


## Equaliser teeth at the balloon's lower right: ink triangles that rise and fall with the voice, and a 2 px ink
## baseline that they fall back to when idle.
func _draw_manga_soundwave() -> void:
	var step := WAVE_BAR_W + WAVE_GAP
	var span := step * float(WAVE_BARS) - WAVE_GAP
	var wave_x: float = _balloon_x() + BALLOON_W - 16.0 - span
	var base_y: float = BALLOON_TOP + _balloon_h - 11.0
	_wave_layer.draw_rect(Rect2(wave_x, base_y - 2.0, span, 2.0), INK)
	for index: int in range(WAVE_BARS):
		var height: float = 2.0 + _wave_bars[index] * (WAVE_MAX_H - 2.0)
		if height <= 2.5:
			continue
		var x := wave_x + float(index) * step
		_wave_layer.draw_colored_polygon(PackedVector2Array([
			Vector2(x, base_y), Vector2(x + WAVE_BAR_W * 0.5, base_y - height), Vector2(x + WAVE_BAR_W, base_y)]), INK)


static func _halftone_tile() -> Texture2D:
	if halftone_tile != null:
		return halftone_tile
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var ink := Color(T.INK_BORDER_BLACK, 0.34)
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
