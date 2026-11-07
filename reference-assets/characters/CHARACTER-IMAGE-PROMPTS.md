# Prompt Full Body 2D Driver (generate manual via web)

**Proyek:** La Voiture. **Gaya baku:** cel-shaded anime, garis tinta manga tebal, shading halftone Ben-Day, kontras tinggi.
**Status:** menggantikan katalog lama (cadangan: `temp/backup_CHARACTER-IMAGE-PROMPTS.md`, tidak di-commit).

## 1. Aturan

1. `radio_portrait.png` adalah **sumber kanon** wajah dan rambut. Jangan digenerate ulang dan jangan diubah.
2. Tiap gambar berisi **satu figur saja**, tampak depan. Tidak ada turnaround, tampak samping/belakang, inset ekspresi, teks, label, bingkai panel, atau bayangan lantai. Inilah penyebab noise pada standee lama.
3. Latar **satu warna polos** (warna per driver ada di tabel, dipilih agar tidak bentrok dengan kostum). Cutout transparan dikerjakan di sisi kode dengan membuang warna itu, jadi **jangan minta latar transparan** dan jangan beri gradasi atau lantai.
4. Satu driver = 2 gambar: `base` + `pose_win`. Pose dibuat dari `base` (dengan portrait sebagai referensi kedua), bukan dari portrait saja, agar kostum konsisten. `pose_pleased` dan `pose_dejected` tidak dibuat: podium hanya memakai satu pose menang untuk P1, P2, dan P3.
5. Semua gambar satu driver memakai **kanvas, skala, dan posisi telapak kaki yang sama** (kaki menyentuh bagian bawah kanvas dengan margin kecil), supaya podium cukup menukar gambar di tempat.

## 2. Pengaturan di web ElevenLabs (Image & Video)

- Model: **GPT Image 2** atau yang lebih baru (GPT Image 2.5). Model ini memakai referensi gambar paling konsisten. Nama menu bisa berbeda; pilih yang setara.
- Rasio **9:16**. Resolusi setinggi yang tersedia (minimal 1K, lebih baik 2K). Kualitas medium atau lebih tinggi.
- Unggah referensi lewat slot **Image Refs** (sampai 10 gambar). Referensi tiap langkah ada di bagian 3.
- Hasil akhir tujuan penyimpanan. Nama file baru, tidak menimpa apa pun:
  `reference-assets/characters/<tim>/<driver>/full_body_base.png` dan `pose_win.png`.
- Bila satu hasil salah, ulangi gambar itu saja. Jangan lanjut ke pose berikutnya sebelum `base` lulus daftar periksa bagian 5.

## 3. Alur per driver

### Langkah 1: `full_body_base.png`
Referensi: (1) `radio_portrait.png` driver, (2) `assets/characters/standees/<driver>.png` (hanya untuk kostum). Tempel prompt:

```
Reference image 1 is the canonical portrait of this racing driver: copy his/her exact face, hair, hair color, eye color and expression style. Reference image 2 is old full-body art: copy ONLY the outfit and body proportions, never its hair color or hairstyle.
Character: {WAJAH_RAMBUT}.
Outfit: {KOSTUM}. Helmet: {HELM}, held under one arm.
Draw ONE single character, full body from the top of the head to the soles of the feet, front view, standing relaxed and neutral with arms at the sides (helmet under one arm), both feet fully visible, centered with a small margin around the figure. Exactly one figure on the canvas: no turnaround, no side or back views, no extra poses, no expression insets, no text, no readable logos, no labels, no panel borders, no cast shadow, no objects on the floor.
Style: cel-shaded anime, thick black manga ink outlines, Ben-Day dot halftone shading, crisp lines, high contrast.
Background: one perfectly flat solid {LATAR} color, no gradient, no floor, no shadow.
```

### Langkah 2: `pose_win.png`
Referensi: (1) `full_body_base.png` yang sudah lulus, (2) `radio_portrait.png`. Awalan sama untuk ketiganya:

```
Same character, same outfit, same face, same hair, same art style, same camera, same framing, same canvas size, and the feet in exactly the same position as reference image 1. Change ONLY the pose and facial expression as described. One single figure, front view, no text, no extra figures, no shadow. Background: one perfectly flat solid {LATAR} color, no gradient, no floor, no shadow, NOT black and NOT white.
```

Lalu tambahkan satu baris pose (sebut helm driver itu dari tabel bagian 4):

`Pose: triumphant victory, mouth open in a joyful shout, one fist raised high, the other hand holding the {HELM} raised up, chest out. Keep the whole figure, including the raised fist and helmet, inside the canvas with a margin.`

Penting: sebut warna latar eksplisit. Jika `base` memakai latar transparan, kalimat "same color as image 1" membuat model memakai latar hitam, yang tidak bisa dibuang dari kostum hitam.

## 4. Data per driver

Nilai {WAJAH_RAMBUT}, {KOSTUM}, {HELM}, {LATAR} untuk tiap driver. **Prioritas** = ditandai bermasalah di audit; kerjakan dulu. Driver lain opsional (standee lama sudah bersih).
Warna latar yang bukan magenta dipilih karena kostum memakai warna magenta atau dekat dengannya.

### #0 K. Ryu (pria) - PRIORITAS
- Folder: `reference-assets/characters/apex-racing/kaze-ryu/`
- Standee lama (referensi kostum): `assets/characters/standees/kaze_ryu.png`
- {WAJAH_RAMBUT}: short spiky black hair with neon lime-green streaks, sharp green eyes, small bandage across the nose, silver chain necklace
- {KOSTUM}: neon lime-yellow puffer jacket over a black race suit with lime accents, black-and-lime sneakers, black fingerless-style gloves with lime trim
- {HELM}: black helmet with a lime lightning bolt
- {LATAR}: #FF00FF (magenta)

### #1 S. Ren (pria) - PRIORITAS
- Folder: `reference-assets/characters/apex-racing/sora-ren/`
- Standee lama (referensi kostum): `assets/characters/standees/sora_ren.png`
- {WAJAH_RAMBUT}: short straight silver-grey hair, amber eyes, thin translucent blue visor over the eyes
- {KOSTUM}: skin-tight black cyber race suit with glowing cyan line trim, thin chest armor plate, white boots
- {HELM}: cream-white helmet
- {LATAR}: #FF00FF (magenta)

### #2 M. Ito (pria) - PRIORITAS
- Folder: `reference-assets/characters/neon-drift/makoto-ito/`
- Standee lama (referensi kostum): `assets/characters/standees/makoto_ito.png`
- {WAJAH_RAMBUT}: wavy medium brown hair, big friendly grin, brown eyes, small earpiece
- {KOSTUM}: bright cyan hoodie, navy cargo pants with a racing harness belt tied around the waist, cyan-and-navy chunky sneakers
- {HELM}: cyan helmet with graffiti stickers
- {LATAR}: #FF00FF (magenta)

### #3 A. Vale (pria) - PRIORITAS
- Folder: `reference-assets/characters/neon-drift/axel-vale/`
- Standee lama (referensi kostum): `assets/characters/standees/axel_vale.png`
- {WAJAH_RAMBUT}: shaggy shoulder-length dirty-blond hair, light stubble, pale blue eyes, rocker look
- {KOSTUM}: black leather biker jacket covered in colorful pins and patches, black jeans, black combat boots, one fingerless glove
- {HELM}: dark helmet with a Union Jack pattern
- {LATAR}: #FF00FF (magenta)

### #4 J. Cruz (pria) - opsional
- Folder: `reference-assets/characters/kurogane-gt/javier-cruz/`
- Standee lama (referensi kostum): `assets/characters/standees/javier_cruz.png`
- {WAJAH_RAMBUT}: short slicked-back black hair, thin scar through one eyebrow, stern dark eyes
- {KOSTUM}: crimson-and-black race suit with a bull emblem on the chest, shoulder armor, red knee pads
- {HELM}: red helmet with small horn-like fins
- {LATAR}: #00FF00 (hijau)

### #5 N. Sato (pria) - opsional
- Folder: `reference-assets/characters/kurogane-gt/naoki-sato/`
- Standee lama (referensi kostum): `assets/characters/standees/naoki_sato.png`
- {WAJAH_RAMBUT}: black buzz cut, face covered from the nose down by a black oni mask with red fangs, narrow fierce eyes
- {KOSTUM}: black-and-crimson race suit with armor panels, black gloves and boots
- {HELM}: white helmet with a black kanji
- {LATAR}: #00FF00 (hijau)

### #6 L. Moreau (pria) - opsional
- Folder: `reference-assets/characters/nordic-phantom/erik-lindqvist/`
- Standee lama (referensi kostum): `assets/characters/standees/erik_lindqvist.png`
- {WAJAH_RAMBUT}: swept-back platinum-white hair, pale blue eyes, calm cold expression
- {KOSTUM}: pale grey-white race suit with light cyan trim lines, silver boots
- {HELM}: dark helmet with a blue visor
- {LATAR}: #FF00FF (magenta)

### #7 R. Silva (wanita) - PRIORITAS
- Folder: `reference-assets/characters/nordic-phantom/freja-berg/`
- Standee lama (referensi kostum): `assets/characters/standees/freja_berg.png`
- {WAJAH_RAMBUT}: WOMAN: icy white-blue hair in a high ponytail plus a long side braid, blue eyes, bandage on the cheek, confident smirk, headset microphone
- {KOSTUM}: light-blue cropped jacket with dark grey panels over a dark grey bodysuit with light-blue side stripes, light-blue boots
- {HELM}: grey helmet with a dark visor
- {LATAR}: #FF00FF (magenta)

### #8 T. Kade (pria) - opsional
- Folder: `reference-assets/characters/zephyr-racing/arthur-sterling-jr/`
- Standee lama (referensi kostum): `assets/characters/standees/arthur_sterling.png`
- {WAJAH_RAMBUT}: swept blond hair, blue eyes, confident noble smile
- {KOSTUM}: navy race suit with cream stripes and a gold lion crest on the chest, white gloves, white-and-navy shoes
- {HELM}: navy helmet with gold trim
- {LATAR}: #FF00FF (magenta)

### #9 E. Novak (pria) - opsional
- Folder: `reference-assets/characters/zephyr-racing/harrison-croft/`
- Standee lama (referensi kostum): `assets/characters/standees/harrison_croft.png`
- {WAJAH_RAMBUT}: very short buzzed brown hair, light stubble, stern grey eyes
- {KOSTUM}: dark navy quilted-panel race suit, black gloves, black boots
- {HELM}: dark helmet with a Union Jack pattern
- {LATAR}: #FF00FF (magenta)

### #10 H. Mori (pria) - opsional
- Folder: `reference-assets/characters/corsa-rossa/luca-ferrari/`
- Standee lama (referensi kostum): `assets/characters/standees/luca_ferrari.png`
- {WAJAH_RAMBUT}: neat medium brown hair, warm brown eyes, youthful smile, headset microphone
- {KOSTUM}: red race suit with yellow piping and a small Italian flag on the sleeve, white-and-yellow shoes
- {HELM}: red helmet with a green-white-red stripe
- {LATAR}: #00FF00 (hijau)

### #11 D. Reyes (pria) - opsional
- Folder: `reference-assets/characters/corsa-rossa/matteo-rossi/`
- Standee lama (referensi kostum): `assets/characters/standees/matteo_rossi.png`
- {WAJAH_RAMBUT}: big voluminous black curly hair, thick black mustache, tan skin, intense dark-orange eyes
- {KOSTUM}: red race suit with yellow side stripes, yellow gloves, yellow shoes
- {HELM}: red helmet with yellow flames
- {LATAR}: #00FF00 (hijau)

### #12 V. Sokol (pria) - PRIORITAS
- Folder: `reference-assets/characters/tokyo-underground/ren-mishima/`
- Standee lama (referensi kostum): `assets/characters/standees/ren_mishima.png`
- {WAJAH_RAMBUT}: black hair with orange-tipped bangs, orange-tinted glasses, headset microphone, cool half-smile
- {KOSTUM}: dark charcoal race suit with orange trim lines, black gloves, black boots
- {HELM}: dark helmet with a gold visor
- {LATAR}: #FF00FF (magenta)

### #13 P. Aoki (pria) - PRIORITAS
- Folder: `reference-assets/characters/tokyo-underground/shinjiro-ono/`
- Standee lama (referensi kostum): `assets/characters/standees/shinjiro_ono.png`
- {WAJAH_RAMBUT}: spiky black hair with a white headband whose tail hangs down, weathered scarred face, hard stare (middle-aged veteran)
- {KOSTUM}: white race suit with orange side panels, grey shoulder armor, white-orange shoes
- {HELM}: white helmet with orange flames
- {LATAR}: #FF00FF (magenta)

### #14 G. Alves (pria) - opsional
- Folder: `reference-assets/characters/valkyrie-scuderia/alistair-finch/`
- Standee lama (referensi kostum): `assets/characters/standees/alistair_finch.png`
- {WAJAH_RAMBUT}: dark brown skin, dreadlocks tied up with gold beads, shaved sides, small earring, calm smile
- {KOSTUM}: green-and-gold race suit with a laurel emblem on the chest, gold sneakers
- {HELM}: green helmet with a gold visor
- {LATAR}: #FF00FF (magenta)

### #15 C. Weiss (pria) - PRIORITAS
- Folder: `reference-assets/characters/valkyrie-scuderia/charles-de-vries/`
- Standee lama (referensi kostum): `assets/characters/standees/charles_de_vries.png`
- {WAJAH_RAMBUT}: wavy golden-brown hair, green eyes, refined calm expression
- {KOSTUM}: dark green race suit with thin gold line trim and a small gold crest, green-gold shoes
- {HELM}: green-and-gold helmet
- {LATAR}: #FF00FF (magenta)

### #16 B. Tanaka (pria) - PRIORITAS
- Folder: `reference-assets/characters/cyberpunk-syndicate/dante-vance/`
- Standee lama (referensi kostum): `assets/characters/standees/dante_vance.png`
- {WAJAH_RAMBUT}: dark purple undercut hair, purple cybernetic eye visor over one eye, confident smirk
- {KOSTUM}: black tactical race suit with glowing purple lines and chest harness straps, black boots
- {HELM}: black helmet with a purple visor
- {LATAR}: #00FF00 (hijau)

### #17 F. Duval (pria) - PRIORITAS
- Folder: `reference-assets/characters/cyberpunk-syndicate/zane-cross/`
- Standee lama (referensi kostum): `assets/characters/standees/zane_cross.png`
- {WAJAH_RAMBUT}: spiky lime-green and purple hair, cyan holographic visor over one eye, wide grin
- {KOSTUM}: purple utility vest with lime straps over a black suit, black cargo pants, black-and-lime sneakers
- {HELM}: purple-and-lime helmet
- {LATAR}: #FF8000 (oranye)

### #18 I. Petrov (pria) - PRIORITAS
- Folder: `reference-assets/characters/veloce-stratos/gianluca-moretti/`
- Standee lama (referensi kostum): `assets/characters/standees/gianluca_moretti.png`
- {WAJAH_RAMBUT}: dark brown swept hair with a silver streak, short stubble beard, warm brown eyes, friendly smile
- {KOSTUM}: blue race suit with silver-white trim, blue-white shoes
- {HELM}: blue helmet with silver trim
- {LATAR}: #FF00FF (magenta)

### #19 O. Mbeki (pria) - opsional
- Folder: `reference-assets/characters/veloce-stratos/pierre-mercier/`
- Standee lama (referensi kostum): `assets/characters/standees/pierre_mercier.png`
- {WAJAH_RAMBUT}: neat swept blond hair, light blue eyes, calm composed expression
- {KOSTUM}: cream-white race suit with royal-blue panels, white gloves, white shoes
- {HELM}: white helmet with a blue stripe
- {LATAR}: #FF00FF (magenta)

### #20 M. Bellini (pria) - PRIORITAS
- Folder: `reference-assets/characters/scuderia-maranello/marco-bellini/`
- Standee lama (referensi kostum): `assets/characters/standees/marco_bellini.png`
- {WAJAH_RAMBUT}: dark wavy hair with red streaks, dark eyes, charming smile, headset microphone
- {KOSTUM}: red race suit with dark trim (follow the portrait, NOT the old black bomber jacket), red shoes
- {HELM}: red-and-gold helmet
- {LATAR}: #00FF00 (hijau)

### #21 A. Rossi (wanita) - PRIORITAS
- Folder: `reference-assets/characters/scuderia-maranello/alessia-rossi/`
- Standee lama (referensi kostum): `assets/characters/standees/alessia_rossi.png`
- {WAJAH_RAMBUT}: WOMAN: short dark-blonde asymmetric bob (NOT black hair), hazel eyes, focused confident look, headset microphone
- {KOSTUM}: black race suit with red-and-gold panels and a red collar, red boots
- {HELM}: black helmet with gold trim
- {LATAR}: #FF00FF (magenta)

### #22 C. Vance (pria) - PRIORITAS
- Folder: `reference-assets/characters/ironhorse-motorsport/colt-vance/`
- Standee lama (referensi kostum): `assets/characters/standees/colt_vance.png`
- {WAJAH_RAMBUT}: messy sandy-blond hair (NOT dark brown), stubble, scruffy confident grin
- {KOSTUM}: faded blue denim vest over a navy race suit, orange bandana at the neck, brown leather gloves and boots
- {HELM}: dark blue skull-pattern helmet
- {LATAR}: #FF00FF (magenta)

### #23 W. Cooper (pria) - PRIORITAS
- Folder: `reference-assets/characters/ironhorse-motorsport/wyatt-cooper/`
- Standee lama (referensi kostum): `assets/characters/standees/wyatt_cooper.png`
- {WAJAH_RAMBUT}: messy dark brown hair under a navy baseball cap, relaxed half-smile, sunglasses hanging on the collar
- {KOSTUM}: grey race suit with orange stripes, black gloves, black shoes
- {HELM}: grey-and-orange helmet
- {LATAR}: #FF00FF (magenta)

### #24 H. Kazama (pria) - opsional
- Folder: `reference-assets/characters/neo-wangan-works/hayato-kazama/`
- Standee lama (referensi kostum): `assets/characters/standees/hayato_kazama.png`
- {WAJAH_RAMBUT}: messy black hair, sharp serious eyes
- {KOSTUM}: white zip jacket with red accents and one large kanji on the chest, black pants with a red stripe, red-and-white sneakers
- {HELM}: white helmet with red accents
- {LATAR}: #00FF00 (hijau)

### #25 R. Takahashi (wanita) - PRIORITAS
- Folder: `reference-assets/characters/neo-wangan-works/rin-takahashi/`
- Standee lama (referensi kostum): `assets/characters/standees/rin_takahashi.png`
- {WAJAH_RAMBUT}: WOMAN: bright red high ponytail with a wrench hair clip (NOT brown hair), amber eyes, cheerful expression, headset microphone
- {KOSTUM}: white race suit with pink and red graphic panels, red sneakers
- {HELM}: white-and-pink helmet
- {LATAR}: #00FF00 (hijau)

## 5. Daftar periksa tiap `base` (wajib sebelum membuat pose)

- Hanya **satu** orang di kanvas. Tidak ada sisa figur lain di tepi.
- Kepala sampai telapak kaki utuh, tidak terpotong, kedua kaki terlihat.
- Wajah, warna rambut, dan gaya rambut **sama dengan portrait** (cek berdampingan).
- Tidak ada teks terbaca, logo, bayangan lantai, atau gradasi di latar.
- Latar benar-benar satu warna rata (tepi figur tajam, tidak berhalo).
- Wanita tetap wanita (Silva, Rossi, Takahashi); semua driver lain pria.

## 6. Setelah gambar tersimpan

Jalankan `py tools/build_driver_standees.py`: membuang latar warna polos jadi PNG transparan, menyelaraskan telapak kaki pose menang ke base, dan menulis `assets/characters/standees/<slug>.png` dan `<slug>_win.png` (720 x 1328). Lalu `godot --headless --path . --import`.
