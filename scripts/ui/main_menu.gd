class_name MainMenu
extends Control

## Title menu (spec §2.1): a dim neon pit garage in 3D behind the neo-brutalist manga
## stack. Only one showcase car is built (GarageEnvironmentBuilder.build(1)) and a
## turntable orbit spins it; the buttons open the race setup, the settings modal, the
## credits dialog and the quit confirmation. Keyboard focus starts on EXHIBITION RACE.

const UI := preload("res://scripts/ui/pit_wall_ui.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const PS := preload("res://scripts/core/presentation_settings.gd")
const ConfigData := preload("res://scripts/core/race_config_data.gd")
const GarageBuilder := preload("res://scripts/world/garage_environment_builder.gd")
const GarageOrbit := preload("res://scripts/ui/garage_car_orbit.gd")
const SprayHaloScript := preload("res://scripts/ui/spray_halo.gd")
const SettingsScene := preload("res://scenes/ui/settings_modal.tscn")
const HEADER := preload("res://assets/fonts/BarlowCondensed.ttf")
const MONO := preload("res://assets/fonts/JetBrainsMono.ttf")
const DISPLAY := preload("res://assets/fonts/Anton.ttf")

const SETUP_SCENE := "res://scenes/ui/race_setup_menu.tscn"
const STAGE := Vector2(1920.0, 1080.0)

## Concept 01 "Street Tag & Speed Stencil": everything leans -12 degrees (0.21 rad), modals -4.
const SLANT_RAD: float = -0.21
const MODAL_TILT_RAD: float = -0.0698 # -4 degrees
const TITLE_POSITION := Vector2(112.0, 130.0)
const SUBTAG := "/// GT3 // RACING SYNDICATE // TOON MOTORSPORT"
const BUTTON_PREFIX := "/// "
const BUTTON_SIZE := Vector2(620.0, 74.0)
const BUTTON_FILL := Color("#141722")
const BUTTON_BORDER_PX: int = 4
const BUTTON_SHADOW := Vector2(6.0, 6.0)
const BUTTON_HOVER_SHADOW := Vector2(8.0, 8.0)
const BUTTON_HOVER_SHIFT := Vector2(6.0, -2.0)
const BUTTON_SETTLE_S: float = 0.12

const CREDITS: Array[String] = [
	"LA VOITURE // NEO-BRUTALIST GT3 STRATEGY SIMULATOR",
	"",
	"DESIGN & ENGINE          LA VOITURE STUDIO",
	"3D VEHICLES              MESHY AI + BLENDER PIPELINE",
	"TOON SHADING            CEL SHADE + INVERTED HULL INK",
	"AUDIO SUITE             SYNTHWAVE + GENERATED SFX",
	"ENGINE                  GODOT 4.7 // GT SIM PORT",
	"",
	"THANK YOU FOR RACING THE PADDOCK.",
]

var stage: Control
var camera: Camera3D
var garage: GarageBuilder
var orbit: GarageOrbit
var fps_label: Label
var exhibition_button: Button
var settings_button: Button
var credits_button: Button
var quit_button: Button
var career_button: Button
var settings: Variant
var _dialog: Control
var _dialog_buttons: Array[Button] = []
var _dialog_opener: Button
var _engine_text: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_engine_text = String(Engine.get_version_info()["string"])
	# The app controller root must not eat pointer events, or the garage orbit never sees a drag.
	var host := get_parent() as Control
	if host != null:
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PS.bootstrap()
	_build_garage()
	_build_stage()
	PS.apply_to_tree(self)
	AudioManager.of(self).start_music()


func _process(_delta: float) -> void:
	if fps_label != null:
		fps_label.text = "FPS %03d  //  GODOT %s" % [Engine.get_frames_per_second(), _engine_text]


# --- ambient 3D garage ---------------------------------------------------------------------------

func _build_garage() -> void:
	var world := Node3D.new()
	world.name = "AmbientGarage"
	add_child(world)

	var holder := WorldEnvironment.new()
	holder.name = "AmbientEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = T.BG_CANVAS_DEEP
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#33415C")
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_bloom = 0.12
	environment.fog_enabled = true
	environment.fog_light_color = Color("#0B1220")
	environment.fog_density = 0.008
	environment.fog_sky_affect = 0.0
	holder.environment = environment
	world.add_child(holder)

	camera = Camera3D.new()
	camera.name = "ShowroomCamera"
	camera.fov = 42.0
	world.add_child(camera)
	camera.current = true

	var sun := DirectionalLight3D.new()
	sun.name = "KeyLight"
	sun.rotation_degrees = Vector3(-42.0, -128.0, 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color("#DCE8FF")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	world.add_child(sun)

	var rim := OmniLight3D.new()
	rim.name = "NeonRim"
	rim.light_color = T.ACCENT_ELECTRIC_CYAN
	rim.light_energy = 5.0
	rim.omni_range = 16.0
	rim.position = Vector3(-4.0, 2.6, 3.4)
	world.add_child(rim)

	var warm := OmniLight3D.new()
	warm.name = "AcidFill"
	warm.light_color = T.ACCENT_ACID_LIME
	warm.light_energy = 2.2
	warm.omni_range = 12.0
	warm.position = Vector3(4.5, 1.8, -3.0)
	world.add_child(warm)

	orbit = GarageOrbit.new()
	orbit.name = "TurntableOrbit"
	world.add_child(orbit)
	orbit.setup(camera)
	orbit.idle_spin_speed = 0.12
	orbit.drag_enabled = true

	garage = GarageBuilder.new()
	garage.name = "ShowroomStall"
	world.add_child(garage)
	garage.build(1)
	if not garage.cars.is_empty():
		orbit.focus(garage.cars[0], true)


# --- UI ------------------------------------------------------------------------------------------

func _build_stage() -> void:
	stage = Control.new()
	stage.name = "Stage"
	stage.size = STAGE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var shade := ColorRect.new()
	shade.color = Color(T.BG_CANVAS_DEEP, 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(shade)

	var halo := SprayHaloScript.new()
	halo.name = "SprayHalo"
	halo.position = TITLE_POSITION + Vector2(330.0, 90.0)
	stage.add_child(halo)

	# Black offset shadow and an acid edge sit behind the inked title as copies of it.
	for layer: Array in [["BrandTitleShadow", Vector2(6.0, 6.0), Color.BLACK], ["BrandTitleEdge", Vector2(-3.0, -1.0), T.ACCENT_ACID_LIME]]:
		var echo := _title_label(String(layer[0]), layer[2])
		echo.position = TITLE_POSITION + (layer[1] as Vector2)
		stage.add_child(echo)
	var brand := _title_label("BrandTitle", T.TEXT_PRIMARY)
	brand.position = TITLE_POSITION
	stage.add_child(brand)

	var subtag := UI.label(SUBTAG, 24, T.ACCENT_ELECTRIC_CYAN, HEADER)
	subtag.name = "Subtag"
	subtag.position = Vector2(130.0, 346.0)
	subtag.rotation = SLANT_RAD
	subtag.add_theme_constant_override("outline_size", 6)
	subtag.add_theme_color_override("font_outline_color", T.INK_BORDER_BLACK)
	stage.add_child(subtag)
	var build := UI.label("EXHIBITION BUILD 1.0  //  PIT LANE, 22:40", 14, T.TEXT_MUTED, MONO)
	build.position = Vector2(118.0, 380.0)
	stage.add_child(build)

	_build_buttons()
	_build_status()
	get_viewport().size_changed.connect(fit)
	fit()


func _build_buttons() -> void:
	var y: float = 430.0
	exhibition_button = _menu_button("EXHIBITION RACE", T.ACCENT_ACID_LIME, y)
	exhibition_button.name = "ExhibitionButton"
	exhibition_button.pressed.connect(_on_exhibition_pressed)
	_build_career_button(y + 92.0)
	settings_button = _menu_button("SETTINGS", T.ACCENT_ELECTRIC_CYAN, y + 184.0)
	settings_button.name = "SettingsButton"
	settings_button.pressed.connect(_on_settings_pressed)
	credits_button = _menu_button("CREDITS", T.ACCENT_PURPLE_SECTOR, y + 276.0)
	credits_button.name = "CreditsButton"
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button = _menu_button("QUIT TO DESKTOP", T.ACCENT_ANIME_CRIMSON, y + 368.0)
	quit_button.name = "QuitButton"
	quit_button.pressed.connect(_on_quit_pressed)
	_focus_ring()


func _title_label(node_name: String, color: Color) -> Label:
	var label := UI.label("LA VOITURE", 156, color, DISPLAY)
	label.name = node_name
	label.rotation = SLANT_RAD
	label.add_theme_constant_override("outline_size", 14)
	label.add_theme_color_override("font_outline_color", T.INK_BORDER_BLACK if node_name == "BrandTitle" else color)
	return label


## One parallelogram plate: dark fill, 4 px ink border, solid 6 px shadow. Hover and focus snap it
## forward onto an acid-lime face with a crimson shadow, black type.
func _plate(fill: Color, shadow: Color, shadow_offset: Vector2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_border_width_all(BUTTON_BORDER_PX)
	box.border_color = T.INK_BORDER_BLACK
	box.skew = Vector2(SLANT_RAD, 0.0)
	box.shadow_color = shadow
	box.shadow_size = 1 # a blur of 1 px reads as a hard offset shadow
	box.shadow_offset = shadow_offset
	box.content_margin_left = 44.0
	box.content_margin_right = 24.0
	return box


func _menu_button(text: String, accent: Color, y: float) -> Button:
	var button := UI.button(BUTTON_PREFIX + text, accent)
	button.position = Vector2(118.0, y)
	button.size = BUTTON_SIZE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 32)
	button.add_theme_constant_override("outline_size", 0)
	var rest := _plate(BUTTON_FILL, Color.BLACK, BUTTON_SHADOW)
	button.add_theme_stylebox_override("normal", rest)
	button.add_theme_stylebox_override("disabled", rest)
	for state: String in ["hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, _plate(T.ACCENT_ACID_LIME, T.ACCENT_ANIME_CRIMSON, BUTTON_HOVER_SHADOW))
	button.add_theme_color_override("font_color", T.TEXT_PRIMARY)
	button.set_meta(&"home", button.position)
	button.mouse_entered.connect(_lift_button.bind(button, true))
	button.mouse_exited.connect(func() -> void:
		if not button.has_focus():
			_lift_button(button, false)
	)
	button.focus_entered.connect(_lift_button.bind(button, true))
	button.focus_exited.connect(func() -> void:
		if not button.is_hovered():
			_lift_button(button, false)
	)
	stage.add_child(button)
	# The accent rides along as a lean tab in front of the type.
	var tab := Polygon2D.new()
	tab.name = "AccentTab"
	tab.color = accent
	tab.polygon = PackedVector2Array([Vector2(14.0, 14.0), Vector2(24.0, 14.0), Vector2(14.0, BUTTON_SIZE.y - 14.0), Vector2(4.0, BUTTON_SIZE.y - 14.0)])
	button.add_child(tab)
	return button


## Snaps to the lifted pose at once; the way back settles over a tenth of a second.
func _lift_button(button: Button, lifted: bool) -> void:
	var tween: Tween = button.get_meta(&"lift_tween") if button.has_meta(&"lift_tween") else null
	if tween != null:
		tween.kill()
	var home: Vector2 = button.get_meta(&"home")
	if lifted:
		button.position = home + BUTTON_HOVER_SHIFT
		return
	tween = button.create_tween()
	tween.tween_property(button, "position", home, BUTTON_SETTLE_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	button.set_meta(&"lift_tween", tween)


func _build_career_button(y: float) -> void:
	career_button = _menu_button("CAREER MODE", T.ACCENT_CYBER_YELLOW, y)
	career_button.name = "CareerButton"
	career_button.disabled = true
	career_button.focus_mode = Control.FOCUS_NONE
	career_button.add_theme_color_override("font_disabled_color", T.TEXT_MUTED)
	var strip := _hazard(Vector2(212.0, 34.0))
	strip.position = Vector2(356.0, 21.0)
	career_button.add_child(strip)
	var soon := UI.label("COMING SOON", 18, T.TEXT_PRIMARY, HEADER)
	soon.add_theme_color_override("font_outline_color", T.INK_BORDER_BLACK)
	soon.add_theme_constant_override("outline_size", 5)
	soon.position = Vector2(372.0, 26.0)
	career_button.add_child(soon)


func _build_status() -> void:
	fps_label = UI.label("", 14, T.TEXT_MUTED, MONO)
	fps_label.name = "FpsLabel"
	fps_label.position = Vector2(118.0, 1008.0)
	stage.add_child(fps_label)
	var hint := UI.label("DRAG THE CAR TO ORBIT  //  ARROWS NAVIGATE  //  ENTER SELECT", 14, T.TEXT_MUTED, MONO)
	hint.position = Vector2(118.0, 1036.0)
	stage.add_child(hint)
	var stamp: Control = UI.header("STALL 01 // SHOWROOM", T.ACCENT_ACID_LIME)
	stamp.position = Vector2(1460.0, 64.0)
	stamp.size = Vector2(360.0, 40.0)
	stage.add_child(stamp)


func _focus_ring() -> void:
	var chain: Array[Button] = [exhibition_button, settings_button, credits_button, quit_button]
	for index: int in range(chain.size()):
		chain[index].focus_next = chain[(index + 1) % chain.size()].get_path()
		chain[index].focus_previous = chain[(index + chain.size() - 1) % chain.size()].get_path()
		chain[index].focus_neighbor_bottom = chain[(index + 1) % chain.size()].get_path()
		chain[index].focus_neighbor_top = chain[(index + chain.size() - 1) % chain.size()].get_path()
	exhibition_button.grab_focus()


func fit() -> void:
	if stage == null or not is_inside_tree():
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var factor: float = minf(view.x / STAGE.x, view.y / STAGE.y)
	stage.scale = Vector2(factor, factor)
	stage.position = (view - STAGE * factor) * 0.5


func _hazard(size_px: Vector2) -> Control:
	var strip := Control.new()
	strip.size = size_px
	strip.clip_contents = true
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.draw.connect(func() -> void:
		strip.draw_rect(Rect2(Vector2.ZERO, strip.size), T.INK_BORDER_BLACK, true)
		var width: float = 12.0
		var gap: float = 10.0
		var x: float = -strip.size.y
		while x < strip.size.x + strip.size.y:
			strip.draw_colored_polygon(PackedVector2Array([
				Vector2(x, strip.size.y),
				Vector2(x + width, strip.size.y),
				Vector2(x + width + strip.size.y, 0.0),
				Vector2(x + strip.size.y, 0.0),
			]), T.ACCENT_CYBER_YELLOW)
			x += width + gap
	)
	strip.resized.connect(strip.queue_redraw)
	return strip


# --- actions -------------------------------------------------------------------------------------

func _on_exhibition_pressed() -> void:
	AudioManager.click(self)
	ConfigData.reset()
	_go(SETUP_SCENE)


func _on_settings_pressed() -> void:
	AudioManager.click(self)
	_open_settings()


func _on_credits_pressed() -> void:
	AudioManager.click(self)
	_open_dialog("CREDITS // PADDOCK", CREDITS, [
		{"text": "CLOSE  [ESC]", "accent": T.ACCENT_ACID_LIME, "action": _close_dialog},
	], credits_button, "SYS // CREDITS")


func _on_quit_pressed() -> void:
	AudioManager.click(self)
	_open_dialog("QUIT TO DESKTOP?", [
		"THE SESSION WILL END.",
		"PRESENTATION SETTINGS ARE SAVED AUTOMATICALLY.",
		"",
		"SEE YOU IN THE PIT LANE.",
	], [
		{"text": "CANCEL  [ESC]", "accent": T.ACCENT_ELECTRIC_CYAN, "action": _close_dialog},
		{"text": "QUIT NOW", "accent": T.ACCENT_ANIME_CRIMSON, "action": _quit_now},
	], quit_button, "SYS // EXIT")


func _quit_now() -> void:
	get_tree().quit()


func _go(path: String) -> void:
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("MainMenu: cannot open %s (%s)" % [path, error_string(error)])


func _unhandled_input(event: InputEvent) -> void:
	if settings != null and settings.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _dialog != null:
			accept_event()
			_close_dialog()


# --- dialogs -------------------------------------------------------------------------------------

func _open_dialog(title: String, lines: Array[String], actions: Array, opener: Button, badge_text: String = "SYS // CONFIG") -> void:
	if _dialog != null:
		return
	_dialog_opener = opener
	_lock_menu_buttons()
	_dialog = Control.new()
	_dialog.name = "Dialog"
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_dialog)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.04, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			_close_dialog()
	)
	_dialog.add_child(dim)

	var panel := Control.new()
	panel.name = "DialogPanel"
	panel.position = Vector2(470.0, 258.0)
	panel.size = Vector2(980.0, 564.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.pivot_offset = panel.size * 0.5
	panel.rotation = MODAL_TILT_RAD # an inspection tag hung slightly off true
	_dialog.add_child(panel)
	UI.surface(panel, T.ACCENT_ACID_LIME)
	var header: Control = UI.header(title, T.ACCENT_ACID_LIME)
	header.position = Vector2(30.0, 26.0)
	header.size = Vector2(920.0, 40.0)
	panel.add_child(header)
	var badge := UI.label(badge_text, 18, T.TEXT_PRIMARY, HEADER)
	badge.name = "SysBadge"
	badge.position = Vector2(-18.0, -22.0)
	var badge_plate := _plate(T.ACCENT_ANIME_CRIMSON, Color.BLACK, Vector2(4.0, 4.0))
	badge_plate.content_margin_left = 16.0
	badge_plate.content_margin_right = 16.0
	badge.add_theme_stylebox_override("normal", badge_plate)
	badge.add_theme_constant_override("outline_size", 0)
	badge.rotation = SLANT_RAD * 0.25
	panel.add_child(badge)
	var body := UI.label("\n".join(lines), 18, T.TEXT_PRIMARY, MONO)
	body.position = Vector2(34.0, 96.0)
	body.size = Vector2(912.0, 340.0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(body)

	_dialog_buttons.clear()
	var x: float = 34.0
	for entry: Dictionary in actions:
		var button := UI.button(String(entry["text"]), entry["accent"])
		button.size = Vector2(260.0, 58.0)
		button.position = Vector2(x, 470.0)
		var action: Callable = entry["action"]
		button.pressed.connect(action)
		panel.add_child(button)
		_dialog_buttons.append(button)
		x += 276.0
	_chain_dialog_focus()
	PS.apply_to_tree(_dialog)
	if not _dialog_buttons.is_empty():
		_dialog_buttons[0].grab_focus()


func _chain_dialog_focus() -> void:
	for index: int in range(_dialog_buttons.size()):
		_dialog_buttons[index].focus_next = _dialog_buttons[(index + 1) % _dialog_buttons.size()].get_path()
		_dialog_buttons[index].focus_previous = _dialog_buttons[(index + _dialog_buttons.size() - 1) % _dialog_buttons.size()].get_path()


func _close_dialog() -> void:
	if _dialog == null:
		return
	_dialog.queue_free()
	_dialog = null
	_dialog_buttons.clear()
	_unlock_menu_buttons()
	if is_instance_valid(_dialog_opener):
		_dialog_opener.grab_focus()


func _lock_menu_buttons() -> void:
	for button: Button in [exhibition_button, settings_button, credits_button, quit_button]:
		button.focus_mode = Control.FOCUS_NONE


func _unlock_menu_buttons() -> void:
	for button: Button in [exhibition_button, settings_button, credits_button, quit_button]:
		button.focus_mode = Control.FOCUS_ALL


# --- settings modal ------------------------------------------------------------------------------

func _open_settings() -> void:
	if settings == null:
		settings = SettingsScene.instantiate()
		settings.closed.connect(_on_settings_closed)
		add_child(settings)
	PS.apply_to_tree(settings)
	_lock_menu_buttons()
	settings.open()


func _on_settings_closed() -> void:
	_unlock_menu_buttons()
	if is_instance_valid(settings_button):
		settings_button.grab_focus()
