class_name CircuitCalendarRegistry
extends RefCounted

## The official 10-round championship calendar (MVP): eight Grand Prix circuits and two Sprint
## circuits. Round 01 is the Apex Ring the game shipped with; Round 02 is Neo-Wangan Shuto Express,
## the first night street sprint. The table is the single source of truth for the race setup selector,
## the career season and the race weekend's circuit loading.

const CircuitDataScript := preload("res://scripts/core/circuit_data.gd")

## Recorded race laps (seconds); rounds without one stay at 0 and show --:--.---.
const LAP_RECORDS: Dictionary = {"apex_ring": 79.6}
## Rounds raced after dark.
const NIGHT_ROUNDS: Dictionary = {"neo_wangan": true}

const APEX_RING_SCENE := "res://scenes/race_world/track_circuit.tscn"
const NEO_WANGAN_SCENE := "res://scenes/race_world/neo_wangan_circuit.tscn"
const DEFAULT_CIRCUIT_ID := "apex_ring"

## Championship table, in round order: id, month, name, native name, inspiration, country, type,
## km, turns, clockwise, elevation delta (m), scene, rain probability, note.
const TABLE: Array[Array] = [
	["apex_ring", "JAN", "Apex Ring International", "", "Fuji Speedway / Motegi", "JPN", 0, 4.16, 9, false, 0.0,
		APEX_RING_SCENE, 0.15, "1.2 km main straight, mountain hairpin, morning fog."],
	["neo_wangan", "FEB", "Neo-Wangan Shuto Express", "新湾岸高速", "Tokyo Shuto C1 / Marina Bay", "JPN", 1, 3.15, 12, true, 9.7,
		NEO_WANGAN_SCENE, 0.25, "Elevated bay expressway, underground underpass, harbor hairpin at night."],
	["brianza", "MAR", "Autodromo di Brianza", "", "Autodromo Nazionale Monza", "ITA", 0, 5.79, 11, true, 12.0,
		"res://scenes/race_world/brianza_circuit.tscn", 0.35, "Temple of speed, Variante chicanes, slipstream war."],
	["monte_azure", "APR", "Monte Azure Marina", "", "Circuit de Monaco / Macau", "MCO", 1, 2.85, 19, true, 42.0,
		"res://scenes/race_world/monte_azure_circuit.tscn", 0.40, "Yacht harbor streets, zero margin for error."],
	["ardennes", "MAY", "Ardennes Valley Ring", "", "Spa-Francorchamps", "BEL", 0, 5.40, 20, true, 104.0,
		"res://scenes/race_world/ardennes_circuit.tscn", 0.75, "Eau Rouge compression climb, micro-climate rain."],
	["stoke_crown", "JUN", "Stoke Crown Circuit", "", "Silverstone Circuit", "GBR", 0, 5.20, 18, true, 12.0,
		"res://scenes/race_world/stoke_crown_circuit.tscn", 0.65, "Maggotts-Becketts high-G aero sweepers."],
	["pacific_corkscrew", "JUL", "Pacific Coast Corkscrew", "", "WeatherTech Raceway Laguna Seca", "USA", 0, 4.10, 11, true, 30.0,
		"res://scenes/race_world/pacific_corkscrew_circuit.tscn", 0.10, "Blind Corkscrew drop, coastal Californian dust."],
	["eifel_forest", "AUG", "Eifel Forest Ring", "", "Nurburgring GP", "GER", 0, 5.15, 16, true, 30.0,
		"res://scenes/race_world/eifel_forest_circuit.tscn", 0.60, "Misty pine forest, technical Schumacher S."],
	["paulistano", "SEP", "Paulistano Speed Arena", "", "Interlagos (Carlos Pace)", "BRA", 0, 4.31, 15, false, 40.0,
		"res://scenes/race_world/paulistano_circuit.tscn", 0.70, "Anti-clockwise, Senna S descent, bowl finish climb."],
	["kurogane", "OCT", "Kurogane Twin-Cross", "", "Suzuka International", "JPN", 0, 5.80, 20, true, 40.0,
		"res://scenes/race_world/kurogane_circuit.tscn", 0.20, "Figure-8 crossover bridge, rhythmic Esses, grand finale."],
]

static var _circuits: Array[CircuitDataScript] = []
static var _by_id: Dictionary = {}


static func get_all_circuits() -> Array[CircuitDataScript]:
	_ensure_built()
	return _circuits


static func get_circuit(circuit_id: String) -> CircuitDataScript:
	_ensure_built()
	return _by_id.get(circuit_id, null)


static func get_circuits_by_type(type: CircuitDataScript.CircuitType) -> Array[CircuitDataScript]:
	_ensure_built()
	var filtered: Array[CircuitDataScript] = []
	for circuit: CircuitDataScript in _circuits:
		if circuit.circuit_type == type:
			filtered.append(circuit)
	return filtered


## The round's championship number, or 0 when the id is not on the calendar.
static func round_of(circuit_id: String) -> int:
	var circuit: CircuitDataScript = get_circuit(circuit_id)
	return circuit.round_number if circuit != null else 0


## The round that follows (or precedes) `circuit_id` on the calendar, wrapping Jan..Dec. Used by
## the race setup selector's arrows.
static func neighbour(circuit_id: String, step: int) -> CircuitDataScript:
	_ensure_built()
	if _circuits.is_empty():
		return null
	var index: int = 0
	for i: int in range(_circuits.size()):
		if _circuits[i].circuit_id == circuit_id:
			index = i
			break
	return _circuits[posmod(index + step, _circuits.size())]


static func _ensure_built() -> void:
	if not _circuits.is_empty():
		return
	var preview_root: String = "res://reference-assets/tracks/%s/concept_key_visual.png"
	for row: Array in TABLE:
		var circuit := CircuitDataScript.new()
		circuit.circuit_id = String(row[0])
		circuit.month_label = String(row[1])
		circuit.display_name = String(row[2])
		circuit.japanese_name = String(row[3])
		circuit.real_inspiration = String(row[4])
		circuit.country_code = String(row[5])
		circuit.circuit_type = int(row[6])
		circuit.length_km = float(row[7])
		circuit.turns_count = int(row[8])
		circuit.direction_clockwise = bool(row[9])
		circuit.elevation_delta_m = float(row[10])
		circuit.scene_path = String(row[11])
		circuit.preview_image_path = preview_root % circuit.circuit_id
		circuit.rain_probability = float(row[12])
		circuit.lap_record_s = float(LAP_RECORDS.get(circuit.circuit_id, 0.0))
		circuit.night_race = bool(NIGHT_ROUNDS.get(circuit.circuit_id, false))
		circuit.notes = String(row[13])
		_circuits.append(circuit)
	for index: int in range(_circuits.size()):
		_circuits[index].round_number = index + 1
		_by_id[_circuits[index].circuit_id] = _circuits[index]
