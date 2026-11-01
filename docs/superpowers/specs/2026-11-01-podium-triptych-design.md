# Winning Scene: Triptych (podium seimbang P1-P3)

Tanggal: 2026-11-01. Status: disetujui pemilik proyek pada 2026-11-01 (tampilan sprite hasil bake, 7 keputusan di bagian 15 termasuk font berglyph Jepang, dan tambahan musik di bagian 16). Mengganti struktur cut dari `docs/superpowers/specs/2026-10-27-winning-scene-hero-graffiti-design.md` (5 cut yang menyorot mobil P1). Bagian lain spec itu tetap berlaku: data hasil (`capture_results`, `award_points`), reveal keberangkatan, tower [TAB], musik, dan gaya Toon Anime Graffiti Brutalism.

Referensi visual yang dipilih pemilik proyek:
- Preview Triptych dengan mobil hasil bake dari model 3D dan linimasa 5 cut: https://claude.ai/artifact/7aZxpnm1xEkiPjFo7GNQdw
- Salinan lokal preview itu: `docs/superpowers/specs/2026-11-01-podium-triptych-preview.html`
- Perbandingan 3 konsep (A, B, C) tempat Triptych dipilih: https://claude.ai/artifact/DCAKHB56sHVw9ewusX9d2V. Mobil di sana masih render referensi, dan hanya punya 4 beat.

Mock adalah referensi komposisi, warna, bentuk kartu, dan gerak. Koordinat mock memakai ruang 1920x1080 yang sama dengan `STAGE` di `winning_scene.gd`. Mock bukan kode produksi.

## 1. Maksud

Layar kemenangan sekarang memberi P1 tiga dari lima cut (mobil hero, detail, final), satu-satunya mobil yang dimuat, dan satu-satunya standee yang berdiri di samping mobil. P2 dan P3 mendapat satu cut dinding masing-masing, lalu mengecil jadi chip. Pemilik proyek ingin ketiga finisher tersorot seimbang, termasuk mobilnya, dan ingin karakter tampil sebagai kartu bergaya manga toon.

Arah yang dipilih: tiga panel miring ala halaman manga yang selalu tampil bersamaan. Tiap panel berisi satu finisher: standee, mobil, kartu karakter. Sorotan berpindah P3, P2, P1 dengan melebarkan satu panel sementara dua lainnya meredup, lalu ketiganya kembali sama lebar.

Mobil tidak dimuat sebagai model 3D saat scene berjalan. Tiap mobil adalah gambar 2D hasil tangkapan layar model 3D-nya (sprite), dibuat sekali oleh alat bake dan disimpan sebagai aset.

## 2. Keputusan

Keputusan pemilik proyek:
- Konsep C (Triptych) dari mock, bukan A atau B.
- Gambar mobil di mock diganti tangkapan layar model 3D-nya.

Keputusan saya (pemilik proyek boleh mengubah, daftar singkat ada di bagian 15):
1. Sprite dibake offline untuk 13 mobil di `Roster.CAR_SLUGS` dan di-commit, bukan ditangkap saat runtime. Alasan: tidak ada GLB yang dimuat di scene ini, jadi tidak ada lonjakan beban 884 ribu tris dan 203 MB tekstur saat transisi (hasil ukur untuk Mercedes, Audi, Aston, lihat bagian 12).
2. Lima cut, bukan empat: INTRO, FOCUS_P3, FOCUS_P2, FOCUS_P1, FINAL. Tiap cut 1 bar (1,6 dtk @150 BPM, `CUT_SECONDS`), sehingga FINAL jatuh di 6,4 dtk, tempat tema penuh anthem masuk (komentar di `winning_cut_director.gd`). Mock hanya punya empat beat; INTRO adalah tambahan: tiga panel masuk dengan stagger P3, P2, P1, belum menampilkan detail fokus.
3. P1 dibedakan hanya lewat warna lime, mahkota, dan posisi tengah. Durasi fokus, lebar panel di layar akhir, dan ukuran semua elemen sama.
4. Tanpa impact frame antar beat, tanpa headline "X TAKES IT", tanpa callout spesifikasi mobil, dan tanpa set 3D. Mock tidak memilikinya. Spesifikasi mesin pindah ke plat kecil di panel yang disorot.
5. Standee dipindah dari `KineticStandee3D` ke `TextureRect` 2D dengan shader die-cut `canvas_item` dan napas (breathing) yang sama. File `kinetic_standee_3d.gd` dan `kinetic_standee.gdshader` tidak dihapus, hanya tidak dipakai scene ini.
6. Sorotan manual: panah kiri/kanan dan klik panel (lihat bagian 11).
7. Epithet pengemudi, kanji peringkat, dan SFX katakana ditambahkan, dengan font berglyph Jepang yang disertakan di `assets/fonts` (lihat bagian 7).

## 3. Tujuan, bukan-tujuan, anti-tujuan

Tujuan:
- P1, P2, P3 mendapat durasi sorotan yang sama (satu bar masing-masing), panel sama lebar di layar akhir, dan elemen sama besar: standee, mobil, kartu.
- Mobil P2 dan P3 tampil penuh, di livery timnya sendiri.
- Kartu karakter bergaya manga toon untuk ketiganya, memakai data yang sudah ada kecuali epithet, kanji, dan SFX.
- Scene tidak memuat model 3D mobil. Beban runtime tidak lebih berat dari scene sekarang (satu GLB 300 ribu tris diganti sembilan tekstur 2D); angkanya dicatat di smoke test, tidak diasumsikan.

Bukan-tujuan:
- Mengubah simulasi, hasil, poin, atau tower [TAB] (isi dan perilaku data tetap).
- Mengikuti tim pemain.
- Konsep A (Tiga Bab) dan B (Panggung Sorot). Tidak dibangun.
- Menghapus `kinetic_standee_3d.gd`, `winning_wall_cut.gd`, `winning_hero_callouts.gd`, atau shader lama. File yang menjadi tidak terpakai dilaporkan di laporan fase untuk diputuskan pemilik proyek.
- Mengubah impor tekstur Mercedes (lihat bagian 12).

Anti-tujuan (gagal walau secara teknis jalan):
- Informasi hasil terkunci di balik INTRO yang tidak bisa dilewati.
- Satu finisher terlihat lebih besar atau lebih lama dari yang lain, selain mahkota P1.
- Teks terpotong atau keluar panel untuk nama pengemudi panjang, nama mobil panjang, atau DNF.
- Kanji tampil sebagai kotak kosong (tofu) di mesin tanpa font Jepang.
- Panel atau kartu tertutup tower [TAB].
- Sprite 13 mobil terlihat tidak seragam (sudut, ukuran, pencahayaan).

## 4. Batasan

- Godot 4.7.2, GDScript bertipe statis, tanpa dependensi baru (GDExtension, plugin, library).
- 60 FPS di 1920x1080 High, 0 orphan node setelah restart dan keluar.
- Root scene tetap `Node3D` (`class_name WinningScene`) agar handoff dari `race_weekend_world` dan `manga_race_transition` serta helper `_spawn` di test tidak berubah. Isinya boleh sepenuhnya 2D di atas latar sederhana.
- Font baru wajib berlisensi OFL dan membawa berkas lisensinya di `assets/fonts` seperti font lain.
- Tidak menghapus atau menimpa aset yang tidak dibuat sendiri. Sprite baru adalah file baru.
- Ketentuan selesai dari `AGENTS.md` bagian 8: seluruh suite 100% PASS lewat `tools/run_tests.ps1`, smoke test native 3 lap 20 mobil, laporan di `executor-report/reports/FASE-*.md`, screenshot di `executor-report/screenshots/`.

## 5. Linimasa

| Cut | Isi | Catatan |
| :-- | :-- | :-- |
| 1 INTRO | Tiga panel masuk bergantian P3, P2, P1 dengan pegas. Tiap panel menampilkan latar, angka stensil peringkat, standee, dan mobil. Belum ada detail fokus | Semua sama terang |
| 2 FOCUS_P3 | Panel P3 melebar (flex 1,55), dua panel lain menyempit (flex 1) dan meredup. Detail P3 muncul: epithet, plat mesin, SFX | |
| 3 FOCUS_P2 | Sama untuk P2 | |
| 4 FOCUS_P1 | Sama untuk P1, mahkota sudah tampil | |
| 5 FINAL | Ketiga panel sama lebar, semua detail tampil, terang penuh | Jatuh di 6,4 dtk |

Perpindahan fokus adalah tween lebar (mock: 0,75 dtk, ease keluar kuat), bukan pergantian cut. Redup berarti kecerahan 0,5 dan saturasi 0,55 di mock.

Jumlah finisher kurang dari tiga: panel hanya dibuat untuk finisher yang ada, dan cut FOCUS yang tidak punya finisher dilewati (`playlist_for` mempertahankan pola sekarang: FOCUS_P3 butuh 3, FOCUS_P2 butuh 2, FOCUS_P1 dan INTRO butuh 1, FINAL selalu). Satu finisher: satu panel lebar penuh. Nol finisher: langsung FINAL tanpa panel, tanpa crash.

Skip tetap seperti sekarang: Enter, Spasi, atau klik di area kosong lompat ke FINAL tanpa flash. TAB saat INTRO atau FOCUS lompat ke FINAL lalu membuka tower. `Settings.reduce_motion` langsung menampilkan FINAL, tanpa tween, napas, atau sway.

## 6. Tata letak panel (ruang 1920x1080)

Dari mock. Nilai ini titik awal, bukan kontrak piksel.
- Area panel: y 70 sampai 1010 (di antara pita caution 60 px atas dan bawah), lebar melebihi layar 45 px tiap sisi. Tiga panel jajaran genjang dengan kemiringan 90 px, urutan kiri ke kanan P2, P1, P3 (urutan podium). Panel bertumpang tindih 90 px sehingga tepinya menyambung, dengan garis tinta hitam 8 px di antaranya.
- Latar panel: semburan garis radial berwarna peringkat (lime P1, cyan P2, oranye P3) di atas warna gelap peringkat, halftone, dan angka stensil peringkat raksasa pudar.
- Per panel, dari mock: angka stensil peringkat (170 px) kiri atas; kotak kanji peringkat vertikal di bawahnya; bubble close-up bulat (230 px, potret bust) kanan atas; standee (tinggi 640) berdiri di tengah; mobil di depan standee di bagian bawah (lebar 76% panel, maksimal 760); tag nama spidol (80 px) rata kanan di bawah bubble; plat hasil di dasar panel; mahkota di atas kepala standee P1.
- Detail fokus (fade dalam saat panel disorot, tampil di semua panel pada FINAL): kotak epithet, plat mesin (nama mobil dan konfigurasi mesin), SFX katakana.
- Pita caution dan plat atas/bawah yang sudah ada di scene dipertahankan. Teks plat atas mengikuti isi scene sekarang, bukan teks contoh mock. Petunjuk tombol bawah menambah `←→ Sorot`.

Elemen yang di mock keluar dari bingkai panel (mobil dan standee) harus tetap digambar di atas tepi panel dan tidak terpotong oleh bentuk panel. Bentuk panel (jajaran genjang) memotong hanya latarnya.

## 7. Kartu karakter manga toon

Kartu di Triptych menyatu dengan panel: bubble close-up bulat, kotak kanji peringkat, kotak narasi epithet, tag nama, plat hasil, SFX. Bahasa visualnya: tinta tebal, bayangan keras berwarna peringkat, screentone halftone, garis kecepatan di belakang potret, kotak narasi putih, SFX katakana yang meledak keluar dari bingkai.

| Elemen | Sumber | Status |
| :-- | :-- | :-- |
| Potret bust | `GarageRoster.portrait_path(slot)` (`radio_portrait.png`) | Ada. Dimuat sinkron 1024 px, jadi wajib dipreload sebelum cut pertama (pola garasi) |
| Tag nama | `Kit.spray_tag(driver_name)`, hasil `capture_results` | Ada |
| Angka peringkat, plat hasil | `Kit.stencil_numeral`, `_gap()`, `entry.points` (plus penanda +1 bonus lap tercepat seperti baris tower) | Ada |
| Nama mobil, mesin | `Roster.CAR_NAMES[team]`, `Roster.CAR_ENGINES[team]` | Ada. Tanpa angka tenaga |
| Epithet | Roster karakter (`DRIVER-CHARACTERIZATION-ROSTER.md`, 26 baris berurutan sama dengan slot `GtData.DRIVER_NAMES`) | Baru: array 26 string `DRIVER_EPITHETS` di `garage_roster.gd`. Kosong berarti kotak disembunyikan. Cocokkan tiap epithet dengan `GtData.DRIVER_CODES` (roster menulis kode seperti `#09 KAD`), bukan hanya dengan urutan |
| Kanji peringkat | 優勝 (P1), 準優勝 (P2), 第三位 (P3) | Baru: 3 string |
| SFX katakana | ドォン!! (P1), ザッ! (P2), ゴゴゴ (P3) | Baru: 3 string, dekor statis |
| Font berglyph Jepang | Mock memakai Dela Gothic One (OFL) | Baru. Cukup subset glyph yang dipakai (sekitar 15 karakter) lewat fontTools bila berkas penuh terlalu besar. Cek klausa nama font terpesan OFL sebelum menamai ulang subset. Berkas lisensi disertakan |

Catatan: `kinetic_standee_3d.gd` sekarang mengandalkan font OS (Yu Gothic dan lain-lain) untuk 勝者 dan merender tofu bila tidak ada. Scene baru tidak boleh bergantung pada font OS.

Standee di panel memakai `winning_scene.standee_path(id)` (RGBA 768x1376). Perilaku napas (skala 1,0 sampai 1,015 selama 2,4 dtk dengan telapak kaki tetap) dipindahkan, bukan dibuang.

## 8. Sprite mobil

Tiap mobil dibake menjadi satu PNG transparan.

- Lokasi: `assets/cars/<slug>/podium_sprite.png` untuk 13 slug di `Roster.CAR_SLUGS`, meski hanya 10 tim yang balapan, agar pilihan tim tidak pernah kehilangan sprite.
- Alat: skrip baru `tools/bake_podium_car_sprites.gd`, dijalankan native (butuh renderer, tidak bisa headless): `godot --path . -s tools/bake_podium_car_sprites.gd`. Memuat `<slug>_full.glb`, menerapkan material toon kanon, merender di `SubViewport` dengan `transparent_bg` dan `own_world_3d`, memotong ke kotak alpha plus margin kecil, menyimpan PNG. Satu skrip membake semua, satu argumen opsional membatasi ke satu slug.
- Tampilan: sama dengan mobil di game (livery toon, outline `inverted_hull_outline`, lampu depan dan belakang), sudut tiga perempat depan rendah menghadap kiri-bawah seperti mock, sudut dan jarak kamera sama untuk semua mobil, lebar mobil dinormalisasi ke piksel yang sama sehingga lebar sprite seragam dan tinggi mengikuti bentuk mobil, dasar sprite = dasar ban supaya semua mobil menapak di garis yang sama.
- Resolusi: lebar sekitar 1600 px (tampil sekitar 830 px di 1080p dan perlu tajam di 1440p), mipmap aktif.
- Kontur putih die-cut dan bayangan keras miring dari mock bukan bagian sprite. Keduanya efek runtime dari shader `canvas_item` yang sama dengan standee, supaya tebalnya konsisten.
- `_apply_hero_toon`, `_car_bounds`, dan `_light_hero_car` di `winning_scene.gd` dipindah ke alat bake (dipindah, tidak digandakan).
- Hasil bake adalah aset yang di-commit; alatnya sumber kebenaran. Bila livery atau model berubah, jalankan ulang alat. Cantumkan perintahnya di tabel perintah `AGENTS.md` bagian 3.
- Ukuran: target di bawah 1,5 MB per sprite. Bila lebih, gunakan WebP lossless (didukung impor Godot).
- Persetujuan visual: spike `temp/bake_sprites_spike.gd` sudah membake tiga mobil contoh (Mercedes, Audi, Aston) ke `temp/sprite_spike/` dan hasilnya dipasang di preview. Spike memakai SubViewport transparan, lampu dan material yang disalin dari `winning_scene.gd`, kamera di (3,0; 1,85; 5,9) menuju (0; 0,5; 0), dan menghasilkan sprite sekitar 950 px lebar dengan rasio 1,6. Alat final memperbesar ke sekitar 1600 px dan menormalisasi lebar. Setelah tampilan disetujui, bake 13 mobil dan tampilkan lembar kontak 13 sprite.
- Livery: sprite memakai livery game dari `materials/<slug>_toon_body.tres`. Aston di game bernuansa biru tua dengan aksen lime, berbeda dari gambar referensi hijau.

## 9. Pemetaan ke kode

Dipakai ulang: `graffiti_kit.gd` (`spray_tag`, `stencil_numeral`, `plate`, `crown`, `caution_tape`, `poster`), `ui_theme_tokens.gd`, `pit_wall_ui.gd`, shader halftone dan speedlines (versi `canvas_item` yang sudah ada atau port kecil), `WinningCutDirector` (timer, skip, `playlist_for`, `label`), tower [TAB] dan `toggle_leaderboard`, `capture_results`, `award_points`, `_reveal_departure`, musik.

Baru:
- Komponen panel (`winning_triptych.gd` atau serupa): latar jajaran genjang, tween lebar, redup, detail fokus, kartu.
- Shader `canvas_item` die-cut (dilasi alpha) dan outline untuk standee dan sprite mobil.
- Alat bake sprite dan 13 sprite.
- Data epithet, kanji, SFX, dan font berglyph Jepang.
- Enum `Cut` baru di `winning_cut_director.gd`: INTRO, FOCUS_P3, FOCUS_P2, FOCUS_P1, FINAL, dengan nama label masing-masing.

Dihapus dari scene ini (file lama dibiarkan): set hero 3D (`HeroSet`, `car_slot`, `turntable`), dua stasiun dinding (`wall_stations`), kamera orbit dan dolly, callout (`hero_callouts`), headline, `_wall_huds`, impact frame. Bila ada kode di `winning_scene.gd` yang menjadi mati setelah ini, hapus kode tersebut dari file itu dan catat di laporan.

## 10. Kontrak: yang dipertahankan dan yang berubah

Dipertahankan (dibaca test atau scene lain):
- `capture_results`, `award_points`, `points_for`, `format_time`, `standee_path`, `pending_results`, `capture_departure`, `setup_celebration`.
- `results`, `order`, `timing_rows` (20), `team_labels` (10), `leaderboard`, `is_leaderboard_open`, `toggle_leaderboard`, `skip_cuts`, `current_cut`, `director`.
- `name_labels` dan `time_labels`: tetap satu label per finisher dalam urutan P1 P2 P3, dan label yang benar-benar tampil di panel (bukan label tersembunyi). `name_labels[i].text` berisi nama huruf besar dan `#NN` (tim boleh di label lain, jadi format lama `#NN NAMA\nTIM` tidak wajib); `time_labels[i].text` tetap berisi gap dan "N PTS".
- Tower [TAB]: `leaderboard.position.x == 1280` saat terbuka, miring 1,2 derajat, baris berisi "+1 PT" dan "DNF".
- Siklus scene: restart ke `manga_race_transition` atau `race_weekend_world` dengan seed yang sama, exit ke `main.tscn`, musik kembali ke menu, nol orphan.
- Signal `restart_requested` dan `exit_requested`.

Berubah (test harus ditulis ulang, ini perubahan yang disengaja):
- `studio.standees` (3 `KineticStandee3D` dengan bayangan 3D): jadi 3 `TextureRect` standee. Asersi bayangan dan `outline_width` shader 3D diganti asersi tekstur dan parameter shader `canvas_item`.
- `car_slot`, `turntable`, `camera`, orbit, `HeroSet`, `wall_stations`, `hero_callouts`, `headline`, `_wall_huds`, `_impact`, `DETAIL_CAMERA_POS` dan konstanta kamera lainnya: dihapus. `toggle_leaderboard` tidak lagi menggeser `camera.h_offset`.
- `WinningCutDirector.Cut` dan label ("CUT 2/5 // HERO MACHINE" dan seterusnya): enum dan nama baru. Pola `playlist_for` tetap.
- Asersi tower: "tidak ada plat di bawah tower" tetap, tetapi diperiksa terhadap kartu dan panel, bukan `camera.h_offset`.
- Test baru: panel sama lebar di FINAL, durasi fokus sama, sprite ada untuk 13 slug dan RGBA dengan alpha, kartu memuat data finisher yang benar (nama, tim, mobil, gap, poin), DNF dan nama panjang muat, tanpa kanji tofu (font ada dan memuat glyph), preload tekstur selesai sebelum cut pertama, `reduce_motion`, panah dan klik memindah fokus, tower tidak menimpa panel.
- Berkas yang menyentuh API scene dan perlu diperiksa: `tests/test_winning_scene_and_standee.gd`, `tests/test_winning_cut_director.gd`, `tests/test_radio_and_podium.gd`, `tests/test_podium_music.gd`, `scratch/smoke_winning_scene.gd`, `scratch/capture_phase6_podium.gd`, `scratch/capture_fase84.gd`.

## 11. Input

- Enter, Spasi, klik area kosong: skip ke FINAL (tidak berubah). Setelah FINAL, klik panel tidak lagi berarti skip.
- R restart, Esc keluar ke HQ, TAB tower (tidak berubah).
- Setelah FINAL: panah kanan menggeser sorotan dalam siklus netral, P2, P1, P3, netral. Panah kiri membalik siklus. Klik panel menyorotnya, klik panel yang sedang disorot kembali ke netral. Keyboard dan klik memakai tween yang sama dengan FOCUS.
- Saat tower terbuka, wadah panel menyusut ke area kiri 1280 px supaya tidak tertimpa, dan sorotan manual tetap bisa dipakai di area itu.

## 12. Risiko dan hasil ukur

Hasil ukur mobil 3D (probe sementara, tidak di-commit), alasan keputusan 1 di bagian 2:

| Mobil | Tris `_full.glb` | Tekstur | Format |
| :-- | :-- | :-- | :-- |
| Mercedes-AMG | 287.986 | 128 MB | RGB8 tanpa kompresi (impor lossless, `vram_texture: false`) |
| Audi R8 | 296.892 | 42,7 MB | BPTC + RGTC |
| Aston Vantage | 299.062 | 32,0 MB | DXT1 + RGTC |
| Tiga mobil | 883.940 | 202,7 MB | |

Risiko:
- Tampilan sprite hasil bake mungkin lebih datar atau lebih gelap dari render referensi di mock. Mitigasi: bake contoh dan persetujuan visual sebelum membangun (bagian 8).
- Sprite statis: tidak ada turntable. Mock memakai sway horizontal kecil dan skala saat fokus, cukup untuk memberi gerak.
- Tekstur Mercedes `_full` (128 MB, tanpa kompresi) memengaruhi balapan, bukan scene ini setelah perubahan. Reimpor dengan kompresi VRAM seperti Aston akan menurunkannya ke sekitar 32 MB. Itu setting impor milik pemilik proyek, dilaporkan tapi tidak diubah.
- Beban muat saat masuk scene: sembilan tekstur (3 sprite, 3 standee, 3 potret). Muat semuanya di `_populate` sebelum `start_cuts`, dan ukur lonjakan frame saat masuk di balik wipe keberangkatan. Standee dan potret sekarang dimuat sinkron.
- Font Jepang menambah satu aset berlisensi.
- Nama panjang di panel sempit saat panel tidak disorot: `Kit.spray_tag` menyusut hingga `MIN_TAG_FONT` lalu membungkus. Panel yang menyempit (sekitar 617 px) harus tetap memuat nama terpanjang di test yang ada ("MAXIMILIAN-ALEXANDER FEATHERSTONEHAUGH").
- `WinningCutDirector.playlist_for` dan penamaan cut dipakai test lain: ikuti daftar berkas di bagian 10.

## 13. Pengujian dan selesai

TDD (Red lalu Green) di branch `fase-20-podium-triptych`. Test mengikuti konvensi proyek (`tests/test_*.gd` dijalankan lewat `tools/run_tests.ps1`), bukan gdUnit4. Selesai berarti:
1. Suite penuh 100% PASS, 0 FAIL.
2. Smoke test native: 3 lap, 20 mobil, podium, kembali ke menu, 0 orphan node, 60 FPS (p95 frame time di FINAL dan saat tween fokus, tercatat).
3. Tangkapan layar tiap cut untuk tiga kombinasi pemenang berbeda (termasuk Mercedes, Audi, Aston di podium) dan satu kasus DNF atau nama panjang, di `executor-report/screenshots/`, plus lembar kontak 13 sprite.
4. Laporan `executor-report/reports/FASE-20-PODIUM-TRIPTYCH-REPORT.md`, termasuk daftar file yang menjadi tidak terpakai.

## 14. Diserahkan ke pelaksana

Nilai parameter shader, kemiringan dan geometri panel (Polygon2D, shader, atau `Container` kustom), kurva dan durasi tween di dalam batas 1,6 dtk per cut, tata letak persis pada resolusi lain (lewat `_fit()`), posisi tepat elemen panel di panel yang menyempit, sudut kamera dan lampu bake (selama seragam), format sprite (PNG atau WebP lossless), dan susunan node. Semua ditetapkan dengan mencocokkan mock dan menjaga bagian 10.

## 15. Keputusan saya yang perlu dicek

1. Sprite dibake dan di-commit (bukan tangkapan runtime).
2. Lima cut dengan INTRO supaya FINAL jatuh di 6,4 dtk, tempat tema anthem masuk.
3. Tanpa impact frame, headline, dan callout mesin di layar ini.
4. Standee dipindah ke 2D, kelas 3D lama dibiarkan.
5. P1 hanya dibedakan lewat lime, mahkota, dan posisi tengah.
6. Epithet, kanji, SFX, dan font berglyph Jepang ditambahkan. Bila font tidak boleh, kartu tampil tanpa kanji dan SFX, dan kotak epithet tetap bisa jalan dengan font yang ada.
7. Sorotan manual dengan panah dan klik.

## 16. Musik: satu konfigurasi Music di Settings

Permintaan pemilik proyek: seluruh volume musik diatur di satu konfigurasi Music di Settings.

Hasil audit (2026-11-01):
- Semua musik sudah lewat satu pemutar (`AudioManager._music_player`) di satu bus `Music`, dan satu slider Settings (`PresentationSettings.volumes[&"Music"]`, default 0,63, disimpan di `user://presentation.cfg` kunci `audio/Music`) mengaturnya. Dua lagunya (`streetwear_synth.ogg` untuk menu, `podium_rock_anthem.mp3` untuk podium) berbagi pemutar dan bus itu. Tidak ada pemutar musik lain: `EngineRoar` di `manga_race_transition.tscn` dan suara mesin garasi ada di bus SFX.
- Tiga celah yang membuat "satu konfigurasi" belum utuh:
  1. Label slider masih `SYNTHWAVE MUSIC` (`PresentationSettings.BUS_LABELS`), padahal bus yang sama sekarang juga membawa anthem rock podium.
  2. Anthem podium lebih keras dari lagu menu pada posisi slider yang sama: ukur ffmpeg `ebur128`, menu -11,9 LUFS, podium -9,7 LUFS (selisih 2,2 LU), puncak keduanya sekitar 0 dBFS. Satu slider tidak memberi loudness yang sama untuk dua lagu.
  3. `RadioAudioDirector.duck_music` menurunkan bus Music dari `music_base_db`, nilai dB bus yang disimpan sekali di `_ready`, bukan dari konfigurasi Settings. Hari ini aman karena modal Settings hanya dibuka dari menu utama, tetapi bila volume Music berubah saat ducking atau setelah director dibuat, bus kembali ke nilai lama dan konfigurasi tidak lagi jadi satu-satunya sumber.

Perubahan:
- Label slider menjadi `MUSIC`. Hanya label; kunci `Music` dan berkas konfigurasi tidak berubah, jadi pengaturan tersimpan pemain tetap berlaku.
- Trim loudness per lagu sebagai konstanta statis di `AudioManager` (bukan opsi pemain), diterapkan ke `_music_player.volume_db` di `_set_track`: menu 0,0 dB, podium -2,2 dB. Dengan trim, slider yang sama memberi loudness terukur yang sama. Ukur ulang bila lagu diganti, dan tulis perintah ukurnya di komentar konstanta.
- Ducking relatif terhadap konfigurasi: `duck_music` menghitung dasar dari `PresentationSettings.volume(AudioManager.BUS_MUSIC)` saat dipanggil (`linear_to_db(maxf(gain, 0.001))`), bukan dari `music_base_db`. Bila Music di-mute di konfigurasi (nilai 0), ducking dan pemulihan tidak membuka mute.
- Tidak ada bus, slider, atau kunci konfigurasi baru. Master, SFX, Radio, UI tidak berubah.

Pengujian (test baru, konvensi `tests/test_*.gd`):
- Kedua lagu (`play_menu_music`, `play_podium_music`) dimainkan di bus Music, dan satu nilai `PresentationSettings.set_volume(&"Music", v)` memberi dB bus yang sama untuk keduanya.
- Setelah ducking, mengubah volume Music di konfigurasi, lalu melepas ducking, bus kembali ke nilai konfigurasi yang baru, bukan yang lama.
- Dengan Music = 0, ducking dan pemulihan membiarkan bus tetap mute.
- Selisih trim menu dan podium sama dengan selisih LUFS terukur (2,2 dB, toleransi 0,3 dB), dan label slider berbunyi `MUSIC`.
- Test yang sudah ada tentang musik podium (`tests/test_podium_music.gd`) dan scene kemenangan tetap lulus.
