# TASK HANDOFF: Langkah 3 — Tactical Pit Wall Deck Refinement & Two-Way Radio Comms (In-Game HUD)

**Target Branch:** `main`  
**Target Engine:** Godot Engine 4.7.2 stable (`Godot_v4.7.2-stable_win64_console.exe`)  
**Role:** Senior UI/UX Engineer & Game Systems Programmer  
**Reference Documents:**
* **Spesifikasi Desain:** [`docs/superpowers/specs/2026-10-24-langkah-3-tactical-deck-and-radio-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-24-langkah-3-tactical-deck-and-radio-design.md)
* **Rencana Implementasi:** [`docs/superpowers/plans/2026-10-24-langkah-3-tactical-deck-and-radio-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-24-langkah-3-tactical-deck-and-radio-plan.md)
* **Approved Interactive Preview HTML:** [`temp/brainstorm/content/ui_step_3_hud_preview.html`](file:///D:/Occupation/Porto/genex/La_Voiture/temp/brainstorm/content/ui_step_3_hud_preview.html) (Live di `http://localhost:61716`)
* **Approved Visual Reference Capture:** [`hud_preview_capture.png`](file:///C:/Users/Lee/.gemini/antigravity-cli/brain/811c31b7-0204-457f-88fa-74a528b6c84e/hud_preview_capture.png)
* **Pedoman Resmi Arsitektur & Rules:** [`AGENTS.md`](file:///D:/Occupation/Porto/genex/La_Voiture/AGENTS.md)

---

## 1. Context & Catatan Kritis Pengguna (Must-Read)

Pengguna secara spesifik telah **menyetujui konsep desain visual & interaksi** yang dimodelkan pada `temp/brainstorm/content/ui_step_3_hud_preview.html`.

> [!IMPORTANT]
> **ATURAN TATA LETAK MUTLAK (LAYOUT LOCK):**  
> Pengguna secara tegas menginstruksikan: **"JANGAN MERUBAH POSISI LAYOUT UI NYA. TUJUAN REFINING HANYA UNTUK MENGUBAH UNSUR ELEMENT HUD/MODAL/NODE UI NYA."**  
> Seluruh koordinat panggung 1920×1080 (posisi, ukuran, dan jangkar layout) dari setiap modul HUD tidak boleh diubah:
> * Tactical Deck: `pos (16, 880)`, `size (1888, 140)` [Open] / `size (1888, 44)` [Collapsed]
> * Suggestion Card: `pos (656, 690)`, `size (608, 136..156)`
> * Top Ribbon Zone A: `pos (16, 12)`, `size (1888, 60)`
> * Timing Tower: `pos (16, 88)`, `size (320, 780)`
> * Telemetry Drawer: `pos (1598, 372)`, `size (312, 496)`

---

## 2. Rincian Ruang Lingkup Tugas (Scope of Work)

### A. Core Pit Cancel Mechanics
* **Files:** [`scripts/gt/gt_race.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_race.gd) & [`scripts/world/race_weekend_world.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/race_weekend_world.gd)
1. Tambahkan `cancel_pit(car_id: int) -> bool`:
   - Batalkan panggilan jika `car.pit == null` dan `car.pit_request >= 0`.
   - Kembalikan `car.pit_request = -1`.
   - Kirim transmisi radio pit wall: `"Stay out, stay out! Box call cancelled."` via `push_radio()`.
   - Pastikan pacing mobil kembali ke target normal tanpa penalti.

### B. Actionable 2-State Pit Button & Desk Modes
* **File:** [`scripts/hud/tactical_deck.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/hud/tactical_deck.gd)
1. **Dynamic 2-State Button:**
   - State 1: `REQUEST BOX [B]` (Neon Acid Lime `#D8FF00`, teks hitam tebal).
   - State 2: Saat `car.pit_request >= 0`, tombol **JANGAN dinonaktifkan** (`disabled = false`). Tombol berubah menjadi **`CANCEL BOX [ESC]  //  <COMPOUND>`** dengan warna *Anime Crimson* dan pola garis hazard, berkedip denyut peringatan.
   - Mengklik tombol saat State 2 memanggil `cancel_box()`.
2. **2 Desk Modes:**
   - `[MANUAL]` (Strategy Director / Default): Pemain memegang kontrol 100%.
   - `[AUTO]` (AI Race Engineer Assisted): AI otomatis mengunci keputusan jika timer habis.
3. **Street-Manga Styling:**
   - Styling pelat miring, ring warna compound ban yang otentik, driver tab badge dengan bar wear.

### C. Suggestion Card with 10-Second Burning Timer & Keybindings
* **File:** [`scripts/hud/race_hud.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/hud/race_hud.gd)
1. **Burning Countdown Bar:**
   - Tambahkan bar api 10 detik di bagian atas modal `SuggestionCard` (`_build_card()`).
   - Bar menyusut dari 10.0s ke 0.0s dengan gradasi menyala oranye-ke-merah.
   - Label waktu tersisa: `"10.0s"` $\rightarrow$ `"00.0s"`.
   - Di mode `AUTO`: Saat 0.0s, otomatis `accept_button.pressed.emit()`.
   - Di mode `MANUAL`: Saat 0.0s, kartu dismiss otomatis.
2. **Keybindings:**
   - `[B]`: Request Box
   - `[ESC]`: Cancel Box (jika pit called) atau Dismiss suggestion card
   - `[ENTER]`: Accept suggestion card

### D. Two-Way Radio Comms Flow
* **File:** [`scripts/ui/anime_radio_cutin.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/ui/anime_radio_cutin.gd) & [`scripts/gt/gt_race.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_race.gd)
1. Koordinasi panggilan radio dua arah saat grip cliff / snap oversteer / hujan lebat:
   - Driver panggil duluan di cut-in kiri (Lime).
   - Pit Wall membalas 2.5 detik kemudian di cut-in kanan (Cyan).
   - Squelch audio & ducking berjalan mulus tanpa tabrakan audio.

### E. Quality Gate & Definition of Done
1. Seluruh 27 test suite yang sudah ada tetap **100% PASS (0 FAIL)**.
2. Buat suite baru `tests/test_pit_deck_and_radio.gd` (memverifikasi toggle box, cancel box, desk mode, timer bar, dan radio).
3. Dokumentasikan di `executor-report/reports/FASE-11-LANGKAH-3-TACTICAL-DECK-AND-RADIO-REPORT.md`.
4. Update `ROADMAP.md`.
