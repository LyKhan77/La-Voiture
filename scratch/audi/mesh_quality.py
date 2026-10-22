# Surface-smoothness metrics of a body GLB: triangle size, dihedral-angle spread, share of near-flat edges.
#   blender -b --python mesh_quality.py -- <glb> <label>
import bpy, bmesh, sys, math, numpy as np
glb, label = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
bm = bmesh.new(); bm.from_mesh(ob.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)          # UV-seam duplicates must not look like open edges
bmesh.ops.triangulate(bm, faces=bm.faces)
areas = np.array([f.calc_area() for f in bm.faces])
lens = np.array([e.calc_length() for e in bm.edges])
ang = np.array([math.degrees(e.calc_face_angle(0.0)) for e in bm.edges if len(e.link_faces) == 2])
bounds = sum(1 for e in bm.edges if len(e.link_faces) == 1)
print("MQ", label, "tris", len(bm.faces), "edges", len(bm.edges), "boundary edges", bounds)
print("MQ", label, "edge length cm: median %.1f p90 %.1f max %.1f" % (np.median(lens) * 100, np.percentile(lens, 90) * 100, lens.max() * 100))
print("MQ", label, "tri area cm2: median %.1f p90 %.1f" % (np.median(areas) * 1e4, np.percentile(areas, 90) * 1e4))
print("MQ", label, "dihedral deg: median %.1f p90 %.1f p99 %.1f | edges >15deg %.1f%%  >30deg %.1f%%  >60deg %.1f%%" % (
    np.median(ang), np.percentile(ang, 90), np.percentile(ang, 99), (ang > 15).mean() * 100, (ang > 30).mean() * 100, (ang > 60).mean() * 100))
