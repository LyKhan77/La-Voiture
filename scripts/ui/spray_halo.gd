extends Control

## Spray-can bloom behind the main menu title: an acid-lime core inside a wider crimson halo. Each
## disc is built from stacked low-alpha circles so the edge bleeds out like a soft nozzle blast.

const CORE_COLOR := Color("#d8ff00", 0.40)
const HALO_COLOR := Color("#ff1a4b", 0.22)
const CORE_RADIUS: float = 140.0
const HALO_RADIUS: float = 280.0
const LAYERS: int = 14


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	_bloom(HALO_RADIUS, HALO_COLOR)
	_bloom(CORE_RADIUS, CORE_COLOR)


## Stacked circles from the full radius down to the centre; the alpha of each is the share that
## adds up to `color.a` where all of them overlap.
func _bloom(radius: float, color: Color) -> void:
	var step_alpha: float = 1.0 - pow(1.0 - color.a, 1.0 / float(LAYERS))
	for layer: int in range(LAYERS):
		var share: float = 1.0 - float(layer) / float(LAYERS)
		draw_circle(Vector2.ZERO, radius * share, Color(color, step_alpha))
