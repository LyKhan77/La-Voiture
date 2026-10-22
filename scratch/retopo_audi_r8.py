# Audi R8 retopo + bake EXPERIMENT (output goes to temp/, nothing in assets/ is touched).
# raw Meshy mesh (2.77M tris, closed once welded) -> voxel remesh -> smooth -> collapse to ~115k tris -> wheel cut + lip snap + tubs
# (same as refine_audi_r8.py) -> Smart UV -> Cycles bake of base colour + tangent normal from the raw mesh -> GLB.
#   blender --background --python scratch/retopo_audi_r8.py -- <raw.glb> <out_dir> [smooth_iters=40] [target_tris=115000]
import bpy, bmesh, math, os, sys, time
import numpy as np
from math import sin, cos, atan2, hypot, radians
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
SMOOTH_ITERS = int(argv[2]) if len(argv) > 2 else 40
TARGET_TRIS = int(argv[3]) if len(argv) > 3 else 115000
os.makedirs(OUT, exist_ok=True)
T0 = time.time()
def log(*a): print("RT %6.1fs" % (time.time() - T0), *a, flush=True)

# ---- same geometry constants as refine_audi_r8.py ---------------------------------------------------------------------
LENGTH, R_LIP, R_TUB, X_IN, X_CUT, Z_AXLE, Z_FLOOR, TAPER = 4.55, 0.372, 0.369, 0.65, 0.50, 0.33, 0.10, 25.0
RAW_AXLE_Y = {"F": -1.215, "R": 1.461}; RAW_AXLE_Z = 0.350
Y_MID = (RAW_AXLE_Y["F"] + RAW_AXLE_Y["R"]) / 2
AXLE = {"FL": (-1, RAW_AXLE_Y["F"] - Y_MID), "FR": (1, RAW_AXLE_Y["F"] - Y_MID), "RL": (-1, RAW_AXLE_Y["R"] - Y_MID), "RR": (1, RAW_AXLE_Y["R"] - Y_MID)}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
hp = [o for o in bpy.data.objects if o.type == "MESH"][0]; hp.name = "HP_raw"; hp.data.name = "HP_raw"
me = hp.data
n = len(me.vertices); P = np.empty(n * 3); me.vertices.foreach_get("co", P); P = P.reshape(-1, 3)
S = LENGTH / (P[:, 0].max() - P[:, 0].min())
Q = np.c_[-P[:, 1], P[:, 0], P[:, 2]] * S
Q[:, 2] -= Q[:, 2].min() + (RAW_AXLE_Z - Z_AXLE); Q[:, 1] -= Y_MID
me.vertices.foreach_set("co", Q.ravel()); me.update()
bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6); bm.to_mesh(me); bm.free(); me.update()
log("high-poly welded:", len(me.polygons), "faces")

# ---- 1. low-poly: voxel remesh -> smooth -> collapse -------------------------------------------------------------------
lp_me = me.copy(); lp_me.name = "AudiR8_Retopo"
lp = bpy.data.objects.new("AudiR8_Retopo", lp_me); bpy.context.scene.collection.objects.link(lp)
lp_me.materials.clear()
bpy.context.view_layer.objects.active = lp
for o in bpy.data.objects: o.select_set(o is lp)
lp_me.remesh_voxel_size = 0.012; lp_me.remesh_voxel_adaptivity = 0.0
bpy.ops.object.voxel_remesh()
log("voxel remesh:", len(lp_me.polygons), "quads")
md = lp.modifiers.new("cs", "CORRECTIVE_SMOOTH"); md.smooth_type = "LENGTH_WEIGHTED"; md.factor = 0.8; md.iterations = SMOOTH_ITERS; md.use_only_smooth = True; md.rest_source = "ORCO"
bpy.ops.object.modifier_apply(modifier=md.name)
bm = bmesh.new(); bm.from_mesh(lp_me); bmesh.ops.triangulate(bm, faces=bm.faces); bm.to_mesh(lp_me); bm.free()
md = lp.modifiers.new("dec", "DECIMATE"); md.decimate_type = "COLLAPSE"; md.ratio = TARGET_TRIS / len(lp_me.polygons)
bpy.ops.object.modifier_apply(modifier=md.name)
for p in lp_me.polygons: p.use_smooth = True
log("smoothed %d it, collapsed to" % SMOOTH_ITERS, len(lp_me.polygons), "tris")

# ---- 2. materials, wheel cut, lip snap, tubs (as in refine_audi_r8.py) ----------------------------------------------------
paint = bpy.data.materials.new("AudiR8_Paint"); lp_me.materials.append(paint)
liner = bpy.data.materials.new("FenderLinerMat"); lp_me.materials.append(liner)
liner.use_nodes = True
nb = next(nd for nd in liner.node_tree.nodes if nd.type == "BSDF_PRINCIPLED")
nb.inputs["Base Color"].default_value = (0.0030, 0.0030, 0.0030, 1); nb.inputs["Roughness"].default_value = 0.95; nb.inputs["Metallic"].default_value = 0.0
LINER_IDX = 1

cut_me = bpy.data.meshes.new("WheelCutters"); cut_ob = bpy.data.objects.new("WheelCutters", cut_me); bpy.context.scene.collection.objects.link(cut_ob)
cb = bmesh.new(); SEG = 96
for k, (sg, yc) in AXLE.items():
    rings = []
    for x in (X_CUT * sg, 1.35 * sg):
        rings.append([cb.verts.new((x, yc + R_LIP * sin(2 * math.pi * j / SEG), Z_AXLE + R_LIP * cos(2 * math.pi * j / SEG))) for j in range(SEG)])
    for j in range(SEG):
        cb.faces.new([rings[0][j], rings[0][(j + 1) % SEG], rings[1][(j + 1) % SEG], rings[1][j]])
    cb.faces.new(rings[0][::-1]); cb.faces.new(rings[1])
bmesh.ops.recalc_face_normals(cb, faces=cb.faces); cb.to_mesh(cut_me); cb.free()
bpy.context.view_layer.objects.active = lp
bmod = lp.modifiers.new("Cut", "BOOLEAN"); bmod.operation = "DIFFERENCE"; bmod.operand_type = "OBJECT"; bmod.object = cut_ob
bmod.solver = "EXACT"; bmod.use_self = False; bmod.use_hole_tolerant = True
bpy.ops.object.modifier_apply(modifier=bmod.name)
bpy.data.objects.remove(cut_ob); bpy.data.meshes.remove(cut_me)
log("after wheel cut:", len(lp_me.polygons), "faces")

bm = bmesh.new(); bm.from_mesh(lp_me)
stray = [f for f in bm.faces if any(abs(v.co.x) > 1.10 for v in f.verts)]
bmesh.ops.delete(bm, geom=stray, context="FACES")
def near_wheel(c): return any(c.x * sg > 0.45 and hypot(c.y - yc, c.z - Z_AXLE) < 0.62 for sg, yc in AXLE.values())
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
        if key in first: parent[find(f.index)] = find(first[key])
        else: first[key] = f.index
groups = {}
for f in bm.faces: groups.setdefault(find(f.index), []).append(f)
crumbs = [f for g in groups.values() if len(g) < 60 and all(near_wheel(f.calc_center_median()) for f in g) for f in g]
bmesh.ops.delete(bm, geom=crumbs, context="FACES")
log("stray faces", len(stray), "crumb faces", len(crumbs))

# The voxel remesh is a closed solid, so the wheel cut leaves no open lip edge to snap. Measure the lip instead: the outermost |x| of any
# vertex sitting in the ring just outside the cut circle, per degree around the axle (the tub then starts right at the body skin).
mouth = {k: [] for k in AXLE}
for v in bm.verts:
    for k, (sg, yc) in AXLE.items():
        r = hypot(v.co.y - yc, v.co.z - Z_AXLE)
        if v.co.x * sg >= 0.88 and R_LIP - 0.002 < r < 0.46:
            mouth[k].append((math.degrees(atan2(v.co.y - yc, v.co.z - Z_AXLE)), v.co.x * sg)); break
log("lip samples", {k: len(v) for k, v in mouth.items()})

def mouth_profile(k):
    bins = np.full(361, np.nan)
    for a, x in mouth[k]:
        i = int(round(a)) + 180
        if 0 <= i <= 360 and (np.isnan(bins[i]) or x > bins[i]): bins[i] = x
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
        edge = min(deg - lo, hi - deg); base = float(prof[int(round(deg)) + 180]); fade = max(0.0, min(1.0, 1.0 + edge / TAPER))
        return X_IN + 0.02 + (base - 0.002 - X_IN - 0.02) * fade
    fr = [0.0, 0.18, 0.34, 0.50, 0.66, 0.82, 1.0]; ring = []
    for t in fr:
        row = []
        for j in range(segs + 1):
            deg = a_lo + (a_hi - a_lo) * j / segs; a = radians(deg); x0 = mouth_at(deg)
            row.append(bm.verts.new(((x0 + (X_IN - x0) * t) * sg, yc + R_TUB * sin(a), max(Z_FLOOR, Z_AXLE + R_TUB * cos(a)))))
        ring.append(row)
    new_faces = []
    for xi in range(len(fr) - 1):
        for j in range(segs):
            vs = [ring[xi][j], ring[xi][j + 1], ring[xi + 1][j + 1], ring[xi + 1][j]]
            new_faces.append(bm.faces.new(vs if sg > 0 else vs[::-1]))
    cen = bm.verts.new((X_IN * sg, yc, Z_AXLE))
    disc = [bm.verts.new((X_IN * sg, yc + R_TUB * sin(radians(d)), max(Z_FLOOR, Z_AXLE + R_TUB * cos(radians(d))))) for d in range(0, 360, 6)]
    for j in range(len(disc)):
        vs = [disc[(j + 1) % len(disc)], disc[j], cen]
        new_faces.append(bm.faces.new(vs if sg > 0 else vs[::-1]))
    for f in new_faces: f.material_index = LINER_IDX
for k, (sg, yc) in AXLE.items(): tub(k, sg, yc)
bm.normal_update(); bm.to_mesh(lp_me); bm.free(); lp_me.update()
bm = bmesh.new(); bm.from_mesh(lp_me)
for f in bm.faces:
    if f.material_index != LINER_IDX: continue
    c = f.calc_center_median()
    for k, (sg, yc) in AXLE.items():
        if c.x * sg > X_IN - 0.01 and hypot(c.y - yc, c.z - Z_AXLE) < R_TUB + 0.01 and c.x * sg < 1.1:
            ref = Vector((0, yc - c.y, Z_AXLE - c.z)) if abs(f.normal.x) < 0.5 else Vector((sg, 0, 0))
            if f.normal.dot(ref) < 0: f.normal_flip()
            break
bm.to_mesh(lp_me); bm.free(); lp_me.update()
for p in lp_me.polygons: p.use_smooth = (abs(p.normal.x) < 0.5) if p.material_index == LINER_IDX else True
log("tubs built; low-poly tris", sum(len(p.vertices) - 2 for p in lp_me.polygons))

# ---- 3. UV unwrap the paint faces ---------------------------------------------------------------------------------------------
lp_me.uv_layers.new(name="UVMap")
bpy.context.view_layer.objects.active = lp
for o in bpy.data.objects: o.select_set(o is lp)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="DESELECT"); lp.active_material_index = 0; bpy.ops.object.material_slot_select()
bpy.ops.uv.smart_project(angle_limit=radians(66), island_margin=0.003, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
bpy.ops.object.mode_set(mode="OBJECT")
log("smart UV done")

# ---- 4. bake base colour + tangent normal from the raw mesh --------------------------------------------------------------------
RES = 4096
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 4; sc.cycles.use_denoising = False
paint.use_nodes = True
nt = paint.node_tree; nt.nodes.clear()
tex_color = nt.nodes.new("ShaderNodeTexImage"); tex_color.image = bpy.data.images.new("bake_color", RES, RES, alpha=False); tex_color.image.colorspace_settings.name = "sRGB"
tex_norm = nt.nodes.new("ShaderNodeTexImage"); tex_norm.image = bpy.data.images.new("bake_normal", RES, RES, alpha=False, float_buffer=False); tex_norm.image.colorspace_settings.name = "Non-Color"
bsdf_p = nt.nodes.new("ShaderNodeBsdfPrincipled"); out = nt.nodes.new("ShaderNodeOutputMaterial")
nmap = nt.nodes.new("ShaderNodeNormalMap")
nt.links.new(tex_color.outputs["Color"], bsdf_p.inputs["Base Color"]); nt.links.new(tex_norm.outputs["Color"], nmap.inputs["Color"]); nt.links.new(nmap.outputs["Normal"], bsdf_p.inputs["Normal"])
bsdf_p.inputs["Metallic"].default_value = 0.1; bsdf_p.inputs["Roughness"].default_value = 0.45
nt.links.new(bsdf_p.outputs["BSDF"], out.inputs["Surface"])
for o in bpy.data.objects: o.select_set(o is hp)
lp.select_set(True); bpy.context.view_layer.objects.active = lp
common = dict(use_selected_to_active=True, cage_extrusion=0.03, max_ray_distance=0.08, margin=16, margin_type="EXTEND", use_clear=True)
tex_color.select = True; nt.nodes.active = tex_color
bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, **common); log("colour baked")
tex_norm.select = True; nt.nodes.active = tex_norm
bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", **common); log("normal baked")
for img, name in ((tex_color.image, "bake_color.png"), (tex_norm.image, "bake_normal.png")):
    img.filepath_raw = os.path.join(OUT, name); img.file_format = "PNG"; img.save()
log("textures saved")

# ---- 5. report + export ------------------------------------------------------------------------------------------------------------
bm = bmesh.new(); bm.from_mesh(lp_me); bmesh.ops.triangulate(bm, faces=bm.faces)
wb = bm.copy(); bmesh.ops.remove_doubles(wb, verts=wb.verts, dist=1e-5)
ang = np.array([math.degrees(e.calc_face_angle(0.0)) for e in wb.edges if len(e.link_faces) == 2])
pts = np.array([v.co[:] for v in bm.verts])
msg = "tris %d | boundary edges %d | dihedral median %.1f  >30deg %.1f%%  >60deg %.1f%% | bbox %s .. %s" % (
    len(bm.faces), sum(1 for e in wb.edges if e.is_boundary), np.median(ang), (ang > 30).mean() * 100, (ang > 60).mean() * 100, pts.min(0).round(3), pts.max(0).round(3))
log("FINAL", msg)
open(os.path.join(OUT, "metrics.txt"), "w").write(msg + "\n")
wb.free(); bm.free()
bpy.data.objects.remove(hp)
for o in bpy.data.objects: o.select_set(o is lp)
bpy.context.view_layer.objects.active = lp
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "audi_r8_body_retopo.glb"), use_selection=True, export_format="GLB", export_apply=False, export_yup=True,
                          export_image_format="JPEG", export_jpeg_quality=90, export_cameras=False, export_lights=False)
log("exported", os.path.getsize(os.path.join(OUT, "audi_r8_body_retopo.glb")))
