# Executor Report — Fase 1: Inisialisasi Godot 4 & Core Simulation Math Engine

**Tanggal:** 20 Oktober 2026
**Status:** Selesai — verifikasi exit code 0
**Engine:** Godot 4.7.2 stable
**Acuan:** PRD 01, PRD 07, ROADMAP.md, Handoff Fase 1

---

## 1. Ringkasan Eksekusi

Fase 1 membangun fondasi proyek Godot 4 dan mesin simulasi balap deterministik berbasis tick 60 Hz. Tidak ada viewport 3D yang dimuat saat pengujian; seluruh verifikasi berjalan headless.

Cakupan yang selesai:

- Inisialisasi `project.godot` (1920×1080, Forward+, target 60 FPS, physics 60 Hz).
- Struktur direktori proyek.
- Model ban 4 sudut, bahan bakar, state telemetri mobil.
- Engine simulasi deterministik dengan sub-stepping 1×–16×, slipstream, dirty air, dan mini-sektor.
- Headless runner 30 lap × 20 mobil.
- Test verifikasi model terfokus.

---

## 2. File yang Dibuat / Diubah

| File | Status | Isi |
|---|---|---|
| `project.godot` | Diubah (aditif) | Resolusi 1920×1080, `forward_plus`, `run/max_fps=60`, physics 60 Hz. Autoload dan editor plugin lama dipertahankan. |
| `scripts/core/tire_model.gd` | Baru | Compound Soft/Medium/Hard/Wet, wear + suhu independen FL/FR/RL/RR. |
| `scripts/core/fuel_model.gd` | Baru | Konsumsi kg, weight penalty `0.15 s/10 kg`, mode ECO/STANDARD/PUSH. |
| `scripts/core/car_state.gd` | Baru | State telemetri, spline distance, speed, lane, timing lap/sektor/mini-sektor. |
| `scripts/core/race_sim_engine.gd` | Baru | Tick 60 Hz deterministik, sub-stepping, traffic, timing tower. |
| `scripts/core/headless_sim_runner.gd` | Baru | Balapan 30 lap, 20 mobil, tanpa grafis + assertion. |
| `tests/test_simulation_verification.gd` | Baru | Verifikasi model ban, fuel, aero, compound A/B, mini-sektor, determinisme singkat. |
| `scripts/car/`, `scripts/ui/`, `shaders/`, `assets/`, `tests/` | Dibuat | Struktur folder sesuai instruksi. |

Tidak ada file lama yang dihapus. `scenes/main.tscn`, `addons/`, `docs/`, dan dokumen PRD tidak disentuh.

---

## 3. Implementasi Teknis

### 3.1 `project.godot`

```ini
[application]
run/max_fps=60

[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=0

[physics]
common/physics_ticks_per_second=60

[rendering]
renderer/rendering_method="forward_plus"
renderer/rendering_method.mobile="mobile"
```

### 3.2 Model Ban — `tire_model.gd`

- Enum `Compound { SOFT, MEDIUM, HARD, WET }` dan `Corner { FL, FR, RL, RR }`.
- Data mengikuti PRD 01 §4.2:

| Compound | Base grip | Wear/lap | Suhu optimal | Cliff |
|---|---|---|---|---|
| Soft | 1.25 | 4.25% | 102.5 °C | 25% |
| Medium | 1.15 | 2.50% | 92.5 °C | 20% |
| Hard | 1.05 | 1.40% | 87.5 °C | 15% |
| Wet | 0.95 kering / 1.20 basah | 8% kering / 1.5% basah | 67.5 °C | 20% |

- Wear disimpan sebagai kondisi tersisa (`1.0` baru, `0.0` habis).
- Grip efektif = base grip × faktor wear × faktor suhu × faktor wetness.
- Tikungan kanan membebani ban kiri (FL/RL); tikungan kiri membebani ban kanan (FR/RR).
- Beban longitudinal: pengereman menambah panas/wear depan; akselerasi menambah panas/wear belakang.
- Suhu permukaan dan suhu dalam (inner) diintegrasikan terpisah.
- Dirty air menaikkan heat input 12%.
- Cliff penalty hingga 2.5 s/lap diterapkan sebagai pengurangan target speed.
- Rata-rata wear/suhu di-cache untuk jalur panas engine; update termal engine berjalan 20 Hz (setiap 3 tick) agar biaya CPU turun tanpa mengubah determinisme tick.

### 3.3 Model Bahan Bakar — `fuel_model.gd`

- Kapasitas awal 65 kg; konsumsi referensi 2.0 kg/lap.
- Laju bakar per detik dipengaruhi throttle input dan mode mesin:
  - ECO ×0.85
  - STANDARD ×1.0
  - PUSH ×1.15
- Weight penalty:
  ```gdscript
  (remaining_kg / 10.0) * 0.15
  ```
  Contoh: 65 kg → 0.975 s; +10 kg → +0.15 s.
- Massa bahan bakar masuk ke fisika melalui `mass = DRY_MASS_KG + remaining_kg`, sehingga akselerasi dan pengereman terpengaruh.

### 3.4 State Mobil — `car_state.gd`

Menyimpan antara lain:

- `car_id`, `team_id`, `driver_name`, `driver_skill`
- `spline_distance`, `total_distance`, `segment_index`
- `speed_mps`, `lap_number`, `laps_completed`
- `current_lane`, `lane_target`, `lane_position`, `lane_offset_m`
- `tire_compound`, `tire_wear`, `tire_temps` (proxy ke model ban)
- `fuel_remaining_kg`, `ers_battery_pct`
- `pace_mode`, `engine_mode`
- `last_lap_time`, `best_lap_time`, `lap_times`
- `sector_times`, `mini_sector_times`, `mini_sector_best`, `mini_sector_deltas`
- Status traffic: gap, slipstream, dirty air, target lane.
- `get_telemetry()` untuk kebutuhan UI/timing tower.

### 3.5 Engine Simulasi — `race_sim_engine.gd`

- Tick tetap `1/60 s`, terpisah dari frame render.
- `process_frame(delta)` memakai akumulator fixed-point integer 1e9 untuk mencegah drift; `time_scale` 1×–16× mengeksekusi beberapa tick per frame.
- Trek virtual 5807 m, 16 segmen (straight + corner radius), 3 lajur, 12 mini-sektor (3 sektor × 4).
- Fisika point-mass:
  - Downforce dan drag dari kecepatan.
  - Corner speed limit memakai formula grip + downforce PRD.
  - Braking lookahead 3 segmen, maksimum 500 m.
  - Massa mobil = dry mass + fuel.
  - Traksi, power-limited acceleration, drag deceleration.
- Slipstream: gap < 0.8 s di trek lurus → drag ×0.70.
- Dirty air: gap < 1.0 s di tikungan → downforce ×0.82 dan heat ban ×1.12.
- AI lane:
  - Deteksi mobil di depan <12 m.
  - Pindah lajur jika delta speed >5 km/jam dan lajur target kosong.
  - Kembali ke racing line saat gap >30 m.
  - Lane change halus dengan batas 1.4 lane/detik.
  - Lift/follow cap untuk mencegah tabrakan.
- Timing:
  - Lap time dihitung saat melewati garis start/finish.
  - Mini-sektor mencatat split time, delta terhadap session best, status PURPLE/GREEN/WHITE.
  - `get_standings()` menghasilkan klasifikasi live dengan gap dan interval.
  - Sinyal `lap_completed` dan `race_finished`.

### 3.6 Headless Runner — `headless_sim_runner.gd`

- Membuat 10 tim × 2 mobil = 20 mobil.
- Compound grid: 7 Soft, 7 Medium, 6 Hard.
- Grid stagger 10 m, lajur bergantian.
- Menjalankan 30 lap tanpa grafis.
- Menjalankan dua simulasi identik:
  - `time_scale = 1.0`
  - `time_scale = 16.0`
- Membandingkan secara bit-identik:
  - Jumlah tick
  - Race time
  - Urutan finis
  - 600 lap time
  - Finish time
  - Wear 4 sudut
  - Fuel
  - Total distance
- Menjalankan A/B Soft vs Hard dengan mobil identik (single car, lap 2).
- Menampilkan timing tower, mini-sector delta, wear/suhu 4 sudut, dan waktu eksekusi.
- Exit code 0 jika semua assertion lulus, 1 jika ada kegagalan.

---

## 4. Verifikasi

### 4.1 Perintah Utama

```powershell
& "C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" --headless --script scripts/core/headless_sim_runner.gd
```

**Exit code: 0**

### 4.2 Hasil Assertion

| Verifikasi | Hasil |
|---|---|
| Soft vs Hard, lap 2, mobil identik | Soft **1:50.550**, Hard **1:51.533** |
| Delta Soft–Hard | **+0.983 s/lap** (di dalam target PRD 0.8–1.4 s) |
| Balapan 30 lap × 20 mobil | **20/20 finis**, masing-masing 30 lap tercatat |
| Determinisme 1× vs 16× | **202.689 tick identik** |
| Klasifikasi finis 1× vs 16× | Identik |
| 600 lap time | Bit-identik |
| Wear 4 sudut | Bit-identik |
| Fuel mass | Bit-identik |
| Total distance | Bit-identik |
| Mini-sektor | 12 split per lap; jumlah split = lap time |
| Assertion akhir | `[PASS] ALL SIMULATION ASSERTIONS VERIFIED` |

### 4.3 Hasil Balapan 30 Lap

- Sesi best lap: **1:49.733**.
- Pemenang: **G. Alves (Static Speed, Hard)** — 55:45.183.
- Mobil Hard/Medium mendominasi klasifikasi.
- Mobil Soft turun ke posisi 14–20 dengan gap ±32.8–33.0 s karena kondisi ban mendekati 0% dan terkena cliff penalty.
- Contoh wear 4 sudut pemimpin: FL 65.6%, FR 65.0%, RL 65.6%, RR 65.0% (kondisi tersisa).
- Contoh suhu 4 sudut pemimpin: FL 70.6 °C, FR 73.1 °C, RL 71.9 °C, RR 74.4 °C.
- Sisa fuel: Hard/Medium ±2.7 kg; Soft ±2.1 kg.

### 4.4 Test Model Terfokus

```powershell
& "C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --script tests/test_simulation_verification.gd
```

**Exit code: 0** — seluruh assertion model lulus, termasuk:

- Ban kanan-kiri aus sesuai arah tikungan.
- Ban memanas saat cornering dan mendingin di lurus.
- Soft > Hard untuk grip; Wet > slick di hujan.
- 65 kg = 0.975 s; +10 kg = +0.15 s.
- ECO < STANDARD < PUSH untuk konsumsi fuel.
- Slipstream 0.70 dan dirty air 0.82 sesuai threshold.
- 12 mini-sektor dan 3 sektor menjumlah ke lap time.
- Determinisme singkat 1× vs 16×.

---

## 5. Catatan Performa

| Metrik | Terukur |
|---|---|
| Durasi simulasi balapan 30 lap | ±3.378 s waktu simulasi |
| Wall time 30 lap, 20 mobil (1×) | ±111 s |
| Wall time 30 lap, 20 mobil (16×) | ±119 s |
| Total wall time runner (dua simulasi + A/B) | ±230 s |
| Realtime factor simulasi | ±28× |

`time_scale` 16× mengurangi jumlah pemanggilan `process_frame`, tetapi tidak mengurangi jumlah tick matematika. Karena itu wall time 1× dan 16× hampir sama; yang dijamin identik adalah hasil tick-nya.

**Gap terhadap PRD 07 (QA-01):** target ≤3 s per balapan 50 lap belum terpenuhi oleh implementasi full-fidelity GDScript 60 Hz ini. Untuk Monte Carlo massal diperlukan salah satu dari:

1. Implementasi engine matematika di C#/GDExtension.
2. Mode balance reduced-fidelity terpisah yang tidak mensimulasikan setiap tick 60 Hz.
3. Paralelisasi per mobil dengan barrier deterministik.

Engine gameplay 60 Hz saat ini sudah memenuhi kebutuhan determinisme Fase 1 dan siap dipakai untuk integrasi UI/3D pada fase berikutnya.

---

## 6. Batasan Fase 1

- Belum ada rendering, viewport 3D, atau track mesh; trek direpresentasikan sebagai segmen matematika 5807 m.
- Belum ada pit stop, safety car, weather dinamis, atau DNF.
- AI masih deterministik berbasis lane/lift; belum memiliki strategi undercut/overcut.
- Belum ada file `weather_system.gd` dan `ai_race_director.gd` penuh; wetness dan AI dasar sudah diintegrasikan di engine.
- Headless runner memverifikasi determinisme penuh 30 lap, tetapi biaya wall time masih tinggi untuk Monte Carlo.

---

## 7. Kesimpulan

Fase 1 selesai. Seluruh acceptance criteria eksplisit terpenuhi:

- `project.godot` dan struktur folder siap.
- Model ban 4 sudut, fuel, dan state telemetri terimplementasi.
- Engine 60 Hz deterministik dengan sub-stepping 1×–16×, slipstream, dirty air, dan mini-sektor.
- Headless runner 30 lap × 20 mobil berjalan tanpa grafis.
- Perintah verifikasi persis mengembalikan **exit code 0** dan **seluruh assertion lulus**.
- Soft lebih cepat dari Hard (**+0.983 s/lap**) dan hasil 1× vs 16× identik.
