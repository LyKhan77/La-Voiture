from PIL import Image
import numpy as np

orig = Image.open('assets/cars/lexus_rcf/textures/base_color_original.png').convert('RGB')
orm = Image.open('assets/cars/lexus_rcf/textures/orm.png').convert('RGB')

orig_arr = np.array(orig)
orm_arr = np.array(orm)

print("Original base_color shape:", orig_arr.shape)
print("ORM shape:", orm_arr.shape)

# Let's inspect roughness (G) distribution
roughness = orm_arr[..., 1]
metallic = orm_arr[..., 2]
ao = orm_arr[..., 0]

print(f"Roughness: min={roughness.min()}, max={roughness.max()}, mean={roughness.mean():.1f}, median={np.median(roughness):.1f}")
print(f"Metallic: min={metallic.min()}, max={metallic.max()}, mean={metallic.mean():.1f}")
print(f"AO: min={ao.min()}, max={ao.max()}, mean={ao.mean():.1f}")

# What does the original base color look like?
r, g, b = orig_arr[..., 0], orig_arr[..., 1], orig_arr[..., 2]
print(f"Orig R: min={r.min()}, max={r.max()}, mean={r.mean():.1f}")
print(f"Orig G: min={g.min()}, max={g.max()}, mean={g.mean():.1f}")
print(f"Orig B: min={b.min()}, max={b.max()}, mean={b.mean():.1f}")
