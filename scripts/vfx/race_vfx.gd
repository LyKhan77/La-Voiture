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
const FLAME_POP_S: float = 0.12
const GRAFFITI_CRIMSON := Color("#ff1a4b")
const GRAFFITI_ACID := Color("#d8ff00")
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
const WAKES: Array[Vector3] = [Vector3(-0.84, 0.46, -2.4), Vector3(0.84, 0.46, -2.4)]
const SPARK_POOL: int = 10
const SMOKE_LAUNCH_V: float = 18.0
const GLOOM_SUN_ENERGY: float = 0.4

var world: Node3D
var race: GtRace
var track: GtTrack
var rain: MangaRain3D
var track_material: ShaderMaterial
var sprays: Dictionary = {} # car id -> MangaRoadSpray
var smokes: Dictionary = {} # car id -> Array[GPUParticles3D]
var wakes: Dictionary = {} # car id -> Array[MeshInstance3D]
var flames: Dictionary = {} # car id -> Array[MeshInstance3D]
var tips: Dictionary = {} # car id -> Node3D holding the Code and Status sprites
var head_lights: Dictionary = {} # car id -> Array[SpotLight3D]
var kerb_sparks: Dictionary = {} # car id -> GPUParticles3D
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
var _last_gear: Dictionary = {} # car id -> gear
var _clock: float = 0.0
var _sky_material: ProceduralSkyMaterial
var _environment: Environment
var _sun: DirectionalLight3D
var _bar_materials: Array[StandardMaterial3D] = []
var _smoke_mesh: QuadMesh


func setup(p_world: Node3D) -> void:
	world = p_world
	race = world.race
	track = world.track
	_sun = world.get_node("Sun")
	_build_smoke_mesh()
	_build_status_textures()
	_build_weather()
	_build_sparks()
	for actor: ActorScript in world.actors:
		_build_car_effects(actor)
	_build_safety_car()
	race.collision_event.connect(_on_collision)


func update(delta: float) -> void:
	_clock += delta
	_update_weather(delta)
	var followed_id: int = world.followed_id
	for actor: ActorScript in world.actors:
		_update_car_effects(actor, delta, actor.car.id == followed_id)
	_update_safety_car()
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
func _build_smoke_mesh() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_texture = texture
	material.albedo_color = Color(0.92, 0.92, 0.95, 0.8)
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


func _flame_cone(radius: float, height: float) -> CylinderMesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = 5 # a ragged, hand-cut starburst rather than a smooth cone
	return cone


## Acid-lime and orange streaks thrown back off an outside wheel that rides the kerb.
func _build_kerb_sparks() -> GPUParticles3D:
	var streak := QuadMesh.new()
	streak.size = Vector2(0.03, 0.22)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.albedo_color = Color.WHITE
	streak.material = material
	var ramp := Gradient.new()
	ramp.set_color(0, GRAFFITI_ACID)
	ramp.set_color(1, Color("#ffaa00"))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 0.5, 1.0) # up and back: the car runs toward -Z
	process.spread = 38.0
	process.initial_velocity_min = 9.0
	process.initial_velocity_max = 14.0
	process.gravity = Vector3(0.0, -9.8, 0.0)
	process.color_initial_ramp = ramp_texture
	process.particle_flag_align_y = true
	var sparks_3d := GPUParticles3D.new()
	sparks_3d.name = "KerbSparks"
	sparks_3d.amount = KERB_SPARK_AMOUNT
	sparks_3d.lifetime = 0.22
	sparks_3d.local_coords = false
	sparks_3d.emitting = false
	sparks_3d.position = Vector3(0.0, 0.05, 1.2)
	sparks_3d.process_material = process
	sparks_3d.draw_pass_1 = streak
	sparks_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sparks_3d


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
		smoke.draw_pass_1 = _smoke_mesh # soft puffs; the scene's own material is shared with the showroom
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
		flame.rotation_degrees = Vector3(90.0, 0.0, 0.0) # tip points to the rear
		flame.position = offset + Vector3(0.0, 0.0, 0.25)
		flame.visible = false
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		actor.add_child(flame)
		flame_list.append(flame)
	flames[id] = flame_list
	# The lamps themselves are emissive slabs on the chassis (GtCarActor); these cones only throw the light.
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
	tips[id] = _build_tip(actor)
	_last_gear[id] = actor.car.gear


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
	_last_gear[id] = car.gear
	if shifted or (car.throttle < 0.2 and car.v > 40.0 and car.brake < 0.2 and randf() < 0.08):
		timer = FLAME_POP_S
		for flame: MeshInstance3D in flames[id]:
			flame.rotation_degrees = Vector3(90.0, 0.0, randf_range(-14.0, 14.0))
			flame.scale = Vector3(randf_range(0.8, 1.25), randf_range(0.9, 1.5), randf_range(0.8, 1.25))
	_flame_timers[id] = timer
	for flame: MeshInstance3D in flames[id]:
		flame.visible = timer > 0.0 and car.pit == null

	# Headlamps: on at night and in the gloom. The slabs glow on the actor; the cones light the asphalt.
	actor.night_lights = headlight_energy
	var beams_on: bool = headlight_energy > 0.5
	for beam: SpotLight3D in head_lights[id]:
		beam.visible = beams_on
		beam.light_energy = headlight_energy * HEAD_BEAM_ENERGY_SHARE

	# A wheel on the kerb strikes sparks off the sawtooth.
	var kerb := kerb_sparks[id] as GPUParticles3D
	kerb.emitting = car.v > KERB_SPARK_MIN_V and absf(car.lateral) > SpatialCarAudio.KERB_LATERAL_M and car.pit == null
	kerb.position.x = signf(car.lateral) * 0.92 # the wheel on the outside lip

	_update_tip(actor, followed, delta)

	# A burst rim grinds sparks on the asphalt.
	if car.is_punctured and car.v > 2.0 and randf() < 0.65:
		var wheel_index: int = 0 if car.punctured_wheel == GtTypes.Wheel.FL or car.punctured_wheel == GtTypes.Wheel.RL else 1
		var wheel_z: float = -1.19 if car.punctured_wheel == GtTypes.Wheel.FL or car.punctured_wheel == GtTypes.Wheel.FR else 1.26
		var local := Vector3(-0.98 if wheel_index == 0 else 0.98, 0.1, wheel_z)
		_spark(actor.global_transform * local)


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
	_safety_car_state.team_id = 7 # the pale team colour reads as a marshal car
	_safety_car_state.compound = GtTypes.Compound.MEDIUM
	safety_car_actor = ActorScene.instantiate() as ActorScript
	world.add_child(safety_car_actor)
	safety_car_actor.bind(_safety_car_state, track)
	safety_car_actor.visible = false
	var bar := MeshInstance3D.new()
	bar.name = "LightBar"
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.12, 0.25)
	bar.mesh = box
	var amber := _lamp(Color("#ffaa00"), 5.0)
	bar.material_override = amber
	bar.position = Vector3(0.0, 1.45, 0.2)
	safety_car_actor.add_child(bar)
	_bar_materials.append(amber)


func _update_safety_car() -> void:
	var state: Dictionary = race.safety_car
	var active: bool = bool(state["active"])
	safety_car_actor.visible = active
	if not active:
		return
	var sc: GtCar = _safety_car_state
	sc.prev_s = sc.s
	sc.prev_lateral = sc.lateral
	sc.s = float(state["s"])
	sc.lateral = float(state["lateral"])
	sc.v = float(state["v"])
	safety_car_actor.present(1.0, 0.016)
	var bar := safety_car_actor.get_node("LightBar") as MeshInstance3D
	bar.visible = bool(state["lights_on"]) and sin(_clock * 12.0) > -0.3
