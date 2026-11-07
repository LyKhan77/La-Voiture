class_name GtTeamStats
extends RefCounted

## The people behind each of the 13 teams, as numbers the player can see and Career Mode can grow: the race
## Engineer (how well the pit wall reads the forecast and how soon it acts), the pit crew (how fast it works and how
## rarely it errs) and the two personality constants of the strategist (`risk_bias`, `herd`, not shown). Same order as
## `GtData.TEAM_NAMES`. Ratings are 0..1; nobody is the best at both Engineer and crew speed.

## Engineer rating: forecast trust, read noise and reaction speed all follow it (`engineer_profile`).
const ENGINEER: Array[float] = [0.55, 0.40, 0.70, 0.50, 0.45, 0.80, 0.30, 0.60, 0.75, 0.35, 0.90, 0.25, 0.65]
## Pit crew speed: mean stop time (GtTeamStats pit-crew functions of Task 11).
const CREW_SPEED: Array[float] = [0.60, 0.50, 0.45, 0.70, 0.85, 0.35, 0.65, 0.55, 0.40, 0.80, 0.15, 0.75, 0.95]
## Pit crew consistency: how rarely a stop goes wrong.
const CREW_CONSISTENCY: Array[float] = [0.55, 0.60, 0.70, 0.45, 0.50, 0.65, 0.40, 0.85, 0.75, 0.55, 0.60, 0.35, 0.80]
## Strategist personality, constant per team: water points its reading leans (+ keeps rain tyres longer) and how much it follows the field.
const RISK_BIAS: Array[float] = [1.5, -3.0, 4.0, -1.0, 6.0, -5.0, 2.0, -7.0, 3.0, 0.5, -2.0, 7.0, -4.0]
const HERD: Array[float] = [0.50, 0.30, 0.70, 0.40, 0.20, 0.80, 0.60, 0.10, 0.90, 0.50, 0.35, 0.65, 0.45]


## The strategist of `team_id` (same keys as GtStrategy.profile): the Engineer rating sets trust, noise and reaction;
## the personality constants set the lean and the herding.
static func engineer_profile(team_id: int) -> Dictionary:
	var team: int = clampi(team_id, 0, ENGINEER.size() - 1)
	var engineer: float = ENGINEER[team]
	return {
		"forecast_trust": lerpf(0.45, 1.0, engineer),
		"risk_bias": RISK_BIAS[team],
		"reaction_sectors": 2 - roundi(2.0 * engineer),
		"read_noise": 1.0 - engineer,
		"herd": HERD[team],
	}


## Seconds the crew of `team_id` needs for a clean stop (before damage repair and refuelling): faster crews are lower.
static func mean_stop_time(team_id: int) -> float:
	return lerpf(3.8, 2.6, CREW_SPEED[clampi(team_id, 0, CREW_SPEED.size() - 1)])


## The team whose crew is the slowest (the one the mandatory-stop penalty is sized against).
static func slowest_crew_team() -> int:
	var slowest: int = 0
	for team: int in range(CREW_SPEED.size()):
		if CREW_SPEED[team] < CREW_SPEED[slowest]:
			slowest = team
	return slowest


## How long one stop of `team_id` takes: the mean, plus an error of 0.5 to 2.0 s now and then (more often for a less
## consistent crew). `serial` tells the team's stops apart; the draw comes from its own hash stream, so a seed replays.
static func pit_stop_time(team_id: int, race_seed: int, serial: int) -> float:
	var team: int = clampi(team_id, 0, CREW_SPEED.size() - 1)
	var rng := GtRng.new(((race_seed * 1103515245) ^ ((serial + 1) * 0x9E3779B1) ^ ((team + 1) * 0x85EBCA6B) ^ 0x1F83D9AB) & 0x7FFFFFFF)
	var time_s: float = mean_stop_time(team)
	if rng.next() < lerpf(0.25, 0.04, CREW_CONSISTENCY[team]):
		time_s += lerpf(0.5, 2.0, rng.next())
	return maxf(2.0, time_s)
