# Dense slices from the undecimated raw mesh, transformed like stage_transform.py.
import bpy, numpy as np, sys
OUT = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath="D:/Occupation/Porto/genex/La_Voiture/assets/cars/audi_r8/raw/audi_r8_raw.glb")
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
me = ob.data; n = len(me.vertices)
P = np.empty(n * 3); me.vertices.foreach_get("co", P); P = P.reshape(-1, 3)
S = 4.55 / (P[:, 0].max() - P[:, 0].min())
Q = np.c_[-P[:, 1], P[:, 0], P[:, 2]] * S; Q[:, 2] -= Q[:, 2].min()
np.save(OUT + "/raw_Q.npy", Q.astype(np.float32))
def plot(name, a, b, extent, ppm=600):
    (a0, a1), (b0, b1) = extent
    W, H = int((a1 - a0) * ppm), int((b1 - b0) * ppm)
    img = np.zeros((H, W, 4)); img[..., 3] = 1; img[..., :3] = 0.05
    for g in np.arange(np.ceil(a0 * 10) / 10, a1, 0.1):
        c = int((g - a0) * ppm); img[:, c, :3] = (0.55, 0.15, 0.15) if abs(g * 10 % 5) < 1e-6 else (0.15, 0.15, 0.3)
    for g in np.arange(np.ceil(b0 * 10) / 10, b1, 0.1):
        r = int((g - b0) * ppm); img[r, :, :3] = (0.55, 0.15, 0.15) if abs(g * 10 % 5) < 1e-6 else (0.15, 0.15, 0.3)
    ci = ((a - a0) * ppm).astype(int); ri = ((b - b0) * ppm).astype(int)
    ok = (ci >= 0) & (ci < W) & (ri >= 0) & (ri < H)
    img[ri[ok], ci[ok], :3] = 1.0
    im = bpy.data.images.new(name, W, H, alpha=True); im.pixels[:] = img.ravel(); im.filepath_raw = OUT + "/" + name + ".png"; im.file_format = "PNG"; im.save()
    print("saved", name)
for nm, yc in (("rawslice_front_axle", -1.203), ("rawslice_rear_axle", 1.349)):
    m = np.abs(Q[:, 1] - yc) < 0.004
    plot(nm, Q[m, 0], Q[m, 2], ((-1.2, 1.2), (-0.05, 1.0)), 500)
# x-slice through the right tire (x=0.85) seen from the side: y horizontal, z vertical
for nm, xc in (("rawslice_x085", 0.85), ("rawslice_x095", 0.96)):
    m = np.abs(Q[:, 0] - xc) < 0.004
    plot(nm, Q[m, 1], Q[m, 2], ((-2.4, 2.4), (-0.05, 1.0)), 330)
