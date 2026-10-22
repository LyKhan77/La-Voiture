class_name MangaRaceTransition
extends CanvasLayer

## Pre-race cut-in: the garage's last rendered frame snapped to a monochrome negative,
## three slanted manga panels over it, then a screentone wipe onto the grid fly-through.
## The race world loads threaded while the panels cover the screen, so its 20 cars and
## their streams never hitch the art. The transition hands itself to the world, drives
## the pre-grid camera hold through `grid_intro_progress`, then frees itself, which is
## also what releases the countdown at the very end of the fly-through.

const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const Roster := preload("res://scripts/ui/garage_roster.gd")
const Data := preload("res://scripts/gt/gt_data.gd")
const UI := preload("res://scripts/ui/pit_wall_ui.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const ROAR: AudioStream = preload("res://assets/audio/engine/gt3_engine_loop.wav")

const WORLD_PATH := "res://scenes/race_weekend_world.tscn"
const MENU_PATH := "res://scenes/ui/main_menu.tscn"

const FLASH_SEC := 0.1
const PANELS_SEC := 0.8
const WIPE_SEC := 1.2
const LOAD_TIMEOUT_SEC := 20.0

const INK := T.INK_BORDER_BLACK
const PAPER := T.SURFACE_SNAP_INVERT
const ACID := T.ACCENT_ACID_LIME
const CYAN := T.ACCENT_ELECTRIC_CYAN
const BLOOD := T.ACCENT_ANIME_CRIMSON

## Region of a radio portrait that frames both eyes.
const EYE_UV := Rect2(0.16, 0.32, 0.68, 0.2)

enum State { FLASH, PANELS, WAIT_WORLD, WIPE, ERROR, DONE }

## The garage's last rendered frame, captured by the garage just before it swaps scenes.
static var snapshot: ImageTexture


## Copies the rendered frame into `snapshot`. The garage calls this after
## `await RenderingServer.frame_post_draw` and before changing to this scene, so the
## negative flash is the real garage frame rather than a stand-in. Headless keeps it null.
static func capture_snapshot(viewport: Viewport) -> void:
	if viewport == null:
		return
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return
	snapshot = ImageTexture.create_from_image(image)


class CutPanel extends Node2D:
	var size := Vector2.ZERO
	var home := Vector2.ZERO
	var slide := Vector2.ZERO
	var home_rotation := 0.0
	var spin := 0.0
	var delay := 0.0


@onready var _backdrop: ColorRect = $Backdrop
@onready var _snapshot: TextureRect = $Snapshot
@onready var _flash: ColorRect = $Flash
@onready var _cut_in: Node2D = $CutIn
@onready var _panel_root: Node2D = $CutIn/Panels
@onready var _speedlines: ColorRect = $CutIn/Speedlines
@onready var _wipe: ColorRect = $Wipe
@onready var _error_box: Control = $ErrorBox
@onready var _error_label: Label = $ErrorBox/Box/Message
@onready var _back_button: Button = $ErrorBox/Box/Back
@onready var _roar: AudioStreamPlayer = $EngineRoar

var _state: int = State.FLASH
var _screen := Vector2(1920.0, 1080.0)
var _team: int = 0
var _clock: float = 0.0
var _rev: float = 0.0
var _wait_clock: float = 0.0
var _wipe_clock: float = 0.0
var _load_failed: bool = false
var _panels: Array[CutPanel] = []
var _wipe_mat: ShaderMaterial
var _world: Node


func _ready() -> void:
	var config: RefCounted = ConfigScript.get_config()
	_team = clampi(int(config.get("selected_team_id")), 0, Data.TEAM_NAMES.size() - 1)
	_screen = get_viewport().get_visible_rect().size
	_wipe_mat = _wipe.material as ShaderMaterial
	_back_button.pressed.connect(_on_back_pressed)
	_build_panels()
	_apply_panels(0.0)
	_wipe.visible = false
	_error_box.visible = false
	_speedlines.size = _screen
	_show_flash()
	_start_roar()
	_request_world()


## The visible intro: the real frame when the garage supplied one, a white snap otherwise.
func _show_flash() -> void:
	if snapshot != null:
		_snapshot.texture = snapshot
		snapshot = null # one garage frame per launch; never reuse a stale one
		_snapshot.visible = true
		_flash.visible = false
	else:
		_snapshot.visible = false
		_flash.visible = true
	_cut_in.visible = false
	# The snap is exactly one rendered frame, not a hold: the moment it has been drawn the
	# black backdrop takes over for the rest of the beat. Headless never draws, so skip.
	if DisplayServer.get_name() != "headless":
		RenderingServer.frame_post_draw.connect(_on_flash_drawn, CONNECT_ONE_SHOT)


func _on_flash_drawn() -> void:
	_snapshot.visible = false
	_flash.visible = false


func _start_roar() -> void:
	_roar.stream = ROAR
	_roar.volume_db = 0.0
	_roar.pitch_scale = 1.35
	if AudioManager.has_output():
		_roar.play()


func _request_world() -> void:
	var error: int = ResourceLoader.load_threaded_request(WORLD_PATH, "PackedScene")
	if error != OK and error != ERR_BUSY:
		_load_failed = true


func _process(delta: float) -> void:
	match _state:
		State.FLASH:
			_rev += delta
			_clock += delta
			_roar.pitch_scale = lerpf(1.35, 1.12, clampf(_rev / FLASH_SEC, 0.0, 1.0))
			if _clock >= FLASH_SEC:
				_enter_panels()
		State.PANELS:
			_rev += delta
			_clock += delta
			var panels_t: float = clampf(_clock / PANELS_SEC, 0.0, 1.0)
			_apply_panels(panels_t)
			_roar.pitch_scale = lerpf(1.12, 0.78, panels_t)
			if panels_t >= 1.0:
				_state = State.WAIT_WORLD
				_wait_clock = 0.0
		State.WAIT_WORLD:
			_wait_clock += delta
			if _wait_clock >= LOAD_TIMEOUT_SEC:
				_fail("The race scene took too long to load.")
				return
			_poll_world()
		State.WIPE:
			_wipe_clock += delta
			var wipe_t: float = clampf(_wipe_clock / WIPE_SEC, 0.0, 1.0)
			_set_wipe(wipe_t)
			_roar.volume_db = lerpf(0.0, -34.0, wipe_t)
			if wipe_t >= 1.0:
				_finish()


func _enter_panels() -> void:
	_state = State.PANELS
	_clock = 0.0
	_snapshot.visible = false
	_flash.visible = false
	_cut_in.visible = true
	_apply_panels(0.0)


func _poll_world() -> void:
	if _load_failed:
		_fail("The race scene could not be loaded.")
		return
	var status: int = ResourceLoader.load_threaded_get_status(WORLD_PATH)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		_fail("The race scene could not be loaded.")
		return
	var packed := ResourceLoader.load_threaded_get(WORLD_PATH) as PackedScene
	if packed == null:
		_fail("The race scene could not be loaded.")
		return
	_hand_over(packed)


## Swaps the comic frame for the real grid: the world becomes the current scene with the
## player's config and the start hold on, the transition reparents under it (so it keeps
## drawing above the 3D scene and dies with it), and the screentone wipe opens.
func _hand_over(packed: PackedScene) -> void:
	var world := packed.instantiate()
	if world == null:
		_fail("The race scene could not be instantiated.")
		return
	_world = world
	world.set("race_config", ConfigScript.get_config())
	world.set("pre_grid_hold", true)
	world.set("grid_intro_progress", 0.0)
	var tree := get_tree()
	tree.root.add_child(world)
	var hud: Node = world.get("hud")
	if hud != null:
		hud.call("set_shown", false)
	tree.current_scene = world
	var old_parent := get_parent()
	if old_parent != null:
		old_parent.remove_child(self)
	world.add_child(self)
	_backdrop.visible = false
	_cut_in.visible = false
	_wipe.visible = true
	_set_wipe(0.0)
	_state = State.WIPE
	_wipe_clock = 0.0


func _set_wipe(progress: float) -> void:
	if _wipe_mat != null:
		_wipe_mat.set_shader_parameter("progress", progress)
	if _world != null:
		_world.set("grid_intro_progress", progress)


## The fly-through has reached the grid: the HUD comes back, the countdown is released,
## and the transition leaves nothing behind.
func _finish() -> void:
	_state = State.DONE
	if _world != null:
		_set_wipe(1.0)
		var hud: Node = _world.get("hud")
		if hud != null:
			hud.call("set_shown", true)
		_world.call("finish_grid_intro")
	_roar.stop()
	queue_free()


func _fail(message: String) -> void:
	if _state == State.ERROR or _state == State.DONE:
		return
	_state = State.ERROR
	_roar.stop()
	_snapshot.visible = false
	_flash.visible = false
	_cut_in.visible = false
	_wipe.visible = false
	_backdrop.visible = true
	_error_label.text = message
	_error_box.visible = true
	_back_button.grab_focus()


func _on_back_pressed() -> void:
	AudioManager.click(self)
	get_tree().change_scene_to_file(MENU_PATH)


# --- comic panels ----------------------------------------------------------------

func _build_panels() -> void:
	var width: float = _screen.x * 1.45
	var height: float = _screen.y * 0.44
	var slot1: int = _team * 2
	var slot2: int = slot1 + 1

	var top := _new_panel(0, Vector2(_screen.x * 0.44, _screen.y * 0.23), Vector2(-width * 1.05, 0.0), -7.5, 0.14, 0.0, width, height)
	_dress_eye_panel(top, slot1, PAPER, INK, true, PAPER)
	var middle := _new_panel(1, Vector2(_screen.x * 0.56, _screen.y * 0.53), Vector2(width * 1.05, 0.0), 6.0, -0.12, 0.1, width, height)
	_dress_eye_panel(middle, slot2, INK, PAPER, false, CYAN.lightened(0.45))
	var bottom := _new_panel(2, Vector2(_screen.x * 0.47, _screen.y * 0.85), Vector2(-width * 1.05, _screen.y * 0.12), -4.5, 0.1, 0.2, width, height)
	_dress_number_panel(bottom)


func _new_panel(index: int, home: Vector2, slide: Vector2, rotation_deg: float, spin: float, delay: float, width: float, height: float) -> CutPanel:
	var panel := CutPanel.new()
	panel.name = "Panel%d" % index
	panel.size = Vector2(width, height)
	panel.home = home
	panel.slide = slide
	panel.home_rotation = deg_to_rad(rotation_deg)
	panel.spin = spin
	panel.delay = delay
	panel.rotation = panel.home_rotation
	panel.position = home
	panel.z_index = index
	_panel_root.add_child(panel)
	_panels.append(panel)
	return panel


## Eye close-up on one side of the panel, driver identity on the other.
func _dress_eye_panel(panel: CutPanel, slot: int, bg: Color, text_color: Color, eye_at_right: bool, tint: Color) -> void:
	var width: float = panel.size.x
	var height: float = panel.size.y
	_add_frame(panel, width, height)
	_add_body(panel, bg, width, height)

	var path: String = Roster.portrait_path(slot)
	var portrait: Texture2D = null
	if path != "":
		portrait = load(path) as Texture2D
	if portrait != null:
		var eye := Polygon2D.new()
		eye.texture = portrait
		eye.polygon = _eye_polygon(width, height, eye_at_right)
		eye.uv = _eye_uv(portrait.get_size())
		eye.color = tint
		panel.add_child(eye)

	var text_x: float = -width * 0.25 if eye_at_right else width * 0.10
	var tag_size: int = maxi(18, int(height * 0.075))
	var name_size: int = maxi(28, int(height * 0.19))
	var number_size: int = maxi(24, int(height * 0.15))
	_add_label(panel, Data.TEAM_NAMES[_team].to_upper(), UI.HEADER, tag_size, text_color, Vector2(text_x, -height * 0.42), -0.04)
	_add_label(panel, Data.DRIVER_NAMES[slot].to_upper(), UI.DISPLAY, name_size, text_color, Vector2(text_x, -height * 0.2), -0.05)
	var accent: Color = BLOOD if text_color == INK else ACID
	_add_label(panel, "#%02d  %s" % [slot + 1, Data.DRIVER_CODES[slot]], UI.DISPLAY, number_size, accent, Vector2(text_x, height * 0.2), -0.05)


## The pair's numbers in graffiti, with a bolt and the launch tag.
func _dress_number_panel(panel: CutPanel) -> void:
	var width: float = panel.size.x
	var height: float = panel.size.y
	_add_frame(panel, width, height)
	_add_body(panel, ACID, width, height)

	var number1: String = "%02d" % (_team * 2 + 1)
	var number2: String = "%02d" % (_team * 2 + 2)
	var big: int = maxi(64, int(height * 0.62))
	var base := Vector2(-width * 0.24, -height * 0.4)
	_add_label(panel, number1, UI.DISPLAY, big, BLOOD, base + Vector2(8.0, 10.0), -0.09)
	_add_label(panel, number1, UI.DISPLAY, big, INK, base, -0.09)
	_add_label(panel, number2, UI.DISPLAY, int(big * 0.66), INK, Vector2(width * 0.06, -height * 0.20), -0.07)
	_add_label(panel, Data.TEAM_NAMES[_team].to_upper(), UI.HEADER, maxi(18, int(height * 0.08)), INK, Vector2(-width * 0.24, -height * 0.46), -0.03)
	_add_label(panel, "LAUNCH TO GRID", UI.HEADER, maxi(20, int(height * 0.09)), BLOOD, Vector2(width * 0.04, -height * 0.46), -0.05)

	var scale: float = height * 0.8
	var bolt := Polygon2D.new()
	bolt.color = BLOOD
	bolt.position = Vector2(width * 0.33, -height * 0.04)
	bolt.polygon = PackedVector2Array([
		Vector2(-0.02, -0.30) * scale, Vector2(0.08, -0.30) * scale,
		Vector2(0.03, -0.05) * scale, Vector2(0.11, -0.05) * scale,
		Vector2(-0.05, 0.30) * scale, Vector2(-0.01, 0.04) * scale,
		Vector2(-0.09, 0.04) * scale,
	])
	panel.add_child(bolt)


func _add_frame(panel: CutPanel, width: float, height: float) -> void:
	var frame := Polygon2D.new()
	frame.color = INK
	frame.polygon = _rect_polygon(width + 14.0, height + 14.0)
	frame.z_index = -1
	panel.add_child(frame)


func _add_body(panel: CutPanel, color: Color, width: float, height: float) -> void:
	var body := Polygon2D.new()
	body.color = color
	body.polygon = _rect_polygon(width, height)
	panel.add_child(body)


func _add_label(panel: CutPanel, text: String, font: Font, font_size: int, color: Color, pos: Vector2, rotation_rad: float = 0.0) -> Label:
	var label := UI.label(text, font_size, color, font)
	label.position = pos
	label.rotation = rotation_rad
	panel.add_child(label)
	return label


func _rect_polygon(width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-width * 0.5, -height * 0.5), Vector2(width * 0.5, -height * 0.5),
		Vector2(width * 0.5, height * 0.5), Vector2(-width * 0.5, height * 0.5),
	])


func _eye_polygon(width: float, height: float, eye_at_right: bool) -> PackedVector2Array:
	var x0: float = -width * 0.5 + width * (0.36 if eye_at_right else 0.0)
	var x1: float = x0 + width * 0.64
	return PackedVector2Array([
		Vector2(x0, -height * 0.5), Vector2(x1, -height * 0.5),
		Vector2(x1, height * 0.5), Vector2(x0, height * 0.5),
	])


## Polygon2D UVs are in texels, not 0..1.
func _eye_uv(texture_size: Vector2) -> PackedVector2Array:
	var x0: float = EYE_UV.position.x * texture_size.x
	var x1: float = EYE_UV.end.x * texture_size.x
	var y0: float = EYE_UV.position.y * texture_size.y
	var y1: float = EYE_UV.end.y * texture_size.y
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


func _apply_panels(t: float) -> void:
	for panel: CutPanel in _panels:
		var local: float = clampf((t - panel.delay) / maxf(0.001, 1.0 - panel.delay), 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - local, 3.0)
		panel.position = panel.home + panel.slide * (1.0 - eased)
		panel.rotation = panel.home_rotation + panel.spin * (1.0 - eased)
