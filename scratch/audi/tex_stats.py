import bpy, numpy as np, sys
for n in ("base_color", "metallic", "roughness", "normal"):
    im = bpy.data.images.load("D:/Occupation/Porto/genex/La_Voiture/assets/cars/audi_r8/raw/audi_r8_raw_textures/%s.png" % n)
    a = np.array(im.pixels[:]).reshape(-1, im.channels if im.channels else 4)
    print("TEX", n, im.size[:], "channels", im.channels, "colorspace", im.colorspace_settings.name, "mean", a.mean(0).round(3), "p10", np.percentile(a, 10, axis=0).round(3), "p90", np.percentile(a, 90, axis=0).round(3))
