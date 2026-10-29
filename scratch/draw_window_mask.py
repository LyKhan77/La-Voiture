import json
import numpy as np
from PIL import Image, ImageDraw

with open("temp/lexus_window_uvs.json", "r") as f:
    window_polys = json.load(f)

# Image size 4096 x 4096
W = 4096
H = 4096

mask_img = Image.new("L", (W, H), 0)
draw = ImageDraw.Draw(mask_img)

for poly in window_polys:
    # In glTF UV: u is 0..1 (left to right), v is 0..1 (bottom to top in Blender, but in glTF 2.0 v=0 is top)
    # Blender's gltf importer imports UVs such that y in Blender UV = 1.0 - v_gltf.
    # Let's map Blender uv to pixel: (u * W, (1.0 - v) * H)
    pts = [ (u * W, (1.0 - v) * H) for u, v in poly ]
    if len(pts) >= 3:
        draw.polygon(pts, fill=255)

mask_img.save("temp/lexus_glass_mask.png")
print("Saved temp/lexus_glass_mask.png")
