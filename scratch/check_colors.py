import os
from PIL import Image

cars = [
    "mercedes_amg", "audi_r8", "nissan_gtr", "bmw_m4", "aston_vantage",
    "chevy_corvette", "honda_nsx", "lexus_rcf", "mclaren_720s", "lambo_huracan",
    "ferrari_296", "ford_mustang", "toyota_supra"
]

teams = [
    ("Apex Racing", "#CCFF00 (Lime)"),
    ("Neon Drift", "#00F0FF (Cyan)"),
    ("Kurogane GT", "#FF1E56 (Crimson)"),
    ("Vanta Motors", "#FFE600 (Yellow)"),
    ("Razorline", "#D946EF (Magenta)"),
    ("Zero Hour", "#FF7A00 (Orange)"),
    ("Oni Works", "#3D7BFF (Blue)"),
    ("Static Speed", "#F4F5F7 (White)"),
    ("Chrome Syndicate", "#00E08A (Green)"),
    ("Night Shift", "#9B5CFF (Purple)"),
    ("Scuderia Maranello", "#D40000 (Rosso Corsa)"),
    ("Ironhorse Motorsport", "#1E3A8A (Navy)"),
    ("Neo-Wangan Works", "#E2E8F0 (White)")
]

for idx, car in enumerate(cars):
    tex_path = f"assets/cars/{car}/textures/base_color.png"
    if not os.path.exists(tex_path):
        tex_path = f"assets/cars/{car}/{car}_body_base_color.jpg"
    
    t_name, t_col = teams[idx]
    if os.path.exists(tex_path):
        im = Image.open(tex_path).convert("RGB")
        im.thumbnail((128, 128))
        pixels = list(im.getdata())
        r = sum(p[0] for p in pixels) / len(pixels)
        g = sum(p[1] for p in pixels) / len(pixels)
        b = sum(p[2] for p in pixels) / len(pixels)
        print(f"[{idx:02d}] {t_name:20s} Target: {t_col:22s} | Car: {car:16s} AvgRGB: ({r:5.1f}, {g:5.1f}, {b:5.1f})")
    else:
        print(f"[{idx:02d}] {t_name:20s} Target: {t_col:22s} | Car: {car:16s} File missing: {tex_path}")
