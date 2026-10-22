class_name MangaRain3D
extends Node3D

## Manga rain as 3D particles. A box of raindrops is kept ahead of the active
## camera; drops live in world space, so the camera really drives through them
## (parallax, hidden behind cars and the road). The streak shader stretches each
## drop along its velocity relative to the camera, which is why this node tracks
## the camera's velocity. It only draws what `set_intensity()` says (0..1).

const StreakShader := preload("res://assets/shaders/manga_rain_streaks.gdshader")

const AMOUNT: int = 2600
const LIFETIME_S: float = 1.0
const FALL_SPEED_MPS: float = 25.0
## Spawn box: centered this far ahead of and above the camera, big enough to
## fill the view out to the far fade of the shader.
const SPAWN_AHEAD_M: float = 28.0
const SPAWN_HEIGHT_M: float = 16.0
const SPAWN_HALF_EXTENTS := Vector3(24.0, 0.5, 42.0)
const CULL_AABB := AABB(Vector3(-70.0, -45.0, -110.0), Vector3(140.0, 90.0, 160.0))
## Share of the new camera velocity taken each physics frame; hides the jump when
## the camera snaps to another car.
const VELOCITY_SMOOTHING: float = 0.35

var intensity: float = 0.0

var _particles: GPUParticles3D
var _material: ShaderMaterial
var _camera_velocity: Vector3 = Vector3.ZERO
var _previous_camera_position: Vector3 = Vector3.ZERO
var _has_previous: bool = false


func _ready() -> void:
	_build()
	set_intensity(intensity)


func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	if _particles == null:
		return
	_particles.emitting = intensity > 0.0
	_particles.amount_ratio = maxf(intensity, 0.01)


func is_raining() -> bool:
	return _particles != null and _particles.emitting


func get_camera_velocity() -> Vector3:
	return _camera_velocity


func _physics_process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or delta <= 0.0:
		return
	var position: Vector3 = camera.global_position
	if _has_previous:
		_camera_velocity = _camera_velocity.lerp((position - _previous_camera_position) / delta, VELOCITY_SMOOTHING)
	_previous_camera_position = position
	_has_previous = true
	_material.set_shader_parameter("camera_velocity", _camera_velocity)
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 1e-6:
		return
	forward = forward.normalized()
	_particles.global_transform = Transform3D(
		Basis.looking_at(forward, Vector3.UP), position + forward * SPAWN_AHEAD_M + Vector3.UP * SPAWN_HEIGHT_M
	)


func _build() -> void:
	_material = ShaderMaterial.new()
	_material.shader = StreakShader
	_material.set_shader_parameter("rain_velocity", Vector3(0.0, -FALL_SPEED_MPS, 0.0))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _material
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = SPAWN_HALF_EXTENTS
	process.direction = Vector3.DOWN
	process.spread = 0.0
	process.initial_velocity_min = FALL_SPEED_MPS
	process.initial_velocity_max = FALL_SPEED_MPS
	process.gravity = Vector3.ZERO
	_particles = GPUParticles3D.new()
	_particles.name = "Streaks"
	_particles.amount = AMOUNT
	_particles.lifetime = LIFETIME_S
	_particles.local_coords = false
	_particles.visibility_aabb = CULL_AABB
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particles.process_material = process
	_particles.draw_pass_1 = quad
	_particles.emitting = false
	add_child(_particles)
	# The emitter is placed in world space every physics frame.
	_particles.top_level = true
