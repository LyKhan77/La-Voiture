#!/usr/bin/env python3
import argparse
import os
import sys
import numpy as np
from PIL import Image

CAR_RECOLOR_CONFIGS = {
    "aston_vantage": {
        "mode": "hue_shift",
        "src_hue": 130.0,
        "hue_tol": 45.0,
        "target_hex": "D946EF", # Electric Magenta
        "sat_mult": 1.2,
        "val_mult": 1.15
    },
    "lambo_huracan": {
        "mode": "hue_shift",
        "src_hue": 100.0,
        "hue_tol": 42.0,
        "target_hex": "9B5CFF", # Ultra Violet / Deep Purple
        "sat_mult": 1.25,
        "val_mult": 1.1
    },
    "mclaren_720s": {
        "mode": "hue_shift",
        "src_hue": 30.0,
        "hue_tol": 28.0,
        "target_hex": "00E08A", # Mint Emerald Green
        "sat_mult": 1.3,
        "val_mult": 1.15
    },
    "lexus_rcf": {
        "mode": "dark_to_white",
        "target_hex": "F4F5F7", # Snow White
        "accent_hex": "050505"
    },
    "bmw_m4": {
        "mode": "hue_shift",
        "src_hue": 215.0, # M-Sport blue stripes
        "hue_tol": 35.0,
        "target_hex": "FFE600", # Cyber Yellow
        "sat_mult": 1.4,
        "val_mult": 1.3
    },
    "chevy_corvette": {
        "mode": "hue_shift",
        "src_hue": 55.0,
        "hue_tol": 25.0,
        "target_hex": "FF7A00", # Blaze Orange
        "sat_mult": 1.2,
        "val_mult": 1.05
    },
    "audi_r8": {
        "mode": "hue_shift",
        "src_hue": 355.0, # Red factory stripes
        "hue_tol": 30.0,
        "target_hex": "00F0FF", # Electric Cyan
        "sat_mult": 1.4,
        "val_mult": 1.2
    },
    "mercedes_amg": {
        "mode": "accent_tint",
        "target_hex": "CCFF00" # Acid Lime
    },
    "nissan_gtr": {
        "mode": "accent_tint",
        "target_hex": "FF1E56" # Anime Crimson
    },
    "honda_nsx": {
        "mode": "accent_tint",
        "target_hex": "3D7BFF" # Cobalt Royal Blue
    }
}

def hex_to_rgb(hex_str: str):
    hex_str = hex_str.lstrip('#')
    return [int(hex_str[i:i+2], 16) / 255.0 for i in (0, 2, 4)]

def rgb_to_hsv_numpy(arr_rgb):
    r, g, b = arr_rgb[..., 0], arr_rgb[..., 1], arr_rgb[..., 2]
    maxc = np.maximum(np.maximum(r, g), b)
    minc = np.minimum(np.minimum(r, g), b)
    v = maxc
    deltac = maxc - minc
    
    with np.errstate(divide='ignore', invalid='ignore'):
        s = np.where(maxc != 0, deltac / maxc, 0.0)
    
    h = np.zeros_like(v)
    mask_r = (maxc == r) & (deltac != 0)
    mask_g = (maxc == g) & (deltac != 0)
    mask_b = (maxc == b) & (deltac != 0)
    
    with np.errstate(divide='ignore', invalid='ignore'):
        h[mask_r] = ((g[mask_r] - b[mask_r]) / deltac[mask_r]) % 6.0
        h[mask_g] = ((b[mask_g] - r[mask_g]) / deltac[mask_g]) + 2.0
        h[mask_b] = ((r[mask_b] - g[mask_b]) / deltac[mask_b]) + 4.0
    h = np.nan_to_num(h * 60.0, 0.0)
    return h, s, v

def recolor_hue_range(img_path: str, out_path: str, src_hue_deg: float, hue_tolerance: float,
                      target_hex: str, sat_mult: float = 1.0, val_mult: float = 1.0) -> bool:
    if not os.path.exists(img_path):
        return False
    im = Image.open(img_path).convert("RGBA")
    arr = np.array(im, dtype=np.float32) / 255.0
    rgb = arr[..., :3]
    h, s, v = rgb_to_hsv_numpy(rgb)
    
    tr, tg, tb = hex_to_rgb(target_hex)

    # Angular distance around 360 circle
    diff = np.abs(h - src_hue_deg)
    diff = np.minimum(diff, 360.0 - diff)
    
    # Weight: requires hue proximity and saturation >= 0.18 (excludes neutral carbon/glass)
    weight = np.clip(1.0 - (diff / hue_tolerance), 0.0, 1.0) * np.clip((s - 0.12) / 0.12, 0.0, 1.0)
    weight = weight[..., np.newaxis]
    
    # Target RGB matching luminance
    target_rgb = np.stack([v * tr * val_mult, v * tg * val_mult, v * tb * val_mult], axis=-1)
    
    blended = rgb * (1.0 - weight) + target_rgb * weight
    blended = np.clip(blended * 255.0, 0.0, 255.0).astype(np.uint8)
    
    out_img = Image.fromarray(blended, "RGB")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    out_img.save(out_path, format="PNG")
    return True

def recolor_dark_to_white(img_path: str, out_path: str, target_hex: str = "F4F5F7") -> bool:
    if not os.path.exists(img_path):
        return False
    im = Image.open(img_path).convert("RGBA")
    arr = np.array(im, dtype=np.float32) / 255.0
    rgb = arr[..., :3]
    h, s, v = rgb_to_hsv_numpy(rgb)
    tr, tg, tb = hex_to_rgb(target_hex)

    # For dark carbon (v between 0.04 and 0.45, s < 0.25): lift to clean white with inking
    mask = (v > 0.03) & (v < 0.48) & (s < 0.25)
    weight = np.clip((v - 0.03) / 0.05, 0.0, 1.0) * np.clip((0.48 - v) / 0.1, 0.0, 1.0) * mask
    weight = weight[..., np.newaxis]

    # Map darkness to white shade
    lifted_v = np.clip(0.68 + v * 0.7, 0.0, 0.98)
    target_rgb = np.stack([lifted_v * tr, lifted_v * tg, lifted_v * tb], axis=-1)

    blended = rgb * (1.0 - weight) + target_rgb * weight
    blended = np.clip(blended * 255.0, 0.0, 255.0).astype(np.uint8)
    out_img = Image.fromarray(blended, "RGB")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    out_img.save(out_path, format="PNG")
    return True

def recolor_accent_tint(img_path: str, out_path: str, target_hex: str) -> bool:
    if not os.path.exists(img_path):
        return False
    im = Image.open(img_path).convert("RGBA")
    arr = np.array(im, dtype=np.float32) / 255.0
    rgb = arr[..., :3]
    h, s, v = rgb_to_hsv_numpy(rgb)
    tr, tg, tb = hex_to_rgb(target_hex)

    # Accent tint on mid-light highlight trims (v between 0.35 and 0.75, low saturation)
    mask = (v > 0.35) & (v < 0.75) & (s < 0.2)
    weight = np.clip((v - 0.35) / 0.15, 0.0, 0.45) * np.clip((0.75 - v) / 0.15, 0.0, 1.0) * mask
    weight = weight[..., np.newaxis]

    target_rgb = np.stack([v * tr * 1.2, v * tg * 1.2, v * tb * 1.2], axis=-1)
    blended = rgb * (1.0 - weight) + target_rgb * weight
    blended = np.clip(blended * 255.0, 0.0, 255.0).astype(np.uint8)
    out_img = Image.fromarray(blended, "RGB")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    out_img.save(out_path, format="PNG")
    return True

def recolor_car(car_slug: str, base_dir: str = "assets/cars") -> bool:
    if car_slug not in CAR_RECOLOR_CONFIGS:
        return False
    cfg = CAR_RECOLOR_CONFIGS[car_slug]
    car_tex_dir = os.path.join(base_dir, car_slug, "textures")
    orig_path = os.path.join(car_tex_dir, "base_color_original.png")
    active_path = os.path.join(car_tex_dir, "base_color.png")
    team_path = os.path.join(car_tex_dir, "base_color_team.png")

    src_input = orig_path if os.path.exists(orig_path) else active_path
    if not os.path.exists(src_input):
        print(f"Error: {src_input} does not exist.", file=sys.stderr)
        return False

    mode = cfg.get("mode", "hue_shift")
    if mode == "hue_shift":
        return recolor_hue_range(
            src_input, team_path,
            cfg["src_hue"], cfg["hue_tol"], cfg["target_hex"],
            cfg.get("sat_mult", 1.0), cfg.get("val_mult", 1.0)
        )
    elif mode == "dark_to_white":
        return recolor_dark_to_white(src_input, team_path, cfg["target_hex"])
    elif mode == "accent_tint":
        return recolor_accent_tint(src_input, team_path, cfg["target_hex"])
    return False

def main():
    parser = argparse.ArgumentParser(description="La Voiture GT3 Texture Recoloring Tool")
    parser.add_argument("--car", choices=list(CAR_RECOLOR_CONFIGS.keys()), help="Car slug to recolor")
    parser.add_argument("--all", action="store_true", help="Recolor all configured cars")
    parser.add_argument("--dir", default="assets/cars", help="Base directory")
    args = parser.parse_args()

    if args.all:
        for car in CAR_RECOLOR_CONFIGS:
            if recolor_car(car, args.dir):
                print(f"[RECOLOR] {car} -> Generated base_color_team.png")
            else:
                print(f"[FAIL]    {car}")
    elif args.car:
        if recolor_car(args.car, args.dir):
            print(f"[RECOLOR] {args.car} -> Generated base_color_team.png")
        else:
            print(f"[FAIL]    {args.car}")
    else:
        print("Specify --car <slug> or --all.")

if __name__ == "__main__":
    main()
