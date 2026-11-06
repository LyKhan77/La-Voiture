# Fase 29 — Live Timing "Slab" + Tyre Life Wheel: Desain

**Tanggal:** 2026-11-05
**Status:** menunggu persetujuan developer (belum ada kode)
**Branch implementasi:** `fase-29-live-timing-slab` (dibuat saat implementasi dimulai)
**Preview yang disetujui:** konsep C ("Slab"), lihat `temp/hud_compare.html` (gitignored; artifact "Ring vs Slab in the Real HUD").

## 1. Maksud

Live Timing di HUD balapan belum setara tower timing motorsport dan tidak mengikuti warna tim yang dipilih player. Matriks tyre di telemetri hanya menampilkan sumur panas dan blok life kecil. Developer ingin:

1. Live Timing yang lebih informatif dan memakai warna tim player.
2. Elemen ban di telemetri berbentuk roda dengan nilai Tyre Life.
3. Telemetri hanya memantau driver player (yang aktif di Tactical Deck). Status driver lain hanya terbaca lewat Live Timing.

## 2. Tujuan, bukan-tujuan, anti-tujuan

**Tujuan**
- Tower memakai desain Slab: baris ringkas untuk semua mobil, satu slab besar berwarna tim untuk mobil yang dipilih.
- Setiap baris menampilkan ring tyre-life dengan huruf kompon. Slab menambah umur ban, jumlah stop, INT/GAP/LAST sekaligus, dan bar sektor.
- Warna chrome tower (header, sorotan, slab, bayangan) ikut `style.accent`, `style.on_accent`, `style.shadow` dari `GarageStyle`.
- Elemen ban di hero car telemetri menjadi roda tick: tick menyala = tyre life, spoke berwarna suhu.
- Telemetri bersumber dari mobil deck (`deck.deck_car_id`), tidak pernah dari mobil rival.

**Bukan-tujuan**
- Mengubah panel telemetri lain: speed, gear, G arrow, ERS, tank, pedal, panel driver, caption, brake disc, onomatopoeia.
- Wear per roda. Sim hanya punya satu `wear` per mobil; empat roda menampilkan tyre life yang sama. Wear per roda adalah perubahan sim terpisah.
- Mengubah `TyreWheel` di Tactical Deck (itu pemilih kompon, bukan indikator life), radar, weather deck, atau lebar tower.

**Anti-tujuan (dianggap gagal walau secara teknis jalan)**
- Warna data (kompon, suhu, life, sektor) ikut warna tim. Warna data tetap tetap.
- Daftar melompat sehingga klik baris berikutnya salah sasaran.
- Tower memakai lebih dari 320 px lebar (radio dock mulai di x=352) atau memerlukan scroll untuk 20 mobil di kondisi normal.
- Rival yang diklik di tower mengubah isi telemetri.

## 3. Keputusan developer

- Konsep C dipilih (B dan campuran ditolak).
- Hanya elemen ban di telemetri yang berubah.
- Telemetri hanya driver player; status lain via Live Timing.
- Warna HUD mengikuti tim yang dipilih player.

## 4. Desain

### 4.1 Tower (`scripts/ui/timing_tower.gd`, `scripts/ui/driver_row.gd`, `scenes/pit_wall/driver_row.tscn`)

Ukuran tower tetap 320×780 di (16, 88).

| Bagian | Spesifikasi |
|---|---|
| Header | Teks "LIVE TIMING" dan "LAP nn/nn". Garis bawah 3 px warna `style.accent`. Panel berbingkai 3 px `style.accent` dengan bayangan keras `style.shadow`. |
| Header kolom | POS, DRIVER, kolom nilai (INT/GAP/LAST, sesuai Tab), TYRE. Label kolom nilai berwarna `style.accent` dan tebal. |
| Baris ringkas | Tinggi 30 px: posisi, nomor, kode, nilai, penanda tim (14×6 px, warna livery), ring tyre-life 22 px. Baris tim player: nomor berwarna livery; kode diberi tanda `*` seperti sekarang. |
| Slab (baris terpilih) | Tinggi 100 px. Latar `style.accent`, teks `style.on_accent`, bayangan keras `style.shadow` offset 4 px. Isi: posisi besar, plat nomor (latar `on_accent`, teks `accent`), kode, nilai kolom aktif, ring 46 px di lingkaran gelap, INT/GAP/LAST, AGE, STOPS, DRS, tiga bar sektor. |
| Total tinggi | 30 header + 18 header kolom + 19×30 + 100 + 6 jarak + 22 footer ≈ 746 px, muat di 780 tanpa scroll. |

Aturan lain:
- Mobil terpilih = `tower.selected_car_id` (mobil yang di-follow, termasuk rival). Hanya satu slab.
- Nilai kolom aktif memakai `_tower_right_text()` yang sudah ada: PIT, PEN, DNF, FIN menggantikan nilai di semua state Tab. Slab menampilkan INT/GAP/LAST lengkap tanpa bergantung pada Tab; untuk PIT/DNF/FIN ketiganya diganti teks status yang sama.
- Pergantian slab: snap tanpa animasi (bahasa visual "snap" proyek, dan menghindari daftar yang bergerak di bawah kursor). Keputusan saya, bukan dari developer.
- Teks pada slab dan chip mengikuti `style.on_accent` (hitam atau putih menurut luminansi), bukan literal.
- Tinggi baris dipilih lewat `custom_minimum_size`; dua mode pada satu scene baris (`set_expanded(bool)`), 20 baris tetap di-pre-instance. Layout hanya dihitung ulang saat pilihan berubah.

Bar sektor di slab memakai `GtTypes.SectorColor`: PURPLE tinggi penuh, GREEN 70%, YELLOW 40%, NONE 15% abu-abu. Warna: ungu `T.ACCENT_PURPLE_SECTOR`, hijau lime, kuning cyber yellow.

### 4.2 Ring tyre-life (kontrol baru, dipakai baris dan slab)

Satu `Control` baru (nama: `TyreLifeRing`, `scripts/hud/tyre_life_ring.gd`), digambar dengan `_draw`:
- busur = `tyre_life` (0..1), mulai jam 12;
- warna busur `LIME` bila life > 0,25 (`1 - GtTypes.TYRE_CLIFF_WEAR`), selain itu `CRIMSON` (garis yang sama dengan gauge TYRE LIFE di deck; amandemen 2026-11-05, semula 0,3 dari blok tread lama);
- huruf kompon di tengah dengan `GtTypes.COMPOUND_COLOR`;
- redraw hanya saat nilainya berubah, bukan tiap frame.

### 4.3 Data (`GtRace.standings_entries()`)

Menambah ke dictionary entry (semua sudah ada di `GtCar`): `tyre_life` = `clampf(1.0 - car.wear, 0.0, 1.0)`, `tyre_age_laps`, `stops`. Yang sudah ada dan dipakai: `team_id`, `compound`, `last_lap_time`, `best_lap_time`, `sector_colors`, `drs`, `interval_s`, `gap_s`, `in_pit`, `is_dnf`, `is_finished`, `penalty_hold_s`. Tidak ada perubahan sim; dictionary hanya bertambah tiga kunci.

### 4.4 Warna tim

`RaceHud` sudah memegang `style` (`GarageStyle`). Tower menerima `style` dan mendaftarkan widget-nya ke `style` (`face`, `tint`, `border`, `shade`) sehingga `RaceHud.set_team_accent()` mengecat ulang tower di tempat, sama seperti logo dan marquee. Penanda tim rival memakai `Liveries.color_for(team_id)`.

### 4.5 Telemetri: elemen ban saja (`scripts/hud/telemetry_painter.gd`, fungsi `_tyre`)

Posisi empat roda tetap (center x ±56, y 34 dan 176 pada koordinat mobil). Ganti isi `_tyre`:
- Roda tick berdiameter ±44 px: 16 tick melingkar, `ceili(tread × 16)` tick menyala. Warna menyala `LIME` bila tread > 0,25 (`1 - GtTypes.TYRE_CLIFF_WEAR`), selain itu `CRIMSON`; tick mati `WELL`.
- Isi dalam gelap dengan 5 spoke dan hub berwarna `state.heat_tint[index]` (warna suhu tetap: cyan, lime, kuning, crimson).
- Label di sisi luar: kode roda dan persen life (sebaris), suhu besar berwarna suhu di bawahnya.
- Dipertahankan: glow suhu > 105 °C, kedip bila > 125 °C (tanpa kedip saat `reduce_motion`), garis blister, silang ban pecah, brake disc dan strip-nya.
- Dihapus: sumur panas 24×44 dan enam blok tread.
- Roda digeser 8 px ke luar dari sumbu mobil agar tidak menutup brake disc.

`TelemetryState` sudah menyimpan `tread` dan `heat_tint`; tidak perlu field baru.

### 4.6 Sumber telemetri (`scripts/hud/race_hud.gd`, `_update_panels`)

Ganti pengisian drawer dari `followed` menjadi mobil deck: `race.get_car(deck.deck_car_id)`. `deck.deck_car_id` sudah hanya berpindah ke mobil tim player (`RaceHud._update_panels` dan `_on_car_picked`). Klik rival di tower hanya menggeser sorotan tower dan kamera; `drawer` tidak berubah. Pindah driver di Tactical Deck atau tekan N memindahkan telemetri, ring, dan header (`#nn KODE // LIVE 60Hz`).

## 5. Kendala

- Godot 4.7.2, GDScript statis wajib; satu proses test per suite, semua suite 100% PASS via `tools/run_tests.ps1`.
- 60 FPS: tower dan panel sudah di-throttle (`TOWER_REFRESH_FRAMES = 6`). Tidak boleh ada alokasi per frame pada ring dan baris; node tidak dibuat ulang saat refresh. 0 orphan node.
- `PresentationSettings.reduce_motion` berlaku untuk semua kedip dan animasi baru.
- Tower tidak boleh menembus `RADIO_DOCK` (x ≥ 352) dan tidak bertabrakan dengan deck dan drawer (`test_race_hud.gd` memeriksa rect). Bayangan keras ±5 px masih di dalam batas ini.

## 6. Ditinggalkan untuk builder

- Kontras penanda tim terhadap panel `#0E1118`. Palet 13 tim berisi warna gelap (misal `#1E3A8A`) yang nyaris tak terlihat sebagai strip kecil. Preview belum menguji ini. Usul: bila kontras < 3:1, beri outline 1 px terang. Builder menentukan ambang dan menambah tes.
- Jarak persis, ukuran font, posisi tiap elemen di baris (preview adalah acuan, bukan piksel final).
- Perilaku `deck_car_id` sebelum pilihan pertama dan saat kedua mobil player pensiun: pertahankan sampel terakhir; builder memeriksa nilai awal.
- Nama field/metode internal.

## 7. Rencana tes (merah dulu, sesuai aturan repo)

Konvensi repo: `tests/test_*.gd` (headless), bukan gdUnit4. Setiap tes ditulis dan dilihat **gagal** terhadap kode lama sebelum implementasi.

1. Telemetri: mobil rival di-follow → `drawer.state.header_text` tetap kode mobil deck; pindah tab deck → header dan data ikut berpindah. (`test_race_hud.gd`)
2. Tower mengikuti `style`: `set_team_accent()` mengubah warna slab, header, dan bayangan; teks slab mengikuti `on_accent` untuk satu warna terang dan satu gelap. (`test_race_hud.gd` / `test_hud_theme_and_telemetry.gd`)
3. `standings_entries()` memuat `tyre_life` (= 1 − wear), `tyre_age_laps`, `stops`. (`test_gt_sim.gd`)
4. Ring dan roda tick: jumlah tick menyala dari `tread`; warna LIME/CRIMSON di batas 0,25; warna suhu tidak berubah oleh warna tim (tes lama baris 304 tetap hijau). (`test_hud_theme_and_telemetry.gd`)
5. Layout: 20 baris + satu slab muat di 780 px tanpa scroll; tepat satu slab; klik baris memindahkan slab. (`test_race_hud.gd`)
6. Tes yang memakai `_interval`, `_driver`, `_compound` pada baris (`_test_tower`, `_test_single_tower_highlight`) diperbarui bila nama node berubah.
7. Painter: probe menggambar semua kondisi ban (pecah, blister, panas, normal) dengan dan tanpa `reduce_motion`.

Lalu: suite HUD/telemetri via `tools/run_tests.ps1 -Filter hud`, suite penuh per irisan, smoke native 3 lap 20 mobil (FPS dan orphan), capture 1080p dengan tim terang, gelap, dan hampir-crimson, plus rival diklik dan ganti driver deck. Laporan di `executor-report/reports/FASE-29-*.md`.

## 8. Dilewati / belum dicek

- Keterbacaan roda tick dan font 12 px di ukuran asli Godot belum diuji (preview HTML saja).
- Kontras 13 warna tim belum diukur.
- Wear per roda: tidak termasuk.
