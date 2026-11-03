# FASE 25 — Eifel Forest Ring (Ronde 08 AUG GER) — implementasi produksi

**Tanggal:** 2026-11-03
**Agen:** omp — Executor
**Branch:** `fase-25-eifel-forest`
**Paket:** `mapgen-circuit/builds/eifel_forest/production-handoff.md` (revisi T13 2026-11-03)
**Geometry hash:** `sha256:8de6956c723c4f4037054e1c8317e103e12ff7704f285ea89e6a18ed951eaa3c`

---

## Ringkasan

Sirkuit **Eifel Forest Ring** (5.150 m, 16 tikungan, 13 m aspal, Δelevasi 30 m, pit
kanan 410 m) sudah playable sebagai Ronde 08. Modul produksi menerjemahkan sandbox
Route 2 yang disetujui, bukan mendesain ulang: kurva kompilasi blueprint identik
dengan sandbox (0,000000 m), empat GLB landmark disalin, dan seluruh gate repo lulus.

Fase 0 menemukan **1 kink** di T13 (s=4128, fillet 54 m). Homologasi Catmull-Rom
Stoke/Pacific (deviasi 0,028–0,110 m) dan spline handle melalui seluruh 5.150 titik
(0,00376 m) tidak menghapusnya. Atas persetujuan user, radius fillet T13 direvisi
**54,0 → 110,0 m** lewat `core/patch.gd` (vertex tidak bergerak; peak κ 0,0140 →
0,0091; panjang lap 5.150,730 m). `lock.json` + `manifest.json` di-re-freeze,
sandbox dibangun ulang (422.938 tri, 109 surface, 4/4 landmark, 0 proxy), dan
validator tetap **26 PASS / 0 WARN / 0 FAIL**.

## Deliverable

| Area | File |
|---|---|
| Layout & konstanta | `scripts/world/circuits/eifel_forest/eifel_forest_layout.gd` |
| Builder kurva/turns | `scripts/world/circuits/eifel_forest/eifel_forest_circuit_builder.gd` |
| Environment | `eifel_forest_environment.gd` (Tier A corridor + Tier B biome + sky) |
| Pit complex | `eifel_forest_pit_complex.gd`, `eifel_forest_pit_corridor.gd`, `eifel_forest_paddock_detail.gd` |
| Terrain/biome | `eifel_forest_terrain.gd`, `eifel_forest_strip.gd`, `eifel_forest_toon.gd`, `eifel_forest_catch_fence.gd`, `eifel_forest_steel_fence.gd` |
| Scene | `scenes/race_world/circuits/eifel_forest/eifel_forest_circuit.tscn`, `eifel_forest_pit_complex.tscn` |
| Aset | `assets/tracks/eifel_forest/data/eifel_forest_curve.tres`, `assets/tracks/eifel_forest/models/*.glb` (4 hero landmark) |
| Shader | `shaders/eifel_forest_{anime_glass,steel_mesh,terrain_mottle,tree_wind}.gdshader` |
| Tes | `tests/test_eifel_forest_{circuit,pit_drive,pit_flood}.gd` + 7 suite kontrak diperluas |
| Registri | `CircuitCalendarRegistry` Ronde 08 → scene produksi |
| Preview | `assets/ui/circuit_maps/previews.res` di-rebake (2.576 sampel Eifel) |
| Capture | `executor-report/screenshots/phases/phase-25-eifel-forest/{day,pit,sunset,night}` |

## Gate produksi

| Gate | Hasil | Bukti |
|---|---|---|
| Kurva & turns | **PASS** | 5.150,730 m; 16 turns bernama; 4/4 landmark; 0 `Pending_*` |
| Pit flood 14 m | **PASS 0 FAIL** | 5 skenario × 20 mobil; release mean 0,29 s, max 3,2 s |
| Pit drive | **PASS 16/16** | entry 4950 (79,2 km/h), stop s=127 / lateral 16,5, servis 3,2 s, merge 211,86, 0 frame off-asphalt, lap 5.150,730 m |
| Terrain | **PASS** | 0 buried, 0 floating (asphalt tiap 6 m); pit apron 0/0 |
| Landmark | **PASS** | castle, arena, flyover, archway 4/4; base on terrain/deck |
| Kontrak repo | **PASS** | pit complex, environment, flag panels, team assignment, signage, identity, pit straightness |
| Racing line | **PASS** | 0 kink; 32 reversals (cap 48); 8/8 corners outside-apex-outside; 203 km/jam |
| Selector/preview/minimap | **PASS** | Ronde 08 playable, poster 640×360, map baked |
| Suite penuh | **PASS** | 108/108 suite, 0 FAIL (`tools/run_tests.ps1`, 5 irisan) |
| Native smoke | **PASS** | 3 lap / 20 mobil: 20/20 finis, podium, 0 orphan |
| Frame time | **PASS** | DAY mean 16,67 ms; SUNSET 16,67; NIGHT 16,66 (p95 16,80–17,07) |
| Draw calls | **PASS** | environment worst 169 (limit 180), `measure_env_draw_calls.gd` |
| Environment triangles | **PASS (approved class)** | 424.808 (approved Route 2 total 423.450; corridor included) |

## Deviasi / keputusan yang dicatat

1. **Pitch 14 m dipertahankan** (keputusan user). Gate flood Eifel lulus 0 FAIL;
   standar umum 20 m di panduan lahir dari lane lain. Jika 20 m diwajibkan, span
   200 m menabrak exit s=210 dan paket harus kembali ke Map Planner.
2. **T13 radius 110 m** (revisi geometri disetujui; lihat Fase 0). Sandbox dan
   paket di-re-freeze; bukan perubahan lokal di sisi produksi.
3. **`BED_WINDOW_SAMPLES` 4 → 2** pada terrain: sampling produksi yang lebih rapat
   (tiap 6 m, 858 titik) menemukan 6 titik bed −0,40 m; jendela ±2 m mempertahankan
   road bed −0,16 m dan 0 floating/0 buried. Profil elevasi beku tidak berubah.
4. **`fast_lane_m` = 10,8 m** di sim: blueprint 8,5 m adalah tepi dalam fast lane
   4,6 m; pusat lane (yang dikendarai) 10,8 m, sama dengan dummy car sandbox.
5. **Triangles 424.808** melebihi angka generik 320k di panduan, tetapi sesuai total
   Route 2 yang disetujui (423.450) dan handoff gate #5; angka generik 320k berlaku
   untuk environment tanpa corridor kit.
6. **Shadow policy**: hanya hero landmark + struktur pit building/grandstand/tower
   yang cast shadow; terrain, furniture, fence, paddock, pit paint, sign, crew,
   transporter, detail garasi dimatikan. Draw call worst turun 253 → 169.
7. **Native p95** 16,80 (DAY/SUNSET) dan 17,07 (NIGHT) sedikit di atas 16,66;
   mean 16,66–16,67 dan 60 FPS. Sama dengan catatan p95 sirkuit lain di repo.
8. **Capture FPS 12–16** pada `capture_eifel_forest_views.gd` karena world
   `PROCESS_MODE_DISABLED`; angka frame time yang valid berasal dari `smoke_race.gd`.
9. **Grid/full-race pit**: 3 lap 20 mobil tanpa error; pit drive & flood memakai sim
   produksi, bukan DummyCar sandbox. Compression/extension visual DummyCar tidak
   tersedia di `GtCar` produksi dan tidak diklaim.
10. **Satu directional light**: scene sirkuit tidak membawa `Sun` sendiri (pola
    Stoke/Pacific); `RaceWeekendWorld` menyediakan `Sun` dan `bind_world`
    mengarahkannya. Ini mencegah dua matahari yang membuat aspal/rumput terlalu
    terang. Capture final dirender ulang setelah perbaikan.

## Bukti visual

- `day/` — 7 kamera: start/pit, archway S1, arena S2, castle S3, flyover, sky/horizon, chase.
- `pit/` — 10 kamera: entry, entry aerial, lane, garage close, paddock aerial/front, grandstand, race control, exit, exit aerial.
- `sunset/`, `night/` — 7 kamera masing-masing; moon, stars, clouds, lampu pit.
- Semua 1920×1080, 0 failure, 0 orphan setelah free.

## Catatan operasional

- `designs/eifel_forest/final/blueprint.track.json` diubah **hanya** lewat
  `core/patch.gd`; backup pre-revisi di `builds/eifel_forest/temp/backup_pre_t13/`.
- Mapgen repo bukan git; perubahan paket tercatat di `production-handoff.md` dan
  `build-report.md`.
- Repo produksi tidak membaca mapgen saat runtime; strip dan kurva sudah dibekukan
  ke `eifel_forest_strip.gd` / `eifel_forest_curve.tres`.
