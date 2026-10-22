# KATALOG PROMPT GAMBAR LENGKAP 20 KARAKTER PEMBALAP (IMAGE GENERATION PROMPTS)
**Proyek:** *La Voiture* — Broadcast GT3 Motorsport Strategy Simulation  
**Direktori:** `reference-assets/characters/`  
**Gaya Visual Baku:** Cel-Shaded Toon Anime $\times$ Inverted-Hull Ink Outline $\times$ Manga Halftone Neo-Brutalism $\times$ Streetwear NFS Unbound  
**Target Tool:** Genex Image CLI (`npx genex image`), Midjourney v6, Fal.ai (Flux), atau DALL-E 3

---

## 1. Parameter Gaya Visual Global (Master Style Tokens)

Setiap prompt disusun dengan token estetika yang konsisten:
* **Style Anchor:** `cel-shaded anime style, thick black manga ink outlines, Ben-Day dot halftone screentone shading, neo-tokyo motorsport streetwear, sharp geometric shadows, dynamic high-contrast lighting, brutalist graphic novel aesthetic, zero softness, crisp lines`
* **Negative Prompt Standar:**
  `photorealistic, 3d render, western comic style, soft airbrushed shading, blurry, gradient shadows, deformed hands, extra fingers, noisy background, muddy colors, bad anatomy, low quality`

Setiap pembalap memiliki **2 Jenis Prompt**:
1. **Prompt Tipe A (2D Comms Radio & HUD Portrait):** Rasio $1:1$ (Bust-up / Close-up wajah beremosi tajam untuk banner transmisi radio `RaceHud.RADIO_DOCK`).
2. **Prompt Tipe B (Full-Body 3D Reference Model):** Rasio $9:16$ atau $1:1$ (Tubuh penuh berdiri A-Pose / Relaxed untuk input ke generator 3D Meshy / Genex Character).

---

## 2. Katalog Prompt 20 Pembalap (10 Tim Pabrikan)

---

### TIM 0: APEX RACING (Porsche 911 GT3 R | Pemilik: Kenji Takahashi)
**Palet Warna:** *Acid Lime* (`#CCFF00`) $\times$ *Deep Charcoal Black* (`#0E1118`)

#### 1. Kaze Ryu (`#01 RYU`) — The High-Voltage Prodigy
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Dynamic bust-up anime portrait of Kaze Ryu, 22-year-old male Japanese racing driver, spiky messy black anime hair with electric acid-lime neon highlights, fierce determined eyes with confident smirk, band-aid on nose bridge, heavy silver chain necklace. Wearing black matte FIA racing suit with neon acid-lime racing collar, radio mic clipped to collar. Thick black manga ink outlines, halftone Ben-Day dot screentone shading, speed lines background, cel-shaded anime style, high contrast, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept art of Kaze Ryu, Japanese male GT3 racer in relaxed standing pose. Wearing an open cropped neon acid-lime puffer jacket over a black racing undersuit with geometric sponsor decals, fingerless neon racing gloves, black and neon-green high-top futuristic sneakers. Holding a matte black GT3 racing helmet with acid-lime lightning graffiti under his left arm. Flat neutral grey background, clean front turnaround reference, crisp cel-shaded anime outline, neo-tokyo motorsport fashion
  ```

#### 2. Sora Ren (`#02 REN`) — The Cybernetic Calculator
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Sora Ren, 24-year-old male GT3 tactical driver, straight sleek silver-grey anime hair with neat bangs covering part of forehead, calm cold analytical amber eyes, emotionless focused expression. Wearing an ultra-thin sporty HUD telemetry smart-glass over left eye emitting faint cyan data glow, high-collar black techwear racing suit with electric cyan circuit board pinstripes. Thick manga ink outlines, crisp halftone screentone, cel-shaded anime, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept turnaround of Sora Ren, slender tall male racing strategist. Wearing slim-fit aerodynamic black techwear racing suit with glowing electric cyan accents, carbon-fiber chest protector vest, minimalist white and cyan racing boots. Holding a sleek ivory-white racing helmet with silver mirror visor in right hand, left hand holding a thin digital telemetry tablet. Standing upright in precise military posture, neutral grey studio background, cel-shaded anime aesthetic
  ```

---

### TIM 1: NEON DRIFT (Audi R8 LMS GT3 | Pemilik: Rei Kisaragi)
**Palet Warna:** *Electric Cyan* (`#00F0FF`) $\times$ *Midnight Navy* (`#060B19`)

#### 3. Makoto Ito (`#03 ITO`) — The Apex Drifter
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Makoto Ito, 21-year-old cheerful Japanese drift racer, messy wavy brown hair, big energetic hazel eyes with a wide playful grin. Wearing an oversized bright electric cyan streetwear hoodie pulled over his racing collar, dual wireless pit earphones. Heavy manga ink contours, vibrant pop-art halftone dots, diagonal comic action lines, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Makoto Ito standing casually with double peace signs. Wearing an oversized electric cyan hoodie over racing suit tied around his waist, baggy navy cargo pants, chunky platform streetwear sneakers. A graffiti-tagged cyan racing helmet with Japanese wave spray paint resting on the ground next to his foot. Clean turnaround pose, cel-shaded anime style, neutral background
  ```

#### 4. Axel Vale (`#04 VAL`) — The Camden Rocker
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Axel Vale, 25-year-old British rebel driver, shaggy shoulder-length dirty-blonde rockstar hair, rebellious smoldering blue eyes with dark smudged eyeliner, slight smirk with small lip piercing. Wearing a distressed black leather racing jacket covered in punk band enamel pins and cyan patches. Heavy comic ink outlines, dark grunge manga halftone, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Axel Vale in rockstar swagger pose. Tall athletic build, wearing distressed black leather moto jacket, slim racing trousers with zip details, combat racing boots. Holding a distressed matte black helmet with stencil Union Jack graffiti by the chin strap like a guitar. Neutral grey background, sharp anime cel-shading, neo-punk motorsport fashion
  ```

---

### TIM 2: KUROGANE GT (Nissan GT-R NISMO GT3 | Pemilik: Daisuke Kurogane)
**Palet Warna:** *Anime Crimson* (`#FF1E56`) $\times$ *Matte Obsidian Carbon* (`#0B0C10`)

#### 5. Javier Cruz (`#05 CRU`) — The Iron Matador
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Javier Cruz, 32-year-old battle-hardened Spanish racer, sharp chiseled jawline with rugged 5-o'clock stubble shadow, intense predator gaze with scar through left eyebrow, slicked-back jet black hair. Wearing a heavy-duty crimson-red and carbon-fiber racing collar with tribal bull insignia. Bold dramatic manga shadows, aggressive ink crosshatching, halftone texture, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Javier Cruz standing with arms crossed in imposing stance. Muscular broad-shouldered build, wearing reinforced crimson and matte black Kevlar racing suit with carbon shoulder guards, heavy-duty racing boots. A sinister crimson racing helmet with black bull horns artwork resting on his hip. Solid neutral background, high-contrast cel-shaded anime style
  ```

#### 6. Naoki Sato (`#06 SAT`) — The Silent Ronin
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Naoki Sato, 26-year-old stoic Japanese driver, sharp buzzcut black hair, cold piercing slit eyes, wearing a black neck gaiter mask with fierce crimson Hannya samurai demon teeth pattern covering mouth and nose. Deep shadow over eyes, stark brutalist manga ink lines, crimson blood-red halftones, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Naoki Sato standing motionless in disciplined martial arts attention pose. Wearing sleek black and dark crimson racing suit inspired by samurai armor plates, high-top racing boots, black Hannya mask. Holding a pure matte-white helmet inscribed with bold black brush calligraphy kanji in both hands. Neutral grey studio background, clean anime turnaround reference
  ```

---

### TIM 3: VANTA MOTORS (BMW M4 GT3 | Pemilik: Henrik von Vanta)
**Palet Warna:** *Cyber Yellow* (`#FFE600`) $\times$ *Pitch Black Vanta* (`#020202`)

#### 7. Luc Moreau (`#07 MOR`) — The Monaco Prodigy
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Luc Moreau, 23-year-old aristocratic French driver, charming elegant face, wavy styled chestnut brown hair, soulful amber eyes, subtle confident smile. Wearing a high-fashion black satin racing collar with sharp cyber-yellow trim, luxury titanium chronograph watch visible. Clean sharp anime ink lines, gold-yellow halftone screentone, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Luc Moreau in poised, elegant standing posture. Wearing pitch-black Vanta racing suit with razor-sharp cyber-yellow geometric chevron stripes, tailored racing cut, polished bespoke racing shoes. Holding a glossy black helmet adorned with geometric yellow gemstone facets under his arm. Clean turnaround, cel-shaded anime aesthetics, neutral background
  ```

#### 8. Rodrigo Silva (`#08 SIL`) — The Sao Paulo Storm
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Rodrigo Silva, 24-year-old energetic Brazilian driver, sun-kissed tan skin, short curly black hair with bleached blonde frosted tips, radiant passionate brown eyes with infectious smile, bright cyber-yellow racing bandana tied around neck. Vibrant manga ink outlines, sunny yellow halftone dots, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Rodrigo Silva in dynamic athletic stance, flexing right arm with broad smile. Wearing modern cyber-yellow and dark carbon racing suit with tropical green-and-yellow gradient hazard stripes, athletic racing sneakers. Holding a custom yellow helmet with palm leaf silhouette graffiti. Solid neutral background, sharp cel-shaded anime rendering
  ```

---

### TIM 4: RAZORLINE (Aston Martin Vantage AMR GT3 | Pemilik: Lady Victoria Sterling)
**Palet Warna:** *Electric Magenta* (`#D946EF`) $\times$ *Razor Silver* (`#C0C5CE`)

#### 9. Theo Kade (`#09 KAD`) — The Laser Meister
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Theo Kade, 27-year-old German perfectionist racer, immaculate short platinum-blonde parted hair, icy crystalline blue eyes, razor-sharp jawline with serious composed expression. Wearing an aerodynamic metallic silver racing collar with electric magenta laser-line accents. Surgical clean manga ink lines, vivid magenta screentone, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Theo Kade in precise upright standing posture. Lean athletic physique, wearing mirror-silver racing suit with sharp magenta diagonal slashes across torso, silver racing gloves, metallic racing boots. Holding a chrome mirror-finish helmet with magenta polarized visor under arm. Neutral grey background, clean anime turnaround view
  ```

#### 10. Elena Novak (`#10 NOV`) — The Iron Valkyrie
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Elena Novak, 25-year-old fierce Czech female racing ace, high platinum-blonde ponytail with loose front bangs, piercing steel-grey eyes with bold winged black eyeliner, confident defiant smirk, small silver hoop earring. Wearing a cropped silver-and-magenta moto racing jacket over black fireproof undersuit. Bold ink contours, magenta halftone dots, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Elena Novak in commanding stance, right hand on hip. Athletic female racer build, wearing tailored silver and electric magenta racing suit, cropped racing bolero jacket, high-top racing boots. Holding a white-and-magenta helmet with winged valkyrie emblems resting on her bent knee. Neutral studio background, cel-shaded anime style
  ```

---

### TIM 5: ZERO HOUR (Chevrolet Corvette Z06 GT3.R | Pemilik: "Big Jim" Callahan)
**Palet Warna:** *Blaze Orange* (`#FF7A00`) $\times$ *Gunmetal Industrial* (`#2B2D42`)

#### 11. Hideo Mori (`#11 MRI`) — The Redline Brawler
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Hideo Mori, 29-year-old brawny Japanese-American muscle driver, broad neck and square jaw, short black mohawk with bright blaze-orange tip, intense wild grinning expression, mechanical tachometer tattoo on neck. Wearing heavy gunmetal racing collar with blaze-orange flame decals, reinforced leather strap. Gritty manga crosshatching, bold comic ink, orange halftones, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Hideo Mori in powerful brawler stance with clenched fists. Heavily muscled build, wearing gunmetal grey reinforced mechanic racing suit with rolled-up sleeves showing forearm tattoos, steel-toed industrial racing boots, reinforced knuckles gloves. A rugged blaze-orange helmet with skull tachometer stencil on the floor beside him. Neutral grey background, cel-shaded anime style
  ```

#### 12. Diego Reyes (`#12 REY`) — The Guadalajara Bull
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Diego Reyes, 28-year-old charismatic Mexican endurance driver, handsome rugged face with warm confident brown eyes, wavy thick dark brown hair, neat goatee beard, black-and-orange checkered hazard scarf tucked into racing collar. Expressive warm anime features, crisp ink line work, orange screentone dots, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Diego Reyes standing proudly, touching the team emblem on chest. Wearing deep blaze-orange and matte gunmetal racing suit with Aztec sun pattern accents on sleeves, checkered racing scarf, durable racing shoes. Holding a metallic orange helmet with gold eagle wings emblem under his arm. Clean turnaround reference, cel-shaded anime aesthetic
  ```

---

### TIM 6: ONI WORKS (Honda NSX GT3 Evo22 | Pemilik: Ryuji Sakamoto)
**Palet Warna:** *Cobalt Royal Blue* (`#3D7BFF`) $\times$ *Demon Bone White* (`#EAEBED`)

#### 13. Viktor Sokol (`#13 SOK`) — The Siberian Frost
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Viktor Sokol, 27-year-old towering Russian ice racer, extremely pale skin, icy frosty-blue eyes with unblinking gaze, very short bleached platinum hair, stoic expressionless face. Wearing a high-tech cobalt blue arctic racing collar with frost crack patterns. Cold minimalist manga lines, blue halftone screentone, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Viktor Sokol in relaxed, intimidating tall posture. Tall slender frame, wearing bone-white and cobalt royal blue thermal racing suit with ice crystal geometric patterns, heavy white racing boots. Holding a matte cobalt blue helmet with dark sapphire visor in right hand. Solid neutral background, sharp cel-shaded anime style
  ```

#### 14. Priya Aoki (`#14 AOK`) — The Cyber Kitsune
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Priya Aoki, 20-year-old half-Japanese half-Indian female prodigy driver, playful mischievous dark eyes with a wink, asymmetrical black bob haircut with cobalt blue streaks, small neon blue nine-tailed fox sticker on right cheek. Wearing a cobalt blue streetwear racing hoodie with subtle fox ear contours on hood. Energetic manga lines, pop-art blue halftone dots, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Priya Aoki in playful anime stance hugging her helmet. Petite agile female build, wearing cobalt blue racing dungarees over white techwear undersuit, oversized fox-eared hoodie, stylish chunky sneakers. Holding a pearl-white helmet painted with a glowing blue Kitsune mask. Clean turnaround view, cel-shaded anime style, neutral background
  ```

---

### TIM 7: STATIC SPEED (Lexus RC F GT3 | Pemilik: Dr. Aris Thorne)
**Palet Warna:** *Snow White* (`#F4F5F7`) $\times$ *Inverted Pitch Ink* (`#050505`)

#### 15. Gabriel Alves (`#15 ALV`) — The Monokrom Stylist
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Gabriel Alves, 26-year-old Brazilian fashion-forward driver, supermodel features with beaming bright smile, wavy dark hair tied into small topknot, wearing thick white-framed futuristic sunglasses pushed up onto forehead, pure black-and-white harlequin split racing collar. High-fashion manga ink art, stark black-and-white halftone dots, zero color, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Gabriel Alves in runway fashion pose. Wearing avant-garde split-colored racing suit (left half solid snow white, right half pure black ink), designer high-top racing boots, silver rings on fingers. Holding a split black-and-white helmet with fading Ben-Day manga dots. Pure monochrome palette, cel-shaded anime turnaround, neutral grey background
  ```

#### 16. Clara Weiss (`#16 WEI`) — The Bauhaus Architect
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Clara Weiss, 25-year-old German minimalist driver, geometric precise platinum-blonde blunt bob haircut, round thin wire-rimmed glasses, cool serene expression, pure white racing collar with 1mm black architectural grid lines. Clean ultra-sharp manga ink lines, elegant understated halftone screentone, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Clara Weiss in symmetrical balanced standing posture. Wearing tailored snow-white racing suit with minimal black architectural grid accents, white driving gloves, clean white racing shoes. Holding a minimalist white helmet with dark chrome visor symmetrically with both hands at chest level. Neutral studio background, cel-shaded anime style
  ```

---

### TIM 8: CHROME SYNDICATE (McLaren 720S GT3 | Pemilik: Lord Vincent Chen)
**Palet Warna:** *Mint Emerald* (`#00E08A`) $\times$ *Liquid Chrome Mirror* (`#D8DFE8`)

#### 17. Bento Tanaka (`#17 TAN`) — The Monsoon Emperor
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Bento Tanaka, 30-year-old master Japanese wet-weather driver, charismatic weathered face, slicked-back wavy black hair with water droplet glints, intense focused gaze, translucent emerald green rain poncho collar over chrome racing suit. Dramatic manga rain streak lines, emerald green halftone screentone, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Bento Tanaka standing with open arms embracing the storm. Wearing liquid-chrome racing suit under a translucent waterproof poncho with emerald green dragon graffiti stencil on back, wet-grip racing boots. A liquid-chrome helmet reflecting water droplets resting at his side. Solid neutral background, high-contrast cel-shaded anime style
  ```

#### 18. Felix Duval (`#18 DUV`) — The Riviera Playboy
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Felix Duval, 23-year-old flamboyant French driver, curly golden-blonde hair, dazzling green eyes with roguish wink, open silk racing collar showing gold emerald pendant necklace, charming smile. Glamorous manga ink linework, mint green screentone, sparkling anime highlights, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Felix Duval in casual leaning pose with helmet rested on shoulder. Lean graceful frame, wearing metallic seafoam-mint racing suit with gold laurel leaf embroidery, white silk gloves, luxury racing loafers. Holding a pastel mint helmet with gold laurel motifs. Neutral studio background, clean anime turnaround view
  ```

---

### TIM 9: NIGHT SHIFT (Lamborghini Huracán GT3 EVO2 | Pemilik: Klaus Richter)
**Palet Warna:** *Ultra Violet* (`#9B5CFF`) $\times$ *Deep Void Black* (`#08040C`)

#### 19. Igor Petrov (`#19 PET`) — The Ghost Operator
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Igor Petrov, 28-year-old enigmatic midnight racer, gaunt sharp facial features, messy dark purple hair with long bangs obscuring one eye, emotionless piercing violet eyes, dark techwear collar with glowing violet digital glitch pattern. Shadowy dramatic manga ink, ultraviolet halftone dots, cyber-noir aesthetic, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Igor Petrov in stealthy techwear stance with hands in pockets. Tall thin build, wearing oversized matte-black windbreaker jacket with ultraviolet utility straps over black racing suit, combat tech sneakers. A matte purple helmet with glowing violet digital radar graphics resting on the ground. Neutral grey background, cel-shaded anime style
  ```

#### 20. Omar Mbeki (`#20 MBE`) — The Horizon Hunter
* **Prompt A (2D Comms Radio Portrait):**
  ```text
  Bust-up anime portrait of Omar Mbeki, 22-year-old South African prodigy driver, warm radiant smile with sharp confident amber eyes, clean short fade haircut with carved geometric lines at temple, deep ultraviolet racing collar with tribal star constellation motif. Crisp lively manga ink outlines, deep purple halftone screentone, transparent background --transparent
  ```
* **Prompt B (Full-Body 3D Reference Concept):**
  ```text
  Full-body character concept of Omar Mbeki in relaxed modern streetwear standing pose. Athletic lean build, wearing deep ultraviolet and obsidian racing suit paired with a sleeveless black utility vest, custom purple racing sneakers. Holding a dark purple nebula helmet with southern star constellation stencil under arm. Neutral studio background, cel-shaded anime turnaround
  ```

---

## 3. Skrip Perintah Cepat via Genex Tools CLI

Untuk men-generate gambar 2D secara instan melalui terminal menggunakan Genex (biaya 7 kredit per gambar):

```bash
# Contoh 1: Kaze Ryu (Radio Portrait 2D)
npx genex image "Dynamic bust-up anime portrait of Kaze Ryu, 22-year-old male Japanese racing driver, spiky messy black hair with acid lime highlights, confident smirk, band-aid on nose, black racing suit with acid lime collar, thick manga ink outlines, halftone screentone, cel-shaded anime, transparent background" --transparent --out-dir assets/ui/characters/portraits/

# Contoh 2: Kaze Ryu (Full-Body 3D Reference Concept)
npx genex image "Full-body character concept art of Kaze Ryu, Japanese male GT3 racer in relaxed standing pose, cropped neon acid-lime puffer jacket over black racing undersuit, holding helmet under arm, clean turnaround reference, neutral grey background, cel-shaded anime" --out-dir reference-assets/characters/concepts/
```
