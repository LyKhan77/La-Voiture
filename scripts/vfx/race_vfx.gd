class_name RaceVfx
extends Node3D

## Everything that makes the weekend world read as a race, driven by the GT sim state
## (FASE 5.7): weather (rain, wet road, spray, gloomy sky, lightning, time of day),
## tyre smoke (launch, lock-up, spin), sparks (contacts, rim grinding, wheel guns),
## slipstream ribbons, exhaust pops, headlights, a floating status tip over every car, the
## safety car. Nothing here feeds back into the sim. Call setup() once, update() per frame.

const RainScene := preload("res://scenes/vfx/manga_rain_3d.tscn")
const SmokeScene := preload("res://scenes/vfx/manga_smoke_emitter.tscn")
const SprayScript := preload("res://scripts/vfx/manga_road_spray.gd")
const WetShader := preload("res://shaders/road_asphalt.gdshader")
const ActorScene := preload("res://scenes/race_world/gt_car_actor.tscn")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")

## Rear of the car in actor space (+Z), where the spray leaves the road.
const SPRAY_OFFSET := Vector3(0.0, 0.4, 2.2)
const SPRAY_FULL_SPEED_MPS: float = 70.0
const FOLLOWED_SPRAY_SHARE: float = 0.3
const REAR_WHEELS: Array[Vector3] = [Vector3(-0.98, 0.3, 1.26), Vector3(0.98, 0.3, 1.26)]
const EXHAUSTS: Array[Vector3] = [Vector3(-0.3, 0.3, 2.3), Vector3(0.3, 0.3, 2.3)]
const HEADLIGHTS: Array[Vector3] = [Vector3(-0.62, 0.63, -2.12), Vector3(0.62, 0.63, -2.12)]
const HEAD_COLOR := Color("#eaf2ff")
const HEAD_BEAM_RANGE_M: float = 45.0
const HEAD_BEAM_ANGLE_DEG: float = 32.0
const HEAD_BEAM_ENERGY_SHARE: float = 0.55 # 4.0 lamp energy (night) -> 2.2 beam
const HEAD_BEAM_FADE_BEGIN_M: float = 70.0
const HEAD_BEAM_FADE_LENGTH_M: float = 20.0
## Kerb strike: sparks leave a wheel on the kerb (beyond the audio's kerb offset) above this speed.
const KERB_SPARK_MIN_V: float = 35.0
const KERB_SPARK_AMOUNT: int = 18
const KERB_STAR_AMOUNT: int = 7
const FLAME_POP_S: float = 0.12
const GRAFFITI_CRIMSON := Color("#ff1a4b")
const GRAFFITI_ACID := Color("#d8ff00")
## Genex sprite sheets (2x2 frames, transparent): halftone graffiti tyre smoke and comic flame bursts.
const SmokeSheet := preload("res://assets/vfx/2x2-sprite-sheet-of-four-different-anime-cmvkkjc7.png")
const FlameSheet := preload("res://assets/vfx/2x2-sprite-sheet-of-four-different-manga-cmvkkjfc.png")
const SHEET_FRAMES: int = 2
## One-shot sounds (Genex): the backfire crackle on a downshift, the boost whoosh when ERS overtake kicks in.
const BackfireStream := preload("res://assets/audio/sfx/short-exhaust-backfire-crackle-three-sha-cmvkm1hx.wav")
const BoostStream := preload("res://assets/audio/sfx/fast-electric-boost-whoosh-rising-sweep-cmvkm1o4.wav")
const ONE_SHOT_RANGE_M: float = 60.0
const ONE_SHOT_VOICES: int = 4
const BACKFIRE_DB: float = -4.0
const BOOST_DB: float = -6.0
const BURST_SIZE_M: float = 0.7
const WING_BURST_SIZE_M: float = 0.85
const TRAIL_WAVE_M: float = 0.32
## Lamp VFX: soft glows and a neon ribbon at each lamp anchor. Nothing is modelled on the car body.
const TAIL_COLOR := Color("#ff1a4b")
const TRAIL_POINTS: int = 22
const TRAIL_WIDTH_M: float = 0.045
const TRAIL_RANGE_M: float = 140.0
const TRAIL_MIN_V: float = 8.0
const TAIL_ENERGY_FULL: float = 6.5 # GtCarActor.TAIL_BRAKE_ENERGY
const GLOW_SIZE_M: float = 0.7
const GLOW_ON: float = 0.02
const HEAD_GLOW_MIN_CAMERA_M: float = 10.0
## Floating graffiti tip over every car: a name tag that flashes up for a moment (a pass, a
## selection, a car coming close) and a status sticker (hazard, pit, DRS, brake) while it lasts.
const TIP_HEIGHT_M: float = 2.6
const TIP_RANGE_M: float = 60.0 # rivals only; the followed car is always eligible
const TIP_HIDE_NEAR_M: float = 3.0
const TIP_PIXEL_SIZE: float = 0.00042
const TIP_HOLD_S: float = 2.4
const TIP_FADE_IN_S: float = 0.1
const TIP_FADE_OUT_S: float = 0.5
const TIP_NAME_OPACITY: float = 0.6
const TIP_STATUS_OPACITY: float = 0.92
const TIP_STATUS_PAINT: Dictionary = {
	"HAZARD": Color("#ffaa00"), "PIT": Color("#00f0ff"), "DRS": Color("#00f0ff"), "BRAKE": Color("#ff1e56"),
}
## Retired cars: smoke pours from the bonnet, four orange hazard lamps blink at the body corners (actor space, nose is -Z).
const WRECK_SMOKE_AT := Vector3(0.0, 0.85, -1.2)
const HAZARD_LAMPS: Array[Vector3] = [Vector3(-0.92, 0.66, -2.0), Vector3(0.92, 0.66, -2.0), Vector3(-0.92, 0.66, 2.05), Vector3(0.92, 0.66, 2.05)]
const HAZARD_COLOR := Color("#ff8a00")
const HAZARD_ENERGY: float = 6.0
const HAZARD_HZ: float = 1.5
const HAZARD_SIZE_M: float = 0.16
const WAKES: Array[Vector3] = [Vector3(-0.84, 0.46, -2.4), Vector3(0.84, 0.46, -2.4)]
const SPARK_POOL: int = 10
const SMOKE_LAUNCH_V: float = 18.0
const GLOOM_SUN_ENERGY: float = 0.4

static var _textures: Dictionary = {} # procedural sprite name -> ImageTexture, drawn once for all cars

var world: Node3D
var race: GtRace
var track: GtTrack
var rain: MangaRain3D
var track_material: ShaderMaterial
var sprays: Dictionary = {} # car id -> MangaRoadSpray
var smokes: Dictionary = {} # car id -> Array[GPUParticles3D]
var wreck_smokes: Dictionary = {} # car id -> GPUParticles3D, made the first time that car retires
var wreck_hazards: Dictionary = {} # car id -> Array[MeshInstance3D], the four blinking lamps
var wakes: Dictionary = {} # car id -> Array[MeshInstance3D]
var flames: Dictionary = {} # car id -> Array[MeshInstance3D]
var tips: Dictionary = {} # car id -> Node3D holding the Code and Status sprites
var head_lights: Dictionary = {} # car id -> Array[SpotLight3D]
var kerb_sparks: Dictionary = {} # car id -> GPUParticles3D
## How many one-shot sounds the VFX layer has started (tests and the HUD can watch it).
var one_shots_played: int = 0
var wing_bursts: Dictionary = {} # car id -> Array[MeshInstance3D], comic flame bursts at the two wing tips
var tail_trails: Dictionary = {} # car id -> MeshInstance3D (ImmediateMesh ribbon, world space)
var lamp_glows: Dictionary = {} # car id -> {"tail": Array[MeshInstance3D], "head": Array[MeshInstance3D]}
var sparks: Array[GPUParticles3D] = []
## Headlamp emission the weather asks for this frame (0 by day, up to 4 at night or in a storm).
var headlight_energy: float = 0.0
var safety_car_actor: ActorScript
var rain_intensity: float = 0.0
var lightning: float = 0.0

var _safety_car_state: GtCar
var _spark_index: int = 0
var _status_textures: Dictionary = {} # status text -> Texture2D
var _tip_timer: Dictionary = {} # car id -> seconds the name tag stays up
var _tip_alpha: Dictionary = {} # car id -> 0..1 fade of the name tag
var _tip_memory: Dictionary = {} # car id -> what it looked like last frame
var _tip_status_text: Dictionary = {} # car id -> status shown now
var _flame_timers: Dictionary = {} # car id -> seconds the pop stays lit
var _wing_timers: Dictionary = {} # car id -> seconds the wing-tip bursts stay lit
var _trail_history: Dictionary = {} # car id -> two Array[Vector3] of world points, newest first
var _sfx_voices: Array[AudioStreamPlayer3D] = []
var _sfx_next: int = 0
var _last_ers: Dictionary = {} # car id -> ErsMode last frame
var _glow_mesh: QuadMesh
var _tail_glow_mesh: QuadMesh
var _last_gear: Dictionary = {} # car id -> gear
var _clock: float = 0.0
var _sky_material: ProceduralSkyMaterial
var _environment: Environment
var _sun: DirectionalLight3D
var _smoke_mesh: QuadMesh


func setup(p_world: Node3D) -> void:
	world = p_world
	race = world.race
	track = world.track
	_sun = world.get_node("Sun")
	_build_smoke_mesh()
	_build_lamp_meshes()
	_build_one_shot_voices()
	_build_status_textures()
	_build_weather()
	_build_sparks()
	for actor: ActorScript in world.actors:
		_build_car_effects(actor)
	_build_safety_car()
	race.collision_event.connect(_on_collision)


func update(delta: float, alpha: float = 1.0) -> void:
	_clock += delta
	_update_weather(delta)
	var followed_id: int = world.followed_id
	for actor: ActorScript in world.actors:
		_update_car_effects(actor, delta, actor.car.id == followed_id)
	_update_safety_car(delta, alpha)
	_update_crew_sparks()


# --- weather ---------------------------------------------------------------------

func _build_weather() -> void:
	rain = RainScene.instantiate()
	add_child(rain)
	track_material = ShaderMaterial.new()
	track_material.shader = WetShader
	var road := world.ribbon.get_node("RoadMesh") as MeshInstance3D
	road.material_override = track_material
	# The pit lane is the same asphalt: it wets, dries and puddles with the circuit.
	var pit_asphalt := world.pit_lane.get_node_or_null("PitAsphalt") as MeshInstance3D
	if pit_asphalt != null:
		pit_asphalt.material_override = track_material
	var world_environment := world.get_node("WorldEnvironment") as WorldEnvironment
	_environment = world_environment.environment
	if _environment.sky != null:
		_sky_material = _environment.sky.sky_material as ProceduralSkyMaterial


func _update_weather(delta: float) -> void:
	var weather: GtWeather = race.weather
	rain_intensity = clampf(sqrt(weather.rain_intensity), 0.0, 1.0)
	var wetness: float = weather.track_water_pct / 100.0
	track_material.set_shader_parameter("track_wetness", wetness)
	track_material.set_shader_parameter("rain_intensity", rain_intensity)
	rain.set_intensity(rain_intensity)
	var gloom: float = maxf(rain_intensity, wetness)
	var tod: Dictionary = weather.time_of_day
	lightning = maxf(lightning - delta * 3.0, weather.lightning_flash)
	_sun.light_color = tod["sun_color"]
	_sun.light_energy = float(tod["sun_intensity"]) * lerpf(1.0, GLOOM_SUN_ENERGY, gloom) + lightning * 2.0
	_sun.rotation.x = -deg_to_rad(10.0 + 70.0 * float(tod["sun_altitude"]))
	_environment.ambient_light_color = tod["hemi_color"]
	_environment.ambient_light_energy = float(tod["hemi_intensity"]) + lightning * 1.5
	_environment.ssr_enabled = wetness > 0.1
	if _sky_material != null:
		var top: Color = tod["sky_color"]
		var storm := Color(0.14, 0.16, 0.20)
		_sky_material.sky_top_color = top.lerp(storm, gloom * 0.8)
		_sky_material.sky_horizon_color = top.lerp(Color.WHITE, 0.35).lerp(Color(0.36, 0.4, 0.46), gloom * 0.8)
		_sky_material.ground_horizon_color = _sky_material.sky_horizon_color
	var headlights: float = float(tod["headlights"])
	headlight_energy = 4.0 * maxf(headlights, gloom * 0.6)


# --- per car -----------------------------------------------------------------------

## Round, soft-edged puff instead of the flat square of the stock emitter.
## Halftone graffiti swirls: each puff shows one random frame of the 2x2 sheet (see _build_car_effects).
func _build_smoke_mesh() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.particles_anim_h_frames = SHEET_FRAMES
	material.particles_anim_v_frames = SHEET_FRAMES
	material.particles_anim_loop = false
	material.albedo_texture = SmokeSheet
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.92)
	_smoke_mesh = QuadMesh.new()
	_smoke_mesh.size = Vector2(1.3, 1.3)
	_smoke_mesh.material = material


func _lamp(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


## A small pool of 3D voices for the short effects; the oldest one is reused when all are busy.
func _build_one_shot_voices() -> void:
	for index: int in range(ONE_SHOT_VOICES):
		var voice := AudioStreamPlayer3D.new()
		voice.name = "OneShot%d" % index
		voice.bus = &"SFX"
		voice.max_distance = ONE_SHOT_RANGE_M * 1.5
		voice.unit_size = 8.0
		add_child(voice)
		_sfx_voices.append(voice)


func _one_shot(stream: AudioStream, at: Vector3, volume_db: float) -> void:
	var voice: AudioStreamPlayer3D = _sfx_voices[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_voices.size()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.global_position = at
	voice.play()
	one_shots_played += 1


## Two soft round flares (additive, camera-facing): crimson for the tail, ice white for the head.
func _build_lamp_meshes() -> void:
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	_tail_glow_mesh = _flare_quad(texture, TAIL_COLOR)
	_glow_mesh = _flare_quad(texture, HEAD_COLOR)


func _flare_quad(texture: Texture2D, color: Color) -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA # additive blending still reads the flare/vertex alpha
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = texture
	material.albedo_color = color
	material.no_depth_test = false
	var quad := QuadMesh.new()
	quad.size = Vector2(GLOW_SIZE_M, GLOW_SIZE_M)
	quad.material = material
	return quad


## Lamps are effects, not parts: a soft flare per anchor and one neon ribbon streaming off the tail.
func _build_lamp_vfx(actor: ActorScript) -> void:
	var id: int = actor.car.id
	var glows: Dictionary = {"tail": [] as Array[MeshInstance3D], "head": [] as Array[MeshInstance3D]}
	for kind: String in ["tail", "head"]:
		for anchor: Vector3 in actor.lamp_anchors[kind]:
			var flare := MeshInstance3D.new()
			flare.name = "%sGlow" % kind.capitalize()
			flare.mesh = _tail_glow_mesh if kind == "tail" else _glow_mesh
			flare.position = anchor
			flare.visible = false
			flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			actor.chassis.add_child(flare)
			glows[kind].append(flare)
	lamp_glows[id] = glows
	var wing_list: Array[MeshInstance3D] = []
	for anchor: Vector3 in actor.lamp_anchors["wing"]:
		var burst := _burst_sprite("WingBurst", WING_BURST_SIZE_M)
		burst.position = anchor
		burst.visible = false
		actor.chassis.add_child(burst)
		wing_list.append(burst)
	wing_bursts[id] = wing_list
	var ribbon := MeshInstance3D.new()
	ribbon.name = "TailTrail"
	ribbon.top_level = true # world-space points: it must not follow the car
	ribbon.mesh = ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA # a crisp red neon line, not an additive wash to pink
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true # the ribbon colour is an sRGB crimson; linear would wash it to pink
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribbon.material_override = material
	ribbon.visible = false
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbon.extra_cull_margin = 60.0 # the rebuilt strip is far larger than its empty first AABB
	actor.add_child(ribbon)
	tail_trails[id] = ribbon
	_trail_history[id] = [[] as Array[Vector3], [] as Array[Vector3]]


func _update_lamp_vfx(actor: ActorScript) -> void:
	var car: GtCar = actor.car
	var id: int = car.id
	var strength: float = clampf(actor.taillight_energy / TAIL_ENERGY_FULL, 0.0, 1.0)
	var glows: Dictionary = lamp_glows[id]
	for flare: MeshInstance3D in glows["tail"]:
		flare.visible = strength > GLOW_ON
		flare.scale = Vector3.ONE * lerpf(0.5, 1.4, strength)
	var heads_on: bool = headlight_energy > 0.5 and world.camera.global_position.distance_to(actor.global_position) > HEAD_GLOW_MIN_CAMERA_M # not the flares of the car the camera rides on
	for flare: MeshInstance3D in glows["head"]:
		flare.visible = heads_on
	var ribbon := tail_trails[id] as MeshInstance3D
	var distance: float = world.camera.global_position.distance_to(actor.global_position)
	var streaming: bool = strength > GLOW_ON and car.v > TRAIL_MIN_V and distance < TRAIL_RANGE_M and PresentationSettings.light_trails()
	ribbon.visible = streaming
	var history: Array = _trail_history[id]
	if not streaming:
		for line: Array in history:
			line.clear()
		return
	var mesh := ribbon.mesh as ImmediateMesh
	mesh.clear_surfaces()
	for side: int in range(2):
		var line: Array = history[side]
		line.push_front(actor.lamp_point("tail", side))
		if line.size() > TRAIL_POINTS:
			line.pop_back()
		if line.size() >= 2:
			_stroke_ribbon(mesh, line, strength, PI * float(side))


## One camera-facing triangle strip along the points (newest first), tapering and fading with age.
func _stroke_ribbon(mesh: ImmediateMesh, points: Array, strength: float, phase: float) -> void:
	var eye: Vector3 = world.camera.global_position
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index: int in range(points.size()):
		var here: Vector3 = points[index]
		var ahead: Vector3 = points[index - 1] if index > 0 else points[index + 1]
		var behind: Vector3 = points[index + 1] if index + 1 < points.size() else points[index]
		var along: Vector3 = (ahead - behind).normalized()
		var across: Vector3 = along.cross(eye - here).normalized()
		var age: float = float(index) / float(TRAIL_POINTS)
		var width: float = TRAIL_WIDTH_M * (1.0 - age) * lerpf(0.6, 1.4, strength)
		# The neon ribbon swims in a loose S as it ages, like the swirling light trails of the concept art.
		var sway: float = sin(age * 9.0 + _clock * 4.0 + phase) * TRAIL_WAVE_M * age
		here += across * sway + Vector3.UP * sway * 0.6
		mesh.surface_set_color(Color(TAIL_COLOR, pow(1.0 - age, 1.5) * lerpf(0.35, 1.0, strength)))
		mesh.surface_add_vertex(here + across * width)
		mesh.surface_add_vertex(here - across * width)
	mesh.surface_end()


func tail_trail_length(car_id: int) -> float:
	var line: Array = (_trail_history[car_id] as Array)[0]
	var total: float = 0.0
	for index: int in range(1, line.size()):
		total += (line[index] as Vector3).distance_to(line[index - 1])
	return total


## A camera-facing comic flame burst: one frame of the flame sheet, picked per pop by _pick_burst_frame().
func _burst_sprite(node_name: String, size_m: float) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.albedo_texture = FlameSheet
	material.uv1_scale = Vector3(1.0 / float(SHEET_FRAMES), 1.0 / float(SHEET_FRAMES), 1.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(size_m, size_m)
	var sprite := MeshInstance3D.new()
	sprite.name = node_name
	sprite.mesh = quad
	sprite.material_override = material
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sprite


func _pick_burst_frame(sprite: MeshInstance3D) -> void:
	var frame: int = randi() % (SHEET_FRAMES * SHEET_FRAMES)
	(sprite.material_override as StandardMaterial3D).uv1_offset = Vector3(float(frame % SHEET_FRAMES), float(frame / SHEET_FRAMES), 0.0) / float(SHEET_FRAMES)


func _flame_cone(radius: float, height: float) -> CylinderMesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = 5 # a ragged, hand-cut starburst rather than a smooth cone
	return cone


## Kerb strike: a spray of uneven ink-cut shards (every size, all four spray colours) plus a few slow
## sparkle stars, thrown up and back off the outside wheel. The throw leans away from the kerb side
## (see _update_car_effects), so no two bursts and no two sides look alike.
func _build_kerb_sparks() -> GPUParticles3D:
	var shards := _spark_emitter("KerbSparks", _spark_quad(_shard_texture(), Vector2(0.06, 0.34)), KERB_SPARK_AMOUNT, 0.26, 7.0, 16.0, true)
	var stars := _spark_emitter("KerbStars", _spark_quad(_star_texture(), Vector2(0.3, 0.3)), KERB_STAR_AMOUNT, 0.4, 2.5, 6.5, false)
	shards.add_child(stars)
	return shards


func _spark_quad(texture: Texture2D, size: Vector2) -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.albedo_texture = texture
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = material
	return quad


func _spark_emitter(node_name: String, quad: QuadMesh, amount: int, life: float, speed_min: float, speed_max: float, align_to_velocity: bool) -> GPUParticles3D:
	var palette := Gradient.new()
	palette.offsets = PackedFloat32Array([0.0, 0.34, 0.66, 1.0])
	palette.colors = PackedColorArray([GRAFFITI_ACID, Color("#ffaa00"), GRAFFITI_CRIMSON, Color("#00f0ff")])
	var palette_texture := GradientTexture1D.new()
	palette_texture.gradient = palette
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	var shrink_texture := CurveTexture.new()
	shrink_texture.curve = shrink
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 0.6, 1.0)
	process.spread = 55.0
	process.initial_velocity_min = speed_min
	process.initial_velocity_max = speed_max
	process.gravity = Vector3(0.0, -9.8, 0.0)
	process.color_initial_ramp = palette_texture
	process.scale_min = 0.25
	process.scale_max = 1.9
	process.scale_curve = shrink_texture
	process.hue_variation_min = -0.06
	process.hue_variation_max = 0.06
	process.particle_flag_align_y = align_to_velocity
	if not align_to_velocity:
		process.angle_min = -180.0
		process.angle_max = 180.0
		process.angular_velocity_min = -360.0
		process.angular_velocity_max = 360.0
	var emitter := GPUParticles3D.new()
	emitter.name = node_name
	emitter.amount = amount
	emitter.lifetime = life
	emitter.local_coords = false
	emitter.emitting = false
	emitter.position = Vector3(0.0, 0.05, 1.2) if node_name == "KerbSparks" else Vector3.ZERO
	emitter.process_material = process
	emitter.draw_pass_1 = quad
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return emitter


## A pointed shard: thin tips, fat just below the middle, soft rim. Drawn once.
static func _shard_texture() -> Texture2D:
	if _textures.has(&"shard"):
		return _textures[&"shard"]
	var image := Image.create(32, 128, false, Image.FORMAT_RGBA8)
	for y: int in range(128):
		var along: float = float(y) / 127.0
		var half: float = 0.5 * pow(1.0 - absf(2.0 * along - 0.8), 1.2) if along < 0.9 else 0.0
		for x: int in range(32):
			var across: float = absf(float(x) - 15.5) / 15.5
			var alpha: float = clampf((half * 2.0 - across) * 4.0, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_textures[&"shard"] = ImageTexture.create_from_image(image)
	return _textures[&"shard"]


## A four-point sparkle (astroid) with a hot soft core. Drawn once.
static func _star_texture() -> Texture2D:
	if _textures.has(&"star"):
		return _textures[&"star"]
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y: int in range(64):
		for x: int in range(64):
			var px: float = absf((float(x) - 31.5) / 31.5)
			var py: float = absf((float(y) - 31.5) / 31.5)
			var arm: float = clampf((1.0 - (sqrt(px) + sqrt(py))) * 5.0, 0.0, 1.0)
			var core: float = clampf(1.0 - sqrt(px * px + py * py) * 2.4, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, maxf(arm, core)))
	_textures[&"star"] = ImageTexture.create_from_image(image)
	return _textures[&"star"]


func _build_car_effects(actor: ActorScript) -> void:
	var id: int = actor.car.id
	var spray := SprayScript.new()
	spray.position = SPRAY_OFFSET
	actor.add_child(spray)
	sprays[id] = spray
	var smoke_list: Array[GPUParticles3D] = []
	for offset: Vector3 in REAR_WHEELS:
		var smoke := SmokeScene.instantiate() as GPUParticles3D
		smoke.position = offset
		smoke.rotation.y = PI # the scene throws toward -Z; the car's rear is +Z
		smoke.draw_pass_1 = _smoke_mesh # the scene's own material is shared with the showroom
		var swirl := smoke.process_material.duplicate() as ParticleProcessMaterial # random frame and spin per puff, for this car only
		swirl.anim_offset_min = 0.0
		swirl.anim_offset_max = 1.0
		swirl.angle_min = -180.0
		swirl.angle_max = 180.0
		smoke.process_material = swirl
		actor.add_child(smoke)
		smoke_list.append(smoke)
	smokes[id] = smoke_list
	var wake_list: Array[MeshInstance3D] = []
	for offset: Vector3 in WAKES:
		var ribbon := MeshInstance3D.new()
		ribbon.name = "SlipstreamRibbon"
		var quad := QuadMesh.new()
		quad.size = Vector2(0.28, 7.0)
		ribbon.mesh = quad
		ribbon.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		ribbon.position = offset + Vector3(0.0, 0.0, -3.5)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(0.7, 0.95, 1.0, 0.0)
		ribbon.material_override = material
		ribbon.visible = false
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		actor.add_child(ribbon)
		wake_list.append(ribbon)
	wakes[id] = wake_list
	var flame_list: Array[MeshInstance3D] = []
	for offset: Vector3 in EXHAUSTS:
		var flame := MeshInstance3D.new()
		flame.name = "ExhaustPop"
		# Two-tone comic burst: an acid-yellow shell around a crimson core.
		flame.mesh = _flame_cone(0.1, 0.5)
		flame.material_override = _lamp(GRAFFITI_ACID, 5.0)
		var core := MeshInstance3D.new()
		core.name = "Core"
		core.mesh = _flame_cone(0.05, 0.34)
		core.material_override = _lamp(GRAFFITI_CRIMSON, 6.0)
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.add_child(core)
		flame.add_child(_burst_sprite("Burst", BURST_SIZE_M))
		flame.rotation_degrees = Vector3(90.0, 0.0, 0.0) # tip points to the rear
		flame.position = offset + Vector3(0.0, 0.0, 0.25)
		flame.visible = false
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		actor.add_child(flame)
		flame_list.append(flame)
	flames[id] = flame_list
	# The lamps are VFX (see _build_lamp_vfx); these cones throw the headlight onto the asphalt.
	var heads: Array[SpotLight3D] = []
	for offset: Vector3 in HEADLIGHTS:
		var cone := SpotLight3D.new()
		cone.name = "HeadlightBeam"
		cone.position = offset
		cone.rotation_degrees = Vector3(-4.0, 0.0, 0.0) # the car travels along -Z; tipped a little onto the asphalt
		cone.light_color = HEAD_COLOR
		cone.spot_range = HEAD_BEAM_RANGE_M
		cone.spot_angle = HEAD_BEAM_ANGLE_DEG
		cone.shadow_enabled = false
		cone.set_meta(&"no_shadow", true) # PresentationSettings keeps these pooled fill lights shadowless
		cone.distance_fade_enabled = true
		cone.distance_fade_begin = HEAD_BEAM_FADE_BEGIN_M
		cone.distance_fade_length = HEAD_BEAM_FADE_LENGTH_M
		cone.light_energy = 0.0
		cone.visible = false
		actor.add_child(cone)
		heads.append(cone)
	head_lights[id] = heads
	var kerb := _build_kerb_sparks()
	actor.add_child(kerb)
	kerb_sparks[id] = kerb
	_build_lamp_vfx(actor)
	tips[id] = _build_tip(actor)
	_last_gear[id] = actor.car.gear
	_last_ers[id] = actor.car.ers_mode


func _update_car_effects(actor: ActorScript, delta: float, followed: bool) -> void:
	var car: GtCar = actor.car
	var id: int = car.id
	var wetness: float = race.weather.track_water_pct / 100.0
	var spray_strength: float = wetness * car.v / SPRAY_FULL_SPEED_MPS
	if car.pit != null:
		spray_strength *= 0.3
	sprays[id].set_strength(spray_strength * (FOLLOWED_SPRAY_SHARE if followed else 1.0))

	var smoking: bool = false
	var started: bool = race.time > 0.0 and car.v < SMOKE_LAUNCH_V and car.throttle > 0.9 and car.pit == null and race.time < 12.0
	if started or car.spin_timer > 0.0 or (car.error_timer > 1.8 and car.v > 20.0) or (car.brake > 0.95 and car.v > 35.0):
		smoking = true
	for smoke: GPUParticles3D in smokes[id]:
		smoke.emitting = smoking

	var wake_visible: bool = car.slipstream_factor > 0.04 and car.v > 24.0
	for ribbon: MeshInstance3D in wakes[id]:
		ribbon.visible = wake_visible
		if wake_visible:
			(ribbon.material_override as StandardMaterial3D).albedo_color.a = minf(0.55, car.slipstream_factor * 0.65)

	# Exhaust pops on lift-off at speed and on every gear change; each pop is a freshly tilted, scaled burst.
	var timer: float = float(_flame_timers.get(id, 0.0)) - delta
	var shifted: bool = car.gear != int(_last_gear[id])
	var downshift: bool = car.gear < int(_last_gear[id])
	_last_gear[id] = car.gear
	if shifted or (car.throttle < 0.2 and car.v > 40.0 and car.brake < 0.2 and randf() < 0.08):
		timer = FLAME_POP_S
		for flame: MeshInstance3D in flames[id]:
			flame.rotation_degrees = Vector3(90.0, 0.0, randf_range(-14.0, 14.0))
			flame.scale = Vector3(randf_range(0.8, 1.25), randf_range(0.9, 1.5), randf_range(0.8, 1.25))
			_pick_burst_frame(flame.get_node("Burst") as MeshInstance3D)
	var bursts_on: bool = PresentationSettings.comic_bursts()
	var near_camera: bool = world.camera.global_position.distance_to(actor.global_position) < ONE_SHOT_RANGE_M
	var wing_timer: float = float(_wing_timers.get(id, 0.0)) - delta
	if downshift:
		wing_timer = FLAME_POP_S
		if near_camera:
			_one_shot(BackfireStream, actor.global_position + Vector3(0.0, 0.5, 2.3), BACKFIRE_DB)
		for burst: MeshInstance3D in wing_bursts[id]:
			_pick_burst_frame(burst)
			burst.rotation_degrees.z = randf_range(-30.0, 30.0)
	_wing_timers[id] = wing_timer
	if car.ers_mode == GtTypes.ErsMode.OVERTAKE and int(_last_ers[id]) != GtTypes.ErsMode.OVERTAKE and near_camera:
		_one_shot(BoostStream, actor.global_position, BOOST_DB)
	_last_ers[id] = car.ers_mode
	for burst: MeshInstance3D in wing_bursts[id]:
		burst.visible = wing_timer > 0.0 and car.pit == null and bursts_on
	_flame_timers[id] = timer
	for flame: MeshInstance3D in flames[id]:
		flame.visible = timer > 0.0 and car.pit == null
		(flame.get_node("Burst") as Node3D).visible = bursts_on

	# Headlamps: on at night and in the gloom. The slabs glow on the actor; the cones light the asphalt.
	actor.night_lights = headlight_energy
	var beams_on: bool = headlight_energy > 0.5 and PresentationSettings.headlight_beams()
	for beam: SpotLight3D in head_lights[id]:
		beam.visible = beams_on
		beam.light_energy = headlight_energy * HEAD_BEAM_ENERGY_SHARE

	# A wheel on the kerb strikes sparks off the sawtooth.
	var kerb := kerb_sparks[id] as GPUParticles3D
	kerb.emitting = car.v > KERB_SPARK_MIN_V and absf(car.lateral) > SpatialCarAudio.KERB_LATERAL_M and car.pit == null
	kerb.position.x = signf(car.lateral) * 0.92 # the wheel on the outside lip
	var lean: float = -signf(car.lateral) * (0.25 + 0.5 * absf(sin(_clock * 9.0 + float(id)))) # the throw wanders burst to burst
	for emitter: GPUParticles3D in [kerb, kerb.get_child(0)]:
		(emitter.process_material as ParticleProcessMaterial).direction = Vector3(lean, 0.6, 1.0)
	(kerb.get_child(0) as GPUParticles3D).emitting = kerb.emitting
	_update_lamp_vfx(actor)

	_update_tip(actor, followed, delta)
	_update_wreck_effects(actor)

	# A burst rim grinds sparks on the asphalt.
	if car.is_punctured and car.v > 2.0 and randf() < 0.65:
		var wheel_index: int = 0 if car.punctured_wheel == GtTypes.Wheel.FL or car.punctured_wheel == GtTypes.Wheel.RL else 1
		var wheel_z: float = -1.19 if car.punctured_wheel == GtTypes.Wheel.FL or car.punctured_wheel == GtTypes.Wheel.FR else 1.26
		var local := Vector3(-0.98 if wheel_index == 0 else 0.98, 0.1, wheel_z)
		_spark(actor.global_transform * local)


# --- wreckage ------------------------------------------------------------------------

## Built the first time a car retires (a healthy field carries none of it). Smoke rises from the bonnet; the
## hazard lamps are small unshaded emissive beads, so they cost no lights.
func _build_wreck_effects(actor: ActorScript) -> void:
	var id: int = actor.car.id
	var smoke := SmokeScene.instantiate() as GPUParticles3D
	smoke.name = "WreckSmoke"
	smoke.position = WRECK_SMOKE_AT
	smoke.draw_pass_1 = _smoke_mesh
	var plume := smoke.process_material.duplicate() as ParticleProcessMaterial
	plume.direction = Vector3.UP
	plume.spread = 18.0
	plume.initial_velocity_min = 1.2
	plume.initial_velocity_max = 2.6
	plume.gravity = Vector3(0.0, 0.8, 0.0)
	plume.anim_offset_min = 0.0
	plume.anim_offset_max = 1.0
	plume.angle_min = -180.0
	plume.angle_max = 180.0
	smoke.process_material = plume
	smoke.lifetime = 1.6
	actor.add_child(smoke)
	wreck_smokes[id] = smoke
	var bead := SphereMesh.new()
	bead.radius = HAZARD_SIZE_M * 0.5
	bead.height = HAZARD_SIZE_M
	var material: StandardMaterial3D = _lamp(HAZARD_COLOR, HAZARD_ENERGY)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var lamps: Array[MeshInstance3D] = []
	for offset: Vector3 in HAZARD_LAMPS:
		var lamp := MeshInstance3D.new()
		lamp.name = "HazardLamp"
		lamp.mesh = bead
		lamp.material_override = material
		lamp.position = offset
		lamp.visible = false
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		actor.add_child(lamp)
		lamps.append(lamp)
	wreck_hazards[id] = lamps


## Smoke while the wreck is on the track, hazards blinking in step; both stop once the marshals start the recovery.
func _update_wreck_effects(actor: ActorScript) -> void:
	var car: GtCar = actor.car
	if not car.is_dnf:
		return
	var id: int = car.id
	if not wreck_smokes.has(id):
		_build_wreck_effects(actor)
	var on_track: bool = car.evac_started_at < 0.0
	(wreck_smokes[id] as GPUParticles3D).emitting = on_track
	var lit: bool = on_track and sin(_clock * TAU * HAZARD_HZ) > 0.0
	for lamp: MeshInstance3D in wreck_hazards[id]:
		lamp.visible = lit


# --- floating tip -----------------------------------------------------------------

## Renders one graffiti tag once into a viewport and returns its texture.
func _paint_tag(text: String, paint: Color, seed_value: int, kind: int) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.size = Vector2i(GraffitiTag.SIZE_NAME if kind == GraffitiTag.Kind.NAME else GraffitiTag.SIZE_STATUS)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var tag := GraffitiTag.new()
	viewport.add_child(tag)
	tag.rebuild(text, paint, seed_value, kind)
	return viewport.get_texture()


func _build_status_textures() -> void:
	var seed_value: int = 11
	for text: String in TIP_STATUS_PAINT:
		_status_textures[text] = _paint_tag(text, TIP_STATUS_PAINT[text], seed_value, GraffitiTag.Kind.STATUS)
		seed_value += 7


func _tip_sprite(sprite_name: String, texture: Texture2D) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.fixed_size = true
	sprite.pixel_size = TIP_PIXEL_SIZE
	sprite.shaded = false
	sprite.double_sided = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sprite


func _build_tip(actor: ActorScript) -> Node3D:
	var tip := Node3D.new()
	tip.name = "Tip"
	tip.position = Vector3(0.0, TIP_HEIGHT_M, 0.0)
	tip.visible = false
	actor.add_child(tip)
	var car: GtCar = actor.car
	var code := _tip_sprite("Code", _paint_tag(car.code, car.color.lightened(0.2), car.number * 31 + 5, GraffitiTag.Kind.NAME))
	code.offset = Vector2(0.0, GraffitiTag.SIZE_NAME.y * 0.5) # the pointer at the bottom edge touches the anchor
	code.modulate.a = 0.0
	tip.add_child(code)
	var status := _tip_sprite("Status", null)
	status.visible = false
	tip.add_child(status)
	_tip_alpha[car.id] = 0.0
	_tip_timer[car.id] = 0.0
	_tip_status_text[car.id] = ""
	return tip


## The one status a car shows beside its tag; empty text means none. "lit" blinks a hazard.
func tip_status(car: GtCar, followed: bool) -> Dictionary:
	if car.is_punctured or car.fuel_stage == GtTypes.FuelStage.LIMP or car.is_dnf:
		return {"text": "HAZARD", "lit": sin(_clock * 16.0) > 0.0}
	if car.pit != null:
		return {"text": "PIT", "lit": true}
	if car.drs_active:
		return {"text": "DRS", "lit": true}
	if followed and car.brake > 0.1:
		return {"text": "BRAKE", "lit": true}
	return {"text": "", "lit": true}


## Shows the name tag of a car for a moment.
func ping_tip(car_id: int) -> void:
	_tip_timer[car_id] = TIP_HOLD_S


func tip_alpha(car_id: int) -> float:
	return float(_tip_alpha[car_id])


func tip_status_text(car_id: int) -> String:
	return String(_tip_status_text[car_id])


func _update_tip(actor: ActorScript, followed: bool, delta: float) -> void:
	var car: GtCar = actor.car
	var id: int = car.id
	var tip := tips[id] as Node3D
	var distance: float = world.camera.global_position.distance_to(actor.global_position)
	var near: bool = distance < TIP_RANGE_M
	# A pass, a new selection or a car coming close flashes the name tag.
	var memory: Dictionary = _tip_memory.get(id, {})
	if not memory.is_empty() and (int(memory["position"]) != car.position or (followed and not bool(memory["followed"])) or (near and not bool(memory["near"]))):
		ping_tip(id)
	_tip_memory[id] = {"position": car.position, "followed": followed, "near": near}
	var timer: float = maxf(float(_tip_timer[id]) - delta, 0.0)
	_tip_timer[id] = timer
	var target: float = 1.0 if timer > 0.0 else 0.0
	var alpha: float = float(_tip_alpha[id])
	alpha = move_toward(alpha, target, delta / (TIP_FADE_IN_S if target > alpha else TIP_FADE_OUT_S))
	_tip_alpha[id] = alpha
	var status: Dictionary = tip_status(car, followed)
	var status_text: String = String(status["text"])
	_tip_status_text[id] = status_text
	tip.visible = (followed or near) and distance > TIP_HIDE_NEAR_M and (alpha > 0.0 or status_text != "")
	if not tip.visible:
		return
	var code := tip.get_node("Code") as Sprite3D
	code.modulate.a = alpha * TIP_NAME_OPACITY
	var sticker := tip.get_node("Status") as Sprite3D
	sticker.visible = status_text != ""
	if status_text != "":
		sticker.texture = _status_textures[status_text]
		sticker.modulate.a = TIP_STATUS_OPACITY if bool(status["lit"]) else 0.3
		# Sits just above the anchor, or above the name tag while that is showing.
		sticker.offset = Vector2(0.0, GraffitiTag.SIZE_STATUS.y * 0.5 + 6.0 + GraffitiTag.SIZE_NAME.y * alpha * 0.92)
	tip.scale = Vector3.ONE * (1.35 if followed else 0.8)


# --- sparks ----------------------------------------------------------------------------

func _build_sparks() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.82, 0.25)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	quad.material = material
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 70.0
	process.initial_velocity_min = 2.5
	process.initial_velocity_max = 7.0
	process.gravity = Vector3(0.0, -9.8, 0.0)
	for index: int in range(SPARK_POOL):
		var burst := GPUParticles3D.new()
		burst.name = "Sparks%d" % index
		burst.amount = 14
		burst.lifetime = 0.35
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.local_coords = false
		burst.emitting = false
		burst.process_material = process
		burst.draw_pass_1 = quad
		burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(burst)
		sparks.append(burst)


func _spark(position: Vector3) -> void:
	var burst: GPUParticles3D = sparks[_spark_index]
	_spark_index = (_spark_index + 1) % sparks.size()
	burst.global_position = position
	burst.restart()
	burst.emitting = true


func _on_collision(event: Dictionary) -> void:
	var pose: Transform3D = track.point_at(float(event["s"]), float(event["lateral"]))
	var kind: int = event["type"]
	_spark(pose.origin + Vector3.UP * 0.35)
	if kind != GtTypes.CollisionKind.RUB:
		_spark(pose.origin + Vector3.UP * 0.5)


## Wheel-gun sparks while the crew works on the wheels.
func _update_crew_sparks() -> void:
	for job: PitstopChoreographer.Job in world.choreographer.jobs:
		if job.phase != PitstopChoreographer.Phase.SERVICING:
			continue
		for member: Node3D in job.crew_members:
			if randf() < 0.08:
				_spark(member.global_position + Vector3(0.0, 0.5, 0.0))


# --- safety car --------------------------------------------------------------------------

func _build_safety_car() -> void:
	_safety_car_state = GtCar.new()
	_safety_car_state.team_id = ActorScript.SAFETY_CAR_TEAM_ID
	_safety_car_state.compound = GtTypes.Compound.MEDIUM
	safety_car_actor = ActorScene.instantiate() as ActorScript
	world.add_child(safety_car_actor)
	safety_car_actor.bind(_safety_car_state, track)
	safety_car_actor.visible = false


## Amber during deployment; withdrawal and hidden are lights out. Green is pickup permission only.
func _strobe_mode_for(phase: int) -> SafetyCarChassis.StrobeMode:
	match phase:
		GtTypes.SafetyCarPhase.DEPLOYED:
			return SafetyCarChassis.StrobeMode.AMBER
		GtTypes.SafetyCarPhase.IN_THIS_LAP:
			return SafetyCarChassis.StrobeMode.OFF
	return SafetyCarChassis.StrobeMode.OFF


func _update_safety_car(delta: float, alpha: float) -> void:
	var state: Dictionary = race.safety_car
	var active: bool = bool(state["active"])
	safety_car_actor.visible = active
	var official := safety_car_actor.chassis as SafetyCarChassis
	var strobe: SafetyCarChassis.StrobeMode = _strobe_mode_for(int(state["phase"])) if active else SafetyCarChassis.StrobeMode.OFF
	if active and int(state["phase"]) == GtTypes.SafetyCarPhase.DEPLOYED and bool(state.get("wave_by", false)):
		strobe = SafetyCarChassis.StrobeMode.AMBER_GREEN
	official.set_strobe_mode(strobe)
	if not active:
		return
	var sc: GtCar = _safety_car_state
	sc.prev_s = float(state.get("prev_s", state["s"]))
	sc.prev_lateral = float(state.get("prev_lateral", state["lateral"]))
	sc.s = float(state["s"])
	sc.lateral = float(state["lateral"])
	sc.v = float(state["v"])
	var distance: float = sc.s - sc.prev_s
	if distance > 0.0001:
		sc.yaw_offset = atan2(sc.lateral - sc.prev_lateral, distance)
	safety_car_actor.present(alpha, delta)
