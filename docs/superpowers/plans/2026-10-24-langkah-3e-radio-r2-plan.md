# Langkah 3e: Radio R2 "Wheatpaste Collage" Dua Arah Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dua cut-in radio (driver, engineer) tampil sebagai kartu kertas tempel R2 (sobek, bertape, halftone, teks Anton kapital dengan kata kunci disorot, potret stiker miring), driver kiri-atas dalam warna tim dan engineer kanan-tengah dalam warna komplementer; yang bicara menyala, lawan bicara meredup, kartu masuk dengan tamparan; dan sim menjadwalkan balasan engineer 2.5 s setelah panggilan kritis driver.

**Architecture:** Sim: tabel murni `GtRadioReplies` + antrean balasan di `GtRace` (waktu sim, deterministik) + satu pemicu banjir baru. UI: `anime_radio_cutin.gd` digambar ulang ke gaya R2 tanpa mengubah kontrak yang dipakai test lama (`banner`, `speech`, `_hold`, `HOLD_SEC`, `_portrait_texture`, `_hide_banner`, `layer == 30`, `play_radio`, `set_portrait`, `set_dock`, sinyal `transmission_shown/finished`, `soundwave_*`); `RaceHud` memberi warna, potret yang di-preload, dan status talk/dim.

**Tech Stack:** Godot 4.7.2 stable, GDScript 2.0 (static typing wajib), test headless `SceneTree` lewat `runtest.sh` yang menolak `SCRIPT ERROR` dan `[FAIL]`.

**Spec:** `docs/superpowers/specs/2026-10-24-langkah-3-hud-redesign-v2-design.md` §4.6 (dan §3 layout lock, §10). Acuan visual: `docs/design-refs/ui_step_4_hud_discussion.html` (bagian 4, CSS `.r2`, `.rc`, `.rc-text`, `.rc-wave`, animasi `slap`). Pemicu contoh: spec lama `docs/superpowers/specs/2026-10-24-langkah-3-tactical-deck-and-radio-design.md` §2D (angka dan kalimat di bawah sudah disesuaikan dengan sim).

## Global Constraints

- Radio dock (area kartu) tetap `(352, 88, 1230×790)`; kartu **470×190** (tinggi bertambah bila teks panjang, tetap di dalam dock). Tidak ada kotak HUD lain yang bergeser.
- Dua arah: driver kiri-atas dock, miring **−2°**, warna = `message["team_color"]` mobil yang bicara; engineer kanan-tengah dock, miring **+1.6°**, warna = `GarageStyle.engineer` (komplementer aksen tim pemain, sudah ada dari 3b). Panggilan `urgent` memakai kertas crimson seperti sekarang. Teks di atas kertas gelap memakai putih (ambang luminans 0.35 seperti `GarageStyle.on_accent`), selain itu ink `#050505`.
- Yang bicara: opasitas 1.0, skala penuh. Lawan bicara (kartu satunya, bila sedang tampil): `modulate` `(0.75, 0.75, 0.75, 0.6)` dan skala ×0.95. Dim adalah keadaan, bukan gerak (tetap berlaku di `reduce_motion`).
- Masuk dengan tamparan: dari skala ×1.55 dan rotasi −9° (driver; engineer +9°) ke skala dan tilt istirahat dalam **0.45 s**, opasitas 0→1 di 55 % pertama. Tahan `HOLD_SEC = 3.5` (atau lama klip suara), lalu fade keluar **1.8 s** (`FADE_OUT_SEC`). `PresentationSettings.reduce_motion`: tanpa tamparan dan tanpa fade bertahap (langsung ke posisi/tilt istirahat, hilang tanpa animasi); suara dan teks tetap.
- Teks: Anton (`UI.DISPLAY`) **30 px**, kapital, kata kunci disorot blok ink berisi teks berwarna kertas: `BOX`, `WET`, `WETS`, `INTER`, `INTERS`, `TYRES`, `TYRE`, `PIT`, `SLICKS`, `FUEL`, `ERS`, `DRS`, `PUNCTURE`, `CLIFF`, `OVERTAKE`, hanya kata utuh (`BOXING` tidak disorot). `speech.text` tetap teks biasa (kontrak test); sorotan memakai `RichTextLabel` terpisah.
- Bar suara: **12** gerigi segitiga ink naik-turun (`WAVE_BARS` 14 → 12), energi dari `soundwave_energy()` yang sudah ada.
- Balasan sim: hanya untuk tim pemain (tidak untuk rival), **2.5 s waktu sim** setelah panggilan driver yang punya balasan; deterministik (hanya `race.time` dan keadaan mobil saat balasan jatuh tempo); tidak memakai RNG UI. Pesan balasan punya kunci `reply_to` (id pesan driver); `urgent` false.
- Potret: 20 potret driver di-preload saat `RaceHud.bind` (tidak ada `load()` saat balapan); file hilang → `PORTRAIT` bawaan, tanpa crash.
- Audio (squelch, ducking, klip suara) tidak berubah; `transmission_shown/finished` tetap sekali per pesan.
- Fade keluar 1.8 s memperpanjang waktu hilangnya kartu dari ±3.7 s ke ±5.3 s: `tests/test_pit_wall.gd` yang menunggu 4.0 s untuk `not radio.banner.visible` ditambah menjadi 6.0 s (ruling, kontrak waktu berubah).
- Sim deterministik: `race_seed` yang sama → daftar pesan (id, teks, waktu) identik. Commit trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; hanya `git add` file yang disebut; class baru butuh `godot --headless --path . --import` dan `.uid`-nya ikut di-commit. Satu instance Godot sekaligus.

## Review Focus

1. Driver rival tidak pernah memicu balasan engineer; hanya mobil tim pemain. Dua panggilan driver berurutan (snap oversteer lalu tyres cooked dalam 2 s): kedua balasan tetap datang berurutan, tidak ada yang hilang, kartu pengganti tidak meninggalkan keadaan dim yang macet. (Task 1, 3)
2. Balasan untuk mobil yang sudah pit/DNF/finis saat jatuh tempo: teks tetap valid, tidak crash, tidak membagi nol. (Task 1)
3. `reduce_motion`: tanpa tamparan, rotasi bertahap, atau fade bertahap; kartu tetap muncul di tilt istirahat dan hilang. (Task 3)
4. Potret hilang atau mobil tanpa file potret: kartu tetap tampil dengan potret bawaan. (Task 3)
5. Teks panjang (±120 karakter, mis. "Suspension has snapped from the flat tyre! I can't continue...") membuat kartu lebih tinggi tetapi tetap di dalam dock; dua kartu tidak saling menutupi teks. (Task 2, 3)
6. Ducking musik tidak macet: tiap `transmission_shown` punya `transmission_finished`, termasuk saat kartu diganti di tengah tampil. (Task 3)

## File Structure

- Create `scripts/gt/gt_radio_replies.gd` — `class_name GtRadioReplies`: tabel balasan.
- Modify `scripts/gt/gt_race.gd` — antrean balasan, pemicu banjir, `reply_to`.
- Create `scripts/ui/radio_markup.gd` — `class_name RadioMarkup`: sorotan kata kunci dan pilihan warna tinta.
- Modify `scripts/ui/anime_radio_cutin.gd`, `scenes/pit_wall/anime_radio_cutin.tscn` — gaya R2, dim, tamparan, tempat.
- Modify `scripts/hud/race_hud.gd` — warna, potret ter-preload, talk/dim.
- Modify `tests/test_pit_deck_and_radio.gd` (radio dua arah), `tests/test_pit_wall.gd` (menunggu 6.0 s); create `tests/test_radio_r2.gd`.
- Create `scratch/capture_langkah3e.gd`, `executor-report/reports/FASE-11-LANGKAH-3E-RADIO-R2-REPORT.md`, `executor-report/screenshots/phases/phase-11-langkah-3e-*.png`; modify `ROADMAP.md`.

---

### Task 1: Balasan engineer dan pemicu banjir di sim

**Files:**
- Create: `scripts/gt/gt_radio_replies.gd`
- Modify: `scripts/gt/gt_race.gd` (`push_radio`, `step`, antrean, pemicu banjir)
- Test: `tests/test_pit_deck_and_radio.gd` (`_test_two_way_radio()`)

**Interfaces:**
- Produces: `class_name GtRadioReplies extends RefCounted`: `static func reply_for(text: String, car: GtCar, water_pct: float) -> String` (`""` bila tak ada balasan). Tabel (awalan teks driver → balasan; `%s` nama pendek `car.driver_name`'s kode `car.code`, `%d` persen):
  - `"Had a snap of oversteer"` → `"Copy %s, stay on it. Rear tyres at %d%%, watch the exit."` (`car.code`, `roundi(car.wear * 100)`)
  - `"Tyres are cooked"` → `"Copy %s, tyres at %d%%. Manage the pace, the box call is yours."`
  - `"Track is flooding"` → `"Understood %s, water at %d%%. Box for WETS when you are ready."` (`water_pct`)
  - `"Puncture"` → `"Copy %s, limp it back to the pits, box box box."`
- Produces pada `GtRace`: `const RADIO_REPLY_DELAY_S: float = 2.5`; pesan radio mendapat kunci `"reply_to": int` (-1 bila bukan balasan); `push_radio(car, speaker, text, force = false, rival = false, reply_to: int = -1)`; pemicu banjir: tiap tick, mobil tim pemain di ban slick dengan `weather.track_water_pct > GtForecast.WET_WATER_PCT` yang belum ditandai dan `can_push_driver_radio` → driver `"Track is flooding, aquaplaning heavily!"` sekali; tanda dihapus bila `track_water_pct < GtForecast.INTER_WATER_PCT`.
- Consumes: `GtForecast.WET_WATER_PCT`, `INTER_WATER_PCT`, `GtTypes.is_slick`.

- [ ] **Step 1: Tulis test gagal `_test_two_way_radio()`** (dunia balap seperti test lain di file itu; tangkap pesan lewat `race.radio_message.connect`; satu tick = `GtTypes.TICK_DT`):
  - Snap oversteer pada mobil tim pemain: `race.push_radio(car, "driver", "Had a snap of oversteer! Lost some time.")`; setelah 2.4 s sim (`race.step_ticks(ceili(2.4 / GtTypes.TICK_DT))`) belum ada pesan engineer; setelah total 2.6 s tepat satu pesan engineer: `reply_to == id pesan driver`, teks diawali `"Copy "`, memuat `"%"`, `urgent == false`: "radio: a driver call gets one engineer reply 2.5 s later".
  - Driver rival (`car.team_id != race.player_team_id`) dengan teks yang sama dan `rival = true`: setelah 3 s tidak ada balasan: "radio: a rival driver call gets no engineer reply".
  - Dua panggilan berurutan (snap pada t, `"Tyres are cooked! Rear is sliding everywhere!"` pada t + 1 s dengan `force = true` agar melewati cooldown): dua balasan, urutan sesuai, selisih waktu ≈ 1 s: "radio: two driver calls in a row keep both replies in order".
  - Balasan untuk mobil yang jadi DNF atau `pit != null` sebelum jatuh tempo tetap datang dengan teks valid (tidak kosong, tanpa `%` mentah): "radio: a reply for a car that retired meanwhile is still valid".
  - Banjir: `race.weather.track_water_pct = 60.0`, mobil pemain di MEDIUM: setelah 1 tick tepat satu pesan driver berawalan `"Track is flooding"`; 100 tick lagi tidak ada pesan banjir kedua; balasan engineer (setelah 2.6 s) memuat `"WETS"` dan `"60%"`; air diturunkan ke 5 % lalu dinaikkan lagi ke 60 % (cooldown driver dikosongkan lewat `race.driver_radio_cooldown.clear()`) → pesan banjir kedua: "radio: flooding is called once per episode and answered".
  - Mobil di ban WET tidak memicu banjir: "radio: a car already on wets does not call the flood".
  - Deterministik: dua dunia dengan `race_seed` sama, panggilan sama → daftar `(text, time)` pesan identik: "radio: replies are deterministic".
- [ ] **Step 2: Jalankan, pastikan gagal** (`runtest.sh test_pit_deck_and_radio`; parse error `GtRadioReplies`/argumen `reply_to`).
- [ ] **Step 3: Implementasi** sesuai Interfaces: `push_radio` mengisi `reply_to` dan, bila `speaker == "driver"`, mobil tim pemain, bukan `rival`, dan `reply_for(...)` tidak kosong, menambah `{"due": time + RADIO_REPLY_DELAY_S, "car_id", "reply_to": id pesan, "driver_text"}` ke `_pending_replies`; satu fungsi `_flush_replies()` dipanggil di `step` setelah `_tick_driver_radio_cooldowns(dt)` yang mengirim balasan yang jatuh tempo (teks dihitung saat jatuh tempo dari keadaan mobil saat itu) lewat `push_radio(car, "engineer", text, false, false, reply_to)`; `_check_flood_radio()` di `step`.
- [ ] **Step 4: Jalankan** `runtest.sh test_pit_deck_and_radio test_gt_sim test_race_world test_audio_and_race_weekend`. Expected: OK (suite lama tidak peka terhadap pesan tambahan; bila ada yang peka, catat ruling dan sesuaikan asersinya).
- [ ] **Step 5: Commit** `git add scripts/gt/gt_radio_replies.gd scripts/gt/gt_radio_replies.gd.uid scripts/gt/gt_race.gd tests/test_pit_deck_and_radio.gd` / `feat(radio): engineer replies 2.5 s after a driver call and a flood call`.

---

### Task 2: Kartu R2 (gambar, sorotan, ukuran)

**Files:**
- Create: `scripts/ui/radio_markup.gd`
- Modify: `scripts/ui/anime_radio_cutin.gd`, `scenes/pit_wall/anime_radio_cutin.tscn`
- Test: `tests/test_radio_r2.gd`

**Interfaces:**
- Produces: `class_name RadioMarkup extends RefCounted`: `const KEYWORDS: Array[String]` (daftar di Global Constraints); `static func highlight(text: String, paper: Color, ink: Color) -> String` (teks sudah kapital; membungkus tiap kata kunci utuh `"[bgcolor=#%s][color=#%s]%s[/color][/bgcolor]"` dengan hex warna `ink` sebagai latar dan `paper` sebagai teks); `static func ink_for(paper: Color) -> Color` (putih bila luminans < 0.35, selain itu `#050505`).
- Produces pada `anime_radio_cutin.gd`: `const BANNER_WIDTH := 470.0`, `BANNER_MIN_HEIGHT := 190.0`, `SPEECH_SIZE := 30`, `WAVE_BARS := 12`, `FADE_OUT_SEC := 1.8`, `SLAP_SEC := 0.45`, `REST_TILT_DEG` (driver −2.0, engineer 1.6); `var base_color: Color` (warna kertas bila bukan urgent; default lama: lime driver, cyan engineer) dengan `func set_base_color(color: Color) -> void`; `var rich: RichTextLabel` (teks tersorot, di atas `speech` yang tidak terlihat tapi tetap berisi teks biasa); `func paper_polygon(size: Vector2) -> PackedVector2Array` (≥ 16 titik tak beraturan di dalam `Rect2(Vector2.ZERO, size)`), `func tape_rects() -> Array[Rect2]` (2 pita); `var dimmed: bool` dengan `func set_dimmed(value: bool) -> void`.
- Gambar (`_draw_backdrop` diganti): lembar bayangan hitam berputar 2.5° di belakang, kertas poligon sobek berwarna `_accent`, halftone multiply (tile yang ada), kilau diagonal putih α 0.22, dua pita kuning α 0.82 (kiri-atas miring −4°, kanan-bawah miring +5°), potret = stiker die-cut (bingkai putih 5 px, tilt ±6°, di sudut luar kartu); bar suara 12 gerigi segitiga ink. Semua digambar di `_backdrop`/`_wave_layer` yang sudah ada (tanpa node per elemen).

- [ ] **Step 1: Tulis test gagal** `tests/test_radio_r2.gd` (kerangka `SceneTree`, memakai `AnimeRadioCutIn` scene dan `await process_frame`):
  - `RadioMarkup.highlight("BOX THIS LAP, CONFIRM WET TYRES. BOXING IS NOT A CALL", Color.RED, Color("#050505"))` menyorot tepat `BOX`, `WET`, `TYRES` (3 pembungkus), `BOXING` tidak; `ink_for(Color("#101820")) == Color.WHITE` dan `ink_for(Color("#CCFF00")) == Color("#050505")`: "radio r2: keywords are highlighted whole-word and ink follows the paper".
  - Kartu driver: `play_radio(3, "Box this lap, confirm WET tyres.")` → `speech.text` tetap `"Box this lap, confirm WET tyres."` (plain), `rich.text` memuat `[bgcolor=` dan huruf kapital, `rich` memakai font Anton 30; `paper_polygon(Vector2(470, 190)).size() >= 16` dan semua titiknya di dalam rect; `tape_rects().size() == 2`; `WAVE_BARS == 12`: "radio r2: the card is paper with tape and a highlighted headline".
  - `set_base_color(Color("#FF1E56"))` lalu `play_radio(..., false)` → `_accent == Color("#FF1E56")`; `urgent = true` → `_accent == ACCENT_ANIME_CRIMSON`: "radio r2: the paper takes the speaker's colour, urgent calls are crimson".
  - `set_dimmed(true)` → `banner.modulate.a == 0.6` dan `banner.scale` ≈ `dock_scale * 0.95`; `set_dimmed(false)` memulihkan: "radio r2: the listener dims and recovers".
  - Teks 120 karakter: `_banner_h > BANNER_MIN_HEIGHT` dan `_banner_h <= viewport tinggi`; teks pendek: `_banner_h == BANNER_MIN_HEIGHT`: "radio r2: long calls make the card taller, short ones keep 470x190".
- [ ] **Step 2: Jalankan, pastikan gagal** (`runtest.sh test_radio_r2`; kelas/anggota belum ada).
- [ ] **Step 3: Implementasi** sesuai Interfaces; pertahankan semua nama/sinyal yang dipakai test lama (lihat Architecture); `speech` dijadikan tak terlihat (`modulate.a = 0`, tetap dihitung ukurannya), `rich` mengisi teks `RadioMarkup.highlight(message.to_upper(), _accent, ink)`; ukuran kartu dihitung dari teks Anton 30 px (`get_multiline_string_size`); `_play()` memakai `base_color` bukan konstanta lime/cyan; ubah `.tscn` hanya bila perlu (anak `rich` dibuat dari kode).
- [ ] **Step 4: Jalankan** `runtest.sh test_radio_r2 test_radio_and_podium test_pit_wall test_audio_and_race_weekend test_race_hud` (`test_pit_wall`: ubah tunggu 4.0 s menjadi 6.0 s dan catat ruling). Expected: OK.
- [ ] **Step 5: Commit** `git add scripts/ui/radio_markup.gd scripts/ui/radio_markup.gd.uid scripts/ui/anime_radio_cutin.gd scenes/pit_wall/anime_radio_cutin.tscn tests/test_radio_r2.gd tests/test_radio_r2.gd.uid tests/test_pit_wall.gd` / `feat(radio): wheatpaste R2 card with highlighted headline`.

---

### Task 3: Dua arah di HUD (tamparan, talk/dim, tempat, warna, potret)

**Files:**
- Modify: `scripts/ui/anime_radio_cutin.gd` (masuk tamparan, fade keluar, tempat di dock, tilt), `scripts/hud/race_hud.gd` (`_on_radio`, `bind`)
- Test: `tests/test_radio_r2.gd` (`_test_two_way_hud()`), `tests/test_pit_deck_and_radio.gd`

**Interfaces:**
- Consumes: Task 1 (pesan `reply_to`), Task 2 (`set_base_color`, `set_dimmed`, `REST_TILT_DEG`, `FADE_OUT_SEC`, `SLAP_SEC`).
- Produces: `RaceHud._portraits: Dictionary` (car_id → `Texture2D`, 20 entri, diisi di `bind`); `func _portrait_for(car_id: int) -> Texture2D` (cache, `PORTRAIT` bila file hilang); di `_on_radio`: `radio.set_base_color(message["team_color"])` untuk driver, `engineer_radio.set_base_color(style.engineer)`; saat satu kartu menampilkan pesan, kartu lain `set_dimmed(true)` (bila sedang `_present`), kartu yang bicara `set_dimmed(false)`; saat `transmission_finished`, kartu lawan `set_dimmed(false)`. Tempat (koordinat dock di stage): driver `(dock.x + 28, dock.y + 28)`, engineer `x = dock.end.x − 28 − lebar kartu`, `y = dock.y + dock.height × 0.42`; keduanya di dalam dock dan tidak saling menimpa bila tinggi total ≤ dock.
- Animasi masuk: `pivot_offset` di tengah kartu; mulai `scale = dock_scale × 1.55`, `rotation_degrees = ∓9`, `modulate.a = 0`; tween `SLAP_SEC` (`TRANS_BACK`, `EASE_OUT`) ke skala/tilt istirahat, alpha 1 dalam 0.55 × `SLAP_SEC`; tahan `_hold`; fade `modulate.a` ke 0 selama `FADE_OUT_SEC`; `reduce_motion` → nilai istirahat langsung, hilang tanpa tween. Kartu pengganti saat masih tampil: tidak mengulang tamparan (langsung istirahat), `transmission_finished` dipancarkan sekali untuk kartu yang diganti.

- [ ] **Step 1: Tulis test gagal `_test_two_way_hud()`** (dunia balap; `hud.radio`, `hud.engineer_radio`):
  - Driver bicara: `race.push_radio(player_car, "driver", "Had a snap of oversteer! Lost some time.", true)` → `hud.radio.banner.visible`, `hud.radio.dimmed == false`, `hud.radio._accent == player_car.color` (atau crimson bila urgent: gunakan `force = false` dengan `can_push_driver_radio`), `hud.radio.banner.rotation_degrees` mendekati −9 sesaat setelah mulai (tamparan) dan `banner.scale.x > dock_scale * 1.4`; setelah `hud.radio._settle()` (anggota uji yang melompati tween ke nilai istirahat) rotasi −2.0 dan skala = skala dock: "hud radio: the driver card slaps in and settles at its tilt".
  - Engineer menjawab: pesan engineer → `hud.engineer_radio` terang, `hud.radio.dimmed == true`, `hud.engineer_radio._accent == hud.style.engineer`, rotasi istirahat +1.6: "hud radio: the speaker is lit and the other card dims".
  - `hud.radio._hide_banner()` (kartu driver selesai) → `hud.engineer_radio.dimmed == false`: "hud radio: the dim ends with the other card".
  - Tempat: driver `banner.position` di dalam dock dan kiri-atas, engineer di kanan dan `y` ≈ `dock.y + 0.42 × dock.height`; `Rect2` keduanya (dengan tinggi kartu) tidak berpotongan dan berada di dalam dock: "hud radio: the cards sit at the two ends of the dock without overlapping".
  - Potret: `hud._portraits.size() == 20`; `hud.radio._portrait_texture` untuk pembicara tertentu sama dengan `hud._portraits[car_id]`; `_portrait_for(9999)` mengembalikan `PORTRAIT` tanpa error: "hud radio: portraits are preloaded and a missing one falls back".
  - `reduce_motion = true`: `radio.play_radio(...)` → `banner.scale` = skala dock dan rotasi = tilt istirahat segera (tanpa tamparan); `_hide_banner()` menyembunyikan tanpa tween: "hud radio: reduce motion skips the slap and the fade".
  - Rantai driver → engineer lewat sim: `push_radio` snap, `step_ticks` 2.6 s, lalu `radio_audio`/`transmission_shown` tercatat 2 kali dan `transmission_finished` kemudian 2 kali setelah kedua `_hide_banner()` (tidak ada ducking macet: `director.is_transmitting() == false`; gunakan anggota yang dipakai test audio): "hud radio: a driver call and its reply each key and release the radio once".
  - Kartu diganti di tengah tampil: dua `play_radio` berturut-turut pada kartu yang sama → `transmission_shown` 2×, `transmission_finished` tidak lebih dari 2×, tidak macet.
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasi** sesuai Interfaces; tambahkan anggota uji `_settle()` pada cut-in (men-skip tween ke nilai istirahat, dipakai test saja); `fit()`/`set_dock` memberi posisi per peran.
- [ ] **Step 4: Jalankan** `runtest.sh test_radio_r2 test_pit_deck_and_radio test_radio_and_podium test_audio_and_race_weekend test_race_hud test_pit_wall`. Expected: OK.
- [ ] **Step 5: Commit** `git add scripts/ui/anime_radio_cutin.gd scripts/hud/race_hud.gd tests/test_radio_r2.gd tests/test_pit_deck_and_radio.gd` / `feat(radio): two-way R2 cards with slap entry, talk and dim`.

---

### Task 4: Regresi, bukti, review akhir, dokumen

**Files:**
- Create: `scratch/capture_langkah3e.gd` (pola `capture_langkah3d.gd`), `executor-report/reports/FASE-11-LANGKAH-3E-RADIO-R2-REPORT.md`, `executor-report/screenshots/phases/phase-11-langkah-3e-*.png`
- Modify: `ROADMAP.md`

- [ ] **Step 1: Seluruh suite** — `runtest.sh $(semua tests/test_*.gd tanpa .gd)`; harapan semua OK (≥ 32 suite), tanpa `[FAIL]`/`SCRIPT ERROR`. Satu instance Godot sekaligus.
- [ ] **Step 2: Tangkapan layar native** (`--resolution 1920x1080`, potong ke dock): driver sendirian (tim lime), driver lalu engineer (driver dim, engineer lit), panggilan urgent (crimson), teks panjang, tim putih/gelap (teks putih), kata kunci tersorot (BOX/WETS). Tamparan tidak bisa difoto; catat. Lihat tiap gambar.
- [ ] **Step 3: Review akhir seluruh cabang** (agen terpisah, model `fable`, `review-package`), grade ulang, satu putaran perbaikan TDD, regresi penuh ulang.
- [ ] **Step 4: Dokumen dan commit** — laporan (ringkasan, file, hasil, temuan, ruling: balasan memakai data sim bukan skrip "box this lap" karena mode MANUAL, banjir pada 45 % (sim) bukan 35 %, fade 1.8 s dan tes `test_pit_wall` 6.0 s, sorotan lewat `RichTextLabel` terpisah, 20 potret di-preload), ROADMAP 3e dicentang.

```bash
git add scratch/capture_langkah3e.gd executor-report/reports/FASE-11-LANGKAH-3E-RADIO-R2-REPORT.md executor-report/screenshots/phases/phase-11-langkah-3e-*.png ROADMAP.md
git commit -m "docs(fase-11): Langkah 3e report and screenshots"
```

---
