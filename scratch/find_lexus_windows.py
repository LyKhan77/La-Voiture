import bpy
import json

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath="assets/cars/lexus_rcf/lexus_rcf_body.glb")

obj = bpy.data.objects["LexusRCF_Body"]
mesh = obj.data
uv_layer = mesh.uv_layers.active.data

verts = [v.co for v in mesh.vertices]
min_v = [min(v[i] for v in verts) for i in range(3)]
max_v = [max(v[i] for v in verts) for i in range(3)]
print(f"Car bounds: X={min_v[0]:.2f}..{max_v[0]:.2f}, Y={min_v[1]:.2f}..{max_v[1]:.2f}, Z={min_v[2]:.2f}..{max_v[2]:.2f}")

window_uv_polys = []

for poly in mesh.polygons:
    if poly.material_index != 0:
        continue
    c = poly.center
    n = poly.normal
    
    # Windshield: y in [0.65, 1.15], z in [0.05, 0.9], normal.z > 0.2, normal.y > 0.25, abs(c.x) < 0.75
    is_windshield = (0.65 < c.y < 1.15) and (0.05 < c.z < 0.9) and (n.z > 0.2) and (n.y > 0.2) and (abs(c.x) < 0.75)
    # Side window: y in [0.65, 1.15], z in [-0.7, 0.5], abs(n.x) > 0.55, abs(c.x) > 0.62
    is_side_window = (0.65 < c.y < 1.15) and (-0.7 < c.z < 0.5) and (abs(n.x) > 0.5) and (abs(c.x) > 0.60)
    # Rear window: y in [0.68, 1.15], z in [-0.95, -0.2], n.z < -0.2, n.y > 0.25, abs(c.x) < 0.75
    is_rear_window = (0.68 < c.y < 1.15) and (-0.95 < c.z < -0.2) and (n.z < -0.15) and (n.y > 0.2) and (abs(c.x) < 0.75)
    
    if is_windshield or is_side_window or is_rear_window:
        uvs = [ [uv_layer[loop_idx].uv.x, uv_layer[loop_idx].uv.y] for loop_idx in poly.loop_indices ]
        window_uv_polys.append(uvs)

print(f"Total window polygons identified: {len(window_uv_polys)}")
with open("temp/lexus_window_uvs.json", "w") as f:
    json.dump(window_uv_polys, f)
print("Saved temp/lexus_window_uvs.json")
