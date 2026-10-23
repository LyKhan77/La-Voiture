# FASE 8.5 — Visual Polish, Graffiti VFX, Concept 01 UI & Graphics Consistency

**Engine:** Godot 4.7.2 stable · **Branch:** `main` · **Suite baru:** `tests/test_visual_polish_and_consistency.gd` (17 assertions)

## 1. Lampu kendaraan (tanpa SphereMesh)

| Item | Hasil |
| :--- | :--- |
| `SphereMesh` di `race_vfx.gd` | Dihapus. Test menghitung 0 `SphereMesh` di seluruh 20 aktor (sebelumnya 40). |
| Lampu depan/belakang | Slab emisif tipis (`BoxMesh`) di `Chassis/Lamps`, dipasang dari batas AABB bodi tiap sasis, ikut roll/pitch bodi. Grup "Tail" / "Head" disembunyikan saat energinya 0. |
| Lampu rem reaktif | `GtCarActor.taillight_energy`: 6.5 saat `brake > 0.05` atau `longitudinal_g < -0.5` (naik 18 energi/detik), 1.2 saat malam/hujan, 0 siang. |
| Cahaya ke aspal | Sepasang `SpotLight3D` per mobil (range 45 m, sudut 32°, energi 0.55 × energi lampu = 2.2 malam), tanpa shadow, `no_shadow` meta, `distance_fade` 70–90 m agar 40 spot tidak membebani GPU. |

## 2. Suite VFX graffiti

| Efek | Implementasi |
| :--- | :--- |
| Manga speedlines | `RaceHud.MangaSpeedlines` (`ColorRect` di `CanvasLayer` 5, `manga_speedlines.gdshader`). Intensitas = `clamp((km/h − 200) / 80)`; 1.0 selama ERS `OVERTAKE`. 252 km/h → 0.65. |
| Boost warp | `BroadcastCameraDirector.punch_fov()`: +3.5° dalam 0.08 s (expo-out), kembali dalam 0.35 s (smoothstep). Dipicu HUD saat mobil yang diikuti masuk `OVERTAKE`. |
| Kerb strike sparks | `GPUParticles3D` "KerbSparks" per mobil: 18 streak acid-lime → oranye, lifetime 0.22 s, aktif bila `v > 35 m/s` dan `|lateral| > 5.2 m` (ambang kerb yang sama dengan audio kerb). |
| Backfire graffiti | Cangkang acid-yellow `#D8FF00` + inti crimson `#FF1A4B`, 0.12 s pada setiap pergantian gigi (naik maupun turun) dan lift-off; kemiringan & skala diacak per letupan. |
| Brake rotor glow | Sudah ada sejak Fase 5.7 (`BRAKE_GLOW_G = 1.5`, fall 1.2/s); tidak diubah. |

## 3. Main menu Concept 01

Judul "LA VOITURE" Anton 156 pt, `rotation = -0.21`, outline 14 px, bayangan hitam (+6,+6) dan tepi acid (−3,−1); `SprayHalo` (inti lime 140 px / halo crimson 280 px) di belakangnya; subtag `/// GT3 // RACING SYNDICATE // TOON MOTORSPORT`.
Tombol: `StyleBoxFlat.skew` −0.21, border 4 px, bayangan solid 6 px, awalan `/// `. Hover/fokus: geser (+6, −2) seketika, latar → acid lime, teks → hitam, bayangan → crimson (8 px); kembali dalam 0.12 s. Modal credits/quit miring −4° dengan lencana crimson `SYS // …`.

Bukti: `screenshots/phases/fase-8.5-main-menu.png`, `fase-8.5-main-menu-hover.png`.

## 4. Konsistensi showroom ↔ balapan

`GarageEnvironmentBuilder._instantiate_car()` kini memuat sasis balap (`GtCarActor.CHASSIS_BY_TEAM` / `BASE_CHASSIS`) dengan roda medium, bukan `*_full.glb`. Material bodi = material balapan (toon_car_paint untuk 9 mobil, anime_cel_shaded untuk Porsche) lengkap dengan `next_pass` inverted-hull. `PresentationSettings.apply_to_tree()` sudah menelusuri `next_pass`; test membuktikan lebar tinta LOW 0.007 m → ULTRA 0.020 m di showroom. Tidak ada perubahan di `presentation_settings.gd`.
Semua 10 sasis `keeps_original_paint = true`, sehingga tidak ada tint livery tambahan.

## 5. Keputusan (rulings)

1. **Speedlines:** rumus rencana (220→290 km/h) hanya memberi 0.46 pada 252 km/h, padahal acceptance meminta > 0.5 di atas 240 km/h. Dipakai ramp 200→280 km/h (240 km/h = 0.5, 252 = 0.65).
2. **FOV punch:** rencana menyebut basis 42°; lensa chase sebenarnya 70°. Punch bersifat aditif di atas FOV mode kamera mana pun.
3. **Kerb:** ambang `|d| > 2.8 m` berada di tengah lintasan (lebar 14 m, batas pakai 5.4 m) dan akan memercikkan api di racing line; dipakai `SpatialCarAudio.KERB_LATERAL_M = 5.2`.
4. **Lampu:** sasis tidak punya permukaan lampu tersendiri (lampu dilukis di tekstur), jadi dibuat slab emisif dari batas bodi. `race.is_night` tidak ada; RaceVfx mengirim `actor.night_lights` (energi lampu dari cuaca/malam/hujan).
5. **`test_main_menu_flow.gd`:** asersi `*_full.glb` per stall diubah ke path sasis balap karena kontrak showroom memang berubah.
6. **Warna awalan `/// `:** teks `Button` satu warna; awalan tidak diwarnai lime terpisah (aksen dibawa tab miring di kiri tombol).

## 6. Verifikasi

Lihat bagian "Hasil 25 suite" di bawah.

## 7. Hasil 25 suite

`godot --headless` untuk setiap `tests/test_*.gd`: **25/25 PASS, 0 FAIL** (termasuk `test_visual_polish_and_consistency.gd` 17/17 dan `test_main_menu_flow.gd` 64/64).

Bukti visual: `screenshots/phases/fase-8.5-*.png` (menu, hover, balap malam, speedlines + kerb sparks, close-up lampu 4 tim).

## 8. Batas yang diketahui

- Tekstur sebagian sasis sudah melukis lampu sendiri; strip LED emisif berada tepat di bawahnya, bukan menggantikan lukisan itu.
- Speedlines di `CanvasLayer` 5 sesuai spesifikasi, sehingga garisnya melintasi panel HUD.
- Smoke test native 3 lap 20 mobil dan hitungan orphan node belum dijalankan di sesi ini; hanya headless + capture visual.
- Review akhir dilakukan sendiri oleh penulis (tanpa subagent).
