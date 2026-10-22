# Close-up renders of an exported body GLB with tub material highlighted.
#   blender -b --python close.py -- <glb> <out_dir> name:lx:ly:lz:tx:ty:tz[:lens] ...
import bpy, sys, os
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
GLB, OUT, views = a[0], a[1], a[2:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
sc = bpy.context.scene
for o in bpy.data.objects:
    if o.type == "MESH":
        for m in o.data.materials:
            if m: m.use_backface_culling = True; m.diffuse_color = (0.9, 0.15, 0.1, 1) if "Liner" in m.name else (0.6, 0.62, 0.66, 1)
sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "MATERIAL"
sc.render.resolution_x, sc.render.resolution_y = 1000, 800
cd = bpy.data.cameras.new("c"); cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
for v in views:
    p = v.split(":"); n = p[0]; f = list(map(float, p[1:]))
    cd.lens = f[6] if len(f) > 6 else 45
    cam.location = Vector(f[0:3]); cam.rotation_euler = (Vector(f[3:6]) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(OUT, n + ".png"); bpy.ops.render.render(write_still=True); print("rendered", n)
