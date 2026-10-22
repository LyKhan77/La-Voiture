# LAPORAN EKSEKUTIF FASE 7: PERBAIKAN FITMENT RODA DAN GEOMETRI RONGGA BAN (8 MOBIL GT3)

Tugas: `prompt/TASK-FIX-CAR-WHEEL-FIT-AND-FENDERS.md`. Cakupan: nissan_gtr, aston_vantage, bmw_m4, lambo_huracan, honda_nsx, chevy_corvette, lexus_rcf, mclaren_720s (semua yang dibuat oleh `scratch/refine_car.py`). Porsche 911 dan Audi R8 tidak diubah.

## 1. Ringkasan

- Seluruh 8 mobil lulus gerbang baru `scratch/fit_cars.gd`: lantai bodi +0,050 m (BMW +0,064 m), celah radial ban ke lengkung 3,8 sampai 3,9 cm, 0 vertex di dalam volume ban, kulit fender di atas ban minimal +6,4 cm di seluruh lebar ban, dan tepi luar ban rata dengan fender per as (selisih paling besar 1,4 cm pada Lambo, 0,5 cm pada mobil lain).
- Perbaikan tahap kedua berasal dari review langsung `*_full.glb`: pada roda depan Aston, McLaren, Lambo, Nissan, dan Lexus kulit fender di atas ban terlalu rendah atau hilang, sehingga ban menyembul dari bodi. Gerbang tahap pertama tidak mendeteksinya (ia hanya mengukur vertex yang ada). Penyebab dan perbaikannya di bagian 2b.
- Seluruh test Godot lulus (lihat bagian 5). Delapan bodi, 24 tekstur, 8 `*_full.glb`, 5 scene `.tscn` (socket X), dan 8 file test chassis berubah. Backup sebelum perubahan ada di `temp/backup_wheelfit_20261022/` (proyek ini bukan repo git).
- Diagnosis di dokumen tugas benar soal angka, tetapi tiga dari empat penyebab yang ditulis tidak berlaku. Perbaikan yang dikerjakan mengikuti penyebab yang terukur, bukan rumusan dokumen (bagian 2).

## 2. Koreksi terhadap diagnosis di dokumen tugas

| Butir di dokumen | Temuan terukur | Tindakan |
| :--- | :--- | :--- |
| 1. `Q[:, 2] -= RAW_Z - Z_AXLE` membuat bodi ambles dan roda terdorong ke spakbor | Baris itu menyamakan sumbu roda mesh mentah dengan sumbu roda master (0,33 m); posisi roda terhadap lengkung tidak bergeser, karena pemotong dan lip dipusatkan di `Z_AXLE`. Titik terendah bodi (y -0,05 sampai -0,09) berada tepat di bawah tiap roda dengan y = 0,33 - r untuk r 0,38 sampai 0,42: sisa tapak ban mentah AI yang lebih besar dari ban master. Lantai di antara as tidak ambles (+0,004 sampai +0,067). | Sisa tapak dibuang, geometri lain yang di bawah 0,05 m diratakan ke 0,05 m. Bodi **tidak** diangkat: menaikkannya 13 cm akan menjadikan ride height 13 cm lebih tinggi dan celah atas roda ikut melebar. |
| 2. Overhang depan dan belakang berbeda membuat sumbu Z off-center | `AXLE` memakai `RAW_Y_F` dan `RAW_Y_R` terpisah, dan bodi digeser agar titik tengah wheelbase di 0. Socket ±wheelbase/2 jatuh persis di pusat lengkung; overhang yang tidak sama (BMW +6 cm) hanya menggeser bodi terhadap origin, bukan roda terhadap lengkung. | Tidak ada perubahan Z. |
| 3. Lebar track depan dan belakang berbeda | Benar. Selisih tepi fender belakang minus depan: Corvette +3,7 cm, Honda +2,8 cm, McLaren +2,0 cm, Aston +1,7 cm; Lambo kiri-kanan depan berbeda 2,3 cm dari mesh AI sendiri. | Socket X dipisah per as untuk 5 mobil (bagian 4). |
| 4. Radius lengkung 0,372 m kurang longgar | Celah radial sebenarnya 0,372 - 0,33 = 0,042 m. Angka "+0,011 m" di diagnostik lama adalah artefak: ia mengambil vertex lip terendah di jendela z ±0,15 m (lip di samping puncak sudah lebih rendah) dan membandingkannya dengan puncak ban. Selain itu skrip hanya membaca surface 0 (cat). | Radius tidak diubah. Metrik diganti dengan celah radial sebenarnya (bagian 3). |

Temuan tambahan yang tidak ada di dokumen: dinding tub (surface 1, liner) menembus separuh bawah ban pada semua mobil buatan `refine_car.py` (60 sampai 78 vertex per roda; Honda dan BMW 5 sampai 11). Letaknya di dalam karet ban sehingga tidak terlihat, tetapi gerbang "0 penetrating" lama lulus hanya karena surface 1 tidak ikut diperiksa.

## 2b. Temuan dari review: kulit fender di atas ban hilang di roda depan

Mesh AI menyatukan ban dengan fender: di atas ban hampir tidak ada fender terpisah, dan di sisi luar kulit bodi lebih rendah daripada puncak lengkung (sumbu + 0,372 m). Pemotongan roda (silinder radius 0,372 m dari x = 0,5 sampai 1,35) lalu menghapus seluruh kulit luar di situ; ban master (puncak 0,66 m) menyembul keluar dari bodi, terlihat jelas dari atas dan dari samping. Kulit fender di atas ban, tinggi di atas puncak ban 0,66 m, sebelum perbaikan (roda depan, terendah di lebar ban): Aston tidak ada sama sekali di setengah luar ban, McLaren +1,8 cm, Lambo +3,1 cm, Nissan +3,9 cm, Lexus +4,3 cm; Audi dan Porsche (rujukan) +7 sampai +16 cm. Roda belakang semua mobil dan roda depan BMW, Honda, Corvette sudah cukup (+5 sampai +13 cm).

Usulan memakai ukuran ban mesh mentah (radius 0,34 sampai 0,43 m) tidak dipakai: di mesh mentah ban sendiri sudah menjadi garis fender, jadi ban yang lebih besar menyembul lebih parah; diameter 0,80 sampai 0,85 m juga jauh di atas ban GT3 asli (sekitar 0,68 m) dan berbeda antar mobil, serta menuntut radius per mobil di `wheel_controller.gd` dan semua test.

Perbaikan: `refine_car.py` mengukur tinggi kulit mentah per as dan menaikkannya secara lokal (peluruhan halus ke atas sumbu, ke arah dalam bodi, dan sepanjang mobil), pada mesh mentah sebelum remesh dan potong agar bake tekstur tetap cocok, sampai kulit melewati puncak lengkung 4 cm (`fender_lift: "auto"`, `fender_margin`). Besarnya (depan/belakang, m): Aston 0,091 / 0,028; McLaren 0,053 / 0; Lambo 0,054 / 0; Nissan 0,045 / 0,022; Lexus 0,031 / 0,025; BMW, Honda, Corvette tidak dihitung ulang karena sudah lulus gerbang. Mesh yang diangkat bisa bersilangan dengan dirinya sendiri dan boolean eksak tanpa `use_self` menghapus hampir seluruh bodi tanpa pesan galat (tersisa sekitar 5 persen); kini dipakai `use_self` dan ada pemeriksaan jumlah face (di bawah 60 persen dianggap gagal).

## 3. Perubahan

- `scratch/refine_car.py`
  - Langkah 4a "ground clamp": faces yang punya vertex di bawah `ground_min` (default 0,05 m) di bawah roda (x > 0,55, |y - sumbu| < 0,35) dibuang; vertex lain di bawah 0,05 diangkat ke 0,05. Log: `ground clamp: N tread faces under the wheels dropped, M vertices lifted`.
  - Busur tub dibatasi `tub_arc_deg` (default dihitung dari `Z_FLOOR`, sekitar 125 derajat dari atas) agar dinding tub tidak masuk ke separuh bawah ban.
  - `--out-dir` kini dijadikan path absolut: dengan path relatif, `Image.save()` Blender tidak menulis PNG tekstur (tanpa pesan galat).
  - Langkah 0b "fender lift" (bagian 2b): `fender_lift` (`"auto"` atau `{"front": m, "rear": m}`), `fender_margin` (0,04 m). Log: `fender <as> <sudut>: skin above the axle ... -> need N cm` dan `fender lift applied`.
  - Pemotongan lengkung: bodi dibersihkan (vertex ganda, face degenerate, orientasi) lalu dipotong dengan boolean eksak `use_self`; hasil dengan kurang dari 60 persen face asal dianggap gagal dan diulang atau dihentikan dengan galat.
  - Opsi baris perintah untuk melihat lebih cepat: `--lift-report`, `--precut-only` (dengan `"debug_precut": true`), `--stop-after-cut`.
- `scratch/fit_cars.gd` (baru): gerbang fitment seluruh 10 chassis. Per roda: celah radial (vertex bodi terdekat di dalam slab ban, semua surface, dikurangi radius ban), jumlah vertex di dalam radius ban, dan selisih tepi luar ban terhadap titik terlebar bodi di zona lengkung as itu; per mobil: titik terendah bodi. Ambang: celah 2,5 sampai 5 cm, penetrasi 0, flush kurang dari 1,5 cm, kulit fender di atas ban minimal 5 cm di seluruh lebar ban (tinggi vertex cat tertinggi per bin 4 cm dikurangi puncak ban; bin tanpa kulit dibaca -1), lantai di atas 0,04 m. Keluar dengan kode 1 bila gagal. `-- --apply <mobil...>` menulis ulang X keempat socket ke usulan (rata-rata kiri-kanan per as). Porsche dan Audi dicetak sebagai referensi dan tidak dihitung gagal (jalur lama).
- Scene `scenes/car/*_chassis.tscn`: hanya angka X socket untuk aston_vantage, lambo_huracan, honda_nsx, chevy_corvette, mclaren_720s.
- Test `tests/test_<mobil>_chassis.gd`: delapan mobil: assertion lantai diperketat dari "tidak turun lebih dari 10 cm di bawah tanah" ke "titik terendah minimal 4 cm di atas tanah", dan assertion baru "kulit fender di atas tiap ban minimal 5 cm di seluruh lebar ban" lewat helper baru `tests/wheel_fit_checks.gd`; uji "ban rata dengan fender" kini membandingkan tiap as dengan fender as itu sendiri (sebelumnya satu titik terlebar untuk kedua as, sehingga gagal pada fender yang bertingkat), pemeriksaan posisi socket tidak lagi mengunci X (hanya simetri kiri-kanan, tinggi sumbu, Z, dan lebar track 0,75 sampai 0,95 m), dan ada assertion baru untuk celah radial 2,5 sampai 5 cm tanpa vertex di dalam ban (tub ikut dihitung). Semuanya lewat `tests/wheel_fit_checks.gd`, yang juga dipakai `fit_cars.gd`; tiap test chassis kini 18 assertion. Assertion kulit fender dilihat gagal pada aset sebelum perbaikan tahap kedua tepat di 5 mobil (Aston, McLaren, Lambo, Nissan, Lexus) dan lulus di 3 mobil lain.
- Aset: `assets/cars/<mobil>/<mobil>_body.glb`, `textures/{base_color,normal,orm}.png`, `<mobil>_full.glb` untuk 8 mobil.
- Alat dan aturan baru: `scratch/make_car.ps1` (pipeline satu perintah), `scratch/capture_wheel_review.gd` (render tinjauan), `tests/wheel_fit_checks.gd` (pengukuran bersama), `.claude/rules/car-asset-pipeline.md` (aturan agen), `.git` (repo baru, tanpa commit) dan tiga baris di `.gitignore`.

## 4. Hasil terukur (`fit_cars.gd`)

| Mobil | Lantai sebelum | Lantai sesudah | Celah radial sebelum (surface liner ikut) | Celah sesudah | Vertex di dalam ban sebelum | sesudah | Socket X depan / belakang (m) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| nissan_gtr | -0,078 | +0,050 | -0,091 | +0,038 | 74 sampai 78 | 0 | 0,807 / 0,807 (tetap) |
| aston_vantage | -0,089 | +0,050 | -0,091 | +0,039 | 72 | 0 | 0,818 / 0,818 menjadi 0,808 / 0,825 |
| bmw_m4 | +0,064 | +0,064 | -0,018 sampai -0,021 | +0,038 | 5 sampai 7 | 0 | 0,847 / 0,847 (tetap) |
| lambo_huracan | -0,068 | +0,050 | -0,091 | +0,039 | 60 | 0 | 0,872 / 0,872 menjadi 0,875 / 0,868 |
| honda_nsx | +0,024 | +0,050 | -0,025 sampai -0,035 | +0,039 | 5 sampai 11 | 0 | 0,860 / 0,860 menjadi 0,846 / 0,873 |
| chevy_corvette | -0,076 | +0,050 | -0,091 | +0,039 | 60 sampai 61 | 0 | 0,850 / 0,850 menjadi 0,830 / 0,868 |
| lexus_rcf | -0,049 | +0,050 | -0,091 | +0,038 | 78 | 0 | 0,818 / 0,818 (tetap) |
| mclaren_720s | -0,083 | +0,050 | -0,091 | +0,039 | 60 | 0 | 0,878 / 0,878 menjadi 0,868 / 0,887 |

Kulit fender di atas ban (roda depan, terendah di lebar ban, cm di atas puncak ban 0,66 m), sebelum dan sesudah tahap kedua:

| Mobil | Sebelum | Sesudah | Fender lift depan / belakang (cm) | Polycount |
| :--- | :--- | :--- | :--- | :--- |
| aston_vantage | tidak ada | +7,5 | 9,1 / 2,8 | 105.750 |
| mclaren_720s | +1,8 | +7,4 sampai +7,9 | 5,3 / 0 | 103.637 |
| lambo_huracan | +3,1 | +8,9 | 5,4 / 0 | 90.722 |
| nissan_gtr | +3,9 | +8,7 | 4,5 / 2,2 | 90.523 |
| lexus_rcf | +4,3 | +7,3 sampai +7,6 | 3,1 / 2,5 | 100.898 |
| bmw_m4, honda_nsx, chevy_corvette | +9,7 / +6,6 / +6,4 | tidak diulang | - | 98.759 / 105.620 / 90.390 |

Selisih tepi luar ban terhadap fender setelah perbaikan: paling besar 0,5 cm pada 7 mobil; Lambo kiri depan -1,4 cm dan kanan depan +1,1 cm (mesh AI-nya tidak simetris kiri-kanan, tidak bisa diatasi socket yang simetris). Socket X akhir (depan / belakang, m): Aston 0,815 / 0,825; Lambo 0,875 / 0,868; Honda 0,846 / 0,873; Corvette 0,830 / 0,868; McLaren 0,868 / 0,887; Lexus 0,821 / 0,818 (digeser 3 mm oleh `--apply` saat menguji `make_car.ps1`); Nissan dan BMW tidak berubah dari nilai awal. Polycount semua mobil di rentang 80k sampai 120k yang diuji.

Gerbang dijalankan pada aset sebelum perbaikan tahap pertama: 39 kegagalan; setelah tahap pertama, tetapi dengan metrik kulit fender ditambahkan: 10 kegagalan (roda depan 5 mobil); setelah tahap kedua: PASS. Itulah bukti bahwa gerbang benar-benar bisa gagal.

## 5. Verifikasi

- `scratch/fit_cars.gd`: FIT GATE PASS.
- Seluruh 18 file di `tests/` dijalankan headless setelah perbaikan tahap kedua dan semuanya exit 0 dengan 0 failure: delapan test chassis baru (masing-masing 17 assertion), `test_audi_r8_chassis.gd` (17), `test_audio_and_race_weekend.gd` (35), `test_modular_car.gd`, `test_gt_sim.gd` (43), `test_weather_and_ai.gd` (43), `test_car_dynamics_vfx.gd` (18), `test_race_hud.gd` (31), `test_race_weekend_and_physics.gd` (31), `test_pit_wall.gd`. `test_race_world.gd` (sekitar 10 menit) dan `test_simulation_verification.gd` exit 0 tetapi tidak mencetak baris ringkasan PASS yang bisa dibaca skrip. Pada run tahap pertama ada 3 kegagalan (Corvette, Honda, McLaren: uji "ban rata dengan fender" memakai satu titik terlebar untuk kedua as) yang diperbaiki dengan uji per as.
- Screenshot sesudah perbaikan: `executor-report/phase-7-<mobil>-showroom.png` (3/4 depan) dan `phase-7-<mobil>-left_side.png` (samping). Versi sebelum tahap pertama disimpan di `executor-report/wheel-fit-before/`. Close-up roda depan kanan dari samping dan dari atas untuk 5 mobil yang diperbaiki tahap kedua: `executor-report/wheel-fit-after/<mobil>-front-right-{high,side}.png`.
- Tinjauan visual: close-up roda depan dan belakang kanan dari samping dan atas serta tampak samping penuh untuk kedelapan mobil. Pada kelima mobil tahap kedua fender kini menutup ban dengan lengkung yang jelas; BMW, Honda, dan Corvette dinilai sudah benar dari render yang sama. Tidak ada artefak yang saya anggap mengganggu, tetapi tekstur toon AI (bercak terang di sekitar lengkung Lambo dan Nissan) sudah ada sejak bake awal dan tidak diubah.

## 6. Alur kerja untuk mobil berikutnya

Rongga ban tiap mobil berbeda: radius tapak ban mentah AI 0,38 sampai 0,42 m padahal ban master 0,33 m, lebar fender depan dan belakang berbeda 0 sampai 4 cm, tinggi lantai berbeda. Alur lama memakai konstanta yang sama untuk semuanya, socket X ditulis tangan, dan gerbangnya salah ukur. Alur yang disarankan (langkah 2 sampai 5 dijalankan berurutan oleh `scratch/make_car.ps1 -Car <slug>`; lihat bagian 8):

1. **Ukur saat intake.** `refine_car.py ... --detect-only` mencetak sumbu dan radius tapak. Radius tapak di luar kisaran yang diterima planner atau wheelbase yang tidak masuk akal berarti mesh mentah perlu dibuat ulang (foto referensi samping lurus).
2. **Bangun.** `refine_car.py ... --out-dir <path absolut di temp/>`; periksa log (`fender lift applied`, `wheel cut` dengan jumlah face yang masuk akal, `ground clamp`, `FINAL tris`, bbox z min = 0,05). Jalankan satu mobil sekali waktu: refine memakai sekitar 4 sampai 6 GB RAM, dan pada mesin 16 GB yang juga menjalankan aplikasi lain proses latar belakang pernah dimatikan sistem.
3. **Pasang dan impor.** Salin body GLB dan tiga PNG ke `assets/cars/<mobil>/`. Bila editor Godot terbuka, impor ulang dengan `godot --headless --path . --import` tetap bekerja untuk file yang berubah (aksi `reimport` lewat MCP tidak membangun ulang cache GLB).
4. **Turunkan socket dari mesh.** `godot --headless --path . -s scratch/fit_cars.gd -- --apply <mobil>` untuk X per as; Z tidak perlu disentuh (ditentukan oleh deteksi sumbu).
5. **Gerbang.** `godot --headless --path . -s scratch/fit_cars.gd` harus PASS (termasuk kulit fender di atas ban); lalu `build_full_car.py`, test chassis mobil itu, dan screenshot. Lihat sendiri close-up roda depan dari samping dan dari atas: gerbang hanya mengukur apa yang ada, jadi fender yang hilang hanya tertangkap oleh metrik kulit dan oleh mata.
6. **Proses aman.** Selalu uji ke `temp/` dulu dan buat backup sebelum menimpa; disarankan `git init` agar ada undo.

## 7. Batasan dan yang belum dikerjakan

- Porsche dan Audi tidak lulus gerbang baru (celah Audi 0,1 sampai 1,4 cm; tub Porsche menembus ban 16 vertex). Keduanya dibuat oleh jalur lama (`refine_body.py`, `refine_audi_r8.py`) dan tidak diubah di tugas ini; perlu keputusan planner apakah dipindah ke `refine_car.py`.
- Ambang celah 2,5 sampai 5 cm dan flush 1,5 cm adalah usulan yang diturunkan dari dokumen tugas; Lambo kiri depan dan kanan depan (1,1 sampai 1,2 cm) masih di dalam ambang 1,5 cm tetapi di atas 1 cm yang disebut dokumen.
- Sembilan test chassis masih memuat konstanta socket dan radius secara hardcode; baru kulit fender yang diukur lewat helper bersama (`tests/wheel_fit_checks.gd`). Celah, penetrasi, flush per as, dan lantai sebaiknya ikut dipindah ke helper itu; belum dikerjakan.
- Perubahan test X per as, flush per as, dan lantai 4 cm tidak diperlihatkan gagal pada kode lama satu per satu; yang diperlihatkan gagal-lalu-lulus adalah `fit_cars.gd` (aset lama dan baru) dan assertion kulit fender (gagal tepat di 5 mobil sebelum tahap kedua).
- Fender lift adalah deformasi lokal pada mesh AI: teksturnya ikut bergeser bersama permukaan (bake dilakukan setelah lift), tetapi bentuk fender depan Aston naik 9 cm dan perlu dinilai oleh art director; angka `fender_margin` (4 cm) dan ambang gerbang (5 cm) adalah usulan yang mengikuti tinggi fender Audi (minimal +7 cm).
- BMW, Honda, dan Corvette tidak di-refine ulang pada tahap kedua karena sudah lulus gerbang; bila nanti ambang kulit dinaikkan, mereka yang paling dekat batas (+6,4 sampai +6,7 cm di Honda dan Corvette).

## 8. Pencegahan: mengapa alur lama lolos dan apa yang diubah

Cacat fitment ini lolos bukan karena satu bug, tetapi karena alur lama tidak punya cara untuk melihatnya. Tabel berikut memetakan tiap kelemahan proses ke pencegahannya.

| # | Kelemahan di alur lama | Pencegahan | Status |
| :--- | :--- | :--- | :--- |
| 1 | Gerbang yang tidak pernah terlihat gagal: `diagnose_wheels.gd` melaporkan "+0,011 m" dan 0 penetrasi pada mobil yang cacat (angka itu artefak jendela, dan hanya surface 0 yang dibaca). | Gerbang baru wajib dijalankan dulu pada aset yang diketahui rusak dan harus gagal sebelum dipercaya. Dilakukan untuk `fit_cars.gd` (39 kegagalan, lalu 10, lalu PASS) dan untuk assertion kulit fender (gagal tepat di 5 mobil). | Dikerjakan |
| 2 | Gerbang hanya mengukur apa yang ada, bukan apa yang hilang: fender yang terhapus tidak punya vertex untuk diukur. | Metrik kulit fender membaca bin tanpa kulit sebagai -1 (gagal). Prinsip: tiap metrik harus punya kasus "ada tapi salah" dan "tidak ada". | Dikerjakan |
| 3 | Diagnosis tugas diterima apa adanya (3 dari 4 penyebab di brief tidak terbukti). | Ukur dulu, bandingkan dengan brief, dan laporkan koreksi sebelum mengubah apa pun (bagian 2 dan 2b). | Dilakukan di tugas ini; belum menjadi aturan tertulis di luar laporan |
| 4 | Verifikasi visual hanya 2 mobil dari satu sudut; cacat roda depan terlihat jelas hanya dari atas. | `scratch/capture_wheel_review.gd`: close-up roda depan dan belakang dari samping dan atas, plus tampak samping penuh, untuk semua mobil. Wajib dilihat sebelum mobil dinyatakan selesai (daftar periksa 9.10 di spec). | Dikerjakan |
| 5 | Konstanta global untuk bodi yang berbeda: radius lengkung 0,372 m, X socket sama, tidak ada penyesuaian tinggi fender, tidak ada penanganan sisa tapak. | Nilai diukur per mobil: sumbu otomatis, `fender_lift` otomatis, ground clamp, socket X dari `fit_cars.gd --apply`. | Dikerjakan |
| 6 | Pipeline gagal diam-diam: boolean membuang sekitar 95 persen bodi tanpa galat; `Image.save()` dengan path relatif tidak menulis PNG. | Pemeriksaan jumlah face setelah potong (galat bila di bawah 60 persen), `--out-dir` absolut, dan log yang wajib dibaca (bagian 6, langkah 2). | Dikerjakan |
| 7 | Sembilan test chassis adalah salinan templat dengan angka hardcode, sehingga mudah ikut salah. | Satu definisi pengukuran di `tests/wheel_fit_checks.gd` (celah radial, penetrasi, flush per as, kulit fender, lantai, tata letak socket), dipakai oleh delapan test chassis dan oleh `fit_cars.gd`. Test tidak lagi mengunci X socket: `fit_cars.gd --apply` menurunkannya dari mesh dan flush per as memeriksanya. Terbukti pada Lexus: `--apply` menggeser socket depan 3 mm dan test chassis tetap lulus tanpa diubah. Yang masih hardcode: `AXLE_Z` dan `ARCH_R` per test. | Dikerjakan |
| 8 | Tidak ada git dan tidak ada backup otomatis. | `git init` dijalankan (`.gitignore` ditambah `.godot/`, `temp/`, `*.stackdump`); `make_car.ps1` mencadangkan berkas mobil sebelum menimpa. Repo belum punya commit: tanpa commit dasar tidak ada yang bisa dikembalikan. | Sebagian: commit dasar menunggu keputusan pemilik proyek |
| 9 | Beban mesin: refine memakai 4 sampai 6 GB RAM dan proses latar belakang pernah dimatikan sistem. | `make_car.ps1` menolak refine bila RAM yang tersedia di bawah 5 GB (`-Force` untuk menimpa); satu mobil sekali waktu. Diuji: menolak pada 1,6 GB dengan pesan yang jelas. | Dikerjakan |
| 10 | Urutan langkah bisa dilewati atau dijalankan sebagian. | `scratch/make_car.ps1 -Car <slug>` menjalankan refine, install, import, gate, full GLB, test, dan review berurutan dan berhenti pada kegagalan pertama (`-From <tahap>`, `-DryRun`, `-NoReview`). Diuji: dry run, jalur gagal (config tidak ada, RAM kurang), dan lari nyata dari tahap install dan gate pada Lexus dan Honda. Tahap refine memakai pemeriksaan log yang sama dengan yang dibaca manual (diuji pada log Lexus), tetapi belum dijalankan penuh lewat skrip karena RAM saat itu hanya 1,6 GB. | Dikerjakan |
| 11 | Tidak ada aturan tertulis untuk agen berikutnya. | `.claude/rules/car-asset-pipeline.md` (berlaku untuk berkas pipeline mobil): definisi selesai, aturan "gerbang harus pernah gagal", ukur sebelum mengubah, dan larangan menaikkan seluruh bodi. | Dikerjakan |

Definisi "selesai" untuk satu mobil baru (usulan sebagai syarat tertulis):
1. Log refine dibaca: `fender lift applied`, `wheel cut` dengan jumlah face yang masuk akal, `ground clamp`, `FINAL tris` dalam rentang, bbox z min 0,05.
2. `scratch/fit_cars.gd` PASS untuk mobil itu (lantai, celah radial, penetrasi, flush per as, kulit fender).
3. Test chassis mobil itu dan suite lama 0 failure.
4. `scratch/capture_wheel_review.gd -- <mobil>` dijalankan dan gambarnya dilihat, terutama tampak atas roda depan; tidak ada ban yang menyembul dari bodi.
5. `*_full.glb` dibangun ulang dari `.tscn` setelah socket berubah, dan laporan diperbarui.

Yang masih terbuka: commit dasar di repo git yang baru dibuat (satu perintah, menunggu keputusan pemilik proyek); menjalankan tahap refine penuh lewat `make_car.ps1` pada mobil berikutnya saat RAM cukup (bagian ini belum diuji ujung ke ujung); dan memindahkan Porsche serta Audi ke `refine_car.py` agar semua mobil memakai gerbang yang sama (keputusan planner, tidak dikerjakan).
- Jumlah edge terbuka mesh hasil refine 728 sampai 1154 (sebelumnya tidak dicatat per mobil, jadi tidak ada pembanding).
