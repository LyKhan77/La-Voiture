# Langkah 3d: Ribbon Cuaca Ladder 8 Lap + Weather Deck Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chip cuaca 350×56 di ribbon menampilkan ladder 8 lap (hujan, ban rekomendasi, lap crossover, tag BOX) dan klik chip atau `[W]` membuka Weather Deck: grafik water% dengan kerucut ketidakpastian, peta lintasan, angka cuaca, kotak NEXT CHANGE dan tombol aksi tyre.

**Architecture:** Satu kelas data murni `GtWeatherOutlook` (tanpa node) mengubah `GtWeather.forecast` + cuaca langsung menjadi baris per lap, ringkasan perubahan dan lap BOX ideal; memakai ambang ban sim lewat `GtForecast.recommended_compound`. `WeatherRadarWidget` (chip) dan `WeatherDeck` (dropdown) hanya menggambar baris itu. `RaceHud` memberi makan keduanya pada irama `_update_weather()` yang sudah ada, dan kartu BOX WINDOW milik deck 3c membaca ringkasan yang sama supaya satu sumber kebenaran.

**Tech Stack:** Godot 4.7.2 stable, GDScript 2.0 (static typing wajib), test headless `SceneTree` lewat `runtest.sh` yang menolak `SCRIPT ERROR` dan `[FAIL]`.

**Spec:** `docs/superpowers/specs/2026-10-24-langkah-3-hud-redesign-v2-design.md` §4.3, §3 (layout lock), §10. Acuan visual: `docs/design-refs/ui_step_4_hud_discussion.html` (fungsi `wxData`, `tyFor`, `wxSummary`, `wxChipHTML`, `wxUpdateChip`, `wxDeckHTML`, `wxUpdateDeck`; CSS `.wx-chip`, `.wx-c`, `.wx-deck`, `.wx-next`, `.wx-act`). Angka mockup (skenario, suhu, kelembapan, angin) adalah placeholder; nilai sim ada di bagian Global Constraints.

## Global Constraints

- Kotak tetap (layout lock): ribbon (16,12) 1888×60; chip di ribbon (990,2) **350×56**; radar (1598,82) 312×212; records (1598,306); drawer (1598,372). Overlay baru yang diizinkan: Weather Deck dropdown di bawah ribbon, **stage (1006,76), 560×264** (berhenti sebelum x 1598, tidak menutup radar).
- Ambang ban = sim, bukan angka mockup: `GtForecast.WET_WATER_PCT = 45.0` atau `rain > 0.55` → WET; `INTER_WATER_PCT = 18.0` → INTERMEDIATE; selain itu slick (MEDIUM). Tabung wet di chip memberi tick di **18 %** dan **45 %**; garis grafik berlabel `WET > 45%` dan `INTER > 18%` (mockup memakai 35 % dan 10 %, tidak dipakai).
- Confidence: `max(0.3, 1 - 0.085 * k)`; sebaran kerucut = `(1 - confidence) * 38` titik persen water. Ini heuristik tampilan, bukan probabilitas sim (tulis begitu di teks bantuan).
- Ladder chip = **8 kolom, k = 0..7** (k = 0 lap sekarang dengan data langsung, k ≥ 1 dari `GtWeather.forecast`), kolom pertama bertanda `NOW`. Grafik Weather Deck = k = 0..10. `lap` = lap pemimpin (`max(1, floori(1 + standings()[0].s / track.length))`, sama seperti `weather_status()`).
- Kolom setelah garis finish (`lap + k > race.laps`) kosong/redup, tidak pernah bertanda BOX atau crossover, dan tidak dihitung dalam ringkasan. Bila `forecast` habis sebelum k yang diminta, nilai entri terakhir dipakai (tanpa error).
- Semua gerak (hujan jatuh, kolom crossover berdenyut, bracket BOX berkedip, kerucut berdenyut) mati bila `PresentationSettings.reduce_motion`; warna dan tag tetap. Warna bukan satu-satunya pembawa makna (huruf ban W/I/M, tag NOW/BOX).
- Kontrak lama tetap: `WeatherRadarWidget.format_forecast/format_status` (statis), `status_label`, `forecast_label`; `RaceHud.weather_status()` (kunci `state`, `wetness_pct`, `forecast` 5 elemen int, `ambient_c`) dan `RaceHud.weather_state`; test lama di `tests/test_race_hud.gd` dan `tests/test_weather_and_ai.gd` tidak diubah.
- Sim deterministik: tidak ada perubahan pada `GtWeather`/`GtRace`; semua baru adalah pembacaan. Tidak ada RNG di UI.
- Tombol aksi Weather Deck **tidak memanggil BOX**: ia memilih ban untuk panggilan BOX berikutnya (`deck.pit_compound`) dan menyorot lap BOX ideal; BOX tetap tombol pemain.
- Commit trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; hanya `git add` file yang disebut (ada file asing untracked). Class baru butuh `godot --headless --path . --import` sebelum test dan `.uid`-nya ikut di-commit. Satu instance Godot sekaligus.

## Review Focus

1. Sisa lap kurang dari 8 (lap terakhir, 2 lap lagi): kolom setelah finish redup, tanpa tag BOX/crossover, ringkasan tidak mengusulkan ganti ban setelah bendera finis. (Task 1, 2)
2. Balapan kering sepanjang forecast: semua kolom M, `NO CHANGE IN 10 LAPS`, tidak ada tag BOX, tombol aksi tersembunyi; forecast kosong atau lebih pendek dari kolom yang diminta tidak error. (Task 1, 3)
3. Trek basah yang mengering (water 60 → 40 → 10): tidak ada kolom BOX di k = 0; `box_k` minimum 1; kolom crossover = lap ban rekomendasi berubah. (Task 1)
4. `reduce_motion` aktif: tidak ada denyut, kedip, atau hujan animasi; Weather Deck terbuka tetap terbaca. (Task 2, 3)
5. HUD disembunyikan (`H`) atau `[W]` ditekan saat stage tersembunyi: Weather Deck tertutup/diabaikan; klik di luar chip dan deck tidak terblokir; deck tertutup tidak memakan CPU (`set_process(false)`). (Task 4)

## File Structure

- Create `scripts/gt/gt_weather_outlook.gd` — `class_name GtWeatherOutlook`: baris per lap, ringkasan, confidence.
- Modify `scripts/ui/weather_radar_widget.gd` — ladder 8 kolom, tabung, sinyal `clicked`; statis lama utuh.
- Create `scripts/ui/weather_deck.gd` (`class_name WeatherDeck`), `scripts/ui/weather_track_map.gd` (`class_name WeatherTrackMap`).
- Modify `scripts/hud/race_hud.gd` — chip → deck, `[W]`, pemberian data, `weather_state` mendelegasikan.
- Modify `scripts/hud/tactical_deck.gd` — `_update_window` membaca `GtWeatherOutlook`.
- Create `tests/test_weather_ladder.gd`; create `scratch/capture_langkah3d.gd`, laporan `executor-report/reports/FASE-11-LANGKAH-3D-WEATHER-LADDER-REPORT.md`, screenshot `phase-11-langkah-3d-*.png`; modify `ROADMAP.md`.

---

### Task 1: `GtWeatherOutlook` (data murni)

**Files:**
- Create: `scripts/gt/gt_weather_outlook.gd`
- Modify: `scripts/hud/race_hud.gd` (`weather_state` mendelegasikan, `weather_status` memakai `ahead`)
- Test: `tests/test_weather_ladder.gd`

**Interfaces:**
- Produces: `class_name GtWeatherOutlook extends RefCounted`:
  - `const LADDER_LAPS: int = 8`, `const CHART_LAPS: int = 10`.
  - `static func state_of(rain: float, water_pct: float) -> int` (0 dry, 1 drizzle `rain > 0.08`, 2 heavy `rain > 0.55`, 3 drying `water_pct > 8`): logika yang sekarang di `RaceHud.weather_state`, yang kini memanggilnya.
  - `static func state_name(state: int) -> String` (`DRY`, `DRIZZLE`, `HEAVY RAIN`, `DRYING`).
  - `static func confidence(k: int) -> float`, `static func cone_spread(k: int) -> float`.
  - `static func ahead(weather: GtWeather, lap: int, count: int, race_laps: int = 0) -> Array[Dictionary]`: `count + 1` entri `{"k": int, "lap": int, "rain": float, "water": float, "tyre": int (Compound), "state": int, "past_finish": bool}`; k = 0 memakai `weather.rain_intensity` dan `weather.track_water_pct`; `past_finish` hanya bila `race_laps > 0 and lap + k > race_laps`.
  - `static func summary(entries: Array[Dictionary]) -> Dictionary`: `{"now": Dictionary, "tyre_change": Dictionary ({} bila tidak ada), "state_change": Dictionary, "box_k": int (0 bila tidak ada; `max(1, tyre_change.k - 1)`), "confidence": float (confidence dari `state_change.k`, atau 0.95 bila tak ada perubahan)}`; entri `past_finish` diabaikan.
- Consumes: `GtForecast.recommended_compound(water_pct: float, rain: float) -> int`.

- [ ] **Step 1: Tulis test gagal `_test_outlook()`** di `tests/test_weather_ladder.gd` (kerangka `SceneTree` seperti `tests/test_deck_n2.gd`; helper `_forecast(rain: Array, water: Array) -> Array[Dictionary]` memberi `lap = indeks + 1`, `cloud_cover 0.3`, `wind_speed 10.0`; `GtWeather.new(10, 1, GtWeather.Archetype.DRY_SUNNY)` lalu timpa `forecast`):
  - Kasus A (lap 3, live rain 0 / water 3, forecast lap 4-6 kering water 3, lap 7 rain 0.3 water 30, lap 8 rain 0.9 water 70, 14 lap total): `ahead(w, 3, 8)` berisi 9 entri; `[0]` `k == 0 and lap == 3 and water == 3.0`; `[4].tyre == INTERMEDIATE`, `[5].tyre == WET`; `summary`: `tyre_change.k == 4`, `state_change.k == 4`, `box_k == 3`, `is_equal_approx(confidence, 0.66)`; `cone_spread(4)` ≈ 12.92 dan `confidence(12) == 0.3`: "outlook: the first tyre change, the box lap and the confidence come from the forecast".
  - Kasus B semua kering: `tyre_change.is_empty()`, `state_change.is_empty()`, `box_k == 0`, `confidence == 0.95`: "outlook: a dry forecast has no tyre change and no box lap".
  - Kasus C: `ahead(w, 3, 8, 6)`: entri k = 4 `past_finish`, `summary(...).tyre_change.is_empty()`: "outlook: laps after the chequered flag never ask for a tyre change".
  - Kasus D (lap 12, forecast berakhir di lap 14): `ahead(w, 12, 6)[5]` (lap 17) memakai nilai lap 14 dan `lap == 17`; forecast kosong (`[]`) tidak error dan semua entri memakai cuaca langsung: "outlook: a short or empty forecast repeats the last value without error".
  - Kasus E (live water 60 rain 0, forecast lap+1 water 40, lap+2 water 10): `tyre` k = 0 WET, 1 INTERMEDIATE, 2 MEDIUM; `box_k == 1`: "outlook: a drying track boxes no earlier than one lap ahead".
  - `state_of(0.9, 85.0) == 2 and state_of(0.2, 10.0) == 1 and state_of(0.0, 30.0) == 3 and state_of(0.0, 2.0) == 0` dan `RaceHud.weather_state(0.9, 85.0) == 2`: "outlook: weather states keep the HUD's meanings".
- [ ] **Step 2: Jalankan, pastikan gagal** (`runtest.sh test_weather_ladder`; parse error kelas belum ada).
- [ ] **Step 3: Implementasi `GtWeatherOutlook`** sesuai Interfaces; ubah `RaceHud.weather_state` menjadi satu baris yang memanggil `GtWeatherOutlook.state_of`, dan `weather_status()` memakai `ahead(race.weather, lap, 5)` (entri k = 1..5) untuk `forecast` (bentuk dan nilai dictionary lama tidak berubah).
- [ ] **Step 4: Jalankan** `godot.cmd --headless --path . --import` lalu `runtest.sh test_weather_ladder test_race_hud test_weather_and_ai`. Expected: OK semua.
- [ ] **Step 5: Commit**

```bash
git add scripts/gt/gt_weather_outlook.gd scripts/gt/gt_weather_outlook.gd.uid scripts/hud/race_hud.gd tests/test_weather_ladder.gd tests/test_weather_ladder.gd.uid
git commit -m "feat(weather): GtWeatherOutlook rows, tyre change and box lap from the forecast"
```

---

### Task 2: Chip cuaca dengan ladder 8 lap

**Files:**
- Modify: `scripts/ui/weather_radar_widget.gd`
- Test: `tests/test_weather_ladder.gd` (`_test_chip()`)

**Interfaces:**
- Consumes: `GtWeatherOutlook.ahead`, `summary`, `state_name` (Task 1).
- Produces: pada `WeatherRadarWidget`: `signal clicked`; `var columns: Array[Dictionary]` (8 entri `{"tyre": int, "rain": float, "tag": String ("NOW", "BOX" atau ""), "crossover": bool, "dim": bool}`); `func update_outlook(entries: Array[Dictionary], summary: Dictionary, air_c: float, track_c: float) -> void`; `mouse_filter = STOP` dan `gui_input` kiri → `clicked`. Row 1: `status_label` (tetap, ikon + nama + suhu udara), `forecast_label` diisi `"> %s L+%d   TRK %d°C"` (perubahan state berikutnya) atau `"> STABLE 10L   TRK %d°C"`; row 2: 8 kolom (batang hujan setinggi `max(8 %, rain)`, huruf ban W/I/M di dasar kolom, tag di atas), tabung wet di kanan dengan tick 18 % dan 45 %. `update_status(status)` lama tetap dan tetap mengisi `forecast_label` dengan `format_forecast`; `update_outlook` menimpanya.

- [ ] **Step 1: Tulis test gagal `_test_chip()`** (entri dari kasus A Task 1 dibangun ulang lewat helper): `columns.size() == 8`, `columns[0].tag == "NOW"`, `columns[3].tag == "BOX"` (box_k 3), `columns[4].crossover == true` dan `columns[4].tyre == INTERMEDIATE`, `columns[5].tyre == WET`, `forecast_label.text` mengandung `"DRIZZLE L+4"`: "chip: the ladder marks NOW, the box lap and the crossover column". Kasus kering: tidak ada tag `BOX`, `forecast_label.text` mengandung `"STABLE"`: "chip: a dry forecast shows no box tag". Sisa 2 lap (`past_finish` untuk k ≥ 3): `columns[3].dim and columns[3].tag == ""`: "chip: columns after the flag are dimmed and untagged". `WeatherRadarWidget.format_forecast(0, [0,0,1,1,2]) == "L+3: DRIZZLE | L+5: HEAVY RAIN"` tetap (kontrak lama). `widget.gui_input` dengan `InputEventMouseButton` kiri menekan memancarkan `clicked` sekali: "chip: a click emits clicked". Dengan `reduce_motion = true`, `widget.is_processing() == false`: "chip: reduce motion stops the rain animation".
- [ ] **Step 2: Jalankan, pastikan gagal** (`update_outlook` tidak ada).
- [ ] **Step 3: Implementasi** sesuai Interfaces; gambar semua di satu `_draw()`; hujan jatuh = garis pendek bergeser dari `Time.get_ticks_msec()` (hanya tampilan) pada kolom `rain > 0.08`, denyut kolom crossover; `set_process` hanya bila ada kolom hujan atau crossover dan bukan `reduce_motion`; `queue_redraw` hanya bila sidik ringkasan berubah atau sedang beranimasi.
- [ ] **Step 4: Jalankan** `runtest.sh test_weather_ladder test_race_hud test_weather_and_ai`. Expected: OK.
- [ ] **Step 5: Commit** `git add scripts/ui/weather_radar_widget.gd tests/test_weather_ladder.gd` / `feat(weather): ribbon chip with the 8 lap ladder`.

---

### Task 3: Weather Deck

**Files:**
- Create: `scripts/ui/weather_deck.gd`, `scripts/ui/weather_track_map.gd`
- Test: `tests/test_weather_ladder.gd` (`_test_deck()`)

**Interfaces:**
- Consumes: `GtWeatherOutlook` (Task 1), `GtTypes.COMPOUND_COLOR`, `GtWeather` (`air_temp`, `track_temp`, `humidity`, `wind_speed`, `wind_direction`, `track_water_pct`, `drying_line_pct`).
- Produces: `class_name WeatherDeck extends Control` (560×264, `visible = false`): `signal tyres_chosen(compound: int, box_k: int)`; `var is_open: bool`; `func set_open(value: bool) -> void`, `func toggle() -> void`; `func update_outlook(entries: Array[Dictionary], summary: Dictionary, snapshot: Dictionary) -> void` (`snapshot`: `air`, `track`, `humidity`, `wind_kmh`, `wind_dir`, `water`, `drying_line`); `func set_ribbon(ribbon: TrackRibbon, length_m: float) -> void` (meneruskan ke peta); anggota uji: `chart: Control` (menggambar 11 titik), `next_label: Label`, `action_button: Button`, `info_labels: Dictionary` (`AIR`, `TRACK`, `HUMIDITY`, `WIND`), `map: WeatherTrackMap`. `class_name WeatherTrackMap extends Control` (170×104): `func set_points(points: PackedVector2Array)` (titik lintasan ternormalisasi), `func set_wetness(sector_water: Array[float], drying_line_pct: float)`; tiga sektor = sepertiga panjang titik, air sektor = `water + [0, 10, -8]` dijepit 0..100 (heuristik tampilan karena sim tidak punya air per sektor; catat di laporan), warna `<10` abu, `<25` cyan, `<45` biru, selain itu ungu.
  - Isi: grafik 11 titik: garis air (putih), batang hujan, kerucut `±cone_spread(k)` di sekitar garis, dua garis ambang berlabel `WET > 45%` dan `INTER > 18%`, bracket merah `BOX WINDOW` di sekitar `box_k` (berkedip), baris ban W/I/M per kolom. `next_label`: `"%s IN ~%d LAP%s"` + baris kecil `"confidence %d%% · crossover > %s at L+%d"` atau `"NO CHANGE IN 10 LAPS"` + `"confidence 95%"`. `action_button` terlihat hanya bila `box_k > 0`, teks `"SET TYRES  L+%d > %s"` (nama compound sim), menekannya memancarkan `tyres_chosen(summary.tyre_change.tyre, box_k)` dan memberi umpan klik (`AudioManager.click_pitched`).

- [ ] **Step 1: Tulis test gagal `_test_deck()`** (kasus A/B/C dari Task 1): `deck.set_open(true)` → `visible and is_open`, `toggle()` menutup; `update_outlook` kasus A: `next_label.text` mengandung `"DRIZZLE IN ~4 LAPS"` dan `"confidence 66%"` dan `"INTERMEDIATE"`; `action_button.visible` dan `action_button.text == "SET TYRES  L+3 > INTERMEDIATE"`; `action_button.pressed.emit()` memancarkan `tyres_chosen(INTERMEDIATE, 3)`: "deck: the weather deck names the next change and offers the tyre for the box lap". Kasus B: `next_label.text` mengandung `"NO CHANGE IN 10 LAPS"` dan `not action_button.visible`: "deck: a dry forecast offers no tyre action". Kasus C (`race_laps` 6): `not action_button.visible`: "deck: nothing is offered after the flag". `info_labels["AIR"].text` mengandung `"24"` untuk `snapshot.air = 24.0`, `info_labels["WIND"].text` mengandung `"18"` untuk 18 km/h. `map.set_points` dengan 60 titik lalu `set_wetness([3.0, 13.0, 0.0], 0.0)` tidak error dan `map.sector_colors().size() == 3` dengan sektor 2 lebih basah warnanya dari sektor 1 (`sector_colors()` anggota uji). Set `reduce_motion = true`: `deck.is_processing() == false`: "deck: reduce motion stops the bracket blink". Deck tertutup: `is_processing() == false` walau `reduce_motion == false`: "deck: a closed weather deck does not process".
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasi** kedua kelas sesuai Interfaces (gaya `UI.surface`, `UI.label`, font sama dengan HUD; satu `_draw()` untuk grafik; peta menggambar tiga polyline tebal plus garis dry line berlapis opasitas `1 - water/40`).
- [ ] **Step 4: Jalankan** `godot.cmd --headless --path . --import` lalu `runtest.sh test_weather_ladder`. Expected: OK.
- [ ] **Step 5: Commit** (`weather_deck.gd`, `weather_track_map.gd`, `.uid`, test) / `feat(weather): weather deck with chart, cone, track map and tyre action`.

---

### Task 4: Integrasi HUD, regresi, bukti, dokumen

**Files:**
- Modify: `scripts/hud/race_hud.gd` (`_build_ribbon`, `_update_weather`, `handle_key`, `set_shown`), `scripts/hud/tactical_deck.gd` (`_update_window`)
- Create: `scratch/capture_langkah3d.gd` (pola `capture_langkah3c.gd`), `executor-report/reports/FASE-11-LANGKAH-3D-WEATHER-LADDER-REPORT.md`, `executor-report/screenshots/phases/phase-11-langkah-3d-*.png`
- Modify: `ROADMAP.md`
- Test: `tests/test_weather_ladder.gd` (`_test_hud()`)

**Interfaces:**
- Consumes: Task 1-3. Produces: `RaceHud.weather_deck: WeatherDeck` (anak `stage` di (1006,76), `z_index` di atas radio dock); chip `weather_widget.clicked` → `weather_deck.toggle()`; `handle_key(KEY_W)` → `toggle()` (hanya bila stage terlihat); `ESC` menutup deck bila terbuka (sebelum aturan kartu/BOX); `set_shown(false)` menutup deck; `weather_deck.tyres_chosen` → `deck.pit_compound = compound`, `deck.tyre_row.set_active(compound + 1)`, `deck.wheel.set_compound(compound + 1, true)`, `deck.apply_click_feedback(deck.wheel, "TYRES", 1.1)`, lalu `deck.refresh()`. `_update_weather()` memanggil `update_status` (lama), lalu membangun `ahead(race.weather, lap, 10, race.laps)` sekali dan memberi makan chip (8 entri pertama) dan deck (bila `is_open`). `TacticalDeck._update_window` memakai `GtWeatherOutlook.ahead(..., 5, race.laps)` + `summary`, teks hasil identik dengan 3c (`"BOX WINDOW L+%d -> %s"` dengan `box_k`, `"NO TYRE CHANGE"`, cadangan `"NO TYRE CHANGE\nweather stable"` hanya bila forecast kosong) dan chip per lap tetap.

- [ ] **Step 1: Tulis test gagal `_test_hud()`** (dunia balap seperti `test_deck_n2.gd`; isi `race.weather.forecast` dengan kasus A relatif lap pemimpin): `hud.weather_widget.clicked.emit()` → `hud.weather_deck.is_open`; `hud.handle_key(KEY_W)` menutupnya dan mengembalikan `true`; `hud.set_shown(false)` lalu `hud.handle_key(KEY_W)` → `false` dan deck tertutup; `hud.set_shown(true)`; deck dibuka lalu `ESC` menutupnya dan mengembalikan `true` tanpa menyentuh BOX: "hud: the chip and W open the weather deck, hiding the HUD closes it". Dengan deck terbuka dan kasus A: `weather_deck.action_button.pressed.emit()` → `hud.deck.pit_compound == INTERMEDIATE and hud.deck.wheel.compound == 1 + INTERMEDIATE`: "hud: the weather deck picks the tyre for the next box call and does not call the car" (`car.pit_request == -1`). Kartu BOX WINDOW deck dengan kasus A mengandung `"BOX WINDOW L+3 -> INTERMEDIATE"` dan, untuk forecast kering, `"NO TYRE CHANGE"`: "hud: the deck's window card and the weather deck read the same outlook". `hud.weather_status()` tetap `forecast.size() == 5`.
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasi integrasi** sesuai Interfaces; chip ditambahkan di ribbon yang `mouse_filter` IGNORE, jadi chip sendiri `STOP` hanya pada kotak 350×56-nya.
- [ ] **Step 4: Seluruh suite** — `runtest.sh $(semua tests/test_*.gd tanpa .gd)`; harapan semua OK (≥ 31 suite), tanpa `[FAIL]`/`SCRIPT ERROR`.
- [ ] **Step 5: Tangkapan layar native** (`scratch/capture_langkah3d.gd`, `--resolution 1920x1080`, potong ke ribbon dan area deck): chip dengan ladder kasus A; chip kering; Weather Deck terbuka dengan grafik, kerucut, bracket BOX, peta, kotak NEXT CHANGE dan tombol aksi; Weather Deck kering; chip dengan sisa 2 lap (kolom redup); tim crimson. Lihat tiap gambar.
- [ ] **Step 6: Review akhir seluruh cabang** (agen terpisah, model `fable`, `review-package`), grade ulang, satu putaran perbaikan TDD, regresi penuh ulang.
- [ ] **Step 7: Dokumen dan commit** — laporan (ringkasan, file, hasil, temuan, ruling: ambang 18/45 bukan 35/10, k = 0..7 dengan NOW di kolom pertama, tombol aksi memilih ban bukan memanggil BOX, air per sektor adalah heuristik tampilan), ROADMAP 3d dicentang.

```bash
git add scripts/hud/race_hud.gd scripts/hud/tactical_deck.gd tests/test_weather_ladder.gd scratch/capture_langkah3d.gd executor-report/reports/FASE-11-LANGKAH-3D-WEATHER-LADDER-REPORT.md executor-report/screenshots/phases/phase-11-langkah-3d-*.png ROADMAP.md
git commit -m "feat(hud): weather deck wiring, shared outlook for the box window card, report"
```

---
