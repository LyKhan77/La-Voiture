# FASE 19 — Strategi Ban AI Adaptif, Puncture Realistis & Desk AUTO/MANUAL/COACH

**Tanggal:** 2026-11-01 · **Agen:** Claude Code (Executor) · **Branch:** `fase-19-adaptive-tyre-strategy`

## 1. Masalah & akar penyebab

| Gejala (laporan developer) | Akar penyebab yang terbukti |
|---|---|
| AI tetap memakai ban wet/inter di trek kering sampai ban pecah | (a) `decide_strategy` hanya membaca air di trek **saat ini** di garis finish, lalu mobil masih harus satu lap penuh ke pit entry. (b) Ada celah ambang: penalti wet-on-dry aktif < 15 % air, keputusan slick baru < 12 %, dan tidak ada aturan WET → INTER. (c) Air live mengering ~5× lebih cepat dari model forecast (60 % → 0 % dalam ±40 s, forecast −14..−24 per lap). Ban WET di trek kering aus ≈ 0.59 per lap (×5 scrub, ×3.5 di atas 115 °C, ×1.4 di atas 112 °C). |
| Keputusan semua tim identik | 19 AI membaca satu nilai global, ambang yang sama, di momen yang sama. Probe kode lama: **20/20 mobil memanggil slick di air 0 %, 28 ban wet/inter pecah dalam 3 balapan WET_DRYING**. |
| Forecast tidak dipakai | `weather.forecast` hanya dibaca HUD. Forecast juga sama persis dengan cuaca nyata (tidak ada ketidakpastian). |
| Puncture jauh dari pit: mobil berjalan sangat lama | Grip ban kempis = ban aus (`wear ≥ 0.95` → cliff ≈ 0.21) × 0.22 ≈ 13 %, dikalikan linear ke batas kecepatan tikungan: mobil merangkak 2–7 m/s (8–25 km/jam), bukan 55 km/jam. Tidak ada auto-box; AI baru box di garis finish berikutnya lewat aturan wear (dan tidak sama sekali bila ≤ 2 lap tersisa). DNF hanya karena jarak > 1 lap. |

## 2. Solusi

### 2.1 Cuaca: forecast yang akurat tapi tidak maha tahu (`gt_weather.gd`)
- `truth`: cuaca nyata = outlook awal yang digeser waktunya (±0.9 lap) dan diskalakan intensitasnya (±30 %), dari stream rng sendiri (outlook dan `race.rng` tidak berubah).
- `forecast` (yang dibaca HUD dan semua pit wall) = blend outlook → truth dengan `GtWeatherOutlook.confidence(k)`, diperbarui tiap lap (`publish`). Lap berikutnya ≈ 91.5 % akurat; 5–8 lap ke depan masih bisa mengejutkan. Probe: error rata-rata 1 lap ke depan 0.36 vs 4.82 untuk lap jauh (72 race).
- `WATER_PACE = 0.2`: laju air live dan groove disamakan dengan model per-lap forecast (level kesetimbangan tidak berubah). Trek basah kini kering dalam hitungan lap, bukan detik.
- `rebase_outlook()`: preset setup (WET, MONSOON, overcast) yang membentuk ulang forecast kini juga membentuk ulang cuaca nyata. Tanpa ini, preset WET diabaikan (rain nyata 0.04, test dilihat merah).
- Advisory radar dipisah menjadi `info` + `advice` (sinyal `advisory(info, advice)`).

### 2.2 Strategist per tim (`scripts/gt/gt_strategy.gd`, baru)
- **Profil** per tim dari `GtRng` sendiri (hash seed × tim, **tidak** memakai `race.rng`): `forecast_trust` 0.45–1, `risk_bias` ±8 poin air, `reaction_sectors` 0–2, `read_noise`, `herd`.
- **Keyakinan air** per lap ke depan = lerp(trek sekarang, forecast, trust) + salah baca sebesar cone + lean + tarikan field (porsi mobil yang masih di ban hujan).
- **Utility**: biaya stay vs box untuk tiap ban selama 3 lap setelah lap ini. Lap time diturunkan dari tabel grip sim sendiri (`GtDriving.worn_grip`, `compound_water_mult`, `aquaplane_brake_mult`, kini static dan dipakai bersama), + pit loss dari panjang pit lane, + ban pecah bila tidak bertahan. Box hanya bila menang > 3 s (hysteresis).
- **Refleks**: ban hujan yang diproyeksikan mencapai 85 % aus sebelum pit entry langsung box (kind `cooking`).
- `decide_strategy` kini dipanggil di **setiap sector line**. AI bertindak setelah `reaction_sectors` panggilan berturut-turut yang sama; refleks melewati jeda.
- Lap terakhir: tidak ada box cuaca.

### 2.3 Puncture (`gt_driving.gd`, `gt_race.gd`)
- `box_for_puncture`: box otomatis (keputusan pembalap, semua mode desk), kecuali di lap terakhir (merangkak ke finish).
- Limp: batas 100 km/jam (`LIMP_SPEED_MPS`), grip ban kempis = 60 % grip kompon (bukan cliff ban aus). **Satu lap penuh ban kempis: −82 s** (Apex Ring, lap bersih 79.7 s); dari setengah lap, mobil sampai box dalam ±106 s termasuk stop.
- Kerusakan sekunder: 20 per km × (v/limp)² × kerapuhan 0.6–1.5 (hash, tanpa rng). DNF "Suspension Failure" di 90 → **VSC 25 s** (mobil berhenti). Kebanyakan mobil selamat satu lap; yang rapuh dan jauh dari pit patah.
- Blow-out yang membuat mobil spin → **VSC debris 18 s**; puncture tanpa spin → yellow lokal 10 s.
- Tidak ada aturan "300 m" (tidak ada di dunia nyata): jarak ke pit berpengaruh lewat kerusakan yang menumpuk.

### 2.4 Desk pemain (`gt_race.gd`, `tactical_deck.gd`)
| Mode | Perilaku |
|---|---|
| **AUTO** | Engineer langsung mengeksekusi ("Affirmative, executing …"), tanpa kartu. Tombol COACH nonaktif. |
| **MANUAL + COACH ON** | Kartu keputusan + saran (seperti sebelumnya, kini dari strategist). |
| **MANUAL + COACH OFF** | Tanpa kartu, tanpa saran: engineer hanya fakta ("Track water 28%, forecast 0% next lap.", "Tyre wear at 70%."). Advisory radar tanpa kalimat saran. |
- `GtRace.coach_enabled` disetel oleh tombol COACH. Saran SC/VSC/wing/wear memakai ban terbaik untuk kondisi (`best_fresh_compound`), bukan HARD/SOFT tetap.

### 2.5 Suara radio
21 klip Kokoro baru (`tools/audio/radio_lines.mjs`, bm_lewis): kalimat strategist (drying MEDIUM, rain easing, cooking, wear INTER/WET), SC/VSC per ban, 6 kalimat info coach-off, 2 advisory radar tanpa saran. Klip lama tidak dirender ulang (manifest: hanya tambahan).

## 3. Test

- Baru: `tests/test_adaptive_tyre_strategy.gd` (28 assertion): determinisme dan cone forecast, radar update, preset WET → cuaca nyata, profil (beragam, tanpa `race.rng`), 7 skenario keputusan (wets → slick/inter, inters tetap di luar saat hujan datang, slick di banjir, refleks, lap terakhir), panggilan AI wets → inter di 28 %, **balapan WET_DRYING 3 seed: 0 ban pecah, panggilan tersebar ≥ 5 % air dan ≥ 3 titik lap.sektor**, puncture (auto-box, limp ≤ 100 km/jam, sampai box, DNF kerusakan + VSC, blow-out spin → VSC, lap terakhir tanpa box), dan tiga mode desk + advisory.
- **Dilihat merah di kode lama**: balapan mengering (28 blow-out, air saat panggilan 0..0 %); preset WET tanpa `rebase_outlook` (rain nyata 0.04).
- Diubah karena mengunci semantik lama: `test_gt_sim` (limp 55 km/jam → ≤ 100 km/jam; AUTO card → eksekusi langsung), `test_pit_deck_and_radio` (jendela AUTO 10 s → eksekusi langsung; + MANUAL tanpa COACH; cancel tetap menahan AUTO), `test_deck_n2` (+ COACH menyetel sim dan terkunci di AUTO).
- Sebaran panggilan slick setelah perbaikan (probe, 4 seed, 20 mobil): 2–3 lap, 5–6 titik lap.sektor, air saat panggilan 0–38 %.

- `test_garage_tyre_strategy`: fixture "wets on a dry track puncture within three laps" kini memakai mobil pemain (MANUAL hanya kartu). Sebelumnya mobil AI uji di-box oleh refleks strategist sebelum bannya pecah (gagal di run penuh, lap −1.0), dan test ini memang mengukur fisika ban, bukan strategi.
- **Full suite `tools/run_tests.ps1` dengan kode final: 87/87 PASS.** Run penuh: 86 PASS + `test_garage_tyre_strategy` gagal; setelah perbaikan fixture (hanya file test), suite itu dijalankan ulang: 39/39 PASS.
- **Native smoke test** (`scratch/smoke_race.gd`, 1920×1080, 3 lap 20 mobil, podium, world dibebaskan):

| Sirkuit | Mobil finish | Frame mean / p95 / terburuk (ms) | Draw call environment | Orphan |
|---|---|---|---|---|
| Apex Ring | 20 | 16.67 / 16.75 / 17.34 | 118–128 | 0 |
| Neo-Wangan | 20 | 16.67 / 16.81 / 17.20 | 128–143 | 0 |
| Brianza | 20 | 16.67 / 16.74 / 17.32 | 135–169 | 0 |
| Monte Azure | 20 | 16.67 / 16.78 / 17.42 | 127–151 | 0 |
| Ardennes | 20 | 16.67 / 16.72 / 17.21 | 110–148 | 0 |
| Apex Ring, DYNAMIC WET_DRYING (`temp/fase19/smoke_wet.gd`) | 20 | 16.67 / 16.74 / 17.53 | 122–162 | 0 |

  60 FPS terkunci, tanpa SCRIPT ERROR. Pada balapan basah 3 lap: 0 puncture, 0 stop. Dengan 1–2 lap tersisa, stop (~25 s) lebih mahal daripada bertahan di inter (~11 s/lap), jadi strategist memilih tetap di luar.

## 4. Bukti visual

`executor-report/screenshots/phases/phase-19/` (skrip `scratch/capture_phase19_strategy.gd`, 1920×1080):
- `phase-19-desk-manual-coach-card.png`: kartu "BOX FOR MEDIUM" + saran di MANUAL + COACH ON.
- `phase-19-desk-manual-no-coach-facts.png`: MANUAL + COACH OFF, tanpa kartu, engineer hanya "Track water 28%, forecast 0% next lap."
- `phase-19-desk-auto-executes-coach-locked.png`: AUTO, "Affirmative, executing BOX FOR MEDIUM", tombol COACH redup.
- `phase-19-puncture-limp-box-called.png`: mobil kempis 100 km/jam dengan box terpanggil, VSC.
- `phase-19-drying-race-walls-split.png`: balapan mengering lap 4, sebagian tim sudah di slick, sisanya di pit/ban inter.

## 4b. Polish (lanjutan)

- **Garage CREW PICK** kini `GtStrategy.start_compound` dengan strategist netral: membaca forecast dan jumlah lap (dulu: air ≥ 40 → WET, ≥ 18 → INTER, selain itu MEDIUM, tanpa forecast). Contoh: trek 20 % yang kering di lap berikutnya → slick (dulu INTER). Ban start rival dari strategist tiap tim (`RaceConfigData.apply_to_race`); slick bawaan grid dipertahankan bila panggilannya slick. Test di `test_adaptive_tyre_strategy`.
- **Bahasa:** semua teks in-game berbahasa Indonesia diganti English (catatan kompon & hazard di garage, poster mismatch `wheatpaste_poster.gd`). Garage tidak lagi menulis "APEX RING" untuk sirkuit lain.
- **Radio Comms "Koma Strip"** (`scripts/ui/anime_radio_cutin.gd`): frame tinta + outline aksen + bayangan keras; panel potret (wajah di-paint ke panel miring, garis konsentrasi di-clip ke panel) dan panel balon (kertas screentone, tag speaker, headline, equaliser) dipisah gutter miring; panel SFX kecil pecah keluar dari sudut atas frame (crimson + screentone saat urgent, panel balon "terangkat"). Lebar tetap 258 px: kartu saran (656–1264) dan tyre toast (880–1320) di tengah HUD membatasi kedua sudut. Maks 4 baris; tinggi diambil dari konten RichTextLabel (blok keyword memakai font display yang lebih tinggi, 21–25 px/baris vs 18 px yang dihitung dulu). API, pop/dock/dim/shiver/equaliser/prewarm tidak berubah. `test_radio_r2`: cek balon bergerigi diganti cek panel koma; batas compact 264×108.
- Full suite setelah polish: **87/87 PASS** (dijalankan per slice 0–19, 20–39, 40–59, 60–74, 75–86 karena run penuh di background dihentikan sistem saat RAM menipis).
- Konsep & varian: canvas artifact "Radio Comms Card Concepts". Bukti: `phase-19-radio-koma-driver-routine.png`, `phase-19-radio-koma-two-way-urgent.png`, `phase-19-radio-koma-full-hud.png`.

## 5. Catatan / risiko

- **Sebaran crossover masih 2–3 lap.** Di world, field masih rapat (selisih 0.1–0.8 s di lap 4), jadi panggilan yang jatuh di lap yang sama tetap masuk pit lane bersamaan (shot drying: 14 mobil di pit lane). Untuk sebaran lebih lebar: faktor posisi (tim di luar poin gamble lebih awal, leader cover), atau menghindari double-stack rekan setim.
- `WATER_PACE` mengubah tempo semua balapan hujan: trek basah kini bertahan beberapa lap. Ini disengaja (forecast = trek), tapi terasa beda di playtest.
- Grip ban kempis mengabaikan keausan tiga ban lain (model ban tunggal).
- Forecast yang dipublikasikan untuk lap berjalan menampilkan air live; cloud/angin lap berjalan tetap dari radar lap sebelumnya.
- Kokoro dipasang di scratchpad sesi (`kokoro-js`), bukan dependensi proyek; render ulang butuh `KOKORO_DIR` seperti di header generator.
