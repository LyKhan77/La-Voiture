extends SceneTree

## Run: godot --headless --path . -s res://tests/test_podium_car_sprites.gd
## The podium draws each car as a baked 2D sprite (tools/bake_podium_car_sprites.gd). The shared check must
## reject bad sprites before it is trusted on the real ones.
const Checks := preload("res://tests/podium_sprite_checks.gd")
const Roster := preload("res://scripts/ui/garage_roster.gd")
var failures: int = 0
var assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])


## A filled ellipse that touches the middle of every edge: transparent corners, a ground row, 0.785 fill.
func _ellipse(width: int, height: int) -> Image:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var a: float = float(width) * 0.5
	var b: float = float(height) * 0.5
	for y: int in range(height):
		var dy: float = (float(y) + 0.5 - b) / b
		var half: int = int(a * sqrt(maxf(0.0, 1.0 - dy * dy)))
		if half > 0:
			image.fill_rect(Rect2i(int(a) - half, y, half * 2, 1), Color(0.7, 0.2, 0.2, 1.0))
	return image


func _run() -> void:
	var block := Image.create_empty(Checks.WIDTH, 900, false, Image.FORMAT_RGBA8)
	block.fill(Color.WHITE)
	check(not Checks.problems(block).is_empty(), "A fully opaque block is rejected")
	var empty := Image.create_empty(Checks.WIDTH, 900, false, Image.FORMAT_RGBA8)
	check(not Checks.problems(empty).is_empty(), "An empty image is rejected")
	var cornered: Image = _ellipse(Checks.WIDTH, 900)
	cornered.set_pixel(0, 0, Color.WHITE)
	check(not Checks.problems(cornered).is_empty(), "A 1600 wide image with an opaque corner is rejected")
	var good: Image = _ellipse(Checks.WIDTH, 900)
	check(Checks.problems(good).is_empty(), "A car-like ellipse with a ground row passes: %s" % str(Checks.problems(good)))
	var narrow: Image = _ellipse(1200, 700)
	check(not Checks.problems(narrow).is_empty(), "A sprite that is not 1600 wide is rejected")

	for team: int in range(Roster.CAR_SLUGS.size()):
		var slug: String = Roster.CAR_SLUGS[team]
		var path: String = Roster.podium_sprite_path(team)
		var image: Image = (load(path) as Texture2D).get_image() if ResourceLoader.exists(path) else null
		var found: Array[String] = []
		if image == null:
			found.append("missing file %s" % path)
		else:
			found = Checks.problems(image)
		check(found.is_empty(), "%s has a podium sprite that passes the checks %s" % [slug, str(found)])
	print("PODIUM CAR SPRITES: %d assertions, %d FAIL" % [assertions, failures])
	quit(0 if failures == 0 else 1)
