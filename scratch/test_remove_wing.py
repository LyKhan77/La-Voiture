import bpy
import os
import bmesh
import math

bpy.ops.wm.read_factory_settings(use_empty=True)
glb_path = os.path.abspath("assets/from-image-front-png-cmvh1rlu.glb")
bpy.ops.import_scene.gltf(filepath=glb_path)
car_obj = [o for o in bpy.data.objects if o.type == 'MESH'][0]

bm = bmesh.new()
bm.from_mesh(car_obj.data)

# 1. Vertices to delete: rear wing
wing_verts = [v for v in bm.verts if v.co.x < -0.365 and v.co.z > 0.065]
print("Deleting rear wing verts:", len(wing_verts))
bmesh.ops.delete(bm, geom=wing_verts, context='VERTS')

# 2. Vertices to delete: front chin extension (leave bumper curve intact)
# Let's inspect chin verts carefully
chin_verts = [v for v in bm.verts if v.co.x > 0.470 and v.co.z < -0.11]
print("Deleting front chin verts:", len(chin_verts))
bmesh.ops.delete(bm, geom=chin_verts, context='VERTS')

bm.to_mesh(car_obj.data)
bm.free()
car_obj.data.update()

# Render side and rear-quarter
cam_data = bpy.data.cameras.new("Cam")
cam_obj = bpy.data.objects.new("Cam", cam_data)
bpy.context.scene.collection.objects.link(cam_obj)
bpy.context.scene.camera = cam_obj

# Lights
for loc, energy in [((0, 0, 5), 2.0), ((4, 4, 3), 3.0), ((-4, -4, 3), 3.0)]:
    l_data = bpy.data.lights.new("Sun", type='SUN')
    l_data.energy = energy
    l_obj = bpy.data.objects.new("Sun", l_data)
    l_obj.location = loc
    bpy.context.scene.collection.objects.link(l_obj)

cam_obj.location = (-1.8, 1.2, 0.8)
cam_obj.rotation_euler = (math.radians(65), 0, math.radians(-50))

bpy.context.scene.render.resolution_x = 800
bpy.context.scene.render.resolution_y = 600
bpy.context.scene.render.filepath = os.path.abspath("scratch/view_wing_removed.png")
bpy.ops.render.render(write_still=True)
print("Wing removed render done!")
