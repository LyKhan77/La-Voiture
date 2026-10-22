# TASK SPECIFICATION: FASE 6 — AUDIO SOUNDSCAPE GENEX & POLISHING BALAPAN PENUH

**Task ID:** `TASK-FASE-6-AUDIO-SOUNDSCAPE-FULL-POLISH`  
**Assignee:** Executor Agent (Godot Audio & Game Systems Specialist)  
**Priority:** High (Final Polish for Vertical Slice Completion)  
**Engine:** Godot Engine 4.7.2 (`C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`)  
**Workspace:** `D:\Occupation\Porto\genex\La_Voiture`  
**Reference Docs:**
- `PRD/06-AUDIO-SOUNDSCAPE.md` (Spesifikasi Audio & Bus Layout)
- `docs/superpowers/specs/2026-10-21-phase-6-audio-soundscape-and-polish.md`
- `docs/superpowers/plans/2026-10-21-phase-6-implementation-plan.md`

---

## 1. Scope & Deliverables

Executor Agent ditugaskan untuk membangun **Sistem Audio Lengkap (Soundscape Engine)**, mengintegrasikan suara mesin balap 3D, decit ban adaptif, transmisi radio walkie-talkie dengan *music ducking*, umpan balik klik UI taktil, serta menghadirkan **Layar Podium Juara (Race Weekend Finale)**.

### Deliverables:
1. **Godot 4 Audio Bus Layout (`default_bus_layout.tres`):**
   - 5 Bus: `Master`, `Music`, `SFX`, `UI`, dan `Radio`.
   - Bus `Radio` memiliki `AudioEffectBandPassFilter` ($300\text{Hz} - 3.4\text{kHz}$) dan `AudioEffectDistortion` (drive 0.28).
2. **Koleksi Aset Suara (`assets/audio/`):**
   - Hasilkan atau buat file audio `.wav` / `.ogg` valid:
     * UI: `click_snap.wav`, `warning_siren.wav`, `start_beep.wav`, `lights_out.wav`.
     * Engine: `gt3_engine_loop.wav`, `gearshift_pop.wav`.
     * SFX: `tire_screech.wav`, `pit_gun.wav`, `kerb_rumble.wav`.
     * Radio: `squelch_in.wav`, `squelch_out.wav`.
     * Music: `streetwear_synth.ogg`.
   - *Catatan Kredit Genex:* Jika menggunakan `npx genex sfx`, biaya hanya 2 cr/file. Generator WAV prosedural / synthesizer murni juga diperbolehkan sebagai pendukung.
3. **Global Audio Manager (`scripts/audio/audio_manager.gd`):**
   - Autoload atau pengatur global untuk memainkan efek suara UI, alarm peringatan, dan nada lampu start FIA.
4. **3D Spatial Vehicle Audio (`scripts/audio/engine_audio_3d.gd` & `tire_audio_3d.gd`):**
   - Pasang pada [`scenes/race_world/gt_car_actor.tscn`](file:///D:/Occupation/Porto/genex/La_Voiture/scenes/race_world/gt_car_actor.tscn).
   - Suara mesin: Modulasi pitch kontinu berdasarkan putaran RPM ($1200 \dots 8500\text{ RPM}$, pitch $0.65 \dots 1.85$) dan modulasi volume berdasarkan bukaan gas serta kecepatan.
   - Suara letupan knalpot (*backfire pop*) seketika saat mobil menaikkan gigi (*upshift*).
   - Suara decit ban: Aktif otomatis saat gaya sentrifugal lateral $|G_{\text{lat}}| > 1.8\text{G}$ atau saat ban terkunci (*lockup*).
5. **Radio Audio Director & Music Ducking (`scripts/audio/radio_audio_director.gd`):**
   - Terintegrasi dengan radio cut-in: Saat transmisi radio aktif, bus `Music` diduck sebesar $-8.0\text{dB}$ dalam tempo $150\text{ms}$.
   - Membunyikan `squelch_in` di awal, menayangkan pesan, membunyikan `squelch_out`, lalu memulihkan volume musik (+8dB dalam 500ms).
6. **Umpan Balik Taktil Antarmuka (HUD & Gantry):**
   - Setiap klik tombol di Tactical Deck, Timing Tower, dan Telemetry Drawer membunyikan `click_snap.wav`.
   - Countdown 5 lampu start gantry membunyikan nada bertingkat `start_beep.wav` dan nada `lights_out.wav` saat lampu padam.
   - Servis pit stop kru 3D membunyikan deru mesin pneumatik `pit_gun.wav` saat roda dicopot/dipasang.
7. **Layar Podium Juara & Akhir Balapan (`scenes/ui/podium_screen.tscn` & `scripts/ui/podium_screen.gd`):**
   - Muncul otomatis saat balapan selesai (`CHEQUERED_FLAG`).
   - Panggung podium 3 tingkat bergaya anime neo-brutalisme dengan pemenang P1, P2, P3, trofi, dan confetti.
   - Tabel perolehan poin kejuaraan konstruktor FIA GT3 ($25, 18, 15, 12, 10, 8, 6, 4, 2, 1$).
   - Cap grafiti ungu `FASTEST LAP // +1 PT BONUS`.
   - Tombol aksi `RESTART` dan `EXIT TO HQ`.
8. **Automated Test Suite:**
   - Script [`tests/test_audio_and_race_weekend.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/tests/test_audio_and_race_weekend.gd) dengan minimal 20 assertions wajib lulus 100%.

---

## 2. Spesifikasi Teknis Formula & Integrasi

### A. Formula Pitch & Volume Mesin
```gdscript
# scripts/audio/engine_audio_3d.gd
func update_engine_audio(rpm: float, throttle: float, speed_mps: float) -> void:
    var normalized_rpm: float = clampf((rpm - 1200.0) / (8500.0 - 1200.0), 0.0, 1.0)
    pitch_scale = 0.65 + 1.20 * pow(normalized_rpm, 0.85)
    var target_db: float = -18.0 + (12.0 * throttle) + (6.0 * (speed_mps / 76.0))
    volume_db = clampf(target_db, -30.0, 4.0)
```

### B. Formula Decit Ban
```gdscript
# scripts/audio/tire_audio_3d.gd
func update_tire_audio(lateral_g: float, is_locked: bool) -> void:
    if absf(lateral_g) > 1.8 or is_locked:
        if not playing:
            play()
        var target_db: float = -24.0 + (absf(lateral_g) - 1.8) * 12.0
        volume_db = clampf(target_db, -28.0, 0.0)
    else:
        if playing:
            stop()
```

### C. Alur Music Ducking
```gdscript
# scripts/audio/radio_audio_director.gd
func duck_music(active: bool) -> void:
    var music_bus_idx: int = AudioServer.get_bus_index("Music")
    var target_db: float = -8.0 if active else 0.0
    var duration: float = 0.15 if active else 0.50
    # Interpolasikan AudioServer.set_bus_volume_db(music_bus_idx, target_db) via Tween
```

---

## 3. Protokol Pengujian & Syarat Kelulusan (Acceptance Criteria)

Jalankan pengujian headless:
```powershell
& "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_audio_and_race_weekend.gd
```

### 20 Assertions Wajib (100% PASS):
1. `[PASS]` Audio bus layout memuat 5 bus (`Master`, `Music`, `SFX`, `UI`, `Radio`).
2. `[PASS]` Bus Radio memiliki AudioEffectBandPassFilter dengan cutoff frekuensi vokal 1.8 kHz.
3. `[PASS]` Bus Radio memiliki AudioEffectDistortion mode CLIP.
4. `[PASS]` Seluruh file audio esensial tersedia dan dapat di-load tanpa null resource.
5. `[PASS]` Pitch mesin monoton naik dari 0.65 (pada 1200 RPM) hingga 1.85 (pada 8500 RPM).
6. `[PASS]` Volume mesin meningkat sebanding dengan bukaan gas dan kecepatan.
7. `[PASS]` Letupan knalpot (gearshift pop) terpicu saat sinyal upshift dikirim.
8. `[PASS]` Audio decit ban aktif saat lateral G > 1.8G.
9. `[PASS]` Audio decit ban diam/berhenti saat berkendara lurus santai (< 1.8G).
10. `[PASS]` Music ducking menurunkan volume bus Music sebesar minimal -8 dB saat radio aktif.
11. `[PASS]` Music ducking memulihkan volume bus Music kembali normal saat transmisi selesai.
12. `[PASS]` Squelch in berbunyi di awal transmisi dan squelch out di akhir transmisi.
13. `[PASS]` Klik tombol Tactical Deck memicu sinyal audio UI.
14. `[PASS]` Klik baris Timing Tower memicu audio snap klik taktil.
15. `[PASS]` Nada hitung mundur lampu start berbunyi pada setiap pasang lampu merah gantry.
16. `[PASS]` Nada buzzer hijau berbunyi seketika saat LIGHTS OUT!
17. `[PASS]` Bunyi pit gun berbunyi saat proses penggantian 4 roda kru di pit lane.
18. `[PASS]` Layar podium juara (podium screen) menampilkan pemenang P1, P2, P3 dengan benar.
19. `[PASS]` Tabel poin konstruktor FIA GT3 menghitung perolehan poin 25-18-15 dengan akurat.
20. `[PASS]` Seluruh test suite sebelumnya (`test_modular_car`, `test_simulation_verification`, `test_pit_wall`, `test_weather_and_ai`, `test_race_world`, `test_gt_sim`, `test_car_dynamics_vfx`, `test_race_hud`, `test_race_weekend_and_physics`) tetap 100% PASS tanpa regresi.

---

## 4. Laporan Hasil Eksekusi

Setelah menyelesaikan seluruh langkah di atas dan memastikan semua tes lulus 100%, buat laporan eksekutif di:
`executor-report/FASE-6-AUDIO-SOUNDSCAPE-FULL-POLISH.md`

Sertakan:
- Rangkuman implementasi bus audio, script kontroler, dan integrasi layar podium.
- Capture terminal hasil pengujian `test_audio_and_race_weekend.gd`.
- Screenshot visual layar selebrasi podium juara (`scratch/phase-6-podium.png`).
