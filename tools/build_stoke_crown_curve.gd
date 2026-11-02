extends SceneTree

## Rebuild the homologated curve from the approved Phase 0 blueprint snapshot.
const Compiler := preload("res://tools/stoke_crown/compiler.gd")
const DATA := "res://assets/tracks/stoke_crown/data/"

func _initialize() -> void:
	var blueprint: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA + "blueprint.track.json"))
	var compiled: Dictionary = Compiler.compile(blueprint)
	assert(compiled.ok, "Stoke Crown blueprint compilation failed")
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	for point: Vector3 in compiled.points:
		curve.add_point(point)
	curve.add_point(compiled.points[0])
	var error := ResourceSaver.save(curve, DATA + "stoke_crown_curve.tres")
	assert(error == OK, "Could not save Stoke Crown curve")
	print("[PASS] Stoke Crown curve baked: %.3f m, %d control points" % [curve.get_baked_length(), curve.point_count])
	var strip: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA + "environment_strip.json"))
	var file := FileAccess.open("res://scripts/world/circuits/stoke_crown/stoke_crown_strip.gd", FileAccess.WRITE)
	assert(file != null)
	file.store_string("extends RefCounted\n\n## Baked environment strip; regenerate with tools/build_stoke_crown_curve.gd.\nconst SEGMENTS: Array[Dictionary] = " + JSON.stringify(strip.segments, "\t") + "\n")
	file.close()
	quit()
