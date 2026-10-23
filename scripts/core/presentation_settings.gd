class_name PresentationSettings
extends RefCounted

## Presentation choices shared by the menu, the settings modal and every scene that renders
## the toon look. The fields are static, so a choice survives scene changes, and they persist
## to `user://presentation.cfg`. `apply_to_tree()` pushes the graphics choices onto the real
## render nodes (light shadows, inverted-hull outline width, halftone shader, particle
## density), and `set_volume()` writes straight to the five AudioServer buses.

const SAVE_PATH := "user://presentation.cfg"

enum Quality { LOW, MEDIUM, HIGH, ULTRA }
enum DisplayMode { WINDOWED, BORDERLESS, FULLSCREEN }

const QUALITY_NAMES: Array[String] = ["LOW", "MEDIUM", "HIGH", "ULTRA"]
const DISPLAY_MODE_NAMES: Array[String] = ["WINDOWED", "BORDERLESS", "FULLSCREEN"]
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(2560, 1440)]
const RESOLUTION_NAMES: Array[String] = ["1920 x 1080", "1280 x 720", "2560 x 1440"]

const BUSES: Array[StringName] = [&"Master", &"SFX", &"Radio", &"Music", &"UI"]
const BUS_LABELS: Array[String] = ["MASTER", "ENGINE SFX", "PIT RADIO", "SYNTHWAVE MUSIC", "UI CLICK"]

## Shadows by preset: distance (0 disables them), blur, directional split mode.
const SHADOW_DISTANCE: Array[float] = [0.0, 70.0, 150.0, 260.0]
const SHADOW_BLUR: Array[float] = [0.0, 0.0, 1.0, 2.0]
const SHADOW_SPLITS: Array[int] = [0, 0, 1, 2]
## Inverted-hull ink thickness: performance outline below High, full 0.02 m from High up.
const OUTLINE_WIDTH: Array[float] = [0.007, 0.012, 0.02, 0.02]
const HALFTONE_ALPHA: Array[float] = [0.05, 0.06, 0.07, 0.07]
const VFX_RATIO: Array[float] = [0.4, 0.7, 1.0, 1.0]

static var quality: int = Quality.HIGH
static var display_mode: int = DisplayMode.WINDOWED
static var resolution: int = 0
static var vsync: bool = true
static var halftone: bool = true
static var vfx_high: bool = true
## Accessibility: no FOV punch and frozen speedline re-rolls. Persisted with the graphics choices.
static var reduce_motion: bool = false
## Linear bus gain, 0..1; the layout's own balance is the default mix.
static var volumes: Dictionary = {
	&"Master": 1.0, &"SFX": 1.0, &"Radio": 1.0, &"Music": 0.63, &"UI": 0.79,
}

static var _saved_display: bool = false


## Reads the saved choices, applies the saved window mode once, and restores the mix.
static func bootstrap() -> void:
	load_saved()
	AudioManager.ensure_buses()
	apply_audio()
	if _saved_display:
		apply_display()


static func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	quality = clampi(int(cfg.get_value("graphics", "quality", quality)), 0, QUALITY_NAMES.size() - 1)
	halftone = bool(cfg.get_value("graphics", "halftone", halftone))
	vfx_high = bool(cfg.get_value("graphics", "vfx_high", vfx_high))
	reduce_motion = bool(cfg.get_value("graphics", "reduce_motion", reduce_motion))
	display_mode = clampi(int(cfg.get_value("display", "mode", display_mode)), 0, DISPLAY_MODE_NAMES.size() - 1)
	resolution = clampi(int(cfg.get_value("display", "resolution", resolution)), 0, RESOLUTIONS.size() - 1)
	vsync = bool(cfg.get_value("display", "vsync", vsync))
	_saved_display = true
	for bus: StringName in BUSES:
		volumes[bus] = clampf(float(cfg.get_value("audio", String(bus), volumes[bus])), 0.0, 1.0)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("graphics", "halftone", halftone)
	cfg.set_value("graphics", "vfx_high", vfx_high)
	cfg.set_value("graphics", "reduce_motion", reduce_motion)
	cfg.set_value("display", "mode", display_mode)
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("display", "vsync", vsync)
	for bus: StringName in BUSES:
		cfg.set_value("audio", String(bus), float(volumes.get(bus, 1.0)))
	cfg.save(SAVE_PATH)


# --- graphics ------------------------------------------------------------------------------------

## Presets drive every visual knob; the individual toggles can still override them after.
static func set_quality(index: int) -> void:
	quality = clampi(index, 0, QUALITY_NAMES.size() - 1)
	halftone = quality >= Quality.MEDIUM
	vfx_high = quality >= Quality.HIGH


## The heavier race VFX each preset keeps: light trails and comic bursts from MEDIUM, headlight beams from HIGH.
static func light_trails() -> bool:
	return quality >= Quality.MEDIUM


static func comic_bursts() -> bool:
	return quality >= Quality.MEDIUM


static func headlight_beams() -> bool:
	return quality >= Quality.HIGH


## Pushes shadows, outline, halftone and particle density onto a live scene tree. Call it
## after the scene (and its HUD) is built; safe to call again on every settings change.
static func apply_to_tree(root: Node) -> void:
	if root == null:
		return
	_walk(root, {})


static func _walk(node: Node, seen: Dictionary) -> void:
	if node is Light3D:
		_apply_light(node as Light3D)
	elif node is GPUParticles3D:
		var particles := node as GPUParticles3D
		if not particles.has_meta(&"presentation_base_amount"):
			particles.set_meta(&"presentation_base_amount", particles.amount)
		# Dynamic rain/spray own amount_ratio; scale the budget instead so updates cannot undo density.
		var density: float = VFX_RATIO[quality] if vfx_high else 0.3
		var budget: int = maxi(1, roundi(float(particles.get_meta(&"presentation_base_amount")) * density))
		if particles.amount != budget:
			particles.amount = budget
	elif node is MeshInstance3D:
		_apply_mesh(node as MeshInstance3D, seen)
	if node is CanvasItem:
		_apply_material((node as CanvasItem).material, seen)
	for child: Node in node.get_children():
		_walk(child, seen)


static func _apply_light(light: Light3D) -> void:
	# Pooled fill lights (the floodlight spots) opt out: they never cast shadows at any quality.
	if light.has_meta(&"no_shadow"):
		light.shadow_enabled = false
		return
	light.shadow_enabled = quality >= Quality.MEDIUM
	light.shadow_blur = SHADOW_BLUR[quality]
	var sun := light as DirectionalLight3D
	if sun != null:
		sun.directional_shadow_max_distance = SHADOW_DISTANCE[quality]
		sun.directional_shadow_mode = SHADOW_SPLITS[quality]


static func _apply_mesh(mesh: MeshInstance3D, seen: Dictionary) -> void:
	_apply_material(mesh.material_override, seen)
	if mesh.mesh == null:
		return
	for surface: int in range(mesh.mesh.get_surface_count()):
		_apply_material(mesh.get_surface_override_material(surface), seen)
		_apply_material(mesh.mesh.surface_get_material(surface), seen)


static func _apply_material(material: Material, seen: Dictionary) -> void:
	if material == null or seen.has(material):
		return
	seen[material] = true
	var shader_material := material as ShaderMaterial
	if shader_material != null and shader_material.shader != null:
		var path: String = shader_material.shader.resource_path
		if path.ends_with("inverted_hull_outline.gdshader"):
			shader_material.set_shader_parameter("outline_width", OUTLINE_WIDTH[quality])
		elif path.ends_with("halftone_screentone.gdshader"):
			var alpha: float = HALFTONE_ALPHA[quality] if halftone else 0.0
			shader_material.set_shader_parameter("dot_color", Color(1.0, 1.0, 1.0, alpha))
	# The ink hull lives on next_pass of the cel material, not on the surface material itself.
	_apply_material(material.next_pass, seen)


# --- display -------------------------------------------------------------------------------------

static func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	match display_mode:
		DisplayMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		DisplayMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			_fit_window(RESOLUTIONS[resolution])
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			_fit_window(RESOLUTIONS[resolution])
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	_saved_display = true
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		# Fullscreen windows match the monitor; resolution controls the actual 3D render target.
		var screen_size: Vector2i = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
		tree.root.scaling_3d_scale = float(RESOLUTIONS[resolution].y) / float(maxi(1, screen_size.y)) if display_mode == DisplayMode.FULLSCREEN else 1.0


## A window larger than the screen would start off-screen; the usable rect caps it.
static func _fit_window(size: Vector2i) -> void:
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var capped := Vector2i(mini(size.x, usable.size.x), mini(size.y, usable.size.y))
	DisplayServer.window_set_size(capped)
	DisplayServer.window_set_position(usable.position + (usable.size - capped) / 2)


# --- audio ---------------------------------------------------------------------------------------

static func apply_audio() -> void:
	for bus: StringName in BUSES:
		set_volume(bus, float(volumes.get(bus, 1.0)))


static func set_volume(bus: StringName, gain: float) -> void:
	volumes[bus] = clampf(gain, 0.0, 1.0)
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, gain <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(gain, 0.001)))


static func volume(bus: StringName) -> float:
	return float(volumes.get(bus, 1.0))
