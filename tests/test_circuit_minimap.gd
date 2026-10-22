extends SceneTree

## In-game minimap (feedback round after FASE 10): the circuit radar of the race HUD reads at a glance.
## Every car is a team-coloured dot carrying its race number, the lap is split into three sector bands
## with their S1 / S2 / S3 labels and boundary ticks, the followed car is picked out, the player's team is
## ringed, and the strip under the map shows the followed car's three sector results and the yellow flag sector.
## Run: Godot --headless --path . -s res://tests/test_circuit_minimap.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const RadarScene := preload("res://scenes/pit_wall/circuit_radar_2d.tscn")
const DirectorScript := preload("res://scripts/world/race_weekend_director.gd")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const FRAME: float = 1.0 / 60.0
const RADAR_RECT := Rect2(0.0, 0.0, 300.0, 200.0)

var failures: int = 0
var assertions: int = 0
var world: Node3D
var hud: RaceHud
var race: GtRace


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	world = WorldScene.instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	hud = world.hud
	race = world.race
	race.incidents_enabled = false
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(40):
		world.step(FRAME)
	race.step_ticks(400)
	hud.refresh_all()
	_test_numbers_on_every_car()
	_test_sector_bands()
	_test_followed_and_player()
	_test_sector_chips()
	_test_yellow_sector()
	_test_legacy_snapshot()
	_test_panel_footprint()
	race.dispose()
	world.queue_free()
	for _frame: int in range(3):
		await process_frame
	ActorScript._paint_cache.clear()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("CIRCUIT MINIMAP: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


## The radar's own data, which exists whether or not a frame was drawn.
func array_of(name: String) -> Array:
	var value: Variant = hud.radar.get(name)
	return value if value is Array else []


func _test_numbers_on_every_car() -> void:
	var marks: Array = array_of("marks")
	var numbers: Dictionary = {}
	var readable: bool = true
	var inside: bool = true
	for mark: Dictionary in marks:
		numbers[str(mark.get("text", ""))] = true
		readable = readable and float(mark.get("radius", 0.0)) >= 7.5 and int(mark.get("font_size", 0)) >= 10
		inside = inside and RADAR_RECT.grow(-3.0).has_point(mark.get("at", Vector2(-99.0, -99.0)))
	var expected: bool = marks.size() == race.cars.size() and not marks.is_empty()
	for car: GtCar in race.cars:
		expected = expected and numbers.has(str(car.number))
	check(expected and readable and inside and numbers.size() == race.cars.size(),
		"#R1 each of the %d cars is a dot of at least 15 px carrying its own race number in 10+ px type, inside the radar (%d numbers shown)" % [race.cars.size(), numbers.size()])


func _test_sector_bands() -> void:
	var bands: Array = array_of("bands")
	var ticks: Array = array_of("ticks")
	var joined: bool = bands.size() == 3
	var colors: Dictionary = {}
	var labels_ok: bool = bands.size() == 3
	if bands.size() == 3:
		for index: int in range(3):
			var band: Dictionary = bands[index]
			var path: PackedVector2Array = band["path"]
			colors[(band["color"] as Color).to_html()] = true
			labels_ok = labels_ok and band["label"] == "S%d" % (index + 1) and RADAR_RECT.grow(-4.0).has_point(band["label_at"])
			if index > 0:
				var before: PackedVector2Array = bands[index - 1]["path"]
				joined = joined and path.size() > 8 and before[before.size() - 1].distance_to(path[0]) < 0.5
		var last: PackedVector2Array = bands[2]["path"]
		var first: PackedVector2Array = bands[0]["path"]
		joined = joined and last[last.size() - 1].distance_to(first[0]) < 1.5
	var start_ticks: int = 0
	var sector_ticks: int = 0
	for tick: Dictionary in ticks:
		if tick.get("kind", "") == "start":
			start_ticks += 1
		elif tick.get("kind", "") == "sector":
			sector_ticks += 1
	check(joined and labels_ok and colors.size() == 3 and start_ticks == 1 and sector_ticks == 2,
		"#R2 the lap is three joined sector bands in three colours labelled S1 S2 S3, with a start line tick and two sector boundary ticks (%d colours, %d + %d ticks)" % [colors.size(), start_ticks, sector_ticks])


func _test_followed_and_player() -> void:
	var other: GtCar = null
	for car: GtCar in race.cars:
		if car.team_id != race.player_team_id:
			other = car
			break
	world.followed_id = other.id
	hud.refresh_all()
	var marks: Array = array_of("marks")
	var followed: Dictionary = {}
	var largest_other: float = 0.0
	var rung: bool = true
	var seen_player: int = 0
	for mark: Dictionary in marks:
		if bool(mark["followed"]):
			followed = mark
		else:
			largest_other = maxf(largest_other, float(mark["radius"]))
		if bool(mark["player"]):
			seen_player += 1
			rung = rung and bool(mark["player_ring"])
	var on_top: bool = not marks.is_empty() and bool(marks[marks.size() - 1]["followed"])
	var expected_player: int = 0
	for car: GtCar in race.cars:
		if car.team_id == race.player_team_id:
			expected_player += 1
	check(not followed.is_empty() and int(followed["car_id"]) == other.id and float(followed["radius"]) > largest_other and on_top and seen_player == expected_player and rung and seen_player > 0,
		"#R3 the followed car (#%d) is the biggest dot and drawn on top, and the player's %d cars each wear a team ring" % [other.number, seen_player])


func _test_sector_chips() -> void:
	var followed: GtCar = race.get_car(world.followed_id)
	followed.sector_colors[0] = Types.SectorColor.PURPLE
	followed.sector_colors[1] = Types.SectorColor.GREEN
	followed.sector_colors[2] = Types.SectorColor.YELLOW
	hud.refresh_all()
	var chips: Array = array_of("chips")
	var order_ok: bool = chips.size() == 3
	var current_count: int = 0
	var fills: Dictionary = {}
	if chips.size() == 3:
		for index: int in range(3):
			var chip: Dictionary = chips[index]
			order_ok = order_ok and chip["text"] == "S%d" % (index + 1) and RADAR_RECT.encloses(chip["rect"]) and (chip["rect"] as Rect2).size.x >= 34.0
			fills[(chip["fill"] as Color).to_html()] = true
			if bool(chip["current"]):
				current_count += 1
				order_ok = order_ok and index == followed.current_sector
	var caption: String = str(hud.radar.get("followed_text"))
	check(order_ok and fills.size() == 3 and current_count == 1 and caption == "#%d %s" % [followed.number, followed.code],
		"#R4 the strip under the map shows the followed car's S1 purple, S2 green, S3 yellow, marks the sector it is in (S%d) and names the car (%s)" % [followed.current_sector + 1, caption])


func _test_yellow_sector() -> void:
	race.set_flag(Types.Flag.YELLOW, 2, "YELLOW FLAG SECTOR 2", 20.0)
	hud.refresh_all()
	var bands: Array = array_of("bands")
	var chips: Array = array_of("chips")
	var lit: Array[int] = []
	for band: Dictionary in bands:
		if bool(band["yellow"]):
			lit.append(int(band["sector"]))
	var chip_lit: bool = chips.size() == 3 and bool(chips[1]["flagged"]) and not bool(chips[0]["flagged"]) and not bool(chips[2]["flagged"])
	race.set_flag(Types.Flag.GREEN, 1, "TRACK CLEAR", 0.0)
	race.race_control["flag"] = Types.Flag.GREEN
	hud.refresh_all()
	var cleared: bool = true
	for band: Dictionary in array_of("bands"):
		cleared = cleared and not bool(band["yellow"])
	check(lit == [2] and chip_lit and cleared,
		"#R5 a yellow flag in sector 2 turns band S2 and its chip yellow and nothing else, and clears with the flag (lit %s)" % str(lit))


func _test_legacy_snapshot() -> void:
	var radar: Control = RadarScene.instantiate()
	root.add_child(radar)
	radar.set_ribbon(world.ribbon, world.track.length)
	radar.update_snapshot({"cars": [{"car_id": 3, "team_id": 2, "spline_distance": 100.0}]})
	var marks: Array = radar.get("marks")
	var chips: Array = radar.get("chips")
	check(marks.size() == 1 and marks[0]["text"] == "4" and chips.size() == 3,
		"#R6 callers that send only car_id, team_id and spline_distance still get a numbered dot (#%s) and the sector strip" % [str(marks[0]["text"]) if marks.size() == 1 else "?"])
	radar.queue_free()


func _test_panel_footprint() -> void:
	var radar_rect := Rect2(hud.radar.position, hud.radar.size)
	var drawer_rect := Rect2(hud.drawer.position, hud.drawer.size)
	var tower_rect := Rect2(hud.tower.position, hud.tower.size)
	var column := Rect2(1598.0, 76.0, 312.0, 300.0)
	check(column.encloses(radar_rect) and not radar_rect.intersects(drawer_rect) and not radar_rect.intersects(tower_rect) and radar_rect.size.is_equal_approx(RADAR_RECT.size),
		"#R7 the map keeps its 300x200 footprint in the right column, clear of the tower and the telemetry drawer (%s)" % str(radar_rect))
