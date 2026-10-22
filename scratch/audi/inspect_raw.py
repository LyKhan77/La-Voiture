# Inspect the raw Meshy GLB: object list, face counts, bounds, materials.
#   blender --background --python scratch/audi/inspect_raw.py -- <in.glb>
import bpy, sys, numpy as np
src = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in bpy.data.objects:
    print("OBJ", o.name, o.type, tuple(round(x, 3) for x in o.location), tuple(round(x, 3) for x in o.rotation_euler), tuple(round(x, 3) for x in o.scale))
    if o.type == "MESH":
        me = o.data
        n = len(me.vertices)
        P = np.empty(n * 3, dtype=np.float64); me.vertices.foreach_get("co", P); P = P.reshape(-1, 3)
        print("  verts", n, "faces", len(me.polygons), "mats", [m.name for m in me.materials])
        print("  min", P.min(0).round(3), "max", P.max(0).round(3), "size", (P.max(0) - P.min(0)).round(3))
        print("  uv layers", [u.name for u in me.uv_layers], "tris", sum(len(p.vertices) - 2 for p in me.polygons))
