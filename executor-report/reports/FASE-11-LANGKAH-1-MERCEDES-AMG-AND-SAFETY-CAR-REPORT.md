# LAPORAN EKSEKUTIF FASE 11 — LANGKAH 1: MERCEDES-AMG GT3 EVO & OFFICIAL FIA SAFETY CAR

**Status:** SELESAI dan TERVERIFIKASI, dengan batasan yang dicatat di bagian 9 (pengukuran FPS, dua peringatan saat keluar proses, dan butir visual yang belum dikerjakan).
**Task Spec:** `prompt/TASK-MERCEDES-AMG-GT3-AND-SAFETY-CAR.md`. **Design:** `docs/superpowers/specs/2026-10-23-langkah-1-mercedes-amg-gt3-and-safety-car-design.md`. **Plan:** `docs/superpowers/plans/2026-10-23-langkah-1-mercedes-amg-gt3-and-safety-car-plan.md`.
**Metode:** Meshy AI (MCP), Blender 5.2 headless (`scratch/make_car.ps1` → `refine_car.py`, `build_full_car.py`), Godot 4.7.2 stable (Forward+ / D3D12, RTX 3050 Laptop GPU). Tanggal: 2026-10-23.

---

## 0. Ringkasan

| Butir | Hasil |
| :--- | :--- |
| Tim 0 (Apex Racing: Kaze Ryu & Sora Ren) | Kini memakai sasis **Mercedes-AMG GT3 Evo** (`scenes/car/mercedes_amg_chassis.tscn`), bukan Porsche |
| Bodi Mercedes | 94.674 tris, 2 surface (`Paint` + `FenderLinerMat`), 2,138 x 1,258 x 4,542 m, lantai bodi y +0,050 |
| Gerbang fitment (`scratch/fit_cars.gd`) | **PASS**: gap radial 0,038 m di keempat roda, 0 vertex di dalam ban, flush maksimum 1,1 cm, skin fender 8,6 s.d. 11,7 cm |
| Safety Car | Sasis khusus `scenes/car/safety_car_chassis.tscn` (bodi Porsche 911, livery perak, pita chevron, lightbar atap amber 12 Hz / hijau solid) |
| Test | `test_mercedes_amg_chassis.gd` 18 asersi; `test_car_dynamics_vfx.gd` 29 asersi; **26 dari 26 suite headless exit 0, 0 `[FAIL]`** |
| Smoke native | Balapan 3 lap 20 mobil sampai podium, kembali ke `res://scenes/main.tscn`, **0 orphan node**; rata-rata 16,67 ms (60 FPS terkunci) pada pengukuran 1×; lihat bagian 6 untuk batasannya |

Git belum di-commit (tidak diminta). Berkas biner mentah `assets/cars/mercedes_amg/raw/mercedes_amg_raw.glb` (107,5 MB) tercakup pola LFS `assets/cars/*/raw/*.glb` di `.gitattributes`, jadi `git lfs track` tidak perlu dijalankan lagi.

---

## 1. Task 1.1: Rekonstruksi 3D via Meshy AI

Tool `meshy_multi_image_to_3d` tidak tersedia di awal sesi; server Meshy MCP dipasang ke konfigurasi lokal Claude Code (di luar repo) dan tool-nya termuat setelah reconnect.

| Parameter | Nilai |
| :--- | :--- |
| Input | `reference-assets/cars/mercedes-amg-gt3/front.png` + `back.png` |
| `ai_model` | `latest` (Meshy 7.1) |
| `enable_pbr` | `true` |
| `texture_resolution` | `4k` (geometri standar, tanpa Ultra) |
| `target_formats` | `glb` |
| Task ID | `01a16918-2533-7396-a6c0-61f95987713b` (selesai dalam kira-kira 2,5 menit) |
| Biaya | **30 credits**, dikonfirmasi pengguna sebelum dijalankan |
| Output | `assets/cars/mercedes_amg/raw/mercedes_amg_raw.glb`: 112.671.256 byte, header glTF sama dengan ukuran file |
| Tekstur PBR mentah | `raw/mercedes_amg_raw_textures/{base_color,metallic,roughness,normal}.png` |

`raw/.gdignore` ditambahkan supaya Godot tidak mengimpor GLB mentah.

---

## 2. Task 1.2: Konfigurasi dan refine Blender

Config: `scratch/car_configs/mercedes_amg.json` (panjang 4,55 m, `axle_z` 0,33, arch 0,372, tub 0,369, target 105.000 tris, `fender_lift: auto`, `ground_min: 0.05`). Perintah: `powershell -File scratch\make_car.ps1 -Car mercedes_amg`.

### 2.1 Log refine (dibaca sesuai `.claude/rules/car-asset-pipeline.md`)

| Butir | Nilai |
| :--- | :--- |
| Sumbu roda terdeteksi | front y −1,321, rear y 1,222, axle height 0,443, tread radius 0,434, **wheelbase 2,543 m** |
| Skala | 2,3931 (panjang menjadi 4,55 m) |
| `fender lift applied` | depan 0,064 m, belakang 0,0 |
| `wheel cut` | 90.010 faces (sehat); tubs dibangun, 98.606 tris |
| `ground clamp` | 2.728 face tapak ban di bawah roda dibuang, 11.634 vertex dinaikkan ke z 0,050 |
| `FINAL tris` | **94.674** (batas 80k s.d. 120k), open edges 1.163 |
| bbox | [−1,068 −2,228 0,05] .. [1,07 2,314 1,308] |
| Durasi refine | 160 detik |

### 2.2 Gerbang fitment: gagal sekali, lalu lulus

Run pertama: **4 FAILURES**, gap 0,012 m di keempat roda (batas 0,025 s.d. 0,050). Diagnosis dari angka, bukan dugaan: refine menaruh pusat lengkung roda di z = ±1,2715 (setengah wheelbase deteksi), sedangkan socket saya masih di ±1,299 sesuai spec. Selisih 2,8 cm ke depan dan belakang memotong gap konsentris 0,042 m menjadi sekitar 0,014 m. Semua mobil lain memakai setengah wheelbase deteksinya sendiri (Audi 1,338, Lexus 1,289, dan seterusnya).

Perbaikan: socket z menjadi ±1,272 dan `AXLE_Z` di test mengikuti; bodi tidak diubah (rule: jangan angkat atau turunkan bodi global). Jalankan ulang dari tahap gate:

```
mercedes_amg    floor y +0.050 ok
   FL gap +0.038  pen 0  flush -0.011  skin +0.086  ok
   FR gap +0.038  pen 0  flush +0.011  skin +0.087  ok
   RL gap +0.038  pen 0  flush +0.001  skin +0.117  ok
   RR gap +0.038  pen 0  flush +0.000  skin +0.114  ok
FIT GATE: PASS
```

Gate ini terbukti bisa gagal (run pertama), sesuai rule "gate yang belum pernah gagal belum bisa dipercaya". Socket x akhir: depan ±0,906, belakang ±0,895 (hasil `--apply`).

Stage `full` membangun ulang `mercedes_amg_full.glb` (7,6 MB) setelah perubahan socket terakhir; stage `test` lulus (`test_mercedes_amg_chassis.gd` dan `test_modular_car.gd`).

### 2.3 Stage review diam-diam tidak merender

Stage `review` melaporkan `ok` dalam 2 detik tanpa PNG apa pun karena `mercedes_amg` belum ada di `CARS` pada `scratch/capture_wheel_review.gd`. Entri sudah ditambahkan dan stage dijalankan ulang; gambar `mercedes_amg_fr_high.png` dan `rr_high.png` dilihat. Script `make_car.ps1` sendiri tidak diubah (tidak menggagalkan stage bila tidak ada PNG); itu catatan untuk planner.

---

## 3. Task 1.3: Scene sasis dan wiring runtime

| File | Isi |
| :--- | :--- |
| `scenes/car/mercedes_amg_chassis.tscn` | `ModularCarAssembler`; bodi `mercedes_amg_body.glb`; `Socket_Wheel_FL/FR/RL/RR` (x depan ±0,906, belakang ±0,895, z ±1,272, y 0,33), `Socket_Cockpit`, `Socket_Exhaust_L/R` (x ±1,0, y 0,30, z −0,70; diukur dari lebar sill 1,023 m); `keeps_original_paint = true` |
| `materials/mercedes_amg_toon_body.tres` | `toon_car_paint.gdshader` + `next_pass` outline `inverted_hull_outline.gdshader` (0,02 m) |
| `scripts/car/gt_car_actor.gd` | `CHASSIS_BY_TEAM[0]` = Mercedes (komentar `# Apex Racing`) |
| `scripts/ui/garage_roster.gd` | slug tim 0 menjadi `mercedes_amg`, nama "Mercedes-AMG GT3 Evo" (kartu garasi sebelumnya masih menulis "Porsche 911 GT3 R (992)") |
| `scripts/world/garage_environment_builder.gd` | **tidak diubah**: sudah membaca `GtCarActor.CHASSIS_BY_TEAM`, sehingga stall 0 otomatis memuat Mercedes |
| `scratch/fit_cars.gd`, `scratch/capture_wheel_review.gd` | entri `mercedes_amg` |

Test yang mengunci "tim 0 = Porsche" diperbarui lebih dulu (RED: 3 asersi gagal), baru wiring (GREEN):
- `tests/test_audi_r8_chassis.gd`: peta tim 0 → `mercedes_amg_chassis.tscn`.
- `tests/test_main_menu_flow.gd`: `expected_slugs[0] = "mercedes_amg"`, pengecualian `base_chassis` dihapus, ditambah 1 asersi kartu garasi tim 0 (nama Mercedes + `mercedes_amg_full.glb` ada).

---

## 4. Task 1.4: Official FIA Safety Car

| File | Isi |
| :--- | :--- |
| `scenes/car/safety_car_chassis.tscn` | Bodi `porsche_911_body.glb`, socket roda sama dengan `base_chassis.tscn`; `RooftopLightbar` (slab 0,96 x 0,07 x 0,24 m di y 1,345, z −0,35) dengan `AmberLed0..3` dan `GreenLed0..1`; `GrilleStrobeL/R` |
| `scripts/car/safety_car_chassis.gd` | `class_name SafetyCarChassis extends ModularCarAssembler`; `StrobeMode { OFF, AMBER, GREEN }`; `set_strobe_mode()` (idempoten); `advance(dt)`; `STROBE_HZ = 12.0` |
| `materials/safety_car_toon_body.tres` | Toon perak (0,62 / 0,63 / 0,65) + ORM kecil untuk highlight, outline hull 0,016 |
| `scripts/car/gt_car_actor.gd` | `SAFETY_CAR_TEAM_ID = -1` dipetakan ke sasis Safety Car |
| `scripts/vfx/race_vfx.gd` | `_build_safety_car()` memakai sasis resmi; `_update_safety_car()` mengikuti `race.safety_car["phase"]` melalui `_strobe_mode_for()`; kotak `LightBar` lama dan `_bar_materials` dihapus |

Perilaku: `DEPLOYED` → amber, empat LED roof berkedip dalam dua pasang bergantian (indeks genap lawan ganjil) pada 12 Hz, strobo grille kiri/kanan ikut pasangannya; `IN_THIS_LAP` → amber mati, dua LED hijau menyala solid; `HIDDEN` → mobil tidak terlihat dan lightbar `OFF`. Livery dibuat di kode (`_build_livery()`): teks `SAFETY CAR` di dua pintu dan kap mesin (`Label3D`), serta pita chevron kuning-hitam (`ChevronStripL/R`, mesh `SurfaceTool`, tanpa overlap sehingga tanpa z-fighting) di antara dua lengkung roda.

Posisi ditentukan dari ukuran mesin Porsche, bukan dari angka spec (bagian 7, butir 1 dan 3). Probe `temp/probe_porsche*.gd`, `temp/probe_hood.gd` mengukur atap (y ≈ 1,33), bidang pintu (x ≈ 0,91 s.d. 0,93), dan bentuk kap.

Perbaikan setelah render pertama: LED hijau terbaca cyan (energi emisi 6 → 3 amber, 2,5 hijau); pita hitam tampak abu-abu (`vertex_color_is_srgb = true`); teks kap mesin tenggelam di cekungan tengah kap (dipindah ke z 1,15); strobo grille terlalu menonjol (diperkecil dan dimundurkan).

---

## 5. Task 1.5: Test dan regresi

### 5.1 Test baru dan yang diperbarui

| Test | Asersi | Catatan |
| :--- | :-: | :--- |
| `tests/test_mercedes_amg_chassis.gd` (baru) | **18** | Pola test BMW; socket, panjang 4,55 m, lebar, tinggi, lantai ≥ 0,04 m, tris 80k s.d. 120k, `FenderLinerMat`, 0 vertex di lengkung, flush, gap, skin |
| `tests/test_car_dynamics_vfx.gd` | 29 (bagian Safety Car: 1 → 12 asersi) | `_test_safety_car` ditulis ulang: sasis khusus, perak, 3 label, chevron, amber DEPLOYED, dua pasang bergantian, 12 Hz, hijau gelap saat DEPLOYED, IN_THIS_LAP → hijau solid dan amber mati, lightbar `OFF` saat mobil pergi |
| `tests/test_audi_r8_chassis.gd` | 17 | Peta tim 0 diperbarui |
| `tests/test_main_menu_flow.gd` | 65 | Peta tim 0 + 1 asersi baru |

Bukti RED sebelum implementasi: `test_audi_r8_chassis` dan `test_main_menu_flow` gagal tepat pada 3 asersi terkait; `test_car_dynamics_vfx` gagal dengan `Could not find type "SafetyCarChassis"`; `test_mercedes_amg_chassis` gagal dengan `Resource file not found: res://assets/cars/mercedes_amg/mercedes_amg_body.glb`.

Frekuensi strobo diukur 23 toggle dalam 1 detik (11,5 Hz); test mengizinkan ±1 Hz karena ujung periode jatuh di batas detik.

### 5.2 Suite penuh

Perintah: `godot --headless --fixed-fps 60 --path . -s res://tests/<suite>.gd` untuk setiap `tests/test_*.gd`. Run terakhir (setelah perubahan kode terakhir): **26 file, 0 exit non-nol, 0 baris `[FAIL]`, 0 parse error**, termasuk `test_race_world` (`ALL PASS`) dan `test_simulation_verification` (`ALL CORE MODEL ASSERTIONS VERIFIED`).

---

## 6. Smoke test native (1080p, preset High, 20 mobil, malam badai, RTX 3050 Laptop GPU)

Catatan kondisi: `project.godot` memiliki `run/max_fps=60`, jadi rata-rata terkunci di 16,67 ms; headroom dilihat dari biaya per frame.

| Run | Skrip | Rata-rata | Median | p95 | p99 | Maks | Orphan |
| :--- | :--- | :-: | :-: | :-: | :-: | :-: | :-: |
| A | `scratch/smoke_fase85.gd` (asli), 40 s | 16,67 ms | n/a | 20,88 | 21,77 | 22,84 | 0 |
| B1 / B2 | varian tanpa Safety Car, 40 s | 16,68 / 16,66 | 16,62 / 16,67 | 22,87 / 22,21 | 23,78 / 23,15 | 65,41 / 25,44 | 0 |
| C1 / C2 | varian Safety Car dipaksa, 40 s (terlihat di 2.401 dari 2.401 frame, strobo amber semua frame, kedua pasang LED teramati) | 16,67 / 16,67 | 18,04 / 16,63 | 20,28 / 22,91 | 21,43 / 23,86 | 24,33 / 50,70 | 0 |
| D | balapan penuh 3 lap, 8×, Safety Car dipaksa di detik ke-25, sampai podium | 16,77 | 15,42 | 22,58 | 23,28 | 196,88 | 0 |

Biaya per frame (run A): GPU 5,22 ms, render-CPU 1,58 ms, `_process` 5,55 ms, physics 7,28 ms; draw call maksimum 1.254. Pembanding yang sudah diterima di laporan Fase 8.5 (preset High, skenario sama): 60 FPS terkunci, p99 19 s.d. 23 ms, maksimum sekitar 23 ms, kerja per frame 5 s.d. 6 ms. Run A cocok dengan angka itu.

Run D: 118 detik dinding, waktu balapan 854 s, **20 dari 20 mobil finis**, podium muncul, `podium.exit_requested` membawa scene ke `res://scenes/main.tscn` (HQ), lalu scene itu dibebaskan: **0 orphan node**. Selama balapan, status Safety Car dan strobo selalu konsisten: `phase 1 / AMBER / terlihat` 262 frame, `phase 2 / GREEN / terlihat` 3.029 frame, `phase 0 / OFF / tersembunyi` 3.770 frame, dan 1 frame transisi `phase 1 / OFF / tersembunyi` (frame tepat saat bendera dipasang, sebelum `vfx.update`).

Run pertama yang **dibuang**: rata-rata 20,43 ms (49 FPS), p99 185,9 ms, maksimum 1.029,8 ms. Saat itu RAM tersedia hanya 1,3 GB dan editor Godot, VS Code, Avast, serta aplikasi lain berjalan; run diulang setelah beban dikurangi dan angkanya tidak dipakai.

---

## 7. Keputusan dan penyimpangan dari spec (Ruling)

1. **Wheelbase 2,543 m, socket z ±1,272** (spec: sekitar 2,65 m / ±1,32). Itu jarak lengkung roda hasil deteksi mesh; socket mengikuti lengkung. Akibatnya mobil tampak sedikit lebih pendek dari Mercedes asli (2,665 m). Biaya bila salah: bodi harus diregangkan, yang menyentuh seluruh pipeline.
2. **Node `Chassis/Lamps` tidak dibuat.** `tests/test_visual_polish_and_consistency.gd:304` mensyaratkan tidak ada `Lamps`, `Headlight`, `Taillight` di sasis mana pun; lampu tetap efek VFX (`lamp_anchors`).
3. **Lightbar di y 1,345 (spec: ≈ 1,28)** karena atap Porsche terukur 1,33 m.
4. **Livery perak saja** (spec: perak/hitam). Aksen hitam hanya pada teks dan pita; cat dua warna butuh tekstur atau shader baru.
5. **Scene dan test Mercedes dibuat sebelum refine** (urutan plan terbalik): `make_car.ps1` mensyaratkan keduanya sejak awal. Entri `CARS` di `fit_cars.gd` ditunda sampai GLB ada.
6. **`git lfs track` tidak dijalankan** karena `.gitattributes` sudah mencakup polanya.
7. **Lebar bodi 2,138 m** (spec: sekitar 2,06 m); masih di dalam rentang test (1,85 s.d. 2,25 m).
8. **Tidak ada commit**, karena tidak diminta.

---

## 8. Bukti visual

Di `executor-report/screenshots/phases/` (14 berkas, `phase-11-*.png`):

- Mercedes-AMG: `phase-11-mercedes-amg-wheel-fr-high.png`, `phase-11-mercedes-amg-wheel-rr-high.png`, `phase-11-mercedes-amg-side.png`, `phase-11-mercedes-amg-race-rear.png`, `phase-11-mercedes-amg-race-side.png`, `phase-11-garage-stall0-mercedes-amg.png` (kartu "GT3 // MERCEDES-AMG GT3 EVO").
- Safety Car: `phase-11-safety-car-side.png`, `phase-11-safety-car-front34.png`, `phase-11-safety-car-bonnet.png`, `phase-11-safety-car-lightbar-amber.png`, `phase-11-safety-car-lightbar-green.png`, `phase-11-safety-car-race-amber-rear.png`, `phase-11-safety-car-race-amber-side.png`, `phase-11-safety-car-race-green-rear.png`.

---

## 9. Batasan dan yang belum diverifikasi

- **"Tanpa frame drop di bawah 60 FPS" tidak dapat dinyatakan penuh.** Rata-rata terkunci 16,67 ms di semua run valid, tetapi sekitar sepertiga frame melebihi 20 ms (judder presentasi di bawah limiter 60 FPS; identik dengan dan tanpa Safety Car, dan sudah dicatat di laporan Fase 8.5), serta ada lonjakan frame tunggal 50 s.d. 197 ms pada run B1, C2, dan D. Penyebab lonjakan tidak diselidiki.
- **Pengukuran 1× hanya 40 detik pertama** setelah pemanasan 15 detik (praktik yang sama dengan Fase 8.5 dan 10). Balapan 3 lap penuh dijalankan pada 8×, dan statistik frame pada 8× tidak mewakili 1×.
- **Dua peringatan saat keluar proses:** (a) `7 RIDs of type "Texture" were leaked` hanya muncul di run D; probe yang cuma memuat menu utama (`temp/probe_menu_exit.gd`) mereproduksinya 3 dari 3 kali, jadi ini perilaku menu yang sudah ada dan tidak terkait Mercedes atau Safety Car. (b) `4 ObjectDB instances were leaked` dan `1 resources still in use` muncul **sekali** pada satu run Safety Car dan tidak muncul lagi pada empat run berikutnya; penyebabnya belum diketahui. Orphan node 0 di setiap run.
- **Cacat visual yang tidak diukur gate:** tepi bibir fender bergerigi di bawah lengkung belakang Mercedes (`phase-11-mercedes-amg-wheel-rr-high.png`); flush kiri −1,1 cm dan kanan +1,1 cm (asimetri mesh AI, toleransi 1,5 cm); tekstur bake di area ventilasi samping berbintik.
- **Safety Car:** warna perak sedikit dingin di bawah ambient render; lightbar relatif kecil dari kamera balap yang jauh; belum dilihat dengan kamera balap di berbagai sudut selain tiga tangkapan di atas.
- Peringatan RGB8 yang sudah ada (`Image format RGB8 not supported by hardware`) juga muncul untuk tekstur Mercedes seperti tekstur lain.
- File `.uid` yang harus di-commit bersama skripnya: `scripts/car/safety_car_chassis.gd.uid`, `tests/test_mercedes_amg_chassis.gd.uid`.

---

## 10. Berkas yang berubah

Baru: `assets/cars/mercedes_amg/` (bodi, full, tekstur, `raw/`), `materials/mercedes_amg_toon_body.tres`, `materials/safety_car_toon_body.tres`, `scenes/car/mercedes_amg_chassis.tscn`, `scenes/car/safety_car_chassis.tscn`, `scratch/car_configs/mercedes_amg.json`, `scripts/car/safety_car_chassis.gd`, `tests/test_mercedes_amg_chassis.gd`, 14 screenshot `phase-11-*.png`, laporan ini.

Diubah: `scripts/car/gt_car_actor.gd`, `scripts/ui/garage_roster.gd`, `scripts/vfx/race_vfx.gd`, `scratch/fit_cars.gd`, `scratch/capture_wheel_review.gd`, `tests/test_audi_r8_chassis.gd`, `tests/test_car_dynamics_vfx.gd`, `tests/test_main_menu_flow.gd`, `ROADMAP.md`.

Skrip bantu sementara ada di `temp/` (tidak ikut git): `probe_exhaust.gd`, `probe_porsche.gd`, `probe_porsche2.gd`, `probe_hood.gd`, `probe_menu_exit.gd`, `capture_safety_car.gd`, `capture_langkah1.gd`, `smoke_langkah1_sc.gd`, `smoke_langkah1_full.gd`.
