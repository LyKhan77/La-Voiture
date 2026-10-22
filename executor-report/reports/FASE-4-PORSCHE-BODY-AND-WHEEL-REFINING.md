# LAPORAN EKSEKUTIF FASE 4 (LANJUTAN): REFINING BODI PORSCHE 911 GT3 & MODUL RODA GT3

**Status:** SELESAI & TERVERIFIKASI DI GODOT (modular car test PASS, visual 4 roda diperiksa)
**Task Spec:** `prompt/TASK-PORSCHE-BODY-AND-WHEEL-REFINING.md`
**Metode:** Blender 5.2 (live addon via socket port `9875` + headless CLI), Godot 4.7.2 untuk verifikasi.

---

## 1. Deliverable B: Modul Roda GT3 (`assets/cars/parts/gt3_wheel_master.glb`)

Roda lama berupa silinder primitif (ban 64 vertex, kaliper berupa kotak 8 vertex). Roda dibangun ulang dari nol dengan script `scratch/build_gt3_wheel.py` (sumbu roda = +X, sisi luar = +X, pusat roda di origin).

| Node | Isi |
| :--- | :--- |
| `GT3_AlloyRim` | Barrel dengan drop-center, dish cekung dalam, 5 spoke Y-split twin-spoke (gaya BBS FI-R), takik Y berujung bulat, lubang relief di pangkal spoke, hub boss. Dish dipotong dengan Boolean exact lalu di-bevel. |
| `GT3_TireRubber` | Profil penampang melengkung (bahu ban membulat, sidewall menggembung), 4 alur tapak melingkar, teks timbul "GT3 RACING" (2 sisi, material putih terpisah) di sidewall luar. R luar 0.33 m, lebar 0.28 m. |
| `GT3_SidewallStripe` | Cincin tipis di dalam alur sidewall pada radius 0.27 m. Satu surface, jadi override material per kompon (`tire_stripe_*.tres`) tetap bekerja. |
| `GT3_BrakeDisc` | Dua cincin gesek cross-drilled (2 baris x 36 lubang), 36 vane melengkung di antaranya, hat aluminium anodized. Radius 0.185 m, tebal 0.024 m. |
| `GT3_CenterNut` | Hex center-lock merah anodized dengan kerah dudukan, tutup bertingkat, dan klip pengunci baja. |
| `GT3_BrakeCaliper` | Monobloc 6-piston kuning `#FFC200`, melengkung mengikuti disc, 3 bore piston di sisi luar, baut bleed. Statis (anak `GT3_Wheel_Assembly`, bukan `WheelRotating`). |

Hierarki node di Godot identik dengan sebelumnya (dicek dengan `scratch/inspect_wheel_glb.gd`), sehingga `wheel_controller.gd` dan 4 scene `porsche_wheel_*.tscn` tidak perlu diubah.

Angka: sekitar 48 ribu segitiga per roda (tire 16.4k, rim 16.5k, disc 10k, stripe 2.2k, nut 2k, caliper 1.2k). Ukuran file naik dari 179 KB ke sekitar 1.3 MB. Aset ini hanya dipakai scene showroom/pit stop, bukan race world.

Penyimpangan dari spec: warna rim memakai linear (0.10, 0.108, 0.125), lebih terang dari `#1E2024`. Nilai spec tampil hitam pekat di showroom gelap sehingga spoke tidak terbaca.

---

## 2. Deliverable A: Body Mesh (`assets/cars/porsche_911/porsche_911_body.glb`)

### Temuan
- Mesh Tripo masih memuat ban "baked" tebal di keempat sudut (radius 0.355 m, sisi luar sampai x = ±1.14). Ban ini menutupi roda baru, terutama di belakang (roda kanan-belakang tampak sebagai cakram hitam di screenshot lama).
- `FenderLinerMat` lama hanya berupa 4 plug silinder datar, bukan inner tub.
- Pusat lengkungan spakbor asli (z = +1.19 depan, -1.26 belakang, tinggi 0.35) tidak sama dengan socket lama (z = +1.25 / -1.18), selisih 6 sampai 8 cm. Ban juga menjorok melewati bibir spakbor di x = 1.004.

### Pekerjaan (`scratch/refine_body.py`, headless Blender)
1. Pusat sumbu tiap lengkungan dicari dengan circle-fit pada tapak ban baked.
2. Ban baked, dinding sumur yang bergerigi, dan plug lama dihapus (sekitar 15 ribu face).
3. Tepi dalam bibir spakbor (pita datar di |x| sekitar 1.004) dirapikan dan vertex tepinya di-snap ke lingkaran sempurna R = 0.372 m.
4. Inner tub baru per sudut: dinding setengah-pipa R = 0.372 m sepanjang 300 derajat, dinding dalam tertutup di |x| = 0.64, material slot 1 `FenderLinerMat` (`#0A0A0A`, roughness 0.95). Dasar tub dijepit di z = 0.10 agar tidak keluar dari bawah bodi.
5. Mesh tidak di-weld pada hasil akhir (menjaga UV seam). Weld hanya dipakai pada salinan untuk analisis konektivitas.

### Hasil dimensi
- Lebar 2.058 m, panjang 4.57 m, tinggi 1.336 m dari tanah (sebelumnya lebar 2.28 m karena ban baked).
- Origin dan orientasi tidak berubah (+Z depan, +Y atas, +X kanan).
- Cat livery Gulf dan permukaan flare luar tidak disentuh.

### Perubahan socket (di luar spec, perlu diketahui)
File `scenes/car/base_chassis.tscn`, hanya 4 baris transform:

| Socket | Lama | Baru |
| :--- | :--- | :--- |
| `Socket_Wheel_FL` | (-0.90, 0.33, 1.25) | (-0.86, 0.33, 1.19) |
| `Socket_Wheel_FR` | (0.90, 0.33, 1.25) | (0.86, 0.33, 1.19) |
| `Socket_Wheel_RL` | (-0.90, 0.33, -1.18) | (-0.86, 0.33, -1.26) |
| `Socket_Wheel_RR` | (0.90, 0.33, -1.18) | (0.86, 0.33, -1.26) |

Alasan: roda harus di tengah lengkungan asli dan permukaan luar ban rata dengan bibir spakbor (flush stance). Jika ingin kembali ke nilai lama, cukup ubah 4 baris ini, tetapi roda akan menembus bibir spakbor.

---

## 3. Verifikasi

| Langkah | Hasil |
| :--- | :--- |
| `Godot --headless --editor --quit` (re-import) | Berhasil, tanpa error |
| `scratch/inspect_wheel_glb.gd` | Hierarki node identik dengan sebelum refining |
| `Godot --headless -s tests/test_modular_car.gd` | 18 assertion PASS, `ACCEPTANCE: PASS` (0 failure), diulang setelah body dan socket diganti |
| `capture_showroom.gd` (d3d12) | `scratch/godot_showroom_screenshot.png`, lengkungan bersih, 4 roda tampak detail |
| `scratch/capture_wheel_closeups.gd` | 5 sudut close-up di `scratch/wheel_views/` (kanan, kiri, depan-kanan, belakang-kanan, depan-kiri) |

Screenshot hasil: `phase-4-refined-showroom.png`, `phase-4-refined-wheel-rear-right.png`, `phase-4-refined-left-side.png` (di folder ini).

---

## 4. Batasan & Catatan

- `tests/test_race_world.gd` tidak dijalankan: race world tidak memakai body, chassis, maupun roda ini (dicek lewat grep).
- Kaliper statis berada di sisi belakang pada roda kanan tetapi di sisi depan pada roda kiri, karena assembler memutar roda kiri 180 derajat (`rotation.y = PI`). Assembler tidak diubah.
- Sisa potongan panel lama masih terlihat rendah di dalam bukaan lengkungan (dekat rocker). Sebagian besar tertutup roda.
- Tool MCP `blender` gagal terhubung. Addon Blender mendengarkan di port `9875` (bukan `9876` seperti di instruksi), jadi eksekusi dilakukan lewat socket mentah dan Blender headless.
- Scene Blender live sekarang berisi objek roda baru. Objek roda lama hanya di-rename `OLD_*` dan disembunyikan, tidak dihapus.

## 5. Backup & Script

- Backup aset asli: `scratch/backup_wheel_refine/` (`gt3_wheel_master.orig.glb`, `porsche_911_body.orig.glb`, `godot_showroom_screenshot.before.png`).
- Script reproduksi: `scratch/build_gt3_wheel.py` (roda) dan `scratch/refine_body.py` (bodi, jalankan dengan `blender --background --python scratch/refine_body.py -- <in.glb> <out.glb>`).
- Script capture baru: `scratch/capture_wheel_closeups.gd`.
