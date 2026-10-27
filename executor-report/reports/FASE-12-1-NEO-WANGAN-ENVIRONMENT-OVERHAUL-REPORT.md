# FASE 12.1 — Neo-Wangan Environment Overhaul & Shared FIA Paddock Kit

Pelaksanaan: 27–28 Oktober 2026. Engine: Godot 4.7.2 stable, Forward+ Vulkan. DCC: Blender 5.2.0 LTS.

**Status akhir: Task 1–3 selesai; DoD keseluruhan belum ditutup.** Enam gate visual/geometri dan 48/48 suite headless lulus. Smoke native menuntaskan 3 lap / 20 mobil dan kembali ke HQ dengan 0 orphan node, tetapi **60 FPS locked belum lulus** dan warning tujuh Texture RID pada shutdown masih ada. Tidak ada klaim selesai penuh untuk Fase 12.1.

## Keputusan spesifikasi dan preservasi

1. Handoff utama dan permintaan pengguna mengungguli bagian rencana lama yang menyebut empat GLB, direktori `assets/world/circuits/neo_wangan/`, dan nama screenshot Fase 12 v2. Implementasi menghasilkan enam GLB terpisah pada path yang diminta pengguna.
2. Pengguna mengonfirmasi penempatan mengikuti span spline aktual: jembatan **250–700 m**, terowongan **1080–1260 m**, harbor sekitar **1418 m**. Koordinat spline dan profil elevasi kedua sirkuit tidak diubah. Pylon berada pada 385/565 m; portal pada 1080/1260 m; crane mengelilingi harbor aktual. Angka lokasi literal handoff berasal dari asumsi layout berbeda.
3. Default Apex aktual dipertahankan: panjang pit **140 m**, pitch **14 m**, panjang tribun **240 m**. Nilai asumsi 164/16/220 m pada handoff tidak diterapkan pada Apex karena akan mengubah geometri lama. Konfigurasi Neo-Wangan: pit 124 m, 10 bay dengan pitch 12 m, fascia 15,5 m, lantai lounge 4,7 m, tribun 140 m, cyan accent.
4. Workspace yang sama dipakai; seluruh scratch milik pengguna dan pekerjaan lain tetap dipertahankan. Tidak ada push, publikasi, dependensi baru, atau perubahan roster.
5. Repo awal memiliki **45** suite GDScript. Selain dua suite baru yang diminta, gate bernama `test_track_environment_upgrade.gd` ternyata belum ada; ditambahkan sebagai turunan gate Apex lengkap. Inventaris akhir menjadi **48**, bukan 47. Gate tambahan ini menjalankan 40 asersi Apex yang sama.

## Implementasi enam lapis

| Lapis standar | Implementasi dan bukti |
|---|---|
| 1. Spine dan permukaan | `TrackRibbon`, shader aspal, kerb 3D, driving line, sektor, pit trigger, dan profil elevasi tetap menggunakan spline aktual. |
| 2. Ground massing | `UrbanIslandRoot/UrbanGroundSlab` berupa union grid 5 m mengikuti semua span darat. `QuayWalls` turun sampai bawah permukaan air. Grid menggantikan slab ribbon yang saling menutup pada chicane bertingkat. `TunnelOverpassPlaza` berada di atas atap terowongan dengan puncak 5,3 m. |
| 3. Shared FIA kit | `PitLane/PitBuilding`, `MainGrandstand` dengan crowd MultiMesh dan Jumbotron live setiap 0,5 detik, `RaceControlTower`, catch fence, garasi terbuka, serta equipment dari helper Apex. `RaceWeekendWorld` tetap memakai StartGantry bersama dengan lima pasang lampu FIA. **36 papan rem 150/100/50 m** memakai mesh dan shader FIA bersama. Fence pit berhenti pada entry/exit merge. |
| 4. Koridor dekat | `MidgroundCorridorRoot`: **77** tower GLB pada lateral 24/32/40 m; seluruh footprint diperiksa terhadap setiap kaki jalan, termasuk chicane yang berdekatan. MultiMesh dipisah per varian dan district 300 m agar bounds dapat di-cull. **24** billboard instanced dengan cyan, magenta, acid lime dan kedua muka panel. |
| 5. Hero landmarks | `HeroLandmarksRoot`: dua pylon H-frame 44 × 65 m; kabel baja diikat ulang pada koordinat deck spline sehingga endpoint tidak melayang; side truss MultiMesh, dua portal overpass, dan empat crane GLB dengan clearance seluruh kaki jalan. Piers dikoreksi agar alasnya di seabed dan atasnya menyentuh bagian bawah deck. |
| 6. Atmosfer dan visual gate | Sky malam, glow, fog, warm streetlight pools dan cyan tunnel pools. Street pools berukuran 9 × 5,5 m pada lateral ±3,2 m; clipping shader menyisakan margin 0,75 m terhadap tepi aspal untuk tikungan terkecil. Enam kamera native 1920 × 1080. |

Nama root mengikuti handoff (`UrbanIslandRoot`, `HeroLandmarksRoot`, `MidgroundCorridorRoot`); nomor lapis pada tabel mengikuti Circuit Environment Component Guide.

## Pipeline aset Blender

Perintah reproduksi:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --factory-startup --background --python tools/build_neo_wangan_assets.py
godot --headless --path . --import
```

`--factory-startup` menghindari error unregister add-on BlenderMCP milik profil pengguna; generator hanya menghapus objek dan collection yang dibuat oleh invokasinya sendiri. Scene Blender pengguna tidak dikosongkan. Seluruh runtime asset memakai file lokal, tanpa URL eksternal.

| GLB pada `assets/tracks/neo_wangan/models/` | Tris | Surface |
|---|---:|---:|
| `shuto_bridge_pylon.glb` | 568 | 2 |
| `tunnel_portal_overpass.glb` | 244 | 2 |
| `harbor_gantry_crane.glb` | 836 | 1 |
| `skyscraper_tower_a.glb` | 968 | 2 |
| `skyscraper_tower_b.glb` | 724 | 2 |
| `skyscraper_tower_c.glb` | 456 | 2 |

`asset_manifest.json` mencatat provenance generator, unit meter, pivot foundation dan anggaran per aset. Mesh menyimpan warna vertex dan alpha emission mask; node Alpha Blender dihubungkan ke shader agar glTF benar-benar mempertahankan mask. Impor StandardMaterial Godot tidak mengaktifkan warna secara otomatis; integrasi runtime memakai shader cel vertex-color bersama. Shell gedung mempertahankan inverted-hull outline dan shadow; detail jendela menghindari kedua pass duplikat tersebut.

## TDD dan review

- Shared kit: 7 kegagalan awal → GREEN; ditambah hash geometri pre-phase untuk ketiga default kit Apex.
- GLB: enam file hilang → 30 asersi asset PASS, termasuk bounds, triangle count, material, dan warna vertex.
- Lapis lingkungan: root, jumlah gedung, billboard dan pool bounds mula-mula RED → GREEN.
- Regresi tambahan dari inspeksi: 1.008 ray check mendeteksi slab yang menutupi jalan; palette GLB, footprint crane, kabel berjangkar spline, seabed pier, dan Jumbotron live masing-masing diperiksa.
- Reviewer independen menemukan outline `next_pass` yang belum dihitung dan pergeseran 0,5 m strip jendela belakang Apex akibat shadowing variabel. Hitungan kini memasukkan seluruh material pass; hash mesh Apex yang sempat RED kini cocok byte-for-byte dengan pre-phase untuk ketiga kit.
- Test headless memakai layout transform yang dikirim ke MultiMesh karena dummy renderer tidak menyediakan readback buffer transform. Enam render native memverifikasi hasil sebenarnya.
- Jumbotron yang semula hanya ada secara struktural kini benar-benar menerima standings. Gate live screen mula-mula RED lalu GREEN.
- Sky Neo-Wangan kini memakai salinan `Environment`, mengikuti pola `_build_sky()` Apex. Gate ownership RED → GREEN membuktikan resource weekend bersama tidak lagi dimutasi.
- Runner ketat menemukan empat `SCRIPT ERROR` pada suite Safety Car lama yang tetap mencetak PASS dan exit 0. `_build_grid()` mengalokasikan `count / 2` tim sehingga grid tiga mobil hanya memiliki dua entry. Rumus menjadi `(count + 1) / 2`; grid 20 mobil tetap mengambil sepuluh tim dengan urutan RNG yang sama. Dua guard ukuran grid memperjelas kegagalan test. Suite Safety Car kini menjalankan **108 asersi**, bukan 89 yang sebelumnya tersisa setelah dua fungsi terputus.

## Enam kamera dan anggaran rendering

| Gate | Gambar | Inspeksi |
|---|---|---|
| 1 | [Start / paddock](../screenshots/phases/phase-12-1-cam1-start-paddock.png) | Tribun dan crowd, Jumbotron, gantry FIA, pit building, dan tower bersama. |
| 2 | [Shuto bridge](../screenshots/phases/phase-12-1-cam2-shuto-bridge.png) | Dua pylon, kabel berjangkar deck, side truss, pier dan air teluk. |
| 3 | [Tunnel / chicane](../screenshots/phases/phase-12-1-cam3-tunnel-chicane.png) | Bukaan terowongan jelas, massa plaza di atas atap, koridor dan neon. Jalan tidak tertutup slab. |
| 4 | [Harbor hairpin](../screenshots/phases/phase-12-1-cam4-harbor-hairpin.png) | Crane merah-putih, container yard, hairpin dan daratan dermaga. Pit entry berada pada span aktual lain dan dibuktikan oleh gate pit, bukan dipindah agar masuk gambar ini. |
| 5 | [Helicopter overview](../screenshots/phases/phase-12-1-cam5-aerial-overview.png) | Semua jalan darat berdiri di pulau; teluk terbuka pada jembatan dan massa terowongan menyatu dengan kota. |
| 6 | [Chase cam action](../screenshots/phases/phase-12-1-cam6-chase-cam-action.png) | Balapan aktual 20 GT3; tower dekat, barriers, lampu, billboard dan pack mobil terlihat. |

Semua gambar dibuka dan diperiksa setelah render. Gate menggunakan weekend 20 mobil yang sebenarnya, bukan scene gambar tiruan. Pengukuran environment dilakukan pada viewport yang sama setelah actors, crew dan VFX dinonaktifkan sementara; screenshot tetap diambil dengan balapan lengkap.

Counter `VIEWPORT_RENDER_INFO_TYPE_VISIBLE` dipisahkan dari shadow pass dan Canvas HUD. `Performance.RENDER_TOTAL_*` untuk seluruh game mencakup mobil, shadow, HUD dan viewport tambahan; tidak dipakai untuk mengklaim budget environment.

**Anggaran statik penuh sirkuit: 121 draw call, 229.328 tris, termasuk outline pass.** Enam gate native final menunjukkan maksimum **124 visible 3D draw call / 186.926 visible 3D tris**, dalam budget 160 / 320.000.

| Gate | Visible 3D draw | Visible 3D tris | Shadow draw | Canvas draw saat isolasi |
|---|---:|---:|---:|---:|
| Cam 1 | 54 | 164.440 | 89 | 0 |
| Cam 2 | 48 | 109.076 | 43 | 0 |
| Cam 3 | 104 | 180.374 | 60 | 0 |
| Cam 4 | 55 | 99.602 | 51 | 0 |
| Cam 5 | 124 | 186.926 | 0 | 0 |
| Cam 6 | 35 | 92.910 | 44 | 153 |

Canvas Cam 6 berasal dari overlay radio yang merupakan CanvasLayer tersendiri; pemisahan counter memastikan overlay itu tidak disamarkan sebagai geometri lingkungan.

## Regresi lengkap dan native smoke

**Regresi final sesudah batching telemetry: 48/48 PASS, 0 FAIL, 1.494 asersi, 0 script error, 0 warning headless.** Putaran pertama menjalankan nested legacy juga dan menangkap satu kegagalan tersembunyi Safety Car. Sesudah seluruh perbaikan, semua 48 script dijalankan lagi; dua wrapper memakai `--skip-legacy` untuk menghindari pengulangan pemanggilan, karena masing-masing script legacy juga dijadwalkan langsung dalam run yang sama. Tidak ada suite legacy yang dihilangkan.

Regresi final mencakup `test_neo_wangan_circuit.gd` **40/40**, `test_neo_wangan_glb_assets.gd` **33/33**, shared kit **10/10**, telemetry **32/32**; gate Apex asli dan upgrade masing-masing **40/40**. Bukti machine-readable lengkap tersedia pada [FASE-12-1-VERIFICATION-RESULTS.json](FASE-12-1-VERIFICATION-RESULTS.json). Log penuh tetap di `temp/phase12-1-regression-batched/`; log RED/GREEN telemetry di `temp/phase12-telemetry-batch-red-engine.log` dan `temp/phase12-telemetry-batch-green-engine.log`; perbandingan piksel native di `temp/phase12-dot-compare-green.log`.

Smoke menjalankan 3 lap / 20 mobil / Neo-Wangan / malam / cuaca kering / High / 1080p pada **NVIDIA GeForce RTX 3050 Laptop GPU**, renderer Safe. Sampling 600 frame dilakukan pada 1× setelah start dan 300 frame warm-up; penyelesaian ke bendera memakai 16×, lalu kembali ke menu utama.

| Pemeriksaan native final | Hasil | Status |
|---|---|---|
| Mobil / lap / finis | 20 mobil, 3 lap, 20 finis | PASS |
| Menu HQ | Termuat, error 0 | PASS |
| Orphan saat balapan / setelah HQ | 0 / 0 | PASS |
| Frame mean / p95 / worst | **16,755 / 21,715 / 76,837 ms** | Masih ada frame di atas 16,6667 ms |
| FPS rata-rata | **59,68 FPS** | **FAIL untuk 60 FPS locked** |
| Frame di atas 16,6667 ms | **210 / 600** | FAIL untuk frame budget ketat |
| Exit smoke | **1**, karena gate FPS | FAIL yang disengaja, tidak disembunyikan |
| Shutdown renderer | Warning **7 Texture RID** tertahan | OPEN; atlas refleksi internal Godot, terpicu ReflectionProbe garasi HQ |

Hasil bersih ini memakai timer wall-clock saja. Harness keluar 1 bila satu pun frame sampel melewati 16,6667 ms; rata-rata cepat tidak cukup untuk lulus. Angka dari probe yang memanggil waktu CPU/GPU viewport per frame tidak digunakan sebagai gate: API itu dapat memaksa sinkronisasi rendering. Mode render thread `separate` juga tidak diterapkan ke proyek karena engine menandainya eksperimental dan probe menghasilkan error texture update. Setting renderer proyek tetap Safe. Pengukuran yang overlap dengan test/proses native lain tidak dijadikan hasil penerimaan.

Monitor native melaporkan 144,003 Hz. Pengujian pacing tambahan mempertahankan High, 20 mobil, viewport 1920×1080 dan cap 60; hasil berikut hanya diagnostik, tanpa perubahan pengaturan produksi:

| Presentasi | FPS rata-rata | p95 / worst ms | Interval >16,6667 ms |
|---|---:|---:|---:|
| VSync disabled | 59,69 | 23,428 / 80,823 | 283 / 600 |
| Mailbox | 60,00 | 20,303 / 38,242 | 387 / 600 |
| Exclusive fullscreen + Mailbox | 59,98 | 23,616 / 42,303 | 276 / 600 |

Mailbox mencapai rata-rata 60 tetapi tetap belum membuktikan pacing locked 60. Hitungan interval di atas anggaran mencakup jitter timer/presentasi; itu bukan pengukuran waktu kerja murni GPU/CPU. Sumber seluruh lonjakan sisa belum terbukti, sehingga preset, limiter, dan renderer produksi tidak diubah berdasarkan asumsi.

Profil diagnostik memberi indikasi bahwa GPU 3D memiliki ruang. Probe gameplay tanpa VSync/pembatas FPS menghasilkan 60,48 FPS rata-rata, p95 24,560 ms dan worst 80,256 ms; ini tetap bukan 60 FPS locked. Probe yang menghentikan update HUD menghasilkan 78,58 FPS; probe tanpa update VFX menghasilkan 82,48 FPS. Keduanya hanya eksperimen isolasi, bukan hasil penerimaan atau perubahan produksi. Timing script `world.step()` sekitar 2,87 ms, termasuk VFX 1,20 ms. Profil painter lanjutan mengisolasi bagian hero telemetry: 2,58 ms/frame, terutama hingga 576 panggilan `draw_circle` untuk titik stres. Grid tetap itu kini memakai sembilan MultiMesh 2D milik CanvasItem; tiap kolom berbagi satu disk yang radiusnya diperbarui sesuai rumus lama. Biaya bagian hero turun ke 0,36 ms dan total painter dari 3,43 ke 1,11 ms pada probe berinstrumen. Probe gameplay tanpa pembatas mencapai 101,98 FPS, p95 15,357 ms; angka ini diagnostik, bukan bukti locked 60. TDD dua asersi instancing/cache mula-mula RED lalu GREEN; suite telemetry 32/32. Perbandingan native legacy versus batch pada stres 0,05/0,14/0,3/0,7/1,0 menunjukkan **0 piksel RGBA berbeda** pada semua lima gambar. Shader, warna, posisi, radius, animasi, dan data telemetry tetap sama. Resource batch dimiliki CanvasItem dan dibebaskan bersama drawer, tanpa cache global. Smoke setelah optimasi tetap gagal batas frame ketat; optimasi ini tidak dipakai untuk mengklaim gate hijau. Probe panel yang menghasilkan script error serta probe yang overlap tidak dijadikan bukti performa yang valid. Selain batching telemetry yang diukur dan diverifikasi visual, HUD, audio, solver, serta preset tidak diubah untuk membuat gate tampak hijau.

Warning RID berhasil diisolasi dengan tiga probe native: SceneTree kosong bersih, balapan tanpa menu bersih, menu HQ sendiri memunculkan tepat tujuh Texture RID. Menghilangkan `ReflectionProbe` hanya pada probe menu menghilangkan warning. Hasil lokal ini konsisten dengan [Godot issue #122498: reflection atlas leaks seven texture RIDs](https://github.com/godotengine/godot/issues/122498), yang menjelaskan color buffer dan enam face views tidak dibebaskan pada renderer RD. Issue ditutup menuju milestone 4.8 melalui perbaikan upstream; engine proyek tetap 4.7.2. Ini atribusi berdasarkan reproduksi lokal dan laporan upstream, bukan bukti engine proyek sudah diperbaiki. Efek refleksi produksi tidak dinonaktifkan dan binary engine tidak diganti. Peringatan RID tetap dilaporkan terpisah dari orphan node; keberhasilan 0 orphan bukan bukti nol kebocoran GPU.

## Checklist penerimaan

- [x] Shared FIA kit terparameterisasi; geometri default Apex identik.
- [x] Enam model Blender lokal dan gate asset.
- [x] Ground massing, landmark, koridor, billboard, papan rem dan pool bounds.
- [x] Enam gambar 1920 × 1080 dirender, dibuka dan diinspeksi.
- [x] Anggaran lingkungan dan semua 48 suite headless PASS.
- [x] Tiga lap / 20 mobil / kembali HQ / 0 orphan node.
- [ ] **60 FPS locked pada native High.**
- [ ] Penutupan warning tujuh Texture RID pada engine proyek; sumber sudah diisolasi ke atlas refleksi Godot.

Task 12.1.4 dan Fase 12.1 tetap terbuka di ROADMAP. Pekerjaan lanjutan harus menutup dua gate terakhir sebelum fase dinyatakan selesai penuh.

## Commit lokal

- `0521c37`: parameterisasi dan integrasi kit FIA.
- `92b4d2e`: generator Blender, enam GLB dan gate asset.
- `8bb73f4`: ground massing, koridor dan landmark, serta perbaikan review.
- `25cd8ef`: perbaikan grid ganjil yang membuka seluruh asersi Safety Car.
- `80035e1`: presentasi final, emission mask GLB, isolasi Environment, serta harness kamera dan smoke.
- `03ec1b9`: batching telemetry yang identik secara visual dan gate smoke berbasis setiap frame.

Tidak ada push atau publikasi.
