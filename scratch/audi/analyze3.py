import bpy, numpy as np, math
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
me = ob.data; n = len(me.vertices)
Q = np.empty(n * 3); me.vertices.foreach_get("co", Q); Q = Q.reshape(-1, 3)
GUESS = {"FR": (1, -1.21, 0.367), "FL": (-1, -1.21, 0.367), "RR": (1, 1.37, 0.367), "RL": (-1, 1.37, 0.367)}
def fit(pts):
    A = np.c_[2 * pts[:, 0], 2 * pts[:, 1], np.ones(len(pts))]; b = (pts ** 2).sum(1)
    c = np.linalg.lstsq(A, b, rcond=None)[0]; return c[0], c[1], math.sqrt(c[2] + c[0] ** 2 + c[1] ** 2)
for k, (sg, yg, zg) in GUESS.items():
    x = Q[:, 0] * sg
    for xlo, xhi in ((0.70, 0.97), (0.74, 0.92)):
        y0, z0, r0 = yg, zg, 0.37
        for it in range(12):
            r = np.hypot(Q[:, 1] - y0, Q[:, 2] - z0)
            m = (x > xlo) & (x < xhi) & (Q[:, 2] < z0 + 0.04) & (np.abs(r - r0) < 0.02)
            pts = Q[m][:, 1:3]
            if len(pts) < 20: break
            y0, z0, r0 = fit(pts)
        ang = np.degrees(np.arctan2(pts[:, 1] - z0, pts[:, 0] - y0))
        print("RES", k, "x[%.2f,%.2f]" % (xlo, xhi), "axle y=%.3f z=%.3f r=%.4f n=%d angle span %.0f..%.0f" % (y0, z0, r0, len(pts), ang.min(), ang.max()))
# lowest body panel (excluding tire zones) and x extents outside tire zones
for k, (sg, yg, zg) in GUESS.items():
    pass
body = np.ones(n, bool)
for k, (sg, yg, zg) in GUESS.items():
    r = np.hypot(Q[:, 1] - yg, Q[:, 2] - zg); body &= ~((Q[:, 0] * sg > 0.5) & (r < 0.5))
print("RES lowest z of non-wheel verts", Q[body][:, 2].min().round(3), " max |x| non-wheel", np.abs(Q[body][:, 0]).max().round(3))
for yb in (-2.0, -1.6, -0.6, 0.0, 0.6, 1.0, 1.9):
    s = body & (np.abs(Q[:, 1] - yb) < 0.1) & (Q[:, 2] < 1.0)
    print("RES y=%.1f max|x| %.3f" % (yb, np.abs(Q[s][:, 0]).max()))
