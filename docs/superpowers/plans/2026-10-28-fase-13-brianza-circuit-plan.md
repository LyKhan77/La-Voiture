# Rencana Implementasi: Fase 13 — Autodromo di Brianza (GP #2 - Round 03)

**Status:** Ready for Execution  
**Tanggal:** 28 Oktober 2026  
**Branch:** `fase-13-brianza-circuit`  
**Spesifikasi Terkait:** [`docs/superpowers/specs/2026-10-28-autodromo-di-brianza-track-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-28-autodromo-di-brianza-track-design.md) · [`Circuit-Environment-Component-Guide.md`](file:///D:/Occupation/Porto/genex/La_Voiture/Circuit-Environment-Component-Guide.md)

---

## 1. Tujuan & Ruang Lingkup

Membangun sirkuit Grand Prix kedua (**GP #2 — Round 03: Autodromo di Brianza**, Italia, 5.790 m, 11 tikungan) mengikuti panduan arsitektur baku **2-Tier Architecture**:
* **Tier A (Reusable Core Kit):** Menggunakan 100% komponen bersama yang sudah teruji (`road_asphalt.gdshader`, `PitLaneComplex` 410 m GP, `StartGantry`, `PitBuilding`, `MainGrandstand` + Jumbotron, `RaceControlTower`, `SharedCelSkyController`).
* **Tier B (Improvised Biome Decorator):** Biome Parco Reale di Monza (Stone Pines, Italian Cypress, rerumputan keemasan Toskana) dan 3 Hero Landmarks (jembatan layang beton bersejarah *La Sopraelevata*, gerbang bata *Villa Reale Gate*, menara *Torre Ascari*).

---

## 2. Tahapan Eksekusi Rinci

### Task 1: Fondasi Geometri Spline & Ribbon Lintasan (`brianza_circuit_builder.gd`)
* **File Target:** `scripts/world/circuits/brianza/brianza_circuit_builder.gd` & scene `scenes/race_world/brianza_circuit.tscn`.
* **Spesifikasi Teknis:**
  - `length_m`: $5,790\text{ m} \pm 20\text{ m}$.
  - Lebar koridor aspal: $14.0\text{ m}$ (lebar standar GP).
  - 11 tikungan terkalibrasi:
    1. Turn 1 & 2 (*Variante del Rettifilo* chicane) di $s \approx 580\text{ m} - 740\text{ m}$.
    2. Turn 3 (*Curva Biassono / Curva Grande*) di $s \approx 980\text{ m} - 1,520\text{ m}$.
    3. Turn 4 & 5 (*Variante della Roggia*) di $s \approx 1,880\text{ m} - 2,080\text{ m}$.
    4. Turn 6 & 7 (*Lesmo 1 & Lesmo 2*) di $s \approx 2,320\text{ m} - 2,750\text{ m}$.
    5. Turn 8, 9 & 10 (*Variante Ascari*) di $s \approx 3,650\text{ m} - 4,120\text{ m}$.
    6. Turn 11 (*Curva Parabolica / Curva Alboreto*) di $s \approx 4,980\text{ m} - 5,480\text{ m}$.
  - Elevasi profil: delta $12.0\text{ m}$ (lembut, meluncur turun di Serraglio, mendaki kembali di Parabolica).
  - Sawtooth kerb 3D bertema tricolor Italia (Hijau, Putih, Merah) dengan tinggi $+0.05\text{ m}$.

### Task 2: Pemasangan Tier A Reusable Core Kit
* Memasang `PitLaneComplex.gd` di sisi kanan Main Straight:
  - *Pit Entry:* Membelok di $s = 5,530\text{ m}$ (260 m sebelum $s=0$).
  - *Fast Lane & 10 Garasi:* 10 pit box berjarak 14 m per tim ($140\text{ m}$ span).
  - *Pit Exit:* Menyatu kembali di $s = +150\text{ m}$.
* Memasang `StartGantry` 5 lampu merah FIA di atas garis start/finish.
* Memasang `PitBuilding` 2 lantai dan `MainGrandstand` dengan layar Jumbotron live telemetry.
* Memasang `SharedCelSkyController` yang menyinkronkan matahari/bulan, awan 3D, bintang, dan pencahayaan dengan parameter `DAY / SUNSET / NIGHT`.

### Task 3: Pemodelan & Instancing Tier B Biome & Hero Landmarks (`brianza_environment.gd`)
* **Vegetasi Taman Kerajaan:**
  - Instancing `MultiMeshInstance3D` untuk 1,500+ pohon Stone Pines (*Pinus pinea*) berkanopi payung lebar dan Cypress ramping tinggi dengan shader goyangan angin *wind_foliage*.
* **Hero Landmark 1: La Sopraelevata di Monza**
  - Model 3D Blender 5.2 (`assets/tracks/brianza/models/sopraelevata_banking.glb`): struktur viaduk beton oval melengkung dengan kemiringan sudut $30^\circ$ yang melintang gagah di atas lintasan Serraglio di antara Lesmo dan Ascari.
* **Hero Landmark 2: Villa Reale Archway**
  - Gerbang neoklasik bata merah Italia di area belakang paddock.
* **Hero Landmark 3: Torre Ascari**
  - Menara pengawas vintage di zona masuk chicane Ascari.

### Task 4: Automated Test Suite & Verifikasi Visual Gate
* **Unit & Integration Test:** `tests/test_brianza_circuit.gd` (memverifikasi panjang 5.79 km, 11 tikungan, pit layout FIA, collision wall, clearance, dan integrasi dengan `RaceConfigData` serta `RaceWeekendWorld`).
* **Visual Gate (6 Sudut Pandang Kamera + Day/Sunset/Night):**
  - Cam 1: Main Straight & Paddock
  - Cam 2: Curva Grande & Royal Park Canopy
  - Cam 3: Sopraelevata Concrete Viaduct Overpass
  - Cam 4: Curva Parabolica & Pit Entry
  - Cam 5: Sky & Horizon Overview
  - Cam 6: Player Chase Cam Action
* **Performance Budget Gate:**
  - Draw Calls $< 160$ per kamera.
  - Triangles Lingkungan $< 320,000$.
  - Framerate: 60 FPS locked (16.66 ms) pada 1080p High.
