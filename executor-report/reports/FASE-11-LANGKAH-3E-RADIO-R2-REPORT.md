# LAPORAN EKSEKUTIF FASE 11 / LANGKAH 3E: RADIO R2 "WHEATPASTE COLLAGE" DUA ARAH

Spec: `docs/superpowers/specs/2026-10-24-langkah-3-hud-redesign-v2-design.md` (§4.6). Rencana: `docs/superpowers/plans/2026-10-24-langkah-3e-radio-r2-plan.md`. Cabang `feat/langkah-3e-radio-r2` (bertumpuk di `feat/langkah-3d-weather-ladder`). Godot 4.7.2 stable, Windows.

## 1. Ringkasan

| Hasil | Detail |
|---|---|
| Balasan engineer (sim) | `GtRadioReplies` + antrean di `GtRace`: panggilan driver tim pemain ("snap of oversteer", "Tyres are cooked", "Track is flooding", "Puncture") dijawab engineer **2.5 s waktu sim** kemudian; teks dibuat saat jatuh tempo dari keadaan mobil (umur ban, air trek), jadi benar walau mobil sudah pit atau DNF. Rival tidak pernah dibalas. Pesan balasan punya kunci `reply_to` |
| Panggilan banjir (sim) | Mobil tim pemain di ban slick dipanggil sekali per episode saat air > 45 % (ambang sim), dihapus tandanya saat air < 18 %; ban WET tidak memicu |
| Kartu R2 | Kertas sobek (18 titik) berwarna pembicara, lembar bayangan hitam berputar 2.5°, halftone, kilau diagonal, dua pita kuning, potret = stiker die-cut miring di sudut luar, teks Anton 30 px kapital dengan kata kunci (BOX, WET, TYRES, …) disorot blok ink, bar suara 12 gerigi segitiga. 470×190, makin tinggi bila teks panjang |
| Dua arah | Driver kiri-atas dock, miring −2°, warna tim mobil yang bicara; engineer kanan dock **sebaris dengan driver** (sama-sama di tepi atas dock, supaya tidak menutupi mobil), miring +1.6°, warna komplementer (`GarageStyle.engineer`); panggilan urgent crimson; yang bicara menyala, lawan bicara meredup (α 0.6, ×0.95, tint 0.75) dan pulih saat kartu lawan selesai |
| Gerak | Masuk dengan tamparan 0.45 s (skala ×1.55 dan putar 9° ke pose istirahat di sekitar pusat kartu, mendarat tepat di posisi dock), tahan 3.5 s, fade 1.8 s. `reduce_motion`: pose istirahat langsung, tanpa fade |
| Potret | 20 potret driver di-preload saat `RaceHud.bind` (`_portraits`); file hilang → potret bawaan |

## 2. File yang berubah

| File | Perubahan |
|---|---|
| `scripts/gt/gt_radio_replies.gd` (baru), `scripts/gt/gt_race.gd` | tabel balasan, `_pending_replies`, `_flush_replies`, `_check_flood_radio`, `push_radio(..., reply_to)` |
| `scripts/ui/radio_markup.gd` (baru) | sorotan kata kunci utuh dan warna tinta menurut gelap-terangnya kertas |
| `scripts/ui/anime_radio_cutin.gd`, `scenes/pit_wall/anime_radio_cutin.tscn` | gambar R2, `rich`, `base_color`, `dimmed`, tamparan, fade, tempat per peran; semua kontrak lama dipertahankan |
| `scripts/hud/race_hud.gd` | warna per pembicara, `_portraits`, talk/dim, `_on_cut_in_finished` |
| `tests/test_radio_r2.gd` (baru, 13 assertion), `tests/test_pit_deck_and_radio.gd` (+6 assertion radio dua arah) | |
| `tests/test_audio_and_race_weekend.gd` | #33 melewati balasan dan panggilan banjir (tanpa klip rekaman), #28 membandingkan dengan warna tim/komplementer |
| `scratch/capture_langkah3e.gd` | tangkapan layar native |

## 3. Verifikasi

- **32 suite headless (31 + `test_radio_r2`): semua OK** dengan pembungkus ketat (gagal bila exit ≠ 0, `[FAIL]`, atau `SCRIPT ERROR`).
- Tiap bagian dilihat gagal lebih dulu (parse error kelas/anggota belum ada).
- Bukti visual native 1920×1080 (dipotong ke dock) di `executor-report/screenshots/phases/`: `phase-11-langkah-3e-driver.png`, `-two-way.png` (driver meredup, engineer cyan menyala), `-urgent.png`, `-long-call.png` (crimson, kartu lebih tinggi), `-team2.png`, `-team7.png`.

**Tidak dilakukan:** tamparan dan fade adalah animasi (hanya pose istirahat yang difoto); pengukuran frame time 60 FPS dan uji asap native 3 lap.

## 4. Temuan dan ruling

1. **Balasan memakai data sim**, bukan skrip "box this lap" dari spec lama: pada mode MANUAL engineer tidak boleh seolah memerintahkan BOX; balasan melaporkan umur ban dan air trek dan menyerahkan panggilan BOX ke pemain.
2. **Banjir pada 45 % air** (ambang sim, `GtForecast.WET_WATER_PCT`), bukan 35 % dari spec lama.
3. **Balasan dan panggilan banjir tidak punya klip suara rekaman** (angka hidup tidak bisa direkam lebih dulu). Test #33 (semua panggilan punya klip) kini melewati pesan dengan `reply_to` dan panggilan banjir; keduanya hanya squelch dan teks.
4. **Sorotan kata kunci lewat `RichTextLabel` terpisah** supaya `speech.text` tetap teks biasa seperti kontrak test lama.
5. **Fade 1.8 s hanya untuk kartu HUD yang di-dock**; dashboard pit wall lama (tidak di-dock) tetap meluncur keluar cepat, sehingga `tests/test_pit_wall.gd` tidak berubah (rencana menyebut 6.0 s; tidak perlu).
6. Tamparan memutar dan menskala di sekitar pusat kartu dengan memajukan `position` (pivot tetap di pojok kiri-atas) agar semantik `banner.position` di test lama tidak berubah.
7. Rotasi istirahat (−2° / +1.6°) berputar di sekitar pojok kiri-atas kartu, bukan pusatnya; selisih kecil (±16 px di ujung jauh).
8. **Aliran RNG sim bergeser dari cabang 3d untuk seed yang sama.** Balasan dan panggilan banjir memperbarui `last_radio_time`, dan `gt_driving.gd` memakai selisihnya untuk menentukan kapan `rng.next()` dipanggil. Tetap deterministik; hanya baseline seed-emas yang direkam sebelum 3e yang berubah.
9. **Pasca-review:** satu panggilan banjir per episode untuk seluruh tim (sebelumnya tiap mobil slick memanggil sendiri dan dua kartu saling menimpa dalam satu tick); panggilan rutin engineer tidak lagi menimpa kartu urgent yang masih tampil (hanya ticker). Test baru mengunci keduanya, mendaratnya tamparan di posisi dock dan dua kartu panjang yang tidak bertumpuk.
