# Porsche 911 GT3 body polish: strip the Tripo baked-in tires, trim the 4 wheel-arch lips to clean circles,
# and build curved inner fender tubs (FenderLinerMat, slot 1).
#   blender --background --python scratch/refine_body.py -- <in.glb> <out.glb> [render_dir]
# Coordinates below are Blender space (X right, Y = -Godot Z, Z up); the glTF exporter converts back.
import bpy, bmesh, math, os, sys
import numpy as np
from math import pi, sin, cos, atan2, hypot
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC, DST = argv[0], argv[1]
RENDER_DIR = argv[2] if len(argv) > 2 else None

# ---- design values (m) -----------------------------------------------------------------------------
LIP_X = 1.004          # flat fender-lip band sits at |x| ~ 1.00-1.01
R_LIP = 0.372          # arch opening radius (spec ~0.36 + paint-edge)
R_TUB = 0.372          # tub wall radius = opening radius -> seamless tunnel
X_IN = 0.64            # inboard closing wall of the tub
ZC = 0.35              # arch centre height
ARC = 150.0            # tub covers this many degrees either side of straight up
Z_FLOOR = 0.10         # tub never reaches below the body underside (lowest legit body panel ~0.09)
GUESS = {"FL": (-1, -1.19), "FR": (1, -1.20), "RL": (-1, 1.261), "RR": (1, 1.261)}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
me = ob.data
print("loaded", ob.name, len(me.vertices), "verts", len(me.polygons), "faces", [m.name for m in me.materials])
liner_mat = next((m for m in me.materials if m.name == "FenderLinerMat"), None)
if liner_mat is None:
    liner_mat = bpy.data.materials.new("FenderLinerMat"); me.materials.append(liner_mat)
liner_mat.use_nodes = True
n = next(n for n in liner_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
n.inputs["Base Color"].default_value = (0.0030, 0.0030, 0.0030, 1)     # sRGB #0A0A0A
n.inputs["Roughness"].default_value = 0.95
n.inputs["Metallic"].default_value = 0.0
LINER_IDX = list(me.materials).index(liner_mat)

# ---- circle fit of the baked tread (gives each arch's true axle) -------------------------------------
P = np.array([v.co[:] for v in me.vertices])
def fit(pts):
    A = np.c_[2 * pts[:, 0], 2 * pts[:, 1], np.ones(len(pts))]; b = (pts ** 2).sum(1)
    c = np.linalg.lstsq(A, b, rcond=None)[0]; return c[0], c[1], math.sqrt(c[2] + c[0] ** 2 + c[1] ** 2)
axle = {}
for k, (sg, yg) in GUESS.items():
    zc = ZC
    for _ in range(4):
        r = np.hypot(P[:, 1] - yg, P[:, 2] - zc)
        sel = P[(P[:, 0] * sg > 0.80) & (P[:, 0] * sg < 1.0) & (r > 0.345) & (r < 0.362)]
        yg, zc, rr = fit(sel[:, 1:3])
    axle[k] = (sg, yg, zc, rr)
    print(k, "baked tread axle y=%.3f z=%.3f r=%.4f" % (yg, zc, rr))

bm = bmesh.new(); bm.from_mesh(me)
uv = bm.loops.layers.uv.active

# ---- 1. delete old plugs + baked tire / well clutter ---------------------------------------------------
def rad(v, a): return hypot(v.y - a[1], v.z - a[2])
dele = []
for f in bm.faces:
    if f.material_index == LINER_IDX:
        dele.append(f); continue
    c = f.calc_center_median()
    for k, (sg, yc, zc, rr) in axle.items():
        xa = c.x * sg
        if xa < X_IN - 0.04:
            continue
        r = hypot(c.y - yc, c.z - zc)
        lo = (yc, zc)
        if xa < LIP_X - 0.012 and r < 0.405:                              # tire + ragged well wall
            dele.append(f); break
        if xa > LIP_X + 0.014 and r < 0.60:                               # nothing legitimate lies outboard of the lip: only baked tire
            dele.append(f); break
        if xa >= LIP_X - 0.012 and r < R_LIP + 0.002:                     # inner part of the flat lip band
            dele.append(f); break
print("deleting faces", len(dele))
bmesh.ops.delete(bm, geom=list(set(dele)), context="FACES")

# floating crumbs left over by the cut (position-keyed union-find, so UV-seam duplicates stay connected)
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
sizes = {}
for f in bm.faces:
    sizes[find(f.index)] = sizes.get(find(f.index), 0) + 1
crumbs = [f for f in bm.faces if sizes[find(f.index)] < 60]
print("removing crumb faces", len(crumbs))
bmesh.ops.delete(bm, geom=crumbs, context="FACES")

# ---- 2. snap the ragged lip boundary onto an exact circle ----------------------------------------------
# connectivity must ignore UV seams, so find boundary edges on a welded copy and map back by position
wb = bm.copy()
bmesh.ops.remove_doubles(wb, verts=wb.verts, dist=1e-5)
bnd = set()
for e in wb.edges:
    if e.is_boundary:
        for v in e.verts:
            bnd.add((round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4)))
wb.free()
snapped = 0
for v in bm.verts:
    key = (round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4))
    if key not in bnd:
        continue
    for k, (sg, yc, zc, rr) in axle.items():
        if v.co.x * sg >= LIP_X - 0.03 and 0.34 < hypot(v.co.y - yc, v.co.z - zc) < 0.42:
            d = Vector((v.co.y - yc, v.co.z - zc)); d.normalize()
            v.co.y, v.co.z = yc + d.x * R_LIP, zc + d.y * R_LIP
            snapped += 1
            break
print("snapped lip boundary verts", snapped)

# ---- 3. inner tubs ---------------------------------------------------------------------------------------
def tub(sg, yc, zc):
    """Half-pipe wall (radius R_TUB) over the arch + closing inner wall, as one shell facing the wheel."""
    segs = 48
    a0, a1 = -radians(ARC), radians(ARC)
    xs = [LIP_X - 0.002, 0.93, 0.86, 0.80, 0.74, 0.69, X_IN]
    ring = []
    for xi, x in enumerate(xs):
        row = []
        # slight roll-over at the mouth: the first ring is the lip circle itself
        for j in range(segs + 1):
            a = a0 + (a1 - a0) * j / segs
            row.append(bm.verts.new((x * sg, yc + R_TUB * sin(a), max(Z_FLOOR, zc + R_TUB * cos(a)))))
        ring.append(row)
    new_faces = []
    for xi in range(len(xs) - 1):
        for j in range(segs):
            vs = [ring[xi][j], ring[xi][j + 1], ring[xi + 1][j + 1], ring[xi + 1][j]]
            new_faces.append(bm.faces.new(vs if sg > 0 else vs[::-1]))
    # inboard wall: fan to a centre vertex on the closing plane
    cen = bm.verts.new((X_IN * sg, yc, zc))
    for j in range(segs):
        vs = [ring[-1][j + 1], ring[-1][j], cen]
        new_faces.append(bm.faces.new(vs if sg > 0 else vs[::-1]))
    # the fan only spans the arc; close the wedge under the arch ends so the inboard wall has no hole
    vs = [ring[-1][segs], ring[-1][0], cen]
    new_faces.append(bm.faces.new(vs if sg > 0 else vs[::-1]))
    for f in new_faces:
        f.material_index = LINER_IDX
    return new_faces

from math import radians
for k, (sg, yc, zc, rr) in axle.items():
    tub(sg, yc, zc)

bm.normal_update()
bm.to_mesh(me); bm.free()
me.update()

# winding: make the tub normals face the wheel (toward the axle) -- check on a sample face per corner
bm = bmesh.new(); bm.from_mesh(me)
flipped = 0
for f in bm.faces:
    if f.material_index != LINER_IDX:
        continue
    c = f.calc_center_median()
    for k, (sg, yc, zc, rr) in axle.items():
        if c.x * sg > X_IN - 0.01 and hypot(c.y - yc, c.z - zc) < R_TUB + 0.01 and c.x * sg < LIP_X + 0.01:
            toward_axle = Vector((0, yc - c.y, zc - c.z))
            ax_dir = Vector((sg, 0, 0))          # inboard wall faces outboard, toward the wheel
            ref = toward_axle if abs(f.normal.x) < 0.5 else ax_dir
            if f.normal.dot(ref) < 0:
                f.normal_flip(); flipped += 1
            break
print("flipped tub faces", flipped)
bm.to_mesh(me); bm.free()
me.update()

# smooth the half-pipe wall, keep the inboard fan wall flat (smooth normals at the fan centre read as a cone)
for p in me.polygons:
    if p.material_index == LINER_IDX:
        p.use_smooth = abs(p.normal.x) < 0.5

# ---- export ------------------------------------------------------------------------------------------------
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.export_scene.gltf(filepath=DST, use_selection=True, export_format="GLB", export_apply=False,
                          export_yup=True, export_image_format="AUTO", export_cameras=False, export_lights=False)
print("exported", DST)

# ---- optional previews ---------------------------------------------------------------------------------
if RENDER_DIR:
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = sc.render.resolution_y = 800
    for m in me.materials:
        m.use_backface_culling = True
    cd = bpy.data.cameras.new("c"); cd.lens = 45
    cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
    def shot(name, loc, tgt):
        cam.location = loc; cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(RENDER_DIR, name + ".png"); bpy.ops.render.render(write_still=True)
    shot("rb_RR_out", (2.9, 2.6, 0.55), (0.9, 1.26, 0.35))
    shot("rb_RR_side", (3.2, 1.26, 0.45), (0.9, 1.26, 0.40))
    shot("rb_FR_out", (2.9, -2.6, 0.55), (0.9, -1.2, 0.35))
    shot("rb_FL_out", (-2.9, -2.6, 0.55), (-0.9, -1.19, 0.35))
    shot("rb_RL_low", (-2.4, 2.0, 0.15), (-0.9, 1.26, 0.35))
    shot("rb_full", (4.5, -3.5, 1.4), (0.0, 0.0, 0.5))
