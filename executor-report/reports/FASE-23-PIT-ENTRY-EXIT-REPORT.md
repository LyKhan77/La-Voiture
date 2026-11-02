# FASE 23 — Pit Entry–Exit Map 1–3

Tanggal: 2026-11-03

Branch: `fase-23-pit-entry-exit`

Engine teramati: Godot 4.7.2 stable `ed1daf0bf`

Renderer native: D3D12 / Forward+ / NVIDIA RTX 3050 Laptop GPU

## 1. Diagnosa dan akar masalah

Temuan pengguna terkonfirmasi melalui kode dan regresi mesh runtime. Map 1 Apex Ring, map 2 Neo-Wangan, dan map 3 Brianza belum memakai bentuk pavement sambungan seperti map berikutnya. Ini penyelarasan standar internal proyek, bukan klaim homologasi FIA dunia nyata.

- Apex `_build_asphalt()` hanya membangun u=0..length_m, dengan tepi dalam yang bergeser menjauhi tepi trek. Tidak ada taper sebelum entry atau setelah exit.
- Neo-Wangan mulai tepat pada entry; tepi dalam pavement menjauh dari jalan, sedangkan tepi luar setelah limiter exit tetap selebar fast lane hingga merge. Hasilnya sambungan akhir tidak mengecil ke tepi trek.
- Brianza membangun u=0..410 saja dan memakai tepi driving corridor sebagai batas pavement, sehingga terbentuk strip kosong di antara trek dan pit.
- Pembanding: Monte Azure dan Ardennes memiliki pavement menerus di tepi jalan serta tail di kedua mulut; Stoke Crown dan Pacific Corkscrew memperpanjang pavement 65 m sebelum entry dan setelah exit. Pacific memakai overlap dan marka luar yang mengikuti taper.

## 2. Patch

File produksi yang diubah dengan izin pengguna:

- `scripts/world/circuits/apex_ring/apex_pit_complex.gd`
- `scripts/world/circuits/neo_wangan/neo_wangan_pit_complex.gd`
- `scripts/world/circuits/brianza/brianza_pit_complex.gd`

Perubahan:

1. Pavement mendapat tail 65 m sebelum entry dan 65 m setelah rejoin. Neo-Wangan menggunakan akhir bypass/merge, bukan akhir limiter, sebagai acuan departure tail.
2. Tepi dalam pavement overlap 0,2 m terhadap tepi trek sepanjang lane dan tail; tidak ada strip tanah/deck kosong di antaranya.
3. Tepi luar taper memakai smoothstep menuju lebar fast lane dan kembali ke tepi trek. Apron tetap menjangkau garasi.
4. Garis putih luar mengikuti pavement dan kedua taper, bukan berhenti pada limiter.
5. Geometry dibake sekali melalui MeshBatch yang sudah ada; tidak menambah proses per-frame atau dependency.

Tidak diubah: Curve3D, koordinat/handle trek, driving corridor, lap length, timing limiter, entry/exit simulasi, bypass Turn 1 Neo-Wangan, stall/garage, pit wall, dan choreography.

## 3. Regresi mesh

`tests/test_pit_mouth_pavement.gd` menginstansiasi race world sebenarnya dan memeriksa triangle mesh PitAsphalt di ketiga map:

- Tail entry/departure tersambung pada jarak 32 m dari mulut.
- Ujung tail mengecil ke tepi trek, bukan slab persegi selebar lane.
- Sampling setiap 5 m sepanjang sambungan trek–pit tidak menemukan strip kosong.

RED: 9 FAIL / 6 PASS sebelum patch (tail dan strip kosong gagal di semua map).

GREEN: 15 PASS / 0 FAIL sesudah patch.

Suite penuh melalui `powershell -NoProfile -File tools/run_tests.ps1`: **104/104 suite PASS, 0 FAIL** (termasuk regresi pavement baru).

| Irisan (`-From` / `-To`) | Suite | Waktu | Gagal |
|:---|---:|---:|---:|
| 0–9 | 10 | 308 s | 0 |
| 10–19 | 10 | 376 s | 0 |
| 20–39 | 20 | 248 s | 0 |
| 40–59 | 20 | 167 s | 0 |
| 60–79 | 20 | 679 s | 0 |
| 80–103 | 24 | 247 s | 0 |

Catatan eksekusi: percobaan awal irisan 0–19 dihentikan deadline tool 600 s sebelum runner mencetak ringkasan; diganti irisan 0–9 dan 10–19 yang keduanya selesai PASS. Irisan 20–39 memakai `-TimeoutSec 120`; irisan lain memakai timeout suite default. Timeout perintah dinaikkan agar tidak memutus irisan panjang; tidak ada assertion yang dilewati atau diubah.

## 4. Native smoke dan visual

Ketiga map dijalankan melalui race weekend sebenarnya, HIGH, 1920×1080:

- 20 mobil GT3 masing-masing map.
- Leader mencapai lap 4: tiga lap jarak balap selesai, konfigurasi empat lap agar pengukuran tidak terpotong transisi podium.
- Satu mobil diminta pit dan teramati masuk lalu keluar pit.
- World dibebaskan lalu menu HQ diinstansiasi; 0 orphan node pada masing-masing map.
- Pengukuran FPS 180 frame pada 1x setelah 180 frame warm-up: minimum, median, p5 semuanya 60 FPS pada ketiga map. Sesudah sampling, race dipercepat 8x untuk smoke tiga lap. Ini sampel performa, bukan jaminan tidak ada frame drop di seluruh balapan/cuaca.
- 18 PNG 1920×1080: entry dan exit, masing-masing aerial/oblique/chase di setiap map. Pemeriksaan gambar dan contact sheet memperlihatkan taper terhubung pada keenam mulut.

Bukti: `executor-report/screenshots/fase-23-pit-entry-exit/` (18 PNG dan `contact-sheet.jpg`).

## 5. Edge cases dan batas verifikasi

- Arc negatif dan arc sesudah akhir lane disampling melalui modulo lap yang sudah digunakan proyek; tidak mengganti jalur fisika.
- Lebar lane khusus Neo-Wangan dan bypass Turn 1 dipertahankan, tidak disalin mentah dari sirkuit GP.
- Lapisan overlap memakai ketinggian pavement/marka yang sudah ada.
- Verifikasi visual dilakukan pada DAY/dry. SUNSET/NIGHT/storm bukan bagian pengukuran native ini.
- Semua smoke native mengeluarkan warning shutdown `7 RIDs of type Texture were leaked`, meskipun orphan node=0. Kontrol terpisah menjalankan hanya scene main menu yang tidak diubah (`--quit-after 120 scenes/ui/main_menu.tscn`) dan menghasilkan warning identik. Dengan demikian warning juga terjadi tanpa memuat pit/trek; tidak diperbaiki dengan menutupi warning atau memperluas patch ke menu.
- Setelah verifikasi, pengguna mengotorisasi commit, merge ke `main`, dan push ke `origin`; tidak ada perubahan kode di antara suite penuh yang lulus dan integrasi. Regresi pavement dijalankan ulang melalui runner sebelum commit: 1/1 suite PASS.
