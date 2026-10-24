# LAPORAN EKSEKUTIF FASE 11 / LANGKAH 3B: TEMA WARNA TIM + TELEMETRY DRAWER (KONSEP F)

Spec: `docs/superpowers/specs/2026-10-24-langkah-3-hud-redesign-v2-design.md` (§4.1, §4.2). Rencana: `docs/superpowers/plans/2026-10-24-langkah-3b-team-theme-telemetry-plan.md`. Cabang `feat/langkah-3b-team-theme-telemetry` (bertumpuk di `feat/langkah-3a-pit-mechanics`). Godot 4.7.2 stable, Windows.

## 1. Ringkasan

| Hasil | Detail |
|---|---|
| Warna engineer | `GarageStyle.engineer_for(accent)`: kandidat berurutan cyan, pink, lime, kuning dengan selisih hue > 55°; aksen tak berwarna → cyan. Dipakai kartu radio di 3e |
| Skin tim | `RaceHud.style` (GarageStyle) berisi warna livery tim pemain; `set_team_accent(team_id)` mengecat ulang logo `LA VOITURE`, bar marquee dan teksnya (ink/putih sesuai luminans), header deck |
| Data drawer | `TelemetryState` (tanpa node): nilai mobil, jejak pedal 96 sampel, jejak G 40, tint panas ban, level tangki, ERS, stress/confidence/detak, caption satu baris (prioritas stress > ban kritis > ERS overtake > rem keras > DRS > bersih) dengan efek ketik 42 karakter/detik, onomatope pada tepi naik (maksimum 2, umur 1,6 detik) |
| Gambar drawer | `TelemetryPainter` + `TelemetryDrawer` (satu `_draw`): panel miring pada gutter bertint aksen, speed lines dan halftone, gear dengan kick, hero mobil top-down (ban berisi panas bergelombang, halo, disc rem, tread, tangki, tulang punggung ERS mengalir, panah G dengan jejak, tanda damage), pedal, bar stress/confidence, ECG, jantung berdenyut, caption, onomatope |
| Warna makna | Tidak mengikuti aksen: panas ban, pedal, ERS, gear kuning, DRS, status kritis (dijaga test) |

Kotak drawer tetap `(1598, 372)` `312×496`. Yang dihapus dari drawer lama sesuai spec: strip fuel/ERS, bar LIFE/DMG, teks fuel di bawah mobil.

## 2. File yang berubah

| File | Perubahan |
|---|---|
| `scripts/ui/manga/garage_style.gd` | `PINK`, `ENGINEER_MIN_HUE_GAP`, `engineer`, `engineer_for()` |
| `scripts/hud/race_hud.gd` | `style`, `logo_label`, `marquee_bar`, `marquee_texts`, `set_team_accent()`, `_on_style_changed()`, `drawer.style = style` |
| `scripts/hud/tactical_deck.gd` | `header_shape`, `header_title`, `set_accent()` |
| `scripts/hud/telemetry_state.gd` (baru) | data drawer, onomatope, caption |
| `scripts/hud/telemetry_painter.gd` (baru) | seluruh gambar panel F |
| `scripts/hud/telemetry_drawer.gd` | ditulis ulang (data di `state`, gambar via painter) |
| `tests/test_hud_theme_and_telemetry.gd` (baru, 26 assertion), `tests/test_race_hud.gd` | `_test_drawer` ditulis ulang ke API baru |
| `scratch/capture_langkah3b.gd`, file `.uid` baru | tangkapan layar dan uid yang dibuat Godot |

## 3. Verifikasi

- **29 suite headless (28 + `test_hud_theme_and_telemetry`): semua OK** dengan pembungkus ketat yang gagal bila ada exit ≠ 0, `[FAIL]`, atau `SCRIPT ERROR` (lihat temuan 1 di bagian 4).
- Setiap perilaku baru dilihat gagal lebih dulu (parse error tipe/fungsi belum ada, atau asersi gagal untuk kasus dua ban melewati 125 °C sekaligus).
- Bukti visual native 1920×1080 di `executor-report/screenshots/phases/`: `phase-11-langkah-3b-drawer-team0.png` (lime), `-team2.png` (crimson), `-team7.png` (putih), `-team6.png` (biru), `-events.png` (rem keras, ban kritis, stress tinggi: onomatope `DON!!` dan `JIRI JIRI`, caption `HEART RACING`).

**Tidak dilakukan:** pengukuran frame time 60 FPS belum dilakukan (GPU dipakai bersama proses lain; angka belum sah). Drawer menggambar ±300 primitif per frame hanya saat terlihat dan tidur saat disembunyikan (dijaga test).

## 4. Temuan dan ruling

1. **Suite headless bisa mencetak PASS dan exit 0 walau ada `SCRIPT ERROR`.** Error runtime di dalam argumen `check()` melewatkan asersi itu saja. Jalan keluarnya: pembungkus `runtest.sh` (di workspace, bukan di repo) yang menggagalkan exit ≠ 0, `[FAIL]`, dan `SCRIPT ERROR`. Disarankan menjadikan pemeriksaan ini bagian dari runner proyek; belum ada perubahan di repo.
2. `class_name` baru butuh `godot --headless --path . --import` supaya test mengenalnya; import juga membuat file `.uid` (yang dibuat sesi ini di-commit, termasuk dua milik 3a yang sebelumnya tertinggal).
3. `GarageStyle` tidak punya `class_name`; konsumen mem-preload skripnya.
4. Aturan kontras teks memakai aturan `GarageStyle` yang sudah ada (luminans 0,35), bukan 0,3 dari mockup.
5. Angka kecepatan memakai Anton (mockup memakai Dela Gothic One yang tidak ada di `assets/fonts`; tanpa aset font baru). Hati digambar dari poligon dan lingkaran (glyph ♥ pada font belum diverifikasi). Ketik caption, `shift_time`, dan level tangki (`fuel`) ditambahkan ke `TelemetryState` (rencana tidak menyebutnya; semuanya diuji).
6. Dua ban melewati 125 °C pada sampel yang sama kini menghasilkan satu onomatope (sebelumnya dua, dan menyingkirkan onomatope lain).
7. **Kode mati:** `scripts/hud/telemetry_widgets.gd` dan `scripts/hud/step_bar.gd` bukan buatan sesi ini; hanya `TelemetryWidgets.tyre_tint` dan `PulseTrace.beat` yang masih dipanggil. File dibiarkan; keputusan menghapus ada pada pengguna.
8. Bagian skin yang belum mengikuti aksen (menyusul di 3c–3e sesuai spec): tower, baris rate, tombol dan segmen deck, kartu saran, kartu radio, ribbon cuaca.

## 5. Untuk langkah berikutnya

- `TelemetryState` dan `TelemetryPainter` adalah titik masuk bila deck N2 (3c) perlu data yang sama (kecepatan, ERS, ban).
- `GarageStyle.engineer` siap dipakai kartu radio R2 (3e).
