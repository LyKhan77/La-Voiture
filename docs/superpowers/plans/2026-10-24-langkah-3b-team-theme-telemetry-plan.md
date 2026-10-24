# Langkah 3b — Tema Warna Tim + Telemetry Drawer (konsep F) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** HUD balapan memakai warna livery tim pemain sebagai aksen "kulit" (logo, marquee, header deck, drawer) dan drawer telemetry ditulis ulang menjadi konsep F: panel miring, hero mobil X-ray beranimasi, onomatope, caption narasi; tanpa mengubah warna makna data.

**Architecture:** Aksen datang dari `GarageStyle` yang sudah ada (aksen + warna teks di atas aksen + bayangan), satu instance dimiliki `RaceHud`. Drawer dipisah jadi data murni yang bisa diuji headless (`TelemetryState`) dan lapisan gambar (`TelemetryDrawer` + `TelemetryPainter`, semua lewat `_draw()`).

**Tech Stack:** Godot 4.7.2 stable, GDScript 2.0 (static typing wajib), test headless `SceneTree`.

**Spec:** `docs/superpowers/specs/2026-10-24-langkah-3-hud-redesign-v2-design.md` §4.1 (tema tim) dan §4.2 (drawer). Acuan visual dan geometri: `docs/design-refs/ui_step_5_layout.html` (fungsi `drawTele(c,dt,ty,lean)`, `speedPanel`, `gearPanel`, `heroPanel`, varian `lean=true`) dan `docs/design-refs/ui_step_3_telemetry_hybrid_bd.html` (`carXray`, `carPath`, `pedals`, `moodW`, `pulseW`). Mockup memakai kanvas HTML: port bentuk, koordinat, dan warna, bukan kodenya.

## Global Constraints

- Kotak HUD tidak berubah: drawer `pos (1598, 372)` `size (312, 496)`; deck, kartu, ribbon, tower, radar, marquee seperti `race_hud.gd` sekarang.
- Static typing wajib; tanpa dependensi baru; tanpa node per elemen animasi: seluruh drawer digambar di satu `_draw()`.
- Warna makna **tidak pernah** mengikuti aksen: panas ban (`TelemetryWidgets.tyre_tint`: cyan <70, lime ≤105, kuning ≤125, crimson di atas), throttle lime / brake crimson, ERS ungu `#D946EF`, status kritis crimson, gear kuning, DRS kuning/cyan.
- Warna aksen = `Liveries.color_for(race.player_team_id)` (`scripts/car/team_liveries.gd`). Teks di atas aksen dan bayangan memakai aturan `GarageStyle` yang sudah ada (`on_accent` ink/putih pada luminans 0.35; bayangan cyan bila aksen dekat crimson). Ruling dasar: mockup memakai ambang 0.3; kode proyek (0.35) menang.
- Warna engineer = komplementer otomatis: kandidat berurutan `#00F0FF`, `#FF007F`, `#CCFF00`, `#FFE600`; pilih yang pertama dengan selisih hue > 55° (0.1528) terhadap aksen; aksen tak berwarna (saturasi < 0.3) → `#00F0FF`. Dipakai kartu radio di 3e.
- Drawer menyimpan kontrak publik yang dipakai HUD: `show_car(car: GtCar, laps: int) -> void`, `visible` (tombol `T`), `static func temp_tint(temp: float) -> Color`.
- Tanpa menghapus file yang bukan buatan sesi ini: `scripts/hud/telemetry_widgets.gd` dan `scripts/hud/step_bar.gd` tetap di repo (hanya `TelemetryWidgets.tyre_tint` dan `PulseTrace.beat` yang masih dipanggil); status "kode mati" dicatat di laporan untuk keputusan pengguna.
- Test lama (28 suite) tetap hijau; `_test_drawer` di `tests/test_race_hud.gd` ditulis ulang di Task 4.
- Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; hanya `git add` file yang disebut di task (ada file untracked milik orang lain).

## Review Focus

1. Mengganti tim ke warna dekat crimson (`#FF1E56`) dan ke warna terang (`#F4F5F7`): teks di atas aksen tetap terbaca (ink vs putih) dan warna ban kritis tetap crimson serta panas ban tetap lime/kuning/cyan. (Task 2, 4)
2. Aksen tak berwarna (putih) memilih engineer cyan; aksen cyan memilih pink; aksen dekat cyan (biru, mint) memilih pink, bukan cyan yang nyaris sama. (Task 1)
3. Drawer menerima mobil yang berpindah (tab/`N`): jejak pedal, G, dan onomatope lama tidak ikut terbawa ke mobil baru. (Task 3)
4. Onomatope tidak menumpuk: paling banyak 2 aktif, yang tertua dibuang, dan hilang sendiri setelah 1.6 detik. (Task 3)
5. `show_car` dipanggil dengan mobil DNF, mobil di pit, atau `driver_*` bernilai ekstrem (stress 0, confidence 100, heart_rate sangat rendah): tidak error, caption tetap string valid. (Task 3)
6. Drawer disembunyikan (`T`) tidak memakan waktu gambar dan tidak mengumpulkan sampel basi saat tersembunyi lalu dimunculkan lagi. (Task 4)

## File Structure

- Modify `scripts/ui/manga/garage_style.gd` — `engineer` + `engineer_for()`.
- Modify `scripts/hud/race_hud.gd` — `style`, `logo_label`, marquee bar/teks berwarna aksen, `set_team_accent()`, perutean ke deck dan drawer.
- Modify `scripts/hud/tactical_deck.gd` — `set_accent()` pada header deck.
- Create `scripts/hud/telemetry_state.gd` — data drawer, jejak, onomatope, caption (tanpa node).
- Create `scripts/hud/telemetry_painter.gd` — fungsi gambar statis untuk panel F.
- Modify `scripts/hud/telemetry_drawer.gd` — ditulis ulang di atas dua file di atas.
- Create `tests/test_hud_theme_and_telemetry.gd` — suite baru.
- Modify `tests/test_race_hud.gd` — `_test_drawer` ditulis ulang.
- Create `executor-report/reports/FASE-11-LANGKAH-3B-TEAM-THEME-TELEMETRY-REPORT.md`, screenshot `executor-report/screenshots/phases/phase-11-langkah-3b-*.png`, `scratch/capture_langkah3b.gd`; modify `ROADMAP.md`.

---

### Task 1: Warna engineer di `GarageStyle`

**Files:**
- Modify: `scripts/ui/manga/garage_style.gd`
- Create: `tests/test_hud_theme_and_telemetry.gd`

**Interfaces:**
- Produces: `GarageStyle.PINK: Color = Color("#FF007F")`; `GarageStyle.ENGINEER_MIN_HUE_GAP: float = 55.0 / 360.0`; `static func engineer_for(accent: Color) -> Color`; `var engineer: Color` (diperbarui di `blend_accent`, berdasarkan `goal` seperti `shadow`).

- [ ] **Step 1: Buat kerangka suite dan test gagal**

  Salin harness dari `tests/test_pit_deck_and_radio.gd` (memuat `race_weekend_world.tscn`, masuk `GREEN_RACING`, `race.step_ticks(200)`, `hud.refresh_all()`, `quit` sesuai kegagalan) ke `tests/test_hud_theme_and_telemetry.gd`; judul suite `FASE 11 LANGKAH 3B TEAM THEME + TELEMETRY`. Tulis `_test_engineer_colour()` dengan asersi `GarageStyle.engineer_for(x) == y`: lime `#CCFF00` → `#00F0FF`; cyan `#00F0FF` → `#FF007F`; crimson `#FF1E56` → `#00F0FF`; kuning `#FFE600` → `#00F0FF`; ungu `#D946EF` → `#00F0FF`; oranye `#FF7A00` → `#00F0FF`; violet `#9B5CFF` → `#00F0FF`; biru `#3D7BFF` → `#FF007F`; mint `#00E08A` → `#FF007F`; putih `#F4F5F7` → `#00F0FF`. Pesan: "style: the engineer colour is the first of cyan / pink / lime / yellow at least 55 degrees of hue from the team accent (grey accents get cyan)". Tambah asersi pada instance: setelah `style.set_accent(Color("#3D7BFF"))` → `style.engineer == Color("#FF007F")`, dan `set_accent` kembali ke lime → cyan: "style: set_accent keeps engineer in step with the accent".

- [ ] **Step 2: Jalankan dan pastikan gagal**

  Run: `godot --headless --path . -s res://tests/test_hud_theme_and_telemetry.gd`
  Expected: gagal (parse error `engineer_for` tidak ada).

- [ ] **Step 3: Implementasi `engineer_for` dan `engineer`**

  Hue memakai `Color.h` (0..1); selisih sirkular `minf(absf(a-b), 1.0-absf(a-b))`; kandidat berurutan seperti Global Constraints; saturasi aksen < `MIN_SATURATION_FOR_HUE` → cyan. `blend_accent` mengisi `engineer = engineer_for(goal)`.

- [ ] **Step 4: Jalankan test**

  Run: `godot --headless --path . -s res://tests/test_hud_theme_and_telemetry.gd` dan `godot --headless --path . -s res://tests/test_garage_tyre_strategy.gd` (pemakai `GarageStyle`).
  Expected: keduanya PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/manga/garage_style.gd tests/test_hud_theme_and_telemetry.gd
git commit -m "feat(theme): engineer colour derived from the team accent"
```

---

### Task 2: Aksen tim di kulit HUD (logo, marquee, header deck)

**Files:**
- Modify: `scripts/hud/race_hud.gd` (`bind` baris ~96-134, `_build_ribbon` ~192-210, `_build_marquee` ~264-280), `scripts/hud/tactical_deck.gd` (`_init`, header)
- Test: `tests/test_hud_theme_and_telemetry.gd`

**Interfaces:**
- Consumes: `GarageStyle.set_accent/changed/accent/on_accent/shadow`, `Liveries.color_for(team_id)`.
- Produces: `RaceHud.style: GarageStyle`; `RaceHud.logo_label: Label`; `RaceHud.marquee_bar: ColorRect`; `RaceHud.marquee_texts: Array[Label]` (tag RACE CONTROL dan ticker); `func RaceHud.set_team_accent(team_id: int) -> void` (memanggil `style.set_accent(Liveries.color_for(team_id))`); `TacticalDeck.header_shape: ColorRect`, `TacticalDeck.header_title: Label`; `func TacticalDeck.set_accent(accent: Color, on_accent: Color) -> void` (shader param `fill_color` pada `header_shape.material` dan warna font `header_title`).

- [ ] **Step 1: Tulis test gagal `_test_hud_accent()`**

  Asersi (`team_id` pemain di world uji = 0, aksen lime):
  - `hud.style.accent == TeamLiveries.color_for(race.player_team_id)`; `hud.logo_label.get_theme_color("font_color") == hud.style.accent`; `hud.marquee_bar.color == hud.style.accent`; setiap `hud.marquee_texts[i].get_theme_color("font_color") == hud.style.on_accent`; `(hud.deck.header_shape.material as ShaderMaterial).get_shader_parameter("fill_color") == hud.style.accent`: "theme: the HUD skin starts in the player team's livery colour".
  - `hud.set_team_accent(2)` (crimson `#FF1E56`): `style.accent == Color("#FF1E56")`, `marquee_bar.color == Color("#FF1E56")`, `marquee_texts[0]` warna font `== Color.WHITE` (on_accent pada crimson), header deck mengikuti, `logo_label` mengikuti: "theme: switching to a crimson team repaints the skin and flips the type on it to white".
  - `hud.set_team_accent(7)` (putih `#F4F5F7`): `marquee_texts[0]` warna font `== T.INK_BORDER_BLACK`: "theme: a light team colour keeps ink type".
  - Semantik tetap: `RaceHud.burn_color(0.1) == T.ACCENT_ANIME_CRIMSON` dan `TelemetryDrawer.temp_tint(95.0) == T.ACCENT_ACID_LIME` setelah `set_team_accent(2)`: "theme: data colours do not follow the team colour".
  - Kembalikan `hud.set_team_accent(race.player_team_id)` di akhir.

- [ ] **Step 2: Jalankan dan pastikan gagal**

  Run: `godot --headless --path . -s res://tests/test_hud_theme_and_telemetry.gd`
  Expected: gagal (parse error `hud.style` / `marquee_bar` tidak ada).

- [ ] **Step 3: Implementasi**

  `RaceHud` memiliki `style := GarageStyle.new()`, dibuat sebelum `_build_ribbon`, diisi `set_accent(Liveries.color_for(race.player_team_id))` di `bind` dan disambungkan `style.changed.connect(_on_style_changed)`. `_on_style_changed` mengecat ulang: `logo_label` (override `font_color` = aksen), `marquee_bar.color` = aksen, setiap teks di `marquee_texts` (`font_color` = `style.on_accent`), dan memanggil `deck.set_accent(style.accent, style.on_accent)`. Simpan referensi node di `_build_ribbon`/`_build_marquee` (saat ini lokal). `TacticalDeck._init` menyimpan `header_shape = header.get_child(0)` dan `header_title = header.get_child(1)`; `set_accent` mengubah shader param dan warna font. Flag label, rate row, kartu saran, tower tidak disentuh di 3b (ranah 3c/3e).

- [ ] **Step 4: Jalankan test**

  Run: `godot --headless --path . -s res://tests/test_hud_theme_and_telemetry.gd` dan `godot --headless --path . -s res://tests/test_race_hud.gd`
  Expected: PASS keduanya.

- [ ] **Step 5: Commit**

```bash
git add scripts/hud/race_hud.gd scripts/hud/tactical_deck.gd tests/test_hud_theme_and_telemetry.gd
git commit -m "feat(theme): team accent skins the logo, marquee and deck header"
```

---

### Task 3: `TelemetryState` — data, jejak, onomatope, caption

**Files:**
- Create: `scripts/hud/telemetry_state.gd`
- Test: `tests/test_hud_theme_and_telemetry.gd`

**Interfaces:**
- Produces: `class_name TelemetryState extends RefCounted` dengan konstanta `PEDAL_SAMPLES: int = 96`, `G_TRAIL: int = 40`, `POP_LIFETIME_S: float = 1.6`, `MAX_POPS: int = 2`, `RPM_IDLE: float = 4000.0`, `RPM_LIMIT: float = 8800.0`; properti `car_id: int`, `header_text: String` (`"#%02d %s // LIVE 60Hz" % [number, code]`), `gear: int`, `speed_kmh: float`, `rpm: float` (0..1), `limiter: bool` (rpm > 0.96), `drs: int` (0 mati, 1 eligible, 2 aktif), `throttle` dan `brake: PackedFloat32Array` (panjang `PEDAL_SAMPLES`), `g_trail: Array[Vector2]` (`Vector2(lateral_g, longitudinal_g)`, paling banyak `G_TRAIL`), `heat: PackedFloat64Array` (4), `heat_tint: Array[Color]` (4, FL FR RL RR), `blown: int` (-1 bila tak ada), `tread: float` (0..1 umur tersisa = `1 - wear`), `blister: PackedFloat64Array`, `disc_temp: PackedFloat64Array`, `ers_mode: int`, `ers_charge: float` (0..1), `stress: float`, `confidence: float` (0..1), `heart_rate: float`, `damage: float` (0..1), `caption: String`, `pops: Array[Dictionary]` (`{"text": String, "kind": String, "born": float}`), `clock: float`; metode `func update(car: GtCar, laps: int) -> void`, `func advance(delta: float) -> void` (menambah `clock`, membuang pop yang `clock - born > POP_LIFETIME_S`), `static func caption_for(car: GtCar) -> String`.
- Onomatope (`kind` → `text`): `brake` "GUOOO!!", `shift` "KACHA!", `drs` "VWOOOM!", `tyre` "JIRI JIRI", `ers` "DON!!". Pemicu hanya pada tepi naik: brake > 0.55 (dari ≤ 0.55), gear naik, `drs_active` baru aktif, `wheel_temp[i] > 125` pertama kali pada ban itu, `ers_mode` baru `OVERTAKE`. Pop baru menyingkirkan yang tertua bila sudah `MAX_POPS`. Berganti `car.id` menghapus jejak, pop, dan memori tepi.
- Caption (prioritas, huruf besar): stress ≥ 80 → `HEART RACING — DRIVER AT THE LIMIT…`; ban terpanas > 125 → `<WHEEL> TYRE <n>°C — GRIP FADING AT THE REAR…` untuk RL/RR dan `… AT THE FRONT…` untuk FL/FR (`<WHEEL>` = `FL`/`FR`/`RL`/`RR`, `<n>` dibulatkan); ERS OVERTAKE → `OVERTAKE DEPLOYED — ALL ENERGY, ALL IN!`; brake > 0.5 → `HARD ON THE BRAKES — DISCS GLOWING…`; DRS aktif → `DRS OPEN — FULL SEND DOWN THE STRAIGHT.`; selain itu `CLEAN LAP. PACE STEADY, TYRES IN THE WINDOW.`

- [ ] **Step 1: Tulis test gagal `_test_telemetry_state()`**

  Siapkan mobil uji `mine[0]` seperti test drawer lama: `v = 70.0` (252 km/jam), `gear = 5`, `rpm = 8800.0`, `drs_active = true`, `throttle = 1.0`, `brake = 0.0`, `lateral_g = 2.4`, `longitudinal_g = -1.5`, `is_punctured = true` dengan `punctured_wheel = Wheel.FL`, `wheel_temp[1] = 140.0`, `wheel_blister_pct = [0, 40, 0, 0]`, `ers_mode = OVERTAKE`, `ers_battery = 55.0`, `driver_stress = 80.0`, `driver_confidence = 30.0`. Buat `var s := TelemetryState.new()`; `s.update(car, race.laps)`; asersi:
  - `s.gear == 5`, `roundi(s.speed_kmh) == 252`, `is_equal_approx(s.rpm, 1.0)`, `s.limiter`, `s.drs == 2`, `s.header_text.contains(car.code)`: "telemetry state: gear, speed, shift lights and DRS mirror the car".
  - `s.throttle[s.throttle.size() - 1] == 1.0`, `s.brake[s.brake.size() - 1] == 0.0`, `s.g_trail[s.g_trail.size() - 1] == Vector2(2.4, -1.5)`: "telemetry state: pedal and G traces record the live sample".
  - `s.blown == GtTypes.Wheel.FL`, `s.heat_tint[0] == T.ACCENT_ANIME_CRIMSON` (ban meletus), `s.heat_tint[1] == T.ACCENT_ANIME_CRIMSON` (140 °C), `s.heat_tint[3] == T.ACCENT_ACID_LIME`, `s.blister[1] == 40.0`: "telemetry state: blown and overheated tyres are crimson, a healthy one lime, blister flag carried".
  - `s.ers_mode == GtTypes.ErsMode.OVERTAKE`, `is_equal_approx(s.ers_charge, 0.55)`, `is_equal_approx(s.stress, 0.8)`, `is_equal_approx(s.confidence, 0.3)`: "telemetry state: ERS charge, stress and confidence are 0..1".
  - Rival: `s.update(rival, race.laps)` → `s.g_trail.size() == 1` dan `s.pops.is_empty()`: "telemetry state: another car starts with fresh traces and no pops".
  - Pop: mobil baru bersih (`brake = 0.0`, `gear = 4`, `drs_active = false`, `ers_mode = NEUTRAL`, panas ban 90): `update`; set `brake = 0.9`; `update` → `pops` memuat `kind == "brake"` dengan teks "GUOOO!!"; `update` lagi dengan `brake` tetap 0.9 → jumlah pop `brake` tetap 1 (hanya tepi naik); `gear = 5`, `update` → ada pop "KACHA!" dan `pops.size() == 2`; `drs_active = true`, `update` → `pops.size() == 2` dan pop "GUOOO!!" (tertua) hilang, "VWOOOM!" ada: "telemetry state: onomatopoeia fire on rising edges only and at most two live".
  - `s.advance(1.0)`: pop masih ada; `s.advance(1.0)` lagi (total 2.0 s): `pops.is_empty()`: "telemetry state: onomatopoeia expire after 1.6 s".
  - Caption: `TelemetryState.caption_for(car)` untuk lima keadaan (stress 90; `wheel_temp[2] = 134` dengan stress rendah → berisi `RL TYRE 134°C` dan `AT THE REAR`; OVERTAKE; brake 0.8; DRS aktif; bersih) sesuai daftar di Interfaces: "telemetry state: the caption follows the situation by priority".
  - Ketahanan: `car.is_dnf = true` dan `car.driver_stress = 0.0`, `driver_confidence = 100.0`, `driver_heart_rate = 20.0` → `s.update(car, race.laps)` tidak error, `s.caption != ""`, `s.heart_rate >= 0.0`: "telemetry state: a DNF car and extreme driver values still give a valid view". Kembalikan semua field mobil uji ke nilai awal di akhir test.

- [ ] **Step 2: Jalankan dan pastikan gagal**

  Run: `godot --headless --path . -s res://tests/test_hud_theme_and_telemetry.gd`
  Expected: gagal (parse error `TelemetryState` tidak ada).

- [ ] **Step 3: Implementasi `TelemetryState`**

  Port logika `S`/`story`/`fx` dari mockup (`ui_step_3_telemetry_hybrid_bd.html`) ke data nyata `GtCar` (nama field di `gt_car.gd`; `lateral_g`, `longitudinal_g`, `wheel_temp`, `wheel_brake_temp`, `wheel_blister_pct`, `driver_*`, `damage`, `ers_*`, `drs_*`, `gear`, `rpm`, `punctured_wheel`). Pedal/G memakai `remove_at(0)` + `append` seperti widget lama. `heat_tint` lewat `TelemetryWidgets.tyre_tint` (merah bila `blown`).

- [ ] **Step 4: Jalankan test**

  Run: `godot --headless --path . -s res://tests/test_hud_theme_and_telemetry.gd`
  Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/hud/telemetry_state.gd tests/test_hud_theme_and_telemetry.gd
git commit -m "feat(telemetry): TelemetryState with traces, onomatopoeia and caption"
```

---

### Task 4: Drawer F: `TelemetryPainter` dan `TelemetryDrawer` ditulis ulang

**Files:**
- Create: `scripts/hud/telemetry_painter.gd`
- Modify: `scripts/hud/telemetry_drawer.gd` (ditulis ulang), `scripts/hud/race_hud.gd` (menyambungkan `drawer.style`)
- Modify: `tests/test_race_hud.gd` (`_test_drawer`, baris ~242-299)
- Test: `tests/test_hud_theme_and_telemetry.gd`

**Interfaces:**
- Consumes: `TelemetryState` (Task 3), `GarageStyle` (aksen, `on_accent`), `TelemetryWidgets.tyre_tint`, `TelemetryWidgets.PulseTrace.beat`.
- Produces: `class_name TelemetryPainter extends RefCounted` dengan fungsi statis menggambar ke `CanvasItem` (`canvas: CanvasItem`): `paint(canvas, state, accent, on_accent, clock, reduce_motion)` dan sub-fungsi panel (`speed_panel`, `gear_panel`, `hero_panel`, `pedal_panel`, `driver_panel`, `caption_panel`, `pops`); `class TelemetryDrawer extends Control` dengan `style: GarageStyle` (disetel `RaceHud`), `state: TelemetryState`, `draw_count: int` (naik tiap `_draw`), `func accent_color() -> Color` (= `style.accent`, atau lime bila `style == null`), `show_car(car, laps)` (memanggil `state.update`, `queue_redraw`), `_process(delta)` (hanya bila `is_visible_in_tree()`: `state.advance(delta)`, `queue_redraw()`), `static func temp_tint(temp: float) -> Color` (tetap), `static func heartbeat(phase: float) -> float` (mendelegasikan ke `TelemetryWidgets.PulseTrace.beat`).
- Geometri (koordinat dalam kotak 312×496, mengikuti varian `lean` mockup): bingkai gelap dengan garis aksen 1 px dan gutter `mix(#151b29, aksen, 0.07)`; tag judul miring aksen di (8,6) 130×26 dengan teks "TELEMETRY" (ink/putih = `on_accent`), teks `state.header_text` rata kanan di (302,24); panel speed poligon (8,38)-(192,38)-(180,118)-(8,118); panel gear (214,38)-(304,38)-(304,118)-(202,118) (tepi kuning, ungu saat `limiter`); hero (8,122) 296×256; pedal (8,382) 296×36; panel driver (8,422) 296×34; caption (8,460) 296×30. Semua tepi panel: ink 3 px + garis aksen 1 px.

- [ ] **Step 1: Tulis test gagal**

  Di suite baru, `_test_drawer_theme_and_draw()` (async: pakai `await process_frame`):
  - `hud.drawer.size == Vector2(312.0, 496.0)` dan `hud.drawer.position == Vector2(1598.0, 372.0)`: "drawer: the layout box is unchanged".
  - Setelah `hud.refresh_all()` dan satu `await process_frame`: `hud.drawer.draw_count > 0`; setelah tombol `T` dua kali drawer tampil lagi dan `draw_count` naik; selama tersembunyi (`KEY_T` sekali, `await process_frame` dua kali) `draw_count` tidak bertambah: "drawer: it draws while visible and sleeps while hidden".
  - `hud.drawer.accent_color() == hud.style.accent`; setelah `hud.set_team_accent(2)` → `Color("#FF1E56")`; kembalikan: "drawer: the skin follows the team accent".
  - Semantik: setelah `set_team_accent(2)` → `TelemetryDrawer.temp_tint(60.0) == T.ACCENT_ELECTRIC_CYAN`, `temp_tint(95.0) == T.ACCENT_ACID_LIME`, `temp_tint(118.0) == T.ACCENT_CYBER_YELLOW`, `temp_tint(130.0) == T.ACCENT_ANIME_CRIMSON` dan `hud.drawer.state.heat_tint[3] == T.ACCENT_ACID_LIME`: "drawer: tyre heat colours stay fixed whatever the team colour".
  - Tab ke mobil lain: `hud.drawer.show_car(rival, race.laps)` → `state.g_trail.size() == 1` lalu mobil semula; `KEY_T` menyembunyikan dan menampilkan lagi (`visible`): "drawer: another car starts with fresh traces, T hides and shows the drawer".
  - `TelemetryDrawer.heartbeat(0.35) > 0.9`, `absf(heartbeat(0.0)) < 0.001`, `heartbeat(0.66) > 0.2`: "drawer: the heartbeat trace keeps its QRS spike and T wave".

  Di `tests/test_race_hud.gd`, tulis ulang `_test_drawer`: pertahankan penyiapan mobil (baris 243-262) dan pemanggilan `hud.refresh_all()`; ganti asersi ke API baru: `drawer.state.gear == 5`, `roundi(drawer.state.speed_kmh) == 252`, `drawer.state.limiter`, `drawer.state.drs == 2`, `drawer.state.header_text.contains(car.code)`; jejak pedal/G (`state.throttle`, `state.g_trail`); ban meletus/panas crimson, sehat lime, blister 40; `state.ers_mode`, `ers_charge == 0.55`, `stress == 0.8`, `confidence == 0.3`; rival → `g_trail.size() == 1`; `T` toggle; `temp_tint` empat tingkat; `TelemetryDrawer.heartbeat`. Pesan asersi diawali "telemetry:" seperti sebelumnya.

- [ ] **Step 2: Jalankan dan pastikan gagal**

  Run: `godot --headless --path . -s res://tests/test_hud_theme_and_telemetry.gd`; `godot --headless --path . -s res://tests/test_race_hud.gd`
  Expected: gagal (parse error `draw_count`/`state`/`heartbeat` tidak ada pada drawer lama).

- [ ] **Step 3: Implementasi painter dan drawer**

  Tulis `TelemetryPainter` sebagai port gambar dari mockup (`ui_step_5_layout.html` `drawTele` lean, `speedPanel`, `gearPanel`, `heroPanel`; `ui_step_3_telemetry_hybrid_bd.html` `carXray`, `carPath`, `pedals`, `moodW`, `pulseW`): poligon miring via `draw_colored_polygon` + `draw_polyline`; speed lines radial (kerapatan ∝ kecepatan) dan titik halftone; gear dengan *kick* (skala + split chroma cyan/crimson ~0.3 s setelah upshift, dilacak dari pop `shift`), shift-light 12 balok; hero: mobil top-down dengan 4 ban (isi panas bergelombang), halo berdenyut untuk panas > 105 (lebih cepat saat > 125), disc rem menyala (`discCol`), tread 6 balok, silang untuk ban meletus, tangki bensin bergelombang, garis tulang punggung ERS bergerak (maju DEPLOY, mundur HARVEST, cepat OVERTAKE, redup NEUTRAL), panah G-force dengan jejak, tanda damage berkedip; pedal pilar lime/crimson; driver: bar stress/confidence (10 balok per sisi), ECG (`heartbeat`), ♥ berdenyut; caption typewriter satu baris (`state.caption`, kecepatan 42 karakter/detik, reset bila teks berubah); onomatope pop (skala 1.9→1 dalam 0.14 s, goyang 0.5 s, pudar 1.2–1.6 s) di posisi tetap per `kind`. Animasi memakai `state.clock` (bukan waktu dinding); `reduce_motion` mematikan getar, kedip, dan speed lines berdenyut. `TelemetryDrawer` hanya `_draw()`: panggil `TelemetryPainter.paint(...)`, naikkan `draw_count`. `RaceHud.bind` menyetel `drawer.style = style` sebelum `refresh_all`. Font: `UI.DISPLAY` (Anton), `UI.HEADER` (Barlow), `UI.MONO`; teks onomatope boleh memakai `UI.DISPLAY` bila font marker tidak ada di `assets/fonts/`.

- [ ] **Step 4: Jalankan test**

  Run: `godot --headless --path . -s res://tests/test_hud_theme_and_telemetry.gd` dan `godot --headless --path . -s res://tests/test_race_hud.gd`
  Expected: PASS keduanya. Bila `draw_count` tidak naik di mode headless (renderer dummy tidak mengirim `NOTIFICATION_DRAW`), putuskan ruling: ganti asersi gambar menjadi pemeriksaan bahwa `_process` memanggil `queue_redraw` (mis. penghitung `redraw_requests`) dan catat di ledger; jangan memanggil `_draw()` langsung.

- [ ] **Step 5: Commit**

```bash
git add scripts/hud/telemetry_painter.gd scripts/hud/telemetry_drawer.gd scripts/hud/race_hud.gd tests/test_race_hud.gd tests/test_hud_theme_and_telemetry.gd
git commit -m "feat(telemetry): concept F drawer drawn in one _draw with team accent"
```

---

### Task 5: Regresi penuh, bukti visual, dokumen

**Files:**
- Create: `scratch/capture_langkah3b.gd` (pola `scratch/capture_langkah3a.gd`), `executor-report/reports/FASE-11-LANGKAH-3B-TEAM-THEME-TELEMETRY-REPORT.md`, `executor-report/screenshots/phases/phase-11-langkah-3b-*.png`
- Modify: `ROADMAP.md`

- [ ] **Step 1: Jalankan seluruh suite**

  Run (satu per satu, urut): `for f in tests/test_*.gd; do godot.cmd --headless --path . -s res://tests/$(basename $f); done` (bash) atau loop `Get-ChildItem tests\test_*.gd` di PowerShell.
  Expected: 29 suite (28 + `test_hud_theme_and_telemetry`), semua exit 0, tanpa `[FAIL]` atau `SCRIPT ERROR` di log. Jangan menjalankan dua instance Godot sekaligus (memori).

- [ ] **Step 2: Tangkapan layar native (butuh GPU)**

  Jalankan `godot --path . --resolution 1920x1080 --script res://scratch/capture_langkah3b.gd`: drawer dengan tim lime (default), dengan crimson (`hud.set_team_accent(2)`), dengan putih (7), dan dengan biru (6); satu tangkapan saat rem keras (pop "GUOOO!!") dan satu saat ban kritis (pop "JIRI JIRI"); bandingkan bentuk dengan `docs/design-refs/ui_step_5_layout.html`. Lihat tiap gambar sebelum menyatakan selesai.

- [ ] **Step 3: Pengukuran frame time**

  Jalankan balapan 1× 40 detik dengan drawer terlihat dan catat frame time median/p95 (pola `scratch/` yang sudah ada, atau `Engine.get_frames_per_second` rata-rata dari skrip tangkapan). Bila GPU terbagi dengan proses lain, tulis "belum sah diukur" di laporan, bukan angka.

- [ ] **Step 4: Dokumen dan commit**

  Laporan (ringkasan, tabel file, hasil 29 suite, daftar screenshot, ruling, status kode mati `telemetry_widgets.gd` dan `step_bar.gd`), centang 3b di `ROADMAP.md`.

```bash
git add scratch/capture_langkah3b.gd executor-report/reports/FASE-11-LANGKAH-3B-TEAM-THEME-TELEMETRY-REPORT.md executor-report/screenshots/phases/phase-11-langkah-3b-*.png ROADMAP.md
git commit -m "docs(fase-11): Langkah 3b report and screenshots"
```
