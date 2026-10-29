import os
import numpy as np
from PIL import Image

def recolor_hue_range(img_path, out_path, src_hue_deg, hue_tolerance, target_hex, sat_mult=1.0, val_mult=1.0):
    im = Image.open(img_path).convert("RGBA")
    arr = np.array(im, dtype=np.float32) / 255.0
    r, g, b, a = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
    
    maxc = np.maximum(np.maximum(r, g), b)
    minc = np.minimum(np.minimum(r, g), b)
    v = maxc
    deltac = maxc - minc
    s = np.where(maxc != 0, deltac / maxc, 0.0)
    
    h = np.zeros_like(v)
    mask_r = (maxc == r) & (deltac != 0)
    mask_g = (maxc == g) & (deltac != 0)
    mask_b = (maxc == b) & (deltac != 0)
    
    h[mask_r] = ((g[mask_r] - b[mask_r]) / deltac[mask_r]) % 6.0
    h[mask_g] = ((b[mask_g] - r[mask_g]) / deltac[mask_g]) + 2.0
    h[mask_b] = ((r[mask_b] - g[mask_b]) / deltac[mask_b]) + 4.0
    h = h * 60.0 # to degrees 0..360
    
    # Parse target color
    target_hex = target_hex.lstrip('#')
    tr, tg, tb = [int(target_hex[i:i+2], 16) / 255.0 for i in (0, 2, 4)]
    t_maxc = max(tr, tg, tb)
    t_minc = min(tr, tg, tb)
    t_v = t_maxc
    t_delta = t_maxc - t_minc
    t_s = t_delta / t_maxc if t_maxc != 0 else 0.0
    if t_delta == 0:
        t_h = 0.0
    elif t_maxc == tr:
        t_h = ((tg - tb) / t_delta) % 6.0
    elif t_maxc == tg:
        t_h = ((tb - tr) / t_delta) + 2.0
    else:
        t_h = ((tr - tg) / t_delta) + 4.0
    t_h = (t_h * 60.0) % 360.0

    # Calculate distance to source hue
    diff = np.abs(h - src_hue_deg)
    diff = np.minimum(diff, 360.0 - diff)
    
    # Selection weight: requires saturation and matching hue
    weight = np.clip(1.0 - (diff / hue_tolerance), 0.0, 1.0) * np.clip(s / 0.15, 0.0, 1.0)
    weight = weight[..., np.newaxis]
    
    # Target RGB preserving local shading (lightness/value)
    # We tint by multiplying the value
    new_r = v * tr * val_mult
    new_g = v * tg * val_mult
    new_b = v * tb * val_mult
    new_rgb = np.stack([new_r, new_g, new_b], axis=-1)
    
    orig_rgb = arr[..., :3]
    blended_rgb = orig_rgb * (1.0 - weight) + new_rgb * weight
    blended_rgb = np.clip(blended_rgb * 255.0, 0.0, 255.0).astype(np.uint8)
    
    result = Image.fromarray(blended_rgb, "RGB")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    result.save(out_path, quality=92)
    print(f"Recolored {img_path} -> {out_path} (target: #{target_hex})")

if __name__ == "__main__":
    # Aston Martin: Green (~110-150 deg) -> Magenta #D946EF
    recolor_hue_range("assets/cars/aston_vantage/textures/base_color.png", "temp/recolor_preview/aston_vantage_magenta.jpg", 130, 45, "D946EF")
    
    # Lamborghini: Lime Green (~80-120 deg) -> Purple #9B5CFF
    recolor_hue_range("assets/cars/lambo_huracan/textures/base_color.png", "temp/recolor_preview/lambo_huracan_purple.jpg", 100, 40, "9B5CFF")
    
    # McLaren: Orange (~20-45 deg) -> Mint #00E08A
    recolor_hue_range("assets/cars/mclaren_720s/textures/base_color.png", "temp/recolor_preview/mclaren_720s_mint.jpg", 30, 30, "00E08A")
