# Handoff Blueprint: Fase 1 — Godot 4 Setup & Core Simulation Engine
**Target Executor:** Godot Systems & Simulation Engineer Agent  
**Spesifikasi Acuan:** [PRD/01-CORE-SIMULATION-ENGINE.md](file:///D:/Occupation/Porto/genex/La_Voiture/PRD/01-CORE-SIMULATION-ENGINE.md) & [PRD/07-DATA-TESTING-PERFORMANCE.md](file:///D:/Occupation/Porto/genex/La_Voiture/PRD/07-DATA-TESTING-PERFORMANCE.md)  
**Tujuan Akhir:** Menginisialisasi proyek Godot 4 dan membangun mesin simulasi matematika deterministik (20 mobil, degradasi 4 sudut ban, bensin, dirty air, mini-sektor) yang lulus uji headless hingga Fast-Forward $16\times$.

---

## 1. Copy-Paste Prompt untuk Executor Agent

Salin prompt di bawah ini ke agent eksekutor:

```text
Anda adalah Godot 4 Systems & Core Gameplay Engineer. Tugas Anda adalah mengeksekusi FASE 1 proyek game "La Voiture": Inisialisasi Proyek Godot 4 dan Pembangunan Core Simulation Math Engine.

Dokumen Acuan Wajib:
- PRD 01: docs/superpowers/specs/2026-10-20-la-voiture-architecture-design.md dan PRD/01-CORE-SIMULATION-ENGINE.md
- PRD 07: PRD/07-DATA-TESTING-PERFORMANCE.md
- Roadmap: ROADMAP.md

Lingkungan Eksekusi:
- Godot Engine Path: "C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
- Shell: PowerShell di Windows

Instruksi Eksekusi:
1. Inisialisasi file project.godot (resolusi 1920x1080, Forward+, 60 FPS target).
2. Buat struktur folder: scenes/, scripts/core/, scripts/car/, scripts/ui/, shaders/, assets/, tests/.
3. Implementasikan scripts/core/tire_model.gd (kompon Soft, Medium, Hard, Wet; degradasi & temperatur 4 sudut ban FL, FR, RL, RR).
4. Implementasikan scripts/core/fuel_model.gd (konsumsi bahan bakar kg dan penalti massa +0.15s/10kg).
5. Implementasikan scripts/core/car_state.gd (state telemetri mobil, spline distance, kecepatan, lajur).
6. Implementasikan scripts/core/race_sim_engine.gd (loop 60Hz deterministik, sub-stepping 1x-16x, kalkulasi slipstream, dirty air, mini-sektor delta).
7. Buat scripts/core/headless_sim_runner.gd yang menjalankan balapan 30 lap untuk 20 mobil tanpa grafis.
8. Verifikasi dengan menjalankan:
   & "C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" --headless --script scripts/core/headless_sim_runner.gd
   Pastikan exit code 0 dan seluruh assertion lulus (Soft lebih cepat dari Hard, deterministik 1x vs 16x).

Jangan menyentuh atau menghapus file yang sudah ada di luar cakupan ini. Tulis kode GDScript dengan static typing ketat.
```

---

## 2. Rincian File yang Harus Dibuat

```text
D:/Occupation/Porto/genex/La_Voiture/
├── project.godot
├── scripts/
│   └── core/
│       ├── car_state.gd
│       ├── tire_model.gd
│       ├── fuel_model.gd
│       ├── race_sim_engine.gd
│       └── headless_sim_runner.gd
└── tests/
    └── test_simulation_verification.gd
```

---

## 3. Langkah Implementasi Terinci (Step-by-Step Plan)

### Step 1: File Konfigurasi `project.godot`
Buat `project.godot` berisi:
```ini
; Engine configuration file.
config_version=5

[application]
config/name="La Voiture"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.3", "Forward Plus")

[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=0
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

### Step 2: Implementasi `scripts/core/tire_model.gd`
- Definisikan enum kompon: `SOFT`, `MEDIUM`, `HARD`, `WET`.
- Array 4 sudut: `wear = [1.0, 1.0, 1.0, 1.0]`, `temps = [90.0, 90.0, 90.0, 90.0]`.
- Rumus degradasi per lap sesuai tabel di [PRD 01 Bab 4.2](file:///D:/Occupation/Porto/genex/La_Voiture/PRD/01-CORE-SIMULATION-ENGINE.md#L97-L105).
- Fungsi `calculate_grip(corner_idx: int) -> float`: menghitung koefisien cengkeraman $\mu_{\text{eff}}$.

### Step 3: Implementasi `scripts/core/fuel_model.gd`
- Variabel `remaining_kg: float = 65.0`.
- Laju bakar $1.8\text{ s.d. } 2.4\text{ kg/lap}$.
- Fungsi `get_weight_penalty_seconds() -> float`:
  ```gdscript
  func get_weight_penalty_seconds() -> float:
      return (remaining_kg / 10.0) * 0.15
  ```

### Step 4: Implementasi `scripts/core/car_state.gd`
- Menyimpan: `car_id`, `team_id`, `driver_name`, `spline_distance`, `current_lane`, `speed_mps`, `lap_number`, `tire_model`, `fuel_model`, `pace_mode`, `engine_mode`.

### Step 5: Implementasi `scripts/core/race_sim_engine.gd`
- Tick $60\text{ Hz}$ ($dt = 0.016667\text{s}$).
- Sub-stepping untuk `time_scale`:
  ```gdscript
  func process_tick(delta: float) -> void:
      var steps: int = int(ceil(time_scale))
      var sub_dt: float = delta / float(steps)
      for i in range(steps):
          _tick_simulation(sub_dt)
  ```
- Perhitungan slipstream ($30\%$ drag drop jika jarak $< 0.8\text{s}$ di trek lurus).
- Pelacak waktu lap dan mini-sektor.

### Step 6: Implementasi `scripts/core/headless_sim_runner.gd`
- Meng-extends `SceneTree`.
- Men-generate sirkuit virtual $5807\text{ meter}$ dan 20 mobil.
- Mensimulasikan 30 lap, memverifikasi konsistensi lap times, dan memastikan determinisme antara kecepatan $1\times$ dan $16\times$.
- Mengeluarkan status `[PASS] ALL SIMULATION ASSERTIONS VERIFIED`.

---

## 4. Perintah Verifikasi & Acceptance Test

```powershell
& "C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" --headless --script scripts/core/headless_sim_runner.gd
```
* **Kriteria Keberhasilan:** Exit code `0`, konsol menampilkan tabel telemetri lengkap 20 mobil dengan delta waktu realistis.
