# DESIGN SPEC v2: Langkah 3 — HUD Redesign (Team Theme, Telemetry, Weather, Tactical Deck N2, Radio R2)

**Target Phase:** FASE 11 (Langkah 3)
**Target Engine:** Godot Engine 4.7.2 stable
**Status:** Disetujui pengguna di sesi brainstorm 2026-10-24 (menunggu persetujuan urutan sub-langkah, lihat §9)
**Menggantikan sebagian:** `2026-10-24-langkah-3-tactical-deck-and-radio-design.md` (spec lama tetap berlaku untuk mekanik di §6; bagian visual deck, kartu radio, dan drawer digantikan dokumen ini)
**Gaya visual:** Street-Manga × Need for Speed Unbound × Neo-Brutalism (tidak berubah)

---

## 1. Maksud dan alasan

Pengguna membuka kembali desain visual Langkah 3 karena lima hal yang belum memuaskan:

1. Telemetry drawer terasa datar dan tidak punya animasi.
2. HUD tidak mengikuti warna tim yang dipilih pemain.
3. Ribbon cuaca pada trek basah miskin informasi dan tidak membantu memprediksi lap berikutnya.
4. Tactical deck dan telemetry dianggap bermasalah secara UX: data berulang di dua tempat, kontrol tidak memberi tahu akibatnya, pemain pemula tidak tahu batasnya.
5. Kartu radio berbentuk banner persegi, pengguna ingin gaya *toon manga × graffiti* yang abstrak.

Prinsip yang diputuskan pengguna: **satu data satu rumah**. Telemetry menjawab "apa yang terjadi pada mobil sekarang" (sensor). Deck menjawab "apa yang kuputuskan dan apa akibatnya". Tactical Strategy **tetap di HUD bawah**.

## 2. Tujuan, bukan-tujuan, anti-tujuan

**Tujuan**
- Semua modul tampil dalam satu bahasa visual (panel miring ala manga, gutter bertint tim, halftone, onomatope).
- Warna tim mengendalikan kulit HUD, bukan makna data.
- Pemain pemula bisa memahami tiap kontrol dan melihat batasnya sebelum menekan.
- Setiap klik punya umpan balik (visual, suara, animasi).
- Forecast cuaca bisa dibaca sebagai rencana, bukan sekadar status.

**Bukan-tujuan**
- Tidak mengubah posisi atau ukuran kotak HUD (lihat §3).
- Tidak menambah mekanik balapan baru (rencana stint, auto-strategi baru). Stint planner (opsi N3 di brainstorm) sengaja tidak dipilih.
- Tidak mengubah model fisika ban, bensin, ERS.

**Anti-tujuan** (dianggap gagal walau fungsional)
- Warna tim mengubah warna panas ban, status kritis, ERS, bensin, atau compound.
- Pilihan berisiko dikunci atau disembunyikan (harus tetap bisa dipilih, hanya diberi tanda).
- Angka dampak yang ditampilkan di UI tidak sama dengan perilaku sim.
- Hitch saat kartu radio muncul (potret harus di-preload).

## 3. Layout lock (diperbarui)

Seluruh kotak berikut **tidak berubah**. Yang berubah hanya isi di dalamnya.

| Modul | Posisi | Ukuran |
|---|---|---|
| Top ribbon | (16, 12) | 1888×60 |
| Weather widget di ribbon | (990, 2) relatif ribbon | 350×56 |
| Timing tower | (16, 88) | 320×780 |
| Radar panel | (1598, 82) | 312×212 |
| Session records | (1598, 306) | 312×60 |
| Telemetry drawer | (1598, 372) | 312×496 |
| Suggestion card | (656, 690) | 608×136..156 |
| Tactical deck | (16, 880) | 1888×140 (open) / 1888×44 (collapsed) |
| Race control marquee | (0, 1032) | 1920×48 |
| Radio dock (area kartu radio) | (352, 88) | 1230×790 |

**Overlay baru yang diizinkan** (tidak menggeser modul lain): tooltip deck (muncul di atas deck, boleh menimpa area 3D), Weather Deck dropdown (di bawah ribbon, dibuka klik chip atau `[W]`), pop teks onomatope.

## 4. Keputusan per modul

Referensi interaktif ada di §8. **Angka di mockup adalah placeholder**, lihat §5 untuk nilai sebenarnya dari sim.

### 4.1 Tema warna tim
- Sumber warna: `scripts/car/team_liveries.gd` (`TeamLiveries.color_for(team_id)`, 10 warna). Aksen mengikuti `GarageStyle` yang sudah memakai warna livery.
- **Mengikuti tim (chrome):** tag judul panel, tepi panel, segmen/tab terpilih, tombol BOX, baris tower milik pemain, speed lines dan halftone latar, wipe transisi, kartu radio driver, tint 7% pada gutter.
- **Tidak berubah (semantik):** panas ban (cyan→lime→kuning→crimson), pedal throttle/brake, ERS ungu, status kritis, compound S/M/H/I/W, margin bensin, bendera, gear kuning, DRS.
- Teks di atas aksen: otomatis ink (`#050505`) bila luminans relatif aksen > 0.3, selain itu putih.
- **Benturan dengan warna semantik** (crimson = critical, lime = optimal, kuning = warning, ungu = ERS): status dibedakan lewat bentuk (ikon ✓ ▲ ✖, kedip, hazard stripe, label teks), tidak lewat warna saja.
- **Warna engineer di kartu radio** = komplementer otomatis: pilih pertama dari [cyan, pink, lime, kuning] yang selisih hue dengan aksen > 55° (aksen tak berwarna → cyan).

### 4.2 Telemetry drawer (konsep F, tema gelap)
Kotak 312×496. Panel miring, tepi aksen-tim 1px di atas ink 3px, gutter `mix(#151b29, aksen, 0.07)`, hero mobil X-ray.
- **Header:** tag "TELEMETRY" (aksen-tim) + `#NN KODE // LIVE 60Hz`.
- **Speed + gear (y 38–118):** speed besar dengan speed lines radial (rapat saat cepat) dan halftone; chip DRS (kuning berdenyut = eligible, cyan dengan chevron mengalir = aktif). Gear kuning dengan *kick* (skala + chroma split) tiap upshift, shift-light 12 balok, panel ungu saat limiter.
- **Hero mobil top-down (y 122–378):** 4 ban dengan isi panas bergelombang, halo berdenyut saat panas/kritis, disc rem menyala, tread, blister, silang ban meletus; panah G-force dari pusat dengan jejak; tulang punggung ERS dengan garis mengalir (maju deploy, mundur harvest, cepat overtake); tangki bensin bergelombang; tanda damage berkedip. Panel bergetar saat rem keras; halftone merah tumbuh dengan stres.
- **Pedal (y 382–416):** trace throttle/brake.
- **Driver (y 420–454):** bar stress/confidence, ECG, ♥ berdenyut mengikuti QRS, angka detak.
- **Caption (y 458–490):** narasi typewriter satu baris sesuai situasi.
- **Onomatope pop** saat kejadian: rem keras "GUOOO!!", upshift "KACHA!", DRS "VWOOOM!", ban kritis "JIRI JIRI", ERS overtake "DON!!".
- **Dihapus dari drawer (pindah ke deck):** strip fuel/ERS, bar LIFE/DMG, teks "FUEL // OPTIMAL" di bawah mobil.
- Anggaran: seluruh gambar via `_draw()`; tidak ada node per elemen animasi; pop teks dibatasi 2 sekaligus.

### 4.3 Ribbon cuaca (chip 350×56) dan Weather Deck
- **Chip:** baris 1: ikon + status + `→ STATE L+n` + suhu udara/trek. Baris 2: ladder 8 lap ke depan, tiap kolom = batang intensitas hujan (animasi hujan jatuh saat rain > 0.08) + chip rekomendasi ban (W/I/M). Kolom lap pertama bertanda NOW; kolom crossover berdenyut; kolom lap BOX ideal bertag **BOX** merah. Tabung WET di kanan dengan tick 35%.
- **Weather Deck (klik chip atau `[W]`):** grafik water% 10 lap dengan **kerucut ketidakpastian** melebar mengikuti jarak, garis ambang W ≥ 35% dan SLICK ≤ 10%, bracket BOX WINDOW merah berkedip, peta lintasan dengan 3 sektor berwarna basah/kering plus dry line, AIR/TRACK/HUMIDITY/WIND, kotak NEXT CHANGE dengan confidence, tombol aksi `SET BOX CALL L+n → compound`.
- **Sumber data:** `GtWeather.forecast` (`lap, rain_intensity, water_pct, cloud_cover, wind_speed`), `track_water_pct`, `drying_line_pct`, `air_temp`, `track_temp`, `humidity`. Rekomendasi ban memakai ambang yang sudah ada di sim (35% wet crossover); ambang slick/inter 10% adalah usulan, builder memverifikasi terhadap `gt_driving.gd`.
- Confidence turun seiring jarak (usulan: `max(0.3, 1 − 0.085·k)`); ini heuristik tampilan, bukan probabilitas sim.

### 4.4 Tactical deck N2 "Faders Console" (kotak 1888×140 tetap)
Isi dari kiri ke kanan:
1. **Kartu 2 mobil** (tanpa tab): posisi, nama, compound, umur ban, mini bar fuel/ERS; kartu terpilih bergaris aksen dan menentukan mobil yang diikuti telemetry.
2. **Tiga fader vertikal** PACE / FUEL / ERS (atas = lebih agresif). Tiap fader: tangga tombol, **gauge vertikal berzona**, angka besar, pill status, legenda limit.
   - Gauge ban: zona merah di bawah cliff, kuning di zona menuju cliff, hijau di atas. Gauge bensin: zona merah di bawah "flag" (cukup untuk finish). Gauge baterai: merah di bawah 20%. Garis putih = limit; **garis putus-putus = prakiraan posisi saat finish** (ban, baterai).
   - Setiap pilihan berisiko diberi ikon bentuk **sebelum diklik**: ✓ OK, ▲ WATCH, ✖ DANGER. Pilihan **tidak pernah dikunci**.
3. **Roda ban** 96×96 (canvas) + 6 chip (AUTO, SOFT, MED, HARD, INTER, WET). Roda berputar sebanding kecepatan mobil, ada motion blur saat kencang; klik atau scroll pada roda ganti compound; ganti compound menghentak roda (impuls putar) dan menyalakan cincin. AUTO menampilkan saran dari forecast (mis. `→I`).
4. **BOX dua-state:** `REQUEST BOX [B]` ↔ `BOX CONFIRMED ✓ / CANCEL [ESC] · NO PENALTY`; konfirmasi memukul roda dengan impact wrench (shake + impuls). Tombol tidak pernah disabled sebelum pit limiter (selaras spec lama §2A).
5. **Kartu BOX WINDOW**: ladder 5 lap + teks perubahan cuaca.
- **Header deck:** tag, **baris prakiraan live** `NEXT LAP ▸ LAP … · WEAR …/lap · CLIFF L… · FUEL … · BATT …`, tombol **COACH ON/OFF**, segmen DESK (**MANUAL/AUTO saja**; mode HYBRID dihapus, lihat §6), baris radio terakhir, FOLD.
- **Tooltip (di atas deck):** pill severity + nama pilihan; bila COACH ON, satu kalimat bahasa biasa; angka dampak relatif terhadap pilihan aktif; verdict berwarna dengan alasan. Muncul saat hover fader, chip ban, roda, BOX; tetap tampil setelah klik.
- **Umpan balik klik (wajib di semua kontrol):** tombol menekan (skala 0.92→1) dengan cincin aksen, teks pop (`SOFT ✓`, `BOX!`, `CANCELLED`) di atas kontrol, blip suara dengan nada berbeda per aksi (gunakan `AudioManager.click()` dan varian untuk konfirmasi/batal), roda dihentak untuk aksi ban/BOX.
- **Teks tooltip dan pill harus bisa dibaca tanpa warna** (ikon + label).

### 4.5 Suggestion card + burning bar
Dipertahankan dari spec lama §2C (bar api 10 detik, label sisa waktu, ENTER/ESC), dengan tepi dan tombol ACCEPT mengikuti aksen-tim, dan ladder ban 7 lap kecil (chip W/I/M) di kartu saat saran terkait cuaca.

### 4.6 Radio R2 "Wheatpaste Collage" (dua arah)
- **Kartu:** kertas tempel sobek (clip-path poligon tak beraturan) berwarna `--c`, halftone multiply, kilau diagonal, lembar bayangan hitam berputar 2.5°, dua tape kuning. Potret = stiker die-cut miring di sudut luar. Teks Anton kapital 30px, kata kunci (`*kata*`) ditandai blok ink dengan warna kartu. Bar suara = gerigi segitiga ink (12) yang naik-turun saat bicara.
- **Dua arah:** driver kiri-atas (warna tim, miring −2°), engineer kanan-tengah (warna komplementer, +1.6°). Yang bicara menyala (`talk`), lawan bicara meredup (`dim`: opasitas .6, saturasi turun, skala .95). Masuk dengan animasi tamparan (skala 1.55 + rotasi −9° → 1 dalam 0.45 s). Jeda balasan 2.5–3 s. Cut-in lama hilang setelah fade 1.8 s.
- Penempatan di radio dock (352, 88, 1230×790). Ukuran kartu 470×190. Potret di-preload di `_ready()`.
- Kata-kata contoh dan pemicu mengikuti spec lama §2D (tyre cliff/snap oversteer, banjir > 35%). Audio squelch dan ducking tidak berubah.

## 5. Nilai sebenarnya dari sim (mockup berbeda)

Builder **wajib memakai nilai sim**, bukan angka placeholder mockup. Yang sudah diverifikasi di kode:

| Hal | Sumber | Nilai |
|---|---|---|
| Pengali wear per pace | `gt_driving.gd:188-208` | CONSERVE 0.45, LIGHT 0.72, STANDARD 1.0, AGGRESSIVE 1.45, ATTACK 2.1 |
| Pengali burn bensin per pace | idem | 0.85, 0.93, 1.0, 1.12, 1.25 |
| Pengali burn per fuel mode | `gt_driving.gd:211-218` | CONSERVE ×0.80, PUSH ×1.25 |
| Pengali kecepatan pace | idem | 0.948, 0.978, 1.0, 1.025, 1.048 |
| ERS drain saat deploy | `gt_driving.gd:219-222` | DEPLOY 12/s, OVERTAKE 24/s (satuan baterai per detik saat men-deploy, bukan per lap) |
| Cliff grip ban | `gt_driving.gd:77-80` | mulai wear 0.75 (umur 25%) |
| Tahap bensin | `gt_types.gd:34` | OPTIMAL, WARNING, SPUTTER, LIMP, FLAMEOUT |
| Mode | `gt_types.gd:30-32` | `PACE_NAME`, `ERS_NAME` |

Konsekuensi: angka mockup (+9%/+19% wear, ERS −12%/−35% per lap) **terlalu kecil/salah satuan**. Verdict ✓ ▲ ✖ harus dihitung dari model nyata: umur ban saat finish = `1 − wear_sekarang − COMPOUND_WEAR_PER_LAP × tyre_wear_rate × wear_mult × sisa_lap`; margin bensin dari `fuel / fuel_burn_rate` terhadap sisa lap (sudah dipakai drawer lama); baterai dari drain/detik × estimasi detik deploy per lap. Zona gauge bensin sebaiknya memakai `fuel_stage` yang sudah ada.

## 6. Mekanik yang dipertahankan dari spec lama
`cancel_pit(car_id)` pada `GtRace` dan `RaceWeekendWorld` tanpa penalti (pulihkan pacing, radio "Stay out, stay out! Box call cancelled."); keyboard `[B] [ESC] [ENTER] [M] [T] [TAB] [E] [ [ ] ] [N] [H]`; ditambah `[W]` membuka Weather Deck.

### Mode DESK: hanya MANUAL dan AUTO (keputusan pengguna, HYBRID dihapus)

| Mode | Perilaku |
|---|---|
| **MANUAL** (default) | Race engineer tetap menyarankan lewat kartu saran (perilaku yang sebelumnya milik HYBRID). Kartu punya bar api 10 detik; bila waktu habis, kartu **ditutup** dan tidak ada yang dieksekusi. Tidak ada tindakan tanpa klik pemain. |
| **AUTO** | Kartu saran muncul dengan bar yang sama; bila waktu habis, saran **dikunci dan dieksekusi** (compound dikunci, box dipanggil). Pemain masih bisa ACCEPT/DISMISS lebih cepat. |

**Ini mengubah perilaku sim saat ini** (butuh konfirmasi pengguna, lihat catatan akhir sesi): sekarang `MANUAL` = engineer diam total, `AUTO` = langsung `pit_request` tanpa kartu, dan `HYBRID` = kartu saran (mode default). Dengan HYBRID dihapus, perilaku kartu pindah ke MANUAL dan AUTO mendapat masa tunggu 10 detik.

**Titik sentuh kode untuk penghapusan HYBRID** (ditemukan lewat grep; builder memverifikasi ulang):
- `scripts/gt/gt_types.gd:12` — `enum TacticMode { MANUAL, AUTO, HYBRID }` → hapus `HYBRID` (urutan MANUAL=0, AUTO=1 tidak berubah).
- `scripts/gt/gt_race.gd:31` — default `tactic_mode = HYBRID` → `MANUAL`.
- `scripts/gt/gt_race.gd:217` — `_check_hybrid_tactics()` hanya jalan di HYBRID → jalan untuk MANUAL dan AUTO; ganti nama (mis. `_check_advisor_tactics`).
- `scripts/gt/gt_race.gd:484` — `decide_strategy()` return dini untuk pemain MANUAL → pemain MANUAL kini menghasilkan kartu saran; `:504` cabang `HYBRID` → cabang kartu untuk pemain MANUAL dan AUTO (AUTO mengeksekusi saat timer kartu habis; builder memutuskan jalur cadangan eksekusi langsung bila tidak ada HUD, mis. sim headless).
- `scripts/hud/tactical_deck.gd` — `TACTIC_NAME` dan `ModeRow` desk dari 3 jadi 2 opsi.
- Test: `tests/test_gt_sim.gd` (`_test_tactics`, mengasumsikan HYBRID menawarkan kartu dan MANUAL diam) dan `tests/test_race_hud.gd:174-180` (menekan tombol AUTO, memakai HYBRID) harus ditulis ulang.
- Dokumen: `PRD/02-UI-UX-TOPOLOGY.md` (baris 131, 134-135), `PRD/00-MASTER-OVERVIEW.md:88`, `PRD/07-DATA-TESTING-PERFORMANCE.md:88` menyebut HYBRID; perbarui di sub-langkah 3a.

## 7. Diserahkan kepada builder
- Cara menggambar panel miring di Godot (polygon `_draw()` vs `Polygon2D`/StyleBox), asal tetap ≤ 1 draw call per panel yang wajar dan tanpa node per partikel.
- Pembagian file (saran: `telemetry_drawer.gd` ditulis ulang; `tactical_deck.gd` + node baru `tyre_wheel.gd`, `fader_ladder.gd`, `deck_tooltip.gd`; `weather_radar_widget.gd` + `weather_deck.gd`; `anime_radio_cutin.gd` varian R2).
- API sim untuk verdict (helper statis `GtForecast` atau sejenis) selama memakai nilai §5.
- Nada blip dan penamaan suara.
- Kalimat COACH final (mockup memberi teks Inggris contoh; bahasa final mengikuti bahasa UI game).
- Tinggi minimum target klik fader PACE (mockup 17px dianggap terlalu kecil di bawah 24px; builder boleh menaikkan dengan menambah tinggi gauge/menggeser teks, selama kotak deck tetap).

## 8. Referensi (mockup HTML, hanya acuan visual)
Folder `docs/design-refs/` (di-track git, dilindungi `docs/.gdignore`). Buka langsung di browser; gambar latar dan potret (`/files/*.png`) hanya muncul bila disajikan dari server brainstorm, UI tetap berfungsi tanpa gambar:
- `ui_step_8_n2_final.html` — **deck N2 final** (close-up + HUD penuh, interaktif; deck di mockup masih memakai segmen DESK HYBRID, abaikan, ikuti §6).
- `ui_step_4_hud_discussion.html` — tema tim (bagian 1), ribbon cuaca + Weather Deck (bagian 2), radio R1–R3 (bagian 4; **R2 dipilih**).
- `ui_step_3_telemetry_hybrid_bd.html` — konsep F (telemetry) versi awal.
- `ui_step_5_layout.html` — layout HUD asli berkoordinat kode (radar dan records termasuk).
Mockup memakai simulasi sendiri dan angka placeholder (§5).

## 9. Urutan sub-langkah yang diusulkan
Karena cakupan besar dan modulnya cukup independen, usulan urutan eksekusi (tiap langkah berdiri sendiri dan bisa diverifikasi):
1. **3a — Mekanik:** `cancel_pit`, mode DESK, timer bar kartu saran, keybind, test suite baru. (Tanpa visual baru.)
2. **3b — Tema tim + telemetry drawer F** (token warna aksen, drawer ditulis ulang).
3. **3c — Deck N2:** fader + gauge berzona + verdict dari sim + tooltip + COACH + roda ban + umpan balik klik.
4. **3d — Ribbon cuaca:** ladder 8 lap + Weather Deck.
5. **3e — Radio R2** dua arah.

## 10. Quality gate dan DoD
1. Seluruh 27 test suite lama tetap 100% PASS.
2. Test baru `tests/test_pit_deck_and_radio.gd` (toggle box, cancel box, desk mode, timer bar, radio dua arah), ditambah `tests/test_hud_verdict.gd` (verdict dihitung dari nilai sim §5, bukan konstanta UI) dan `tests/test_weather_ladder.gd` (rekomendasi ban dan lap BOX dari forecast).
3. Tidak ada orphan node saat kembali ke menu; kartu radio dan drawer tidak menyebabkan frame di bawah 60 FPS pada smoke test 3 lap 20 mobil.
4. Screenshot native tiap sub-langkah di `executor-report/screenshots/phases/`, laporan di `executor-report/reports/FASE-11-LANGKAH-3*-REPORT.md`, `ROADMAP.md` diperbarui.
5. Umpan balik klik terverifikasi pada setiap kontrol (checklist di laporan).
