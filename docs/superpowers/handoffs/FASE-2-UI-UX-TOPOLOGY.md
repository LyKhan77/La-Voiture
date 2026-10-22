# Handoff Blueprint: Fase 2 — UI/UX Pit Wall Command Center & Manga Styling
**Target Executor:** Godot UI/UX & Technical Artist Agent  
**Spesifikasi Acuan:** [PRD/02-UI-UX-TOPOLOGY.md](file:///D:/Occupation/Porto/genex/La_Voiture/PRD/02-UI-UX-TOPOLOGY.md) & [DESIGN.md](file:///D:/Occupation/Porto/genex/La_Voiture/DESIGN.md)  
**Tujuan Akhir:** Membangun antarmuka Pit Wall Dashboard neo-brutalisme dengan garis tinta hitam, Ben-Day halftone screentone, reaksi Snap-Invert ($\le 120\text{ms}$), Driver Strategy Deck (4-corner tire telemetry), dan banner Anime Radio Cut-In.

---

## 1. Copy-Paste Prompt untuk Executor Agent

Salin prompt di bawah ini ke agent eksekutor:

```text
Anda adalah Godot 4 UI/UX & Shader Engineer. Tugas Anda adalah mengeksekusi FASE 2 proyek game "La Voiture": Membangun Sistem UI Pit Wall Command Center dan Visual Styling Manga / Neo-Brutalisme.

Dokumen Acuan Wajib:
- DESIGN.md: D:/Occupation/Porto/genex/La_Voiture/DESIGN.md (Hukum UI Mutlak, Topologi Layar 1, Token Warna)
- PRD 02: D:/Occupation/Porto/genex/La_Voiture/PRD/02-UI-UX-TOPOLOGY.md
- PRD 01: D:/Occupation/Porto/genex/La_Voiture/PRD/01-CORE-SIMULATION-ENGINE.md (Koneksi Sinyal Telemetri)

Lingkungan Eksekusi:
- Godot Engine Path: "C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
- Shell: PowerShell di Windows

Instruksi Eksekusi:
1. Buat scripts/ui/ui_theme_tokens.gd berisi konstanta warna DESIGN.md (BG_CANVAS_DEEP #090A0F, SURFACE_PANEL_DARK #0E1118, ACCENT_ACID_LIME #CCFF00, ACCENT_ELECTRIC_CYAN #00F0FF, ACCENT_CYBER_YELLOW #FFE600, ACCENT_ANIME_CRIMSON #FF1E56).
2. Buat shader shaders/halftone_screentone.gdshader (pola radial Ben-Day dots manga).
3. Buat shader shaders/chamfer_header.gdshader (potongan sudut kanan atas 45° setebal 14px).
4. Buat komponen scenes/pit_wall/driver_row.tscn:
   - Terapkan logika Snap-Invert Selection: saat dipilih/hover, latar belakang berubah instan menjadi putih terang #F4F5F7, teks hitam #050505, border #CCFF00, dan bergeser +6px dalam waktu <= 120ms.
5. Buat scenes/pit_wall/timing_tower.tscn untuk 20 mobil (menampilkan posisi 1-20, nama, gap delta, kompon ban).
6. Buat scenes/pit_wall/driver_strategy_deck.tscn:
   - Diagram telemetri 4 sudut ban (FL, FR, RL, RR) dengan indikator persentase & suhu.
   - Slider Pace Mode (Conserve/Balanced/Attack) & Fuel Mode.
   - Tombol eksekusi [BOX THIS LAP] dengan micro camera shake dan pulse crimson.
   - Tab switch antara Car #01 dan Car #02.
7. Buat scenes/pit_wall/anime_radio_cutin.tscn pada CanvasLayer Z-index 30:
   - Banner meluncur dari kiri bawah saat sinyal radio aktif, menampilkan potret karakter dan teks komik pembalap.
8. Rakit seluruh komponen ke dalam scenes/pit_wall/pit_wall_dashboard.tscn sesuai topologi spasial DESIGN.md Bab 3.1.
9. Buat scenes/test_pit_wall.tscn dan verifikasi secara visual dan interaktif.

Patuhi aturan Zero Softness (tanpa rounded glass, tanpa blur, sudut 90°, outline hitam 2.5px).
```

---

## 2. Rincian File yang Harus Dibuat

```text
D:/Occupation/Porto/genex/La_Voiture/
├── shaders/
│   ├── halftone_screentone.gdshader
│   └── chamfer_header.gdshader
├── scripts/
│   └── ui/
│       ├── ui_theme_tokens.gd
│       ├── driver_row_controller.gd
│       ├── timing_tower_controller.gd
│       ├── driver_strategy_deck_controller.gd
│       ├── anime_radio_cutin_controller.gd
│       └── pit_wall_controller.gd
└── scenes/
    ├── pit_wall/
    │   ├── driver_row.tscn
    │   ├── timing_tower.tscn
    │   ├── driver_strategy_deck.tscn
    │   ├── anime_radio_cutin.tscn
    │   └── pit_wall_dashboard.tscn
    └── test_pit_wall.tscn
```

---

## 3. Langkah Implementasi Terinci (Step-by-Step Plan)

### Step 1: Shader Halftone & Token Tema
- Buat `shaders/halftone_screentone.gdshader` sesuai kode GLSL di [PRD 02 Bab 5.2](file:///D:/Occupation/Porto/genex/La_Voiture/PRD/02-UI-UX-TOPOLOGY.md#L143-L158).
- Buat `scripts/ui/ui_theme_tokens.gd` memuat seluruh palet warna dan durasi transisi ($120\text{ms}$).

### Step 2: Driver Row Component & Snap-Invert
- `driver_row.tscn` memuat `PanelContainer` dengan `HBoxContainer`:
  - `Label_Pos` (Font Bold, lebar 28px).
  - `Label_Name` (Nama driver 3 huruf, misal `KAZ`, `VEX`).
  - `Label_Gap` (Interval waktu, misal `+1.42s`).
  - `TextureRect_Tire` (Ikon kompon ban dengan warna semantik: Merah=Soft, Kuning=Medium, Putih=Hard, Cyan=Wet).
- `driver_row_controller.gd`: fungsi `set_selected(active: bool)` yang mengubah `theme_override_styles/panel` menjadi putih `#F4F5F7` dan teks hitam `#050505` dalam waktu $\le 120\text{ms}$.

### Step 3: Timing Tower (Zone B)
- `timing_tower.tscn` berisi header miring $-6^\circ$ (`.skew-box`) dengan teks `"LIVE TIMING // P1-P20"`.
- Script mendengarkan sinyal `telemetry_updated` dari `RaceSimEngine` dan mengurutkan baris pembalap secara otomatis tanpa animasi lambat.

### Step 4: Driver Strategy Deck (Zone D)
- Panel kanan dengan tab toggle `Car #01` dan `Car #02`.
- Kontainer telemetri ban: 4 kotak grid (FL, FR, RL, RR) dengan bar persentase aus dan label suhu.
- Tombol aksi `BOX THIS LAP`: StyleBox warna Acid Lime `#CCFF00`, teks hitam tebal, dan border hitam $2.5\text{px}$.

### Step 5: Anime Radio Cut-In Overlay (Zone E)
- Node `CanvasLayer` ber-Z-index 30.
- `AnimationPlayer` dengan track posisi `offset:x` yang menggeser panel komik masuk dari $-400\text{px}$ ke $+20\text{px}$ saat sinyal transmisi radio dipicu.

### Step 6: Integrasi Pit Wall Dashboard
- Satukan seluruh modul ke dalam `pit_wall_dashboard.tscn` sesuai grid 3 kolom:
  - Kolom Kiri ($320\text{px}$): Timing Tower.
  - Kolom Tengah (Flex-1): 3D Viewport / Circuit Radar.
  - Kolom Kanan ($360\text{px}$): Strategy Deck.

---

## 4. Perintah Verifikasi & Acceptance Test

```powershell
& "C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" scenes/test_pit_wall.tscn
```
* **Kriteria Keberhasilan:** Window Godot terbuka pada resolusi $1920 \times 1080$, menampilkan layout Pit Wall bergaya manga, interaksi hover/klik baris driver langsung memicu Snap-Invert putih terang, dan penekanan tombol Box memicu animasi banner cut-in anime.
