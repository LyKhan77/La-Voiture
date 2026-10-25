extends SceneTree
## Re-samples the untouched master mesh at 30 Hz; prints sole support indices for the choreographer.
## Read-only asset calibration: godot --headless --path . -s scratch/calibrate_pitcrew_soles.gd
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var model: Node3D = load("res://assets/characters/pitcrew/pitcrew_master.glb").instantiate()
	root.add_child(model)
	await process_frame
	var mesh: MeshInstance3D = model.find_child("char1", true, false)
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var a: Array = mesh.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var supports: Dictionary = {}
	var worst: float = 0.0
	for clip: String in ["idle", "walk", "run", "tire_service"]:
		var length: float = ap.get_animation(clip).length
		ap.play(clip)
		for sample: int in range(int(ceil(length*30.0))+1):
			ap.seek(minf(float(sample)/30.0,length),true)
			sk.force_update_all_bone_transforms()
			var poses: Array[Transform3D] = []
			for bind: int in range(mesh.skin.get_bind_count()):
				poses.append(sk.global_transform * sk.get_bone_global_pose(sk.find_bone(mesh.skin.get_bind_name(bind))) * mesh.skin.get_bind_pose(bind))
			var minimum: float = INF
			var lowest: int = -1
			for i: int in range(verts.size()):
				if verts[i].y > 0.15: continue
				var y: float = 0.0
				for j: int in range(4):
					var w: float = weights[i*4+j]
					if w > 0.0: y += (poses[bones[i*4+j]] * verts[i]).y * w
				if y < minimum:
					minimum = y
					lowest = i
			supports[lowest] = true
			worst = maxf(worst,absf(minimum))
	print("SUPPORTS ", supports.keys())
	print("MAXIMUM UNCLAMPED SOLE ERROR ", worst)
	model.queue_free()
	await process_frame
	quit()
