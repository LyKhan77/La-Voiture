from PIL import Image
import numpy as np

img = Image.open('executor-report/screenshots/winning_scene/clean-cinematic.png').convert('RGB')
arr = np.array(img)
print("Image size:", img.size)

# Find where the yellow jacket of Kaze Ryu is
# Check middle region y in [350, 650], x in [850, 1050]
sub = arr[350:650, 850:1050]
# Find bright pixels
mask = (sub[:, :, 0] > 150) & (sub[:, :, 1] > 150) & (sub[:, :, 2] < 100)
ys, xs = np.where(mask)
if len(xs) > 0:
    print("Jacket local bbox in [350:650, 850:1050]:")
    print(f"X: {xs.min() + 850} to {xs.max() + 850}, Y: {ys.min() + 350} to {ys.max() + 350}")
    print(f"Center X: {xs.mean() + 850:.1f}, Center Y: {ys.mean() + 350:.1f}")

# Check top-left UI region
print("Top-left UI text box is around X: 0-600, Y: 0-250")
print("Bottom UI cards box is around X: 150-1750, Y: 780-1080")
