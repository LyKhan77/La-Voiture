# FASE 13.1 — Autodromo di Brianza Environment Overhaul (Arsitektur 6-Lapis)

**Tanggal:** 28 Oktober 2026 · **Branch:** `fase-13-1-brianza-environment-overhaul` · **Engine:** Godot 4.7.2 stable
**Spesifikasi:** `docs/superpowers/specs/2026-10-28-fase-13-1-brianza-environment-overhaul-design.md` · **Rencana:** `docs/superpowers/plans/2026-10-28-fase-13-1-brianza-environment-overhaul-plan.md`

---

## 1. Ringkasan

Lingkungan Brianza dirombak dari whitebox menjadi enam lapis (`scripts/world/brianza_environment.gd`). Spline `TrackRibbon`, elevasi 12,0 m, dan pit lane 10 stall **tidak disentuh**. Tidak ada jalan melayang: tanah padat di bawah setiap titik jalan, pohon, tribun, pagar, dan tiang.

| Lapis | Hasil |
| :--- | :--- |
| 1 Ground | `ParcoRealeGroundRoot`: ladang 4.200 × 3.600 m (3 nada rumput stepped, `#3c7a38` pertama), lajur verge ±80 m yang mengikuti elevasi jalan, apron kerikil `ParkPathways` (`#8c7e63`), lantai luar sampai cincin vista, `MuraDelParco` (bata `#a3483b`, topi kapur, 3,2 m). `ground_y_at(pos)` = lantai padat di bawah titik mana pun. |
| 2 Sopraelevata | Busur dek 480 m, R 320 m, banking 28°, lebar 14 m, tebal 1,8 m; sisi dalam bawah 13,5 m di atas jalan; 4 portal 2 pilar yang berpijak di tanah; pagar karat `#733d26` di bibir atas. |
| 3 Tribun & landmark | `RettifiloGrandstand` (120 m, kanopi merah, 3 tingkat) dan `AscariGrandstand` (160 m, 4 tingkat, kanopi putih, Jumbotron); penonton `MultiMesh`; `VillaRealeGatehouse` (neoklasik, pedimen) dan `TorreAscari` (4 lantai, spanduk Agip) sebagai node terpisah. Jumbotron utama dan Ascari kini menampilkan klasemen live (`BrianzaEnvironment.update`). |
| 4 Vegetasi | Pinus payung (kanopi 3 nada `#2d5432/#3f7345/#528c5a`, batang miring), cemara (`#1c3822`), semak; `MultiMeshInstance3D`, `cast_shadow = OFF`; berpijak di tanah; tidak masuk tapak tribun, menara, atau bawah viaduk; kanopi pinus tidak menjorok ke jalan (kedalaman min 18,5 m). |
| 5 Keselamatan | `CatchFence` (tiang 45°, panel kawat alpha 0,35, 2,8 m) di atas armco sepanjang tribun dan 220 m pengereman 3 tikungan; 12 papan rem 200/150/100/50 m di gantri overhead (Rettifilo, Roggia, Ascari); papan sponsor Pirelli/Brembo/Agip/Magneti Marelli (4 `MultiMesh` + 4 label nama); 8 pos marshal. |
| 6 Vista & cahaya | `BrianzaVistaRing`: hutan 4.300 m, perbukitan 4.420 m, Alpen 4.550 m (puncak bersalju); shader `shaders/brianza_vista_haze.gdshader`. `bind_world()` penuh: matahari `#fff3db` pitch 42°/yaw 215°, bayangan lembut, ambient `#a3c2f0`, kabut `#dce8f5`, tonemap ACES, glow; `apply_time_of_day()` untuk DAY/SUNSET/NIGHT (matahari rendah oranye, bulan, lampu sorot menyala). |

## 2. Verifikasi

| Gate | Hasil |
| :--- | :--- |
| `tests/test_brianza_circuit.gd` | **91/91 PASS** (dari 23). Asersi Layer 1–6 plus anggaran render. |
| Seluruh suite headless | **52/52 PASS, 0 FAIL.** 50 suite exit 0 pada putaran penuh. `test_race_world` butuh `--fixed-fps 60` (seperti pembungkus legacy proyek): ALL PASS. `test_audio_and_race_weekend`: 36/36 PASS. Setelah perubahan terakhir, 6 suite terkait Brianza/Wangan dijalankan ulang: 0 FAIL. |
| Anggaran statis lingkungan | **70 draw call (≤ 160), 317.745 segitiga (≤ 320.000)**, terkunci di test `#P1`. Armco (99 ribu) dan menara lampu (27 ribu) adalah kit Tier A bersama. |
| Native smoke (RTX 3050 Laptop, 1080p, High) | 3 lap, **20/20 mobil finis**, podium terbuka, **0 orphan node** setelah dunia dibebaskan (`scratch/smoke_brianza_race.gd`). |
| Frame time | rata-rata 16,64 ms, **p95 21,27 ms**, terburuk 35,67 ms. **60 FPS locked belum PASS** (gate terbuka, sama seperti Fase 12.1). Lingkungan disembunyikan: p95 22,43 ms, jadi lingkungan bukan penyebab. Hitungan frame mentah (termasuk kaskade bayangan) 137–182 draw call. |
| Visual native 1920×1080 | 8 PNG `phase-13-1-*.png` (6 kamera + sunset + night) dan 5 PNG `phase-13-1-extra-*.png` di `executor-report/screenshots/phases/`; seluruhnya diinspeksi. |

## 3. Keputusan (Ruling) dan penyimpangan

1. **Posisi `s` tribun.** Spesifikasi/rencana menyebut Rettifilo di s=1120–1240 dan Ascari 3960–4120. Spline sebenarnya: Turn 1 di s≈718, kompleks Ascari s 4087–4340. Tribun diikatkan ke `builder.turns`; test `#L3.2` memeriksa rentang tikungan sebenarnya. Kamera cam2/cam5 pada `capture_phase13_1_views.gd` (bukan buatan saya, dijalankan apa adanya) memakai angka spesifikasi, sehingga tidak membingkai tikungan sebenarnya; `scratch/capture_phase13_1_extra.gd` membingkai Turn 1 (gantri 200 m), tribun Ascari, dan viaduk.
2. **Shader vista sendiri.** `mountain_haze.gdshader` memutihkan cincin 4,5 km (haze + kabut ganda). `brianza_vista_haze.gdshader`: `fog_disabled`, haze dasar lebih tipis, puncak bersalju. Lereng cincin diperlonggar (`VISTA_FLANK_RUN = 0.12`) agar lapisan tidak saling menutup (versi pertama menyembunyikan hutan dan perbukitan di balik Alpen).
3. **Far plane.** `bind_world()` menaikkan `camera.far` ke 6.500 m; dunia balapan memakai 3.500 m dan akan memotong cincin.
4. **Jumbotron** diumpan dari `BrianzaEnvironment.update` (seperti NeoWangan), bukan `brianza_pit_complex.gd`: kompleks pit tidak memegang referensi balapan. `brianza_pit_complex.gd` tidak diubah.
5. **Sponsor.** Satu `Label3D` per papan menghabiskan anggaran draw call; 4 `MultiMesh` berblok warna + 4 papan unggulan berhuruf nyata.
6. **Dek Sopraelevata:** sisi bawah dalam = 13,5 m (pusat dek ≈ 17,6 m), mengikuti spesifikasi "clearance bersih 13,5 m".
7. **Headless:** `MultiMesh` tidak menyimpan transform di renderer dummy, jadi `foliage_poses` dan `catch_fence_poses` disimpan agar bisa diuji.

## 4. Belum dilakukan / risiko

- **Gate 60 FPS locked terbuka** (p95 21,3 ms; sumbernya bukan lingkungan).
- Penonton statis (tidak ada animasi bersorak). Tribun hanya sisi luar.
- `VillaRealeGatehouse` tidak terlihat jelas pada PNG yang dirender (tertutup pinus di `phase-13-1-extra-villa-gatehouse.png`); geometri diuji, bukan dinilai visual penuh.
- Anggaran segitiga 317.745 dari 320.000 (margin 0,7 %). Tambahan aset berikutnya harus mengurangi tempat lain.
- Review akhir adalah **self-review** (tidak ada subagen karena tidak diminta).

## 5. File

`scripts/world/brianza_environment.gd` · `shaders/brianza_vista_haze.gdshader` · `tests/test_brianza_circuit.gd` · `scratch/capture_phase13_1_extra.gd` · `scratch/smoke_brianza_race.gd` · `scratch/measure_brianza_budget.gd`
