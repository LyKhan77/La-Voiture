from PIL import Image, ImageDraw
import numpy as np

img = Image.open('executor-report/screenshots/winning_scene/clean-cinematic.png').convert('RGBA')
w, h = img.size

# Clean top-left UI text completely (x from 0 to 650, y from 0 to 240)
# We can sample a large clean block of Ben-Day dots wall from x in [40, 650], y in [240, 480]
clean_wall = img.crop((40, 240, 650, 480))
img.paste(clean_wall, (40, 10))
img.paste(clean_wall.crop((0, 0, 40, 240)), (0, 10))

# Clean bottom cards completely (y >= 840)
draw = ImageDraw.Draw(img)
floor_sample = np.array(img.crop((100, 820, 300, 835)))
mean_color = tuple(floor_sample.mean(axis=(0, 1)).astype(int))

for y in range(835, 1080):
    factor = 1.0 - (y - 835) / 500.0
    r = max(0, int(mean_color[0] * factor))
    g = max(0, int(mean_color[1] * factor))
    b = max(0, int(mean_color[2] * factor))
    draw.line([(0, y), (w, y)], fill=(r, g, b, 255))

output_path = "temp/stage_clean_pristine.png"
img.save(output_path)
print("Updated pristine stage image with complete UI wipe:", output_path)
