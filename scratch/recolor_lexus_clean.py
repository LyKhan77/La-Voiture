import json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

print("Loading classification JSON...")
with open("temp/lexus_classified_uvs.json", "r") as f:
    classified = json.load(f)

orig_path = "assets/cars/lexus_rcf/textures/base_color_original.png"
orig_img = Image.open(orig_path).convert("RGBA")
W, H = orig_img.size
print(f"Original image size: {W}x{H}")

# Create masks
mask_body_img = Image.new("L", (W, H), 0)
draw_body = ImageDraw.Draw(mask_body_img)

mask_glass_img = Image.new("L", (W, H), 0)
draw_glass = ImageDraw.Draw(mask_glass_img)

mask_trim_img = Image.new("L", (W, H), 0)
draw_trim = ImageDraw.Draw(mask_trim_img)

print("Drawing body polygons...")
for poly in classified["body"]:
    pts = [(u * W, (1.0 - v) * H) for u, v in poly]
    if len(pts) >= 3:
        draw_body.polygon(pts, fill=255)

print("Drawing glass polygons...")
for poly in classified["glass"]:
    pts = [(u * W, (1.0 - v) * H) for u, v in poly]
    if len(pts) >= 3:
        draw_glass.polygon(pts, fill=255)

print("Drawing aero/trim polygons...")
for poly in classified["aero_trim"]:
    pts = [(u * W, (1.0 - v) * H) for u, v in poly]
    if len(pts) >= 3:
        draw_trim.polygon(pts, fill=255)

# Slightly dilate body mask (1-2 px) to prevent seam gaps
mask_body_img = mask_body_img.filter(ImageFilter.MaxFilter(3))

# Subtract glass and trim from body
body_arr = np.array(mask_body_img, dtype=np.float32) / 255.0
glass_arr = np.array(mask_glass_img, dtype=np.float32) / 255.0
trim_arr = np.array(mask_trim_img, dtype=np.float32) / 255.0

# Glass and trim take absolute priority
protect_arr = np.clip(glass_arr + trim_arr, 0.0, 1.0)
final_body_mask = np.clip(body_arr - protect_arr * 1.5, 0.0, 1.0)
final_body_mask = final_body_mask[..., np.newaxis]

# Original image array
orig_arr = np.array(orig_img, dtype=np.float32) / 255.0
rgb_orig = orig_arr[..., :3]

# Create Snow White paint (#F4F5F7)
# Snow white target: 244/255, 245/255, 247/255
tr, tg, tb = 244.0 / 255.0, 245.0 / 255.0, 247.0 / 255.0

# Use original brightness to modulate panel lines and crevices
v_orig = np.maximum(np.maximum(rgb_orig[..., 0], rgb_orig[..., 1]), rgb_orig[..., 2])
# Normalize v_orig: crevices are darker, flat panels are lighter
# Map v_orig (0..0.4) to subtle panel depth (0.80..1.0)
panel_depth = np.clip(0.85 + (v_orig / 0.15) * 0.15, 0.70, 1.0)

white_paint = np.stack([
    tr * panel_depth,
    tg * panel_depth,
    tb * panel_depth
], axis=-1)

# Blend: only body becomes white paint! Glass and trims stay 100% original!
blended_rgb = rgb_orig * (1.0 - final_body_mask) + white_paint * final_body_mask

# For glass area: ensure authentic dark smoke tint (RGB 18, 20, 26) with crisp reflection
glass_mask_3d = glass_arr[..., np.newaxis]
smoke_glass = np.array([18.0 / 255.0, 20.0 / 255.0, 26.0 / 255.0])
blended_rgb = blended_rgb * (1.0 - glass_mask_3d) + smoke_glass * glass_mask_3d

blended_rgb = np.clip(blended_rgb * 255.0, 0.0, 255.0).astype(np.uint8)
out_img = Image.fromarray(blended_rgb, "RGB")

# Save to team texture and active texture
team_path = "assets/cars/lexus_rcf/textures/base_color_team.png"
active_path = "assets/cars/lexus_rcf/textures/base_color.png"
out_img.save(team_path, format="PNG")
out_img.save(active_path, format="PNG")
print("SUCCESS: Updated Lexus RC F textures with authentic dark smoke glass and white body panels!")
