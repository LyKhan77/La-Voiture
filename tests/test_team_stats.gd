extends SceneTree

## Fase 32 Task 10: every team has a visible Engineer rating (and the personality constants `risk_bias` / `herd`) in
## GtTeamStats; GtStrategy.profile now reads it, so a strategist no longer depends on the race seed, and a better
## Engineer trusts the forecast more, reads it with less noise and reacts sooner.
## Run: godot --headless --path . -s res://tests/test_team_stats.gd

var failures: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_tables()
	_test_profile_follows_the_engineer()
	_test_profile_ignores_the_seed()
	quit(1 if failures else 0)


func _in_unit_range(values: Array[float]) -> bool:
	for value: float in values:
		if value < 0.0 or value > 1.0:
			return false
	return true


func _test_tables() -> void:
	var teams: int = GtData.TEAM_NAMES.size()
	check(GtTeamStats.ENGINEER.size() == teams and GtTeamStats.CREW_SPEED.size() == teams and GtTeamStats.CREW_CONSISTENCY.size() == teams \
			and GtTeamStats.RISK_BIAS.size() == teams and GtTeamStats.HERD.size() == teams, "every table has one entry per team (%d)" % teams)
	check(_in_unit_range(GtTeamStats.ENGINEER) and _in_unit_range(GtTeamStats.CREW_SPEED) and _in_unit_range(GtTeamStats.CREW_CONSISTENCY) and _in_unit_range(GtTeamStats.HERD), "every rating is between 0 and 1")
	var bias_ok: bool = true
	for bias: float in GtTeamStats.RISK_BIAS:
		bias_ok = bias_ok and absf(bias) <= GtStrategy.MAX_RISK_BIAS_PCT
	check(bias_ok, "every risk bias is inside +-%.0f water points" % GtStrategy.MAX_RISK_BIAS_PCT)
	var low: float = 1.0
	var high: float = 0.0
	var best_engineer: int = 0
	var best_crew: int = 0
	for team: int in range(teams):
		low = minf(low, GtTeamStats.ENGINEER[team])
		high = maxf(high, GtTeamStats.ENGINEER[team])
		if GtTeamStats.ENGINEER[team] > GtTeamStats.ENGINEER[best_engineer]:
			best_engineer = team
		if GtTeamStats.CREW_SPEED[team] > GtTeamStats.CREW_SPEED[best_crew]:
			best_crew = team
	check(high - low >= 0.4, "the Engineer ratings are spread (%.2f to %.2f)" % [low, high])
	check(best_engineer != best_crew, "no team is the best at both Engineer and crew speed")


func _test_profile_follows_the_engineer() -> void:
	var order: Array[int] = []
	for team: int in range(GtData.TEAM_NAMES.size()):
		order.append(team)
	order.sort_custom(func(a: int, b: int) -> bool: return GtTeamStats.ENGINEER[a] < GtTeamStats.ENGINEER[b])
	var trust_up: bool = true
	var noise_down: bool = true
	var react_down: bool = true
	var previous: Dictionary = GtStrategy.profile(1, order[0])
	for index: int in range(1, order.size()):
		var profile: Dictionary = GtStrategy.profile(1, order[index])
		trust_up = trust_up and float(profile["forecast_trust"]) >= float(previous["forecast_trust"]) - 0.0001
		noise_down = noise_down and float(profile["read_noise"]) <= float(previous["read_noise"]) + 0.0001
		react_down = react_down and int(profile["reaction_sectors"]) <= int(previous["reaction_sectors"])
		previous = profile
	check(trust_up, "a better Engineer trusts the forecast at least as much")
	check(noise_down, "a better Engineer reads it with no more noise")
	check(react_down, "a better Engineer waits no more sectors before acting")
	var worst: Dictionary = GtStrategy.profile(1, order[0])
	var best: Dictionary = GtStrategy.profile(1, order[order.size() - 1])
	var worst_weight: float = float(worst["read_noise"]) * (1.0 - float(worst["forecast_trust"]))
	var best_weight: float = float(best["read_noise"]) * (1.0 - float(best["forecast_trust"]))
	check(best_weight < worst_weight, "the best Engineer's forecast error weight is below the worst's (%.3f < %.3f)" % [best_weight, worst_weight])
	var complete: bool = true
	for team: int in range(GtData.TEAM_NAMES.size()):
		var profile: Dictionary = GtStrategy.profile(1, team)
		complete = complete and profile.has("forecast_trust") and profile.has("risk_bias") and profile.has("reaction_sectors") and profile.has("read_noise") and profile.has("herd")
		complete = complete and is_equal_approx(float(profile["risk_bias"]), GtTeamStats.RISK_BIAS[team]) and is_equal_approx(float(profile["herd"]), GtTeamStats.HERD[team])
	check(complete, "every profile has the five keys and carries the team's personality constants")


func _test_profile_ignores_the_seed() -> void:
	var same: bool = true
	for team: int in range(GtData.TEAM_NAMES.size()):
		same = same and GtStrategy.profile(1, team) == GtStrategy.profile(999, team)
	check(same, "a team's strategist is the same in every race seed")
	check(GtStrategy.NEUTRAL_PROFILE == {"forecast_trust": 1.0, "risk_bias": 0.0, "reaction_sectors": 0, "read_noise": 0.0, "herd": 0.0}, "the garage crew pick still reads the forecast as it is")
