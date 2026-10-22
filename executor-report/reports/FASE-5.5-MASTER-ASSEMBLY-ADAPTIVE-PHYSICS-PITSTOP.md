# LAPORAN EKSEKUTIF FASE 5.5: 3D MASTER ASSEMBLY, ADAPTIVE TRACK PHYSICS & REALISTIC RACE WEEKEND

**Status:** SELESAI & TERVERIFIKASI (31 assertion `test_race_weekend_and_physics.gd` PASS, 0 failure; 25 butir akseptansi + 1 grup tambahan; seluruh suite lama PASS tanpa regresi; tangkap layar dari GPU nyata, Godot 4.7.2 Forward+)  
**Task:** `prompt/TASK-FASE-5.5-MASTER-ASSEMBLY-ADAPTIVE-PHYSICS-PITSTOP.md`

> **Diperbarui oleh Fase 5.6 - 5.8** (`FASE-5.6-5.8-GT-SIM-PORT-DYNAMICS-VFX-FUSED-HUD.md`): dunia akhir pekan kini berjalan di atas sim GT (`scripts/gt/`). `MatchColliderSystem`, `WorldPitDirector` dan hook `TrafficRaceSim` di bawah ini sudah dihapus / dikembalikan; `test_race_weekend_and_physics.gd` berisi 30 assertion di sim baru. Bagian ini tetap berlaku sebagai catatan sejarah Fase 5.5.


## 0. Ringkasan

Fase 5.5 menyatukan mobil Porsche 911 GT3 modular, fisika lintasan adaptif, match collider 190 pasang, alur start 5 lampu merah, pit lane fisik dengan koreografi pitstop kru 3D, set trackside low-poly, dan lima kamera siaran ke satu dunia: `scenes/race_weekend_world.tscn`.

| Area | Hasil |
|---|---|
| Master car assembly | `car_actor.tscn` kini memasang `base_chassis.tscn` (bodi Porsche + 4 roda BBS FI-R modular); `BoxMesh` dihapus. Roda berputar sesuai kecepatan, kaliper statis, cakram rem berpijar jernih saat deselerasi > 1.5 G |
| Racing line adaptif | Kelengkungan bertanda κ(s) dari spline, `d_target` ±3.2 m (apex clipping, melihat 25 m ke depan), batas kecepatan tikungan sqrt(μg/\|κ\|), kurva pengereman yang mulai lebih awal saat grip rendah |
| Match collider | 190 pasang per tick, jarak siklis modulo keliling, kontak 4.6 × 1.9 m, repulsi 12 m/s² elastis + pass posisi yang menjamin 0 tumpang tindih; one-move defending, ruang balap 1.8 m, bendera biru |
| Race weekend | `GRID_LINEUP → LIGHTS_COUNTDOWN → LIGHTS_HOLD (0.5-2.0 s acak) → GREEN_RACING → SAFETY_CAR → CHEQUERED_FLAG → PODIUM`; gantry baja dengan 5 pasang lampu merah |
| Pit lane | 408.8 m (masuk s = 3900, keluar s = 150), batas 80 km/jam, 10 garasi tim; koreografi: berhenti di stall, jack +15 cm dalam 0.3 s, 4 mekanik ganti 4 roda modular, turun 0.2 s, lollipop, keluar; mobil satu tim antre 8 m di belakang |
| Trackside | 9 kerb merah-putih bergerigi di sisi dalam tikungan tajam, guardrail Armco (tiang tiap 6 m), catch fence di sisi luar tikungan, 900 pohon low-poly (`MultiMesh`) |
| Kamera | Chase, Cockpit, Heli, Trackside TV, Close-Up Pitstop (otomatis saat ada pitstop); tombol `C` mengganti |
| Dunia terpadu | 20 mobil, RaceControl, AI rival yang pit lewat pit lane 3D, HUD Pit Wall (Live Timing, radar, status mobil yang diikuti) |

Cara menjalankan: tes `Godot --headless --path . -s tests/test_race_weekend_and_physics.gd` (±2 menit; `-- --skip-legacy` ±25 s tanpa suite lama); dunia: buka `scenes/race_weekend_world.tscn` (F6). Tombol: `1-5` skala waktu, `←/→` ganti mobil, `C` kamera, `P` mobil yang diikuti masuk pit.

---

## 1. Rangkuman Implementasi

### File baru

| File | Peran |
|---|---|
| `scripts/car/adaptive_racing_line.gd` | κ bertanda `(t1 × t0)·ŷ / Δs`, `d_target`, batas kecepatan tikungan per grip μ, kurva pengereman (sapuan mundur 2 lintasan, di-cache per bucket μ), titik pengereman |
| `scripts/car/match_collider_system.gd` | Collider 190 pasang + aturan FIA GT (one-move defending, racing room, blue flag) |
| `scripts/car/pitstop_choreographer.gd` | Mesin keadaan pitstop `ENTRY → SETTLE → LIFTING → SERVICING → LOWERING → RELEASE → EXIT → DONE`, antrean teammate, kru 3D (4 mekanik, 2 jack, lollipop) |
| `scripts/world/race_weekend_director.gd` | State machine akhir pekan balap + hitung mundur 5 lampu |
| `scripts/world/start_gantry.gd` + `scenes/race_world/start_gantry.tscn` | Jembatan rangka baja, panel 5 pasang lampu, cahaya merah |
| `scripts/world/pit_lane_complex.gd` + `scenes/race_world/pit_lane_complex.tscn` | Aspal pit, garis limiter kuning, 10 garasi tim + plang nama + kotak servis, dinding pit, rambu 80 |
| `scripts/world/track_environment_builder.gd` | Kerb, Armco, catch fence, pohon, rumput |
| `scripts/world/broadcast_camera_director.gd` | 5 kamera + tombol `C` + pitstop otomatis |
| `scripts/world/world_pit_director.gd` | Subclass `AIRaceDirector`: strategi sama, pit lane abstrak diganti pit lane 3D |
| `scripts/world/race_weekend_world.gd` + `scenes/race_weekend_world.tscn` | Dunia terpadu + HUD |
| `scripts/world/toon_materials.gd`, `scripts/world/ribbon_geometry.gd` | Material cel-shaded bersama, helper mesh mengikuti ribbon |
| `tests/test_race_weekend_and_physics.gd` | Suite akseptansi (31 assertion) |
| `scratch/capture_phase55.gd` | Skrip tangkap layar (butuh GPU) |

### File lama yang diubah (semuanya disebut task/spec/plan)

| File | Perubahan |
|---|---|
| `scenes/race_world/car_actor.tscn` | `Mesh` dan `Cabin` (BoxMesh) diganti instance `base_chassis.tscn` (diputar π karena model Porsche menghadap +Z); `Body` + 3 sensor tidak berubah |
| `scripts/car/kinematic_car_actor.gd` | Memasang roda per kompon, memutar roda, cakram rem berpijar, livery tim di material bodi, `extra_lateral_m`, `external_pose`, `place()` |
| `scripts/car/wheel_controller.gd` | Arah putar roda kiri dikoreksi, `set_brake_glow()` (overlay emisif pada `GT3_BrakeDisc`) |
| `scripts/car/traffic_race_sim.gd` | Dua hook opsional: `speed_caps` (batas kecepatan per mobil) dan `pit_lane_ids` (mobil di pit lane tidak memblokir dan tidak diblokir). Tanpa isi, perilaku identik dengan sebelumnya |

Core sim (`scripts/core/*`), `modular_car_assembler.gd`, `track_circuit.tscn`, dan semua file UI tidak diubah.

### Keputusan arsitektur

- **Collider hidup di atas lajur sim.** Sim tetap memilih lajur 0/1/2; collider memegang `offset` lateral per mobil (racing line + repulsi + aturan) yang ditambahkan ke lajur. Dengan begitu rencana lajur dan aturan longitudinal `TrafficRaceSim` tidak berubah, dan rate 1.8 m/s berlaku pada pergeseran racing line, bukan pada pergantian lajur sim (3.5 m/s) yang akan membuat sim dan 3D tidak sepakat.
- **Jaminan 0 tumpang tindih** punya tiga lapis: aturan sim (jarak aman per lajur), repulsi elastis `a = sign(Δd)(1.9 − |Δd|)·12`, lalu pass posisi yang mendorong setiap pasangan di dalam envelope ke tepat 1.9 m (seluruh dorongan ke satu mobil bila yang lain menempel batas lintasan).
- **Di tikungan, kotak mobil berputar.** Selisih arah 0.05 rad membuat kotak 4.6 × 1.9 m yang berjarak 1.9 m tetap tumpang tindih ±6 cm. Maka jarak lateral kontak dilebarkan menjadi `1.9 + 2.3·sin(κ·Δs)` (di jalan lurus tepat 1.9 m seperti spec), dan Δs dikalikan skala panjang lintasan `1 − κ·d`.
- **Dunia memegang loop tick sendiri** (akumulator fixed-point sama dengan `RaceControl`), supaya batas kecepatan dan pit job diperbarui sebelum setiap tick dan 1x/16x menjalankan urutan tick yang sama.
- **Pitstop tersambung ke sim lewat batas kecepatan.** `drive(car_id, dt, u, v)` mengembalikan speed cap; sim menggerakkan mobil, 3D hanya menempatkannya. Satu hukum kontrol dipakai oleh `advance(dt)` (tes, mobil virtual) dan `drive()` (dunia).
- **`WorldPitDirector` menggantikan `control.ai`**: keputusan pit rival (ban habis, cuaca, undercut, SC) tetap dari `AIRaceDirector`; yang diganti hanya pit lane abstrak 500 m. Servis sim (ban baru, tangki penuh) dijalankan saat mobil selesai di pit lane.

### Interpretasi spesifikasi yang perlu diketahui (rulings)

1. **Tanda κ.** Rumus spec `(t1 × t0)·ŷ / Δs` bernilai positif untuk belokan **kanan**, sama dengan arah +X (kanan) pada ribbon, sehingga `d_target` > 0 selalu ke sisi dalam. Dipakai persis; `TrackRibbon.get_curvature_at` memakai konvensi sebaliknya (kiri positif) dan tidak diubah.
2. **`d_target` ±3.2 m vs lebar jalan.** Fungsi `d_target(s)` persis spec dan diuji (clamp 3.2). Saat diterapkan ke seluruh barisan, pergeseran dibatasi ±2.25 m (4.75 m batas tengah mobil − lajur 2.5 m) agar tiga lajur tetap muat tanpa menumpuk di sisi dalam.
3. **Ruang balap 1.8 m** = jarak antara sisi bodi bertahan dan tepi lintasan di sisi penyerang (jalan 6.0 m, setengah lebar mobil 0.95 m, sehingga pusat bertahan paling jauh 3.25 m). Diuji pada skenario menekan ke tepi (2.20 m tersisa) dan pada kasus batas (clamp aktif).
4. **One-move defending** = satu gerakan menuju sisi penyerang per penyerang (penyerang = mobil terdekat di belakang dalam 25 m). Gerakan kedua menuju penyerang dibekukan; gerakan menjauh tidak pernah dibatasi.
5. **Bendera biru**: mobil tertinggal 1 lap dengan pemimpin < 15 m di belakangnya melambat ke 90 % (rate 0.2/s) dan bergeser 2.0 m ke luar garis, menjauh dari pemimpin; kembali normal setelah pemimpin lewat.
6. **Pit lane** mengikuti ribbon. `ENTRY_S = 3900`, `EXIT_S = 150` setelah garis start, panjang lengkung 408.8 m (spec: 410 m, toleransi ±5 m). Stall ada di lurusan sebelum tikungan terakhir (`s = 3925 + 14·tim`), garasi 19.2 m di kanan racing line (sisi luar tikungan terakhir). Jalur cepat 12.5 m, jalur kerja (stall) 15.6 m.
7. **Margin kontak sim di dunia ini 0.8 m** (bukan 0.1 m seperti `test_race_world`): di sisi dalam tikungan 35 m, satu meter ribbon hanya 0.86 m lintasan nyata.
8. **Cuaca**: dunia akhir pekan berjalan kering (jadwal cuaca kosong). Grip ban (aus, suhu, basah) tetap masuk ke batas kecepatan tikungan lewat μ, jadi pengereman lebih awal saat ban aus tetap hidup.
9. **Pit mobil pemain**: AI hanya mengelola mobil rival (id ≥ 2, aturan Fase 5). Mobil 0 dan 1 masuk pit lewat tombol `P`.

### Di luar lingkup task (dicatat, tidak dikerjakan)

- `scripts/ui/tactical_deck_hud.gd` (5 level Pace, 3 Fuel Mix, tombol `M`) hanya muncul di diagram arsitektur spec; tidak ada di daftar deliverable maupun 25 assertion task.
- `track_circuit.tscn` tidak diubah; kerb, guardrail, pohon, gantry, dan pit lane dipasang oleh dunia akhir pekan sehingga `test_race_world` dan `test_weather_world` tidak terpengaruh.

---

## 2. Hasil Pengujian

Perintah: `Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_race_weekend_and_physics.gd` → exit code 0, 31 assertion, 0 failure, ±2 menit.

Pemetaan ke 25 butir akseptansi (nomor di awal setiap baris tes):

| # | Butir | Hasil terukur |
|---|---|---|
| 1 | κ nol di lurusan, tidak nol di tikungan | 0.00000 di s = 500; −0.0297 di tikungan tertajam; tanda + kanan, − kiri |
| 2 | `d_target` menempel apex dalam | −3.20 m di apex (sisi dalam kiri), mulai 25 m lebih awal, 0 di lurusan, laju lateral 1.8 m/s |
| 3 | Patuh v_limit grip-adaptif | Kurva pengereman tak pernah melebihi v_limit (selisih 0.0000); di balapan 3600 tick selisih terburuk +0.60 m/s (jeda satu tick) |
| 4 | Pengereman lebih awal saat μ rendah | Basah mulai di s = 877, kering di s = 1047; jarak pengereman 70 → 25 m/s lebih panjang |
| 5 | 190 pasang tiap tick | 190 per tick, 684 000 pengecekan dalam 3600 tick |
| 6 | Jarak siklis garis start | Mobil di L−1 dan 2: 3.0 m, bersentuhan; 10 vs L−10: −20 m |
| 7 | Repulsi dalam envelope 4.6 × 1.9 | Dorongan 0.253 m/s = rumus; tidak aktif di luar envelope |
| 8 | 0 tumpang tindih 3600 tick | 0 frame tumpang tindih (grid standar) dan 0 frame (pack padat 20 mobil dalam 140 m, lajur acak, 16 kontak diselesaikan) |
| 9 | One-move defending | 1 gerakan menuju penyerang, gerakan kedua diblokir 120 kali |
| 10 | Ruang balap ≥ 1.8 m | 4.42 m (menekan ke tepi), 2.20 m (sudah di luar) |
| 11 | Bendera biru | 90 %, bergeser 2.0 m, ≤ 1.80 m/s, kembali setelah pemimpin lewat |
| 12 | Grid 20 mobil | Kolom berselang-seling ±2.5 m, baris 10 m, tanpa tumpang tindih |
| 13 | Lampu satu per satu | 5 lampu tiap 1.0 s (4.02 … 8.02 s) |
| 14 | Lights out | Semua lampu padam serentak; hold 0.59 … 1.99 s di 25 seed; balapan mulai |
| 15 | Nol false start | 0 tick sim dan kecepatan 0 sebelum lampu padam |
| 16 | Limiter 80 km/jam | Mobil datang 60 m/s turun ke 22.22 m/s di garis, puncak 22.22 m/s di dalam pit lane |
| 17 | Berhenti di stall | Galat 0.000 m |
| 18 | Jack +15 cm | 15 cm dalam 0.30 s, turun 0.22 s |
| 19 | 4 roda baru kompon diminta | 4 penggantian WET; juga di dalam balapan: mobil 8 MEDIUM → HARD, ban sim dan roda 3D sama |
| 20 | Antrean double-stack | Mobil kedua antre 8.0 m di belakang stall, jarak terdekat 7.84 m, selesai berurutan |
| 21 | Roda berputar, kaliper statis | Keempat roda maju (130.2 rad/s di 43 m/s), transform kaliper tak berubah |
| 22 | Cakram berpijar > 1.5 G | Glow 1.00 di 3 G, 0 di 1.4 G, padam kembali |
| 23 | Kerb merah-putih sisi dalam | 9 kerb, 2 surface merah/putih, sisi sama dengan tanda kelengkungan; 1313 tiang guardrail, 900 pohon |
| 24 | Gantry dan 10 garasi | Gantry di garis start (5 pasang = 10 lampu), 10 garasi tepat di koordinat stall, pitch 14 m |
| 25 | Suite lama | `test_modular_car` 18, `test_simulation_verification` 43, `test_pit_wall` 26, `test_weather_and_ai` 43, `test_race_world` 65: semua PASS |
| 26 (tambahan) | 5 kamera | `C` memutar chase > cockpit > heli > trackside TV; kamera pit memotong sendiri dan mengembalikan |

Cuplikan terminal (lari penuh terakhir):

```
[PASS] #16 the pit lane limiter holds 80 km/h (22.22 m/s): a car arriving at 60 m/s is down to 22.22 m/s at the line, peak 22.22 m/s inside
[PASS] #17 the car stops on the stall of its team's garage (0.000 m along, 0.000 m from the box centre)
[PASS] #18 the hydraulic jacks lift the chassis 15 cm in 0.30 s and drop it in 0.22 s
[PASS] #19 the crew took the four old wheels off and fitted four WET wheels (4 swaps, wheels off during service: true)
[PASS] #20 the second teammate queued 8.0 m behind the stall until the first left (closest approach 7.84 m), then stopped at the stall
    test_modular_car OK (18 PASS, 0 FAIL, 0 s)
    test_simulation_verification OK (43 PASS, 0 FAIL, 3 s)
    test_pit_wall OK (26 PASS, 0 FAIL, 7 s)
    test_weather_and_ai OK (43 PASS, 0 FAIL, 18 s)
    test_race_world OK (65 PASS, 0 FAIL, 67 s)
[PASS] #25 the earlier suites still pass without regressions: ...
31 assertions, 0 failure(s)
FASE 5.5 ACCEPTANCE: PASS
```

Uji rendam di luar suite (`headless`, 16x, 252 000 tick = 70 menit waktu balap): berjalan tanpa error sampai lap 30, 18 pit stop rival lewat pit lane 3D, `unresolved` collider 0 sepanjang jalan. Mobil 0 (milik pemain, tanpa strategi AI) berhenti (kecepatan 0) di sekitar lap 30, kemungkinan kehabisan bensin (tangki standar untuk 30 lap); penyebab tidak diperiksa lebih jauh.

## 3. Tangkap Layar

Diambil dari `scenes/race_weekend_world.tscn` dengan `scratch/capture_phase55.gd` (GPU nyata, 1920 × 1080):

1. `scratch/phase-5.5-race-track.png`: Porsche modular melaju di tikungan dengan kerb merah-putih bergerigi, guardrail dengan tiang, catch fence, pohon low-poly.
2. `scratch/phase-5.5-start-lights.png`: grid di belakang gantry start dengan 5 pasang lampu merah menyala, HUD Pit Wall (Live Timing, radar, banner `LIGHTS ●●●●●`).
3. `scratch/phase-5.5-pitstop-action.png`: close-up kru 3D di stall tim; salah satu roda sudah dilepas (soket kosong), roda lama dibawa mekanik, jack kuning di bawah mobil, kotak servis berwarna tim.

## 4. Catatan untuk Pemilik Proyek

- **Tinjauan akhir:** dikerjakan inline; proyek bukan repo git sehingga tidak ada diff untuk dibandingkan, dan tidak ada reviewer segar. Yang diperiksa sendiri: seluruh suite lama (termasuk `test_race_world`, 65 assertion) dan rendam 70 menit.
- **Keputusan terbuka:** (1) kecepatan balap kini juga dibatasi kurva tikungan ribbon 3D di atas model segmen sim (hanya bisa menurunkan kecepatan, jadi waktu lap bisa lebih lambat dari sim murni; belum diukur terhadap baseline); (2) skala pit lane (jalur 408.8 m) berbeda dari pit lane abstrak 500 m di `AIRaceDirector`, yang tetap dipakai sesi Pit Wall; (3) tampilan kru (kapsul + helm) masih placeholder low-poly; (4) `tactical_deck_hud.gd` belum disentuh.
- Setelah menambah `class_name`, jalankan `godot --headless --path . --import` sekali.
