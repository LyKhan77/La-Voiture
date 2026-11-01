extends RefCounted
## Single definition of what a baked podium car sprite must look like. Used by test_podium_car_sprites.gd.
## A sprite is a transparent PNG of one car, trimmed to its silhouette and scaled to a fixed width.

const WIDTH := 1600
const ASPECT_MIN := 1.3
const ASPECT_MAX := 2.1
const FILL_MIN := 0.25
const FILL_MAX := 0.85
const GROUND_ROWS := 8
const CORNER_ALPHA_MAX := 0.05
const GROUND_ALPHA_MIN := 0.8


## Empty when the image passes; otherwise one line per problem.
static func problems(image: Image) -> Array[String]:
	var found: Array[String] = []
	if image == null or image.is_empty():
		found.append("image is empty")
		return found
	if image.get_format() != Image.FORMAT_RGBA8:
		found.append("format is %d, not RGBA8" % image.get_format())
		return found
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width != WIDTH:
		found.append("width is %d, not %d" % [width, WIDTH])
	var aspect: float = float(width) / float(height)
	if aspect < ASPECT_MIN or aspect > ASPECT_MAX:
		found.append("aspect %.2f is outside %.1f..%.1f" % [aspect, ASPECT_MIN, ASPECT_MAX])
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(width - 1, 0), Vector2i(0, height - 1), Vector2i(width - 1, height - 1)]:
		if image.get_pixelv(corner).a > CORNER_ALPHA_MAX:
			found.append("corner %s is not transparent" % corner)
	var grounded: bool = false
	for y: int in range(height - GROUND_ROWS, height):
		for x: int in range(width):
			if image.get_pixel(x, y).a > GROUND_ALPHA_MIN:
				grounded = true
				break
		if grounded:
			break
	if not grounded:
		found.append("no opaque pixel in the bottom %d rows" % GROUND_ROWS)
	var opaque: int = 0
	for y: int in range(0, height, 4):
		for x: int in range(0, width, 4):
			if image.get_pixel(x, y).a > 0.5:
				opaque += 1
	var fill: float = float(opaque) / float(((width + 3) / 4) * ((height + 3) / 4))
	if fill < FILL_MIN or fill > FILL_MAX:
		found.append("silhouette fills %.2f of its box, expected %.2f..%.2f" % [fill, FILL_MIN, FILL_MAX])
	return found
