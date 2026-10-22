# LAPORAN EKSEKUTIF FASE 7: REFINING & ASSEMBLY 8 MOBIL GT3

**Status:** SELESAI dan TERVERIFIKASI (8 bodi + 8 aset utuh + 8 sasis + 8 tes; seluruh suite **0 FAIL**).
**Task Spec:** `prompt/TASK-MULTI-CAR-REFINING-AND-ASSEMBLY.md`
**Metode:** Blender 5.2 headless (`scratch/refine_car.py`, `scratch/build_full_car.py`), Godot 4.7.2 (import, tes, capture). Pipeline sama dengan prototipe Audi R8 FASE 7; penyimpangan dicatat di bagian 4.

---

## 0. Ringkasan

| # | Mobil | Tim (`GtData.TEAM_NAMES`) | `team_id` | Wheelbase | Socket X | Socket Z | Tris bodi | Dimensi W x L x T (m) | Body GLB | Full GLB |
| :-: | :--- | :--- | :-: | :-: | :-: | :-: | :-: | :--- | :-: | :-: |
| 1 | Nissan GT-R Nismo GT3 | Kurogane GT | 2 | 2,598 m | 0,807 | ±1,299 | 94.990 | 1,906 x 4,533 x 1,295 | 5,9 MB | 7,3 MB |
| 2 | Aston Martin Vantage AMR GT3 | Vanta Motors | 3 | 2,626 m | 0,818 | ±1,313 | 107.947 | 2,059 x 4,534 x 1,230 | 7,8 MB | 9,2 MB |
| 3 | BMW M4 GT3 | Zero Hour | 5 | 2,598 m | 0,847 | ±1,299 | 99.095 | 2,085 x 4,538 x 1,310 | 5,0 MB | 6,7 MB |
| 4 | Lamborghini Huracan GT3 EVO2 | Oni Works | 6 | 2,578 m | 0,872 | ±1,289 | 94.812 | 2,192 x 4,540 x 1,241 | 5,3 MB | 7,6 MB |
| 5 | Honda NSX GT3 EVO22 | Chrome Syndicate | 8 | 2,622 m | 0,860 | ±1,311 | 106.134 | 2,075 x 4,544 x 1,469 | 6,4 MB | 8,9 MB |
| 6 | Chevrolet Corvette Z06 GT3.R | Razorline | 4 | 2,644 m | 0,850 | ±1,322 | 94.926 | 2,082 x 4,541 x 1,267 | 5,1 MB | 6,9 MB |
| 7 | Lexus RC F GT3 | Static Speed | 7 | 2,578 m | 0,818 | ±1,289 | 103.419 | 1,982 x 4,535 x 1,287 | 5,3 MB | 6,7 MB |
| 8 | McLaren 720S GT3 EVO | Night Shift | 9 | 2,640 m | 0,878 | ±1,320 | 106.650 | 2,110 x 4,542 x 1,225 | 7,1 MB | 8,8 MB |

Semua bodi: panjang 4,53-4,54 m (target 4,55 ± 0,02), 94.812-107.947 tris (target 80.000-120.000), 2 surface (`Paint` + `FenderLinerMat`), 0 vertex geometri roda di keempat lengkung, 4 ban flush dan menyentuh tanah, tekstur asli dipertahankan (`keeps_original_paint = true`).

Tim 0 (Apex Racing) tetap memakai Porsche 911 GT3 R; tim 1 (Neon Drift) Audi R8; 8 tim lain memakai mobil baru. Grid 10 tim x 2 mobil konsisten.

---

## 1. Input dan Perintah

Input `assets/cars/<slug>/raw/<slug>_raw.glb` + 4 peta PBR mentah tidak diubah. Folder `raw/` diberi `.gdignore` agar editor Godot tidak mengimpor GLB mentah 39-132 MB (tidak dipakai game).

```powershell
# 1. Deteksi sumbu roda (front axis + axle height + wheelbase)
blender --background --python scratch/refine_car.py -- scratch/car_configs/<slug>.json --detect-only

# 2. Retopo + bake 4K (3-4 menit per mobil)
blender --background --python scratch/refine_car.py -- scratch/car_configs/<slug>.json

# 3. Aset utuh (bodi + 4 roda master di socket sasis)
blender --background --python scratch/build_full_car.py -- scenes/car/<slug>_chassis.tscn assets/cars/<slug>/<slug>_full.glb
```

Log per mobil: `scratch/multicar/logs/detect_*.log`, `refine_*.log`, `full_*.log`.

### 1.1 Hasil deteksi (dipakai untuk socket)

| Mobil | Front y | Rear y | Axle height | Tread r | Wheelbase |
| :--- | :-: | :-: | :-: | :-: | :-: |
| Nissan GT-R | -1,317 | 1,280 | 0,410 | 0,425 | 2,597 |
| Aston Vantage | -1,346 | 1,280 | 0,420 | 0,400 | 2,626 |
| BMW M4 | -1,362 | 1,234 | 0,351 | 0,338 | 2,597 |
| Lambo Huracan | -1,224 | 1,353 | 0,399 | 0,382 | 2,577 |
| Honda NSX | -1,264 | 1,357 | 0,364 | 0,351 | 2,622 |
| Corvette Z06 | -1,341 | 1,302 | 0,408 | 0,386 | 2,643 |
| Lexus RC F | -1,342 | 1,235 | 0,380 | 0,366 | 2,577 |
| McLaren 720S | -1,227 | 1,413 | 0,414 | 0,399 | 2,640 |

`Socket Z = wheelbase / 2`; `axle_z` bodi tetap 0,33 m (roda master r = 0,33 m). Tidak ada kasus deteksi gagal.

---

## 2. Deliverable per Mobil

| Deliverable | Path |
| :--- | :--- |
| Config | `scratch/car_configs/<slug>.json` (8 file) |
| Clean body | `assets/cars/<slug>/<slug>_body.glb` (2 surface, tekstur JPEG tertanam) |
| Tekstur bake | `assets/cars/<slug>/textures/{base_color,normal,orm}.png` (semua 4096 x 4096) |
| Full car | `assets/cars/<slug>/<slug>_full.glb` (bodi + 4 roda master, 37 objek) |
| Material toon | `materials/<slug>_toon_body.tres` (shine + emboss + AO, outline 0,02 m) |
| Chassis scene | `scenes/car/<slug>_chassis.tscn` (`ModularCarAssembler`, 4 socket roda + cockpit, `keeps_original_paint = true`) |
| Tes | `tests/test_<slug>_chassis.gd` (16 assertion per mobil) |
| Screenshot | `executor-report/phase-7-<slug>-showroom.png`, `...-left_side.png` |

Integrasi tim: `scripts/car/gt_car_actor.gd` -> `CHASSIS_BY_TEAM` sekarang berisi 9 entri (team 1 Audi + team 2-9 mobil baru). Tim 0 jatuh ke `BASE_CHASSIS` (Porsche).

Impor Godot: `*_body.glb` disetel `gltf/embedded_image_handling=0` (tekstur tertanam dibuang; material toon memakai `textures/`), tekstur disetel VRAM-compressed (`compress/mode=2`), normal map ditandai (`compress/normal_map=1`), mipmap aktif, `detect_3d/compress_to=0`.

---

## 3. Pengujian (semua dijalankan headless)

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_<slug>_chassis.gd   # x8
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_audi_r8_chassis.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_modular_car.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_audio_and_race_weekend.gd
```

| Suite | Hasil |
| :--- | :--- |
| `test_nissan_gtr_chassis` | 16 PASS, 0 FAIL |
| `test_aston_vantage_chassis` | 16 PASS, 0 FAIL |
| `test_bmw_m4_chassis` | 16 PASS, 0 FAIL |
| `test_lambo_huracan_chassis` | 16 PASS, 0 FAIL |
| `test_honda_nsx_chassis` | 16 PASS, 0 FAIL |
| `test_chevy_corvette_chassis` | 16 PASS, 0 FAIL |
| `test_lexus_rcf_chassis` | 16 PASS, 0 FAIL |
| `test_mclaren_720s_chassis` | 16 PASS, 0 FAIL |
| `test_audi_r8_chassis` (diperbarui ke grid 10 tim) | 17 PASS, 0 FAIL |
| `test_modular_car` | 18 PASS, 0 FAIL |
| `test_audio_and_race_weekend` | 35 assertion, 0 FAIL (9 suite lama tanpa regresi) |

Assertion per mobil: posisi 4 socket (`x = X`, `y = 0,33`, `z = ±Z`), socket cockpit, material toon, `keeps_original_paint`, panjang 4,55 ± 0,02, lebar 1,85-2,25, tinggi 1,0-1,55, tidak ada bodi tenggelam > 10 cm, origin dekat tengah wheelbase, tris 80k-120k, surface liner, 0 vertex geometri roda di lengkung (R 0,362), ban flush < 2 cm ke flare fender, 4 ban menyentuh tanah, radius ban < bukaan 0,372.

---

## 4. Keputusan & Penyimpangan (disengaja)

1. **`texture_clean` dimatikan untuk 8 mobil ini.** Langkah itu disetel untuk cat netral Audi (satu puncak luminansi); livery 8 mobil ini multi-warna (hijau/putih/merah/cyan). Sampling tekstur mentah menunjukkan pembersihan akan menaikkan abu-abu gelap milik livery ke warna cat dominan. Warna asli lebih penting; `base_color` di-bake apa adanya.
2. **Socket X tidak dipaku 0,88 m.** Lebar bodi hasil bake 1,91-2,19 m; `X = rata-rata lebar fender (di sekitar kedua sumbu) - 0,141` (offset sisi luar ban master). Hasil: ban flush di semua mobil (Nissan 0,807 m, Lambo 0,872 m, dst.). Socket Z tetap dari deteksi sumbu roda.
3. **Nama tim memakai `GtData.TEAM_NAMES`**, bukan nama di tabel task (mis. `bmw_m4` -> Zero Hour, bukan "Nordic Phantom"; `aston_vantage` -> Vanta Motors). `team_id` sesuai task (2,3,5,6,8,4,7,9); `team_name` scene harus sama dengan sim/HUD.
4. **Tes Audi diperbarui:** assertion "semua tim selain Neon Drift memakai Porsche" tidak berlaku lagi; sekarang memetakan 10 tim ke 9 sasis + base Porsche dan tetap memeriksa warna asli serta tint opt-out.
5. **McLaren 720S: booleans sempat menghapus bodi** (sisa 530 face) pada dua run pertama. Perbaikan: `"recalc_normals": true` + `"debug_precut": true` di config (ekspor diagnostik `temp/mclaren_720s_precut.glb` sebelum boolean). Dengan keduanya, potongan roda normal (96.692 face, final 106.650 tris). Flag dipertahankan agar build ulang reproducible.
6. **Batas tes dibuat generik**, bukan angka Audi: tinggi bodi sampai 1,55 m (Honda NSX 1,469 m karena wing), lebar 1,85-2,25 m (Lambo 2,192 m), ground clearance memakai jumlah vertex tengah yang tenggelam (bukan AABB minimum, karena bibir lengkung bawah memang di bawah bidang tanah dan tertutup trek).
7. **`.gdignore` di `assets/cars/<slug>/raw/`** agar editor tidak mengimpor 681 MB GLB mentah dan tekstur 4K mentah. File mentah tidak diubah/dihapus.
8. **Tidak ada file pengguna yang dihapus.** Semua output baru dapat dibangun ulang dari config + skrip; `raw/` utuh.
9. **Tes baru tidak dimasukkan** ke daftar `LEGACY_SUITES` di `test_audio_and_race_weekend.gd` (sesuai pola Audi); dijalankan terpisah seperti perintah di task.

---

## 5. Verifikasi Visual

Screenshot showroom (3/4 depan) dan tampak samping kiri (flush stance) untuk 8 mobil:

`executor-report/phase-7-{nissan_gtr,aston_vantage,bmw_m4,lambo_huracan,honda_nsx,chevy_corvette,lexus_rcf,mclaren_720s}-{showroom,left_side}.png`

Aset utuh diperiksa terpisah lewat `scratch/view_glb.gd` (tanpa impor): `scratch/multicar/full_nissan_{3q,side,rear}.png` -- bodi + 4 roda master terpasang di socket, warna asli.

Dari pemeriksaan gambar: orientasi depan semua mobil benar (grille/headlight menghadap kamera), livery terbaca (HONDA/HRC, M4, Huracan #63, GT-R, Corvette, McLaren), ban menyentuh tanah dan flush dengan fender, tidak ada roda baked tersisa. Cacat tekstur halus (smudge/UV seam) berasal dari mesh AI mentah, sama seperti batasan Audi di FASE 7.

---

## 6. Catatan & Risiko

- **Bobot grid:** 9 bodi x ~100k tris + Porsche ~115k = ~1 juta tris bodi, ditambah 80 roda. `test_race_world` tetap lulus (63 detik) dan tidak ada regresi; FPS 20 mobil di trek belum diukur ulang.
- **Variasi lebar bodi:** hasil uniform scale dari panjang 4,55 m; Nissan 1,906 m dan Lambo 2,192 m (spec FIA ~2,04 m). Tidak ada penskalaan sumbu X agar proporsi asli tidak distorsi.
- **Open edges 770-996** pada hasil akhir berasal dari tub/lip (sama seperti pipeline Audi); tidak terlihat sebagai lubang pada render.
- **Godot impor:** body GLB memakai tekstur eksternal (hemat VRAM); extracted JPEG dari impor pertama masih ada di `assets/cars/<slug>/` dan tidak dipakai game.
- **McLaren:** bila pipeline dijalankan ulang tanpa `debug_precut`, boolean EXACT berisiko menghapus bodi; flag sudah disetel di config.
