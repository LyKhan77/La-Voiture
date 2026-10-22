import bpy, numpy as np, math
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
me = ob.data; n = len(me.vertices)
Q = np.empty(n * 3); me.vertices.foreach_get("co", Q); Q = Q.reshape(-1, 3)
GUESS = {"FR": (1, -1.209, 0.365), "FL": (-1, -1.209, 0.365), "RR": (1, 1.450, 0.362), "RL": (-1, 1.450, 0.362)}
def fit(pts):
    A = np.c_[2 * pts[:, 0], 2 * pts[:, 1], np.ones(len(pts))]; b = (pts ** 2).sum(1)
    c = np.linalg.lstsq(A, b, rcond=None)[0]; return c[0], c[1], math.sqrt(c[2] + c[0] ** 2 + c[1] ** 2)
for k, (sg, yg, zg) in GUESS.items():
    x = Q[:, 0] * sg
    for xlo, xhi in ((0.70, 0.97), (0.66, 1.00), (0.74, 0.92)):
        y0, z0, r0 = yg, zg, 0.36
        for it in range(15):
            r = np.hypot(Q[:, 1] - y0, Q[:, 2] - z0)
            ang = np.degrees(np.arctan2(Q[:, 2] - z0, Q[:, 1] - y0))
            m = (x > xlo) & (x < xhi) & (ang < -20) & (ang > -160) & (np.abs(r - r0) < 0.02)
            pts = Q[m][:, 1:3]
            if len(pts) < 20: break
            y0, z0, r0 = fit(pts)
        print("RES", k, "x[%.2f,%.2f]" % (xlo, xhi), "axle y=%.3f z=%.3f r=%.4f n=%d" % (y0, z0, r0, len(pts)))
