import bpy, numpy as np, sys
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=sys.argv[sys.argv.index("--") + 1])
for ob in bpy.data.objects:
    if ob.type != "MESH": continue
    me = ob.data; n = len(me.vertices)
    P = np.empty(n * 3); me.vertices.foreach_get("co", P); P = P.reshape(-1, 3)   # blender space after import
    print("DBG", ob.name, n, "mats", [m.name if m else None for m in me.materials])
    print("DBG bbox", P.min(0).round(3), P.max(0).round(3))
    far = P[np.abs(P[:, 0]) > 1.05]
    print("DBG verts |x|>1.05:", len(far)); print(far[:12].round(3))
