# Experiment: smooth the voxel remesh, then reduce to ~100k tris (collapse or Quadriflow); report smoothness + render.
#   blender -b s1_voxel.blend --python retopo_s2.py -- <label> <smooth_iters> <collapse|quad> <out_dir>
import bpy, bmesh, sys, time, math, os, numpy as np
from mathutils import Vector
label, iters, method, outdir = sys.argv[sys.argv.index("--") + 1:][:4]; iters = int(iters)
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]; me = ob.data
bpy.context.view_layer.objects.active = ob; ob.select_set(True)
t = time.time()
if iters > 0:
    md = ob.modifiers.new("cs", "CORRECTIVE_SMOOTH"); md.smooth_type = "LENGTH_WEIGHTED"; md.factor = 0.8; md.iterations = iters; md.use_only_smooth = True; md.rest_source = "ORCO"
    bpy.ops.object.modifier_apply(modifier=md.name)
print("S2", label, "smoothed %d it in %.1fs" % (iters, time.time() - t))
t = time.time()
if method == "quad":
    try:
        bpy.ops.object.quadriflow_remesh(use_mesh_symmetry=False, use_preserve_sharp=False, use_preserve_boundary=False, smooth_normals=True, mode="FACES", target_faces=50000, seed=1)
    except Exception as ex:
        print("S2", label, "QUADRIFLOW FAILED", ex)
else:
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.triangulate(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
    md = ob.modifiers.new("dec", "DECIMATE"); md.decimate_type = "COLLAPSE"; md.ratio = 100000.0 / len(me.polygons)
    bpy.ops.object.modifier_apply(modifier=md.name)
tris = sum(len(p.vertices) - 2 for p in me.polygons)
print("S2", label, method, "-> faces", len(me.polygons), "tris", tris, "in %.1fs" % (time.time() - t))
for p in me.polygons: p.use_smooth = True
bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.triangulate(bm, faces=bm.faces)
ang = np.array([math.degrees(e.calc_face_angle(0.0)) for e in bm.edges if len(e.link_faces) == 2])
print("S2", label, "boundary edges", sum(1 for e in bm.edges if e.is_boundary), "dihedral median %.1f  >30deg %.1f%%  >60deg %.1f%%" % (np.median(ang), (ang > 30).mean() * 100, (ang > 60).mean() * 100))
bm.free()
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "SINGLE"; sc.display.shading.single_color = (0.7, 0.72, 0.78)
sc.render.resolution_x, sc.render.resolution_y = 1100, 650
cd = bpy.data.cameras.new("c"); cd.lens = 45; cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
for name, loc, tgt in (("3q", (3.9, -4.4, 1.5), (0, 0, 0.55)), ("side", (6.5, 0, 0.7), (0, 0, 0.55))):
    cam.location = loc; cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(outdir, "s2_%s_%s.png" % (label, name)); bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.environ["SCRATCHPAD"], "s2_%s.blend" % label))
