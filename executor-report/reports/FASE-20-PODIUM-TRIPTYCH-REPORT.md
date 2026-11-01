# FASE 20 — Podium Triptych (P1–P3 seimbang, kartu manga, satu konfigurasi Music)

Branch: `fase-20-podium-triptych`. Agen: Claude Code (Executor, eksekusi native). Spec: `docs/superpowers/specs/2026-11-01-podium-triptych-design.md`. Rencana: `docs/superpowers/plans/2026-11-01-podium-triptych.md`. Preview konsep: https://claude.ai/artifact/7aZxpnm1xEkiPjFo7GNQdw

## 1. Ringkasan

Layar kemenangan lama memberi P1 tiga dari lima cut dan satu-satunya mobil. Sekarang layar kemenangan adalah **Triptych**: tiga panel manga miring (P2 | P1 | P3) yang selalu tampil, tiap panel berisi standee, mobil, dan kartu karakter. Lima cut satu bar (1,6 dtk): INTRO, FOCUS P3, FOCUS P2, FOCUS P1, FINAL (jatuh di 6,4 dtk, tempat tema anthem masuk). Setelah FINAL, panah kiri/kanan atau klik panel memindah sorotan.

Mobil tidak lagi dimuat sebagai model 3D saat scene berjalan: tiap mobil adalah sprite PNG hasil bake dari `<slug>_full.glb` (`tools/bake_podium_car_sprites.gd`, 13 mobil).

Musik: semua musik sudah lewat satu bus `Music` dan satu slider. Tiga celah ditutup: label slider `MUSIC`, trim loudness anthem podium -2,2 dB, ducking radio relatif terhadap konfigurasi.

## 2. Perubahan

| Area | File |
| :-- | :-- |
| Musik | `scripts/core/presentation_settings.gd` (`bus_db`, label), `scripts/audio/audio_manager.gd` (`TRACK_TRIM_DB`, `track_trim_db`), `scripts/audio/radio_audio_director.gd` (ducking dari konfigurasi) |
| Data kartu | `scripts/ui/garage_roster.gd` (`DRIVER_EPITHETS` 26, `RANK_KANJI`, `RANK_SFX`, `epithet()`, `podium_sprite_path()`) |
| Font | `assets/fonts/DelaGothicOne-Podium.ttf` (subset 4,4 KB), `DelaGothicOne-OFL.txt` |
| Sprite | `tools/bake_podium_car_sprites.gd`, `assets/cars/<slug>/podium_sprite.png` (13, lebar 1600) |
| Linimasa | `scripts/ui/winning_cut_director.gd` (`INTRO, FOCUS_P3, FOCUS_P2, FOCUS_P1, FINAL`) |
| Tampilan | `scripts/ui/winning_panel.gd`, `scripts/ui/winning_triptych.gd`, `shaders/diecut_sprite.gdshader`, `shaders/winning_panel_burst.gdshader` |
| Scene | `scripts/ui/winning_scene.gd` ditulis ulang (2D, tanpa set 3D, kamera, callout, headline, impact frame, konfeti 3D) |
| Test | `test_music_single_config`, `test_podium_data`, `test_podium_font`, `test_podium_car_sprites` (+ `podium_sprite_checks.gd`), `test_winning_panel`, `test_winning_triptych`, `test_winning_cut_director` (tulis ulang), `test_winning_scene_and_standee` (tulis ulang), `test_radio_and_podium` (asersi standee) |
| Alat bantu | `scratch/smoke_winning_scene.gd` (diperbarui), `scratch/capture_podium_triptych.gd` (baru), `AGENTS.md` (perintah bake) |

## 3. Bukti

### 3.1 Test per suite (headless, `tools/run_tests.ps1 -Filter <nama>`)

| Suite | Asersi | Hasil |
| :-- | --: | :-- |
| `test_music_single_config` | 10 | 0 FAIL |
| `test_podium_data` | 6 | 0 FAIL |
| `test_podium_font` | 4 | 0 FAIL |
| `test_podium_car_sprites` (13 sprite + 5 gerbang sintetis) | 18 | 0 FAIL |
| `test_winning_panel` | 23 | 0 FAIL |
| `test_winning_triptych` | 24 | 0 FAIL |
| `test_winning_cut_director` | 16 | 0 FAIL |
| `test_winning_scene_and_standee` (hasil, 5 cut, input, tower, restart ke grid nyata, exit ke HQ, nol orphan) | 88 | 0 FAIL |
| `test_radio_and_podium` | 35 | 0 FAIL |
| Filter `winning` (4 suite), `podium` (5), `radio` (4), `main_menu` (1), `audio_and_race` (1, 245 dtk, dijalankan di Task 1) | | 0 failing |

**Suite penuh, 93 suite, `tools/run_tests.ps1` dalam lima irisan di latar depan: 0 failing.** Irisan 0–19 (459 dtk), 20–39 (121 dtk), 40–59 (430 dtk) dijalankan sebelum perbaikan lebar tag; irisan 60–74 (281 dtk) dan 75–92 (152 dtk) sesudahnya. Perbaikan itu hanya menyentuh `winning_panel.gd`, yang hanya dipakai suite di irisan 60–92. Satu kegagalan sempat muncul di irisan 60–74 (`test_radio_and_podium`, #28): 15 dari 26 nama pengemudi nyata terpotong elipsis di tag (batas 380 px), akibat perbaikan elipsis yang saya tambahkan sendiri belakangan. Test baru memeriksa semua `GtData.DRIVER_NAMES`, lebar tag jadi 640 px dengan penskalaan ke ruang yang tersedia, lalu irisan itu hijau.

Test merah dulu (diamati gagal karena alasan yang benar) untuk tiap task; satu temuan nyata dari gerbang: sprite hasil bake pertama ditolak `PodiumSpriteChecks` karena margin bawah.

### 3.2 Native 1080p High (RTX 3050 Laptop, `scratch/smoke_winning_scene.gd`, tanpa `--race`)

Dua kali jalan. Jalan kedua: 0 FAIL, semua state 60,003 FPS dan p95 <= 16,71 ms.

| State | FPS (jalan 2) | p95 ms (jalan 1 / jalan 2) | draw call |
| :-- | --: | :-- | --: |
| FINAL sama lebar | 60,003 | 16,829 / 16,686 | 101 |
| Fokus P2 | 60,003 | 16,689 / 16,682 | 87 |
| Fokus P1 | 60,003 | 16,694 / 16,686 | 87 |
| Fokus P3 | 60,003 | 16,695 / 16,685 | 87 |
| Tower terbuka | 60,003 | 16,693 / 16,685 | 107 |
| Linimasa INTRO ke FINAL (6,2 dtk) | 60,004 | 16,701 / 16,703 | 87 |

Jalan ketiga (`-- --race`: 3 lap, 20 mobil, malam badai, High) mengulang pengukuran studio dengan hasil sama (semua state 60,002–60,003 FPS, p95 <= 16,70 ms), lalu mengukur balapan itu sendiri: **RACE 1X HIGH 60,040 FPS, p95 16,839 ms (ambang 16,8; selisih 0,039 ms), maks 20,8 ms, 1144 draw call**. Itu pelanggaran ambang di dunia balapan, kode yang tidak disentuh cabang ini (Fase 19 mencatat p95 <= 16,81 ms untuk pengukuran yang sama). Alur balapan nyata sampai podium lalu HQ lulus: studio dicapai, dunia balapan dibebaskan, wipe keberangkatan berjalan lewat frame antara, 20 hasil bertahan, kembali ke HQ dengan 0 orphan node.

Jalan pertama punya satu pelanggaran ambang (FINAL sama lebar, p95 16,829 ms terhadap batas 16,8 ms, maks 17,4 ms). Itu pengukuran pertama setelah tangkapan layar (jeda OS yang sama dengan yang dicatat di spec Fase 11) dan tidak muncul lagi di jalan kedua. Waktu proses per frame 1,2 sampai 2,5 ms. ESC dari studio kembali ke HQ dengan 0 orphan node. Pada jalan pertama Godot melaporkan 7 RID tekstur bocor saat keluar (peringatan penutupan proses, belum diselidiki).

### 3.3 Tangkapan layar (`executor-report/screenshots/phases/phase-20/`)

- Lima cut podium A (Mercedes-AMG, Audi, Aston): `a-1-intro` sampai `a-5-final`, plus `a-6-final-with-tower`.
- Podium B (BMW, Corvette, Lexus): `b-final`, `b-focus-p3`. Podium C (Honda, McLaren, Toyota): `c-final`, `c-focus-p2`.
- `d-dnf-p3-and-long-name`: P3 pensiun ("DNF // 0 PTS") dan nama 38 huruf (tag dipotong dengan elipsis).
- Keluaran `smoke_winning_scene.gd`: `triptych-cut-1-intro` dan seterusnya, `triptych-final-tab`.
- `podium-sprites-contact-sheet.png`: 13 sprite, sudut, lebar 1600, dan garis kontak ban seragam.
- Tangkapan layar native menemukan masalah yang tidak terlihat di test: angka peringkat, bubble, dan tag saling menimpa di panel 500 px saat tower terbuka. Diperbaiki dengan penskalaan konten (`content_scale`).

## 4. Keputusan dan temuan (ruling)

- Tetap di checkout utama pada branch baru, bukan git worktree (cache impor `.godot`, tekstur 200 MB, dan file `temp/` tidak ikut worktree).
- Urutan eksekusi T1, T2, T3, T4, T6, T7, T5, T8, T9, T10: enum `Cut` berubah di T5 dan scene lama memakai anggota lama sampai T8, jadi T5 dirapatkan ke T8. Satu commit (T5) membiarkan scene tidak dapat dimuat.
- Font Dela Gothic One: `OFL.txt` tidak mendeklarasikan Reserved Font Name (hanya definisi umum), jadi subset memakai nama keluarga aslinya.
- Margin trim sprite 8 px di atas, kiri, kanan, nol di bawah: cek bersama `PodiumSpriteChecks` (baris terbawah harus berisi piksel buram = garis kontak ban) menolak 13 sprite hasil bake pertama yang punya margin bawah. Alat diperbaiki, 13 sprite dibake ulang.
- Shader memakai penamaan proyek (`diecut_sprite`, `winning_panel_burst`), bukan awalan `canvas_`.
- Teks tag nama menjadi `#NN NAMA` agar `name_labels` (label yang tampil) memuat nomor sesuai kontrak spec bagian 10. Nama yang terlalu panjang dipotong dengan elipsis ("#03 MAXIM…").
- Lebar sempit saat tower terbuka: 1215 px (rencana: 1240, lalu 1230). Tower miring 1,2 derajat, kotak batasnya mulai di x=1271; 1215 menyisakan celah.
- Konten panel diskalakan turun (`content_scale` >= 0,6) pada panel di bawah 700 px agar angka peringkat, bubble, dan tag tidak saling menimpa.
- Konfeti 3D hilang bersama set 3D (scene tidak punya kamera lagi dan mock tidak memuat konfeti).
- Skip saat INTRO membiarkan panel meluncur masuk sekitar 1 dtk (tween intro tidak dibatalkan). Klik di panel yang belum selesai meluncur jatuh ke area kosong, yang juga berarti skip.

## 5. Yang tersisa untuk keputusan pemilik proyek

1. **RACE 1X HIGH p95 16,839 ms** (ambang 16,8) di dunia balapan pada jalan `--race`: selisih 0,039 ms, kode balapan tidak diubah di cabang ini. Perlu dibandingkan dengan `main` bila ingin dipastikan bukan regresi.
2. **Kode yang tidak lagi dipakai**, dibiarkan: `scripts/ui/winning_wall_cut.gd`, `winning_hero_callouts.gd`, `winning_final_hud.gd`, `kinetic_standee_3d.gd` dan `shaders/kinetic_standee.gdshader` (tanpa pemakai); `shaders/winning_impact_frame.gdshader` dan `winning_concrete.gdshader` (hanya dirujuk `tests/test_graffiti_kit.gd`); `winning_marble` dan `winning_stage_print` (sudah tanpa pemakai sebelumnya).
3. **Tekstur Mercedes `_full`** diimpor tanpa kompresi (RGB8, sekitar 128 MB) dan memengaruhi balapan, bukan lagi podium. Reimpor dengan kompresi VRAM seperti Aston menurunkannya ke sekitar 32 MB. Setting impor milik pemilik proyek, tidak diubah.
4. **File `.import` yang berubah di working tree** (suara radio, tekstur Mercedes, aset Ardennes) berasal dari reimpor Godot (perbedaan akhir baris), bukan dari pekerjaan ini. Tidak di-commit.
5. **Konfeti 3D** hilang. Menambahkan konfeti 2D adalah pekerjaan kecil bila diminta.
6. **Art standee Marco Bellini** (`assets/characters/standees/marco_bellini.png`) memuat sosok kedua dan sisa artefak di sampingnya (terlihat di `e-longest-real-names.png`). Itu aset yang sudah ada, tidak diubah.
7. `AudioManager.set_bus_volume` adalah API publik tanpa pemanggil yang bisa melewati konfigurasi Music.
8. Godot melaporkan 7 RID tekstur bocor saat keluar pada beberapa jalan smoke native (peringatan penutupan proses, belum diselidiki).
