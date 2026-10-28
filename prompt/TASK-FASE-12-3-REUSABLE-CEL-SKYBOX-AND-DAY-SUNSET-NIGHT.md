# TASK HANDOFF — FASE 12.3: Shared Reusable Cel-Skybox & Multi-Time-of-Day (`DAY / SUNSET / NIGHT`) Environment Unification

## 1. Dokumen Acuan Wajib Dibaca Pertama
1. **Panduan Arsitektur Sirkuit v2.0**: [`Circuit-Environment-Component-Guide.md`](file:///D:/Occupation/Porto/genex/La_Voiture/Circuit-Environment-Component-Guide.md)
2. **Design Spec**: [`docs/superpowers/specs/2026-10-28-fase-12-3-reusable-cel-skybox-and-time-of-day-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-28-fase-12-3-reusable-cel-skybox-and-time-of-day-design.md)
3. **TDD Implementation Plan**: [`docs/superpowers/plans/2026-10-28-fase-12-3-reusable-cel-skybox-and-time-of-day-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-28-fase-12-3-reusable-cel-skybox-and-time-of-day-plan.md)

---

## 2. Ringkasan Tugas Eksekusi

### A. Ekstrak Komponen Langit Reusable (`scripts/world/shared_cel_sky_controller.gd`) & Update Shaders
1. Buat `SharedCelSkyController` (`scripts/world/shared_cel_sky_controller.gd`) yang membangun dan mengendalikan `SkyAmbienceRoot` (`AnimeMoon`, `NightStars`, `AnimeNightClouds`) untuk semua sirkuit:
   - **`AnimeMoon` (`shaders/neo_wangan_moon.gdshader`)**: Berperan sebagai **Matahari Cel-Shaded (saat `DAY` & `SUNSET`)** dengan `crater_density = 0.0` dan **Bulan Halftone Ber-Halo (saat `NIGHT`)** dengan `crater_density = 0.34`.
   - **`NightStars` (`shaders/neo_wangan_stars.gdshader`)**: Tambahkan `uniform float star_opacity = 1.0;` agar bintang otomatis disembunyikan saat `DAY` (`visible = false`), muncul tipis saat `SUNSET`, dan penuh saat `NIGHT`.
   - **`AnimeNightClouds` (`shaders/neo_wangan_clouds.gdshader`)**: 28 gugus awan 3D cel-shaded yang berputar mengikuti `wind_speed` (`apply_wind(delta, wind_kph)`) dan otomatis berubah warna 3-step toon (`cloud_shadow`, `cloud_mid`, `cloud_rim`, `moon_dir`) sesuai mode `DAY` (putih-krem), `SUNSET` (emas-lembayung), atau `NIGHT` (indigo-perak) serta mendung hujan (`gloom`).

### B. Integrasi `DAY / SUNSET / NIGHT` di `NeoWanganEnvironment` & `TrackEnvironmentBuilder`
1. Di `scripts/world/neo_wangan_environment.gd`:
   - Gunakan `SharedCelSkyController` untuk membangun `SkyAmbienceRoot`.
   - Implementasikan `apply_time_of_day(tod: Dictionary, gloom: float = 0.0)` dan panggil setiap frame dari `update(delta, race)`:
     * **`Skyline` (`shaders/neo_wangan_skyline.gdshader`)**: Tambahkan `uniform float roof_neon_energy = 2.2;`. Saat `DAY` (`mode == 0`), fasad gedung berwarna beton/baja toon (`#4a5a75` → `#788cab`) dengan kaca reflektif langit tanpa emisi (`window_energy = 0.0, roof_neon_energy = 0.0`). Saat `SUNSET` (`mode == 1`), siluet senja hangat dengan jendela mulai menyala (`window_energy = 0.95 * pulse`). Saat `NIGHT` (`mode == 2`), siluet malam gelap dengan neon penuh (`window_energy = 1.8 * pulse`).
     * **`Water` (`shaders/neo_wangan_water.gdshader`)**: Tambahkan `uniform float band_emission = 0.25;` dan `uniform float crest_emission = 0.70;`. Saat `DAY`, air biru laut Tokyo (`#124878` / `#2474b5`) dengan buih putih-cyan. Saat `SUNSET`, air lembayung-emas senja. Saat `NIGHT`, air malam pekat dengan puncak neon cyan/magenta.
     * **`StreetlightHeads` & `StreetlightPools`**: Mati saat `DAY` cerah (`StreetlightPools.visible = false`, `emission = 0.0`), menyala saat `SUNSET` / `NIGHT` atau hujan badai gelap (`gloom > 0.55`). Lampu terowongan bawah tanah (`TunnelNeon`, `TunnelNeonPools`) **tetap menyala** di semua waktu.
2. Di `scripts/world/track_environment_builder.gd` (Apex Ring):
   - Pasang `SharedCelSkyController` (`include_stars = false` agar `MountainVista.star_instance` tetap menjadi starfield tunggal yang diuji `test_track_environment.gd`) dan perbarui di `update(delta, race)` sehingga Apex Ring juga memiliki Matahari/Bulan Cel-Shaded dan 28 Awan 3D Cel-Shaded yang bergerak mengikuti angin.

### C. Verifikasi & Dokumentasi (Definition of Done)
1. Buat dan jalankan `tests/test_reusable_sky_and_time_of_day.gd` serta pastikan **seluruh 51 test suite headless** (`tests/test_*.gd`) **100% PASS (0 FAIL)**.
2. Tangkap 4 screenshot native 1920×1080 di `executor-report/screenshots/phases/`:
   - `phase-12-3-wangan-day-bridge.png`
   - `phase-12-3-wangan-sunset-skyline.png`
   - `phase-12-3-wangan-night-skyline.png`
   - `phase-12-3-apex-ring-cel-sky.png`
3. Tulis laporan eksekutif di `executor-report/reports/FASE-12-3-REUSABLE-CEL-SKYBOX-AND-DAY-SUNSET-NIGHT-REPORT.md` dan perbarui `ROADMAP.md`.
