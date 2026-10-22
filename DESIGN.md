# DESIGN.md — NFS Unbound $\times$ Toon Anime UI Topology (GT Manager Adaptation)

> **Target Consumer:** AI / LLM Coding Agents & UI Engineers
>
> **Scope:** Murni mengatur **Komponen Warna**, **Topologi & Arsitektur Komponen UI**, serta **Spesifikasi VFX (Visual Effects)**. Tidak mencakup *3D rendering* atau *gameplay arcade*.
>
> **Target Domain:** **GT Manager / Motorsport Strategy & Simulation** (Pit Wall Command Center, Live Timing Tower, Telemetry Modules, Setup/HQ Management, Driver Radio).
>
> **Visual DNA:** *Streetwear Brutalism & Acid Graffiti* (NFS Unbound) $\times$ *Hard-Edge Manga/Anime UI* (Zenless Zone Zero, Persona 5).

## 1. Hukum Dasar Desain (Core UI Laws)

Agent LLM wajib mematuhi 5 aturan mutlak berikut saat membuat komponen UI:

1. **Zero Softness (No Blur, No Rounded Glass):**
   Dilarang menggunakan *glassmorphism* (`backdrop-filter: blur`), bayangan kabur, atau sudut membulat lembut. Semua kontainer wajib bersudut tajam ($0\text{px}$), menggunakan garis tepi tinta hitam pekat ($2\text{px}$ hingga $2.5\text{px}$ `#050505`), serta *hard offset shadow* ($4\text{px}$ hingga $6\text{px}$ dengan $0\text{px}$ *blur*).

2. **Utilitarian Data Grid vs. Subversive Event VFX:**
   Karena **GT Manager** menampilkan tabel data dan telemetri padat, struktur tabel internal wajib lurus ($0^\circ$) dan bersih agar mudah dibaca. Kemiringan dinamis ($\theta = -6^\circ$) serta ledakan VFX (grafiti, *RGB split*, *anime cut-in*) hanya diterapkan pada *header* panel, *badge* status, tombol aksi (*Pit Call*), dan momen kritis (*Fastest Lap*, *Safety Car*, *Critical Tire Wear*).

3. **3-Tier Z-Index UI Depth:**
   Setiap layar dibagi ke dalam 3 lapisan kedalaman UI:

   * **Layer 1 (**$Z = 10$**) — Diegetic Backdrop:** Tipografi *hollow-stroke* raksasa (`14vw`–`18vw`) dan grid titik LED di latar belakang.

   * **Layer 2 (**$Z = 20$**) — Modular Workspace Grid:** Panel data utama, *timing tower*, grafik telemetri, dan kartu manajemen.

   * **Layer 3 (**$Z = 30$**) — Reactive VFX & Cut-In Layer:** *Banner* interupsi radio pembalap (*Anime Cut-In*), *stamp* grafiti, dan *toast* peringatan strategi.

4. **Snap-Invert Selection State:**
   Baris tabel, tab navigasi, atau kartu pilihan yang aktif/di-*hover* tidak boleh menggunakan efek *fade* lambat. Komponen harus langsung membalikkan warna (*invert*) dari gelap (`#0C0E14`) menjadi putih terang (`#F4F5F7`) dengan teks hitam pekat (`#050505`) dan bergeser tajam dalam waktu $\le 120\text{ms}$.

5. **Manga Screentone Texturing:**
   Permukaan panel tidak boleh berupa warna solid polos yang mati; lapisi dengan pola titik *halftone* (*Ben-Day dots*) beropasitas rendah untuk memberikan tekstur cetak manga/komik.

## 2. Sistem Komponen Warna & Tekstur (Color & Surface Tokens)

### 2.1 Variabel CSS & Pemetaan Semantik GT Manager

```
:root {
  /* === 1. BASE SURFACES & INK OUTLINES === */
  --bg-canvas-deep: #090A0F;                  /* Latar dasar utama aplikasi */
  --surface-panel-dark: rgba(14, 17, 24, 0.94);/* Permukaan panel data & kartu gelap */
  --surface-panel-elevated: #161A24;          /* Header tabel / sub-modul */
  --surface-snap-invert: #F4F5F7;             /* Surface aktif/terpilih (Putih Terang) */
  --ink-border-black: #050505;                /* Garis tepi tinta komik & bayangan keras */
  --hairline-divider: rgba(255, 255, 255, 0.16); /* Garis pemisah baris tabel data */

  /* === 2. HIGH-VOLTAGE ACCENTS (SEMANTIK GT MANAGER) === */
  --accent-acid-lime: #CCFF00;     /* Primary Active, Optimal Pace, Push Mode, Confirm Pit */
  --accent-electric-cyan: #00F0FF; /* Live Telemetry, Wet Weather, ERS/Battery, Sector Delta (-) */
  --accent-cyber-yellow: #FFE600;  /* Pit Window Open, Yellow Flag, Tire Deg Warning, Medium Compound */
  --accent-anime-crimson: #FF1E56; /* Critical Alert, BOX BOX Now, Redline/Overheat, Soft Compound */
  --accent-purple-sector: #D946EF; /* Overall Fastest Sector / Lap Record Stamp */

  /* === 3. TYPOGRAPHY HIERARCHY === */
  --text-primary: #FFFFFF;
  --text-secondary: #949BA8;
  --text-muted: #5E6573;
  --text-inverted: #050505;
}

```

### 2.2 Matriks Penerapan Warna pada Komponen UI

| **Komponen UI** | **Background Surface** | **Border Dalam** | **Outline Luar** | **Hard Offset Shadow** | **Warna Teks & Aksen** | 
| **Panel Data Standar** | `--surface-panel-dark` + Halftone | $2.5\text{px}$ `#050505` | $1\text{px}$ `rgba(255,255,255,0.2)` | `5px 5px 0px #000000` | Teks `#FFFFFF`, Label `#949BA8` | 
| **Panel Fokus / Strategi Aktif** | `--surface-panel-dark` + Halftone | $2.5\text{px}$ `#050505` | $1.5\text{px}$ `#CCFF00` | `6px 6px 0px #CCFF00` | Header `#CCFF00`, Teks `#FFFFFF` | 
| **Baris Tabel / Menu (Active)** | `--surface-snap-invert` (`#F4F5F7`) | $2\text{px}$ `#050505` | $2\text{px}$ `#CCFF00` | `5px 5px 0px #CCFF00` | Teks `#050505` (*Bold*) | 
| **Tombol Eksekusi (`BOX THIS LAP`)** | `--accent-acid-lime` + Halftone | $2.5\text{px}$ `#050505` | $1\text{px}$ `#FFFFFF` | `5px 5px 0px #FF1E56` | Teks `#050505` (*Heavy Uppercase*) | 
| **Alert Kritis / Red Flag / Overheat** | `--accent-anime-crimson` + Halftone | $2.5\text{px}$ `#050505` | $2\text{px}$ `#FFE600` | `6px 6px 0px #000000` | Teks `#FFFFFF` + Badge `#FFE600` | 

### 2.3 Komponen Tekstur Halftone (Manga Screentone CSS)

```
/* Tekstur dasar untuk seluruh kartu data gelap */
.surface-halftone-dark {
  background-color: var(--surface-panel-dark);
  background-image: radial-gradient(rgba(255, 255, 255, 0.07) 1px, transparent 0);
  background-size: 6px 6px;
}

/* Tekstur untuk header aktif, badge utama, dan tombol CTA */
.surface-halftone-lime {
  background-color: var(--accent-acid-lime);
  background-image: radial-gradient(rgba(0, 0, 0, 0.16) 1.25px, transparent 0);
  background-size: 5px 5px;
}

/* Tekstur untuk peringatan kritis & banner interupsi */
.surface-halftone-crimson {
  background-color: var(--accent-anime-crimson);
  background-image: radial-gradient(rgba(0, 0, 0, 0.24) 1.5px, transparent 0);
  background-size: 5px 5px;
}

/* Tekstur grid titik LED untuk latar belakang layar (Layer 1) */
.backdrop-led-matrix {
  background-color: var(--bg-canvas-deep);
  background-image: radial-gradient(rgba(204, 255, 0, 0.14) 1px, transparent 0);
  background-size: 16px 16px;
}

```

## 3. Topologi Spasial & Arsitektur Komponen UI

### 3.1 Topologi Layar 1: Pit Wall / Race Strategy Dashboard (Data-Dense Grid)

Tata letak untuk memantau jalannya balapan, kondisi ban/bahan bakar, dan instruksi strategi pembalap:

```
+===================================================================================+
| [ZONE A: TOP TELEMETRY & SESSION RIBBON (Z:20 | Height: 56px)]                    |
|  [■ GT_SERIES // RD.04]  [LAP: 24/50]  [⛅ TRACK: 34°C DRY]  [FLAG: GREEN // 1.0x] |
+-----------------------------------------------------------------------------------+
|   . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   |
|   . [LAYER 1 BACKDROP (Z:10)]: Teks Hollow Raksasa "P I T _ W A L L // 作戦"  .   |
|   . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   |
|                                                                                   |
| +----------------------+ +-----------------------------+ +----------------------+ |
| | [ZONE B: LEFT (Z:20)]| | [ZONE C: CENTER (Z:20)]     | | [ZONE D: RIGHT(Z:20)]| |
| | LIVE TIMING TOWER    | | CIRCUIT MAP & TELEMETRY     | | DRIVER STRATEGY DECK | |
| | (Width: 280px–320px) | | WORKSPACE (Flex-1)          | | (Width: 340px–380px) | |
| |                      | |                             | |                      | |
| | POS  DRIVER   GAP  T | |  +-----------------------+  | | [CAR #01 // KAZE]    | |
| | -------------------- | |  | 2D VECTOR TRACK NODES |  | |  PACE: [■ ATTACK   ] | |
| | [01 ★ KAZE   LEAD S] | |  | & SECTOR DELTAS       |  | |  ERS : [█████░░ 72%] | |
| |  ^ Snap-Invert Putih | |  +-----------------------+  | |  FUEL: [██████░ +1.2]| |
| |  02  VEX    +1.42 M  | |                             | |                      | |
| |  03  SORA   +3.18 S  | |  +-----------------------+  | | TIRE DEG (4-CORNER): | |
| |  04  KAI    +4.05 H  | |  | LAP TIME & TIRE CLIFF |  | |  FL [82%]   FR [78%] | |
| |  05  RYU     PIT  M  | |  | STEPPED GRAPH MODULE  |  | |  RL [85%]   RR [84%] | |
| |  ...                 | |  +-----------------------+  | |                      | |
| |                      | |                             | | [⚡ BOX THIS LAP ★ ] | |
| +----------------------+ +-----------------------------+ +----------------------+ |
|                                                                                   |
| +-------------------------------------------------------------------------------+ |
| | [ZONE E: BOTTOM EVENT MARQUEE & RADIO CUT-IN ANCHOR (Z:30 | Height: 64px)]    | |
| |  [★ ANIME RADIO CUT-IN SLIDE OVERLAY]  //  [TICKER: SECTOR 2 PURPLE BY #01]   | |
| +-------------------------------------------------------------------------------+ |
+===================================================================================+

```

### 3.2 Topologi Layar 2: HQ / Car Setup & Team Management (Asymmetric Split)

Tata letak untuk layar kustomisasi *setup* mobil, R&D komponen, atau manajemen pembalap:

```
+===================================================================================+
| [TOP HEADER: BREADCRUMB STAMP & TEAM BUDGET (Z:20)]                               |
|  [■ HQ // CAR_DEVELOPMENT]                        [TIER: GT3 PRO] [$ 12,450,000]  |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|   =============================================================================   |
|   || [LAYER 1 BACKDROP (Z:10)]: 16vw Hollow Stroke "E N G I N E E R I N G"   ||   |
|   =============================================================================   |
|                                                                                   |
| +------------------------+  +---------------------------------------------------+ |
| | [LEFT NAV STACK (Z:20)]|  | [RIGHT BENTO SPEC GRID (Z:20)]                    | |
| | (Width: 300px)         |  |                                                   | |
| |                        |  | +-----------------------+ +---------------------+ | |
| | [01 AERO SETUP      ★] |  | | MODULE 01 (Skew -4deg)| | MODULE 02           | | |
| |  +-- Ticker Strip      |  | | DOWNFORCE BALANCE     | | GEAR RATIO MATRIX   | | |
| |  +-- Inverted #F4F5F7  |  | | FR [██████░░] 64%     | | 1ST..6TH STEP BARS  | | |
| |                        |  | +-----------------------+ +---------------------+ | |
| | [02 SUSPENSION & CAM ] |  | +-----------------------------------------------+ | |
| | [03 POWERTRAIN & ERS ] |  | | MODULE 03: TELEMETRY COMPARISON TABLE         | | |
| | [04 PIT CREW TRAINING] |  | | High-contrast monospace rows + delta badges   | | |
| +------------------------+  +---------------------------------------------------+ |
|                                                                                   |
| [BOTTOM BAR: KEYBOARD SHORTCUTS & STREETWEAR SHIPPING LABEL (Z:20)]               |
+===================================================================================+

```

### 3.3 Anatomi Komponen UI Inti (Component Rules)

#### A. Kontainer Neo-Brutalist & Counter-Skew (`.toon-panel`)

* **Panel Data Besar (Tabel / Grafik):** Gunakan sudut $90^\circ$ murni (`border-radius: 0px`) agar baris data tidak terpotong, dilengkapi *top header strip* setebal $28\text{px}$ dengan potongan sudut kanan atas $45^\circ$:
  `clip-path: polygon(0 0, calc(100% - 14px) 0, 100% 14px, 100% 100%, 0 100%);`

* **Kartu Status, Badge & Tombol Aksi (`.skew-box`):** Gunakan kemiringan paralelogram $\theta = -6^\circ$ dan penyeimbang teks internal $+\theta = +6^\circ$:

  ```
  .skew-box { transform: skewX(-6deg); }
  .unskew-content { transform: skewX(6deg); }
  
  ```

#### B. Baris Navigasi & Tabel "Snap-Invert" + Marquee Ticker

* Saat sebuah baris pembalap di *Timing Tower* atau kategori menu dipilih:

  1. Latar berubah instan ke `--surface-snap-invert` (`#F4F5F7`) dan teks menjadi `#050505`.

  2. Kontainer bergeser secara horizontal `transform: translateX(8px)` dengan `box-shadow: 5px 5px 0px var(--accent-acid-lime)`.

  3. Di bagian atas kartu muncul **Micro-Ticker Bar** setinggi $14\text{px}$ dengan latar `#CCFF00` dan teks `JetBrains Mono` $9\text{px}$ berjalan horizontal (`@keyframes marquee`).

#### C. Segmented Telemetry & Tire Wear Bars

* **Dilarang** menggunakan *progress bar* membulat atau gradasi halus.

* Gunakan balok-balok terpisah (*stepped segments* sebanyak $10$ atau $20$ blok dengan `gap: 2px`) yang dibungkus dalam bingkai hitam `border: 2px solid #050505`.

* Aturan warna blok berdasarkan persentase ketahanan ban/komponen $p$:

  * $p > 60\%$: `--accent-acid-lime` (`#CCFF00`)

  * $30\% < p \le 60\%$: `--accent-cyber-yellow` (`#FFE600`)

  * $p \le 30\%$: `--accent-anime-crimson` (`#FF1E56`) disertai kedipan *glitch*.

#### D. Sistem Tipografi 4-Pilar

1. **Display / Backdrop & Big Numerals (`'Anton'`):** Untuk teks dinding `Layer 1`, nomor mobil (`#01`), dan posisi klasemen (`P1`).

2. **UI Headers & Strategy Controls (`'Barlow Condensed'`):** *Weight* $700$–$900$, *uppercase*, untuk judul modul, tombol perintah (`BOX THIS LAP`, `PUSH HARD`), dan label ban.

3. **Timing & Telemetry Data (`'JetBrains Mono'`):** Wajib digunakan untuk semua angka waktu putaran (`01:32.408`), selisih waktu (`-0.312s`), suhu ban (`98°C`), dan persentase bahan bakar (`font-variant-numeric: tabular-nums`).

4. **Anime Radio & Event Callouts (`'Chakra Petch'`):** *Weight* $700$ *italic*, untuk dialog radio pembalap/insinyur dan *banner* interupsi.

## 4. Spesifikasi VFX & Reactive Motion (VFX Topology)

Bagian ini mengatur bagaimana elemen visual *NFS Unbound* (grafiti, *RGB split*) dan *Toon Anime* (*cut-in*, *speed lines*, *impact frame*) muncul sebagai respons terhadap *event* manajemen di **GT Manager**.

### 4.1 Chromatic Aberration (RGB Split VFX)

Diterapkan pada angka berprioritas tinggi (Nomor Posisi, *Fastest Lap Time*, atau peringatan *BOX NOW*):

* **Static High-Contrast Split (Default pada Angka Utama):**

  ```
  .vfx-rgb-split {
    text-shadow: -2.5px 0px 0px var(--accent-anime-crimson),
                  2.5px 0px 0px var(--accent-electric-cyan);
  }
  
  ```

* **Reactive Glitch Burst (Dipicu selama** $600\text{ms}$ **saat Overtake / Purple Lap / Pit Call):**

  ```
  @keyframes vfxRgbGlitch {
    0%   { text-shadow: -4px -1px 0 var(--accent-anime-crimson), 4px 1px 0 var(--accent-electric-cyan); transform: translate(0, 0) skewX(-6deg); }
    50%  { text-shadow: 4px 2px 0 var(--accent-acid-lime), -4px -2px 0 var(--accent-anime-crimson); transform: translate(-2px, 1px) skewX(-9deg); }
    100% { text-shadow: -3px 1px 0 var(--accent-electric-cyan), 3px -1px 0 var(--accent-anime-crimson); transform: translate(1px, -1px) skewX(-6deg); }
  }
  .vfx-glitch-active {
    animation: vfxRgbGlitch 0.14s steps(2, end) infinite;
  }
  
  ```

### 4.2 2D Anime Cut-In Banner (Driver / Race Engineer Radio)

Saat pembalap melapor lewat radio (misal: *"Tires are gone!"*, *"Overtake complete!"*) atau pemain menekan tombol perintah strategi utama, *banner* komik diagonal meluncur memotong sudut kiri bawah atau tengah layar (`Layer 3 / Z:30`):

* **Geometri Kontainer:** Lebar $420\text{px}$–$520\text{px}$, miring `transform: skewX(-10deg)`, `border: 3px solid #050505`, `outline: 2px solid #CCFF00`, `box-shadow: 8px 8px 0px #000000`.

* **Latar Internal:** `.surface-halftone-crimson` (untuk kondisi darurat/serangan) atau `.surface-halftone-lime` (untuk konfirmasi strategi), ditambah garis-garis kecepatan diagonal (*manga speed lines* SVG) di belakang potret 2D karakter/helm.

* **Kurva Animasi Masuk:**

  * Initial state: `transform: translateX(-125%) skewX(-10deg);`

  * Active state: `transform: translateX(0%) skewX(-10deg);` dengan transisi `cubic-bezier(0.16, 1, 0.3, 1)` berdurasi $220\text{ms}$.

### 4.3 Subversive Graffiti Stamps & Manga SFX Overlays

Untuk menghindari kesan *spreadsheet* yang kaku pada game manajer, gunakan elemen grafis SVG bergaya coretan tangan (*street art*) sebagai penanda status:

1. **Graffiti Crown Stamp (`👑`):** Muncul di sebelah nama pembalap yang memegang *Fastest Lap* atau *P1 Leader*.

2. **Acid Brush Underline:** Saat sebuah tab utama dipilih, garis bawahnya bukan garis lurus CSS biasa, melainkan *path* SVG sapuan kuas kasar berwarna `#CCFF00`.

3. **Manga Impact Frame (1-Frame Flash):** Saat tombol krusial ditekan (seperti mengaktifkan *ERS Overtake Override* atau *Box This Lap*), panel target berkedip selama $80\text{ms}$ menjadi siluet hitam-putih kontras tinggi sebelum kembali ke warna normal.

4. **Diagonal Caution Tape Strip:** Saat *Safety Car* atau *Yellow Flag* keluar, pita berjalan (`marquee`) bergaris diagonal kuning-hitam (`repeating-linear-gradient(-45deg, #FFE600 0 12px, #050505 12px 24px)`) langsung mengunci bagian atas *Timing Tower*.

### 4.4 Spesifikasi Timing & Transisi (Motion Tokens)

* **Hover / Snap-Invert:** `110ms cubic-bezier(0.16, 1, 0.3, 1)` (instan dan tajam).

* **Panel / Modal Open:** `180ms cubic-bezier(0.34, 1.56, 0.64, 1)` (sedikit efek pegas komik/*overshoot*).

* **Data Tick Update (Timing Tower):** Saat posisi pembalap naik/turun, baris berkedip `#CCFF00` (naik) atau `#FF1E56` (turun) selama $300\text{ms}$ dengan pergeseran `translateX(6px)`.

## 5. Ringkasan Guardrails untuk Agent LLM

* **JANGAN** membuat *gauge speedometer* melingkar ala game menyetir *arcade*; gunakan **Segmented Step Bars**, **Delta Sparklines**, dan **Timing Tower Rows** untuk *GT Manager*.

* **JANGAN** memiringkan (`skewX`) tabel berisi ratusan angka telemetri; terapkan `skewX(-6deg)` hanya pada *header* modul, lencana status (*badges*), *button* perintah, dan *banner* notifikasi.

* **SELALU** pasangkan `border: 2px solid #050505` dengan `outline: 1px solid ...` dan *hard offset shadow* (`0px` blur) pada setiap kartu modul untuk mempertahankan identitas visual *NFS Unbound* $\times$ *Toon Anime*.