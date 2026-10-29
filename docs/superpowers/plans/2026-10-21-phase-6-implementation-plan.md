# IMPLEMENTATION PLAN: FASE 6 — AUDIO SOUNDSCAPE & RACE WEEKEND FINALE

**Goal:** Membangun arsitektur audio Godot 4 lengkap dengan 5 bus, suara mesin 3D reaktif RPM, decit ban lateral G, radio walkie-talkie lo-fi dengan music ducking, efek suara UI taktil, serta layar selebrasi podium juara balapan.

---

## Tahap Eksekusi Terinci

### Tahap 1: Audio Bus Layout & Sound Assets Production
- [x] Konfigurasi `default_bus_layout.tres`:
  - Bus `Master`, `Music`, `SFX`, `UI`, dan `Radio`.
  - Pasang `AudioEffectBandPassFilter` (300Hz-3.4kHz) dan `AudioEffectDistortion` pada bus `Radio`.
- [x] Siapkan folder `assets/audio/` (`ui/`, `engine/`, `sfx/`, `radio/`, `music/`).
- [x] Dapatkan atau buat aset suara (via `npx genex sfx` / generator prosedural WAV yang valid):
  - UI: `click_snap.wav`, `warning_siren.wav`, `start_beep.wav`, `lights_out.wav`.
  - Engine: `gt3_engine_loop.wav`, `gearshift_pop.wav`.
  - SFX: `tire_screech.wav`, `pit_gun.wav`, `kerb_rumble.wav`.
  - Radio: `squelch_in.wav`, `squelch_out.wav`.
  - Music: `streetwear_synth.ogg`.

### Tahap 2: Global Audio Manager & Dynamic Music Ducking
- [x] Buat `scripts/audio/audio_manager.gd`:
  - Fungsi `play_ui_click()`, `play_warning()`, `play_start_beep()`, `play_lights_out()`.
  - Manajemen level volume bus secara tersentralisasi.
- [x] Buat `scripts/audio/radio_audio_director.gd`:
  - Sambungkan ke event radio `RaceHud`.
  - Implementasikan ducking bus `Music` sebesar $-8\text{dB}$ saat transmisi aktif dan pulihkan secara halus ($500\text{ms}$).
  - Mainkan `squelch_in` dan `squelch_out`.

### Tahap 3: 3D Spatial Audio pada Mobil (`GtCarActor`)
- [x] Buat `scripts/audio/engine_audio_3d.gd`:
  - AudioStreamPlayer3D pada bus `SFX`.
  - Modulasi pitch berkelanjutan berdasarkan putaran RPM ($1200 \dots 8500\text{ RPM}$).
  - Modulasi volume berdasarkan bukaan throttle dan kecepatan mobil.
  - Trigger letupan knalpot `gearshift_pop` saat upshift gigi.
- [x] Buat `scripts/audio/tire_audio_3d.gd`:
  - AudioStreamPlayer3D pada bus `SFX`.
  - Picu decit ban ketika gaya lateral $|G_{\text{lat}}| > 1.8\text{G}$ atau saat ban terkunci (*lockup*).
- [x] Pasang komponen audio 3D ke `scenes/race_world/gt_car_actor.tscn`.

### Tahap 4: Audio Feedback pada Antarmuka (HUD & Gantry)
- [x] Pasang umpan balik audio klik taktil pada `scripts/hud/tactical_deck.gd`, `timing_tower.gd`, dan `telemetry_drawer.gd`.
- [x] Hubungkan countdown 5 lampu merah di `scripts/world/shared/start_gantry.gd` dengan nada `start_beep.wav` dan nada `lights_out.wav` saat lampu padam serentak.
- [x] Hubungkan aksi pit stop di `scripts/car/pitstop_choreographer.gd` dengan suara `pit_gun.wav` saat roda dicopot/dipasang.

### Tahap 5: Layar Podium Selebrasi Juara (Race Weekend Finale)
- [x] Buat `scenes/ui/podium_screen.tscn` dan `scripts/ui/podium_screen.gd`:
  - Panggung juara 3 tingkat bergaya manga cel-shaded / neo-brutalism.
  - Tampilkan 3 pembalap terbaik dengan piala, warna livery tim, dan total waktu tempuh.
  - Tampilkan cap grafiti ungu `FASTEST LAP +1 PT` untuk pencetak rekor putaran tercepat.
  - Tabel poin kejuaraan konstruktor FIA GT3 (25, 18, 15, 12, 10, 8, 6, 4, 2, 1).
  - Tombol aksi `RESTART` dan `EXIT TO HQ`.
- [x] Sambungkan pemicu kemunculan podium ke event `CHEQUERED_FLAG` di `scripts/world/weekend/race_weekend_world.gd`.

### Tahap 6: Automated Testing & Verification
- [x] Buat dan jalankan test suite `tests/test_audio_and_race_weekend.gd`:
  - Minimal 20 assertions berstatus 100% PASS.
  - Uji seluruh suite legacy (`test_modular_car`, `test_simulation_verification`, `test_pit_wall`, `test_weather_and_ai`, `test_race_world`, `test_gt_sim`, `test_car_dynamics_vfx`, `test_race_hud`, `test_race_weekend_and_physics`).
