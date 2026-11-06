extends SceneTree

## FASE 29 acceptance: the Slab live timing tower, the tyre life ring and wheel, and a telemetry drawer that only
## watches the tactical deck car. Run: Godot --headless --path . -s res://tests/test_live_timing_slab.gd

const WorldScene := preload("res://scenes/race_weekend_world.tscn")
const DirectorScript := preload("res://scripts/world/weekend/race_weekend_director.gd")
const ActorScript := preload("res://scripts/car/gt_car_actor.gd")
const T := preload("res://scripts/ui/ui_theme_tokens.gd")
const RowScene := preload("res://scenes/pit_wall/driver_row.tscn")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const FRAME: float = 1.0 / 60.0

var failures: int = 0
var assertions: int = 0
var world: Node3D
var hud: RaceHud
var race: GtRace
var mine: Array[GtCar] = []


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
	world.set_process(false)
	hud = world.hud
	race = world.race
	race.incidents_enabled = false
	for car: GtCar in race.cars:
		if car.team_id == race.player_team_id:
			mine.append(car)
	mine.sort_custom(func(a: GtCar, b: GtCar) -> bool: return a.id < b.id) # the deck lists its cars by id
	world.director._enter(DirectorScript.State.GREEN_RACING)
	for _i: int in range(40):
		world.step(FRAME)
	race.step_ticks(200)
	hud.refresh_all()
	_test_telemetry_follows_deck_car()
	_test_radar_reads_deck_car_only()
	_test_entries_carry_tyre_life()
	_test_tyre_life_ring_rules()
	_test_painter_wheel_uses_shared_rules()
	_test_row_compact()
	await _test_slab_layout()
	_test_slab_texts_and_team_colour()
	race.dispose()
	world.queue_free()
	await process_frame
	ActorScript._paint_cache.clear()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("FASE 29 LIVE TIMING SLAB: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


func _first_rival() -> GtCar:
	for car: GtCar in race.cars:
		if car.team_id != race.player_team_id:
			return car
	return null


# --- telemetry source ---------------------------------------------------------------------------------------

func _test_telemetry_follows_deck_car() -> void:
	var deck: TacticalDeck = hud.deck
	var rival: GtCar = _first_rival()
	deck.tabs[0].pressed.emit()
	world.followed_id = rival.id
	hud.refresh_all()
	var header: String = hud.drawer.state.header_text
	check(header.contains(mine[0].code) and not header.contains(rival.code),
		"telemetry: a rival followed in the tower leaves the drawer on the deck car (%s)" % header)
	deck.tabs[1].pressed.emit()
	hud.refresh_all()
	check(hud.drawer.state.header_text.contains(mine[1].code),
		"telemetry: switching the deck driver moves the drawer to that car (%s)" % hud.drawer.state.header_text)
	deck.tabs[0].pressed.emit()
	mine[0].is_dnf = true
	world.followed_id = rival.id
	hud.refresh_all()
	var after_dnf: String = hud.drawer.state.header_text
	mine[0].is_dnf = false
	check(after_dnf.contains(mine[0].code) and not after_dnf.contains(rival.code),
		"telemetry: a retired deck car keeps the drawer, it does not jump to the followed rival (%s)" % after_dnf)
	world.followed_id = mine[0].id
	hud.refresh_all()


# --- standings entries ------------------------------------------------------------------------------------------

func _entry_of(car_id: int) -> Dictionary:
	for entry: Dictionary in race.standings_entries():
		if int(entry["car_id"]) == car_id:
			return entry
	return {}


func _test_entries_carry_tyre_life() -> void:
	var car: GtCar = mine[0]
	car.wear = 0.3
	car.tyre_age_laps = 7
	car.stops = 2
	var entry: Dictionary = _entry_of(car.id)
	check(is_equal_approx(float(entry.get("tyre_life", -1.0)), 0.7) and int(entry.get("tyre_age_laps", -1)) == 7 and int(entry.get("stops", -1)) == 2,
		"entries: tyre life is 1 - wear, with the tyre age in laps and the stop count (%s)" % [entry.get("tyre_life")])
	car.wear = 1.4
	var worn: float = float(_entry_of(car.id).get("tyre_life", -1.0))
	car.wear = -0.1
	var fresh: float = float(_entry_of(car.id).get("tyre_life", -1.0))
	car.wear = 0.0
	car.tyre_age_laps = 0
	car.stops = 0
	check(worn == 0.0 and fresh == 1.0, "entries: tyre life is clamped to 0..1 (%s, %s)" % [worn, fresh])


# --- tyre life ring ---------------------------------------------------------------------------------------------

func _test_tyre_life_ring_rules() -> void:
	check(TyreLifeRing.lit_ticks(1.0, 16) == 16 and TyreLifeRing.lit_ticks(0.0, 16) == 0 and TyreLifeRing.lit_ticks(0.01, 16) == 1 and TyreLifeRing.lit_ticks(0.5, 16) == 8,
		"ring: ticks lit are ceil(life x total), a sliver of life still lights one")
	check(TyreLifeRing.tint_for(0.25) == T.ACCENT_ANIME_CRIMSON and TyreLifeRing.tint_for(0.26) == T.ACCENT_ACID_LIME,
		"ring: the colour turns crimson at the tyre cliff, the same line as the deck TYRE LIFE gauge")
	check(TyreLifeRing.life_of(1.4) == 0.0 and TyreLifeRing.life_of(-0.1) == 1.0 and is_equal_approx(TyreLifeRing.life_of(0.3), 0.7),
		"ring: life is 1 - wear, clamped to 0..1")
	var ring := TyreLifeRing.new()
	ring.set_tyre(0.5, "S", Color.RED)
	var first: int = ring.change_count
	ring.set_tyre(0.5, "S", Color.RED)
	var repeated: int = ring.change_count
	ring.set_tyre(0.4, "S", Color.RED)
	check(ring.life == 0.4 and ring.letter == "S" and first == 1 and repeated == 1 and ring.change_count == 2,
		"ring: setting the same tyre again does not ask for a redraw (%d, %d, %d)" % [first, repeated, ring.change_count])
	ring.free()


# --- telemetry wheel --------------------------------------------------------------------------------------------

func _test_painter_wheel_uses_shared_rules() -> void:
	var car: GtCar = mine[0]
	car.wear = 0.3
	car.wheel_temp[0] = 90.0
	var state := TelemetryState.new()
	state.update(car, race.laps)
	var before: Color = state.heat_tint[0]
	hud.set_team_accent(7)
	state.update(car, race.laps)
	var after: Color = state.heat_tint[0]
	hud.set_team_accent(race.player_team_id)
	car.wear = 0.0
	check(TelemetryPainter.wheel_ticks() == 16 and TyreLifeRing.lit_ticks(state.tread, TelemetryPainter.wheel_ticks()) == 12,
		"painter: the wheel has 16 ticks and 70%% life lights 12 of them (%d)" % TyreLifeRing.lit_ticks(state.tread, TelemetryPainter.wheel_ticks()))
	check(before == T.ACCENT_ACID_LIME and after == before,
		"painter: the wheel's heat colour is the fixed data colour whatever the team accent")


# --- tower rows -------------------------------------------------------------------------------------------------

func _row_of(car_id: int) -> Control:
	for row: Control in hud.tower.rows:
		if row.car_id == car_id:
			return row
	return null


func _test_row_compact() -> void:
	check(DriverRow.team_mark_needs_outline(Color("#1E3A8A")) and not DriverRow.team_mark_needs_outline(Color("#CCFF00")),
		"row: a dark team colour gets an outline on the panel, a bright one does not")
	var purple: float = DriverRow.SectorBars.height_of(GtTypes.SectorColor.PURPLE)
	var green: float = DriverRow.SectorBars.height_of(GtTypes.SectorColor.GREEN)
	var yellow: float = DriverRow.SectorBars.height_of(GtTypes.SectorColor.YELLOW)
	var none: float = DriverRow.SectorBars.height_of(GtTypes.SectorColor.NONE)
	check(purple > green and green > yellow and yellow > none and purple == 1.0,
		"row: sector bars are tall for purple, then green, yellow, none (colour is not the only cue)")
	var leader: GtCar = race.standings()[0]
	var leader_row: Control = _row_of(leader.id)
	check(leader_row != null and is_equal_approx(leader_row._ring.life, TyreLifeRing.life_of(leader.wear)) and leader_row._ring.letter == GtTypes.COMPOUND_LABEL[leader.compound],
		"row: the ring carries the car's tyre life and compound letter")
	var bare: Control = RowScene.instantiate()
	root.add_child(bare)
	bare.update_entry({"car_id": 1, "position": 3})
	check(is_equal_approx(bare._ring.life, 1.0), "row: an entry without tyre_life or team_id (the old pit wall) draws a full ring, no error")
	bare.queue_free()
	var compact_h: bool = true
	for row: Control in hud.tower.rows:
		if row.visible and not row.expanded:
			compact_h = compact_h and row.custom_minimum_size.y == DriverRow.ROW_H_COMPACT
	check(compact_h, "row: a compact row is %d px tall" % int(DriverRow.ROW_H_COMPACT))


func _expanded_rows() -> Array[Control]:
	var found: Array[Control] = []
	for row: Control in hud.tower.rows:
		if row.visible and row.expanded:
			found.append(row)
	return found


func _test_slab_layout() -> void:
	world.followed_id = mine[0].id
	hud.refresh_all()
	var slabs: Array[Control] = _expanded_rows()
	check(slabs.size() == 1 and slabs[0].car_id == mine[0].id and slabs[0].custom_minimum_size.y == DriverRow.ROW_H_SLAB,
		"slab: exactly one row, the followed car's, opens into the %d px slab" % int(DriverRow.ROW_H_SLAB))
	check(slabs[0]._slab_code.text.contains(mine[0].code) and slabs[0]._slab_value.text == slabs[0]._interval.text and is_equal_approx(slabs[0]._slab_ring.life, TyreLifeRing.life_of(mine[0].wear)),
		"slab: code, column value and the big ring come from the same entry (%s)" % slabs[0]._slab_code.text)
	check(is_equal_approx(DriverRow.ROW_H_SLAB, 46.0) and is_equal_approx(DriverRow.ROW_H_SLAB - DriverRow.ROW_H_COMPACT, 16.0),
		"slab: the selected row is a 30 px row plus a 16 px strip, so the list below moves 16 px")
	var entry: Dictionary = _entry_of(mine[0].id)
	var texts: Dictionary = RaceHud.slab_texts(entry)
	var strip: String = slabs[0]._slab_note.text
	check(strip.contains("%dL" % int(entry["tyre_age_laps"])) and strip.contains("%d STOP" % int(entry["stops"])) and strip.contains(String(texts["gap"])) and strip.contains(String(texts["last"])),
		"slab: the strip reads tyre age, stops, gap and last lap (%s)" % strip)
	var rival: GtCar = _first_rival()
	var old_slab: Control = slabs[0]
	var clicked: Control = _row_of(rival.id)
	clicked._activate()
	hud.refresh_all()
	var moved: Array[Control] = _expanded_rows()
	check(moved.size() == 1 and moved[0] == clicked and not old_slab.expanded and world.followed_id == rival.id,
		"slab: clicking another row moves the slab to it and collapses the old one")
	world.followed_id = mine[0].id
	hud.refresh_all()
	await process_frame
	var rows_box: Control = hud.tower.get_node("Body/RowsScroll/Rows")
	var scroll: Control = hud.tower.get_node("Body/RowsScroll")
	check(rows_box.get_combined_minimum_size().y <= scroll.size.y and hud.tower.size.x == 320.0 and Rect2(hud.tower.position, hud.tower.size).end.x <= RaceHud.RADIO_DOCK.position.x,
		"slab: 20 rows with the slab fit the tower without scrolling (%.0f of %.0f px), tower stays 320 px wide" % [rows_box.get_combined_minimum_size().y, scroll.size.y])
	world.followed_id = -999
	hud.refresh_all()
	var none_open: int = _expanded_rows().size()
	world.followed_id = mine[0].id
	hud.refresh_all()
	hud.tower.clear_selection()
	var cleared: int = _expanded_rows().size()
	hud.refresh_all()
	check(none_open == 0 and cleared == 0 and _expanded_rows().size() == 1,
		"slab: a followed id that is not in the standings opens no slab, clearing the selection closes it")


# --- race hud wiring --------------------------------------------------------------------------------------------

func _test_slab_texts_and_team_colour() -> void:
	var lead: Dictionary = {"position": 1, "interval_s": 0.0, "gap_s": 0.0, "last_lap_time": 83.456, "is_dnf": false, "is_finished": false, "in_pit": false, "penalty_hold_s": 0.0}
	var mid: Dictionary = lead.duplicate()
	mid["position"] = 5
	mid["interval_s"] = 1.26
	mid["gap_s"] = 7.84
	var dnf: Dictionary = mid.duplicate()
	dnf["is_dnf"] = true
	var fin: Dictionary = mid.duplicate()
	fin["is_finished"] = true
	var pitting: Dictionary = mid.duplicate()
	pitting["in_pit"] = true
	var held: Dictionary = pitting.duplicate()
	held["penalty_hold_s"] = 4.2
	check(RaceHud.slab_texts(lead) == {"int": "LEAD", "gap": "LEAD", "last": "1:23.456"} and RaceHud.slab_texts(mid) == {"int": "+1.3", "gap": "+7.8", "last": "1:23.456"},
		"hud: the slab shows INT, GAP and the last lap together (%s)" % [RaceHud.slab_texts(mid)])
	check(RaceHud.slab_texts(dnf)["gap"] == "DNF" and RaceHud.slab_texts(fin)["last"] == "FIN" and RaceHud.slab_texts(pitting)["int"] == "PIT" and RaceHud.slab_texts(held)["gap"] == "PEN 4.2",
		"hud: DNF, FIN, PIT and the penalty hold replace all three slab numbers")
	check(hud.tower.style == hud.style and hud.tower._header_note.text == hud.lap_label.text,
		"hud: the tower wears the HUD's team skin and its header carries the lap (%s)" % hud.tower._header_note.text)
	var row: Control = _expanded_rows()[0]
	hud.set_team_accent(7)
	var light_ok: bool = row.slab_style.bg_color == Liveries.color_for(7) and hud.style.on_accent == T.INK_BORDER_BLACK and row._slab_code.get_theme_color("font_color") == T.INK_BORDER_BLACK
	hud.set_team_accent(2)
	var near_crimson_ok: bool = row.slab_style.shadow_color == hud.style.shadow and hud.style.shadow != Color("#FF1E56")
	hud.set_team_accent(11)
	var dark_ok: bool = hud.style.on_accent == Color.WHITE and row._slab_code.get_theme_color("font_color") == Color.WHITE
	var dark_header: float = DriverRow.contrast_ratio(hud.tower._col_int.get_theme_color("font_color"), T.SURFACE_PANEL_DARK)
	hud.set_team_accent(0)
	var lime_header: Color = hud.tower._col_int.get_theme_color("font_color")
	var data_colour: Color = TyreLifeRing.tint_for(0.5)
	hud.set_team_accent(race.player_team_id)
	check(light_ok and near_crimson_ok and dark_ok and data_colour == T.ACCENT_ACID_LIME,
		"hud: a team colour repaints the slab, type flips ink/white, a near-crimson team gets the cyan shadow, data colours stay fixed (%s %s %s)" % [light_ok, near_crimson_ok, dark_ok])
	check(dark_header >= DriverRow.MIN_MARK_CONTRAST and lime_header == Liveries.color_for(0),
		"hud: the Tab column label stays readable on a dark team colour (contrast %.1f) and wears the accent when it is bright" % dark_header)


# --- radar source ---------------------------------------------------------------------------------------------

func _test_radar_reads_deck_car_only() -> void:
	var deck: TacticalDeck = hud.deck
	var rival: GtCar = _first_rival()
	deck.tabs[0].pressed.emit()
	for sector: int in range(3):
		rival.sector_colors[sector] = GtTypes.SectorColor.PURPLE
		mine[0].sector_colors[sector] = GtTypes.SectorColor.GREEN
	world.followed_id = rival.id
	hud.refresh_all()
	var radar_text: String = hud.radar.followed_text
	check(radar_text.contains(mine[0].code) and not radar_text.contains(rival.code),
		"radar: a rival followed in the tower leaves the caption on the deck car (%s)" % radar_text)
	var all_deck_colour: bool = hud.radar.chips.size() == 3
	for chip: Dictionary in hud.radar.chips:
		all_deck_colour = all_deck_colour and int(chip["status"]) == GtTypes.SectorColor.GREEN
	check(all_deck_colour, "radar: the sector chips show the deck car's results, not the followed rival's")
	deck.tabs[1].pressed.emit()
	hud.refresh_all()
	check(hud.radar.followed_text.contains(mine[1].code),
		"radar: switching the deck driver moves the caption to that car (%s)" % hud.radar.followed_text)
	deck.tabs[0].pressed.emit()
	world.followed_id = mine[0].id
	hud.refresh_all()
