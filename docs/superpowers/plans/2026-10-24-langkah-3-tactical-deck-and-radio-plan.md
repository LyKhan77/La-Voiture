# IMPLEMENTATION PLAN: Langkah 3 — Tactical Pit Wall Deck Refinement & Two-Way Radio Comms

**Branch:** `main`  
**Engine:** Godot Engine 4.7.2 stable  
**Spec Reference:** [`docs/superpowers/specs/2026-10-24-langkah-3-tactical-deck-and-radio-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-24-langkah-3-tactical-deck-and-radio-design.md)  
**DoD:** 100% PASS on new test suite + all existing 27 test suites, 0 errors, clean working tree.

---

## Task Breakdown & Order of Execution

### Task 1: Core Pit Cancel Mechanics (`scripts/gt/gt_race.gd` & `scripts/world/race_weekend_world.gd`)
- [ ] Add `cancel_pit(car_id: int) -> bool` to `gt_race.gd`:
  * Resets `car.pit_request = -1` if `car.pit == null`.
  * Emits radio line: `"Stay out, stay out! Box call cancelled."` via `push_radio()`.
  * Returns true if successfully cancelled.
- [ ] Add `cancel_pit(car_id: int) -> bool` to `race_weekend_world.gd`:
  * Delegates to `race.cancel_pit(car_id)`.

### Task 2: Tactical Deck 2-State Pit Button & Desk Modes (`scripts/hud/tactical_deck.gd`)
- [ ] Refactor `box_button` behavior in `tactical_deck.gd`:
  * When `pit_request < 0`: Displays `"REQUEST BOX [B]"` with Neon Acid Lime styling.
  * When `pit_request >= 0` and `pit == null`: Displays `"CANCEL BOX [ESC]  //  %s"` with Crimson Hazard styling, and keeps button enabled (`disabled = false`).
  * Clicking `box_button` toggles: if `pit_request < 0` calls `press_box()`; if `pit_request >= 0` calls `cancel_box()`.
- [ ] Add `cancel_box() -> bool` method to `TacticalDeck`.
- [ ] Update `tactic_row` Desk modes:
  * Clarify `[MANUAL]` (100% player directive) vs `[AUTO]` (AI race engineer assisted).
  * Update info label with active desk mode description.
- [ ] Refine visual elements:
  * Slanted plate button styling on tyre compound selector (Soft, Medium, Hard, Inter, Wet).
  * Enhanced driver tabs with team color accents, position badge, and wear indicator.

### Task 3: Suggestion Card with 10-Second Burning Timer & Keybindings (`scripts/hud/race_hud.gd`)
- [ ] Add burning countdown timer node and logic to `_build_card()` in `race_hud.gd`:
  * Procedural bar with gradient/flame colors (`timer_bar`).
  * Countdown logic in `update(delta)`: decrements from 10.0s to 0.0s.
  * Remaining seconds label: `"10.0s"`.
  * If timer expires in `AUTO` mode: automatically triggers `accept_button.pressed.emit()`.
  * If timer expires in `MANUAL` mode: auto-dismisses card.
- [ ] Add new keyboard shortcuts to `handle_key` in `race_hud.gd`:
  * `KEY_B`: Triggers `deck.press_box()` when `car.pit_request < 0`.
  * `KEY_ESCAPE`: Triggers `deck.cancel_box()` if pit called, or dismisses suggestion card if active.
  * `KEY_ENTER`: Triggers `accept_button.pressed.emit()` if suggestion card is active.

### Task 4: Two-Way Radio Comms Dialogue Flow (`scripts/ui/anime_radio_cutin.gd` & `gt_race.gd`)
- [ ] Coordinate two-way radio sequences:
  * When driver calls out for tire wear cliff or snap oversteer (cut-in on left), schedule engineer response (cut-in on right) with 2.5s delay.
  * Ensure audio squelch and ducking seamlessly handle consecutive driver-engineer dialogue.
  * Verify soundwave equalizer bar animations pulse during voice playback.

### Task 5: Automated Test Suite & Verification (`tests/test_pit_deck_and_radio.gd`)
- [ ] Create `tests/test_pit_deck_and_radio.gd`:
  * Test `REQUEST BOX [B]` transitions to `CANCEL BOX [ESC]`.
  * Test clicking `CANCEL BOX` or pressing `KEY_ESCAPE` successfully cancels pit call without penalty.
  * Test `[MANUAL]` vs `[AUTO]` desk modes and auto-locking on 10s countdown expiry.
  * Test two-way radio triggers and cut-in dock layout.
- [ ] Run full headless test suite verification (`tests/test_*.gd`) to ensure 100% PASS with zero regression.

### Task 6: Native Visual Verification & Documentation
- [ ] Capture native in-engine screenshots of:
  * Tactical Deck with `REQUEST BOX [B]` state.
  * Tactical Deck with `CANCEL BOX [ESC]` hazard state.
  * Suggestion Card with active burning countdown bar.
  * Two-way radio dialogue in action.
- [ ] Compile executive report at `executor-report/reports/FASE-11-LANGKAH-3-TACTICAL-DECK-AND-RADIO-REPORT.md`.
- [ ] Update `ROADMAP.md` marking Langkah 3 as complete.
