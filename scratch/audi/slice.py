# Plot cross-section slices of the staged mesh as dot images.  blender -b staged.blend --python slice.py -- <out_dir>
import bpy, numpy as np, sys
OUT = sys.argv[sys.argv.index("--") + 1]
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
me = ob.data; n = len(me.vertices)
Q = np.empty(n * 3); me.vertices.foreach_get("co", Q); Q = Q.reshape(-1, 3)
def plot(name, a, b, extent, ppm=500):
    (a0, a1), (b0, b1) = extent
    W, H = int((a1 - a0) * ppm), int((b1 - b0) * ppm)
    img = np.zeros((H, W, 4)); img[..., 3] = 1; img[..., :3] = 0.05
    for g in np.arange(np.ceil(a0 * 10) / 10, a1, 0.1):
        c = int((g - a0) * ppm); img[:, c, :3] = (0.5, 0.15, 0.15) if abs(g * 10 % 5) < 1e-6 else (0.15, 0.15, 0.3)
    for g in np.arange(np.ceil(b0 * 10) / 10, b1, 0.1):
        r = int((g - b0) * ppm); img[r, :, :3] = (0.5, 0.15, 0.15) if abs(g * 10 % 5) < 1e-6 else (0.15, 0.15, 0.3)
    ci = ((a - a0) * ppm).astype(int); ri = ((b - b0) * ppm).astype(int)
    ok = (ci >= 0) & (ci < W) & (ri >= 0) & (ri < H)
    img[ri[ok], ci[ok], :3] = 1.0
    im = bpy.data.images.new(name, W, H, alpha=True); im.pixels[:] = img.ravel(); im.filepath_raw = OUT + "/" + name + ".png"; im.file_format = "PNG"; im.save()
    print("saved", name)
for nm, yc in (("slice_front_axle", -1.203), ("slice_rear_axle", 1.349)):
    m = np.abs(Q[:, 1] - yc) < 0.012
    plot(nm, Q[m, 0], Q[m, 2], ((-1.2, 1.2), (-0.05, 1.0)))
