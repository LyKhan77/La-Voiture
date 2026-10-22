# Bake rotation (front -> -Y blender / +Z godot) + uniform scale to 4.55 m + ground z=0 into the decimated mesh.
#   blender -b decimated.blend --python stage_transform.py -- <out.blend>
import bpy, sys, numpy as np
OUT = sys.argv[sys.argv.index("--") + 1]
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
me = ob.data
n = len(me.vertices)
P = np.empty(n * 3); me.vertices.foreach_get("co", P); P = P.reshape(-1, 3)
S = 4.55 / (P[:, 0].max() - P[:, 0].min())
Q = np.c_[-P[:, 1], P[:, 0], P[:, 2]] * S
Q[:, 2] -= Q[:, 2].min()
me.vertices.foreach_set("co", Q.ravel()); me.update()
print("scale", S, "min", Q.min(0).round(3), "max", Q.max(0).round(3))
bpy.ops.wm.save_as_mainfile(filepath=OUT)
