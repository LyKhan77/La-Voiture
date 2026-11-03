# Exhibition circuit posters and selection responsiveness

Date: 2026-11-03
Status: Approved direction; execution authorized by user on 2026-11-03

## Selected provider and access check

User initially selected ElevenLabs `gpt-image-2.5-sunburst`. After the access failure below, user explicitly authorized the built-in Codex image generator. This supersedes both ElevenLabs and Genex. Backend model identity is not exposed and is not claimed to be Sunburst.

Read-only account check on 2026-11-03: subscription is active on the Starter tier. The image API returned HTTP 402 `paid_plan_required`: "This endpoint requires a Pro plan or above." Authentication works, but image generation is blocked by the subscription tier. No generation request was submitted and no generation credits were spent. Exact Sunburst pricing remains unverified. The sheet-vs-individual production decision should be revisited using ElevenLabs quotes once access is available; the Genex balance is unrelated to ElevenLabs billing.

Final production decision: ten separate built-in generations, one per circuit, to preserve environmental detail. User explicitly included Stoke Crown, Pacific Coast Corkscrew and Ardennes Valley Ring after identifying their existing images as screenshots. Preserve every previous artwork file.

## Intent

Give every calendar circuit a consistent generated environment poster and remove avoidable work from map selection. User chose generated circuit-only posters and requested improved selection performance.

## Approaches

- In-game screenshots: representative of playable geometry, but not the user's chosen approach.
- Separate generated environment posters: strong individual detail, but ten default generations cost 70 credits against the current 57-credit balance.
- One generated sheet with ten environment panels, cropped into individual posters: proposed production method to keep one art direction and fit current credits. Check actual generation quote and supported canvas first. Inspect every crop for separators, legibility and circuit identity before integration.

## Visual scope

- Cover all ten IDs in CircuitCalendarRegistry.TABLE, including circuits not yet playable.
- Landscape 16:9 panels: environment and recognizable circuit feature; no cars, drivers, lettering or baked UI. Shared cel-shaded manga linework, restrained screentone, consistent framing. Lighting and palette may differ by venue.
- Follow registry circuit notes and available project references. Posters communicate venue identity; they are not accurate layout diagrams. Existing spline map remains the source of layout information.
- Preserve all existing concept art. Add generated originals and runtime crops under assets/. Use local files only.
- Target runtime crops around 640x360, subject to supported generation resolution and visual review. Keep full-resolution source separately.

## Responsiveness scope

- Current poster path reads and decodes bytes synchronously on first selection. Replace this with imported runtime textures prepared before interactive selection; selection assigns an available texture only.
- Current TrackMap.load_circuit loads and instantiates circuit scenes to derive map data. Measure this path independently of poster decoding.
- Prepare reusable map display data offline if first-selection scene construction is a measured source of stalls. Reuse current sampling and map presentation; do not change track curves or simulation geometry.
- Preserve unavailable-circuit handling, stats, sectors, DRS, official turns, focus navigation and configuration behavior.
- Do not merely move a long stall into menu opening: measure cold entry and first/repeated selection separately. Keep preparation outside the active selection path; use existing loading flow where appropriate.
- Bound resident texture memory with small imported images and scene-owned references. No live 3D previews, new dependencies or per-frame image loading.

## Validation

- Measure before/after first and repeated selections across all ten circuits, including rapid input. Record frame times and entry latency separately; target no selection-triggered frame above 16.66 ms on the tested machine, with hardware and sampling limitations documented.
- Regression coverage must verify preview availability and preserve map/config behavior, including unavailable circuits. Run all headless suites through tools/run_tests.ps1.
- Native UI checks at 1080p with visual evidence; repository-required native race smoke and orphan checks before claiming full completion.
- Save official report and screenshots in executor-report/. Do not claim an RTX 3050 performance guarantee from other hardware.

## Implementation boundaries

Expected reach: circuit registry preview paths, setup menu texture preparation, TrackMap data preparation if measurements justify it, relevant tests, generated assets, offline tooling only if needed, task checklist and report. Use a dedicated fase-* branch. No changes to simulation, circuit curves, driver roster or old artwork.

## Approval boundary

User authorized proceeding with built-in generation and added three explicit circuit replacements. Execute the scoped implementation and verify before declaring completion.
