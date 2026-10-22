class_name WheelController extends Node3D

## Controller roda GT3: menangani rotasi ban saat melaju dan pergantian kompon.
## Hierarki: BrakeCaliper tetap diam, WheelRotating berputar pada sumbu X.

const BRAKE_GLOW_COLOR := Color(1.0, 0.32, 0.04)
const BRAKE_GLOW_ENERGY: float = 6.0

@export var angular_speed: float = 0.0 # rad/s
@export var wheel_radius_m: float = 0.33 # Radius efektif GT3

## 0..1 heat of the brake rotor; drives the emissive overlay on GT3_BrakeDisc.
var brake_glow: float = 0.0

var wheel_rotating: Node3D
var brake_caliper: MeshInstance3D
var brake_disc: MeshInstance3D

var _glow_material: StandardMaterial3D

func _ready() -> void:
	wheel_rotating = find_child("WheelRotating", true, false) as Node3D
	brake_caliper = find_child("GT3_BrakeCaliper", true, false) as MeshInstance3D
	brake_disc = find_child("GT3_BrakeDisc", true, false) as MeshInstance3D

func _process(delta: float) -> void:
	if angular_speed != 0.0 and wheel_rotating:
		wheel_rotating.rotation.x += _spin_sign() * angular_speed * delta

## Update kecepatan putar berdasarkan kecepatan linear mobil (m/s)
func set_rolling_speed(forward_speed_mps: float) -> void:
	angular_speed = forward_speed_mps / max(0.01, wheel_radius_m)

## Hentikan putaran
func stop_rotation() -> void:
	angular_speed = 0.0

## Glows the rotor orange; 0 removes the overlay so a cold disc costs nothing.
func set_brake_glow(level: float) -> void:
	brake_glow = clampf(level, 0.0, 1.0)
	if brake_disc == null:
		return
	if brake_glow <= 0.01:
		brake_disc.material_overlay = null
		return
	if _glow_material == null:
		_glow_material = StandardMaterial3D.new()
		_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glow_material.emission_enabled = true
		_glow_material.emission = BRAKE_GLOW_COLOR
	_glow_material.albedo_color = Color(BRAKE_GLOW_COLOR, brake_glow)
	_glow_material.emission_energy_multiplier = BRAKE_GLOW_ENERGY * brake_glow
	brake_disc.material_overlay = _glow_material

## The assembler turns left-side wheels half a turn so their outer face points
## out; the same spin then runs backwards unless the sign is flipped.
func _spin_sign() -> float:
	var socket := get_parent() as Node3D
	return -1.0 if socket != null and socket.position.x < 0.0 else 1.0
