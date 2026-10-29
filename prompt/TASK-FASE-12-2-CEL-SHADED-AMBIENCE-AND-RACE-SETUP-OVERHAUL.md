# TASK SPECIFICATION: FASE 12.2 — NEO-WANGAN CEL-SHADED SKY/WIND AMBIENCE & EXHIBITION RACE SETUP OVERHAUL

**Task ID:** `TASK-FASE-12-2-CEL-SHADED-AMBIENCE-AND-RACE-SETUP-OVERHAUL`  
**Assignee:** Senior Godot 4 3D Shader / Environment Technical Artist & UI/UX Systems Engineer  
**Priority:** High (Visual Style Alignment + Exhibition Race Setup & Seeded Dynamic Weather Overhaul)  
**Dokumen Desain (Spec):** [`docs/superpowers/specs/2026-10-28-fase-12-2-cel-shaded-ambience-and-race-setup-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-28-fase-12-2-cel-shaded-ambience-and-race-setup-design.md)  
**Rencana Implementasi Detail (TDD Plan):** [`docs/superpowers/plans/2026-10-28-fase-12-2-cel-shaded-ambience-and-race-setup-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-28-fase-12-2-cel-shaded-ambience-and-race-setup-plan.md)  
**Mockup Referensi Interaktif HTML:** [`temp/race_setup_concepts_preview.html`](file:///D:/Occupation/Porto/genex/La_Voiture/temp/race_setup_concepts_preview.html)  
**Godot Console:** `C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` (atau alias `godot`)  

---

## 1. Latar Belakang & Sasaran Pekerjaan

Berdasarkan evaluasi visual [`executor-report/reports/FASE-12-1-NEO-WANGAN-ENVIRONMENT-OVERHAUL-REPORT.md`](file:///D:/Occupation/Porto/genex/La_Voiture/executor-report/reports/FASE-12-1-NEO-WANGAN-ENVIRONMENT-OVERHAUL-REPORT.md) dan diskusi desain UI bersama pengguna, Fase 12.2 memiliki **2 sasaran utama**:

### Bagian A — Cel-Shaded / Toon Anime Polish & Living Sky/Wind Ambience (Neo-Wangan)
1. **Perbaikan 3 Elemen Visual yang Belum Cel-Shaded:**
   - **110 Gedung Skyline (`shaders/neo_wangan_skyline.gdshader`)**: Tambahkan `render_mode cull_back, diffuse_toon, specular_toon;`, gradasi vertikal malam, *halftone dot pattern* di dalam jendela menyala, *roofline neon trim* di puncak gedung, serta `next_pass` *Inverted-Hull Outline* (`OutlineShader`).
   - **Air Teluk (`shaders/neo_wangan_water.gdshader`)**: Ganti `StandardMaterial3D` PBR pada `_water_material()` (yang menyebabkan bola silau putih PBR raksasa di `phase-12-1-cam2-shuto-bridge.png`) dengan shader air *cel-shaded* beriak gelombang yang bergerak mengikuti kecepatan & arah angin (`wind_speed_kph`, `wind_dir`).
   - **24 Papan Billboard Jalanan (`shaders/neo_wangan_billboard.gdshader`)**: Ganti 3 kotak garis polos pada `StreetBillboardMM` dengan shader papan reklame bergaya **Kanji/Katakana Jepang + Halftone Screentone + Comic Ink Frame**.
2. **Menghidupkan Ambience Langit Malam & Efek Angin (`SkyAmbienceRoot` & `WindBannersMM`):**
   - Buat node `SkyAmbienceRoot` di `NeoWanganEnvironment`:
     * **`AnimeMoon`**: Bulan purnama anime bercahaya di langit malam dengan halo lembut (`cast_shadow = OFF`).
     * **`NightStars`**: `MultiMeshInstance3D` berisi $\ge 600$ (target 900) bintang di kubah langit malam (`cast_shadow = OFF`).
     * **`AnimeNightClouds`**: `MultiMeshInstance3D` berisi $\ge 20$ (target 28) gugus awan malam *cel-shaded* (`shaders/neo_wangan_clouds.gdshader`) dengan *silver/cyan rim light* yang bergeser/berputar perlahan melintasi langit mengikuti kecepatan angin (`race.weather.wind_speed`).
   - Buat `WindBannersMM` (`MultiMeshInstance3D` berisi 24 banner vertikal di tiang lampu jembatan & dermaga dengan `shaders/neo_wangan_wind_banner.gdshader`) yang berkibar mengikuti `wind_speed`.
   - Implementasikan `apply_wind_ambience(delta: float, wind_kph: float, wind_dir: float)` di `NeoWanganEnvironment` dan panggil setiap frame dari `update(delta, race)`.

### Bagian B — Overhaul `Exhibition Race Setup` & Seeded Dynamic Weather (`Opsi A`)
1. **Ekstensi `RaceConfigData` (`scripts/core/race_config_data.gd`):**
   - Dukungan jumlah lap `[3, 5, 10, 15]`.
   - Opsi **`weather_preset = 4` (`DYNAMIC RADAR`)**: Menggunakan `race_seed` dan `get_active_circuit().rain_probability` untuk memilih salah satu dari 7 *archetype* cuaca dinamis `GtWeather` (`DRY_TO_STORM`, `PASSING_SHOWERS`, `WET_DRYING`, `OVERCAST_GUSTY`, `DRY_SUNNY`) **tanpa** meratakan `weather.forecast`! Setiap `race_seed` baru menghasilkan kurva cuaca per-lap yang unik namun tetap 100% deterministik saat *Restart*.
   - Opsi **`time_of_day = 3` (`RANDOM`)**: Mengundi waktu balapan (`0 = DAY`, `1 = SUNSET`, `2 = NIGHT`) secara deterministik via `resolved_time_of_day()` menggunakan `race_seed`.
   - Opsi **`race_dynamics: int = 1`** (`0 = CLEAN PACE`, `1 = FIA STANDARD`, `2 = STREET CHAOS`) yang mengatur `race.incidents_enabled` sambil mempertahankan kecepatan AI 100% berdasarkan **26-Driver Skill Matrix**.
   - Method `reroll_seed() -> int` untuk mengacak ulang `race_seed`.
2. **Tata Letak Baru `RaceSetupMenu` (`scripts/ui/race_setup_menu.gd` & `scripts/ui/chip_row.gd`):**
   - **Unified 12-Round Interactive Carousel** di bawah kartu peta (`x = 60..1200, y = 852..956`), menghapus duplikasi 3 kartu statis lama (`_build_venue_strip`) dan menyatukan `TrackPrevButton` (`<`), 4 kartu ronde interaktif yang bisa diklik langsung, serta `TrackNextButton` (`>`). Pertahankan nama node `CircuitNameLabel`, `CircuitRoundLabel`, `CircuitTypeLabel`, `CircuitLengthLabel`, dan `CircuitTurnsLabel` agar `test_track_selector_ui.gd` tetap 100% PASS.
   - **Sidebar Artwork & Track Demand di Dalam Hero Map Card**: Tambahkan `VenuePreviewArt` (`TextureRect`), `TrackDemandPanel` (3 bar: `TOP SPEED`, `CORNERING GRIP`, `TYRE STRESS`), dan `VenueNotesLabel` di sisi kanan dalam kartu peta, serta perbarui badge status pojok kanan atas peta (`ACTIVE // READY` vs `IN PREPARATION`).
   - **Aturan Lap GP vs Sprint**:
     * Saat memilih sirkuit **SPRINT** (`selected.is_sprint() == true`, misal *Neo-Wangan*): Otomatis mengunci `total_laps = 3` (`lap_select.select(0)`) dan menonaktifkan chip `5`, `10`, dan `15` di UI (`set_chip_disabled(1..3, true)`).
     * Saat memilih sirkuit **GRAND PRIX** (`selected.is_sprint() == false`, misal *Apex Ring*): Mengaktifkan chip `5`, `10`, dan `15` (`set_chip_disabled(1..3, false)`), menonaktifkan klik manual pada chip `3` (`set_chip_disabled(0, true)`), namun tetap mengizinkan pemanggilan publik `select_laps(3)` agar kompatibel dengan `test_main_menu_flow.gd`.
   - **Panel Parameter Kanan**: Tambahkan `RerollSeedButton` (`🎲 SEED #...`), 5 chip Weather (`SUNNY`, `RAIN?`, `WET`, `MONSOON`, `DYNAMIC`) + **`MeteoRadarStrip`** (preview prediksi cuaca per-lap), 4 chip Time of Race (`DAY`, `SUNSET`, `NIGHT`, `RANDOM`), dan 3 chip Race Dynamics (`CLEAN`, `STANDARD`, `CHAOS`).

---

## 2. Batasan Kritis (Critical Constraints)

> [!CAUTION]
> 1. **JANGAN UBAH GEOMETRI SHARED PADDOCK KIT (`PitBuilding`, `MainGrandstand`, `RaceControlTower`):** Test `tests/test_shared_paddock_kit.gd` memeriksa SHA-256 hash byte-for-byte dari mesh default ketiga node tersebut. Seluruh banner angin (`WindBannersMM`) dan langit malam (`SkyAmbienceRoot`) wajib ditempatkan di dalam `NeoWanganEnvironment`.
> 2. **KOMPATIBILITAS PENUH TEST LAMA:** Pastikan `tests/test_main_menu_flow.gd` dan `tests/test_track_selector_ui.gd` tetap **100% PASS** tanpa regresi.
> 3. **ANGGARAN PERFORMA:** Total visible 3D draw calls lingkungan Neo-Wangan wajib tetap $\le 160$ dan visible 3D triangles $\le 320.000$. Matikan `cast_shadow` pada `AnimeMoon`, `NightStars`, `AnimeNightClouds`, dan `WindBannersMM`.

---

## 3. Checklist Eksekusi (Step-by-Step TDD)

Ikuti kode lengkap pada [`docs/superpowers/plans/2026-10-28-fase-12-2-cel-shaded-ambience-and-race-setup-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-28-fase-12-2-cel-shaded-ambience-and-race-setup-plan.md):

- [ ] **Task 1: Shaders Cel-Shaded & `SkyAmbienceRoot` / `WindBannersMM` di Neo-Wangan**
  - Buat `tests/test_neo_wangan_cel_ambience.gd`.
  - Buat/update ke-5 shader (`neo_wangan_skyline.gdshader`, `neo_wangan_water.gdshader`, `neo_wangan_billboard.gdshader`, `neo_wangan_clouds.gdshader`, `neo_wangan_wind_banner.gdshader`).
  - Integrasikan `SkyAmbienceRoot` (`AnimeMoon`, `NightStars`, `AnimeNightClouds`), `WindBannersMM`, dan `apply_wind_ambience()` di `scripts/world/circuits/neo_wangan/neo_wangan_environment.gd`.
  - Jalankan `test_neo_wangan_cel_ambience.gd` dan `test_neo_wangan_circuit.gd` $\rightarrow$ PASS, commit.
- [ ] **Task 2 & 3: Overhaul `RaceConfigData`, `ChipRow`, dan `RaceSetupMenu`**
  - Buat `tests/test_race_setup_overhaul.gd`.
  - Update `scripts/ui/chip_row.gd` dan `scripts/core/race_config_data.gd`.
  - Rombak `scripts/ui/race_setup_menu.gd` sesuai spesifikasi.
  - Jalankan `test_race_setup_overhaul.gd`, `test_track_selector_ui.gd`, dan `test_main_menu_flow.gd` $\rightarrow$ PASS, commit.
- [ ] **Task 4: Verifikasi Visual (6-Cam Neo-Wangan + 2 Screenshot Race Setup), Full Test Suite & Laporan**
  - Render ulang 6 kamera Neo-Wangan (`executor-report/screenshots/phases/phase-12-2-cam1..6-*.png`) + 2 tangkapan layar `RaceSetupMenu` (`phase-12-2-race-setup-gp.png` dan `phase-12-2-race-setup-sprint.png`).
  - Buka dan inspeksi visual seluruh gambar PNG tersebut.
  - Jalankan seluruh 50 test suite headless (`100% PASS, 0 FAIL`).
  - Tulis laporan resmi di `executor-report/reports/FASE-12-2-CEL-SHADED-AMBIENCE-AND-RACE-SETUP-REPORT.md` dan update `ROADMAP.md`.

---

## 4. Perintah Terminal Pembantu (CLI Reference)

```powershell
# 1. Menjalankan test baru Fase 12.2
godot --headless --path . -s res://tests/test_neo_wangan_cel_ambience.gd
godot --headless --path . -s res://tests/test_race_setup_overhaul.gd

# 2. Menjalankan test regresi terkait
godot --headless --path . -s res://tests/test_neo_wangan_circuit.gd
godot --headless --path . -s res://tests/test_shared_paddock_kit.gd
godot --headless --path . -s res://tests/test_track_selector_ui.gd
godot --headless --path . -s res://tests/test_main_menu_flow.gd

# 3. Menjalankan seluruh 50 test suite headless
Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --path . -s "res://tests/$($_.Name)" }
```
