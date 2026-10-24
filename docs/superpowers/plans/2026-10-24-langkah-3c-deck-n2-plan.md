# Langkah 3c — Tactical Deck N2 "Faders Console" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deck bawah menjadi konsol N2: tiga fader PACE/FUEL/ERS dengan gauge berzona dan verdict dari model sim, pemilih ban berbentuk roda berputar, tombol BOX dua-state yang menghentak roda, tooltip bahasa biasa (COACH), dan umpan balik klik di semua kontrol.

**Architecture:** Semua angka batas dan verdict datang dari satu helper sim (`GtForecast`) yang memakai tabel pengali yang sama dengan `gt_driving.gd` (tabel dipindah ke `GtTypes`, perilaku sim tidak berubah). Widget baru (`SeverityMark`, `FaderLadder`, `ZonedGauge`, `ChipGrid`, `TyreWheel`, `DeckTip`) dipakai `TacticalDeck`; API anggota lama (`pace_row`, `fuel_row`, `ers_row`, `tyre_row`, `tactic_row`, `tabs`, `box_button`, `desk_status`, `radio_label`, `info_label`, `press_box`, `cancel_box`, `refresh`) dipertahankan agar test lama tetap berlaku.

**Tech Stack:** Godot 4.7.2 stable, GDScript 2.0 (static typing wajib), test headless `SceneTree` (jalankan lewat `runtest.sh` yang menolak `SCRIPT ERROR` dan `[FAIL]`).

**Spec:** `docs/superpowers/specs/2026-10-24-langkah-3-hud-redesign-v2-design.md` §4.4, §5, §6. Acuan visual dan geometri: `docs/design-refs/ui_step_8_n2_final.html` (fungsi `deckN2c`, `fader2`, `verdict`, `COACH`, `drawWheel`, `initDeck`, `winBig`; CSS `.fadr`, `.vbz`, `.pill2`, `.tip`, `.tychip2`, `.boxbtn`). Angka dampak mockup adalah placeholder; nilai sim ada di bagian Global Constraints.

## Global Constraints

- Kotak deck tetap `pos (16, 880)` `size (1888, 140)` open / `(1888, 44)` collapsed. Isi: body mulai y = 38, tinggi 96 (berakhir y = 134). Tooltip boleh keluar di atas kotak deck (overlay yang diizinkan spec §3).
- Static typing wajib; tanpa dependensi atau aset baru (font: `UI.HEADER`, `UI.MONO`, `UI.DISPLAY`; glyph centang/segitiga/silang digambar, bukan karakter font).
- **Nilai sim (tabel tunggal, dipindah ke `GtTypes`, pengali pace berindeks `GtTypes.PaceMode`)**: `PACE_WEAR_MULT = [0.45, 0.72, 1.0, 1.45, 2.1]`, `PACE_FUEL_MULT = [0.85, 0.93, 1.0, 1.12, 1.25]`, `PACE_SPEED_MULT = [0.948, 0.978, 1.0, 1.025, 1.048]`, `FUEL_MODE_BURN_MULT = [0.80, 1.0, 1.25]` (CONSERVE/STANDARD/PUSH), `ERS_DRAIN_PER_S = [0.0, 0.0, 12.0, 24.0]` (per detik **saat men-deploy**, HARVEST/NEUTRAL 0), `ERS_HARVEST_PER_S = 4.0`, `TYRE_CLIFF_WEAR = 0.75`. Keausan per lap = `COMPOUND_WEAR_PER_LAP[car.compound] * car.tyre_wear_rate * PACE_WEAR_MULT[pace]` (di atas 112 °C ×1.4, di atas 115 °C ×3.5: tidak dimodelkan di verdict, dicatat di tooltip bila ban > 112 °C). Bensin per lap (kg) = `car.fuel_use * PACE_FUEL_MULT[pace] * FUEL_MODE_BURN_MULT[fuel_mode]`; margin dalam lap = `car.fuel / burn - laps_left`.
- Verdict severity `0 OK`, `1 WATCH`, `2 DANGER`; ikon ✓ ▲ ✖ digambar. Pilihan **tidak pernah dikunci**.
- Ambang verdict: ban saat finish `1 - wear - wear_per_lap * laps_left`: `< 0.15` DANGER, `< 0.25` WATCH; bensin: margin `< 0` lap DANGER, `< 0.5` lap WATCH; ERS (hanya DEPLOY/OVERTAKE): detik deploy tersisa `battery / drain` `< 6` WATCH (OVERTAKE ≈ 4.2 s pada baterai penuh, DEPLOY ≈ 8.3 s), `< 2` DANGER. Pilihan ban dinilai oleh `GtForecast.tyre_verdict` (Task 1): slick saat air > 45% atau hujan > 0.55 (atau forecast 4 lap ke depan merekomendasikan basah) = DANGER; inter/wet saat trek kering = WATCH.
- Umpan balik klik di semua kontrol deck: tombol menekan (skala 0.92→1 dalam 0.12 s), teks pop di atas kontrol (nama pilihan, mis. `SOFT`, tanpa glyph centang), `AudioManager.click_pitched(node, pitch)` (pitch berbeda per aksi), roda dihentak untuk aksi ban dan BOX. `PresentationSettings.reduce_motion` meniadakan skala/hentak/goyang tetapi tidak suara.
- Teks tooltip dan pill harus terbaca tanpa warna (ikon + label). Bahasa teks coach: Inggris (seperti mockup), diisolasi dalam satu tabel (`DeckCoach`) agar mudah dilokalkan.
- Test lama tetap hijau (29 suite); `_test_deck_*` memakai API anggota yang sama.
- Commit trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; hanya `git add` file yang disebut. File baru butuh `godot --headless --path . --import` sebelum test (class_name) dan `.uid`-nya ikut di-commit.

## Review Focus

1. Pemain memilih PUSH / ATTACK / OVERTAKE saat kondisi sudah genting (ban 20%, bensin 1 lap, baterai 10%): verdict DANGER dengan alasan; tombol tetap bisa diklik. (Task 1, 3)
2. Mobil tanpa `fuel_burn_rate` (0), `laps_left = 0`, mobil DNF, mobil di pit: verdict tidak membagi nol dan mengembalikan teks valid. (Task 1)
3. Tooltip dekat tepi kiri/kanan deck tetap berada dalam 1920 piksel layar dan tidak menutup tombol yang sedang ditunjuk secara permanen. (Task 2)
4. `reduce_motion` aktif: roda tetap berputar sesuai kecepatan tapi tanpa hentak/goyang; tombol tidak berkedip. (Task 2, 3)
5. Mengganti mobil (tab/`N`) mengganti seluruh verdict, gauge, dan kartu tanpa sisa mobil sebelumnya; mobil kedua yang berbeda compound menampilkan ban yang benar. (Task 3)
6. BOX dua-state: klik cepat dua kali tidak memanggil lalu langsung membatalkan secara tak sengaja (debounce ≥ 0.25 s pada klik tombol, bukan pada tombol keyboard). (Task 3)

## File Structure

- Modify `scripts/gt/gt_types.gd` — tabel pengali dan konstanta (di atas).
- Modify `scripts/gt/gt_driving.gd` — memakai tabel itu (tanpa mengubah angka).
- Create `scripts/gt/gt_forecast.gd` — `class_name GtForecast`: proyeksi dan verdict.
- Modify `scripts/audio/audio_manager.gd` — `click_pitched`.
- Create `scripts/hud/severity_mark.gd`, `fader_ladder.gd`, `zoned_gauge.gd`, `chip_grid.gd`, `tyre_wheel.gd`, `deck_tip.gd`, `deck_coach.gd` (tabel teks).
- Modify `scripts/hud/tactical_deck.gd` — tata letak N2.
- Modify `scripts/hud/race_hud.gd` — meneruskan aksen dan data cuaca ke deck.
- Create `tests/test_deck_n2.gd` — suite baru.
- Modify `tests/test_race_hud.gd`, `tests/test_pit_deck_and_radio.gd` hanya bila kontrak anggota berubah.
- Create `executor-report/reports/FASE-11-LANGKAH-3C-DECK-N2-REPORT.md`, `scratch/capture_langkah3c.gd`, screenshot `phase-11-langkah-3c-*.png`; modify `ROADMAP.md`.

---

### Task 1: Tabel sim bersama dan `GtForecast` (verdict, proyeksi, rekomendasi ban)

**Files:**
- Modify: `scripts/gt/gt_types.gd`, `scripts/gt/gt_driving.gd` (blok `match car.pace_mode` ~baris 188-208, fuel mode ~211-218, ERS ~219-234)
- Create: `scripts/gt/gt_forecast.gd`, `tests/test_deck_n2.gd`

**Interfaces:**
- Produces (`GtTypes`): konstanta tabel di Global Constraints.
- Produces (`GtForecast`, semua `static`): `wear_per_lap(car: GtCar, pace_mode: int) -> float`; `burn_per_lap(car: GtCar, pace_mode: int, fuel_mode: int) -> float` (kg); `tyre_life_at_finish(car: GtCar, pace_mode: int, laps_left: float) -> float` (0..1, bisa negatif → dijepit 0); `fuel_margin_laps(car: GtCar, pace_mode: int, fuel_mode: int, laps_left: float) -> float`; `ers_seconds(battery: float, ers_mode: int) -> float` (`INF` bila tidak men-deploy); `verdict(kind: String, index: int, car: GtCar, laps_left: float) -> Dictionary` dengan kunci `"severity": int`, `"text": String`, `"projected": float` (kind `"pace"`, `"fuel"`, `"ers"`; `index` = enum mode; menilai pilihan itu terhadap keadaan mobil sekarang, pilihan pace diuji bersama `car.fuel_mode`, fuel bersama `car.pace_mode`); `tyre_verdict(index: int, water_pct: float, rain: float, forecast: Array[Dictionary]) -> Dictionary` (index 0 AUTO, 1..5 = `Compound + 1`); `recommended_compound(water_pct: float, rain: float) -> int` (`WET` bila air > 45 atau hujan > 0.55; `INTERMEDIATE` bila air > 18; selain itu `MEDIUM`: ambang yang sama dengan `decide_strategy`); `laps_left(race: GtRace, car: GtCar) -> float` (`maxf(0, race.laps - maxi(car.lap, 0))`).
- Kalimat verdict (Inggris, persis awalannya): ban `"Tyres end at ~%d%%: above the cliff."` / `"Tyres end at ~%d%%: right at the cliff (25%%) by the finish."` / `"Tyres pass the cliff (25%%) about %d laps from now, well before the finish."`; bensin `"+%.1f laps of fuel spare at the finish."` / `"Only +%.1f laps of fuel spare at the finish. Very tight."` / `"Short by %.1f laps of fuel: you will not finish without a stop."`; ERS `"Battery lasts ~%.0f s of deploying: save it for a pass."` / `"Battery lasts ~%.0f s of deploying."` / `"Recharges while you drive."` / `"Battery stays level."`.

- [ ] **Step 1: Buat suite dan tulis test gagal `_test_forecast()`**

  Harness seperti `tests/test_hud_theme_and_telemetry.gd` (memuat dunia balap, `race`, `mine`). Asersi (mobil uji `mine[0]` dengan `compound = MEDIUM`, `tyre_wear_rate = 1.0`, `wear = 0.28`, `fuel_use = 3.0`, `fuel = 39.0`, `ers_battery = 100.0`):
  - Tabel: `GtTypes.PACE_WEAR_MULT == [0.45, 0.72, 1.0, 1.45, 2.1]`, `PACE_FUEL_MULT == [0.85, 0.93, 1.0, 1.12, 1.25]`, `FUEL_MODE_BURN_MULT == [0.8, 1.0, 1.25]`, `ERS_DRAIN_PER_S[3] == 24.0`: "forecast: the multiplier tables carry the numbers gt_driving always used".
  - `GtForecast.wear_per_lap(car, GtTypes.PaceMode.ATTACK)` ≈ `0.032 * 1.0 * 2.1` (0.0672); `burn_per_lap(car, STANDARD, PUSH)` ≈ 3.75; `tyre_life_at_finish(car, STANDARD, 10.0)` ≈ `1 - 0.28 - 0.32 = 0.40`; `fuel_margin_laps(car, STANDARD, STANDARD, 10.0)` ≈ `39/3 - 10 = 3.0`; `ers_seconds(100.0, OVERTAKE)` ≈ 4.17; `ers_seconds(100.0, DEPLOY)` ≈ 8.33; `ers_seconds(100.0, NEUTRAL)` = `INF`: "forecast: wear, burn, fuel margin and battery seconds come from the sim's own formulas".
  - Verdict: dengan `laps_left = 10.0`: pace STANDARD → severity 0 (ban 40%); pace ATTACK → `0.28 + 0.672 = 0.952` terpakai, sisa 4.8% → severity 2 (DANGER) dan `text` mulai dengan "Tyres pass the cliff"; pace AGGRESSIVE (0.28 + 0.464 = 0.744 → sisa 25.6%) → severity 0; naikkan `wear` ke 0.34 → AGGRESSIVE sisa 19.6% → severity 1 dengan awalan "Tyres end at ~20%". Fuel `fuel = 30.0` (margin STANDARD 0.0 → WATCH `< 0.5`), PUSH → `30/3.75 - 10 = -2` → severity 2 "Short by 2.0 laps". ERS OVERTAKE pada 100% → severity 1 (4.2 s < 6), pada 40% (1.67 s < 2) → severity 2; NEUTRAL dan HARVEST → severity 0: "forecast: risky options are flagged from the model, never locked".
  - Ketahanan: `fuel_burn` nol (`fuel_use = 0.0`), `laps_left = 0.0`, `car.is_dnf = true`: `verdict("fuel", 1, car, 0.0)["text"] != ""` dan severity ∈ {0,1,2} tanpa error; `laps_left(race, car)` ≥ 0.
  - `recommended_compound(50.0, 0.0) == WET`, `(10.0, 0.7) == WET`, `(25.0, 0.1) == INTERMEDIATE`, `(5.0, 0.0) == MEDIUM`: "forecast: tyre recommendation uses the strategy desk's own thresholds".
  - `tyre_verdict(1, 5.0, 0.0, [])` (SOFT, kering) severity 0; `tyre_verdict(1, 50.0, 0.8, [])` (slick saat hujan lebat) severity 2 dengan teks berisi "aquaplane"; `tyre_verdict(5, 5.0, 0.0, [])` (WET di trek kering) severity 1 dengan "overheat"; `tyre_verdict(0, 5.0, 0.0, [])` severity 0 dengan "Auto will fit".

- [ ] **Step 2: Jalankan dan pastikan gagal**

  Run: `bash <workspace>/runtest.sh test_deck_n2`
  Expected: gagal (parse error `GtForecast` / konstanta tidak ada).

- [ ] **Step 3: Implementasi**

  Tambahkan tabel ke `GtTypes` dan buat `gt_driving.gd` membaca tabel itu persis di tempat blok `match` / `if` sekarang (angka tidak berubah; `target_temp` per pace tetap lokal di `gt_driving.gd`). Tulis `GtForecast` memakai tabel dan rumus di Global Constraints; verdict ban/bensin/ERS per ambang di sana; `tyre_verdict` memakai `recommended_compound` dan, bila ada entri `forecast` (`{"lap","rain_intensity","water_pct"}`) dalam 4 lap ke depan yang merekomendasikan basah, memberi DANGER untuk slick (`"Water arrives in %d laps: slicks will aquaplane (3x braking distance)."`).

- [ ] **Step 4: Jalankan test, lalu seluruh suite yang menyentuh sim**

  Run: `godot --headless --path . --import`, lalu `runtest.sh test_deck_n2 test_gt_sim test_race_weekend_and_physics test_garage_tyre_strategy test_pit_deck_and_radio`
  Expected: semua OK (determinisme `test_gt_sim` membuktikan refactor tabel tidak mengubah sim).

- [ ] **Step 5: Commit**

```bash
git add scripts/gt/gt_types.gd scripts/gt/gt_driving.gd scripts/gt/gt_forecast.gd scripts/gt/gt_forecast.gd.uid tests/test_deck_n2.gd tests/test_deck_n2.gd.uid
git commit -m "feat(forecast): shared sim multiplier tables and GtForecast verdicts"
```

---

### Task 2: Widget deck (ikon, ladder, gauge, chip, roda, tooltip) + `click_pitched`

**Files:**
- Create: `scripts/hud/severity_mark.gd`, `scripts/hud/fader_ladder.gd`, `scripts/hud/zoned_gauge.gd`, `scripts/hud/chip_grid.gd`, `scripts/hud/tyre_wheel.gd`, `scripts/hud/deck_tip.gd`, `scripts/hud/deck_coach.gd`
- Modify: `scripts/audio/audio_manager.gd`
- Test: `tests/test_deck_n2.gd`

**Interfaces:**
- `class_name SeverityMark extends Control`: `var severity: int` (0/1/2), `func set_severity(value: int) -> void`; `_draw` menggambar ✓ (hijau `#6DFF9C`), ▲ (kuning `#FFE600`), ✖ (merah `#FF6B86`) dalam kotak 14×14.
- `class_name FaderLadder extends VBoxContainer`: `signal selected(index: int)`; `var buttons: Array[Button]` (urut indeks opsi 0..n-1; di layar opsi terbesar di atas), `var active: int`; `_init(labels: Array[String], tints: Array[Color])`; `func set_active(index: int) -> void`; `func set_marks(severities: Array[int]) -> void` (menampilkan `SeverityMark` di tepi kanan tombol bila severity > 0, menyembunyikan bila 0); `signal hovered(index: int)` dan `signal unhovered`. Tinggi tiap tombol = `floor((total - gap*(n-1)) / n)`.
- `class_name ZonedGauge extends Control`: `var value: float` (0..1), `var zone_colors: Array[Color]` (12, dari bawah), `var tick: float` (0..1), `var ghost: float` (< 0 = sembunyi), `var ghost_color: Color`; `func set_state(value: float, tick: float) -> void`; `_draw` 12 blok (nyala sampai `ceil(value*12)`, sisanya `Color(zone, 0.18)`), garis putih di `tick`, garis putus-putus di `ghost`.
- `class_name ChipGrid extends GridContainer`: sama bentuk dengan `ModeRow` (`signal selected(index)`, `buttons`, `active`, `set_active`), 6 tombol 3 kolom, teks dua baris `"S\nSOFT"`, warna latar per compound.
- `class_name TyreWheel extends Control` (96×96): `signal clicked`, `var compound: int` (0 AUTO, 1..5), `var angle: float`, `var impulse: float`, `var armed: bool`, `var box_flash: float`; `func set_compound(index: int, kick: bool) -> void` (menambah `impulse` 900 dan `flash` bila `kick`); `func hit() -> void` (impulse +1800, shake); `static func spin_velocity(speed_kmh: float, impulse: float) -> float` (= `speed_kmh * 1.6 + impulse`); `_process(delta)` (meluruhkan impuls `exp(-3.2*dt)`, memajukan `angle`; `reduce_motion` meniadakan hentak/goyang tetapi tidak putaran); klik kiri mengemit `clicked`, roda mouse mengemit `clicked` dan mengubah arah via `signal wheel_scrolled(direction: int)`; `_draw` menggambar ban (24 blok tread berputar), cincin sidewall warna compound (putus-putus untuk AUTO), pelek 5 jari-jari dengan motion blur bila `|v| > 250`, hub dengan huruf compound, lencana `→<huruf>` untuk AUTO (rekomendasi diteruskan lewat `var auto_hint: int`), cincin cyan berputar saat `armed`.
- `class_name DeckTip extends Control` (lebar 440): `func show_for(target: Control, severity: int, title: String, plain: String, numbers: String, verdict: String, coach: bool) -> void` (memosisikan tip di atas `target`, menjepit x ke `[0, deck.size.x - 440]` dalam koordinat deck, dan ke dalam layar 1920); `func hide_tip() -> void`; anak: `SeverityMark`, label judul, label plain (autowrap, disembunyikan bila `coach == false`), label angka (MONO 11), label verdict berwarna sesuai severity.
- `class_name DeckCoach extends RefCounted`: `const PACE: Array[String]`, `FUEL`, `ERS`, `TYRE` berisi kalimat bahasa biasa persis seperti mockup (`COACH` dan `TYR_TIP` di `ui_step_8_n2_final.html`).
- `AudioManager`: `static func click_pitched(node: Node, pitch: float) -> void` (memanggil `_play_ui(CLICK, pitch)` melalui `hub.play_ui_click_pitched(pitch)`); `func play_ui_click_pitched(pitch: float) -> void`.

- [ ] **Step 1: Tulis test gagal `_test_widgets()`**

  Asersi (semua headless, tanpa deck):
  - `FaderLadder.new(["CONSERVE","LIGHT","STANDARD","AGGRESSIVE","ATTACK"], tints)`: `buttons.size() == 5`; `buttons[4]` ada di posisi paling atas (`get_child(0) == buttons[4]`); `set_active(2)` → `active == 2`; menekan `buttons[3].pressed.emit()` mengemit `selected(3)` (tangkap lewat array) dan `active == 3`; `set_marks([0,0,0,1,2])` → tanda terlihat hanya pada indeks 3 dan 4 (cek `visible` anak `SeverityMark`): "widgets: the fader ladder keeps the option order, selects, and marks risky options".
  - `ZonedGauge`: `set_state(0.72, 0.25)` lalu hitung blok menyala = `ceili(0.72*12 - 1e-4) == 9` lewat metode `lit_blocks() -> int`; `ghost = -1` → `ghost_visible() == false`; `ghost = 0.24` → true: "widgets: the gauge lights blocks by value and shows the finish ghost only when set".
  - `ChipGrid`: 6 tombol, `set_active(4)`, tombol 4 menekan → `selected(4)`: "widgets: the tyre chip grid selects a compound".
  - `TyreWheel.spin_velocity(100.0, 0.0) == 160.0` dan `spin_velocity(100.0, 900.0) == 1060.0`; `wheel.set_compound(3, true)` menaikkan `impulse` ≥ 900 dan `compound == 3`; `_process(0.5)` mengurangi `impulse` (`< 900 * exp(-1.6) + 0.1`) dan mengubah `angle`; dengan `PresentationSettings.reduce_motion = true`, `hit()` tidak menambah `impulse` (tetap putar karena kecepatan mobil): "widgets: the wheel spins with the car, kicks on a change, and holds still-ish under reduce motion". Kembalikan `reduce_motion = false`.
  - `AudioManager`: `AudioManager.of(node).play_counts` naik setelah `AudioManager.click_pitched(node, 1.2)`: "audio: click_pitched logs a click".
  - `DeckTip`: `show_for` ke target di (10, 0) menjepit x ≥ 0; ke target dekat tepi kanan (x = deck.size.x - 20) menjepit sehingga `tip.position.x + 440 <= deck.size.x`; `coach = false` menyembunyikan label plain: "widgets: the tooltip stays inside the deck width and drops the plain sentence when COACH is off".

- [ ] **Step 2: Jalankan dan pastikan gagal** (`runtest.sh test_deck_n2`: parse error kelas belum ada).

- [ ] **Step 3: Implementasi widget dan `click_pitched`**

  Port bentuk dan warna dari CSS/JS mockup (`.fadr`, `.vbz`, `.pill2`, `.tip`, `drawWheel`). Tombol ladder memakai `UI.button` dengan font 12 dan gaya `StyleBoxFlat`; tombol aktif berwarna tint opsi dengan font ink. Roda digambar di satu `_draw` (blok tread, cincin, pelek, jari-jari, motion blur 3 jejak alpha menurun). Jalankan `godot --headless --path . --import` setelah membuat file.

- [ ] **Step 4: Jalankan test** (`runtest.sh test_deck_n2`; harapan OK).

- [ ] **Step 5: Commit** (semua file baru termasuk `.uid`).

```bash
git add scripts/hud/severity_mark.gd scripts/hud/fader_ladder.gd scripts/hud/zoned_gauge.gd scripts/hud/chip_grid.gd scripts/hud/tyre_wheel.gd scripts/hud/deck_tip.gd scripts/hud/deck_coach.gd scripts/hud/*.gd.uid scripts/audio/audio_manager.gd tests/test_deck_n2.gd
git commit -m "feat(deck): fader ladder, zoned gauge, tyre wheel, tooltip and pitched click widgets"
```

---

### Task 3: Tata letak N2 di `TacticalDeck`

**Files:**
- Modify: `scripts/hud/tactical_deck.gd` (`_init`, `_build_tabs/_build_modes/_build_pit/_build_tactics/_build_radio`, `refresh`, `_on_*`), `scripts/hud/race_hud.gd` (meneruskan aksen via `deck.set_accent`, sudah ada)
- Modify: `tests/test_race_hud.gd`, `tests/test_pit_deck_and_radio.gd` hanya bila kontrak berubah
- Test: `tests/test_deck_n2.gd`

**Interfaces (anggota dipertahankan):** `pace_row: FaderLadder`, `fuel_row: FaderLadder`, `ers_row: FaderLadder` (tipe berubah dari `ModeRow`, API `buttons/active/set_active/selected` sama), `tyre_row: ChipGrid`, `tactic_row: ModeRow` (MANUAL/AUTO, dipindah ke header), `tabs: Array[Button]` (2 kartu mobil; teks berisi `P%d  #%02d %s   %s %d%%`), `box_button`, `desk_status`, `radio_label`, `info_label`, `collapse_button`. Baru: `coach_button: Button`, `coach: bool` (default true), `wheel: TyreWheel`, `pace_gauge/fuel_gauge/ers_gauge: ZonedGauge`, `pace_pill/fuel_pill/ers_pill: Label` + `*_mark: SeverityMark`, `tip: DeckTip`, `window_label: Label`, `forecast_label: Label`; `func verdict_for(kind: String, index: int) -> Dictionary` (memanggil `GtForecast.verdict` untuk mobil deck); `func apply_click_feedback(control: Control, text: String, pitch: float) -> void` (animasi tekan 0.92→1 dalam 0.12 s, teks pop, `AudioManager.click_pitched`, `wheel.hit()` bila aksi ban/BOX; tanpa animasi bila `reduce_motion`).
- Tata letak (koordinat relatif kotak deck, body mulai y = 38, tinggi 96): kartu mobil (14,38) dan (14,86) masing-masing 250×44; fader PACE x = 284, FUEL x = 498, ERS x = 712 (tiap grup: ladder 104 lebar, gauge di x + 112 lebar 22, teks di x + 142 lebar 60: judul 9 pt mono, angka besar 22 pt `UI.DISPLAY`, pill 11 pt, legenda 8 pt); roda (944,38) 96×96; chip ban (1048,38) 224×96 (3×2, 72×46, jarak 4); tombol BOX (1286,38) 270×78 font 28 dengan `info_label` di bawahnya (1286,118); kartu BOX WINDOW (1568,38) 304×96; header: pelat judul `UI.header` dipersempit ke 264 lebar, di belakangnya `ColorRect` `#121722` selebar deck, `forecast_label` (x 282, lebar 650, MONO 12), `coach_button` (x 944, 86×22), `tactic_row` (x 1040, 230×24), `radio_label` (x 1284, 440 lebar, 1 baris terpotong), `collapse_button` (x 1740, 130×24). Tinggi/kotak deck tidak berubah.
- Gauge: PACE = umur ban saat ini (`1 - wear`), zona merah 0–25% (blok 0–2), kuning 25–50% (3–5), lime di atasnya, tick pada 0.25 (cliff), ghost = proyeksi finish untuk opsi terpilih/di-hover; FUEL = `car.fuel / car.fuel_burn_rate / race.laps` dijepit, zona merah di bawah tick, tick pada `laps_left / race.laps` (flag), teks `+x.x laps`; ERS = `ers_battery / 100`, zona merah blok 0–1 (≤ 20%), ungu di atasnya, ghost = baterai setelah 3 detik deploy opsi terpilih.
- Tooltip: hover opsi/chip/roda/BOX menampilkan `DeckTip` (verdict, kalimat coach dari `DeckCoach` bila `coach`, angka dampak relatif terhadap pilihan aktif: selisih keausan per lap `GtForecast.wear_per_lap`, selisih bensin per lap, detik deploy). Teks BOX: "Calls the car into the pits at the next pit entry. You can cancel any time before pit entry with no penalty." dengan verdict OK `"Best lap to pit: ..."` dari `window_label`.
- Kartu BOX WINDOW (versi 3c, 3d menggantinya dengan ladder penuh): memakai `race.weather.forecast` untuk 5 lap ke depan: chip rekomendasi ban per lap lewat `GtForecast.recommended_compound` dan satu baris `"BOX WINDOW L+%d -> %s"` bila rekomendasi berubah (lap sebelum perubahan, minimum L+1), selain itu `"NO TYRE CHANGE"`; teks cadangan `"weather stable"`.
- Header `forecast_label`: `"NEXT LAP > LAP %s - WEAR %.1f%%/lap - CLIFF L%d - FUEL %+.1f laps - BATT %d%%"` (LAP = `last_lap` bila ≥ 0 dalam `RaceHud.lap_text`, selain itu `--`; CLIFF = `car.lap + (0.75 - wear) / wear_per_lap` dibulatkan, `--` bila tak terjangkau; lihat `GtForecast`). Saat hover opsi, label berubah menjadi dampak pilihan (`<KIND>: <NAMA> -> LAP .. WEAR .. FUEL ..`) dan kembali saat mouse pergi.
- BOX: klik tombol memakai debounce 0.25 s (`_box_clicked_at` dari `Time.get_ticks_msec()` hanya untuk UI, bukan sim); `press_box()`/`cancel_box()`/tombol `B`/`ESC` tidak di-debounce. Setelah `press_box()` sukses: `wheel.armed = true`, `wheel.hit()`; setelah `cancel_box()`: `armed = false`, `hit()`. `refresh()` menyamakan `armed` dengan `car.pit_request >= 0 and car.pit == null`.
- Pilih ban: chip atau roda (klik = compound berikutnya, scroll = ±1) memanggil `_on_tyre(index)`; `wheel.set_compound(index, true)`; `wheel.auto_hint = recommended compound` untuk AUTO.

- [ ] **Step 1: Tulis test gagal `_test_deck_layout_and_flow()`** (memakai dunia balap, mobil `mine[0]`; panggil `deck.refresh()` setelah setiap perubahan):
  - Tata letak: `deck.position == Vector2(16, 880)`, `deck.size == Vector2(1888, 140)`; tiap kontrol N2 berada dalam kotak deck (`Rect2(Vector2.ZERO, deck.size).encloses(control_rect)` untuk `pace_row`, `fuel_row`, `ers_row`, gauge, `wheel`, `tyre_row`, `box_button`, `tabs`, kartu window); `coach_button`, `tactic_row`, `radio_label`, `collapse_button` berada di y < 36: "deck N2: every control sits inside the unchanged 1888x140 box, the header holds COACH, desk, radio and fold".
  - Fader: menekan `deck.pace_row.buttons[GtTypes.PaceMode.ATTACK].pressed` → `car.pace_mode == ATTACK`; `deck.pace_row.active == ATTACK`; `deck.fuel_row` PUSH dan `deck.ers_row` OVERTAKE sama (tes lama di `test_race_hud` tetap): "deck N2: faders write straight into the sim".
  - Verdict di UI: pada mobil dengan `wear = 0.5`, `laps_left` besar: setelah `refresh()`, tanda pada `pace_row` untuk ATTACK severity ≥ 1 (`pace_row.marks()[ATTACK] >= 1`), pill `pace_pill.text` sesuai severity opsi aktif ("OK"/"WATCH"/"DANGER"), `fuel_gauge.value` dan `pace_gauge.value == 1.0 - car.wear`: "deck N2: option marks, pills and gauges follow the model". Mobil tidak terkunci: `pace_row.buttons[ATTACK].disabled == false`.
  - Hover: emit `hovered` pada ladder ATTACK → `deck.tip.visible` dan `forecast_label.text` mengandung "ATTACK"; `unhovered` → label kembali berawalan "NEXT LAP": "deck N2: hovering an option shows its effect and the tooltip".
  - COACH: `deck.coach_button.pressed.emit()` → `deck.coach == false`, tooltip tanpa label plain; kembali ke true: "deck N2: COACH toggles the plain-language sentence".
  - Roda dan chip: `deck.tyre_row.buttons[1 + GtTypes.Compound.INTERMEDIATE].pressed.emit()` → `deck.wheel.compound == 1 + INTERMEDIATE` dan `deck.pit_compound == INTERMEDIATE`; klik roda (`deck.wheel.clicked.emit()`) memajukan compound; `deck.wheel.impulse > 800.0` setelah ganti compound: "deck N2: the wheel and the chips pick the next tyre and the wheel is kicked".
  - BOX: `deck.press_box()` → `deck.wheel.armed == true` setelah `refresh()`, teks `CANCEL BOX [ESC]  //  ...`; `deck.cancel_box()` → `armed == false`. Dua klik tombol dalam < 0.25 s (panggil `deck.on_box_pressed()` dua kali berurutan): keadaan akhir tetap `pit_request >= 0` (klik kedua diabaikan): "deck N2: BOX arms the wheel, cancel releases it, a double click does not call then cancel".
  - Mobil kedua: `deck.tabs[1].pressed.emit()` → `deck.deck_car_id == mine[1].id`, `pace_gauge.value == 1.0 - mine[1].wear`, tab 1 aktif: "deck N2: switching car swaps verdicts, gauges and the active card".
  - Umpan balik klik: `AudioManager.of(deck).play_counts[&"click"]` (atau kunci yang dipakai `CLICK`) naik setelah menekan fader; `deck.apply_click_feedback` dengan `reduce_motion = true` tidak membuat tween (cek `deck.feedback_tweens == 0`) tetapi tetap menaikkan hitungan suara: "deck N2: every control gives audible and visible click feedback (no animation under reduce motion)".
  - Jendela BOX: dengan `race.weather.forecast` diisi 3 lap kering lalu hujan deras, `deck.window_label.text` berisi "BOX WINDOW" dan "WET"; semua kering: "NO TYRE CHANGE": "deck N2: the window card reads the weather forecast".

- [ ] **Step 2: Jalankan dan pastikan gagal** (parse error anggota baru / tipe).

- [ ] **Step 3: Implementasi tata letak dan alur** sesuai bagian Interfaces. Hapus pembangunan `ModeRow` untuk pace/fuel/ers/tyre; `_caption(...)` label lama dihapus; `info_label` dan `radio_label` tetap diisi seperti sekarang. `refresh()` menghitung verdict untuk setiap opsi sekali per refresh (3 ladder × 3–5 opsi) dan menyimpan hasilnya (`_verdicts`) untuk tooltip.

- [ ] **Step 4: Jalankan test**

  Run: `runtest.sh test_deck_n2 test_race_hud test_pit_deck_and_radio test_hud_theme_and_telemetry`
  Expected: semua OK. Perbaiki test lama hanya bila kontrak anggota yang dijanjikan berubah, dan catat di ledger.

- [ ] **Step 5: Commit**

```bash
git add scripts/hud/tactical_deck.gd scripts/hud/race_hud.gd tests/test_deck_n2.gd tests/test_race_hud.gd tests/test_pit_deck_and_radio.gd
git commit -m "feat(deck): N2 faders console with verdicts, gauges, wheel and coach tooltips"
```

---

### Task 4: Regresi penuh, bukti visual, dokumen

**Files:**
- Create: `scratch/capture_langkah3c.gd` (pola `capture_langkah3b.gd`), `executor-report/reports/FASE-11-LANGKAH-3C-DECK-N2-REPORT.md`, `executor-report/screenshots/phases/phase-11-langkah-3c-*.png`
- Modify: `ROADMAP.md`

- [ ] **Step 1: Seluruh suite** — `runtest.sh $(semua tests/test_*.gd tanpa .gd)`; harapan semua OK (≥ 30 suite), tanpa `[FAIL]`/`SCRIPT ERROR`. Satu instance Godot sekaligus.
- [ ] **Step 2: Tangkapan layar native** — deck N2 bersih; tooltip PACE ATTACK (WATCH/DANGER); BOX CANCEL dengan roda `armed`; tim crimson dan putih; COACH OFF; satu keadaan ban kritis (`wear` 0.8) dengan ikon ✖; bandingkan dengan `docs/design-refs/ui_step_8_n2_final.html`. Lihat tiap gambar.
- [ ] **Step 3: Dokumen dan commit** — laporan (ringkasan, file, hasil, temuan, ruling), ROADMAP 3c dicentang.

```bash
git add scratch/capture_langkah3c.gd executor-report/reports/FASE-11-LANGKAH-3C-DECK-N2-REPORT.md executor-report/screenshots/phases/phase-11-langkah-3c-*.png ROADMAP.md
git commit -m "docs(fase-11): Langkah 3c report and screenshots"
```
