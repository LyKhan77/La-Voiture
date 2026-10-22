# Config-driven car body pipeline: raw AI mesh (closed once welded) -> game-ready body GLB with baked textures.
#   weld -> orient/scale/ground -> voxel remesh -> smooth (detail zones protected) -> collapse -> wheel cut -> lip warp -> tubs
#   -> Smart UV -> Cycles bake of base colour + tangent normal from the raw mesh -> GLB (+ PNG textures for the toon material).
#   blender --background --python scratch/refine_car.py -- scratch/car_configs/<car>.json [--out-dir <dir>]
# --out-dir redirects the GLB and the textures (use it for trial runs; without it the files in the config are overwritten).
# Quick looks that stop early: --detect-only (axles), --lift-report (fender lift per axle), --precut-only (needs "debug_precut": true), --stop-after-cut.
# Config knobs beyond the basics: "fender_lift" ("auto" | {"front": m, "rear": m}), "fender_margin" (skin above the arch top, 0.04), "ground_min" (0.05), "tub_arc_deg".
# Final space is Blender space (X sideways, Y = -Godot Z, Z up); the glTF exporter converts to Godot (+Z front, +Y up).
import bpy, bmesh, json, math, os, sys, time
import numpy as np
from math import sin, cos, atan2, hypot, radians
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
CFG = json.load(open(argv[0]))
PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(argv[0]))))
out_dir = os.path.abspath(argv[argv.index("--out-dir") + 1]) if "--out-dir" in argv else None   # absolute: Image.save() drops a relative path silently
def project_path(p): return p if os.path.isabs(p) else os.path.join(PROJECT, p)
RAW = project_path(CFG["raw_glb"])
BODY_GLB = os.path.join(out_dir, os.path.basename(CFG["body_glb"])) if out_dir else project_path(CFG["body_glb"])
TEX_DIR = out_dir if out_dir else project_path(CFG["texture_dir"])
os.makedirs(os.path.dirname(BODY_GLB), exist_ok=True); os.makedirs(TEX_DIR, exist_ok=True)
T0 = time.time()
def log(*a): print("RC %6.1fs" % (time.time() - T0), *a, flush=True)

LENGTH = CFG["length_m"]; R_LIP = CFG["arch_radius"]; R_TUB = CFG["tub_radius"]; X_IN = CFG["tub_inner_x"]
Z_AXLE = CFG["axle_z"]; X_CUT, Z_FLOOR, TAPER = 0.50, 0.10, 25.0
# The tub wall stops before Z_FLOOR would clamp it: below that angle the wall runs through the lower half of the 0.33 m tyre.
TUB_ARC = CFG.get("tub_arc_deg", math.degrees(math.acos((Z_FLOOR - Z_AXLE) / R_TUB)) - 3.0)
DETECT_ONLY = "--detect-only" in argv
def smoothstep(t): t = np.clip(t, 0.0, 1.0); return t * t * (3 - 2 * t)

# ---- 0. import, orient, scale, ground, weld ------------------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=RAW)
hp = [o for o in bpy.data.objects if o.type == "MESH"][0]; hp.name = "HP_raw"; hp.data.name = "HP_raw"
me = hp.data
n = len(me.vertices); P = np.empty(n * 3); me.vertices.foreach_get("co", P); P = P.reshape(-1, 3)

def detect_front_axis(P):
    """Raw front direction on the ground plane: the long horizontal axis; the nose is the end with the lower mean height
    (bonnet, versus engine cover and wing at the rear of a GT car)."""
    ext = P.max(0) - P.min(0); ax = 0 if ext[0] >= ext[1] else 1
    c = P[:, ax]; span = c.max() - c.min()
    lo_z = P[c < c.min() + 0.12 * span][:, 2].mean(); hi_z = P[c > c.max() - 0.12 * span][:, 2].mean()
    sgn = -1.0 if lo_z < hi_z else 1.0                      # nose at the low end -> front points to -axis
    v = [0.0, 0.0]; v[ax] = sgn
    return v

def detect_axles(Q):
    """Wheel axles from the tyres themselves (Q: ground at z=0, front at -Y): the contact patches give the axle y,
    a tread-circle search (centre at z = radius), refined by a least-squares fit of the lower arc, gives the axle height. Returns (front_y, rear_y, axle_z, radius)."""
    ys = {}
    for name, half in (("front", Q[:, 1] < 0), ("rear", Q[:, 1] >= 0)):
        side = half & (np.abs(Q[:, 0]) > 0.55) & (np.abs(Q[:, 0]) < 1.15)
        zmin = Q[side][:, 2].min()
        patch = Q[side & (Q[:, 2] < zmin + 0.012)]
        ys[name] = float(np.median(patch[:, 1])) if len(patch) > 20 else None
    if ys["front"] is None or ys["rear"] is None or ys["rear"] - ys["front"] < 1.8:
        raise RuntimeError("axle detection failed: contact patches %s" % ys)
    zs, rs_out = [], []
    for name in ("front", "rear"):
        yc = ys[name]
        m = (np.abs(Q[:, 0]) > 0.62) & (np.abs(Q[:, 0]) < 1.02) & (np.abs(Q[:, 1] - yc) < 0.48) & (Q[:, 2] < 0.8)
        pts = Q[m]
        rs = np.arange(0.28, 0.42, 0.002)
        scores = [int(((np.abs(np.hypot(pts[:, 1] - yc, pts[:, 2] - r) - r) < 0.006) & (pts[:, 2] < r)).sum()) for r in rs]
        r0 = float(rs[int(np.argmax(scores))]); zc = r0
        for _ in range(12):                                  # refine: least-squares circle with the centre y fixed, lower arc only
            d = np.hypot(pts[:, 1] - yc, pts[:, 2] - zc)
            sel = pts[(np.abs(d - r0) < 0.025) & (pts[:, 2] < zc)]
            if len(sel) < 30: break
            A = np.c_[2 * sel[:, 2], np.ones(len(sel))]; b = (sel[:, 1] - yc) ** 2 + sel[:, 2] ** 2
            zc, k = np.linalg.lstsq(A, b, rcond=None)[0]; r0 = float(np.sqrt(k + zc * zc))
        zs.append(float(zc)); rs_out.append(r0)
    return ys["front"], ys["rear"], float(np.mean(zs)), float(np.mean(rs_out))

fa = CFG["front_axis_raw"]
fx, fy = detect_front_axis(P) if fa == "auto" else fa
log("front axis (raw):", (fx, fy), "(auto)" if fa == "auto" else "(config)")
phi = -math.pi / 2 - atan2(fy, fx)                           # turn the raw front onto -Y (Blender) = +Z (Godot)
R = np.array([[cos(phi), -sin(phi)], [sin(phi), cos(phi)]])
Q = P.copy(); Q[:, :2] = P[:, :2] @ R.T
S = LENGTH / (Q[:, 1].max() - Q[:, 1].min()); Q *= S
Q[:, 2] -= Q[:, 2].min()                                     # ground = lowest vertex (a tyre contact patch)
ra = CFG.get("raw_axle", "auto")
if ra == "auto":
    RAW_Y_F, RAW_Y_R, RAW_Z, tyre_r = detect_axles(Q)
    log("axles detected from the tyres: front y %.3f  rear y %.3f  axle height %.3f  tread radius %.3f  (wheelbase %.3f)" % (RAW_Y_F, RAW_Y_R, RAW_Z, tyre_r, RAW_Y_R - RAW_Y_F))
else:
    RAW_Y_F, RAW_Y_R, RAW_Z = ra["front_y"], ra["rear_y"], ra["z"]
    log("axles from config: front y %.3f  rear y %.3f  z %.3f" % (RAW_Y_F, RAW_Y_R, RAW_Z))
if DETECT_ONLY:
    sys.exit(0)
Y_MID = (RAW_Y_F + RAW_Y_R) / 2
AXLE = {"FL": (-1, RAW_Y_F - Y_MID), "FR": (1, RAW_Y_F - Y_MID), "RL": (-1, RAW_Y_R - Y_MID), "RR": (1, RAW_Y_R - Y_MID)}
Q[:, 2] -= RAW_Z - Z_AXLE; Q[:, 1] -= Y_MID                  # axle height -> Z_AXLE, wheelbase centre -> y = 0

# ---- 0b. fender lift: the AI body fuses the tyre into the fender, so above and beside the tyre the skin can be lower than the arch top
# (axle + R_LIP) and the wheel cut then removes the whole outer fender there (tyre pokes out of the body). Lift the raw skin over each axle
# until it clears the arch top by FENDER_MARGIN. Done on the raw mesh before the cut, so the bake still matches. "fender_lift": "auto" | {"front": m, "rear": m}.
FENDER_MARGIN = CFG.get("fender_margin", 0.04)
def fender_widest(sg, yc):
    zone = (np.abs(Q[:, 1] - yc) < 0.45) & (Q[:, 2] > 0.30) & (Q[:, 2] < 0.85) & (Q[:, 0] * sg > 0)
    return float((Q[zone, 0] * sg).max())
def fender_top_profile(sg, yc):
    """Highest raw surface above the axle in each 4 cm bin of x across the wheel (|dy| < 0.15), from the tyre's inner side out to the widest fender point."""
    sx = Q[:, 0] * sg; col = np.abs(Q[:, 1] - yc) < 0.15; top = []
    for e in np.arange(0.70, fender_widest(sg, yc) - 0.045, 0.04):                  # stop short of the rounded outer edge
        m = col & (np.abs(sx - e) < 0.02)
        top.append(float(Q[m, 2].max() - Z_AXLE) if m.any() else 0.0)
    return top
lift_cfg = CFG.get("fender_lift", "auto"); lift = {"front": 0.0, "rear": 0.0}
for k, (sg, yc) in AXLE.items():
    axle_name = "front" if yc < 0 else "rear"; prof = fender_top_profile(sg, yc)
    need = max(0.0, R_LIP + FENDER_MARGIN - min(prof))
    lift[axle_name] = max(lift[axle_name], need) if lift_cfg == "auto" else float(lift_cfg.get(axle_name, 0.0))
    log("fender %s %s: skin above the axle (cm, inner to outer) %s -> need %.1f cm" % (axle_name, k, " ".join("%.0f" % (t * 100) for t in prof), need * 100))
lift = {a: min(v, 0.10) for a, v in lift.items()}
if "--lift-report" in argv:
    log("fender lift (m):", lift); sys.exit(0)
for k, (sg, yc) in AXLE.items():
    L = lift["front" if yc < 0 else "rear"]
    if L <= 0: continue
    dy, dz, sx = Q[:, 1] - yc, Q[:, 2] - Z_AXLE, Q[:, 0] * sg
    Q[:, 2] += L * smoothstep(dz / 0.30) * smoothstep((sx - 0.45) / 0.25) * (1.0 - smoothstep((np.abs(dy) - 0.40) / 0.35))
log("fender lift applied (m):", {a: round(v, 3) for a, v in lift.items()})
me.vertices.foreach_set("co", Q.ravel()); me.update()
bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
if CFG.get("recalc_normals", False):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
open_edges = sum(1 for e in bm.edges if e.is_boundary); bm.to_mesh(me); bm.free(); me.update()
log("raw welded: %d faces, %d open edges, scale %.4f" % (len(me.polygons), open_edges, S))

# ---- 1. low-poly: voxel remesh -> smooth (zones protected) -> collapse (zones favoured) ------------------------------------------
lp_me = me.copy(); lp_me.name = CFG["mesh_name"]; lp_me.materials.clear()
lp = bpy.data.objects.new(CFG["mesh_name"], lp_me); bpy.context.scene.collection.objects.link(lp)
bpy.context.view_layer.objects.active = lp
for o in bpy.data.objects: o.select_set(o is lp)
lp_me.remesh_voxel_size = CFG["voxel_m"]; lp_me.remesh_voxel_adaptivity = 0.0
bpy.ops.object.voxel_remesh()
log("voxel remesh %.1f mm: %d quads" % (CFG["voxel_m"] * 1000, len(lp_me.polygons)))

def zone_weights():
    """1 inside a detail zone (box), fading to 0 over `margin` metres outside it."""
    nv = len(lp_me.vertices); V = np.empty(nv * 3); lp_me.vertices.foreach_get("co", V); V = V.reshape(-1, 3)
    z = np.zeros(nv)
    for zone in CFG.get("detail_zones", []):
        lo, hi = np.array(zone["box_min"]), np.array(zone["box_max"])
        d = np.maximum(np.maximum(lo - V, V - hi), 0.0)
        z = np.maximum(z, 1.0 - smoothstep(np.linalg.norm(d, axis=1) / zone["margin"]))
    return z
def assign_group(name, w):
    vg = lp.vertex_groups.new(name=name)
    q = np.round(w * 20).astype(int)
    for level in np.unique(q):
        idx = np.nonzero(q == level)[0].tolist()
        if idx: vg.add(idx, float(level) / 20.0, "REPLACE")
    return vg
zw = zone_weights()
log("detail-zone vertices (weight > 0.5):", int((zw > 0.5).sum()))
vg_smooth = assign_group("smooth_w", 1.0 - zw)
vg_keep = assign_group("keep_w", 0.35 + 0.65 * zw)
md = lp.modifiers.new("cs", "CORRECTIVE_SMOOTH"); md.smooth_type = "LENGTH_WEIGHTED"; md.factor = 0.8; md.iterations = CFG["smooth_iterations"]
md.use_only_smooth = True; md.rest_source = "ORCO"; md.vertex_group = vg_smooth.name
bpy.ops.object.modifier_apply(modifier=md.name)
bm = bmesh.new(); bm.from_mesh(lp_me); bmesh.ops.triangulate(bm, faces=bm.faces); bm.to_mesh(lp_me); bm.free()
md = lp.modifiers.new("dec", "DECIMATE"); md.decimate_type = "COLLAPSE"; md.ratio = CFG["target_tris"] / len(lp_me.polygons); md.vertex_group = vg_keep.name
bpy.ops.object.modifier_apply(modifier=md.name)
lp.vertex_groups.clear()
for p in lp_me.polygons: p.use_smooth = True
log("smoothed %d it, collapsed to %d tris" % (CFG["smooth_iterations"], len(lp_me.polygons)))
if CFG.get("debug_precut"):
    pts = np.empty(len(lp_me.vertices) * 3); lp_me.vertices.foreach_get("co", pts); pts = pts.reshape(-1, 3)
    log("precut bbox", pts.min(0).round(3), pts.max(0).round(3))
    os.makedirs(project_path("temp"), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=project_path("temp/%s_precut.glb" % CFG["car"]), use_selection=True, export_format="GLB")
    if "--precut-only" in argv: sys.exit(0)

# ---- 2. materials, wheel cut --------------------------------------------------------------------------------------------------------
paint = bpy.data.materials.new(CFG["paint_material"]); lp_me.materials.append(paint)
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
bm = bmesh.new(); bm.from_mesh(lp_me)                         # the exact solver misjudges inside/outside on doubled vertices and zero-area faces
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6); bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
vol = bm.calc_volume(signed=True); bmesh.ops.recalc_face_normals(bm, faces=bm.faces)   # an inside-out body turns the difference into an intersection
log("body volume %.3f m3 before orienting, %.3f after" % (vol, bm.calc_volume(signed=True)))
bm.to_mesh(lp_me); bm.free(); lp_me.update()
n_before = len(lp_me.polygons); cut_ok = False
for self_hit in (True, False):                            # the lifted body can intersect itself: only use_self cuts it right; a failed cut deletes most of the body silently, so check
    backup = lp_me.copy()
    bmod = lp.modifiers.new("Cut", "BOOLEAN"); bmod.operation = "DIFFERENCE"; bmod.operand_type = "OBJECT"; bmod.object = cut_ob
    bmod.solver = "EXACT"; bmod.use_self = self_hit; bmod.use_hole_tolerant = True
    bpy.ops.object.modifier_apply(modifier=bmod.name)
    if len(lp_me.polygons) > 0.6 * n_before:
        cut_ok = True; bpy.data.meshes.remove(backup); break
    log("wheel cut broke the body (%d of %d faces, self intersection %s)" % (len(lp_me.polygons), n_before, self_hit))
    lp.data = backup; bpy.data.meshes.remove(lp_me); lp_me = backup; lp_me.name = CFG["mesh_name"]
if not cut_ok: raise RuntimeError("wheel cut failed with both solver settings")
bpy.data.objects.remove(cut_ob); bpy.data.meshes.remove(cut_me)
log("wheel cut:", len(lp_me.polygons), "faces")
if "--stop-after-cut" in argv: sys.exit(0)
bm = bmesh.new(); bm.from_mesh(lp_me)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if any(abs(v.co.x) > 1.10 for v in f.verts)], context="FACES")
bm.to_mesh(lp_me); bm.free(); lp_me.update()

# ---- 3. lip warp: pull each arch lip onto an exact circle of R_LIP, blending into the fender flare -----------------------------------
def read_verts():
    nv = len(lp_me.vertices); V = np.empty(nv * 3); lp_me.vertices.foreach_get("co", V); return V.reshape(-1, 3)
V = read_verts()
lip_report = {}
for k, (sg, yc) in AXLE.items():
    dy, dz = V[:, 1] - yc, V[:, 2] - Z_AXLE
    r = np.hypot(dy, dz); th = np.degrees(np.arctan2(dy, dz)); sx = V[:, 0] * sg
    skin = np.full(361, np.nan); lipr = np.full(361, np.nan)
    near = (sx >= 0.86) & (r < 0.62)
    b = np.clip(np.round(th).astype(int) + 180, 0, 360)
    for i in range(361):
        m = near & (np.abs(b - i) <= 1)
        outer = m & (r > 0.40)
        if outer.sum() < 4: continue
        xs = np.percentile(sx[outer], 90); skin[i] = xs
        ring = m & (sx >= xs - 0.03) & (r >= R_LIP - 0.001)
        if ring.sum() >= 2: lipr[i] = r[ring].min()
    ok = ~np.isnan(lipr)
    if ok.sum() < 20: log("lip: no data for", k); continue
    idx = np.arange(361); lipr_f = np.interp(idx, idx[ok], lipr[ok]); skin_f = np.interp(idx, idx[ok], skin[ok])
    for _ in range(2): lipr_f = np.array([np.median(lipr_f[max(0, i - 3):i + 4]) for i in range(361)])
    lipr_f = np.convolve(np.pad(lipr_f, 4, mode="edge"), np.ones(9) / 9, mode="valid")
    lo, hi = idx[ok].min() - 180, idx[ok].max() - 180
    edge = np.minimum(th - lo, hi - th); fade = np.clip(1.0 + edge / TAPER, 0.0, 1.0)
    d = R_LIP - lipr_f[b]; xs_v = skin_f[b]
    wx = smoothstep((sx - 0.80) / np.maximum(xs_v - 0.03 - 0.80, 0.05))
    wr = np.where(r <= lipr_f[b], 1.0, 1.0 - smoothstep((r - lipr_f[b]) / 0.07))
    move = near & (sx >= 0.80)
    r_new = np.where(move, np.maximum(R_LIP, r + d * fade * wx * wr), r)
    s = np.where(r > 1e-6, r_new / np.maximum(r, 1e-6), 1.0)
    V[:, 1] = np.where(move, yc + dy * s, V[:, 1]); V[:, 2] = np.where(move, Z_AXLE + dz * s, V[:, 2])
    lip_report[k] = "natural lip r %.3f..%.3f m -> %.3f" % (lipr_f[ok].min(), lipr_f[ok].max(), R_LIP)
lp_me.vertices.foreach_set("co", V.ravel()); lp_me.update()
log("lip warp", lip_report)

# ---- 4. crumbs, lip samples, tubs (as in refine_audi_r8.py) ----------------------------------------------------------------------------
bm = bmesh.new(); bm.from_mesh(lp_me)
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
mouth = {k: [] for k in AXLE}
for v in bm.verts:
    for k, (sg, yc) in AXLE.items():
        r = hypot(v.co.y - yc, v.co.z - Z_AXLE)
        if v.co.x * sg >= 0.88 and R_LIP - 0.002 < r < 0.46:
            mouth[k].append((math.degrees(atan2(v.co.y - yc, v.co.z - Z_AXLE)), v.co.x * sg)); break
log("crumb faces", len(crumbs), "lip samples", {k: len(v) for k, v in mouth.items()})
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
    a_lo, a_hi = max(lo - TAPER, -TUB_ARC), min(hi + TAPER, TUB_ARC)
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
log("tubs built; tris", sum(len(p.vertices) - 2 for p in lp_me.polygons))

# ---- 4a. ground clamp: the raw tread (radius 0.37..0.42 about the axle) that survives the arch cut hangs under the road below each wheel,
# because the raw tyre is larger than the 0.33 m game wheel. Drop it, then flatten whatever else dips under GROUND_MIN (underbody, splitter).
# Clamping the tread instead would leave vertices inside the new tyre. The body is never lifted: the arch, the tubs and the axle stay put.
GROUND_MIN = CFG.get("ground_min", 0.05)
bm = bmesh.new(); bm.from_mesh(lp_me); bm.faces.ensure_lookup_table()
def under_wheel(co): return any(co.x * sg > 0.55 and abs(co.y - yc) < 0.35 for sg, yc in AXLE.values())
sliver = [f for f in bm.faces if any(v.co.z < GROUND_MIN and under_wheel(v.co) for v in f.verts)]
bmesh.ops.delete(bm, geom=sliver, context="FACES")
lifted = 0
for v in bm.verts:
    if v.co.z < GROUND_MIN: v.co.z = GROUND_MIN; lifted += 1
bm.to_mesh(lp_me); bm.free(); lp_me.update()
log("ground clamp: %d tread faces under the wheels dropped, %d vertices lifted to z %.3f" % (len(sliver), lifted, GROUND_MIN))

# ---- 4b. toon shading normals: keep the geometry, but shade the paint with the normals of a smoothed copy --------------------------------------
# A cel step flips wherever n.l crosses its threshold, so millimetre ripples on a panel that sits near the threshold become jagged dark patches.
# Smoothed normals (blended back to the real ones on sharp features) give coherent bands; baked after this, the normal map stays consistent.
tn = CFG.get("toon_normals")
if tn:
    iters, feat = tn.get("iterations", 30), tn.get("feature_angle", 35.0)
    bm = bmesh.new(); bm.from_mesh(lp_me); bm.verts.ensure_lookup_table(); bm.normal_update()
    nv = len(bm.verts)
    n_orig = np.array([v.normal[:] for v in bm.verts]); P0 = np.array([v.co[:] for v in bm.verts])
    paint_v = np.array([any(f.material_index == 0 for f in v.link_faces) for v in bm.verts])
    ev = np.array([[e.verts[0].index, e.verts[1].index] for e in bm.edges if paint_v[e.verts[0].index] and paint_v[e.verts[1].index]])
    Ps = P0.copy()
    for _ in range(iters):
        acc = np.zeros_like(Ps); cnt = np.zeros(nv)
        np.add.at(acc, ev[:, 0], Ps[ev[:, 1]]); np.add.at(acc, ev[:, 1], Ps[ev[:, 0]])
        np.add.at(cnt, ev[:, 0], 1); np.add.at(cnt, ev[:, 1], 1)
        has = cnt > 0
        Ps[has] += 0.6 * (acc[has] / cnt[has, None] - Ps[has])
    for v, co in zip(bm.verts, Ps): v.co = co
    bm.normal_update()
    n_smooth = np.array([v.normal[:] for v in bm.verts]); bm.free()
    ang = np.degrees(np.arccos(np.clip((n_orig * n_smooth).sum(1), -1.0, 1.0)))
    w = 1.0 - smoothstep((ang - 0.5 * feat) / (0.5 * feat))
    n_toon = n_smooth * w[:, None] + n_orig * (1.0 - w[:, None])
    n_toon /= np.maximum(np.linalg.norm(n_toon, axis=1, keepdims=True), 1e-9)
    loop_n = []
    for poly in lp_me.polygons:
        for li in poly.loop_indices:
            vi = lp_me.loops[li].vertex_index
            if poly.material_index == 0: loop_n.append(tuple(n_toon[vi]))
            elif poly.use_smooth: loop_n.append(tuple(n_orig[vi]))
            else: loop_n.append(tuple(poly.normal))
    lp_me.normals_split_custom_set(loop_n)
    log("toon normals: %d smoothing iterations, %.1f%% of paint vertices blended, mean change %.1f deg" % (iters, 100.0 * w[paint_v].mean(), ang[paint_v].mean()))

# ---- 5. UV unwrap the paint faces ---------------------------------------------------------------------------------------------------------
lp_me.uv_layers.new(name="UVMap")
bpy.context.view_layer.objects.active = lp
for o in bpy.data.objects: o.select_set(o is lp)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="DESELECT"); lp.active_material_index = 0; bpy.ops.object.material_slot_select()
bpy.ops.uv.smart_project(angle_limit=radians(66), island_margin=0.003, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
bpy.ops.object.mode_set(mode="OBJECT")

# ---- 6. bake base colour, tangent normal, ambient occlusion and roughness from the raw mesh ---------------------------------------------------------------------------------
RES = CFG["texture_px"]
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 4; sc.cycles.use_denoising = False
paint.use_nodes = True
nt = paint.node_tree; nt.nodes.clear()
tex_color = nt.nodes.new("ShaderNodeTexImage"); tex_color.image = bpy.data.images.new("base_color", RES, RES, alpha=False); tex_color.image.colorspace_settings.name = "sRGB"
tex_norm = nt.nodes.new("ShaderNodeTexImage"); tex_norm.image = bpy.data.images.new("normal", RES, RES, alpha=False); tex_norm.image.colorspace_settings.name = "Non-Color"
bsdf_p = nt.nodes.new("ShaderNodeBsdfPrincipled"); out = nt.nodes.new("ShaderNodeOutputMaterial"); nmap = nt.nodes.new("ShaderNodeNormalMap")
nt.links.new(tex_color.outputs["Color"], bsdf_p.inputs["Base Color"]); nt.links.new(tex_norm.outputs["Color"], nmap.inputs["Color"]); nt.links.new(nmap.outputs["Normal"], bsdf_p.inputs["Normal"])
bsdf_p.inputs["Metallic"].default_value = 0.1; bsdf_p.inputs["Roughness"].default_value = 0.45
nt.links.new(bsdf_p.outputs["BSDF"], out.inputs["Surface"])
for o in bpy.data.objects: o.select_set(o is hp)
lp.select_set(True); bpy.context.view_layer.objects.active = lp
common = dict(use_selected_to_active=True, cage_extrusion=0.03, max_ray_distance=0.08, margin=16, margin_type="EXTEND", use_clear=True)
def box_filter_bool(m, r, mode):
    """Binary erosion (mode "min") or dilation (mode "max") with a (2r+1) square window, separable."""
    f = np.minimum if mode == "min" else np.maximum
    out = m.copy()
    for axis in (0, 1):
        acc = out.copy()
        for k in range(1, r + 1):
            acc = f(acc, np.roll(out, k, axis=axis)); acc = f(acc, np.roll(out, -k, axis=axis))
        out = acc
    return out

def clean_albedo(a, cfg):
    """Flatten the dark smudges the AI baked into the paint: low-chroma pixels darker than the paint but lighter than the
    black trim, in blobs wider than the opening size, are pulled back to the paint luminance (hue kept). Logos, red and black stay."""
    rgb = a[..., :3]; mx = rgb.max(2); mn = rgb.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-4); lum = rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    low = sat < 0.12
    h, e = np.histogram(lum[low & (lum > 0.4) & (lum < 0.7)], bins=60, range=(0.4, 0.7))
    paint = float(e[int(h.argmax())] + 0.005)
    lo, hi = cfg.get("band_low", 0.22), paint - cfg.get("band_margin", 0.03)
    blotch = (low & (lum > lo) & (lum < hi)).astype(np.uint8)
    r = cfg.get("open_radius", 3)
    core = box_filter_bool(box_filter_bool(blotch, r, "min"), r + cfg.get("grow", 2), "max").astype(bool)
    m = core & low & (lum > 0.15) & (lum < paint)
    out = a.copy()
    out[..., :3][m] = rgb[m] * (paint / np.maximum(lum[m], 1e-3))[:, None]
    log("texture clean: paint luminance %.3f, %.2f%% of pixels flattened" % (paint, 100.0 * m.mean()))
    return np.clip(out, 0.0, 1.0)

tc = CFG.get("texture_clean")
if tc and tc.get("enabled", True):
    src_img = None
    for nd in hp.data.materials[0].node_tree.nodes:                    # the base colour image, not the roughness or normal one
        if nd.type == "TEX_IMAGE" and nd.image:
            for l in nd.outputs["Color"].links:
                if l.to_node.type == "BSDF_PRINCIPLED" and l.to_socket.name == "Base Color":
                    src_img = nd.image
    assert src_img is not None, "no base colour image on the raw material"
    src_img.colorspace_settings.name = "Non-Color"                     # read the stored sRGB values, not their linearisation
    arr = np.array(src_img.pixels[:], dtype=np.float32).reshape(src_img.size[1], src_img.size[0], 4)
    arr = clean_albedo(arr, tc)
    src_img.pixels.foreach_set(arr.ravel()); src_img.update()
    src_img.colorspace_settings.name = "sRGB"
tex_color.select = True; nt.nodes.active = tex_color
bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, **common); log("colour baked")
tex_norm.select = True; nt.nodes.active = tex_norm
bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", **common); log("normal baked")
for img in (tex_color.image, tex_norm.image):
    img.filepath_raw = os.path.join(TEX_DIR, img.name + ".png"); img.file_format = "PNG"; img.save()

# ambient occlusion (cavities and panel lines, the "emboss") and roughness (the "shine" mask) from the raw mesh, packed like the Porsche ORM
world = bpy.data.worlds.new("bake_world"); sc.world = world; world.light_settings.distance = CFG.get("ao_distance_m", 0.2)
def bake_gray(kind, name, samples):
    img = bpy.data.images.new(name, RES, RES, alpha=False); img.colorspace_settings.name = "Non-Color"
    node = nt.nodes.new("ShaderNodeTexImage"); node.image = img; node.select = True; nt.nodes.active = node
    sc.cycles.samples = samples
    bpy.ops.object.bake(type=kind, **common)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(RES, RES, 4)[..., 0].copy()
    nt.nodes.remove(node); bpy.data.images.remove(img)
    return px
ao_px = bake_gray("AO", "ao_tmp", 24); log("ambient occlusion baked")
rough_px = bake_gray("ROUGHNESS", "rough_tmp", 4); log("roughness baked")
orm_img = bpy.data.images.new("orm", RES, RES, alpha=False); orm_img.colorspace_settings.name = "Non-Color"
orm_px = np.ones((RES, RES, 4), dtype=np.float32); orm_px[..., 0] = ao_px; orm_px[..., 1] = rough_px; orm_px[..., 2] = 0.0
orm_img.pixels.foreach_set(orm_px.ravel()); orm_img.filepath_raw = os.path.join(TEX_DIR, "orm.png"); orm_img.file_format = "PNG"; orm_img.save()
log("orm.png: AO mean %.2f, roughness mean %.2f" % (ao_px.mean(), rough_px.mean()))

# ---- 7. report + export ----------------------------------------------------------------------------------------------------------------------
bm = bmesh.new(); bm.from_mesh(lp_me); bmesh.ops.triangulate(bm, faces=bm.faces)
wb = bm.copy(); bmesh.ops.remove_doubles(wb, verts=wb.verts, dist=1e-5)
ang = np.array([math.degrees(e.calc_face_angle(0.0)) for e in wb.edges if len(e.link_faces) == 2])
pts = np.array([v.co[:] for v in bm.verts])
log("FINAL tris %d | open edges %d | dihedral median %.1f  >30deg %.1f%%  >60deg %.1f%% | bbox %s .. %s" % (
    len(bm.faces), sum(1 for e in wb.edges if e.is_boundary), np.median(ang), (ang > 30).mean() * 100, (ang > 60).mean() * 100, pts.min(0).round(3), pts.max(0).round(3)))
wb.free(); bm.free()
bpy.data.objects.remove(hp)
for o in bpy.data.objects: o.select_set(o is lp)
bpy.context.view_layer.objects.active = lp
bpy.ops.export_scene.gltf(filepath=BODY_GLB, use_selection=True, export_format="GLB", export_apply=False, export_yup=True,
                          export_image_format="JPEG", export_jpeg_quality=90, export_cameras=False, export_lights=False)
log("exported", BODY_GLB, os.path.getsize(BODY_GLB))
