# LAPORAN EKSEKUTIF FASE 5.6 - 5.8: PORT SIM GT, DINAMIKA 3D + VFX, HUD GABUNGAN

**Status:** SELESAI & TERVERIFIKASI (suite akseptansi `test_race_weekend_and_physics.gd` PASS dengan 8 suite turunan: `test_modular_car` 18, `test_simulation_verification` 43, `test_pit_wall` 26, `test_weather_and_ai` 43, `test_race_world` 65, `test_gt_sim` 43, `test_car_dynamics_vfx` 18, `test_race_hud` 31; tangkap layar dari GPU nyata, Godot 4.7.2 Forward+)
**Asal:** permintaan refining setelah Fase 5.5 (balapan menumpuk menyamping, kecepatan terlalu lambat, ban depan tidak membelok, VFX belum terpasang, HUD belum lengkap) dengan referensi `D:\Occupation\Porto\universal-modder\game-1\gt-manager`.
**Pilihan pemilik proyek:** (a) model gerak = **port penuh `race.ts`** ke GDScript; (b) HUD = **tactical deck + telemetry gt-manager dikombinasikan dengan dashboard Pit Wall** menjadi desain khas La Voiture.
**Dokumen:** spec `docs/superpowers/specs/2026-10-21-phase-5.6-gt-sim-port-and-refinement.md`, plan `docs/superpowers/plans/2026-10-21-phase-5.6-implementation-plan.md` (T1 - T13 tercentang).

Laporan ini **menggantikan** bagian arsitektur di `FASE-5.5-...md`: `MatchColliderSystem`, `WorldPitDirector`, dan hook `TrafficRaceSim` tidak lagi dipakai dunia akhir pekan (lihat bagian 2).

---

## 0. Jawaban atas lima keluhan

| Keluhan | Penyebab yang terukur | Hasil sekarang |
|---|---|---|
| Barisan menumpuk menyamping, aturan 3 lajur tidak realistis | Sim lama hanya punya 3 lajur diskret; pemakaian lajur di 3D [4, 15, 1] mobil; collider hanya menggeser offset di atas lajur | Tidak ada lajur. Posisi `s` dan `lateral` kontinu, AI `targetLateral` (menyerang, bertahan satu gerakan, mengalah, bendera biru, pemecah side-by-side, ruang balap 2.4 m antar pusat). Pasangan side-by-side terlama **2.5 s**, tiga sejajar terlama **1.6 s** dalam balapan 3 lap, 20 mobil |
| Kecepatan balap terlalu lambat | Lap sim 5807 m digambar di ribbon 4159 m (x 0.716) + batas tikungan +12 % + akselerasi dibatasi traksi: lap terbaik 109.7 s di engine, **123.6 s di 3D** (rata-rata 119 km/jam, puncak 221) | Sim berjalan langsung di panjang ribbon 4159 m. Lap terbaik **79.6 - 88.0 s**, rata-rata **188 km/jam**, puncak **287 km/jam**, speed trap 283 km/jam. Soak 25 lap: pemimpin 84.8 - 86.1 s |
| Tidak ada animasi belokan (leaning, roda) | Aktor memutar keempat roda dan tidak punya sudut sasis | `GtCarActor`: roda depan membelok (`steer = kappa x 14 + heading x 1.35`, batas 0.42 rad), roda belakang tidak pernah membelok, bodi roll ke sisi luar tikungan (`a_c x 0.0022`, batas 0.085), hidung turun saat mengerem dan belakang jongkok saat tenaga (`-a_long x 0.0026`), mobil menghadap arah gerak lateral (yaw) |
| VFX belum dirakit | Hanya hujan/jalan basah dari Fase 5; tidak terpasang di dunia akhir pekan | `scripts/vfx/race_vfx.gd` terpasang di `Vfx`: hujan + jalan basah + matahari meredup + petir, percikan air per mobil, asap ban belakang (spin/kunci), ribbon slipstream, letupan knalpot saat naik gigi, lampu depan malam, tip status mengambang di atas mobil (menggantikan lampu belakang dan flap DRS), 10 pool percikan (kontak, puncture, pistol roda kru), mobil safety car dengan lightbar |
| HUD belum lengkap | Hanya tower, radar, satu label | `scripts/hud/`: ribbon Zone A, tower INT/GAP/LAST, radar + rekor sesi, drawer telemetri, tactical deck, kartu saran hybrid, pita peringatan (caution tape), marquee race control, radio cut-in anime |

---

## 1. Rangkuman Implementasi

### Fase 5.6 - Port `race.ts` (`scripts/gt/`)

| File | Isi |
|---|---|
| `gt_types.gd` | Enum Compound (5), PaceMode, FuelMode, ErsMode, TacticMode, Flag, FuelStage, Overtake, PitPhase, SafetyCarPhase, SectorColor, CollisionKind, TacticType, Wheel; konstanta TICK_DT 0.05 s, ACCEL 6.8, BRAKE 16.5, PIT_SPEED 22 m/s |
| `gt_rng.gd`, `gt_data.gd`, `gt_car.gd`, `gt_pit.gd` | mulberry32 deterministik; 20 mobil dalam 10 tim La Voiture dengan kode siaran unik; state mobil lengkap (sasis, telemetri 4 roda, biometrik pembalap) |
| `gt_track.gd` | Dibangun di atas `TrackRibbon` lewat `AdaptiveRacingLine`; lebar 14 m, profil kecepatan dua sapuan (lateral 19.5, rem 15, gas 7, V_MAX 76 m/s), garis ideal, 2 zona DRS, clamp ±5.4 m |
| `gt_weather.gd` | 7 arketipe, forecast `lap + 5`, air di trek / jalur kering, waktu hari, advisory radio |
| `gt_race.gd` | `step(dt)` 20 Hz, standings, bendera FIA + safety car fisik, DRS/ERS/slipstream, strategi dan kartu saran hybrid, sektor + speed trap, akhir balapan (finisher pertama mengakhiri balapan untuk semua) |
| `gt_driving.gd` | Gerak per mobil: kecepatan target `speed_limit(s) x pace`, AI lateral, aturan serang/bertahan/bendera biru, ban (tebing 75 %, puncture), bahan bakar (5 tahap), pit lane (entry, queue, box, exit, limiter 80 km/jam) |
| `gt_contacts.gd` | Resolver 190 pasang tiap tick, dua pass, sadar tikungan: `skala = 1 - kappa x lateral`, lebar `2.08 + 2.225 x (sin(kappa x ds) + yaw_extra)`; insiden (rub, minor, heavy), spin, DNF + marshal |

### Dunia dan aktor

- `scripts/world/race_weekend_world.gd` dibangun ulang di atas `GtRace`: director menahan sim sampai lampu padam, tick tetap 20 Hz (skala waktu 1x - 16x menjalankan urutan tick yang sama), aktor diinterpolasi antar tick, pit mengikuti state pit sim.
- `scripts/car/gt_car_actor.gd` + `scenes/race_world/gt_car_actor.tscn`: aktor 3D satu `GtCar` (5 kompon roda, livery tim, sudut sasis, roda depan membelok, cakram rem berpijar).
- `scripts/car/pitstop_choreographer.gd` dipangkas menjadi **presenter kru**: sim yang memegang state pit, kru hanya memeragakan (jack, ganti 4 roda, lollipop) dari `wheel_swap_progress` dan `lift_y`.
- `scripts/vfx/race_vfx.gd` (kelas `RaceVfx`): seluruh VFX di tabel 0, digerakkan dari state sim.
- Aset baru: `scenes/car/parts/porsche_wheel_inter.tscn`, `materials/tire_stripe_inter.tres` (kompon intermediate).

### Fase 5.8 - HUD gabungan (`scripts/hud/`)

Panggung 1920 x 1080 diskalakan ke jendela (huruf kotak, tanpa distorsi). Bahasa desain mengikuti `DESIGN.md` (panel 0 px radius, border tinta, bayangan offset keras, screentone, snap-invert, bar bersegmen, caution tape, tanpa gauge bundar).

| Komponen | Peran |
|---|---|
| `race_hud.gd` (`RaceHud`, node `Hud`) | Zone A: LA VOITURE, lap pemimpin, banner bendera/lampu start/chequered, widget radar cuaca `WeatherRadarWidget` (adapter dari `GtWeather`: kering / gerimis / hujan deras / mengering + forecast 5 lap), tombol skala waktu 1x - 16x, nama kamera, status DRS. Tower `timing_tower.tscn` dipakai ulang (INT / GAP / LAST dengan Tab; PIT, DNF, FIN, DRS; huruf kompon S/M/H/I/W berwarna; `*` menandai mobil tim pemain). Radar sirkuit dipakai ulang + panel rekor (lap tercepat, speed trap, suhu). Radio cut-in anime dipakai ulang (`play_radio`) untuk radio tim pemain dan pesan mendesak. Marquee race control |
| `tactical_deck.gd` | Satu strip lebar 1888 x 140 px di bawah tower dan drawer (layout A pilihan pemilik proyek): tab dua mobil tim pemain, baris Pace (5), Fuel Mix (3), ERS (4), pilihan ban berikutnya (AUTO, S, M, H, I, W) + tombol **BOX THIS LAP** (memanggil mobil masuk pit di pit entry berikutnya), Tactic Desk (MANUAL / AUTO / HYBRID), tombol lipat `M`, baris radio terakhir + jumlah stop. Semua tombol menulis lewat panggilan taktik sim (`set_pace_mode`, `set_fuel_mode`, `set_ers_mode`, `set_tactic_mode`, `request_pit`) |
| `telemetry_drawer.gd` + `telemetry_widgets.gd` | `T`: instrumen, bukan deretan angka: kotak gigi + strip lampu RPM + bar speed + chip DRS, jejak pedal 6 detik, kotak G persegi dengan jejak, matriks panas 4 ban (suhu, tread, cakram rem, blister, silang saat blow-out), bar fuel dengan penanda bendera + margin, meter ERS dengan chevron aliran, bar stres / percaya diri berlawanan arah, jejak detak jantung, bar umur ban dan kerusakan |
| kartu saran hybrid | Muncul saat desk HYBRID mengusulkan (BOX FOR HARD, dst.); ACCEPT menjalankan `accept_suggestion()`, DISMISS `dismiss_suggestion()` |
| `step_bar.gd`, `mode_row.gd`, `caution_tape.gd` | Bar bersegmen (lime > 60 %, kuning 30 - 60 %, crimson berkedip <= 30 %), baris tombol eksklusif, pita kuning-hitam bergerak untuk yellow / VSC / safety car |

Tombol: `M` lipat deck, `T` telemetri, `Tab` kolom tower, `H` sembunyikan HUD, `E` ERS overtake, `[` `]` pace, `N` mobil berikutnya tim pemain. Tombol dunia tetap: `1-5` skala waktu, `←/→` ganti mobil, `C` kamera, `P` pit mobil yang diikuti. Mengklik baris tower atau tab deck mengganti mobil yang diikuti kamera.

### File lama yang diubah atau dihapus

| File | Perubahan |
|---|---|
| `scripts/ui/driver_row.gd` (CRLF) | Kunci opsional `right_text`, `right_color`, `compound_letter`, `compound_color`; tanpa kunci itu perilaku sama seperti sebelumnya |
| `scripts/world/track_environment_builder.gd`, `scripts/world/start_gantry.gd` | Offset kerb / armco / pagar dari `road_half_width_m` ribbon; lampu gantry lebih terang |
| `scenes/race_weekend_world.tscn` | Ribbon `road_half_width_m = 7.0`, node `Vfx` dan skrip `Hud` |
| `scripts/car/traffic_race_sim.gd` | Hook `speed_caps` dan `pit_lane_ids` dari Fase 5.5 **dikembalikan** ke perilaku awal |
| dihapus (dibuat di Fase 5.5) | `scripts/car/match_collider_system.gd`, `scripts/world/world_pit_director.gd` |

`scripts/core/*`, `modular_car_assembler.gd`, `track_circuit.tscn`, `driver_strategy_deck.gd` dan sesi Pit Wall lama tidak diubah.

### Rulings

1. **Sim berjalan 20 Hz tetap, dunia menginterpolasi.** Referensi juga 20 Hz; skala 16x memajukan jumlah tick, bukan ukuran tick, jadi hasil balapan sama di semua skala.
2. **Panjang lap = panjang ribbon 4159 m**, bukan 5807 m milik engine lama. Kecepatan puncak mobil dikalikan sekitar 0.93 dari referensi dan `V_MAX = 76 m/s`; nama tim / pembalap milik La Voiture, kode siaran dibuat unik.
3. **Ruang balap = 2.4 m antar pusat mobil** (sesuai referensi), bukan 1.8 m antara bodi dan tepi lintasan seperti di Fase 5.5. Aturan one-move defending dan bendera biru tetap ada, kini di sim.
4. **Kotak kontak melebar di tikungan** (`gt_contacts.gd`) agar uji tumpang tindih SAT 4.45 x 2.08 m di 3D (toleransi 0.05 m) lolos tanpa mematikan side-by-side.
5. **Pit lane memakai ulang geometri `PitLaneComplex`** (masuk, garis cepat, stall, keluar) dan konstanta 80 km/jam; sim yang menggerakkan mobil, 3D hanya menampilkan. Pit exit mempertahankan limiter sampai garis keluar.
6. **Kompon GT 5 nilai**, perakit modular hanya mengenal 4 (`TireCompound`): intermediate dan wet memakai nama WET milik perakit, adegan roda dipilih terpisah (`WHEEL_SCENES`).
7. **HUD memakai kanvas tetap 1920 x 1080** seperti `PitWallDashboard`, bukan jangkar per kontrol, supaya semua pecahan ukuran tetap selaras dengan desain.
8. **Kelas `SegmentBar` di `driver_strategy_deck.gd` sudah ada** (kelas dalam) dan bentrok dengan nama global, jadi bar baru bernama `StepBar`.
9. **Mobil pemain** = mobil tim `player_team_id` (0), dua mobil. AI hanya mengelola rival; mobil pemain pit lewat tombol `P` atau tactical deck.
10. **Cuaca bawaan dunia: DRY_SUNNY** (ekspor `weather_archetype`; `-1` memilih dari seed). Hujan bisa diuji lewat tangkap layar `rain`.

---

## 2. Hasil Pengujian

Perintah penuh: `Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_race_weekend_and_physics.gd` (± 3 menit; `-- --skip-legacy` ± 20 s). Suite turunan bisa dijalankan sendiri-sendiri dengan `-s tests/<nama>.gd`; `test_race_world` butuh `-- --fixed-fps 60`.

| Suite | Assertion | Cakupan |
|---|---|---|
| `test_gt_sim.gd` | 43 | RNG, data, trek, cuaca (7 arketipe), balapan 3 lap penuh (tanpa NaN, 0 pasangan tumpang tindih > 0.2 m dalam 5496 tick), side-by-side, racecraft, bendera + safety car fisik, DRS/ERS/slipstream, bahan bakar, ban + puncture, pit + double stack, taktik, sudut sasis, telemetri, sektor |
| `test_race_weekend_and_physics.gd` | 30 | 25 butir akseptansi Fase 5.5 pada sim GT (garis balap, collider, start 5 lampu, pit di dunia, roda, lingkungan, kamera) + suite turunan |
| `test_car_dynamics_vfx.gd` | 18 | Roda depan membelok / belakang tidak, roll / pitch / yaw, lampu, sayap DRS, hujan dan jalan basah, asap, percikan, letupan knalpot, slipstream, safety car |
| `test_race_hud.gd` | 31 | Ribbon, bar bersegmen, tower 20 baris + Tab + DNF + klik, tombol deck menulis ke sim, tab pembalap, BOX THIS LAP, lipat deck, tombol keyboard, drawer telemetri, kartu saran accept / dismiss, radio cut-in, caution tape, widget cuaca, tombol skala waktu |
| suite lama | 18 + 43 + 26 + 43 + 65 | `test_modular_car`, `test_simulation_verification`, `test_pit_wall`, `test_weather_and_ai`, `test_race_world`: tanpa regresi |

Cuplikan terminal:

```
[PASS] pace: best laps run 79.6 s to 88.0 s on 4.16 km (avg 188 km/h), cars differ by team
[PASS] pace: top speed in the race 287 km/h
[PASS] contact: no two car boxes overlap by more than 0.2 m in 5496 ticks (0 pair-ticks)
[PASS] lanes: longest side-by-side pair 2.5 s, longest three abreast 1.6 s (no stacked rows)
[PASS] chassis: front wheels steer into the corner, + for right and - for left (13894 of 13960 samples)
[PASS] chassis: the body rolls with the corner (13931 of 13960), dives under braking (+pitch, 26 of 26), squats under power (-pitch, 392 of 392), all angles finite
31 assertions, 0 failure(s)
FASE 5.8 FUSED HUD: PASS
```

Uji rendam (skrip sementara, sudah dihapus; 25 lap, 16x, seed 11, HUD aktif): 2629 s waktu balapan dalam 81 s CPU (± 1.3 ms per tick sim), 18 pit stop AI lewat pit lane 3D, 0 DNF, 0 error, semua mobil finis; pemimpin lap terbaik 84.8 s (SOK), 85.2 s (CRU), 85.7 s (AOK).

Bug yang ditemukan dan dibereskan selama pengerjaan: indeks kompon 4 di luar batas perakit (dipetakan dengan `mini`), roda lama menggantung di soket (`remove_child` sebelum `queue_free`), mobil finis tetap membakar bensin hingga DNF (kini berhenti), tumpang tindih SAT di tikungan, referensi siklik `GtRace` (ditambah `dispose()`), bentrok nama `wrap()` dan `SegmentBar`, urutan banner `LIGHTS OUT!` yang menutupi bendera kuning di 2 s pertama.

## 2b. Putaran umpan balik (setelah tinjauan pemilik proyek)

| Keluhan | Akar masalah (terukur) | Perbaikan | Bukti |
|---|---|---|---|
| Leaning / belokan bergetar | Sim memperbarui `chassis_roll`, `chassis_pitch`, `yaw_offset`, `steer_angle` tiap tick 20 Hz; aktor memakainya apa adanya, jadi 66 - 70 % frame 60 fps membeku lalu melompat (rasio turunan kedua / pertama = 2.00, lompatan roll sampai 0.063 rad dalam satu frame) | `GtCarActor.ease2()`: dua low-pass bertingkat (τ 0.07 s) untuk roll, pitch, yaw dan steer; spin tetap digambar mentah | Setelah: frame beku 0 %, rasio 0.12 - 0.23, lompatan maksimum turun ± 20x. Uji `smooth:` (lompatan per frame < 10 % dari ukuran langkah; sebelum perbaikan 0.99 / 1.00 / 1.00 / 0.30) |
| Kamera pit menyorot mobil lain | `_update_cameras` mengambil stall job terakhir bila tidak ada job milik mobil yang dipilih | Fokus pit hanya untuk job `car_id == followed_id` | Uji `#26b` (merah sebelum perbaikan) |
| Highlight Live Timing ganda setelah klik baris lalu `N` | Baris yang diklik menyimpan fokus keyboard, yang menyalakannya seperti pilihan; saat mobil berganti lewat `N`, panah, atau tab deck, fokus tidak dilepas (baris menyala: `[0, 6]`) | `RaceHud._update_tower` melepas fokus baris yang bukan mobil yang diikuti | Uji `tower: clicking a row then pressing N...` (merah, lalu `[0]`) |
| Telemetri terlalu banyak angka | Delapan baris teks angka | `TelemetryDrawer` didesain ulang jadi instrumen (`telemetry_widgets.gd`): strip lampu RPM + bar speed + kotak gigi, jejak pedal 6 detik, kotak G persegi dengan jejak, matriks panas 4 ban (suhu, tread, cakram rem, blister, silang saat blow-out), bar fuel dengan penanda bendera, meter ERS dengan chevron aliran, bar stres / percaya diri berlawanan arah, jejak detak jantung, bar umur ban dan kerusakan. Angka tersisa: gigi, speed, margin fuel, detak jantung | 5 uji `telemetry:` baru |
| Elemen merah melayang di belakang dan biru di sayap | Bar lampu belakang dan flap DRS cyan buatan `RaceVfx` | Keduanya dihapus. Diganti tip mengambang di atas tiap mobil (`Label3D` billboard): kode pembalap + satu baris status (HAZARD berkedip, PIT, DRS, BRAKE hanya untuk mobil yang diikuti); rival hanya tampil dalam 60 m, mobil yang diikuti selalu | Uji `tip:` (2) |
| Layout: sudut kiri dan kanan bawah kosong | Deck 1236 px melayang di tengah; tower dan kolom kanan berhenti di y 872 | Pemilik proyek memilih **opsi A (strip lebar)**: deck jadi satu pita 1888 x 140 px di bawah semua panel (tab mobil, Pace / Fuel / ERS, ban + BOX, tactic desk, baris radio terakhir + jumlah stop); tower 780 px, drawer telemetri 496 px; banner radio anime diangkat di atas strip. Opsi lain ada di artifact perbandingan | Uji `layout:` (merah, lalu hijau), tangkap layar `phase-5.8-hud.png` |

**Putaran lanjutan, tip grafiti:** tip kode pembalap diganti elemen brutalis grafiti (`scripts/vfx/graffiti_tag.gd`, dilukis sekali ke `SubViewport` lalu jadi `Sprite3D` billboard): slab cat miring warna tim dengan bayangan tinta keras, border tebal, percikan spray, tetesan cat, pita hazard di sudut, pita halftone dan panah stensil menunjuk mobil; bentuknya dari seed per mobil. Nama kini hanya muncul sesaat (2.4 s, fade-in 0.1 s, fade-out 0.5 s) saat posisi berubah, mobil dipilih, atau rival mendekat dalam 60 m, dengan opasitas 0.6. Status (DRS, PIT, HAZARD berkedip, BRAKE untuk mobil yang diikuti) jadi stiker grafiti kecil yang tampil selama kondisinya berlaku. Uji: 5 uji `tip:` (18 assertion di `test_car_dynamics_vfx`).

File yang disentuh: `scripts/car/gt_car_actor.gd`, `scripts/world/race_weekend_world.gd`, `scripts/vfx/race_vfx.gd`, `scripts/hud/*` (baru: `telemetry_widgets.gd`; diubah: `race_hud.gd`, `tactical_deck.gd`, `telemetry_drawer.gd`, `step_bar.gd`, `mode_row.gd`), tes `test_car_dynamics_vfx` (18 assertion), `test_race_hud` (31), `test_race_weekend_and_physics` (+ `#26b`). Suite akseptansi penuh: PASS.

## 3. Tangkap Layar

Dari `scenes/race_weekend_world.tscn` dengan `scratch/capture_phase55.gd` (GPU nyata, 1920 x 1080; mode `all`, `lights`, `track`, `pit`, `rain`, `launch`, `hud`):

1. `scratch/phase-5.8-hud.png`: HUD gabungan dengan layout A (strip deck lebar): ribbon, tower, radar + rekor, drawer telemetri instrumen, kartu saran, radio cut-in di atas strip, marquee.
1b. `scratch/phase-5.8-tips.png`: HUD disembunyikan (`H`), tip mengambang di atas mobil.
2. `scratch/phase-5.7-rain.png`: hujan, jalan memantul, percikan air.
3. `scratch/phase-5.7-launch.png`: start, asap ban dan letupan knalpot.
4. `scratch/phase-5.5-race-track.png`, `scratch/phase-5.5-start-lights.png`, `scratch/phase-5.5-pitstop-action.png`: dirender ulang di atas sim GT (kerb, gantry, kru pit).

## 4. Catatan untuk Pemilik Proyek

- **Tinjauan akhir:** dikerjakan inline; proyek bukan repo git, jadi tidak ada diff dan tidak ada reviewer segar. Yang diperiksa sendiri: seluruh suite di atas dan rendam 25 lap.
- **Tuning terbuka:** waktu lap 84.8 - 88 s di trek 4159 m; angka `LATERAL_ACCEL 19.5` dan `V_MAX 76` di `gt_track.gd` menentukan kesan kecepatan. Uji `pace` menerima 60 - 105 s, jadi menaik-turunkannya tidak merusak suite.
- **Belum dikerjakan:** `weather_archetype` hujan tidak punya tombol di HUD (hanya ekspor dan tangkap layar); `tactical_deck_hud.gd` dari diagram spec 5.5 digantikan oleh `tactical_deck.gd`; kru pit masih kapsul + helm low-poly; potret radio memakai satu gambar yang sama untuk semua pembalap.
- **Biaya yang diketahui:** tower dan panel HUD memanggil `race.standings()` (sort 20 mobil) tiap 3 - 6 frame; pada 16x biaya ini belum diukur terpisah; soak 25 lap berjalan tanpa masalah.
- Setelah menambah `class_name`, jalankan `godot --headless --path . --import` sekali.
