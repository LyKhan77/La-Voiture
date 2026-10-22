import bpy
import os

bpy.ops.wm.read_factory_settings(use_empty=True)
glb_path = os.path.abspath("assets/from-image-front-png-cmvh1rlu.glb")
bpy.ops.import_scene.gltf(filepath=glb_path)
car_obj = [o for o in bpy.data.objects if o.type == 'MESH'][0]

# Inspect vertices at rear wing:
wing_verts = [v.co for v in car_obj.data.vertices if v.co.x < -0.36 and v.co.z > 0.06]
print("Rear wing verts (X < -0.36, Z > 0.06):", len(wing_verts))
if wing_verts:
    print("  X range:", min(v.x for v in wing_verts), max(v.x for v in wing_verts))
    print("  Y range:", min(v.y for v in wing_verts), max(v.y for v in wing_verts))
    print("  Z range:", min(v.z for v in wing_verts), max(v.z for v in wing_verts))

# Inspect vertices at front chin/splitter:
front_chin = [v.co for v in car_obj.data.vertices if v.co.x > 0.45 and v.co.z < -0.10]
print("Front chin verts (X > 0.45, Z < -0.10):", len(front_chin))
