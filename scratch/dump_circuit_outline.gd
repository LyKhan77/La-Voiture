extends SceneTree

## Writes the circuit's top-down outline (and the sharpest corners) as JSON for the Race Setup concept mockups:
##   godot --headless --path . -s res://scratch/dump_circuit_outline.gd

const Ribbon := preload("res://scripts/car/track_ribbon.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ribbon := load("res://scenes/race_world/track_circuit.tscn").instantiate() as Ribbon
	root.add_child(ribbon)
	await process_frame
	var points: Array = []
	var corners: Array = []
	var step: float = 15.0
	var count: int = int(ribbon.length_m / step)
	var last_corner: float = -1000.0
	for index: int in range(count):
		var s: float = float(index) * step
		var p: Vector3 = ribbon.get_point_on_ribbon(s, 1).origin
		points.append([snappedf(p.x, 0.1), snappedf(p.z, 0.1), snappedf(p.y, 0.1)])
		var radius: float = ribbon.get_radius_at(s)
		if radius < 90.0 and s - last_corner > 120.0:
			corners.append({"s": s, "i": index, "r": snappedf(radius, 1.0)})
			last_corner = s
	var file := FileAccess.open(ProjectSettings.globalize_path("res://temp/concepts/circuit_outline.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"length_m": ribbon.length_m, "points": points, "corners": corners}))
	file.close()
	print("outline: %d points, %d corners, %.0f m" % [points.size(), corners.size(), ribbon.length_m])
	quit(0)
