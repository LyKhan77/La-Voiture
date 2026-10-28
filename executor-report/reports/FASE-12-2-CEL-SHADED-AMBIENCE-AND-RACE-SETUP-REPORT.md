# FASE 12.2 — Neo-Wangan Cel-Shaded Sky/Wind Ambience & Exhibition Race Setup Overhaul

Pelaksanaan: 28 Oktober 2026. Engine: Godot 4.7.2 stable, Forward+ Vulkan (RTX 3050 Laptop). Branch kerja: `fase-12-2-cel-ambience-race-setup` (empat commit di atas `de957df`: shader/ambience, config, menu, perbaikan garasi; belum di-merge, tidak ada push).

**Status akhir:** Task 1–3 (kode + TDD) selesai dan delapan screenshot native 1920 × 1080 dirender serta diinspeksi. **50/50 suite headless PASS (0 FAIL)**: 49 dijalankan dengan `godot --headless --path . -s res://tests/<nama>.gd`; `test_race_world` dijalankan dengan `--fixed-fps 60` sesuai header test itu (tanpa flag ini ia berjalan real-time dan melewati batas 280 s runner; dengan flag selesai 65 s, ALL PASS). Tinjauan akhir berupa self-review oleh pelaksana (tidak ada reviewer terpisah) dan menemukan satu cacat nyata (garasi, bagian 3 no. 12). Smoke test native 3 lap / 20 mobil dan gate 60 FPS tidak dijalankan pada fase ini (gate FPS Fase 12.1 tetap terbuka; lihat "Belum diverifikasi").

## 1. Bagian A — Cel-Shaded Neo-Wangan & ambience langit/angin

| Elemen | Implementasi | Bukti |
|---|---|---|
| `Skyline` (110 tower) | `neo_wangan_skyline.gdshader`: `diffuse_toon, specular_toon`, gradasi vertikal malam, halftone di jendela menyala, trim neon roofline. `next_pass` = `neo_wangan_skyline_outline.gdshader` (ink hull 0,9 m **di ruang dunia**). | cam1/2/5 |
| `Water` | `neo_wangan_water.gdshader`: dua nada berundak, pita gelombang yang bergerak melintang arah angin, garis puncak neon cyan/magenta putus-putus, `specular_disabled`. Tidak ada lagi bola silau PBR di bawah jembatan. | cam2, extra-wind-banners |
| `StreetBillboardMM` (24) | `neo_wangan_billboard.gdshader` pada satu `BoxMesh` 10 × 5,5 × 0,45: gradien halftone, empat blok goresan Kanji prosedural, stripe sub-banner, bingkai komik tebal; warna dari instance color. | cam4, cam6 |
| `SkyAmbienceRoot/AnimeMoon` | Satu quad billboard + `neo_wangan_moon.gdshader`: cakram kuning pucat, limb halftone, kawah, dua cincin halo perak-cyan. | cam5 |
| `SkyAmbienceRoot/NightStars` | MultiMesh **900** bintang di kubah R = 2400 m (elevasi 5°–88°, rata per sin-elevasi); `neo_wangan_stars.gdshader` berkedip per-instance dalam tiga step. | semua cam |
| `SkyAmbienceRoot/AnimeNightClouds` | MultiMesh **28** gugus (3 puff pipih digabung jadi satu surface), `neo_wangan_clouds.gdshader` memakai arah bulan di ruang dunia untuk rim perak-cyan. Cincin awan berputar: `0,004 + 0,00035 × wind_kph` rad/s, sudut diintegrasikan tiap frame. | cam2, cam5, cam6 |
| `HeroLandmarksRoot/WindBannersMM` | **24** banner vertikal di tiang lampu jembatan dan harbor; `neo_wangan_wind_banner.gdshader` menggelombangkan sisi bebas dengan frekuensi/amplitudo sebanding `wind_speed`, fase per instance. | extra-wind-banners |
| `apply_wind_ambience(delta, wind_kph, wind_dir)` | Dipanggil tiap frame dari `update(delta, race)` dengan `race.weather.wind_speed` / `wind_direction`; mengisi uniform air, banner, dan sudut awan; menyimpan `current_wind_kph`. | `tests/test_neo_wangan_cel_ambience.gd` |

`PitBuilding`, `MainGrandstand`, `RaceControlTower` tidak disentuh (semua elemen baru berada di dalam `NeoWanganEnvironment`); `test_shared_paddock_kit` tetap PASS.

**Anggaran render:** `stats()` lingkungan Neo-Wangan pada test RED sebelum perubahan 102 draw call / 165.964 tris; sesudah Task 1 **107 draw call / 177.150 tris** (+5 draw call: bulan, bintang, awan, banner, pass outline skyline). Angka 127 / 231.854 di laporan 12.1 memakai metode hitung lain dan tidak dibandingkan langsung. Viewport native per kamera, kendaraan/VFX disembunyikan (batas ≤ 160 draw / ≤ 320.000 tris):

| Kamera | Draw call | Tris |
|---|---:|---:|
| cam1-start-paddock | 62 | 178.018 |
| cam2-shuto-bridge | 50 | 119.586 |
| cam3-tunnel-chicane | 117 | 194.114 |
| cam4-harbor-hairpin | 60 | 110.424 |
| cam5-sky-moon-skyline | 101 | 189.528 |
| cam6-chase-cam-action | 30 | 100.906 |

## 2. Bagian B — Exhibition Race Setup

- **`RaceConfigData`**: `total_laps` ∈ {3, 5, 10, 15}; `weather_preset = 4` (DYNAMIC: archetype dipilih dari `race_seed` + `circuit.rain_probability`, kurva forecast `GtWeather` **tidak diratakan**); `time_of_day = 3` (RANDOM, `resolved_time_of_day()` dari `race_seed + 77`); `race_dynamics` 0/1/2; `reroll_seed()`. Rival berbalut WET/INTERMEDIATE pada grid basah untuk preset mana pun (`track_water_pct > 15`).
- **`ChipRow`**: `set_chip_disabled()`, `is_chip_disabled()`, `chip_at()`; chip terkunci dibuat redup (α 0,4), lepas dari fokus.
- **`RaceSetupMenu`**: carousel 12 ronde tunggal (`TrackPrevButton`, `CarouselCard0..3`, `TrackNextButton`) menggantikan venue strip; sidebar kartu peta (`VenuePreviewArt`, `TrackDemandPanel`, `VenueNotesLabel`) dan `CircuitStatusBadge` (ACTIVE // READY vs IN PREPARATION); Sprint mengunci 3 lap dan menonaktifkan chip 5/10/15 (`LapRuleBadge`), GP membuka 5/10/15 dan mengunci chip 3 untuk klik (API `select_laps(3)` tetap bekerja); `RerollSeedButton`; lima chip cuaca + `MeteoRadarStrip` (sampel hingga enam lap yang benar-benar dibalap); empat chip waktu; `dynamics_select`; badge "AI PACE: 26-DRIVER SKILL MATRIX".
- **Race dynamics**: CLEAN = `incidents_enabled = false`; STANDARD = laju stok; CHAOS = `GtRace.incident_rate × 2,5` (kenaikan peluang kontak, spin solo, dan kesalahan; laju AI tidak berubah). `incident_rate = 1,0` menjaga simulasi seed lama identik bit-per-bit.

## 3. Keputusan (Ruling) yang diambil

1. Branch di tempat tanpa worktree: tree kerja berisi banyak file untracked milik pengguna dan cache `.godot`.
2. Ink hull skyline memakai shader baru `neo_wangan_skyline_outline.gdshader`: `inverted_hull_outline.gdshader` mengekstrusi di ruang model, pada box satuan yang diskalakan per-instance garis 0,18 akan membengkak mengikuti ukuran gedung (≈ 26 m pada tower 145 m). Shader bersama tidak diubah.
3. Bulan dan bintang memakai shader (`neo_wangan_moon`, `neo_wangan_stars`), bukan `StandardMaterial3D` polos: spec meminta kawah halftone, halo, dan bintang berkedip.
4. Shader air dan awan dari plan diubah setelah render GPU: rumus air plan menghasilkan bulatan polka raksasa (kini pita berundak + garis puncak putus-putus); awan plan memakai `NORMAL.y` ruang model sehingga tampak hitam rata dari bawah (kini diterangi arah bulan di ruang dunia).
5. Stripe banner memakai `VERTEX.y` (UV BoxMesh adalah atlas); `_cloud_drift_m` dari plan dihapus dan sudut cincin awan diintegrasikan (rumus plan melompat saat angin berubah); tinggi awan 260–420 m mengikuti spec (plan: 240–380).
6. `STREET CHAOS` diberi efek nyata lewat `GtRace.incident_rate` (plan hanya memetakan `incidents_enabled`, sehingga CHAOS = STANDARD).
7. Track Demand = empat bar `TOP SPEED / TECHNICALITY / TIRE ABRASION / OVERTAKING` sesuai pesan pengguna; spec/plan menyebut tiga (`TOP SPEED / CORNERING GRIP / TYRE STRESS`). Satu baris `DEMAND_NAMES` + `demand_profile()` bila ingin kembali ke tiga bar.
8. `reference-assets/tracks/*/concept_key_visual.png` adalah **data JPEG berekstensi .png**: importer Godot menandainya `valid=false` dan `load()` gagal. Menu men-decode artwork dari byte file (cek magic number); file milik pengguna tidak diubah/diganti nama. Ronde tanpa artwork menampilkan plat fallback.
9. `tests/test_visual_polish_and_consistency.gd` ("race setup C") diperbarui untuk perubahan layout yang disengaja spec (peta 780 px, chip 4/5/4, venue strip → `CarouselCard0..3`).
10. Script capture baru (`scratch/capture_phase12_2_views.gd`, `capture_phase12_2_setup.gd`); `capture_phase12_views.gd` tidak diubah karena akan menimpa bukti Fase 12.1. cam5 menjadi shot langit/bulan/skyline (aerial overview tidak dapat memperlihatkan langit); satu screenshot tambahan `phase-12-2-extra-wind-banners.png`.
11. `tests/test_race_setup_overhaul.gd` berisi satu file; asersi menu baru hijau hanya setelah Task 3. Gate Task 2 = 13 asersi config lulus + regresi; berkas penuh 22/22 PASS setelah Task 3. Asersi `RACE DYNAMICS` ditambahkan ke test plan.
12. **Cacat ditemukan saat self-review:** `garage_team_select.gd` mengindeks tabel label dengan `weather_preset` 4 dan `time_of_day` 3 (error *out of bounds* di `_refresh_forecast`) dan menganggap setiap preset ≥ 2 sebagai start basah, sehingga start DYNAMIC kering menandai ban slick `SLICKS_ON_WET`. Diperbaiki test-first (2 asersi RED → GREEN pada `test_race_setup_overhaul`, kini 24/24): garasi menampilkan `DYNAMIC RADAR`, waktu hasil undian seed, dan memakai `RaceConfigData.is_wet_preset()`.

## 4. TDD

| Task | RED | GREEN |
|---|---|---|
| 1 `test_neo_wangan_cel_ambience` | 7 dari 9 asersi gagal (node/shader/`apply_wind_ambience` belum ada) | 12/12 |
| 2 `test_race_setup_overhaul` (bagian config) | 22/22 gagal | 13 asersi config lulus |
| 3 `test_race_setup_overhaul` (penuh) | 9 asersi menu gagal | 22/22 |
| Perbaikan garasi (no. 12) | 2 asersi garasi gagal (out-of-bounds + `SLICKS_ON_WET`) | 24/24 |

Pelajaran runner: test SceneTree yang melempar script error di `_run()` tidak pernah memanggil `quit()` dan menggantung selamanya; semua akses properti yang belum ada di test baru dijaga (`has_method`, `get()` + null check) agar kegagalan RED tercatat sebagai FAIL, bukan hang.

## 5. Bukti visual (native 1920 × 1080, `executor-report/screenshots/phases/`)

- `phase-12-2-cam1-start-paddock.png` — bintang, awan dengan rim, skyline toon + neon roofline.
- `phase-12-2-cam2-shuto-bridge.png` — air berundak dengan garis puncak neon, tanpa bola silau PBR.
- `phase-12-2-cam3-tunnel-chicane.png`
- `phase-12-2-cam4-harbor-hairpin.png` — bulan di tepi atas, billboard Kanji kuning.
- `phase-12-2-cam5-sky-moon-skyline.png` — bulan halftone + halo, 900 bintang, awan bergerak, skyline outline.
- `phase-12-2-cam6-chase-cam-action.png` — billboard Kanji magenta/kuning di street canyon saat balapan.
- `phase-12-2-race-setup-gp.png` — Apex Ring: chip 5/10/15 terbuka, chip 3 redup, DYNAMIC dengan radar L1 DRY / L3 18% / L5 58% / L6 47% / L8 DRY / L10 DRY (seed 14), carousel halaman 1.
- `phase-12-2-race-setup-sprint.png` — Neo-Wangan: 3 lap terkunci (SPRINT LOCKED), artwork venue, empat bar demand, RANDOM time, CHAOS.
- Tambahan: `phase-12-2-extra-wind-banners.png`.

## 6. Belum diverifikasi / catatan untuk pengguna

- Smoke test native 3 lap / 20 mobil dan profil 60 FPS **tidak dijalankan** pada fase ini; gate 60 FPS Fase 12.1 (p95 20,4 ms) tetap terbuka, dan penambahan ambience belum diukur terhadap frame time (hanya draw call/tris).
- Kualitas "berkibar" banner dan "berkedip" bintang hanya diverifikasi sebagai satu frame; animasi belum ditonton langsung.
- Menu belum dijalankan dengan input keyboard/gamepad manual; urutan fokus diverifikasi lewat kode, bukan sesi interaktif.
- Efek `incident_rate` 2,5 belum dikalibrasi lewat balapan penuh; nilainya adalah tebakan awal (`RaceConfigData.CHAOS_INCIDENT_RATE`).
- File artwork JPEG-berekstensi-PNG di `reference-assets/tracks/` sebaiknya diganti nama ke `.jpg` oleh pemilik aset agar impor Godot valid.
