import bpy, numpy as np, sys
for path in sys.argv[sys.argv.index("--") + 1:]:
    im = bpy.data.images.load(path); im.colorspace_settings.name = "Non-Color"
    a = np.array(im.pixels[:]).reshape(-1, 4)[:, :3]
    used = a.max(1) > 0.01
    mx, mn = a.max(1), a.min(1); sat = (mx - mn) / np.maximum(mx, 1e-4); lum = a @ np.array([0.2126, 0.7152, 0.0722])
    low = (sat < 0.12) & used
    h, e = np.histogram(lum[low], bins=np.arange(0, 1.0001, 0.05))
    print("TH", path.split("/")[-2], "used %.2f" % used.mean(), " ".join("%.2f:%.1f%%" % (e[i], 100.0 * h[i] / low.sum()) for i in range(len(h))))
