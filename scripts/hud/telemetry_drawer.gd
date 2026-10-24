class_name TelemetryDrawer
extends Control

## Right-hand telemetry drawer (key T) for the followed car, concept F: slanted manga panels on a dark
## gutter skinned by the team accent, a top-down X-ray car with live tyres, brake discs, ERS flow and a G
## arrow, a pedal trace, the driver's stress and heartbeat, a story caption and onomatopoeia. The data and
## the animation clock live in `state` (TelemetryState); this node only forwards samples and paints them
## with TelemetryPainter in one `_draw`. Heat, pedal, ERS and gear colours never follow the team accent.

const T = preload("res://scripts/ui/ui_theme_tokens.gd")
const GarageStyleScript := preload("res://scripts/ui/manga/garage_style.gd")

const SIZE_OPEN := Vector2(312.0, 496.0)

## Set by RaceHud: the team accent of the HUD skin (null = the default lime).
var style: GarageStyleScript
var state: TelemetryState = TelemetryState.new()
## Times `_draw` has run (the tests use it to see that a hidden drawer sleeps).
var draw_count: int = 0


func _init() -> void:
	custom_minimum_size = SIZE_OPEN
	size = SIZE_OPEN


## The drawer is a solid panel: a click on it gets the same tactile snap as the buttons.
func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		AudioManager.click(self)
		accept_event()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	state.advance(delta)
	queue_redraw()


## Takes one sample from a car; `laps` is the race length. Call at a steady rate: the pedal and G traces
## advance one sample per call.
func show_car(car: GtCar, laps: int) -> void:
	state.update(car, laps)
	queue_redraw()


func accent_color() -> Color:
	return style.accent if style != null else T.ACCENT_ACID_LIME


func on_accent_color() -> Color:
	return style.on_accent if style != null else T.INK_BORDER_BLACK


func _draw() -> void:
	draw_count += 1
	TelemetryPainter.paint(self, state, accent_color(), on_accent_color(), PresentationSettings.reduce_motion)


## Tyre window: cold under 70 °C, ideal to 105, hot to 125, then critical.
static func temp_tint(temp: float) -> Color:
	return TelemetryWidgets.tyre_tint(temp)


## One heartbeat from phase 0..1: P bump, QRS spike, T wave.
static func heartbeat(phase: float) -> float:
	return TelemetryWidgets.PulseTrace.beat(phase)
