extends SceneTree

## 12-month championship calendar (FASE 12, TASK-12): seven Grand Prix rounds and five Sprint
## rounds, one per month, as the data foundation of Career Mode. The registry is checked against the
## official design table, and RaceConfigData is checked to resolve the selected round.
## Run: godot --headless --path . -s res://tests/test_circuit_calendar_registry.gd

const CircuitDataScript := preload("res://scripts/core/circuit_data.gd")
const RegistryScript := preload("res://scripts/core/circuit_calendar_registry.gd")
const ConfigScript := preload("res://scripts/core/race_config_data.gd")

## The official calendar, in championship order: (id, round, name, type, country, km).
const EXPECTED: Array[Array] = [
	["apex_ring", 1, "Apex Ring International", 0, "JPN", 4.16],
	["neo_wangan", 2, "Neo-Wangan Shuto Express", 1, "JPN", 3.15],
	["brianza", 3, "Autodromo di Brianza", 0, "ITA", 5.79],
	["monte_azure", 4, "Monte Azure Marina", 1, "MCO", 2.85],
	["ardennes", 5, "Ardennes Valley Ring", 0, "BEL", 5.40],
	["haruna", 6, "Haruna Mountain Touge", 1, "JPN", 2.90],
	["stoke_crown", 7, "Stoke Crown Circuit", 0, "GBR", 5.20],
	["pacific_corkscrew", 8, "Pacific Coast Corkscrew", 1, "USA", 3.60],
	["eifel_forest", 9, "Eifel Forest Ring", 0, "GER", 5.15],
	["iron_mountain", 10, "Iron Mountain Ridge", 1, "AUS", 3.85],
	["paulistano", 11, "Paulistano Speed Arena", 0, "BRA", 4.31],
	["kurogane", 12, "Kurogane Twin-Cross", 0, "JPN", 5.80],
]

var failures: int = 0
var assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])


func _run() -> void:
	_test_calendar_shape()
	_test_official_table()
	_test_metadata()
	_test_type_filters()
	_test_race_config_integration()
	print("%d assertions, %d failure(s)" % [assertions, failures])
	print("CIRCUIT CALENDAR REGISTRY: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)


## Twelve rounds, one per month, in championship order, with unique ids.
func _test_calendar_shape() -> void:
	var all: Array = RegistryScript.get_all_circuits()
	var ids: Dictionary = {}
	var rounds: Dictionary = {}
	var ordered: bool = all.size() == 12
	for index: int in range(all.size()):
		var circuit: CircuitDataScript = all[index]
		ids[circuit.circuit_id] = true
		rounds[circuit.round_number] = true
		ordered = ordered and circuit.round_number == index + 1
	check(all.size() == 12 and ordered and ids.size() == 12 and rounds.size() == 12,
		"#K1 the registry holds exactly 12 rounds, ordered Round 01 to Round 12, with 12 unique ids and round numbers (%d entries, %d ids)" % [all.size(), ids.size()])


## Every row of the official table resolves to the same round, name, type, country and length.
func _test_official_table() -> void:
	var mismatches: Array[String] = []
	for row: Array in EXPECTED:
		var circuit: CircuitDataScript = RegistryScript.get_circuit(String(row[0]))
		if circuit == null:
			mismatches.append("%s missing" % row[0])
			continue
		var facts: Array[String] = []
		if circuit.round_number != int(row[1]):
			facts.append("round %d" % circuit.round_number)
		if circuit.display_name != String(row[2]):
			facts.append("name '%s'" % circuit.display_name)
		if int(circuit.circuit_type) != int(row[3]):
			facts.append("type %d" % int(circuit.circuit_type))
		if circuit.country_code != String(row[4]):
			facts.append("country '%s'" % circuit.country_code)
		if absf(circuit.length_km - float(row[5])) > 0.005:
			facts.append("%.2f km" % circuit.length_km)
		if not facts.is_empty():
			mismatches.append("%s: %s" % [row[0], ", ".join(facts)])
	check(mismatches.is_empty(),
		"#K2 all 12 rounds match the official calendar (id, round, name, type, country, length)%s" % ("" if mismatches.is_empty() else " — " + "; ".join(mismatches)))


## Round 01 is the existing permanent circuit; Round 02 is the new night street sprint.
func _test_metadata() -> void:
	var apex: CircuitDataScript = RegistryScript.get_circuit("apex_ring")
	var wangan: CircuitDataScript = RegistryScript.get_circuit("neo_wangan")
	var apex_ok: bool = apex != null and apex.circuit_type == CircuitDataScript.CircuitType.GRAND_PRIX \
		and not apex.direction_clockwise and apex.turns_count == 9 and apex.scene_path == "res://scenes/race_world/track_circuit.tscn"
	var wangan_ok: bool = wangan != null and wangan.circuit_type == CircuitDataScript.CircuitType.SPRINT \
		and wangan.japanese_name == "新湾岸高速" and wangan.real_inspiration.contains("Shuto") \
		and wangan.scene_path == "res://scenes/race_world/neo_wangan_circuit.tscn" and wangan.turns_count == 12
	check(apex_ok and wangan_ok and ResourceLoader.exists(apex.scene_path),
		"#K3 Round 01 is Apex Ring (GP, anti-clockwise, 9 corners, the existing scene) and Round 02 is 新湾岸高速 Neo-Wangan (SPRINT, 3.15 km, 12 turns, its own reserved scene)")

	var metadata_ok: bool = true
	for circuit: CircuitDataScript in RegistryScript.get_all_circuits():
		metadata_ok = metadata_ok and circuit.length_km > 0.0 and circuit.turns_count > 0 \
			and circuit.country_code.length() == 3 and circuit.scene_path.begins_with("res://") \
			and circuit.preview_image_path.begins_with("res://") \
			and circuit.rain_probability >= 0.0 and circuit.rain_probability <= 1.0 \
			and circuit.elevation_delta_m >= 0.0 and circuit.notes != ""
	check(metadata_ok,
		"#K4 every round carries a length, a turn count, a 3-letter country, scene and preview paths, a 0..1 rain probability and a non-empty note")


## 7 Grand Prix + 5 Sprint, each list in championship order, and the length bands of the spec.
func _test_type_filters() -> void:
	var gp: Array = RegistryScript.get_circuits_by_type(CircuitDataScript.CircuitType.GRAND_PRIX)
	var sprint: Array = RegistryScript.get_circuits_by_type(CircuitDataScript.CircuitType.SPRINT)
	var gp_bands: bool = true
	var sprint_bands: bool = true
	var gp_order: bool = true
	var sprint_order: bool = true
	for circuit: CircuitDataScript in gp:
		gp_bands = gp_bands and circuit.length_km >= 4.16 and circuit.length_km <= 5.80
	for circuit: CircuitDataScript in sprint:
		sprint_bands = sprint_bands and circuit.length_km >= 2.85 and circuit.length_km <= 3.85
	for index: int in range(1, gp.size()):
		gp_order = gp_order and gp[index].round_number > gp[index - 1].round_number
	for index: int in range(1, sprint.size()):
		sprint_order = sprint_order and sprint[index].round_number > sprint[index - 1].round_number
	check(gp.size() == 7 and sprint.size() == 5 and gp_bands and sprint_bands and gp_order and sprint_order,
		"#K5 the calendar splits into 7 Grand Prix (4.16–5.80 km) and 5 Sprint (2.85–3.85 km) rounds, each in round order")


## RaceConfigData resolves the selected round and falls back to Round 01 for an unknown id.
func _test_race_config_integration() -> void:
	var config := ConfigScript.new()
	var default_ok: bool = config.selected_circuit_id == "apex_ring" and config.get_active_circuit() != null \
		and config.get_active_circuit().circuit_id == "apex_ring"
	config.selected_circuit_id = "neo_wangan"
	var selected: CircuitDataScript = config.get_active_circuit()
	var select_ok: bool = selected != null and selected.circuit_id == "neo_wangan" and selected.round_number == 2
	config.selected_circuit_id = "not_a_circuit"
	var fallback: CircuitDataScript = config.get_active_circuit()
	var fallback_ok: bool = fallback != null and fallback.circuit_id == "apex_ring"
	check(default_ok and select_ok and fallback_ok,
		"#K6 RaceConfigData starts on apex_ring, resolves neo_wangan when selected, and falls back to Round 01 for an unknown id")

	var shared := ConfigScript.get_config()
	shared.selected_circuit_id = "neo_wangan"
	var shared_ok: bool = shared.get_active_circuit().circuit_id == "neo_wangan"
	ConfigScript.reset()
	var reset_ok: bool = ConfigScript.get_config().selected_circuit_id == "apex_ring"
	check(shared_ok and reset_ok,
		"#K7 the selection rides on the shared draft and a reset returns the calendar to Round 01")

	var missing: CircuitDataScript = RegistryScript.get_circuit("nope")
	check(missing == null,
		"#K8 an unknown circuit id resolves to null instead of a fabricated round")
