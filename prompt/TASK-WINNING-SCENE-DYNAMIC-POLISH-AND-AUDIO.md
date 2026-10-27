# TASK HANDOFF: Winning Scene Dynamic Polish & Anime Rock Audio Integration

**Dokumen Referensi:**
- Spec: `docs/superpowers/specs/2026-10-26-winning-scene-and-2.5d-character-pipeline-design.md`
- Prototype Preview: `temp/car_spotlight_preview.html`
- Screenshots Konsep: `executor-report/screenshots/winning_scene/car-spotlight-*.png`
- Audio Asset: `res://assets/audio/music/podium_rock_anthem.mp3`

---

## 1. Tujuan Tugas

Memperbaiki dan memoles `scenes/ui/winning_scene.tscn` dan script pendukungnya agar panggung kemenangan:
1. **Dinamis & Bergerak Hidup (Tidak Kaku/Statis):** Menambahkan *slow dynamic camera orbit sweep* dan menaikkan putaran turntable mobil.
2. **Menyorot Penuh Mobil GT3 Juara (*Hero Machine Spotlight*):** Memberikan pencahayaan sorot volumetrik vertikal, *headlight flare*, cincin neon turntable, dan kartu spesifikasi mesin juara di kanan atas.
3. **Menghilangkan Elemen Sayap (Wings):** Meniadakan sayap grafiti yang mengambang agar komposisi panggung bersih dan fokus.
4. **Menata Kartu UI Pembalap (Streetwear Manga Cards):** Menata kartu P1, P2, P3 di sepertiga bawah dengan sudut miring dan efek *auto-dodge* saat `[TAB]` ditekan (mengeliminasi overlap pada P3).
5. **Mengintegrasikan Musik Baru:** Memasang trek *Melodic Anime Rock Victory Anthem* (`res://assets/audio/music/podium_rock_anthem.mp3`) ke `AudioManager` saat berada di winning scene.

---

## 2. Rincian Teknis Implementasi

### A. Dynamic Scene Motion (`scripts/ui/winning_scene.gd`)
1. **Kamera Orbit Sweep:**
   * Di `_process(delta: float)`: Tambahkan interpolasi sudut orbit kamera horizontal menggunakan fungsi sinus halus:
     `var orbit_offset := sin(_orbit_time * 0.35) * 0.16` (mengorbit $\pm 9^\circ$ secara berkala).
   * Update posisi kamera agar tetap fokus mengunci titik tengah panggung (`Vector3(0, 1.2, 0)`).
2. **Paced Turntable Rotation:**
   * Naikkan kecepatan rotasi turntable mobil dari `0.06 rad/s` ke $\approx 0.16 - 0.20\text{ rad/s}$ agar velg BBS FI-R dan bodi mobil GT3 terlihat jelas berputar.
3. **Sorotan Lampu Volumetrik & Headlight:**
   * Pastikan spotlight utama dari atas panggung terarah tajam ke atap dan kap mesin mobil GT3.
   * Tambahkan efek cahaya lampu depan mobil (SpotLight3D / OmniLight3D atau billboard mesh) yang memancar ke arah depan.
   * Pastikan partikel konfeti emas dan sparkle manga melayang dinamis melintasi panggung.

### B. Layout UI & Callout Mesin GT3
1. **Hapus Elemen Sayap (Wings):**
   * Pastikan tidak ada mesh atau efek shader sayap grafiti pada karakter.
2. **Kartu Spesifikasi Mesin Juara (`car-spec-callout`):**
   * Di sisi kanan atas, buat panel info teknis mobil P1:
     * Menampilkan nama mobil pemenang secara dinamis dari `_winner_car_slug` (misal `MERCEDES-AMG GT3 EVO`, `AUDI R8 LMS GT3`, `PORSCHE 911 GT3 R`).
     * Info mesin ringkas (misal `6.2L V8 NA / 550 HP / BBS FI-R WHEELS`).
3. **Kartu Pembalap Slanted & Auto-Dodge:**
   * P2 (Kiri): Rotasi $-3.5^\circ$, tema Electric Cyan, stiker `[P2] RUNNER-UP`.
   * P1 (Tengah): Terangkat ke atas, tema Acid Lime, stiker `★ [P1] GRAND CHAMPION ★`, badge Fastest Lap.
   * P3 (Kanan): Rotasi $+3.5^\circ$, tema Hazard Orange, stiker `[P3] BRONZE LOCK`.
   * **Auto-Dodge TAB:** Saat `[TAB]` ditekan membuka timing tower, animasikan kartu podium bawah bergeser ke bawah / memudar (`modulate.a = 0.15`), sehingga kartu P3 tidak tertimpa panel klasifikasi!

### C. Integrasi Musik Podium Rock Anthem (`scripts/audio/audio_manager.gd`)
1. Muat trek audio baru:
   `const PODIUM_MUSIC_STREAM := preload("res://assets/audio/music/podium_rock_anthem.mp3")`
2. Tambahkan metode:
   * `func play_podium_music() -> void`: Menghentikan musik saat ini, mengganti stream ke `PODIUM_MUSIC_STREAM` dengan loop aktif, dan memutar di bus `Music`.
   * `func play_menu_music() -> void`: Mengembalikan stream ke `streetwear_synth.ogg` saat kembali ke HQ.
3. Di `winning_scene.gd`:
   * Panggil `play_podium_music()` di `_ready()`.
   * Panggil `play_menu_music()` saat pemain menekan `[ESC]` atau klik `EXIT TO HQ`.

---

## 3. Verifikasi & Definisi Selesai (DoD)

1. **Test Headless (Zero Regression):**
   * Jalankan seluruh 36 test suite:
     `Get-ChildItem tests\test_*.gd | ForEach-Object { godot --headless --path . -s "res://tests/$($_.Name)" }`
   * Seluruh 36 test suite wajib **100% PASS, 0 FAIL**.
2. **Smoke Test Native:**
   * Jalankan `godot --path . -s res://scratch/smoke_winning_scene.gd`.
   * Pastikan alur TAB, ESC, dan restart bekerja mulus dengan 0 error dan 0 orphan node.
3. **Visual Proof & Dokumentasi:**
   * Ambil tangkapan layar native 1920x1080 terbaru (clean stage dengan sorotan mobil dan expanded leaderboard tanpa overlap).
   * Perbarui laporan di `executor-report/reports/FASE-11-LANGKAH-7-WINNING-SCENE-REPORT.md` (Addendum Revisi Visual & Audio).
