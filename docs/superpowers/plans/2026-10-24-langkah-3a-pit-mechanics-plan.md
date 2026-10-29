# Langkah 3a — Pit Mechanics (cancel box, mode DESK MANUAL/AUTO, bar api, keybind) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pemain bisa membatalkan panggilan box tanpa penalti, desk hanya punya MANUAL dan AUTO (HYBRID dihapus), kartu saran punya bar api 10 detik yang menutup (MANUAL) atau mengeksekusi (AUTO) saran, dan tombol `B` / `ESC` / `ENTER` bekerja.

**Architecture:** Timer jendela saran hidup **di sim** (`GtRace`, waktu balapan) supaya deterministik per `race_seed` dan tetap jalan di test headless; HUD hanya membaca sisa waktu untuk menggambar bar. Tombol BOX di deck menjadi dua-state (request ↔ cancel). Tidak ada perubahan posisi/ukuran kotak HUD.

**Tech Stack:** Godot 4.7.2 stable, GDScript 2.0 (static typing wajib), test headless `SceneTree` (`godot --headless --path . -s res://tests/<nama>.gd`).

**Spec:** `docs/superpowers/specs/2026-10-24-langkah-3-hud-redesign-v2-design.md` (§4.5, §6 dan tabel mode). Spec lama `2026-10-24-langkah-3-tactical-deck-and-radio-design.md` §2A–2C dan §2E memberi detail state tombol dan keybind; bila bertentangan, spec v2 menang.

## Global Constraints

- Layout lock: deck `pos (16, 880)` `size (1888, 140)` open / `(1888, 44)` collapsed; suggestion card `pos (656, 690)` `size (608, 136)`; seluruh kotak HUD lain tidak berubah. 3a hanya mengisi ulang isi node, tidak memindahkan.
- Static typing wajib; tanpa dependensi baru; semua draw/animasi lewat node yang sudah dipakai deck dan kartu.
- Sim deterministik: seed sama ⇒ hasil sama. Tidak ada `Time.get_ticks_msec()`, `randf()`, atau waktu dinding di logika sim; jendela saran dihitung dari `GtRace.time`.
- Mode desk: `GtTypes.TacticMode { MANUAL, AUTO }` (MANUAL = 0 default, AUTO = 1). Tidak ada HYBRID di kode, test, atau PRD setelah Task 1 dan 5.
- Teks tombol BOX (persis): `REQUEST BOX [B]`, `CANCEL BOX [ESC]  //  <COMPOUND>` (dua spasi sekitar `//`, `<COMPOUND>` = `GtTypes.COMPOUND_NAME[car.pit_request]`), `IN THE PIT LANE`, `RETIRED`, `CHEQUERED`.
- Radio pembatalan (persis): `Stay out, stay out! Box call cancelled.`
- Jendela saran: `GtRace.SUGGESTION_WINDOW_S = 10.0` detik waktu balapan. Label sisa waktu `"%04.1fs"` (`10.0s` → `03.2s` → `00.0s`); di bawah 3.0 s kartu dan label berkedip crimson.
- Seluruh test lama (27 suite) tetap 100% PASS. Test yang menyebut HYBRID ditulis ulang di Task 1 dan 3 supaya tetap hijau.
- Commit: akhiri pesan dengan baris `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Hanya `git add` file yang disebut di tiap task (ada file untracked milik orang lain di repo: jangan `git add -A`).

## Review Focus

Input yang tidak disebut spec tapi akan menimpa pemain, paling mungkin dulu; tiap baris punya test di task pemilik kodenya:

1. Membatalkan saat mobil sudah di jalur pit (`car.pit != null`) atau tanpa panggilan aktif: `cancel_pit` mengembalikan `false`, tidak mengubah state, tidak mengirim radio. (Task 2)
2. `ESC` saat kartu saran tampil **dan** box sudah dipanggil: ESC pertama menutup kartu, ESC kedua membatalkan box; ESC tanpa keduanya tidak dikonsumsi HUD (jatuh ke `timing_tower.gd` yang memakai `ui_cancel`). (Task 4)
3. AUTO: pemain menerima saran di detik 9.9 lalu bar habis: tidak ada eksekusi ganda, dan bila mobil sudah punya `pit_request`/`pit` saat bar habis, saran hanya ditutup. (Task 1)
4. Saran baru menggantikan saran lama di tengah jendela: bar dan label mulai dari 10.0 s lagi, tidak menampilkan sisa waktu saran lama. (Task 1, 4)
5. Pembatalan tidak memicu saran box yang sama seketika: cooldown saran PIT mobil itu ≥ 30 s setelah `cancel_pit`. (Task 2)
6. Time scale 4x–16x memendekkan jendela di dunia nyata (10 detik waktu balapan). Dicatat di laporan; tidak diubah di 3a. (Task 5)

## File Structure

- Modify `scripts/gt/gt_types.gd:12` — enum `TacticMode`.
- Modify `scripts/gt/gt_race.gd` — default mode, `cancel_pit`, jendela saran, ganti nama `_check_hybrid_tactics`, `decide_strategy` untuk pemain.
- Modify `scripts/world/weekend/race_weekend_world.gd` — `cancel_pit` pembungkus.
- Modify `scripts/hud/tactical_deck.gd` — desk dua opsi, tombol BOX dua-state, label status desk, `cancel_box()`.
- Modify `scripts/hud/race_hud.gd` — bar api, label waktu, keybind B/ESC/ENTER.
- Create `tests/test_pit_deck_and_radio.gd` — suite baru (radio dua arah ditambahkan di sub-langkah 3e).
- Modify `tests/test_gt_sim.gd` (`_test_tactics`) dan `tests/test_race_hud.gd` — buang referensi HYBRID/teks lama.
- Modify `PRD/00-MASTER-OVERVIEW.md:88`, `PRD/02-UI-UX-TOPOLOGY.md:131,134-135`, `PRD/07-DATA-TESTING-PERFORMANCE.md:88`, `ROADMAP.md`.
- Create `executor-report/reports/FASE-11-LANGKAH-3A-PIT-MECHANICS-REPORT.md` dan screenshot di `executor-report/screenshots/phases/`.

---

### Task 1: Desk MANUAL/AUTO tanpa HYBRID + jendela saran 10 detik di sim

**Files:**
- Create: `tests/test_pit_deck_and_radio.gd`
- Modify: `scripts/gt/gt_types.gd:12`, `scripts/gt/gt_race.gd` (baris 31, 217-218, 431-444, 477-508, 511 dan konstanta di blok const atas)
- Modify: `tests/test_gt_sim.gd:643-668` (`_test_tactics`)

**Interfaces:**
- Produces: `GtTypes.TacticMode { MANUAL, AUTO }`; `GtRace.SUGGESTION_WINDOW_S: float = 10.0`; `GtRace.suggestion_remaining() -> float` (detik waktu balapan tersisa, `0.0` bila tak ada saran); kunci baru `"deadline": float` di `latest_suggestion`; `GtRace._check_advisor_tactics() -> void` (nama baru, dipanggil **di setiap mode** tiap tick); `GtRace._expire_suggestion() -> void` (dipanggil di akhir `step()` sebelum `time += dt`).
- Consumes: `GtRace.suggest_tactic`, `accept_suggestion`, `dismiss_suggestion`, `request_pit` yang sudah ada.

- [ ] **Step 1: Buat kerangka suite baru dan tulis test gagal**

  Salin harness dari `tests/test_race_hud.gd:1-65` (extends `SceneTree`, `check()`, `_run()` yang memuat `race_weekend_world.tscn`, masuk `GREEN_RACING`, `race.step_ticks(200)`, `quit(0 if failures == 0 else 1)`) ke `tests/test_pit_deck_and_radio.gd`. Tulis fungsi `_test_desk_modes_and_suggestion_window()` dengan `mine[0]` sebagai mobil uji, `race.incidents_enabled = false`, dan assertion (nama pesan deskriptif):
  - `GtTypes.TacticMode.size() == 2` dan `race.tactic_mode == GtTypes.TacticMode.MANUAL` pada race baru: "desk: only MANUAL and AUTO exist and MANUAL is the default".
  - MANUAL: `race.suggest_tactic(car, PIT, HARD, "BOX FOR HARD", "x")` → `is_equal_approx(race.suggestion_remaining(), 10.0)`; `race.time += 5.0` → `absf(race.suggestion_remaining() - 5.0) < 0.001`; `race.time += 5.1; race.step()` → `race.latest_suggestion.is_empty()` dan `car.pit_request < 0`: "suggestion: in MANUAL the card closes at 0.0 s and nothing is executed".
  - AUTO: `race.set_tactic_mode(AUTO)`, suggest lagi (setelah mengosongkan `race._suggestion_cooldowns`), `race.time += 10.1; race.step()` → `car.pit_request == GtTypes.Compound.HARD` dan `latest_suggestion.is_empty()`: "suggestion: in AUTO the card locks and executes at 0.0 s".
  - AUTO tapi mobil sudah `pit_request >= 0` saat bar habis: `latest_suggestion.is_empty()` dan `car.pit_request` tidak berubah (tetap nilai awal): "suggestion: AUTO never double-calls a car already boxing".
  - Saran baru di tengah jendela: suggest A, `race.time += 6.0`, suggest B (tipe berbeda) → `suggestion_remaining() > 9.9`: "suggestion: a replacement card restarts the 10 s window".
  - Pemain menerima di detik 9.9: `race.time += 9.9; race.accept_suggestion(); race.time += 0.3; race.step()` → `car.pit_request` hanya terset sekali (nilai = compound saran) dan tidak ada radio "Box this lap" kedua (`race.radio_history` berisi tepat satu entri engineer "Box this lap" sejak saran).

- [ ] **Step 2: Jalankan dan pastikan gagal**

  Run: `godot --headless --path . -s res://tests/test_pit_deck_and_radio.gd`
  Expected: FAIL (`TacticMode.size()` = 3, `suggestion_remaining` belum ada, default masih HYBRID).

- [ ] **Step 3: Hapus HYBRID dari enum dan ubah default**

  `gt_types.gd:12` → `enum TacticMode { MANUAL, AUTO }`. `gt_race.gd:31` → `var tactic_mode: int = GtTypes.TacticMode.MANUAL`. Perbarui komentar kelas di `gt_race.gd:7` ("a hybrid tactic desk" → "a manual / auto tactic desk").

- [ ] **Step 4: Implementasikan jendela saran di `GtRace`**

  Tambah `const SUGGESTION_WINDOW_S: float = 10.0`. Di `suggest_tactic`, isi `"deadline": time + SUGGESTION_WINDOW_S` pada dictionary `latest_suggestion`. `func suggestion_remaining() -> float` mengembalikan `maxf(0.0, float(latest_suggestion["deadline"]) - time)` atau `0.0` bila kosong. `func _expire_suggestion() -> void`: bila `latest_suggestion` tidak kosong dan `time >= deadline`: jika `tactic_mode == AUTO` dan saran bertipe PIT dan mobilnya masih `pit == null and pit_request < 0` → `accept_suggestion()`; AUTO dengan tipe PACE/FUEL/ERS → `accept_suggestion()`; selain itu (MANUAL, atau AUTO tapi mobil sudah boxing) → `dismiss_suggestion()`. Panggil `_expire_suggestion()` di `step()` menggantikan blok `if tactic_mode == HYBRID:` (baris 217-218), setelah `_check_advisor_tactics()`.

- [ ] **Step 5: Ubah `_check_hybrid_tactics` dan `decide_strategy`**

  Ganti nama menjadi `_check_advisor_tactics()` dan panggil **tanpa syarat mode** tiap tick (isi tidak berubah). Di `decide_strategy`: hapus `if is_player and tactic_mode == MANUAL: return` (baris 484-485); ganti cabang baris 504 menjadi `if is_player:` → `suggest_tactic(...)` (berlaku MANUAL dan AUTO); cabang `else` (mobil AI) tetap `car.pit_request = target`.

- [ ] **Step 6: Tulis ulang `_test_tactics` di `tests/test_gt_sim.gd:643-668`**

  Pertahankan skenario (`wear = 0.7`, `_place`, `_park_others`). Assertion baru: MANUAL menawarkan kartu BOX dan `accept_suggestion()` memanggil stop (menggantikan "hybrid offers"); AUTO: `decide_strategy(player)` menghasilkan kartu (bukan `pit_request` langsung) dan `race.time += RaceScript.SUGGESTION_WINDOW_S + 0.1; race.step()` membuat `player.pit_request >= 0`. Hapus asersi "manual stays quiet". Pesan: "tactics: MANUAL and AUTO both raise a BOX card at 70 %% wear; accept calls the stop; AUTO calls it itself when the 10 s window ends".

- [ ] **Step 7: Jalankan test yang terkena**

  Run: `godot --headless --path . -s res://tests/test_pit_deck_and_radio.gd` lalu `godot --headless --path . -s res://tests/test_gt_sim.gd`
  Expected: keduanya `PASS`, 0 FAIL. `test_gt_sim` juga memuat `_test_determinism`: harus tetap lulus.

- [ ] **Step 8: Commit**

```bash
git add scripts/gt/gt_types.gd scripts/gt/gt_race.gd tests/test_gt_sim.gd tests/test_pit_deck_and_radio.gd
git commit -m "feat(gt): drop HYBRID desk mode, 10 s suggestion window in the sim"
```

---

### Task 2: `cancel_pit` di sim dan world

**Files:**
- Modify: `scripts/gt/gt_race.gd` (setelah `request_pit`, baris 406-410), `scripts/world/weekend/race_weekend_world.gd` (setelah `request_pit`, baris 152-165)
- Test: `tests/test_pit_deck_and_radio.gd`

**Interfaces:**
- Produces: `GtRace.cancel_pit(car_id: int) -> bool`; `RaceWeekendWorld.cancel_pit(car_id: int) -> bool` (pembungkus yang mengembalikan hasil sim).
- Consumes: `GtRace.get_car`, `push_radio`, `_suggestion_cooldowns`, `GtDriving._pit_logic` (tidak diubah).

- [ ] **Step 1: Tulis test gagal `_test_cancel_pit()`**

  Assertion:
  - Panggil `world.request_pit(car.id, GtTypes.Compound.WET)` → `car.pit_request == WET`; `world.cancel_pit(car.id)` → `true`, `car.pit_request == -1`, `race.latest_radio["text"] == "Stay out, stay out! Box call cancelled."` dan `race.latest_radio["speaker"] == "engineer"`: "pit: cancelling a box call clears the request and the engineer confirms it".
  - Pacing pulih: tempatkan mobil di awal zona pendekatan (`car.s = PitLaneScript.ENTRY_S - 290.0`, `car.prev_s = car.s`, `car.v = 45.0`, `car.lap = 1`; `pit_u` = −290, batas komit pit −120), `request_pit` lalu `race.step_ticks(20)` → `car.v <= 38.5` (limiter pendekatan `_target = minf(_target, 38.0)`); `cancel_pit`, `race.step_ticks(80)` → `car.v > 50.0` dan `car.pit == null` (melewati garis pit tanpa masuk): "pit: after cancelling, the car leaves the pit approach pace, recovers speed and drives past the pit entry with no penalty". Jangan mulai lebih dekat dari −290 m: 80 tick × kecepatan mobil akan melewati batas komit −120 bila `pit_request` masih aktif.
  - Tanpa panggilan: `cancel_pit` → `false` dan `race.radio_history.size()` tidak bertambah: "pit: cancelling with no call is a no-op".
  - Sudah di pit: set `car.pit = GtPit.new()` (fase `ENTRY`) → `cancel_pit` → `false`, `car.pit` tidak berubah: "pit: a car already committed to the pit lane cannot cancel".
  - Cooldown: setelah cancel, `float(race._suggestion_cooldowns["%d-%d" % [car.id, GtTypes.TacticType.PIT]]) >= race.time + 30.0`: "pit: cancelling blocks an instant repeat BOX suggestion".

- [ ] **Step 2: Jalankan dan pastikan gagal**

  Run: `godot --headless --path . -s res://tests/test_pit_deck_and_radio.gd`
  Expected: FAIL ("Invalid call. Nonexistent function 'cancel_pit'").

- [ ] **Step 3: Implementasi `GtRace.cancel_pit(car_id: int) -> bool`**

  Tolak (`return false`, tanpa efek) bila `car == null`, `car.pit != null`, `car.pit_request < 0`, atau `car.finished_at >= 0.0`. Selain itu: `car.pit_request = -1`, set `_suggestion_cooldowns["%d-%d" % [car.id, GtTypes.TacticType.PIT]] = time + 30.0`, `push_radio(car, "engineer", "Stay out, stay out! Box call cancelled.", true)`, `return true`. Pacing pulih sendiri karena `GtDriving._pit_logic` hanya menahan kecepatan selama `pit_request >= 0`.

- [ ] **Step 4: Implementasi `RaceWeekendWorld.cancel_pit(car_id: int) -> bool`**

  `return race.cancel_pit(car_id)`; letakkan tepat setelah `request_pit`, dengan komentar satu baris seperti gaya sekitarnya.

- [ ] **Step 5: Jalankan test**

  Run: `godot --headless --path . -s res://tests/test_pit_deck_and_radio.gd`
  Expected: PASS. Bila asersi `car.v <= 38.5` gagal karena mobil belum menyentuh zona (u antara −300 dan −120), sesuaikan `ENTRY_S - 200.0` setelah mengecek `GtDriving.pit_u`, jangan melonggarkan asersi.

- [ ] **Step 6: Commit**

```bash
git add scripts/gt/gt_race.gd scripts/world/weekend/race_weekend_world.gd tests/test_pit_deck_and_radio.gd
git commit -m "feat(pit): cancel_pit with no penalty and a repeat-suggestion cooldown"
```

---

### Task 3: Deck: desk dua opsi, tombol BOX dua-state, label status desk

**Files:**
- Modify: `scripts/hud/tactical_deck.gd` (`TACTIC_NAME` baris 22, `_build_tactics` 148-158, `_build_pit` 133-145, `press_box` 208-210, `refresh` 252-280)
- Modify: `tests/test_race_hud.gd:174-196`
- Test: `tests/test_pit_deck_and_radio.gd`

**Interfaces:**
- Produces: `TacticalDeck.cancel_box() -> bool` (memanggil `_world.cancel_pit(deck_car_id)`); `TacticalDeck.desk_status: Label` di `Vector2(1366.0, ROW_2 + 32.0)` ukuran `Vector2(258.0, 18.0)`, font 11 `UI.MONO`; `TacticalDeck.on_box_pressed() -> void` (penangan klik tombol: cancel bila `car.pit_request >= 0 and car.pit == null`, selain itu `press_box()`).
- Consumes: `RaceWeekendWorld.cancel_pit`, `request_pit` (Task 2 dan yang sudah ada), `GtTypes.TacticMode`.

- [ ] **Step 1: Tulis test gagal `_test_deck_box_and_desk()`**

  Assertion (pakai `hud.deck`, `deck.deck_car_id = mine[0].id`):
  - `deck.tactic_row.buttons.size() == 2`; teks tombol `MANUAL`, `AUTO`: "deck: the desk row has MANUAL and AUTO only".
  - Awal: `deck.box_button.text == "REQUEST BOX [B]"` dan `not deck.box_button.disabled`.
  - `deck.tyre_row.buttons[1 + GtTypes.Compound.WET].pressed.emit()` lalu `deck.box_button.pressed.emit()` lalu `deck.refresh()` → `car.pit_request == WET`, `deck.box_button.text == "CANCEL BOX [ESC]  //  WET"`, `not deck.box_button.disabled`: "deck: after a box call the button becomes CANCEL BOX and stays enabled".
  - `deck.box_button.pressed.emit()` lagi → `car.pit_request == -1`; `deck.refresh()` → teks kembali `REQUEST BOX [B]`: "deck: clicking CANCEL BOX withdraws the call".
  - State terkunci: `car.pit = GtPit.new()` → `refresh()` → `text == "IN THE PIT LANE"` dan `disabled`; `car.pit = null`; `car.is_dnf = true` → `"RETIRED"` dan `disabled` (kembalikan `is_dnf = false`).
  - `deck.tactic_row.buttons[GtTypes.TacticMode.AUTO].pressed.emit()` → `race.tactic_mode == AUTO` dan `deck.desk_status.text == "MODE: AUTO // AI ENGINEER ASSISTED"`; tombol MANUAL → `"MODE: MANUAL // 100% PLAYER DIRECTIVE"` (setelah `refresh()`).

- [ ] **Step 2: Jalankan dan pastikan gagal**

  Run: `godot --headless --path . -s res://tests/test_pit_deck_and_radio.gd`
  Expected: FAIL (tombol desk masih 3, teks lama `BOX THIS LAP`).

- [ ] **Step 3: Ubah desk dan tombol di `tactical_deck.gd`**

  `TACTIC_NAME = ["MANUAL", "AUTO"]`; di `_build_tactics` tint `[T.ACCENT_ACID_LIME, T.ACCENT_CYBER_YELLOW]` dan lebar `ModeRow` disesuaikan agar dua tombol memenuhi `Vector2(214.0, ROW_H)` yang sama; tambah `desk_status` (kata-kata persis di Step 1) yang diisi di `refresh()` dari `race.tactic_mode`. `box_button.pressed` tersambung ke `on_box_pressed`. Di `refresh()`: `locked` hanya untuk `pit != null`, `is_dnf`, `finished_at >= 0.0` (hapus `pit_request >= 0` dari `locked`); teks sesuai daftar Global Constraints; saat state CANCEL beri `box_button` gaya crimson memakai token `T.ACCENT_ANIME_CRIMSON` (cara sama seperti `UI.style(...)` di `_style_tab`), kembalikan gaya normal saat bukan CANCEL. `cancel_box()` memanggil `AudioManager.click(self)` seperti `press_box`.

- [ ] **Step 4: Perbarui `tests/test_race_hud.gd`**

  Baris 174-179: tetap menekan AUTO (kini indeks 1). Baris 180: ganti `race.set_tactic_mode(GtTypes.TacticMode.HYBRID)` dengan `race.set_tactic_mode(GtTypes.TacticMode.MANUAL)`. Baris 191-192: asersi tombol diganti ke `deck.box_button.text.contains("CANCEL BOX") and deck.box_button.text.contains("WET") and not deck.box_button.disabled`; pesan "deck: choosing W and REQUEST BOX calls the car in for wets and the button turns into CANCEL BOX". Baris 311: pesan "the desk shows a card" (ganti kata "hybrid").

- [ ] **Step 5: Jalankan test**

  Run: `godot --headless --path . -s res://tests/test_pit_deck_and_radio.gd` dan `godot --headless --path . -s res://tests/test_race_hud.gd`
  Expected: keduanya PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/hud/tactical_deck.gd tests/test_race_hud.gd tests/test_pit_deck_and_radio.gd
git commit -m "feat(deck): MANUAL/AUTO desk, two-state REQUEST/CANCEL BOX button"
```

---

### Task 4: Bar api 10 detik di kartu saran + keybind B / ESC / ENTER

**Files:**
- Modify: `scripts/hud/race_hud.gd` (`_build_card` 223-242, `_on_suggestion` 424-429, `update` 440+, `handle_key` 326-350)
- Test: `tests/test_pit_deck_and_radio.gd`

**Interfaces:**
- Produces: `RaceHud.burn_fill: ColorRect` (anak `burn_track` 4 px dari tepi kartu, tinggi 10 px, lebar penuh = `card.size.x - 8.0`), `RaceHud.card_timer: Label`, `RaceHud.card_critical: bool` (true bila sisa < 3.0 s); `static func RaceHud.burn_color(fraction: float) -> Color` (≥0.66 `T.ACCENT_CYBER_YELLOW`, ≥0.33 oranye `Color("#FF6D00")`, selain itu `T.ACCENT_ANIME_CRIMSON`); `static func RaceHud.burn_text(remaining: float) -> String` (`"%04.1fs" % remaining`, dijepit ≥ 0); `func _update_burn() -> void`; `handle_key` menangani `KEY_B`, `KEY_ESCAPE`, `KEY_ENTER`, `KEY_KP_ENTER`.
- Consumes: `GtRace.suggestion_remaining()`, `SUGGESTION_WINDOW_S` (Task 1); `TacticalDeck.press_box`, `cancel_box` (Task 3).

- [ ] **Step 1: Tulis test gagal `_test_burn_bar_and_keys()`**

  Assertion:
  - `RaceHud.burn_text(10.0) == "10.0s"`, `RaceHud.burn_text(3.24) == "03.2s"`, `RaceHud.burn_text(-1.0) == "00.0s"`; `burn_color(1.0) == T.ACCENT_CYBER_YELLOW`, `burn_color(0.5) == Color("#FF6D00")`, `burn_color(0.1) == T.ACCENT_ANIME_CRIMSON`: "burn bar: label format and flame colour stages".
  - `race.suggest_tactic(car, PIT, HARD, "BOX FOR HARD", "x")`, `hud.refresh_all()`: `hud.card.visible`, `is_equal_approx(hud.burn_fill.size.x, hud.card.size.x - 8.0)` (penuh, gunakan lebar bar yang kamu pilih, konsisten dengan Step 3 implementasi), `hud.card_timer.text == "10.0s"`. Lalu `race.time += 5.0; hud.refresh_all()`: `absf(hud.burn_fill.size.x / full - 0.5) < 0.01` dan `hud.card_timer.text == "05.0s"`: "burn bar: the fill and label follow the 10 s window".
  - Kedip: `race.time += 3.0` (sisa 2.0 s) lalu panggil `hud._update_burn()` dengan dua nilai `Time`-independen: cek properti `hud.card_critical == true` (bool publik yang diset `remaining < 3.0`): "burn bar: under 3 s the card enters its critical state".
  - Saran baru menggantikan saran lama: suggest lagi tipe lain → `hud.card_timer.text == "10.0s"`: "burn bar: a replacement card restarts at 10.0 s".
  - `hud.handle_key(KEY_ENTER)` dengan kartu tampil → `true`, `not hud.card.visible`, `car.pit_request == HARD` (accept). Tanpa kartu: `handle_key(KEY_ENTER)` → `false`.
  - ESC: kartu tampil **dan** `car.pit_request >= 0`: `handle_key(KEY_ESCAPE)` → `true`, kartu tertutup, `car.pit_request` masih `>= 0`; `handle_key(KEY_ESCAPE)` lagi → `true`, `car.pit_request == -1`; sekali lagi → `false` (tidak dikonsumsi).
  - `B`: `car.pit_request = -1`, `hud.deck.deck_car_id = car.id`, `handle_key(KEY_B)` → `true` dan `car.pit_request >= 0`; `B` lagi saat sudah dipanggil → `true` dan `pit_request` tidak berubah.

- [ ] **Step 2: Jalankan dan pastikan gagal**

  Run: `godot --headless --path . -s res://tests/test_pit_deck_and_radio.gd`
  Expected: FAIL (`burn_text` tidak ada).

- [ ] **Step 3: Bangun bar dan label di `_build_card`**

  Dalam `card` (608×136): `burn_track` (ColorRect gelap) `position (4, 4)` `size (card.size.x - 8, 10)`; `burn_fill` anak track, lebar penuh awal; `card_timer` Label di kanan header (`position (card.size.x - 96, 10)`, font 22 `UI.HEADER`, rata kanan). Geser `card_title` tidak diperlukan (judul di y=10; bar di y 4–14 menimpa sedikit: naikkan `card_title` ke y=16 dan `card_text` ke y=46 jika ada tabrakan; kotak kartu tidak berubah). Semua `mouse_filter = IGNORE`.

- [ ] **Step 4: Implementasi `_update_burn` dan helper statis**

  `_update_burn()` dipanggil dari `update()` saat `card.visible`: `fraction = race.suggestion_remaining() / GtRace.SUGGESTION_WINDOW_S`; set lebar `burn_fill` ∝ fraction, warna `burn_color(fraction)`, `card_timer.text = burn_text(race.suggestion_remaining())`; `card_critical = remaining < 3.0` dan bila true berkedip (modulasi warna border kartu dan label antara crimson dan teks biasa dengan `int(world_clock * 6) % 2`; gunakan penghitung frame HUD `_frame`, bukan waktu dinding). `_on_suggestion` memanggil `_update_burn()` agar nilai langsung benar. Hormati `PresentationSettings.reduce_motion` (tidak berkedip bila true).

- [ ] **Step 5: Keybind di `handle_key`**

  Tambah cabang `KEY_B`: `deck.press_box()`; `KEY_ENTER`/`KEY_KP_ENTER`: bila `card.visible` → `_on_accept()` dan konsumsi, selain itu `return false`; `KEY_ESCAPE`: bila `card.visible` → `_on_dismiss()`; elif mobil deck punya `pit_request >= 0 and pit == null` → `deck.cancel_box()`; selain itu `return false` (jangan konsumsi, supaya `timing_tower.gd:108` tetap menerima `ui_cancel`). Perbarui teks ticker di `_build_marquee` menambahkan `[B] REQUEST BOX  [ESC] CANCEL BOX` dan komentar keys di header file.

- [ ] **Step 6: Jalankan test**

  Run: `godot --headless --path . -s res://tests/test_pit_deck_and_radio.gd`; `godot --headless --path . -s res://tests/test_race_hud.gd`
  Expected: keduanya PASS (test_race_hud memeriksa ticker/marquee: bila ada asersi panjang teks ticker, sesuaikan, jangan hapus).

- [ ] **Step 7: Commit**

```bash
git add scripts/hud/race_hud.gd tests/test_pit_deck_and_radio.gd
git commit -m "feat(hud): 10 s burn bar on the suggestion card and B / ESC / ENTER keys"
```

---

### Task 5: Regresi penuh, dokumen, bukti visual

**Files:**
- Modify: `PRD/00-MASTER-OVERVIEW.md:88`, `PRD/02-UI-UX-TOPOLOGY.md:131,134-135`, `PRD/07-DATA-TESTING-PERFORMANCE.md:88`, `ROADMAP.md`
- Create: `executor-report/reports/FASE-11-LANGKAH-3A-PIT-MECHANICS-REPORT.md`, screenshot di `executor-report/screenshots/phases/phase-11-langkah-3a-*.png`
- Create (sementara, boleh tetap): `scratch/capture_langkah3a.gd` mengikuti pola `scratch/capture_phase55.gd`

- [ ] **Step 1: Jalankan seluruh suite**

  Run: `Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --path . -s "res://tests/$($_.Name)" }`
  Expected: setiap suite mencetak `PASS`; total 28 suite (27 lama + `test_pit_deck_and_radio`), 0 FAIL. Bila ada suite lama gagal karena default desk berubah, perbaiki asersinya (bukan perilaku) dan catat di laporan.

- [ ] **Step 2: Smoke test native + tangkapan layar**

  Jalankan `godot --path . scenes/main.tscn`, balapan 3 lap, dan tangkap: (a) deck dengan `REQUEST BOX [B]`, (b) deck dengan `CANCEL BOX [ESC] // <COMPOUND>` crimson, (c) kartu saran dengan bar api penuh dan setengah (MANUAL), (d) kartu dengan sisa < 3.0 s, (e) desk di AUTO. Simpan di `executor-report/screenshots/phases/`.

- [ ] **Step 3: Perbarui dokumen**

  Hapus/ubah semua sebutan HYBRID di tiga file PRD menjadi dua mode (MANUAL: kartu saran menutup sendiri; AUTO: kartu mengeksekusi saat bar habis). Tandai 3a selesai di `ROADMAP.md` (Fase 11, Langkah 3a). Tulis laporan `FASE-11-LANGKAH-3A-PIT-MECHANICS-REPORT.md`: ringkasan, tabel file yang berubah, hasil 28 suite, daftar tangkapan layar, catatan Review Focus nomor 6 (time scale memendekkan jendela) dan keputusan perilaku baru MANUAL/AUTO.

- [ ] **Step 4: Commit**

```bash
git add PRD/00-MASTER-OVERVIEW.md PRD/02-UI-UX-TOPOLOGY.md PRD/07-DATA-TESTING-PERFORMANCE.md ROADMAP.md executor-report/reports/FASE-11-LANGKAH-3A-PIT-MECHANICS-REPORT.md executor-report/screenshots/phases scratch/capture_langkah3a.gd
git commit -m "docs(fase-11): Langkah 3a report, screenshots, PRD without HYBRID"
```
