# Safety Car Smoothness and Baseline Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans task-by-task. User already authorized execution in this workspace; no approval pause or commit is required.

**Goal:** Fix observed SC shaking and close essential race-control baseline gaps, then update final report with fresh proof.

**Architecture:** Keep 20Hz sim and existing actor/world interfaces. SC tick snapshots feed the existing interpolation. Race control owns pickup/queue/withdrawal/restart decisions; per-car restart line is typed car state. Driving enforces no overtaking at its shared movement boundary. VFX maps meaningful lamp state to chassis LEDs.

**Tech Stack:** Godot4.7.2, typed GDScript, existing Python/PowerShell validation tools.

**Spec:** `docs/superpowers/specs/2026-10-25-safety-car-smoothness-and-baseline-correction-design.md`

## Global Constraints

- Preserve all unrelated user modifications. No new dependencies, asset overwrite, Curve3D changes, or driver changes.
- Keep deterministic tick sequence, time scales1–16, manual `world.step(delta)`, current screenshots as historical evidence.
- User's explicit execute authorization supersedes skill approval pauses. Use current workspace and final read-only review.

## Review Focus

1. Multiple sim ticks in one rendered frame: snapshots must represent the final two ticks, never two presentation frames.
2. SC merges mid-pack: pickup permission cannot authorize passing race cars or strand leader behind a nonleader.
3. New incident during withdrawal/after parking: no invalid green or lateral teleport.
4. Pit/retired/lapped cars and last-lap line crossings: no deadlock or accidental artificial restart.
5. Global GREEN with trailing cars before line: no attacks, bypass or contact-induced order reversal before each car's line.

## Task 1 — Tick interpolation and camera

Files: `scripts/gt/gt_race.gd`, `scripts/vfx/race_vfx.gd`, `scripts/world/race_weekend_world.gd`, `tests/test_safety_car_cinematic.gd`.

Interfaces: SC dictionary `prev_s`, `prev_lateral`; `RaceVfx.update(delta:float, alpha:float=1.0)` preserves direct test/capture compatibility.

- [x] Add failing sample tests at 30/60/120Hz, first-frame deployment, heading and camera relative motion; baseline probe showed80/120 stationary frames and1.27m jumps at60Hz.
- [x] Run focused suite and confirm expected failures.
- [x] Snapshot SC only at sim ticks; initialize spawn snapshots together. Pass world alpha and actual delta to VFX/actor; derive yaw from trajectory movement.
- [x] Run focused suite and motion probe; require no stationary-frame pattern during constant travel and bounded per-frame movement.

## Task 2 — Physical pickup, queue, lamps and withdrawal

Files: `scripts/gt/gt_race.gd`, `scripts/gt/gt_driving.gd`, `scripts/car/safety_car_chassis.gd`, `scripts/vfx/race_vfx.gd`, SC/dynamics tests.

Interfaces: SC state `picked_up`, `wave_by`, `finish_under_caution`; race helpers `restart_pending(car)`, `sc_may_pass(car)`; chassis additive AMBER_GREEN mode without changing existing enum values.

- [x] Write failing tests for physical pickup, allowed SC bypass only, queue and track-clear gating, lights OFF on in-lap, no SC teleport, late approach and renewal.
- [x] Implement slow collection, minimal pickup bypass signal and condition-based withdrawal. Short exhibitions minimum1 leader lap; retain duration as minimum incident hold.
- [x] Keep complete pit-trajectory milestones; announce in-lap only before full approach. GREEN requires completed peel-off and leader's restart line.
- [x] Update old green-on-inlap assertions to OFF (intentional semantic correction), preserving deployed strobe coverage.
- [x] Run SC, dynamics/VFX and GT sim suites.

## Task 3 — Individual restart and caution finish

Files: `scripts/gt/gt_car.gd`, `scripts/gt/gt_race.gd`, `scripts/gt/gt_driving.gd`, `tests/test_safety_car_cinematic.gd`.

Interfaces: `GtCar.sc_restart_line_s:float=-1.0`; `race.restart_pending(car)` extends `is_under_caution` beyond globalGREEN until each crossing.

- [x] Test leader past line / trailing car before line, high closing-speed no-pass, final-lap SC finish, late deployment, pit exclusion and deterministic seed.
- [x] Enforce caution progress behind a physical predecessor at shared longitudinal movement boundary; cap cannot move a car backwards. Preserve pit exceptions and normal green racing.
- [x] Leader controls rolling pace via existing pace settings; regular acceleration/braking remains bounded.
- [x] Latch finish-under-caution when required; no GREEN at chequered line. Clear per-car restart state on next deployment.
- [x] Run focused SC+GT suites, then all34 suites once per file using existing skip-legacy aggregation option.

## Task 4 — Native proof and final report

Files: `scratch/capture_safety_car_cinematic.gd`, `executor-report/reports/FASE-11-LANGKAH-5-SAFETY-CAR-PROCEDURE-REPORT.md`, `ROADMAP.md`; evidence under `executor-report/screenshots/safety_car/` with new revision filenames.

- [x] Read-only fresh reviewer checks final scoped diff and newly added tests; fix important findings with reproductions.
- [x] Native 1080p/High, 20cars, three laps through actual SC pickup/withdraw/restart OR regulation-correct caution finish, podium→HQ and0orphans. Separate forced fixtures are labeled.
- [x] Fresh exit/entry images, quantitative frame-motion probe and native motion observation/recording. Native performance measured after warmup without concurrent matrix; report any gate still open.
- [x] Update report with plan link, corrections to earlier claims, exact suite counts, regulatory adaptation, measured motion and performance, warnings and remaining limits. Roadmap reflects verified status.
- [x] `git diff --check`; leave reviewable workspace changes, no automatic commit/publish.
