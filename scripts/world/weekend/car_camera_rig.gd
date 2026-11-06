class_name CarCameraRig
extends RefCounted

## Per-car camera anchors, measured from the body mesh (the cars have no cockpit, and every nose is a
## different length and height). All numbers are in the chassis frame: the model's front is +Z.
## Measured once per mesh and cached; the body has ~100k vertices.

const HOOD_EYE_LIFT_M: float = 0.12 # eye height above the highest body point ahead of it
const HOOD_EYE_NOSE_SHARE: float = 0.2 # how far from the front axle to the nose the eye sits: back enough to leave a long hood in frame
const HOOD_STRIP_HALF_M: float = 0.35 # centre strip of the body that counts as "hood"
const FALLBACK_NOSE_Z: float = 2.2
const FALLBACK_AXLE_Z: float = 1.3
const FALLBACK_HALF_WIDTH: float = 1.0
const FALLBACK_EYE := Vector3(0.0, 1.0, 1.7)

static var _cache: Dictionary = {}

var eye: Vector3 = FALLBACK_EYE
var nose_z: float = FALLBACK_NOSE_Z
var tail_z: float = -FALLBACK_NOSE_Z
var axle_z: float = FALLBACK_AXLE_Z
var half_width: float = FALLBACK_HALF_WIDTH


static func measure(chassis: Node3D) -> CarCameraRig:
	var body: MeshInstance3D = chassis.get("base_body_mesh") as MeshInstance3D
	if body == null or body.mesh == null:
		return CarCameraRig.new()
	var key: int = body.mesh.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var rig := CarCameraRig.new()
	rig._measure(chassis, body)
	_cache[key] = rig
	return rig


func _measure(chassis: Node3D, body: MeshInstance3D) -> void:
	var to_chassis: Transform3D = chassis.global_transform.affine_inverse() * body.global_transform
	var bounds: AABB = to_chassis * body.mesh.get_aabb()
	nose_z = bounds.end.z
	tail_z = bounds.position.z
	half_width = bounds.size.x * 0.5
	var socket := chassis.get_node_or_null("Sockets/Socket_Wheel_FL") as Node3D
	if socket != null:
		axle_z = socket.position.z
		half_width = maxf(half_width, absf(socket.position.x))
	var eye_z: float = lerpf(axle_z, nose_z, HOOD_EYE_NOSE_SHARE)
	var top_y: float = -INF
	for surface: int in range(body.mesh.get_surface_count()):
		var vertices: PackedVector3Array = body.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for local: Vector3 in vertices:
			var v: Vector3 = to_chassis * local
			if absf(v.x) < HOOD_STRIP_HALF_M and v.z >= eye_z - 0.05 and v.y > top_y:
				top_y = v.y
	if top_y == -INF:
		top_y = bounds.position.y + bounds.size.y * 0.5
	eye = Vector3(0.0, top_y + HOOD_EYE_LIFT_M, eye_z)
