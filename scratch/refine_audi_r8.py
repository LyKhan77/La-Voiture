# Audi R8 LMS GT3 body polish: decimate the Meshy mesh, orient/scale it to FIA GT3 size, cut the 4 baked wheels out with
# exact-boolean cylinders, snap the arch lips to clean circles and build curved inner fender tubs (FenderLinerMat, slot 1).
#   blender --background --python scratch/refine_audi_r8.py -- <raw.glb> <out.glb> [render_dir]
# Final space is Blender space (X sideways, Y = -Godot Z, Z up); the glTF exporter converts to Godot (+Z front, +Y up).
import bpy, bmesh, math, os, sys
import numpy as np
from math import sin, cos, atan2, hypot, radians
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC, DST = argv[0], argv[1]
RENDER_DIR = argv[2] if len(argv) > 2 else None

# ---- design values (m) -----------------------------------------------------------------------------
LENGTH = 4.55          # FIA GT3 overall length, the one dimension the uniform scale is driven by
RATIO = 0.045          # collapse-decimate ratio of the 2.77M-face Meshy mesh (-> ~100k tris once the wheels are gone)
R_LIP = 0.372          # arch opening radius
R_TUB = 0.369          # tub wall radius, 3 mm inside the opening so leftover wall slivers behind it never z-fight
X_IN = 0.65            # inboard closing wall of the tub
X_CUT = 0.50           # wheel-cutter cylinders start here (tire + brakes live at |x| 0.54 .. 1.02)
Z_AXLE = 0.33          # wheel centre height after the body is dropped onto the ground
Z_FLOOR = 0.10         # tub never reaches below the body underside
# Measured on the staged mesh (ground = lowest point, +90deg yaw, uniform scale), before the final recentring:
RAW_AXLE_Y = {"F": -1.215, "R": 1.461}     # tread circle fits, lower arc, x 0.66..1.00
RAW_AXLE_Z = 0.350
Y_MID = (RAW_AXLE_Y["F"] + RAW_AXLE_Y["R"]) / 2
AXLE = {"FL": (-1, RAW_AXLE_Y["F"] - Y_MID), "FR": (1, RAW_AXLE_Y["F"] - Y_MID),
        "RL": (-1, RAW_AXLE_Y["R"] - Y_MID), "RR": (1, RAW_AXLE_Y["R"] - Y_MID)}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
ob.name = "AudiR8_Body"; ob.data.name = "AudiR8_Body"
me = ob.data
print("raw", len(me.vertices), "verts", len(me.polygons), "faces")

# ---- 1. decimate ---------------------------------------------------------------------------------------------
bpy.context.view_layer.objects.active = ob
md = ob.modifiers.new("Dec", "DECIMATE"); md.decimate_type = "COLLAPSE"; md.ratio = RATIO; md.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=md.name)
print("decimated ->", len(me.vertices), "verts", sum(len(p.vertices) - 2 for p in me.polygons), "tris")

# ---- 2. orient (raw front = -X  ->  front = -Y), scale to LENGTH, ground, centre ------------------------------
n = len(me.vertices)
P = np.empty(n * 3); me.vertices.foreach_get("co", P); P = P.reshape(-1, 3)
S = LENGTH / (P[:, 0].max() - P[:, 0].min())
Q = np.c_[-P[:, 1], P[:, 0], P[:, 2]] * S
Q[:, 2] -= Q[:, 2].min() + (RAW_AXLE_Z - Z_AXLE)      # lowest baked-tire point to z=0, then drop the body so the axle sits at Z_AXLE
Q[:, 1] -= Y_MID
me.vertices.foreach_set("co", Q.ravel()); me.update()
print("scale %.4f  bbox min %s max %s" % (S, Q.min(0).round(3), Q.max(0).round(3)))

# ---- 3. liner material (slot 1) ---------------------------------------------------------------------------------
paint_mat = me.materials[0]; paint_mat.name = "AudiR8_Paint"
liner_mat = bpy.data.materials.new("FenderLinerMat"); me.materials.append(liner_mat)
liner_mat.use_nodes = True
bsdf = next(nd for nd in liner_mat.node_tree.nodes if nd.type == "BSDF_PRINCIPLED")
bsdf.inputs["Base Color"].default_value = (0.0030, 0.0030, 0.0030, 1)     # sRGB #0A0A0A
bsdf.inputs["Roughness"].default_value = 0.95
bsdf.inputs["Metallic"].default_value = 0.0
LINER_IDX = 1

# ---- 4. cut the baked wheels out with exact-boolean cylinders ---------------------------------------------------
cut_me = bpy.data.meshes.new("WheelCutters"); cut_ob = bpy.data.objects.new("WheelCutters", cut_me)
bpy.context.scene.collection.objects.link(cut_ob)
cb = bmesh.new(); SEG = 96
for k, (sg, yc) in AXLE.items():
    rings = []
    for x in (X_CUT * sg, 1.35 * sg):
        rings.append([cb.verts.new((x, yc + R_LIP * sin(2 * math.pi * j / SEG), Z_AXLE + R_LIP * cos(2 * math.pi * j / SEG))) for j in range(SEG)])
    for j in range(SEG):
        cb.faces.new([rings[0][j], rings[0][(j + 1) % SEG], rings[1][(j + 1) % SEG], rings[1][j]])
    cb.faces.new(rings[0][::-1]); cb.faces.new(rings[1])
bmesh.ops.recalc_face_normals(cb, faces=cb.faces)
cb.to_mesh(cut_me); cb.free()
bm_mod = ob.modifiers.new("Cut", "BOOLEAN"); bm_mod.operation = "DIFFERENCE"; bm_mod.operand_type = "OBJECT"; bm_mod.object = cut_ob
bm_mod.solver = "EXACT"; bm_mod.use_self = False; bm_mod.use_hole_tolerant = True
bpy.ops.object.modifier_apply(modifier=bm_mod.name)
bpy.data.objects.remove(cut_ob); bpy.data.meshes.remove(cut_me)
print("after wheel cut:", len(me.vertices), "verts", len(me.polygons), "faces")

bm = bmesh.new(); bm.from_mesh(me)

# the exact solver can leave a sliver reaching the cutter's outer cap; nothing legitimate lies beyond |x| 1.10
stray = [f for f in bm.faces if any(abs(v.co.x) > 1.10 for v in f.verts)]
print("stray cutter-cap faces", len(stray))
bmesh.ops.delete(bm, geom=stray, context="FACES")

# ---- 5. drop crumbs the cut orphaned (islands < 60 faces entirely inside a wheel zone) --------------------------
def near_wheel(c):
    return any(c.x * sg > 0.45 and hypot(c.y - yc, c.z - Z_AXLE) < 0.62 for sg, yc in AXLE.values())
bm.faces.ensure_lookup_table()
parent = list(range(len(bm.faces)))
def find(a):
    while parent[a] != a:
        parent[a] = parent[parent[a]]; a = parent[a]
    return a
first = {}
for f in bm.faces:
    for v in f.verts:
        key = (round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4))
        if key in first:
            parent[find(f.index)] = find(first[key])
        else:
            first[key] = f.index
groups = {}
for f in bm.faces:
    groups.setdefault(find(f.index), []).append(f)
crumbs = [f for g in groups.values() if len(g) < 60 and all(near_wheel(f.calc_center_median()) for f in g) for f in g]
print("islands", len(groups), "removing crumb faces", len(crumbs))
bmesh.ops.delete(bm, geom=crumbs, context="FACES")

# ---- 6. snap the ragged lip boundary onto an exact circle ----------------------------------------------------------
wb = bm.copy()
bmesh.ops.remove_doubles(wb, verts=wb.verts, dist=1e-5)
bnd = set()
for e in wb.edges:
    if e.is_boundary:
        for v in e.verts:
            bnd.add((round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4)))
wb.free()
snapped = 0
mouth = {k: [] for k in AXLE}                       # (angle from straight-up, |x|) of every snapped outer-lip vertex
for v in bm.verts:
    key = (round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4))
    if key not in bnd:
        continue
    for k, (sg, yc) in AXLE.items():
        r = hypot(v.co.y - yc, v.co.z - Z_AXLE)
        if v.co.x * sg >= 0.90 and 0.36 < r < 0.43:
            d = Vector((v.co.y - yc, v.co.z - Z_AXLE)); d.normalize()
            v.co.y, v.co.z = yc + d.x * R_LIP, Z_AXLE + d.y * R_LIP
            mouth[k].append((math.degrees(atan2(d.x, d.y)), v.co.x * sg))
            snapped += 1
            break
print("snapped lip boundary verts", snapped, {k: len(v) for k, v in mouth.items()})

# ---- 7. inner tubs -----------------------------------------------------------------------------------------------------
TAPER = 25.0           # degrees over which the tub fades out where the body skin ends below the axle
def mouth_profile(k):
    """Outermost lip |x| per 1-degree bin (median-smoothed, small gaps interpolated) and the angular span that has body skin."""
    bins = np.full(361, np.nan)
    cnt = np.zeros(361)
    for a, x in mouth[k]:
        i = int(round(a)) + 180
        if 0 <= i <= 360:
            cnt[i] += 1
            if np.isnan(bins[i]) or x > bins[i]:
                bins[i] = x
    ok = ~np.isnan(bins)
    prof = np.interp(np.arange(361), np.arange(361)[ok], bins[ok])
    prof = np.array([np.median(prof[max(0, i - 3):i + 4]) for i in range(361)])
    have = np.nonzero(ok)[0]
    return prof, have.min() - 180, have.max() - 180

def tub(k, sg, yc):
    prof, lo, hi = mouth_profile(k)
    a_lo, a_hi = max(lo - TAPER, -170.0), min(hi + TAPER, 170.0)
    segs = int(math.ceil((a_hi - a_lo) / 5.0))
    def mouth_at(deg):
        edge = min(deg - lo, hi - deg)                      # < 0 outside the skinned span
        base = float(prof[int(round(deg)) + 180])
        fade = max(0.0, min(1.0, 1.0 + edge / TAPER))
        return X_IN + 0.02 + (base - 0.002 - X_IN - 0.02) * fade
    fr = [0.0, 0.18, 0.34, 0.50, 0.66, 0.82, 1.0]
    ring = []
    for t in fr:
        row = []
        for j in range(segs + 1):
            deg = a_lo + (a_hi - a_lo) * j / segs
            a = radians(deg); x0 = mouth_at(deg)
            row.append(bm.verts.new(((x0 + (X_IN - x0) * t) * sg, yc + R_TUB * sin(a), max(Z_FLOOR, Z_AXLE + R_TUB * cos(a)))))
        ring.append(row)
    new_faces = []
    for xi in range(len(fr) - 1):
        for j in range(segs):
            vs = [ring[xi][j], ring[xi][j + 1], ring[xi + 1][j + 1], ring[xi + 1][j]]
            new_faces.append(bm.faces.new(vs if sg > 0 else vs[::-1]))
    # closing inboard wall: a full disc fan (z clamped like the strip), independent of how far the strip reaches
    cen = bm.verts.new((X_IN * sg, yc, Z_AXLE))
    disc = [bm.verts.new((X_IN * sg, yc + R_TUB * sin(radians(d)), max(Z_FLOOR, Z_AXLE + R_TUB * cos(radians(d))))) for d in range(0, 360, 6)]
    for j in range(len(disc)):
        vs = [disc[(j + 1) % len(disc)], disc[j], cen]
        new_faces.append(bm.faces.new(vs if sg > 0 else vs[::-1]))
    for f in new_faces:
        f.material_index = LINER_IDX

for k, (sg, yc) in AXLE.items():
    tub(k, sg, yc)
bm.normal_update()
bm.to_mesh(me); bm.free(); me.update()

# winding: tub normals face the wheel
bm = bmesh.new(); bm.from_mesh(me)
flipped = 0
for f in bm.faces:
    if f.material_index != LINER_IDX:
        continue
    c = f.calc_center_median()
    for k, (sg, yc) in AXLE.items():
        if c.x * sg > X_IN - 0.01 and hypot(c.y - yc, c.z - Z_AXLE) < R_TUB + 0.01 and c.x * sg < 1.1:
            toward_axle = Vector((0, yc - c.y, Z_AXLE - c.z))
            ref = toward_axle if abs(f.normal.x) < 0.5 else Vector((sg, 0, 0))
            if f.normal.dot(ref) < 0:
                f.normal_flip(); flipped += 1
            break
print("flipped tub faces", flipped)
bm.to_mesh(me); bm.free(); me.update()
for p in me.polygons:
    if p.material_index == LINER_IDX:
        p.use_smooth = abs(p.normal.x) < 0.5

# ---- report --------------------------------------------------------------------------------------------------------------
n = len(me.vertices)
P = np.empty(n * 3); me.vertices.foreach_get("co", P); P = P.reshape(-1, 3)
print("FINAL tris", sum(len(p.vertices) - 2 for p in me.polygons), "bbox min", P.min(0).round(3), "max", P.max(0).round(3),
      "size (x w, y len, z h)", (P.max(0) - P.min(0)).round(3))
for k, v in mouth.items():
    print("mouth", k, "|x| mean %.3f max %.3f min %.3f" % (np.mean([x for _, x in v]), max(x for _, x in v), min(x for _, x in v)) if v else "none")

# ---- export (the Meshy PBR textures stay embedded so the GLB shows its own colours in any viewer; Godot wires its toon material to the copies in textures/) ---
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True); bpy.context.view_layer.objects.active = ob
bpy.ops.export_scene.gltf(filepath=DST, use_selection=True, export_format="GLB", export_apply=False, export_yup=True,
                          export_image_format="AUTO", export_cameras=False, export_lights=False)
print("exported", DST, os.path.getsize(DST))

# ---- optional previews ---------------------------------------------------------------------------------------------------
if RENDER_DIR:
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = sc.render.resolution_y = 800
    for m in me.materials:
        if m: m.use_backface_culling = True
    cd = bpy.data.cameras.new("c"); cd.lens = 45
    cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
    def shot(name, loc, tgt):
        cam.location = loc; cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(RENDER_DIR, name + ".png"); bpy.ops.render.render(write_still=True)
    yf, yr = AXLE["FR"][1], AXLE["RR"][1]
    shot("ar_FR_out", (2.9, yf - 2.2, 0.55), (0.9, yf, 0.35))
    shot("ar_FR_side", (3.2, yf, 0.45), (0.9, yf, 0.40))
    shot("ar_RR_out", (2.9, yr + 2.2, 0.55), (0.9, yr, 0.35))
    shot("ar_RL_low", (-2.4, yr + 1.6, 0.15), (-0.9, yr, 0.35))
    shot("ar_FL_out", (-2.9, yf - 2.2, 0.55), (-0.9, yf, 0.35))
    shot("ar_full", (4.5, -3.5, 1.4), (0.0, 0.0, 0.5))
