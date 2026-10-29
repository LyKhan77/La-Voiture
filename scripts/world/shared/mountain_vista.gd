class_name MountainVista
extends Node3D

## Horizon backdrop for the Apex Ring (FASE 10): three concentric ridge lines of jagged
## low-poly mountains out to about 1500 m, hazier the farther they are, plus a star field
## for night races. The ring is centred on the middle of the circuit; each layer is one
## surface with its own haze material, so the whole range is three draw calls. The mountain
## bases are buried just under the ground plane.

const HazeShader := preload("res://shaders/mountain_haze.gdshader")

const SEED: int = 8128
const SEGMENTS: int = 220
## Distance of each ridge line from the circuit centre, nearest first. The farthest is the "R ~ 1500 m" ring.
const LAYER_RADII_M: Array[float] = [1250.0, 1380.0, 1500.0]
## Crest height range (min, max) per layer, and the noise frequency around the ring.
const LAYER_HEIGHTS_M: Array[Vector2] = [Vector2(90.0, 240.0), Vector2(150.0, 330.0), Vector2(220.0, 470.0)]
const LAYER_NOISE_FREQ: Array[float] = [3.0, 2.4, 1.9]
const LAYER_COLORS: Array[Color] = [Color("#3a5f7d"), Color("#5a82a3"), Color("#8eaecb")]
const LAYER_HAZE: Array[float] = [0.10, 0.32, 0.55]
## A flank rises from this far inside the crest radius per meter of height (steep: jagged peaks).
const FLANK_RUN_PER_M: float = 0.5
const BASE_Y_M: float = -8.0
const NOISE_OCTAVES: int = 4
const SHARPNESS: float = 1.5

const STAR_COUNT: int = 900
const STAR_RADIUS_M: float = 2500.0
const STAR_MIN_ELEVATION_DEG: float = 3.0
const STAR_SIZE_M: Vector2 = Vector2(9.0, 22.0)

var ridge_instance: MeshInstance3D
var star_instance: MultiMeshInstance3D
var star_material: StandardMaterial3D
var star_count: int = 0
## Centre of the ring (the middle of the circuit's bounding box, on the ground).
var centre: Vector3 = Vector3.ZERO
var haze_materials: Array[ShaderMaterial] = []


## Builds the ring around the ribbon's bounding-box centre.
func build(ribbon: TrackRibbon) -> void:
	centre = _circuit_centre(ribbon)
	_build_ridges()
	_build_stars()


## Retints the ring for the time of day: haze toward the sky horizon, crest light from the sun,
## stars fading in at night (`stars_opacity` of the weather's time-of-day dictionary, 0..1).
func set_time_of_day(tod: Dictionary, horizon: Color, sun_color: Color, gloom: float) -> void:
	var night: float = float(tod["floodlights"])
	for material: ShaderMaterial in haze_materials:
		material.set_shader_parameter("haze_color", horizon)
		material.set_shader_parameter("ridge_light", sun_color)
		material.set_shader_parameter("brightness", lerpf(1.0, 0.3, night) * lerpf(1.0, 0.7, gloom))
		material.set_shader_parameter("haze_strength", lerpf(1.0, 0.8, night))
	star_material.albedo_color = Color(1.0, 1.0, 1.0, clampf(float(tod["stars_opacity"]) * (1.0 - gloom), 0.0, 1.0))
	star_instance.visible = star_material.albedo_color.a > 0.01


func _circuit_centre(ribbon: TrackRibbon) -> Vector3:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var s: float = 0.0
	while s < ribbon.length_m:
		var point: Vector3 = ribbon.get_point_at_offset(s, 0.0).origin
		low = Vector2(minf(low.x, point.x), minf(low.y, point.z))
		high = Vector2(maxf(high.x, point.x), maxf(high.y, point.z))
		s += 6.0
	var middle: Vector2 = (low + high) * 0.5
	return Vector3(middle.x, 0.0, middle.y)


## One surface per layer: a strip of flanks from a buried base ring up to a jagged ridge line.
func _build_ridges() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = NOISE_OCTAVES
	noise.frequency = 1.0
	var mesh := ArrayMesh.new()
	for layer: int in range(LAYER_RADII_M.size()):
		var crest := PackedVector3Array()
		var base := PackedVector3Array()
		for index: int in range(SEGMENTS):
			var angle: float = TAU * float(index) / float(SEGMENTS)
			var direction := Vector3(cos(angle), 0.0, sin(angle))
			# Sampled on a circle in noise space so the ring closes without a seam.
			var ridged: float = 1.0 - absf(noise.get_noise_2d(direction.x * LAYER_NOISE_FREQ[layer] + float(layer) * 17.0, direction.z * LAYER_NOISE_FREQ[layer]))
			var height: float = lerpf(LAYER_HEIGHTS_M[layer].x, LAYER_HEIGHTS_M[layer].y, pow(clampf(ridged, 0.0, 1.0), SHARPNESS))
			crest.append(centre + direction * LAYER_RADII_M[layer] + Vector3.UP * height)
			base.append(centre + direction * (LAYER_RADII_M[layer] - height * FLANK_RUN_PER_M) + Vector3.UP * BASE_Y_M)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index: int in range(SEGMENTS):
			var next: int = (index + 1) % SEGMENTS
			_emit_flank(st, base[index], base[next], crest[next], crest[index])
		st.commit(mesh)
		var material := ShaderMaterial.new()
		material.shader = HazeShader
		material.set_shader_parameter("layer_color", LAYER_COLORS[layer])
		material.set_shader_parameter("layer_haze", LAYER_HAZE[layer])
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
		haze_materials.append(material)
	ridge_instance = MeshInstance3D.new()
	ridge_instance.name = "Ridges"
	ridge_instance.mesh = mesh
	ridge_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ridge_instance)


## One flank quad facing the circuit. Vertex alpha is the height fraction the shader bands and
## hazes by: 0 on the buried base edge, 1 on the crest.
func _emit_flank(st: SurfaceTool, base_a: Vector3, base_b: Vector3, crest_b: Vector3, crest_a: Vector3) -> void:
	var corners: Array[Vector3] = [base_a, base_b, crest_b, base_a, crest_b, crest_a]
	var alphas: Array[float] = [0.0, 0.0, 1.0, 0.0, 1.0, 1.0]
	var toward_centre: Vector3 = (centre - (crest_a + crest_b) * 0.5) * Vector3(1.0, 0.0, 1.0)
	var normal: Vector3 = (crest_b - base_a).cross(base_b - base_a)
	if normal.dot(toward_centre) < 0.0:
		# Wrong way round: swap the second and third corner of each triangle so it winds clockwise from the circuit.
		corners = [base_a, crest_b, base_b, base_a, crest_a, crest_b]
		alphas = [0.0, 1.0, 0.0, 0.0, 1.0, 1.0]
		normal = -normal
	normal = normal.normalized()
	for index: int in range(corners.size()):
		st.set_color(Color(1.0, 1.0, 1.0, alphas[index]))
		st.set_normal(normal)
		st.add_vertex(corners[index])

## Billboard points on the upper dome, one MultiMesh; the sky controller sets their opacity.
func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	star_material = StandardMaterial3D.new()
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	star_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star_material.billboard_keep_scale = true
	star_material.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	star_material.disable_fog = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = star_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = STAR_COUNT
	for index: int in range(STAR_COUNT):
		var elevation: float = deg_to_rad(rng.randf_range(STAR_MIN_ELEVATION_DEG, 89.0))
		var azimuth: float = rng.randf() * TAU
		var position := Vector3(cos(azimuth) * cos(elevation), sin(elevation), sin(azimuth) * cos(elevation)) * STAR_RADIUS_M
		var size: float = rng.randf_range(STAR_SIZE_M.x, STAR_SIZE_M.y)
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), centre + position))
	star_count = STAR_COUNT
	star_instance = MultiMeshInstance3D.new()
	star_instance.name = "Stars"
	star_instance.multimesh = multimesh
	star_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star_instance.visible = false
	add_child(star_instance)
