import bpy

def inspect(filepath, label):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=filepath)
    print(f"\n================ {label} ================")
    for obj in bpy.data.objects:
        verts = len(obj.data.vertices) if obj.type == 'MESH' else 0
        faces = len(obj.data.polygons) if obj.type == 'MESH' else 0
        print(f"Object: {obj.name} ({obj.type}), Verts: {verts}, Faces: {faces}")
        if obj.type == 'MESH':
            dim = obj.dimensions
            print(f"  Dimensions: X={dim.x:.3f}, Y={dim.y:.3f}, Z={dim.z:.3f}")
            for idx, slot in enumerate(obj.material_slots):
                mat_name = slot.material.name if slot.material else "None"
                print(f"  Slot {idx}: {mat_name}")

inspect(r"D:\Occupation\Porto\genex\La_Voiture\assets\cars\porsche_911\porsche_911_body.glb", "PORSCHE 911 (GENEX/TRIPO)")
inspect(r"D:\Occupation\Porto\genex\La_Voiture\assets\cars\audi_r8\raw\audi_r8_raw.glb", "AUDI R8 RAW (MESHY)")
