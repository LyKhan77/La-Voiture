class_name CircuitData
extends Resource

## One round of the 12-month championship calendar (FASE 12): the venue's identity, its racing
## facts and where the game loads it from. The calendar registry owns the official table
## (CircuitCalendarRegistry); the race setup menu, the career season and RaceWeekendWorld read it.

enum CircuitType { GRAND_PRIX, SPRINT }

@export var circuit_id: String = ""
@export var round_number: int = 0
## Championship month, JAN..DEC (12 rounds, one per month).
@export var month_label: String = ""
## Official fictional name, e.g. "Neo-Wangan Shuto Express".
@export var display_name: String = ""
## Native-script name shown beside the English one ("" when the venue has none).
@export var japanese_name: String = ""
## The real circuit the layout is modelled on, e.g. "Tokyo Shuto C1 / Marina Bay".
@export var real_inspiration: String = ""
@export var country_code: String = ""
@export var circuit_type: CircuitType = CircuitType.GRAND_PRIX
@export var length_km: float = 0.0
@export var turns_count: int = 0
@export var direction_clockwise: bool = true
## Highest corner above the lowest, metres (the elevation profile's amplitude).
@export var elevation_delta_m: float = 0.0
## Scene carrying the circuit's TrackRibbon (Path3D); "" until the venue is built.
@export var scene_path: String = ""
## Concept art for the selector card; loaded only when the file exists.
@export var preview_image_path: String = ""
## 0..1 chance of rain in this round's weekend weather, used by Career Mode.
@export var rain_probability: float = 0.0
## True for a street circuit run under floodlights: the setup screen defaults the time chip to night.
@export var night_race: bool = false
## The round's fastest race lap in seconds; 0 until a lap has been set.
@export var lap_record_s: float = 0.0
## One line of colour for the setup card and the career calendar.
@export var notes: String = ""


func is_sprint() -> bool:
	return circuit_type == CircuitType.SPRINT


func type_label() -> String:
	return "SPRINT" if is_sprint() else "GRAND PRIX"


## True once the circuit's own scene exists, so callers can offer it instead of teasing it.
func is_playable() -> bool:
	return scene_path != "" and ResourceLoader.exists(scene_path)


## "3.15 KM" for cards and labels.
func length_label() -> String:
	return "%.2f KM" % length_km


## "1:19.600", or "--:--.---" while the round has no recorded lap.
func lap_record_label() -> String:
	if lap_record_s <= 0.0:
		return "--:--.---"
	return "%d:%06.3f" % [int(lap_record_s / 60.0), fmod(lap_record_s, 60.0)]
