# Stoke Crown Implementation Plan

> **For agentic workers:** Execute natively task-by-task; approved production handoff defines design. Track verified progress in todo.md.

**Goal:** Integrate approved Stoke Crown Route 2 as playable championship round 6.
**Architecture:** Dedicated circuit builder, CircuitEnvironment and CircuitPitComplex subclasses; reusable production corridor/paddock/sky kits. Translate approved sandbox, preserve stations and visual refinements.
**Tech Stack:** Godot 4.7.2, typed GDScript, existing GLB assets; no new dependencies.
**Spec:** `D:/Occupation/Porto/genex/mapgen-circuit/builds/stoke_crown/production-handoff.md`.

## Constraints and review focus

- Phase 0 precedes production: use core/patch.gd for frozen geometry; update manifest hashes; scope external writes to designs/stoke_crown/final and builds/stoke_crown.
- 5200 m, 18 turns, clockwise, June GBR GP; preserve calendar, elevation, five landmark stations, tower s=232/lateral32, flyover lateral0.
- No shared driving/racing-line semantics changes or legacy kink cap changes.
- Reuse kit APIs; all repeated geometry instanced; trees shadow OFF; no placeholders.
- Review sim lateral coordinates against actual sandbox pavement (handoff values conflict with production API; clarification pending).
- Test seam, all turn regions, road/pit terrain support, service/merge, simultaneous pit queue, team reseating, day/night, resource cleanup.

## Task 1 — Phase 0

- [x] Probe original: reproduce kinks s3275 and s4322.
- [x] Probe radius100 at vertices12/15 through ConceptPatch: zero kinks; max station displacement0.092m; ribbon5200.134m.
- [x] Back up affected source files under builds/stoke_crown/phase0_backup; patch radii and pit pitch20; update Crown Wing span205, service bay station130 and prose.
- [x] Re-freeze manifest using core/hash.gd; rebuild Crown Wing; refresh existing scene ribbon without regenerating scaffold.
- [x] Verify test_pit_drive25/25, probe_phase18 zero kinks, smoke_env, capture_gate.

## Task 2 — Production geometry and environment

Create scripts/world/circuits/stoke_crown/{stoke_crown_circuit_builder,stoke_crown_layout,stoke_crown_environment,stoke_crown_terrain,...}.gd; scenes/race_world/circuits/stoke_crown/stoke_crown_circuit.tscn; assets/tracks/stoke_crown/models/*.glb and frozen data.

- [x] Add failing Stoke Crown geometry/environment acceptance test.
- [x] Translate compiler alignment to multi-point curve and expose production builder metadata (turns/sectors/elevation).
- [x] Translate terrain/strip/landmarks and approved LOD; wire production corridor/groove/flag panels/sky, wind and leaderboard APIs.
- [x] Preserve grounded slabs and exclusions; inspect all five model placements.

## Task 3 — Production pit and registry

Create dedicated stoke_crown_pit_complex.gd and pit scene; update scripts/core/circuit_calendar_registry.gd scene path.

- [x] Add pit-flood regression based on existing circuit test helper; register circuit in five required contract suites plus any automatically discovered hardcoded lists.
- [x] Implement sim_layout and matching pavement, ten boxes/garages20m pitch, team identities, production standby crew/choreography/signage/transporter contracts.
- [x] Test geometry and contracts green without special circuit branches in RaceWeekendWorld or GtDriving.

## Task 4 — Release verification

- [x] Run racing-line and targeted tests, then full tools/run_tests.ps1 in bounded foreground slices.
- [x] Native smoke_race3laps20cars and smoke_pit_race six-car flood; 0 orphan.
- [x] Capture racing-line plan/worker/plot and six views DAY/SUNSET/NIGHT plus pit closeup, inspect screenshots.
- [x] Native draw-call profiling, triangle count, FPS and VRAM evidence; record actual results/limits.
- [x] Write executor-report/reports/FASE-21-STOKE-CROWN-REPORT.md, update verified checklist, review diff. Developer approved commit–merge–push on2026-11-02 after deferring global performance gates.

## Initiate Prompt

Execute this plan natively on fase-21-stoke-crown. Read linked handoff, complete Phase0 verification before production, preserve approved visual design, resolve pit-coordinate discrepancy with developer, then run all release gates and report measured results.

## Execution result (2026-11-02)

Implementation and verification actions above executed natively. 96/96 headless suites pass after two obsolete UI fixtures were updated. Map budget317054triangles/141staticdrawcalls,0kinks,0floatingroad/apron; storm/night20/20finish,podium→HQ,0orphan. Independent review fixes verified. Developer approved commit–merge–push on2026-11-02; final speed-change regression96/96PASS; integration authorized.

- [ ] Close global performance gate: isolated busy-pit High1080p20cars/6pit averages64.73FPS but p95=20.175ms (limit16.6667ms); totalframe180drawcalls also not met. Developer explicitly approved deferring these two gates on2026-11-02; do not label the performance gates PASS. Evidence and limits: executor-report/reports/FASE-21-STOKE-CROWN-REPORT.md.

## Final scope amendment (2026-11-02)

Remove16× player fast-forward; keep1×/2×/4×/8× across weekend HUD, keyboard and pit wall/legacy controls. Cap both simulation APIs at8×. Update callers/fixtures/docs, demonstrate RED→GREEN and native controls, rerun all96suites, then commit–merge–push to main as authorized. Preserve unrelated scratchUID files and source mapgen repo changes outside this commit.

Final amended scope verified: HUD/keyboard/dashboard/API1/2/4/8×; RED→GREEN; full96/96suitePASS; native8×20/20finish,10stops,podium→HQ,0orphan. Independent review clean. Global performance gates remain explicitly deferred by developer.
