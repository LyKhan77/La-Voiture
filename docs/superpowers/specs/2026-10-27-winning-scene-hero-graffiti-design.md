# Winning Scene: Hero Machine Graffiti (Fase 11 Langkah 7, revisi desain)

Tanggal: 2026-10-27. Menggantikan arah visual di `prompt/TASK-WINNING-SCENE-DYNAMIC-POLISH-AND-AUDIO.md`. Spec induk (pipeline standee 2.5D, reveal, hasil) tetap berlaku: `docs/superpowers/specs/2026-10-26-winning-scene-and-2.5d-character-pipeline-design.md`.

Referensi visual yang disetujui pemilik proyek:
- Mock interaktif 5 cut: https://claude.ai/artifact/9Ui2fUWtpVm2ukjcExMKw2
- Salinan lokal berkas yang sama: `docs/superpowers/specs/2026-10-27-winning-scene-hero-graffiti-preview.html`
- Perbandingan empat konsep awal: https://claude.ai/artifact/HD3hdVN2J9htRfAFTHLRxW

Mock adalah referensi komposisi, warna, dan gerak. Koordinat di mock memakai ruang 1920x1080 yang sama dengan `STAGE` di `winning_scene.gd`. Mock bukan kode produksi.

## 1. Maksud

Layar kemenangan sekarang membuat mobil juara tersembunyi di belakang driver dan piala. Rencana polish sebelumnya (orbit ±10-15°, kartu spesifikasi kanan atas) menambah dua masalah: standee 2D terlihat sebagai kertas tipis saat kamera bergeser, dan kartu spesifikasi bertabrakan dengan TimingTower saat [TAB].

Arah baru, dipilih pemilik proyek: mobil juara menjadi subjek utama (opsi A "Hero Machine"), dengan layar yang bergantian antara cut dinding driver dan cut mobil, semuanya bergaya Toon Anime Graffiti Brutalism. Pemain harus merasakan: "mobil saya menang, dan ini panggung jalanan untuk merayakannya".

## 2. Keputusan

Keputusan pemilik proyek:
- Opsi A sebagai dasar komposisi akhir: kamera rendah, mobil besar, hanya P1 berdiri di sisi mobil, P2 dan P3 sebagai chip kecil, callout spesifikasi menempel ke mobil.
- Gaya visual graffiti brutalism untuk bagian yang bergantian.
- Podium klasik tiga step dihapus (konsekuensi memilih A).

Keputusan saya (pemilik proyek boleh mengubah):
1. Lima cut: P3 tag, mobil, P2 tag, detail mobil, akhir. Total sekitar 9.5 detik (1.9 detik per cut). Pemilik proyek belum menjawab apakah lima terlalu banyak.
2. Reveal bisa dilewati: Enter, Spasi, atau klik loncat ke cut 5. R dan Esc selalu aktif di semua cut. [TAB] saat cut berjalan loncat ke cut 5 lalu membuka tower.
3. `Settings.reduce_motion` langsung menampilkan cut 5 tanpa flash dan tanpa transisi.
4. Scene tidak mengikuti tim pemain. Konsep itu ditunda sampai ada `player_team_id`.
5. Piala dan elemen sayap dihapus. Cut 5 tidak memakai piala.
6. Orbit kamera hanya di cut 2 dan 5, besar ±6° (bukan 10-15°) karena P1 di cut 5 masih standee 2D.
7. Turntable mobil berputar 0.18 rad/s (dari 0.06 rad/s), sesuai rentang 0.16-0.20 di task lama.
8. Callout spesifikasi memakai nama dari `Roster.CAR_NAMES` dan konfigurasi mesin. Angka tenaga (HP) hanya ditampilkan bila angkanya disediakan; default tanpa angka tenaga.

## 3. Tujuan, bukan-tujuan, anti-tujuan

Tujuan:
- Mobil juara terlihat penuh di cut 2, 4, dan 5.
- Tidak ada tumpang tindih antara tower [TAB] dan elemen lain di cut 5.
- Identitas visual jalanan konsisten dengan `DESIGN.md` bagian 4.3 dan `street_style.gd`.
- Anthem `podium_rock_anthem.mp3` bermain di scene ini dan musik menu kembali saat keluar.

Bukan-tujuan:
- Mengubah simulasi, data hasil, atau perhitungan poin.
- Mengikuti tim pemain.
- Data balapan baru (grafik lap, strategi ban). Itu konsep D, ditunda.
- Mengganti pipeline standee atau gambar karakter.

Anti-tujuan (gagal walau secara teknis jalan):
- Informasi hasil terkunci di belakang reveal yang tidak bisa dilewati.
- Standee 2D terlihat sebagai kertas saat kamera bergeser.
- Layar akhir lebih berantakan daripada layar sekarang.

## 4. Batasan

- Godot 4.7.2, GDScript bertipe statis. Tidak ada dependensi baru. Font baru wajib berlisensi OFL dan disertakan berkas lisensinya seperti font lain di `assets/fonts`.
- 60 FPS di 1920x1080 High. 0 orphan node setelah restart dan keluar.
- Tidak menyimpan, menghapus, atau menimpa aset yang tidak dibuat sendiri. Mulai dari aset yang ada.
- Kontrak publik yang dipakai test harus tetap ada (lihat bagian 8).
- Ketentuan selesai dari `AGENTS.md` bagian 8: seluruh suite headless 100% PASS, smoke test native, laporan di `executor-report/reports/FASE-11-LANGKAH-7-WINNING-SCENE-REPORT.md`, screenshot di `executor-report/screenshots/winning_scene/`.

## 5. Urutan cut

| Cut | Isi | Kamera | Catatan |
| :-- | :-- | :-- | :-- |
| 1 P3 tag | Poster tim ditempel, standee P3 berkontur stiker, "P3" stensil oranye, nama disemprot dengan tetesan, plat selisih waktu dan poin, tag "BRONZE LOCK" | Frontal, statis | Dinding beton, halftone |
| 2 Mobil | Mobil juara di turntable dengan cincin lime, cone lampu, coretan spidol ke mesin dan sayap belakang, plat chassis | Rendah, tiga-perempat depan, orbit ±6° | Turntable 0.18 rad/s |
| 3 P2 tag | Sama dengan cut 1, cyan, sisi cermin, tag "RUNNER-UP" | Frontal, statis | |
| 4 Detail | Dolly ke bumper dan velg depan, callout velg dan splitter | Dekat, kamera 3D sungguhan (bukan zoom 2D) | Speedlines |
| 5 Akhir | Komposisi A: mobil, standee P1 di kanan dengan mahkota, headline disemprot, chip P2 dan P3, plat P1 di poster tempel, pita caution atas dan bawah, petunjuk tombol | Rendah, orbit ±6° | [TAB] menggeser mobil dan standee ke kiri (`camera.h_offset`) |

Pergantian cut memakai impact frame 80 ms (negatif hitam-putih, dari `DESIGN.md` 4.3) memakai `manga_snapshot_invert.gdshader`, lalu cut berikutnya masuk dengan sedikit pegas (overshoot). Posisi akhir elemen mengikuti mock.

## 6. Bahasa visual

Palet: beton `#2B2D36`, acid lime `#D8FF00`, crimson `#FF1E56`, cyan `#00F0FF` (P2), oranye `#FF6B00` (P3), kertas tempel `#E8E4D6`, caution `#FFE600`. Medali P1 mengikuti lime, bukan emas.

Elemen:
- Dinding beton dengan seam panel, lubang form-tie, halftone di atasnya, wordmark LA VOITURE disemprot raksasa dan redup di belakang.
- Tag semprot: font spidol (`assets/fonts/PermanentMarker.ttf` sudah ada), kontur tinta, glow warna, tetesan cat yang bergerak pelan.
- Angka posisi stensil: perlu font stensil OFL baru (mock memakai Saira Stencil One). Jika font baru tidak boleh ditambah, pakai `Anton.ttf` dengan mask stensil.
- Poster tempel: kertas dengan tepi sobek, halftone, lakban.
- Stiker die-cut: standee dan mobil berkontur putih 5 px dengan bayangan keras miring ke kanan bawah.
- Pelat miring -12° (`street_style.gd`, `SLANT_RAD`), pita caution, stempel mahkota untuk P1.

## 7. Pemetaan ke kode

Dipakai ulang: `halftone_screentone.gdshader`, `inverted_hull_outline.gdshader`, `manga_snapshot_invert.gdshader`, `manga_speedlines.gdshader`, `winning_reveal.gdshader` (pola wipe), `street_style.gd`, `kinetic_standee_3d.gd`, `UI`/`T` helper di `winning_scene.gd`.

Baru:
- Kontur die-cut di `kinetic_standee.gdshader` (pass dilasi alpha, parameter ketebalan).
- Shader dinding beton, menggantikan `winning_marble` dan `winning_stage_print` untuk scene ini.
- Komponen tag semprot (label, mask erosi, tetesan lewat `Tween`).
- Poster sobek (alpha mask) dan lakban.
- Timeline cut di `winning_scene.gd` (`Tween` atau mesin state kecil), termasuk skip.
- Data spesifikasi mobil per slug di `garage_roster.gd` (konfigurasi mesin untuk 10 mobil).
- `AudioManager.play_podium_music()` dan `play_menu_music()`.

Dari `winning_scene.gd` yang ada dihapus atau diganti: tiga step podium, medal trim, numeral Label3D, piala, kartu bawah tiga kolom, marmer. Dipertahankan: `capture_results`, `award_points`, `capture_departure`, `_reveal_departure`, `toggle_leaderboard`, TimingTower, tombol aksi, `_apply_hero_toon`, `_light_hero_car`.

Cut dinding (1 dan 3) boleh dibuat sebagai "stasiun" 3D dengan kamera frontal terkunci (standee tetap `KineticStandee3D` dan memberi bayangan ke dinding) atau sebagai lapisan 2D. Pilihan diserahkan ke pelaksana, selama kontrak di bagian 8 terjaga.

## 8. Kontrak yang tidak boleh rusak

Test yang ada membaca member publik `winning_scene.gd`:
- `standees`: 3 `KineticStandee3D` dengan `mesh_instance`, `material` (parameter `albedo_texture` = `standee_path(id)`), bayangan aktif.
- `name_labels[place].text` berisi nama driver huruf besar, `time_labels[2].text` berisi teks selisih dan poin.
- `order`, `results`, `car_slot` (anak pertama `scene_file_path == Roster.car_path(0)`), `turntable`, `camera`.
- `leaderboard.position.x == 1280` saat terbuka, `is_leaderboard_open`, `timing_rows.size() == 20`, `team_labels.size() == 10`, baris berisi "+1 PT" dan "DNF".
- Orbit berhenti saat tower terbuka.
- Siklus scene: restart ke `manga_race_transition` atau `race_weekend_world`, exit ke `main.tscn`, tanpa node tertinggal.

Test yang memang harus diubah: kecepatan turntable (sekarang menegaskan 0.06 rad/s), dan asersi orbit "bergerak" (orbit baru hanya aktif di cut 2 dan 5). Test baru: urutan cut, skip, `reduce_motion`, pemanggilan musik, kontur die-cut aktif di standee.

## 9. Audio

- `_ready()` memanggil `AudioManager.play_podium_music()`. Menghentikan musik yang berjalan, memakai `podium_rock_anthem.mp3` berulang di bus `Music`.
- Keluar lewat Esc atau tombol memanggil `play_menu_music()` (kembali ke `streetwear_synth.ogg`).
- Restart: pelaksana memeriksa siapa yang mengurus musik saat balapan dimulai dan memastikan anthem tidak bocor ke balapan.
- Berkas `melodic-anime-rock-victory-anthem-triump-cmvpjcf7.mp3` adalah duplikat byte yang sama (938.0K) dan tidak dipakai. Jangan dihapus tanpa izin pemilik proyek.
- BPM anthem belum diukur. Jika bisa diukur, durasi cut dibulatkan ke bar penuh. Jika tidak, tetap 1.9 detik.

## 10. Risiko yang diketahui

- Lima cut menambah sekitar 9.5 detik sebelum layar akhir terbaca. Skip dan `reduce_motion` adalah mitigasinya.
- Standee P1 di cut 5 tetap 2D di ruang 3D. Orbit dibatasi ±6°. Jika terlihat tipis, kunci orbit di cut 5.
- Font stensil baru menambah satu aset berlisensi.
- Angka tenaga mobil tidak ada di data. Jangan mengarang. Tampilkan hanya yang tersedia.
- Pemenang selalu mobil dari 10 slug yang ada. Callout dan posisi coretan di mock dikalibrasi untuk Mercedes-AMG. Posisi titik mesin dan sayap harus dihitung per mobil dari bounds model (pola `_light_hero_car`), bukan koordinat tetap.

## 11. Yang diserahkan ke pelaksana

Nilai parameter shader, durasi tween di dalam 1.9 detik, tata letak persisnya pada resolusi lain (lewat `_fit()`), apakah cut dinding 3D atau 2D, pemilihan font stensil, dan susunan node. Semua ditetapkan dengan mencocokkan mock dan menjaga bagian 8.
