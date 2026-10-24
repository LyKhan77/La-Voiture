# FASE 11 / Langkah 2: Redesign Team Garage (Street-Manga) & Fisika Ban Realistis

**Tanggal:** 2026-10-24 · **Engine:** Godot 4.7.2 stable · **Status:** selesai, belum di-commit

## 1. Ringkasan

Dua pekerjaan dalam satu langkah:

1. **UI Team Garage dibangun ulang** dengan bahasa visual yang sama dengan Main Menu, Race Setup, dan Settings (`StreetStyle`: plat miring, border tinta, bayangan keras, tag header halftone). Posisi node asli dipertahankan di atas garasi 3D layar penuh, jadi orbit dan inspeksi mobil tidak terhalang. Seluruh aksen mengikuti warna tim yang dipilih.
2. **Fisika ban** di `scripts/gt/gt_driving.gd`: kecepatan lurus dipisah dari kecepatan tikungan, aquaplaning memanjangkan jarak rem, snap oversteer, dan ban WET di trek kering terbakar.

Arah desain disetujui lewat preview HTML sebelum kode ditulis (`temp/concepts/preview_garage_v4.html`). Keputusan pengguna selama preview:

- Posisi node mengikuti garasi asli, bukan layout dua kolom konsep.
- Pelat mobil dan Performance Matrix digabung jadi satu `TeamPanel`.
- Roda, telemetri, dan LAUNCH berada di deck bawah.
- Selektor ban berupa **roda 2D yang berputar**; elemen ROOOAR! dan sayap grafiti **dibuang** karena menutupi mobil.
- Kartu driver memakai opsi **B (Panel Break)** dengan statistik berbentuk **konstelasi segitiga**.
- Warna tim menjadi aksen seluruh UI.

## 2. UI

| Bagian | Implementasi |
|---|---|
| Gaya warna tim | `scripts/ui/manga/garage_style.gd`. Aksen = `Liveries.color_for(team)`. Bayangan keras crimson, otomatis cyan bila hue tim dekat crimson (Kurogane GT). Warna teks di atas aksen hitam atau putih menurut luminansi. Perpindahan tim di-tween 0,25 dtk. |
| Panel | `manga_panel.gd`: border tinta 4 px, bayangan keras, tulang punggung warna tim, tag header halftone. Dipakai TopBar, TeamPanel, StrategyDeck. |
| Selektor ban | `tyre_wheel_button.gd` (subclass `Button`). Ban slick polos, inter beralur dangkal, wet beralur dalam. Diam berputar pelan, hover cepat, klik lonjakan, terpilih naik dan memakai cincin warna tim. Kompon salah bergetar dengan cincin crimson. Badge `★ CREW PICK!`. Fokus keyboard tetap berfungsi. |
| Kartu driver | `driver_seat_card.gd`: potret keluar dari panel komik bergerigi di atas speedlines, kode siaran besar, mahkota di lead seat, tiga rating digambar sebagai segitiga (PACE / TIRE / WET). |
| Tyre inspect | Kotak bergaris putus di deck: menampilkan roda yang di-hover atau terpilih, memakai angka nyata `COMPOUND_GRIP` dan `COMPOUND_WEAR_PER_LAP`. |
| Poster | `wheatpaste_poster.gd`: kertas dengan lakban, border tinta 6 px, slab lime + crimson, balon `ARE YOU CRAZY?!`, empat sel penalti, tiga tombol. Isi berbeda untuk slick di trek basah dan wet di trek kering. |

Logika yang sudah ada dipertahankan: auto-default kompon menurut cuaca, `_check_critical_mismatch()`, intersepsi `launch()`, tiga aksi poster. `_hazard_for(compound)` kini satu sumber kebenaran untuk label, kartu, inspect, dan pengecekan mismatch. WIP garasi sebelumnya dicadangkan di `temp/backup_garage_team_select_WIP_before_manga_redesign.gd`.

## 3. Fisika (`scripts/gt/gt_driving.gd`)

| Aturan | Nilai terukur di test |
|---|---|
| Lurus vs tikungan: `tyre_factor` dipecah jadi `tyre_grip` (karet) × `water_grip` (air vs kompon). Air hanya berlaku di tikungan lewat `smoothstep(0.0025, 0.0045, kelengkungan)`. Penurunan kecepatan umum karena air >40% hanya 35% berlaku di lurus. | Slick di lintasan banjir 75%: puncak lurus **253 km/jam** (>240). |
| Apex slick di air ≥40%: dasar 0,65 ditambah perlambatan cuaca. | Rasio apex basah/kering **0,56** (turun 44%). |
| Aquaplaning: `aquaplane_brake_mult` = `1 − (air−20)/55 × 0,67`, minimum 0,33. | Dekelerasi ban wet / slick **3,02×** (jarak rem ≥ 3×). |
| Snap oversteer: slick >10% di atas batas tikungan, air >25%. `error_timer = 2.0` dan radio driver. | Terpicu pada slick; tidak terpicu pada ban wet dengan kecepatan sama. |
| WET di trek kering (<12% air): panas +38 °C, keausan ×5 lalu pengali blistering yang sudah ada. | Suhu puncak **142 °C**; keausan setelah satu lap **17,9×** medium; puncture di **lap 1,6**; medium aman selama 3 lap. |
| Risiko melintir mandiri slick di air: pengali dibatasi 5×. | Dipakai oleh `_driver_errors` (tidak diuji langsung). |

## 4. Verifikasi

- `tests/test_garage_tyre_strategy.gd`: **39 assertion, 0 FAIL** (23 lama + aksen/roda + 14 fisika). Delapan assertion fisika **sengaja dijalankan lebih dulu terhadap kode lama dan gagal** (puncak lurus 159 km/jam, rasio rem 1,00, suhu 113 °C, keausan 2,7×, dst.) sebelum implementasi.
- Seluruh **27 suite headless** dijalankan setelah perubahan. Dua suite sempat gagal dan sudah ditangani (lihat bagian 5); keduanya, ditambah `test_garage_tyre_strategy` dan `test_main_menu_flow` (65 assertion), dijalankan ulang setelah perbaikan terakhir dan lulus. `test_gt_sim` terakhir dijalankan sebelum penggantian teks radio snap; tidak dijalankan ulang sesudahnya.
- Screenshot native 1920×1080 (`scratch/capture_garage_step2.gd`) di `executor-report/screenshots/phases/phase-11-step-2-*.png`: pilihan cuaca, mismatch slick, poster slick, tim crimson (bayangan cyan), tim putih, mismatch wet di trek kering, poster wet di trek kering.

## 5. Perubahan pada hal yang sudah ada

- `tests/test_race_weekend_and_physics.gd` #19: asersi `car_a.wear < 0.05` diukur **saat pit stop selesai** (`a_wear_at_exit`), bukan di akhir adegan. Tes memasang ban WET di trek kering; sesuai aturan baru, ban itu aus ~18× lebih cepat saat mobil lain masih dilayani.
- Radio snap oversteer memakai kalimat yang sudah bersuara (`Had a snap of oversteer! Lost some time.`). Suite audio mewajibkan klip suara untuk setiap kalimat radio; kalimat baru "Zero grip!..." gagal di #33. Kalimat baru butuh generasi TTS Kokoro bila diinginkan.
- Tiga screenshot `phase-11-step-2-*.png` dari percobaan sebelumnya ditimpa dengan hasil redesign.

## 6. Batas dan hal yang belum dikerjakan

- **Smoke test native (`scratch/smoke_langkah2.gd`, 1080p, High, RTX 3050 Laptop):** bagian fungsional lulus: garasi dengan 10 pergantian tim dan pilihan ban, balapan 3 lap 20 mobil malam badai (1× lalu 8×), **20 dari 20 finis, podium muncul, kembali ke `res://scenes/main.tscn`, 0 orphan node** setelah garasi dibebaskan dan setelah kembali ke menu. **Frame time tidak sah**: run ini menunjukkan garasi 41,5 ms, balapan 1× 69 ms. Pembanding adegan balapan lama (`smoke_fase85.gd`, tidak diubah) pada kondisi yang sama juga 64 ms dengan biaya GPU 60 ms, padahal Langkah 1 mencatat 5,2 ms. Saat itu game dari editor (PID 8596) masih berjalan, VRAM terpakai 2,9 dari 4 GB, GPU sudah 23–37% sebelum tes mulai. Pengukuran 60 FPS harus diulang dengan game/editor lain ditutup. Beban tambahan UI: roda memanggil `queue_redraw()` tiap frame (10 roda).
- Animasi putar roda (hover/klik) dicek lewat kode dan screenshot statis, belum diamati berjalan.
- Strip "ESTIMATED RACE DEFICIT / DNF" dari konsep poster **dihapus**: angkanya (+18,4 dtk/lap, 88%) tidak berasal dari model apa pun.
- Stempel kanji hanya untuk K. Ryu (`疾風`), satu-satunya yang tercatat di `DRIVER-CHARACTERIZATION-ROSTER.md`. Glyph CJK memakai font sistem sebagai fallback (pola yang sama dengan `pit_wall_dashboard.gd`); tampil benar di mesin ini, belum diuji di Web export.
- Angka penalti di poster dan inspect (−45%, 3,0×, −30%, 5–6×) adalah target desain yang sesuai hasil test untuk Monsoon 75% air; nilainya bergantung kadar air dan tidak dihitung ulang secara dinamis.
- Poster modal tidak mengunci fokus keyboard deck di belakangnya (backdrop hanya memblokir mouse); Esc tetap menutup poster.
- Font baru: `assets/fonts/PermanentMarker.ttf` (Apache 2.0).
- Perubahan belum di-commit.
