# FASE 11 / LANGKAH 6 — Laporan Eksekutif Lengkap (handoff ke planner)

**Judul:** Dinamika insiden GT3, panel bendera digital, bangkai DNF + evakuasi, steward penalty, dan polishing radio comms
**Tanggal:** 2026-10-26 · **Branch:** `main` · **Engine:** Godot 4.7.2 stable
**Status:** selesai dan terverifikasi (suite headless + smoke native + review independen dengan perbaikan). **Belum di-commit**, seluruh perubahan masih di working tree (lihat bagian 9).
**Acuan:** spesifikasi `docs/superpowers/specs/2026-10-26-track-incidents-and-stewarding-design.md` · rencana `docs/superpowers/plans/2026-10-26-track-incidents-and-stewarding-plan.md` · handoff `prompt/TASK-TRACK-INCIDENTS-AND-STEWARDING.md` · aturan `AGENTS.md`

---

## 0. Ringkasan untuk planner

| Hal | Hasil |
| :--- | :--- |
| Lingkup handoff (Task 1–4) | Semua selesai. |
| Tambahan di luar handoff | Balon radio comms manga (redesain, atas permintaan pengguna), suara steward, klip suara radio evakuasi, panel dan animasi terverifikasi. |
| Suite headless | **35/35 suite, 909 assertions, 0 FAIL, 0 script error** (diperiksa dari output, bukan hanya exit code). |
| Suite baru | `tests/test_track_incidents_and_stewards.gd`: 55 assertions. `tests/test_radio_r2.gd` ditulis ulang: 28 assertions. |
| Smoke native | High / 1080p / thunderstorm malam / 20 mobil / 3 lap / insiden aktif / RTX 3050 Laptop: **55,38 FPS rata-rata, p95 25,79 ms, max 33,83 ms, 0 orphan**. Gerbang (≥ 50 FPS, p95 ≤ 32 ms) lulus. Tren tiga run ada di bagian 4. |
| Review | Reviewer fresh-context (model terkuat, read-only): 2 temuan Important, 8 Minor. **Semuanya diperbaiki**, masing-masing dengan tes yang gagal dulu. |
| Match collider | 190 pasangan diuji tiap tick selama slide, `race.cars.size() == 20`, 0 overlap, 0 NaN. |
| Terbuka | Lihat bagian 8 (backlog dan risiko). |

---

## 1. Hasil per modul

### Task 1 — Kehilangan kendali (tanpa putaran 360°)
- `GtDriving._spin_recovery`: `yaw_offset = slide_dir · 0.45 · e^(−1.15 t) · cos(7.5 t)`. Puncak 0,45 rad (batas 0,55), kembali ke ±0,006 rad. Meluncur ke verge luar 2,8 m/s; kecepatan turun 16 m/s² dengan lantai 12 m/s (`minf(v, maxf(12, v − 16·dt))`, tidak pernah mempercepat).
- `GtCar.slide_time` (baru) menjalankan envelope; `GtCar.start_spin(duration)` (baru) memulai spin dan mereset envelope. Dipakai di `gt_contacts.gd` (3 tempat) dan puncture di `gt_driving.gd`.
- Opposite lock ditulis sim ke `car.steer_angle = −clamp(yaw·1.6, ±0.65)`; `GtCarActor` menggambar yaw dan setir mentah (tanpa ease) selama slide, ditambah guncangan suspensi 9 Hz.
- `spin_angle` **dihapus** (tidak lagi dibaca siapa pun).

### Task 2 — Panel bendera LED
- 8 panel 1,8 × 1,2 m dalam **satu** `MultiMeshInstance3D` (`FlagPanels`) di `TracksideFurnitureBuilder`. Penempatan: sebelum garis finis, Turn 1, hairpin, chicane (maksimal 5), sisanya membagi celah terlebar; tiap sektor punya minimal satu panel.
- Shader `shaders/digital_flag_panel.gdshader` (dot-matrix 30 × 20): hijau redup statis, chevron kuning 4 Hz, `SC` kuning/oranye bergantian. Status per instance lewat custom data; `apply_flag(flag, sector)` hanya menulis panel yang berubah. YELLOW hanya menyalakan panel sektornya; VSC dan SC menyalakan semua.
- `RaceWeekendWorld._update_flag_panels()` menyinkronkan panel dengan `race.race_control`.

### Task 3 — Bangkai DNF dan evakuasi
- Mobil DNF bersandar `wreck_yaw` (17,5° pada dinding, diskalakan jarak ke barrier), asap komik dari kap dan 4 lampu hazard oranye 1,5 Hz (dibangun lazy hanya untuk mobil DNF, `RaceVfx`).
- Saat Safety Car `IN_THIS_LAP`: `GtRace._start_wreck_evacuation()` memulai fade 2 s lewat `car.wreck_alpha` (transparansi per-mesh, tidak menyentuh material bersama), menyembunyikan aktor di alpha 0, dan mengirim radio *"Track clear in Sector N. Recovery complete, Safety Car in this lap."* (sektor wreck terbaru). `race.cars` tetap 20.

### Task 4 — Steward penalty lite
- `GtStewards` (baru): kontak nose-to-tail dengan closing > 2,8 m/s (diukur sebelum hold-back) membuka kasus at-fault; kontak berat lain yang meningkat menjadi `_collision_incident` membuka kasus racing incident. Investigasi 10 s lalu +5 s atau NFA. Deterministik (tanpa RNG).
- Tidak ada kasus untuk: 45 s pertama balapan (konsertina start), offender yang sama < 60 s, pasangan yang sama < 20 s, mobil depan yang sedang slide atau puncture, dan bendera SC/VSC. Kasus yang masih terbuka saat balapan selesai ditutup seketika (`close_all`).
- Penalti: dilayani di box (mobil ditahan 5 s sebelum `pit.timer` berjalan, kru tidak bekerja) atau, bila mobil tidak pit lagi, `penalty_owed_s` ditambahkan lewat `GtRace.classified_time()` ke urutan `standings()` dan waktu podium (label `+5s PENALTY`).
- HUD: `StewardBanner` (amber untuk investigasi, crimson berstrip hazard untuk penalti, hijau redup untuk NFA). Suara: beep saat investigasi, palu + buzzer saat penalti, sunyi saat NFA.

### Polishing radio comms (permintaan pengguna)
Banner radio lama (470 × 190, menempel di atas area tengah) menimpa banner SC, banner Steward dan Weather Deck. Diganti **balon manga** (`scripts/ui/anime_radio_cutin.gd`, konsep "2b" yang disetujui pengguna):
- 258 × 92 (tinggi bertambah sampai 3 baris), dock di dua sudut bawah area bebas: driver x 360, engineer sampai x 1582, dasar y 868. Tes memastikan tidak menimpa banner SC/Steward, caution tape, Weather Deck, kartu saran, toast ban, tower, deck.
- Outline tinta bergerigi + bayangan keras + screentone, potret bulat dengan garis fokus berkedip 12 fps, ekor petir, kata kunci sebagai stiker aksen, SFX `ザザッ` / `ガガッ!`, tetes keringat saat urgent, equalizer 8 gigi, outline bergetar ±2 px "on twos" (diam saat reduce motion).
- API publik tidak berubah (`play_radio`, `set_dock`, `set_dimmed`, `set_base_color`, `set_portrait`, sinyal). Pop masuk tumbuh dari tengah-bawah.
- `RadioMarkup.highlight` mendapat parameter opsional `bold`.

### Aset baru
- Klip suara radio evakuasi `eng_track_clear_1..3` (Kokoro `bm_lewis`, lewat `tools/audio/radio_lines.mjs`; `manifest.json` +21 baris, tidak ada yang dihapus).
- `steward_investigation.wav` dan `steward_penalty.wav` (Genex `sfx`, sekitar 2 kredit per klip; mp3 sumber di `scratch/audio_raw/`).

---

## 2. Berkas yang berubah

**Diubah (22 berkas):** `scripts/gt/{gt_driving,gt_car,gt_pit,gt_race,gt_contacts}.gd` · `scripts/car/gt_car_actor.gd` · `scripts/vfx/race_vfx.gd` · `scripts/world/{trackside_furniture_builder,race_weekend_world}.gd` · `scripts/hud/race_hud.gd` · `scripts/ui/{podium_screen,anime_radio_cutin,radio_markup}.gd` · `scripts/audio/audio_manager.gd` · `scenes/pit_wall/anime_radio_cutin.tscn` · `tools/audio/radio_lines.mjs` · `assets/audio/radio/voice/manifest.json` · `tests/{test_radio_r2,test_track_environment,test_audio_and_race_weekend}.gd` · `ROADMAP.md`.

**Baru:** `scripts/gt/gt_stewards.gd` · `scripts/hud/steward_banner.gd` · `shaders/digital_flag_panel.gdshader` · `tests/test_track_incidents_and_stewards.gd` · `scratch/smoke_incidents_stewards.gd` · `scratch/capture_radio_balloon.gd` · 3 klip `eng_track_clear_*.wav` · 2 klip `steward_*.wav` · screenshot `phase-11-step-6-*.png` · dokumen spesifikasi/rencana/handoff · laporan ini. Berkas `.uid` dan `.import` ikut dihasilkan engine.

**Tidak disentuh:** `Curve3D` di `scenes/race_world/track_circuit.tscn`, GLB mentah, model mobil.

---

## 3. Verifikasi

- **TDD:** setiap perilaku ditulis sebagai tes merah dulu (diamati gagal), baru diimplementasikan. Pengecualian: tes animasi balon dan klip suara ditulis setelah kodenya ada, dan diperiksa terhadap kode yang berjalan.
- **Exit code menyesatkan:** Godot headless keluar 0 setelah `SCRIPT ERROR`. Semua run memeriksa output untuk `SCRIPT ERROR|Parse Error|[FAIL]`.
- **Animasi terbukti berjalan** (`test_radio_r2`, frame nyata): pop dimulai 1,4× / 6° / transparan lalu mendarat sendiri dalam 0,7 s; outline melewati 4 pose dan garis fokus 2 fase; gigi equalizer mencapai 0,91 lalu rata; reduce motion membuat semuanya diam.
- **Screenshot native 1920 × 1080** di `executor-report/screenshots/phases/`: `phase-11-step-6-flag-panel-yellow.png`, `-flag-panel-sc.png`, `-snap-oversteer-countersteer.png`, `-dnf-wreck-smoke-hazard.png`, `-dnf-evacuation-fade.png`, `-steward-penalty-banner.png`, `-radio-balloons-routine.png`, `-radio-balloons-urgent.png`. Alat: `scratch/smoke_incidents_stewards.gd`, `scratch/capture_radio_balloon.gd`.

---

## 4. Performa (smoke native 1× dengan insiden)

| Run | FPS rata-rata | p95 | max |
| :--- | :--- | :--- | :--- |
| Setelah Langkah 6, sebelum balon baru | 60,05 | 26,10 ms | 30,16 ms |
| Setelah balon, suara dan klip | 57,50 | 26,07 ms | 64,07 ms |
| Setelah perbaikan review | 55,38 | 25,79 ms | 33,83 ms |

Ketiganya melewati gerbang (≥ 50 FPS, p95 ≤ 32 ms), tetapi **rata-rata menurun dari 60,05 ke 55,38**. Penyebabnya belum diisolasi: insiden yang di-stage berbeda tiap run, satu mesin dengan proses lain berjalan, dan balon baru menggambar lebih banyak poligon. Lonjakan 64 ms pada run kedua tidak muncul lagi; dugaan: `RadioVoice.find` memuat klip WAV saat panggilan pertama (perilaku lama). p95 sekitar 26 ms berada di atas frame budget 16,66 ms sejak sebelum langkah ini. Rekomendasi planner: profiling terpisah bila 60 FPS ketat tetap menjadi target.

---

## 5. Review independen dan disposisinya

Reviewer fresh-context membaca seluruh diff dan menjalankan probe sendiri. Setiap temuan diverifikasi ulang sebelum diperbaiki.

| # | Tingkat | Temuan | Disposisi |
| :-- | :--- | :--- | :--- |
| 1 | Important | Mobil yang retire saat slide menyimpan `spin_timer > 0` selamanya (bangkai tidak bersandar, guncangan jalan terus, ban berdecit tanpa henti). | **Diperbaiki:** cabang `is_dnf` mereset `spin_timer` dan `slide_time`. Tes: `review: a car retired mid-slide stops spinning`. |
| 2 | Important | Glyph `S` pada panel `SC` terbalik vertikal (terbaca "2C"); terlihat di screenshot dan sempat terlewat. | **Diperbaiki:** `rows[6 - g.y]`. Diverifikasi di screenshot native (terbaca `SC`). |
| 3 | Minor | Spin baru saat slide masih berjalan melanjutkan envelope lama. | **Diperbaiki:** `GtCar.start_spin()` di semua titik. Tes ada. |
| 4 | Minor | Steward menghukum menabrak mobil yang sedang slide/puncture atau di bawah SC/VSC. | **Diperbaiki:** guard di `report_nose_to_tail`. Tes ada, termasuk kontrol bendera hijau. |
| 5 | Minor | Kasus terbuka saat balapan selesai tidak pernah diputuskan. | **Diperbaiki:** `GtStewards.close_all()` saat `is_finished()`. Tes ada. |
| 6 | Minor | Radio evakuasi menyebut sektor yang salah. | **Diperbaiki:** memakai wreck terbaru (`finished_at` terbesar). Tes ada. |
| 7 | Minor | Dim saat pop masuk menghasilkan alpha salah (tween menimpa). | **Diperbaiki:** alpha = progres fade × alpha istirahat. Tes ada. Efek samping: `test_audio_and_race_weekend` #30 hanya lulus karena bug itu (balon engineer yang di-dim kembali ke alpha 1,0); syarat `alpha == 1.0` diubah menjadi `>= 0.59` (terlihat penuh atau di-dim). |
| 8 | Minor | Balon yang tampil tidak mengikuti resize jendela. | **Diperbaiki:** `set_dock` menempatkan ulang pose istirahat. Tes ada. |
| 9 | Minor | Beberapa assertion tidak membuktikan apa pun (tautologi; "tidak ada kasus" tanpa memastikan kontak terjadi). | **Diperbaiki:** tautologi dihapus; tes "tidak ada kasus" kini menegaskan `contacts_last > 0`; tes countersteer independen dari rumus sim. **Belum:** jalur BOX dengan antrean rekan satu tim (`_service_car` dipanggil langsung di tes). |
| 10 | Minor | `spin_angle` mati; komentar "dithers" salah. | **Diperbaiki:** field dihapus; komentar dikoreksi (transparansi per-mesh). |

**Tidak dapat diverifikasi reviewer (butuh GPU), status sekarang:**
- Fade pada material toon: terlihat bersih di screenshot `dnf-evacuation-fade` (outline hull masih tampak samar).
- Posisi panel di setiap lokasi: tidak diperiksa satu per satu.
- Overflow `RichTextLabel` dengan huruf tebal Anton: belum diuji dengan teks terpanjang di layar.
- Fallback font katakana: lihat bagian 8.
- FPS setelah balon: sudah diukur (bagian 4).

---

## 6. Ruling (penyimpangan dari rencana/handoff, beserta biaya bila salah)

1. **Opposite lock ditulis sim** (`car.steer_angle`), bukan dihitung ulang di aktor. Biaya: pindahkan satu baris.
2. **`slide_time` + `start_spin()`** menggantikan `4.0 − spin_timer` dari handoff (`spin_timer` mulai dari 1,8 / 3,6 / 4,0 s menurut sumber insiden). `spin_angle` dihapus.
3. **Kecepatan slide `minf(v, maxf(12, v − 16·dt))`**, agar mobil di bawah 12 m/s tidak dipercepat.
4. **`test_track_environment` #F1 dan #P3 diubah** (4 → 5 dan 7 → 8 MultiMesh) karena aturan satu `MultiMeshInstance3D` untuk panel.
5. **Grace 45 s dan cooldown offender 60 s** pada steward (tidak ada di spesifikasi): tanpanya run native pertama menghasilkan sekitar 30 penalti dalam 3 lap. Biaya: dua konstanta di `gt_stewards.gd`.
6. **Teks banner investigasi** memakai spesifikasi desain (`INCIDENT INVOLVING CAR #%d UNDER INVESTIGATION`), bukan teks pendek di handoff; vonis 10 s (handoff), bukan 8–12 s (desain). Rub ringan tidak dibuka sebagai kasus.
7. **Nama shader** `digital_flag_panel.gdshader` mengikuti handoff, bukan konvensi `spatial_*` di `.claude/rules/shader-code.md` (shader lain di repo juga tidak mengikutinya).
8. **Steward mengecualikan** mobil depan yang slide/puncture dan bendera SC/VSC (hasil review). Biaya: penalti sah di bawah SC tidak dijatuhkan.
9. **Konsep balon "2b" dan slot dock** dipilih pengguna; engineer berhenti di x 1582 agar tidak menyentuh toast ban (berakhir x 1320).
10. **Pop balon tumbuh dari tengah-bawah** (pivot kiri-atas membuat dasar melewati deck dan merusak `test_race_hud`).
11. **Alpha balon = progres fade × alpha istirahat**; tes #30 diubah (bagian 5, #7).
12. **`kokoro-js` dipasang di luar proyek** (scratchpad) untuk membuat klip radio, sesuai catatan di `generate_radio_voices.mjs`.
13. **Bekerja langsung di `main` tanpa commit** (target tertulis di handoff; commit tidak diminta).

---

## 7. Cara menjalankan dan regenerasi

- Suite penuh (PowerShell): `Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --path . -s "res://tests/$($_.Name)" }`; periksa keluaran untuk `SCRIPT ERROR|Parse Error|[FAIL]`. `godot` hanya ada di PATH PowerShell, bukan bash.
- `class_name` baru (`GtStewards`, `StewardBanner`) butuh `godot --headless --path . --import` sekali sebelum test headless melihatnya.
- Smoke native: `godot --path . -s res://scratch/smoke_incidents_stewards.gd -- --smoke`; capture balon: `godot --path . -s res://scratch/capture_radio_balloon.gd`.
- Klip radio: `KOKORO_DIR=<folder dengan kokoro-js> node tools/audio/generate_radio_voices.mjs --only <id,id>` (butuh `ffmpeg` di PATH).
- Berkas repo ini memakai CRLF; penggantian teks multibaris lewat skrip PowerShell gagal, gunakan alat Edit.

---

## 8. Backlog dan risiko terbuka (untuk planner)

1. **FPS:** rata-rata native turun ke 55,4 (bagian 4); p95 sekitar 26 ms di atas frame budget 16,66 ms. Perlu profiling bila 60 FPS ketat tetap target.
2. **Font Jepang:** katakana (`ザザッ`, `ガガッ!`) dirender lewat font cadangan sistem (seperti banner Safety Car yang sudah ada). Proyek belum membawa font Jepang; build di sistem tanpa font Jepang bisa menampilkan kotak kosong. Solusi: tambahkan subset Noto Sans JP.
3. **Jalur BOX dengan antrean rekan satu tim** untuk penalti di box belum diuji langsung.
4. **Steward:** belum ada penanganan restart SC (konsentrasi mobil setelah restart masih bisa menghasilkan kasus); tidak ada drive-through; penalti yang dijatuhkan setelah mobil melewati box menjadi tambahan waktu di podium; mobil DNF di bawah yellow flag saja tidak dievakuasi (evakuasi hanya terpicu `IN_THIS_LAP`).
5. **Panel bendera:** posisi di setiap lokasi belum diperiksa satu per satu (tidak melayang, tidak menembus pagar); tampilan LED hanya terverifikasi lewat render native pada dua lokasi.
6. **`RichTextLabel` balon:** keyword memakai huruf Anton yang lebih lebar daripada font ukur (celah 8 px); belum diuji dengan teks terpanjang.
7. **`npm audit`:** `kokoro-js` melaporkan 3 kerentanan tingkat tinggi pada dependensinya; hanya dipakai offline di luar proyek.
8. **Review:** reviewer fresh-context hanya menjalankan dua suite sendiri; seluruh 35 suite dijalankan oleh penulis.

---

## 9. Status git

Semua perubahan **belum di-commit** (22 berkas terlacak diubah, ditambah berkas baru tak terlacak). Berkas tak terkait yang sudah berubah sebelum sesi ini (`assets/characters/pitcrew/*.import`, `meshy_output/`, `production/session-logs/`) tidak disentuh. Tidak ada yang dihapus atau ditimpa dari aset milik orang lain.
