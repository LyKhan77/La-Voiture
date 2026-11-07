# Tactical Deck Balance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every Tactical Deck option a context where it is best, make 10 and 15 lap races carry a real pit decision, make the Safety Car reach the leader in bounded time, and expose per-team Engineer and Pit Crew stats as the foundation for Career Mode.

**Architecture:** All rules stay inside the GT sim (`scripts/gt/`), driven at the existing 20 Hz tick. New numeric knobs live in `GtTypes`; new logic lives in two new focused files (`gt_fuel_plan.gd`, `gt_team_stats.gd`) plus small additions to `GtRace`, `GtDriving`, `GtStrategy`. Rivals and AUTO share one mode-chooser (`GtStrategy.choose_modes`) that differs only by a hash-seeded parameter profile. Every task is gated by a headless test and by the balance probe (`temp/probe_balance.gd`).

**Tech Stack:** Godot 4.7.2, GDScript 2.0 (static typing), headless SceneTree tests under `tests/test_*.gd`, `tools/run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-11-07-tactical-deck-balance-design.md` (executors read both; section 5a holds the rulings on mandatory-stop rules, circuit scope, fuel, AUTO/rival sharing, `risk_bias`/`herd`, VSC escalation).

## Global Constraints

- Branch `fase-32-tactical-balance`; one commit per task; stage files per path (never `git add -A` or `git add .`); every commit message ends with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Simulation stays deterministic for `race_seed`: every new random decision (VSC delay, rival tactic profile, pit crew error, caution-stop roll) uses its own hash stream `GtRng.new(((race_seed * 1103515245) ^ ((key + 1) * 0x9E3779B1) ^ SALT) & 0x7FFFFFFF)` with a unique `SALT`, never `race.rng`.
- GDScript 2.0 with static typing everywhere; no new dependency.
- Race lengths stay 3, 5, 10, 15 laps (`scripts/ui/race_setup_menu.gd`, `LAPS`). Mandatory stop applies at 10 and 15 laps only; 3 and 5 lap races never get a pit penalty.
- Tank cap 110 kg (`gt_driving.gd:1253`); running dry keeps the existing FLAMEOUT then DNF "Out of Fuel".
- Pit lane stays open under SC and VSC; VSC from debris or a stopped car (`gt_driving.gd:811`, `:826`, `gt_contacts.gd:246`) is not changed.
- AUTO desk mode must use the same decision code as rivals; rain-race behaviour must not regress (`test_weather_and_ai`, `test_weather_ladder`, `test_adaptive_tyre_strategy` stay green).
- Tests follow this repo's convention (SceneTree script `tests/test_<feature>.gd` with a `check(ok, description)` helper printing `[PASS]` / `[FAIL]`, as in `tests/test_pit_under_safety_car.gd`), not gdUnit4. A new test must be run against the unchanged code first and seen to fail.
- Run suites through `powershell -File tools/run_tests.ps1 -Filter <name>`; the full regression runs in foreground slices under 10 minutes (`-From 0 -To 19`, `20-34`, `35-52`, `53-72`, `73-82`, `83-92`, `93-115`, plus the new suites).
- Frame budget (60 FPS, 20 cars) is untouched: no per-frame work outside the 20 Hz tick.
- Probe, scratch output and backups go to `temp/`; docs report to `executor-report/reports/FASE-32-TACTICAL-BALANCE-REPORT.md`.

## Review Focus

- A car retires (DNF) before the stop window in a 10-lap race: no mandatory-stop penalty (Task 5 test).
- A weather stop at 12% progress in a rain race counts as the mandatory stop and no second penalty is added (Task 5 test).
- 3 and 5 lap races never receive a mandatory-stop penalty at the flag (Task 5 test).
- SC deployed while `_sc_leader()` is null (everyone in the pits or retired) or a second heavy crash while an escalation is pending or an SC is active: one SC only, no crash (Tasks 1 and 2 tests).
- Garage fuel input of 0, negative, NaN-like extremes, or above 110 kg is clamped; a pick too small for the plan is allowed and shows DANGER (Task 4 test).
- Same `race_seed` run twice gives an identical finishing order and stop count after rival tactics are added (Task 9 test).

---

### Task 0: Branch, task board, and baseline probe

**Files:**
- Modify: `todo.md` (the old list is fully checked, so overwrite is allowed)
- Create: `temp/probe_balance.gd` (restore the full probe; the file now holds only the rate table)
- Create: `temp/baseline_fase32.txt`

**Interfaces:**
- Produces: probe functions `_rate_table()`, `_solo_matrix()`, `_field_run(laps)`, `_sc_catchup()`, `_pit_loss()` that later tasks re-run; `temp/baseline_fase32.txt` holding the numbers in spec section 1 plus the measured pit loss in seconds.

- [ ] **Step 1:** `git checkout -b fase-32-tactical-balance`; overwrite `todo.md` with this plan's task list (title, date 2026-11-07, agent, branch, one `- [ ]` per task).
- [ ] **Step 2:** Restore `_solo_matrix()`, `_field_run()` and `_sc_catchup()` in `temp/probe_balance.gd` from spec section 1 (the three functions the earlier probe had); keep `_rate_table()`. Call them from `_run()` behind a command-line arg so each can run alone.
- [ ] **Step 3:** Find why the earlier 1-stop probe ended with `stops=0` (a `request_pit(0, compound)` made at `c.lap >= laps / 2` was never serviced for a solo car). Fix the probe, not the sim, unless the cause is a sim bug; if it is a sim bug, stop and report it.
- [ ] **Step 4:** Add `_pit_loss()`: the same solo race with and without one stop; print `loss_s = time_with_stop - time_without_stop` for 5, 10, 15 laps on Apex Ring. Record the result in `temp/baseline_fase32.txt`.
- [ ] **Step 5:** Run the probe through the console exe (`Godot_v4.7.2-stable_win64_console.exe --headless --path . -s temp/probe_balance.gd`), confirm it reproduces spec section 1 (SC pickup 434 s at 5% lap, rate table, 0 stops in 15 laps) and writes `baseline_fase32.txt`.
- [ ] **Step 6:** Commit `todo.md` only (`temp/` is ignored): `chore(fase-32): task board and baseline numbers`.

---

### Task 1: Safety Car catch-up

**Files:**
- Modify: `scripts/gt/gt_race.gd:20-21` (constants), `:585-587` (SC speed), `scripts/gt/gt_driving.gd:545-558` (catch-up cap)
- Test: `tests/test_sc_catchup.gd`; update pinned values in `tests/test_safety_car_cinematic.gd` and `tests/test_track_incidents_and_stewards.gd` only where they fail

**Interfaces:**
- Produces: `GtRace.SC_CATCHUP_SPEED_MPS: float = 22.0`, `SC_LEADER_CATCHUP_MAX_MPS: float = 50.0`, `SC_CATCHUP_NEAR_M: float = 250.0`, `SC_CATCHUP_FAR_M: float = 900.0`, and `static func sc_catchup_cap(gap_to_sc: float) -> float` (27.0 at or below `SC_CATCHUP_NEAR_M`, 50.0 at or above `SC_CATCHUP_FAR_M`, `smoothstep` between, monotone).

- [ ] **Step 1: Write the failing test** `tests/test_sc_catchup.gd` with: unit `check(is_equal_approx(GtRace.sc_catchup_cap(100.0), 27.0))`, `check(is_equal_approx(GtRace.sc_catchup_cap(1500.0), 50.0))`, monotone over 20 samples; integration on Apex Ring (`TrackScene`, `RaceScript.new(track, 10, 5, DRY, 20)`, `incidents_enabled = false`): warm up 1500 ticks, advance until the leader is 5%, 50% and 95% of a lap past `pit_layout["exit_s"] - 60.0`, call `race.set_flag(Types.Flag.SC, 1, "test", 28.0)`, assert `safety_car["picked_up"]` becomes true within 170 s of race time for the 5% case, 120 s for 50%, 40 s for 95%; assert the `collision_event` signal count stays 0 during the catch-up; assert `_sc_queue_ready` style bunching: the field is within `SC_QUEUE_GAP_M` gaps no later than 90 s after pickup. Add a case where every car is in the pit or retired (`_sc_leader()` null) and `step()` runs 100 ticks without a script error.
- [ ] **Step 2:** Run `powershell -File tools/run_tests.ps1 -Filter sc_catchup`. Expected: FAIL (function missing).
- [ ] **Step 3:** Add the constants and `sc_catchup_cap` to `GtRace`; change unpicked SC `target_v` at `gt_race.gd:586-587` from 18.0 to `SC_CATCHUP_SPEED_MPS`.
- [ ] **Step 4:** In `GtDriving._apply_flags` (SC branch), while `phase == DEPLOYED` and `not picked_up` and the car is racing (not in pit), replace the `110.0 / 3.6` cap with `GtRace.sc_catchup_cap(gap_to_sc)` for every car, not only the leader (a leader-only cap stretches the field). Cars behind keep following the car ahead through the existing lead-hold lines (`:559-561`). After pickup the existing 110 km/h and 27 m/s caps apply unchanged.
- [ ] **Step 5:** Run the new suite; expected PASS. Run `-Filter safety_car` and `-Filter incidents_and_stewards`; for each pinned number that moves, update the assertion with a comment `# Fase 32: SC catch-up cap` and confirm the cause is the new speeds, not a regression.
- [ ] **Step 6:** Re-run the probe `_sc_catchup()`; record the new pickup times next to the baseline.
- [ ] **Step 7:** Commit per path: `feat(sc): leader catch-up cap and faster unpicked safety car`.

---

### Task 2: VSC before SC

**Files:**
- Modify: `scripts/gt/gt_race.gd` (new `raise_sc`, pending state, `_update_race_control` top), `scripts/gt/gt_driving.gd:272`, `scripts/gt/gt_contacts.gd:217`, `:260`
- Test: `tests/test_vsc_escalation.gd`; update `tests/test_safety_car_cinematic.gd`, `tests/test_track_incidents_and_stewards.gd`, `tests/test_pit_under_safety_car.gd` where they assume an immediate SC

**Interfaces:**
- Produces: `GtRace.raise_sc(sector: int, message: String, duration: float = 28.0) -> void`; `static func sc_escalation_delay_s(race_seed: int, serial: int) -> float` (8.0 to 15.0 from its own hash stream, SALT `0x7C5A11E3`); private `_sc_pending: Dictionary` (`{"at": float, "sector": int, "message": String, "duration": float}` or empty) and `_sc_serial: int`.
- Consumes: `set_flag(flag, sector, message, duration)` (existing).

- [ ] **Step 1: Write the failing test** `tests/test_vsc_escalation.gd`: (a) `race.raise_sc(2, "CRASH", 32.0)` sets flag `VSC` immediately and `SC` after `sc_escalation_delay_s(seed, 0)` seconds, never earlier than 8.0 or later than 15.0 plus one tick; (b) two races with the same seed give the same delay, different `serial` can differ; (c) a second `raise_sc` while an escalation is pending or an SC is active produces exactly one `SafetyCarPhase.DEPLOYED` spawn (`safety_car["s"]` unchanged by the second call); (d) the existing debris `set_flag(VSC, ...)` still clears to GREEN by timer with no SC; (e) pit lane open: a car given `request_pit` during the VSC window enters the pit.
- [ ] **Step 2:** Run `-Filter vsc_escalation`; expected FAIL.
- [ ] **Step 3:** Implement `raise_sc`: if `flag == SC and active` or `_sc_pending` is non-empty, route to `set_flag(SC, ...)` (no second spawn) or return; otherwise `set_flag(VSC, sector, "VIRTUAL SAFETY CAR - INCIDENT SECTOR %d" % sector, delay)` and fill `_sc_pending`. At the top of `_update_race_control`, if `_sc_pending` is non-empty and `time >= at`, clear it and call `set_flag(SC, sector, message, duration)` before the VSC timer can expire to GREEN.
- [ ] **Step 4:** Replace the three `set_flag(GtTypes.Flag.SC, ...)` calls with `race.raise_sc(sector, message, duration)` (same messages and durations).
- [ ] **Step 5:** Run the new suite (PASS), then `-Filter safety_car`, `-Filter pit_under`, `-Filter incidents_and_stewards`; fix test assumptions with a `# Fase 32: VSC precedes SC` comment.
- [ ] **Step 6:** Commit: `feat(sc): VSC window before safety car on heavy crashes`.

---

### Task 3: Fuel plan model

**Files:**
- Create: `scripts/gt/gt_fuel_plan.gd`
- Modify: `scripts/gt/gt_types.gd`, `scripts/gt/gt_car.gd`, `scripts/gt/gt_forecast.gd`, `scripts/gt/gt_race.gd:181`, `scripts/gt/gt_driving.gd:354`, `:786-797`, `:1253-1254`, `:1003`
- Test: `tests/test_fuel_plan.gd`

**Interfaces:**
- Produces in `GtTypes`: `TANK_CAP_KG: float = 110.0`, `REFUEL_S_PER_KG: float = 0.06`, `FUEL_WEIGHT_PACE_PER_KG: float = 0.0004` (all start values; Task 7 tunes them).
- Produces `GtFuelPlan` (`class_name GtFuelPlan extends RefCounted`): `static func clamp_kg(kg: float) -> float` (0 to `TANK_CAP_KG`; non-finite becomes 0); `static func crew_pick_kg(total_laps: int, fuel_use: float) -> float` (`total_laps * fuel_use * 1.08` below `MANDATORY_MIN_LAPS`; at or above it `0.5 * total_laps * fuel_use * 1.08`, the light start for a stop around mid window; clamped); `static func refuel_target_kg(laps_left: float, fuel_use: float) -> float` (`minf(TANK_CAP_KG, laps_left * fuel_use * 1.08)`).
- Produces `GtForecast.fuel_alarm(race: GtRace, car: GtCar) -> bool`: true when `fuel_margin_laps(...) < 0.0` and the car has no mandatory stop still ahead (not required, already done, or progress at or past `STOP_WINDOW_CLOSE - 0.05`), or when fuel is under 1.5 laps of burn regardless.
- Also produces here, so Task 5 only uses them: in `GtTypes` `MANDATORY_MIN_LAPS: int = 10`, `STOP_WINDOW_OPEN: float = 0.20`, `STOP_WINDOW_CLOSE: float = 0.80`; in `scripts/gt/gt_car.gd` `var mandatory_stop_done: bool = false`. `fuel_alarm` computes progress inline as `car.s / (float(race.laps) * race.track.length)` and tests `race.laps >= GtTypes.MANDATORY_MIN_LAPS` itself, because `GtRace.mandatory_stop_required()` and `race_progress()` arrive in Task 5.

- [ ] **Step 1: Write the failing test** `tests/test_fuel_plan.gd`: `crew_pick_kg(5, 3.0)` equals `5*3.0*1.08` and `crew_pick_kg(15, 3.0)` equals `0.5*15*3.0*1.08`; `clamp_kg(-4.0) == 0.0`, `clamp_kg(500.0) == 110.0`, `clamp_kg(INF) == 0.0`; a grid built by `RaceScript.new(track, 15, 5, DRY, 20)` gives every car `fuel == GtFuelPlan.crew_pick_kg(15, car.fuel_use)`; a pit service adds `(target - initial) * REFUEL_S_PER_KG` to `pit.duration` (assert on `car.pit.duration` after `enter_pit_lane` for a car with 10 kg and with 40 kg); `fuel_alarm` is false for a car on a planned stop at 30% progress with 40% fuel left and true for a car past the window with `margin < 0`.
- [ ] **Step 2:** Run `-Filter fuel_plan`; expected FAIL.
- [ ] **Step 3:** Implement `GtFuelPlan`, the `GtTypes` constants, and `GtForecast.fuel_alarm`.
- [ ] **Step 4:** `gt_race.gd:181`: set `car.fuel = GtFuelPlan.crew_pick_kg(laps, car.fuel_use)`. `gt_driving.gd:354`: `fuel_factor = 1.0 - GtTypes.FUEL_WEIGHT_PACE_PER_KG * car.fuel`. `enter_pit_lane` (`:1003`): add `refuel_s = (GtFuelPlan.refuel_target_kg(laps_left, car.fuel_use) - car.fuel) * REFUEL_S_PER_KG` (floored at 0) to `pit.duration`; `_service_car` (`:1253`) uses `GtFuelPlan.refuel_target_kg` for `needed` (keep the `maxf(pit.initial_fuel, ...)`).
- [ ] **Step 5:** Replace the fixed `car.fuel < 3.0` WARNING branch (`:792-795`) with `GtForecast.fuel_alarm(race, car)`; keep the LIMP, SPUTTER and FLAMEOUT thresholds untouched. The "Fuel critical" radio call fires only on the alarm.
- [ ] **Step 6:** Run `-Filter fuel_plan`, `-Filter race_world`, `-Filter pit_stop`, `-Filter pit_lane`, `-Filter deck_n2`; update pins that assumed `fuel_use * laps * 1.05` with a `# Fase 32` comment.
- [ ] **Step 7:** Commit: `feat(fuel): fuel plan, refuel time, weight constant and projection alarm`.

---

### Task 4: Garage fuel choice with Crew Pick

**Files:**
- Modify: `scripts/core/race_config_data.gd:25-26` and `:95-103`, `scripts/ui/garage_team_select.gd` (strategy deck `:447-496`, `select_compound` neighbours)
- Test: `tests/test_garage_fuel_choice.gd`

**Interfaces:**
- Produces: `RaceConfigData.car1_start_fuel_kg: float = -1.0` and `car2_start_fuel_kg: float = -1.0` (-1 means Crew Pick); `RaceConfigData.start_fuel_for(car_slot: int, fuel_use: float) -> float` (the pick or `GtFuelPlan.crew_pick_kg(total_laps, fuel_use)`, always clamped); `garage_team_select.gd`: `func select_fuel(car_slot: int, kg: float) -> void` (clamps with `GtFuelPlan.clamp_kg`, refreshes labels, plays the click like `select_compound`), `func get_crew_pick_fuel(car_slot: int) -> float`, and per car a `fuel_label: Label` plus step buttons `fuel_down`, `fuel_up`, reachable as `garage.fuel_controls[car_slot]` (Dictionary with those three keys).
- Consumes: `GtFuelPlan.crew_pick_kg`, `GtFuelPlan.clamp_kg`, `GtForecast.fuel_margin_laps`.

- [ ] **Step 1: Write the failing test** `tests/test_garage_fuel_choice.gd` in the style of `tests/test_garage_tyre_strategy.gd`: instantiate `scenes/ui/garage_team_select.tscn` with `config.total_laps = 15`; `get_crew_pick_fuel(0)` equals `GtFuelPlan.crew_pick_kg(15, <team fuel_use>)`; `select_fuel(0, -5.0)` stores 0.0, `select_fuel(0, 9999.0)` stores 110.0; `select_fuel(1, 12.0)` leaves car 1's choice independent; the label for a pick below the one-stop need contains `DANGER`; the Crew Pick value is marked with the star used for tyres; after `apply_to_race(race)` the player cars carry the chosen fuel and rivals carry `crew_pick_kg`; a team change leaves a manual pick untouched.
- [ ] **Step 2:** Run `-Filter garage_fuel`; expected FAIL.
- [ ] **Step 3:** Add the config fields and `start_fuel_for`; in `apply_to_race`, after the tyre assignment, set `car.fuel = start_fuel_for(slot, car.fuel_use)` for the two player cars.
- [ ] **Step 4:** Add the fuel row to the strategy deck inside the free band of the existing 1840x252 panel without moving `LaunchButton`/`BackButton` or the forecast block; mirror the StreetStyle helpers used by the tyre row. The label shows kg, laps of fuel, the verdict word (OK, WATCH, DANGER from `GtForecast`-style thresholds against the one-stop plan), and `★ CREW PICK` on the suggested value; step size 2 kg.
- [ ] **Step 5:** Run `-Filter garage_fuel` (PASS) and `-Filter garage` for the existing garage suites; fix only intended breakage.
- [ ] **Step 6:** Commit: `feat(garage): per-car start fuel choice with crew pick`.

---

### Task 5: Mandatory pit stop

**Files:**
- Modify: `scripts/gt/gt_car.gd` (state), `scripts/gt/gt_pit.gd` (`forced`), `scripts/gt/gt_race.gd:191` (`mark_finished`) and new methods, `scripts/gt/gt_driving.gd:1003` and `:1278`, `scripts/hud/tactical_deck.gd` (`_build_header`, `refresh`), `tools/audio/radio_lines.mjs` plus the new clips
- Test: `tests/test_mandatory_stop.gd`

**Interfaces:**
- Produces (`GtCar.mandatory_stop_done` already exists from Task 3): `GtPit.forced: bool = false` (set in `enter_pit_lane` when the car is punctured, damaged, or the target compound switches between slick and rain classes); `GtRace.mandatory_stop_required() -> bool` (`laps >= GtTypes.MANDATORY_MIN_LAPS`); `GtRace.race_progress(car: GtCar) -> float` (`clampf(car.s / (float(laps) * track.length), 0.0, 1.0)`); `GtRace.note_stop_completed(car: GtCar, forced: bool) -> void` (sets `mandatory_stop_done` when required and progress is in `[STOP_WINDOW_OPEN, STOP_WINDOW_CLOSE]`, or when `forced` and progress is at most `STOP_WINDOW_CLOSE`); `GtRace.mandatory_penalty_s() -> float` (`1.5 * GtStrategy.pit_loss_s(self, track.length / 45.0)`, raised to at least `GtTypes.MANDATORY_PENALTY_FLOOR_S = 30.0`); `GtRace.mandatory_stop_status(car: GtCar) -> Dictionary` (`{"required": bool, "done": bool, "window_open": bool, "open_lap": int, "close_lap": int, "penalty_s": float}`); `TacticalDeck.stop_label: Label`.
- Consumes: Task 0's measured pit loss (the 1.5 multiplier is checked against it in Step 6).

- [ ] **Step 1: Write the failing test** `tests/test_mandatory_stop.gd`: 15 lap race, one car with no stop: after `mark_finished`, `penalty_owed_s == mandatory_penalty_s()` and `classified_time` is higher by that amount; a car stopping at 50% progress gets no penalty and `mandatory_stop_done`; a stop at 10% does not count (done stays false) unless `forced`; a stop at 85% does not count; a forced rain-tyre stop at 12% counts and adds no second penalty (Review Focus); a car marked `is_dnf` before the window is never penalised (Review Focus); 3 and 5 lap races never penalise (Review Focus); `mandatory_stop_status` returns window laps `ceili(0.2*laps)` and `floori(0.8*laps)`; a stop under an active SC counts; the deck's `stop_label.text` shows REQUIRED before and DONE after.
- [ ] **Step 2:** Run `-Filter mandatory_stop`; expected FAIL.
- [ ] **Step 3:** Implement the state and methods above; call `note_stop_completed(car, pit.forced)` next to `car.stops += 1` (`gt_driving.gd:1278`); in `mark_finished`, add `mandatory_penalty_s()` to `car.penalty_owed_s` when required, not done, and not DNF (guard against double application with a flag on the car).
- [ ] **Step 4:** Add `stop_label` to the deck header and update it in `refresh()` from `mandatory_stop_status` for the deck car (hidden when not required); add the two engineer radio lines ("Mandatory stop window is open. Suggest box this lap." and "Window closes in two laps. Box now.") by reading `tools/audio/radio_lines.mjs` and the existing generation procedure and producing the clips the same way existing lines are made (the radio rule: every call needs a clip).
- [ ] **Step 5:** Run the new suite (PASS), then `-Filter pit`, `-Filter race_world`, `-Filter deck`.
- [ ] **Step 6:** Using the probe's `_pit_loss()` numbers, confirm the penalty is at least 1.5 times the measured loss at 10 and 15 laps; raise `MANDATORY_PENALTY_FLOOR_S` if not.
- [ ] **Step 7:** Commit: `feat(race): mandatory pit stop window and penalty for 10/15 lap races`.

---

### Task 6: Mode economy

**Files:**
- Modify: `scripts/gt/gt_types.gd:33-42`, `scripts/gt/gt_driving.gd:295-325`, `:455-456`
- Test: `tests/test_mode_economy.gd`

**Interfaces:**
- Produces in `GtTypes` (start values, builder tunes with the probe): `FUEL_PACE_MULT: Array[float] = [0.990, 1.0, 1.007]`, `ERS_DEPLOY_PACE_MULT: Array[float] = [1.0, 1.0, 1.003, 1.006]`, `ERS_REGEN_BRAKE_PER_S: float = 8.5`; retuned `PACE_TARGET_TEMP[ATTACK]`, `PACE_WEAR_MULT[ATTACK]`, `PACE_SPEED_MULT[ATTACK]`.
- Produces test helper in the test file: `_lap(compound, pace, fuel, ers) -> Dictionary {"lap_s", "wear", "fuel_kg"}` (solo car, lap 2, full battery, same procedure as the probe `_rate_table()`).

- [ ] **Step 1: Write the failing test** `tests/test_mode_economy.gd` asserting on a fresh MEDIUM solo lap against STANDARD: fuel PUSH is at least 0.4 s faster and burns at least 1.2 times the fuel; ERS DEPLOY is at least 0.3 s faster than NEUTRAL; ATTACK is at least 0.5 s faster than AGGRESSIVE and no puncture or wear above 0.85 within 2 laps; AGGRESSIVE stays 0.7 to 1.2 s faster than STANDARD; CONSERVE and LIGHT are slower and cheaper. Generic dominance property over all pace and fuel options: no option is at least as fast, as cheap in wear and as cheap in fuel as STANDARD while strictly better in one of them, and no option except CONSERVE, LIGHT, HARVEST is slower and costlier in both wear and fuel.
- [ ] **Step 2:** Run `-Filter mode_economy`; expected FAIL (PUSH gain 0.05 s, ERS gain 0.00 s, ATTACK 8 s slower).
- [ ] **Step 3:** In `GtDriving.update_car`, multiply `pace_mult` by `FUEL_PACE_MULT[car.fuel_mode]` and, while `deploying`, by `ERS_DEPLOY_PACE_MULT[car.ers_mode]`; replace the literal `8.5` at `:456` with `GtTypes.ERS_REGEN_BRAKE_PER_S`. Retune the ATTACK row so it is a short push (about 1.5 s per lap faster, very high wear) that does not reach 115 C within two laps.
- [ ] **Step 4:** Iterate the constants with `probe_balance.gd` `_rate_table()` until the test passes; keep the numbers in the report.
- [ ] **Step 5:** Run `-Filter mode_economy`, `-Filter deck`, `-Filter weather_and_ai`; update `GtForecast` text only if a threshold moved.
- [ ] **Step 6:** Commit: `feat(sim): working fuel push, ERS lap-time value and ATTACK push`.

---

### Task 7: One-stop balance (wear and fuel weight)

**Files:**
- Modify: `scripts/gt/gt_types.gd:23-24` (`COMPOUND_GRIP`, `COMPOUND_WEAR_PER_LAP`), `REFUEL_S_PER_KG`, `FUEL_WEIGHT_PACE_PER_KG`
- Test: `tests/test_one_stop_balance.gd`

**Interfaces:**
- Produces test helper `_plan_time(laps: int, first: int, second: int, stop_progress: float, start_fuel_kg: float) -> float` (solo race, `request_pit(0, second)` at the first sector line past `stop_progress`, returns `finished_at + classified penalty`).
- Consumes: Task 0 pit loss, Task 3 constants, Task 5 penalty.

- [ ] **Step 1: Write the failing test** `tests/test_one_stop_balance.gd`: for `laps` in 10 and 15, time five plans (SOFT then HARD at 35%, MEDIUM then MEDIUM at 45%, HARD then SOFT at 55%, an early plan at 25%, a late plan at 70%, each with its Crew Pick fuel) and assert (a) best to worst spread is at most 6 s, (b) the best plan at 10 laps differs from the best plan at 15 laps, (c) a no-stop plan with full tank costs more than the best one-stop plan by at least the penalty margin (never profitable), (d) a one-stop plan with a heavy start beats a light start by under 3 s and loses by under 3 s depending on length (neither fuel strategy dominates).
- [ ] **Step 2:** Run `-Filter one_stop_balance`; expected FAIL.
- [ ] **Step 3:** Tune `COMPOUND_WEAR_PER_LAP`, `COMPOUND_GRIP`, `REFUEL_S_PER_KG`, `FUEL_WEIGHT_PACE_PER_KG` using the probe until the test passes. Change wear only now that pit loss is measured (Task 0). Re-run `test_adaptive_tyre_strategy` and the rain probe cases; if rain behaviour shifts, revert the wear change for wet compounds.
- [ ] **Step 4:** Run `-Filter one_stop_balance`, `-Filter adaptive_tyre`, `-Filter weather`.
- [ ] **Step 5:** Commit: `feat(balance): one-stop plans balanced across 10 and 15 laps`.

---

### Task 8: Shared mode chooser for rivals and AUTO

**Files:**
- Modify: `scripts/gt/gt_strategy.gd` (new functions), `scripts/gt/gt_race.gd:1018` neighbourhood (call at sector lines)
- Test: `tests/test_rival_tactics.gd`

**Interfaces:**
- Produces: `GtStrategy.NEUTRAL_TACTIC: Dictionary` (`{"aggression": 0.5, "fuel_save": 0.5, "ers_greed": 0.5, "cover_gap_s": 2.0, "stop_bias": 0.0}`, used by AUTO); `static func tactic_profile(race_seed: int, team_id: int) -> Dictionary` (same keys, hash stream SALT `0x2B7E1516`: `aggression`, `fuel_save`, `ers_greed` in 0..1, `cover_gap_s` 1.0..3.0, `stop_bias` -1..1); `static func choose_modes(race: GtRace, car: GtCar, tp: Dictionary) -> Dictionary` (`{"pace": int, "fuel": int, "ers": int}` as `GtTypes.PaceMode` / `FuelMode` / `ErsMode` values); `GtRace.decide_modes(car: GtCar) -> void`; `GtRace.tactic_profile_of(team_id: int) -> Dictionary` (cached like `strategy_profile`).
- Consumes: `GtForecast.tyre_life_at_finish`, `fuel_margin_laps`, `ers_seconds`, `GtForecast.TYRE_WATCH_LIFE`.

- [ ] **Step 1: Write the failing test** `tests/test_rival_tactics.gd`: (a) parity: for the same car state, `choose_modes(race, car, NEUTRAL_TACTIC)` is what AUTO applies to a player car (call `race.tactic_mode = AUTO`, run to the next sector line, assert modes equal); (b) a 20-car 10-lap dry run shows at least 3 distinct (pace, fuel) pairs among rivals and no rival DNFs on fuel; (c) no car is placed on AGGRESSIVE or ATTACK while `tyre_life_at_finish` projects under `TYRE_DANGER_LIFE`; (d) MANUAL player cars are never changed by `decide_modes`; (e) two runs with the same seed give identical mode sequences.
- [ ] **Step 2:** Run `-Filter rival_tactics`; expected FAIL.
- [ ] **Step 3:** Implement `choose_modes` with these rules (the signature and tests do not fix them): pace goes to LIGHT when tyre life at the finish is under `TYRE_WATCH_LIFE`, to AGGRESSIVE when within 1.5 s behind a car, tyre life is healthy and `aggression > 0.5`, ATTACK only in the last two laps with margin and `aggression > 0.7`, otherwise STANDARD; fuel goes to CONSERVE when the margin to the finish (or to the stop still pending) is under 0.3 laps, to PUSH when in battle with margin above 1.0 laps and `fuel_save < 0.5`, otherwise STANDARD; ERS goes to OVERTAKE within 1.2 s behind a car with battery above 35%, to DEPLOY when the car behind is within 0.8 s, to HARVEST when battery is under 30% and not in battle, otherwise NEUTRAL; `ers_greed` shifts the battery thresholds by up to 10 points.
- [ ] **Step 4:** `GtRace.decide_modes(car)`: rivals call `set_pace_mode`/`set_fuel_mode`/`set_ers_mode` directly with the profile of their team; player cars in AUTO route each differing mode through `suggest_tactic` with `NEUTRAL_TACTIC` so the radio and cooldown behave as today; MANUAL player cars are skipped. Call it from `update_sector_and_speed_trap` next to `decide_strategy(car)`.
- [ ] **Step 5:** Run `-Filter rival_tactics` (PASS), `-Filter weather_and_ai`, `-Filter race_world`, `-Filter pit_wall`.
- [ ] **Step 6:** Commit: `feat(ai): shared mode chooser for rivals and AUTO`.

---

### Task 9: Rival stops, cover, and caution pits

**Files:**
- Modify: `scripts/gt/gt_strategy.gd` (`plan`, new `mandatory_call`, `should_cover`), `scripts/gt/gt_race.gd:885-904` (`decide_strategy`)
- Test: `tests/test_rival_stops.gd`

**Interfaces:**
- Produces: `GtStrategy.mandatory_call(race: GtRace, car: GtCar, tp: Dictionary) -> int` (compound to fit, or -1 for no call: required, not done, progress at or past `lerpf(0.30, 0.55, (tp["stop_bias"] + 1.0) / 2.0)`, or fuel under 1.5 laps, or progress at or past 0.72 as a failsafe before the window closes); `GtStrategy.should_cover(race: GtRace, car: GtCar, tp: Dictionary) -> bool` (the car directly behind within `tp["cover_gap_s"]` is in the pit this sector, the window is open, own tyre age is at least 3 laps); caution rule inside `decide_strategy`: under SC or VSC, a car whose mandatory stop is pending and window open pits with probability 0.7 from a hash roll (SALT `0x3C6EF372`, keyed by team and SC serial), and a car with wear above 0.45 always pits.
- Consumes: `GtRace.mandatory_stop_status`, `GtStrategy.best_fresh_compound`, Task 8 profile.

- [ ] **Step 1: Write the failing test** `tests/test_rival_stops.gd`: 15 lap dry run, 20 cars: every running rival completes exactly one stop, inside the window, with `mandatory_stop_done` and zero `penalty_owed_s`; the stops are spread (not all in the same lap: at least 4 distinct stop laps); under an SC raised at 40% progress, at least half of rivals with a pending stop pit during it; the cover case (car B directly behind A within 2 s pits, A has 4 laps on its tyres: A has `pit_request >= 0` within one sector); determinism: the same seed twice gives the same finishing order and the same per-car stop count (Review Focus); the pit queue suites below stay green.
- [ ] **Step 2:** Run `-Filter rival_stops`; expected FAIL.
- [ ] **Step 3:** Implement `mandatory_call` and `should_cover`; in `decide_strategy`, before the weather plan for non-player cars, apply the mandatory call, the cover rule and the caution rule; the player's mandatory suggestion goes through `suggest_tactic(car, PIT, compound, "BOX (MANDATORY)", text, info)` with the radio lines from Task 5 (AUTO executes it, COACH raises a card, MANUAL reports facts).
- [ ] **Step 4:** Run `-Filter rival_stops` (PASS), `-Filter pit_queue`, `-Filter pit_under`, `-Filter pit_lane`, `-Filter pit_stop_in_world`.
- [ ] **Step 5:** Commit: `feat(ai): rivals take the mandatory stop, cover stops and pit under caution`.

---

### Task 10: Team stats and Engineer rating

**Files:**
- Create: `scripts/gt/gt_team_stats.gd`
- Modify: `scripts/gt/gt_strategy.gd:45-53` (`profile`)
- Test: `tests/test_team_stats.gd`; update `tests/test_adaptive_tyre_strategy.gd` pins that assumed the per-seed hash profile

**Interfaces:**
- Produces `GtTeamStats` (`class_name GtTeamStats extends RefCounted`): `const ENGINEER: Array[float]` (13 entries, 0.0..1.0), `const CREW_SPEED: Array[float]` (13, 0.0..1.0), `const CREW_CONSISTENCY: Array[float]` (13, 0.0..1.0), `const RISK_BIAS: Array[float]` (13, within `GtStrategy.MAX_RISK_BIAS_PCT`), `const HERD: Array[float]` (13, 0.0..1.0), `static func engineer_profile(team_id: int) -> Dictionary` (same keys as `GtStrategy.profile`: `forecast_trust = lerpf(0.45, 1.0, ENGINEER[team])`, `read_noise = 1.0 - ENGINEER[team]`, `reaction_sectors = 2 - roundi(2.0 * ENGINEER[team])`, `risk_bias = RISK_BIAS[team]`, `herd = HERD[team]`).
- `GtStrategy.profile(race_seed, team_id)` keeps its signature and returns `GtTeamStats.engineer_profile(team_id)` (the seed argument no longer affects it; keep the parameter so callers stay valid).

- [ ] **Step 1: Write the failing test** `tests/test_team_stats.gd`: arrays have 13 entries in range; the engineer ratings are not all equal (spread of at least 0.4) and no team is the best at both Engineer and crew speed (ordering is a design choice, the test checks the spread only); `GtStrategy.profile(1, t) == GtStrategy.profile(999, t)` for every team (no seed dependence); `NEUTRAL_PROFILE` is unchanged; rain probe: a 10 lap `WET_DRYING` race shows the better Engineer teams reach the right tyre call at least as early on average than the worst (assert on the mean `gain_s`-bearing call lap across 3 seeds).
- [ ] **Step 2:** Run `-Filter team_stats`; expected FAIL.
- [ ] **Step 3:** Create `GtTeamStats` with a hand-picked spread for the 13 teams (a design call; document the values in the report) and route `GtStrategy.profile` through it.
- [ ] **Step 4:** Run `-Filter team_stats`, `-Filter adaptive_tyre`, `-Filter weather`; update the pinned expectations in `test_adaptive_tyre_strategy.gd` with a `# Fase 32: team Engineer rating` comment and re-check rain outcomes in the probe (Review Focus: rain must not regress).
- [ ] **Step 5:** Commit: `feat(strategy): visible per-team Engineer rating replaces per-seed profile`.

---

### Task 11: Pit crew stop time

**Files:**
- Modify: `scripts/gt/gt_team_stats.gd`, `scripts/gt/gt_driving.gd:1003`, `scripts/gt/gt_strategy.gd:155-158` (`pit_loss_s`)
- Test: `tests/test_pit_crew_stats.gd`

**Interfaces:**
- Produces: `GtTeamStats.pit_stop_time(team_id: int, race_seed: int, serial: int) -> float` (mean `lerpf(3.8, 2.6, CREW_SPEED[team])`; with chance `lerpf(0.25, 0.04, CREW_CONSISTENCY[team])` from a hash stream, SALT `0x1F83D9AB`, add 0.5 to 2.0 s; floor 2.0 s); `GtTeamStats.mean_stop_time(team_id: int) -> float` (the mean without error, for `pit_loss_s`).
- Consumes: `GtTypes.PIT_STOP_TIME` stays as the fallback default; `enter_pit_lane` replaces it with `pit_stop_time(car.team_id, race.race_seed, car.stops)` before adding damage and refuel time.

- [ ] **Step 1: Write the failing test** `tests/test_pit_crew_stats.gd`: for the fastest and the slowest crew, mean `pit_stop_time` over 200 serials differs by at least 0.8 s; every value is at least 2.0 s; same arguments give the same value; the most consistent crew has fewer error stops than the least consistent over 200 serials; `enter_pit_lane` produces `pit.duration >= pit_stop_time(...)`; `pit_loss_s` uses the team's mean (a fast crew has a smaller loss).
- [ ] **Step 2:** Run `-Filter pit_crew_stats`; expected FAIL.
- [ ] **Step 3:** Implement both functions; wire `enter_pit_lane`; make `pit_loss_s` take the car's team mean (add an optional `team_id: int = -1` parameter; -1 keeps the old constant; callers in `GtStrategy.plan` pass `car.team_id`).
- [ ] **Step 4:** Run `-Filter pit_crew_stats` (PASS), `-Filter pit`, `-Filter pitcrew` (visual suite for crew animation timing), `-Filter one_stop_balance`, `-Filter rival_stops`.
- [ ] **Step 5:** Re-tune `MANDATORY_PENALTY_FLOOR_S` against the slowest crew's loss (the penalty must still exceed 1.5 times the slowest loss).
- [ ] **Step 6:** Commit: `feat(pit): per-team crew speed and consistency in pit stop time`.

---

### Task 12: Regression, circuit sanity, native smoke, report

**Files:**
- Create: `executor-report/reports/FASE-32-TACTICAL-BALANCE-REPORT.md`, `executor-report/screenshots/phases/phase-32/*`
- Modify: `ROADMAP.md`, `todo.md`, `AGENTS.md` (command table and phase note, only if a command or rule changed)

**Interfaces:**
- Consumes: every earlier task; the probe from Task 0.

- [ ] **Step 1:** Run the full regression in foreground slices (Global Constraints list plus the new suites: `sc_catchup`, `vsc_escalation`, `fuel_plan`, `garage_fuel`, `mandatory_stop`, `mode_economy`, `one_stop_balance`, `rival_tactics`, `rival_stops`, `team_stats`, `pit_crew_stats`). Expected: 100% pass, 0 `[FAIL]`, no `SCRIPT ERROR`.
- [ ] **Step 2:** Circuit sanity: re-run the probe's `_sc_catchup()` and the one-stop balance on Paulistano (left pit) and Ardennes (long); confirm SC pickup times and that the penalty exceeds 1.5 times the measured pit loss on each; record the numbers. A circuit that fails gets a documented per-circuit note (constants derive from track length and `pit_layout`, no per-circuit hard-coding).
- [ ] **Step 3:** Native smoke (renderer): a 15 lap race with 20 cars, one forced crash at 30% progress, the player stopping inside the window; capture screenshots of the garage fuel row, the deck stop label, the VSC banner then the SC banner, and the podium; check the log for errors and orphan nodes after returning to the menu.
- [ ] **Step 4:** Write the FASE-32 report (baseline versus final numbers: SC pickup, rate table, 0 stops versus rival stop spread, penalty size, chosen constants and team stat values, the files not committed); update `ROADMAP.md`; tick every box in `todo.md`.
- [ ] **Step 5:** Commit report, roadmap and todo per path: `docs(fase-32): report, roadmap and regression result`; list uncommitted noise (`.uid`, `temp/`) in the final message to the developer.
