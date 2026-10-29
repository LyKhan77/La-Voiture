import os
import numpy as np
from PIL import Image

TEAMS_DATA = [
    {
        "id": 0, "name": "Apex Racing", "car": "mercedes_amg", "car_name": "Mercedes-AMG GT3",
        "target_name": "Acid Lime", "target_hex": "#CCFF00", "accent_hex": "#0E1118",
        "current_status": "Dark Charcoal / Abu-abu gelap dengan minim aksen lime",
        "action": "Aksen Acid Lime pada grille, side skirts, mirrors, dan rear wing",
        "mode": "accent", "src_hue": 0, "tolerance": 0
    },
    {
        "id": 1, "name": "Neon Drift", "car": "audi_r8", "car_name": "Audi R8 LMS GT3",
        "target_name": "Electric Cyan", "target_hex": "#00F0FF", "accent_hex": "#060B19",
        "current_status": "Abu-abu gelap dengan strip merah standar pabrikan",
        "action": "Ubah striping merah menjadi Electric Cyan cerah",
        "mode": "shift_red_to_cyan", "src_hue": 0, "tolerance": 25
    },
    {
        "id": 2, "name": "Kurogane GT", "car": "nissan_gtr", "car_name": "Nissan GT-R NISMO GT3",
        "target_name": "Anime Crimson", "target_hex": "#FF1E56", "accent_hex": "#0B0C10",
        "current_status": "Putih / Perak NISMO standar",
        "action": "Perkuat aksen Anime Crimson dan matte obsidian carbon",
        "mode": "accent", "src_hue": 0, "tolerance": 0
    },
    {
        "id": 3, "name": "Vanta Motors", "car": "bmw_m4", "car_name": "BMW M4 GT3",
        "target_name": "Cyber Yellow", "target_hex": "#FFE600", "accent_hex": "#020202",
        "current_status": "Abu-abu dengan decal M-Sport (biru-merah) standar",
        "action": "Ubah aksen bodi menjadi Cyber Yellow kontras di atas bodi hitam Vanta",
        "mode": "shift_to_yellow", "src_hue": 220, "tolerance": 40
    },
    {
        "id": 4, "name": "Razorline", "car": "aston_vantage", "car_name": "Aston Martin Vantage GT3",
        "target_name": "Electric Magenta", "target_hex": "#D946EF", "accent_hex": "#C0C5CE",
        "current_status": "British Racing Green (Hijau Tua) - Mismatched!",
        "action": "Recolor seluruh panel hijau menjadi Electric Magenta",
        "mode": "shift_green_to_magenta", "src_hue": 130, "tolerance": 45
    },
    {
        "id": 5, "name": "Zero Hour", "car": "chevy_corvette", "car_name": "Chevy Corvette Z06 GT3",
        "target_name": "Blaze Orange", "target_hex": "#FF7A00", "accent_hex": "#2B2D42",
        "current_status": "Kuning C8.R standar pabrikan",
        "action": "Shift warna bodi dari kuning menjadi Blaze Orange tajam",
        "mode": "shift_yellow_to_orange", "src_hue": 55, "tolerance": 25
    },
    {
        "id": 6, "name": "Oni Works", "car": "honda_nsx", "car_name": "Honda NSX GT3",
        "target_name": "Cobalt Royal Blue", "target_hex": "#3D7BFF", "accent_hex": "#EAEBED",
        "current_status": "Abu-abu karbon polos",
        "action": "Tambahkan panel bodi Cobalt Blue dan aksen Demon Bone White",
        "mode": "accent", "src_hue": 0, "tolerance": 0
    },
    {
        "id": 7, "name": "Static Speed", "car": "lexus_rcf", "car_name": "Lexus RC F GT3",
        "target_name": "Snow White", "target_hex": "#F4F5F7", "accent_hex": "#050505",
        "current_status": "Hitam karbon matte polos - Mismatched!",
        "action": "Inversi panel bodi utama menjadi Snow White dengan inking hitam",
        "mode": "invert_to_white", "src_hue": 0, "tolerance": 0
    },
    {
        "id": 8, "name": "Chrome Syndicate", "car": "mclaren_720s", "car_name": "McLaren 720S GT3",
        "target_name": "Mint Emerald Green", "target_hex": "#00E08A", "accent_hex": "#D8DFE8",
        "current_status": "Papaya Orange (Oranye) standar McLaren - Mismatched!",
        "action": "Shift seluruh bodi oranye menjadi Mint Emerald Green",
        "mode": "shift_orange_to_mint", "src_hue": 30, "tolerance": 30
    },
    {
        "id": 9, "name": "Night Shift", "car": "lambo_huracan", "car_name": "Lamborghini Huracán GT3",
        "target_name": "Ultra Violet / Purple", "target_hex": "#9B5CFF", "accent_hex": "#08040C",
        "current_status": "Verde Mantis (Hijau Neon) - Mismatched!",
        "action": "Shift panel bodi hijau menjadi Ultra Violet / Deep Purple",
        "mode": "shift_green_to_purple", "src_hue": 100, "tolerance": 40
    },
    {
        "id": 10, "name": "Scuderia Maranello", "car": "ferrari_296", "car_name": "Ferrari 296 GT3",
        "target_name": "Rosso Corsa", "target_hex": "#D40000", "accent_hex": "#FFD000",
        "current_status": "Rosso Corsa Red dengan gold / carbon accents - SUDAH SESUAI",
        "action": "Dipertahankan (Livery asli sudah akurat)",
        "mode": "keep", "src_hue": 0, "tolerance": 0
    },
    {
        "id": 11, "name": "Ironhorse Motorsport", "car": "ford_mustang", "car_name": "Ford Mustang GT3",
        "target_name": "Steel Navy Blue", "target_hex": "#1E3A8A", "accent_hex": "#FF5400",
        "current_status": "Steel Navy Blue & orange hazard accents - SUDAH SESUAI",
        "action": "Dipertahankan (Livery asli sudah akurat)",
        "mode": "keep", "src_hue": 0, "tolerance": 0
    },
    {
        "id": 12, "name": "Neo-Wangan Works", "car": "toyota_supra", "car_name": "Toyota Supra GT",
        "target_name": "Pearl Ghost White", "target_hex": "#E2E8F0", "accent_hex": "#FF0055",
        "current_status": "Pearl White & infrared kanji accents - SUDAH SESUAI",
        "action": "Dipertahankan (Livery asli sudah akurat)",
        "mode": "keep", "src_hue": 0, "tolerance": 0
    }
]

def make_recolor_previews():
    out_dir = "temp/livery_previews"
    os.makedirs(out_dir, exist_ok=True)
    
    # Process textures and generate crops for Before vs After
    for t in TEAMS_DATA:
        car = t["car"]
        tex_path = f"assets/cars/{car}/textures/base_color.png"
        if not os.path.exists(tex_path):
            tex_path = f"assets/cars/{car}/{car}_body_base_color.jpg"
            
        if not os.path.exists(tex_path):
            continue
            
        orig_img = Image.open(tex_path).convert("RGB")
        orig_img.thumbnail((600, 600))
        orig_path = f"{out_dir}/{car}_orig.jpg"
        orig_img.save(orig_path, quality=85)
        
        # Check if we have recolored version
        recolored_path = f"temp/recolor_preview/{car}_recolored.jpg"
        # If exists copy or use, else create thumbnail
        if car == "aston_vantage":
            recolored_source = "temp/recolor_preview/aston_vantage_magenta.jpg"
        elif car == "lambo_huracan":
            recolored_source = "temp/recolor_preview/lambo_huracan_purple.jpg"
        elif car == "mclaren_720s":
            recolored_source = "temp/recolor_preview/mclaren_720s_mint.jpg"
        else:
            recolored_source = None
            
        if recolored_source and os.path.exists(recolored_source):
            rec_img = Image.open(recolored_source).convert("RGB")
            rec_img.thumbnail((600, 600))
            rec_img.save(f"{out_dir}/{car}_recolored.jpg", quality=85)

make_recolor_previews()
print("Preview images generated in temp/livery_previews/")
