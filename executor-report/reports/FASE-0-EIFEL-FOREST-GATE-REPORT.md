# FASE 0 — Eifel Forest Ring: paket, pit flood, dan kink gate

**Tanggal:** 2026-11-03
**Agen:** omp — Executor
**Paket:** `D:/Occupation/Porto/genex/mapgen-circuit/builds/eifel_forest/production-handoff.md`
**Geometri:** `sha256:8de6956c723c4f4037054e1c8317e103e12ff7704f285ea89e6a18ed951eaa3c` (sebelum revisi T13: `d07769f5…063c`)
**Status:** **SELESAI (revisi T13 diterapkan)** — user mengotorisasi patch T13 54→110 m pada 2026-11-03; paket di-re-freeze, gate kink menjadi 0, flood tetap 0 FAIL, dan Fase 1–2 dilanjutkan. Lihat [`FASE-25-EIFEL-FOREST-REPORT.md`](FASE-25-EIFEL-FOREST-REPORT.md).

---

## Ringkasan

| Gate | Hasil | Bukti |
|---|---|---|
| Checksum paket beku | **PASS 4/4 SAMA** | `sha256sum` vs `final/manifest.json` |
| Geometry hash | **PASS** | hash subtree = lock = manifest = `d07769f5…063c` |
| Validator paket | **PASS 26 / WARN 0 / FAIL 0** | `core/validator.gd` |
| Kurva homologasi | **PASS** | 5.150 titik blueprint = sandbox, delta maksimum **0,000000 m** |
| Pit flood pitch 14 m | **PASS 0 FAIL** (5 skenario, 20 mobil) | `tests/pit_flood_checks.gd` |
| Kink / racing-line Fase 18 | **FAIL** — 1 kink di s=4128 (T13) | batas sirkuit baru: 0 |
| Manifest regeneration | **Tidak dijalankan** — paket belum stabil | menunggu keputusan Map Planner |

Tidak ada kode produksi yang ditulis. `designs/` tidak disentuh. Semua probe berada di `temp/` (gitignored).

---

## 1. Verifikasi paket

- `blueprint.track.json` — `4f389e68…c022` (SAMA)
- `environment_strip.json` — `8d4cb4d1…7b52f`
- `handoff-prompt.md` — `e753b57e…03c3`
- `procedural-spec.md` — `732d76d3…f1a5`
- `geometry_hash` subtree (alignment + elevation + road.width_m + pit fields) dihitung ulang dengan canonical JSON + snap 3 desimal: **`sha256:d07769f5e5805a23a59fe7f094c08c4fc36d1643db1aa8ea87d1d440caaf063c`** — identik dengan `lock.json`, `manifest.json`, dan handoff.
- Schema: 0 error. Validator: **26 PASS / 0 WARN / 0 FAIL**.

## 2. Kurva spline approved

Kurva dikompilasi ulang dari `final/blueprint.track.json` memakai `core/compiler.gd` (algoritma yang sama dengan sandbox Route 2), lalu dibandingkan titik demi titik dengan `Curve3D` di `builds/eifel_forest/scene/eifel_forest_build.tscn`:

```
compiled 5150 points, length 5150.000 m
sandbox  5151 points, baked 5150.732 m
compared 5150 points, max delta 0.000000 m, sandbox closes loop true
```

Hasil: `assets/tracks/eifel_forest/data/eifel_forest_curve.tres`, baked **5.150,732 m**. Ini terjemahan persis geometri sandbox yang disetujui, bukan desain ulang. Regenerasi wajib bila paket direvisi.

## 3. Pit flood — pitch 14 m (approved)

Dijalankan pada ribbon hasil kompilasi blueprint, lebar aspal 13,0 m, layout:

```
entry_s 4950, exit_s 210, lane_length_m 410,
stall_first_s = length + 57 (bay 0 di s=57; service bay 5 di s=127),
stall_pitch_m 14, stall_lane_m 16.5, fast_lane_m 8.5, edge_lateral_m 5.2
```

`tests/pit_flood_checks.gd` (lima skenario, 20 mobil, seed 31):

| Skenario | Servis | Lane kosong | Stand-still maks | Decel | Teleport | Overlap > 1 m |
|---|---:|---:|---:|---:|---:|---:|
| train 30 m | 20/20 | 53 s | 7,3 s | 9,0 m/s² | 0,05 m | 16 tick (1,82 m) |
| bunched 20 m | 20/20 | 50 s | 9,5 s | 9,0 | 0,05 | 14 tick (1,90 m) |
| spread lap | 20/20 | 128 s | 0,1 s | 9,0 | 0,05 | 0 |
| raced field all-box | 20/20 | 126 s | 5,4 s | 9,0 | 0,05 | 16 tick (1,86 m) |
| raced field 3–9 s apart | 20/20 | 248 s | 1,8 s | 9,0 | 0,05 | 0 |

Semua ambang lulus: release mean **0,21 s** (batas 1,5), release max **1,6 s** (batas 7), merge stand **0,1 s** (batas 4). **0 FAIL.**

Kesimpulan: pitch 14 m milik Eifel **tidak** memicu kegagalan flood. Secara behavioral, tidak perlu revisi pitch ke 20 m; batas 20 m di panduan adalah standar umum yang lahir dari kegagalan lane lain, bukan assertion literal pada gate flood bersama. Namun jika Map Planner mempertahankan standar literal 20 m, span 10 stall menjadi 200 m dan pada building centre s=120 menempati 20..220 — melewati pit exit s=210. Sesuai handoff, kondisi itu **wajib** dikembalikan ke Map Planner (cascade span/centre/entry/exit/spec/manifest), bukan ditambal di sisi produksi. Deviasi pitch 14 m ini dicatat untuk keputusan planner.

## 4. Kink gate — MERAH

Gate yang sama dengan `tests/test_racing_line.gd` `_check_kinks` (peak |κ| > 0,01 1/m, jalan lurus < 25% κ pada ±8 m, jarak antar-kink > 20 m). Batas sirkuit baru: **0**.

```
centreline kinks: 1 [4128.0]
```

Lokasi: **s=4128**, vertex blueprint ke-13 `(-719.6, 257.0)` — **T13 NGK Chicane Left**, radius fillet **54,0 m**. Arc tikungan lebih pendek dari jendela sampling 16 m, sehingga profil kelengkungan memuncak 0,0140 1/m dengan jalan lurus di kedua sisinya.

### Upaya homologasi produksi (pola Stoke/Pacific)

Closed Catmull-Rom melalui control point tiap 10 m (pola `tools/build_pacific_corkscrew_curve.gd`) diuji:

| Stride | Deviasi maks dari guide | Kink | Catatan |
|---:|---:|---:|---|
| 3 | 1,073 m | 1 | tidak menghapus kink |
| 5 | 0,028 m | 1 | tidak menghapus kink |
| 10 | 0,110 m | 1 | batas deviasi yang diterima Pacific, tetap gagal |
| 15 | 10,702 m | 0 | lolos hanya dengan menggeser geometri >10 m — desain ulang, ditolak |

Spline dengan handle Catmull-Rom melalui **seluruh 5.150 titik approved** (deviasi maksimum hanya **0,00376 m**, panjang 5.150,743 m) juga masih membaca **1 kink** di s=4129. Jadi masalahnya bukan interpolasi polyline; fillet 54 m itu sendiri yang memuncak di atas ambang.

Homologasi **tidak** dapat menghapus kink dalam toleransi 0,13 m yang diterima untuk Stoke/Pacific. Meluruskan tikungan secara lokal dilarang handoff.

### Usulan patch Map Planner (belum diterapkan)

Sweep radius fillet T13 (vertex tidak bergerak), peak kelengkungan centreline di s=4128:

| Radius T13 | Peak κ | Kink | Panjang lap |
|---:|---:|---:|---:|
| 54,0 m (paket) | 0,01400 | 1 | 5.150,732 m |
| 90,0 m | 0,01098 | 1 | 5.150,731 m |
| 98,0 m | 0,01017 | 1 | 5.150,732 m |
| 100,0 m | 0,00998 | 0 | 5.150,731 m |
| **110,0 m (usulan)** | **0,00909** | **0** | **5.150,730 m** |
| 120,0 m | 0,00833 | 0 | 5.150,730 m |

100,0 m lolos hanya 0,2% di bawah ambang 0,01; **110,0 m** dipilih sebagai usulan dengan margin 9% tanpa menggeser vertex atau mengubah panjang lap.

```json
{
  "op": "alignment.set_radius",
  "index": 12,
  "value": 110.0,
  "geometry_intent": "FASE 18 kink gate: the frozen T13 NGK Chicane Left fillet (radius 54.0 m) reads a 0.0140 1/m centreline spike at s=4128, over the 0.01 kink threshold with straight road 8 m either side. A 110.0 m fillet lowers the peak to 0.0091 (9% margin) without moving any vertex; lap length stays 5150.73 m. No other geometry field is touched.",
  "approved": false
}
```

Preview `core/patch.gd`:

- before: `sha256:d07769f5e5805a23a59fe7f094c08c4fc36d1643db1aa8ea87d1d440caaf063c`
- after: `sha256:8de6956c723c4f4037054e1c8317e103e12ff7704f285ea89e6a18ed951eaa3c`
- kink sesudah patch: **0**; baked length 5.150,730 m.

Rekaman lengkap: `temp/eifel_forest-t13-radius-patch.json`.

## 5. Keputusan

Sesuai `production-handoff.md` Fase 0 butir 2 dan 4:

> bila ada kink, revisi spline lewat Map Planner. Jangan meluruskan tikungan secara lokal.
> Baru setelah ketiganya hijau, lanjut Fase 1.

Kink gate merah, jadi:

- **Fase 1 tidak dimulai.**
- Paket dikembalikan ke **Map Planner** dengan patch request di atas (melalui `core/patch.gd`, bukan edit `designs/`).
- Setelah patch disetujui: re-freeze `lock.json`, regenerasi `manifest.json` + `environment_strip`/spec cascade bila perlu, rebuild sandbox + review, lalu handoff ulang. Kurva produksi dan seluruh modul Fase 1 baru dibuat dari paket yang sudah hijau.

## 6. File yang disentuh

| Path | Status |
|---|---|
| `assets/tracks/eifel_forest/data/eifel_forest_curve.tres` | baru — kurva hasil kompilasi blueprint, identik dengan sandbox (0,000000 m) |
| `executor-report/reports/FASE-0-EIFEL-FOREST-GATE-REPORT.md` | laporan ini |
| `temp/fase0_curve_probe.gd`, `temp/fase0_gate_probe.gd`, `temp/fase0_kink_probe.gd`, `temp/fase0_homolog_probe.gd`, `temp/fase0_homolog_sweep.gd`, `temp/fase0_radius_probe.gd`, `temp/fase0_validator_probe.gd`, `temp/fase0_patch_request.gd`, `temp/eifel_forest-t13-radius-patch.json` | probe scratch, gitignored |

`designs/` dan seluruh scene/script sirkuit yang ada tidak diubah.
