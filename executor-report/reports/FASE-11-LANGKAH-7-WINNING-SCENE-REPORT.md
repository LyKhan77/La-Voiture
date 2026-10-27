# FASE 11 / LANGKAH 7 — Winning Scene Studio & Kinetic Character

**Tanggal:** 26 Oktober 2026  
**Status:** Implementasi fungsional terverifikasi; **gate global TERTAHAN**, bukan seluruh fase selesai.  
**Keputusan pengguna:** terbitkan laporan gate tertahan; jangan memperluas perubahan ke optimasi global sirkuit/VFX/transisi di luar izin yang sudah diberikan.

## 1. Hasil utama

- Scene mandiri `scenes/ui/winning_scene.tscn` menggantikan overlay podium lama. Balapan menyimpan snapshot nilai hasil akhir, lalu membebaskan world sirkuit sebelum studio mengambil alih viewport.
- Pipeline Pillow/NumPy menghasilkan **20 PNG 768×1376 RGBA** di `assets/characters/standees/`, termasuk `kaze_ryu.png`, `makoto_ito.png`, dan `arthur_sterling.png`. Seluruh output memiliki rentang alpha 0–255. Tidak ada model karakter 3D baru, dependensi baru, atau perubahan pada gambar mentah `reference-assets/characters/`.
- `KineticStandee3D`: QuadMesh tegak 1,05×1,85 m, alpha-scissor silhouette shadow, diffuse cel lighting, rim warna tim, micro sway, breathing 2,4 detik dengan telapak tetap di podium, serta hologram 勝者 dan partikel speedline untuk P1.
- Podium obsidian/marmer 0,8 / 0,5 / 0,3 m, trim emas/perak/perunggu, trofi prosedural emas, turntable diameter 6,5 m pada 0,06 rad/detik, tiga spotlight volumetrik, kabut, confetti, dan lampu mobil. Model P1 diambil dari `assets/cars/<slug>/<slug>_full.glb` sesuai hasil balapan.
- TAB/klik membuka timing tower 20 pembalap dan 10 konstruktor dengan tween reversibel 0,25 detik. Waktu klasifikasi memasukkan penalti yang belum dilayani; DNF dan lapped car dibedakan; bonus fastest lap hanya untuk finisher top ten.
- R/klik restart mempertahankan konfigurasi balapan. Jalur standalone tanpa draft menu mempertahankan jumlah lap, seed simulasi, seed lampu start, dan archetype cuaca. ESC/klik EXIT TO HQ kembali ke menu utama.

## 2. File dan cutover

### File baru

- `scratch/process_character_cutout.py`
- `assets/characters/standees/*.png` — 20 cutout lokal
- `scripts/ui/kinetic_standee_3d.gd`
- `scripts/ui/winning_scene.gd`
- `scenes/ui/winning_scene.tscn`
- `shaders/kinetic_standee.gdshader`
- `shaders/winning_marble.gdshader`
- `shaders/winning_reveal.gdshader`
- `tests/test_winning_scene_and_standee.gd`
- `scratch/smoke_winning_scene.gd`

### File lama yang dimigrasikan dengan izin pengguna

- `scripts/world/race_weekend_world.gd`
- `tests/test_audio_and_race_weekend.gd`
- `tests/test_radio_and_podium.gd`
- `tests/test_main_menu_flow.gd`
- `tests/test_track_incidents_and_stewards.gd`
- `scratch/capture_fase84.gd`
- `scratch/capture_phase6_podium.gd`
- `scratch/capture_safety_car_cinematic.gd`
- `scratch/smoke_incidents_stewards.gd`
- `scratch/smoke_langkah2.gd`
- `scratch/smoke_pitcrew_visual.gd`

Overlay usang `scripts/ui/podium_screen.gd`, sidecar UID-nya, dan `scenes/ui/podium_screen.tscn` dihapus setelah consumer dimigrasikan. Tidak ada alias kompatibilitas `PodiumScreen` atau properti `world.podium`. `show_podium()` sekarang memicu perpindahan scene, bukan mengembalikan overlay. Enam probe historis lolos `--check-only`; skenario native lengkap keenam probe tersebut tidak dijalankan ulang dalam tugas ini.

## 3. Pipeline cutout dan batasnya

Sumber adalah model sheet multi-pose, bukan foto satu karakter. Pipeline memakai crop/polygon per sheet untuk memilih tubuh utama, edge-connected flood fill, perlindungan tinta/area abu-abu tertutup, cleanup bayangan studio, matte tepi, decontamination, dan resampling ke ukuran sumber dengan telapak di dasar kanvas.

Verifikasi visual memperbaiki beberapa masalah yang tidak tertangkap pemeriksaan keberadaan file: bayangan lantai Arthur, sleeve Makoto yang terpotong crop, pose Luca yang terpotong, sisa latar antara kaki Sora/Ren, dan pose tumpang tindih Shinjiro. Tiga karakter prototipe diperiksa penuh; contact sheet seluruh roster juga diperiksa.

**Batas:** koordinat crop/polygon dikalibrasi untuk sheet saat ini. Mengganti ilustrasi sumber memerlukan kalibrasi dan review ulang; ini bukan segmentasi semantik universal. Nama folder seni mengikuti mapping `GarageRoster` yang sudah ada. Identitas UI tetap menggunakan `GtData`/hasil balapan aktual: misalnya artwork Arthur berada pada slot runtime T. Kade/Razorline. Roster maupun nama pembalap tidak diubah untuk memaksa label contoh desain.

Kanji memakai `SystemFont` CJK Windows (Yu Gothic/Meiryo dan fallback). Glyph 勝者 terlihat pada capture native workstation ini. Font CJK belum dibundel; ketersediaan glyph pada host lain tidak dijamin.

## 4. Pengujian headless

**Hasil full run: 36/36 suite PASS, seluruh process exit code 0, 0 timeout.** Dua suite agregator memakai `--skip-legacy` karena suite lama sudah dijalankan masing-masing; `test_race_world` memakai `--fixed-fps 60` sesuai kontraknya. Ini bukan pengurangan jumlah suite.

Suite baru terakhir dijalankan setelah koreksi render/aset: **47 assertion, 0 FAIL**. Cakupan perilaku mencakup:

- urutan klasifikasi dan penalti finis;
- kelayakan bonus fastest lap dan penjumlahan poin konstruktor;
- snapshot tidak bergantung pada mutasi simulator;
- 20 cutout transparan dan pemilihan seni masing-masing finisher;
- shadow casting, telapak yang tetap menapak selama breathing, model mobil P1;
- rotasi turntable, dolly, TAB saat tombol memiliki fokus, pembalikan tween cepat;
- restart konfigurasi menu dan restart standalone;
- race → studio → HQ dengan pelepasan world dan **0 orphan node**.

Ringkasan full run tersimpan di `temp/winning-suite-summary.log`; stdout/stderr per suite di `temp/winning-test_*.{stdout,stderr}.log`.

```text
PASS test_winning_scene_and_standee
PASS test_track_incidents_and_stewards
PASS test_main_menu_flow
PASS test_radio_and_podium
PASS test_audio_and_race_weekend
PASS test_radio_r2
PASS test_track_environment
PASS test_safety_car_cinematic
PASS test_car_dynamics_vfx
PASS test_race_weekend_and_physics
PASS test_pitcrew_visual
PASS test_weather_ladder
PASS test_race_hud
PASS test_pit_deck_and_radio
PASS test_gt_sim
PASS test_hud_theme_and_telemetry
PASS test_deck_n2
PASS test_pit_wall
PASS test_garage_tyre_strategy
PASS test_audi_r8_chassis
PASS test_mercedes_amg_chassis
PASS test_visual_polish_and_consistency
PASS test_pit_lane
PASS test_circuit_minimap
PASS test_mclaren_720s_chassis
PASS test_lexus_rcf_chassis
PASS test_chevy_corvette_chassis
PASS test_honda_nsx_chassis
PASS test_lambo_huracan_chassis
PASS test_bmw_m4_chassis
PASS test_aston_vantage_chassis
PASS test_nissan_gtr_chassis
PASS test_weather_and_ai
PASS test_modular_car
PASS test_race_world
PASS test_simulation_verification
TOTAL 36/36 PASS; 0 FAIL
```

Self-test pipeline: `self-test: PASS (7 checks)`, termasuk latar transparan, pakaian abu-abu tertutup, tinta hitam, alpha parsial, decontamination tepi, dimensi, dan penempatan telapak.

## 5. Native 1080p High — pengukuran aktual

**Engine:** Godot 4.7.2 stable, Vulkan Forward+.  
**GPU:** NVIDIA GeForce RTX 3050 Laptop GPU.  
**Resolusi:** 1920×1080; High; render scale 1,0 pada race; tanpa proses suite headless berjalan saat pengukuran akhir.  
**Metode:** sampel wall-clock antar-frame, setelah warmup; race diukur pada 1× lalu dipercepat 16× hanya untuk menyelesaikan siklus tiga lap. Statistik di bawah bukan statistik balapan pada 16×.

| Skenario | Frame sampel | FPS rata-rata | Rata-rata ms | P95 ms | Maksimum ms | CPU process ms terakhir | Draw call frame terakhir |
|---|---:|---:|---:|---:|---:|---:|---:|
| Studio clean, 10 detik | 602 | 60,199 | 16,6115 | 16,6820 | 16,8970 | 1,5190 | 241 |
| Studio timing, 5 detik | 302 | 60,398 | 16,5568 | 16,6920 | 17,1700 | 1,6380 | 252 |
| Race 1×, 3 lap/20 mobil/malam-hujan, 8 detik | 390 | 48,642 | 20,5582 | 34,2270 | 429,8660 | 21,0650 | 1336 |

Studio memenuhi pacing sekitar 60 Hz pada sampel ini. Probe menyatakan toleransinya secara eksplisit: rata-rata ≥59,9 FPS dan P95 ≤16,8 ms, karena satu periode 60 Hz adalah 16,666… ms. **Bukan bukti bahwa setiap frame selalu ≤16,66 ms**: nilai maksimum aktual tetap dicantumkan.

**Gate global 60 FPS balapan TIDAK LULUS.** `smoke_winning_scene.gd -- --race` berakhir **exit 1 / 1 FAIL**, bukan pass yang disamarkan. Threshold tidak diturunkan menjadi gate 50 FPS yang dipakai beberapa probe lama. Log sebelumnya `temp/native_smoke.txt:20` juga mencatat race sekitar 55,38 FPS; itu skenario berbeda, bukan benchmark A/B yang membuktikan besar regresi atau penyebabnya. Profiling sirkuit/VFX dan budget render global diperlukan untuk menutup gate ini; pengguna memilih tidak memperluas scope pada eksekusi ini.

Log akhir yang dapat dibaca: `temp/winning-native-final.log`.

### Alur native yang lulus

- Tiga lap, 20 mobil, cuaca malam-hujan mencapai studio melalui finis sungguhan.
- World lama sudah bebas ketika studio tampil; 20 baris hasil aktual tetap tersedia.
- Frame race masuk ke negative snap/manga wipe; uniform progress benar-benar melewati nilai antara; overlay snapshot dibebaskan setelah reveal.
- TAB dan ESC diuji lewat input keyboard, bukan hanya signal emit.
- Race → studio → HQ selesai, **0 orphan node** setelah pelepasan.
- Tidak ada script error pada run native akhir. Error tween uniform yang ditemukan pada run sebelumnya diperbaiki memakai setter shader eksplisit melalui `tween_method()` dan diuji ulang lewat finis sungguhan.

## 6. Bukti visual native

Seluruh PNG berikut adalah tangkapan renderer native **1920×1080**, bukan mockup:

- [Clean cinematic — fixture Ryu/Ito/artwork Arthur](../screenshots/winning_scene/clean-cinematic.png)
- [Expanded timing tower](../screenshots/winning_scene/expanded-timing-tower.png)
- [Close-up karakter, trofi, dan bayangan siluet nyata](../screenshots/winning_scene/kaze-ryu-shadow-closeup.png)
- [Finis balapan aktual — S. Ren / K. Ryu / V. Sokol](../screenshots/winning_scene/actual-race-finish.png)

Fixture tiga karakter hanya untuk screenshot representatif. Snapshot finis aktual berasal dari simulator; pemenang tidak dipaksa menjadi Kaze Ryu.

## 7. Retensi resource dan gate yang tetap terbuka

**0 orphan node sudah diukur; ini tidak disamakan dengan 0 resource tertahan.**

1. Shutdown Vulkan masih mencetak `WARNING: 7 RIDs of type "Texture" were leaked.` Warning yang sama ada pada log native fase sebelumnya (`temp/native_smoke.txt:28`). Penyebab internalnya belum ditetapkan; tidak disembunyikan dan bukan klaim seluruh tekstur GPU bebas.
2. Suite baru menghasilkan warning **53–54 ObjectDB/RefCounted** saat process exit pada jalur restart manga. Probe isolasi menghasilkan 0 leaked instance untuk studio kosong, world → studio langsung, dan restart standalone; jalur restart melalui manga mereproduksi 54. Ini mempersempit jalur masalah, **bukan bukti penyebab engine tertentu atau perbaikan tuntas**. Berkas bukti diagnosis: `temp/refcount-{empty,world,restart,standalone}.log`. Pengguna memilih memasukkannya sebagai gate tertahan, bukan memperluas perubahan transisi di eksekusi ini.
3. Pengujian native hanya dilakukan pada GPU/workstation tersebut. Tidak ada klaim export Web, mesin lain, atau sesi soak panjang.

## 8. Review dan keputusan implementasi

Skill gamedev yang digunakan: `router`, `godot-gdscript`, `godot-3d-essentials`, `godot-shaders`, `godot-ui-control`, `game-ui-ux`, dan `godot-gdscript-headless-testing`.

Dua review read-only memeriksa lifecycle/scoring serta shader/render/UI. Perbaikannya:

- konsumsi key R/ESC sebelum `change_scene_to_file()` melepas viewport;
- pertahankan seed/lap untuk restart standalone;
- hindari perkalian ALBEDO dua kali dalam custom lighting dan normalkan diffuse dengan PI;
- pulihkan High/1080p/render scale setelah HQ me-load preferensi tersimpan;
- verifikasi ulang reveal pada renderer native, bukan hanya headless.

Keputusan/ruling yang diambil:

- Memproses seluruh 20 seni roster, bukan tiga saja, agar setiap kombinasi podium memakai karakter yang benar. Biaya: tambahan PNG turunan dan hint per sheet.
- Bekerja pada workspace yang secara eksplisit diizinkan tanpa worktree/commit, sesuai rencana yang disediakan. Biaya: tidak ada isolasi branch baru.
- Memigrasikan consumer dan pengujian perilaku ke studio 3D; tidak mempertahankan assertion pixel-layout atau alias overlay 2D. Biaya: probe lama harus dimigrasikan, bukan dijalankan lewat shim.
- Mempertahankan identitas runtime dan mapping seni yang ada; tidak mengubah nama/karakteristik driver untuk menyamakan label folder referensi.
- Membatasi gerak kamera pada dolly/arc kecil agar standee 2.5D tetap terbaca dari depan; tidak menambah kamera bebas 360° atau sistem rig karakter.
- Menggunakan material/shader dan mesh trofi prosedural lokal; tidak ada generasi aset berbayar atau karakter rig 3D yang tidak diminta.

## 9. Reproduksi

```powershell
python scratch/process_character_cutout.py --self-test
python scratch/process_character_cutout.py                 # output yang ada dilewati
# --force hanya untuk sengaja meregenerasi PNG turunan milik pipeline ini.

godot --headless --editor --path . --import
godot --headless --path . -s res://tests/test_winning_scene_and_standee.gd

godot --path . -s res://scratch/smoke_winning_scene.gd -- --captures-only
godot --path . -s res://scratch/smoke_winning_scene.gd
godot --path . -s res://scratch/smoke_winning_scene.gd -- --race
```

Perintah terakhir memang diharapkan tetap melaporkan gagal selama gate FPS race global di atas belum diperbaiki. Untuk log CLI Godot gunakan path filesystem absolut pada `--log-file`, bukan `res://`, karena logging awal diinisialisasi sebelum resolver proyek tersedia.

**Kesimpulan:** fitur winning scene, karakter kinetik, leaderboard, cutover, bukti visual, dan pengujian fungsional telah diterbitkan. Status fase tetap **TERTAHAN pada gate global performa/resource**, sesuai keputusan pengguna; laporan ini tidak menyatakan seluruh Definition of Done sudah terpenuhi.

## 10. Koreksi visual setelah playtest — toon anime

**Masalah yang dilaporkan pengguna:** winning scene belum mengikuti tema toon anime.

**Akar masalah:** studio memuat `<slug>_full.glb` langsung, sehingga tidak menjalankan override material toon pada scene chassis. Mobil tetap memakai material PBR impor; lantai, podium, dan trofi juga menggunakan metallic/specular lembut dengan reflection probe. Karakter anime saja tidak cukup menyelaraskan seluruh panggung.

### Perubahan lokal

- `scripts/ui/winning_scene.gd` menerapkan material resmi `materials/<slug>_toon_body.tres` pada permukaan paint serta `toon_carbon_aero.tres` pada fender liner. Livery resmi tetap dipakai, tanpa mengubah GLB/tekstur sumber.
- Seluruh material roda dikonversi ke shader cel bersama, mempertahankan warna/tekstur sumber, dengan ink hull tipis 6 mm. Satu material per sumber dipakai ulang oleh keempat roda.
- Trofi dan lantai memakai `ToonMaterials`; podium/turntable memakai marmer grafis dua-band dengan urat tegas, screentone, dan ink hull 18 mm.
- `shaders/winning_marble.gdshader` tidak lagi memakai metallic/refleksi PBR. `shaders/winning_stage_print.gdshader` menambahkan backdrop Ben-Day dots, tinta hitam, dan pita acid-lime.
- Reflection probe studio dihapus; bloom dimatikan, fog dikurangi, tonemap linear dan bayangan tajam diterapkan khusus scene ini. Spotlight, confetti, lampu mobil, turntable, ilustrasi karakter, scoring, serta kontrol tetap tersedia.
- Tidak ada perubahan pada shader/material global, seni mentah, roster, atau konfigurasi sirkuit.

### Verifikasi koreksi

Native Godot 4.7.2 / Vulkan Forward+ / RTX 3050 Laptop, 1920×1080 High:

|Mode studio|Sampel|Rata-rata frame|FPS rata-rata|p95|Maksimum frame|Draw calls|
|:---|---:|---:|---:|---:|---:|---:|
|Clean cinematic|602 frame / 10 detik|16,6116 ms|60,199|16,7110 ms|17,5850 ms|396|
|Timing tower terbuka|302 frame / 5 detik|16,5572 ms|60,397|16,7270 ms|17,2490 ms|409|

`godot --path . -s res://scratch/smoke_winning_scene.gd` menghasilkan **0 FAIL**: tiga capture native, TAB membuka leaderboard, ESC membebaskan studio dan kembali ke HQ, **0 orphan node**. Batas pacing probe adalah ≥59,9 FPS dan p95 ≤16,8 ms; tabel tidak membuktikan setiap frame ≤16,66 ms.

Probe sementara menjalankan jalur material baru pada **10 mobil / 420 permukaan**: seluruhnya memakai cel/ink, tekstur livery resmi tetap terpasang, warna roda tetap sama, dan material roda bersama tidak diduplikasi per roda. Probe awal membandingkan identitas resource tekstur GLB dengan PNG eksternal dan gagal; pemeriksaan diperbaiki menggunakan resource livery resmi yang memang dipakai chassis, bukan menyamakan dua identitas resource berbeda.

Capture clean, expanded, dan close-up pada bagian 6 telah diperbarui dan diperiksa visual. Capture `actual-race-finish.png` tetap bukti balapan aktual **sebelum koreksi visual ini**, bukan capture ulang versi toon.

**Batas tetap:** warning shutdown Vulkan `7 RIDs of type "Texture" were leaked` masih muncul. Gate performa balapan malam/hujan dan retensi restart manga pada bagian 7 tidak dinyatakan selesai; skenario race penuh tidak dijalankan ulang untuk koreksi material lokal ini.

Regresi setelah koreksi: **36/36 suite headless PASS**, seluruh exit code 0, tidak ada timeout atau `SCRIPT ERROR`/`ERROR`/assertion gagal. Suite winning scene sendiri menghasilkan **47 assertion / 0 FAIL**. Opsi agregator dan fixed-fps sama dengan bagian 4; log tiap suite dan hasil terstruktur disimpan di `temp/winning-toon-tests/`.

Satu warning headless tetap tercatat: **55 ObjectDB instances leaked at exit** pada `test_winning_scene_and_standee.err.log`, dibanding 53–54 pada pengukuran sebelumnya. Ini tidak dinyatakan sebagai 0 resource tertahan atau disamakan dengan hasil 0 orphan node. Tidak ada warning headless lain pada run ini. Probe dan runner sementara telah dibersihkan; harness smoke permanen tetap tersedia.

---

## Addendum: Revisi Hero Machine Graffiti (2026-10-27)

Spec: `docs/superpowers/specs/2026-10-27-winning-scene-hero-graffiti-design.md`. Rencana: `docs/superpowers/plans/2026-10-27-winning-scene-hero-graffiti-plan.md`. Arah ini menggantikan polish di `prompt/TASK-WINNING-SCENE-DYNAMIC-POLISH-AND-AUDIO.md`.

### Yang berubah

- Podium tiga step, trofi, dan kartu bawah tiga kolom dihapus. Mobil juara berdiri di turntable di origin; P1 berdiri di sisinya. P2 dan P3 berdiri di dua stasiun dinding beton di x = ±30.
- Lima cut bergantian: P3 tag, mobil, P2 tag, detail mobil, akhir (1,9 detik per cut). Urutan ditangani `WinningCutDirector` (`scripts/ui/winning_cut_director.gd`); finisher yang kurang dari tiga melewati cut dindingnya, tanpa finisher langsung ke akhir.
- Gaya Toon Anime Graffiti Brutalism: `graffiti_kit.gd` (tag semprot dengan tetesan, angka stensil, poster sobek, pita caution, mahkota, catatan spidol), `winning_wall_cut.gd`, `winning_hero_callouts.gd`, `winning_final_hud.gd`.
- Shader baru: `winning_concrete`, `winning_impact_frame` (impact frame 80 ms), `winning_caution_tape`; kontur stiker die-cut ditambahkan ke `kinetic_standee.gdshader`.
- Orbit kamera ±6° hanya di cut mobil dan akhir; turntable 0,18 rad/s; tower [TAB] menjadi poster kertas miring 1,2° yang masuk dari kanan (`leaderboard.position.x` tetap 1280).
- Skip: Enter, Spasi, atau klik; [TAB] di tengah cut melompat ke akhir lalu membuka tower; `reduce_motion` langsung ke cut akhir tanpa flash dan tanpa tween tetesan.
- Musik: `AudioManager.play_podium_music()` saat masuk, `play_menu_music()` saat R atau Esc (`start_music()` tidak memutar ulang track yang sedang jalan, jadi tanpa ini anthem akan bocor ke balapan berikutnya).
- Data: `Roster.CAR_ENGINES` (konfigurasi mesin 10 mobil, dari pengetahuan umum, **perlu diperiksa sebelum rilis**). Angka tenaga sengaja tidak ditampilkan.
- Font: `assets/fonts/SairaStencilOne-Regular.ttf` (+ `SairaStencilOne-OFL.txt`), OFL, diunduh dari repo Google Fonts.

### Verifikasi

- Suite headless: **39/39 bersih** (36 lama + `test_podium_music` 7, `test_winning_cut_director` 15, `test_graffiti_kit` 15 assertion). `test_winning_scene_and_standee`: **97 assertion / 0 FAIL** (sebelumnya 47). `test_audio_and_race_weekend` memakan sekitar 8 menit; seluruh suite sekitar 30 menit.
- Smoke native (`godot --path . -s res://scratch/smoke_winning_scene.gd`), RTX 3050 Laptop, 1920x1080 High, **0 FAIL**:

|Mode|Sampel|Rata-rata|FPS|p95|Maks|Draw calls|
|:---|---:|---:|---:|---:|---:|---:|
|Cut akhir|601 frame / 10 s|16,6659 ms|60,003|16,681 ms|16,756 ms|190|
|Tower terbuka|301 frame / 5 s|16,6658 ms|60,003|16,676 ms|16,705 ms|190|

Dua run berturut-turut sesudah perbaikan review: 0 FAIL. Catatan pengukuran: menyimpan PNG tepat sebelum sampel memunculkan satu stall 300–390 ms (terbukti oleh run tanpa penyimpanan PNG: 60,199 FPS, maksimum 16,9 ms), jadi `_measure` sekarang menunggu 1,5 detik sebelum mengambil sampel.
- Screenshot native: `executor-report/screenshots/winning_scene/hero-graffiti-cut-1.png` sampai `-cut-5.png`, `hero-graffiti-final-tab.png`, `hero-graffiti-standee-closeup.png`. Screenshot lama tidak ditimpa. `actual-race-finish.png` tetap bukti balapan sebelum revisi ini.
- Probe shader native (`SHADER ERROR` nol) menangkap satu bug nyata: `return` tidak boleh di `fragment()`; outline stiker memakai flag.

### Batas dan catatan

- Jalur balapan penuh (`--race`) tidak dijalankan ulang untuk revisi ini. Warning shutdown `7 RIDs of type "Texture" were leaked` masih muncul seperti di laporan sebelumnya.
- `test_winning_scene_and_standee` sekarang memuat `race_weekend_world.tscn` di thread utama sebelum menekan R. Tanpa itu langkah restart gagal secara acak di baseline (preload siklik saat pertama kali dimasuki dari loader thread transisi). Perbaikan akar masalah itu belum dilakukan dan di luar lingkup revisi ini.
- Hologram kanji kemenangan P1 (`kinetic_standee_3d.gd`) tetap ada; di cut akhir ia terlihat sebagai blok lime di belakang bahu P1.
- Cadangan berkas yang diedit: `temp/backup_winning_graffiti/` (tidak ikut git).

### Addendum 2: Polishing Visual Detail & Beat-Sync Audio (2026-10-27)

Pembaruan lanjutan untuk menuntaskan sinkronisasi audio dan pemolesan visual detail:

1. **Sinkronisasi Beat Audio 150 BPM (Beat-Synced Cuts)**:
   - Audio `podium_rock_anthem.mp3` dianalisis secara spektral dan terbukti memiliki tempo presisi **150.0 BPM** (1 beat = 0,40 detik, 1 bar 4/4 = 1,60 detik).
   - Durasi cut di `WinningCutDirector` (`CUT_SECONDS`) disinkronkan menjadi **1,60 detik** (sebelumnya 1,9 detik).
   - Transisi ke Cut 5 (Final Tableau) sekarang mendarat tepat pada ketukan pertama Bar 5 (detik 6,40), di mana drop instrumen rock klimaks meledak.
   - `_elapsed` kini di-reset ke `0.0` saat cut berganti, mengeliminasi jitter/drift dan menyelesaikan cacat lama di mana frame drop awal dapat memotong durasi cut.
2. **Manga Speedlines pada Cut 4 (Car Detail Cut)**:
   - Overlay canvas `_speedlines` berbasis `shaders/manga_speedlines.gdshader` dipasang di `WinningScene`.
   - Garis aksi manga dinamis (warna Acid Lime, Punk Cyan, Crimson) menyala terfokus saat kamera melakukan dolly close-up ke velg forged BBS FI-R dan carbon splitter.
3. **Spring Overshoot Easing (Pop-In Anime)**:
   - Elemen HUD dinding beton (P2/P3) dan final HUD kini muncul menggunakan transisi pegas membal (`Tween.TRANS_BACK` + `Tween.EASE_OUT`) dari skala 0.88–0.92 ke 1.0, memberikan impresi visual tag stensil yang ditembakkan secara bertenaga ke layar.
4. **Failsafe Audio Cleanup di `_exit_tree()`**:
   - `_exit_tree()` dihubungkan langsung ke `_hand_back_music()`, menjamin pemulihan musik menu synthwave secara aman saat scene kemenangan dilepas dari scene tree tanpa bergantung pada tombol UI.
5. **Aksen Livery Tim Pemenang & Konfeti Dinamis**:
   - Material konfeti 3D (`confetti.draw_pass_1.material`) dan styling hover/focus tombol navigasi (`[TAB]`, `[R]`, `[ESC]`) kini otomatis mengadopsi warna signature livery tim juara (`Liveries.color_for()`).
6. **Proteksi Teks Meluber (Driver Name Auto-Wrap & Trim)**:
   - Label nama driver di `winning_final_hud.gd` (`p1_name`, `chip_name`) dibekali batas `custom_minimum_size`, `AUTOWRAP_WORD_SMART`, dan `OVERRUN_TRIM_ELLIPSIS`, plus pengecilan ukuran font otomatis bila nama melampaui 16 karakter.

### Verifikasi Akhir
- **39 Test Suites Headless Godot**: **100% PASS, 0 FAIL**.
- `test_winning_scene_and_standee.gd`: **98 assertions / 0 FAIL**.
- `test_podium_music.gd`: **7 assertions / 0 FAIL**.
- `test_winning_cut_director.gd`: **15 assertions / 0 FAIL**.
- `test_graffiti_kit.gd`: **16 assertions / 0 FAIL**.
- **Native Smoke Test (RTX 3050 Laptop GPU, 1920x1080 High)**: **0 FAIL, 60 FPS locked, 0 orphan nodes**.
- Tangkapan layar verifikasi diperbarui di `executor-report/screenshots/winning_scene/hero-graffiti-cut-1.png` s.d. `-cut-5.png`, `hero-graffiti-final-tab.png`, dan `hero-graffiti-standee-closeup.png`.
