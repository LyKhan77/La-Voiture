class_name SettingsModal
extends Control

## Display, graphics and audio settings (spec §2.2) as a modal over the main menu.
## Every control applies immediately: window mode/resolution/V-Sync go to DisplayServer,
## the preset and toggles go through PresentationSettings.apply_to_tree() onto the live
## render tree, and the five sliders write the AudioServer bus volumes. Escape or CLOSE
## returns to the menu; the choice is saved to user://presentation.cfg on close.

signal closed

const UI := preload("res://scripts/ui/pit_wall_ui.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const PS := preload("res://scripts/core/presentation_settings.gd")
const StreetStyle := preload("res://scripts/ui/street_style.gd")
const HEADER := preload("res://assets/fonts/BarlowCondensed.ttf")
const MONO := preload("res://assets/fonts/JetBrainsMono.ttf")
const DISPLAY := preload("res://assets/fonts/Anton.ttf")

const STAGE := Vector2(1920.0, 1080.0)
const TILT_RAD: float = -0.0698 # the panel hangs like an inspection tag, -4 degrees
const PANEL_RECT := Rect2(330.0, 140.0, 1260.0, 800.0)
const LEFT_X: float = 44.0
const RIGHT_X: float = 660.0
const COLUMN_W: float = 556.0

var stage: Control
var display_option: OptionButton
var resolution_option: OptionButton
var vsync_check: CheckButton
var quality_option: OptionButton
var halftone_check: CheckButton
var reduce_motion_check: CheckButton
var vfx_check: CheckButton
var outline_label: Label
var sliders: Dictionary = {} # bus name -> HSlider
var value_labels: Dictionary = {} # bus name -> Label
var close_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	stage = Control.new()
	stage.name = "Stage"
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	_build_backdrop()
	_build_panel()
	get_viewport().size_changed.connect(fit)
	fit()
	visible = false


func fit() -> void:
	if stage == null or not is_inside_tree():
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var factor: float = minf(view.x / STAGE.x, view.y / STAGE.y)
	stage.scale = Vector2(factor, factor)
	stage.position = (view - STAGE * factor) * 0.5


## Shows the modal over the current screen and gives the first control the keyboard.
func open() -> void:
	_sync()
	visible = true
	fit()
	display_option.grab_focus()


func close() -> void:
	if not visible:
		return
	PS.save()
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		accept_event()
		close()


# --- build ---------------------------------------------------------------------------------------

func _build_backdrop() -> void:
	var dim := ColorRect.new()
	dim.name = "Backdrop"
	dim.color = Color(0.02, 0.025, 0.04, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_backdrop_input)
	stage.add_child(dim)


func _on_backdrop_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		close()


func _build_panel() -> void:
	var panel := Control.new()
	panel.name = "Panel"
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.pivot_offset = PANEL_RECT.size * 0.5
	panel.rotation = TILT_RAD
	stage.add_child(panel)
	UI.surface(panel, T.ACCENT_ELECTRIC_CYAN)
	var badge := StreetStyle.badge("SYS // CONFIG")
	badge.name = "SysBadge"
	badge.position = Vector2(-26.0, -30.0)
	panel.add_child(badge)

	var header := UI.header("SYSTEM SETTINGS // PRESENTATION & AUDIO", T.ACCENT_ELECTRIC_CYAN)
	header.name = "Title"
	header.position = Vector2(40.0, 26.0)
	header.size = Vector2(PANEL_RECT.size.x - 80.0, 40.0)
	panel.add_child(header)

	_section(panel, "DISPLAY // RENDER", Vector2(LEFT_X, 96.0), T.ACCENT_ACID_LIME)
	_section(panel, "AUDIO MIXER // FIVE BUSES", Vector2(RIGHT_X, 96.0), T.ACCENT_ELECTRIC_CYAN)

	display_option = _option(["WINDOWED", "BORDERLESS", "FULLSCREEN"], "DisplayModeOption")
	_row(panel, "DISPLAY MODE", display_option, 140.0, LEFT_X)
	display_option.item_selected.connect(_on_display_mode)

	resolution_option = _option(PS.RESOLUTION_NAMES, "ResolutionOption")
	_row(panel, "RESOLUTION", resolution_option, 204.0, LEFT_X)
	resolution_option.item_selected.connect(_on_resolution)

	vsync_check = _check("V-SYNC", "VsyncCheck")
	vsync_check.toggled.connect(_on_vsync)
	_row(panel, "V-SYNC", vsync_check, 268.0, LEFT_X)

	_section(panel, "GRAPHICS PRESET", Vector2(LEFT_X, 340.0), T.ACCENT_ACID_LIME)
	quality_option = _option(PS.QUALITY_NAMES, "QualityOption")
	_row(panel, "PRESET", quality_option, 384.0, LEFT_X)
	quality_option.item_selected.connect(_on_quality)

	halftone_check = _check("MANGA HALFTONE", "HalftoneCheck")
	halftone_check.toggled.connect(_on_halftone)
	_row(panel, "SCREENTONE", halftone_check, 448.0, LEFT_X)

	vfx_check = _check("ANIME VFX DENSITY", "VfxCheck")
	vfx_check.toggled.connect(_on_vfx)
	_row(panel, "VFX DENSITY", vfx_check, 512.0, LEFT_X)

	reduce_motion_check = _check("REDUCE MOTION", "ReduceMotionCheck")
	reduce_motion_check.toggled.connect(_on_reduce_motion)
	_row(panel, "ACCESSIBILITY", reduce_motion_check, 576.0, LEFT_X)

	outline_label = UI.label("", 16, T.ACCENT_ACID_LIME, MONO)
	outline_label.name = "OutlineLabel"
	outline_label.position = Vector2(LEFT_X, 644.0)
	outline_label.size = Vector2(COLUMN_W, 24.0)
	panel.add_child(outline_label)

	for index: int in range(PS.BUSES.size()):
		_add_audio_row(panel, index)

	var hint := UI.label(
		"CHANGES APPLY IMMEDIATELY  //  ESC CLOSES",
		14, T.TEXT_MUTED, MONO
	)
	hint.position = Vector2(LEFT_X, 690.0)
	hint.size = Vector2(700.0, 22.0)
	panel.add_child(hint)

	close_button = UI.button("CLOSE  [ESC]", T.ACCENT_ACID_LIME)
	close_button.name = "CloseButton"
	StreetStyle.skin(close_button, 4, Vector2(6.0, 6.0), 24)
	var hot: StyleBox = close_button.get_theme_stylebox("pressed")
	close_button.add_theme_stylebox_override("normal", hot) # the way out wears the lime face
	close_button.add_theme_color_override("font_color", T.INK_BORDER_BLACK)
	close_button.add_theme_color_override("font_hover_color", T.INK_BORDER_BLACK)
	close_button.position = Vector2(960.0, 684.0)
	close_button.size = Vector2(256.0, 56.0)
	close_button.pressed.connect(close)
	panel.add_child(close_button)
	_chain_focus()


func _section(parent: Control, text: String, at: Vector2, fill: Color) -> Label:
	var node := StreetStyle.section(text, fill)
	node.position = at
	parent.add_child(node)
	return node


## One label + control row at `y`, in the column that starts at `x`.
func _row(parent: Control, text: String, control: Control, y: float, x: float) -> void:
	var caption := UI.label(text, 16, T.TEXT_SECONDARY, MONO)
	caption.position = Vector2(x, y)
	caption.size = Vector2(180.0, 40.0)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(caption)
	control.position = Vector2(x + 200.0, y + 4.0)
	control.size = Vector2(COLUMN_W - 200.0, 40.0)
	parent.add_child(control)


func _option(items: Array, node_name: String) -> OptionButton:
	var option := OptionButton.new()
	option.name = node_name
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	StreetStyle.skin(option, 3, Vector2(4.0, 4.0), 20)
	for item: String in items:
		option.add_item(item)
	return option


func _check(text: String, node_name: String) -> CheckButton:
	var check := CheckButton.new()
	check.name = node_name
	check.text = text
	check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	check.add_theme_font_override("font", HEADER)
	check.add_theme_font_size_override("font_size", 20)
	check.add_theme_color_override("font_color", T.TEXT_PRIMARY)
	check.add_theme_color_override("font_hover_color", T.ACCENT_ACID_LIME)
	check.add_theme_color_override("font_pressed_color", T.TEXT_PRIMARY)
	check.add_theme_color_override("font_focus_color", T.TEXT_PRIMARY)
	for state: String in ["checked", "checked_disabled"]:
		check.add_theme_icon_override(state, StreetStyle.switch_icon(true))
	for state: String in ["unchecked", "unchecked_disabled"]:
		check.add_theme_icon_override(state, StreetStyle.switch_icon(false))
	return check


func _add_audio_row(parent: Control, index: int) -> void:
	var bus: StringName = PS.BUSES[index]
	var y: float = 148.0 + float(index) * 92.0
	var caption := UI.label(PS.BUS_LABELS[index], 16, T.TEXT_SECONDARY, MONO)
	caption.position = Vector2(RIGHT_X, y)
	caption.size = Vector2(220.0, 24.0)
	parent.add_child(caption)
	var value := UI.label("100%", 18, T.ACCENT_ACID_LIME, DISPLAY)
	value.name = String(bus) + "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.position = Vector2(RIGHT_X + COLUMN_W - 90.0, y - 2.0)
	value.size = Vector2(90.0, 24.0)
	parent.add_child(value)
	var slider := HSlider.new()
	slider.name = String(bus) + "Slider"
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.focus_mode = Control.FOCUS_ALL
	slider.custom_minimum_size = Vector2(COLUMN_W, 30.0)
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.position = Vector2(RIGHT_X, y + 32.0)
	slider.size = Vector2(COLUMN_W, 30.0)
	StreetStyle.skin_slider(slider)
	slider.value_changed.connect(_on_volume.bind(bus))
	parent.add_child(slider)
	sliders[bus] = slider
	value_labels[bus] = value


## Tab and arrows walk the modal's own controls, never the menu behind it.
func _chain_focus() -> void:
	var chain: Array[Control] = [
		display_option, resolution_option, vsync_check, quality_option,
		halftone_check, vfx_check, reduce_motion_check, close_button,
	]
	for bus: StringName in PS.BUSES:
		chain.append(sliders[bus])
	for index: int in range(chain.size()):
		chain[index].focus_neighbor_top = chain[posmod(index - 1, chain.size())].get_path()
		chain[index].focus_neighbor_bottom = chain[posmod(index + 1, chain.size())].get_path()
		chain[index].focus_next = chain[posmod(index + 1, chain.size())].get_path()
		chain[index].focus_previous = chain[posmod(index - 1, chain.size())].get_path()


# --- state ---------------------------------------------------------------------------------------

func _sync() -> void:
	display_option.select(PS.display_mode)
	resolution_option.select(PS.resolution)
	vsync_check.set_pressed_no_signal(PS.vsync)
	quality_option.select(PS.quality)
	halftone_check.set_pressed_no_signal(PS.halftone)
	vfx_check.set_pressed_no_signal(PS.vfx_high)
	reduce_motion_check.set_pressed_no_signal(PS.reduce_motion)
	_refresh_labels()
	for bus: StringName in PS.BUSES:
		var slider: HSlider = sliders[bus]
		slider.set_value_no_signal(PS.volume(bus))
		var label: Label = value_labels[bus]
		label.text = "%d%%" % roundi(PS.volume(bus) * 100.0)


func _refresh_labels() -> void:
	var full: bool = PS.quality >= PS.Quality.HIGH
	outline_label.text = "TOON INK OUTLINE // %s" % ("FULL 0.02 m" if full else "PERFORMANCE 0.012 m")
	halftone_check.text = "MANGA HALFTONE // " + ("ON" if PS.halftone else "OFF")
	vfx_check.text = "ANIME VFX // " + ("HIGH" if PS.vfx_high else "LOW")
	reduce_motion_check.text = "REDUCE MOTION // " + ("ON" if PS.reduce_motion else "OFF")
	vsync_check.text = "V-SYNC // " + ("ON (60 FPS)" if PS.vsync else "OFF")


func _on_display_mode(index: int) -> void:
	PS.display_mode = index
	PS.apply_display()
	PS.save()


func _on_resolution(index: int) -> void:
	PS.resolution = index
	PS.apply_display()
	PS.save()


func _on_vsync(pressed: bool) -> void:
	PS.vsync = pressed
	PS.apply_display()
	_refresh_labels()
	PS.save()


func _on_quality(index: int) -> void:
	PS.set_quality(index)
	_sync()
	PS.apply_to_tree(get_tree().root)
	PS.save()


func _on_halftone(pressed: bool) -> void:
	PS.halftone = pressed
	_refresh_labels()
	PS.apply_to_tree(get_tree().root)
	PS.save()


func _on_reduce_motion(pressed: bool) -> void:
	PS.reduce_motion = pressed
	_refresh_labels()
	PS.save()


func _on_vfx(pressed: bool) -> void:
	PS.vfx_high = pressed
	_refresh_labels()
	PS.apply_to_tree(get_tree().root)
	PS.save()


func _on_volume(value: float, bus: StringName) -> void:
	PS.set_volume(bus, value)
	var label: Label = value_labels[bus]
	label.text = "%d%%" % roundi(value * 100.0)
