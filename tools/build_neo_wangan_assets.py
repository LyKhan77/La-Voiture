"""Blender 5.2: deterministic metre-scale Neo-Wangan modular architecture.

Run: blender --background --python tools/build_neo_wangan_assets.py
Local Z is up in Blender; glTF export converts it to Godot Y-up. All origins sit
on their foundation. Original procedural geometry, guided by project concept art.
"""
from pathlib import Path
import json
import math
import bpy
from mathutils import Vector

OUTPUT = Path(__file__).resolve().parents[1] / "assets/tracks/neo_wangan/models"
PALETTE = {"concrete": (0.30, 0.35, 0.44, 1), "dark": (0.055, 0.075, 0.12, 1),
           "steel": (0.5, 0.6, 0.72, 1), "cyan": (0.0, 0.94, 1.0, 1),
           "magenta": (1.0, 0.12, 0.34, 1), "white": (0.88, 0.91, 0.96, 1),
           "red": (0.72, 0.075, 0.10, 1), "window": (0.32, 0.66, 0.82, 1)}
groups = {}
manifest = []


def solid(name, vertices, faces, color="concrete"):
    verts, polys, colors = groups.setdefault(name, ([], [], []))
    offset = len(verts)
    verts.extend(vertices)
    polys.extend(tuple(offset + i for i in face) for face in faces)
    value = PALETTE[color]
    # Vertex alpha is the shared Godot cel shader's emission mask, not transparency.
    if name in ("WindowsMat", "StayCablesMat") and color in ("cyan", "magenta", "window"):
        value = (*value[:3], 0.25)
    colors.extend([value] * len(faces))


def box(name, center, size, color="concrete"):
    x, y, z = center
    a, b, c = (v / 2 for v in size)
    vertices = [(x+i*a, y+j*b, z+k*c) for i,j,k in
                [(-1,-1,-1), (1,-1,-1), (1,1,-1), (-1,1,-1),
                 (-1,-1,1), (1,-1,1), (1,1,1), (-1,1,1)]]
    solid(name, vertices, [(0,3,2,1), (4,5,6,7), (0,1,5,4),
                           (1,2,6,5), (2,3,7,6), (3,0,4,7)], color)


def beam(name, a, b, radius, color="steel"):
    start, end = Vector(a), Vector(b)
    axis = (end-start).normalized()
    side = axis.cross(Vector((0,0,1)))
    if side.length < 0.01:
        side = axis.cross(Vector((0,1,0)))
    side.normalize()
    up = axis.cross(side)
    vertices = [tuple(point + radius*(math.cos(i*math.tau/6)*side + math.sin(i*math.tau/6)*up))
                for point in (start,end) for i in range(6)]
    faces = [(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
    faces += [tuple(reversed(range(6))), tuple(range(6,12))]
    solid(name, vertices, faces, color)


def chamfered(name, width, depth, bottom, height, color="dark"):
    cut = min(width, depth)*0.16
    ring = [(-width/2+cut,-depth/2),(width/2-cut,-depth/2),
            (width/2,-depth/2+cut),(width/2,depth/2-cut),
            (width/2-cut,depth/2),(-width/2+cut,depth/2),
            (-width/2,depth/2-cut),(-width/2,-depth/2+cut)]
    vertices = [(x,y,z) for z in (bottom,bottom+height) for x,y in ring]
    faces = [(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
    faces += [tuple(reversed(range(8))),tuple(range(8,16))]
    solid(name, vertices, faces, color)


def windows(width, depth, bottom, height):
    for level in range(int(height/3)):
        z = bottom+1.6+level*3
        for side in (-1,1):
            box("WindowsMat", (0,side*(depth/2+0.02),z), (width*0.78,0.05,0.7), "window")
            box("WindowsMat", (side*(width/2+0.02),0,z), (0.05,depth*0.78,0.7), "window")


def pylon():
    for x in (-20,20):
        box("PylonConcreteMat", (x,0,32.5), (4,5,65))
        box("PylonConcreteMat", (x,0,-1), (8,9,2))
        box("StayCablesMat", (x-2.03,0,33), (0.1,3.2,62), "cyan")
        for direction in (-1,1):
            for n in range(4):
                beam("StayCablesMat", (x,0,61-n*5), (math.copysign(7.2,x),direction*(24+n*13),2), 0.13)
    for z in (20,57,63):
        box("PylonConcreteMat", (0,0,z), (44,4,2.0))
    for x in range(-18,19,6):
        beam("PylonConcreteMat", (x,0,57), (x+6,0,63), 0.24)


def portal():
    for side in (-1,1):
        box("PortalConcreteMat", (side*9.5,0,3.0), (4,16,6))
        box("PortalConcreteMat", (side*13,5,1.8), (3,26,3.6))
        box("PortalConcreteMat", (side*8,0,4.5), (0.3,16,0.45), "cyan")
    box("PortalConcreteMat", (0,0,6.0), (30,18,1.5))
    box("PortalConcreteMat", (0,0,7.0), (32,20,0.5), "steel")
    for x in range(-14,15,4):
        box("PortalConcreteMat", (x,9.3,7.8), (3.6,0.35,1.2))
    for x in (-4,4):
        beam("PortalVentMat", (x,-5.0,4.8), (x,-2.4,4.8), 0.42, "steel")
    box("PortalConcreteMat", (11,0,9.0), (7,13,3.0), "dark")


def crane():
    for x in (-6,6):
        for y in (-5,5):
            beam("HarborCraneMat", (x,y,0), (x*0.75,y,27), 0.5, "red")
            box("HarborCraneMat", (x,y,0.7), (3,3,1.4), "dark")
        for z in range(3,25,6):
            beam("HarborCraneMat", (x,-5,z), (x,5,z+6), 0.18, "white")
    for y in (-3,3):
        beam("HarborCraneMat", (-10,y,27), (22,y,27), 0.45, "red")
        beam("HarborCraneMat", (-10,y,29), (22,y,29), 0.3, "white")
        for x in range(-10,22,4):
            beam("HarborCraneMat", (x,y,27), (x+4,y,29), 0.15, "red")
    box("HarborCraneMat", (4,0,25.5), (4,5,2.8), "white")
    box("HarborCraneMat", (4,-2.55,25.6), (3,0.1,1.5), "cyan")
    for y in (-1.5,1.5):
        beam("HarborCraneMat", (17,y,27), (17,y,9), 0.05, "dark")
    box("HarborCraneMat", (17,0,8.8), (5,4,0.4), "red")
    for x in (-3,0,3):
        for level in range(2):
            box("HarborCraneMat", (x,8,1.3+level*2.6), (2.8,6,2.5), "red" if x else "white")


def tower_a():
    for width,depth,bottom,height in [(16,16,0,5),(12,12,5,30),(9,9,35,16)]:
        chamfered("TowerShellMat",width,depth,bottom,height)
        windows(width,depth,bottom,height)
        box("TowerShellMat", (0,0,bottom+height), (width+0.4,depth+0.4,0.4), "concrete")
    box("TowerShellMat", (0,0,51.5), (10,10,0.6), "steel")
    for x in (-1,1):
        box("WindowsMat", (x*1.6,0,51.82), (0.35,4,0.05), "cyan")
    box("WindowsMat", (0,0,51.82), (3.2,0.35,0.05), "cyan")
    beam("TowerShellMat", (2,2,52), (2,2,62), 0.14)
    box("WindowsMat", (2,2,62), (0.4,0.4,0.4), "magenta")


def tower_b():
    chamfered("TowerShellMat",14,12,0,41)
    windows(14,12,0,41)
    for z in (6,20,40,43):
        box("WindowsMat", (0,0,z), (14.5,12.5,0.35), "magenta")
    box("TowerShellMat", (0,-6.6,17), (11,0.7,13), "steel")
    box("WindowsMat", (0,-7,17), (9.8,0.1,11.8), "cyan")


def tower_c():
    box("TowerShellMat", (0,0,3), (18,14,6))
    for x in (-4.5,4.5):
        box("TowerShellMat", (x,0,17), (7,10,24), "dark")
        box("WindowsMat", (x,0,29.2), (7.4,10.4,0.4), "cyan")
        for z in range(8,28,3):
            for side in (-1,1):
                box("WindowsMat", (x,side*5.03,z), (5.6,0.05,0.8), "window")
    for x in range(-7,8,3):
        box("WindowsMat", (x,-7.03,2.4), (2,0.05,3.4), "cyan")


def export(name, build):
    groups.clear()
    build()
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    objects = []
    triangle_count = 0
    for material_name, (vertices,faces,colors) in groups.items():
        mesh = bpy.data.meshes.new(name+"_"+material_name)
        mesh.from_pydata(vertices,[],faces)
        mesh.update()
        attr = mesh.color_attributes.new(name="Color",type="FLOAT_COLOR",domain="CORNER")
        for poly,color in zip(mesh.polygons,colors):
            for loop in poly.loop_indices:
                attr.data[loop].color_srgb = color
        material = bpy.data.materials.new(material_name)
        material.use_nodes = True
        nodes = material.node_tree.nodes
        color_node = nodes.new("ShaderNodeVertexColor")
        color_node.layer_name = "Color"
        shader = nodes.get("Principled BSDF")
        material.node_tree.links.new(color_node.outputs["Color"],shader.inputs["Base Color"])
        material.node_tree.links.new(color_node.outputs["Alpha"],shader.inputs["Alpha"])
        shader.inputs["Roughness"].default_value = 0.65
        if material_name in ("WindowsMat","StayCablesMat"):
            material.node_tree.links.new(color_node.outputs["Color"],shader.inputs["Emission Color"])
            shader.inputs["Emission Strength"].default_value = 0.7
        mesh.materials.append(material)
        obj = bpy.data.objects.new(material_name,mesh)
        collection.objects.link(obj)
        objects.append(obj)
        mesh.calc_loop_triangles()
        triangle_count += len(mesh.loop_triangles)
    assert 100 < triangle_count <= 5000, (name,triangle_count)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    path = OUTPUT/(name+".glb")
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
                              export_yup=True,export_apply=True,export_extras=True)
    manifest.append({"file":path.name,"triangles":triangle_count,"surfaces":len(groups),
                     "origin":"foundation","unit":"metre","source":"procedural Blender 5.2 / build_neo_wangan_assets.py"})
    print(f"NEO_WANGAN_ASSET {path.name}: {triangle_count} triangles, {len(groups)} surfaces")
    # Only objects authored by this invocation are removed; existing Blender scene is untouched.
    for obj in objects:
        bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.collections.remove(collection)


OUTPUT.mkdir(parents=True,exist_ok=True)
for filename,builder in [("shuto_bridge_pylon",pylon),("tunnel_portal_overpass",portal),
                         ("harbor_gantry_crane",crane),("skyscraper_tower_a",tower_a),
                         ("skyscraper_tower_b",tower_b),("skyscraper_tower_c",tower_c)]:
    export(filename,builder)
(OUTPUT/"asset_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
