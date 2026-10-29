# SPESIFIKASI DESAIN: FASE 13.3 — BRIANZA: KONTINUITAS TERRAIN, PIT LANE & ISI PADDOCK (LAYOUT-DRIVEN REUSE)

**Tanggal:** 28 Oktober 2026 · **Status:** Draft, menunggu persetujuan developer · **Peran penulis:** Planner (tidak mengubah kode produksi)
**Sirkuit:** `brianza` (Autodromo di Brianza, Round 03) · **Branch usulan:** `fase-13-3-brianza-civil-pit-paddock-polish` (dari `main`)
**Dokumen terkait:** `Circuit-Environment-Component-Guide.md` v2.0 · `docs/AGENT-WORKFLOW.md` · `executor-report/reports/FASE-13-2-BRIANZA-POLISH-REPORT.md` · `docs/superpowers/specs/2026-10-28-fase-13-1-brianza-environment-overhaul-design.md`

---

## 1. Maksud dan prinsip arahan developer

Developer meminta polishing environment Brianza dan review alur kerja pembuatan map. Arahan developer (28 Oktober 2026), menjadi prinsip mengikat untuk fase ini dan sirkuit berikutnya:

1. Environment **boleh reusable**.
2. **Bentuk dan layout harus menyesuaikan layout track**, lalu diimprovisasi agar logis.
3. Jika suatu environment (termasuk komponen bersama) **kurang baik, perbaiki**, jangan dipertahankan demi konsistensi.

Aturan turunan:

- **R1.** Komponen bersama tidak boleh membaca konstanta milik sirkuit lain. Layout masuk sebagai parameter. Kontrak yang sudah ada dipakai ulang: dictionary `pit_layout` (lihat `GtRace.default_pit_layout()` dan `BrianzaPitComplex.sim_layout()`), yang sudah menjadi sumber tunggal untuk simulasi.
- **R2.** Penempatan ditentukan dari data track (arc `s`, kelengkungan, jarak ke ruas jalan lain, elevasi), bukan angka tetap yang disalin dari sirkuit lain.
- **R3.** Memperbaiki komponen bersama (Tier A) diizinkan, dengan syarat test Apex Ring dan Neo Wangan tetap hijau dan perilaku Apex tidak berubah.

## 2. Diagnosis (terukur, bukan dugaan)

Bukti: probe headless `temp/probe_brianza_overlap.gd`, `temp/probe_pit_armco.gd` dan 10 screenshot diagnosis `temp/diag/*.png` (gitignored; dihasilkan ulang oleh `temp/capture_polish_diag.gd`).

### 2.1 Rumput menutupi track di akhir Sektor 2 menuju Sektor 3
- `ParcoRealeOuterFloor` (`scripts/world/circuits/brianza/brianza_environment.gd:472-480`) adalah plane datar di y = `-GROUND_DROP_M - 0.6` = **-3,0 m**. Jalan turun sampai **-7,2 m** (`ELEVATION` di `brianza_circuit_builder.gd`; s = 3860 berada di y = -4,35 m).
- Dari tabel elevasi, jalan berada di bawah plane pada s ≈ 3260 sampai 4030 (perkiraan; wajib diverifikasi oleh test). Plane hanya satu sisi: tidak terlihat dari bawah, menutup jalan dan mobil dari kamera chase atau TV di atasnya (`temp/diag/a-s3860-road-level.png`, `d-s3860-aerial.png`).
- Test `#L1.8` memeriksa fungsi `ground_y_at()` (`tests/test_brianza_circuit.gd:239-250`), bukan permukaan yang dirender, sehingga lolos. Kamera `cam4` gate 13.1 kebetulan berada di bawah plane.
- Gejala sekunder yang sama sumbernya (generator ground):
  - Field 48 m memakai tone per sel acak (`GRASS_TONES`): terlihat sebagai kotak catur dan segitiga gelap besar di aerial (`f`, `j`).
  - Verge selebar 80 m (`VERGE_LATERAL_M`) tidak memeriksa ruas jalan lain. Parabolica dan back straight hanya 66 m dari tengah ke tengah, sehingga verge satu jalan melintasi koridor jalan lain (probe: s = 4768, 4856, 5480, 5552; saat ini 1,6 sampai 3,2 m di bawah aspal lawan, jadi belum terlihat, tetapi menjadi jebakan jika elevasi atau drop diubah).
  - Lantai pit dan paddock berada di y +0,015 sedangkan verge turun ke -0,30 pada lateral 12 m dan -1,20 pada 40 m: gedung dan apron melayang di atas rumput.

### 2.2 Pit lane
- **Guardrail memotong fast lane.** `TracksideFurnitureBuilder.armco_ranges_for()` (`trackside_furniture_builder.gd:195-203`) membuka celah armco memakai `PitLaneScript.ENTRY_S` milik **Apex Ring (3900)**, bukan 5530 milik Brianza. Probe: celah armco kanan ada di s 3880 sampai 4350 (Serraglio, tempat yang salah); di pit yang sebenarnya armco berdiri di lateral **11,5 m**, sedangkan lintasan fast lane di **11,6 m** (`temp/diag/h-pit-exit.png`).
- Konstanta pit Apex juga dibaca `broadcast_camera_director.gd:246` (zona pengecualian stasiun kamera TV), sehingga stasiun TV bisa jatuh di area garasi Brianza.
- `brianza_environment.gd:614-618` dan `654-657` menanam angka pit sendiri (5530, 410, 5510 sampai 5790). Tiga tempat, tiga salinan.
- Bentuk lane adalah salinan Apex v1, belum Apex v2: ramp 35 m dan 45 m (Apex v2: 80 m dan 90 m, sehingga pergeseran 5,6 m dalam 35 m terlihat patah); lateral tepi 6,0 (Apex v2: 5,2); dinding mulai tetap di u = 25 (Apex v2: mulai saat verge >= 1,1 m); tanpa crash cushion di kedua ujung; aspal pit memakai toon vertex-color biru keabuan, bukan shader aspal jalan.
- Lane keluar dari tikungan Parabolica (radius 77 sampai 88 m pada s 5495 sampai 5573) dan garasi 0 sampai 2 berdiri di segmen yang masih melengkung, padahal PitBuilding adalah satu kotak lurus.
- Concept art `view1` dan `view4` menunjukkan elemen yang belum ada: chevron di wedge entry, drum cushion oranye, pagar kawat di atas pit wall, gantry "80 PIT ENTRY", strip sponsor pada pit wall.

### 2.3 Paddock
- Bukan overlap: paddock **kosong**. Di belakang PitBuilding hanya ada ladang rumput. Tidak ada apron, jalan servis, transporter, tenda hospitality, pagar, atau parkir (`temp/diag/j-paddock-aerial.png`, `i-paddock-behind.png`).

### 2.4 Temuan alur kerja
1. Tier A tidak netral dalam praktik: konstanta pit Apex tertanam di furniture, kamera TV dan zona-zona lain; Brianza dan Wangan menyalin file pit (372 dan 623 baris).
2. Gate "0 floating road" menguji fungsi query, bukan mesh. Brianza adalah sirkuit pertama dengan elevasi 12 m, sementara alur lama dirancang untuk Apex yang datar.
3. Visual gate memakai 6 kamera yang dipilih penulisnya, jadi mudah melewatkan titik buruk.
4. Tidak ada test yang menjaga lintasan pit dari barrier.
5. Anggaran render tipis: draw call environment 155 sampai 169 (acuan <= 160) dan 60 FPS belum terkunci pada Fase 13.2.

## 3. Tujuan, bukan-tujuan, anti-tujuan

**Tujuan**
- G1. Tidak ada permukaan tanah yang berada di atas jalan, kerb, aspal pit atau apron di titik mana pun (diuji pada mesh).
- G2. Pit lane Brianza bersih: tidak ada barrier di lintasan mobil, bentuk entry dan exit halus, tampilan sesuai concept art.
- G3. Layout pit dan paddock mengikuti spline Brianza (garasi hanya di segmen lurus; paddock mengikuti pit dan ruang yang ada).
- G4. Paddock terisi dan masuk akal secara fungsi.
- G5. Alur kerja diperbaiki: kontrak zona pit tunggal, gate terrain mesh-level, flythrough gate, dan dokumentasinya.

**Bukan-tujuan**
- Mengubah spline Brianza (`VERTICES`, `RADII`, `ELEVATION`), spline Apex (`track_circuit.tscn`) atau profil elevasi. Perubahan semacam itu perlu persetujuan terpisah.
- Mengubah roster, fisika ban, atau perilaku simulasi Apex.
- Mengganti sistem sky, vegetasi pohon, Sopraelevata, tribun sudut, atau vista (sudah selesai di 13.1).
- Rewrite penuh `PitLaneComplex` untuk semua sirkuit.

**Anti-tujuan** (gagal walau teknis lulus)
- Menambah draw call environment di atas batas yang disepakati (bagian 6).
- Mengubah perilaku Apex Ring atau Neo Wangan (hash determinisme Apex dan semua test lama harus identik).
- Memperbaiki satu titik dengan angka ajaib baru yang hanya cocok untuk satu kamera.

## 4. Desain

### 4.1 Terrain (G1)
- **Invarian:** pada setiap sampel jalan (s tiap <= 6 m, lateral -7, 0, +7 dan seluruh lebar aspal pit dan apron), tinggi tertinggi dari semua permukaan tanah (`ParcoRealeOuterFloor`, field, verge, platform) harus <= tinggi jalan - 0,05 m.
- Lantai luar harus berada di bawah jalan terendah: `min_elevation - GROUND_DROP_M - margin`, atau diganti kontinu dengan field yang memudar ke tinggi lantai itu. Metode dipilih executor; invarian di atas adalah kontraknya.
- Tone rumput: ganti tone per sel acak dengan pola organik berfrekuensi rendah (noise halus atau tambalan lebar), tetap 3 tone cel. Tidak boleh ada kotak sumbu-sejajar yang terlihat di aerial.
- Verge: lebar dibatasi oleh jarak ke ruas jalan lain (pakai `SurfaceGeometry.other_road_distance` / `max_extent`, yang sudah ada), sehingga tidak melintasi koridor jalan lain.
- **Platform pit dan paddock:** daftar zona datar `{s0, s1, side, lateral_to, y_offset, skirt}` yang dihormati oleh verge, `ground_y_at()` dan penempatan pohon. Platform duduk tepat di bawah permukaan pit dan turun halus (skirt) ke ground. Ini menghilangkan lantai garasi dan apron yang melayang.

### 4.2 Kontrak zona pit (G2, R1)
- Satu fungsi yang menghitung zona pit `{start_s, length_m}` dari `pit_layout` (dan jarak lead/trail), dipakai oleh semua konsumen. Tidak ada konsumen yang menyimpan salinan angka.
- Konsumen yang harus membaca kontrak itu: celah armco (`armco_ranges_for`), gate runoff dan gravel (`plan_runoffs`), zona floodlight (`hero_zones`), keep-out foliage dan tribun, pengecualian stasiun kamera TV (`broadcast_camera_director`), dan trigger pit. Apex Ring memasok layout default-nya sendiri sehingga perilakunya tidak berubah.
- `TracksideFurnitureBuilder.build()` menerima zona pit sebagai parameter (default = layout Apex agar pemanggil lama tetap valid).
- Neo Wangan diaudit untuk bug yang sama; jika terbukti, diperbaiki lewat parameter yang sama (R3).

### 4.3 Pit lane Brianza (G2, G3)
Pertahankan nama node dan antarmuka yang dipakai test, RaceVfx dan choreographer: `PitAsphalt`, `PitMarkings`, `PitWall`, `Socket_PitStall_n`, `PitEntryTrigger`, `PitExitTrigger`, `sim_layout()`, `stall_transform()`, `garage_for_team()`, `crew_spot()`.

Layout logis menurut spline (keputusan planner, lihat bagian 7):
- `ENTRY_S` tetap 5530 dan `EXIT_S` tetap 150 (panjang lane 410 m tetap).
- `STALL_FIRST_S` 5555 menjadi **5600**, sehingga ke-10 stall dan PitBuilding berdiri di segmen lurus (radius > 250 m; tikungan berakhir di s ≈ 5573).
- Ramp masuk 80 m dan keluar 90 m, `edge_lateral_m` 5,2 (setara Apex v2). Nilai ini mengalir ke simulasi lewat `sim_layout()` sehingga jalur mobil dan aspal tetap sama.
- Geometri mengikuti logika Apex v2 yang sudah teruji: tepi aspal (wedge dari tepi sirkuit ke fast lane ke working lane), `wall_lateral`, dinding hanya mulai saat verge >= 1,1 m, **crash cushion di kedua ujung**, garis marking (limiter kuning, putih, separator, stop line, nomor box), rambu 80 / PIT LANE / PIT EXIT. Port dan sesuaikan; berbagi yang murah lewat instance `ApexPitScript` seperti Neo Wangan (`asphalt_material()`, `standby_roles()`, `_garage_props()`).
- Aspal pit memakai ShaderMaterial aspal jalan yang sama (warna cocok dengan jalan).
- Elemen dari concept art: chevron pada wedge entry, drum cushion oranye di nose dinding, pagar kawat di atas pit wall, gantry "80 PIT ENTRY" melintang, strip sponsor pada dinding.
- Tidak ada armco, tecpro, atau papan sponsor trackside yang masuk ke lebar lane (lihat 4.2).

### 4.4 Paddock (G3, G4)
Zona: mengikuti pit. Sepanjang stall pertama - 30 m sampai stall terakhir + 30 m, dari punggung PitBuilding (lateral ≈ 32 m) keluar sampai batas yang lebih kecil dari 95 m atau `jarak ke jalan lain - 14 m` (probe: ruang hanya ≈ 114 m di s ≈ 5570 karena back straight berjarak 74 m dari lateral 40).

Isi, tersusun menurut fungsi:
1. **Apron platform** beton (tone cel terang, di atas platform 4.1) dengan **jalan servis** di belakang garasi (lateral ≈ 34 sampai 40) dan jalur penghubung ke **gerbang paddock** di sisi luar.
2. **10 transporter tim** di belakang masing-masing garasi, sejajar stall, warna per tim (`Liveries`); MultiMesh dengan warna per instance.
3. **Hospitality**: 6 sampai 8 tenda/marquee gable putih dengan trim Monza red, di barisan kedua (lateral ≈ 58 sampai 70).
4. **Pagar paddock** (tiang + panel kawat) di batas luar apron dengan gerbang berlengkung bertanda "PADDOCK".
5. **Parkir** kecil (dua baris blok kendaraan), generator/kontainer/tumpukan ban sebagai prop.
6. Pohon dan semak tetap menjauh dari zona paddock; barisan cypress boleh menjadi tabir di luar pagar.
Semua elemen berulang wajib `MultiMeshInstance3D` atau `MeshBatch` (aturan > 3 pengulangan). Tidak ada figur baru.

### 4.5 Gate dan alur kerja (G5)
Test baru (RED dulu), pada `tests/test_brianza_circuit.gd` atau suite baru:
- **T1 permukaan tanah vs jalan** (invarian 4.1) membaca mesh/node yang dirender, bukan `ground_y_at()`.
- **T2 lintasan pit bebas barrier**: untuk u = 0 sampai panjang lane tiap 2 m, lintasan mobil ± 1,1 m tidak bersinggungan dengan armco, dinding, atau cushion; armco tidak ada di seluruh zona pit.
- **T3 zona pit satu sumber**: parametrik untuk Apex, Brianza dan Wangan; setiap konsumen mengembalikan zona yang sama dengan `pit_layout` sirkuit itu. Uji kontrol: layout Brianza sengaja digeser harus mengubah celah armco.
- **T4 stall di segmen lurus**: radius minimum sepanjang blok stall >= 250 m.
- **T5 paddock**: jumlah elemen, jejak berada dalam zona, tidak menimpa gedung, tidak masuk koridor jalan lain, berdiri di atas platform.
- **T6 lint**: komponen bersama tidak mereferensikan konstanta sirkuit tertentu (pemindaian teks sederhana; daftar izin untuk file Apex sendiri).
- **T7 anggaran**: draw call environment dan triangles tidak melewati batas bagian 6.

Visual gate baru: **flythrough** setinggi kamera chase tiap 150 m ke dua arah sepanjang lap (contact sheet), aerial pit, aerial paddock, pit entry dan exit, Day/Sunset/Night. Simpan di `executor-report/screenshots/phases/phase-13-3-*` (nama baru, jangan menimpa tangkapan lama).

Dokumentasi: tambahkan "Layout-Driven Reuse", "gate terrain mesh-level untuk track berelevasi", "flythrough gate" ke `Circuit-Environment-Component-Guide.md` (Tahap 2 dan 5) dan `docs/AGENT-WORKFLOW.md`.

## 5. Kendala dan aturan mengikat
- Kode GDScript 2.0 bertipe statis, ikuti gaya file sekitar. Jangan menimpa atau menghapus aset yang bukan buatan executor (AGENTS.md aturan 1). Pohon kerja saat ini memuat banyak berkas belum di-commit: jangan disentuh.
- Spline Brianza dan Apex tidak diubah. Seed dan simulasi Apex harus identik (hash determinisme Apex).
- Brianza boleh berubah pada layout pit (`sim_layout()` baru): test Brianza yang meng-hardcode angka lama diperbarui secara sadar (RED dulu), jangan dilonggarkan.
- Definisi Selesai proyek: 100% test headless lulus (saat ini 52 suite), smoke native 3 lap 20 mobil, laporan di `executor-report/reports/FASE-13-3-*.md`. Catatan jujur Fase 13.2 (60 FPS belum terkunci, kembali ke menu belum diverifikasi) tidak boleh dikaburkan; laporkan apa adanya.

## 6. Anggaran
- Draw call environment: acuan <= 160; terukur 155 sampai 169 pada 13.2. Fase ini tidak boleh memperburuk angka terburuk 13.2 (169) dan target <= 160 dicapai dengan menggabung mesh (mis. marking dan sign pit) untuk membayar isi paddock.
- Segitiga lingkungan <= 320.000 (aturan proyek) dan nol orphan node.

## 7. Keputusan planner (tandai untuk ditinjau)
- K1. Entry tetap, stall pertama digeser ke s = 5600, ramp 80/90, tepi 5,2 (4.3).
- K2. Zona pit disalurkan lewat `pit_layout` yang sudah ada, bukan kelas baru; Apex memasok default-nya (4.2).
- K3. Pit Brianza diperbaiki di dalam file Brianza dengan porting logika Apex v2, bukan memparameterkan seluruh `PitLaneComplex` (terlalu berisiko bagi Apex dan Wangan, manfaat tambahan kecil).
- K4. Isi paddock sesuai 4.4, termasuk gerbang dan jalan servis.
- K5. Elemen concept art (chevron, drum, pagar kawat, gantry, strip sponsor) termasuk lingkup.
- K6. Neo Wangan hanya diaudit; diperbaiki hanya jika bug armco terbukti, dengan parameter yang sama.

## 8. Diserahkan kepada executor
Metode pasti untuk lantai luar dan field, bentuk mesh transporter/tenda/gerbang, pola noise tone rumput, nilai jarak paddock yang tepat, dan pembagian commit, selama invarian dan gate di atas terpenuhi.

## 9. Risiko
- Zona pit parametrik menyentuh furniture, runoff, kamera dan foliage yang dipakai Apex dan Wangan: wajib regresi penuh dan perbandingan hash Apex.
- Menggeser stall mengubah posisi PitBuilding, tower, dan kamera pit Brianza; test hardcode perlu diperbarui.
- Paddock menambah draw call pada anggaran yang sudah tipis.
- Verifikasi 60 FPS terkunci pada hardware target belum pernah lulus; fase ini tidak boleh mengklaimnya tanpa pengukuran.
