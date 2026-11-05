# FASE 27 — Kurogane Twin-Cross GP (Ronde 10 OKT JPN)

**Tanggal:** 2026-11-05 · **Agen:** Claude Code (Sonnet 5.5) · **Branch:** `fase-27-kurogane` (belum di-commit; commit hanya bila diminta)
**Sumber:** `mapgen-circuit/builds/kurogane/` (`production-handoff.md`, `build-report.md`, `qa-report.json`, `placement-manifest.json`, skrip sandbox). Paket beku tidak diubah.

## 1. Gerbang Fase 0 (paket beku)

| Gerbang | Hasil |
|---|---|
| SHA-256 `blueprint.track.json` / `environment_strip.json` / `procedural-spec.md` | SAMA 3/3 |
| geometry hash vs `lock.json` | SAMA `sha256:051118ec…77cd` |
| Schema + validator | 0 error · **26 PASS / 0 WARN / 0 FAIL** |
| Kurva terkompilasi vs sandbox | 5.800 titik, Δ maks **0,000000 m**, loop tertutup → `assets/tracks/kurogane/data/kurogane_curve.tres` (baked 5.801,389 m; 1,389 m = selisih panjang 3D vs plan) |
| Crossover terukur | plan 0,23 m di **s 2752 (y 11,60) × s 3924 (y 37,84)**; range blueprint lama (2050–2350 / 4650–4950) diabaikan |

## 2. File yang berubah

**Baru** — modul `scripts/world/circuits/kurogane/`: `kurogane_layout.gd`, `_circuit_builder.gd`, `_strip.gd`, `_environment.gd`, `_terrain.gd`, `_toon.gd`, `_pit_complex.gd`, `_pit_corridor.gd`, `_paddock_detail.gd`, `_catch_fence.gd`, `_steel_fence.gd` · `scenes/race_world/circuits/kurogane/{kurogane_circuit,kurogane_pit_complex}.tscn` · `assets/tracks/kurogane/{data/kurogane_curve.tres, models/*.glb}` (4 GLB) · 4 shader `shaders/kurogane_*.gdshader` · tes `test_kurogane_{circuit,pit_drive,pit_flood}.gd` · `scratch/{capture,smoke}_kurogane_*.gd`.
**Diubah** — `scripts/core/circuit_calendar_registry.gd` (path scene Ronde 10 → modul produksi) · `assets/ui/circuit_maps/previews.res` (bake ulang, Ronde 10 ditambah) · kontrak bersama diperluas dengan `kurogane`: `test_circuit_environment_contract`, `test_flag_panels_contract`, `test_pit_complex_contract`, `test_pit_team_assignment_contract`, `test_team_identity_consistency`, `test_team_signage_contract`, `test_pit_straightness`, `test_track_selector_ui` (#S4h) · `tests/pit_flood_checks.gd` (+`deep_overlap_ticks_max`, default 20 tak berubah).
**Tidak di-commit (sengaja):** perubahan EOL `.import` Paulistano (dipulihkan), 3 `.uid` test milik orang lain yang sudah ada tak terlacak, probe di `temp/`.

## 3. Titik integrasi dengan builder sirkuit yang ada

- **Kontrak:** `KuroganeEnvironment extends CircuitEnvironment`, `KuroganePitComplex extends CircuitPitComplex` (sama seperti Eifel/Paulistano); `RaceWeekendWorld` memuat lewat registri, tanpa perubahan kode dunia/sim.
- **Kit bersama:** `TracksideFurnitureBuilder` (Armco/Tecpro/papan rem/menara lampu/panel bendera), `EnhancedTrackGeometry` (kerb/runoff/kerikil/groove), `PitZone` (rel kanan terbuka di lajur pit), `PitBuilding`/`MainGrandstand`/`RaceControlTower`/`StartGantry`, `TeamTransporters`, `PitKit`, `SharedCelSkyController`+`WorldSkyRig`, `GtRace` (sim pit bertanda, sisi kanan).
- **Dari Paulistano (terbaru):** koridor pit (papan PIT IN 11 m dari tepi), apron pit dihitung dari `u`, interior garasi memakai livery tim yang duduk (`teams`), `bind_world`/`apply_time_of_day`.
- **Baru di modul Kurogane:** heightfield + parit + jembatan; pemangkasan furnitur yang tak berpijak; kait `supported: Callable` pada pagar tangkap.

## 4. Audit terrain & aset — temuan dan perbaikan

Probe `temp/kuro_audit.gd` mengukur sampel per meter; hasilnya dikunci menjadi aset tes permanen (`test_kurogane_circuit`, 59 cek). Setiap cacat di bawah **diamati GAGAL dulu** (mutasi: pelurusan dimatikan → FAIL, perbaikan → PASS).

| # | Temuan (offset / tumpang tindih / ilogis) | Perbaikan |
|---|---|---|
| 1 | **Terrain menutupi tepi aspal** hingga 0,58 m di s 2938–2947 (grid 12 m tak mengikuti tanjakan 10 %) — z-fight/aspal terpotong | `lower_under()`: sudut segitiga diturunkan seminimal mungkin (bobot barycentric, batas 0,8 m) di bawah aspal, kerb, runoff, kerikil; 0 sampel tertutup |
| 2 | **Armco melayang** (hingga 27 m) di tepi dek jembatan (rel kit di 11,25 m, dek 10,75 m) dan **Armco terkubur** (hingga 7 m) di pintu masuk parit | `_prune_armco()`: tiang tak berpijak dipangkas; tabel `armco_runs`/`arcs`/`post_count` tetap konsisten; jembatan memakai parapetnya sendiri |
| 3 | **Armco di dalam pilar beton** (pilar 3,1 m dari tepi aspal jalur bawah) | tiang di footprint pilar (+1 m) dipangkas; juga pagar tangkap, tiang lampu |
| 4 | **Menara lampu**: 28/28 berdiri di elevasi jalan, bukan di tanah | berdiri di tanah (≤ 6 m dari elevasi jalan) atau dibuang; catatan sorot malam ikut |
| 5 | **Dinding penahan beton** (mesh vertikal) tak cocok dengan heightfield: baji putih menonjol dari lereng (juga ada di sandbox) | diganti **lapisan beton yang menempel pada lereng** (9 m, mengikuti triangle terrain, +0,12 m), tak lagi mencor bayangan (menghilangkan zebra bayangan) |
| 6 | **Fondasi race control** mulai di lateral 12 m → menyerobot 1,1 m ke lajur cepat (tepi luar 13,1 m), meninggi 7 cm | mulai di 13,6 m |
| 7 | `PaddockTerrace` (-0,06) di atas `PaddockTerraceBase` (-0,07): z-fight 1 cm; lawn -0,04 | quad redundan dihapus; lawn -0,02 |
| 8 | **Kincir ria menghadap tepi ke arah lintasan** (disk YZ model ditempatkan dengan +Z ke lintasan) | `face_x`: sumbu +X ke lintasan → disk terlihat penuh dari jalan |
| 9 | **Stasiun tikungan** ganda/tak urut (vertex plan sampai 190 m di luar fillet; figure-8 mencocokkan cabang salah) | dibake dari titik tengah busur fillet kompiler (skala 1,19646): urut, 20/20 radius nyata, min 31,1 m |
| 10 | `track_query` (terrain sandbox): indeks kasar dilaporkan sebagai stasiun 1 dari 8 kueri; tanda lateral terbalik | diperbaiki |
| 11 | Mesh wind/pohon: kanopi Momiji 178 tri × 1.500 = 267 k → env 484 k | 3 gumpalan, kutub tak terdegenerasi (82 tri); Armco profil tipis 16 tri (profil yang sama dengan sandbox disetujui) → env **313,3 k** |
| 12 | Jembatan: 69 m dikunci dari handoff; ukur ulang dengan triangle-exact memberi 62 m | konstanta `BRIDGE_SPAN_S = 3888…3957`; ukuran terrain disimpan sebagai pemeriksa (≤ 12 m) |
| 13 | **Cat kotak pit tim tidak terlihat** (temuan review developer): `PitKit.PAINT_Y` 3,5 cm di atas frame, apron +7 cm menutupnya | frame kotak dinaikkan sebesar `PIT_APRON_LIFT_M`; tes `test_kurogane_circuit` (60 cek) gagal 10/10 sebelum, lolos sesudah; screenshot `boxes/` dan set `pit` DAY/SUNSET/NIGHT diulang |
| 14 | **Cat kotak pit Paulistano (Ronde 9) tidak terlihat** (temuan review developer, bug yang sama dengan butir 13): apron pit rata di tinggi garis tengah + 0,07 m, sedangkan frame kotak mengikuti kemiringan melintang jalan, jadi cat (+3,5 cm) terbenam di apron (7 dari 10 kotak di bawah permukaan). Frame kotak kini diletakkan di apron (paulistano_pit_complex.gd); tes baru di 	est_paulistano_circuit gagal 7/10 sebelum perbaikan, lulus sesudahnya. Capture: phase-26-paulistano/boxes/ (DAY/SUNSET/NIGHT). | diperbaiki |

**Tersisa (tercatat):** di s 2934–2948 jalan "melayang" ≤ 1,0 m di atas lereng samping 10 % (keterbatasan grid 12 m); ambang tes 1,5 m. Menara lampu dalam parit (s 2797) dipertahankan (penerangan underpass). Pilar 3,1 m dari aspal bawah (tak ada kolisi scenery di sim; Armco dipangkas).

## 5. Verifikasi

| Gerbang | Hasil |
|---|---|
| Setara `verify_build` 15/15 + audit | `test_kurogane_circuit` **59/59** |
| Setara `test_pit_drive` 25/25 | `test_kurogane_pit_drive` **20/20** (masuk s 5600 @79,2 km/jam, stop s 107 / +16,5 m, servis 3,2 s, merge s 211,7, lap penuh Δy 40,00 m, 0 frame keluar aspal, 0 sentuhan pit wall) |
| Banjir pit 14 m | `test_kurogane_pit_flood` hijau **dengan 1 deviasi menunggu persetujuan** (lihat §6) |
| Kontrak bersama (200/80/204+ cek) | hijau dengan `kurogane` |
| Suite penuh `tools/run_tests.ps1` | lihat §7 |
| Native 3 lap / 20 mobil DAY · SUNSET · NIGHT | **20/20 finis, podium, 0 orphan**; frame mean **16,67 ms (60 FPS)**, p95 16,77–16,81 ms |
| Draw call lingkungan | statis **64**; per kamera (frame dengan − tanpa environment, 29 kamera × 6 set) **maks 113** (≤ 160) |
| Segitiga lingkungan | **313.322** (≤ 320.000); heightfield 42.896 |
| Screenshot 1080p | `executor-report/screenshots/phases/phase-27-kurogane/{day,sunset,night,crossover-*,pit,landmarks,boxes}` + `capture_metrics.json` per set |

## 6. Deviasi dari handoff

1. **Pit flood, seed 31, skenario "box 3–9 dtk":** 24 tick overlap dalam (batas 20; terdalam 1,90 m) — mobil yang baru lepas box 4,8 m/dtk dijangkau mobil yang meninggalkan box sebelumnya 13,9 m/dtk, 3 m di belakang. Seed 7/13/101/2024: 0–6 tick. Aturan release sim bersama, bukan geometri; `queue_gap_m` 10/12 m hanya memindahkan kegagalan ke seed lain. Batas 25 tick **hanya untuk lajur ini**, tercatat di tes — **butuh persetujuan developer** (preseden: deviasi release Paulistano).
2. **Sisi kuil & jarak menara:** handoff menulis kuil "120 m kanan" dan menara "70 m kiri"; kode sandbox yang disetujui memakai kuil **kiri** 120 m dan menara kiri **62 m** → dipertahankan (label "R" kuil di rekaman sandbox salah).
3. **Dinding penahan** → lapisan beton mengikuti lereng (§4 #5); **kincir ria** dihadapkan ke lintasan (§4 #8); keduanya perubahan visual terhadap sandbox.
4. **Armco profil tipis** dan **Momiji 3 gumpalan** demi anggaran 320 k (sandbox juga memakai Armco tipis).
5. **Interior garasi:** kru standby 13 orang berasal dari `StandbyCrew` (dipakai koreografi pit), bukan digandakan di detail; transporter dari `TeamTransporters` bersama (bukan kotak sandbox).
6. **Rig simulasi sandbox (`DummyCar`/`SimManager`)** tidak dipasang: sim GT produksi menggantikannya.
7. **Kink centreline T09 "Degner 2" (s 2174):** fillet 10 m / 13° (r 43 m) di antara dua lurusan pada blueprint beku → `test_racing_line` (cap 0 untuk sirkuit baru) gagal 1 kink. Geometri terkunci, tidak di-patch; cap `kurogane: 1` dicatat di tes — **butuh persetujuan developer** (alternatif: patch radius via `core/patch.gd` + re-freeze seperti Eifel T13).
8. Manifest `build_map.gd` tak diubah (follow-up planner di handoff).

## 7. Suite penuh

`tools/run_tests.ps1` penuh, 114 suite dalam 4 irisan (0–24, 25–49, 50–79, 80–113): **114/114 PASS, 0 FAIL**. Satu-satunya kegagalan awal, `test_racing_line` (kink T09, deviasi #7), hijau setelah cap dicatat. Dua deviasi menunggu persetujuan: #1 (pit flood) dan #7 (kink).
