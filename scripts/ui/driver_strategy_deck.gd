class_name DriverStrategyDeck
extends Control

## Right-hand pit wall strategy deck (Zone D): selected car identity, four
## corner tyre state, ERS/fuel readouts, pace/fuel maps and the BOX call.
##
## Pure presentation: every command leaves through a signal, every displayed
## number comes from a telemetry packet. No engine state is mutated here.

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")

signal car_selected(car_id: int)
signal pace_requested(car_id: int, mode: int)
signal fuel_requested(car_id: int, mode: int)
signal box_requested(car_id: int)
signal impact_requested()

const PACE_NAMES: Array[String] = ["CONSERVE", "BALANCED", "ATTACK"]
const FUEL_NAMES: Array[String] = ["ECO", "STANDARD", "PUSH"]
const CORNER_NAMES: Array[String] = ["FL", "FR", "RL", "RR"]
const MIN_CAR_ID: int = 0
const MAX_CAR_ID: int = 1
const BLINK_TIME_S: float = 0.12


class SegmentBar extends Control:
	const TOKENS = preload("res://scripts/ui/ui_theme_tokens.gd")

	var value: float = 0.0
	var tint: Color = TOKENS.ACCENT_ELECTRIC_CYAN
	var segment_count: int = 10

	func _init(count: int = 10) -> void:
		segment_count = maxi(1, count)
		custom_minimum_size = Vector2(0, 8)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		draw.connect(_paint)
		resized.connect(queue_redraw)

	func set_state(p_value: float, p_tint: Color) -> void:
		value = clampf(p_value, 0.0, 1.0)
		tint = p_tint
		queue_redraw()

	func _paint() -> void:
		var gap: float = 2.0
		var usable: float = maxf(0.0, size.x - gap * float(segment_count - 1))
		var block_width: float = usable / float(segment_count)
		var lit: int = int(round(value * float(segment_count)))
		for index: int in range(segment_count):
			var rect := Rect2(float(index) * (block_width + gap), 0.0, block_width, size.y)
			draw_rect(rect, tint if index < lit else TOKENS.SURFACE_PANEL_ELEVATED)


## Test/integration surface.
var pace_slider: HSlider
var fuel_slider: HSlider
var box_button: Button
var tabs: Array[Button] = []

var selected_car_id: int:
	get:
		return _selected_car_id
	set(value):
		_selected_car_id = clampi(value, MIN_CAR_ID, MAX_CAR_ID)
		if _built:
			_refresh_tabs()
			_apply_selected_packet()

var _selected_car_id: int = 0
var _built: bool = false
var _packets: Dictionary = {}

var _badge: Label
var _driver: Label
var _team: Label
var _compound: Label
var _ers_value: Label
var _ers_bar: SegmentBar
var _fuel_value: Label
var _fuel_sub: Label
var _pace_value: Label
var _fuel_mode_value: Label
var _tire_cells: Array[Dictionary] = []

var _box_label: Label
var _box_backdrop: Control
var _box_fill_mat: ShaderMaterial
var _box_border_mat: ShaderMaterial
var _box_shadow_mat: ShaderMaterial
var _shaker: Control
var _pulse: ColorRect
var _flash: ColorRect
var _box_tweens: Array[Tween] = []
var _box_ack: bool = false

var _blink_timer: Timer
var _blink_on: bool = false


func _ready() -> void:
	set_process(false)
	_build()
	_built = true
	_refresh_tabs()
	_apply_selected_packet()


# --- public API -------------------------------------------------------------

func select_car(car_id: int) -> void:
	var target: int = clampi(car_id, MIN_CAR_ID, MAX_CAR_ID)
	var changed: bool = target != _selected_car_id
	_selected_car_id = target
	if _built:
		_refresh_tabs()
		_apply_selected_packet()
	if changed:
		car_selected.emit(target)


func update_telemetry(packet: Dictionary) -> void:
	if packet.is_empty():
		return
	var car_id: int = _selected_car_id
	if packet.has("car_id"):
		car_id = int(packet["car_id"])
	if car_id < MIN_CAR_ID or car_id > MAX_CAR_ID:
		return
	_packets[car_id] = packet
	if _built and car_id == _selected_car_id:
		_render_packet(packet)


# --- build ------------------------------------------------------------------

func _build() -> void:
	var column := VBoxContainer.new()
	column.name = "DeckColumn"
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 8.0
	column.offset_top = 8.0
	column.offset_right = -8.0
	column.offset_bottom = -8.0
	column.add_theme_constant_override("separation", 6)

	column.add_child(UI.header("STRATEGY // DRIVER DECK", T.ACCENT_ACID_LIME))
	column.add_child(_build_tabs())
	column.add_child(_build_identity())
	column.add_child(_build_resources())
	column.add_child(_build_tires())
	column.add_child(_build_pace())
	column.add_child(_build_fuel_map())

	var spacer := Control.new()
	spacer.name = "FlexSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	column.add_child(_build_cta())

	var hint := UI.label("TAB // FOCUS    ARROWS // ADJUST    ENTER // BOX", 9, T.TEXT_MUTED, UI.MONO)
	hint.name = "KeyHint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

	_blink_timer = Timer.new()
	_blink_timer.name = "CriticalBlinkTimer"
	_blink_timer.wait_time = BLINK_TIME_S
	_blink_timer.timeout.connect(_on_blink_timer)
	add_child(_blink_timer)

	_flash = ColorRect.new()
	_flash.name = "ImpactFlash"
	_flash.color = Color.WHITE
	_flash.visible = false
	_flash.z_index = 100
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_tabs() -> Control:
	var row := HBoxContainer.new()
	row.name = "CarTabs"
	row.custom_minimum_size.y = 32.0
	row.add_theme_constant_override("separation", 6)
	for index: int in range(2):
		var tab := Button.new()
		tab.name = "CarTab%d" % index
		tab.text = "CAR #%02d" % (index + 1)
		tab.focus_mode = Control.FOCUS_ALL
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.custom_minimum_size = Vector2(0, 32)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_override("font", UI.HEADER)
		tab.add_theme_font_size_override("font_size", 16)
		tab.pressed.connect(_on_tab_pressed.bind(index))
		tab.gui_input.connect(_on_tab_gui_input.bind(index))
		row.add_child(tab)
		tabs.append(tab)
	return row


func _build_identity() -> Control:
	var panel := _make_panel(T.ACCENT_ACID_LIME, 66)
	panel.name = "DriverIdentity"
	var row := HBoxContainer.new()
	_mount(panel, row, 8.0)
	row.add_theme_constant_override("separation", 8)

	_badge = UI.label("#01", 24, T.ACCENT_ACID_LIME, UI.DISPLAY)
	_badge.name = "CarBadge"
	_badge.custom_minimum_size.x = 52
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_badge)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 0)
	_driver = UI.label("--", 22, T.TEXT_PRIMARY, UI.DISPLAY)
	_driver.name = "DriverName"
	info.add_child(_driver)
	_team = UI.label("AWAITING TELEMETRY", 10, T.TEXT_SECONDARY, UI.MONO)
	_team.name = "TeamIdentity"
	info.add_child(_team)
	row.add_child(info)
	return panel


func _build_resources() -> Control:
	var row := HBoxContainer.new()
	row.name = "Resources"
	row.custom_minimum_size.y = 64.0
	row.add_theme_constant_override("separation", 6)

	var ers_panel := _make_panel(T.ACCENT_ELECTRIC_CYAN, 64)
	ers_panel.name = "ERSPanel"
	ers_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ers_box := _content(ers_panel, 7.0)
	ers_box.add_theme_constant_override("separation", 1)
	ers_box.add_child(UI.label("ERS // BATTERY", 10, T.TEXT_SECONDARY, UI.HEADER))
	_ers_value = UI.label("--", 15, T.ACCENT_ELECTRIC_CYAN, UI.MONO)
	_ers_value.name = "ERSValue"
	ers_box.add_child(_ers_value)
	_ers_bar = SegmentBar.new(12)
	_ers_bar.name = "ERSBar"
	_ers_bar.custom_minimum_size.y = 7.0
	_ers_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ers_bar.tint = T.ACCENT_ELECTRIC_CYAN
	ers_box.add_child(_ers_bar)
	row.add_child(ers_panel)

	var fuel_panel := _make_panel(T.TEXT_PRIMARY, 64)
	fuel_panel.name = "FuelPanel"
	fuel_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fuel_box := _content(fuel_panel, 7.0)
	fuel_box.add_theme_constant_override("separation", 1)
	fuel_box.add_child(UI.label("FUEL // REMAINING", 10, T.TEXT_SECONDARY, UI.HEADER))
	_fuel_value = UI.label("-- KG", 15, T.TEXT_PRIMARY, UI.MONO)
	_fuel_value.name = "FuelValue"
	fuel_box.add_child(_fuel_value)
	_fuel_sub = UI.label("NO SNAPSHOT", 9, T.TEXT_MUTED, UI.MONO)
	_fuel_sub.name = "FuelPenalty"
	fuel_box.add_child(_fuel_sub)
	row.add_child(fuel_panel)
	return row


func _build_tires() -> Control:
	var panel := _make_panel(T.ACCENT_CYBER_YELLOW, 202)
	panel.name = "TireDeck"
	var box := _content(panel, 8.0)
	box.add_theme_constant_override("separation", 3)

	var head := HBoxContainer.new()
	head.name = "TireHeader"
	var title := UI.label("TIRE DEG // 4-CORNER", 12, T.TEXT_SECONDARY, UI.HEADER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_compound = UI.label("--", 10, T.ACCENT_CYBER_YELLOW, UI.MONO)
	_compound.name = "Compound"
	head.add_child(_compound)
	box.add_child(head)

	var grid := GridContainer.new()
	grid.name = "TireGrid"
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for index: int in range(CORNER_NAMES.size()):
		grid.add_child(_build_tire_cell(index))
	return panel


func _build_tire_cell(index: int) -> Control:
	var cell := Panel.new()
	cell.name = "Tire" + CORNER_NAMES[index]
	cell.custom_minimum_size = Vector2(0, 78)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	UI.surface(cell, Color(1, 1, 1, 0.16))

	var strip := ColorRect.new()
	strip.name = "ConditionStrip"
	strip.color = T.TEXT_MUTED
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(strip)
	strip.anchor_left = 0.0
	strip.anchor_top = 0.0
	strip.anchor_right = 0.0
	strip.anchor_bottom = 1.0
	strip.offset_left = 5.0
	strip.offset_top = 7.0
	strip.offset_right = 9.0
	strip.offset_bottom = -7.0

	var content := VBoxContainer.new()
	content.name = "Content"
	cell.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14.0
	content.offset_top = 6.0
	content.offset_right = -6.0
	content.offset_bottom = -6.0
	content.add_theme_constant_override("separation", 1)

	var head := HBoxContainer.new()
	var corner := UI.label(CORNER_NAMES[index], 12, T.TEXT_SECONDARY, UI.HEADER)
	corner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(corner)
	var temp := UI.label("--", 10, T.TEXT_SECONDARY, UI.MONO)
	temp.name = "Temp"
	temp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(temp)
	content.add_child(head)

	var pct := UI.label("--", 16, T.TEXT_MUTED, UI.MONO)
	pct.name = "Condition"
	content.add_child(pct)

	var condition_bar := SegmentBar.new(10)
	condition_bar.name = "ConditionBar"
	condition_bar.custom_minimum_size.y = 7.0
	condition_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(condition_bar)

	var thermal_bar := SegmentBar.new(10)
	thermal_bar.name = "TempBar"
	thermal_bar.custom_minimum_size.y = 5.0
	thermal_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thermal_bar.tint = T.ACCENT_ELECTRIC_CYAN
	content.add_child(thermal_bar)

	_tire_cells.append({
		"strip": strip,
		"pct": pct,
		"temp": temp,
		"condition": condition_bar,
		"thermal": thermal_bar,
		"critical": false,
		"tint": T.TEXT_MUTED,
	})
	return cell


func _build_pace() -> Control:
	var panel := _make_panel(T.ACCENT_ACID_LIME, 72)
	panel.name = "PacePanel"
	var box := _content(panel, 8.0)
	box.add_theme_constant_override("separation", 2)

	var row := HBoxContainer.new()
	var title := UI.label("PACE // DRIVER MODE", 11, T.TEXT_SECONDARY, UI.HEADER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	_pace_value = UI.label("--", 11, T.ACCENT_ACID_LIME, UI.MONO)
	_pace_value.name = "PaceValue"
	row.add_child(_pace_value)
	box.add_child(row)

	pace_slider = _make_slider(0.0, 2.0, 1.0)
	pace_slider.name = "PaceSlider"
	pace_slider.value = 1.0
	box.add_child(pace_slider)
	box.add_child(_build_mode_ticks(PACE_NAMES))
	pace_slider.value_changed.connect(_on_pace_changed)
	return panel


func _build_fuel_map() -> Control:
	var panel := _make_panel(T.ACCENT_ELECTRIC_CYAN, 72)
	panel.name = "FuelMapPanel"
	var box := _content(panel, 8.0)
	box.add_theme_constant_override("separation", 2)

	var row := HBoxContainer.new()
	var title := UI.label("FUEL MAP // ENGINE", 11, T.TEXT_SECONDARY, UI.HEADER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	_fuel_mode_value = UI.label("--", 11, T.ACCENT_ELECTRIC_CYAN, UI.MONO)
	_fuel_mode_value.name = "FuelModeValue"
	row.add_child(_fuel_mode_value)
	box.add_child(row)

	fuel_slider = _make_slider(0.0, 2.0, 1.0)
	fuel_slider.name = "FuelSlider"
	fuel_slider.value = 1.0
	box.add_child(fuel_slider)
	box.add_child(_build_mode_ticks(FUEL_NAMES))
	fuel_slider.value_changed.connect(_on_fuel_changed)
	return panel


func _build_mode_ticks(names: Array[String]) -> Control:
	var row := HBoxContainer.new()
	row.name = "ModeTicks"
	for index: int in range(names.size()):
		var tick := UI.label(names[index], 9, T.TEXT_MUTED, UI.MONO)
		tick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if index == 0:
			tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		elif index == names.size() - 1:
			tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		else:
			tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(tick)
	return row


func _build_cta() -> Control:
	var slot := Control.new()
	slot.name = "BoxSlot"
	slot.custom_minimum_size = Vector2(0, 82)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_pulse = ColorRect.new()
	_pulse.name = "CrimsonPulse"
	_pulse.color = T.ACCENT_ANIME_CRIMSON
	_pulse.modulate = Color(1, 1, 1, 0)
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(_pulse)
	_pulse.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_shaker = Control.new()
	_shaker.name = "BoxShaker"
	_shaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(_shaker)
	_shaker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	box_button = Button.new()
	box_button.name = "BoxButton"
	box_button.text = "BOX THIS LAP"
	box_button.focus_mode = Control.FOCUS_ALL
	box_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	box_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shaker.add_child(box_button)
	box_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box_button.offset_left = 4.0
	box_button.offset_top = 2.0
	box_button.offset_right = -8.0
	box_button.offset_bottom = -10.0

	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		box_button.add_theme_stylebox_override(state, empty)
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0, 0, 0, 0)
	focus_style.border_color = T.SURFACE_SNAP_INVERT
	focus_style.set_border_width_all(3)
	focus_style.set_expand_margin_all(3)
	box_button.add_theme_stylebox_override("focus", focus_style)
	for key: String in [
		"font_color", "font_hover_color", "font_pressed_color",
		"font_focus_color", "font_hover_pressed_color", "font_disabled_color",
	]:
		box_button.add_theme_color_override(key, Color(0, 0, 0, 0))
	box_button.pressed.connect(_on_box_pressed)

	_box_backdrop = Control.new()
	_box_backdrop.name = "SkewBackdrop"
	_box_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_button.add_child(_box_backdrop)
	_box_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box_backdrop.offset_left = 4.0
	_box_backdrop.offset_top = 4.0
	_box_backdrop.offset_right = -4.0
	_box_backdrop.offset_bottom = -4.0

	var shadow_layer := ColorRect.new()
	shadow_layer.name = "CrimsonShadow"
	shadow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_backdrop.add_child(shadow_layer)
	shadow_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow_layer.offset_left = 6.0
	shadow_layer.offset_top = 6.0
	shadow_layer.offset_right = 6.0
	shadow_layer.offset_bottom = 6.0
	_box_shadow_mat = _skew_material(shadow_layer, T.ACCENT_ANIME_CRIMSON, 14.0)

	var border_layer := ColorRect.new()
	border_layer.name = "InkBorder"
	border_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_backdrop.add_child(border_layer)
	border_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box_border_mat = _skew_material(border_layer, T.INK_BORDER_BLACK, 14.0)

	var fill_layer := ColorRect.new()
	fill_layer.name = "LimeFill"
	fill_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_backdrop.add_child(fill_layer)
	fill_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill_layer.offset_left = 3.0
	fill_layer.offset_top = 3.0
	fill_layer.offset_right = -3.0
	fill_layer.offset_bottom = -3.0
	_box_fill_mat = _skew_material(fill_layer, T.ACCENT_ACID_LIME, 14.0)

	_box_label = UI.label("BOX THIS LAP", 26, T.INK_BORDER_BLACK, UI.DISPLAY)
	_box_label.name = "BoxLabel"
	_box_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box_button.add_child(_box_label)
	_box_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box_label.offset_left = 4.0
	_box_label.offset_top = 4.0
	_box_label.offset_right = -4.0
	_box_label.offset_bottom = -4.0
	return slot


func _make_panel(accent: Color, height: float) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, height)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	UI.surface(panel, Color(accent.r, accent.g, accent.b, 0.55))
	return panel


func _mount(panel: Control, node: Control, margin: float) -> void:
	panel.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.offset_left = margin
	node.offset_top = margin
	node.offset_right = -margin
	node.offset_bottom = -margin


func _content(panel: Control, margin: float) -> VBoxContainer:
	var box := VBoxContainer.new()
	_mount(panel, box, margin)
	return box


func _make_slider(minimum: float, maximum: float, step: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.tick_count = int(round((maximum - minimum) / step)) + 1
	slider.ticks_on_borders = true
	slider.allow_greater = false
	slider.allow_lesser = false
	slider.focus_mode = Control.FOCUS_ALL
	slider.custom_minimum_size = Vector2(0, 20)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var track := StyleBoxFlat.new()
	track.bg_color = T.SURFACE_PANEL_ELEVATED
	track.border_color = T.INK_BORDER_BLACK
	track.set_border_width_all(2)
	track.set_content_margin_all(3)
	slider.add_theme_stylebox_override("slider", track)

	var filled := StyleBoxFlat.new()
	filled.bg_color = T.ACCENT_ACID_LIME
	filled.set_content_margin_all(3)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)

	var grabber := _grabber_icon(T.ACCENT_ACID_LIME)
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", _grabber_icon(T.SURFACE_SNAP_INVERT))

	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = T.ACCENT_ACID_LIME
	focus.set_border_width_all(1)
	focus.set_expand_margin_all(2)
	slider.add_theme_stylebox_override("focus", focus)
	return slider


func _grabber_icon(tint: Color) -> ImageTexture:
	var image := Image.create(12, 18, false, Image.FORMAT_RGBA8)
	image.fill(T.INK_BORDER_BLACK)
	image.fill_rect(Rect2i(2, 2, 8, 14), tint)
	return ImageTexture.create_from_image(image)


func _skew_material(rect: ColorRect, fill: Color, cut: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = UI.CHAMFER
	mat.set_shader_parameter("fill_color", fill)
	mat.set_shader_parameter("cut_px", cut)
	mat.set_shader_parameter("skew_degrees", -6.0)
	mat.set_shader_parameter("rect_size", rect.size)
	rect.material = mat
	rect.resized.connect(_sync_skew_rect.bind(rect, mat))
	return mat


func _sync_skew_rect(rect: ColorRect, mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("rect_size", rect.size)


# --- selection / rendering --------------------------------------------------

func _refresh_tabs() -> void:
	for index: int in range(tabs.size()):
		_style_tab(tabs[index], index == _selected_car_id)
	if _badge != null:
		_badge.text = "#%02d" % (_selected_car_id + 1)


func _style_tab(tab: Button, active: bool) -> void:
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = T.ACCENT_ACID_LIME
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(2)
	tab.add_theme_stylebox_override("focus", focus)

	if active:
		tab.add_theme_stylebox_override("normal", _tab_box(T.SURFACE_SNAP_INVERT, T.INK_BORDER_BLACK, T.ACCENT_ACID_LIME))
		tab.add_theme_stylebox_override("hover", _tab_box(T.SURFACE_SNAP_INVERT, T.ACCENT_ACID_LIME, T.ACCENT_ACID_LIME))
		tab.add_theme_stylebox_override("pressed", _tab_box(T.ACCENT_ACID_LIME, T.INK_BORDER_BLACK, T.INK_BORDER_BLACK))
		for key: String in [
			"font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_hover_pressed_color",
		]:
			tab.add_theme_color_override(key, T.INK_BORDER_BLACK)
	else:
		tab.add_theme_stylebox_override("normal", _tab_box(T.SURFACE_PANEL_ELEVATED, T.INK_BORDER_BLACK, T.INK_BORDER_BLACK))
		tab.add_theme_stylebox_override("hover", _tab_box(T.SURFACE_SNAP_INVERT, T.ACCENT_ACID_LIME, T.ACCENT_ACID_LIME))
		tab.add_theme_stylebox_override("pressed", _tab_box(T.ACCENT_ACID_LIME, T.INK_BORDER_BLACK, T.INK_BORDER_BLACK))
		tab.add_theme_color_override("font_color", T.TEXT_SECONDARY)
		for key: String in [
			"font_hover_color", "font_pressed_color",
			"font_focus_color", "font_hover_pressed_color",
		]:
			tab.add_theme_color_override(key, T.INK_BORDER_BLACK)


func _tab_box(fill: Color, border: Color, shadow: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(3)
	box.shadow_color = shadow
	box.shadow_size = 0
	box.shadow_offset = Vector2(4, 4)
	box.set_content_margin_all(4)
	return box


func _apply_selected_packet() -> void:
	if _packets.has(_selected_car_id):
		var packet: Dictionary = _packets[_selected_car_id]
		_render_packet(packet)
	else:
		_render_placeholder()


func _render_placeholder() -> void:
	_badge.text = "#%02d" % (_selected_car_id + 1)
	_driver.text = "--"
	_team.text = "AWAITING TELEMETRY"
	_compound.text = "--"
	_ers_value.text = "--"
	_ers_bar.set_state(0.0, T.TEXT_MUTED)
	_fuel_value.text = "-- KG"
	_fuel_sub.text = "NO SNAPSHOT"
	_pace_value.text = "--"
	_fuel_mode_value.text = "--"
	pace_slider.set_value_no_signal(1.0)
	fuel_slider.set_value_no_signal(1.0)
	for cell: Dictionary in _tire_cells:
		_render_tire_empty(cell)
	_update_blink_timer()
	_set_box_ack(false)


func _render_packet(packet: Dictionary) -> void:
	var car_id: int = _selected_car_id
	_badge.text = "#%02d" % (car_id + 1)

	var driver_name: String = str(packet.get("driver_name", "--"))
	_driver.text = driver_name if not driver_name.is_empty() else "--"

	var team: String = str(packet.get("team_name", ""))
	if team.is_empty():
		team = str(packet.get("team_code", ""))
	if team.is_empty():
		team = "TEAM %02d" % (int(packet.get("team_id", 0)) + 1)
	_team.text = "%s // CAR #%02d" % [team.to_upper(), car_id + 1]

	_compound.text = str(packet.get("tire_compound_name", "--"))
	_render_tires(packet)

	if packet.has("ers_battery_pct"):
		var ers: float = clampf(float(packet["ers_battery_pct"]), 0.0, 1.0)
		_ers_value.text = "%d%%" % roundi(ers * 100.0)
		_ers_bar.set_state(ers, T.ACCENT_ELECTRIC_CYAN)
	else:
		_ers_value.text = "--"
		_ers_bar.set_state(0.0, T.TEXT_MUTED)

	if packet.has("fuel_remaining_kg"):
		_fuel_value.text = "%.1f KG" % float(packet["fuel_remaining_kg"])
	else:
		_fuel_value.text = "-- KG"
	if packet.has("fuel_weight_penalty_s"):
		_fuel_sub.text = "LOAD +%.2fS" % float(packet["fuel_weight_penalty_s"])
	else:
		_fuel_sub.text = "--"

	if packet.has("pace_mode"):
		var pace: int = clampi(int(packet["pace_mode"]), 0, PACE_NAMES.size() - 1)
		pace_slider.set_value_no_signal(float(pace))
		_pace_value.text = PACE_NAMES[pace]
	else:
		pace_slider.set_value_no_signal(1.0)
		_pace_value.text = "--"

	if packet.has("engine_mode"):
		var engine_mode: int = clampi(int(packet["engine_mode"]), 0, FUEL_NAMES.size() - 1)
		fuel_slider.set_value_no_signal(float(engine_mode))
		_fuel_mode_value.text = FUEL_NAMES[engine_mode]
	else:
		fuel_slider.set_value_no_signal(1.0)
		_fuel_mode_value.text = "--"

	_set_box_ack(bool(packet.get("box_requested", false)))


func _render_tires(packet: Dictionary) -> void:
	var wear: PackedFloat64Array = _to_floats(packet.get("tire_wear"))
	var temps: PackedFloat64Array = _to_floats(packet.get("tire_temps"))
	for index: int in range(_tire_cells.size()):
		var cell: Dictionary = _tire_cells[index]
		var has_wear: bool = index < wear.size()
		var has_temp: bool = index < temps.size()
		if has_wear:
			_render_tire(
				cell,
				clampf(wear[index], 0.0, 1.0),
				has_temp,
				temps[index] if has_temp else 0.0
			)
		else:
			_render_tire_empty(cell)
	_update_blink_timer()


func _render_tire(cell: Dictionary, remaining: float, has_temp: bool, temp_c: float) -> void:
	var pct := cell["pct"] as Label
	var temp := cell["temp"] as Label
	var strip := cell["strip"] as ColorRect
	var condition_bar := cell["condition"] as SegmentBar
	var thermal_bar := cell["thermal"] as SegmentBar

	var tint: Color = _condition_color(remaining)
	var critical: bool = remaining <= 0.30
	cell["tint"] = tint
	cell["critical"] = critical

	pct.text = "%d%%" % roundi(remaining * 100.0)
	pct.modulate.a = 1.0
	pct.add_theme_color_override("font_color", tint)
	strip.color = tint
	condition_bar.set_state(remaining, tint)

	if has_temp:
		temp.text = "%d°C" % roundi(temp_c)
		thermal_bar.set_state(clampf((temp_c - 40.0) / 100.0, 0.0, 1.0), T.ACCENT_ELECTRIC_CYAN)
	else:
		temp.text = "--"
		thermal_bar.set_state(0.0, T.TEXT_MUTED)


func _render_tire_empty(cell: Dictionary) -> void:
	var pct := cell["pct"] as Label
	var temp := cell["temp"] as Label
	var strip := cell["strip"] as ColorRect
	var condition_bar := cell["condition"] as SegmentBar
	var thermal_bar := cell["thermal"] as SegmentBar
	cell["critical"] = false
	cell["tint"] = T.TEXT_MUTED
	pct.text = "--"
	pct.modulate.a = 1.0
	pct.add_theme_color_override("font_color", T.TEXT_MUTED)
	temp.text = "--"
	strip.color = T.TEXT_MUTED
	condition_bar.set_state(0.0, T.TEXT_MUTED)
	thermal_bar.set_state(0.0, T.TEXT_MUTED)


func _condition_color(remaining: float) -> Color:
	if remaining > 0.60:
		return T.ACCENT_ACID_LIME
	if remaining > 0.30:
		return T.ACCENT_CYBER_YELLOW
	return T.ACCENT_ANIME_CRIMSON


func _to_floats(value: Variant) -> PackedFloat64Array:
	if value is PackedFloat64Array:
		var typed: PackedFloat64Array = value
		return typed
	if value is PackedFloat32Array:
		var source_32: PackedFloat32Array = value
		var from_32 := PackedFloat64Array()
		from_32.resize(source_32.size())
		for index: int in range(source_32.size()):
			from_32[index] = float(source_32[index])
		return from_32
	if value is Array:
		var source_array: Array = value
		var from_array := PackedFloat64Array()
		from_array.resize(source_array.size())
		for index: int in range(source_array.size()):
			from_array[index] = float(source_array[index])
		return from_array
	return PackedFloat64Array()


# --- interaction ------------------------------------------------------------

func _on_tab_pressed(car_id: int) -> void:
	if car_id != _selected_car_id:
		select_car(car_id)
	else:
		_refresh_tabs()


func _on_tab_gui_input(event: InputEvent, car_id: int) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_LEFT or key.keycode == KEY_RIGHT:
				var direction: int = (1 if key.keycode == KEY_RIGHT else -1)
				var target: int = clampi(car_id + direction, MIN_CAR_ID, MAX_CAR_ID)
				if target != car_id:
					select_car(target)
					tabs[target].grab_focus()
				tabs[car_id].accept_event()


func _on_pace_changed(value: float) -> void:
	var mode: int = clampi(int(round(value)), 0, PACE_NAMES.size() - 1)
	_pace_value.text = PACE_NAMES[mode]
	pace_requested.emit(_selected_car_id, mode)


func _on_fuel_changed(value: float) -> void:
	var mode: int = clampi(int(round(value)), 0, FUEL_NAMES.size() - 1)
	_fuel_mode_value.text = FUEL_NAMES[mode]
	fuel_requested.emit(_selected_car_id, mode)


func _on_box_pressed() -> void:
	if _box_ack:
		return
	box_requested.emit(_selected_car_id)
	impact_requested.emit()
	_reset_box_fx()
	_play_box_fx()


func _set_box_ack(requested: bool) -> void:
	var changed: bool = requested != _box_ack
	_box_ack = requested
	if box_button == null or not changed:
		return
	if requested:
		_reset_box_fx()
	box_button.disabled = requested
	box_button.text = "BOX REQUESTED" if requested else "BOX THIS LAP"
	_box_label.text = "BOX REQUESTED" if requested else "BOX THIS LAP"
	_box_label.add_theme_color_override(
		"font_color", T.ACCENT_ACID_LIME if requested else T.INK_BORDER_BLACK
	)
	_apply_box_palette(requested)


func _apply_box_palette(requested: bool) -> void:
	if _box_fill_mat != null:
		_box_fill_mat.set_shader_parameter(
			"fill_color", T.SURFACE_PANEL_ELEVATED if requested else T.ACCENT_ACID_LIME
		)
	if _box_border_mat != null:
		_box_border_mat.set_shader_parameter(
			"fill_color", T.ACCENT_ACID_LIME if requested else T.INK_BORDER_BLACK
		)
	if _box_shadow_mat != null:
		_box_shadow_mat.set_shader_parameter(
			"fill_color", T.INK_BORDER_BLACK if requested else T.ACCENT_ANIME_CRIMSON
		)


func _reset_box_fx() -> void:
	for tween: Tween in _box_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_box_tweens.clear()
	if _shaker != null:
		_shaker.position = Vector2.ZERO
	if _pulse != null:
		_pulse.modulate.a = 0.0
	if _flash != null:
		_flash.visible = false


func _play_box_fx() -> void:
	if not is_inside_tree() or _shaker == null:
		return
	if _flash != null:
		_flash.visible = true
		_flash.color = Color(1, 1, 1, 0.95)

	var flash := create_tween()
	flash.tween_interval(0.04)
	flash.tween_callback(_impact_black)
	flash.tween_interval(0.04)
	flash.tween_callback(_impact_end)
	_box_tweens.append(flash)

	var shake := create_tween()
	shake.tween_property(_shaker, "position", Vector2(-6, 0), 0.03)
	shake.tween_property(_shaker, "position", Vector2(6, 1), 0.035)
	shake.tween_property(_shaker, "position", Vector2(-5, -1), 0.035)
	shake.tween_property(_shaker, "position", Vector2(4, 1), 0.03)
	shake.tween_property(_shaker, "position", Vector2(-3, 0), 0.03)
	shake.tween_property(_shaker, "position", Vector2.ZERO, 0.04)
	shake.tween_callback(_shake_rest)
	_box_tweens.append(shake)

	var pulse := create_tween()
	pulse.tween_property(_pulse, "modulate:a", 0.9, 0.07)
	pulse.tween_property(_pulse, "modulate:a", 0.0, 0.24)
	pulse.tween_callback(_pulse_rest)
	_box_tweens.append(pulse)


func _impact_black() -> void:
	_flash.color = Color(0, 0, 0, 0.95)


func _impact_end() -> void:
	_flash.visible = false


func _shake_rest() -> void:
	_shaker.position = Vector2.ZERO


func _pulse_rest() -> void:
	_pulse.modulate.a = 0.0


func _on_blink_timer() -> void:
	_blink_on = not _blink_on
	_apply_blink_phase()


func _update_blink_timer() -> void:
	if _blink_timer == null:
		return
	var has_critical: bool = false
	for cell: Dictionary in _tire_cells:
		if bool(cell["critical"]):
			has_critical = true
			break
	if has_critical:
		if _blink_timer.is_stopped():
			_blink_on = false
			_blink_timer.start()
	else:
		_blink_timer.stop()
		_blink_on = false
	_apply_blink_phase()


func _apply_blink_phase() -> void:
	for cell: Dictionary in _tire_cells:
		if not bool(cell["critical"]):
			continue
		var pct := cell["pct"] as Label
		var strip := cell["strip"] as ColorRect
		var tint: Color = cell["tint"]
		if _blink_on:
			pct.add_theme_color_override("font_color", T.TEXT_PRIMARY)
			pct.modulate.a = 0.45
			strip.color = Color(1, 1, 1, 0.35)
		else:
			pct.add_theme_color_override("font_color", tint)
			pct.modulate.a = 1.0
			strip.color = tint
