import bpy
import json

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath="assets/cars/lexus_rcf/lexus_rcf_body.glb")

obj = bpy.data.objects["LexusRCF_Body"]
mesh = obj.data
uv_layer = mesh.uv_layers.active.data

# Bounds: X: -0.99..0.99, Y: -2.22..2.32, Z: 0.05..1.24
# Let's inspect different parts:

glass_polys = []
aero_trim_polys = []
body_polys = []

for poly in mesh.polygons:
    if poly.material_index != 0:
        continue
    c = poly.center
    n = poly.normal
    
    # 1. Glass:
    # Windshield:
    is_windshield = (0.64 < c.z < 1.15) and (0.15 < c.y < 1.05) and (n.z > 0.15) and (n.y > 0.15) and (abs(c.x) < 0.78)
    # Side windows:
    is_side_win = (0.64 < c.z < 1.12) and (-0.80 < c.y < 0.45) and (abs(c.x) > 0.60) and (abs(n.x) > 0.35)
    # Rear window:
    is_rear_win = (0.68 < c.z < 1.15) and (-1.15 < c.y < -0.15) and (n.z > 0.15) and (n.y < -0.15) and (abs(c.x) < 0.78)
    # Exclude roof:
    is_roof = (c.z > 1.13) and (abs(n.z) > 0.75) and (abs(c.x) < 0.65)
    
    is_glass = (is_windshield or is_side_win or is_rear_win) and not is_roof
    
    # 2. Aero & Trims:
    # Front splitter / canards: low front (z < 0.22, y > 1.8)
    is_splitter = (c.z < 0.22) and (c.y > 1.6)
    # Rear diffuser: low rear (z < 0.30, y < -1.8)
    is_diffuser = (c.z < 0.30) and (c.y < -1.7)
    # Rear wing: high rear (z > 1.05, y < -1.5)
    is_rear_wing = (c.z > 0.95) and (c.y < -1.45)
    # Front grill mesh: front facing, center (y > 2.05, abs(c.x) < 0.55, z < 0.65)
    is_grill = (c.y > 2.02) and (abs(c.x) < 0.55) and (c.z < 0.65)
    # Headlights: front corners (y > 1.85, 0.45 < abs(c.x) < 0.88, 0.45 < c.z < 0.72)
    is_headlight = (c.y > 1.85) and (0.42 < abs(c.x) < 0.90) and (0.42 < c.z < 0.75)
    # Taillights: rear corners (y < -2.05, 0.45 < abs(c.x) < 0.88, 0.65 < c.z < 0.90)
    is_taillight = (c.y < -2.05) and (0.42 < abs(c.x) < 0.90) and (0.60 < c.z < 0.92)
    
    is_aero_trim = is_splitter or is_diffuser or is_rear_wing or is_grill or is_headlight or is_taillight
    
    uvs = [ [uv_layer[loop_idx].uv.x, uv_layer[loop_idx].uv.y] for loop_idx in poly.loop_indices ]
    
    if is_glass:
        glass_polys.append(uvs)
    elif is_aero_trim:
        aero_trim_polys.append(uvs)
    else:
        body_polys.append(uvs)

print(f"Glass polys: {len(glass_polys)}")
print(f"Aero/trim polys: {len(aero_trim_polys)}")
print(f"Body polys: {len(body_polys)}")

result = {
    "glass": glass_polys,
    "aero_trim": aero_trim_polys,
    "body": body_polys
}

with open("temp/lexus_classified_uvs.json", "w") as f:
    json.dump(result, f)
print("Saved temp/lexus_classified_uvs.json")
