class_name KineticStandee3D
extends Node3D

## 2.5D kinetic manga standee for the winning podium. One alpha-cutout QuadMesh (1.05 x 1.85 m)
## stands on the podium with its soles at the node origin, casts a real silhouette shadow, breathes
## on a foot-anchored 2.4 s sine tween, and — for the race winner only — floats the 勝者 hologram
## and AR speedlines behind the portrait.
##
## configure() may run before add_child() (the common case) or again later; it only feeds the
## shader uniforms and the hologram visibility, so nodes are never rebuilt. Every child, tween and
## resource is owned by this node, so freeing the standee frees the whole act.

const STANDEE_SHADER: Shader = preload("res://shaders/kinetic_standee.gdshader")

const HEIGHT: float = 1.85
const WIDTH: float = 1.05
## Breathing: 1.0 -> 1.015 -> 1.0 over 2.4 s, soles pinned to y = 0.
const BREATH_PERIOD: float = 2.4
const BREATH_SCALE: float = 0.015
## White die-cut sticker border, in metres on the quad (about 5 px at the 1080p hero framing).
const OUTLINE_WIDTH: float = 0.014
const RIM_BASE: float = 0.45
const RIM_WINNER: float = 0.7
const HOLOGRAM_HEIGHT: float = 1.12
## Negative Z is away from the camera the QuadMesh faces (+Z), so the hologram sits behind the
## silhouette and is hidden wherever the cutout is opaque.
const HOLOGRAM_DEPTH: float = -0.12
const HOLOGRAM_FLOAT: float = 0.045
const HOLOGRAM_PERIOD: float = 3.6
const HOLOGRAM_TEXT: String = "勝者"
const SPEEDLINE_COUNT: int = 36
## No CJK font ships in assets/fonts; these OS families cover 勝者 (Windows: the first two).
## On a host without any of them the text falls back to the default font and renders tofu.
const KANJI_FONTS: Array[String] = [
	"Yu Gothic UI", "Yu Gothic", "Meiryo", "Noto Sans CJK JP", "Noto Sans JP",
	"MS Gothic", "MS Mincho", "Source Han Sans",
]

var mesh_instance: MeshInstance3D
var material: ShaderMaterial
## Winner-only hologram group: kanji label plus speedline particles.
var hologram: Node3D
var kanji_label: Label3D
var speedlines: GPUParticles3D

var _speedline_process: ParticleProcessMaterial
var _breath: Tween
var _floating: Tween


func _init() -> void:
	_build()


func _ready() -> void:
	_start_motion()


func _exit_tree() -> void:
	_stop_motion()


## Feeds the character cutout, team identity color and winner state. Safe before entering the
## tree or again afterwards; only uniforms and visibility change.
func configure(texture: Texture2D, color: Color, winner: bool = false) -> void:
	material.set_shader_parameter("albedo_texture", texture)
	material.set_shader_parameter("team_color", color)
	material.set_shader_parameter("rim_color", color.lightened(0.22))
	material.set_shader_parameter("rim_intensity", RIM_WINNER if winner else RIM_BASE)
	hologram.visible = winner
	speedlines.emitting = winner

	var glow: Color = color.lightened(0.35)
	glow.a = 0.92
	kanji_label.modulate = glow
	var streak: Color = color.lightened(0.25)
	streak.a = 0.8
	_speedline_process.color = streak


func _build() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH, HEIGHT)
	# The vertex sway bands (hem -> waist -> hair) need interior vertices; 4 corners would only
	# shear the whole portrait. 8 x 16 is ~150 verts, nothing on a podium prop. A QuadMesh's
	# second parametric axis is Y, so vertical detail comes from subdivide_depth.
	quad.subdivide_width = 8
	quad.subdivide_depth = 16

	material = ShaderMaterial.new()
	material.shader = STANDEE_SHADER
	material.set_shader_parameter("outline_width", OUTLINE_WIDTH)

	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "StandeeQuad"
	mesh_instance.mesh = quad
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# QuadMesh is centered on its origin; lift it half a body so the soles rest on the podium.
	mesh_instance.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(mesh_instance)

	_build_hologram()


func _build_hologram() -> void:
	hologram = Node3D.new()
	hologram.name = "Hologram"
	hologram.position = Vector3(0.0, HOLOGRAM_HEIGHT, HOLOGRAM_DEPTH)
	hologram.visible = false
	add_child(hologram)

	kanji_label = Label3D.new()
	kanji_label.name = "Kanji"
	kanji_label.text = HOLOGRAM_TEXT
	kanji_label.font = _kanji_font()
	kanji_label.font_size = 96
	kanji_label.pixel_size = 0.005
	kanji_label.language = "ja"
	kanji_label.modulate = Color(1.0, 0.9, 0.5, 0.92)
	kanji_label.outline_size = 12
	kanji_label.outline_modulate = Color(0.06, 0.04, 0.0, 0.85)
	kanji_label.shaded = false
	kanji_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	kanji_label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	kanji_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hologram.add_child(kanji_label)

	_build_speedlines()


func _build_speedlines() -> void:
	var streak := QuadMesh.new()
	streak.size = Vector2(0.55, 0.012)
	var streak_material := StandardMaterial3D.new()
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	streak_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	streak_material.vertex_color_use_as_albedo = true
	streak_material.disable_receive_shadows = true
	streak.material = streak_material

	_speedline_process = ParticleProcessMaterial.new()
	_speedline_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_speedline_process.emission_box_extents = Vector3(1.0, 0.85, 0.05)
	_speedline_process.direction = Vector3(1.0, 0.0, 0.0)
	_speedline_process.spread = 10.0
	_speedline_process.initial_velocity_min = 0.8
	_speedline_process.initial_velocity_max = 2.6
	_speedline_process.gravity = Vector3.ZERO
	_speedline_process.scale_min = 0.45
	_speedline_process.scale_max = 1.4
	_speedline_process.lifetime_randomness = 0.4
	_speedline_process.color = Color(0.847, 1.0, 0.0, 0.8)

	speedlines = GPUParticles3D.new()
	speedlines.name = "Speedlines"
	speedlines.amount = SPEEDLINE_COUNT
	speedlines.lifetime = 1.6
	speedlines.preprocess = 0.8
	speedlines.local_coords = true
	speedlines.emitting = false
	speedlines.process_material = _speedline_process
	speedlines.draw_pass_1 = streak
	speedlines.visibility_aabb = AABB(Vector3(-2.2, -1.4, -0.3), Vector3(4.4, 2.8, 0.6))
	speedlines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hologram.add_child(speedlines)


func _kanji_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(KANJI_FONTS)
	font.font_weight = 700
	font.allow_system_fallback = true
	font.generate_mipmaps = true
	return font


func _start_motion() -> void:
	if _breath == null or not _breath.is_valid():
		_breath = create_tween().set_loops()
		_breath.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_breath.tween_method(_set_breath, 1.0, 1.0 + BREATH_SCALE, BREATH_PERIOD * 0.5)
		_breath.tween_method(_set_breath, 1.0 + BREATH_SCALE, 1.0, BREATH_PERIOD * 0.5)
	if _floating == null or not _floating.is_valid():
		_floating = create_tween().set_loops()
		_floating.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_floating.tween_property(hologram, "position:y", HOLOGRAM_HEIGHT + HOLOGRAM_FLOAT, HOLOGRAM_PERIOD * 0.5)
		_floating.tween_property(hologram, "position:y", HOLOGRAM_HEIGHT, HOLOGRAM_PERIOD * 0.5)


func _set_breath(scale_y: float) -> void:
	mesh_instance.scale = Vector3(1.0, scale_y, 1.0)
	# The quad's center rises with the scale; the soles stay glued to y = 0.
	mesh_instance.position.y = HEIGHT * 0.5 * scale_y


func _stop_motion() -> void:
	if _breath != null and _breath.is_valid():
		_breath.kill()
	if _floating != null and _floating.is_valid():
		_floating.kill()
