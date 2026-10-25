# DESIGN SPEC: Langkah 3 — Tactical Pit Wall Deck Refinement & Two-Way Radio Comms (In-Game HUD)

**Target Phase:** FASE 11 (Langkah 3)  
**Target Engine:** Godot Engine 4.7.2 stable  
**Approved Concept Preview:** [`temp/brainstorm/content/ui_step_3_hud_preview.html`](file:///D:/Occupation/Porto/genex/La_Voiture/temp/brainstorm/content/ui_step_3_hud_preview.html)  
**Visual Style:** Street-Manga $\times$ Need for Speed Unbound $\times$ Neo-Brutalism  

---

## 1. Executive Summary & Core Mandate

Langkah 3 memfokuskan peningkatan pada modul **In-Game Race HUD**, khususnya **Tactical Pit Wall Deck** (strip taktis bawah), **Suggestion Card** (modal saran strategi dengan timer terbakar), dan **Two-Way Radio Comms** (komunikasi radio dua arah antara driver dan race engineer).

> [!IMPORTANT]
> **ATURAN TATA LETAK MUTLAK (LAYOUT LOCK):**  
> Seluruh koordinat panggung 1920×1080 (posisi, ukuran, dan jangkar layout) dari setiap modul HUD **DIKUNCI 100% DAN TIDAK BOLEH BERUBAH SAMA SEKALI**:
> * Zone A Top Ribbon: `pos (16, 12)`, `size (1888, 60)`
> * Timing Tower: `pos (16, 88)`, `size (320, 780)`
> * Telemetry Drawer: `pos (1598, 372)`, `size (312, 496)`
> * Suggestion Card: `pos (656, 690)`, `size (608, 136..156)`
> * Tactical Deck: `pos (16, 880)`, `size (1888, 140)` [Open] / `size (1888, 44)` [Collapsed]
> * Race Control Marquee: `pos (0, 1032)`, `size (1920, 48)`
> 
> Tujuan pemolesan adalah **merombak unsur elemen internal node** (styling pelat miring, inking border, dynamic button state, countdown timer bar, tipografi, dan respons interaktif) tanpa menggeser posisi tata letak.

---

## 2. Rincian Arsitektur & Spesifikasi Elemen

### A. Tactical Deck: Actionable 2-State Pit Button (`tactical_deck.gd`)
1. **Dynamic State Toggle:**
   - **State 1 (`REQUEST BOX [B]`):**
     * Aktif saat `car.pit_request < 0` dan `car.pit == null`.
     * Tampilan: Latar *Neon Acid Lime* (`#D8FF00`), font hitam display tebal, bayangan offset hitam 4px, font `'Barlow Condensed'` / `'Anton'`.
     * Aksi: Memanggil `_world.request_pit(deck_car_id, pit_compound)` atau shortcut keyboard `[B]`.
   - **State 2 (`CANCEL BOX [ESC] // <COMPOUND>`):**
     * Aktif saat `car.pit_request >= 0` dan `car.pit == null` (mobil belum memasuki jalur pit limiter).
     * Tampilan: Latar *Anime Crimson* (`#FF1744`), corak garis miring hazard (`repeating-linear-gradient`), animasi denyut peringatan (`hazardPulse`), teks putih tebal dengan stroke hitam.
     * **Tombol TIDAK LAGI dinonaktifkan (`disabled = false`)**, sehingga pemain dapat mengklik tombol ini kapan saja sebelum pit limiter untuk membatalkan panggilan pit.
     * Aksi: Memanggil `_world.cancel_pit(deck_car_id)` atau shortcut keyboard `[ESC]`.
   - **State 3 (Locked / In Pit / Finished):**
     * Jika `car.pit != null`: Teks `"IN THE PIT LANE"`, `disabled = true`.
     * Jika `car.is_dnf`: Teks `"RETIRED"`, `disabled = true`.
     * Jika `car.finished_at >= 0.0`: Teks `"CHEQUERED"`, `disabled = true`.

2. **Pembatalan Pit Tanpa Penalti (`gt_race.gd` & `race_weekend_world.gd`):**
   - Menambahkan method `cancel_pit(car_id: int) -> bool` pada `GtRace` dan `RaceWeekendWorld`.
   - Mengembalikan `car.pit_request = -1`.
   - Mengirimkan transmisi radio engineer: `"Stay out, stay out! Box call cancelled."` via `push_radio()`.
   - Memulihkan target pacing mobil ke kondisi normal tanpa penalti waktu atau grip.

---

### B. Dua Mode Operasi Pit Wall (`[MANUAL]` vs `[AUTO]`)
Pada baris `DESK` di `tactical_deck.gd`:
1. **Mode `[MANUAL]` (Strategy Director / Default):**
   - Pemain memegang kendali 100% atas strategi ban, pacing, dan pit call.
   - AI tidak akan memanggil pit stop secara otomatis untuk mobil pemain.
   - Suggestion card hanya muncul sebagai info tanpa auto-lock.
   - Status tag: `MODE: MANUAL // 100% PLAYER DIRECTIVE`.
2. **Mode `[AUTO]` (AI Race Engineer Assisted):**
   - Race Engineer secara proaktif memantau kondisi ban dan cuaca.
   - Jika kondisi cuaca berubah drastis atau ban aus melewati batas kritis, kartu saran strategi muncul dengan burning countdown bar.
   - **Jika timer 10 detik habis pada mode AUTO**, strategi ban dan panggilan box otomatis dikunci (`auto-lock`) dan dieksekusi tanpa memerlukan klik manual pemain.
   - Status tag: `MODE: AUTO // AI ENGINEER ASSISTED`.
3. **Mode `[HYBRID]` (Advisor Prompts):**
   - Mode perantara yang menyarankan taktik tetapi tidak melakukan auto-lock jika timer habis (kartu otomatis dismiss jika diabaikan).

---

### C. 10-Second Burning Countdown Bar pada Suggestion Card (`race_hud.gd`)
1. **Visual Burning Flame Timer:**
   - Baris timer horizontal di bagian atas modal (tinggi 8–10 px) yang menyusut dari lebar 100% ke 0% selama 10.0 detik.
   - Warna gradasi menyala: *Cyber Yellow (`#FFD400`) $\rightarrow$ Blaze Orange (`#FF6D00`) $\rightarrow$ Anime Crimson (`#FF1744`)*.
   - Ujung bar memiliki efek lidah api putih berkilau (`ember bloom`).
2. **Dynamic Remaining Time Label:**
   - Label waktu di kanan header kartu: `"10.0s"` $\rightarrow$ `"03.2s"` $\rightarrow$ `"00.0s"`.
   - Jika sisa waktu $< 3.0$ detik, teks dan border berkedip merah peringatan (`CRITICAL`).
3. **Interaksi Keyboard:**
   - `[ENTER]`: `ACCEPT` saran strategi (seketika mengunci compound dan memanggil box).
   - `[ESC]` / `[BACKSPACE]`: `DISMISS` saran strategi (menutup kartu dan membiarkan mobil tetap di lintasan).

---

### D. Two-Way Radio Comms Dialogue (`anime_radio_cutin.gd`)
1. **Arsitektur Dialog 2-Arah:**
   - Dialog terkoordinasi saat terjadi momen kritis balapan:
     * **Pemicu 1 (Tyre Wear Critical / Snap Oversteer):**  
       *Driver (Cut-in kiri, Lime):* `"Had a snap of oversteer! Rear tyres have zero grip!"`  
       *Engineer (Cut-in kanan, Cyan, jeda 2.5s):* `"Copy Ren, box this lap, box this lap. Confirming fresh rubber!"`
     * **Pemicu 2 (Track Flooding / Water > 35%):**  
       *Driver (Cut-in kiri):* `"Track is flooding in sector two, aquaplaning heavily!"`  
       *Engineer (Cut-in kanan, jeda 2.5s):* `"Understood, box for Wets, pit crew is ready."`
2. **Visual Manga Soundwave Equalizer:**
   - 14 bilah soundwave neon yang bergetar dinamis mengikuti energi audio saat transmisi aktif.
   - Balon teks komik miring dengan bayangan offset pekat dan frame potret manga terpolarisasi.

---

### E. Keyboard Shortcuts HUD Lengkap (`race_hud.gd`)
* `[B]`: Request Box untuk mobil yang sedang dipilih.
* `[ESC]`: Cancel Box jika pit sudah dipanggil, atau dismiss suggestion card jika kartu sedang aktif.
* `[ENTER]`: Accept suggestion card jika sedang aktif.
* `[M]`: Fold / Unfold Tactical Deck.
* `[T]`: Buka / Tutup Telemetry Drawer.
* `[TAB]`: Ganti kolom Timing Tower (INT $\rightarrow$ GAP $\rightarrow$ LAST).
* `[E]`: Toggle ERS Overtake.
* `[ ]` & `[ ]`: Turunkan / Naikkan Pace Mode.
* `[N]`: Ganti fokus ke mobil rekan setim berikutnya.
* `[H]`: Hide / Show seluruh HUD.

---

## 3. Rencana Pengujian (Quality Gate & DoD)

1. **Unit & Integration Test Suite Baru:** `tests/test_pit_deck_and_radio.gd`
   - Memverifikasi transisi state `REQUEST BOX [B]` $\rightarrow$ `CANCEL BOX [ESC]`.
   - Memverifikasi eksekusi `cancel_pit()` mengembalikan `car.pit_request = -1` dan pacing mobil pulih.
   - Memverifikasi mode `[MANUAL]` vs `[AUTO]` pada Tactical Desk.
   - Memverifikasi 10-second countdown bar pada `SuggestionCard` menyusut dan melakukan auto-lock di mode AUTO.
   - Memverifikasi pemicu radio 2-arah antara Driver dan Engineer.
2. **Zero Regression Test:** Seluruh 27 test suite yang sudah ada wajib tetap **100% PASS, 0 FAIL**.
3. **Native Smoke Test:** Menjalankan balapan 3 lap di engine Godot dengan HUD aktif, menguji tombol cancel box dan radio dialog secara real-time.
