extends SceneTree

## Normalize generated originals to the setup card's bounded runtime size, without changing source art.
const Registry := preload("res://scripts/core/circuit_calendar_registry.gd")
const POSTER_ROOT := "res://assets/ui/circuit_posters/"

func _initialize() -> void:
	var failed: bool = false
	for circuit in Registry.get_all_circuits():
		var image := Image.load_from_file(POSTER_ROOT + "sources/%s.png" % circuit.circuit_id)
		if image == null or image.is_empty():
			push_error("Missing source: " + circuit.circuit_id)
			failed = true
			continue
		# Fit center crop tolerates minor aspect-ratio differences from the image generator.
		var width: int = mini(image.get_width(), roundi(image.get_height() * 16.0 / 9.0))
		var height: int = mini(image.get_height(), roundi(width * 9.0 / 16.0))
		image = image.get_region(Rect2i((image.get_width() - width) / 2, (image.get_height() - height) / 2, width, height))
		image.convert(Image.FORMAT_RGB8)
		image.resize(640, 360, Image.INTERPOLATE_LANCZOS)
		var output: String = POSTER_ROOT + "%s.png" % circuit.circuit_id
		if image.save_png(output) != OK:
			failed = true
			continue
		var saved := Image.load_from_file(output)
		if saved == null or saved.get_size() != Vector2i(640, 360):
			failed = true
		print("[%s] %s normalized to 640x360" % ["FAIL" if failed else "PASS", circuit.circuit_id])
	quit(1 if failed else 0)
