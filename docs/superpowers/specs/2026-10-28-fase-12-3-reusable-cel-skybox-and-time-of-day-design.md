# FASE 12.3 — Shared Reusable Cel-Skybox & Multi-Time-of-Day (`DAY / SUNSET / NIGHT`) Environment Unification

**Tanggal:** 28 Oktober 2026  
**Target Engine:** Godot Engine 4.7.2 stable (GDScript 2.0 Static Typing + `.gdshader`)  
**Dokumen Acuan:** [`Circuit-Environment-Component-Guide.md`](file:///D:/Occupation/Porto/genex/La_Voiture/Circuit-Environment-Component-Guide.md) · [`ROADMAP.md`](file:///D:/Occupation/Porto/genex/La_Voiture/ROADMAP.md)

---

## 1. Latar Belakang & Masalah yang Diselesaikan

Berdasarkan evaluasi pasca-Fase 12.2:
1. **Neo-Wangan Belum Memiliki Mode `DAY` dan `SUNSET`**:
   - Meskipun menu **Exhibition Race Setup** mengizinkan pemain memilih `DAY`, `SUNSET`, `NIGHT`, atau `RANDOM` di **Neo-Wangan Shuto Express**, `NeoWanganEnvironment` masih mematok langit malam secara statis (`_apply_night_sky()`). Akibatnya, saat balapan Siang (`DAY`) atau Sore (`SUNSET`), Bulan (`AnimeMoon`), 900 Bintang (`NightStars`), gedung hitam berjendela neon penuh, air malam, dan lampu jalan tetap menyala di siang bolong.
2. **Duplikasi Sistem Langit & Belum Menyatu Antara Sirkuit GP (Apex Ring) dan Street Circuit (Neo-Wangan)**:
   - Awan 3D cel-shaded (`AnimeNightClouds`) dan Matahari/Bulan halftone (`AnimeMoon`) baru ada di `NeoWanganEnvironment`, belum menjadi komponen *reusable* yang otomatis dinikmati oleh `TrackEnvironmentBuilder` (Apex Ring) maupun 10 sirkuit kalender berikutnya.
3. **Standarisasi Alur Kerja Map 2-Tier (`Circuit-Environment-Component-Guide.md` v2.0)**:
   - Seluruh map wajib memisahkan **Tier A (Reusable Core Kit: Area Lintasan, Infrastruktur FIA, dan Shared Cel-Skybox `DAY/SUNSET/NIGHT`)** dari **Tier B (Improvised Biome: Terrain/Air, Vegetasi, dan Hero Landmarks sesuai referensi map)**, serta menegakkan gerbang gaya visual **Cel-Shaded / Toon Anime**.

---

## 2. Desain Arsitektur: `SharedCelSkyController` & Adaptasi `DAY / SUNSET / NIGHT`

### A. Komponen Langit Reusable (`scripts/world/shared_cel_sky_controller.gd`)
`SharedCelSkyController` adalah kelas `RefCounted` / `Node` bersama yang membangun dan memperbarui `SkyAmbienceRoot` di atas titik tengah sirkuit (`TrackRibbon`) untuk **semua map**:

1. **Hierarki Node di bawah `SkyAmbienceRoot`**:
   - `AnimeMoon` (`MeshInstance3D` — quad billboard `285 × 285 m` dengan `shaders/neo_wangan_moon.gdshader`):
     - Berfungsi ganda sebagai **Matahari Cel-Shaded (saat `DAY` & `SUNSET`)** dan **Bulan Halftone Ber-Halo (saat `NIGHT`)**:
       * **`DAY` (`night_factor < 0.15`)**: Posisi tinggi (`Vector3(-520, 960, -980)`), warna cakram putih-kuning hangat (`#fffef5` / `#ffe885`), halo biru langit (`#b3ecff`), `crater_density = 0.0` (tanpa kawah bulan).
       * **`SUNSET` (`0.15 <= night_factor < 0.7`)**: Posisi rendah di cakrawala senja (`Vector3(-720, 340, -1100)`), cakram Matahari Senja Anime jingga-merah (`#ffb838` / `#ff3d1f`), halo emas-lembayung (`#ff7043`), `crater_density = 0.0`.
       * **`NIGHT` (`night_factor >= 0.7`)**: Posisi malam (`Vector3(-650, 780, -1100)`), cakram Bulan kuning pucat (`#fff8d6` / `#c7d1bd`), halo perak-cyan (`#9edbff`), `crater_density = 0.34` (kawah halftone aktif).
   - `NightStars` (`MultiMeshInstance3D` — 900 bintang berkedip dengan `shaders/neo_wangan_stars.gdshader`, opsional `include_stars: bool = true`):
     - Dikendalikan oleh uniform `star_opacity = clampf(float(tod["stars_opacity"]) * (1.0 - gloom * 0.85), 0.0, 1.0)`:
     - **`DAY`**: `NightStars.visible = false`, `star_opacity = 0.0` (0 bintang di siang hari).
     - **`SUNSET`**: Bintang senja mulai tampak tipis (`visible = star_opacity > 0.02`).
     - **`NIGHT`**: 900 bintang berkedip penuh (`visible = true`, `star_opacity = 1.0` saat cerah).
   - `AnimeNightClouds` (`MultiMeshInstance3D` — 28 gugus awan 3D cel-shaded 3-puff dengan `shaders/neo_wangan_clouds.gdshader`):
     - Berputar mengelilingi horizon sesuai kecepatan angin (`_cloud_angle += delta * (CLOUD_BASE_RATE + wind_kph * CLOUD_WIND_RATE)`).
     - Warna 3-step toon (`cloud_shadow`, `cloud_mid`, `cloud_rim`) dan arah rim (`moon_dir`) otomatis beradaptasi terhadap waktu dan mendung hujan (`gloom`):
       * **`DAY`**: Putih-krem anime cerah (`rim #ffffff`, `mid #dcebfa`, `shadow #93b4db`), meredup ke abu-abu biru saat badai (`gloom > 0`).
       * **`SUNSET`**: Lembayung-emas dramatis (`rim #ffb057`, `mid #bd5e7a`, `shadow #4a2c56`).
       * **`NIGHT`**: Indigo malam dengan rim perak-cyan bulan (`rim #b8e0ff`, `mid #405285`, `shadow #1f2645`).

### B. Adaptasi `DAY / SUNSET / NIGHT` pada **Neo-Wangan Shuto Express** (`scripts/world/neo_wangan_environment.gd`)
`NeoWanganEnvironment` mendelegasikan langit ke `SharedCelSkyController` dan menyediakan fungsi publik `apply_time_of_day(tod: Dictionary, gloom: float = 0.0)` yang dipanggil otomatis setiap frame dari `update(delta, race)`:

| Elemen Kota Neo-Wangan | Mode `DAY` (`0`) | Mode `SUNSET` (`1`) | Mode `NIGHT` (`2`) |
| :--- | :--- | :--- | :--- |
| **Langit & Fog (`WorldEnvironment`)** | Biru Tokyo cerah (`top #2673d6`, `horizon #99d6ff`), fog tipis `0.00022` | Jingga-lembayung senja (`top #2d1b4e`, `horizon #ff6b3d`), fog hangat `0.00032` | Malam indigo (`top #060a18`, `horizon #2a1a3e`), fog malam `0.00055` |
| **Menara `Skyline` (`neo_wangan_skyline.gdshader`)** | Fasad beton/baja toon (`#4a5a75` → `#788cab`), kaca biru langit **tanpa emisi neon** (`window_energy = 0.0`, `roof_neon_energy = 0.0`) | Siluet senja ungu-emas (`#28233d` → `#6e4263`), jendela kaca memantulkan senja & mulai menyala (`window_energy = 0.95`, `roof_neon_energy = 1.2`) | Siluet malam gelap (`#0b0e16` → `#171f33`), jendela halftone & trim neon menyala penuh (`window_energy = 1.8`, `roof_neon_energy = 2.2`) |
| **Air Teluk (`neo_wangan_water.gdshader`)** | Biru laut Tokyo (`deep #124878`, `band #2474b5`) + garis buih putih-cyan (`crest_emission = 0.25`) | Lembayung-merah senja (`deep #26193b`, `band #6b3252`) + riak emas-magenta (`crest_emission = 0.55`) | Biru malam pekat (`deep #061020`, `band #0d2947`) + puncak neon cyan/magenta (`crest_emission = 0.70`) |
| **Lampu Jalan & Pool Aspal (`StreetlightHeads`, `StreetlightPools`)** | **MATI** (`StreetlightPools.visible = false`, `emission = 0.0`), kecuali saat badai gelap (`gloom > 0.55`) | Menyala hangat redup (`intensity = 0.5 * night_factor`) | Menyala penuh (`intensity = 0.5`, `emission = 2.6`) |
| **Terowongan (`TunnelNeon`, `TunnelNeonPools`)** | **TETAP MENYALA** (karena berada di bawah tanah / *underpass*) | **TETAP MENYALA** | **TETAP MENYALA** |

### C. Integrasi `SharedCelSkyController` pada **Apex Ring (`TrackEnvironmentBuilder`)**
- `TrackEnvironmentBuilder` turut memasang `SharedCelSkyController` (dengan `include_stars = false` karena `MountainVista` sudah memiliki 900 bintang `Stars` yang diuji oleh `test_track_environment.gd`), sehingga **Apex Ring** juga mendapatkan **Matahari/Bulan Cel-Shaded (`AnimeMoon`)** dan **28 Awan 3D Cel-Shaded (`AnimeNightClouds`)** yang bergerak mengikuti angin di mode `DAY`, `SUNSET`, dan `NIGHT`!
- Tambahan biaya render di Apex Ring hanya **+2 draw calls** dan **+8.402 triangles**, tetap jauh di bawah batas `< 180` draw calls dan `< 350.000` triangles pada `tests/test_track_environment.gd`.
