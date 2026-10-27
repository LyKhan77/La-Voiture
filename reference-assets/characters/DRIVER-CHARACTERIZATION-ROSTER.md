# ROSTER KARAKTERISASI LENGKAP 20 PEMBALAP (GT3 DRIVER DOSSIER)
**Proyek:** *La Voiture* — Broadcast GT3 Motorsport Strategy Simulation  
**Direktori:** `reference-assets/characters/`  
**Gaya Visual:** Cel-Shaded Toon Anime $\times$ Manga Halftone Neo-Brutalism $\times$ Streetwear NFS Unbound  
**Pendekatan:** Hybrid (Karakter Orisinil berbasis Livery Tim dengan Inspirasi Persona Legenda Balap Dunia Nyata)

---

## 1. Filosofi Desain Karakter (Design Philosophy)

Setiap pembalap dirancang dengan prinsip **Dual-Role Visual Asset**:
1. **2D Anime Cut-In Portrait (In-Game Radio & HUD):**
   - Ilustrasi bergaya komik/manga dengan tinta tebal (*heavy ink outline*), arsir screentone halftone, dan garis kecepatan diagonal.
   - Digunakan pada banner transmisi radio pembalap ([`RaceHud.RADIO_DOCK`](file:///D:/Occupation/Porto/genex/La_Voiture/PRD/02-UI-UX-TOPOLOGY.md)) dan tabel profil pembalap.
2. **3D Rigged Humanoid Avatar (Podium & HQ Only):**
   - Model 3D ber-rig bipedal bergaya toon cel-shaded.
   - **HANYA muncul pada dua lokasi khusus:**
     - **Podium Selebrasi Kemenangan ([`podium_screen.tscn`](file:///D:/Occupation/Porto/genex/La_Voiture/PRD/05-GAMEPLAY-SYSTEMS-CAREER.md)):** Berdiri di tangga P1, P2, atau P3 mengangkat piala, mengepalkan tangan (*fist pump*), atau menyemprotkan sampanye di tengah hujan confetti.
     - **Markas Tim HQ ([`scenes/main.tscn`](file:///D:/Occupation/Porto/genex/La_Voiture/scenes/main.tscn)):** Berdiri santai di bengkel dekat mobil (*idle pose*) saat pemain mengatur riset dan upgrade part R&D.
   - *Tidak dimasukkan ke dalam kokpit mobil saat balapan*, demi menjaga performa 60 FPS tetap mulus.

---

## 2. Roster Lengkap 20 Pembalap (10 Tim Pabrikan)

---

### TIM 0: APEX RACING (Tim Utama Pemain)
**Mobil Pabrikan:** **Porsche 911 GT3 R (992)** ([`reference-assets/cars/porsche-911-gt3`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/porsche-911-gt3))  
**Pemilik Tim / Team Principal:** **Kenji "Apex" Takahashi** — Legenda balap jalanan Wangan Tokyo yang pensiun dan mendirikan tim independen beranggaran taktis. Bertindak sebagai manajer karismatik sekaligus mentor balap Ryu dan Ren.  
**Warna Livery:** *Acid Lime* (`#CCFF00`) $\times$ *Deep Charcoal* (`#0E1118`) $\times$ *Inverted White*  
**Filosofi Tim:** Inovator jalanan neo-Tokyo yang menantang hegemoni pabrikan tradisional dengan teknologi hybrid dan strategi berani.

#### 1. Kaze Ryu (`#01 RYU`) — "The High-Voltage Prodigy"
* **Inspirasi Legenda Real-Life:** *Ayrton Senna* (keberanian instingtif di limit) $\times$ *Lewis Hamilton muda* (gaya streetwear eksentrik) $\times$ *Akira Kaneda*.
* **Visual Karakter (Anime Streetwear):**
  - **Wajah & Rambut:** Pemuda usia 22 tahun, tatapan mata tajam penuh percaya diri, rambut anime hitam acak-acakan (*messy spiky*) dengan highlight ujung rambut berwarna hijau neon *Acid Lime*.
  - **Pakaian Balap:** Racing suit balap FIA hitam doff yang dipadukan dengan *oversized cropped streetwear puffer jacket* berwarna Acid Lime dengan ritsleting terbuka setengah. Mengenakan sarung tangan balap neon tanpa jari luar saat di paddock.
  - **Sepatu & Aksesoris:** High-top racing sneakers bergaya retro futuristic, kalung rantai perak tebal, plester grafiti kecil di pangkal hidung.
* **Helm:** Helm balap full-face hitam doff berhias grafiti petir Acid Lime dan stensil kanji `疾風` (Kaze / Angin Cepat), visor pelangi bunglon (*iridescent visor*). Saat di luar mobil, helm dijepit di bawah lengan kiri.
* **Persona Radio:** Antusias, beradrenalin tinggi, vokal agresif saat meminta mode OVERTAKE (*"Target locked, unleash the battery now!"*).
* **Animasi Selebrasi Podium (P1):** Mengangkat trofi emas tinggi-tinggi dengan satu tangan lalu menginjakkan satu kaki di bibir podium dengan seringai puas.
* **Stance HQ:** Bersandar santai di kap depan sasis Porsche 911 sambil memeriksa sarung tangan balapnya.

#### 2. Sora Ren (`#02 REN`) — "The Cybernetic Calculator"
* **Inspirasi Legenda Real-Life:** *Alain Prost* (si Profesor, presisi matematika ban) $\times$ *Niki Lauda* (ketenangan kalkulatif) $\times$ *Katsuragi Keima*.
* **Visual Karakter (Anime Streetwear):**
  - **Wajah & Rambut:** Pemuda usia 24 tahun, ekspresi tenang dan misterius, rambut abu-abu perak lurus berponi rapi menutupi separuh dahi.
  - **Pakaian Balap:** Racing suit monokrom ramping (*slim-fit*) berkerah tinggi ala techwear cyberpunk dengan garis sirkuit neon cyan tipis di sepanjang lengan. Rompi pelindung dada serat karbon.
  - **Sepatu & Aksesoris:** Smart-visor kacamata balap sporty tipis yang memproyeksikan data telemetri HUD mini di lensa kiri. Jam tangan instrumen balap titanium.
* **Helm:** Helm putih gading bersih dengan garis geometris heksagonal presisi, visor cermin perak (*chrome mirror visor*).
* **Persona Radio:** Nada bicara datar, fokus data, dingin namun mutlak (*"Gap is 1.2 seconds. Undercut window is optimal. Box this lap."*).
* **Animasi Selebrasi Podium:** Berdiri tegak bersedekap dada sambil tersenyum tipis dan mengangguk tenang menghormati kru garasi.
* **Stance HQ:** Berdiri tegak di samping layar telemetri MoTeC sambil mengetik data setup di tablet digital portabel.

---

### TIM 1: NEON DRIFT
**Mobil Pabrikan:** **Audi R8 LMS GT3 Evo II** ([`reference-assets/cars/audi-r8-gt3`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/audi-r8-gt3))  
**Pemilik Tim / Team Principal:** **Rei Kisaragi** — Ratu sirkuit malam Shibuya & taipan fashion streetwear cyberpunk; mendanai tim drift beralih ke kancah balap sirkuit resmi GT3 dengan estetika klub malam.  
**Warna Livery:** *Electric Cyan* (`#00F0FF`) $\times$ *Midnight Navy* (`#060B19`)  
**Filosofi Tim:** Kru malam Shibuya yang menggabungkan presisi sirkuit GT dengan gaya drift kultur jalanan Jepang.

#### 3. Makoto Ito (`#03 ITO`) — "The Apex Drifter"
* **Inspirasi Legenda Real-Life:** *Keiichi Tsuchiya* (Drift King) $\times$ *Lando Norris* (humoris & ramah media).
* **Visual:** Rambut cokelat bergelombang santai, hoodie bertudung *oversized* Electric Cyan yang dikenakan di balik racing suit terlipat ke pinggang, sneakers platform chunky.
* **Helm:** Grafiti cat semprot neon *spray-drip* dengan motif ombak omikron Jepang.
* **Selebrasi Podium:** Melompat girang ke atas podium sambil melakukan gestur *peace sign* ganda ke arah kamera siaran.

#### 4. Axel Vale (`#04 VAL`) — "The Camden Rocker"
* **Inspirasi Legenda Real-Life:** *James Hunt* (karisma rockstar tanpa kompromi) $\times$ *George Russell* (postur tinggi atletis).
* **Visual:** Pria Inggris pirang gondrong acak-acakan, jaket kulit balap robek-robek (*distressed leather racing jacket*) berpin enamel band rock, tatapan mata liar menantang.
* **Helm:** Corak bendera Union Jack monokrom grunge dengan goresan stensil cat semprot.
* **Selebrasi Podium:** Mengangkat piala seperti gitar listrik lalu tertawa lepas di tengah semprotan sampanye.

---

### TIM 2: KUROGANE GT
**Mobil Pabrikan:** **Nissan GT-R NISMO GT3** ([`reference-assets/cars/nissan-gtr-gt3`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/nissan-gtr-gt3))  
**Pemilik Tim / Team Principal:** **Daisuke Kurogane** — Taipan konglomerasi baja industri berat Yokohama & bos sindikat sirkuit; menjalankan tim dengan disiplin militer ketat dan menuntut hasil tanpa kompromi.  
**Warna Livery:** *Anime Crimson* (`#FF1E56`) $\times$ *Matte Obsidian Carbon* (`#0B0C10`)  
**Filosofi Tim:** Konglomerasi industri baja berat; gaya militeristik, kejam di trek, tanpa belas kasihan saat bertahan posisi.

#### 5. Javier Cruz (`#05 CRU`) — "The Iron Matador"
* **Inspirasi Legenda Real-Life:** *Fernando Alonso* (kegigihan banteng bertarung di segala kondisi) $\times$ *Juan Manuel Fangio*.
* **Visual:** Pria Spanyol berwajah tegas berahang keras dengan janggut tipis (*stubble*), luka goresan kecil di alis kiri, tatapan predator, rambut hitam disisir ke belakang (*slicked-back*). Racing suit berserat kevlar merah gelap berlapis pelindung bahu bertato tribal.
* **Helm:** Helm motif api merah darah dengan tanduk banteng tribal hitam di kedua sisi visor.
* **Selebrasi Podium:** Menyilangkan kedua tangan mengepal di dada (*X-guard*), menatap tajam ke kamera menantang semua rival.

#### 6. Naoki Sato (`#06 SAT`) — "The Silent Ronin"
* **Inspirasi Legenda Real-Life:** *Kimi Räikkönen* (Iceman, minim bicara, aksi 100% di kemudi) $\times$ *Takuma Sato* (agresivitas menyalip).
* **Visual:** Pemuda berambut hitam cepak militer, mengenakan masker buff kain hitam bermotif gigi taring samurai iblis (*Hannya mask*) yang menutupi hidung hingga leher.
* **Helm:** Putih matte berhias kaligrafi kanji tinta kuas hitam tebal `不退転` (Pantang Mundur).
* **Selebrasi Podium:** Menerima piala dengan kedua tangan secara formal, membungkuk sedikit (*bow*), tanpa berkata sepatah kata pun.

---

### TIM 3: VANTA MOTORS
**Mobil Pabrikan:** **BMW M4 GT3** ([`reference-assets/cars/bmw-m4-gt3`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/bmw-m4-gt3))  
**Pemilik Tim / Team Principal:** **Baron Henrik von Vanta** — Ilmuwan kedirgantaraan eksentrik dari Munich yang terobsesi dengan cat penyerap cahaya Vantablack dan efisiensi terowongan angin sirkuit.  
**Warna Livery:** *Cyber Yellow* (`#FFE600`) $\times$ *Pitch Black Vanta* (`#020202`)  
**Filosofi Tim:** Laboratorium aerodinamika rahasia Eropa Barat; pendekatan aerodinamika radikal dengan cat penyerap cahaya.

#### 7. Luc Moreau (`#07 MOR`) — "The Monaco Prodigy"
* **Inspirasi Legenda Real-Life:** *Charles Leclerc* (kecepatan kualifikasi murni & karisma elegan) $\times$ *Jules Bianchi*.
* **Visual:** Pemuda Prancis tampan bermata cokelat teduh, rambut cokelat bertekstur rapi, racing suit ultra-modern beraksen kuning cerah dengan kerah satin elegan.
* **Helm:** Corak geometris emas-kuning glossy dengan pola permata heksagonal.
* **Selebrasi Podium:** Menunjuk ke langit dengan jari telunjuk kanan sebagai dedikasi emosional, lalu memeluk piala kemenangan.

#### 8. Rodrigo Silva (`#08 SIL`) — "The Sao Paulo Storm"
* **Inspirasi Legenda Real-Life:** *Felipe Massa* (semangat Amerika Latin berapi-api) $\times$ *Rubens Barrichello*.
* **Visual:** Pemuda atletis asal Brasil, kulit sawo matang, rambut ikal pendek pirang ombre, bandana kuning terselip di leher, ekspresi penuh senyuman hangat.
* **Helm:** Gradasi kuning cerah ke hitam vanta dengan siluet daun palem tropis neon.
* **Selebrasi Podium:** Menari samba kecil di atas podium sebelum mengangkat piala ke atas kepala dengan kedua tangan.

---

### TIM 4: RAZORLINE
**Mobil Pabrikan:** **Aston Martin Vantage AMR GT3** ([`reference-assets/cars/aston-vantage-gt3`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/aston-vantage-gt3))  
**Pemilik Tim / Team Principal:** **Lady Victoria Sterling** — Miliarder venture capitalist & perancang busana haute-couture Mayfair London; menggabungkan kemewahan British aristokrat dengan presisi aerodinamika tajam.  
**Warna Livery:** *Electric Magenta* (`#D946EF`) $\times$ *Razor Silver* (`#C0C5CE`)  
**Filosofi Tim:** Tim independen beranggaran besar dengan filosofi kecepatan tajam seperti silet dan desain haute-couture.

#### 9. Theo Kade (`#09 KAD`) — "The Laser Meister"
* **Inspirasi Legenda Real-Life:** *Michael Schumacher* (etos kerja sempurna tanpa celah) $\times$ *Sebastian Vettel*.
* **Visual:** Pria Jerman berambut pirang cepak rapi, postur tegap sempurna, tatapan mata biru dingin fokus, seragam balap abu-abu perak dengan selempang magenta tajam.
* **Helm:** Helm perak krom mengilap dengan visor magenta cermin yang memantulkan lampu sorot malam.
* **Selebrasi Podium:** Lompatan podium Schumacher yang legendaris (*podium jump* dengan dua kepalan tangan ke atas).

#### 10. Elena Novak (`#10 NOV`) — "The Iron Valkyrie"
* **Inspirasi Legenda Real-Life:** *Michèle Mouton* (ratu reli legendaris tanpa rasa takut) $\times$ *Susie Wolff*.
* **Visual:** Wanita tangguh asal Ceko, rambut kuncir kuda tinggi (*high ponytail*) warna platinum blonde, tatapan mata elang bergaris celak hitam tegas (*winged eyeliner*), jaket balap crop perak dengan emblem sayap elang magenta.
* **Helm:** Helm putih-magenta dengan grafiti sayap valkyrie bersayap ganda di samping.
* **Selebrasi Podium:** Berdiri bertolak pinggang dengan piala bertumpu di paha atasnya, tersenyum bangga membungkam para rival pria.

---

### TIM 5: ZERO HOUR
**Mobil Pabrikan:** **Chevrolet Corvette Z06 GT3.R** ([`reference-assets/cars/chevy-corvette-gt3`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/chevy-corvette-gt3))  
**Pemilik Tim / Team Principal:** **"Big Jim" Callahan** — Mantan kepala kru balap legendaris Detroit; mekanik veteran berotot besar yang mengutamakan ketahanan mesin V8 Amerika dan perkelahian posisi keras di sirkuit.  
**Warna Livery:** *Blaze Orange* (`#FF7A00`) $\times$ *Gunmetal Industrial* (`#2B2D42`)  
**Filosofi Tim:** Bengkel balap jalanan distrik industri Detroit; mengandalkan tenaga torsi raksasa dan gaya brawler keras kepala.

#### 11. Hideo Mori (`#11 MRI`) — "The Redline Brawler"
* **Inspirasi Legenda Real-Life:** *Nigel Mansell* (agresivitas banteng seruduk) $\times$ *Kamui Kobayashi* (master aksi salip gila).
* **Visual:** Pria berbadan kekar dan bahu lebar, rambut mohawk hitam pendek bergaris oranye, tato tribal sirkuit di lengan bawah, mengenakan sarung tangan kulit bertulang pelindung keras.
* **Helm:** Oranye menyala dengan visor hitam pekat dan stensil tengkorak tachometer redline.
* **Selebrasi Podium:** Meninju udara berkali-kali (*power punches*) lalu mengaum kencang merayakan kemenangan podium.

#### 12. Diego Reyes (`#12 REY`) — "The Guadalajara Bull"
* **Inspirasi Legenda Real-Life:** *Sergio 'Checo' Perez* (ahli manajemen ban & pertahanan posisi legendaris) $\times$ *Carlos Sainz Jr.*
* **Visual:** Pria Meksiko berwajah ramah namun berkarakter kuat, rambut ikal hitam bergelombang rapi, racing suit oranye gelap berbalut syal hazard bermotif kotak-kotak balap.
* **Helm:** Oranye-abu metalik berhias motif burung elang Aztec emas di bagian puncak.
* **Selebrasi Podium:** Menepuk lambang tim di dada kirinya berkali-kali dengan penuh rasa bangga dan haru.

---

### TIM 6: ONI WORKS
**Mobil Pabrikan:** **Honda NSX GT3 Evo22** ([`reference-assets/cars/honda-nsx-gt3`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/honda-nsx-gt3))  
**Pemilik Tim / Team Principal:** **Ryuji "Oni" Sakamoto** — Master tuner legenda balap sirkuit bawah tanah Osaka yang memadukan mitologi iblis Jepang dengan teknologi hybrid mid-engine ultra-responsif.  
**Warna Livery:** *Cobalt Royal Blue* (`#3D7BFF`) $\times$ *Demon Bone White* (`#EAEBED`)  
**Filosofi Tim:** Tim modifikator sirkuit bawah tanah Osaka yang mengusung simbolik mitologi iblis Jepang (*Oni*).

#### 13. Viktor Sokol (`#13 SOK`) — "The Siberian Frost"
* **Inspirasi Legenda Real-Life:** *Mika Häkkinen* (terbang tenang di kecepatan mengerikan) $\times$ *Daniil Kvyat* (Torpedo agresif).
* **Visual:** Pria tinggi berkulit pucat, tatapan mata biru es menusuk, rambut pirang platinum sangat pendek, ekspresi tanpa senyum yang mengintimidasi rival.
* **Helm:** Biru kobalt doff berhias motif retakan es putih dan visor biru sapphire gelap.
* **Selebrasi Podium:** Menyilangkan kedua kaki di atas podium dengan gestur santai dingin sambil memegang piala seperti segelas kopi pagi.

#### 14. Priya Aoki (`#14 AOK`) — "The Cyber Kitsune"
* **Inspirasi Legenda Real-Life:** *Danica Patrick* (daya tarik media & ketajaman sirkuit) $\times$ *Yuki Tsunoda* (keberanian gigih & radio kocak).
* **Visual:** Gadis berdarah campuran Jepang-India, rambut hitam bob asimetris berhighlight biru kobalt, stiker grafiti rubah berekor sembilan di pipi kanan, jaket balap hoodie bertelinga kitsune mini.
* **Helm:** Putih mutiara mengilap berhias grafiti topeng rubah Kitsune dengan mata biru LED yang menyala.
* **Selebrasi Podium:** Berpose anime ceria dengan satu mata berkedip (*wink*) sambil merangkul trofi dengan kedua lengan.

---

### TIM 7: STATIC SPEED
**Mobil Pabrikan:** **Lexus RC F GT3** ([`reference-assets/cars/lexus-rcf-gt3`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/lexus-rcf-gt3))  
**Pemilik Tim / Team Principal:** **Dr. Aris Thorne** — Arsitek minimalis & pelopor teknologi tampilan grafis monokrom; menganggap sirkuit balap sebagai kanvas instalasi seni kinetik bertempo tinggi.  
**Warna Livery:** *Snow White* (`#F4F5F7`) $\times$ *Inverted Pitch Ink* (`#050505`)  
**Filosofi Tim:** Representasi visual murni estetika *Snap-Invert* dan *Halftone Manga* *La Voiture*; tim monokrom hitam-putih tanpa warna primer.

#### 15. Gabriel Alves (`#15 ALV`) — "The Monokrom Stylist"
* **Inspirasi Legenda Real-Life:** *Lewis Hamilton di Paddock Fashion Week* $\times$ *Daniel Ricciardo* (senyum lebar periang).
* **Visual:** Pembalap berpenampilan bak model runway catwalk internasional, kacamata hitam berbingkai putih tebal, racing suit terbagi dua sisi (*half black / half white harlequin*), sneakers desainer kustom.
* **Helm:** Setengah putih cerah setengah hitam pekat dengan pola titik Ben-Day dots manga halftone yang memudar.
* **Selebrasi Podium:** Melepaskan sepatu balapnya lalu meminum sampanye dari sepatu (*The Shoey Celebration*) sambil tertawa gembira.

#### 16. Clara Weiss (`#16 WEI`) — "The Bauhaus Architect"
* **Inspirasi Legenda Real-Life:** *Nico Rosberg* (intelektual teknis perfeksionis) $\times$ *Jenson Button* (gaya mengemudi super halus).
* **Visual:** Wanita Jerman berambut pirang lurus berpotongan bob geometris sangat presisi, kacamata bingkai kawat bulat, racing suit putih bersih tanpa stiker sponsor mencolok (minimalis murni).
* **Helm:** Putih arsitektural bergaris kisi grid tipis hitam $1\text{mm}$, visor krom gelap.
* **Selebrasi Podium:** Mengangkat piala setinggi dada dengan kedua tangan berbalut sarung tangan putih, tersenyum anggun dan simetris.

---

### TIM 8: CHROME SYNDICATE
**Mobil Pabrikan:** **McLaren 720S GT3 Evo** ([`reference-assets/cars/mclaren-720s-gt3`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/mclaren-720s-gt3))  
**Pemilik Tim / Team Principal:** **Lord Vincent Chen** — Taipan kasino & konsorsium sirkuit Guia Macau; mengendalikan sindikat balap sirkuit basah beranggaran tak terbatas dengan sasis aerodinamika karbon McLaren.  
**Warna Livery:** *Mint Emerald* (`#00E08A`) $\times$ *Liquid Chrome Mirror* (`#D8DFE8`)  
**Filosofi Tim:** Sindikat sirkuit ultra-mewah dari Macau; dominan dalam kondisi trek basah dan hujan badai ekstrem.

#### 17. Bento Tanaka (`#17 TAN`) — "The Monsoon Emperor"
* **Inspirasi Legenda Real-Life:** *Ayrton Senna saat Hujan (Donington 1993)* $\times$ *Max Verstappen (Brazil 2016)*. Pembalap terbaik di sirkuit basah pada simulasi (*Wet Skill: 0.96*).
* **Visual:** Pria karismatik usia 30 tahun, rambut hitam bergelombang agak basah yang disisir ke belakang, jubah ponco transparan tahan air bergrafiti hijau zamrud di atas seragam kromnya.
* **Helm:** Krom cermin cair memantulkan tetesan air hujan dengan garis naga air emerald meliuk di sekeliling helm.
* **Selebrasi Podium:** Menengadahkan kepala ke atas menyambut guyuran hujan dan confetti, merentangkan kedua tangan lebar-lebar merayakan status raja hujan.

#### 18. Felix Duval (`#18 DUV`) — "The Riviera Playboy"
* **Inspirasi Legenda Real-Life:** *Gilles Villeneuve* (keberanian melayang di tikungan) $\times$ *Pierre Gasly*.
* **Visual:** Pemuda Prancis flamboyan berambut pirang ikal, kerah racing suit sutra terbuka memperlihatkan kalung liontin zamrud, senyum menawan yang memikat penggemar.
* **Helm:** Hijau mint pastel metalik dengan aksen daun laurel kemenangan emas.
* **Selebrasi Podium:** Meniupkan ciuman ke arah tribun penonton lalu menyandarkan piala di bahu kanannya dengan santai.

---

### TIM 9: NIGHT SHIFT
**Mobil Pabrikan:** **Lamborghini Huracán GT3 EVO2** ([`reference-assets/cars/lambo-huracan-gt3`](file:///D:/Occupation/Porto/genex/La_Voiture/reference-assets/cars/lambo-huracan-gt3))  
**Pemilik Tim / Team Principal:** **Klaus "Shadow" Richter** — Tokoh pemberontak kultur klub malam Berlin dan spesialis balap malam sirkuit gelap; mengandalkan raungan beringas V10 Italia di bawah temaram lampu ultraviolet.  
**Warna Livery:** *Ultra Violet* (`#9B5CFF`) $\times$ *Deep Void Black* (`#08040C`)  
**Filosofi Tim:** Kru balap underground jalanan Berlin; beroperasi di zona bayangan, spesialis balapan malam hari dan kondisi suhu aspal dingin.

#### 19. Igor Petrov (`#19 PET`) — "The Ghost Operator"
* **Inspirasi Legenda Real-Life:** *Robert Kubica* (ketangguhan baja kembali dari musibah) $\times$ *Vitaly Petrov*.
* **Visual:** Pria berpostur kurus tinggi berwajah dingin misterius, rambut ungu gelap acak-acakan yang menutupi satu mata, jaket techwear hoodie tahan angin berwarna ultraviolet dengan banyak saku taktis.
* **Helm:** Ungu gelap matte dengan corak radar digital glitchy dan visor ungu polarized.
* **Selebrasi Podium:** Mengangkat piala setinggi mata lalu menatap piala tersebut dengan pandangan tajam tanpa emosi berlebihan.

#### 20. Omar Mbeki (`#20 MBE`) — "The Horizon Hunter"
* **Inspirasi Legenda Real-Life:** *Jody Scheckter* (juara dunia Afrika Selatan pertama) $\times$ *Oscar Piastri* (ketenangan luar biasa di usia muda).
* **Visual:** Pemuda Afrika Selatan berpostur atletis ramping, senyum ramah percaya diri, rambut fade pendek rapi dengan ukiran pola tribal di pelipis, racing suit ungu berpadu rompi windbreaker hitam modern.
* **Helm:** Ungu nebula bergradasi ke hitam dengan grafiti stensil konstelasi bintang selatan.
* **Selebrasi Podium:** Melompat turun dari tangga podium untuk berpose jongkok gaya streetwear modern (*street squat pose*) di depan trofi kemenangannya.

---

### TIM 10: SCUDERIA MARANELLO
**Mobil Pabrikan:** **Ferrari 296 GT3** (`reference-assets/cars/ferrari-296-gt3`)  
**Pemilik Tim / Team Principal:** **Enzo Cavalli** — Taipan mode haute couture Milan dan kurator seni modern yang memadukan warisan balap darah murni Maranello dengan aerodinamika radikal abad ke-21. Menuntut kesempurnaan estetika dan presisi telemetri di setiap tikungan.  
**Warna Livery:** *Rosso Corsa* (`#E60026`) $\times$ *Solar Gold Accent* (`#FFD000`) $\times$ *Deep Carbon Obsidian* (`#0A0A0A`)  
**Filosofi Tim:** Kemegahan aristokrasi balap Italia; kecepatan murni yang dibalut keanggunan eksotis dan teknologi hybrid aero mutakhir.

#### 21. Marco Bellini (`#21 BEL`) — "The Monza Virtuoso"
* **Inspirasi Legenda Real-Life:** *Michele Alboreto* (karisma pejuang Ferrari sejati) $\times$ *Lorenzo Bandini* (gairah balap Italia) $\times$ *Giancarlo Fisichella*.
* **Visual Karakter (Anime Streetwear):**
  - **Wajah & Rambut:** Pemuda Italia usia 23 tahun berparas flamboyan, senyum menawan penuh percaya diri, rambut ikal hitam bertekstur lebat disisir samping dengan highlight merah tua (*dark crimson*).
  - **Pakaian Balap:** Racing suit merah menyala *Rosso Corsa* beraksen striping emas tipis pada bahu, dipadukan jaket bomber balap satin hitam berkerah terbuka bergaya streetwear Milan.
  - **Sepatu & Aksesoris:** Kacamata hitam berbingkai emas tipis yang diselipkan di kerah leher, sarung tangan balap merah berpanel pelindung titanium, jam tangan kronograf mewah.
* **Helm:** Merah gloss dengan strip tricolor bendera Italia vertikal di bagian tengah, visor cermin emas (*solar gold mirror visor*).
* **Persona Radio:** Emosional, penuh gairah balap, ekspresif saat duel sengit (*"Mama mia! The balance is exquisite! Push, push, we take the lead!"*).
* **Animasi Selebrasi Podium (P1):** Mencondongkan badan ke depan lalu mencium piala emas dengan penuh penghormatan sebelum mengangkatnya tinggi-tinggi ke arah langit.
* **Stance HQ:** Berdiri santai menyandarkan satu lengan di atas kap belakang Ferrari 296 GT3 sambil memutar-mutar kacamata hitam di tangan kanannya.

#### 22. Alessia Rossi (`#22 ROS`) — "The Aero Donna"
* **Inspirasi Legenda Real-Life:** *Lella Lombardi* (pencetak poin wanita legendaris Italia) $\times$ *Maria Teresa de Filippis*.
* **Visual Karakter (Anime Streetwear):**
  - **Wajah & Rambut:** Wanita muda usia 25 tahun asal Bologna, tatapan mata cokelat hazel tajam berwibawa, rambut pirang gelap lurus dipotong bob pendek asimetris yang rapi.
  - **Pakaian Balap:** Racing suit slim-fit hitam karbon doff dengan panel dada dan lengan merah Rosso Corsa tegas, rompi techwear serat karbon dengan saku telemetri kompak.
  - **Sepatu & Aksesoris:** Racing boots merah beraksen sol hitam tebal, earset radio mikro nirkabel di telinga kiri, sarung tangan balap dengan grip silikon emas.
* **Helm:** Hitam matte berpadu corak grafiti aero streamlines merah menyala dan aksen stensil mahkota daun salam emas.
* **Persona Radio:** Tegas, presisi, fokus pada stabilitas downforce dan slipstream (*"Rear downforce is locked. Keep the pace steady, the apex is ours."*).
* **Animasi Selebrasi Podium:** Berdiri tegak elegan bersedekap dada sambil memegang piala di sisi pinggangnya dengan senyum anggun dan percaya diri.
* **Stance HQ:** Memeriksa layar telemetri suspensi di pit wall dengan tablet digital sambil berdiskusi intens dengan kepala mekanik.

---

### TIM 11: IRONHORSE MOTORSPORT
**Mobil Pabrikan:** **Ford Mustang GT3** (`reference-assets/cars/ford-mustang-gt3`)  
**Pemilik Tim / Team Principal:** **"Jax" Jackson** — Veteran kepala kru balap mobil stok Detroit berotot liat; pria bertopi koboi dan rompi kulit yang memandang balapan GT3 sebagai arena pertarungan banteng mekanis tanpa kompromi.  
**Warna Livery:** *Steel Navy Blue* (`#1D3557`) $\times$ *Hazard Blaze Orange* (`#FF5400`) $\times$ *Raw Brushed Metal* (`#B0B7C3`)  
**Filosofi Tim:** Otot liar distrik industri Motor City Detroit; suara gahar V8 naturally aspirated, ketahanan sasis baja, dan gaya bertarung agresif jarak dekat (*door-to-door brawling*).

#### 23. Colt Vance (`#23 VAN`) — "The Detroit Brawler"
* **Inspirasi Legenda Real-Life:** *Parnelli Jones* (raja sirkuit jalanan Trans-Am tanpa rasa takut) $\times$ *Dan Gurney* (pelopor inovasi dan keberanian Amerika).
* **Visual Karakter (Anime Streetwear):**
  - **Wajah & Rambut:** Pria Amerika usia 26 tahun bertubuh kekar tegap, rahang persegi keras berjanggut tipis (*rugged stubble*), rambut cokelat pirang bergaya undercut acak-acakan.
  - **Pakaian Balap:** Racing suit biru baja tahan api yang dipadukan dengan rompi denim robek ber-emblem kuda liar Mustang bordir besar di punggungnya.
  - **Sepatu & Aksesoris:** Sarung tangan balap kulit cokelat bertulang pelindung buku jari, sepatu balap mid-top bernuansa koboi retro, bandana oranye di pergelangan tangan kiri.
* **Helm:** Biru dongker doff dengan grafiti tengkorak kuda besi bertanduk dan garis chevron hazard oranye menyala di rahang helm.
* **Persona Radio:** Keras, penuh tawa percaya diri, bersemangat saat kontak bodi mobil (*"Let that V8 eat! Rubbing is racing, boys, I'm diving inside!"*).
* **Animasi Selebrasi Podium:** Mengangkat trofi dengan dua tangan lalu menghentakkannya ke udara disertai auman semangat ke arah penonton paddock.
* **Stance HQ:** Duduk santai di atas ban balap bekas sambil mengunyah tusuk gigi dan mengamati mesin V8 Mustang yang sedang di-tuning.

#### 24. Wyatt Cooper (`#24 COO`) — "The High-Plains Drifter"
* **Inspirasi Legenda Real-Life:** *Mark Donohue* (Captain Nice, mekanik jenius sekaligus pembalap tanpa ragu) $\times$ *Carroll Shelby*.
* **Visual Karakter (Anime Streetwear):**
  - **Wajah & Rambut:** Pemuda jangkung usia 24 tahun asal Texas, tatapan mata abu-abu dingin fokus, rambut hitam lurus berantakan yang sering tertutup topi trucker terbalik saat di paddock.
  - **Pakaian Balap:** Racing suit abu-abu baja berserat kevlar dengan strip balap ganda oranye terang vertikal dari kerah hingga ujung kaki.
  - **Sepatu & Aksesoris:** Kacamata hitam aviator berbingkai perak tebal, jam tangan mekanik militer analog, sarung tangan balap bermotif sirkuit cetak.
* **Helm:** Abu-abu brushed metal dengan motif garis balap klasik ganda oranye dan visor hitam pekat anti-silau matahari senja.
* **Persona Radio:** Santai, tenang di bawah tekanan, taktis saat pengereman lambat (*"Draft acquired. Late braking into turn four... got him clean."*).
* **Animasi Selebrasi Podium:** Menyandarkan trofi di salah satu pundaknya lalu memberikan gestur hormat dua jari santai ke kamera.
* **Stance HQ:** Membuka kap mesin serat karbon Mustang dan menyetel bilah sayap depan dengan obeng torsi di tangan.

---

### TIM 12: NEO-WANGAN WORKS
**Mobil Pabrikan:** **Toyota GR Supra GT** (`reference-assets/cars/toyota-supra-gt`)  
**Pemilik Tim / Team Principal:** **Kenichi Shindo** — Tuner legenda jalan layang Shuto Expressway Daikoku Futo yang kini memimpin operasi balap sirkuit profesional resmi dengan etos perakitan mesin tangan (*Takumi precision*).  
**Warna Livery:** *Pearl Ghost White* (`#F8F9FA`) $\times$ *Infrared Neo-Red* (`#FF0055`) $\times$ *Ink Black Halftone* (`#050505`)  
**Filosofi Tim:** Kultur tuner jalanan Wangan Tokyo bertemu presisi GT3 sirkuit dunia; responsivitas turbo instan, bobot gesit di chicane, dan gaya grafiti manga halftone murni.

#### 25. Hayato Kazama (`#25 KAZ`) — "The Midnight Ghost"
* **Inspirasi Legenda Real-Life:** *Akio Asakura (Wangan Midnight)* $\times$ *Keiichi Tsuchiya muda* $\times$ *Takumi Fujiwara*.
* **Visual Karakter (Anime Streetwear):**
  - **Wajah & Rambut:** Pemuda Jepang usia 22 tahun asal Shinjuku, sorot mata tajam berkonsentrasi tinggi dengan pupil kemerahan redup, rambut hitam pekat berponi belah tengah khas anime 90-an modern.
  - **Pakaian Balap:** Jaket racing windbreaker putih mutiara bermotif kanji reflektif `湾岸` (Wangan) di dada kanan, dipadukan celana balap hitam berpotongan streetwear longgar (*tapered track pants*).
  - **Sepatu & Aksesoris:** Sneakers balap retro putih-merah bersol tipis untuk sensitivitas pedal heel-and-toe maksimal, plester hitam di dagu.
* **Helm:** Putih mutiara mengilap berhias kaligrafi sapuan kuas kanji tinta hitam `鬼神` (Oni Demon God) dan visor merah infrared pelangi.
* **Persona Radio:** Pendiam, hanya bicara saat perlu, sangat peka terhadap grip aspal (*"Boost is peaking. Car is rotating beautifully. Clearing the pack now."*).
* **Animasi Selebrasi Podium (P1):** Berdiri tenang di puncak podium, menurunkan resleting jaket windbreaker-nya sedikit, lalu mengangkat trofi setinggi dada dengan seringai tipis misterius.
* **Stance HQ:** Berjongkok di samping roda depan Supra memeriksa keausan tapak ban slick dengan telapak tangannya.

#### 26. Rin Takahashi (`#26 TAK`) — "The Touge Empress"
* **Inspirasi Legenda Real-Life:** *Satoshi Motoyama* (ketangguhan JGTC/Super GT legendaris) $\times$ *Juichi Wakisaka*.
* **Visual Karakter (Anime Streetwear):**
  - **Wajah & Rambut:** Gadis muda usia 21 tahun asal Gunma, senyum berani dan ceria, rambut panjang merah tua diikat ekor kuda tinggi (*high anime ponytail*) dengan dua jepit rambut perak berbentuk kunci pas mini.
  - **Pakaian Balap:** Racing suit putih bersih beraksen garis halftone manga merah neon di sepanjang paha dan pinggang, sarung tangan balap merah berpotongan pendek.
  - **Sepatu & Aksesoris:** High-top sneakers merah mencolok dengan tali sepatu putih neon, smartwatch dengan pemantau detak jantung dan G-force.
* **Helm:** Gradasi merah infrared ke putih mutiara dengan ilustrasi manga bunga sakura mekar yang terbang terbawa angin kecepatan tinggi.
* **Persona Radio:** Ceria, lincah, selalu bersemangat saat melibas tikungan kombinasi S (*"Whew! That chicane was butter! Tyres are singing, let's hunt down P1!"*).
* **Animasi Selebrasi Podium:** Melompat ke podium dengan kedua tangan membentuk pose V-sign di dekat mata sambil tersenyum lebar ke arah kamera penggemar.
* **Stance HQ:** Bersandar di pintu samping Supra sambil memegang botol minum olahraga dan mendengarkan musik lewat headphone nirkabel.

---

## 3. Matriks Referensi Tim, Mobil Pabrikan & Karakter Pembalap

| Kode | Nama Pembalap | Tim | Mobil GT3 | Pemilik Tim (Principal) | Aksen Warna | Pose Selebrasi Podium |
| :---: | :--- | :--- | :--- | :--- | :---: | :--- |
| `RYU` | Kaze Ryu | Apex Racing | Porsche 911 GT3 R | Kenji Takahashi | Acid Lime (`#CCFF00`) | Angkat Trofi 1 Tangan + Injak Podium |
| `REN` | Sora Ren | Apex Racing | Porsche 911 GT3 R | Kenji Takahashi | Cyan Sirkuit (`#00F0FF`) | Sedekap Dada + Senyum Tipis |
| `ITO` | Makoto Ito | Neon Drift | Audi R8 LMS GT3 | Rei Kisaragi | Electric Cyan (`#00F0FF`) | Lompat Girang + Double Peace Sign |
| `VAL` | Axel Vale | Neon Drift | Audi R8 LMS GT3 | Rei Kisaragi | Cyan / Denim (`#00C2FF`) | Piala Gitar Listrik + Tawa Rockstar |
| `CRU` | Javier Cruz | Kurogane GT | Nissan GT-R NISMO | Daisuke Kurogane | Anime Crimson (`#FF1E56`) | Silang Tangan Mengepal (X-Guard) |
| `SAT` | Naoki Sato | Kurogane GT | Nissan GT-R NISMO | Daisuke Kurogane | Blood Crimson (`#D60036`) | Ambil Piala + Membungkuk Sopan |
| `MOR` | Luc Moreau | Vanta Motors | BMW M4 GT3 | Henrik von Vanta | Cyber Yellow (`#FFE600`) | Tunjuk Jari ke Langit + Peluk Piala |
| `SIL` | Rodrigo Silva | Vanta Motors | BMW M4 GT3 | Henrik von Vanta | Samba Gold (`#FFD000`) | Tarian Samba Ringan di Podium |
| `KAD` | Theo Kade | Razorline | Aston Martin Vantage | Lady Victoria Sterling | Electric Magenta (`#D946EF`) | Schumacher Podium Jump |
| `NOV` | Elena Novak | Razorline | Aston Martin Vantage | Lady Victoria Sterling | Magenta Rose (`#FF2E93`) | Tolak Pinggang + Piala di Paha |
| `MRI` | Hideo Mori | Zero Hour | Corvette Z06 GT3.R | "Big Jim" Callahan | Blaze Orange (`#FF7A00`) | Power Punches Tinju Udara |
| `REY` | Diego Reyes | Zero Hour | Corvette Z06 GT3.R | "Big Jim" Callahan | Desert Orange (`#E65C00`) | Tepuk Lambang Dada Bangga |
| `SOK` | Viktor Sokol | Oni Works | Honda NSX GT3 | Ryuji Sakamoto | Cobalt Blue (`#3D7BFF`) | Silang Kaki Santai di Tangga P1 |
| `AOK` | Priya Aoki | Oni Works | Honda NSX GT3 | Ryuji Sakamoto | Royal Blue (`#2463EB`) | Wink Satu Mata + Rangkul Piala |
| `ALV` | Gabriel Alves | Static Speed | Lexus RC F GT3 | Dr. Aris Thorne | Snow White (`#F4F5F7`) | The Shoey (Minum dari Sepatu Balap) |
| `WEI` | Clara Weiss | Static Speed | Lexus RC F GT3 | Dr. Aris Thorne | Inverted Black (`#050505`)| Angkat Piala Simetris Elegan |
| `TAN` | Bento Tanaka | Chrome Syndicate| McLaren 720S GT3 | Lord Vincent Chen | Mint Emerald (`#00E08A`) | Rentangkan Kedua Tangan ke Langit |
| `DUV` | Felix Duval | Chrome Syndicate| McLaren 720S GT3 | Lord Vincent Chen | Seafoam Mint (`#34D399`) | Tiup Ciuman + Piala di Pundak |
| `PET` | Igor Petrov | Night Shift | Lambo Huracán GT3 | Klaus Richter | Ultra Violet (`#9B5CFF`) | Tatap Trofi Dingin Setinggi Mata |
| `MBE` | Omar Mbeki | Night Shift | Lambo Huracán GT3 | Klaus Richter | Deep Purple (`#7C3AED`) | Street Squat Pose di Depan Trofi |
| `BEL` | Marco Bellini | Scuderia Maranello | Ferrari 296 GT3 | Enzo Cavalli | Rosso Corsa (`#E60026`) | Cium Trofi Emas + Angkat ke Langit |
| `ROS` | Alessia Rossi | Scuderia Maranello | Ferrari 296 GT3 | Enzo Cavalli | Solar Gold (`#FFD000`) | Sedekap Dada Elegan + Senyum Anggun |
| `VAN` | Colt Vance | Ironhorse Motorsport | Ford Mustang GT3 | "Jax" Jackson | Blaze Orange (`#FF5400`) | Hentakkan Trofi 2 Tangan + Auman Keras |
| `COO` | Wyatt Cooper | Ironhorse Motorsport | Ford Mustang GT3 | "Jax" Jackson | Steel Navy (`#1D3557`) | Trofi di Pundak + Hormat 2 Jari |
| `KAZ` | Hayato Kazama | Neo-Wangan Works | Toyota GR Supra GT | Kenichi Shindo | Infrared Red (`#FF0055`) | Turunkan Resleting + Trofi di Dada |
| `TAK` | Rin Takahashi | Neo-Wangan Works | Toyota GR Supra GT | Kenichi Shindo | Pearl White (`#F8F9FA`) | Pose V-Sign Ceria di Kedua Mata |

---

## 4. Standar Eksekusi Produksi (Production Specifications)

### 4.1 Untuk Ilustrasi 2D (Comms Radio & UI Dossier)
* **Prompt Format:**
  `Manga portrait of [Deskripsi Karakter], [Livery Color] accents, extreme anime facial expression, heavy black ink outlines, Ben-Day dot halftone screentone background, streetwear motorsport fashion, Neo-Tokyo brutalist typography, transparent background --transparent`
* **Penyimpanan Aset:** Simpan ke `assets/ui/characters/portraits/<driver_code>.png` (resolusi $512 \times 512$ atau $1024 \times 1024$).

### 4.2 Untuk Model 3D Rigged (Podium & HQ)
* **Input ke AI Generator:** Gunakan gambar 2D yang dihasilkan di atas sebagai input ke `npx genex character --image ...` atau `meshy_image_to_3d` + auto-rigging.
* **Spesifikasi Model 3D:**
  - Format: `.glb` dengan skeleton bipedal humanoid (kompatibel dengan clip Mixamo/Uthana).
  - Polycount: Target $\sim 25.000 - 35.000$ tris (sangat ringan untuk layar podium & HQ).
  - Shader: Menggunakan shader toon yang sama dengan bodi mobil (`materials/toon_character.tres`) untuk keseragaman gaya seni anime.
* **Penyimpanan Aset:** Simpan ke `assets/characters/models/<driver_code>_avatar.glb`.
