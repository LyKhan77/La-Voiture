extends RefCounted
## Single definition of the wheel-fit measurements, used by the per-car chassis tests and by scratch/fit_cars.gd.
## Call these with a chassis whose wheels are attached (perform_pitstop_tire_change). Metres, chassis space.

const BIN_M := 0.04
const WINDOW_Z := 0.15
const GAP_MIN := 0.025
const GAP_MAX := 0.050
const SKIN_MIN := 0.050
const FLUSH_TOL := 0.015
const FLOOR_MIN := 0.040
const TRACK_HALF_MIN := 0.75
const TRACK_HALF_MAX := 0.95


## The tyre rubber's box in chassis space: x inner/outer face (absolute), radius, and the top y.
static func tire_box(chassis: ModularCarAssembler, socket: Marker3D) -> Dictionary:
	var tire: MeshInstance3D = socket.get_child(0).find_children("GT3_TireRubber", "MeshInstance3D", true, false)[0]
	var tb: AABB = (chassis.global_transform.affine_inverse() * tire.global_transform) * tire.get_aabb()
	return {
		"x_in": minf(absf(tb.position.x), absf(tb.end.x)),
		"x_out": maxf(absf(tb.position.x), absf(tb.end.x)),
		"radius": tb.size.y * 0.5,
		"bottom": tb.position.y,
		"top": socket.position.y + tb.size.y * 0.5,
	}


static func _vertices(chassis: ModularCarAssembler, surfaces: bool) -> PackedVector3Array:
	var mesh: ArrayMesh = chassis.base_body_mesh.mesh
	var verts := PackedVector3Array()
	for s: int in (mesh.get_surface_count() if surfaces else 1):
		verts.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	return verts


## Radial gap: the nearest body vertex (any surface, so the tub counts) inside the tyre's x slab, minus the tyre radius.
## "pen" counts vertices closer to the axle than the tyre radius. Returns {"gap": float, "pen": int}.
static func radial_gap(chassis: ModularCarAssembler, socket: Marker3D) -> Dictionary:
	var tb: Dictionary = tire_box(chassis, socket)
	var sg: float = signf(socket.position.x)
	var near: float = 999.0
	var pen: int = 0
	for v: Vector3 in _vertices(chassis, true):
		var ax: float = v.x * sg
		if ax > tb["x_in"] and ax < tb["x_out"]:
			var r: float = Vector2(v.y - socket.position.y, v.z - socket.position.z).length()
			near = minf(near, r)
			pen += int(r < tb["radius"])
	return {"gap": near - tb["radius"], "pen": pen}


## Tyre outer face minus the widest body point over the arch of this axle (same zone as the old chassis test: y 0.30..0.85,
## |dz| < 0.45). The fenders of the front and rear axle are not the same width, so each wheel is compared with its own axle.
static func flush_delta(chassis: ModularCarAssembler, socket: Marker3D) -> float:
	var tb: Dictionary = tire_box(chassis, socket)
	var sg: float = signf(socket.position.x)
	var widest: float = 0.0
	for v: Vector3 in _vertices(chassis, true):
		if v.y > 0.30 and v.y < 0.85 and absf(v.z - socket.position.z) < 0.45 and v.x * sg > 0.0:
			widest = maxf(widest, v.x * sg)
	return tb["x_out"] - widest


## Lowest fender skin above the tyre top across the tyre's width: the highest paint vertex per 4 cm bin of x (|dz| < 0.15 around
## the axle), minus the tyre top. A bin with no skin at all reads -1: the tyre pokes out of the body there.
static func fender_skin_min(chassis: ModularCarAssembler, socket: Marker3D) -> float:
	var tb: Dictionary = tire_box(chassis, socket)
	var sg: float = signf(socket.position.x)
	var skin: Array[float] = []
	skin.resize(maxi(1, int((tb["x_out"] - BIN_M - (tb["x_in"] + 0.02)) / BIN_M) + 1))
	skin.fill(-1.0)
	for v: Vector3 in _vertices(chassis, false):
		var bin: int = int((v.x * sg - (tb["x_in"] + 0.02) + 0.02) / BIN_M)
		if v.y > 0.30 and absf(v.z - socket.position.z) < WINDOW_Z and bin >= 0 and bin < skin.size():
			skin[bin] = maxf(skin[bin], v.y - tb["top"])
	return skin.min()


## Lowest body point (any surface).
static func floor_y(chassis: ModularCarAssembler) -> float:
	return chassis.base_body_mesh.get_aabb().position.y


## The four sockets mirror left to right, sit at axle height and at +-axle_z, with a plausible track half-width. The exact x per axle is
## not pinned here: scratch/fit_cars.gd --apply derives it from the mesh and flush_delta checks it.
static func sockets_consistent(chassis: ModularCarAssembler, axle_y: float, axle_z: float) -> bool:
	var fl: Vector3 = chassis.socket_wheel_fl.position
	var fr: Vector3 = chassis.socket_wheel_fr.position
	var rl: Vector3 = chassis.socket_wheel_rl.position
	var rr: Vector3 = chassis.socket_wheel_rr.position
	var mirrored: bool = is_equal_approx(fl.x, -fr.x) and is_equal_approx(rl.x, -rr.x) and fl.y == fr.y and rl.y == rr.y and fl.z == fr.z and rl.z == rr.z
	var placed: bool = is_equal_approx(fl.y, axle_y) and is_equal_approx(rl.y, axle_y) and is_equal_approx(fl.z, axle_z) and is_equal_approx(rl.z, -axle_z)
	var track: bool = absf(fr.x) >= TRACK_HALF_MIN and absf(fr.x) <= TRACK_HALF_MAX and absf(rr.x) >= TRACK_HALF_MIN and absf(rr.x) <= TRACK_HALF_MAX
	return mirrored and placed and track
