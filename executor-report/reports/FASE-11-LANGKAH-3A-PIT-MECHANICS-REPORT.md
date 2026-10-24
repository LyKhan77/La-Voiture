# LAPORAN EKSEKUTIF FASE 11 / LANGKAH 3A: PIT MECHANICS

Spec: `docs/superpowers/specs/2026-10-24-langkah-3-hud-redesign-v2-design.md` (§4.5, §6). Rencana: `docs/superpowers/plans/2026-10-24-langkah-3a-pit-mechanics-plan.md`. Cabang `feat/langkah-3a-pit-mechanics`. Godot 4.7.2 stable (Forward+ / D3D12), Windows.

## 1. Ringkasan

| Hasil | Detail |
|---|---|
| Desk | `GtTypes.TacticMode { MANUAL, AUTO }`; HYBRID dihapus; default MANUAL |
| Jendela saran | `GtRace.SUGGESTION_WINDOW_S = 10.0` detik waktu balapan, dihitung di sim (deterministik). MANUAL menutup kartu saat habis, AUTO mengeksekusinya (kecuali mobil sudah boxing) |
| Advisor | `_check_advisor_tactics()` jalan di semua mode; `decide_strategy` kini menghasilkan kartu untuk mobil pemain di MANUAL dan AUTO |
| Cancel box | `GtRace.cancel_pit(car_id)` dan `RaceWeekendWorld.cancel_pit(car_id)`; tanpa penalti; radio `Stay out, stay out! Box call cancelled.`; cooldown 30 s untuk saran PIT berikutnya |
| Tombol BOX | Dua-state: `REQUEST BOX [B]` ↔ `CANCEL BOX [ESC]  //  <COMPOUND>` (crimson, tetap bisa diklik); `IN THE PIT LANE` / `RETIRED` / `CHEQUERED` terkunci |
| Kartu saran | Bar api 10 detik (kuning → oranye → crimson) + label `10.0s` → `00.0s`; di bawah 3.0 s `card_critical` aktif dan label/bar berkedip (menghormati `reduce_motion`) |
| Keyboard | `B` request, `ESC` (tutup kartu, lalu batalkan box, lalu tidak dikonsumsi sehingga `timing_tower.gd` tetap menerima `ui_cancel`), `ENTER` terima kartu |
| Tag desk | `MODE: MANUAL // 100% PLAYER DIRECTIVE` / `MODE: AUTO // AI ENGINEER ASSISTED` di bawah baris DESK |

Posisi dan ukuran seluruh kotak HUD tidak berubah.

## 2. File yang berubah

| File | Perubahan |
|---|---|
| `scripts/gt/gt_types.gd` | enum `TacticMode` tanpa HYBRID |
| `scripts/gt/gt_race.gd` | default MANUAL, `SUGGESTION_WINDOW_S`, `suggestion_remaining()`, `_expire_suggestion()`, `cancel_pit()`, `_check_advisor_tactics()`, `decide_strategy()` |
| `scripts/world/race_weekend_world.gd` | `cancel_pit()` |
| `scripts/hud/tactical_deck.gd` | desk dua opsi, `desk_status`, `on_box_pressed()`, `cancel_box()`, gaya CANCEL |
| `scripts/hud/race_hud.gd` | bar api, `card_timer`, `card_critical`, `burn_color()`, `burn_text()`, keybind B/ESC/ENTER, teks marquee |
| `tests/test_pit_deck_and_radio.gd` | suite baru, 25 assertion (radio dua arah menyusul di 3e) |
| `tests/test_gt_sim.gd`, `tests/test_race_hud.gd` | skenario HYBRID ditulis ulang untuk MANUAL/AUTO dan tombol CANCEL BOX |
| `PRD/00`, `PRD/02`, `PRD/07`, `ROADMAP.md` | sebutan HYBRID dihapus, status 3a |

## 3. Verifikasi

- **28 suite headless (27 lama + `test_pit_deck_and_radio`): semua exit 0**, tanpa `[FAIL]` dan tanpa `SCRIPT ERROR` di seluruh log. `test_race_world` dan `test_simulation_verification` menutup dengan baris `ALL PASS` / `ALL CORE MODEL ASSERTIONS VERIFIED` (bukan baris `PASS` berformat sama).
- `test_gt_sim.gd` (termasuk `_test_determinism`: seed sama, balapan sama) tetap hijau.
- Setiap test baru dilihat gagal lebih dulu: Task 1 (parse error karena `SUGGESTION_WINDOW_S` belum ada), Task 2 (`cancel_pit` tidak ada), Task 3 (6 asersi gagal), Task 4 (parse error `burn_text`).
- Bukti visual native 1920×1080 (`scratch/capture_langkah3a.gd`), di `executor-report/screenshots/phases/`:
  `phase-11-langkah-3a-deck-request-box.png`, `-deck-cancel-box.png` (tombol crimson `CANCEL BOX [ESC] // WET`), `-card-burn-full.png`, `-card-burn-low.png` (bar oranye, `04.0s`), `-card-burn-critical.png`, `-desk-auto.png`.

**Tidak dilakukan:** smoke test penuh 3 lap 20 mobil sampai podium dan pengukuran frame time 60 FPS tidak dijalankan di langkah ini (hanya sesi tangkapan layar di dunia balapan). Perubahan 3a tidak menambah beban per frame selain satu `ColorRect` dan satu `Label` yang diperbarui saat kartu tampil; pengukuran FPS menyusul bersama 3b–3e.

## 4. Keputusan dan ruling

1. **Cabang fitur, bukan git worktree** (proyek Godot dengan cache `.godot` dan aset LFS membuat worktree berat).
2. **Perilaku MANUAL/AUTO berubah dari sim lama** (sebelumnya MANUAL diam, AUTO langsung memanggil pit tanpa kartu, HYBRID = kartu): lihat spec §6. Dikonfirmasi pengguna.
3. **Timer di sim, bukan di HUD** agar seed sama menghasilkan balapan sama. Akibat: pada time scale 4×–16× jendela 10 detik waktu balapan menjadi jauh lebih pendek di dunia nyata. Tidak diubah di 3a.
4. **Asersi pacing Task 2 diubah:** rencana menulis `v > 50` setelah 80 tick, tetapi tikungan setelah pit entry mengerem semua mobil ke 36.8 m/s (mobil kontrol tanpa request berakhir identik). Mekanik terbukti dengan puncak kecepatan: 38.0 m/s tertahan lalu 51.6 m/s setelah cancel; asersi memakai `peak > 45`.
5. **Kedip border kartu tidak diimplementasikan:** border dimiliki `UI.surface`, dan gaya kartu didesain ulang di 3c. Di keadaan kritis label bergantian crimson/putih dan bar memudar.
6. `test_race_hud.gd:180` (HYBRID → MANUAL) dipindah ke Task 1 agar suite tetap bisa di-parse.
7. Test memakai pola proyek (`tests/test_*.gd` headless), bukan gdUnit4 seperti di `.claude/rules/test-standards.md`.

## 5. Catatan untuk langkah berikutnya

- `scratch/capture_langkah3a.gd` bisa dipakai ulang sebagai kerangka tangkapan 3b–3e.
- Saran baru dari advisor dapat menggantikan kartu terbuka di tengah jendela dan memulai ulang bar dari 10.0 s (disengaja, dicakup test).
