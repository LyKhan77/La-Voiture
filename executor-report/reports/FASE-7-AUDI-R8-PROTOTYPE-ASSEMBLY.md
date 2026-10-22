# LAPORAN EKSEKUTIF FASE 7: PROTOTIPE AUDI R8 LMS GT3 (REFINING BODI & MASTER ASSEMBLY)

**Status:** SELESAI dan TERVERIFIKASI DI GODOT (semua suite PASS, 0 failure; visual showroom + race world diperiksa). Tambahan setelah review: warna asli untuk semua mobil, aset utuh `*_full.glb`, folder `porsche_911` dirapikan (bagian 6, 7, 8). **Pembaca Planner: mulai dari bagian 0.**
**Task Spec:** `prompt/TASK-AUDI-R8-BODY-REFINING-AND-ASSEMBLY.md`
**Metode:** Blender 5.2 headless (`blender --background --python scratch/refine_car.py -- scratch/car_configs/audi_r8.json`: retopo + bake otomatis), Godot 4.7.2 untuk import, test, dan capture. Bodi Audi versi pertama (decimate langsung) sudah diganti oleh versi retopo; lihat bagian 7.

---

## 0. Ringkasan untuk Planner: Alur Kerja Pembuatan Aset Mobil

Bagian ini cukup untuk merencanakan 8 mobil berikutnya. Detail teknis dan riwayat pekerjaan ada di bagian 1 sampai 8.

### 0.1 Status akhir

| | Audi R8 LMS GT3 | Porsche 911 GT3 R |
| :--- | :--- | :--- |
| Sumber | Meshy (2 foto), 2,77 juta triangle | Tripo, 115 ribu triangle |
| Pipeline | `refine_car.py` (retopo + bake) | `refine_body.py` (mesh sudah bersih) |
| Triangle akhir | 103.580 | 115.560 |
| Tampil di game | warna asli (abu-abu muda, aksen merah), mengilap dan timbul | warna asli (biru, putih, oranye) |
| Dipakai oleh | tim id 1 (Neon Drift, 2 mobil) lewat `CHASSIS_BY_TEAM` | 9 tim lain (18 mobil) |
| Folder | `assets/cars/audi_r8/` | `assets/cars/porsche_911/` (struktur sama) |

Pengujian: `test_modular_car` 18 PASS, `test_audi_r8_chassis` 36 PASS, `test_audio_and_race_weekend` 35 assertion termasuk 9 suite lama, semuanya 0 failure (log di `scratch/audi/logs/final5_*.log`). Dari 10 mobil di `PRD/03` bagian 4.1, 2 sudah jadi, 8 belum dibuat.

### 0.2 Alur kerja per mobil

| # | Langkah | Alat | Keluaran | Waktu |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Siapkan foto (4 sisi) dan generate mesh | Meshy MCP (parameter di 0.3) | `assets/cars/<mobil>/raw/<mobil>_raw.glb` + tekstur | menit (kredit) |
| 2 | Periksa mesh mentah | `scratch/audi/mesh_quality.py` | angka kekasaran: edge terbuka, sudut antar-face | 1 menit |
| 3 | Buat config dari `scratch/car_configs/audi_r8.json`; arah depan dan sumbu roda `auto`; atur zona detail (splitter, diffuser) | edit JSON, lalu `refine_car.py ... --detect-only` untuk memeriksa deteksi | `scratch/car_configs/<mobil>.json` | 2 menit |
| 4 | Retopo + bake, uji dulu ke `temp/` | `blender --background --python scratch/refine_car.py -- scratch/car_configs/<mobil>.json --out-dir temp/<mobil>_trial` | body GLB, `base_color.png`, `normal.png`, `orm.png` | 3 sampai 6 menit |
| 5 | Lihat hasil uji, setel parameter bila perlu, lalu jalankan tanpa `--out-dir` | sama | aset terpasang di `assets/` | 3 sampai 6 menit |
| 6 | Aset utuh | `scratch/build_full_car.py -- <chassis.tscn> <out.glb>` | `<mobil>_full.glb` | 10 detik |
| 7 | Godot: salin `audi_r8_chassis.tscn` dan `audi_r8_toon_body.tres`, atur `keeps_original_paint`, tambah satu baris `CHASSIS_BY_TEAM`, salin `tests/test_audi_r8_chassis.gd`, impor lewat editor | editor Godot | scene, material, tes | sekitar 15 menit |
| 8 | Verifikasi | tes mobil + 3 suite di 0.1, `scratch/capture_audi_r8.gd` dan `capture_audi_r8_race.gd` | screenshot dan log | 5 menit (suite penuh sekitar 5 menit) |

Perbedaan dari alur lama: retopo dan bake kini otomatis (bukan kerja manual per mobil), sumbu roda tidak diukur manual, mesh di-weld sebelum diproses, tekstur AI di-bake ulang ke UV baru, dan selalu ada uji coba ke `temp/` sebelum menimpa aset. Waktu di atas adalah perkiraan dari dua mobil.

### 0.3 Parameter Meshy yang disarankan

Dari dokumentasi Meshy; belum diuji pada mobil (Audi dibuat dengan 2 foto).

| Parameter | Nilai | Alasan |
| :--- | :--- | :--- |
| `image_urls` | 4 foto: depan dulu, lalu belakang, kiri, kanan | Foto pertama dianggap tampak depan (Meshy 7.1). Audi hanya 2 foto, sisinya ditebak AI. |
| `ai_model` | `latest` (Meshy 7.1) | Syarat geometri 2k dan `texture_image_urls`. |
| `geometry_resolution` | `2k` | Detail sumber bake. Mesh mentah bisa lebih berat dari Audi; belum diukur. |
| `should_remesh` | `false` | Kualitas tertinggi; pipeline meretopo sendiri. |
| `should_texture`, `enable_pbr` | `true`, `true` | Roughness PBR di-bake menjadi `orm.png`. |
| `texture_resolution` | `4k` | Bake kita 4096 x 4096. Jangan `8k`. |
| `remove_lighting` | `true` | Buang highlight dan bayangan dari warna dasar. |
| `image_enhancement` | `false` (usulan, belum diuji) | Menjaga warna livery seperti foto. |
| `target_formats` | `["glb"]` | Lebih cepat. |

Foto: satu mobil, livery sama di semua foto, berdiri di atas keempat ban (deteksi sumbu memakai titik kontak ban), tanpa bayangan tanah, latar polos, tidak terpotong, sedikitnya 1024 px. Kredit untuk setelan 2k + 4k belum diperiksa.

### 0.4 Aturan baku yang sudah diputuskan

- **Warna asli:** semua mobil memakai tekstur aslinya (`ModularCarAssembler.keeps_original_paint = true`). Warna tim hanya di HUD, radar, papan waktu, dan podium. Konsekuensi: 18 Porsche berlivery sama, dibedakan lewat label nomor dan HUD.
- **Ukuran dan socket:** panjang 4,55 m, origin di tanah tengah wheelbase, sumbu roda di y 0,33, |x| 0,88; z socket diambil dari hasil deteksi (Audi +-1,338), bukan angka spec lama (+1,20 dan -1,25 tidak konsisten dengan wheelbase 2650 mm). Roda memakai `gt3_wheel_master.glb` yang sama untuk semua mobil.
- **Struktur folder:** `raw/` (tidak pernah diubah), `textures/`, `<mobil>_body.glb`, `<mobil>_full.glb`; scene `scenes/car/<mobil>_chassis.tscn`; material `materials/<mobil>_toon_body.tres`; tes `tests/test_<mobil>_chassis.gd`.
- **Impor Godot:** `*_body.glb` dengan `gltf/embedded_image_handling=0` (hemat memori video: Audi -43 MB, Porsche -160 MB terukur kasar), `*_full.glb` dan `raw` dengan nilai 2.
- **Shader:** bodi bertekstur memakai `toon_car_paint.gdshader` (mengilap, timbul, AO). Outline hull 0,02 m. Porsche masih memakai `anime_cel_shaded` dan bisa pindah dengan `orm.jpg` dan `normal.png`-nya.
- **Tidak ada file milik pengguna yang dihapus.** `raw/` selalu utuh; hasil turunan selalu bisa dibangun ulang dari skrip.

### 0.5 Syarat lulus per mobil (usulan)

| Pemeriksaan | Batas | Audi |
| :--- | :--- | :--- |
| Triangle bodi | 80.000 sampai 120.000 | 103.580 |
| Panjang, lebar | 4,55 m (+-0,02), sekitar 2,04 m (+-0,05) | 4,545 m, 2,062 m |
| Sisa geometri roda di lengkung | 0 vertex di dalam R 0,362 | 0 |
| Ban flush dengan bodi, menyentuh tanah | selisih < 2 cm, y ban < 1 cm | lulus |
| Mapping sasis per tim, warna asli | tes mobil lulus | 36 assertion lulus |
| Suite lama | 0 failure | 0 failure |
| Visual | showroom (3/4, samping, belakang, 4 roda) dan satu frame race world diperiksa | diperiksa |

Batas kekasaran mesh (edge > 30 derajat di bawah sekitar 10%) adalah usulan dari dua mobil (Audi 6,6%, Porsche 10,2%), belum dipakai sebagai gerbang otomatis.

### 0.6 Risiko dan pertanyaan terbuka untuk Planner

1. **Budget poligon:** `PRD/03` MOD-04 (bodi maksimal 20.000 tris) tidak tercapai; bodi sekarang 100 sampai 115 ribu. Bila 10 mobil memakai mesh seperti ini, 20 mobil di trek sekitar 2 juta tris. **FPS 20 mobil belum diukur.** Perlu keputusan: andalkan LOD otomatis Godot atau buat varian 30 sampai 40 ribu tris untuk mobil lawan.
2. **Pemetaan tim ke mobil:** baru tim id 1 (Neon Drift) = Audi, selebihnya Porsche. Urutan 8 mobil berikutnya dan tim yang memakainya belum ditentukan.
3. **Meshy:** parameter 2k, 4k, dan `image_enhancement=false` belum diuji; hasil dan kredit belum diketahui. Disarankan mobil ketiga dipakai sebagai uji dengan 4 foto.
4. **Deteksi sumbu roda** divalidasi hanya pada dua mobil (selisih sekitar 1 cm dari ukuran manual) dan mengandalkan mobil yang berdiri di atas ban.
5. **Kualitas Audi** masih dibatasi mesh AI: highlight kecil bergerigi di sudut bumper, atlas UV terpecah banyak pulau, putih asli tekstur hampir hilang saat bake (belum diselidiki).
6. **Offset VFX** di `scripts/vfx/race_vfx.gd` (roda, knalpot) masih khusus Porsche; selisih Audi belasan sentimeter, mobil dengan wheelbase berbeda berpotensi lebih jauh.
7. **Lingkungan kerja:** editor Godot yang terbuka mengimpor sendiri semua `.blend`, `.glb`, dan gambar di dalam proyek; `godot --headless --import` tidak mengimpor aset baru saat editor terbuka (pakai `scan` lewat godot-ai MCP); Blender sekali berhenti tanpa pesan saat memori penuh (run ulang normal).
8. **Porsche:** belum memakai shader mengilap dan timbul, dan belum melalui `refine_car.py` (tidak perlu karena mesh sudah bersih); perlu keputusan apakah dipindah agar seragam dengan Audi.

### 0.7 Peta file utama

| Fungsi | File |
| :--- | :--- |
| Pipeline bodi (retopo, bake) | `scratch/refine_car.py`, config `scratch/car_configs/<mobil>.json` |
| Aset utuh | `scratch/build_full_car.py` |
| Pratinjau GLB tanpa impor | `scratch/view_glb.gd` |
| Perbandingan sebelum/sesudah | `scratch/compare_audi_retopo.gd` |
| Pemilihan sasis per tim | `scripts/car/gt_car_actor.gd` (`CHASSIS_BY_TEAM`) |
| Kebijakan warna | `scripts/car/modular_car_assembler.gd` (`keeps_original_paint`) |
| Shader dan material | `shaders/toon_car_paint.gdshader`, `materials/audi_r8_toon_body.tres` |
| Tes | `tests/test_audi_r8_chassis.gd` (salin per mobil) |
| Standar lengkap dan daftar periksa | `docs/superpowers/specs/2026-10-22-audi-r8-gt3-prototype-pipeline.md` bagian 8 dan 9, `PRD/03-MODULAR-ASSET-PIPELINE.md` (MOD-05, MOD-06) |

---

## 1. Ringkasan Dimensi & Polycount (Sebelum / Sesudah)

| Metrik | Mentah (Meshy) | Akhir (`audi_r8_body.glb`) |
| :--- | :--- | :--- |
| Triangle | 2.771.448 | **103.580** (target 80k-120k) |
| Ukuran file | 85,4 MB | 5,8 MB (geometri + 2 tekstur JPEG tertanam); `textures/`: `base_color.png` 8,5 MB, `normal.png` 12,1 MB, `orm.png` 9,8 MB (semuanya 4096 x 4096) |
| Panjang (Z) | 1,903 m (sumbu X mentah) | **4,545 m** (AABB Godot) |
| Lebar (X) | 0,865 m | **2,062 m** (spec 2,04) |
| Tinggi dari tanah | 0,539 m | **1,269 m** (atap; spec 1,25. Bodi tanpa ban: y 0,077 .. 1,269) |
| Orientasi | depan = -X, atas = +Z (Blender) | depan = +Z, atas = +Y (Godot) |
| Origin | bukan di tanah | (0, 0, 0) di tanah, tengah wheelbase |
| Material slot | 1 (`Material_0`) | 2: `AudiR8_Paint`, `FenderLinerMat` (`#0A0A0A`, roughness 0,95) |

Rincian jumlah triangle: voxel remesh 10 mm menghasilkan 873.948 quad; collapse ke 118.000 triangle; pemotongan 4 roda menurunkannya ke 98.707 face; 4 inner tub menambah sekitar 5,9k. Skala seragam 2,3915 (dari panjang mentah agar panjang bodi 4,55 m; lebar dan tinggi mengikuti, tanpa distorsi; panjang akhir 4,547 m karena ujung bodi sedikit menyusut oleh smoothing).

Pengukuran sumbu roda (circle-fit pada busur bawah tapak ban, pada mesh yang sudah di-orient dan di-skala): sumbu depan y = -1,215, sumbu belakang y = +1,461, tinggi sumbu 0,350, jari-jari tapak 0,34 m. Wheelbase terukur **2,676 m** (R8 nyata 2,65 m). Bodi diturunkan 2 cm dan digeser agar sumbu roda jatuh di y = 0,33 dan origin tepat di tengah wheelbase, sehingga sumbu akhir berada di z = +-1,338.

---

## 2. Koordinat Socket Roda (`scenes/car/audi_r8_chassis.tscn`)

| Socket | X | Y | Z |
| :--- | :---: | :---: | :---: |
| `Socket_Wheel_FL` | -0,88 | 0,33 | **+1,338** |
| `Socket_Wheel_FR` | +0,88 | 0,33 | **+1,338** |
| `Socket_Wheel_RL` | -0,88 | 0,33 | **-1,338** |
| `Socket_Wheel_RR` | +0,88 | 0,33 | **-1,338** |
| `Socket_Cockpit` | 0,00 | 0,72 | 0,05 |

Verifikasi flush stance (`scratch/audi/check_fit.gd`, ban `GT3_TireRubber` dalam ruang chassis): sisi luar ban pada |x| = 1,021, bodi terlebar 1,031; dasar ban pada y = 0,000 (menyentuh tanah); radius ban 0,33 m terhadap bukaan lengkung 0,372 m (celah 4,2 cm).

---

## 3. Pekerjaan Blender (`scratch/refine_car.py` dan `scratch/car_configs/audi_r8.json`)

Skrip berbasis config (satu file JSON per mobil), dijalankan sekitar 3 sampai 6 menit (sebagian besar bake AO). `scratch/refine_audi_r8.py` adalah jalur versi pertama (decimate langsung) dan tidak lagi dipakai untuk aset yang dikirim.

1. **Deteksi otomatis, weld, orient, skala, tanah:** arah depan dan sumbu roda dideteksi dari mesh mentah (bagian 8.1), mesh di-weld (tertutup rapat, 0 edge terbuka), diputar agar depan = +Z Godot, diskala seragam ke 4,55 m, titik terendah ke z = 0, lalu diturunkan agar sumbu roda di 0,33.
2. **Retopo:** voxel remesh 10 mm (OpenVDB), Corrective Smooth 40 iterasi, Decimate Collapse ke 118 ribu triangle. **Zona detail** (splitter depan dan diffuser belakang, margin 12 cm) tidak di-smooth dan diutamakan saat collapse lewat vertex group berbobot, sehingga bilah splitter dan sirip diffuser tidak meleleh.
3. **Pembersihan roda baked:** empat silinder cutter (R = 0,372, |x| 0,50 .. 1,35), modifier `BOOLEAN` solver `EXACT`. Ban, pelek, cakram, dan kaliper terbuang.
4. **Lip warp:** per arah di sekitar tiap sumbu roda diukur radius lip alami (0,372 .. 0,47 m), lalu vertex di sekitar lip digeser radial sehingga tepi bukaan jatuh tepat di lingkaran R = 0,372 dan dilebur halus ke flare spakbor (jarak 7 cm), tidak pernah masuk ke dalam lingkaran roda.
5. **Inner fender tub:** dinding setengah-pipa melengkung (R 0,369, 7 cincin, segmen maksimal 5 derajat) dengan `FenderLinerMat`, mulai di tepi bibir yang diukur dari geometri, dasar dijepit z >= 0,10, dinding dalam disc penuh di |x| = 0,65, arah normal diperiksa per face.
6. **Normal toon:** normal shading cat diganti normal salinan yang di-smooth 30 iterasi (dicampur kembali ke normal asli di tepi tajam). Geometri tidak berubah; hasilnya pita cel yang koheren (bagian 8.3).
7. **UV dan bake dari mesh mentah 2,77 juta triangle** (Smart UV Project pada bagian cat; Cycles CPU, 4096 x 4096): `base_color.png` (setelah bercak gelap tekstur dibersihkan, bagian 8.2), `normal.png` (normal tangent), dan `orm.png` (R = ambient occlusion, G = roughness).
8. **Export** GLB (`export_yup`, tekstur JPEG tertanam) ke `assets/cars/audi_r8/audi_r8_body.glb`. Nama mesh `AudiR8_Body` dipertahankan agar path node di scene chassis tetap sama.
9. **Aset utuh:** `scratch/build_full_car.py` merakit bodi + 4 roda master (mesh roda dipakai bersama) di posisi socket yang dibaca dari `scenes/car/audi_r8_chassis.tscn`, roda kiri diputar setengah putaran seperti `ModularCarAssembler.attach_wheel`, lalu mengekspor `assets/cars/audi_r8/audi_r8_full.glb` (8,3 MB, 37 objek, tekstur tertanam).

### Penyimpangan dari spec (disengaja, perlu diketahui)

| Spec | Yang dibuat | Alasan |
| :--- | :--- | :--- |
| Socket Z = +1,20 / -1,25, |x| 0,88 | Z = **+-1,338**, |x| 0,88 | Z dari spec tidak cocok dengan geometri hasil Meshy, dan tidak konsisten dengan wheelbase 2650 mm yang disebut spec yang sama (1,20 + 1,25 = 2,45 m). Nilai di atas hasil ukur circle-fit (wheelbase 2,676 m). |
| Tub setengah-pipa 300 derajat, R 0,372 | R **0,369** (inset 3 mm), busur mengikuti sisi bodi yang punya kulit plus taper 25 derajat | Kulit R8 berakhir di bawah sumbu; tub 300 derajat penuh menonjol keluar bodi sebagai tabung. Inset 3 mm mencegah z-fighting dengan sisa dinding lama di belakang tub. |
| Outline hull 0,02 m | **0,02 m**, `#050505` (sesuai spec) | Pada bodi versi pertama (decimate langsung) 0,02 m membuat serpihan geometri menjadi goresan hitam, sehingga sempat diturunkan ke 0,012 m. Setelah retopo kontur 0,02 m bersih, jadi dikembalikan ke nilai spec. Satu parameter di `materials/audi_r8_toon_body.tres` (`outline_width`). |
| Tinggi 1,25 m | 1,269 m | Atap dari mesh Meshy; skala seragam menjaga proporsi. |
| Tub setengah-pipa mengikuti lip alami | Lip ditarik ke lingkaran R 0,372 (lip warp) | Lip alami mesh AI bergelombang (radius 0,372 sampai 0,515 m). |
| `shaders/toon_car_paint.gdshader` | dibuat baru | Shader dengan nama itu belum ada di proyek (yang ada `anime_cel_shaded.gdshader`). |
| Team 1 "Neon Drift / Ironclad" | Team id 1 = **Neon Drift** | Tidak ada tim "Ironclad" di `GtData.TEAM_NAMES`; `team_name` scene diisi "Neon Drift". |

---

## 4. Pekerjaan Godot

- **`shaders/toon_car_paint.gdshader`:** cel-shaded 2 langkah dengan uniform yang sama seperti `anime_cel_shaded.gdshader` (jadi `base_color` tetap bisa dipakai untuk tint), ditambah shine (pita specular clear-coat dari roughness bake), emboss (normal map hanya untuk highlight dan rim; pita diffuse memakai normal geometri), dan AO bake (`orm_texture`). Detail di bagian 8.3.
- **`materials/audi_r8_toon_body.tres`:** albedo `base_color.png`, normal `normal.png`, `orm.png` (hasil bake retopo di `assets/cars/audi_r8/textures/`, 4096 x 4096, impor VRAM compressed + mipmap, normal map ditandai), parameter `normal_strength` 0,6, `ao_strength` 0,5, `gloss_strength` 0,6, `spec_size` 0,992, `next_pass` `inverted_hull_outline.gdshader` (0,02 m, `#050505`).
- **Impor `*_body.glb` (Audi dan Porsche):** `gltf/embedded_image_handling=0` (buang tekstur tertanam; material toon sudah memakai `textures/`). Terukur lewat selisih `RENDERING_INFO_VIDEO_MEM_USED` saat satu scene chassis dimuat: Audi 206 MB menjadi 163 MB (-43 MB, tepat dua tekstur 4096 x 4096 terkompresi), Porsche 208 MB menjadi 48 MB (-160 MB). Selisih Porsche lebih besar dari 3 tekstur (sekitar 64 MB) karena pengukuran ikut menangkap overhead unggah GPU satu kali (sekitar 125 MB) yang muncul saat tekstur normal 4096 x 4096 pertama dimuat; satu tekstur terkompresi sendiri 10,7 MB (warna) atau 21,4 MB (normal). Angka kasar (satu proses, tanpa pengulangan).
- **`scenes/car/audi_r8_chassis.tscn`:** root `ModularCarAssembler` (`car_name` "Audi R8 LMS GT3 Evo II"), `BodyShell/AudiBody` memuat GLB (surface 0 = toon Audi, surface 1 = `toon_carbon_aero.tres`), `Sockets` 4 roda + cockpit seperti tabel di atas.
- **`scripts/car/gt_car_actor.gd`:** konstanta `CHASSIS_BY_TEAM = {1: audi_r8_chassis.tscn}` dan `BASE_CHASSIS`. `bind()` memanggil `_use_chassis_for(team_id)` sebelum roda dan livery dipasang; node `Chassis` ditukar dengan mempertahankan transform putaran setengah, tim lain tetap memakai `base_chassis.tscn`. `_apply_livery` dilewati bila `chassis.keeps_original_paint` true.
- **`scripts/car/modular_car_assembler.gd`:** satu properti baru `@export var keeps_original_paint: bool = false`. `scenes/car/audi_r8_chassis.tscn` dan (sejak tambahan di bagian 6) `scenes/car/base_chassis.tscn` menyetelnya true, jadi **warna semua mobil di game mengikuti warna tekstur aslinya**: Audi abu-abu muda dengan aksen merah, Porsche biru-putih-oranye; tidak ada lagi tint warna tim pada bodi.
- **`tests/test_audi_r8_chassis.gd` (baru, 36 assertion):** socket, dimensi bodi, jumlah triangle, tidak ada geometri roda tersisa di 4 lengkung, ban flush dan menyentuh tanah, mapping chassis per tim di race world (hanya 2 mobil Neon Drift yang memakai Audi), kebijakan warna (20 mobil, Audi dan Porsche, tanpa tint), dan chassis yang memilih `keeps_original_paint = false` tetap bertint. Uji mutasi: dengan `_use_chassis_for` dinonaktifkan 3 assertion gagal; dengan aturan cat asli dinonaktifkan 1 assertion gagal; setelah dipulihkan semua lulus.

---

## 5. Verifikasi

### 5.1 Screenshot Godot (render d3d12, 1920 x 1055)

| Tampilan | File |
| :--- | :--- |
| 3/4 depan (grille, lampu, pelek, kaliper kuning) | `executor-report/phase-7-audi-showroom.png` (`scratch/audi_r8_showroom.png`) |
| Samping kiri (flush stance) | `executor-report/phase-7-audi-left-side.png` |
| Belakang (diffuser, sayap) | `executor-report/phase-7-audi-rear.png` |
| Close-up roda depan-kanan / belakang-kanan | `executor-report/phase-7-audi-wheel-front-right.png`, `phase-7-audi-wheel-rear-right.png` |
| Di race world (warna asli, tanpa tint tim) | `executor-report/phase-7-audi-race-world.png`, `phase-7-audi-race-world-rear.png` |
| Aset utuh `audi_r8_full.glb` dibuka langsung (tanpa impor), warna asli | `executor-report/phase-7-audi-full-asset.png` |
| Sebelum (kiri) dan sesudah retopo (kanan): 3/4 depan, lip spakbor, splitter | `executor-report/phase-7-audi-retopo-before-after-3q.png`, `phase-7-audi-retopo-before-after-arch.png`, `phase-7-audi-retopo-before-after-splitter.png` |
| Porsche 911 dengan warna asli: showroom dan race world | `executor-report/phase-7-porsche-showroom-original-paint.png`, `phase-7-porsche-race-world.png` (script `scratch/capture_porsche_911.gd`, `scratch/capture_porsche_911_race.gd`) |

Semua 4 close-up roda ada di `scratch/audi_r8_{fl,fr,rl,rr}_close.png`. Script: `scratch/capture_audi_r8.gd`, `scratch/capture_audi_r8_race.gd`.

### 5.2 Log pengujian

Dijalankan setelah semua perubahan (log mentah di `scratch/audi/logs/final5_*.log`, dijalankan ulang setelah penyempurnaan (bagian 8); baseline sebelum perubahan di `baseline_*.log`, hasilnya sama):

```powershell
& "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_modular_car.gd
& "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_audi_r8_chassis.gd
& "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_audio_and_race_weekend.gd
```

| Suite | Hasil |
| :--- | :--- |
| `test_modular_car.gd` | 18 PASS, 0 FAIL: `GT3 MASTER WHEELS & PIT STOP PIPELINE ACCEPTANCE: PASS` |
| `test_audi_r8_chassis.gd` (baru) | 36 PASS, 0 FAIL: `FASE 7 AUDI R8 CHASSIS: PASS` |
| `test_audio_and_race_weekend.gd` | 35 assertion, 0 failure: `FASE 6 ACCEPTANCE: PASS` |

`test_audio_and_race_weekend.gd` (#20) menjalankan 9 suite lama sebagai subproses, semuanya tanpa regresi:

```text
test_modular_car OK (18 PASS, 0 FAIL, 0 s)
test_simulation_verification OK (43 PASS, 0 FAIL, 4 s)
test_pit_wall OK (26 PASS, 0 FAIL, 7 s)
test_weather_and_ai OK (43 PASS, 0 FAIL, 18 s)
test_race_world OK (65 PASS, 0 FAIL, 65 s)
test_gt_sim OK (43 PASS, 0 FAIL, 41 s)
test_car_dynamics_vfx OK (18 PASS, 0 FAIL, 1 s)
test_race_hud OK (31 PASS, 0 FAIL, 2 s)
test_race_weekend_and_physics OK (30 PASS, 0 FAIL, 24 s)
```

Catatan jumlah: brief menyebut "10 unit test"; yang ada di repo adalah 2 file yang disebut (18 + 35 assertion) ditambah 9 suite lama di dalam #20 dan 1 suite baru. Semua lulus.

### 5.3 Pemeriksaan lain

- `scratch/audi/inspect_audi.gd`: GLB menjadi `audi_r8_body (Node3D) / AudiR8_Body (MeshInstance3D)`; AABB bodi (retopo) ukuran (2,062, 1,192, 4,547), y 0,077 .. 1,269.
- Pratinjau Blender per sudut ada di `scratch/audi/renders/` dan `scratch/audi/views/`.

### 5.4 Batasan & catatan

- Mesh sumber adalah rekonstruksi AI. Setelah retopo permukaan jauh lebih halus dan lip spakbor bulat, tetapi detail halus melunak (sirip diffuser belakang, ventilasi) dan ada noda gelap di tekstur Meshy yang ikut ter-bake (terlihat sebagai bercak abu-abu gelap di pintu). Zona detail baru diterapkan pada splitter depan; diffuser belakang bisa memakai mekanisme yang sama (satu entri di `scratch/car_configs/audi_r8.json`).
- Normal map hampir tidak terlihat pada lighting 2 langkah (diuji kekuatan 0, 0,3, dan 0,8, hasil nyaris sama). Tetap dipasang sesuai spec.
- `scripts/vfx/race_vfx.gd` masih memuat offset roda dan knalpot tetap untuk Porsche (sumbu sekitar +-1,26 m, knalpot 2,3 m). Pada Audi (sumbu +-1,338 m) selisihnya belasan sentimeter, tidak diubah karena di luar spec.
- Seperti Porsche, kaliper statis berada di sisi belakang pada roda kanan dan di sisi depan pada roda kiri (assembler memutar roda kiri 180 derajat).
- Tool MCP `blender` tidak dipakai; seluruh proses Blender lewat CLI headless. `godot --headless --import` tidak mengimpor aset baru di mesin ini karena ada editor Godot yang terbuka; impor dijalankan editor lewat `filesystem_manage scan` (godot-ai MCP).
- Editor yang terbuka juga otomatis mengimpor file `.blend` dan `.glb` yang diletakkan di proyek. File antara milik saya di `scratch/audi/` sudah dihapus beserta file `.import` dan tekstur ekstraksinya.

### 5.4a Tentang "warna texture hilang" pada `raw/audi_r8_raw.glb`

- File mentah **tidak berubah**: 89.542.124 byte, waktu ubah 10:12 (sebelum pekerjaan FASE 7 dimulai), dan hanya dibaca. Materialnya masih memiliki `baseColorTexture`, `metallicRoughnessTexture`, dan `normalTexture` (3 JPEG tertanam), dan saat dimuat langsung di Godot tampil berwarna benar: bodi abu-abu muda, aksen merah, pelek perak (`scratch/audi/views/raw_in_godot_sky.png`). Kehilangan warna pada file ini tidak bisa direproduksi.
- Tempat warna benar-benar hilang ada tiga, semuanya sudah diperbaiki: (1) `audi_r8_body.glb` versi pertama diekspor tanpa tekstur, jadi polos saat dibuka sendiri; sekarang tekstur tertanam. (2) Di game, `GtCarActor` mewarnai bodi dengan warna tim (cyan untuk Neon Drift); sekarang dilewati untuk Audi lewat `keeps_original_paint`. (3) Folder `raw/` saya sembunyikan dari Godot dengan `.gdignore` agar GLB 85 MB tidak ikut diimpor, sehingga tidak muncul di dock FileSystem; `.gdignore` sudah dihapus dan diganti `raw/audi_r8_raw.glb.import` dengan pengaturan ringan (tanpa LOD, shadow mesh, tangent) supaya file bisa dilihat di editor tanpa impor berat.
- Bila warna hilang terlihat di viewer lain, sebutkan viewer-nya; GLB memakai material PBR standar glTF (`metallicFactor` 1,0 dengan peta metallic), yang tampak gelap di viewer tanpa environment map.

### 5.5 File baru / berubah

- Aset: `assets/cars/audi_r8/audi_r8_body.glb` (tekstur tertanam), `assets/cars/audi_r8/audi_r8_full.glb` (bodi + 4 roda master, aset utuh), `assets/cars/audi_r8/textures/{base_color,normal,orm}.png` (hasil bake retopo 4096 x 4096; tekstur asli Meshy tetap di `raw/audi_r8_raw_textures/`), `assets/cars/audi_r8/raw/audi_r8_raw.glb.import` (impor ringan; berkas mentah tidak diubah). Versi bodi sebelum retopo disimpan di `temp/audi_r8_before_retopo/`.
- Shader dan material: `shaders/toon_car_paint.gdshader`, `materials/audi_r8_toon_body.tres`.
- Scene dan script: `scenes/car/audi_r8_chassis.tscn`, `scripts/car/gt_car_actor.gd` dan `scripts/car/modular_car_assembler.gd` (diubah), `tests/test_audi_r8_chassis.gd`.
- Dokumentasi (standar untuk semua mobil): `docs/superpowers/specs/2026-10-22-audi-r8-gt3-prototype-pipeline.md` bagian 8-9, `PRD/03-MODULAR-ASSET-PIPELINE.md` (MOD-05, MOD-06, struktur direktori). Keduanya sudah diperbarui untuk keputusan Porsche di bagian 6.
- Tooling: `scratch/refine_car.py` + `scratch/car_configs/audi_r8.json` (reproduksi: `blender --background --python scratch/refine_car.py -- scratch/car_configs/audi_r8.json [--out-dir <dir>] [--detect-only]`; `scratch/car_configs/porsche_911.json` dipakai untuk menguji deteksi sumbu; `scratch/refine_audi_r8.py` adalah jalur versi pertama), `scratch/retopo_audi_r8.py` (eksperimen retopo awal), `scratch/compare_audi_retopo.gd` (perbandingan sebelum/sesudah), `scratch/build_full_car.py` (umum untuk semua mobil: `blender --background --python scratch/build_full_car.py -- <chassis.tscn> <out.glb>`), `scratch/view_glb.gd` (pratinjau GLB tanpa impor), `scratch/capture_audi_r8.gd`, `scratch/capture_audi_r8_race.gd`, `scratch/capture_porsche_911.gd`, `scratch/capture_porsche_911_race.gd`, `scratch/tidy_porsche_folder.sh`, skrip analisis di `scratch/audi/`.

---

## 6. Tambahan: Porsche ke Warna Asli & Perapihan `assets/cars/porsche_911`

### 6.1 Warna asli untuk Porsche

`scenes/car/base_chassis.tscn` menyetel `keeps_original_paint = true` (satu baris). Semua 20 mobil sekarang tampil dengan warna tekstur aslinya: 2 Audi abu-abu muda dengan aksen merah, 18 Porsche dengan livery biru-putih-oranye. Warna tim tetap dipakai di HUD, radar, papan waktu, dan podium (tidak diubah).

Konsekuensi yang terlihat: 18 Porsche di trek kini berlivery sama, jadi dibedakan lewat label nomor/pembalap di atas mobil dan HUD, tidak lagi lewat warna bodi. Bila ingin tetap membedakannya di trek, `keeps_original_paint = false` pada chassis tertentu mengembalikan tint tim (jalurnya masih ada dan diuji).

### 6.2 Perapihan folder (tanpa ada file yang dihapus)

Sebelum: bodi, 3 tekstur ber-UUID, dan semua file `.import` bercampur di satu folder. Sesudah:

```text
assets/cars/porsche_911/
├── raw/porsche_911_raw.glb (+ .import)     # salinan bodi Tripo sebelum refine_body.py
├── textures/base_color.jpg, normal.png, orm.jpg (+ .import)
├── porsche_911_body.glb (+ .import)        # tidak diubah isinya, namanya, maupun lokasinya
└── porsche_911_full.glb (+ .import)        # baru: bodi + 4 roda master di posisi socket, 13,1 MB
```

| Dipindah dari (folder `porsche_911/`) | Ke |
| :--- | :--- |
| `porsche_911_body_Color_caa06e4e-d9f7-4654-9f18-f144def4be58.jpg` (+ `.import`) | `textures/base_color.jpg` |
| `porsche_911_body_NormalGL_caa06e4e-d9f7-4654-9f18-f144def4be58.png` (+ `.import`) | `textures/normal.png` |
| `porsche_911_body_ORM_caa06e4e-d9f7-4654-9f18-f144def4be58.jpg` (+ `.import`) | `textures/orm.jpg` |

- UID ketiga tekstur dan setelan impornya (VRAM compressed, mipmap, normal map) dipertahankan; Godot membuat ulang cache-nya di lokasi baru. Isi file gambar tidak diubah.
- `raw/porsche_911_raw.glb` adalah **salinan** `scratch/backup_wheel_refine/porsche_911_body.orig.glb`; file asli di `scratch/` tidak disentuh. Tanpa file ini `refine_body.py` tidak punya masukan di folder mobil.
- `porsche_911_body.glb.import`: `gltf/embedded_image_handling` 1 menjadi 2, lalu 0 (lihat bagian 4 dan 7). Dengan nilai 1 setiap impor ulang mengekstrak lagi tiga tekstur ber-UUID ke folder bodi, yaitu kekacauan yang dirapikan di sini.
- Referensi yang diperbarui: `materials/porsche_toon_body.tres` (path `base_color.jpg`). `base_chassis.tscn`, skrip `scratch/`, dan dokumen `prompt/` memakai path `porsche_911_body.glb` yang tidak berubah, jadi tetap valid.
- Skrip pemindahan: `scratch/tidy_porsche_folder.sh` (hanya `mv` dan `cp`, tanpa `rm`).
- Cache `.godot/imported` masih menyimpan entri dengan nama lama; itu cache Godot yang bisa dibuat ulang dan tidak saya hapus.

Catatan: dengan mode 2 hasil impor `porsche_911_body.glb` naik dari 3,4 MB menjadi 34,8 MB karena tiga tekstur 4096 x 4096 tertanam, dan tekstur warna dimuat dua kali (material toon dan material GLB). Itu sudah diukur dan diperbaiki dengan mode 0 (bagian 4: memori video chassis Porsche turun dari 208 MB ke 48 MB, hasil impor kembali 3,4 MB). GLB tetap berisi tekstur saat dibuka di luar Godot.

### 6.3 Verifikasi

`porsche_911_body.glb` dimuat ulang oleh editor (reimport) setelah perubahan; sebelum itu cache lama menunjuk ke tekstur yang sudah dipindah dan bodi gagal dimuat, lalu pulih setelah reimport. Tes warna (20 mobil tanpa tint) lulus, dan frame race world serta showroom Porsche memperlihatkan livery aslinya (lihat 5.1). Hasil suite lengkap ada di 5.2.

---

## 7. Tambahan: Retopo + Bake Dipasang ke Audi, Lip dan Splitter Dirapikan

### 7.1 Kenapa

Pengukuran (`scratch/audi/mesh_quality.py`) menunjukkan bodi Audi versi pertama jauh lebih kasar dari Porsche, dan penyebab utamanya ada di pipeline sendiri: mesh mentah Meshy tertutup rapat setelah di-weld (0 edge terbuka), tetapi decimate saya berjalan sebelum weld sehingga seam UV robek (67.207 edge terbuka). Itu terlihat sebagai retakan dan goresan hitam, diperparah outline hull. Tekstur asli Meshy juga hanya 2048 x 2048 dan berisik (4,8 sampai 5,9 bit per piksel, Porsche 0,9 sampai 1,75).

### 7.2 Hasil (`temp/audi_r8_retopo/` untuk eksperimen awal, `temp/audi_r8_before_retopo/` untuk versi lama)

| | Audi sebelum | Audi retopo (terpasang) | Porsche |
| :--- | :--- | :--- | :--- |
| Triangle | 101.394 | 103.580 | 115.560 |
| Edge terbuka | 67.207 | 756 (tepi tub) | 1.032 |
| Edge > 30 derajat | 31% | 6,8% | 10% |
| Tekstur | 2048 x 2048 asli Meshy | 4096 x 4096 hasil bake | 4096 x 4096 |

Lip spakbor: lip alami mesh AI berkisar 0,372 sampai 0,515 m dari sumbu; lip warp menariknya ke lingkaran R 0,372 dan melebur ke flare, jadi bukaan bulat tanpa serpihan. Splitter depan: zona detail membuat bilah dan plat splitter tetap terbaca (tanpa itu smoothing 40 iterasi melelehkannya). Perbandingan kiri (sebelum) dan kanan (sesudah): `executor-report/phase-7-audi-retopo-before-after-*.png`.

### 7.3 Alur kerja mobil berikutnya

Alur lengkap, tabel waktu, dan cara menghindari retopo ulang ada di `docs/superpowers/specs/2026-10-22-audi-r8-gt3-prototype-pipeline.md` bagian 9.9. Ringkasnya: satu file config per mobil (`scratch/car_configs/<car>.json`) dan satu perintah `refine_car.py` (sekitar 3 sampai 6 menit) menggantikan retopo manual; `build_full_car.py` membuat aset utuh; livery lain untuk mobil yang sama cukup bake ulang warna karena UV tetap.

### 7.4 Batasan

- Detail halus lain (ventilasi samping) masih melunak; zona detail dipasang untuk splitter dan diffuser (bagian 8).
- Noda gelap tekstur Meshy ikut ter-bake (bercak di pintu).
- Quadriflow tidak menghasilkan apa-apa pada mesh ini, jadi hasilnya triangle seragam, bukan quad.
- Sumbu roda kini terdeteksi otomatis dari ban (bagian 8.1).
- Jalur tuning outline dan normal map tidak diubah: outline 0,02 m (spec), normal map hasil bake tetap tipis efeknya di toon.

---

## 8. Penyempurnaan: Sumbu Roda Otomatis, Diffuser, Tekstur Bersih, Mengilap dan Timbul

### 8.1 Sumbu roda otomatis (tidak perlu ukur manual per mobil)

Rongga spakbor tiap mobil memang berbeda, tetapi ban baked selalu bulat dan menyentuh tanah, jadi sumbu roda dideteksi dari ban, bukan dari rongga (`"raw_axle": "auto"`, `"front_axis_raw": "auto"`):

1. **Arah depan:** sumbu horizontal terpanjang; hidung = ujung yang lebih rendah (kap mesin, bukan penutup mesin dan sayap).
2. **Sumbu y:** titik kontak ban (vertex terendah tiap setengah mobil, pita |x| 0,55 .. 1,15); pusat patch kontak ban bulat = sumbu roda.
3. **Tinggi sumbu:** pencarian lingkaran tapak dengan pusat di z = radius, lalu fit lingkaran kuadrat terkecil pada busur bawah.
4. **Rongga spakbor yang berbeda** ditangani oleh lip warp, yang mengukur radius lip alami per derajat di sekitar sumbu hasil deteksi.

Validasi terhadap ukuran manual sebelumnya (`--detect-only`, 1 sampai 6 detik):

| Mobil | Besaran | Otomatis | Ukuran manual / nilai lama |
| :--- | :--- | :---: | :---: |
| Audi R8 (Meshy) | arah depan | -X (otomatis) | -X |
| | sumbu depan y | -1,216 | -1,215 |
| | sumbu belakang y | 1,451 | 1,461 |
| | tinggi sumbu | 0,350 | 0,350 |
| Porsche 911 (Tripo) | arah depan | -Y (otomatis) | -Y |
| | sumbu depan y | -1,190 | -1,19 |
| | sumbu belakang y | 1,260 | 1,261 |

Selisih sekitar 1 cm. Batasan: mengandalkan ban baked yang menyentuh tanah; bila mesh tidak berdiri di atas ban, deteksi gagal dengan pesan jelas dan `raw_axle` bisa diisi manual di config. Hanya dua mobil yang diuji.

### 8.2 Diffuser dan tekstur

- **Diffuser belakang:** zona detail kedua (kotak y > 1,78, z < 0,45, margin 12 cm) seperti splitter.
- **Bercak gelap di pintu:** penelusuran menunjukkan bahwa bercak itu **bukan** dari tekstur mentah (sampel sepanjang pintu: abu-abu cat merata 0,49 sampai 0,53, hanya ada dekal merah) dan bukan dari bayangan atau AO (tetap ada saat bayangan dan AO dimatikan). Penyebabnya pita cel pada normal geometri yang bergelombang (bagian 8.3). Pembersih tekstur (`texture_clean`) tetap dipasang untuk bercak abu-abu gelap berukuran besar di mesh lain: sekitar 3,5% piksel Audi diratakan ke luminansi cat 0,515; logo, merah, dan hitam tidak disentuh.
- **Putih hilang saat bake:** piksel putih asli (sekitar 3,8% area UV mentah) hampir tidak muncul di tekstur hasil bake (0,03%); hanya kontur lampu yang tampak putih karena specular. Belum diselidiki sumbernya (kemungkinan kaca atau interior yang tidak terlihat dari luar).

### 8.3 Mengilap (shine) dan timbul (emboss)

`shaders/toon_car_paint.gdshader` mendapat tiga hal baru, semuanya dibaca dari `textures/orm.png` dan `normal.png`:

- **Shine:** pita highlight clear-coat keras; kekuatannya dari roughness hasil bake (`gloss_strength` 0,6, `spec_size` 0,992).
- **Emboss:** normal map hasil bake membentuk highlight dan rim light saja (`normal_strength` 0,6). Pita cel diffuse memakai normal geometri yang di-smooth (`toon_normals`, 30 iterasi), sehingga garis panel dan ventilasi tampak timbul tanpa membuat pita cel menjadi bercak. `ao_strength` 0,5 menggelapkan celah dari AO bake.
- **Pita cel koheren:** bercak gelap di pintu hilang setelah normal toon (sebelumnya pintu berada tepat di ambang `shadow_threshold` 0,48 pada cahaya showroom sehingga riak milimeter membalik pita).

Mengapa Porsche tampak mengilap dan timbul: material toon-nya (`anime_cel_shaded`) **tidak punya specular maupun normal map** (`light()` hanya menulis `DIFFUSE_LIGHT`), jadi kesan itu bukan dari material. Penyebabnya (a) atlas tekstur Tripo berisi pulau warna datar jenuh dengan tepi tajam dan pantulan yang sudah tergambar, (b) geometri bersih (median sudut antar-face 4 derajat) dengan lampu, ventilasi, dan louver yang benar-benar dimodelkan, sehingga pita cel dan outline hull mengikuti relief nyata. Audi kini mendapat shine dan emboss dari shader dan bake; Porsche tidak diubah (bisa pindah ke `toon_car_paint` dengan `orm.jpg` dan `normal.png`-nya, yang sudah berformat sama).

### 8.4 Hasil

| | Audi (retopo v2) | Audi (final) |
| :--- | :--- | :--- |
| Triangle | 104.626 | 103.580 |
| Edge terbuka | 756 | 789 (tepi tub) |
| Tekstur di `textures/` | `base_color.png`, `normal.png` | + `orm.png` (AO dan roughness) |
| Diffuser, splitter | splitter terlindung | splitter dan diffuser terlindung |
| Bercak gelap di pintu | ada | hilang |
| Shine dan emboss | tidak ada | ada |
| Sumbu roda | ukuran manual | deteksi otomatis |

### 8.5 Batasan

- Highlight shine di sudut bumper depan masih bergerigi kecil (normal map hasil bake dari mesh AI yang bergelombang); `normal_strength` dan `gloss_strength` di `materials/audi_r8_toon_body.tres` bisa diturunkan bila mengganggu.
- Atlas UV (Smart UV Project) memecah mesh jadi ratusan pulau kecil di bagian bawah dan lengkung roda; panel utama tetap besar tetapi packing tidak efisien.
- Sekali dari tiga run penuh, Blender berhenti tanpa pesan error tepat setelah voxel remesh (kemungkinan tekanan memori saat Godot dan Blender berjalan bersamaan); run ulang selesai normal.
- Deteksi sumbu roda hanya divalidasi pada Audi dan Porsche.
- Run `refine_car.py` penuh sekarang 3 sampai 6 menit (AO 24 sampel); mengurangi sampel AO atau resolusi mempercepatnya.
