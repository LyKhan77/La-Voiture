# Rencana Implementasi: Langkah 2 — Setup Garage Weather-Adaptive Tyre Strategy, Critical Mismatch Alert Modal, dan Realistic Tyre Physics Penalty

**Status:** SIAP DIEKSEKUSI  
**Target Engine:** Godot Engine 4.7.2 stable  
**Spesifikasi Desain:** [2026-10-24-langkah-2-garage-tyre-strategy-and-physics-penalty-design.md](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-24-langkah-2-garage-tyre-strategy-and-physics-penalty-design.md)  
**Tanggal:** 2026-10-24  

---

## 1. Rincian Tugas Bertahap (Task Breakdown)

### Task 2.1: Implementasi Logika Rekomendasi Cuaca & Auto-Default Ban
* **File Target:** [`scripts/ui/garage_team_select.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/ui/garage_team_select.gd)
* **Pekerjaan:**
  1. Buat helper method `get_optimal_compound(water_pct: float, preset: int) -> int`:
     - Jika `water_pct >= 40.0` atau preset `FULL MONSOON`: kembalikan `Types.Compound.WET`.
     - Jika `water_pct >= 18.0` atau preset `DYNAMIC WET`: kembalikan `Types.Compound.INTERMEDIATE`.
     - Jika kondisi kering: kembalikan `Types.Compound.MEDIUM`.
  2. Pada `_ready()`:
     - Jika session baru atau cuaca basah ekstrem, auto-default `config.car1_starting_compound` dan `config.car2_starting_compound` ke kompon optimal yang dihitung.
  3. Pada `_refresh_compounds()`:
     - Tambahkan visual badge **`[★ CREW PICK!]`** pada tombol kompon optimal untuk kedua mobil.
     - Perbarui teks telemetri dinamis (menampilkan status `OPTIMAL (100% MATCH)` vs `CRITICAL MISMATCH (HAZARD!)`).

---

### Task 2.2: Implementasi Modal Peringatan Mismatch Kritis (Toon Manga × NFS Unbound)
* **File Target:** [`scripts/ui/garage_team_select.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/ui/garage_team_select.gd)
* **Pekerjaan:**
  1. Buat method `_check_critical_mismatch() -> Dictionary`:
     - Menghitung apakah Car 1 atau Car 2 menggunakan kompon yang berbahaya (Slicks pada Wet/Monsoon, atau Wets pada Sunny Dry).
     - Mengembalikan metadata bahaya (`is_mismatch`, `hazard_type`, `water_pct`, `car1_bad`, `car2_bad`, `recommended_compound`).
  2. Buat konstruksi modal `_build_mismatch_modal()`:
     - Panel modal bergaya *wheatpaste poster* dengan border 6px hitam, drop shadow Hot Magenta `#FF007F` dan Acid Lime `#D8FF00`.
     - Balon kata manga: `「アホか！？」ARE YOU CRAZY?!`.
     - Kotak statistik hukuman: `Cornering: -45% Slow`, `Braking: 3.0x Longer`, `Top Speed: 100% Retained`, `Spin Risk: 500%`.
     - Tombol aksi:
       - **`FORCE OVERRIDE [DEATH WISH]`**: Memanggil `_do_launch()` langsung.
       - **`SLAP WETS ON [CREW REC]`**: Memanggil `_apply_recommended_tyres()` lalu memanggil `_do_launch()`.
       - **`CANCEL [ESC]`**: Menutup modal dan kembali ke garasi.
  3. Modifikasi fungsi `launch()`:
     - Jangan langsung meluncur. Panggil `_check_critical_mismatch()`.
     - Jika mismatch terdeteksi: tampilkan modal peringatan dan tunda peluncuran.
     - Jika tidak ada mismatch: panggil `_do_launch()` secara normal.

---

### Task 2.3: Overhaul Fisika Ban Realistis (Pengereman, Kecepatan Lurus & Tikungan)
* **File Target:** [`scripts/gt/gt_driving.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_driving.gd)
* **Pekerjaan:**
  1. **Dekopling Kecepatan Lurus vs Tikungan:**
     - Pisahkan target kecepatan lurus (`straight_target`) dari batas tikungan (`corner_limit`).
     - Di lintasan lurus (`absf(curv_now) < 0.0035`), mobil pada ban Slick di trek basah TIDAK dipotong oleh `tyre_factor`. Kecepatan lurus tetap tinggi.
     - Di tikungan (`absf(curv_now) >= 0.0035`), batas kecepatan dipotong drastis oleh daya cengkeram lateral ban:
       - Slicks di atas air $\ge 40\%$: kecepatan apex turun $35\% - 45\%$.
  2. **Aquaplane Braking Penalty:**
     - Modifikasi `brake_rate` saat pengereman di lintasan basah dengan ban Slick:
       - Dekelerasi berkurang hingga $65\%$ (jarak pengereman $2.5\times - 3.0\times$ lebih panjang).
  3. **Degradasi Termal & Blistering Ban Wet di Trek Kering:**
     - Pertegas akumulasi suhu pada `car.tyre_temp` jika ban `WET` dipakai di aspal kering ($<12\%$ air), mencapai suhu ekstrem $>130^\circ\text{C}$.
     - Naikkan laju keausan `wear_inc` hingga $5\times - 6\times$, memicu puncture pada lap 2–3.

---

### Task 2.4: Implementasi Snap Oversteer / Solo Spin Risk di Genangan
* **File Target:** [`scripts/gt/gt_contacts.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_contacts.gd) atau [`scripts/gt/gt_driving.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_driving.gd)
* **Pekerjaan:**
  1. Deteksi kondisi batas selip lateral:
     - Jika mobil ban Slick melibas tikungan basah dengan kecepatan $v > \text{corner\_limit} \times 1.10$, terjadi ketidakstabilan rotasi (*snap oversteer*).
     - Aktifkan `car.error_timer = 2.0` dan redam laju sesaat (simulasi melintir dan koreksi kemudi).
     - Picu transmisi radio keluhan pembalap jika belum pernah dipanggil.

---

### Task 2.5: Pembuatan Automated Test Suite Baru
* **File Target:** [`tests/test_garage_tyre_strategy.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/tests/test_garage_tyre_strategy.gd)
* **Pekerjaan:**
  1. Uji logika auto-default cuaca untuk preset `FULL MONSOON`, `DYNAMIC WET`, dan `SUNNY DRY`.
  2. Uji fungsi `_check_critical_mismatch()`:
     - Slick on Monsoon $\rightarrow$ `is_mismatch == true`.
     - Soft vs Med on Dry $\rightarrow$ `is_mismatch == false`.
     - Wet on Dry $\rightarrow$ `is_mismatch == true`.
  3. Uji integrasi modal: aksi `SLAP WETS ON` berhasil menyelaraskan kompon kedua mobil.
  4. Uji simulasi fisika (3 lap headless):
     - Mobil slick di trek lurus basah melaju $>220\text{ km/jam}$.
     - Jarak pengereman slick di trek basah $>2\times$ dibanding ban basah.
     - Ban basah di trek kering mengalami suhu $>125^\circ\text{C}$ dan aus $>4\times$.

---

### Task 2.6: Verifikasi Penuh (Zero Regression & DoD)
* **Pekerjaan:**
  1. Jalankan `godot --headless --path . -s tests/test_garage_tyre_strategy.gd`.
  2. Jalankan seluruh 27 test suites:
     `Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --path . -s "res://tests/$($_.Name)" }`
  3. Pastikan **100% PASS, 0 FAIL**.
  4. Tulis laporan verifikasi FASE-11 Langkah 2.