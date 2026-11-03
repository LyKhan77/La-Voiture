extends SceneTree

## Run headless after changing a circuit layout, or use -- --verify to check committed data.
const Registry := preload("res://scripts/core/circuit_calendar_registry.gd")
const MapView := preload("res://scripts/ui/track_map.gd")
const OUTPUT := "res://assets/ui/circuit_maps/previews.res"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var verify: bool = "--verify" in OS.get_cmdline_user_args()
	var result := Resource.new()
	var circuits: Dictionary = {}
	var failed: bool = false
	var view := MapView.new()
	root.add_child(view)
	for circuit in Registry.get_all_circuits():
		view.scene_path = circuit.scene_path
		var data: Dictionary = view.bake_track()
		if verify:
			var saved: Dictionary = MapView.MAP_DATA.get_meta("circuits", {}).get(circuit.scene_path, {})
			var equal: bool = data == saved
			print("[%s] %s baked map matches circuit source" % ["PASS" if equal else "FAIL", circuit.circuit_id])
			failed = failed or not equal
		elif not data.is_empty():
			circuits[circuit.scene_path] = data
			print("BAKED %s %d samples" % [circuit.circuit_id, (data["raw"] as PackedVector2Array).size()])
	view.free()
	if not verify:
		result.set_meta("circuits", circuits)
		var error: Error = ResourceSaver.save(result, OUTPUT)
		failed = error != OK
		print("[%s] saved %s" % ["FAIL" if failed else "PASS", OUTPUT])
	await process_frame
	quit(1 if failed else 0)
