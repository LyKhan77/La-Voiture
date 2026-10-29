import json
import numpy as np
from PIL import Image

tex = Image.open('assets/cars/lexus_rcf/textures/base_color.png').convert('RGB')
arr = np.array(tex)

with open('tools/data/lexus_classified_uvs.json') as f:
    classified = json.load(f)

W, H = tex.size

print("--- GLASS SAMPLES ---")
glass_rgbs = []
for p in classified['glass']:
    x = int(np.clip(p[0][0] * W, 0, W - 1))
    y = int(np.clip((1.0 - p[0][1]) * H, 0, H - 1))
    glass_rgbs.append(arr[y, x])
glass_rgbs = np.array(glass_rgbs)
print(f"Glass count: {len(glass_rgbs)}, Mean RGB: {np.mean(glass_rgbs, axis=0)}")

print("--- BODY SAMPLES ---")
body_rgbs = []
for p in classified['body'][:5000]:
    x = int(np.clip(p[0][0] * W, 0, W - 1))
    y = int(np.clip((1.0 - p[0][1]) * H, 0, H - 1))
    body_rgbs.append(arr[y, x])
body_rgbs = np.array(body_rgbs)
print(f"Body sample count: {len(body_rgbs)}, Mean RGB: {np.mean(body_rgbs, axis=0)}")
