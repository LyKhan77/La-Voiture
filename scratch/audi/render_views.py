# Workbench orientation renders of an open .blend.   blender -b file.blend --python render_views.py -- <render_dir>
import bpy, sys, os
from mathutils import Vector
RD = sys.argv[sys.argv.index("--") + 1]
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.render.resolution_x = 900; sc.render.resolution_y = 600
cd = bpy.data.cameras.new("c"); cd.lens = 40
cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
def shot(name, loc, tgt):
    cam.location = loc; cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(RD, name + ".png"); bpy.ops.render.render(write_still=True); print("rendered", name)
shot("raw_plusX", (3.2, 0, 0.1), (0, 0, 0)); shot("raw_minusX", (-3.2, 0, 0.1), (0, 0, 0))
shot("raw_plusY", (0, 3.2, 0.1), (0, 0, 0)); shot("raw_top", (0, 0, 3.6), (0, 0, 0))
shot("raw_3q", (2.4, -2.2, 1.2), (0, 0, 0))
