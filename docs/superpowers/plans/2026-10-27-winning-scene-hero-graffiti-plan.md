# Winning Scene Hero Machine Graffiti Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ganti panggung podium dengan lima cut bergantian (P3 tag, mobil, P2 tag, detail mobil, akhir) bergaya Toon Anime Graffiti Brutalism, dengan mobil juara sebagai subjek utama dan anthem rock sebagai musik.

**Architecture:** `winning_scene.gd` tetap pemilik hasil, input, TimingTower, dan siklus scene. Logika urutan cut dipisah ke `WinningCutDirector` (murni, bisa dites tanpa render). Elemen grafiti 2D dibuat oleh `GraffitiKit` (statis) dan dirakit per cut oleh tiga pembangun kecil. Dunia 3D punya satu set mobil di origin dan dua stasiun dinding jauh di sisi (x = ±30) tempat standee P3 dan P2 berdiri; kamera berpindah antar set per cut.

**Tech Stack:** Godot 4.7.2, GDScript bertipe statis, `.gdshader`, test headless `SceneTree` (pola `tests/test_winning_scene_and_standee.gd`, bukan gdUnit4).

**Spec:** `docs/superpowers/specs/2026-10-27-winning-scene-hero-graffiti-design.md`. Referensi visual: `docs/superpowers/specs/2026-10-27-winning-scene-hero-graffiti-preview.html` (buka di browser, tombol "Cut" 1 sampai 5).

## Global Constraints

- Godot 4.7.2 stable, GDScript statis. Tidak ada dependensi baru. Aset font baru wajib OFL dengan berkas lisensi di `assets/fonts/` (seperti `Anton-OFL.txt`).
- Jangan menghapus, memindah, atau menimpa berkas yang tidak dibuat sendiri. Berkas yang diedit di rencana ini dicadangkan dulu (Task 1 Step 1). Tidak ada penghapusan berkas. `winning_marble.gdshader` dan `winning_stage_print.gdshader` dibiarkan tak terpakai.
- Banyak berkas yang diedit tidak punya riwayat git (untracked). Cadangan di `temp/backup_winning_graffiti/` adalah satu-satunya jaring pengaman.
- Jangan commit atau push kecuali pemilik proyek meminta. Rencana ini tidak punya langkah commit.
- Kontrak test lama (spec bagian 8) tidak boleh rusak: `standees` (3 `KineticStandee3D`), `name_labels`, `time_labels`, `order`, `results`, `car_slot`, `turntable`, `camera`, `leaderboard.position.x == 1280` saat TAB terbuka, `timing_rows.size() == 20`, `team_labels.size() == 10`, orbit berhenti saat tower terbuka.
- Nilai dari spec: 5 cut, 1.9 detik per cut, impact frame 80 ms, orbit ±6° (0.105 rad), turntable 0.18 rad/s, kontur stiker 5 px di ruang 1920x1080, pelat miring -12° (`StreetStyle.SLANT_RAD`), `reduce_motion` langsung ke cut akhir tanpa flash dan tanpa tween, 60 FPS di 1920x1080, 0 orphan node.
- Anthem: `res://assets/audio/music/podium_rock_anthem.mp3`, berulang, bus `Music`. Menu: `streetwear_synth.ogg`. Berkas `melodic-anime-rock-victory-anthem-triump-cmvpjcf7.mp3` jangan disentuh.
- Konvensi nama proyek: shader `winning_*.gdshader`, test `tests/test_*.gd`, helper statis lewat `const X := preload(...)` (tanpa `class_name` kecuali `WinningScene`, `AudioManager`, `KineticStandee3D`, dan `WinningCutDirector`).

## Review Focus

Masukan atau kondisi yang tidak disebut spec tetapi paling mungkin menggigit, dan test-nya ada di task pemilik:

1. Kurang dari tiga finisher atau `order` kosong: tidak crash, cut P3 atau P2 dilewati, selalu berakhir di cut akhir (Task 2, Task 6).
2. Finisher podium berstatus DNF: dinding menampilkan "DNF" dan 0 PTS, bukan selisih waktu (Task 6).
3. Nama driver sangat panjang: tag semprot menyusut sampai muat, tidak keluar layar (Task 3).
4. Skip, restart (R), atau keluar (Esc) di tengah cut: tidak ada tween atau node tertinggal, musik menu kembali (Task 9).
5. `reduce_motion = true`: cut akhir langsung, tidak ada flash, tidak ada tween jalan (Task 9).

---

### Task 1: Musik podium di AudioManager

**Files:**
- Modify: `scripts/audio/audio_manager.gd`
- Test: `tests/test_podium_music.gd` (baru)

**Interfaces:**
- Produces (dipakai Task 9): `AudioManager.music_track: StringName` (`&"menu"` atau `&"podium"`), `AudioManager.podium_stream: AudioStreamMP3`, `func play_podium_music() -> void`, `func play_menu_music() -> void`.

- [ ] **Step 1: Cadangkan berkas yang akan diedit di seluruh rencana**

Salin ke `temp/backup_winning_graffiti/` (folder sudah `.gdignore`; buat dengan `New-Item -ItemType Directory`): `scripts/ui/winning_scene.gd`, `scripts/ui/kinetic_standee_3d.gd`, `shaders/kinetic_standee.gdshader`, `scripts/audio/audio_manager.gd`, `scripts/ui/garage_roster.gd`, `tests/test_winning_scene_and_standee.gd`, `tests/test_radio_and_podium.gd`, `tests/test_audio_and_race_weekend.gd`, `tests/test_track_incidents_and_stewards.gd`, `scratch/smoke_winning_scene.gd`, `executor-report/reports/FASE-11-LANGKAH-7-WINNING-SCENE-REPORT.md`. Pertahankan struktur folder relatif. Periksa bahwa tiap salinan ada dan ukurannya sama dengan aslinya.

- [ ] **Step 2: Tulis test yang gagal** di `tests/test_podium_music.gd` (kerangka `check()`/`quit` sama dengan `tests/test_winning_scene_and_standee.gd` baris 1-21). Assertion:
  - hub baru yang masuk tree: `hub.music_track == &"menu"`.
  - `hub.play_podium_music()` lalu `hub.music_track == &"podium"` dan `hub.podium_stream is AudioStreamMP3 and hub.podium_stream.loop`.
  - `hub.play_menu_music()` lalu `hub.music_track == &"menu"` dan `hub._music_player.stream` adalah stream menu (ogg).
  - hub kedua dipanggil `play_podium_music()` sebelum masuk tree, lalu `add_child` dan satu frame: `hub2.music_track == &"podium"` dan `hub2._music_player.stream == hub2.podium_stream`.
  - Tidak ada pemutaran nyata di headless: `hub.is_music_playing() == false` (`has_output()` false).

- [ ] **Step 3: Jalankan, pastikan gagal**

Run: `godot --headless --path . -s res://tests/test_podium_music.gd`
Expected: error "Invalid access to property 'music_track'" atau FAIL.

- [ ] **Step 4: Implementasi di `audio_manager.gd`**

Tambah `const PODIUM_MUSIC_STREAM := preload("res://assets/audio/music/podium_rock_anthem.mp3")`, `var music_track: StringName = &"menu"`, `var podium_stream: AudioStreamMP3` (duplikat dari preload dengan `loop = true`, dibuat di `_init`), `var _menu_stream: AudioStream` (duplikat ogg berulang, dibuat di `_ready` seperti sekarang). `func play_podium_music() -> void` dan `func play_menu_music() -> void` memanggil `_set_track(track)`. `_set_track` selalu menyetel `music_track`; hanya jika `_music_player != null` ia menukar `stream` dan, bila `has_output()` dan `is_inside_tree()`, menghentikan lalu memutar. Di akhir `_ready`, pilih stream sesuai `music_track` tanpa memutar (menutup kasus dipanggil sebelum siap). `start_music()` tidak berubah.

- [ ] **Step 5: Jalankan, pastikan lulus**

Run: `godot --headless --path . -s res://tests/test_podium_music.gd`
Expected: baris akhir `... 0 FAIL`, exit code 0.

---

### Task 2: WinningCutDirector (urutan cut)

**Files:**
- Create: `scripts/ui/winning_cut_director.gd`
- Test: `tests/test_winning_cut_director.gd` (baru)

**Interfaces:**
- Produces (dipakai Task 5-9): `class_name WinningCutDirector extends RefCounted`; `enum Cut { P3_TAG, HERO, P2_TAG, DETAIL, FINAL }`; `const CUT_SECONDS: float = 1.9`; `signal cut_changed(cut: int)`; `var current_cut: int`; `static func playlist_for(finishers: int) -> Array[int]`; `func _init(playlist: Array[int])`; `func start(instant: bool) -> void`; `func tick(delta: float) -> void`; `func skip_to_final() -> void`; `func is_final() -> bool`; `func label() -> String` (bentuk `"CUT 2/5 // HERO MACHINE"`, penyebut = panjang playlist).

- [ ] **Step 1: Tulis test yang gagal.** Assertion:
  - `playlist_for(20) == [P3_TAG, HERO, P2_TAG, DETAIL, FINAL]`; `playlist_for(3)` sama; `playlist_for(2) == [HERO, P2_TAG, DETAIL, FINAL]`; `playlist_for(1) == [HERO, DETAIL, FINAL]`; `playlist_for(0) == [FINAL]`.
  - `start(false)` memancarkan `cut_changed(P3_TAG)` sekali; `tick(1.89)` tetap P3_TAG; `tick(0.02)` pindah ke HERO dan memancarkan sekali.
  - Total `tick(1.95)` berulang empat kali sampai FINAL; `tick(100.0)` tambahan tidak mengubah apa pun dan tidak memancarkan lagi; `is_final()` benar.
  - `skip_to_final()` di tengah cut memancarkan `cut_changed(FINAL)` tepat sekali; panggilan kedua tidak memancarkan.
  - `start(true)` langsung FINAL dan memancarkan sekali.
  - `tick(5.0)` besar dari cut pertama hanya maju satu cut per tick (tidak melompati cut).
  - `label()` untuk playlist 3 elemen di cut kedua = `"CUT 2/3 // HERO MACHINE"`.

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `godot --headless --path . -s res://tests/test_winning_cut_director.gd`
Expected: gagal memuat `winning_cut_director.gd`.

- [ ] **Step 3: Implementasi** `winning_cut_director.gd` sesuai antarmuka. Waktu terkumpul di `_elapsed`; saat `>= CUT_SECONDS` maju satu indeks dan kurangi `CUT_SECONDS` (satu cut per tick). Nama cut untuk `label()`: `"P3 TAG"`, `"HERO MACHINE"`, `"P2 TAG"`, `"DETAIL"`, `"FINAL"`.

- [ ] **Step 4: Jalankan, pastikan lulus** (perintah Step 2, `0 FAIL`).

---

### Task 3: GraffitiKit dan data spesifikasi mobil

**Files:**
- Create: `scripts/ui/graffiti_kit.gd`
- Modify: `scripts/ui/garage_roster.gd` (tambah `CAR_ENGINES`)
- Create (jika unduhan berhasil): `assets/fonts/SairaStencilOne-Regular.ttf`, `assets/fonts/SairaStencilOne-OFL.txt`
- Test: `tests/test_graffiti_kit.gd` (baru)

**Interfaces:**
- Produces (dipakai Task 6-9): `const Kit := preload("res://scripts/ui/graffiti_kit.gd")` dengan konstanta `INK`, `PAPER = Color("#E8E4D6")`, `ORANGE = Color("#FF6B00")`, dan fungsi statis:
  - `spray_tag(text: String, color: Color, max_width: float, font_size: int = 170) -> Label` (font `PermanentMarker.ttf`, kontur ink 4 px, drip sebagai anak `ColorRect` bernama `Drip*` yang dianimasikan `Tween` terikat label; font menyusut hingga lebar minimum label <= `max_width`).
  - `stencil_numeral(text: String, color: Color, font_size: int) -> Label` (kontur ink 7 px, bayangan keras).
  - `poster(size: Vector2, tilt_deg: float) -> Control` (anak `Polygon2D` bernama `Paper` dengan tepi sobek >= 12 titik, overlay halftone dari `UI.DOTS`, rotasi `tilt_deg`).
  - `plate(text: String, fill: Color, font_size: int = 28) -> Label` (membungkus `StreetStyle.badge`).
  - `caution_tape(width: float) -> Control` (tinggi 60, memakai `winning_caution_tape.gdshader` dari Task 4).
  - `crown() -> Control` (`Polygon2D` bernama `Crown`, lime, kontur ink).
  - `marker_note(text: String, sub: String = "") -> Control` (teks spidol putih berkontur, sub-label mono di plat hitam).
  - `scribble_arrow(from: Vector2, to: Vector2) -> Line2D` (lime, lebar 7, kepala panah, melengkung ringan).
- `Roster.CAR_ENGINES: Array[String]` urut `CAR_SLUGS`: `"6.2L V8 NA"`, `"5.2L V10 NA"`, `"3.8L V6 TWIN-TURBO"`, `"3.0L I6 TWIN-TURBO"`, `"4.0L V8 TWIN-TURBO"`, `"5.5L V8 NA"`, `"3.5L V6 TWIN-TURBO"`, `"5.4L V8 NA"`, `"4.0L V8 TWIN-TURBO"`, `"5.2L V10 NA"`. Tanpa angka tenaga (spec bagian 2 butir 8).

- [ ] **Step 1: Tulis test yang gagal.** Assertion:
  - `Roster.CAR_ENGINES.size() == Roster.CAR_SLUGS.size()` dan `CAR_ENGINES[0] == "6.2L V8 NA"`.
  - `spray_tag("T. KADE", Color.ORANGE, 760.0)` memiliki >= 4 anak bernama awalan `Drip` dan `get_minimum_size().x <= 760.0`.
  - Nama panjang `"MAXIMILIAN-ALEXANDER FEATHERSTONEHAUGH"` dengan `max_width = 760.0`: `get_minimum_size().x <= 760.0` dan font akhir `>= 40` (tidak jatuh ke nol).
  - `poster(Vector2(520, 720), -4.0).get_node("Paper").polygon.size() >= 12` dan `rotation_degrees == -4.0`.
  - `stencil_numeral("P3", Color.ORANGE, 560).get_theme_font("font")` bukan null.
  - Setelah `queue_free()` dan dua frame, `Performance.OBJECT_ORPHAN_NODE_COUNT == 0` (Tween ikut mati).

- [ ] **Step 2: Unduh font stensil.** Run (PowerShell): `Invoke-WebRequest https://github.com/google/fonts/raw/main/ofl/sairastencilone/SairaStencilOne-Regular.ttf -OutFile assets/fonts/SairaStencilOne-Regular.ttf` dan berkas `OFL.txt` yang sama ke `assets/fonts/SairaStencilOne-OFL.txt`. Jalankan `godot --headless --path . --import` agar `.import` dibuat. Jika unduhan gagal atau berkas bukan font valid, pakai `Anton.ttf` sebagai `STENCIL_FONT` dan catat di laporan.

- [ ] **Step 3: Jalankan test, pastikan gagal** (`godot --headless --path . -s res://tests/test_graffiti_kit.gd`).

- [ ] **Step 4: Implementasi** `graffiti_kit.gd` dan `CAR_ENGINES` di `garage_roster.gd`. Pola pelat dan font ikuti `street_style.gd` dan `pit_wall_ui.gd`. Tetesan: tiap drip `ColorRect` lebar 12 px, tinggi bervariasi deterministik dari indeks, `Tween` loop ping-pong pada `scale:y` (0.55 ke 1.0, 3-5 detik) dibuat dari label itu sendiri (`label.create_tween()`).

- [ ] **Step 5: Jalankan, pastikan lulus** (`0 FAIL`).

---

### Task 4: Shader (outline stiker, beton, impact frame, pita caution)

**Files:**
- Modify: `shaders/kinetic_standee.gdshader`, `scripts/ui/kinetic_standee_3d.gd`
- Create: `shaders/winning_concrete.gdshader`, `shaders/winning_impact_frame.gdshader`, `shaders/winning_caution_tape.gdshader`
- Test: `tests/test_winning_scene_and_standee.gd` (tambah assertion), `tests/test_graffiti_kit.gd` (tambah)

**Interfaces:**
- Produces: uniform `outline_width: float` (0 = mati, default 0), `outline_color: vec4` di `kinetic_standee.gdshader`; konstanta `KineticStandee3D.OUTLINE_WIDTH: float = 0.006` yang disetel ke material di `_build()`. `winning_concrete.gdshader` (spatial) dengan uniform `base_color`, `seam_spacing: float = 3.0`, `tie_spacing: float = 1.6`. `winning_impact_frame.gdshader` (canvas_item, `hint_screen_texture`, negatif luma hitam-putih; varian layar dari `manga_snapshot_invert.gdshader`, karena impact frame di sini membalik frame yang sedang tampil dan tidak punya snapshot). `winning_caution_tape.gdshader` (canvas_item, garis -45° kuning `#FFE600` dan hitam, uniform `stripe_px = 26.0`).

- [ ] **Step 1: Tulis test yang gagal.**
  - Di `test_winning_scene_and_standee.gd` setelah baris P1 albedo: `studio.standees[0].material.get_shader_parameter("outline_width") > 0.0`.
  - Di `test_graffiti_kit.gd`: tiap dari tiga shader baru `load(path) is Shader`, `shader.get_mode()` sesuai (`MODE_SPATIAL` untuk concrete, `MODE_CANVAS_ITEM` untuk dua lainnya), dan `ShaderMaterial` dengannya bisa dibuat.

- [ ] **Step 2: Jalankan, pastikan gagal** (kedua test).

- [ ] **Step 3: Outline stiker di `kinetic_standee.gdshader`.** Di `fragment()`: bila alpha tekstur piksel ini di bawah `alpha_cutoff` dan salah satu dari 8 arah (radius `outline_width` dalam UV) di atas cutoff, tulis `ALBEDO = outline_color.rgb`, `ALPHA = 1.0`, `EMISSION = vec3(0.0)`; jangan gambar bila `outline_width <= 0.0`. Ambil sampel dengan `textureLod(..., 0.0)` seperti rim. Periksa margin transparan tiap `standees/*.png`: jika siluet menyentuh tepi tekstur, kurangi `OUTLINE_WIDTH` agar tidak terpotong. Komentar header shader tetap menjelaskan anggaran: 8 sampel tambahan, hanya piksel tepi.

- [ ] **Step 4: Tiga shader baru** sesuai antarmuka. Beton: seam vertikal dan lubang form-tie dari `fract()` pada koordinat dunia, noise hash murni (tanpa tekstur), roughness 1.0. Setiap berkas diberi komentar header (tujuan, target Forward+, anggaran).

- [ ] **Step 5: Jalankan, pastikan lulus** (`test_graffiti_kit.gd` dan `test_winning_scene_and_standee.gd`, keduanya `0 FAIL`; scene belum berubah di task ini, jadi assertion lama tetap lulus).

- [ ] **Step 6: Periksa kompilasi shader di mesin render nyata.**

Run: `godot --path . --quit-after 120 -s res://scratch/smoke_winning_scene.gd 2>&1 | Select-String -Pattern "SHADER ERROR|Parse Error"`
Expected: tidak ada baris.

---

### Task 5: Set mobil, stasiun dinding, kamera, dan putaran

**Files:**
- Modify: `scripts/ui/winning_scene.gd` (`_build_studio`, `_build_trophy` dihapus pemakaiannya, `_process`, `_populate`, konstanta)
- Test: `tests/test_winning_scene_and_standee.gd` (ubah dan tambah), `tests/test_radio_and_podium.gd`, `tests/test_audio_and_race_weekend.gd`, `tests/test_track_incidents_and_stewards.gd` (hanya jika asersinya bergantung pada `HEIGHTS` atau step; sesuaikan seperlunya)

**Interfaces:**
- Consumes: `WinningCutDirector.Cut` (Task 2), `GraffitiKit` tidak dipakai di sini.
- Produces (dipakai Task 6-9): konstanta di `winning_scene.gd`: `TURNTABLE_SPEED := 0.18`, `ORBIT_MAX_RAD := 0.105`, `ORBIT_RATE := 0.35`, `HERO_CAMERA_POS := Vector3(0.0, 1.3, 7.4)`, `HERO_CAMERA_TARGET := Vector3(0.0, 1.0, 0.0)`, `DETAIL_CAMERA_POS := Vector3(2.4, 0.9, 3.6)`, `DETAIL_CAMERA_TARGET := Vector3(0.9, 0.6, 1.8)`, `P1_STANDEE_POS := Vector3(2.7, 0.0, 1.4)`, `STATION_X := {2: 30.0, 1: -30.0}` (kunci = indeks place: 2 = P3, 1 = P2), `STATION_CAMERA_OFFSET := Vector3(0.0, 1.15, 5.6)`, `STATION_TARGET_OFFSET := Vector3(0.0, 0.95, 0.0)`. Anggota baru: `var wall_stations: Dictionary` (place ke `Node3D`, bernama `WallStationP2`, `WallStationP3`), `var hero_set: Node3D` (bernama `HeroSet`), `var _cam_pos: Vector3`, `var _cam_target: Vector3`, `var _cut: int` (nilai `WinningCutDirector.Cut`, default `FINAL`). Fungsi baru `func _cam_orbit_angle() -> float` (sudut orbit saat ini, radian). Standee P1 di `P1_STANDEE_POS`, P2 dan P3 di `Vector3(STATION_X[place], 0.0, 0.0)`.

Starting point numerik di atas adalah titik awal. Sesuaikan terhadap mock lewat screenshot native (Task 10), jangan sampai mengubah kontrak.

- [ ] **Step 1: Ubah dan tambah test.** Di `test_winning_scene_and_standee.gd`:
  - Ganti assertion posisi lama (`is_equal_approx(standee.position.y, [0.8, 0.5, 0.3][place])`) dengan `is_equal_approx(standee.position.y, 0.0)`, dan tambah `is_equal_approx(absf(studio.standees[1].position.x), 30.0)` serta `studio.standees[0].position.is_equal_approx(studio.P1_STANDEE_POS)`.
  - Ganti kecepatan turntable ke `0.18` dan judulnya "rotates at 0.18 rad/s".
  - Tambah: `studio.get_node_or_null("HeroSet") != null`, `studio.wall_stations.size() == 2`, tidak ada node bernama `PodiumP1` dan tidak ada `ChampionshipTrophy`.
  - Tambah: setelah 200 pemanggilan `studio._process(0.1)` di cut FINAL, `absf(studio._cam_orbit_angle()) <= 0.106` dan kamera pernah bergerak (nilai maksimum yang teramati `> 0.05`).
  - Pertahankan assertion orbit membeku saat tower terbuka.

- [ ] **Step 2: Jalankan, pastikan gagal.**

Run: `godot --headless --path . -s res://tests/test_winning_scene_and_standee.gd`
Expected: FAIL pada assertion baru.

- [ ] **Step 3: Implementasi.** Di `_build_studio`: hapus tiga step, medal trim, numeral, dan `_build_trophy()`; turntable ke `Vector3(0, 0.05, 0)`; lantai dan latar beton (`winning_concrete.gdshader`) di bawah `HeroSet`; tambahkan `HeroSet` sebagai induk dari turntable, lantai, latar, spot, dan lampu rim yang ada. Tiap stasiun: `Node3D` dengan dinding beton 6x4 m di z = -1.2 dan lantai beton kecil di y = 0, tanpa lampu tambahan (lampu arah `StudioKey` sudah menerangi dan membuat bayangan standee ke dinding). `_process`: turntable berputar `TURNTABLE_SPEED` bila tidak `reduce_motion`; orbit hanya bila `_cut` adalah `HERO` atau `FINAL`, tower tertutup, dan tidak `reduce_motion`: posisi kamera = `_cam_target + Basis(Vector3.UP, sin(_orbit_time * ORBIT_RATE) * ORBIT_MAX_RAD) * (_cam_pos - _cam_target)`, lalu `look_at(_cam_target)`. `_populate` menempatkan standee dan memuat mobil seperti sekarang (`_apply_hero_toon`, `_light_hero_car` tidak berubah). Kamera awal di `HERO_CAMERA_POS`.

- [ ] **Step 4: Jalankan, pastikan lulus**, lalu jalankan tiga test lain yang menyentuh `WinningScene` (`test_radio_and_podium.gd`, `test_audio_and_race_weekend.gd`, `test_track_incidents_and_stewards.gd`) dan perbaiki hanya asersi yang memang bergantung pada podium lama.

---

### Task 6: Cut dinding driver (P3 dan P2) dan penghubung ke director

**Files:**
- Create: `scripts/ui/winning_wall_cut.gd`
- Modify: `scripts/ui/winning_scene.gd` (`_build_ui`, `_populate`, `_process`, `_show_cut`, penggerak director)
- Test: `tests/test_winning_scene_and_standee.gd`

**Interfaces:**
- Consumes: `Kit` (Task 3), `WinningCutDirector` (Task 2), konstanta Task 5.
- Produces (dipakai Task 7-9): `WinningWallCut.build(place: int, entry: Dictionary, gap: String) -> Control` (place 1 = P2 cyan, 2 = P3 oranye; anak bernama `Poster`, `Numeral`, `Tag`, `GapPlate`, `Badge`; teks tag = nama driver huruf besar; `GapPlate` berisi `gap` dan `"%d PTS"`; `Badge` = `"RUNNER-UP"` atau `"BRONZE LOCK"`). Di `winning_scene.gd`: `var director: WinningCutDirector`, `var _wall_huds: Dictionary` (place ke `Control`), `func _show_cut(cut: int) -> void` (menukar kamera ke stasiun atau set, menampilkan HUD cut, memperbarui label cut), `func start_cuts() -> void` (membuat `director` dari `WinningCutDirector.playlist_for(mini(order.size(), 3))` dan memulainya; dipanggil dari `_populate` dan `_ready`), `func current_cut() -> int`.

- [ ] **Step 1: Tulis test yang gagal.** Assertion (fixture hasil 20 mobil seperti test yang ada):
  - `studio.director.current_cut == WinningCutDirector.Cut.P3_TAG` setelah `start_cuts()` tanpa reduce_motion; HUD P3 terlihat, HUD P2 tidak; `studio.camera.position.x` mendekati 30.0.
  - Setelah `studio.director.tick(1.95)` dua kali: cut `P2_TAG`, kamera x mendekati -30.0, HUD P2 terlihat.
  - `Tag.text` di P3 berisi nama driver P3 huruf besar; `GapPlate.text` berisi `"+3.400s"` dan `"15 PTS"` (data fixture yang ada).
  - DNF: ubah entri P3 di snapshot menjadi `is_dnf = true, points = 0` lalu `setup_celebration`; `GapPlate.text` berisi `"DNF"` dan `"0 PTS"` dan tidak berisi `"+"`.
  - Dua finisher saja (potong `order` ke 2 entri): `director` memulai di `HERO` (tidak ada cut P3), tidak crash; `order` kosong: `director.current_cut == FINAL`, tidak crash, `standees.size() == 0`.
  - Nama panjang: entri P2 dengan `driver_name = "MAXIMILIAN-ALEXANDER FEATHERSTONEHAUGH"`: `Tag.get_minimum_size().x <= 760.0`.

- [ ] **Step 2: Jalankan, pastikan gagal.**

- [ ] **Step 3: Implementasi.** `winning_wall_cut.gd` merakit poster tim (nama tim, nomor), standee tidak termasuk (ada di 3D), angka stensil besar (`"P2"`/`"P3"`), tag semprot dengan `max_width = 760`, plat selisih dan poin (`gap + "   //   " + poin`), badge. Posisi dan rotasi mengikuti mock (cut 1 dan 3) di ruang 1920x1080; cut 3 adalah cermin horizontal cut 1. `_show_cut`: untuk `P3_TAG`/`P2_TAG` kamera di `Vector3(STATION_X[place], 0, 0) + STATION_CAMERA_OFFSET` menghadap `+STATION_TARGET_OFFSET`, statis; untuk `HERO` dan `FINAL` kembali ke `HERO_CAMERA_*`; `DETAIL` ditangani Task 7. HUD lama (tiga kartu bawah) dihapus pemakaiannya di sini tetapi `name_labels`/`time_labels` tetap dibuat oleh Task 8, jadi untuk sementara isi keduanya dengan `Label` tak terlihat agar kontrak tidak putus.
  Penggerak: `_process(delta)` memanggil `director.tick(delta)` kecuali `_leaving`.

- [ ] **Step 4: Jalankan, pastikan lulus.**

---

### Task 7: Cut mobil, callout, dan detail

**Files:**
- Create: `scripts/ui/winning_hero_callouts.gd`
- Modify: `scripts/ui/winning_scene.gd` (`_light_hero_car` memakai `_car_bounds`, `_show_cut` untuk `HERO` dan `DETAIL`)
- Test: `tests/test_winning_scene_and_standee.gd`

**Interfaces:**
- Consumes: `Kit` (Task 3), `Roster.CAR_NAMES`/`CAR_ENGINES`, `_cut`/`_cam_pos`/`_cam_target` (Task 5), `_show_cut` (Task 6).
- Produces: `WinningHeroCallouts.anchors(bounds: AABB) -> Dictionary` kunci `&"engine"`, `&"wing"`, `&"wheel"`, `&"splitter"` bernilai `Vector3` lokal model: engine `bounds.position + bounds.size * Vector3(0.5, 0.62, 0.72)`, wing `Vector3(0.5, 0.95, 0.06)`, wheel `Vector3(0.92, 0.2, 0.78)`, splitter `Vector3(0.5, 0.05, 1.0)` (pecahan sumbu x, y, z dari `bounds`; titik awal, kalibrasi di Task 10). `WinningHeroCallouts.build(car_name: String, engine: String) -> Control` dengan anak `Note_engine`, `Note_wing`, `Note_wheel`, `Note_splitter` dan `Arrow_*`. `WinningHeroCallouts.place(root: Control, camera: Camera3D, model: Node3D, bounds: AABB, view: Vector2, cut: int) -> void` menaruh catatan di dekat titik terproyeksi, menampilkan engine dan wing di `HERO`, wheel dan splitter di `DETAIL`. Di scene: `func _car_bounds(model: Node3D) -> AABB` (hasil refactor dari kode di `_light_hero_car`), `var hero_callouts: Control`.

- [ ] **Step 1: Tulis test yang gagal.**
  - `anchors(AABB(Vector3(-1, 0, -2.3), Vector3(2, 1.2, 4.6)))[&"engine"]` berada di dalam AABB itu untuk keempat jangkar.
  - Setelah masuk cut `HERO` (`studio.director.tick` sampai `HERO`) dan satu frame: `hero_callouts.get_node("Note_engine").visible` dan `not hero_callouts.get_node("Note_wheel").visible`; teks catatan engine berisi `Roster.CAR_ENGINES[0]` dan tidak berisi `"HP"`.
  - Di cut `DETAIL`: `Note_wheel.visible`, `not Note_engine.visible`; posisi `Note_wheel.position` berada di dalam `Vector2(1920, 1080)` dan tidak di sudut (0, 0).
  - Kamera di `DETAIL` tiba di `DETAIL_CAMERA_POS` setelah 0.8 detik dan `studio.camera.position.distance_to(DETAIL_CAMERA_POS) < 0.05` (tween dolly), dan orbit tidak aktif di `DETAIL`.
  - Mobil lain: ganti `results.winner_car` ke `"audi_r8"`, `setup_celebration`, masuk cut `HERO`: teks catatan berisi `"5.2L V10 NA"`.

- [ ] **Step 2: Jalankan, pastikan gagal.**

- [ ] **Step 3: Implementasi.** `_show_cut(DETAIL)` menyetel `_cam_pos`/`_cam_target` lewat `Tween` 0.7 detik (`TRANS_CUBIC`, `EASE_OUT`) dari pose `HERO` ke `DETAIL`; kembali instan saat `FINAL`. `place()` dipanggil tiap `_process` selama cut `HERO` atau `DETAIL` (proyeksi mengikuti turntable yang berputar). Teks catatan: engine `"%s"` dengan sub `Roster.CAR_NAMES[team]` huruf besar; wing `"SWAN-NECK WING"`; wheel `"BBS FI-R"` sub `"FORGED"`; splitter `"CARBON SPLITTER"`.

- [ ] **Step 4: Jalankan, pastikan lulus.**

---

### Task 8: HUD akhir (cut 5) dan tower poster

**Files:**
- Create: `scripts/ui/winning_final_hud.gd`
- Modify: `scripts/ui/winning_scene.gd` (`_build_ui`, `_populate`, gaya tower)
- Test: `tests/test_winning_scene_and_standee.gd`

**Interfaces:**
- Consumes: `Kit`, `T`, `UI`, `StreetStyle`, `Roster.CAR_NAMES`.
- Produces: `WinningFinalHud.build() -> Dictionary` dengan kunci `root: Control`, `headline: Label`, `winner_label: Label`, `name_labels: Array[Label]` (urut P1, P2, P3), `time_labels: Array[Label]`, `crown: Control`. Pembangun hanya membuat kerangka; `_populate` mengisi teks. Judul = `"%s TAKES IT" % car_name.split(" ")[0].to_upper()`. Plat P1 memuat `name_labels[0]`/`time_labels[0]`; chip P2 dan P3 memuat labelnya masing-masing. Di scene tetap ada `_winner_label` (sama dengan `winner_label`).

- [ ] **Step 1: Tulis test yang gagal.**
  - Di cut `FINAL`: `name_labels[place].text.contains(driver_name.to_upper())` untuk tiga place, `time_labels[2].text.contains("+3.400s")` dan berisi `"15 PTS"`, `name_labels[0].text.contains("#01")`.
  - `headline.text == "MERCEDES-AMG TAKES IT"` untuk slug `mercedes_amg`; `"AUDI TAKES IT"` untuk `audi_r8`.
  - Posisi tower: setelah TAB `leaderboard.position.x` tepat 1280.0 (kontrak lama), `leaderboard.rotation_degrees` mendekati 1.2, dan rect global `leaderboard` tidak beririsan dengan rect global chip P2/P3/plat P1 yang dihitung dari posisi tertutup di cut `FINAL` setelah tween 0.3 detik, karena mobil dan standee bergeser kiri (`camera.h_offset > 0.5`).
  - Warna teks baris timing sekarang tinta (`Color` dengan luma < 0.2), bukan putih, agar terbaca di kertas.

- [ ] **Step 2: Jalankan, pastikan gagal.**

- [ ] **Step 3: Implementasi.** `winning_final_hud.gd` merakit: pita caution atas dan bawah (`Kit.caution_tape`), plat `"RACE COMPLETE // SUZUKA GP // 3 LAPS"` (nama sirkuit dan jumlah lap diambil dari `results` bila ada; bila tidak ada, hanya `"RACE COMPLETE"`), label cut di kanan atas, headline tag semprot di kiri atas, chip P2 dan P3 (potret bundar dari `standee_path` tidak dipakai; pakai inisial `P2`/`P3` stensil dan nama), plat P1 di poster tempel, mahkota di atas P1, baris petunjuk tombol. Tombol aksi yang ada (`toggle_button`, `restart_button`, `exit_button`) dipertahankan sebagai baris petunjuk yang sama, diberi kulit `StreetStyle.skin`. `leaderboard` diberi isi kertas (`Kit.PAPER`), rotasi 1.2°, bayangan keras.

- [ ] **Step 4: Jalankan, pastikan lulus.**

---

### Task 9: Input, impact frame, musik, dan kondisi tepi

**Files:**
- Modify: `scripts/ui/winning_scene.gd` (`_input`, `_unhandled_input`, `_ready`, `_restart`, `_exit_to_hq`, `_show_cut`, `_flash_cut`)
- Test: `tests/test_winning_scene_and_standee.gd`

**Interfaces:**
- Consumes: `WinningCutDirector`, `AudioManager.play_podium_music()`/`play_menu_music()` (Task 1), `winning_impact_frame.gdshader` (Task 4).
- Produces: `func skip_cuts() -> void` (memanggil `director.skip_to_final()`), `var _impact: ColorRect`, `func _flash_cut() -> void` (80 ms, menampilkan `_impact` lalu menyembunyikan lewat `Tween` milik scene).

- [ ] **Step 1: Tulis test yang gagal.**
  - Tombol: saat `director` belum final, `KEY_ENTER`, `KEY_SPACE`, dan klik kiri pada area kosong (`InputEventMouseButton` lewat `root.push_input`) memanggil lompat ke `FINAL`; saat sudah final Enter dan Spasi tidak memicu lompat dan tombol terfokus bekerja seperti biasa.
  - `KEY_TAB` di tengah cut: `director.is_final()` dan `is_leaderboard_open` setelah satu frame; `KEY_R` dan `KEY_ESCAPE` tetap bekerja di cut 2 (scene berganti seperti test restart/exit yang ada).
  - Impact frame: pada pergantian cut `_impact.visible` benar, dan setelah 0.15 detik tidak terlihat; pada `FINAL` hasil lompat, `_impact` tidak terlihat.
  - Musik: setelah scene masuk tree, `AudioManager.of(studio).music_track == &"podium"`; setelah `_exit_to_hq()` `== &"menu"`; setelah `_restart()` `== &"menu"` (mencegah anthem bocor ke balapan karena `start_music()` tidak memutar ulang bila sudah memutar).
  - `reduce_motion = true` sebelum masuk tree: `director.is_final()`, `_impact.visible == false`, tidak ada tween aktif (`studio.get_tree().get_processed_tweens().size() == 0`, dengan tween loop standee dibiarkan: bandingkan dengan jumlah awal sebelum scene), `camera.position` tidak berubah setelah `_process(1.0)`.
  - Skip berulang (sepuluh kali Enter) memancarkan `cut_changed(FINAL)` tepat sekali.
  - Restart di tengah cut (cut `P2_TAG`), lalu tunggu `scene_changed`: scene lama bebas (WeakRef null) dan orphan node 0 setelah lima frame.

- [ ] **Step 2: Jalankan, pastikan gagal.**

- [ ] **Step 3: Implementasi.** `_input` mempertahankan blok TAB/R/Esc yang ada dan menambah Enter/Spasi saat `director` belum final; `_unhandled_input` menangani klik kiri. TAB di tengah cut memanggil `skip_cuts()` sebelum `toggle_leaderboard()`. `_ready` memanggil `AudioManager.of(self).play_podium_music()`; `_restart()` dan `_exit_to_hq()` memanggil `play_menu_music()` sebelum `change_scene_to_file`. Dengan `Settings.reduce_motion` `start_cuts()` memanggil `director.start(true)` dan `_flash_cut()` tidak melakukan apa pun. Semua tween dibuat dengan `create_tween()` milik scene dan di-`kill()` di `_exit_tree` bila valid.

- [ ] **Step 4: Jalankan, pastikan lulus.**

---

### Task 10: Smoke native, kalibrasi visual, laporan

**Files:**
- Modify: `scratch/smoke_winning_scene.gd` (tambah tangkapan per cut), `executor-report/reports/FASE-11-LANGKAH-7-WINNING-SCENE-REPORT.md` (tambahkan addendum di akhir, jangan hapus isi)
- Create: `executor-report/screenshots/winning_scene/hero-graffiti-cut-{1..5}.png`, `hero-graffiti-final-tab.png`

- [ ] **Step 1: Perluas smoke.** Di `smoke_winning_scene.gd`, setelah studio masuk tree dan `reduce_motion = false`, untuk tiap cut 1 sampai 5 majukan `director` dengan `tick(1.95)`, tunggu `RenderingServer.frame_post_draw`, simpan lewat `_save("hero-graffiti-cut-%d")`; di cut 5 tekan TAB dan simpan `hero-graffiti-final-tab`. Pertahankan pengukuran 60 FPS yang sudah ada.

- [ ] **Step 2: Jalankan smoke native.**

Run: `godot --path . -s res://scratch/smoke_winning_scene.gd`
Expected: semua baris `[PASS]`, tidak ada `ERROR`, enam PNG 1920x1080 tersimpan.

- [ ] **Step 3: Kalibrasi terhadap mock.** Buka enam PNG dan mock (`docs/superpowers/specs/2026-10-27-winning-scene-hero-graffiti-preview.html`, cut yang sama). Sesuaikan konstanta kamera Task 5, jangkar Task 7, dan posisi elemen Task 6 dan 8 sampai: mobil terlihat penuh di cut 2 dan 5, callout menempel ke bagian yang benar, standee tidak terpotong oleh kontur, dan di cut 5 dengan TAB tidak ada tumpang tindih. Ulangi Step 2 setelah tiap penyesuaian; semua test Task 5-9 harus tetap lulus.

- [ ] **Step 4: Seluruh suite headless.**

Run (PowerShell): `$bad = 0; Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --path . -s "res://tests/$($_.Name)"; if ($LASTEXITCODE -ne 0) { $bad++; Write-Host "FAILED: $($_.Name)" } }; "gagal: $bad"`
Expected: `gagal: 0`. Ada tiga berkas test baru (`test_podium_music`, `test_winning_cut_director`, `test_graffiti_kit`), jadi jumlah suite lebih besar dari 36; laporkan jumlah sebenarnya.

- [ ] **Step 5: Laporan.** Tambah di akhir `FASE-11-LANGKAH-7-WINNING-SCENE-REPORT.md` bagian "Addendum Revisi Hero Machine Graffiti": ringkasan perubahan, jumlah suite dan hasil, angka 60 FPS dari smoke, daftar screenshot, font stensil yang dipakai (Saira atau Anton), catatan bahwa angka tenaga mobil sengaja tidak ditampilkan, dan BPM anthem (diukur atau belum).

---

## Self-review

- **Cakupan spec:** keputusan 1-8 bagian 2: lima cut (Task 2, 6, 7, 8), skip dan `reduce_motion` (Task 9), hapus podium/piala (Task 5), orbit ±6° (Task 5), turntable 0.18 (Task 5), callout tanpa HP (Task 3, 7), tim pemain ditunda (tidak ada task, sesuai spec). Bagian 6 (bahasa visual): Task 3, 4, 6, 8. Bagian 7: pemakaian ulang halftone (`UI.DOTS` di poster, Task 3), kontur hull mobil (`_apply_hero_toon` tak berubah), speedlines (belum dirakit; lihat di bawah). Bagian 8: kontrak dijaga di Global Constraints dan assertion Task 5, 8. Bagian 9: Task 1, 9. BPM anthem: dicatat di Task 10 Step 5.
- **Celah yang disengaja:** speedlines (`manga_speedlines.gdshader`) di cut 2 dan 4 belum punya langkah. Tambahkan sebagai lapisan opsional di Task 7 hanya bila screenshot Task 10 Step 3 menunjukkan cut 4 terlalu datar; bila ya, pakai shader yang ada tanpa membuat yang baru.
- **Konsistensi tipe:** `WinningCutDirector.Cut` dan `playlist_for`/`tick`/`skip_to_final`/`is_final`/`label` sama di Task 2, 6, 9. `STATION_X` kunci 1 = P2 dan 2 = P3 dipakai sama di Task 5 dan 6. `Kit` dan nama anak node (`Tag`, `GapPlate`, `Note_*`) sama antara task pembuat dan pengetes.
- **Proporsi:** rencana ini sengaja tidak berisi badan fungsi kecuali angka yang dipatok spec; detail posisi piksel mengikuti mock.
