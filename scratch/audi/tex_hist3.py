import bpy, numpy as np, sys
for path in sys.argv[sys.argv.index("--") + 1:]:
    im = bpy.data.images.load(path); im.colorspace_settings.name = "Non-Color"
    a = np.array(im.pixels[:]).reshape(-1, 4)[:, :3]
    used = a.max(1) > 0.01
    print("TH3", path.split("/")[-2], "max %.3f p99.9 %.3f  px>0.8 %.2f%% of used  px>0.9 %.2f%%  white-ish(all>0.75) %.2f%%" % (
        a.max(), np.percentile(a[used].max(1), 99.9), 100 * (a[used].max(1) > 0.8).mean(), 100 * (a[used].max(1) > 0.9).mean(), 100 * (a[used].min(1) > 0.75).mean()))
