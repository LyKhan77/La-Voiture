# SPESIFIKASI DESAIN FASE 12.2: NEO-WANGAN CEL-SHADED SKY/WIND AMBIENCE & EXHIBITION RACE SETUP OVERHAUL

**Tanggal:** 28 Oktober 2026  
**Status:** Disetujui Pengguna (Opsi A — Adaptive Skill Matrix + Dynamic Weather Radar + Cel-Shaded Living Ambience)  
**Target:** [`scripts/world/neo_wangan_environment.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/world/neo_wangan_environment.gd), [`scripts/ui/race_setup_menu.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/ui/race_setup_menu.gd), [`scripts/core/race_config_data.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/core/race_config_data.gd)

---

## 1. Ringkasan Eksekutif & Tujuan Fase 12.2

Fase 12.2 menyelesaikan dua sasaran kualitas utama berdasarkan hasil review visual Fase 12.1:
1. **Bagian A — Cel-Shaded / Toon Anime Polish & Living Sky/Wind Ambience (Neo-Wangan):**
   - Mengubah 3 elemen visual Neo-Wangan yang masih kaku/PBR menjadi 100% **Cel-Shaded Anime $\times$ Manga Halftone**:
     * **110 Gedung Skyline (`shaders/neo_wangan_skyline.gdshader`)**: Menambahkan *2-tone toon diffuse*, *roofline neon rim*, *halftone screentone*, dan *inverted-hull outline*.
     * **24 Papan Billboard Jalanan (`shaders/neo_wangan_billboard.gdshader`)**: Mengganti 3 strip kotak polos dengan tipografi grafis **Kanji Jepang (`湾岸`, `首都高`, `最高速`, `疾風`)** + pola *halftone dots* bercahaya.
     * **Air Teluk (`shaders/neo_wangan_water.gdshader`)**: Mengganti `StandardMaterial3D` PBR (yang memunculkan bola silau putih raksasa) dengan shader air *cel-shaded* beriak gelombang yang bergerak mengikuti kecepatan angin (`wind_speed`).
   - Menghidupkan **Ambience Langit Malam & Angin (`SkyAmbienceRoot`)**:
     * **Bulan Purnama Anime (`AnimeMoon`)** dengan kawah *halftone* dan halo cahaya perak/cyan.
     * **900 Bintang Malam (`NightStars` MultiMesh)** di kubah langit.
     * **28 Gugus Awan Malam Anime (`AnimeNightClouds` MultiMesh)** yang berarak melintasi langit dengan kecepatan proporsional terhadap `race.weather.wind_speed`.
     * **24 Umbul-Umbul / Wind Banners (`WindBannersMM` MultiMesh)** di sepanjang jembatan & pelabuhan yang berkibar via *vertex wave shader* mengikuti `wind_speed`.
2. **Bagian B — Overhaul Layar `Exhibition Race Setup` & Sistem Cuaca Dinamis Berbasis Seed:**
   - Menyatukan pemilih sirkuit menjadi **12-Round Interactive Carousel** di bawah peta (menghapus duplikasi 3 kartu statis lama vs panah kanan bawah).
   - Menambahkan **Artwork Preview Sirkuit** + **3 Bar *Track Demand Profile*** (*Top Speed*, *Cornering Grip*, *Tyre Stress*) di sisi kanan dalam kartu peta.
   - Menerapkan aturan **Lap Distance GP vs Sprint**:
     * **Sirkuit SPRINT** (*Neo-Wangan*, *Monte Azure*, *Haruna*, dll.): Terkunci otomatis di **`3 LAPS (SPRINT LOCKED)`**; chip `5`, `10`, dan `15` lap dinonaktifkan di UI.
     * **Sirkuit GRAND PRIX** (*Apex Ring*, *Brianza*, *Ardennes*, dll.): Membuka opsi **`5 LAPS (SHORT GP)`**, **`10 LAPS (STANDARD GP)`**, dan **`15 LAPS (ENDURANCE GP)`**; chip `3 LAPS` ditandai *Sprint Only*.
   - Menambahkan opsi **`DYNAMIC (LIVE RADAR)`** pada Weather System (berbasis `race_seed` + `circuit.rain_probability`, lengkap dengan tombol **`🎲 REROLL SEED`** dan **Strip *Meteo Radar Prediction* per-lap**).
   - Menambahkan opsi **`RANDOM`** pada *Time of Race* (`DAY`, `SUNSET`, `NIGHT`, `RANDOM`).
   - Menambahkan baris **Opsi A: `RACE DYNAMICS`** (`CLEAN PACE`, `FIA STANDARD`, `STREET CHAOS`) yang mengatur intensitas insiden & Safety Car sambil menjaga kecepatan AI tetap 100% autentik mengikuti **26-Driver Skill Matrix**.

---

## 2. Arsitektur Bagian A: Cel-Shaded & Living Sky/Wind Ambience (Neo-Wangan)

### 2.1 Tabel Komponen Baru di `NeoWanganEnvironment`

| Node / Shader | Lokasi | Fungsi Visual & Teknis | Anggaran Render |
| :--- | :--- | :--- | :--- |
| `SkyAmbienceRoot/AnimeMoon` | `MeshInstance3D` (`QuadMesh` / `SphereMesh`) | Bulan purnama anime berdiameter 180 m pada jarak 1.800 m searah vektor `$Sun`, dengan shader kawah *halftone* & *outer glow*. | 1 draw call, 0 shadow |
| `SkyAmbienceRoot/NightStars` | `MultiMeshInstance3D` (900 quad) | Kubah 900 bintang berkerlip di elevasi $4^\circ\text{–}88^\circ$ (`R = 2400 m`). | 1 draw call, 0 shadow |
| `SkyAmbienceRoot/AnimeNightClouds` | `MultiMeshInstance3D` (28 cluster) | 28 gugus awan malam *cel-shaded* (`shaders/neo_wangan_clouds.gdshader`) dengan *silver-cyan rim light* di ketinggian `Y = 260..420 m` yang bergeser mengikuti `wind_speed`. | 1 draw call, 0 shadow |
| `HeroLandmarksRoot/WindBannersMM` | `MultiMeshInstance3D` (24 banner) | 24 bendera/banner vertikal jalan tol & dermaga (`shaders/neo_wangan_wind_banner.gdshader`) yang berkibar dengan frekuensi proporsional terhadap `wind_speed`. | 1 draw call, 0 shadow |
| `Water` | `shaders/neo_wangan_water.gdshader` | Mengganti `StandardMaterial3D` PBR pada air teluk dengan air *cel-shaded* 2-nada, riak gelombang angin (`wind_speed`), dan pantulan garis neon terkuantisasi (tanpa *specular blob* putih). | 0 tambahan draw call (mengganti material `Water`) |
| `Skyline` | `shaders/neo_wangan_skyline.gdshader` | Upgrade shader gedung latar: `diffuse_toon`, gradasi vertikal malam, *halftone dot pattern* pada jendela menyala, *roofline neon trim*, + *outline pass*. | +1 pass pada `Skyline` |
| `StreetBillboardMM` | `shaders/neo_wangan_billboard.gdshader` | Papan reklame neon menampilkan pola huruf blok Kanji/Katakana Jepang prosedural + garis *halftone* manga & bingkai tebal. | 0 tambahan draw call |

**Total Tambahan Draw Call:** Hanya **+4 s.d. +5 draw calls** (dari 127 menjadi ~132 draw calls, masih jauh di bawah batas maksimum $\le 160$ draw calls).

---

## 3. Arsitektur Bagian B: Overhaul `Exhibition Race Setup` & `RaceConfigData`

### 3.1 Ekstensi Data pada `RaceConfigData` (`scripts/core/race_config_data.gd`)
Untuk menjaga **100% backward-compatibility** dengan seluruh unit test lama (`test_main_menu_flow.gd`, `test_track_selector_ui.gd`):
- `total_laps: int = 5` (Mendukung nilai `[3, 5, 10, 15]`).
- `weather_preset: int = 4` (Default baru untuk UI Exhibition dapat diatur atau dipilih; indeks `0..4`):
  * `0`: `SUNNY DRY` (`Weather.Archetype.DRY_SUNNY`)
  * `1`: `SHOWERS / RAIN?` (60% `DRY_TO_STORM` / `PASSING_SHOWERS`, 40% `OVERCAST_GUSTY`)
  * `2`: `DYNAMIC WET` (`Weather.Archetype.WET_DRYING` — dipertahankan kompatibel dengan `test_main_menu_flow.gd`)
  * `3`: `FULL MONSOON` (`Weather.Archetype.LATE_MONSOON` dengan air awal >72% — dipertahankan kompatibel dengan `test_main_menu_flow.gd` baris 43!)
  * `4`: **`DYNAMIC RADAR`** (Opsi baru! Memilih *archetype* dari ke-7 pola dinamis `GtWeather` secara deterministik menggunakan `race_seed` dan `get_active_circuit().rain_probability` **tanpa** menimpa `weather.forecast` dengan `lerpf`!).
- `time_of_day: int = 0` (Indeks `0..3`):
  * `0`: `DAY`
  * `1`: `SUNSET`
  * `2`: `NIGHT`
  * `3`: **`RANDOM`** (Diresolusi secara deterministik via `resolved_time_of_day()` menggunakan `GtRng.new(race_seed + 77).range_int(0, 2)`).
- `race_dynamics: int = 1` (Indeks `0..2`):
  * `0`: `CLEAN PACE` (`race.incidents_enabled = false`)
  * `1`: `FIA STANDARD` (`race.incidents_enabled = true`, standar normal)
  * `2`: `STREET CHAOS` (`race.incidents_enabled = true`, agresi dan frekuensi cuaca/insiden tinggi).
- Method baru `reroll_seed() -> int`: Mengacak ulang `race_seed = randi_range(1, 2147483647)` sehingga kurva prediksi cuaca `DYNAMIC` dan hasil undian `RANDOM` waktu balapan berubah di setiap match!

### 3.2 Tata Letak Baru `RaceSetupMenu` (`scripts/ui/race_setup_menu.gd`)
1. **Kolom Kiri (`x = 60..1200`):**
   - **Hero Map Card (`Rect2(60, 196, 1140, 640)`):**
     * Sisi Kiri Kartu (`w = 790`): Peta vektor `CircuitRadar` (`TrackMapView`) + profil elevasi.
     * Sisi Kanan Kartu (`w = 320`):
       - `VenuePreviewArt` (`TextureRect` yang memuat `selected.preview_image_path` jika ada, atau fallback visual sirkuit).
       - `TrackDemandPanel`: 3 progress bar taktis (`TOP SPEED`, `CORNERING GRIP`, `TYRE STRESS`) yang dihitung dari karakteristik sirkuit (`length_km`, `turns_count`, `elevation_delta_m`) sehingga membantu pemain memilih mobil di Garasi.
       - `VenueNotesLabel`: Deskripsi singkat sirkuit (`selected.notes`).
     * Badge Pojok Kanan Atas Peta (`CircuitStatusBadge`): Menampilkan `ACTIVE // READY` (Acid Lime) jika `selected.is_playable()`, atau `IN PREPARATION` (Cyber Yellow) jika belum tersedia.
   - **Unified 12-Round Interactive Carousel (`y = 852..956`):**
     * Menggantikan 3 kartu statis lama (`_build_venue_strip`) dan menyatukan `TrackPrevButton` (`<`) serta `TrackNextButton` (`>`) mengapit 4 kartu sirkuit interaktif (`CarouselCard0..3`) + label metadata tersembunyi/terintegrasi (`CircuitNameLabel`, `CircuitRoundLabel`, `CircuitTypeLabel`, `CircuitLengthLabel`, `CircuitTurnsLabel`) agar seluruh asersi `test_track_selector_ui.gd` tetap 100% PASS.
2. **Kolom Kanan (`x = 1240..1860`):**
   - **Header Parameter + Tombol `RerollSeedButton` (`🎲 SEED #...`)**.
   - **Baris 1 — `LAP DISTANCE` (`lap_select` dengan chips `["3", "5", "10", "15"]`):**
     * Saat sirkuit **SPRINT** dipilih: otomatis memilih indeks `0` (`3 LAPS`), mengunci chip `5`, `10`, `15` (`disabled = true` di UI), dan menampilkan badge `SPRINT LOCKED: 3 LAPS`.
     * Saat sirkuit **GRAND PRIX** dipilih: mengaktifkan chip `5`, `10`, `15` (`disabled = false`), menonaktifkan klik manual pada chip `3` (`disabled = true` di UI, namun `select_laps(3)` tetap mengizinkan pemilihan programatik untuk kompatibilitas unit test `test_main_menu_flow.gd`), dan memilih default `5` atau `10` laps.
   - **Baris 2 — `WEATHER SYSTEM` (`weather_select` dengan 5 chips: `["SUNNY", "RAIN?", "WET", "MONSOON", "DYNAMIC"]`) + `MeteoRadarStrip`:**
     * Dilengkapi panel tipis **Meteo Radar Forecast Strip** di bawahnya yang menampilkan ikon cuaca & persentase air lintasan untuk 6 titik sampel lap ke depan dari ` config.make_weather().forecast`.
   - **Baris 3 — `TIME OF RACE` (`time_select` dengan 4 chips: `["DAY", "SUNSET", "NIGHT", "RANDOM"]`)**.
   - **Baris 4 — `RACE DYNAMICS` (`dynamics_select` dengan 3 chips: `["CLEAN", "STANDARD", "CHAOS"]`)**.
   - **Stat Strip (`LENGTH`, `CORNERS`, `LAP RECORD`) & `SetupSummary`**.
