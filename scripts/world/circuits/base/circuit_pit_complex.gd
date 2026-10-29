class_name CircuitPitComplex
extends Node3D

## The contract every circuit's pit complex fulfils for RaceWeekendWorld, PitstopChoreographer and GtRace, and the
## bookkeeping they all share. A circuit subclasses this (apex_ring, neo_wangan and brianza are the reference
## implementations), builds its lane, boxes and garages into `stalls` and `garages` so that box i serves
## `stalls[i]["team"]` and garage i stands at box i, and overrides only what differs:
##   build()             builds the lane for `ribbon` and seats `team_ids` (sets `built`)
##   _on_teams_assigned  refreshes everything that depends on who sits where (garage fascias, crews, transporters, signs)
##   crew_spot()         where a crew member stands at the garage mouth, if the garage is not the standard width
##   sim_layout()        the lane the GT sim drives, when it differs from the Apex default
## Only the teams that race have a box: the 10 of 13 in `GtRace.active_teams` take the stalls in the sim's stall order,
## and a team without a box has no garage, no crew and no transporter (`stall_index_for_team` is -1).
## `tests/test_pit_team_assignment_contract.gd` and `tests/test_pit_complex_contract.gd` hold every circuit to this.

const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const PitKit := preload("res://scripts/world/shared/pit_kit.gd")

var ribbon: TrackRibbonScript
## How many boxes the lane has, and where the garage fronts and the cars' boxes stand across the lane (metres).
var team_count: int = 0
var garage_front_m: float = 0.0
var stall_lane_m: float = 0.0
## Box i: {team, s, u, lateral, pose, ...}. `team` is -1 for a box nobody races in.
var stalls: Array[Dictionary] = []
var garages: Array[Node3D] = []
## One truck per racing team behind the pit building (null when the circuit parks them elsewhere).
var transporters: Node3D
var built: bool = false


## Builds the lane against `p_ribbon` and seats `team_ids` in the boxes. Override.
func build(_p_ribbon: TrackRibbonScript, _team_ids: Array[int] = []) -> void:
	push_error("%s does not implement build()" % get_script().resource_path)


## What RaceWeekendWorld calls once the race is known: builds the lane if the circuit scene has not, else re-seats.
func seat_teams(p_ribbon: TrackRibbonScript, team_ids: Array[int]) -> void:
	if built:
		assign_teams(team_ids)
	else:
		build(p_ribbon, team_ids)


## Seats `team_ids` (the teams the race runs, in the sim's stall order) in the boxes; extra boxes stay empty.
func assign_teams(team_ids: Array[int]) -> void:
	for i: int in range(stalls.size()):
		stalls[i]["team"] = team_ids[i] if i < team_ids.size() else -1
	_on_teams_assigned()


## Called after the boxes were re-seated: refresh whatever depends on who sits where. Override.
func _on_teams_assigned() -> void:
	pass


func stall_index_for_team(team: int) -> int:
	for i: int in range(stalls.size()):
		if int(stalls[i].get("team", -1)) == team:
			return i
	return -1


func garage_for_team(team: int) -> Node3D:
	var index: int = stall_index_for_team(team)
	return garages[index] if index >= 0 and index < garages.size() else null


## Where the team's car parks (the box pose in world space); the identity for a team without a box.
func stall_transform(team: int) -> Transform3D:
	var index: int = stall_index_for_team(team)
	return stalls[index]["pose"] if index >= 0 else Transform3D.IDENTITY


## The crew standing in a box: 13 people, in the order they line up across the garage mouth.
func crew_roles() -> Array:
	return PitKit.standby_roles()


## Where crew member `slot` stands at the garage mouth (garage frame: +x away from the lane).
func crew_spot(slot: int) -> Vector3:
	return PitKit.standby_spot(slot)


## The lane the GT sim drives (see GtRace.default_pit_layout for the keys). Empty means the Apex default.
func sim_layout() -> Dictionary:
	return {}
