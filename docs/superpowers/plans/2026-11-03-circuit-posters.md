# Circuit Posters Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ten consistent generated environment posters and responsive circuit selection.
**Architecture:** Imported small local poster textures and baked map display data keep image decoding and circuit scene construction out of selection. Retain existing map sampling/drawing and selection contracts.
**Tech Stack:** Godot 4.7.2, statically typed GDScript, built-in Codex image generator, existing Python/Pillow tooling if available.
**Spec:** docs/superpowers/specs/2026-11-03-circuit-posters-design.md

## Global constraints
- Preserve previous assets and circuit geometry. No dependencies or driver changes. User subsequently authorized commit, merge to main and push on 2026-11-03.
- Posters cover all ten calendar circuits, including unavailable layouts; unavailable rounds stay disabled for racing.
- Static local assets only. Record generator and prompts; no runtime generation credentials.
- Measure cold entry and first/repeated selections independently. Do not claim unmeasured hardware performance.

## Review focus
- Unavailable circuits clear old geometry and show their own posters.
- First selection must avoid heavy scene construction, not merely subsequent selections.
- Baked map geometry must match live source, including DRS, elevation, official turns.
- Imported poster paths must work in exports and preserve missing-art fallback.
- Scene changes must release menu references and leave no orphan nodes.

### Task 1: Establish baseline and regression
Files: temp/circuit_preview_probe.gd, tests/test_circuit_previews.gd.
- [x] Measure live menu creation and each first/repeated selection (entry 234 ms; map selection 1–1.6 s).
- [x] Add failing coverage for all ten imported, small, local posters and scene-free map selection.
- [x] Run test through tools/run_tests.ps1 and record RED (28 FAIL / 42 PASS).

### Task 2: Generate and install posters
Files: assets/ui/circuit_posters/<id>.png, assets/ui/circuit_posters/sources/, assets/ui/circuit_posters/provenance.json, scripts/core/circuit_calendar_registry.gd, scripts/ui/race_setup_menu.gd.
- [x] Generate ten independent 16:9 circuit environment posters using shared manga art direction; inspect each output.
- [x] Copy full originals locally and produce 640x360 runtime versions; keep all old artwork.
- [x] Point preview_image_path to imported textures; load resources before selection and make selection lookup-only.

### Task 3: Remove measured circuit scene work from map selection
Files: scripts/ui/track_map.gd, tools/bake_circuit_map_previews.gd, assets/ui/circuit_maps/previews.res, tests/test_circuit_previews.gd.
- [x] Reuse existing sampling to bake map display data offline when baseline confirms scene stalls.
- [x] Remove circuit scene preload/instantiation from runtime map selection; preload small map data and preserve drawing behavior.
- [x] Compare baked output to current source through explicit offline/live verification, retaining unavailable-layout behavior.
- [x] Run focused regression and record GREEN and post-change timing (84 PASS; native selection p50 3.171 ms).

### Task 4: Verify and report
Files: executor-report/reports/FASE-24-CIRCUIT-POSTERS-REPORT.md, executor-report/screenshots/circuit-posters/.
- [x] Import assets, run all headless suites in foreground slices via tools/run_tests.ps1 (105/105 PASS, 0 FAIL).
- [x] Capture native 1080p setup evidence, exercise rapid map navigation, check entry and frame timing.
- [x] Perform repository-required native race smoke / HQ / orphan verification (3 laps, 20/20 finished, 0 orphans); record limits honestly.
- [x] Review diff, update checklist and write report. Independent review found no concrete defects; source-equality regression added for maintenance risk. Actual arrow callback + click audio measured at 3.108 ms p50 / 5.017 ms max CPU; frame max 32.232 ms documented. Subsequent commit/merge/push explicitly authorized by user.
