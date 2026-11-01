class_name WinningTriptych
extends Control

## The winning screen's three slanted manga panels, P2 | P1 | P3 left to right. Every finisher is on screen the
## whole time; focus moves by widening one panel (FOCUS_WEIGHT against 1) while the others dim, and every panel
## shows its details again when focus returns to equal. Panel backgrounds live on a lower layer than the panel
## contents so a car or standee can burst over the neighbouring panel's background.

signal focus_changed(place: int)
signal panel_pressed(place: int)

const OVERLAP_PX: float = 90.0
const FOCUS_WEIGHT: float = 1.55
const FOCUS_SECONDS: float = 0.75
const INTRO_SECONDS: float = 0.75
const INTRO_STAGGER_S: float = 0.14
const TOP: float = 70.0
## The container reaches this far past each screen edge so the slanted outer edges are never visible.
const BLEED_PX: float = 45.0
const FULL_WIDTH: float = 1920.0
## Places from the left of the screen to the right: P2, P1, P3.
const SCREEN_ORDER: Array[int] = [1, 0, 2]

## Indexed by place (0 = P1); only finishers that exist.
var panels: Array[WinningPanel] = []
var name_labels: Array[Label] = []
var time_labels: Array[Label] = []
## -1 = equal, otherwise the focused place.
var focus_place: int = -1
var available_width: float = FULL_WIDTH
## Accessibility: every transition is applied at once.
var reduce_motion: bool = false

var _backgrounds: Control
var _contents: Control
var _weights: Array[float] = []
var _slide: Array[float] = []
var _focus_tween: Tween
var _width_tween: Tween
var _intro_tween: Tween
var _from_weights: Array[float] = []
var _to_weights: Array[float] = []
var _from_dims: Array[float] = []
var _to_dims: Array[float] = []
var _from_details: Array[float] = []
var _to_details: Array[float] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backgrounds = Control.new()
	_backgrounds.name = "Backgrounds"
	_backgrounds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backgrounds)
	_contents = Control.new()
	_contents.name = "Contents"
	_contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_contents)


## `entries`, `gaps` and `textures` are indexed by place; at most three are used. `bonus_ids` are the driver ids
## that hold the fastest-lap bonus point.
func setup(entries: Array, gaps: Array[String], bonus_ids: Array[int], textures: Array[Dictionary], animate: bool) -> void:
	_kill_tweens()
	for panel: WinningPanel in panels:
		panel.background.queue_free()
		panel.queue_free()
	panels.clear()
	name_labels.clear()
	time_labels.clear()
	_weights.clear()
	_slide.clear()
	focus_place = -1
	position = Vector2(-BLEED_PX, TOP)
	size = Vector2(available_width + 2.0 * BLEED_PX, WinningPanel.PANEL_HEIGHT)
	for place: int in range(mini(entries.size(), 3)):
		var panel := WinningPanel.new()
		panel.setup(place, entries[place], gaps[place], int((entries[place] as Dictionary).id) in bonus_ids, textures[place], animate)
		panels.append(panel)
		name_labels.append(panel.name_label)
		time_labels.append(panel.result_label)
		_weights.append(1.0)
		_slide.append(0.0)
		panel.background.gui_input.connect(_on_background_input.bind(place))
	for panel: WinningPanel in _screen_panels():
		_backgrounds.add_child(panel.background)
		_contents.add_child(panel)
	_layout()


func set_focus(place: int, instant: bool = false) -> void:
	if place < 0 or place >= panels.size():
		place = -1
	if panels.is_empty():
		return
	var changed: bool = place != focus_place
	focus_place = place
	_to_weights = []
	_to_dims = []
	_to_details = []
	for panel: WinningPanel in panels:
		var focused: bool = panel.place == place
		_to_weights.append(FOCUS_WEIGHT if focused else 1.0)
		_to_dims.append(0.0 if place < 0 or focused else 1.0)
		_to_details.append(1.0 if place < 0 or focused else 0.0)
	_from_weights = _weights.duplicate()
	_from_dims = _current(func(panel: WinningPanel) -> float: return panel.dim_amount)
	_from_details = _current(func(panel: WinningPanel) -> float: return panel.detail_amount)
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	if instant or reduce_motion or not is_inside_tree():
		_apply_focus(1.0)
	else:
		_focus_tween = create_tween()
		_focus_tween.tween_method(_apply_focus, 0.0, 1.0, FOCUS_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if changed:
		focus_changed.emit(place)


## Equal, P2, P1, P3, equal, ... `step` -1 walks the same cycle backwards.
func cycle_focus(step: int) -> void:
	var sequence: Array[int] = [-1]
	for panel: WinningPanel in _screen_panels():
		sequence.append(panel.place)
	set_focus(sequence[posmod(sequence.find(focus_place) + step, sequence.size())])


## Details hidden, nothing dimmed, then the panels rise in one after another: P3, P2, P1.
func play_intro() -> void:
	_kill_tweens()
	focus_place = -1
	for panel: WinningPanel in panels:
		_weights[panel.place] = 1.0
		panel.dim_amount = 0.0
		panel.detail_amount = 0.0
		_slide[panel.place] = 0.0 if reduce_motion or not is_inside_tree() else 1.0
	_layout()
	if reduce_motion or not is_inside_tree() or panels.is_empty():
		return
	_intro_tween = create_tween().set_parallel()
	for place: int in range(panels.size() - 1, -1, -1):
		_intro_tween.tween_method(_set_slide.bind(place), 1.0, 0.0, INTRO_SECONDS) \
			.set_delay(float(panels.size() - 1 - place) * INTRO_STAGGER_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The visible width the panels share; the timing tower narrows it to make room.
func set_available_width(width: float, instant: bool = false) -> void:
	available_width = width
	if _width_tween != null and _width_tween.is_valid():
		_width_tween.kill()
	if instant or reduce_motion or not is_inside_tree():
		_set_width(width)
		return
	_width_tween = create_tween()
	_width_tween.tween_method(_set_width, size.x - 2.0 * BLEED_PX, width, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func panel_rect(place: int) -> Rect2:
	return panels[place].get_global_rect() if place >= 0 and place < panels.size() else Rect2()


func _screen_panels() -> Array[WinningPanel]:
	var ordered: Array[WinningPanel] = []
	for place: int in SCREEN_ORDER:
		if place < panels.size():
			ordered.append(panels[place])
	return ordered


func _current(read: Callable) -> Array[float]:
	var values: Array[float] = []
	for panel: WinningPanel in panels:
		values.append(float(read.call(panel)))
	return values


func _apply_focus(progress: float) -> void:
	for panel: WinningPanel in panels:
		var i: int = panel.place
		_weights[i] = lerpf(_from_weights[i], _to_weights[i], progress)
		panel.dim_amount = lerpf(_from_dims[i], _to_dims[i], progress)
		panel.detail_amount = lerpf(_from_details[i], _to_details[i], progress)
	_layout()


func _set_slide(amount: float, place: int) -> void:
	_slide[place] = amount
	_layout()


func _set_width(width: float) -> void:
	size = Vector2(width + 2.0 * BLEED_PX, WinningPanel.PANEL_HEIGHT)
	_layout()


## Widths share the container plus the overlaps; each panel starts where the previous one ends minus the overlap.
func _layout() -> void:
	var ordered: Array[WinningPanel] = _screen_panels()
	if ordered.is_empty():
		return
	var total: float = size.x + OVERLAP_PX * float(ordered.size() - 1)
	var weight_sum: float = 0.0
	for panel: WinningPanel in ordered:
		weight_sum += _weights[panel.place]
	var x: float = 0.0
	for panel: WinningPanel in ordered:
		panel.right_inset = BLEED_PX if panel == ordered[ordered.size() - 1] else 0.0
		var width: float = total * _weights[panel.place] / weight_sum
		panel.relayout(Vector2(width, WinningPanel.PANEL_HEIGHT))
		panel.position = Vector2(x, _slide[panel.place] * WinningPanel.PANEL_HEIGHT * 1.1)
		panel.background.position = panel.position
		x += width - OVERLAP_PX


func _kill_tweens() -> void:
	for tween: Tween in [_focus_tween, _width_tween, _intro_tween]:
		if tween != null and tween.is_valid():
			tween.kill()


func _on_background_input(event: InputEvent, place: int) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		panel_pressed.emit(place)
