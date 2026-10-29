import numpy as np
from PIL import Image

orig = Image.open("assets/cars/lexus_rcf/textures/base_color_original.png").convert("RGB")
mask_flip = Image.open("temp/lexus_glass_mask.png")

# Also let's test if mask not flipped: (u * W, v * H)
# Let's check which one aligns with the windows in base_color_original.png!
# In the original texture, what are the pixels of the windshield / window glass?
orig_arr = np.array(orig)
mask_arr = np.array(mask_flip) > 128

glass_pixels_flip = orig_arr[mask_arr]
print(f"Mask (1.0-v): {len(glass_pixels_flip)} pixels, mean RGB: ({glass_pixels_flip[:, 0].mean():.1f}, {glass_pixels_flip[:, 1].mean():.1f}, {glass_pixels_flip[:, 2].mean():.1f})")

# Let's test with v not flipped:
mask_noflip_arr = np.flipud(mask_arr)
glass_pixels_noflip = orig_arr[mask_noflip_arr]
print(f"Mask (v): {len(glass_pixels_noflip)} pixels, mean RGB: ({glass_pixels_noflip[:, 0].mean():.1f}, {glass_pixels_noflip[:, 1].mean():.1f}, {glass_pixels_noflip[:, 2].mean():.1f})")
