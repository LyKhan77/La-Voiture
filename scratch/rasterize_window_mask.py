import bpy
import json

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath="assets/cars/lexus_rcf/lexus_rcf_body.glb")

obj = bpy.data.objects["LexusRCF_Body"]
mesh = obj.data
uv_layer = mesh.uv_layers.active.data

# In Blender coordinates:
# X: width (-0.99 to 0.99)
# Y: length (-2.22 to 2.32, front is +Y, rear is -Y)
# Z: height (0.05 to 1.24, roof is ~1.20)

window_uv_polys = []

for poly in mesh.polygons:
    if poly.material_index != 0:
        continue
    c = poly.center
    n = poly.normal
    
    # Windshield:
    # height Z: 0.65 .. 1.12, Y (forward): 0.15 .. 1.05, normal pointing UP (+Z) and FORWARD (+Y)
    is_windshield = (0.65 < c.z < 1.15) and (0.15 < c.y < 1.05) and (n.z > 0.15) and (n.y > 0.15) and (abs(c.x) < 0.78)
    
    # Side windows:
    # height Z: 0.65 .. 1.12, Y: -0.80 .. 0.45, abs(X) > 0.62, normal pointing LATERAL (+-X)
    is_side_window = (0.65 < c.z < 1.12) and (-0.80 < c.y < 0.45) and (abs(c.x) > 0.60) and (abs(n.x) > 0.35)
    
    # Rear window:
    # height Z: 0.68 .. 1.15, Y: -1.15 .. -0.15, normal pointing UP (+Z) and BACKWARD (-Y)
    is_rear_window = (0.68 < c.z < 1.15) and (-1.15 < c.y < -0.15) and (n.z > 0.15) and (n.y < -0.15) and (abs(c.x) < 0.78)

    # Exclude roof: roof has c.z > 1.14 and abs(n.z) > 0.85 and abs(c.x) < 0.60
    is_roof = (c.z > 1.13) and (abs(n.z) > 0.75) and (abs(c.x) < 0.65)
    
    if (is_windshield or is_side_window or is_rear_window) and not is_roof:
        uvs = [ [uv_layer[loop_idx].uv.x, uv_layer[loop_idx].uv.y] for loop_idx in poly.loop_indices ]
        window_uv_polys.append(uvs)

print(f"Refined window polygons count: {len(window_uv_polys)}")
with open("temp/lexus_window_uvs.json", "w") as f:
    json.dump(window_uv_polys, f)
print("Saved temp/lexus_window_uvs.json")
