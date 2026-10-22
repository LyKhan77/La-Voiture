extends SceneTree

const CHASSIS = {
	"porsche_911": "res://scenes/car/base_chassis.tscn",
	"audi_r8": "res://scenes/car/audi_r8_chassis.tscn",
	"nissan_gtr": "res://scenes/car/nissan_gtr_chassis.tscn",
	"aston_vantage": "res://scenes/car/aston_vantage_chassis.tscn",
	"bmw_m4": "res://scenes/car/bmw_m4_chassis.tscn",
	"lambo_huracan": "res://scenes/car/lambo_huracan_chassis.tscn",
	"honda_nsx": "res://scenes/car/honda_nsx_chassis.tscn",
	"chevy_corvette": "res://scenes/car/chevy_corvette_chassis.tscn",
	"lexus_rcf": "res://scenes/car/lexus_rcf_chassis.tscn",
	"mclaren_720s": "res://scenes/car/mclaren_720s_chassis.tscn"
}

const WheelScene := preload("res://scenes/car/parts/porsche_wheel_soft.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("================================================================================")
	print("DIAGNOSIS OF WHEEL FIT & FENDER CLIPPING ACROSS ALL 10 CARS")
	print("================================================================================")
	
	for car_name: String in CHASSIS:
		var scene_path: String = CHASSIS[car_name]
		var scene: PackedScene = load(scene_path)
		if scene == null:
			print("Could not load scene: ", scene_path)
			continue
		var chassis: ModularCarAssembler = scene.instantiate()
		root.add_child(chassis)
		await process_frame
		
		chassis.perform_pitstop_tire_change(WheelScene, ModularCarAssembler.TireCompound.SOFT)
		await process_frame
		
		var body_mesh: MeshInstance3D = chassis.base_body_mesh
		if body_mesh == null or body_mesh.mesh == null:
			print(car_name, ": base_body_mesh is null!")
			chassis.queue_free()
			continue
			
		var verts: PackedVector3Array = body_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var aabb: AABB = body_mesh.get_aabb()
		
		print("\n--- CAR: %s ---" % car_name)
		print("Body AABB: size (%.3f, %.3f, %.3f), pos (%.3f, %.3f, %.3f)" % [aabb.size.x, aabb.size.y, aabb.size.z, aabb.position.x, aabb.position.y, aabb.position.z])
		
		var sockets = {
			"FL": chassis.socket_wheel_fl,
			"FR": chassis.socket_wheel_fr,
			"RL": chassis.socket_wheel_rl,
			"RR": chassis.socket_wheel_rr
		}
		
		for s_name in sockets:
			var s: Marker3D = sockets[s_name]
			if s == null:
				continue
			var sp: Vector3 = s.position
			
			# Tire geometry: radius 0.33, center at sp.
			# Top of tire: y = sp.y + 0.33
			# Bottom of tire: y = sp.y - 0.33 (ground = 0)
			# Find closest fender vertex directly above tire top (|x - sp.x| < 0.2, |z - sp.z| < 0.15, y > sp.y)
			var min_fender_y: float = 999.0
			var clipping_verts: int = 0
			var severe_clip: int = 0
			
			for v: Vector3 in verts:
				var dx = absf(v.x - sp.x)
				var dy = v.y - sp.y
				var dz = absf(v.z - sp.z)
				var dist_2d = Vector2(dy, v.z - sp.z).length()
				
				# Check if vertex is inside the tire cylinder (radius 0.33, width ~0.35m around wheel center)
				if dx < 0.18 and dist_2d < 0.33:
					clipping_verts += 1
					if dist_2d < 0.30:
						severe_clip += 1
						
				# Find fender lip above wheel
				if dx < 0.25 and dz < 0.15 and v.y > sp.y + 0.25:
					if v.y < min_fender_y:
						min_fender_y = v.y
			
			var clearance = min_fender_y - (sp.y + 0.33)
			print("  Socket %s: (%.3f, %.3f, %.3f) | Top of Tire: %.3f | Fender Min Y: %.3f | Clearance: %+.3fm | Penetrating Verts: %d (severe: %d)" % [
				s_name, sp.x, sp.y, sp.z, sp.y + 0.33, min_fender_y, clearance, clipping_verts, severe_clip
			])
			
		chassis.queue_free()
		await process_frame
		
	print("\n================================================================================")
	quit(0)
