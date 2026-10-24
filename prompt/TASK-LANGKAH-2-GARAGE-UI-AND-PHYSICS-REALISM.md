# TASK HANDOFF: Langkah 2 — Rebuild UI/UX Garasi (Toon Manga × NFS Unbound) & Realistic Tyre Physics Overhaul

**Target Branch:** `main`  
**Target Engine:** Godot Engine 4.7.2 stable (`Godot_v4.7.2-stable_win64_console.exe`)  
**Role:** Senior UI/UX Designer & Motorsport Simulation / Vehicle Dynamics Engineer  
**Reference Documents:**
* **Spesifikasi Desain:** [`docs/superpowers/specs/2026-10-24-langkah-2-garage-tyre-strategy-and-physics-penalty-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-24-langkah-2-garage-tyre-strategy-and-physics-penalty-design.md)
* **Rencana Implementasi:** [`docs/superpowers/plans/2026-10-24-langkah-2-garage-tyre-strategy-and-physics-penalty-plan.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/plans/2026-10-24-langkah-2-garage-tyre-strategy-and-physics-penalty-plan.md)
* **Approved Concept Interactive HTML:** [`temp/concepts/ui_toon_manga_nfs_unbound.html`](file:///D:/Occupation/Porto/genex/La_Voiture/temp/concepts/ui_toon_manga_nfs_unbound.html)
* **Approved Visual Concept PNGs (Wajib Dijadikan Acuan Visual):**
  * Area 01 (Garage & Tyre Bay): [`temp/concepts/concept_01_garage_tyre_bay.png`](file:///D:/Occupation/Porto/genex/La_Voiture/temp/concepts/concept_01_garage_tyre_bay.png)
  * Area 02 (HUD Tactical Deck): [`temp/concepts/concept_02_hud_tactical_deck.png`](file:///D:/Occupation/Porto/genex/La_Voiture/temp/concepts/concept_02_hud_tactical_deck.png)
  * Area 03 (Critical Mismatch Modal): [`temp/concepts/concept_03_critical_mismatch_poster.png`](file:///D:/Occupation/Porto/genex/La_Voiture/temp/concepts/concept_03_critical_mismatch_poster.png)
* **Pedoman Resmi Arsitektur & Rules:** [`AGENTS.md`](file:///D:/Occupation/Porto/genex/La_Voiture/AGENTS.md)

---

## 1. Context & Catatan Kritis Pengguna (Must-Read)

Pengguna secara spesifik telah menyetujui arah visual **Toon Manga × Need for Speed Unbound × Street Graffiti** yang dimodelkan pada `temp/concepts/ui_toon_manga_nfs_unbound.html`. 

> [!IMPORTANT]
> **CATATAN KRITIS:**
> Implementasi prototype awal di Godot sebelumnya sempat ditolak oleh pengguna karena *"literally berbeda dari konsep yang diusulkan"*. Hal ini terjadi karena kode lama hanya menempelkan label teks biasa di atas panel kotak datar Fase 9. Pengguna menginginkan antarmuka di dalam game benar-benar memiliki jiwa visual seperti pada konsep yang disetujui (kemiringan pelat $-12^\circ$, 2D graffiti wings spray di belakang mobil, mahkota doodle 👑 di atas kepala driver, kartu manga pop-out, tombol kaleng semprot, dan poster bahaya wheatpaste).

---

## 2. Instruksi Wajib Sebelum Eksekusi (Preview HTML First)

Sebelum Anda mulai mengubah atau mengeksekusi kode engine, Anda **WAJIB**:
1. Mempelajari dengan seksama ketiga berkas visual di `temp/concepts/`:
   * [`temp/concepts/concept_01_garage_tyre_bay.png`](file:///D:/Occupation/Porto/genex/La_Voiture/temp/concepts/concept_01_garage_tyre_bay.png)
   * [`temp/concepts/concept_03_critical_mismatch_poster.png`](file:///D:/Occupation/Porto/genex/La_Voiture/temp/concepts/concept_03_critical_mismatch_poster.png)
2. **Berikan preview visual dalam bentuk HTML / companion preview** kepada pengguna yang menjelaskan bagaimana Anda akan memetakan dan menyusun node-node Godot (`Control`, `Panel`, `StyleBoxFlat`, `TextureRect`, skew transform/shader) agar hasilnya di dalam game **100% presisi dan identik** dengan konsep yang disetujui, sehingga pengguna dapat membayangkan hasil aslinya secara jelas sebelum kode dieksekusi.

---

## 3. Rincian Ruang Lingkup Tugas (Scope of Work)

### Bagian A: Perombakan Total UI/UX Garasi & Modal Mismatch Kritis
* **Target Files:** [`scenes/ui/garage_team_select.tscn`](file:///D:/Occupation/Porto/genex/La_Voiture/scenes/ui/garage_team_select.tscn) & [`scripts/ui/garage_team_select.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/ui/garage_team_select.gd)
1. **Panggung Mobil 3D & Efek Grafiti 2D:**
   - Tambahkan layer grafiti vektor 2D (Sayap Semprotan Grafiti / Spray Wings bergradien Hot Magenta `#FF007F` dan Acid Lime `#D8FF00`) di belakang sasis mobil.
   - Berikan efek suara manga `「轟音」ROOOAR!` serta lakban bening (*duct tape*) di sudut-sudut pelat sasis.
2. **Kartu Pembalap Pop-Out Manga:**
   - Bingkai potret pembalap pop-out dengan **Mahkota Grafiti Kuning 👑** di atas helm/kepala pembalap.
   - Stempel kanji manga `「疾風」` untuk Kaze Ryu, stiker jalanan bertumpuk (*slap sticker*) dengan sudut terkelupas (*peeling corner*).
   - Indikator ban terpasang: `STARTING TYRE // WET [★ CREW PICK]` jika optimal, atau `[CRITICAL HAZARD!]` jika salah kompon.
3. **Selektor Kompon Ban (Spray Can Buttons):**
   - 5 tombol kompon kaleng semprot miring: Soft (`#FF007F`), Medium (`#FFD400`), Hard (`#FFFFFF`), Inter (`#00F5D4`), Wet (`#D8FF00`).
   - Kompon rekomendasi cuaca otomatis memiliki badge meletup **`★ CREW PICK!`** berwarna Hot Magenta.
   - Kotak telemetri dinamis yang menampilkan kompatibilitas: `OPTIMAL (100% MATCH)` vs `CRITICAL MISMATCH (HAZARD!)`.
   - Tombol peluncuran besar: `LAUNCH TO GRID /// 限界突破`.
4. **Critical Strategy Override Modal (Wheatpaste Poster Liar):**
   - Mencegat tombol `LAUNCH TO GRID` jika mobil tim pemain memakai Slick di trek basah/Monsoon, atau Wet di trek kering (Opsi 2 & Opsi A).
   - Modal tampil sebagai poster *wheatpaste* bertekstur kertas putih, border tinta tebal 6px hitam, drop shadow Hot Magenta `#FF007F`, lakban di sudutnya, dan balon kata manga: `ARE YOU CRAZY?! // WARNING`.
   - Matriks penalti konkret: Cornering -45%, Braking 3.0x, Straight 100%, Spin Risk 500%.
   - Tombol aksi: `FORCE OVERRIDE [DEATH WISH]` vs `SLAP WETS ON [CREW REC]` vs `CANCEL [ESC]`.

---

### Bagian B: Overhaul Fisika Ban Realistis (Realistic Physics Overhaul)
* **Target Files:** [`scripts/gt/gt_driving.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_driving.gd) & [`scripts/gt/gt_contacts.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/scripts/gt/gt_contacts.gd)
1. **Dekopling Kecepatan Lurus vs Tikungan:**
   - Di lintasan lurus (`absf(curv_now) < 0.0035`), mobil pada ban Slick di lintasan basah **TIDAK** dipotong oleh `tyre_factor`. Mobil tetap mampu mencapai kecepatan puncak (>240 km/jam).
   - Di tikungan (`absf(curv_now) >= 0.0035`), batas kecepatan dipotong drastis oleh minimnya grip lateral (kecepatan apex turun 35%–45%).
2. **Aquaplaning & Pengereman Ekstrem:**
   - Dekelerasi pengereman `brake_rate` ambruk hingga 65% di atas genangan air saat memakai ban Slick (jarak pengereman menjadi 3x lebih panjang).
3. **Degradasi Termal Ban Wet di Trek Kering:**
   - Suhu ban meroket pesat hingga >130°C saat ban basah melibas aspal kering (`water < 12%`).
   - Laju keausan melonjak 5x–6x, memicu ban meletus (*puncture*) dalam 2–3 lap.
4. **Snap Oversteer / Solo Spin Risk:**
   - Jika mobil ban Slick melibas tikungan basah melebihi batas grip lateral ($v > \text{corner\_limit} \times 1.10$), mobil memicu *snap oversteer* (mengaktifkan `car.error_timer = 2.0` dan memicu transmisi radio keluhan grip).

---

## 4. Quality Assurance & Definition of Done (DoD)

1. **Test Suite Wajib:**
   - [`tests/test_garage_tyre_strategy.gd`](file:///D:/Occupation/Porto/genex/La_Voiture/tests/test_garage_tyre_strategy.gd) wajib lulus 100% (23+ assertions).
   - Seluruh 27 test suite headless proyek wajib lulus tanpa regresi:
     ```powershell
     Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --path . -s "res://tests/$($_.Name)" }
     ```
2. **Verifikasi Visual Native:**
   - Jalankan `godot --path . --resolution 1920x1080 -s res://scratch/capture_garage_step2.gd`.
   - Pastikan screenshot yang dihasilkan di `executor-report/screenshots/phases/phase-11-step-2-*.png` benar-benar identik secara artistik dengan konsep di `temp/concepts/concept_01_garage_tyre_bay.png` dan `concept_03_critical_mismatch_poster.png`.
3. **Performance Budget:** 60 FPS locked pada resolusi 1080p, 0 orphan nodes.
4. **Laporan Eksekutif:** Buat laporan markdown resmi di `executor-report/reports/FASE-11-LANGKAH-2-GARAGE-UI-AND-PHYSICS-REPORT.md`.
