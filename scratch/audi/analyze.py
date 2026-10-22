# Transform decimated mesh to GT3 space (front -Y blender / +Z godot, ground z=0) and hunt the wheel axles.
import bpy, sys, numpy as np
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
me = ob.data
n = len(me.vertices)
P = np.empty(n * 3); me.vertices.foreach_get("co", P); P = P.reshape(-1, 3)
S = 4.55 / (P[:, 0].max() - P[:, 0].min())
Q = np.c_[-P[:, 1], P[:, 0], P[:, 2]] * S
Q[:, 2] -= Q[:, 2].min()
print("scale", S, "min", Q.min(0).round(3), "max", Q.max(0).round(3))
# Hough for circles in (y,z) per side
def hough(pts, rs, ycs, zcs):
    best = (0, None)
    for r in rs:
        for yc in ycs:
            for zc in zcs:
                d = np.abs(np.hypot(pts[:, 0] - yc, pts[:, 1] - zc) - r)
                sc = (d < 0.008).sum()
                if sc > best[0]: best = (sc, (yc, zc, r))
    return best
for sg in (1, -1):
    for name, ylo, yhi in (("F", -2.2, -0.4), ("R", 0.4, 2.2)):
        m = (Q[:, 0] * sg > 0.7) & (Q[:, 0] * sg < 1.1) & (Q[:, 1] > ylo) & (Q[:, 1] < yhi) & (Q[:, 2] < 0.8)
        pts = Q[m][:, 1:3]
        b = hough(pts, np.arange(0.30, 0.40, 0.01), np.arange(ylo + 0.5, yhi - 0.5, 0.03), np.arange(0.28, 0.42, 0.02))
        print(("R" if sg > 0 else "L"), name, "pts", len(pts), "best", b)
        # refine
        sc, (yc, zc, r) = b
        for rr in np.arange(r - 0.012, r + 0.0121, 0.003):
            for dy in np.arange(-0.03, 0.031, 0.005):
                for dz in np.arange(-0.03, 0.031, 0.005):
                    d = np.abs(np.hypot(pts[:, 0] - (yc + dy), pts[:, 1] - (zc + dz)) - rr)
                    s2 = (d < 0.004).sum()
                    if s2 > sc: sc, b = s2, (sc, (yc + dy, zc + dz, rr))
        print("   refined", b)
# x extent of tire outer face per corner: points within r of axle
