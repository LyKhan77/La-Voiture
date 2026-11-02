# FASE 22 — Pacific Coast Corkscrew (Round 07)

**Tanggal:** 2026-11-02
**Agen:** omp — Adaptive Game Tech Lead / Executor
**Branch:** `fase-22-pacific-corkscrew` (belum di-commit; menunggu izin)
**Sumber:** `mapgen-circuit/builds/pacific_corkscrew/production-handoff.md` (approved 2026-11-02) dan `Circuit-Environment-Component-Guide` v2.0.
**Status:** implementasi produksi selesai; seluruh gate sirkuit PASS; suite penuh dicatat di bagian akhir.

---

## 1. Fase 0 — verifikasi paket dan gate

### 1.1 Integritas paket

| Item | Hasil |
|---|---|
| `geometry_hash` awal | `sha256:1f4ca7aa2202c664…` — cocok dengan `lock.json` dan `manifest.json` |
| Byte `blueprint.track.json` | identik dengan `concept-2d.json` (`sha256:6c362921…`) |
| Checksum file di manifest | **stale** untuk blueprint (`b3c81745…` vs aktual `6c362921…`); file lain SAMA |
| `build_map.gd` | menolak paket karena checksum stale — persis seperti catatan handoff |
| Kesimpulan | geometri tidak drift; metadata manifest yang harus diperbaiki |

### 1.2 Gate pit flood (14 m vs 20 m)

Diukur dengan `tests/pit_flood_checks.gd` pada geometri approved, 20 mobil, lima skenario.

| Pitch | Hasil |
|---:|---|
| **14,0 m** | **GAGAL** — skenario “train of 20 cars 30 m apart”: **53 tick** overlap > 1,0 m (cap 20), kedalaman **1,90 m**; skenario lain PASS |
| **20,0 m** | **PASS** — 30/30 assertion; overlap terdalam 0,96 m, lane clear 52–185 s, semua mobil terlayani |

Tindakan (sesuai instruksi handoff, bukan tambalan produksi):

- `pit.set_pitch` 14 → 20 m diterapkan lewat `designs/pacific_corkscrew/patch_fase0_pitch.gd` yang memakai `core/patch.gd`.
- Cascade: span 140 → **200 m**, bay **s = 30..210**, service bay 5 **s = 130**, control tower **s = 222** (di luar footprint 30..210).
- `lock.json` dan `manifest.json` di-regenerate; `geometry_hash` baru: `sha256:1dcf0b856091ba429c6b7bfbd53a17286a3e0ba4091f65b4600c45256a77d3c2`.
- `procedural-spec.md` §3 diperbarui. `concept-2d.json` tidak diubah (preseden Stoke).

### 1.3 Gate kink / racing line

| Tahap | Hasil |
|---|---|
| Centreline mentah (`ribbon.get_curvature_at`) | **0 kink** |
| Gate produksi (`test_racing_line`, `line.curvature_at`) | **1 kink** di `s ≈ 3317`, κ = 0,020 — tikungan pendek T10 (Rainey) dari fillet single-arc |
| Perbaikan | homologasi spline produksi: Catmull-Rom tertutup melalui titik kontrol tiap 10 m, disampel 1 m; deviasi maksimum **0,129 m** dari centreline approved (Stoke menerima 0,092 m untuk fix kink) |
| Hasil akhir | **0 kink**, lap 4101,308 m, pace profil 217 km/h, 4/4 corner outside–apex–outside |

Tidak ada vertex, radius, atau elevasi approved yang diubah; yang diubah hanya cara spline produksi diinterpolasi (multi-control-point), sesuai guide §3.2.

---

## 2. Fase 1 — modul produksi

### 2.1 Berkas baru

```
scripts/world/circuits/pacific_corkscrew/
  pacific_corkscrew_circuit_builder.gd
  pacific_corkscrew_layout.gd
  pacific_corkscrew_environment.gd
  pacific_corkscrew_pit_complex.gd
  pacific_corkscrew_pit_building.gd   (garage interior + paddock detail)
  pacific_corkscrew_terrain.gd
  pacific_corkscrew_biome.gd
  pacific_corkscrew_catch_fence.gd
  pacific_corkscrew_model.gd
  pacific_corkscrew_strip.gd
  pacific_corkscrew_toon.gd
  pacific_corkscrew_lod.gd

scenes/race_world/circuits/pacific_corkscrew/
  pacific_corkscrew_circuit.tscn
  pacific_corkscrew_pit_complex.tscn

assets/tracks/pacific_corkscrew/
  data/blueprint.track.json, environment_strip.json, pacific_corkscrew_curve.tres
  models/lone_oak_tree.glb, pedestrian_arch_bridge.glb, corkscrew_amphitheater.glb

shaders/pacific_corkscrew/
  anime_glass.gdshader, terrain_mottle.gdshader, tree_wind.gdshader

tools/build_pacific_corkscrew_curve.gd
scratch/capture_pacific_corkscrew_views.gd
tests/test_pacific_corkscrew_circuit.gd
tests/test_pacific_corkscrew_pit_flood.gd
tests/test_pacific_corkscrew_pit_drive.gd
```

### 2.2 Terjemahan sandbox approved

- **Track:** 4.101,308 m, lebar 13 m, 11 tikungan, elevasi 0–30 m, 0 kink.
- **Pit:** entry s=3900, exit s=220, lane 420 m, fast lane centre **10,8 m** (8,5 m inner edge + 2,3 m half-lane), 10 box pitch 20 m (s 30..210), service bay 5 s=130, lateral 16,5 m, stop 3,0 s.
- **Paddock FIA:** pit building 2F/10 garasi 200 m di s=120, detail interior 10 bay (PitKit, 10 lampu kerja, 21 kolom kanopi, brace, parapet, LED, lounge glow, 20 penonton teras), grandstand 240 m kiri di s=90, race control s=222 lateral 32, start gantry 5 pasang lampu, 10 transporter, 8 motorhome, 25 mobil parkir, 9 palm, 12 umbrella, 8 sponsor board, 4 generator, 6 tenda, 120 orang, helipad.
- **Track corridor:** 4 kerb group (7 run terdeteksi; livery biru-putih 2100–3148, merah-putih sisanya), runoff/gravel, rubber groove, Armco 1.988 post, catch fence pada tiap corner ber-kerb, Tecpro, braking boards.
- **Terrain:** heightfield 12 m deterministik, bed 0,16 m, **0 buried / 0 floating**; envelope −3,37…+46,75 m; 0 node koridor di atas bed.
- **Biome:** 1.500 Coast Live Oak, 698 dry grass, 707 chaparral scrub, semua MultiMesh shadow off.
- **Landmark:** 3/3 placed (`lone_oak_tree` R 18, `pedestrian_arch_bridge` lateral 0, `corkscrew_amphitheater` L 35), 0 proxy.
- **Langit/visual:** preset Bright California Midday (matahari 68°, `#fff8e7`, langit `#4f97dd`, marine haze `#cfd9e2`), DAY/SUNSET/NIGHT aktif.

### 2.3 Polish pit lane (review feedback)

- Aspal pit lane **overlap 0,2 m** ke permukaan trek dan melebar/menyempit lewat taper 65 m, sehingga mulut lane menyatu dengan lintasan utama.
- Garis dalam fast lane konvergen dari tepi trek (6,5 m) ke 8,5 m dalam 30 m, lalu kembali ke tepi trek di merge.
- Marka: garis tepi kontinu 8,5 m dan 13,1 m, garis pemisah fast lane/working lane, bar melintang PIT IN/PIT OUT, hatch diagonal tiap 2,5 m di kedua mulut, dan tulisan datar `PIT`, `IN`, `80`, `PIT`, `OUT` pada aspal.
- Apron working lane memakai warna lebih terang (`#7a7e86`) agar fast lane, box, dan paddock terbaca terpisah.
- Screenshot gate pit sekarang mencakup `Pit_Entry`, `Pit_Entry_Aerial`, `Pit_Exit`, `Pit_Exit_Aerial`, `Pit_Lane`, `Garage_Close`.

### 2.4 Integrasi repo

- `CircuitCalendarRegistry` Round 07 sekarang menunjuk `res://scenes/race_world/circuits/pacific_corkscrew/pacific_corkscrew_circuit.tscn`.
- Preview 1920×1080 dari gate shot approved disalin ke `reference-assets/tracks/pacific_corkscrew/concept_key_visual.png`.
- Kontrak pit/environment/team assignment/signage/identity/flag panels memasukkan `pacific_corkscrew`.
- `test_track_selector_ui`: Round 07 playable, Round 08 (Eifel) tetap reserved.

---

## 3. Fase 2 — hasil gate

| Gate | Hasil |
|---|---|
| `test_pacific_corkscrew_circuit.gd` | **23/23 PASS** |
| `test_pacific_corkscrew_pit_flood.gd` | **30/30 PASS** (5 skenario, 20 m) |
| `test_pacific_corkscrew_pit_drive.gd` | **16/16 PASS** — entry 3900,000; 79,2 km/h; stop 130,000 / 16,500; service 3,200 s; merge 221,460; lap 4101,365; 0 off-asphalt |
| `test_racing_line.gd` | **PASS** — 0 kink, 24 reversal (cap 33), 217 km/h, groove |
| `test_pit_complex_contract.gd` | Pacific PASS (box/garage/re-seat/layout) |
| `test_circuit_environment_contract.gd` | Pacific PASS (38 draw call, 301.174 tri environment) |
| `test_pit_team_assignment_contract.gd` | Pacific PASS untuk player 4/11/12 |
| `test_team_signage_contract.gd` | Pacific PASS untuk player 4/11/12 |
| `test_team_identity_consistency.gd` | Pacific PASS untuk player 4/11/12 |
| `test_flag_panels_contract.gd` | Pacific PASS (8 panel, satu MultiMesh) |
| `test_track_selector_ui.gd` | **12/12 PASS** |
| `test_circuit_calendar_registry.gd` | **8/8 PASS** |
| Budget environment | **301.174 tri** (limit 320k), 38 draw call statis |
| Budget total statis | **362.154 tri** raw (kelas approved 359.684k) |
| Draw call environment native | worst **66** (limit 180), mean 60, p95 65 |
| Native 3 lap / 20 mobil | **60,0 FPS**, worst frame **16,67 ms**, 3 lap selesai, **0 orphan** |
| Visual gate | 16 PNG per TOD (6 gate + 10 pit/paddock), 0 failure, 0 orphan; pit lane + garage close-up + entry/exit aerial |
| Suite penuh | **103/103 PASS**, 0 FAIL (semua irisan, latar depan) |

---

## 4. Deviasi dan batasan

1. **Pitch 20 m** menggantikan 14 m; ini perubahan paket yang dipicu gate Fase 18 dan dilakukan lewat `core/patch.gd`. `geometry_hash` berubah menjadi `sha256:1dcf0b85…`.
2. **Spline homologasi** (Catmull-Rom 10 m, ≤ 0,13 m) untuk 0 kink T10. Layout, vertex, dan radius approved tidak diubah.
3. **Kerb 7 run**, bukan 4 seperti klaim handoff; geometri approved menghasilkan 7 segmen kurva tajam. Livery biru-putih/merah-putih tetap sesuai.
4. **Race control s=222**, bukan 200, karena footprint pit building bergeser ke 30..210 setelah pitch 20 m.
5. **Night hanya gate visual**; kalender tetap `night_race=false`.
6. **Garage close-up** memakai kamera luar-masuk; interior tetap terisi PitKit, bukan shell kosong.
7. Angka native diukur pada RTX 3050 Laptop, 1920×1080 High, tanpa HUD.

---

## 5. Cara reproduksi

```powershell
# Paket + curve
godot --headless --path . -s res://tools/build_pacific_corkscrew_curve.gd

# Gate sirkuit
godot --headless --path . -s res://tests/test_pacific_corkscrew_circuit.gd
godot --headless --path . -s res://tests/test_pacific_corkscrew_pit_flood.gd
godot --headless --path . -s res://tests/test_pacific_corkscrew_pit_drive.gd
godot --headless --path . -s res://tests/test_racing_line.gd

# Visual gate
godot --path . --resolution 1920x1080 -s res://scratch/capture_pacific_corkscrew_views.gd -- --out=executor-report/screenshots/phases/fase-22-pacific-corkscrew/day --tod=0 --set=main
godot --path . --resolution 1920x1080 -s res://scratch/capture_pacific_corkscrew_views.gd -- --out=executor-report/screenshots/phases/fase-22-pacific-corkscrew/day --tod=0 --set=pit

# Budget
godot --path . --resolution 1920x1080 --script res://scratch/measure_env_draw_calls.gd -- pacific_corkscrew 150
```

---

## 6. Suite penuh

`powershell -File tools/run_tests.ps1` dijalankan serial, latar depan, irisan maksimal 20 suite. Semua irisan hijau pada kode final (angka di bawah adalah suite yang berjalan di tiap irisan).

| Irisan | Hasil |
|---|---|
| 0–9 | 10/10 suite PASS, 177 s |
| 10–29 | 20/20 suite PASS, 407 s |
| 30–49 | 20/20 suite PASS, 143 s |
| 50–69 | 20/20 suite PASS, 529 s |
| 70–89 | 20/20 suite PASS, 839 s |
| 90–102 | 13/13 suite PASS, 219 s |
| **Total** | **103/103 PASS, 0 FAIL** |

Satu-satunya kegagalan sementara adalah `test_visual_polish_and_consistency` yang masih menganggap Round 07 “IN PREPARATION”; tes diperbarui agar Pacific playable dan Round 08 (Eifel) reserved, lalu irisan 90–102 dijalankan ulang dan PASS. Tidak ada regresi pada Apex, Neo-Wangan, Brianza, Monte Azure, Ardennes, atau Stoke Crown.

Setelah polish pit lane (entry/exit + marka), 12 tes regresi dijalankan ulang: Pacific circuit/pit drive/pit flood, lima kontrak, racing line, selector, dan visual polish — **semua PASS**. Perubahan polish bersifat visual (mesh marka, apron, hatch, label), tidak mengubah geometri sim.

Catatan eksekusi: seluruh proses Godot native/headless ditutup setelah pengujian; tidak ada window atau proses uji yang ditinggalkan.
