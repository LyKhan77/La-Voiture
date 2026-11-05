# FASE 0 — Paulistano Speed Arena: paket, kink, pit kiri, pit flood, audit

**Tanggal:** 2026-11-04
**Agen:** Claude Code (Opus 5.5) — Tech Lead / Executor
**Branch:** `fase-26-paulistano`
**Paket:** `D:/Occupation/Porto/genex/mapgen-circuit/builds/paulistano/production-handoff.md`
**Geometri:** `sha256:e7e318e7536e714cc6ed9979d1e26caac821890d8d2e9b70c7d06822284990cb`
**Status:** **SELESAI.** Satu deviasi pit flood disetujui developer. Collider mengikuti standar repo (disetujui). `designs/` tidak disentuh.

---

## Ringkasan gate

| Gate | Hasil | Bukti |
|---|---|---|
| Checksum paket beku | **PASS 3/3 SAMA** | `blueprint.track.json` `67f2e2f6…b412`, `environment_strip.json` `0c8afba2…1105`, `procedural-spec.md` `c86f115e…c34b` |
| Geometry hash | **PASS** | `core/hash.gd` = `lock.json` = handoff `e7e318e7…90cb` |
| Schema + validator | **PASS 26 / WARN 0 / FAIL 0** | `core/schema.gd`, `core/validator.gd` |
| Kurva homologasi | **PASS** | 4.310 titik blueprint = sandbox, Δ maks **0,000000 m**; baked 4.313,035 m |
| Kink / racing line | **PASS 0 kink** | definisi `tests/test_racing_line.gd::_check_kinks` |
| Pit flood pitch 14 m (kanan, baseline) | **1 FAIL** | release maks 7,9 s (batas 7 s), seed 31, skenario "3–9 s apart" |
| Pit flood pitch 14 m (kiri, setelah fix sim) | **1 FAIL yang sama → deviasi disetujui** | 4 seed lain 0 FAIL |
| Manifest metadata | **Tidak diregenerasi** | lihat §6 |

Probe: `temp/paul_fase0_package_probe.gd` (dijalankan dengan `--path mapgen-circuit`), `temp/paul_fase0_gate_probe.gd`, `temp/paul_left_flood_probe.gd`, `temp/paul_flood_trace.gd` (gitignored).

## 1. Paket dan kurva

Kurva dikompilasi ulang dari `final/blueprint.track.json` dengan `core/compiler.gd` dan dibandingkan titik demi titik dengan `Curve3D` sandbox `builds/paulistano/scene/paulistano_build.tscn`:

```
[hash] computed sha256:e7e318e7…90cb  lock … match=true
[validator] schema errors: 0   PASS 26 / WARN 0 / FAIL 0
[curve] compiled 4310 points, length 4310.000 m
[curve] sandbox 4311 points, baked 4313.035 m
[curve] compared 4310 points, max delta 0.000000 m, closes loop true
```

Hasil: `assets/tracks/paulistano/data/paulistano_curve.tres`.

## 2. Kink gate

```
[fase0] centreline kinks: 0 []
```

Tidak ada revisi spline yang diperlukan.

## 3. Pit kiri: temuan di sim dan kit bersama

Semua sirkuit produksi sebelumnya punya pit di kanan (`PIT_SIDE := 1.0`). Audit menemukan asumsi "pit = lateral positif" di tiga lapisan.

**Sim GT** (3 titik bergantung tanda; sisanya `lerp`/`absf` sudah netral):

| Lokasi | Asumsi lama | Perbaikan |
|---|---|---|
| `gt_driving.gd` OUT merge-away | `other.lateral < car.lateral`, `maxf(..., other.lateral + band)` | dibandingkan dalam frame sisi pit (`side * lateral`) |
| `gt_driving.gd` antrean tim | `stall_lane_m + 0.6` | `+ 0.6 * side` |
| `gt_race.gd` safety car peel | `lateral >= edge_lateral_m` | `lateral * side >= edge * side` |

`GtRace.pit_side_of(layout)` membaca tanda dari `stall_lane_m`, jadi tidak ada kunci layout baru. Untuk sirkuit kanan, `side = 1.0`, sehingga ekspresinya identik bit demi bit.

**Bukti RED → GREEN** (flood Paulistano dengan layout kiri, seed 31):
- sebelum fix: `bunched 20 m apart` **FAIL**, 23 tick overlap > 1 m;
- sesudah fix: 0 tick. 4 seed tambahan (7, 13, 101, 2024) 0 FAIL.

**Kit bersama** (sebelumnya kanan tertanam di kode):

| Komponen | Perbaikan |
|---|---|
| `PitZone.from_layout` | menyimpan `side` dari tanda `stall_lane_m`; `PitZone.side_of(zone)` |
| `TracksideFurnitureBuilder.armco_ranges_for` | membuka rail di sisi zona, bukan selalu kanan |
| `TracksideFurnitureBuilder._build_flag_panels` | panel yang jatuh di jendela pit pindah ke sisi seberang zona |
| `EnhancedTrackGeometry.plan_runoffs` | parameter `pit_side` (default +1) |
| `StartGantry` | `@export pit_side` (sayap dan papan ikut sisi pit, tanpa mirror) + `@export venue_name` |

Ini menggantikan filter lokal sandbox (`_optimize_armco` membuang 125 post, `_relocate_pit_flag_panels`, mirror gantry + `Label3D.scale.x = -1`), sesuai Deviasi #2 dan #3 handoff.

## 4. Pit flood pitch 14 m

| Skenario (seed 31) | Servis | Lane kosong | Stand-still | Overlap > 1 m | Release maks |
|---|---:|---:|---:|---:|---:|
| train 30 m | 20/20 | 55 s | 7,7 s | 18 tick | — |
| bunched 20 m | 20/20 | 52 s | 7,5 s | 0 | — |
| spread lap | 20/20 | 124 s | 0,1 s | 0 | — |
| raced field all-box | 20/20 | 126 s | 8,8 s | 12 tick | — |
| raced field 3–9 s apart | 20/20 | 235 s | 3,0 s | 0 | **7,9 s (batas 7)** |

**Investigasi:**
- Menggeser building (centre s=90 → 76 → 62) menghasilkan angka **identik**. Posisi bay terhadap pit exit bukan penyebab.
- Trace per detik untuk mobil yang tertahan:
  - 0–5,5 s: dua mobil lewat di fast lane menuju box hilir;
  - 6–7,9 s: mobil kedua tim di box 14 m di depan sedang masuk box.

  Semua hold itu benar. Melepas mobil saat itu akan menimbulkan tabrakan.
- Dua aturan release dicoba di `gt_driving.gd`, masing-masing dengan regresi unit RED → GREEN: "first held, first out" dan "mobil yang sedang keluar box di depan tidak menahan". Keduanya tidak mengubah 7,9 s, jadi **di-revert**. Sim bersama tidak diubah tanpa manfaat.
- Pitch 20 m tidak muat: span 200 m melewati pit exit s=160.

**Keputusan developer (2026-11-04):** terima pitch 14 m. `test_paulistano_pit_flood.gd` menjalankan semua cek di seed 31. Khusus batas release dinaikkan ke 8 s lewat `pit_flood_checks.release_max_s`, dengan alasan tercatat di header tes.

## 5. Collider

Handoff mewajibkan `StaticBody3D` yang cocok dengan visual. Fakta repo: **0 `StaticBody3D`** di 8 sirkuit produksi. Mobil digerakkan sim GT (s/lateral, kontak SAT antar mobil, batas trek lewat `clamp_to_width`), bukan physics body. Collider scenery tidak akan pernah dibaca.

**Keputusan developer:** ikuti standar repo. Gate collider diganti gate clearance statis di `tests/test_paulistano_circuit.gd`:
- floodlight di luar jalan, dan ≥ 60 m di belakang paddock kiri sepanjang pit;
- tidak ada flag panel atau braking board di koridor pit kiri;
- rail kiri terbuka sepanjang lane dan rail kanan menerus;
- sign PIT IN / 80 / PIT OUT di lateral −17,75 m;
- landmark di luar jalan + apron;
- sayap gantry menutupi lane kiri, sedangkan pylon kanan di luar jalan.

## 6. Audit visual/sipil: temuan dan tindakan

| # | Temuan (sandbox) | Tindakan produksi |
|---|---|---|
| 1 | Warna crew per bay terbalik terhadap urutan box. `_build_pit_boxes` memakai frame yang diputar 180° dengan `local_z` kit, sehingga bay 0 jatuh di box 9. | Crew per garasi di `PaulistanoPitComplex`, mengikuti tim yang duduk di box (kontrak team assignment). |
| 2 | Bay detail paddock (stripe tim, rak, figur) terbalik dengan alasan yang sama | `paulistano_paddock_detail.gd` memakai `z = -PIT_SIDE * pitch * (bay - 4.5)` |
| 3 | Shutter `PitBuilding` diputar 180° sehingga urutan bay terbalik | `building_team_order()` membalik id; tes memastikan bay 0 bangunan berdiri di garasi box 9 |
| 4 | Cat box diputar dengan `rotated(Vector3.UP, PI)`, sehingga pitch terbalik di straight yang menanjak | `Layout.side_frame` (rotasi di sumbu up trek) |
| 5 | Crew/car butuh −Z = arah laju di pit kiri; rotasi 180° akan menaruh jack man di ekor | `Layout.box_frame`: sumbu X dicerminkan, −Z tetap arah laju |
| 6 | Floodlight sisi pit di lateral 15,25 m (di dalam lane). Sandbox memindahkannya ke kanan, lalu tower s=77 dipindah ke s=190 karena kena kanopi stand. | Hero zone kit: sisi kiri sepanjang pit + 70 m → lateral 75 m (di belakang paddock); stand kanan s −80…180 → 64 m; Senna terrace → 140 m |
| 7 | Stasiun tikungan = titik terdekat ke vertex polyline: 13/15 terbaca radius 10.000 (lurus) | Builder mencari puncak \|κ\| ±80 m: 15/15 di tikungan |
| 8 | Road bed −0,41…−0,47 m di T1 Drop Braking (s 318–408, turunan ±12 %) dengan window ±2 m | `BED_WINDOW_SAMPLES` 2 → 1: 0 buried / 0 floating |
| 9 | `ground_y_at` hanya membaca terrain; pit lane di atas apron beton terbaca "melayang" 0,5–0,74 m karena pad bangunan sengaja −0,58 m | `ground_y_at` = max(terrain, slab apron paddock), sesuai kontrak base "top of the solid ground" |
| 10 | Palem raja: segitiga degenerate per pelepah + 7 cincin batang 0,16 m (84 tri) | 3 cincin, tanpa degenerate: 132 → 75 tri/pohon; total env 450k → 415k |
| 11 | Blueprint `control_tower_s` = 0,0 vs handoff/spec s=20 lateral 25 | Mengikuti handoff yang disetujui (s=20). Nilai blueprint tetap di hash, tidak diubah. |
| 12 | `manifest.json` tanpa `geometry_hash`, `files` berbentuk objek | Tidak diregenerasi (wewenang Map Planner). Produksi memverifikasi hash langsung dengan `core/hash.gd` dan lock. Tidak memblokir. |

**Temuan di luar cakupan** (dicatat, tidak diubah): `EifelForestPitComplex._build_pavement` memberikan station s ke `get_pit_transform(u)`, yang memperlakukannya sebagai u dari entry. Akibatnya apron kerja Eifel tergambar di s≈5000–5140, bukan di bawah box (s 50–190). Paulistano memakai `u_from_s` dengan benar.

## 7. File Fase 0

| Path | Status |
|---|---|
| `assets/tracks/paulistano/data/paulistano_curve.tres` | baru (kompilasi blueprint, identik sandbox) |
| `scripts/gt/gt_race.gd`, `scripts/gt/gt_driving.gd` | pit side-aware (sirkuit kanan identik) |
| `executor-report/reports/FASE-0-PAULISTANO-GATE-REPORT.md` | laporan ini |
| `temp/paul_*` | probe scratch, gitignored |
