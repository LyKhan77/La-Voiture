# Decimate the raw Meshy GLB once and save a .blend for fast iteration + orientation renders.
#   blender --background --python scratch/audi/decimate_preview.py -- <raw.glb> <out.blend> <render_dir>
import bpy, sys, os, numpy as np, time
from mathutils import Vector
SRC, DST, RD = sys.argv[sys.argv.index("--") + 1:][:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
t = time.time()
md = ob.modifiers.new("Dec", "DECIMATE"); md.decimate_type = "COLLAPSE"; md.ratio = 0.04; md.use_collapse_triangulate = True
bpy.context.view_layer.objects.active = ob
bpy.ops.object.modifier_apply(modifier=md.name)
print("decimated in %.1fs -> verts %d tris %d" % (time.time() - t, len(ob.data.vertices), sum(len(p.vertices) - 2 for p in ob.data.polygons)))
bpy.ops.wm.save_as_mainfile(filepath=DST)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.render.resolution_x = 900; sc.render.resolution_y = 600
cd = bpy.data.cameras.new("c"); cd.lens = 40
cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
def shot(name, loc, tgt):
    cam.location = loc; cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(RD, name + ".png"); bpy.ops.render.render(write_still=True)
shot("raw_plusX", (3.2, 0, 0.1), (0, 0, 0)); shot("raw_minusX", (-3.2, 0, 0.1), (0, 0, 0))
shot("raw_plusY", (0, 3.2, 0.1), (0, 0, 0)); shot("raw_top", (0, 0, 3.6), (0, 0, 0))
shot("raw_3q", (2.4, -2.2, 1.2), (0, 0, 0))
