class_name MangaRoadSpray
extends GPUParticles3D

## Rooster-tail of road water behind a car, drawn as flat manga puffs. Attach it
## behind the rear wheels of a car (local +Z is the rear). Puffs live in world
## space, so the tail hangs in the air behind the car; `set_strength()` scales how
## much is thrown (0 = nothing), e.g. wetness * speed.

const PuffShader := preload("res://assets/shaders/manga_spray_puff.gdshader")

const AMOUNT: int = 22
const LIFETIME_S: float = 0.6
const PUFF_SIZE_M: float = 0.8
const THROW_SPEED_MIN_MPS: float = 5.0
const THROW_SPEED_MAX_MPS: float = 9.0
const GRAVITY_MPS2: float = -6.0
const MIN_STRENGTH: float = 0.05

var strength: float = 0.0


func _init() -> void:
	var material := ShaderMaterial.new()
	material.shader = PuffShader
	var quad := QuadMesh.new()
	quad.size = Vector2(PUFF_SIZE_M, PUFF_SIZE_M)
	quad.material = material
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.9, 0.1, 0.2)
	process.direction = Vector3(0.0, 0.55, 1.0)
	process.spread = 22.0
	process.initial_velocity_min = THROW_SPEED_MIN_MPS
	process.initial_velocity_max = THROW_SPEED_MAX_MPS
	process.gravity = Vector3(0.0, GRAVITY_MPS2, 0.0)
	name = "RoadSpray"
	amount = AMOUNT
	lifetime = LIFETIME_S
	local_coords = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	process_material = process
	draw_pass_1 = quad
	emitting = false


func set_strength(value: float) -> void:
	strength = clampf(value, 0.0, 1.0)
	emitting = strength > MIN_STRENGTH
	amount_ratio = maxf(strength, MIN_STRENGTH)
