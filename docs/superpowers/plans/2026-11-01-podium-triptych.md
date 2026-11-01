# Podium Triptych Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ganti layar kemenangan 5 cut yang menyorot mobil P1 dengan Triptych 3 panel yang menyorot P1, P2, P3 seimbang (standee, mobil sprite hasil bake, kartu manga), dan satukan semua volume musik di satu konfigurasi Music.

**Architecture:** Scene `WinningScene` tetap `Node3D`, isinya 2D. `WinningTriptych` (tata letak, fokus, intro) memegang tiga `WinningPanel` (konten per finisher, ditambah latar yang digambar di lapisan bawah). Mobil adalah PNG transparan per slug yang dibake offline dari `<slug>_full.glb` oleh `tools/bake_podium_car_sprites.gd`. `WinningCutDirector` memberi 5 cut berbasis bar 1,6 dtk; cut mengubah fokus panel.

**Tech Stack:** Godot 4.7.2, GDScript bertipe statis, shader `canvas_item`, fontTools (Python 3, sudah terpasang) untuk subset font, ffmpeg untuk ukur loudness.

**Spec:** `docs/superpowers/specs/2026-11-01-podium-triptych-design.md` (bagian 1-16). Referensi visual: `docs/superpowers/specs/2026-11-01-podium-triptych-preview.html`.

## Global Constraints

- Godot 4.7.2 stable, GDScript bertipe statis, tanpa dependensi baru (GDExtension, plugin, library).
- 60 FPS di 1920x1080 High; 0 orphan node setelah restart dan keluar.
- Root scene tetap `Node3D` (`class_name WinningScene`, `scenes/ui/winning_scene.tscn`).
- Satu bar = 1,6 dtk (`WinningCutDirector.CUT_SECONDS`, 150 BPM). 5 cut, FINAL jatuh di 6,4 dtk.
- Kemiringan panel 90 px, tumpang tindih 90 px, garis tinta 8 px, bobot lebar fokus 1,55 dibanding 1; area panel y 70 sampai 1010; ruang stage 1920x1080.
- Sprite mobil: `assets/cars/<slug>/podium_sprite.png`, lebar tepat 1600 px, RGBA, untuk 13 slug di `Roster.CAR_SLUGS`.
- Font berglyph Jepang wajib OFL dengan berkas lisensi di `assets/fonts` seperti font lain.
- Trim loudness anthem podium -2,2 dB, menu 0,0 dB (ukur ffmpeg ebur128: -11,9 LUFS menu, -9,7 LUFS podium).
- Tidak menghapus, memindah, atau menimpa aset yang tidak dibuat sendiri. File lama yang tidak terpakai dibiarkan dan dilaporkan.
- Test mengikuti konvensi proyek: skrip `SceneTree` di `tests/test_*.gd` dengan `check(ok, message)`, dijalankan lewat `powershell -File tools/run_tests.ps1 -Filter <nama>`. Bukan gdUnit4.
- Kerja di branch `fase-20-podium-triptych` (dari `main`). Commit di branch tiap task. Merge ke `main` dan push hanya bila developer meminta.
- Godot dijalankan dari PowerShell (`godot.cmd`); skrip `-s` yang error menggantung, jadi selalu pakai timeout (`tools/run_tests.ps1` sudah). Aset baru butuh `godot --headless --path . --import`.

## Review Focus

1. Nol, satu, atau dua finisher: panel hanya untuk finisher yang ada, tanpa crash (Task 5, 7, 8).
2. Finisher DNF atau gap `RUNNING`: plat hasil menampilkan teks itu dan `0 PTS`, bukan angka sisa (Task 6).
3. Nama pengemudi sangat panjang ("MAXIMILIAN-ALEXANDER FEATHERSTONEHAUGH", input yang sudah dipakai test lama): tag nama tetap muat (Task 6, 8).
4. Epithet kosong atau tekstur mobil null: kotak disembunyikan atau mobil tidak digambar, tanpa error (Task 6).
5. Panah ditekan beruntun atau [TAB] ditekan saat tween berjalan: keadaan akhir selalu mengikuti input terakhir, tanpa panel tertimpa tower (Task 7, 9).
6. Volume Music = 0 saat ducking radio: bus tetap mute (Task 1).

---

### Task 1: Satu konfigurasi Music

**Files:**
- Modify: `scripts/core/presentation_settings.gd`, `scripts/audio/audio_manager.gd`, `scripts/audio/radio_audio_director.gd`
- Test: `tests/test_music_single_config.gd` (baru)

**Interfaces:**
- Produces: `PresentationSettings.bus_db(bus: StringName) -> float` = `linear_to_db(maxf(volume(bus), 0.001))`; `set_volume` memakainya. `AudioManager.TRACK_TRIM_DB: Dictionary` (`&"menu"`: 0.0, `&"podium"`: -2.2) dan `static func track_trim_db(track: StringName) -> float` (0.0 untuk track tak dikenal). `PresentationSettings.BUS_LABELS[3] == "MUSIC"`.

- [ ] **Step 1: Buat branch dan commit dokumen.** `git switch -c fase-20-podium-triptych`, lalu commit spec, preview, dan rencana ini (`docs: podium triptych spec and plan`).
- [ ] **Step 2: Tulis `tests/test_music_single_config.gd`.** Assertion (pesan test = kalimat ini): "Menu and podium tracks both play on the Music bus" (`hub._music_player.bus == &"Music"` setelah `play_menu_music` dan `play_podium_music`); "One Music slider value gives the same bus level for both tracks" (`set_volume(&"Music", 0.4)`, dB bus = `linear_to_db(0.4)` setelah tiap pergantian lagu); "Track trims differ by the measured 2.2 dB" (`track_trim_db(&"menu") - track_trim_db(&"podium")` = 2.2 ±0.05, dan `hub._music_player.volume_db` mengikuti trim lagu aktif, termasuk lagu yang diminta sebelum hub masuk tree); "Music slider caption reads MUSIC"; "Ducking is relative to the Music config" (`RadioAudioDirector` di luar tree: `duck_music(true)` memberi dB = `bus_db(Music) + DUCK_DB`; setelah `set_volume(&"Music", 0.2)` lalu `duck_music(false)` dB bus = `linear_to_db(0.2)`, bukan nilai lama); "Ducking never unmutes a muted Music bus" (`set_volume(&"Music", 0.0)`, `duck_music(true)` lalu `(false)`, `AudioServer.is_bus_mute` tetap true).
- [ ] **Step 3: Jalankan, pastikan merah.** `powershell -File tools/run_tests.ps1 -Filter music_single`. Expected: FAIL pada trim, label, dan ducking.
- [ ] **Step 4: Implementasi.** Tambah `bus_db`; ganti label `SYNTHWAVE MUSIC` jadi `MUSIC`; di `AudioManager` tambah `TRACK_TRIM_DB`, `track_trim_db`, dan terapkan `_music_player.volume_db = track_trim_db(music_track)` di `_ready` dan `_set_track` (komentar konstanta memuat perintah ukur `ffmpeg -i <file> -af ebur128=peak=true -f null -`); di `RadioAudioDirector` hapus `music_base_db` beserta pembacaannya di `_ready`, dan `duck_music` memakai `PresentationSettings.bus_db(AudioManager.BUS_MUSIC)` sebagai dasar.
- [ ] **Step 5: Jalankan hijau.** `run_tests.ps1 -Filter music_single`, `-Filter podium_music`, `-Filter radio`. Expected: semua PASS.
- [ ] **Step 6: Commit.** `feat(audio): one Music config, per-track loudness trim, ducking relative to config`.

### Task 2: Data kartu (epithet, kanji, SFX, path sprite)

**Files:**
- Modify: `scripts/ui/garage_roster.gd`
- Test: `tests/test_podium_data.gd` (baru)

**Interfaces:**
- Produces: `GarageRoster.DRIVER_EPITHETS: Array[String]` (26, urutan = `GtData.DRIVER_NAMES`), `RANK_KANJI: Array[String]` = `["優勝", "準優勝", "第三位"]`, `RANK_SFX: Array[String]` = `["ドォン!!", "ザッ!", "ゴゴゴ"]` (indeks = place 0..2), `static func epithet(slot: int) -> String` ("" bila di luar rentang), `static func podium_sprite_path(team: int) -> String` (`res://assets/cars/<slug>/podium_sprite.png`, indeks `posmod` seperti `car_path`).

- [ ] **Step 1: Tulis `tests/test_podium_data.gd`.** "Every driver slot has an epithet" (`DRIVER_EPITHETS.size() == GtData.DRIVER_NAMES.size() == 26`, tak ada yang kosong); "Epithets follow the roster order" (indeks 0 `The High-Voltage Prodigy`, 2 `The Apex Drifter`, 8 `The Laser Meister`, 25 `The Touge Empress`); "Rank kanji and SFX per place"; "epithet(99) is empty"; "Sprite path follows the car slug" (`podium_sprite_path(0)` = `res://assets/cars/mercedes_amg/podium_sprite.png`, `podium_sprite_path(12)` memakai `toyota_supra`).
- [ ] **Step 2: Jalankan merah.** `run_tests.ps1 -Filter podium_data`. Expected: FAIL (member tak ada).
- [ ] **Step 3: Implementasi di `garage_roster.gd`.** 26 epithet berurutan slot 0..25 persis seperti roster: The High-Voltage Prodigy, The Cybernetic Calculator, The Apex Drifter, The Camden Rocker, The Iron Matador, The Silent Ronin, The Monaco Prodigy, The Sao Paulo Storm, The Laser Meister, The Iron Valkyrie, The Redline Brawler, The Guadalajara Bull, The Siberian Frost, The Cyber Kitsune, The Monokrom Stylist, The Bauhaus Architect, The Monsoon Emperor, The Riviera Playboy, The Ghost Operator, The Horizon Hunter, The Monza Virtuoso, The Aero Donna, The Detroit Brawler, The High-Plains Drifter, The Midnight Ghost, The Touge Empress. Cocokkan tiap baris dengan `GtData.DRIVER_CODES` terhadap kode di `DRIVER-CHARACTERIZATION-ROSTER.md` (mis. `#09 KAD`), bukan hanya urutan.
- [ ] **Step 4: Hijau dan commit.** `run_tests.ps1 -Filter podium_data`; commit `feat(roster): podium epithets, rank kanji, sfx, sprite path`.

### Task 3: Font berglyph Jepang (subset)

**Files:**
- Create: `assets/fonts/DelaGothicOne-Podium.ttf`, `assets/fonts/DelaGothicOne-OFL.txt`
- Test: `tests/test_podium_font.gd` (baru)

**Interfaces:**
- Produces: `res://assets/fonts/DelaGothicOne-Podium.ttf` (FontFile dengan glyph semua karakter di `RANK_KANJI` dan `RANK_SFX`), dipakai Task 6 sebagai `KANJI_FONT`.

- [ ] **Step 1: Tulis `tests/test_podium_font.gd`.** "The podium font loads as a FontFile"; "It covers every rank kanji and SFX character" (`has_char` untuk semua karakter di `GarageRoster.RANK_KANJI + RANK_SFX`); "The subset stays small" (< 150 KB); "The OFL licence ships next to it" (`FileAccess.file_exists`).
- [ ] **Step 2: Merah.** `run_tests.ps1 -Filter podium_font`. Expected: FAIL.
- [ ] **Step 3: Unduh ke direktori baru dan kosong `temp/font_dl/`.** `curl -L` untuk `DelaGothicOne-Regular.ttf` dan `OFL.txt` dari `https://github.com/google/fonts/raw/main/ofl/delagothicone/`. Jangan menjalankan apa pun dari dalam direktori itu. Bila unduhan gagal, berhenti dan laporkan; jangan ganti font tanpa developer.
- [ ] **Step 4: Subset.** `py -3 -I -m fontTools.subset temp/font_dl/DelaGothicOne-Regular.ttf --text="<karakter RANK_KANJI + RANK_SFX>" --layout-features="*" --output-file=assets/fonts/DelaGothicOne-Podium.ttf`. Baca `OFL.txt`: bila memuat "Reserved Font Name", ganti nama family subset lewat `fontTools.ttLib` menjadi `La Voiture Podium Gothic`. Salin lisensi ke `assets/fonts/DelaGothicOne-OFL.txt`. Jalankan `godot --headless --path . --import`.
- [ ] **Step 5: Hijau dan commit.** `run_tests.ps1 -Filter podium_font`; commit `feat(fonts): podium Japanese subset font with OFL licence`.

### Task 4: Alat bake sprite dan 13 sprite

**Files:**
- Create: `tools/bake_podium_car_sprites.gd`, `tests/podium_sprite_checks.gd` (helper), `assets/cars/<slug>/podium_sprite.png` (13)
- Test: `tests/test_podium_car_sprites.gd` (baru)
- Referensi: `temp/bake_sprites_spike.gd` (spike yang disetujui; jangan diubah)

**Interfaces:**
- Produces: `PodiumSpriteChecks.problems(image: Image) -> Array[String]` (kosong = lolos). Aturan: RGBA8; ada alpha; lebar tepat 1600; rasio lebar/tinggi 1,3 sampai 2,1; keempat sudut transparan (alpha < 0,05); ada piksel alpha > 0,8 di 8 baris terbawah; rasio piksel buram terhadap kotak 0,25 sampai 0,85.
- Produces: perintah `godot --rendering-driver d3d12 --resolution 1280x800 --path . -s tools/bake_podium_car_sprites.gd [-- <slug> ... | --sheet]`.

- [ ] **Step 1: Tulis `tests/podium_sprite_checks.gd` dan `tests/test_podium_car_sprites.gd`.** Test: "A fully opaque block is rejected", "An empty image is rejected", "A 1600 wide image with an opaque corner is rejected", "A car-like ellipse with a ground row passes" (gambar sintetis); "Every car slug has a sprite that passes the checks" (loop `Roster.CAR_SLUGS`, `load` + `get_image()`, `problems().is_empty()`, pesan memuat slug).
- [ ] **Step 2: Merah.** `run_tests.ps1 -Filter podium_car_sprites`. Expected: empat test sintetis PASS, test 13 slug FAIL (sprite belum ada). Test sintetis harus lulus sebelum helper dipercaya.
- [ ] **Step 3: Implementasi alat.** Mulai dari spike: `SubViewport` transparan, `own_world_3d`, MSAA 4x, lampu dan lingkungan identik dengan spike, material dan lampu mobil disalin dari `winning_scene.gd` (`_apply_hero_toon`, `_car_bounds`, `_light_hero_car`; dihapus dari scene di Task 8). Beda dari spike: viewport 2560x1600 dengan kamera `(3.0, 1.85, 5.9)` menuju `(0, 0.5, 0)` fov 32; potong ke kotak alpha plus 8 px; ubah ukuran ke lebar tepat 1600 (`Image.INTERPOLATE_LANCZOS`); simpan ke `res://assets/cars/<slug>/podium_sprite.png`; argumen slug membatasi mobil; `--sheet` menulis lembar kontak `temp/podium_sprites_sheet.png` (grid dari sprite yang ada). Model dibebaskan setelah tiap mobil (butuh RAM besar).
- [ ] **Step 4: Bake dan impor.** Jalankan alat natively untuk 13 mobil (timeout 15 menit, satu proses), lalu `godot --headless --path . --import`. Buat lembar kontak dan **lihat gambarnya**: sudut, ukuran, dan dasar ban harus seragam; Mercedes, Audi, dan Aston harus sama dengan spike.
- [ ] **Step 5: Hijau dan commit.** `run_tests.ps1 -Filter podium_car_sprites`; commit `feat(podium): bake tool and 13 car sprites`. Lampirkan lembar kontak di laporan akhir (Task 10).

### Task 5: Linimasa 5 cut

**Files:**
- Modify: `scripts/ui/winning_cut_director.gd`
- Test: `tests/test_winning_cut_director.gd` (tulis ulang)

**Interfaces:**
- Produces: `enum Cut { INTRO, FOCUS_P3, FOCUS_P2, FOCUS_P1, FINAL }`; `NAMES` = "INTRO", "FOCUS P3", "FOCUS P2", "FOCUS P1", "FINAL"; `static func playlist_for(finishers: int) -> Array[int]` (INTRO dan FOCUS_P1 butuh >= 1, FOCUS_P2 butuh >= 2, FOCUS_P3 butuh >= 3, FINAL selalu); `start`, `tick`, `skip_to_final`, `is_final`, `label` tidak berubah.

- [ ] **Step 1: Tulis ulang test.** "Three or more finishers get all five cuts" (3 dan 20); "Two finishers skip the P3 focus" (`[INTRO, FOCUS_P2, FOCUS_P1, FINAL]`); "One finisher gets intro, P1 focus, final"; "No finisher goes straight to the final"; "A cut lasts 1.6 s"; "The final lands at 6.4 s" (empat tick 1,6 dtk dari `start(false)` menghasilkan `FINAL`); "Label counts cuts" (`CUT 2/5 // FOCUS P3`); pertahankan asersi lama: satu tick tak melompati cut, FINAL tak maju lagi, skip dua kali mengumumkan sekali, `start(true)` langsung FINAL, label playlist pendek ("CUT 1/3 // INTRO").
- [ ] **Step 2: Merah** (`run_tests.ps1 -Filter winning_cut_director`), **implementasi enum dan `playlist_for`**, **hijau**, lalu commit `feat(winning): five-cut triptych timeline`. Test lain yang memakai enum lama (`test_winning_scene_and_standee`) diperbaiki di Task 8.

### Task 6: Shader dan `WinningPanel`

**Files:**
- Create: `shaders/diecut_sprite.gdshader`, `shaders/winning_panel_burst.gdshader`, `scripts/ui/winning_panel.gd`
- Test: `tests/test_winning_panel.gd` (baru)

**Interfaces:**
- Consumes: Task 2 (`Roster.epithet`, `RANK_KANJI`, `RANK_SFX`), Task 3 (font), `graffiti_kit.gd` (`spray_tag`, `stencil_numeral`, `plate`, `crown`), `Roster.CAR_NAMES`, `Roster.CAR_ENGINES`.
- Produces: `class_name WinningPanel extends Control` dengan `NAME_MAX_WIDTH: float = 380.0`, `CAR_WIDTH_FRACTION: float = 0.76`, `CAR_MAX_WIDTH: float = 760.0`, `STANDEE_HEIGHT: float = 640.0`; member `place: int`, `background: Control` (dilampirkan triptych ke lapisan bawah dan disinkronkan), `name_label: Label`, `result_label: Label`, `rank_label: Label`, `kanji_label: Label`, `epithet_box: Control`, `engine_plate: Control`, `sfx_label: Label`, `crown: Control` (hanya P1), `standee: TextureRect`, `car: TextureRect`, `bubble: TextureRect`, `detail_amount: float` (setter mengatur alpha tiga elemen detail), `dim_amount: float` (setter menggelapkan konten dan `background` ke kecerahan 0,5); `func setup(place: int, entry: Dictionary, gap_text: String, fastest_bonus: bool, textures: Dictionary, animate: bool) -> void` (kunci `textures`: `"standee"`, `"car"`, `"portrait"`, boleh null); `func relayout(panel_size: Vector2) -> void`; `func background_polygon() -> PackedVector2Array` (titik pertama x = 90); `func start_breathing() -> void`, `func stop_breathing() -> void`.
- Shader `diecut_sprite`: uniform `outline_px: float`, `outline_color: Color` (putih), `shadow_offset: Vector2`, `shadow_color: Color`. `TextureRect` standee dan mobil diberi margin transparan `OUTLINE_PAD_PX = 24` agar kontur dan bayangan tidak terpotong. Shader `winning_panel_burst`: uniform `ray_color`, `base_color`, `center`, `ray_count`.

- [ ] **Step 1: Tulis `tests/test_winning_panel.gd`.** Panel dibangun dengan tekstur sintetis `Image` 64x64. "P1 panel shows its rank, kanji, and crown" (`rank_label.text == "P1"`, `kanji_label.text == "優勝"`, `crown != null`; P2 dan P3 `crown == null`); "Result plate carries gap and points" (`"+3.400s // 15 PTS"`; bonus lap tercepat menambah " +1 FL"); "A retired finisher shows DNF and zero points" (gap `DNF`, poin 0 -> `"DNF // 0 PTS"`); "A running finisher shows RUNNING" ; "Name tag uppercases the driver" ; "A very long name still fits the tag" (nama 38 huruf, `name_label.size.x <= NAME_MAX_WIDTH`); "Standee and car carry the die-cut outline" (`material.get_shader_parameter("outline_px") > 0` pada keduanya); "Detail amount drives the three detail elements" (0 -> alpha 0, 1 -> alpha 1); "An empty epithet hides its box"; "A null car texture draws no car and does not fail"; "Car is centred and capped" (`relayout(Vector2(617, 940))`: lebar mobil = 0,76 x 617, pusat horizontal panel; `relayout(Vector2(1200, 940))`: lebar = 760); "Dim darkens content" (`dim_amount = 1.0` -> `modulate.r` mendekati 0,5); "Background polygon slants 90 px" (`background_polygon()[0].x == 90.0`).
- [ ] **Step 2: Merah.** `run_tests.ps1 -Filter winning_panel`. Expected: FAIL (kelas tak ada). Impor class baru: `godot --headless --path . --import`.
- [ ] **Step 3: Implementasi shader.** `diecut_sprite`: dilasi alpha ke delapan arah sebesar `outline_px` memakai `TEXTURE_PIXEL_SIZE`, bayangan keras bergeser `shadow_offset`, lalu sprite asli di atasnya. `winning_panel_burst`: sinar radial berwarna `ray_color` di atas `base_color` ditambah halftone, tanpa pembacaan tekstur.
- [ ] **Step 4: Implementasi `WinningPanel`.** Tata letak dari bagian 6 spec (angka stensil 170 px kiri atas, kotak kanji vertikal, bubble 230 px kanan atas, standee tinggi 640 di tengah, mobil di depannya 76% lebar maksimal 760 di bawah, tag nama rata kanan, plat hasil di dasar, mahkota P1 di atas kepala standee, epithet, plat mesin dari `Roster.CAR_NAMES` dan `CAR_ENGINES`, SFX katakana). Kanji dan SFX memakai font Task 3. Nama memakai `Kit.spray_tag(name.to_upper(), rank_color, NAME_MAX_WIDTH, 80, animate)`. Napas standee: skala 1,0 ke 1,015 selama 2,4 dtk dengan telapak kaki tetap (`pivot` di dasar), tidak berjalan bila `animate` false.
- [ ] **Step 5: Hijau dan commit.** `run_tests.ps1 -Filter winning_panel`; commit `feat(winning): triptych panel with manga card, die-cut shader`.

### Task 7: `WinningTriptych` (tata letak, fokus, intro, lebar)

**Files:**
- Create: `scripts/ui/winning_triptych.gd`
- Test: `tests/test_winning_triptych.gd` (baru)

**Interfaces:**
- Consumes: `WinningPanel` (Task 6).
- Produces: `class_name WinningTriptych extends Control`; `SLANT_PX = 90.0`, `OVERLAP_PX = 90.0`, `FOCUS_WEIGHT = 1.55`, `FOCUS_SECONDS = 0.75`; `signal focus_changed(place: int)` (-1 = netral); `var panels: Array[WinningPanel]` (urut place 0 = P1, hanya finisher yang ada); `var name_labels: Array[Label]`, `time_labels: Array[Label]` (urut P1, P2, P3); `var focus_place: int = -1`; `func setup(entries: Array, gaps: Array[String], bonus_ids: Array[int], textures: Array[Dictionary], animate: bool) -> void`; `func set_focus(place: int, instant: bool = false) -> void`; `func cycle_focus(step: int) -> void` (siklus layar: netral, P2, P1, P3, netral; `step` -1 membalik); `func play_intro() -> void` (panel masuk P3, P2, P1 dengan jeda 0,14 dtk dan pegas, detail 0); `func set_available_width(width: float, instant: bool = false) -> void` (1920 normal, 1240 saat tower terbuka); `func panel_rect(place: int) -> Rect2` (global).
- Tata letak: wadah `Rect2(-45, 70, available_width + 90, 940)`; urutan layar P2, P1, P3; lebar panel i = (lebar wadah + 90 x (n-1)) x bobot_i / jumlah bobot; x panel i = jumlah lebar sebelumnya - 90 x i. Dengan 3 panel setara tiap panel 730 px. Satu panel mengisi seluruh wadah. Latar semua panel di lapisan bawah, konten semua panel di lapisan atas (mobil dan standee keluar dari bentuk panel tanpa terpotong).

- [ ] **Step 1: Tulis `tests/test_winning_triptych.gd`.** "Equal state gives three equal panels in podium order" (lebar sama ±1 px, x P2 < P1 < P3, tumpang tindih tepat 90 px); "Focus gives the focused panel 1.55 times the others" (`set_focus(2, true)`, rasio 1,55 ±0,02, panel lain `dim_amount == 1`, yang fokus 0); "Focus shows details only on the focused panel and everywhere when equal" (`detail_amount`); "Intro shows no details and all panels undimmed"; "cycle_focus walks equal, P2, P1, P3, equal and back" (maju dan mundur); "Two finishers make two equal panels, one fills the width, none does not fail" (`panels.size()` 2, 1, 0); "Narrowed width keeps every panel left of 1240 + 45" (`set_available_width(1240, true)`: tepi kanan panel terakhir <= 1285 dan >= tepi sebelumnya); "Reversing focus before the tween ends converges to the last request" (`set_focus(2)`, `set_focus(1)`, `set_focus(-1)` beruntun, tunggu 1 dtk, lebar setara); "Focus change emits once with the place" (`focus_changed`); "name_labels and time_labels keep P1, P2, P3 order".
- [ ] **Step 2: Merah** (`run_tests.ps1 -Filter winning_triptych`; impor class lebih dulu). **Step 3: Implementasi.** Bobot lebar sebagai array yang di-tween (`tween_method`, `TRANS_CUBIC`/`EASE_OUT`, `FOCUS_SECONDS`, 0 bila `instant` atau `reduce_motion`); tiap perubahan bobot memanggil `relayout` panel dan menyinkronkan `background`. Tween yang tertinggal dimatikan sebelum yang baru dibuat.
- [ ] **Step 4: Hijau dan commit.** `feat(winning): triptych layout, focus tween, intro`.

### Task 8: Rakit ulang `WinningScene`

**Files:**
- Modify: `scripts/ui/winning_scene.gd`, `scenes/ui/winning_scene.tscn` (hanya bila node berubah)
- Test: `tests/test_winning_scene_and_standee.gd` (bagian hasil dan alur cut ditulis ulang)

**Interfaces:**
- Consumes: Task 2, 5, 6, 7.
- Produces: `WinningScene.triptych: WinningTriptych`; `standees: Array[TextureRect]` (dari panel); `name_labels`, `time_labels` dari triptych (isi memuat nama huruf besar dan `#NN`, plat hasil memuat gap dan "N PTS"); `_show_cut(cut)` memetakan INTRO -> `play_intro`, FOCUS_P3/P2/P1 -> `set_focus(2/1/0)`, FINAL -> `set_focus(-1)` dengan semua detail tampil. Public lain dipertahankan (bagian 10 spec).

- [ ] **Step 1: Tulis ulang test scene.** Pertahankan seluruh bagian awal (snapshot `capture_results`, `award_points`, kepemilikan nilai, 20 cutout RGBA). Ganti asersi lama dengan: "Three finishers populate the triptych from the twenty-car snapshot" (`triptych.panels.size() == 3`, `standees.size() == 3`, `order.size() == 20`); "Each standee shows its own driver" (`standee.texture.resource_path == standee_path(order[p].id)`, `outline_px > 0`); "Each car is the finisher's own sprite" (`car.texture.resource_path == Roster.podium_sprite_path(order[p].team_id)`); "Bubble carries the driver portrait" (`Roster.portrait_path(order[p].id)`); "All textures are loaded before the first cut" (tak ada tekstur null saat INTRO); "The finale opens on INTRO" lalu tiap `director.tick(1.6)` menghasilkan FOCUS_P3 (`triptych.focus_place == 2`), FOCUS_P2 (1), FOCUS_P1 (0), FINAL (-1, semua `detail_amount == 1`); "The scene holds no 3D car" (`find_children("*", "MeshInstance3D")` kosong, tak ada `Camera3D`); "name_labels and time_labels name the real finishers" (nama huruf besar, `#%02d`, `+3.000s`, `15 PTS`); "A retired P3 shows DNF with 0 PTS"; "Two finishers skip FOCUS_P3" dan "No finisher goes straight to the final with no panels"; "A very long driver name still fits its tag". Ganti pemakaian `Cut.P3_TAG` dan sejenisnya di seluruh file. Bagian input, tower, restart, exit, dan orphan masih dengan perilaku lama dan diperbarui di Task 9.
- [ ] **Step 2: Merah** (`run_tests.ps1 -Filter winning_scene_and_standee`). **Step 3: Implementasi.** `_build_ui` mempertahankan canvas, `_stage`, pita caution, plat atas, tombol aksi, tower, `_cut_label`; menambah latar 2D (gradien gelap dengan `UI.DOTS` halftone) dan `triptych`. Hapus: `_build_studio`, `_build_station`, `_build_confetti`, `hero_set`, `car_slot`, `turntable`, `camera`, orbit dan dolly, `wall_stations`, `_wall_huds`/`_wall_layer`, `hero_callouts`, `headline`, `crown`, `final_hud`, `_speedlines`, `_impact`, konstanta kamera, `Standee`, `WallCut`, `Callouts`, `FinalHud`, `_apply_hero_toon`, `_car_bounds`, `_light_hero_car` (sudah ada di alat bake). Konfeti 3D ikut hilang karena tidak ada kamera; catat di laporan. `_populate` memuat sembilan tekstur (`standee`, `car` dari `Roster.podium_sprite_path(team_id)`, `portrait`) secara sinkron sebelum `start_cuts()`, lalu memanggil `triptych.setup`. `_gap()`, `_reveal_departure`, `capture_results`, `award_points`, musik, dan `_restart`/`_exit_to_hq` tidak diubah. `start_cuts` memakai `WinningCutDirector.new(playlist_for(mini(order.size(), 3)))`.
- [ ] **Step 4: Hijau pada bagian alur.** Expected: PASS untuk asersi baru; asersi input/tower menunggu Task 9. Commit `feat(winning): rebuild the scene around the triptych`.

### Task 9: Interaksi (sorotan manual, tower, skip, reduce_motion)

**Files:**
- Modify: `scripts/ui/winning_scene.gd`
- Test: `tests/test_winning_scene_and_standee.gd` (bagian input, tower, siklus scene)

**Interfaces:**
- Consumes: `WinningTriptych.cycle_focus`, `set_focus`, `set_available_width`, `panel_rect`, `focus_changed`.
- Produces: `WinningScene.focus_step(step: int) -> void` (hanya bila `director.is_final()`); `toggle_leaderboard()` menyusutkan wadah ke 1240 px saat tower terbuka dan mengembalikannya ke 1920 saat tertutup.

- [ ] **Step 1: Tulis asersi.** "Enter, Space and a click on empty stage skip to the final without a flash"; "Mashing skip announces the final once"; "TAB mid-cut skips to the final and opens the tower"; "Reduce motion lands on the final with no tweens running and no breathing"; "Right arrow after the final focuses P2, P1, P3, then equal; left arrow reverses"; "Arrow keys do nothing before the final"; "Clicking a panel focuses it and clicking it again returns to equal" (klik panel saat belum FINAL tetap berarti skip); "With the tower open no panel rect intersects it" (`panel_rect(p)` terhadap `leaderboard.get_global_rect()`, juga untuk `name_labels`); "Rapid TAB reversals end closed and the triptych returns to full width"; "Toggling the tower while a focus tween runs ends clean"; pertahankan: tower terbuka di `position.x == 1280` miring 1,2 derajat, baris tower berisi "+1 PT" dan "DNF", 20 baris dan 10 tim, restart ke `race_weekend_world` dengan seed sama, exit ke `main.tscn`, musik kembali ke menu, scene dibebaskan, nol orphan node.
- [ ] **Step 2: Merah, implementasi, hijau.** `_input` menangani `KEY_LEFT`/`KEY_RIGHT` (hanya FINAL) lewat `focus_step(+1/-1)`; klik panel memakai `gui_input` panel dan memanggil `set_focus` atau `set_focus(-1)` bila panel sudah fokus; `_unhandled_input` tetap hanya men-skip saat belum FINAL. `toggle_leaderboard` memanggil `triptych.set_available_width` (tween 0,25 dtk, 0 bila `reduce_motion`) alih-alih menggeser `camera.h_offset`. Hapus `_process` orbit/turntable; `_process` hanya `director.tick(delta)`.
- [ ] **Step 3: Jalankan `-Filter winning` dan commit.** `feat(winning): manual focus, tower makes room, input contract`.

### Task 10: Pembersihan, dokumentasi, verifikasi akhir

**Files:**
- Modify: `AGENTS.md` (tabel perintah bagian 3: tambah perintah bake sprite), `scratch/smoke_winning_scene.gd`, test lain yang menyentuh API scene (`tests/test_radio_and_podium.gd`, `tests/test_podium_music.gd`, `scratch/capture_phase6_podium.gd`, `scratch/capture_fase84.gd`) bila gagal
- Create: `scratch/capture_podium_triptych.gd`, `executor-report/reports/FASE-20-PODIUM-TRIPTYCH-REPORT.md`, `executor-report/screenshots/phases/phase-20/`
- Modify: `todo.md`

- [ ] **Step 1: Cari kode mati.** Grep pemakai `winning_wall_cut.gd`, `winning_hero_callouts.gd`, `winning_final_hud.gd`, `kinetic_standee_3d.gd`, `kinetic_standee.gdshader`, `winning_impact_frame.gdshader`, `winning_concrete.gdshader`, `winning_reveal.gdshader`. Jangan hapus; daftar yang tak punya pemakai di laporan.
- [ ] **Step 2: Perbarui skrip scratch dan AGENTS.md.** `smoke_winning_scene.gd` mengukur p95 frame time di INTRO, tiap FOCUS, FINAL, dan saat tower dibuka; periksa 20/20 finish, podium, 0 orphan. Tambah perintah bake ke `AGENTS.md`.
- [ ] **Step 3: Suite penuh.** `powershell -File tools/run_tests.ps1` dalam irisan (`-From 0 -To 39`, `40-79`, sisanya) bila memori terbatas. Expected: 100% PASS, 0 FAIL. `test_audio_and_race_weekend` memakan sekitar 8 menit.
- [ ] **Step 4: Smoke test native 1080p High.** `godot --path . -s res://scratch/smoke_winning_scene.gd -- --race` (3 lap, 20 mobil). Expected: 60 FPS, p95 <= 16,8 ms di semua cut, kembali ke menu dengan 0 orphan. Catat juga lonjakan frame saat masuk scene di balik wipe keberangkatan.
- [ ] **Step 5: Tangkapan layar.** `capture_podium_triptych.gd` memotret 5 cut untuk tiga kombinasi podium berbeda (termasuk Mercedes/Audi/Aston), satu kasus DNF, satu nama panjang, dan tower terbuka, ke `executor-report/screenshots/phases/phase-20/`, plus lembar kontak 13 sprite. Periksa hasilnya dengan melihat gambarnya.
- [ ] **Step 6: Laporan** `FASE-20-PODIUM-TRIPTYCH-REPORT.md`: hasil test, FPS, tangkapan layar, kode mati yang tersisa, konfeti 3D yang hilang, tekstur Mercedes `_full` 128 MB tanpa kompresi (rekomendasi reimpor, tidak diubah), dan keputusan spec bagian 15.
- [ ] **Step 7: `todo.md` dan commit akhir.** Centang semua langkah dengan bukti; commit `docs(report): fase 20 podium triptych`. Jangan merge atau push sebelum developer meminta.

---

## Initiate Prompt untuk Executor

> Kerjakan `docs/superpowers/plans/2026-11-01-podium-triptych.md` task demi task di branch `fase-20-podium-triptych` (baca juga spec `docs/superpowers/specs/2026-11-01-podium-triptych-design.md` dan `AGENTS.md` bagian 8, 9, 12). TDD: tulis test, lihat merah, implementasi, lihat hijau, commit. Jangan menghapus atau menimpa aset yang bukan buatan Anda. Jalankan Godot lewat PowerShell dengan timeout. Setelah Task 4, tunjukkan lembar kontak 13 sprite sebelum lanjut. Jangan merge atau push tanpa permintaan developer. Lapor hasil test, FPS, dan tangkapan layar apa adanya, termasuk yang gagal.
