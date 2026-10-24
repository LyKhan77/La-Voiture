# LAPORAN RINGKASAN LENGKAP FASE 11 / LANGKAH 3: HUD REDESIGN V2 (3A-3E)

Dokumen serah-terima untuk agent planner (yang akan melakukan merge). Merangkum semua yang dikerjakan di Langkah 3, bagaimana rencana awal berubah, apa yang berubah di perilaku sim, hasil verifikasi, seluruh ruling dan temuan yang ditunda, dan apa yang masih belum dikerjakan. Laporan rinci tiap sub-langkah ada di berkas `FASE-11-LANGKAH-3A…3E-*-REPORT.md` di folder yang sama. Ledger kerja (`.superpowers/sdd/*/progress.md`) di-ignore git, jadi isi pentingnya disalin ke bagian 7 dan 8.

Godot 4.7.2 stable, Windows. Semua cabang ada di repo lokal `D:\Occupation\Porto\genex\La_Voiture`, belum ada yang di-push atau di-merge.

---

## 1. Ringkasan eksekutif

| Sub-langkah | Isi | Cabang (HEAD) | Suite headless setelahnya |
|---|---|---|---|
| **3a** Mekanik pit wall | Mode DESK MANUAL/AUTO (HYBRID dihapus), jendela saran 10 detik, `cancel_pit` tanpa penalti, tombol BOX dua-state, bar api di kartu saran, tombol B / ESC / ENTER | `feat/langkah-3a-pit-mechanics` (`b4f1b19`) | 28/28 |
| **3b** Tema tim + drawer telemetry | Warna HUD mengikuti aksen tim, warna engineer komplementer, drawer telemetry konsep F (hero mobil X-ray, onomatope, caption) | `feat/langkah-3b-team-theme-telemetry` (`fc3daac`) | 29/29 |
| **3c** Deck N2 "Faders Console" | Tiga fader PACE/FUEL/ERS dengan gauge berzona dan verdict OK/WATCH/DANGER dari rumus sim, roda ban berputar, chip ban, COACH, tooltip, kartu BOX WINDOW, umpan balik klik | `feat/langkah-3c-deck-n2` (`11fb542`) | 30/30 |
| **3d** Cuaca | Chip ribbon dengan ladder 8 lap dan Weather Deck (grafik air + kerucut ketidakpastian, peta lintasan, NEXT CHANGE, SET TYRES) | `feat/langkah-3d-weather-ladder` (`fc314aa`) | 31/31 |
| **3e** Radio R2 dua arah | Kartu kertas tempel, driver dan engineer meredup bergantian, balasan engineer 2.5 s setelah panggilan driver, panggilan banjir | `feat/langkah-3e-radio-r2` (`1246686`, terbaru) | 32/32 (31 hijau di run penuh terakhir, satu test disesuaikan lalu dijalankan ulang sendiri dan hijau) |

Semua cabang **bertumpuk** (3b di atas 3a, dst.). Cabang `feat/langkah-3c-deck-n2` juga memuat commit spec v2, berkas referensi desain, rencana 3a–3c, dan rencana 3d. Total perubahan kode dan test terhadap `main` (`6c8faad`): **55 berkas, +4771 / −416 baris** (`scripts/` dan `tests/`).

Tiap sub-langkah dikerjakan dengan alur: spec → rencana → eksekusi mandiri (native, TDD) → review akhir seluruh cabang oleh agen terpisah (model `fable`) → satu putaran perbaikan TDD untuk temuan Critical/Important → regresi penuh → laporan dan screenshot native.

---

## 2. Permintaan awal dan bagaimana rencana berubah

### 2.1 Permintaan awal

Handoff dari agent sebelumnya meminta Langkah 3: *Tactical Pit Wall Deck Refinement & Two-Way Radio Comms* dengan aturan **jangan ubah posisi layout UI**, acuan visual `ui_step_3_hud_preview.html`, dan lingkup: tombol pit dua-state, mode MANUAL/AUTO, bar api 10 detik, radio dua arah, test `tests/test_pit_deck_and_radio.gd`, 27 suite tanpa regresi, screenshot native, laporan `FASE-11-LANGKAH-3-…`, dan pembaruan `ROADMAP.md`. Spec dan rencana lama dari agent itu (`…-langkah-3-tactical-deck-and-radio-design.md`, `…-plan.md`, `prompt/TASK-LANGKAH-3-…md`) **tidak diubah** dan tidak dimasukkan commit.

### 2.2 Sebelum eksekusi: diskusi UI/UX yang mengubah lingkup

Sebelum mengeksekusi, pengguna meminta diskusi UI/UX karena belum puas dengan konsep Telemetry UI. Diskusi panjang itu menghasilkan **spec v2** (`docs/superpowers/specs/2026-10-24-langkah-3-hud-redesign-v2-design.md`) yang jauh lebih luas dari handoff:

| Urutan | Keputusan pengguna | Dampak |
|---|---|---|
| 1 | Minta 5 konsep Telemetry beranimasi | Dibuat 5 konsep (A–E) dalam mockup HTML |
| 2 | "Bisakah B dan D dikombinasikan?" lalu memilih **F** (B×D, hero mobil X-ray, tema gelap) | Telemetry = konsep F |
| 3 | Elemen putih kurang menyatu dengan tema HUD | Warna chrome mengikuti **aksen tim**; warna makna data tetap |
| 4 | Warna elemen mengikuti tim; info cuaca di ribbon masih minim; usul merge deck + telemetry; konsep radio baru toon manga × grafiti | Tema tim, ribbon cuaca ladder, layout baru, tiga konsep radio |
| 5 | Ladder cuaca dan tema disetujui; **strategi tetap di bawah** dan telemetry terpisah di kanan; peta (radar) yang belum masuk mockup harus dihitung; memilih **R2** untuk radio | Layout lock diperbarui; radio R2 |
| 6–8 | Minta alternatif peletakan elemen deck; mempertanyakan matriks yang redundan dengan telemetry; minta polishing | "One datum one home": telemetry = sensor sekarang, deck = keputusan dan konsekuensi. Opsi N2 dibuat |
| 9–10 | Setuju **N2**; matriks harus ramah pemula dan menunjukkan batas; selector ban/pit diganti **roda berputar** dengan umpan balik klik | Verdict ✓▲✖ dengan zona dan batas, COACH, roda ban, tooltip bahasa biasa |
| 11 | "Mode Hybrid jadi dihilangkan" | MANUAL = kartu tertutup saat habis, AUTO = kartu dieksekusi saat habis; perilaku sim berubah |
| 12–13 | "Tulis rencana 3a", "Pakai Native" | Eksekusi mandiri, satu reviewer di akhir per cabang |

### 2.3 Rencana awal vs hasil

| Aspek | Handoff / spec lama | Yang dikerjakan | Alasan |
|---|---|---|---|
| Lingkup | Deck + radio | Tema tim, telemetry F, deck N2, ribbon cuaca + Weather Deck, radio R2, tambah mekanik 3a | Hasil diskusi UI/UX (bagian 2.2) |
| Mode DESK | MANUAL / AUTO / HYBRID | **MANUAL / AUTO saja** | Keputusan pengguna; spec §6 |
| Pembagian pekerjaan | Satu langkah | **Lima sub-langkah** 3a–3e, tiap sub-langkah satu cabang, satu rencana, satu laporan | Modul cukup independen; bisa direview dan diverifikasi sendiri-sendiri |
| Angka verdict | Angka mockup (aus +9 % / +19 %, ERS −12 % / −35 % per lap) | **Nilai sim** lewat `GtForecast` (tabel pengali di `GtTypes`); ERS dihitung per detik deploy, bukan per lap | Angka mockup placeholder dan salah satuan; spec §5 mewajibkan nilai sim |
| Ambang cuaca | 35 % wet, 10 % slick (mockup dan spec) | **45 % wet, 18 % inter** (`GtForecast`, sama dengan `decide_strategy`) | Menyamai sim; tick tabung dan garis grafik mengikuti |
| Pemicu banjir radio | Air > 35 % | **> 45 %** (hilang bila < 18 %) | Menyamai ambang sim |
| Isi balasan engineer | "Box this lap, confirming fresh rubber!" | Laporan fakta dari sim (umur ban, air trek) yang menyerahkan keputusan BOX ke pemain | Di MANUAL engineer tidak boleh seolah memerintahkan BOX |
| Warna kartu radio | Driver lime, engineer cyan | Driver = **warna tim** yang bicara, engineer = **warna komplementer** (`GarageStyle.engineer`), urgent crimson | Konsep R2 dan tema tim |
| Posisi kartu engineer | (spec 3e: kanan-tengah dock) | **Sebaris dengan kartu driver** di tepi atas dock | Permintaan pengguna di akhir: posisi tengah menutupi mobil |
| Tombol aksi Weather Deck | "SET BOX CALL L+n → compound" | **"SET TYRES L+n > compound"**: hanya memilih ban untuk BOX berikutnya | Memanggil BOX sekarang menyalahi arti lap L+n |
| Peta air per sektor | (tidak ditentukan) | Heuristik tampilan `air + [0, +10, −8]` | Sim tidak punya air per sektor; dry line memakai `drying_line_pct` sim |
| Font angka kecepatan | Dela Gothic One (mockup) | Anton | Dela Gothic One tidak ada di `assets/fonts` |
| Berkas lama `step_bar.gd`, `telemetry_widgets.gd` | — | Dibiarkan (tidak dipakai atau hanya sebagian) | Aturan #1 proyek: tidak menghapus yang bukan buatan sendiri |
| Laporan | Satu `FASE-11-LANGKAH-3-…` | Lima laporan per sub-langkah + dokumen ini | Tiap cabang diverifikasi terpisah |
| Test suite | 27 suite | 32 suite | Ada suite baru per sub-langkah |

Aturan utama handoff **dipertahankan**: seluruh kotak layout (ribbon 1888×60, chip cuaca 350×56, tower, radar, records, drawer, kartu saran, deck 1888×140 / 1888×44, marquee, radio dock) tidak berpindah. Overlay baru yang diizinkan spec: tooltip deck dan Weather Deck dropdown.

---

## 3. Isi tiap sub-langkah

### 3a. Mekanik pit wall
- `GtTypes.TacticMode` hanya `{MANUAL, AUTO}`; default MANUAL; `GtRace.SUGGESTION_WINDOW_S = 10.0`, `suggestion_remaining()`, `_expire_suggestion()`, `_check_advisor_tactics()`; `decide_strategy` kini menyarankan juga untuk pemain.
- `cancel_pit(car_id)` di `GtRace` dan `RaceWeekendWorld`: tanpa penalti, memulihkan pacing, radio "Stay out, stay out! Box call cancelled.", kartu BOX yang terbuka untuk mobil itu ikut ditutup, saran BOX berikutnya menunggu 30 detik.
- Tombol BOX satu kontrol dua-state (REQUEST BOX [B] ↔ CANCEL BOX [ESC] // compound), bar api 10 detik di kartu saran (merah dan berkedip saat kritis, menghormati `reduce_motion`), tombol B / ESC / ENTER.
- Dokumen PRD yang menyebut HYBRID diperbarui. Test: `tests/test_pit_deck_and_radio.gd` (awal 26 assertion), `tests/test_race_hud.gd` disesuaikan.

### 3b. Tema tim dan drawer telemetry
- `GarageStyle.engineer_for(accent)` (cyan, pink, lime, kuning dengan selisih hue > 55°), `RaceHud.set_team_accent(team_id)` mengecat logo, marquee, header deck.
- `TelemetryState` (data: jejak pedal 96 sampel, jejak G 40, tint panas ban, caption ketik 42 cps, onomatope maksimum 2 sekaligus) dan `TelemetryPainter` + `TelemetryDrawer` (satu `_draw`): hero mobil X-ray, panel miring, speed lines, halftone, ECG, caption, onomatope (GUOOO!!, KACHA!, VWOOOM!, JIRI JIRI, DON!!). Semua mematuhi `reduce_motion`.
- Test: `tests/test_hud_theme_and_telemetry.gd` (30 assertion).

### 3c. Deck N2
- `GtTypes` memusatkan tabel pengali sim; `GtForecast` (`wear_per_lap`, `burn_per_lap`, `tyre_life_at_finish`, `fuel_margin_laps`, `ers_seconds`, `recommended_compound`, `auto_compound`, `verdict`, `tyre_verdict`): OK / WATCH / DANGER terhadap cliff 75 % keausan, sisa bensin dalam lap, detik deploy baterai, dan kecocokan ban dengan cuaca. **Pilihan tidak pernah dikunci.**
- Widget: `SeverityMark` (ikon digambar sebagai bentuk), `FaderLadder`, `ZonedGauge` (12 blok, garis batas, ghost proyeksi finish), `ChipGrid`, `TyreWheel`, `DeckTip`, `DeckCoach` (semua kalimat bahasa biasa dalam satu tabel), `AudioManager.click_pitched`.
- `TacticalDeck` ditata ulang dalam kotak 1888×140 yang sama; umpan balik klik di tiap kontrol (tekan 0.92→1, teks pop, klik berpitch, roda dihentak); debounce BOX 0.25 s pada klik tombol.
- Test: `tests/test_deck_n2.gd` (33 assertion).

### 3d. Ribbon cuaca dan Weather Deck
- `GtWeatherOutlook` (data murni): baris per lap, ringkasan perubahan ban dan state pertama, lap BOX ideal, confidence, sebaran kerucut; tidak menyarankan ganti ban setelah bendera finis atau untuk BOX di lap finis.
- Chip ribbon: ladder 8 kolom (NOW, BOX, crossover berdenyut, kolom setelah finis redup, tabung wet dengan tick 18 % / 45 %). Weather Deck: grafik 11 titik dengan kerucut, peta lintasan 3 sektor, angka AIR/TRACK/HUMIDITY/WIND, kotak NEXT CHANGE, tombol SET TYRES; dibuka dengan klik chip atau `[W]`, ESC menutup lebih dulu; berada di `CanvasLayer` 31 di atas banner radio (layer 30).
- Test: `tests/test_weather_ladder.gd` (23 assertion).

### 3e. Radio R2 dua arah
- Sim: `GtRadioReplies` + antrean balasan di `GtRace` (2.5 s waktu sim, hanya tim pemain, teks dibuat saat jatuh tempo dari keadaan mobil) dan satu panggilan banjir per episode untuk seluruh tim.
- Kartu R2: kertas sobek, bayangan hitam berputar 2.5°, halftone, kilau, dua pita, stiker potret miring, teks Anton 30 px kapital dengan kata kunci tersorot (`RadioMarkup`), bar suara 12 gerigi. Driver kiri-atas −2°, engineer sebaris di kanan +1.6°; yang bicara menyala, lawan bicara meredup; masuk dengan tamparan 0.45 s, fade 1.8 s; `reduce_motion` menghilangkan gerak. 20 potret di-preload saat `RaceHud.bind`. Panggilan rutin menunggu bila kartu urgent pembicara yang sama masih tampil.
- Test: `tests/test_radio_r2.gd` (16 assertion) dan tambahan di `tests/test_pit_deck_and_radio.gd` (kini 34 assertion).

---

## 4. Perubahan perilaku sim yang perlu diketahui planner

1. **HYBRID dihapus.** Dulu: MANUAL = engineer diam, AUTO = langsung `pit_request` tanpa kartu, HYBRID = kartu saran (default). Sekarang: MANUAL (default) = kartu saran yang ditutup saat 10 detik habis tanpa eksekusi; AUTO = kartu yang dieksekusi saat 10 detik habis. Engineer kini bicara di MANUAL sekitar tiap 40 detik selama kondisi bertahan.
2. **Tabel pengali dipusatkan di `GtTypes`** (`PACE_*`, `FUEL_MODE_BURN_MULT`, `ERS_DRAIN_PER_S`, `TYRE_CLIFF_WEAR`, dst.). `gt_driving.gd` membacanya; angka dan urutan perkalian tidak berubah (suite determinisme hijau).
3. **Aturan ban AUTO satu sumber:** `GtForecast.auto_compound` dipakai oleh `RaceWeekendWorld.request_pit` dan deck.
4. **Aliran RNG sim bergeser untuk seed yang sama** dibanding cabang sebelum 3e: balasan dan panggilan banjir memperbarui `last_radio_time`, yang dipakai `gt_driving.gd` untuk menentukan kapan `rng.next()` dipanggil. Tetap deterministik; hanya baseline seed-emas lama yang berubah (belum ada yang diketahui memakainya).
5. **`GtRace`:** `push_radio(..., reply_to)` menambah kunci `reply_to` di setiap pesan radio; panggilan banjir baru dari sim.
6. Forecast cuaca diindeks lewat **lap pemimpin** (sama dengan sim), bukan lap mobil deck.

---

## 5. Verifikasi

- **32 suite headless** (27 asli + `test_pit_deck_and_radio`, `test_hud_theme_and_telemetry`, `test_deck_n2`, `test_weather_ladder`, `test_radio_r2`) dijalankan lewat pembungkus ketat yang gagal bila exit ≠ 0, ada `[FAIL]`, atau ada `SCRIPT ERROR` (error runtime di dalam argumen `check()` tadinya lolos sebagai PASS dengan exit 0).
- Tiap perilaku baru dilihat **gagal lebih dulu** (merah) sebelum diimplementasi. Pengecualian yang diakui: deck N2 (3c, Task 3) ditulis sebelum test alurnya; merahnya ditunjukkan setelahnya terhadap deck lama.
- **Review akhir oleh agen terpisah** di tiap cabang. Tidak ada temuan Critical. Temuan Important (3a 1, 3b 3, 3c 5, 3d 2, 3e 2) semuanya diperbaiki dengan test merah-hijau; Minor dicatat di bagian 8.
- **Screenshot native 1920×1080** per sub-langkah di `executor-report/screenshots/phases/phase-11-langkah-3[a-e]-*.png`; beberapa cacat hanya ketahuan dari screenshot (tooltip setinggi 2162 px, deck cuaca tertutup kartu radio, label terpotong) dan diperbaiki.
- Run penuh terakhir di cabang 3e: 31 dari 32 hijau, satu gagal (`test_radio_and_podium` #20d, akibat aturan "panggilan rutin menunggu kartu urgent"); test disesuaikan dan **suite itu dijalankan ulang sendiri: hijau**. Perubahan kecil sesudahnya (kartu engineer sebaris) dijalankan pada `test_radio_r2`, `test_audio_and_race_weekend`, `test_radio_and_podium`, `test_race_hud`: hijau.
- Run penuh sempat dihentikan sistem karena memori kritis tiga kali (setelah perbaikan review 3a, 3d, dan 3e); tiap kali dijalankan ulang dan hijau.

### Status terhadap Definition of Done (spec §10)

| Item | Status |
|---|---|
| Suite lama 100 % PASS | Terpenuhi (32 suite) |
| `test_pit_deck_and_radio.gd` | Terpenuhi (34 assertion) |
| `test_hud_verdict.gd` (verdict dari nilai sim) | Isinya ada, tetapi di `tests/test_deck_n2.gd`; nama berkas berbeda dari spec |
| `test_weather_ladder.gd` | Terpenuhi (23 assertion) |
| Tidak ada orphan node saat kembali ke menu; 60 FPS pada smoke test 3 lap 20 mobil | **Belum dikerjakan** |
| Screenshot native tiap sub-langkah + laporan + ROADMAP | Terpenuhi |
| Umpan balik klik terverifikasi pada setiap kontrol (checklist di laporan) | Sebagian: terpasang dan diuji di tiap kontrol deck (tab, fader, chip, roda, BOX, COACH, SET TYRES), tetapi checklist lengkap per kontrol belum ditulis di laporan |

---

## 6. Belum dikerjakan

1. **Uji asap native** balapan 3 lap, 20 mobil: pengukuran 60 FPS, frame time, dan pemeriksaan 0 orphan node saat kembali ke menu. Semua animasi (tamparan, fade, hujan jatuh, kedip bracket, denyut kerucut/crossover, teks pop) baru dilihat sebagai gambar diam; tidak ada yang diukur biayanya.
2. **Checklist umpan balik klik** per kontrol di laporan.
3. **Pengambilan keputusan integrasi:** semua cabang menunggu merge oleh planner (bagian 9).
4. Folder kerja `.superpowers/sdd/` (ledger dan paket review) masih ada; penghapusan sebelumnya ditolak izin.
5. Kode mati `scripts/hud/step_bar.gd` dan sebagian besar `scripts/hud/telemetry_widgets.gd` dibiarkan.

---

## 7. Ruling yang diambil selama eksekusi

Setiap ruling = keputusan atas konflik atau celah rencana, dengan akibat bila keliru.

**Umum**
- Cabang fitur bertumpuk, bukan git worktree (proyek Godot dengan cache `.godot` dan aset LFS membuat worktree berat). Akibat bila keliru: urutan merge penting (3a dulu).

**3a**
- `tests/test_race_hud.gd` (HYBRID→MANUAL) dipindah ke Task 1 karena enum tanpa HYBRID membuat suite tidak ter-parse.
- Asersi kecepatan `v > 50` diganti `peak > 45` (tikungan setelah pintu pit menahan semua mobil di 36.8, termasuk mobil kontrol).
- Kedip border kartu tidak diimplementasi (`UI.surface` memiliki border; label berganti crimson/putih dan bar memudar saat kritis).
- Kartu pengganti menjatuhkan kartu BOX yang menunggu (slot tunggal sesuai desain; kondisi yang gugur akan diajukan lagi).
- Uji asap 3 lap dan pengukuran FPS tidak dijalankan.

**3b**
- `GarageStyle` tidak punya `class_name`; konsumen `preload` sebagai konstanta.
- Class baru butuh `godot --headless --path . --import` sebelum test; berkas `.uid` ikut di-commit.
- Angka kecepatan memakai Anton (bukan Dela Gothic One); ikon hati digambar sebagai poligon dan lingkaran; pengukuran frame time tidak dijalankan (GPU dipakai bersama).

**3c**
- Debounce BOX 0.25 s di `on_box_pressed`; test 3a menekan tombol dua kali dalam satu frame sehingga mereset `deck._box_clicked_at` (satu baris).
- Ukuran kontrol disetel ulang di `TacticalDeck._ready()` (`_extents`) karena ukuran yang diset sebelum masuk tree terdongkrak minimum tema default.
- Di bawah `reduce_motion` teks pop ikut dimatikan (suara tetap).
- BOX WINDOW "L+N" memakai lap sebelum perubahan ban pertama (minimum L+1).

**3d**
- Ambang ban 18 % / 45 % (bukan 35 % / 10 %); ladder k = 0..7 dengan NOW di kolom pertama.
- Tombol aksi hanya memilih ban (tidak memanggil BOX).
- Air per sektor heuristik tampilan; dry line memakai `drying_line_pct` sim.
- `GtWeatherOutlook.leader_lap`; forecast diindeks lap pemimpin (test 3c diperbarui).
- Weather Deck di `CanvasLayer` sendiri (31), ditemukan dari screenshot native.

**3e**
- Balasan dan panggilan banjir tidak punya klip suara rekaman (angka hidup tidak bisa direkam lebih dulu); `test_audio_and_race_weekend` #33 melewatinya, #28 membandingkan dengan warna tim/komplementer.
- Fade 1.8 s hanya untuk kartu HUD yang di-dock; dashboard pit wall lama tidak berubah (`test_pit_wall` tetap 4.0 s).
- `test_radio_and_podium` #20d menyembunyikan kartu driver dulu (aturan baru: panggilan rutin menunggu kartu urgent).
- Kartu engineer dipindah sebaris dengan kartu driver (permintaan pengguna).

---

## 8. Temuan Minor yang ditunda (tidak diperbaiki)

**3a:** `cancel_pit` bisa menurunkan cooldown PIT yang lebih panjang (pakai `maxf`); ACCEPT manual bisa menimpa panggilan yang sudah dibuat; jalur expiry belum memperlakukan DNF sebagai tutup-saja; jendela bisa 0.05 s lebih panjang dari 10.0 s; pembagian integer di `race_hud.gd` (`_frame / CARD_BLINK_FRAMES`) bisa memicu peringatan; `suggestion_remaining` mengindeks `["deadline"]` langsung; advisor kini bicara di MANUAL.

**3b:** drawer yang disembunyikan lalu ditampilkan menyimpan jejak lama; painter membaca `brake[-1]` pada state kosong; `shift_time` tidak direset pada mobil baru; biaya gambar belum diukur; label "LIVE 60Hz" padahal sampling ±20 Hz; `step_bar.gd` tidak dipakai dan `telemetry_widgets.gd` hampir seluruhnya mati.

**3c:** tab menampilkan keausan sementara gauge menampilkan umur ban; verdict mengabaikan panggilan BOX yang sudah keluar; kalimat tooltip BOX canggung dan ada centang OK untuk mobil RETIRED; `TyreWheel._process` jalan saat deck dilipat; `refresh()` menghitung 12 verdict saat dilipat; tombol BOX tetap disabled di pit/DNF/chequered (spec: tidak pernah disabled); tanpa motion blur roda dan ring tekan; test double-click hanya menguji milidetik yang sama.

**3d:** chip menulis "STABLE 10L" padahal sisa lap sedikit; chip tetap beranimasi untuk crossover di luar 8 kolom; filter mouse STOP dan kursor tangan chip juga berlaku di dashboard lama; poligon kerucut punya titik pertama ganda di k = 0; tanpa histeresis dekat ambang 18 % / 45 %; `leader_lap` mengurutkan klasemen tiap refresh deck; label ambang grafik di-hardcode dan denyut kerucut diam pada forecast kering; SET TYRES saat BOX sudah dipanggil mengubah `pit_compound`, bukan panggilan aktif; tidak ada test untuk transform layer saat resize, filter mouse, dan prioritas ESC dengan kartu saran.

**3e:** `_ready` menimpa `base_color` yang diset sebelum siap; `load` potret yang menghasilkan null tersimpan sebagai null; `[` belum di-escape untuk BBCode; kepemilikan alpha dim vs tween dan `dimmed` tidak direset saat sembunyi; variabel lokal `tilt` tak terpakai di `_fade_in_docked`; tinggi kartu dijepit ke viewport bukan ke dock (teks ±250 karakter ke atas bisa melewati dock); teks balasan dibuat saat jatuh tempo sehingga bisa terbaca janggal setelah pit; awalan teks balasan terduplikasi antara `gt_driving.gd` dan `GtRadioReplies`; `_refresh_layout` mereset posisi kartu yang sedang tampil saat jendela di-resize; kartu yang meredup berskala dari pojok kiri-atas; `speech` dan `rich` menduplikasi tata letak teks.

---

## 9. Serah-terima untuk merge

Urutan merge (tiap cabang memuat semua commit cabang sebelumnya, jadi cukup berurutan; `main` saat dipotong: `6c8faad`):

| # | Cabang | HEAD |
|---|---|---|
| 1 | `feat/langkah-3a-pit-mechanics` | `b4f1b19` |
| 2 | `feat/langkah-3b-team-theme-telemetry` | `fc3daac` |
| 3 | `feat/langkah-3c-deck-n2` | `11fb542` |
| 4 | `feat/langkah-3d-weather-ladder` | `fc314aa` |
| 5 | `feat/langkah-3e-radio-r2` | cabang terbaru (commit terakhir kode: `1246686`; commit laporan ini menyusul di atasnya) |

Catatan untuk planner:
- Merge cabang 5 saja sudah membawa seluruh isi 1–4. Memerge berurutan menjaga riwayat per sub-langkah.
- Berkas asing yang **tidak** ikut commit dan jangan ditambahkan: `docs/superpowers/specs/2026-10-24-langkah-3-tactical-deck-and-radio-design.md`, `docs/superpowers/plans/2026-10-24-langkah-3-tactical-deck-and-radio-plan.md`, `prompt/TASK-LANGKAH-3-TACTICAL-DECK-AND-RADIO-COMMS.md`, `scratch/smoke_langkah2.gd.uid`, dan perubahan `production/session-logs/*` (berkas agent sebelumnya).
- Setelah merge: jalankan `godot --headless --path . --import` (class global baru: `GtForecast`, `GtWeatherOutlook`, `GtRadioReplies`, `SeverityMark`, `FaderLadder`, `ZonedGauge`, `ChipGrid`, `TyreWheel`, `DeckTip`, `DeckCoach`, `WeatherDeck`, `WeatherTrackMap`, `RadioMarkup`, `TelemetryState`, `TelemetryPainter`), lalu seluruh suite lewat pembungkus ketat.
- Memori sistem sering terbatas: run penuh 32 suite memakan ±15 menit dan pernah dihentikan sistem; jalankan satu instance Godot sekaligus.

### Berkas laporan dan bukti

- Laporan per sub-langkah: `FASE-11-LANGKAH-3A-PIT-MECHANICS-REPORT.md`, `…3B-TEAM-THEME-TELEMETRY-REPORT.md`, `…3C-DECK-N2-REPORT.md`, `…3D-WEATHER-LADDER-REPORT.md`, `…3E-RADIO-R2-REPORT.md`.
- Spec dan rencana: `docs/superpowers/specs/2026-10-24-langkah-3-hud-redesign-v2-design.md`, `docs/superpowers/plans/2026-10-24-langkah-3[a-e]-*-plan.md`.
- Referensi visual (mockup HTML, hanya acuan): `docs/design-refs/`.
- Skrip tangkapan layar: `scratch/capture_langkah3[a-e].gd`.
