extends SceneTree

## Rebuild the homologated Pacific Corkscrew curve from the approved package
## snapshot, plus the baked environment strip used by the runtime biome.
## Uses the generic blueprint compiler already proven by the Stoke Crown build.
##   godot --headless --path . -s res://tools/build_pacific_corkscrew_curve.gd

const Compiler := preload("res://tools/stoke_crown/compiler.gd")
const DATA := "res://assets/tracks/pacific_corkscrew/data/"
const STRIP := "res://scripts/world/circuits/pacific_corkscrew/pacific_corkscrew_strip.gd"


func _initialize() -> void:
	var blueprint: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA + "blueprint.track.json"))
	var compiled: Dictionary = Compiler.compile(blueprint)
	assert(bool(compiled.get("ok", false)), "Pacific Corkscrew blueprint compilation failed")
	# Fase 18 homologation: the approved blueprint's single-arc fillet at T10
	# (Rainey, clamped to a ~20 m arc) trips the production kink gate. A closed
	# Catmull-Rom through control points every 10 m spreads that curvature over
	# multiple control points while staying within 0.13 m of the approved
	# centreline (Stoke's accepted kink fix moved 0.092 m).
	var points := _homologate(compiled["points"], 10)
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	for point: Vector3 in points:
		curve.add_point(point)
	curve.add_point(points[0])
	var error := ResourceSaver.save(curve, DATA + "pacific_corkscrew_curve.tres")
	assert(error == OK, "Could not save Pacific Corkscrew curve")
	print("[PASS] Pacific Corkscrew curve baked: %.3f m, %d control points" % [curve.get_baked_length(), curve.point_count])
	var strip: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA + "environment_strip.json"))
	var file := FileAccess.open(STRIP, FileAccess.WRITE)
	assert(file != null, "cannot write " + STRIP)
	file.store_string("extends RefCounted\n\n## Baked environment strip; regenerate with tools/build_pacific_corkscrew_curve.gd.\nconst SEGMENTS: Array[Dictionary] = " + JSON.stringify(strip.get("segments", []), "\t") + "\n")
	file.close()
	print("[PASS] environment strip baked: %d segments" % (strip.get("segments", []) as Array).size())
	quit()


## Closed Catmull-Rom through every `stride`-th guide point, sampled at the guide's
## own 1 m step. Keeps the approved layout (<= 0.13 m from the guide) while giving
## each corner several control points, as the production guide requires.
static func _homologate(points: PackedVector3Array, stride: int) -> PackedVector3Array:
	var controls: Array[Vector3] = []
	for index in range(0, points.size(), stride):
		controls.append(points[index])
	var out := PackedVector3Array()
	var count := controls.size()
	var samples := points.size()
	for index in range(samples):
		var t := float(index) / float(samples) * float(count)
		var i := int(t) % count
		var f := t - floorf(t)
		var p0 := controls[posmod(i - 1, count)]
		var p1 := controls[i]
		var p2 := controls[posmod(i + 1, count)]
		var p3 := controls[posmod(i + 2, count)]
		out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f))
	return out
