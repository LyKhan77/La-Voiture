# Assembles a standalone "full car" GLB (clean body + the four master wheels at the chassis sockets) for any chassis scene.
# The body GLB and the wheel sockets are read from the .tscn, so the result always matches what the game assembles.
#   blender --background --python scratch/build_full_car.py -- <chassis.tscn> <out.glb> [wheel.glb]
# Godot (x, y, z) -> Blender (x, -z, y); the left wheels are turned half a turn like ModularCarAssembler.attach_wheel does.
import bpy, math, os, re, sys
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
TSCN, DST = argv[0], argv[1]
PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(TSCN)))
while not os.path.exists(os.path.join(PROJECT, "project.godot")):
    PROJECT = os.path.dirname(PROJECT)
WHEEL = argv[2] if len(argv) > 2 else os.path.join(PROJECT, "assets", "cars", "parts", "gt3_wheel_master.glb")

text = open(TSCN, encoding="utf-8").read()
body_res = re.search(r'\[ext_resource type="PackedScene" path="res://(assets/cars/[^"]+\.glb)"', text).group(1)
sockets = {}
for m in re.finditer(r'\[node name="Socket_Wheel_(FL|FR|RL|RR)" type="Marker3D"[^\n]*\]\s*transform = Transform3D\(([^)]*)\)', text):
    v = [float(x) for x in m.group(2).split(",")]
    sockets[m.group(1)] = Vector((v[9], v[10], v[11]))            # Godot-space origin of the socket
assert len(sockets) == 4, "need the four Socket_Wheel_* markers, found %s" % list(sockets)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(PROJECT, body_res))
body_objs = list(bpy.data.objects)
body_tris = sum(len(o.data.polygons) for o in body_objs if o.type == "MESH")

before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=WHEEL)
wheel_objs = [o for o in bpy.data.objects if o not in before]            # parents come before children in creation order

def blender_pos(g):
    return Vector((g.x, -g.z, g.y))

for corner, g in sockets.items():
    root = bpy.data.objects.new("Wheel_" + corner, None)
    bpy.context.scene.collection.objects.link(root)
    root.location = blender_pos(g)
    if corner in ("FL", "RL"):
        root.rotation_euler = (0.0, 0.0, math.pi)                        # Godot rotation.y = PI == Blender rotation about Z
    copies = {}
    for o in wheel_objs:
        c = o.copy()                                                    # shares mesh data: each wheel mesh is written to the GLB once
        c.name = "%s_%s" % (corner, o.name)
        bpy.context.scene.collection.objects.link(c)
        c.parent = copies[o.parent] if o.parent in copies else root
        c.matrix_parent_inverse = o.matrix_parent_inverse.copy() if o.parent in copies else Matrix.Identity(4)
        copies[o] = c
for o in wheel_objs:
    bpy.data.objects.remove(o)

bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", export_apply=False, export_yup=True, export_image_format="AUTO",
                          export_cameras=False, export_lights=False)
print("FULLCAR body", body_res, "body tris", body_tris, "sockets", {k: tuple(round(x, 3) for x in v) for k, v in sockets.items()})
print("FULLCAR exported", DST, os.path.getsize(DST), "objects", len(bpy.data.objects))
