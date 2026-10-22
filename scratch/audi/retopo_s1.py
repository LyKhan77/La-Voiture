# Experiment: is the raw Meshy mesh closed after welding, and what does a voxel remesh of it look like?
import bpy, bmesh, sys, time, numpy as np, math
OUT = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath="D:/Occupation/Porto/genex/La_Voiture/assets/cars/audi_r8/raw/audi_r8_raw.glb")
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]; me = ob.data
n = len(me.vertices); P = np.empty(n * 3); me.vertices.foreach_get("co", P); P = P.reshape(-1, 3)
S = 4.55 / (P[:, 0].max() - P[:, 0].min())
Q = np.c_[-P[:, 1], P[:, 0], P[:, 2]] * S; Q[:, 2] -= Q[:, 2].min() + (0.350 - 0.33); Q[:, 1] -= 0.123
me.vertices.foreach_set("co", Q.ravel()); me.update()
t = time.time()
bm = bmesh.new(); bm.from_mesh(me)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
bnd = sum(1 for e in bm.edges if e.is_boundary); nm = sum(1 for e in bm.edges if len(e.link_faces) > 2)
print("S1 welded: verts", len(bm.verts), "faces", len(bm.faces), "boundary edges", bnd, "non-manifold(>2 faces) edges", nm, "in %.1fs" % (time.time() - t))
bm.to_mesh(me); bm.free(); me.update()
t = time.time()
me.remesh_voxel_size = 0.012; me.remesh_voxel_adaptivity = 0.0
bpy.context.view_layer.objects.active = ob; ob.select_set(True)
bpy.ops.object.voxel_remesh()
print("S1 voxel remesh 1.2cm: verts", len(me.vertices), "faces", len(me.polygons), "tris", sum(len(p.vertices) - 2 for p in me.polygons), "in %.1fs" % (time.time() - t))
bm = bmesh.new(); bm.from_mesh(me)
print("S1 remeshed boundary edges", sum(1 for e in bm.edges if e.is_boundary), "bbox", np.array([v.co[:] for v in bm.verts]).min(0).round(3), np.array([v.co[:] for v in bm.verts]).max(0).round(3))
bm.free()
bpy.ops.wm.save_as_mainfile(filepath=OUT)
