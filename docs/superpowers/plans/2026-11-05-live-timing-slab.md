# Live Timing Slab + Tyre Life Wheel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Live Timing berdesain Slab yang mengikuti warna tim player, dengan ring tyre-life; elemen ban telemetri menjadi roda tick; telemetri hanya mengikuti mobil deck.

**Architecture:** Tower dan baris tetap memakai `TimingTower` + `DriverRow` (dipakai juga oleh `PitWallDashboard` lama), jadi baris punya mode ringkas dan mode slab (`set_expanded`). Satu kontrol baru `TyreLifeRing` plus statik `tint_for`/`lit_ticks` dipakai tower dan painter telemetri agar ambang life sama dengan gauge TYRE LIFE di deck. Warna chrome didaftarkan ke `GarageStyle` yang sudah dipegang `RaceHud`, jadi `set_team_accent()` mengecat ulang tower tanpa kode tambahan.

**Tech Stack:** Godot 4.7.2, GDScript statis, test headless `tests/test_*.gd` via `tools/run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-11-05-live-timing-slab-design.md`

## Global Constraints

- Godot 4.7.2, GDScript statis wajib; satu proses per suite, semua suite 100% PASS, 0 FAIL, 0 `SCRIPT ERROR`/`Parse Error`.
- Tower tetap 320×780 di (16, 88); tidak melewati `RaceHud.RADIO_DOCK` (x ≥ 352); 20 mobil muat tanpa scroll.
- 60 FPS: tidak ada alokasi per frame di ring dan baris; node tidak dibuat ulang saat refresh (`TOWER_REFRESH_FRAMES = 6`); 0 orphan node.
- `PresentationSettings.reduce_motion` berlaku untuk setiap kedip baru.
- Warna data (kompon, suhu, life, sektor) tidak pernah ikut warna tim; chrome ikut `style.accent`, `style.on_accent`, `style.shadow`.
- Ambang merah tyre life = `1.0 - GtTypes.TYRE_CLIFF_WEAR` (0,25), sama dengan gauge TYRE LIFE di deck (perubahan dari spec awal 0,3; spec diamandemen di Task 3).
- Tes ditulis dan **dilihat gagal** terhadap kode lama sebelum implementasi (aturan repo).
- Staging per path, dilarang `git add -A` / `git add .`. Commit hanya bila developer meminta; langkah "Checkpoint" hanya menyiapkan daftar path.
- Probe/capture sementara di `temp/`, bukan `scratch/`.

## Review Focus

1. Mobil rival di-follow saat mobil deck masuk pit, DNF, atau selesai: telemetri tetap di mobil deck, tidak lompat ke rival. (Task 1)
2. Entry tanpa `tyre_life`/`team_id` (dikirim `PitWallDashboard` lama dari `RaceSimEngine`): baris menggambar ring penuh dan penanda netral, tanpa error. (Task 5)
3. Warna tim sangat terang (`#E2E8F0`), hampir crimson (`#FF1E56`), dan sangat gelap (`#1E3A8A`): teks slab ink atau putih menurut luminansi, bayangan jadi cyan di dekat crimson, penanda tim gelap diberi outline. (Task 5, 6, 7)
4. Baris PIT / PEN / DNF / FIN: ketiga angka slab dan nilai kolom ringkas memakai teks status yang sama pada ketiga state Tab. (Task 7)
5. Tyre life di batas: `wear` 0 → 16 tick menyala, `wear` ≥ 1 → 0 tick, life 0,01 → 1 tick, life tepat 0,25 → CRIMSON dan 0,26 → LIME; `followed_id` yang tidak ada di klasemen → tidak ada slab dan tidak crash. (Task 3, 6)

---

## File Structure

| File | Peran |
|---|---|
| `scripts/hud/tyre_life_ring.gd` (baru) | `TyreLifeRing`: kontrol ring + statik `life_of`, `tint_for`, `lit_ticks` |
| `scripts/ui/driver_row.gd`, `scenes/pit_wall/driver_row.tscn` | Baris ringkas dan mode slab, penanda tim, bar sektor |
| `scripts/ui/timing_tower.gd`, `scenes/pit_wall/timing_tower.tscn` | Chrome ber-style, tinggi baris, satu slab |
| `scripts/hud/race_hud.gd` | Telemetri dari mobil deck, `style` ke tower, `slab_texts`, kunci entry |
| `scripts/gt/gt_race.gd` | `standings_entries()` +3 kunci |
| `scripts/hud/telemetry_painter.gd` | `_tyre()` menjadi roda tick |
| `tests/test_live_timing_slab.gd` (baru) | Semua tes fitur ini |
| `tests/test_race_hud.gd` | Dua assertion yang membaca `_compound` diperbarui |

Suite baru menambah hitungan (93 → 94); irisan di `AGENTS.md` bagian 10 diperbarui di Task 8.

---

### Task 1: Telemetri mengikuti mobil deck

**Files:**
- Create: `tests/test_live_timing_slab.gd`
- Modify: `scripts/hud/race_hud.gd:752-757` (`_update_panels`)

**Interfaces:**
- Produces: `tests/test_live_timing_slab.gd` dengan kerangka `check(ok, description)` dan `_run()` yang meniru `tests/test_race_hud.gd:21-65` (world `race_weekend_world.tscn`, `hud`, `race`, `mine: Array[GtCar]`, `_row_of(car_id)`); Task berikutnya menambah fungsi `_test_*` ke suite ini.

- [ ] **Step 1: Tulis tes `_test_telemetry_follows_deck_car`**: jadikan `race.cars[5]` (bukan tim player) sebagai `world.followed_id`, panggil `hud.refresh_all()`; assert `hud.drawer.state.header_text.contains(mine[0].code)` dan `not hud.drawer.state.header_text.contains(rival.code)`. Lalu pilih tab deck kedua (cara menekan tab: lihat `tests/test_race_hud.gd:170-185`), `refresh_all()`, assert header memuat `mine[1].code`. Lalu paksa `mine[0].is_dnf = true` sambil rival di-follow, assert header tidak berganti ke rival.
- [ ] **Step 2: Jalankan merah:** `powershell -File tools/run_tests.ps1 -Filter live_timing` → Expected: `failing: 1` dengan `[FAIL] telemetry: ...` karena header memuat kode rival.
- [ ] **Step 3: Ubah `_update_panels`** agar `drawer.show_car` dipanggil dengan `race.get_car(deck.deck_car_id)` (bukan `followed`), tetap hanya bila `drawer.visible` dan mobilnya ada. Blok yang mengisi `deck.deck_car_id` dari `followed` bila `followed.team_id == race.player_team_id` dipertahankan dan dijalankan lebih dulu.
- [ ] **Step 4: Jalankan hijau:** `-Filter live_timing` lalu `-Filter race_hud` → Expected: `failing: 0` untuk keduanya (tes lama `_test_drawer` tetap hijau karena mobil follow dan deck sama).
- [ ] **Step 5: Checkpoint:** stage `tests/test_live_timing_slab.gd scripts/hud/race_hud.gd`.

---

### Task 2: Klasemen membawa tyre life, umur, stop

**Files:**
- Modify: `scripts/gt/gt_race.gd:247-267` (`standings_entries`)
- Test: `tests/test_live_timing_slab.gd`

**Interfaces:**
- Produces: tiga kunci di setiap entry: `"tyre_life": float` (0..1), `"tyre_age_laps": int`, `"stops": int`.

- [ ] **Step 1: Tes `_test_entries_carry_tyre_life`**: set `mine[0].wear = 0.3`, `tyre_age_laps = 7`, `stops = 2`; ambil `race.standings_entries()`, cari entry `car_id == mine[0].id`; assert `is_equal_approx(entry["tyre_life"], 0.7)`, `entry["tyre_age_laps"] == 7`, `entry["stops"] == 2`. Set `wear = 1.4` → `tyre_life == 0.0`; `wear = -0.1` → `1.0`.
- [ ] **Step 2: Merah** (`-Filter live_timing`) → `[FAIL] entries: ...` (kunci tidak ada).
- [ ] **Step 3: Tambah ketiga kunci** ke dictionary entry; `tyre_life` = `TyreLifeRing.life_of(car.wear)` setelah Task 3, sementara `clampf(1.0 - car.wear, 0.0, 1.0)` — gunakan ekspresi itu langsung dan ganti ke `life_of` di Task 3 Step 5.
- [ ] **Step 4: Hijau** `-Filter live_timing` dan `-Filter gt_sim`.
- [ ] **Step 5: Checkpoint:** stage `scripts/gt/gt_race.gd tests/test_live_timing_slab.gd`.

---

### Task 3: `TyreLifeRing` dan ambang life bersama

**Files:**
- Create: `scripts/hud/tyre_life_ring.gd`
- Modify: `scripts/gt/gt_race.gd` (pakai `life_of`), `docs/superpowers/specs/2026-11-05-live-timing-slab-design.md` (§4.2 dan §4.5: 0,3 → `1.0 - GtTypes.TYRE_CLIFF_WEAR`, alasan: sama dengan gauge deck)
- Test: `tests/test_live_timing_slab.gd`

**Interfaces:**
- Produces:
  - `class_name TyreLifeRing extends Control`
  - `static func life_of(wear: float) -> float` (= `clampf(1.0 - wear, 0.0, 1.0)`)
  - `static func tint_for(life: float) -> Color` (`T.ACCENT_ANIME_CRIMSON` bila `life <= 1.0 - GtTypes.TYRE_CLIFF_WEAR`, selain itu `T.ACCENT_ACID_LIME`)
  - `static func lit_ticks(life: float, total: int) -> int` (`ceili(clampf(life, 0.0, 1.0) * total - 0.0001)`)
  - `var life: float`, `var letter: String`, `var letter_color: Color`
  - `func set_tyre(p_life: float, p_letter: String, p_letter_color: Color) -> void` (hanya `queue_redraw()` bila ada perubahan)
  - `_init(size_px: float = 22.0)` mengatur `custom_minimum_size` dan `mouse_filter = MOUSE_FILTER_IGNORE`

- [ ] **Step 1: Tes `_test_tyre_life_ring_rules`**: `lit_ticks(1.0, 16) == 16`, `lit_ticks(0.0, 16) == 0`, `lit_ticks(0.01, 16) == 1`, `lit_ticks(0.5, 16) == 8`; `tint_for(0.25) == T.ACCENT_ANIME_CRIMSON`, `tint_for(0.26) == T.ACCENT_ACID_LIME`; `life_of(1.4) == 0.0`, `life_of(-0.1) == 1.0`; `set_tyre(0.5, "S", color)` lalu `ring.life == 0.5 and ring.letter == "S"`; memanggil `set_tyre` dengan nilai sama tidak menaikkan penghitung redraw (tambahkan `var draw_count: int` yang bertambah di `_draw`, pola sama dengan `TelemetryDrawer.draw_count`).
- [ ] **Step 2: Merah** → parse error / `[FAIL]` karena kelas belum ada.
- [ ] **Step 3: Buat `tyre_life_ring.gd`** sesuai Interfaces. `_draw`: lingkaran `T.SURFACE_PANEL_DARK`, trek abu `Color("#242a38")`, busur `life` dari jam 12 dengan `tint_for(life)` memakai `draw_arc`, huruf kompon di tengah (font `UI.MONO`, ukuran ≈ 42% diameter, warna `letter_color`). Ketebalan busur 3 px (diameter ≤ 30) atau 4 px.
- [ ] **Step 4: Hijau** `-Filter live_timing`.
- [ ] **Step 5:** `standings_entries` memakai `TyreLifeRing.life_of(car.wear)`; amandemen spec §4.2/§4.5. Hijau `-Filter live_timing`.
- [ ] **Step 6: Checkpoint:** stage `scripts/hud/tyre_life_ring.gd scripts/hud/tyre_life_ring.gd.uid scripts/gt/gt_race.gd docs/superpowers/specs/2026-11-05-live-timing-slab-design.md tests/test_live_timing_slab.gd`.

---

### Task 4: Roda tick di telemetri

**Files:**
- Modify: `scripts/hud/telemetry_painter.gd:276-316` (`_tyre`)
- Test: `tests/test_hud_theme_and_telemetry.gd` (probe painter lama dipertahankan), `tests/test_live_timing_slab.gd`

**Interfaces:**
- Consumes: `TyreLifeRing.tint_for(life)`, `TyreLifeRing.lit_ticks(life, total)` (Task 3); `state.tread`, `state.heat_tint[index]`, `state.heat[index]`.
- Produces: `static func wheel_ticks() -> int` di `TelemetryPainter` (konstanta 16) supaya tes menyatakan jumlah tick yang sama dengan painter.

- [ ] **Step 1: Tes `_test_painter_wheel_uses_shared_rules`**: `TelemetryPainter.wheel_ticks() == 16`; buat `TelemetryState`, isi dari mobil dengan `wear = 0.3` (`state.update(car, race.laps)`), assert `TyreLifeRing.lit_ticks(state.tread, TelemetryPainter.wheel_ticks()) == 12`; dan warna hub: `state.heat_tint[0]` tetap `T.ACCENT_ACID_LIME` untuk `wheel_temp[0] = 90` meski `style.set_accent(...)` ke warna tim lain (warna suhu tidak ikut tim).
- [ ] **Step 2: Merah** (`wheel_ticks` belum ada).
- [ ] **Step 3: Tulis ulang `_tyre`** sesuai spec §4.5: pusat roda digeser 8 px menjauhi sumbu mobil (kiri `center_x - 8`, kanan `center_x + 8`) agar brake disc di `center_x ± 14/18` tetap terlihat; cincin 16 tick (garis 3 px, panjang 6 px, jari-jari luar 22) dengan `lit_ticks` menyala `tint_for(state.tread)` dan sisanya `WELL`; cakram dalam `INK`, 5 spoke + hub warna `state.heat_tint[index]` (kedip alpha bila `temp > 125` dan bukan `reduce_motion`, sama seperti logika sekarang); label sisi luar: baris 1 `"FL 82%"` (kode `WHEEL_CODE[index]` + persen `roundi(state.tread * 100)`, ukuran 11, `MUTED`), baris 2 suhu `"%d°"` ukuran 17 berwarna `tint`. Dipertahankan: glow suhu, garis blister, silang ban pecah, brake disc. Dibuang: sumur panas dan enam blok.
- [ ] **Step 4: Hijau:** `-Filter live_timing`, `-Filter hud_theme` (probe painter menggambar pecah/blister/panas/normal dengan dan tanpa `reduce_motion`: harus tetap hijau).
- [ ] **Step 5: Capture cepat** (`temp/capture_live_timing.gd`, native `--rendering-driver d3d12 --resolution 1920x1080`): simpan `temp/tel_wheels.png`; periksa bahwa empat roda, brake disc, dan label tidak saling menutup. Jika perlu, setel offset label di sini dan catat nilai akhir di laporan.
- [ ] **Step 6: Checkpoint:** stage `scripts/hud/telemetry_painter.gd tests/test_live_timing_slab.gd`.

---

### Task 5: Baris ringkas: ring, penanda tim, bar sektor

**Files:**
- Modify: `scripts/ui/driver_row.gd`, `scenes/pit_wall/driver_row.tscn`, `tests/test_race_hud.gd:130` (ganti `leader_row._compound.text == ...` dengan `leader_row._ring.letter == GtTypes.COMPOUND_LABEL[leader.compound]`)
- Test: `tests/test_live_timing_slab.gd`, `tests/test_pit_wall.gd` (harus tetap hijau)

**Interfaces:**
- Consumes: `TyreLifeRing` (Task 3); `Liveries.color_for(team_id)` (`scripts/car/team_liveries.gd:13`); entry kunci Task 2.
- Produces di `DriverRow`:
  - `const ROW_H_COMPACT: float = 30.0`, `const ROW_H_SLAB: float = 100.0`
  - `var style: GarageStyleScript` (di-assign sebelum `_ready`; `null` → `GarageStyleScript.new()` default lime)
  - `var _ring: TyreLifeRing` (menggantikan Label `_compound`); label `_pos`, `_driver`, `_interval` tetap dan tetap selalu diisi `update_entry`
  - `static func contrast_ratio(a: Color, b: Color) -> float` (rumus WCAG, luminansi linear)
  - `static func team_mark_needs_outline(team_color: Color) -> bool` (`contrast_ratio(team_color, T.SURFACE_PANEL_DARK) < 3.0`)
  - `class SectorBars extends Control` dengan `static func height_of(sector_color: int) -> float` (fraksi: PURPLE 1.0, GREEN 0.7, YELLOW 0.4, NONE 0.15, indeks `GtTypes.SectorColor`)

- [ ] **Step 1: Tes** `_test_row_compact`: (a) `DriverRow.team_mark_needs_outline(Color("#1E3A8A")) == true` dan `(Color("#CCFF00")) == false`; (b) `SectorBars.height_of(GtTypes.SectorColor.PURPLE) > height_of(GREEN) > height_of(YELLOW) > height_of(NONE)`; (c) baris tower nyata: `_row_of(leader.id)._ring.life` sama dengan `1.0 - leader.wear`, dan `_ring.letter == GtTypes.COMPOUND_LABEL[leader.compound]`; (d) entry minimal `{car_id: 1, position: 3}` tanpa `tyre_life`/`team_id` → `update_entry` tidak error, `_ring.life == 1.0`; (e) tinggi baris ringkas `custom_minimum_size.y == DriverRow.ROW_H_COMPACT`.
- [ ] **Step 2: Merah.**
- [ ] **Step 3: Implementasi** sesuai Interfaces. Layout ringkas mengikuti preview: posisi, nomor (warna livery bila mobil tim player, selain itu `T.TEXT_MUTED`), kode (sudah berisi `*` untuk tim player), nilai kolom, penanda tim 14×6 px berwarna livery (beri outline 1 px `T.TEXT_PRIMARY` bila `team_mark_needs_outline`), ring 22 px di kanan. `_compound` dan `COMPOUND_LETTERS` diganti `_ring.set_tyre(entry.get("tyre_life", 1.0), letter, color)` dengan huruf/warna dari `compound_letter`/`compound_color` bila ada. Tombol/hover/fokus tetap memakai `_lit`; gaya lit ringkas = wash putih 5% plus garis kiri 3 px `style.accent` (bukan invert lime).
- [ ] **Step 4: Hijau:** `-Filter live_timing`, `-Filter race_hud`, `-Filter pit_wall`, `-Filter weather_and_ai`.
- [ ] **Step 5: Checkpoint:** stage `scripts/ui/driver_row.gd scenes/pit_wall/driver_row.tscn tests/test_race_hud.gd tests/test_live_timing_slab.gd`.

---

### Task 6: Mode slab dan chrome tower ber-style

**Files:**
- Modify: `scripts/ui/driver_row.gd`, `scripts/ui/timing_tower.gd`, `scenes/pit_wall/timing_tower.tscn`
- Test: `tests/test_live_timing_slab.gd`

**Interfaces:**
- Consumes: entry kunci Task 2 plus `slab_int`, `slab_gap`, `slab_last` (String, diisi Task 7; entry tanpa kunci ini → slab menampilkan `"--"`), `sector_colors: Array[int]`, `last_lap_time`, `drs`.
- Produces di `DriverRow`: `var expanded: bool`; `func set_expanded(on: bool) -> void` (mengubah `custom_minimum_size.y` antara `ROW_H_COMPACT`/`ROW_H_SLAB`, menampilkan/menyembunyikan node slab); `set_selected(active)` memanggil `set_expanded(active)`; `var slab_style: StyleBoxFlat` (didaftarkan lewat `style.face(...)` dan `style.shade(...)`); label slab didaftarkan `style.tint(label, "font_color", "on")`.
- Produces di `TimingTower`: `var style: GarageStyleScript` (di-assign sebelum `_ready`, diteruskan ke tiap `row.style`); chrome: bingkai 3 px `style.border(...)`, bayangan keras 5 px `style.shade(...)`, header "LIVE TIMING" berwarna `style.tint(...)` dengan garis bawah 3 px accent.

- [ ] **Step 1: Tes** `_test_slab_layout`: (a) tepat satu baris `expanded` dan `row.car_id == world.followed_id`; (b) klik baris lain (`row._activate()` lalu `hud.refresh_all()`) memindahkan slab: baris lama `expanded == false`, baris baru `true`; (c) setelah `await process_frame`: `rows_box.get_combined_minimum_size().y <= rows_scroll.size.y` (`$Body/RowsScroll/Rows` dan `$Body/RowsScroll`) dan `hud.tower.size.x == 320.0`, `Rect2(hud.tower.position, hud.tower.size).end.x <= RaceHud.RADIO_DOCK.position.x`; (d) `world.followed_id = -999` → `hud.refresh_all()` tanpa error dan nol baris `expanded`; (e) `clear_selection()` pada tower menurunkan semua slab.
- [ ] **Step 2: Merah.**
- [ ] **Step 3: Implementasi slab** sesuai spec §4.1: latar `slab_style.bg_color = style.accent`, bayangan keras offset 4 px `style.shadow`, isi: posisi besar, plat nomor (latar `style.on_accent`, teks `style.accent`), kode, nilai kolom aktif (`_interval.text`), ring 46 px di lingkaran `T.SURFACE_PANEL_DARK`, tiga baris INT/GAP/LAST dari `slab_*`, AGE `tyre_age_laps` dan STOPS `stops` dan DRS bila `drs`, tiga `SectorBars` dari `sector_colors` (hijau `T.ACCENT_ACID_LIME`, ungu `T.ACCENT_PURPLE_SECTOR`, kuning `T.ACCENT_CYBER_YELLOW`, kosong `T.TEXT_MUTED`). Snap tanpa animasi. Pita `Tick` + `Ticker` lama dihapus dari tampilan; `_sector_text()` dipertahankan dan hasil non-kosong (hanya dari `PitWallDashboard`) ditampilkan sebagai satu baris kecil di slab.
- [ ] **Step 4: Chrome tower** sesuai Interfaces. Label kolom nilai (`Body/ColHeader/Int`, path dipakai `RaceHud._tower_column`) dan label kolom tyre (teks `T` menjadi `TYRE`) tetap di path yang sama; label kolom nilai diwarnai `style.tint(..., "font_color")` dan tebal. Tower tanpa `style` (PitWallDashboard; winning scene tidak memakai scene ini) memakai `GarageStyleScript.new()` default.
- [ ] **Step 5: Hijau:** `-Filter live_timing`, `-Filter race_hud`, `-Filter pit_wall`, `-Filter weather_and_ai`.
- [ ] **Step 6: Checkpoint:** stage file di atas plus `tests/test_live_timing_slab.gd`.

---

### Task 7: Wiring `RaceHud`: style, teks slab, repaint warna tim

**Files:**
- Modify: `scripts/hud/race_hud.gd` (`_build_tower_and_radar`, `_update_tower`, `_tower_right_text`)
- Test: `tests/test_live_timing_slab.gd`

**Interfaces:**
- Consumes: `DriverRow.slab_style`, `TimingTower.style` (Task 6); `RaceHud.lap_text(seconds: float) -> String` (sudah ada).
- Produces: `static func slab_texts(entry: Dictionary) -> Dictionary` di `RaceHud` → `{"int": String, "gap": String, "last": String}`: DNF → `"DNF"`×3, selesai → `"FIN"`×3, `penalty_hold_s > 0` → `"PEN %.1f"`×3, `in_pit` → `"PIT"`×3, peringkat 1 → `"LEAD"` untuk int dan gap, selain itu `"+%.1f"` dari `interval_s`/`gap_s`; `last` selalu `lap_text(last_lap_time)` kecuali status. `_update_tower` menulis ketiganya ke `entry["slab_int"|"slab_gap"|"slab_last"]`.

- [ ] **Step 1: Tes `_test_slab_texts_and_team_colour`**: (a) `RaceHud.slab_texts` untuk entry leader, entry mid-field, `is_dnf`, `is_finished`, `in_pit`, `penalty_hold_s = 4.2` (nilai persis di atas, termasuk `"PEN 4.2"`); (b) `hud.tower.style == hud.style`; (c) `hud.set_team_accent(7)` (palet `#F4F5F7`) → `row.slab_style.bg_color == Liveries.color_for(7)`, label slab `get_theme_color("font_color") == hud.style.on_accent` dan `on_accent == T.INK_BORDER_BLACK`; `hud.set_team_accent(2)` (`#FF1E56`, hampir crimson) → `row.slab_style.shadow_color == hud.style.shadow` dan bukan crimson; `hud.set_team_accent(11)` (`#1E3A8A`) → `on_accent == Color.WHITE`; (d) warna data tidak berubah: `TyreLifeRing.tint_for(0.5) == T.ACCENT_ACID_LIME` sebelum dan sesudah `set_team_accent`.
- [ ] **Step 2: Merah.**
- [ ] **Step 3: Implementasi:** di `_build_tower_and_radar` set `tower.style = style` setelah `instantiate()` dan sebelum `stage.add_child(tower)`; tambah `slab_texts` dan penulisan kunci di `_update_tower`. Tidak ada penanganan repaint tambahan: widget terdaftar di `style`.
- [ ] **Step 4: Hijau:** `-Filter live_timing`, `-Filter race_hud`.
- [ ] **Step 5: Checkpoint:** stage `scripts/hud/race_hud.gd tests/test_live_timing_slab.gd`.

---

### Task 8: Regresi, smoke native, bukti, dokumentasi

**Files:**
- Modify: `AGENTS.md` (irisan suite bagian 10: 93 → 94 suite), `ROADMAP.md` (entri Fase 29), `todo.md`
- Create: `executor-report/reports/FASE-29-LIVE-TIMING-SLAB-REPORT.md`, `executor-report/screenshots/phases/phase-29-live-timing-slab/*.png`

- [ ] **Step 1: Suite HUD dan terkait:** `powershell -File tools/run_tests.ps1 -Filter hud` dan `-Filter pit` dan `-Filter live_timing` → Expected: `failing: 0` pada ketiganya.
- [ ] **Step 2: Suite penuh per irisan** (latar depan, tiap irisan < 10 menit, sesuai AGENTS bagian 10): `-From 0 -To 19`, `20 -To 39`, `40 -To 59`, `60 -To 74`, `75 -To 93` → Expected: `failing: 0` pada tiap irisan.
- [ ] **Step 3: Smoke native** balapan 3 lap, 20 mobil: `godot --rendering-driver d3d12 --resolution 1920x1080 --path . scenes/main.tscn`; klik rival di tower (telemetri tidak berubah), `N` dan tab deck (telemetri ikut), `Tab` tiga kali (INT, GAP, LAST), `T` lipat drawer; catat FPS (target 60) dan orphan node saat kembali ke menu. Jika native tidak bisa dijalankan di sesi ini, tulis "belum diverifikasi" di laporan.
- [ ] **Step 4: Capture 1080p** (`temp/capture_live_timing.gd`, hasil disalin ke `executor-report/screenshots/phases/phase-29-live-timing-slab/`): tim lime, tim terang `#F4F5F7`, tim hampir crimson `#FF1E56`, tim gelap `#1E3A8A`; rival diklik; ganti driver deck; ban panas; ban di bawah cliff; baris PIT/DNF.
- [ ] **Step 5: Laporan, `ROADMAP.md`, `todo.md`, `AGENTS.md`**: laporan memuat hasil tes, angka FPS, daftar file yang sengaja tidak di-commit (`.uid` tak terkait, `temp/`), keputusan builder (offset roda, ambang outline) dan item yang belum diverifikasi.
- [ ] **Step 6: Checkpoint akhir:** `git status -s` dan `git diff --ignore-cr-at-eol --stat`; stage per path; **tanyakan developer** sebelum commit, merge, atau push.
