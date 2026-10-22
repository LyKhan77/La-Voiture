import bpy, numpy as np
im = bpy.data.images.load("D:/Occupation/Porto/genex/La_Voiture/assets/cars/audi_r8/raw/audi_r8_raw_textures/base_color.png")
im.colorspace_settings.name = "Non-Color"
a = np.array(im.pixels[:]).reshape(-1, 4)[:, :3]
mx, mn = a.max(1), a.min(1); sat = (mx - mn) / np.maximum(mx, 1e-4); lum = a @ np.array([0.2126, 0.7152, 0.0722])
low = sat < 0.12
print("TH size", im.size[:], "low-chroma share %.2f" % low.mean())
h, e = np.histogram(lum[low], bins=np.arange(0, 1.0001, 0.05))
print("TH low-chroma luminance hist:", " ".join("%.2f:%d" % (e[i], h[i]) for i in range(len(h))))
print("TH saturated share %.2f  red-ish share %.3f" % ((sat >= 0.35).mean(), ((a[:, 0] > 0.55) & (a[:, 1] < 0.3) & (a[:, 2] < 0.3)).mean()))
