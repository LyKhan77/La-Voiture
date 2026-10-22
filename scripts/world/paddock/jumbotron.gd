class_name Jumbotron
extends MeshInstance3D

## Giant LED screen on the grandstand roof (FASE 10). The live leaderboard is drawn by
## shaders/led_jumbotron.gdshader from ten team colours and ten bar lengths, so refreshing
## it is two uniform writes. The quad faces local +Z; the grandstand turns it to the track.

const LedShader := preload("res://shaders/led_jumbotron.gdshader")

const ROWS: int = 10

## Team colours of the ten rows last sent to the shader, leader first.
var last_row_colors: Array[Color] = []
var last_row_values: Array[float] = []

var _material: ShaderMaterial


func build(size: Vector2) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	_material = ShaderMaterial.new()
	_material.shader = LedShader
	quad.material = _material
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var blank: Array[Color] = []
	var flat: Array[float] = []
	for _row: int in range(ROWS):
		blank.append(Color("#1c1f26"))
		flat.append(0.0)
	set_leaderboard(blank, flat)


## `colors` and `values` are leader first; values 0..1 set the bar length of each row.
func set_leaderboard(colors: Array[Color], values: Array[float]) -> void:
	last_row_colors = colors.duplicate()
	last_row_values = values.duplicate()
	if _material == null:
		return
	var packed_colors := PackedColorArray()
	var packed_values := PackedFloat32Array()
	for row: int in range(ROWS):
		packed_colors.append(colors[row] if row < colors.size() else Color.BLACK)
		packed_values.append(values[row] if row < values.size() else 0.0)
	_material.set_shader_parameter("row_colors", packed_colors)
	_material.set_shader_parameter("row_values", packed_values)


## 0 = screen dark, 1 = full day brightness; the lighting controller dims it for the night.
func set_brightness(amount: float) -> void:
	if _material != null:
		_material.set_shader_parameter("brightness", amount)
