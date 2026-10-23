# FASE 8.4 — Dynamic Radio Comms & 2D Podium Character Standees

**Status:** SELESAI — 24/24 suite headless PASS, 0 FAIL (23 suite lama + `tests/test_radio_and_podium.gd` baru, 32 assertion).
**Engine:** Godot 4.7.2 stable · **Spec:** `docs/superpowers/specs/2026-10-23-dynamic-radio-comms-and-podium-standees-design.md`

## 1. Manga Soundwave (`scripts/ui/anime_radio_cutin.gd`)

| Parameter | Nilai |
| :--- | :--- |
| Bar | 14 batang, lebar 7 px, jarak 3 px, tinggi maks 22 px, strip 28 px di dasar banner (di bawah teks) |
| Harmonik | 8 / 14 / 22 Hz, bobot 0.5 / 0.3 / 0.2, fase per-bar; `A = 0.18 + 0.82·mix` |
| Gaya | outline `T.INK_BORDER_BLACK`, isi paper `#F4F5F7`, cap tinta di puncak, baseline 2 px |
| Aktif | `soundwave_active = true` di `_play()`, `false` di `_hide_banner()` |
| Idle | peluruhan eksponensial (`WAVE_DECAY = 8/s`); `_process` berhenti menggambar saat energi < 0.0005 |
| API uji | `soundwave_energy()` = rata-rata tinggi bar (0..1) |

Tinggi banner bertambah `WAVE_STRIP` (28 px) agar bar tidak menimpa teks panjang; tinggi minimum 150 px tidak berubah.

## 2. Potret driver dinamis (`scripts/hud/race_hud.gd`)

`_on_radio`: speaker `driver` memuat `GarageRoster.portrait_path(car_id)` (fallback `PORTRAIT`), speaker `engineer` memakai `ENGINEER_PORTRAIT`. 20/20 slot punya `radio_portrait.png`.

## 3. Matriks trigger komunikasi driver

| Situasi | Lokasi | Pesan | Prioritas |
| :--- | :--- | :--- | :--- |
| Overtake selesai | `GtDriving.announce_pass` (saat `car.s > ahead.s + 2.2`) | `Pass made on %s! Clean move down the inside!` | Standar |
| Kehilangan posisi | `GtDriving.announce_pass` (mobil yang disalip) | `Lost the spot to %s! Defending now!` | Standar |
| ERS OVERTAKE aktif | `GtDriving.announce_ers_boost` (transisi mode) | `Deploying ERS boost! Maximum attack!` | Standar |
| Tyre cliff (`wear > 0.75`) | `_wear_and_fuel`, sekali per set ban (`car.tyre_cliff_called`, reset di pit stop) | `Tyres are cooked! Rear is sliding everywhere!` | Standar |
| Rub / kontak ringan | `GtContacts.announce_rub` (mobil tim pemain) | `We touched with %s! Check the telemetry!` | Urgent |

**Cooldown:** `GtRace.driver_radio_cooldown` (car id → detik). `push_radio` untuk speaker `driver` non-urgent menyetel 15 s (`DRIVER_RADIO_COOLDOWN_S`); `step()` menurunkannya per tick; `can_push_driver_radio(id)` true saat ≤ 0. Urgent dan engineer tidak memicu/ditahan cooldown. Diverifikasi: muted di 14 s, bebas di 15 s.

## 4. Suara (Kokoro-82M)

- `tools/audio/radio_lines.mjs`: 5 baris driver baru; `VOICES.driver_female` = `af_bella`. Setiap baris driver otomatis punya varian `<id>_f` (`voice: "female"`).
- `generate_radio_voices.mjs` memilih voice per baris dan menulis `voice` ke manifest.
- 23 klip baru dirender (5 pria + 18 wanita), manifest 64 → 87 baris (diff hanya penambahan).
- `RadioVoice.find(speaker, text, car_id)`: slot 7 (Freja Berg, `FEMALE_DRIVER_SLOTS`) memilih klip wanita, jatuh ke klip pria jika tidak ada.

## 5. Standee podium (`scripts/ui/podium_screen.gd`)

Kartu teks diganti `_build_standee(place, car)`: 360×240 px, border ink 4 px, bayangan offset 6 px, latar warna livery (gelap) + hatching manga, potret 140×140 dalam bingkai ink 2 px, badge nomor, `KODE // TIM`, waktu finis, nama driver, pita tier: Gold `P1 WINNER // 25 PTS`, Silver `P2 RUNNER-UP // 18 PTS`, Bronze `P3 PODIUM // 15 PTS`.

Animasi (`set_elapsed(s)` untuk uji deterministik): P3 t=0.0 s (naik 60 px, fade 0.35 s), P2 t=0.2 s (60 px, 0.35 s), P1 t=0.4 s (80 px, 0.4 s); trophy pop + confetti mulai t=0.5 s.

## 6. Ruling (menyimpang dari plan, spec tetap acuan)

1. `push_radio` memakai parameter `force`, bukan `urgent`; `car.wear`, bukan `tyre_wear`; tidak ada `deploy_ers()` / `_process_tick()` — hook dipasang di titik setara (`step()`, transisi `ErsMode.OVERTAKE`).
2. Baris puncture baru **tidak** ditambahkan: `drv_puncture` ("Puncture! The tyre has delaminated!", urgent) sudah ada dan sudah bersuara. Biaya jika salah: satu baris + dua klip.
3. Kontak: hanya rub ringan yang ditambah (urgent, dengan debounce 15 s per mobil agar balapan rapat tidak membanjiri banner); insiden berat sudah punya pesan urgent sendiri.
4. Female voice = car id 7 (folder `freja-berg`, nomor #08 di sim), bukan "Car #09" seperti tertulis di spec; id mengikuti `GarageRoster.DRIVER_SLUGS`.
5. Pita tier memakai poin tabel dasar (25/18/15); bonus fastest lap tetap di stamp dan tabel poin.
6. Manifest memakai flag `voice: "female"` (bukan speaker `driver_f`) karena `test_audio_and_race_weekend` mewajibkan tepat 2 speaker.

## 6b. Refinement setelah review

- **Rival:** `push_radio(..., force, rival)`. Pass yang melibatkan mobil tim pemain membuat driver AI di pasangan itu ikut bicara (non-urgent, potret driver itu). Pass antar dua mobil AI tetap diam. Cooldown 15 s berlaku untuk semua mobil.
- **Engineer:** pujian `Passing %s! Excellent drive.` dipindah dari awal serangan ke akhir pass (`announce_pass`). Keputusan memuji tetap diambil di titik dan dengan draw rng yang sama seperti sebelumnya (`car.praise_pending`), sehingga urutan acak seed lama tidak bergeser. Percobaan pertama (memindah draw rng) merusak `test_gt_sim` (DRS lap 1) dan dua suite pembungkusnya, lalu dikembalikan.
- **Podium:** stamp FASTEST LAP digeser (x 140 → 50) agar tidak menimpa trophy; layout standee dinaikkan 8 px agar nama tidak menempel border.

## 7. Verifikasi

- `godot --headless --path . -s res://tests/test_radio_and_podium.gd` → 35 assertion, 0 failure (RED awal: parse error pada API yang belum ada).
- Seluruh `tests/test_*.gd` → 24/24 exit 0, 0 baris `[FAIL]`.
- Tangkapan: `executor-report/screenshots/phases/fase-8.4-{radio,podium,podium_mid}.png` (`scratch/capture_fase84.gd`).
- **Belum dijalankan:** smoke test native 3 lap 20 mobil (60 FPS, orphan node saat kembali ke menu) — hanya diuji headless dan lewat tangkapan layar.
