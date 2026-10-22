# Handoff Blueprint: Fase 3 — Lintasan 3D Ribbon & Kinematic Vehicle Actor
**Target Executor:** 3D Gameplay & Physics Engineer Agent  
**Spesifikasi Acuan:** [PRD/01-CORE-SIMULATION-ENGINE.md](file:///D:/Occupation/Porto/genex/La_Voiture/PRD/01-CORE-SIMULATION-ENGINE.md) & [PRD/00-MASTER-OVERVIEW.md](file:///D:/Occupation/Porto/genex/La_Voiture/PRD/00-MASTER-OVERVIEW.md)  
**Tujuan Akhir:** Membangun sistem lintasan koridor 3 lajur (*Multi-Lane Spline Ribbon*) dan aktor kendaraan 3D (*KinematicCarActor*) yang bergerak mulus di atas spline dengan sensor raycast untuk salip-menyalip, terhubung ke minimap radar 2D di layar Pit Wall.

---

## 1. Copy-Paste Prompt untuk Executor Agent

Salin prompt di bawah ini ke agent eksekutor:

```text
Anda adalah Godot 4 3D Gameplay & Physics Engineer. Tugas Anda adalah mengeksekusi FASE 3 proyek game "La Voiture": Membangun Sistem Lintasan 3D Ribbon dan Aktor Mobil Kinematic dengan Penghindaran Raycast.

Dokumen Acuan Wajib:
- PRD 01: D:/Occupation/Porto/genex/La_Voiture/PRD/01-CORE-SIMULATION-ENGINE.md (Kinematic-Dynamic Ribbon Physics)
- PRD 00: D:/Occupation/Porto/genex/La_Voiture/PRD/00-MASTER-OVERVIEW.md (Arsitektur 3D Viewport)

Lingkungan Eksekusi:
- Godot Engine Path: "C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
- Shell: PowerShell di Windows

Instruksi Eksekusi:
1. Buat scripts/car/track_ribbon.gd berbasis Path3D:
   - Menghasilkan 3 koridor lajur paralel: Inside (Lane 0), Racing Line Optimal (Lane 1), Outside (Lane 2) dengan offset lateral 2.5m.
   - Fungsi get_point_on_ribbon(distance: float, lane: int) -> Transform3D.
   - Fungsi get_curvature_at(distance: float) -> float untuk menghitung radius tikungan.
2. Buat scenes/race_world/track_circuit.tscn memuat Path3D sirkuit uji coba (bentuk loop tertutup ~4000m dengan sektor lurus dan tikungan tajam) beserta mesh jalanan dasar.
3. Buat scenes/race_world/car_actor.tscn dan scripts/car/kinematic_car_actor.gd:
   - Node berbasis Node3D dengan visual placeholder (kotak dimensi 4.6m x 2.0m x 1.2m).
   - 3 RayCast3D sensorik: Sensor Depan (jarak 14m), Sensor Kiri (jarak 3m), Sensor Kanan (jarak 3m).
   - Menginterpolasi posisi sepanjang spline lintasan berdasarkan data spline_distance dari CarState.
   - Logika manuver pindah lajur (lane shifting) halus saat Sensor Depan mendeteksi mobil lain dan kecepatan mobil lebih tinggi.
4. Buat scenes/pit_wall/circuit_radar_2d.tscn:
   - Menggambar kurva lintasan 2D menggunakan Line2D.
   - Memetakan koordinat spline_distance dari 20 mobil menjadi 20 titik lingkaran berdiameter 8px pada radar 2D.
5. Buat scenes/test_race_world.tscn yang memuat lintasan 3D dan meng-instansiasi 20 mobil car_actor.tscn yang melaju bersamaan tanpa tabrakan tembus (tunneling).
6. Verifikasi dengan menjalankan test scene dan pastikan 20 mobil dapat saling menyalip secara mulus pada kecepatan 1x hingga 8x time scale.
```

---

## 2. Rincian File yang Harus Dibuat

```text
D:/Occupation/Porto/genex/La_Voiture/
├── scripts/
│   └── car/
│       ├── track_ribbon.gd
│       └── kinematic_car_actor.gd
├── scenes/
│   ├── race_world/
│   │   ├── track_circuit.tscn
│   │   └── car_actor.tscn
│   ├── pit_wall/
│   │   └── circuit_radar_2d.tscn
│   └── test_race_world.tscn
```

---

## 3. Langkah Implementasi Terinci (Step-by-Step Plan)

### Step 1: Implementasi `track_ribbon.gd`
- Meng-extends `Path3D`.
- Menggunakan kurva `curve: Curve3D` tertutup.
- Menghitung koordinat posisi dan rotasi di sepanjang lintasan:
  ```gdscript
  func get_ribbon_transform(distance: float, lane_index: int) -> Transform3D:
      var baked_pos: Vector3 = curve.sample_baked(distance, true)
      var next_pos: Vector3 = curve.sample_baked(distance + 1.0, true)
      var forward: Vector3 = (next_pos - baked_pos).normalized()
      var up: Vector3 = curve.sample_baked_up_vector(distance, true)
      var right: Vector3 = forward.cross(up).normalized()
      
      # Offset lateral lajur: Lane 0 = -2.5m, Lane 1 = 0.0m, Lane 2 = +2.5m
      var lane_offset: float = (float(lane_index) - 1.0) * 2.5
      var final_pos: Vector3 = baked_pos + (right * lane_offset)
      
      var xform: Transform3D = Transform3D()
      xform.origin = final_pos
      xform.basis = Basis(right, up, forward)
      return xform
  ```

### Step 2: Implementasi `kinematic_car_actor.gd`
- Memiliki referensi `car_id: int` dan `current_lane: int = 1`.
- Memiliki 3 node `RayCast3D` (Front, Left, Right) dengan collision mask ke layer mobil (`collision_layer = 2`).
- Fungsi `sync_with_sim(state: CarState, dt: float, ribbon: TrackRibbon)`:
  - Mengambil target transform dari `ribbon.get_ribbon_transform(state.spline_distance, current_lane)`.
  - Menginterpolasi `global_transform` visual menggunakan `lerp` dan `slerp`.
  - Jika sensor depan aktif dan mobil memiliki keunggulan kecepatan $\Delta V \ge 1.5\text{ m/s}$:
    - Periksa apakah sensor kiri kosong $\rightarrow$ beralih ke `Lane 0`.
    - Jika sensor kiri terhalang tapi sensor kanan kosong $\rightarrow$ beralih ke `Lane 2`.

### Step 3: Implementasi 2D Circuit Radar
- Memetakan panjang sirkuit $L$ ke kurva 2D poligon.
- Setiap frame, baca `spline_distance` dari ke-20 mobil dan gambar titik posisi dengan nomor mobil di kanvas radar.

### Step 4: Uji Coba Multi-Mobil di `test_race_world.tscn`
- Muat lintasan, instansiasi 20 mobil dengan variasi kecepatan, jalankan simulasi, dan verifikasi bahwa mobil saling menyalip tanpa tabrakan berantakan.

---

## 4. Perintah Verifikasi & Acceptance Test

```powershell
& "C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" scenes/test_race_world.tscn
```
* **Kriteria Keberhasilan:** Window Godot menampilkan lintasan 3D dengan 20 mobil yang melaju secara dinamis menyusuri spline, raycast sensor aktif mendeteksi mobil di depan, dan mobil berpindah lajur untuk menyalip secara mulus.
