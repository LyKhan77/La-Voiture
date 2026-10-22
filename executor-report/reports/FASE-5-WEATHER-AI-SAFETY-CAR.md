# LAPORAN EKSEKUTIF FASE 5: WEATHER DYNAMICS, AI RIVAL STRATEGIST & SAFETY CAR

**Status:** SELESAI & TERVERIFIKASI (43/43 assertion `test_weather_and_ai.gd` PASS, seluruh suite lama PASS tanpa regresi, shader divalidasi di Godot 4.7.2 Forward+ pada GPU nyata)  
**Task:** `prompt/TASK-FASE-5-WEATHER-AI-STRATEGY.md`


## 0. Ringkasan

Fase 5 menambahkan cuaca dinamis, strategi AI 18 mobil rival, Safety Car, visual aspal basah + hujan manga 3D, dan widget cuaca di Pit Wall. Semua 20 butir akseptansi lulus (43 assertion, 0 failure) tanpa regresi di `test_simulation_verification`, `test_modular_car`, `test_pit_wall`, `test_race_world`.

| Area | Hasil |
|---|---|
| Cuaca | 4 state, air per-lajur, racing line kering 2x lebih cepat, suhu 25 → 17 °C, prakiraan 5 lap, radio callout 35% dan "TRACK IS FLOODING" |
| AI rival | 18 mobil / 9 tim: crossover WET (>0.35 mm) dan slick (<0.18 mm) dengan histeresis, tire cliff <22%, undercut <1.8 s, mode mesin PUSH/ECO, bensin; pit lane melayani semua `box_requested` |
| Safety Car | Pemicu badai >2.8 mm, insiden, mobil mogok; `YELLOW_FLAG`, batas 120 km/jam, barisan merapat ke 14 m, 0 penyalipan, stop murah (4.2 s vs 16.5 s) |
| Visual | Shader aspal (roughness 0.85 → 0.15, puddle, riak hujan 4 frame), hujan manga 3D (`GPUParticles3D`, streak mengikuti kecepatan kamera), spray mobil, SSR |
| Pit Wall | Widget cuaca (status, bar kebasahan, prakiraan), flag `YELLOW FLAG // SAFETY CAR`, radio cut-in |

Cara menjalankan: tes `godot --headless -s tests/test_weather_and_ai.gd`; visual `scenes/test_weather_world.tscn` (F6, tombol `5` = 16x) dan `scenes/pit_wall/pit_wall_dashboard.tscn`.

Tidak ada pekerjaan wajib tersisa. Keputusan terbuka untuk pemilik proyek: (1) Safety Car bertahan ±6 lap saat badai (konstanta di `safety_car_director.gd`), (2) angka partikel hujan masih tuning visual, (3) pit lane belum punya visual 3D.

---

## 1. Rangkuman Implementasi

### File baru

| File | Peran |
|---|---|
| `scripts/core/weather_manager.gd` | State machine `DRY / LIGHT_DRIZZLE / HEAVY_DOWNPOUR / DRYING`, air per-lajur (3 lajur), penguapan, suhu udara, jadwal + prakiraan 5 lap, radio callout |
| `scripts/core/ai_race_director.gd` | Pohon keputusan 18 mobil rival + pit lane yang melayani semua `box_requested` |
| `scripts/core/safety_car_director.gd` | Safety Car virtual: `YELLOW_FLAG`, batas 120 km/jam, kompresi barisan, larangan menyalip |
| `scripts/core/race_control.gd` | Penggerak per-tick: menjalankan Weather → Safety Car → AI setelah setiap tick engine |
| `scripts/ui/race_control_session.gd` | `PitWallSession` + RaceControl (radio ke pit wall) |
| `scripts/ui/weather_radar_widget.gd` | Widget mini-radar cuaca di ribbon Pit Wall |
| `assets/shaders/track_ribbon.gdshader` | Aspal basah (roughness 0.85 → 0.15, puddle noise, specular) |
| `assets/shaders/manga_rain_streaks.gdshader` + `scripts/vfx/manga_rain_3d.gd` + `scenes/vfx/manga_rain_3d.tscn` | Hujan manga 3D: partikel dunia (`GPUParticles3D`), streak diregangkan searah kecepatan relatif terhadap kamera, outline tinta + aksen cyan |
| `assets/shaders/manga_spray_puff.gdshader` + `scripts/vfx/manga_road_spray.gd` | Cipratan air di belakang mobil: gumpalan cel-shaded beroutline tinta, animasi 4 frame |
| `scripts/car/weather_race_world.gd` + `scenes/test_weather_world.tscn` | Dunia 3D 20 mobil + cuaca/SC/AI + shader aspal (riak hujan 4 frame) + hujan 3D + spray + langit mendung + SSR |
| `tests/test_weather_and_ai.gd` | Suite akseptansi (43 assertion) |
| `scratch/capture_phase5_wet_track.gd`, `scratch/capture_phase5_dashboard.gd` | Skrip tangkap layar |

### File lama yang diubah

Hanya `scripts/ui/pit_wall_dashboard.gd` (disebut eksplisit di task): `Session` kini `RaceControlSession`, label cuaca diganti `WeatherRadarWidget`, flag ribbon menampilkan `YELLOW FLAG // SAFETY CAR`. Core sim (`race_sim_engine.gd`, `car_state.gd`, `tire_model.gd`, `fuel_model.gd`), `traffic_race_sim.gd`, `pit_wall_session.gd`, dan `test_race_world.gd` **tidak disentuh** (aturan AGENTS.md: jangan edit file yang bukan buatan sendiri).

### Keputusan arsitektur

- **Engine tidak punya hook per-tick**, dan core tidak boleh diubah. `RaceControl` memegang loop stepping sendiri (`process_frame()` / `step_ticks()`): akumulator integer fixed-point sama persis dengan engine, lalu `engine.step_ticks(1)` dan direktur dijalankan setelah tiap tick. Hasil: 1x dan 16x tetap menjalankan urutan tick yang identik. Bekerja di engine dasar (pit wall) maupun `TrafficRaceSim` (dunia 3D).
- **Weather → engine** tiap tick: `engine.set_weather_wetness(weather_wetness_mm)` + `set_ambient_temp()`, lalu `car.tire.track_wetness_mm` dioverride per mobil dari air di lajurnya (lajur racing line lebih kering saat dilewati mobil).
- **Safety Car** bekerja dengan membatasi `car.speed_mps` setelah tiap tick (turun bertahap 30 m/s²). Pemimpin dipacu 90 km/jam (0.75 × 120), pengikut boleh sampai 120 km/jam untuk merapat ke jarak 14 m, tidak pernah di bawah 7 m. Mobil di pit lane tidak terkena batas SC.
- **Pit lane** (di `AIRaceDirector`): mobil dengan `box_requested` masuk saat melewati garis start, lintas 500 m pada 80 km/jam, berhenti 2.8 s di tengah, ganti ban (`TireModel` baru) + isi bensin penuh, lalu keluar. "Cheap pit stop" muncul dari fisika: biaya waktu relatif terhadap rombongan = `estimate_pit_loss_s(pack_speed)`.

### Interpretasi spesifikasi yang perlu diketahui

1. Spec menyebut `PaceMode.PUSH` / `PaceMode.ECO`; `PaceMode` hanya punya `CONSERVE / STANDARD / ATTACK`. Dipetakan ke `EngineMode.PUSH / ECO` (+ `PaceMode.ATTACK` saat mengejar, `CONSERVE` saat ban > 105 °C karena hanya pace mode yang mendinginkan ban; histeresis turun di 98 °C).
2. Spec menyebut `car.next_compound`; `CarState` tidak punya field itu dan tidak diubah. Disimpan di direktur: `ai.get_next_compound(car)`.
3. "Wetness 35%" = 0.35 mm (1.0 mm = 100%, sesuai skala model ban).
4. Aturan tambahan di luar spec (agar simulasi tidak rusak): AI pit bila bensin < 5 kg (tanpa ini mobil rival kehabisan bensin di lap ~32 pada balapan 50 lap); stop opsional (undercut / SC) ditahan di jendela crossover cuaca 0.18-0.6 mm supaya tidak membeli ban yang segera salah; mobil mogok kehabisan bensin otomatis dilaporkan sebagai insiden → Safety Car.
5. Mobil 0 dan 1 (tim pemain) tidak diatur AI; hanya pit lane yang melayani tombol BOX mereka (sebelumnya `box_requested` tidak pernah dikonsumsi siapa pun).
6. Balapan demo di Pit Wall kini punya front cuaca (`RaceControl.DEMO_SCHEDULE`): kering → gerimis (lap 4) → hujan deras (lap 7) → mengering (lap 11).

---

## 2. Hasil Pengujian

Perintah:

```powershell
& "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless -s tests/test_weather_and_ai.gd
```

Capture terminal (`43 assertions, 0 failure(s)`):

```text
[PASS] #1 WeatherManager starts DRY at 0.0 mm
[PASS] #2 drizzle accumulates track water gradually at 0.005 mm/s ([0.15, 0.3, 0.45] mm per 30 s)
[PASS] #3 downpour passes 1.0 mm in a minute (1.50 mm) and saturates at 3.5 mm
[PASS] #4 DRYING returns the track to 0.0 mm and the state to DRY (1167 s)
[PASS] #5 racing line dries 2x faster with traffic (0.40 mm vs 0.70 outer, 0.70 untrafficked)
[PASS] #6 ambient temperature falls 25 -> 17 C in a downpour (17.0 C)
[PASS] radio: crossing 35% wetness calls out exactly once ('TRACK WETNESS EXCEEDING 35% — BOX FOR WETS!')
[PASS] radio: entering HEAVY_DOWNPOUR calls 'BOX THIS LAP — TRACK IS FLOODING!'
[PASS] 5-lap forecast reads 'L+3: DRIZZLE | L+5: HEAVY RAIN' from the schedule
[PASS] #8 slick loses grip once wetness > 0.35 mm (1.094 -> 0.976)
[PASS] #11 WET compound out-grips slick on wet asphalt at 0.6, 1.0 and 2.0 mm (1.10 vs 1.03, 1.20 vs 0.88, 1.20 vs 0.56)
[PASS] #7 AI Race Director sees 18 rival cars from 9 teams, none of them the player's
[PASS] #9 slick car boxes for WET when wetness passes 0.35 mm (reason WEATHER_WET)
[PASS] wet car stays out while the track is still wet
[PASS] hysteresis: at 0.25 mm neither slicks nor wets pit (window is 0.18-0.35 mm)
[PASS] #12 wet car boxes for MEDIUM/HARD once wetness < 0.18 mm (took HARD)
[PASS] #13 AI undercuts only inside 1.8 s of a worn (<45%) car, and pushes while it chases (far '', fresh '', now 'UNDERCUT')
[PASS] #14 AI boxes when average tire wear drops under 22% (23% stays out, 20% boxes)
[PASS] engine mode: tires over 105 C drop to ECO, hold it until under 98 C, then return to STANDARD
[PASS] low fuel (< 5 kg) boxes the car
[PASS] undercut waits out the weather crossover (0.4 mm -> '', 0.8 mm -> 'UNDERCUT')
[PASS] #10 all 18 rivals are on WET tires after a drizzle crossover, 18 stops served, player cars left alone
[PASS] #15 safety car deploys in an extreme storm (> 2.8 mm): YELLOW_FLAG, overtaking disabled
[PASS] safety car comes in after its minimum 120 s once the storm has cleared
[PASS] a race incident deploys the safety car too
[PASS] a car stranded out of fuel is reported and brings the safety car out
[PASS] control: without the safety car the faster tail car passes (3660 order changes) and tops 328 km/h
[PASS] #16 every car obeys 120 km/h under the safety car (255.5 km/h before, 120.0 km/h peak after settling)
[PASS] #17 nobody overtakes under the yellow flag (0 order changes in 90 s)
[PASS] #18 pack compresses behind the safety car (854 m -> 143 m long, closest gap 13.8 m)
[PASS] safety car pit stop is cheap: 4.2 s lost vs 16.5 s under green
[PASS] AI takes the cheap stop for worn (<60%) tires while the safety car is out
[PASS] #19 track_ribbon shader exposes track_wetness (0..1) and the material accepts it
[PASS] #19 shader drives ROUGHNESS from 0.85 (dry) to 0.15 (wet) with puddle noise and rain ripples
[PASS] 3D world: the ribbon road uses the wet-track shader material
[PASS] 3D world: heavy rain drives track_wetness (0.00 -> 1.00), road ripples and the rain particles
[PASS] 3D rain is world-space GPUParticles3D (no 2D overlay): 2600 drops at ratio 1.00
[PASS] 3D rain tracks the camera velocity (162 m/s) and 20 cars throw road spray
[PASS] 3D world: rain stops when the weather clears
[PASS] pit wall ribbon shows the weather status icons (now '🌧️ RAIN (WET 42%)  25°C')
[PASS] pit wall radio carries 'TRACK WETNESS EXCEEDING 35% — BOX FOR WETS!' and the flooding call
[PASS] pit wall flag turns YELLOW FLAG // SAFETY CAR and radio announces the deployment
[PASS] #20 earlier suites still pass with no regression: test_simulation_verification=PASS, test_modular_car=PASS, test_pit_wall=PASS, test_race_world=PASS
43 assertions, 0 failure(s)
FASE 5 ACCEPTANCE: PASS
```

Pemetaan ke daftar akseptansi: #1-#6 cuaca, #7 18 rival, #8/#11 grip, #9/#10/#12/#13/#14 keputusan AI, #15-#18 Safety Car, #19 shader, #20 regresi. Assertion `control:` membuktikan skenario #17 memang bisa mendeteksi penyalipan (tanpa SC mobil ekor yang lebih cepat menyalip; dengan SC 0 perubahan urutan).

### Regresi (#20)

| Suite | Hasil |
|---|---|
| `tests/test_simulation_verification.gd` | PASS |
| `tests/test_modular_car.gd` | PASS |
| `tests/test_pit_wall.gd` | PASS |
| `tests/test_race_world.gd` (`--fixed-fps 60`) | PASS (`ALL PASS (0 failure(s))`, 65 assertion; dijalankan ulang setelah hujan 3D) |

Tiga suite pertama dijalankan otomatis di dalam #20. `test_race_world` opt-in (total run ±1 menit): `... -s tests/test_weather_and_ai.gd -- --with-race-world`. Run penuh terakhir: 4 suite PASS, 43 assertion, 0 failure, tanpa ERROR/WARNING di log.

### Soak test (tidak masuk suite)

Balapan 50 lap penuh dengan front cuaca demo, 20 mobil, ±4000 detik sim: gerimis memicu 18 rival ke WET (radio 35% di t=490 s), hujan deras memicu Safety Car (t=784 s, bubar t=1430 s), saat mengering 18 rival kembali ke slick, tanpa mobil macet di pit. Kecepatan: ±3900 tick/detik headless (butuh 960 untuk 16x).

---

## 3. Screenshot

- Hujan deras 3D + aspal basah + riak + spray + pantulan mobil (SSR): `scratch/phase-5-wet-track.png`
- Gerimis (partikel lebih jarang, riak lebih sedikit): `scratch/phase-5-drizzle-track.png`
- Pembanding kering (kamera sama): `scratch/phase-5-dry-track.png`
- Widget cuaca di ribbon Pit Wall + radio cut-in: `scratch/phase-5-dashboard.png`

![wet](../scratch/phase-5-wet-track.png)
![drizzle](../scratch/phase-5-drizzle-track.png)
![dry](../scratch/phase-5-dry-track.png)
![dashboard](../scratch/phase-5-dashboard.png)

---

## 4. Batasan & Risiko

- Hujan 3D bergantung pada kecepatan kamera (streak = kecepatan relatif x 0.045 s, maks 3.5 m): saat kamera diam hujan vertikal biasa, saat ngebut/16x streak memanjang dan memancar dari titik hilang. Spray mobil yang diikuti kamera dikurangi 70% agar tidak menutupi layar. Angka jumlah/lebar partikel ada di `manga_rain_3d.gd` dan uniform shader.
- Tidak ada animasi/visual pit lane 3D: mobil di pit lane hanya melambat/berhenti di posisi sim (aktor 3D mengikuti sim).
- Emoji ikon cuaca (`☀️ 🌦️ 🌧️ 🌤️`) dirender lewat font fallback sistem, bukan font tema; tampil kecil di ribbon.
- Safety Car bertahan ≥ 120 s dan menunggu air < 2.4 mm; dengan penguapan 0.003 mm/s dari 3.5 mm itu ±6 lap. Konstanta ada di atas `safety_car_director.gd` bila ingin diperpendek.
- Semua angka gameplay berupa `const` di skrip (mengikuti konvensi core); belum dipindah ke file data.
- `class_name` baru perlu cache class: jalankan `godot --headless --path . --import` sekali pada checkout baru.
