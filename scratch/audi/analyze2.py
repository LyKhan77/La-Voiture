import bpy, numpy as np
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
me = ob.data; n = len(me.vertices)
Q = np.empty(n * 3); me.vertices.foreach_get("co", Q); Q = Q.reshape(-1, 3)
GUESS = {"FR": (1, -1.21, 0.367), "FL": (-1, -1.21, 0.367), "RR": (1, 1.37, 0.367), "RL": (-1, 1.37, 0.367)}
for k, (sg, yg, zg) in GUESS.items():
    x = Q[:, 0] * sg
    r = np.hypot(Q[:, 1] - yg, Q[:, 2] - zg)
    print(k, "radial hist of verts with x in [0.5,1.1] :")
    sel = (x > 0.5) & (x < 1.1) & (r < 0.5)
    h, e = np.histogram(r[sel], bins=np.arange(0.0, 0.5001, 0.02))
    print("   r bins", " ".join("%.2f:%d" % (e[i], h[i]) for i in range(len(h))))
    # x histogram for points near tread radius (0.30..0.36)
    s2 = (r > 0.30) & (r < 0.36) & (x > 0.3) & (x < 1.2)
    h, e = np.histogram(x[s2], bins=np.arange(0.3, 1.2001, 0.04))
    print("   x bins (r .30-.36)", " ".join("%.2f:%d" % (e[i], h[i]) for i in range(len(h))))
