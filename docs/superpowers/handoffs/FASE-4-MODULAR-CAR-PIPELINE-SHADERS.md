# Handoff Blueprint: Fase 4 — Pipeline Mobil 3D Modular & Shader Toon Anime
**Target Executor:** 3D Technical Artist & Vehicle Pipeline Specialist  
**Spesifikasi Acuan:** [PRD/03-MODULAR-ASSET-PIPELINE.md](file:///D:/Occupation/Porto/genex/La_Voiture/PRD/03-MODULAR-ASSET-PIPELINE.md), [PRD/04-RENDERING-SHADERS-VFX.md](file:///D:/Occupation/Porto/genex/La_Voiture/PRD/04-RENDERING-SHADERS-VFX.md), dan [Full-Car-Component-Guide.md](file:///D:/Occupation/Porto/genex/La_Voiture/Full-Car-Component-Guide.md)  
**Tujuan Akhir:** Membangun sistem sasis modular berbasis *Universal Sockets* (`Marker3D`), shader *Toon Cel-Shaded* dengan outline tinta komik *Inverted-Hull*, pemotongan part modular mobil GT3 pertama via Blender MCP/Meshy AI dengan jaminan **0% overlap geometri**, serta efek partikel asap manga 2D.

---

## 1. Copy-Paste Prompt untuk Executor Agent

Salin prompt di bawah ini ke agent eksekutor:

```text
Anda adalah 3D Technical Artist & Vehicle Pipeline Specialist. Tugas Anda adalah mengeksekusi FASE 4 proyek game "La Voiture": Membangun Sistem Sasis Mobil 3D Modular, Shader Toon Anime Cel-Shaded, dan Efek Partikel Manga.

Dokumen Acuan Wajib:
- PRD 03: D:/Occupation/Porto/genex/La_Voiture/PRD/03-MODULAR-ASSET-PIPELINE.md (Standar Universal Socket & Zero Overlap)
- PRD 04: D:/Occupation/Porto/genex/La_Voiture/PRD/04-RENDERING-SHADERS-VFX.md (Shader Cel-Shaded & Inverted Hull)
- Panduan Komponen: D:/Occupation/Porto/genex/La_Voiture/Full-Car-Component-Guide.md (Komponen Eksterior & Kokpit)
- Referensi Gambar: D:/Occupation/Porto/genex/La_Voiture/reference-assets/images

Tools yang Tersedia:
- Blender MCP (mcp-for-blender port 9875)
- Meshy MCP (@meshy-ai/meshy-mcp-server) atau Genex CLI (npx genex model)
- Godot Engine Path: "C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"

Instruksi Eksekusi:
1. Buat shaders/anime_cel_shaded.gdshader:
   - Pencahayaan berundak (2-tone stepped lighting) tanpa gradasi halus.
   - Slot tekstur albedo dasar dan livery mask overlay.
2. Buat shaders/inverted_hull_outline.gdshader:
   - Pass kedua ekstrusi vertex sepanjang normal (+0.015m), cull_front, warna hitam #050505.
3. Buat scripts/car/modular_car_assembler.gd:
   - Mendefinisikan titik kait Marker3D: Socket_FrontSplitter, Socket_RearWing, Socket_Diffuser, Socket_Wheel_FL/FR/RL/RR, Socket_Cockpit.
   - Fungsi equip_part(category, tier, glb_scene) yang menempelkan mesh tepat pada transform socket.
4. Buat sasis dasar mobil GT3 pertama (misal: Porsche 911 GT3 atau Aston Martin Vantage) menggunakan referensi di reference-assets/images:
   - Siapkan mesh sasis dan pisahkan part (Front Splitter, Swan-Neck Wing, Rear Diffuser) menggunakan Blender MCP.
   - Terapkan shared pivot origin (0,0,0) pada semua part modular untuk menjamin 0% tumpang tindih geometri (zero clipping).
   - Simpan part di res://assets/cars/porsche_911/parts/.
5. Buat scenes/vfx/manga_smoke_emitter.tscn:
   - Partikel asap ban 2D arsir manga hitam-putih yang memicu emisi saat mobil selip (slip angle > 15°).
6. Buat scenes/test_modular_car.tscn untuk menguji penggantian part secara visual (Visual Swap) di viewport Godot.
7. Verifikasi bahwa part terpasang presisi sehelai rambut tanpa z-fighting atau clipping.
```

---

## 2. Rincian File yang Harus Dibuat

```text
D:/Occupation/Porto/genex/La_Voiture/
├── shaders/
│   ├── anime_cel_shaded.gdshader
│   └── inverted_hull_outline.gdshader
├── scripts/
│   └── car/
│       └── modular_car_assembler.gd
├── scenes/
│   ├── car/
│   │   └── base_chassis.tscn
│   ├── vfx/
│   │   └── manga_smoke_emitter.tscn
│   └── test_modular_car.tscn
└── assets/
    └── cars/
        └── porsche_911/
            ├── porsche_911_body.glb
            └── parts/
                ├── splitter_tier1.glb
                ├── splitter_tier2.glb
                ├── wing_tier1.glb
                └── diffuser_tier1.glb
```

---

## 3. Langkah Implementasi Terinci (Step-by-Step Plan)

### Step 1: Implementasi Shader Cel-Shaded & Ink Outlines
- Terapkan kode shader `anime_cel_shaded.gdshader` dan `inverted_hull_outline.gdshader` dari [PRD 04 Bab 4](file:///D:/Occupation/Porto/genex/La_Voiture/PRD/04-RENDERING-SHADERS-VFX.md#L90-L135).
- Atur material pada Godot material slots: Pass 1 = Cel-Shaded, Pass 2 (`next_pass`) = Inverted Hull.

### Step 2: Implementasi `modular_car_assembler.gd` & `base_chassis.tscn`
- Node `BaseChassis` memuat node `MeshInstance3D` bodi utama dan anak-anak `Marker3D`:
  - `Socket_FrontSplitter`: $(0.0, 0.12, 2.15)$
  - `Socket_RearWing`: $(0.0, 1.15, -2.10)$
  - `Socket_Diffuser`: $(0.0, 0.18, -2.25)$
  - `Socket_Wheel_FL/FR`: $(\pm 0.95, 0.35, 1.40)$
  - `Socket_Wheel_RL/RR`: $(\pm 0.95, 0.35, -1.25)$
- Logika `equip_part`: saat part lama diganti, part lama di-`queue_free()` dan part baru di-instansiasi sebagai anak langsung dari socket terkait.

### Step 3: Pembuatan & Pemisahan Part di Blender via MCP
- Panggil Blender MCP (`call_mcp_tool(ServerName: "blender", ToolName: "execute_blender_code")`):
  1. Impor mesh siluet mobil GT3 dari referensi.
  2. Potong geometri pada garis celah bodi: bumper bawah (Splitter) dan dudukan bagasi (Wing).
  3. Tetapkan origin koordinat `(0,0,0)` pada semua objek sebelum diekspor.
  4. Ekspor masing-masing part ke direktori `assets/cars/`.

### Step 4: Partikel Asap Manga 2D (`manga_smoke_emitter.tscn`)
- Buat node `GPUParticles3D` dengan material partikel bertekstur asap arsir manga (`billboard_mode = BILLBOARD_PARTICLES`).
- Hubungkan sinyal selip ban agar emisi aktif hanya saat terjadi pengereman keras atau oversteer.

### Step 5: Validasi Perakitan di `test_modular_car.tscn`
- Buat antarmuka tombol sederhana untuk menukar Splitter Tier 1 $\leftrightarrow$ Tier 2 dan Sayap Belakang Tier 1 $\leftrightarrow$ Tier 2 secara real-time.
- Pastikan tidak ada celah berlubang yang tidak disengaja maupun tumpang tindih poligon (*z-fighting*).

---

## 4. Perintah Verifikasi & Acceptance Test

```powershell
& "C:/Users/Lee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" scenes/test_modular_car.tscn
```
* **Kriteria Keberhasilan:** Window Godot menampilkan mobil GT3 dengan gaya visual Toon Anime dan outline tinta hitam tebal, tombol ganti part bekerja instan tanpa clipping/overlap geometri, dan partikel asap manga muncul saat roda berputar cepat.
