import bpy

# Clear default objects
bpy.ops.wm.read_factory_settings(use_empty=True)

# Import GLB
bpy.ops.import_scene.gltf(filepath="assets/cars/lexus_rcf/lexus_rcf_body.glb")

for obj in bpy.context.scene.objects:
    print(f"Object: {obj.name}, type: {obj.type}")
    if obj.type == 'MESH':
        print(f"  Materials ({len(obj.material_slots)}): {[s.name for s in obj.material_slots]}")
        mesh = obj.data
        print(f"  Vertices: {len(mesh.vertices)}, Polygons: {len(mesh.polygons)}")
        # Check UV layers
        print(f"  UV layers: {[uv.name for uv in mesh.uv_layers]}")
