# Fase 24 — Circuit Posters & Responsive Exhibition Selection

Date: 2026-11-03

Agent: Codex — Technical Artist / Gameplay Programmer

Branch: `fase-24-circuit-posters`

Status: Completed within the documented performance limits. 105/105 headless suites passed; native visual, actual arrow-input and three-lap race smoke checks passed. User approved commit, merge to main, push and removal of unnecessary session changes on 2026-11-03. Integration results are recorded on the local task board.

## Scope and outcome

All ten calendar circuits now have coherent generated environment-only posters, including the explicitly requested Stoke Crown, Pacific Coast Corkscrew and Ardennes Valley Ring. The four previously missing entries (Apex Ring, Eifel Forest, Paulistano, Kurogane) are also covered. Previous reference art is preserved without replacement or deletion.

Posters use the built-in Codex `image_gen` tool, explicitly authorized after ElevenLabs image API rejected the Starter subscription with `402 paid_plan_required`. The backend model is not exposed and is not identified as Sunburst. No ElevenLabs generation was submitted.

## Assets and provenance

- Runtime: `assets/ui/circuit_posters/<circuit_id>.png`, ten RGB 640x360 PNG files.
- Runtime PNG disk total: 5,015,749 bytes (4.78 MiB); ten full originals total 34,768,818 bytes (33.16 MiB), excluded from Godot import.
- Full generated originals: `assets/ui/circuit_posters/sources/`, protected from Godot import by its own `.gdignore`.
- Generator and complete prompt per circuit: `assets/ui/circuit_posters/provenance.json`.
- Rebuild runtime crops: `godot --headless --path . -s tools/prepare_circuit_posters.gd`.
- Imported catalog: `assets/ui/circuit_posters/catalog.tres`; resource dependencies are discoverable by Godot exports.
- Nominal uncompressed texture budget for all ten: 6.59 MiB as RGB8, 8.79 MiB if represented as RGBA8; actual driver allocation was not isolated.

Shared direction: landscape anime motorsport travel illustrations, decisive manga contour ink, cel shadows and halftone, circuit environment/landmark dominant, no road cars, drivers, lettering or logos. Distinct venue palette and lighting are intentional. Posters are concept illustrations, not accurate track diagrams; the adjacent spline map remains authoritative.

## Root cause and implementation

The old setup path decoded reference images synchronously on first selection. More significantly, `TrackMapView._load_track()` loaded and instantiated each circuit scene, triggering track, pit, terrain, trees and environment construction every time the selection changed. Even repeat selections between circuits rebuilt these scenes.

- Registry preview paths now target valid, imported runtime PNG textures.
- The menu preloads a small poster catalog. `_preview_texture()` is a dictionary lookup, with the existing missing-art fallback retained. No per-selection disk reads, decoding or image uploads from CPU-side images.
- Map sampling still derives from the actual circuit source, but runs offline using `tools/bake_circuit_map_previews.gd`. Runtime reads the resulting `assets/ui/circuit_maps/previews.res` (197,649 bytes).
- Binary resource format preserves float values exactly; the initial text-resource experiment was removed because serialization rounded the sampled coordinates.
- Existing numbered corners, sectors, DRS zones, direction and elevation are retained. All three unavailable circuits still clear geometry and disable Continue, while displaying their own poster.
- Rebake after a circuit layout change. `godot --headless --path . -s tools/bake_circuit_map_previews.gd -- --verify` compares all ten entries to live source; this equality check is also part of the new ordinary headless regression suite.
- No simulation, car, driver, circuit curve or gameplay-rule changes. No new dependencies. User subsequently authorized committing this verified change, merging to main and pushing.

## Measurements

Baseline headless probe: menu creation including scene load 233.757 ms. First selection of playable non-default circuits: Neo-Wangan 1058.588 ms, Brianza 1108.048 ms, Monte Azure 1228.895 ms, Ardennes 1590.802 ms, Stoke Crown 1281.878 ms, Pacific Coast 1511.888 ms. Repeat switching remained slow (582–1483 ms in this run). This probe was run under the filesystem sandbox and logged certificate/log-directory access errors; its timings establish the magnitude of scene-construction work, not a controlled hardware benchmark.

Post-change headless probe: first/repeated selections 2.708–4.896 ms, 0 orphan nodes. The sample using the initial text bake recorded 264.344 ms entry; the shipped binary bake is covered by native measurement below.

Native: Godot 4.7.2, Direct3D 12, Forward+, NVIDIA GeForce RTX 3050 Laptop GPU, HIGH, 1920x1080.

| Measurement | Public selection API | Actual arrows + UI click audio |
|---|---:|---:|
| Menu load + creation | 231.968 ms | 213.642 ms |
| First selection CPU time, ten circuits | 2.319–3.282 ms | 2.382–3.658 ms |
| 200 consecutive switches, CPU p50 / p95 / max | 3.171 / 4.572 / 6.380 ms | 3.108 / 3.448 / 5.017 ms |
| Rendered frame interval p50 / p95 / max | 16.199 / 23.341 / 29.088 ms | 16.259 / 22.655 / 32.232 ms |
| Orphan nodes after setup → HQ → teardown | 0 | 0 |

Each stress run changes the selected circuit every rendered frame, including the first display of each non-default poster. The final run invokes the arrow callback including UI click audio, rather than only the public selection API. It removes the prior second-long selection freezes, but does not prove a strict 16.66 ms frame ceiling: p95 and maximum exceeded that budget. Startup/preparation time is reported separately, not hidden in selection figures. Measurements use fresh game processes; OS file caches were not flushed.

## Verification

- RED: new preview suite initially produced 28 FAIL / 42 PASS for missing imported posters and live scene construction.
- GREEN: focused preview runner passed after implementation, then passed again with source-equality coverage (84 PASS, 0 FAIL, 9 seconds).
- Offline binary bake verification: 10/10 exact equality, including seven live layouts and three empty unavailable entries.
- Read-only independent code review: no concrete findings. Review's bake-invalidation maintenance concern was addressed by adding source equality to the normal test suite.
- Full suite via `tools/run_tests.ps1`: **105/105 suites PASS, 0 failures**. Every slice exited 0; runner requires `[PASS]` and rejects `[FAIL]`, `SCRIPT ERROR` and `Parse Error`.

| Slice | Suites | Seconds | Failures |
|---|---:|---:|---:|
| 0–19 | 20 | 534 | 0 |
| 20–39 | 20 | 145 | 0 |
| 40–59 | 20 | 303 | 0 |
| 60–69 | 10 | 449 | 0 |
| 70–79 | 10 | 526 | 0 |
| 80–92 | 13 | 253 | 0 |
| 93–104 | 12 | 129 | 0 |
- Native race smoke: Pacific Coast Corkscrew, HIGH, 1920x1080, three laps, 20/20 cars finished, simulation time 231.85 seconds. Minimum / median / p5 of the 180-frame 1x FPS sample after 360 warm-up frames were all 60 FPS. Completion was accelerated to 8x after the sample and camera captures; the ordinary podium transition was held only after the chequered flag so all finishers could be counted. Returned to HQ and teardown reported 0 orphan nodes. Six 1080p race camera captures and a race-to-HQ capture are saved. This sample does not guarantee every individual race frame met 16.66 ms.

## Visual evidence and limits

Evidence: `executor-report/screenshots/circuit-posters/` contains ten 1920x1080 setup views, a ten-poster contact sheet, HQ return capture, six race camera views and a race-to-HQ capture. Final setup captures were refreshed during the actual-arrow run. The three explicitly named circuits were inspected in the generated outputs and the native setup display. All generated illustrations were inspected for coherent style, environmental subject, absence of cars/text and recognizable venue features.

The first temporary screenshot script used `Image.load_from_file` to assemble its offline contact sheet and logged export warnings; gameplay does not use that path, and the probe was corrected to obtain imported texture images instead. The initial native teardown also logged seven texture RIDs, four ObjectDB instances and one resource in use at exit. The final actual-arrow run and native race smoke emitted only the seven-texture shutdown warning, without the initial export/ObjectDB/resource-in-use diagnostics. The seven-texture warning was already reproduced by the unchanged main menu in the prior Fase 23 report; zero orphan nodes is measured separately and does not imply zero resource warnings.

Packaged export, other GPUs and storm-race frame locking are not verified by the UI measurements above. Source resources are local and export-discoverable, but no export build has been claimed.
