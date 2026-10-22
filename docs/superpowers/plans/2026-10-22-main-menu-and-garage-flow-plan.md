# IMPLEMENTATION PLAN: MAIN MENU, RACE SETUP, 3D GARAGE TEAM SELECT & MANGA TRANSITION

**Plan ID:** `PLAN-MAIN-MENU-AND-GARAGE-FLOW`  
**Spec Referensi:** [`docs/superpowers/specs/2026-10-22-main-menu-and-garage-flow-design.md`](file:///D:/Occupation/Porto/genex/La_Voiture/docs/superpowers/specs/2026-10-22-main-menu-and-garage-flow-design.md)  
**Tujuan:** Membangun seluruh antarmuka menu utama, konfigurasi balapan, garasi 3D 10-stall dolly track, integrasi duo karakter 2D, dan transisi anime manga hingga ke grid start balapan.

---

## Tahap 1: Model Data Konfigurasi & Modal Pengaturan (Settings)

### Task 1.1: Kelas Data Konfigurasi Balapan (`RaceConfigData`)
* **File:** `scripts/core/race_config_data.gd`
* **Deskripsi:** Membuat class `RaceConfigData` untuk menyimpan state pilihan pemain:
  * `selected_team_id: int` (0 s/d 9)
  * `track_id: String` ("apex_ring")
  * `total_laps: int` (3, 5, 10)
  * `weather_preset: int` (0=Sunny, 1=Threatening, 2=Wet, 3=Monsoon)
  * `time_of_day: int` (0=Daylight, 1=Sunset, 2=Night)
  * `car1_starting_compound: int` (Soft, Medium, Hard, Inter, Wet)
  * `car2_starting_compound: int` (Soft, Medium, Hard, Inter, Wet)
* **Kriteria Selesai:** Class dapat diinstansiasi dan membawa data antar-scene.

### Task 1.2: Modal Pengaturan Grafis & Audio (`SettingsModal`)
* **File:** `scenes/ui/settings_modal.tscn` & `scripts/ui/settings_modal.gd`
* **Deskripsi:** Membangun modal popup bergaya manga brutalist:
  * Dropdown mode display (Fullscreen, Borderless, Windowed) dan resolusi ($1080\text{p}$, $1440\text{p}$, $720\text{p}$).
  * Pilihan Graphics Preset: Low, Med, High, Ultra.
  * Opsi Toggle V-Sync, Manga Halftone Screentone, dan Anime VFX Density.
  * 5 Slider Audio terhubung langsung ke audio bus Godot (`Master`, `Music`, `SFX`, `Radio`, `UI`) melalui `AudioServer`.
* **Kriteria Selesai:** Perubahan audio dan window mode langsung berefek real-time.

---

## Tahap 2: Layar Menu Utama & Konfigurasi Balapan (Exhibition Setup)

### Task 2.1: Scene Menu Utama (`MainMenu`)
* **File:** `scenes/ui/main_menu.tscn` & `scripts/ui/main_menu.gd`
* **Deskripsi:**
  * Viewport 3D latar belakang garasi dengan kamera sinematik lambat (*subtle ambient dolly*) dan kabut partikel anime.
  * Tombol menu bergaya Neo-Brutalism miring:
    * `EXHIBITION RACE` $\rightarrow$ Navigasi ke `race_setup_menu.tscn`.
    * `CAREER MODE` $\rightarrow$ Disabled dengan pita hazard kuning-hitam `COMING SOON`.
    * `SETTINGS` $\rightarrow$ Membuka `settings_modal.tscn`.
    * `CREDITS` $\rightarrow$ Dialog popup apresiasi pengembang.
    * `QUIT TO DESKTOP` $\rightarrow$ Konfirmasi keluar aplikasi.
* **Kriteria Selesai:** Semua tombol navigasi bekerja mulus dengan SFX klik taktil.

### Task 2.2: Layar Konfigurasi Balapan (`RaceSetupMenu`)
* **File:** `scenes/ui/race_setup_menu.tscn` & `scripts/ui/race_setup_menu.gd`
* **Deskripsi:**
  * Pilihan Sirkuit: Kartu aktif **Apex Ring International** (3.840 m, 14 Turns) dengan diagram garis sirkuit 2D gaya GPS Telemetri. Sirkuit 2 & 3 berlabel `COMING SOON`.
  * Parameter Balapan: Toggle Lap (3, 5, 10 lap), Cuaca (Sunny, Threatening, Dynamic Wet, Monsoon), dan Waktu (Day, Sunset, Night).
  * Tombol `CONTINUE TO TEAM GARAGE` meneruskan `RaceConfigData` ke garasi tim.
* **Kriteria Selesai:** Konfigurasi tersimpan di instance `RaceConfigData` dan berpindah ke scene garasi.

---

## Tahap 3: Garasi Tim 3D, Dolly Camera, & Kartu Duo Karakter 2D

### Task 3.1: Environment Prosedural 10 Stall Garasi Pit
* **File:** `scripts/world/garage_environment_builder.gd` & `scenes/ui/garage_team_select.tscn`
* **Deskripsi:**
  * Membangun 10 stall garasi pit berjajar memanjang dengan jarak antar-stall $14\text{ m}$.
  * Setiap stall memiliki lantai dark epoxy mengilap dengan pantulan bayangan, garis hazard chevron, dan nomor stall di lantai (`// STALL 0X: TEAM NAME`).
  * Partisi baja antar-garasi dengan strip lampu neon LED vertikal yang menyala mengikuti warna identitas tim saat kamera meluncur.
  * Setiap stall memuat mobil tim masing-masing dari aset `assets/cars/<car_slug>/<car_slug>_full.glb` (bodi + 4 master BBS wheels).
  * Kamera memiliki sistem **Dolly Track** yang meluncur mulus antar-stall ($X$-lerp cubic ease-out) saat tombol Tim Berikutnya/Sebelumnya ditekan.
* **Kriteria Selesai:** Kamera meluncur mulus 60 FPS melintasi 10 stall tanpa lag atau stutter.

### Task 3.2: Turntable Orbit Kamera 360° Mobil Terpilih
* **File:** `scripts/ui/garage_car_orbit.gd`
* **Deskripsi:**
  * Pemain dapat mengklik-drag mouse kiri untuk memutar kamera orbit mengelilingi mobil tim terpilih 360°.
  * Memiliki batas elevasi kamera agar tidak tembus ke bawah lantai garasi.
* **Kriteria Selesai:** Orbit kamera responsif, halus, dan kembali ke sudut hero saat ganti tim.

### Task 3.3: UI Overlay Garasi: Duo Karakter 2D & Preset Ban Awal
* **File:** `scenes/ui/garage_team_select.tscn` (CanvasLayer UI)
* **Deskripsi:**
  * **Panel Kiri:** Nama Tim, Principal, Mobil Pabrikan, dan radar matriks performa (Top Speed, Downforce, Tire Wear).
  * **Panel Kanan (Duo Pembalap 2D):** Menampilkan potret anime radio `radio_portrait.png` Pembalap 1 dan 2, kode plat (`#01 RYU`, `#02 REN`), dan bar atribut keahlian (*Pace*, *Tire Care*, *Wet Skill*).
  * **Strategy Deck Bawah (Team Principal Mode):** Pemilih kompon ban awal (*Soft, Medium, Hard, Inter, Wet*) untuk Mobil 1 dan Mobil 2 secara independen, didampingi widget ramalan cuaca balapan.
  * **Tombol Aksi:** Tombol besar bergaya manga **"LAUNCH TO GRID"** dengan SFX raungan mesin GT3.
* **Kriteria Selesai:** Duo karakter 2D tampil tajam, pemilihan ban untuk 2 mobil berfungsi, tombol Launch memicu transisi.

---

## Tahap 4: Transisi Balapan Manga & Integrasi Scene Utama

### Task 4.1: Scene Animasi Transisi Komik Manga (`MangaRaceTransition`)
* **File:** `scenes/ui/manga_race_transition.tscn` & `scripts/ui/manga_race_transition.gd`
* **Deskripsi:**
  * Tahap 1 (0.1s): Efek *Negative Snap-Invert Flash* (layar monokrom terbalik 1-frame) diiringi raungan gas penuh.
  * Tahap 2 (0.8s): Tiga panel komik miring meluncur cepat (*comic strip slash*) menampilkan close-up mata pembalap 2D tim terpilih, nomor mobil grafiti, dan garis aksi (*speedlines*).
  * Tahap 3 (1.2s): Sapuan bintik halftone (*halftone wipe*) membuka kamera sirkuit 3D balapan di `scenes/race_weekend_world.tscn`.
* **Kriteria Selesai:** Animasi transisi berjalan dramatis dan konsisten dengan estetika anime neo-brutalisme.

### Task 4.2: Integrasi ke `scenes/main.tscn` & `RaceWeekendWorld`
* **File:** `scenes/main.tscn`, `scripts/world/race_weekend_world.gd`, `scenes/ui/podium_screen.tscn`
* **Deskripsi:**
  * `scenes/main.tscn` memuat `main_menu.tscn` secara default saat game diluncurkan.
  * `RaceWeekendWorld` membaca `RaceConfigData`:
    * Mengaitkan `selected_team_id` ke mobil pemain (HUD Tactical Deck mengendalikan tim yang dipilih pemain).
    * Memasang kompon ban awal yang dipilih pemain ke mobil 1 dan mobil 2 tim tersebut saat start balapan.
    * Menyesuaikan parameter cuaca awal dan jumlah lap sesuai konfigurasi.
  * Tombol "Exit to HQ" pada `podium_screen.tscn` mengembalikan pemain kembali ke `main_menu.tscn`.
* **Kriteria Selesai:** Balapan penuh dapat dimainkan dari tim mana pun yang dipilih pemain, dan kembali ke menu dengan bersih.

---

## Tahap 5: Pengujian Otomatis & Verifikasi Menyeluruh

### Task 5.1: Script Pengujian Otomatis Alur Menu (`test_main_menu_flow.gd`)
* **File:** `tests/test_main_menu_flow.gd`
* **Deskripsi:** Menguji secara headless:
  * Inisialisasi Main Menu, Race Setup, dan Garage Team Select.
  * Validasi 10 stall garasi dan pemuatan model `*_full.glb`.
  * Validasi ketersediaan file `radio_portrait.png` pada seluruh 20 pembalap.
  * Validasi transfer data `RaceConfigData` ke dalam `RaceWeekendWorld`.
* **Kriteria Selesai:** 100% PASS (0 FAIL).

### Task 5.2: Verifikasi Bebas Regresi
* **Perintah:** Jalankan seluruh 11 test suite proyek:
  ```powershell
  Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_modular_car.gd
  Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_audio_and_race_weekend.gd
  Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_main_menu_flow.gd
  ```
* **Kriteria Selesai:** Seluruh tes lulus tanpa ada regresi pada simulasi GT, fisika, audio, maupun AI rival.
