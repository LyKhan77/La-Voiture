# FASE 26 — Paulistano Speed Arena (Ronde 09 SEP BRA) — implementasi produksi

**Tanggal:** 2026-11-04
**Agen:** Claude Code (Opus 5.5) — Tech Lead / Executor
**Branch:** `fase-26-paulistano` (belum di-commit)
**Paket:** `mapgen-circuit/builds/paulistano/production-handoff.md`
**Geometry hash:** `sha256:e7e318e7536e714cc6ed9979d1e26caac821890d8d2e9b70c7d06822284990cb`
**Fase 0:** [`FASE-0-PAULISTANO-GATE-REPORT.md`](FASE-0-PAULISTANO-GATE-REPORT.md)

---

## Ringkasan

**Paulistano Speed Arena** sudah playable sebagai Ronde 09: 4.310 m, 15 tikungan, counter-clockwise, aspal 13,5 m, Δelevasi 40 m, hujan 0,70. Ini sirkuit produksi pertama dengan **pit kiri**.

Modul ini menerjemahkan sandbox Route 2 yang disetujui, bukan mendesain ulang:
- kurva blueprint identik dengan sandbox (Δ 0,000000 m);
- 4 GLB landmark disalin;
- biome, terrain, dan paddock di-port.

Pit kiri diimplementasikan di sim dan kit bersama, bukan dengan filter lokal. Sirkuit lain identik atau menjadi lebih benar (lihat §Perubahan bersama).

## Deliverable

| Area | File |
|---|---|
| Layout | `scripts/world/circuits/paulistano/paulistano_layout.gd` (`PIT_SIDE = -1`, `side_frame`, `box_frame`) |
| Builder | `paulistano_circuit_builder.gd` (stasiun tikungan = puncak \|κ\|) |
| Environment | `paulistano_environment.gd` (Tier A corridor + reservoir, apron paddock, biome Mata Atlântica, sky badai tropis) |
| Pit complex | `paulistano_pit_complex.gd`, `paulistano_pit_corridor.gd`, `paulistano_paddock_detail.gd` |
| Terrain/biome | `paulistano_terrain.gd`, `paulistano_strip.gd`, `paulistano_toon.gd`, `paulistano_catch_fence.gd`, `paulistano_steel_fence.gd` |
| Scene | `scenes/race_world/circuits/paulistano/paulistano_circuit.tscn`, `paulistano_pit_complex.tscn` |
| Aset | `assets/tracks/paulistano/data/paulistano_curve.tres`, `assets/tracks/paulistano/models/*.glb` (Senna terrace, kartódromo, Guarapiranga, menara paddock historis) |
| Shader | `shaders/paulistano_{anime_glass,steel_mesh,terrain_mottle,tree_wind}.gdshader` |
| Tes baru | `tests/test_paulistano_{circuit,pit_drive,pit_flood}.gd` |
| Registri / preview | Ronde 09 → scene produksi; `assets/ui/circuit_maps/previews.res` di-rebake (10/10 verify) |
| Capture | `scratch/capture_paulistano_views.gd` → `executor-report/screenshots/phases/phase-26-paulistano/{day,sunset,night,pit}` |

## Perubahan bersama (semua sirkuit)

| File | Perubahan | Dampak sirkuit lain |
|---|---|---|
| `gt_race.gd`, `gt_driving.gd` | `GtRace.pit_side_of`; 3 perbandingan lateral pit dibuat sadar sisi | identik (`side = 1`) |
| `pit_zone.gd`, `trackside_furniture_builder.gd`, `enhanced_track_geometry.gd` | sisi pit dibaca dari zona: rail, runoff, dan relokasi flag panel | identik (default kanan) |
| `start_gantry.gd` | `pit_side`, `venue_name`, `set_lights(pairs, silent)` | default identik |
| `circuit_pit_complex.gd` | `building_team_order()` (default = urutan box) | identik |
| `race_weekend_world.gd` | shutter memakai `pit_lane.building_team_order()`; **gantry milik sirkuit mengganti gantry world** | **perbaikan:** Stoke, Pacific, dan Eifel sebelumnya punya 2 gantry bertumpuk, dan lampu gantry sirkuit (dinyalakan 5 saat build) tetap merah setelah lights-out |
| `tests/pit_flood_checks.gd` | `release_max_s` (default 7 s) | identik |

## Gate produksi

| Gate | Hasil | Bukti |
|---|---|---|
| Paket / hash / validator / kurva | **PASS** | 3/3 checksum, hash = lock, 26/0/0, Δ 0,000000 m |
| Kink / racing line | **PASS** | 0 kink; `test_racing_line` (registri) PASS |
| Pit drive (setara 25/25 sandbox) | **PASS 17/17** | entry 4060 @ 79,2 km/h; stop s=97,000 / lateral −16,500; servis 3,2 s; merge 162,06; seluruh lane di kiri (maks −5,20 m); 0 frame off-asphalt; lap 4.313,035 m |
| Pit flood 14 m | **PASS dengan 1 deviasi disetujui** | release maks 7,9 s (batas Paulistano 8 s, bukti di Fase 0 §4); 4 seed lain 0 FAIL |
| Terrain | **PASS** | aspal tiap 6 m: 0 buried / 0 floating; pit lane 0/0; envelope −6,03…+50,13 m |
| Landmark | **PASS 4/4** | 11.098 tri, 0 proxy, semua di luar jalan + apron |
| Pit lane bersih / clearance (pengganti collider) | **PASS** | rail kiri terbuka sepanjang lane, rail kanan menerus; floodlight ≥ 60 m di belakang paddock kiri; 8 flag panel, 0 di koridor pit; 0 braking board di koridor; sign di −17,75 m |
| Gantry | **PASS** | 1 gantry, sayap di atas lane kiri, lampu menghadap grid, papan "PAULISTANO SPEED ARENA" |
| Box ↔ garasi ↔ shutter ↔ interior | **PASS** | kontrak baru: tiap shutter berdiri di box tim yang dikenakannya; interior mengikuti seat |
| Kontrak repo | **PASS** | pit complex, environment, flag panels, team assignment, signage, identity, straightness, selector |
| Suite penuh | **PASS 111/111, 0 FAIL** | `tools/run_tests.ps1`, 6 irisan, setelah perubahan terakhir |
| Native smoke 3 lap / 20 mobil | **PASS** | DAY/SUNSET/NIGHT: 20/20 finis, podium, 0 orphan, 0 script error |
| Frame time | **60 FPS** | mean 16,59–16,83 ms antar-run (noise laptop yang sama di semua TOD), p95 16,8–19,5 ms |
| Draw call environment | **PASS** | terburuk 133 (limit 180), p95 124, mean 68 (`measure_env_draw_calls.gd`) |
| Segitiga environment | **PASS (kelas 430k)** | 415.300 (corridor kit penuh); ±386k–467k terlihat per view di smoke |
| Capture | **32 PNG 1920×1080** | day 7, sunset 7, night 7, pit 11; 0 failure, 0 orphan |

## Regresi yang dilihat gagal dulu (RED → GREEN)

1. Flood dengan layout kiri sebelum fix sim: `bunched 20 m` 23 tick overlap → 0.
2. Interior garasi mengikuti seat: FAIL dengan warna bay statis → PASS.
3. `test_pit_team_assignment_contract` "shutter di box timnya": Paulistano FAIL ×3 sebelum fix world → PASS; sirkuit lain PASS sebelum dan sesudah.
4. `test_pit_complex_contract` "satu gantry, gelap sebelum start": 4 FAIL (Stoke, Pacific, Eifel, Paulistano) sebelum fix world → 9/9 PASS.

## Deviasi / keputusan yang dicatat

1. **Release flood 7,9 s** (batas 7 s) pada seed 31. Hold yang terjadi sah, dan perbaikan release sudah dicoba lalu di-revert. Disetujui developer.
2. **Tanpa StaticBody3D**, sesuai standar repo dan disetujui developer. Gate clearance menggantikannya.
3. **Pitch 14 m** dipertahankan. 20 m tidak muat sebelum exit s=160.
4. **Kontrol tower s=20** mengikuti handoff/spec, meski blueprint `control_tower_s` = 0,0.
5. **`BED_WINDOW_SAMPLES` 1** untuk turunan T1 sekitar 12 %.
6. **Palem raja 75 tri** (dari 132): cincin 7→3 dan segitiga degenerate dihapus.
7. **Manifest mapgen** tanpa `geometry_hash` tidak diregenerasi (wewenang Map Planner).
8. **Malam** hanya gate visual (`night_race=false`).
9. **Di luar cakupan, tidak diubah:** `EifelForestPitComplex._build_pavement` mengirim station s sebagai u, sehingga apron kerja Eifel tergambar di s≈5000–5140, bukan di bawah box.
10. **Efek samping Godot import**: `.import` poster/GLB lain, `default_bus_layout.tres`, dan `reference-assets/...png.import` ditandai `M` hanya karena CRLF; isinya identik dengan HEAD dan sudah di-checkout ulang. Tiga `.uid` tes yang hilang dibuat ulang oleh Godot (`test_garage_engine_test`, `test_garage_transition_engine`, `test_pit_mouth_pavement`).

## Bukti visual

- `day/`: start/pit, Senna S1, kartódromo S2, reservoir S3, menara S3, sky/horizon, chase.
- `pit/`: entry, entry aerial, lane, garage close, paddock aerial/front, grandstand, race control, start gantry, exit, exit aerial.
- `sunset/`, `night/`: 7 kamera masing-masing.

## Revisi 1 — terrain paddock & pit wall (2026-11-04, review developer)

**Pit wall tembus saat entry.** Wall corridor turunan sandbox dimulai pada konstanta u=45 m dan aspal lane menyempit 40 m, sedangkan sim memakai blend 80 m. Akibatnya bodi mobil menembus wall hingga 1,02 m (Paulistano, 189 car-tick pada flood bunched) dan 0,77 m (Eifel, 140 car-tick). Sirkuit lain memulai wall di u=58–85 m (0 overlap).
- Perbaikan: corridor Paulistano dan Eifel kini digambar dari `GtRace.lane_lateral_at` (layout sim). Rentang wall dihitung dari clearance sisi bodi ≥ 0,45 m (Paulistano u 59,9–387,1; Eifel u 55,8–386,8). Impact attenuator dipasang di nose wall.
- Regresi `test_{paulistano,eifel_forest}_pit_drive`: RED 26+552 / 21+390 car-tick → GREEN 0. Race 1× terekam (55 frame entry–box–exit), tanpa tembus.

**Terrain paddock menggantung.**
- Akar masalah: spesifikasi pad terrain duplikat dan tidak sinkron dengan slab (8–62 vs 8–66 m). Pad −0,74 m dan melewati sel < 38 m. Berm hanya lateral. Terrace landmark (Senna, menara) menimpa apron.
- Perbaikan: `Layout.PADDOCK_APRON_SPECS` jadi satu sumber. Pad diletakkan 6 cm di bawah slab dengan uji "ruas sendiri" lewat stasiun terdekat. Berm 36 m mengelilingi seluruh perimeter. Terrace landmark tidak menimpa apron. Retaining wall dan tutup ujung turun sampai terrain dan naik menjadi parapet bila terrace lebih tinggi.
- Gate mesh render: 2.226 kaki wall, 0 menggantung, 0 tepi tertimbun. Pada terrain lama, 269 sampel meleset (terburuk 10,48 m).

**Verifikasi ulang:** suite penuh 111/111 PASS. Smoke 3 lap / 20 mobil Paulistano DAY/SUNSET/NIGHT dan Eifel DAY: 20/20 finis, 60 FPS (mean 16,67 ms), podium, 0 orphan, 0 script error.

## Revisi 2 — waduk Guarapiranga (2026-11-05, review developer)

**Temuan:**
- Air berupa pita quad datar satu warna yang sejajar lintasan (lateral 75–355 m). Material air animasi di toon look tidak pernah tersambung, karena mencari node `River`.
- Ujung pita air menggantung di atas lereng.
- Basin diukir sebagai pita lurus di grid 12 m tepat di samping massa bukit laterit 26 m (pusat ~110 m dari pusat danau). Akibatnya dasar datar −5,9 m langsung melonjak ke +30 m, membentuk deretan piramida (spike vertex maks 29,7 m; 668 vertex > 3,5 m).

**Perbaikan:**
- **Bentuk danau:** `PaulistanoTerrain.lake_shape()`, superellipse sejajar seawall GLB. Sisi dekat lurus di bawah seawall (lateral 46 m); sisi jauh dan ujung membulat dengan noise.
- **Profil basin:** shelf 0,4 m mendalam ke 3,8 m dalam 45 m (18 m di seawall). Tepian 80 m naik dari waterline ke relief alami dan memudar ke zona blend jalan. Cekungan cos² lama dan pita `_stamp_lake` dihapus.
- **Air:** mesh air dibangun per sel grid di bawah waterline di dalam bentuk danau, jadi garis pantai mengikuti kontur terrain. Kedalaman per vertex diteruskan ke shader baru `shaders/paulistano_water.gdshader`: shelf cel dangkal/tengah/dalam, swell silang, buih pantai yang bernapas, dan warna per DAY/SUNSET/NIGHT. Shader tidak membaca depth texture, jadi aman untuk semua renderer.
- **GLB waduk:** dijangkar ke waterline (promenade 7,25 m di atas air, sehingga ponton dan lambung perahu terapung). Teras seawall rata dengan promenade (s 1625–1975).
- **Foliage:** tidak ditanam di air maupun tepian basah.

**Gate (`test_paulistano_circuit`):**
- GLB di waterline.
- 0 tanaman di air.
- 0 vertex air di luar basin.
- Spike basin/tepian ≤ 3,5 m, dikalibrasi ke ekor relief alami (p99,9 3,03 m). Gate yang sama pada danau lama: 668 vertex melampaui.
- Envelope terrain kini −6,22…+50,13 m.

**Verifikasi:** suite penuh 111/111 PASS. Smoke DAY/NIGHT: 20/20 finis, 60 FPS, podium, 0 orphan, 0 error.
