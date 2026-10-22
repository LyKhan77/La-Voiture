class_name TelemetryDrawer
extends Control

## Right-hand telemetry drawer (key T) for the followed car, drawn as instruments rather
## than numbers: gear box, shift-light strip and speed bar, a scrolling pedal trace, a square
## G-force box, a top-down tyre heat matrix (temperature, tread, disc, blister, blow-out),
## fuel range against the flag, an ERS meter with flow chevrons, a stress / confidence
## diverging bar, a heartbeat trace and tyre life / damage bars. The few numbers left are
## gear, speed, the fuel margin and the heart rate.

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")

const SIZE_OPEN := Vector2(312.0, 496.0)
const FUEL_STAGE_TINT: Array[Color] = [T.ACCENT_ACID_LIME, T.ACCENT_CYBER_YELLOW, T.ACCENT_CYBER_YELLOW, T.ACCENT_ANIME_CRIMSON, T.ACCENT_ANIME_CRIMSON]
const TOP_SPEED_KMH: float = 330.0
const RPM_IDLE: float = 4000.0
const RPM_LIMIT: float = 8800.0

var title: Label
var gear_label: Label
var speed_label: Label
var drs_label: Label
var rpm: TelemetryWidgets.RpmStrip
var speed_bar: StepBar
var pedals: TelemetryWidgets.PedalTrace
var gball: TelemetryWidgets.GBall
var tyres: TelemetryWidgets.TyreMatrix
var fuel_stage_label: Label
var fuel_delta_label: Label
var fuel_bar: StepBar
var ers: TelemetryWidgets.ErsMeter
var mood: TelemetryWidgets.MoodBar
var pulse: TelemetryWidgets.PulseTrace
var hr_label: Label
var life_bar: StepBar
var damage_bar: StepBar

var _car_id: int = -1


func _init() -> void:
	custom_minimum_size = SIZE_OPEN
	size = SIZE_OPEN
	UI.surface(self, T.ACCENT_ELECTRIC_CYAN)
	var header := UI.header("TELEMETRY", T.ACCENT_ELECTRIC_CYAN)
	add_child(header)
	header.position = Vector2(6.0, 6.0)
	header.size = Vector2(SIZE_OPEN.x - 12.0, 28.0)
	title = header.get_child(1) as Label
	# Gear box, shift lights, speed bar, DRS chip.
	var gear_box := ColorRect.new()
	gear_box.color = T.INK_BORDER_BLACK
	gear_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gear_box)
	gear_box.position = Vector2(12.0, 42.0)
	gear_box.size = Vector2(52.0, 54.0)
	gear_label = _text("1", Vector2(12.0, 40.0), 44, T.ACCENT_CYBER_YELLOW, UI.DISPLAY)
	gear_label.size = Vector2(52.0, 54.0)
	gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rpm = _widget(TelemetryWidgets.RpmStrip.new(), Vector2(72.0, 42.0), Vector2(228.0, 14.0))
	speed_bar = StepBar.new(20)
	_widget(speed_bar, Vector2(72.0, 60.0), Vector2(228.0, 14.0))
	speed_label = _text("0 KM/H", Vector2(72.0, 78.0), 13, T.TEXT_PRIMARY)
	drs_label = _text("DRS", Vector2(246.0, 78.0), 13, T.TEXT_MUTED, UI.HEADER)
	drs_label.size = Vector2(54.0, 18.0)
	drs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Pedal trace.
	_text("PEDALS  THROTTLE / BRAKE", Vector2(12.0, 100.0), 10, T.TEXT_MUTED)
	pedals = _widget(TelemetryWidgets.PedalTrace.new(), Vector2(12.0, 114.0), Vector2(288.0, 48.0))
	# G box and tyre matrix side by side.
	_text("G-FORCE", Vector2(12.0, 168.0), 10, T.TEXT_MUTED)
	gball = _widget(TelemetryWidgets.GBall.new(), Vector2(12.0, 182.0), Vector2(124.0, 124.0))
	_text("TYRE HEAT / TREAD / DISC", Vector2(148.0, 168.0), 10, T.TEXT_MUTED)
	tyres = _widget(TelemetryWidgets.TyreMatrix.new(), Vector2(148.0, 182.0), Vector2(152.0, 124.0))
	# Fuel against the flag.
	fuel_stage_label = _text("FUEL  //  OPTIMAL", Vector2(12.0, 310.0), 15, T.ACCENT_ACID_LIME, UI.HEADER)
	fuel_delta_label = _text("", Vector2(200.0, 311.0), 13, T.TEXT_SECONDARY)
	fuel_delta_label.size = Vector2(100.0, 18.0)
	fuel_delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fuel_bar = StepBar.new(24)
	_widget(fuel_bar, Vector2(12.0, 330.0), Vector2(288.0, 12.0))
	# ERS.
	_text("ERS", Vector2(12.0, 348.0), 10, T.TEXT_MUTED)
	ers = _widget(TelemetryWidgets.ErsMeter.new(), Vector2(12.0, 362.0), Vector2(288.0, 16.0))
	# Driver.
	_text("< STRESS      CONFIDENCE >", Vector2(12.0, 386.0), 10, T.TEXT_MUTED)
	mood = _widget(TelemetryWidgets.MoodBar.new(), Vector2(12.0, 400.0), Vector2(288.0, 14.0))
	pulse = _widget(TelemetryWidgets.PulseTrace.new(), Vector2(12.0, 418.0), Vector2(288.0, 34.0))
	hr_label = _text("", Vector2(252.0, 420.0), 12, T.TEXT_SECONDARY)
	hr_label.size = Vector2(46.0, 16.0)
	hr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Tyre life and damage.
	_text("LIFE", Vector2(12.0, 460.0), 10, T.TEXT_MUTED)
	life_bar = StepBar.new(20)
	_widget(life_bar, Vector2(48.0, 460.0), Vector2(252.0, 12.0))
	_text("DMG", Vector2(12.0, 478.0), 10, T.TEXT_MUTED)
	damage_bar = StepBar.new(20)
	damage_bar.invert_scale = true
	_widget(damage_bar, Vector2(48.0, 478.0), Vector2(252.0, 12.0))


## The drawer is a solid panel: a click on it gets the same tactile snap as the buttons.
func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		AudioManager.click(self)
		accept_event()


func _text(text: String, at: Vector2, font_size: int, color: Color, font: Font = UI.MONO) -> Label:
	var label := UI.label(text, font_size, color, font)
	add_child(label)
	label.position = at
	return label


func _widget(node: Control, at: Vector2, extent: Vector2) -> Variant:
	add_child(node)
	node.position = at
	node.size = extent
	return node


## Fills the drawer from a car; `laps` is the race length. Call at a steady rate: the
## pedal and G traces advance one sample per call.
func show_car(car: GtCar, laps: int) -> void:
	if car.id != _car_id:
		_car_id = car.id
		pedals.clear()
		gball.clear()
	title.text = "TELEMETRY  //  #%02d %s" % [car.number, car.code]
	gear_label.text = "%d" % car.gear
	speed_label.text = "%d KM/H" % roundi(car.speed_kmh())
	speed_bar.set_value(car.speed_kmh() / TOP_SPEED_KMH, T.ACCENT_ELECTRIC_CYAN)
	rpm.set_value((car.rpm - RPM_IDLE) / (RPM_LIMIT - RPM_IDLE))
	_show_drs(car)
	pedals.push(car.throttle, car.brake)
	gball.push(car.lateral_g, car.longitudinal_g)
	var blown: int = car.punctured_wheel if car.is_punctured else -1
	tyres.set_state(car.wheel_temp, car.wheel_brake_temp, car.wheel_blister_pct, 1.0 - car.wear, blown)
	fuel_stage_label.text = "FUEL  //  %s" % GtTypes.FUEL_STAGE_NAME[car.fuel_stage]
	fuel_stage_label.add_theme_color_override("font_color", FUEL_STAGE_TINT[car.fuel_stage])
	var fuel_laps: float = car.fuel / maxf(car.fuel_burn_rate, 0.01)
	var to_go: float = maxf(0.0, float(laps) - float(maxi(car.lap, 0)))
	var margin: float = fuel_laps - to_go
	fuel_delta_label.text = "%+.1f L" % margin
	fuel_delta_label.add_theme_color_override("font_color", T.ACCENT_ANIME_CRIMSON if margin < 0.0 else T.TEXT_SECONDARY)
	fuel_bar.marker = clampf(to_go / maxf(float(laps), 1.0), 0.0, 1.0)
	fuel_bar.set_value(clampf(fuel_laps / maxf(float(laps), 1.0), 0.0, 1.0), FUEL_STAGE_TINT[car.fuel_stage])
	ers.set_state(car.ers_battery / 100.0, car.ers_mode)
	mood.set_state(car.driver_stress / 100.0, car.driver_confidence / 100.0)
	pulse.set_state(car.driver_heart_rate, car.driver_stress / 100.0)
	hr_label.text = "%d" % roundi(car.driver_heart_rate)
	life_bar.set_value(1.0 - car.wear)
	damage_bar.set_value(car.damage / 100.0)


func _show_drs(car: GtCar) -> void:
	var tint: Color = T.TEXT_MUTED
	var fill: Color = Color(1.0, 1.0, 1.0, 0.07)
	if car.drs_active:
		tint = T.INK_BORDER_BLACK
		fill = T.ACCENT_ELECTRIC_CYAN
	elif car.drs_eligible:
		tint = T.ACCENT_CYBER_YELLOW
		fill = Color(T.ACCENT_CYBER_YELLOW, 0.18)
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	drs_label.add_theme_stylebox_override("normal", box)
	drs_label.add_theme_color_override("font_color", tint)


## Tyre window: cold under 70 °C, ideal to 105, hot to 125, then critical.
static func temp_tint(temp: float) -> Color:
	return TelemetryWidgets.tyre_tint(temp)
