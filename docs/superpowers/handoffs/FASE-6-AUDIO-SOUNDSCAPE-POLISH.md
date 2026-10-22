# Handoff Blueprint: Fase 6 — Audio Soundscape Genex & Polishing Balapan Penuh
**Target Executor:** Audio Engineer & Game Polish Specialist  
**Spesifikasi Acuan:** [PRD/06-AUDIO-SOUNDSCAPE.md](file:///D:/Occupation/Porto/genex/La_Voiture/PRD/06-AUDIO-SOUNDSCAPE.md) & [PRD/00-MASTER-OVERVIEW.md](file:///D:/Occupation/Porto/genex/La_Voiture/PRD/00-MASTER-OVERVIEW.md)  
**Tujuan Akhir:** Menghasilkan dan mengintegrasikan seluruh aset audio (raungan mesin GT3, klik taktil UI, transmisi radio pembalap via Genex Audio), menerapkan sistem *Music Ducking*, serta menyatukan alur balapan penuh dari kualifikasi hingga podium.

---

## 1. Copy-Paste Prompt untuk Executor Agent

Salin prompt di bawah ini ke agent eksekutor:

```text
Anda adalah Audio Engineer & Game Polish Specialist. Tugas Anda adalah mengeksekusi FASE 6 proyek game "La Voiture": Membangun Lanskap Suara (Audio Soundscape), Mengintegrasikan Aset Audio Genex, dan Menyelesaikan Loop Balapan Lengkap.

Dokumen Acuan Wajib:
- PRD 06: D:/Occupation/Porto/genex/La_Voiture/PRD/06-AUDIO-SOUNDSCAPE.md (Audio Bus Layout, Music Ducking, Transmisi Radio)
- PRD 00: D:/Occupation/Porto/genex/La_Voiture/PRD/00-MASTER-OVERVIEW.md (Alur Siklus Balapan Penuh)

Tools yang Tersedia:
- Genex Audio CLI (npx @genex-ai/cli-demo sfx, music, voice)
- Godot Engine Path: "C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"

Instruksi Eksekusi:
1. Konfigurasikan Godot Audio Bus Layout (default_bus_layout.tres):
   - Master -> Music (Send: Master)
   - Master -> SFX (Send: Master)
   - Master -> UI (Send: Master)
   - Master -> Radio (Effect: AudioEffectBandPassFilter 300Hz-3400Hz, Send: Master)
2. Generate aset audio lokal menggunakan Genex CLI:
   - SFX Mesin & Balap: npx @genex-ai/cli-demo sfx "GT3 racing car V8 twin turbo engine revving high rpm" --out-dir res://assets/audio/sfx/
   - SFX UI: npx @genex-ai/cli-demo sfx "hard tactile mechanical keyboard switch click sharp high frequency" --out-dir res://assets/audio/ui/
   - Voice Radio Pembalap: npx @genex-ai/cli-demo voice --archetype racer "Box this lap, confirming pit entry!" --out-dir res://assets/audio/radio/
   - Musik Balap: npx @genex-ai/cli-demo music "fast aggressive dark synthwave racing soundtrack instrumental" --out-dir res://assets/audio/music/
3. Buat scripts/audio/engine_audio_3d.gd:
   - Modulasi pitch suara mesin berdasarkan kecepatan dan putaran RPM mobil (1200 s.d 8500 RPM).
   - Efek letupan knalpot (backfire pops) saat deselerasi pengereman.
4. Buat scripts/audio/radio_voice_manager.gd:
   - Sistem antrean klip suara pembalap.
   - Music Ducking otomatis: menurunkan volume bus Music sebesar -8dB saat radio aktif, lalu memulihkannya dalam waktu 500ms setelah klip suara selesai.
5. Sambungkan seluruh alur game di scenes/main.tscn:
   - Kualifikasi 1-Lap -> Grid Start -> Balapan Utama (Pit Wall) -> Podium Juara.
6. Verifikasi alur permainan lengkap dengan menjalankan scenes/main.tscn dan pastikan seluruh audio terdengar imersif dan performa stabil pada >= 60 FPS.
```

---

## 2. Rincian File yang Harus Dibuat

```text
D:/Occupation/Porto/genex/La_Voiture/
├── default_bus_layout.tres
├── scripts/
│   └── audio/
│       ├── audio_manager.gd
│       ├── engine_audio_3d.gd
│       └── radio_voice_manager.gd
├── scenes/
│   ├── main.tscn
│   └── podium_screen.tscn
└── assets/
    └── audio/
        ├── sfx/
        ├── ui/
        ├── radio/
        └── music/
```

---

## 3. Langkah Implementasi Terinci (Step-by-Step Plan)

### Step 1: Konfigurasi Audio Bus & Efek Bandpass
- Buat `default_bus_layout.tres`:
  - Tambahkan bus `Music`, `SFX`, `UI`, dan `Radio`.
  - Pada bus `Radio`, tambahkan `AudioEffectBandPassFilter` dengan `cutoff_hz = 1500.0` dan `resonance = 0.5` untuk mensimulasikan transmisi interkom pembalap.

### Step 2: Generasi & Penataan Aset Audio Genex
- Jalankan perintah CLI Genex untuk mengunduh sampel suara berkualitas tinggi langsung ke dalam struktur folder Godot `res://assets/audio/`.

### Step 3: Implementasi Modulasi RPM Mesin 3D
- `engine_audio_3d.gd`:
  ```gdscript
  func update_rpm(speed_mps: float, throttle: float) -> void:
      var simulated_rpm: float = clamp(1200.0 + (speed_mps * 95.0), 1200.0, 8500.0)
      pitch_scale = lerp(pitch_scale, simulated_rpm / 3500.0, 0.1)
  ```

### Step 4: Implementasi Music Ducking
- Saat transmisi radio dipicu:
  ```gdscript
  func play_radio_line(stream: AudioStream) -> void:
      var music_idx = AudioServer.get_bus_index("Music")
      AudioServer.set_bus_volume_db(music_idx, -8.0)
      radio_player.stream = stream
      radio_player.play()
      await radio_player.finished
      AudioServer.set_bus_volume_db(music_idx, 0.0)
  ```

### Step 5: Alur Balapan Penuh di `main.tscn`
- Sambungkan transisi state:
  1. *State Kualifikasi:* 20 mobil mencatatkan waktu lap $\rightarrow$ urutan grid tersusun.
  2. *State Balap:* Pemain mengendalikan Car #01 dan Car #02 dari Pit Wall Dashboard hingga bendera finish.
  3. *State Podium:* Layar selebrasi menampilkan 3 mobil teratas dengan musik kemenangan streetwear.

---

## 4. Perintah Verifikasi & Acceptance Test

```powershell
& "C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" scenes/main.tscn
```
* **Kriteria Keberhasilan:** Game berjalan penuh dari sesi Kualifikasi hingga Balapan dan Podium, audio mesin meraung dinamis sesuai RPM, interaksi UI menghasilkan klik renyah, transmisi radio memotong musik dengan efek walkie-talkie lo-fi, dan performa stabil $\ge 60\text{ FPS}$.
