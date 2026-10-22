extends Control

const UI = preload("res://scripts/ui/pit_wall_ui.gd")
const T = preload("res://scripts/ui/ui_theme_tokens.gd")
# Authored circuit schematic, not a collision or simulation path.
const MAP = [Vector2(.12,.78), Vector2(.31,.79), Vector2(.44,.68), Vector2(.39,.57), Vector2(.49,.51), Vector2(.43,.43), Vector2(.54,.36), Vector2(.50,.29), Vector2(.61,.24), Vector2(.71,.30), Vector2(.84,.16), Vector2(.92,.23), Vector2(.85,.42), Vector2(.70,.53), Vector2(.58,.60), Vector2(.47,.73), Vector2(.32,.66), Vector2(.22,.49), Vector2(.10,.46), Vector2(.06,.59), Vector2(.12,.78)]
var cars: Array = []
var selected_car_id := 0
var packet: Dictionary = {}
var history: Array[float] = []
var _sample_elapsed := 0.0
var _clock := 0.0
var _map_rect := Rect2()
var _graph_rect := Rect2()
var _title: Label
var _speed: Label
var _lap: Label
var _sector: Label
var _viewer: SubViewportContainer
var _car_root: Node3D
var _paint: StandardMaterial3D
var _camera: Camera3D
var _map_lengths := PackedFloat32Array()
var _map_total := 0.0

func _ready() -> void:
	UI.surface(self)
	var title := UI.header("02 / LIVE CAR FEED", T.ACCENT_ELECTRIC_CYAN)
	add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 14
	title.offset_right = -14
	title.offset_top = 14
	title.offset_bottom = 42
	_title = UI.label("CAR #01 / APEX RACING", 24, T.TEXT_PRIMARY, UI.HEADER)
	add_child(_title)
	_title.position = Vector2(26, 60)
	_speed = UI.label("000", 72, T.ACCENT_ACID_LIME, UI.DISPLAY)
	add_child(_speed)
	_speed.position = Vector2(26, 100)
	var unit := UI.label("KM/H // LIVE", 12, T.TEXT_SECONDARY)
	add_child(unit)
	unit.position = Vector2(29, 187)
	_lap = UI.label("LAST LAP  --:--.---", 14)
	add_child(_lap)
	_lap.position = Vector2(26, 224)
	_sector = UI.label("SECTOR 01 / AWAITING SPLIT", 12, T.ACCENT_ELECTRIC_CYAN)
	add_child(_sector)
	_sector.position = Vector2(26, 252)
	_build_viewer()
	for i: int in range(MAP.size() - 1):
		_map_total += MAP[i].distance_to(MAP[i + 1])
		_map_lengths.append(_map_total)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	_viewer.position = Vector2(size.x * .36, 58)
	_viewer.size = Vector2(size.x * .61, size.y * .40)
	_map_rect = Rect2(24, size.y * .47, size.x * .55, size.y * .30)
	_graph_rect = Rect2(28, size.y - 120, size.x - 56, 78)
	queue_redraw()

func select_car(car_id: int) -> void:
	selected_car_id = car_id
	history.clear()
	_paint.albedo_color = T.ACCENT_ACID_LIME if car_id < 2 else T.ACCENT_ELECTRIC_CYAN

func update_snapshot(snapshot: Dictionary) -> void:
	cars = snapshot.get("cars", [])
	for entry: Dictionary in cars:
		if int(entry.car_id) == selected_car_id:
			packet = entry
			break
	if packet.is_empty():
		return
	_title.text = "CAR #%02d / %s" % [selected_car_id + 1, str(packet.driver_name).to_upper()]
	_speed.text = "%03d" % roundi(float(packet.speed_kmh))
	var lap_time: float = packet.last_lap_time
	_lap.text = "LAST LAP  %s" % ("%02d:%06.3f" % [int(lap_time / 60), fmod(lap_time, 60.0)] if lap_time > 0 else "--:--.---")
	_sector.text = "SECTOR %02d / %s" % [int(packet.sector_index) + 1, str(packet.last_mini_sector_status)]
	_sector.add_theme_color_override("font_color", T.ACCENT_PURPLE_SECTOR if packet.last_mini_sector_status == "PURPLE" else T.ACCENT_ELECTRIC_CYAN)
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	_sample_elapsed += delta
	if _sample_elapsed >= 1.0 and not packet.is_empty():
		_sample_elapsed = 0
		var remaining := 1.0
		for condition: float in packet.tire_wear:
			remaining = minf(remaining, condition)
		history.append(remaining)
		if history.size() > 100:
			history.pop_front()
		queue_redraw()
	if _car_root:
		_car_root.rotation.y = -.35 + sin(_clock * .18) * .12

func _draw() -> void:
	if _map_rect.size.x <= 0:
		return
	var font: Font = UI.MONO
	draw_line(Vector2(24, size.y * .45), Vector2(size.x - 24, size.y * .45), T.HAIRLINE_DIVIDER)
	draw_string(UI.HEADER, Vector2(28, _map_rect.position.y + 2), "CIRCUIT RADAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, T.TEXT_PRIMARY)
	draw_string(font, Vector2(28, _map_rect.end.y + 20), "SUZUKA // 5.807 KM // SCHEMATIC", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, T.TEXT_MUTED)
	var points := PackedVector2Array()
	for point: Vector2 in MAP:
		points.append(_map_rect.position + point * _map_rect.size)
	draw_polyline(points, T.INK_BORDER_BLACK, 16, false)
	draw_polyline(points, T.TEXT_MUTED, 7, false)
	draw_polyline(points, T.SURFACE_PANEL_ELEVATED, 3, false)
	for entry: Dictionary in cars:
		var pos: Vector2 = _map_point(float(entry.spline_distance) / 5807.0)
		var active: bool = int(entry.car_id) == selected_car_id
		draw_circle(pos, 7 if active else 4, T.INK_BORDER_BLACK)
		draw_circle(pos, 5.0 if active else 2.5, T.ACCENT_ACID_LIME if active else T.ACCENT_ELECTRIC_CYAN)
		if active:
			draw_string(font, pos + Vector2(10,-7), "#%02d" % (selected_car_id + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, T.ACCENT_ACID_LIME)
	var x: float = size.x * .65
	draw_string(UI.HEADER, Vector2(x, _map_rect.position.y + 2), "SECTOR DELTA", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, T.TEXT_PRIMARY)
	for sector: int in range(3):
		var y: float = _map_rect.position.y + 43 + sector * 43
		var split: float = -1
		var completed: bool = not packet.is_empty() and float(packet.sector_times[sector]) > 0.0
		if completed:
			split = 0.0
			for mini_index: int in range(sector * 4, sector * 4 + 4):
				split += float(packet.mini_sector_deltas[mini_index])
		draw_string(font, Vector2(x,y), "S%d" % (sector + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, T.TEXT_SECONDARY)
		draw_string(font, Vector2(x + 42,y), "%+.3fs" % split if completed else "--.---", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, T.ACCENT_ELECTRIC_CYAN)
	var half: float = _graph_rect.size.x * .48
	var tire_rect := Rect2(_graph_rect.position + Vector2(_graph_rect.size.x * .53,0), Vector2(half,_graph_rect.size.y))
	var lap_rect := Rect2(_graph_rect.position,Vector2(half,_graph_rect.size.y))
	draw_string(UI.HEADER, lap_rect.position - Vector2(0,16), "LAP TIME / STEPPED TRACE", HORIZONTAL_ALIGNMENT_LEFT,-1,19,T.TEXT_PRIMARY)
	draw_string(UI.HEADER, tire_rect.position - Vector2(0,16), "TIRE CONDITION / CLIFF", HORIZONTAL_ALIGNMENT_LEFT,-1,19,T.TEXT_PRIMARY)
	for i: int in range(4):
		var y: float = _graph_rect.position.y + i * _graph_rect.size.y / 3
		draw_line(Vector2(_graph_rect.position.x,y),Vector2(_graph_rect.end.x,y),T.HAIRLINE_DIVIDER)
	var lap_values: Array[float] = []
	if not packet.is_empty():
		for value: float in packet.lap_times:
			lap_values.append(value)
	if lap_values.is_empty():
		draw_string(font,lap_rect.position + Vector2(0,40),"AWAITING FIRST TIMED LAP",HORIZONTAL_ALIGNMENT_LEFT,-1,12,T.TEXT_MUTED)
	else:
		var lo: float = lap_values.min() - 1.0
		var hi: float = lap_values.max() + 1.0
		_draw_steps(lap_values,lap_rect,lo,hi,T.ACCENT_ELECTRIC_CYAN)
		draw_string(font,Vector2(28,size.y-18),"LAST %.3fs" % lap_values.back(),HORIZONTAL_ALIGNMENT_LEFT,-1,10,T.TEXT_SECONDARY)
	_draw_steps(history,tire_rect,0,1,T.ACCENT_ACID_LIME)
	var cliff_y: float = tire_rect.end.y - tire_rect.size.y * .30
	draw_line(Vector2(tire_rect.position.x,cliff_y),Vector2(tire_rect.end.x,cliff_y),T.ACCENT_ANIME_CRIMSON,1)
	draw_string(font,Vector2(tire_rect.position.x,size.y-18),"100% → 0% // ALERT ≤30%",HORIZONTAL_ALIGNMENT_LEFT,-1,10,T.TEXT_MUTED)

func _draw_steps(values: Array[float], area: Rect2, lo: float, hi: float, tint: Color) -> void:
	if values.size() == 1:
		draw_circle(area.position + Vector2(0,(1-inverse_lerp(lo,hi,values[0])) * area.size.y),3,tint)
	for i: int in range(1,values.size()):
		var a := area.position + Vector2(float(i-1)/maxi(1,values.size()-1) * area.size.x,(1-clampf(inverse_lerp(lo,hi,values[i-1]),0,1)) * area.size.y)
		var b := area.position + Vector2(float(i)/maxi(1,values.size()-1) * area.size.x,(1-clampf(inverse_lerp(lo,hi,values[i]),0,1)) * area.size.y)
		draw_line(a,Vector2(b.x,a.y),tint,2)
		draw_line(Vector2(b.x,a.y),b,tint,2)

func _map_point(progress: float) -> Vector2:
	var distance: float = fposmod(progress, 1.0) * _map_total
	var before := 0.0
	for i: int in range(_map_lengths.size()):
		if distance <= _map_lengths[i]:
			var weight: float = (distance - before) / (_map_lengths[i] - before)
			return _map_rect.position + MAP[i].lerp(MAP[i + 1], weight) * _map_rect.size
		before = _map_lengths[i]
	return _map_rect.position

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .85
	return mat

func _box(parent: Node3D, dimensions: Vector3, pos: Vector3, paint: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = dimensions
	mesh.mesh = shape
	mesh.material_override = paint
	parent.add_child(mesh)
	mesh.position = pos
	return mesh

func _build_viewer() -> void:
	_viewer = SubViewportContainer.new()
	_viewer.name = "SelectedCarViewport"
	_viewer.stretch = true
	_viewer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewer)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640,360)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	_viewer.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	var atmosphere := Environment.new()
	atmosphere.background_mode = Environment.BG_COLOR
	atmosphere.background_color = T.SURFACE_PANEL_DARK
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_color = Color.WHITE
	atmosphere.ambient_light_energy = .7
	env.environment = atmosphere
	world.add_child(env)
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-45,-30,0)
	light.light_energy = 1.4
	_camera = Camera3D.new()
	world.add_child(_camera)
	_camera.position = Vector3(5,3.5,6)
	_camera.look_at(Vector3(0,.5,0))
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 6.7
	_car_root = Node3D.new()
	world.add_child(_car_root)
	_paint = _material(T.ACCENT_ACID_LIME)
	var ink := _material(T.INK_BORDER_BLACK)
	var glass := _material(Color("#163540"))
	_box(_car_root,Vector3(2,.45,4.4),Vector3(0,.65,0),_paint)
	_box(_car_root,Vector3(1.7,.56,1.7),Vector3(0,1.10,-.12),glass)
	_box(_car_root,Vector3(1.72,.08,1.6),Vector3(0,1.42,-.12),ink)
	_box(_car_root,Vector3(.22,.02,4.4),Vector3(.35,.888,0),ink)
	_box(_car_root,Vector3(2.23,.12,.55),Vector3(0,.53,2.03),ink)
	_box(_car_root,Vector3(2.25,.12,.7),Vector3(0,1.25,-1.9),ink)
	for x: float in [-.78,.78]:
		_box(_car_root,Vector3(.08,.55,.08),Vector3(x,1,-1.9),ink)
		_box(_car_root,Vector3(.44,.08,.04),Vector3(x,.76,2.22),_material(T.TEXT_PRIMARY))
	for x: float in [-1.03,1.03]:
		for z: float in [-1.32,1.34]:
			var wheel := MeshInstance3D.new()
			var tire := CylinderMesh.new()
			tire.top_radius = .39
			tire.bottom_radius = .39
			tire.height = .3
			tire.radial_segments = 12
			wheel.mesh = tire
			wheel.material_override = ink
			_car_root.add_child(wheel)
			wheel.rotation.z = PI / 2
			wheel.position = Vector3(x,.43,z)
	_box(world,Vector3(6,.08,7),Vector3(0,-.03,0),_material(T.SURFACE_PANEL_ELEVATED))
