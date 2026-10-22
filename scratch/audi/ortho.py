# Orthographic side renders with grid + circle overlays.
#   blender -b file.blend --python ortho.py -- <out_dir> <name> <side R|L> <cy> <cz> <width_m> [circle:y:z:r ...]
import bpy, sys, os, math, numpy as np
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
OUT, NAME, SIDE, CY, CZ, WIDTH = a[0], a[1], a[2], float(a[3]), float(a[4]), float(a[5])
circles = [tuple(map(float, c.split(":")[1:])) for c in a[6:]]
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
W, H = 1600, 900
sc.render.resolution_x, sc.render.resolution_y = W, H
cd = bpy.data.cameras.new("c"); cd.type = "ORTHO"; cd.ortho_scale = WIDTH
cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
sx = 1 if SIDE == "R" else -1          # camera on +X (R) sees +Y to screen right; on -X it is mirrored
cam.location = Vector((sx * 8, CY, CZ)); cam.rotation_euler = (Vector((0, CY, CZ)) - cam.location).to_track_quat("-Z", "Y").to_euler()
p = os.path.join(OUT, NAME + ".png"); sc.render.filepath = p; bpy.ops.render.render(write_still=True)
img = bpy.data.images.load(p); px = np.array(img.pixels[:]).reshape(H, W, 4)
ppm = W / WIDTH
def col_of(y): return int(round(W / 2 + sx * (y - CY) * ppm))
def row_of(z): return int(round(H / 2 + (z - CZ) * ppm))      # array row (0 = bottom)
for k in np.arange(math.floor((CY - WIDTH / 2) * 10) / 10, CY + WIDTH / 2, 0.1):
    c = col_of(k)
    if 0 <= c < W: px[:, c, :3] = (0.9, 0.2, 0.2) if abs(k * 10 % 5) < 1e-6 or abs(k * 10 % 5 - 5) < 1e-6 else (0.25, 0.45, 0.9)
for k in np.arange(0.0, 1.6, 0.1):
    r = row_of(k)
    if 0 <= r < H: px[r, :, :3] = (0.9, 0.2, 0.2) if abs(k * 10 % 5) < 1e-6 or abs(k * 10 % 5 - 5) < 1e-6 else (0.25, 0.45, 0.9)
for (cy, cz, cr) in circles:
    for t in np.linspace(0, 2 * math.pi, 1400):
        c, r = col_of(cy + cr * math.cos(t)), row_of(cz + cr * math.sin(t))
        if 0 <= c < W and 0 <= r < H: px[r, c, :3] = (0.1, 1.0, 0.1)
img.pixels[:] = px.ravel(); img.filepath_raw = p; img.file_format = "PNG"; img.save(); print("rendered", p)
