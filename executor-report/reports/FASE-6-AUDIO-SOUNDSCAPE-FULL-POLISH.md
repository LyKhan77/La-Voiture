# LAPORAN EKSEKUTIF FASE 6: AUDIO SOUNDSCAPE & POLISHING BALAPAN PENUH

**Status:** SELESAI & TERVERIFIKASI. `tests/test_audio_and_race_weekend.gd`: **35 assertions PASS, 0 FAIL** (20 wajib + 15 tambahan: 4 untuk overlay engineer, 5 untuk suara radio, lihat bagian 5 dan 6), exit code 0, Godot 4.7.2 headless. Sembilan suite lama tetap 100% PASS (18 + 43 + 26 + 43 + 65 + 43 + 18 + 31 + 30 assertions).
**Dokumen:** `PRD/06-AUDIO-SOUNDSCAPE.md`, spec `docs/superpowers/specs/2026-10-21-phase-6-audio-soundscape-and-polish.md`, plan `docs/superpowers/plans/2026-10-21-phase-6-implementation-plan.md` (semua tahap tercentang).
**Biaya Genex:** 26 kredit (4 sfx + 1 musik 60 s); saldo 147 menjadi 121.

---

## 1. Rangkuman Implementasi

### Bus audio (`default_bus_layout.tres`)

| Bus | Volume | Isi |
|---|---|---|
| `Master` | 0 dB | kirim ke output |
| `Music` | -4 dB | loop `streetwear_synth.ogg`; di-duck saat radio |
| `SFX` | 0 dB | mesin 3D, decit ban, kerb, pit gun, letupan knalpot |
| `UI` | -2 dB | klik taktil, sirene BOX, beep start, buzzer lights out |
| `Radio` | +2 dB | `AudioEffectBandPassFilter` (cutoff 1850 Hz, resonansi 0.85, 24 dB) lalu `AudioEffectDistortion` (CLIP, drive 0.28, post gain 1.2) |

### Aset suara (`assets/audio/`, 12 file, semua ter-import)

| Sumber | File |
|---|---|
| Prosedural, `tools/audio/synth_audio.js` (Node, WAV 16-bit mono 44.1 kHz) | `ui/click_snap`, `ui/warning_siren`, `ui/start_beep`, `ui/lights_out`, `radio/squelch_in`, `radio/squelch_out`, `engine/gt3_engine_loop` (loop 1 s, semua parsial bilangan bulat Hz sehingga menutup tanpa klik, chunk `smpl` untuk loop) |
| Genex (`npx genex sfx` dan `music`, mp3 dikonversi ffmpeg) | `sfx/tire_screech`, `sfx/pit_gun`, `sfx/kerb_rumble`, `engine/gearshift_pop`, `music/streetwear_synth.ogg` (60 s, Vorbis q4) |

Mentah mp3 Genex tersimpan di `scratch/audio_raw/` sebagai provenance.

### Skrip dan scene

| File | Peran |
|---|---|
| `scripts/audio/audio_manager.gd` (autoload `Audio`, kelas `AudioManager`) | Memastikan 5 bus ada, memutar klik UI, sirene, beep start (naik 0.09 per pasang lampu), buzzer hijau, squelch radio dan musik. Setiap suara dicatat (`play_counts`, `play_log`, sinyal `sound_played`). `AudioManager.of(node)` memberi hub, atau membuatnya bila autoload tidak ada |
| `scripts/audio/engine_audio_3d.gd` | `AudioStreamPlayer3D` bus SFX, jarak maks 80 m, `ATTENUATION_INVERSE_DISTANCE`. `pitch = 0.65 + 1.20 x norm^0.85` (1200 sampai 8500 RPM), `volume = -18 + 12 x throttle + 6 x v/76` dijepit -30..+4 dB. Naik gigi membunyikan `gearshift_pop` lewat pemutar kedua |
| `scripts/audio/tire_audio_3d.gd` | Decit aktif bila `abs(lateral_g) > 1.8` atau ban terkunci (rem > 0.95 di atas 35 m/s, atau spin, sama dengan asap ban `RaceVfx`); volume `-24 + (abs(g) - 1.8) x 12` dijepit -28..0 dB |
| `scripts/audio/spatial_car_audio.gd` + `scenes/audio/spatial_car_audio.tscn` | Tiga suara 3D per mobil (mesin di belakang, ban, kerb rumble saat `abs(lateral) > 5.2 m`). Terpasang pada `scenes/race_world/gt_car_actor.tscn`, digerakkan dari `GtCarActor.present()` |
| `scripts/audio/radio_audio_director.gd` | Transmisi: squelch in, duck Music -8 dB dalam 150 ms (Tween), squelch out, pulih dalam 500 ms. Disambung ke radio cut-in anime di `RaceHud` (banner tampil = mulai, banner pergi = selesai; sinyal baru `transmission_finished`) |
| `scripts/ui/podium_screen.gd` + `scenes/ui/podium_screen.tscn` | Layar podium (lihat di bawah) |

### Integrasi ke kode lama

| File | Perubahan |
|---|---|
| `project.godot` | Autoload `Audio` |
| `scripts/car/gt_car_actor.gd`, `gt_car_actor.tscn` | Node `SpatialCarAudio`; `present()` punya parameter `audible` |
| `scripts/hud/mode_row.gd`, `tactical_deck.gd`, `race_hud.gd`, `scripts/ui/timing_tower.gd`, `scripts/hud/telemetry_drawer.gd` | Klik `click_snap` di baris mode, tab, BOX, lipat deck, ACCEPT / DISMISS, baris tower, klik panel drawer dan tombol `T`; pesan radio mendesak membunyikan sirene |
| `scripts/ui/anime_radio_cutin.gd` | Sinyal `transmission_finished` |
| `scripts/world/start_gantry.gd` | `set_lights()` membunyikan beep per pasang lampu dan buzzer saat padam |
| `scripts/car/pitstop_choreographer.gd` | Sinyal `pit_gun_fired` + `gun_shots`; 8 tembakan per stop (4 roda lepas, 4 roda pasang) lewat 4 pemutar 3D di posisi mekanik |
| `scripts/world/race_weekend_world.gd` | Musik mulai di `_ready`; mesin dan ban hening di skala waktu > 2x dan setelah podium; podium muncul dari event `CHEQUERED_FLAG` |

### Layar podium

Kanvas tetap 1920 x 1080 diskalakan ke jendela, bahasa desain pit wall (border tinta, bayangan offset keras, screentone). Tiga tingkat (P1 tengah tertinggi, P2 kiri, P3 kanan, naik dengan animasi 1.6 s), kartu pembalap (nomor, nama, kode + tim, total waktu, warna livery), piala emas, confetti, cap ungu miring `★ FASTEST LAP // +1 PT BONUS`, tabel poin FIA GT3 P1 sampai P10 (25, 18, 15, 12, 10, 8, 6, 4, 2, 1) dengan pencetak poinnya, klasemen konstruktor balapan ini (5 teratas), tombol `RESTART RACE` (muat ulang scene) dan `EXIT TO HQ` (`scenes/main.tscn`). Saat podium tampil HUD disembunyikan (`RaceHud.set_shown(false)`).

### Rulings

1. **Duck relatif.** Spec menulis target `-8.0 dB` dan pulih ke `0.0 dB`, tetapi bus Music di layout berada di -4 dB. Duck dihitung relatif ke level istirahat: -4 menjadi -12 dB, lalu pulih ke -4 dB. Bila absolut, musik akan lebih keras setelah radio daripada sebelumnya.
2. **Poin fastest lap hanya dari top 10** (konvensi tabel FIA). Mobil DNF mendapat 0.
3. **Podium muncul 2.5 s setelah bendera finis** (`PODIUM_REVEAL_S`), bukan seketika, agar mobil melewati garis dulu. Pemicunya tetap state `CHEQUERED_FLAG`; state `PODIUM` milik director (8 s) tidak diubah.
4. **Telemetry Drawer tidak punya tombol.** Klik taktilnya dipasang pada klik mouse di panel dan tombol `T`.
5. **`AudioManager.has_output()` salah di `--headless`.** Driver audio dummy meninggalkan playback hidup saat proses berhenti, sehingga suite lama mencetak error "resources still in use". Pemutaran milik hub dilewati di headless (pencatatan tetap jalan). Suara 3D tetap memanggil `play()` sehingga `playing` bisa diuji.
6. **#20 menjalankan 8 suite lama + `test_race_weekend_and_physics` dengan `-- --skip-legacy`**, karena suite terakhir itu sendiri menjalankan kedelapan suite lama (menghindari proses ganda).
7. **Aset campuran.** Klik, beep, squelch dan loop mesin dibuat prosedural (presisi dan loop mulus); suara organik (decit, pit gun, letupan, kerb, musik) dari Genex. Saya tidak bisa mendengarkan hasilnya; kualitas hanya diperiksa lewat durasi dan level (`ffmpeg volumedetect`).

---

## 2. Hasil Pengujian

Perintah:

```powershell
& "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_audio_and_race_weekend.gd
```

Capture terminal (seluruh log: `scratch/logs/p6_full.txt`):

```
[PASS] #1 the bus layout holds the five buses Master, Music, SFX, UI and Radio: Master, Music, SFX, UI, Radio
[PASS] #2 the Radio bus carries a band-pass filter at the 1.85 kHz voice centre (resonance 0.85, 24 dB)
[PASS] #3 the Radio bus carries a CLIP distortion with drive 0.28
[PASS] #4 all 12 essential audio files exist and load as non-empty streams
[PASS] #5 engine pitch climbs monotonically from 0.65 at 1200 RPM to 1.85 at 8500 RPM
[PASS] #6 engine volume rises with the throttle and with the speed (-18.0 dB idle to 0.0 dB flat out)
[PASS] #7 the exhaust pop fires on the upshift signal and not on a downshift (1 pop)
[PASS] #8 the tyre squeal starts above 1.8 G lateral (either side) or on a locked wheel, at the level -16.8 dB
[PASS] #9 the tyre squeal stays silent on a relaxed drive (1.0 G) and stops at the 1.8 G limit
[PASS] #10 music ducking drops the Music bus 8.0 dB while a radio transmission is live (-4.0 to -12.0 dB)
[PASS] #11 the Music bus is back at its normal level after the transmission (-4.00 dB)
[PASS] #12 squelch-in sounds when the transmission starts and squelch-out when it ends
[PASS] #13 tab, mode-row and BOX clicks of the Tactical Deck each play the click snap (3 clicks)
[PASS] #14 a click on a Timing Tower row (and on the Telemetry Drawer) plays the tactile snap
[PASS] #15 the countdown beeps once per red pair, a step higher each time: [1, 2, 3, 4, 5] beeps, last pitch 1.36
[PASS] #16 the green buzzer sounds once, exactly when the lights go out
[PASS] #17 the wheel gun runs eight times in a four-wheel stop: four wheels off and four on (4 off, 4 on)
[PASS] #21 the HUD radio cut-in keys the radio director: squelch-in with the banner, squelch-out when it leaves
[PASS] #22 every GT car actor carries its spatial engine and tyre voices, driven by its RPM and lateral G (20 cars rolling)
[PASS] #23 a gear change on a car pops its exhaust, and the engine goes quiet at high time scale
[PASS] #24 the podium comes up by itself after the chequered flag (3805 ticks of racing, 2.5 s later)
[PASS] #18 the podium shows P1, P2 and P3 in finishing order (CRU, TAN, SAT) on three steps, P1 tallest in the middle
[PASS] #19 the FIA GT3 table awards 25-18-15-12-10-8-6-4-2-1, adds the fastest-lap point only inside the top ten and sums the constructors (P1 scored 26)
[PASS] #25 the purple FASTEST LAP // +1 PT BONUS stamp and the RESTART RACE / EXIT TO HQ buttons are on the podium
[PASS] #26 the podium buttons raise restart_requested and exit_requested
    test_modular_car OK (18 PASS, 0 FAIL, 0 s)
    test_simulation_verification OK (43 PASS, 0 FAIL, 4 s)
    test_pit_wall OK (26 PASS, 0 FAIL, 7 s)
    test_weather_and_ai OK (43 PASS, 0 FAIL, 18 s)
    test_race_world OK (65 PASS, 0 FAIL, 55 s)
    test_gt_sim OK (43 PASS, 0 FAIL, 39 s)
    test_car_dynamics_vfx OK (18 PASS, 0 FAIL, 1 s)
    test_race_hud OK (31 PASS, 0 FAIL, 1 s)
    test_race_weekend_and_physics OK (30 PASS, 0 FAIL, 22 s)
[PASS] #20 the nine earlier suites still pass without regressions
[PASS] #27 an engineer call cuts in on the right and a driver call on the left, both at once
[PASS] #28 the engineer overlay has its own portrait, ENGINEER title and cyan accent; the driver keeps the lime one
[PASS] #29 the music stays ducked until the last of the two overlapping transmissions ends
[PASS] #30 the driver and engineer banners dock at the top of the free viewport, clear of the tower, drawer, radar, ribbon and deck, and of each other
[PASS] #31 the voice manifest lists 64 unique clips for the engineer and the driver, all loading as 24 kHz speech of 0.4 to 12 s
[PASS] #32 a sim radio text finds its clip by speaker and pattern, and a speaker or text with no recording finds none
[PASS] #33 all 165 radio calls of four short races (12 different clips used) have a voice line
[PASS] #34 a voiced call keys the squelch, speaks its clip after the lead-in (3.0 s banner hold for a 2.5 s clip), skips the siren, and ends with the key-down squelch
[PASS] #35 a call with no recorded line keeps the default banner hold and the warning siren, and speaks nothing
35 assertions, 0 failure(s)
FASE 6 ACCEPTANCE: PASS
```

Peta ke daftar spec: #1 sampai #20 sama dengan nomor spec; #21 sampai #26 adalah pengujian tambahan (cut-in radio ke director, kabel aktor, gear pop di aktor, podium otomatis, cap fastest lap + tombol, sinyal tombol).

## 3. Screenshot

`scratch/phase-6-podium.png` (1920 x 1055, GPU nyata, RTX 3050, Forward+). Dibuat dengan:

```powershell
& "<godot_console.exe>" --path . --resolution 1920x1080 --script res://scratch/capture_phase6_podium.gd
```

Balapan 2 lap penuh disimulasikan sampai bendera finis, podium muncul sendiri. Terlihat: P1 CRU (#05) tengah, P2 TAN (#17) kiri, P3 SAT (#06) kanan, piala, confetti, cap ungu fastest lap, tabel poin (P1 26 PTS karena memegang fastest lap), klasemen konstruktor, dua tombol.

## 4. Batas yang perlu diketahui

- Suara belum didengar manusia: tes memeriksa logika (pitch, volume, pemicu, bus, ducking), bukan kualitas sonik. Setel level di layout bus bila terlalu keras atau pelan.
- Test hanya jalan headless; pemutaran sungguhan (driver audio nyata) tidak tercakup, kecuali screenshot di atas yang berjalan dengan GPU tetapi tanpa verifikasi audio.
- `RESTART RACE` memakai `reload_current_scene()` dan `EXIT TO HQ` membuka `scenes/main.tscn` (kerangka kosong); keduanya hanya diuji lewat sinyal, tidak dijalankan di jendela nyata.
- Tidak ada slider volume Music / SFX di UI; `AudioManager.set_bus_volume()` tersedia untuk itu.

## 5. Tambahan: overlay radio untuk Engineer

Sebelumnya semua pesan radio (driver dan engineer) memakai satu banner dengan potret driver. Sekarang ada dua overlay dengan desain yang sama.

- **Potret baru:** `assets/manga-race-engineer-portrait.png` (Genex image `--edit` dari potret driver agar gaya tinta dan screentone sama; 7 kredit).
- **`scripts/ui/anime_radio_cutin.gd`:** properti `role` (`DRIVER` atau `ENGINEER`) dan `role_title`. Engineer = banner yang sama, dicerminkan ke tepi kanan (kemiringan, garis kecepatan dan potret di kanan), aksen cyan (merah bila mendesak). Default tetap DRIVER di kiri, jadi `PitWallDashboard` tidak berubah.
- **`scripts/hud/race_hud.gd`:** `radio` (driver, kiri) dan `engineer_radio` (kanan). Pesan dengan `speaker == "engineer"` masuk ke overlay engineer, sisanya ke driver. Keduanya bisa tampil bersamaan dan ikut tombol `H`.
- **`radio_audio_director.gd`:** melacak sumber transmisi per overlay. Squelch in dan out berbunyi per overlay; musik baru pulih setelah overlay terakhir selesai.
- **Test lama diubah satu baris:** `tests/test_race_hud.gd` (suite 5.8) memeriksa banner engineer lewat `hud.engineer_radio`, karena panggilan engineer memang pindah overlay. Hasil suite tetap 31 PASS.
- **Screenshot:** `scratch/phase-6-radio-overlays.png` (driver kiri, engineer kanan, bersamaan).
- **Penempatan (opsi A, dipilih pemilik proyek):** banner awalnya di dua pojok bawah dan menutupi baris tower P17 sampai P20 serta separuh bawah telemetry drawer. Sekarang keduanya `docked` di tepi atas area viewport yang bebas (`RaceHud.RADIO_DOCK` = x 352, y 88, 1230 x 790 piksel panggung): driver di ujung kiri, engineer di ujung kanan, di atas langit. Banner mengikuti skala HUD (`set_dock(rect, factor)`) dan muncul dengan fade turun 36 px (bukan geser dari tepi, agar tidak melintasi ribbon). `PitWallDashboard` tetap memakai penempatan lama di strip bawah. Fungsi `_lift_radio_banner` dihapus.
- **Test:** #30 menghitung kotak kedua banner dalam piksel panggung dan memastikan tidak beririsan dengan tower, drawer, radar, ribbon, deck, atau satu sama lain. Asersi radio di `test_race_hud.gd` diubah dari `offset_bottom < -150` menjadi "dasar banner di atas deck" (sadar skala panggung).
- Semua suite diulang: 30 assertions Fase 6 PASS, sembilan suite lama PASS (18, 43, 26, 43, 65, 43, 18, 31, 30). Screenshot `scratch/phase-6-radio-overlays.png` diperbarui.

## 6. Tambahan: suara radio realistis (Kokoro, gratis dan lokal)

Pesan radio sekarang diucapkan. TTS dipilih gratis: **Kokoro-82M** (Apache-2.0, ONNX, berjalan lokal lewat `kokoro-js`; tanpa kredit Genex). Suara dipilih pemilik proyek dari 6 sampel: **`bm_lewis` untuk engineer** dan **`am_eric` untuk driver**.

| File | Peran |
|---|---|
| `tools/audio/radio_lines.mjs` | Katalog 64 baris: id, speaker, regex terhadap teks persis yang dikirim sim, dan teks yang diucapkan (bentuk singkat; angka dan kode mobil dibuang, banner tetap menampilkan teks penuh) |
| `tools/audio/generate_radio_voices.mjs` | Render Kokoro, potong senyap, fade tepi, normalisasi loudness (-16 LUFS), keluaran mono 24 kHz ke `assets/audio/radio/voice/<id>.wav` (64 file, 11 MB) dan `manifest.json`. Bisa diulang (`--force`, `--only id,id`). Kokoro dipasang di folder terpisah di luar proyek (`KOKORO_DIR`) agar Godot tidak memindai `node_modules`. `tools/audio/kokoro_samples.mjs` membuat sampel audisi |
| `scripts/audio/radio_voice.gd` (`RadioVoice`) | `find(speaker, text)` mengembalikan klip pertama yang cocok, atau kosong |
| `radio_audio_director.gd` | `queue_voice()` mengembalikan lama banner; urutan: squelch in, jeda 0.22 s, suara di bus `Radio` (band-pass + distorsi), squelch out, musik pulih. Satu pemutar per overlay, klip yang diganti pesan baru dibatalkan |
| `anime_radio_cutin.gd` | `play_radio(..., hold)`: banner bertahan selama klip (minimal 2.6 s) menggantikan 3.5 s tetap |
| `race_hud.gd` | Mencari klip tiap pesan; pesan tanpa klip tetap hanya teks |

Rulings tambahan:
1. **Sirene BOX dilewati bila pesan bersuara.** Hampir semua panggilan engineer berstatus mendesak; sirene 1.2 s di atas ucapan mengganggu dan mengulang sinyal yang sudah dibawa suara. Pesan tanpa klip tetap berbunyi sirene.
2. **Angka tidak diucapkan.** Persentase air, suhu dan kode mobil dibuang dari ucapan karena kombinasinya tak terhingga; banner menampilkan teks lengkap.
3. **Cakupan terukur, bukan diasumsikan.** Test #33 menjalankan 4 balapan pendek (kering, hujan sesekali, badai, basah mengering), mengumpulkan semua pesan radio sim (165), dan menuntut semuanya punya klip. Bila sim menambah teks baru tanpa klip, test ini menyebut teksnya.
4. **Hasil lewat bus Radio asli diukur**: klip direkam melewati band-pass 1850 Hz + distorsi CLIP di Godot; level rata-rata -18 dB (engineer) dan -14 dB (driver), tidak senyap. Rekaman ada di `scratch/voice_samples/ingame_*.wav`.

Batas: kualitas dan kemiripan nada hanya bisa dinilai dengan telinga. Bila suara kurang cocok, ganti `VOICES` di `radio_lines.mjs` (atau `speed`) lalu jalankan generator dengan `--force`. `npm audit` mencatat peringatan pada dependensi `kokoro-js`; paket hanya dipakai lokal di build untuk teks tulisan sendiri.
