# Rebuild gt3_wheel_master (Porsche 911 GT3 wheel module) inside a live Blender session.
# Axle = +X (outboard face = +X), wheel centre at origin, metres. Run via the Blender addon socket,
# or:  blender --background --python scratch/build_gt3_wheel.py   (set EXPORT_PATH below).
#
# Node tree (names are a contract with scripts/car/wheel_controller.gd and scenes/car/parts/*.tscn):
#   GT3_Wheel_Assembly
#     GT3_BrakeCaliper            static
#     WheelRotating               spins on X
#       GT3_AlloyRim / GT3_BrakeDisc / GT3_CenterNut / GT3_SidewallStripe / GT3_TireRubber
import bpy, bmesh, math, bisect
from math import pi, sin, cos, asin, sqrt, radians
from mathutils import Vector, Matrix

TAU = 2 * pi
EXPORT_PATH = r"D:\Occupation\Porto\genex\La_Voiture\assets\cars\parts\gt3_wheel_master.glb"
DO_EXPORT = globals().get("DO_EXPORT", False)
TAG = "gt3_refine"

# ----------------------------------------------------------------------------------------------
# dimensions (m)
R_TIRE, W_TIRE = 0.33, 0.28
R_DISC, T_DISC = 0.185, 0.024

# ----------------------------------------------------------------------------------------------
def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c) + (1.0,)

def material(name, color, metal, rough, emit=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    n = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    n.inputs["Base Color"].default_value = color
    n.inputs["Metallic"].default_value = metal
    n.inputs["Roughness"].default_value = rough
    m.diffuse_color = color
    if emit:
        n.inputs["Emission Color"].default_value = emit
        n.inputs["Emission Strength"].default_value = 0.6
    return m

MATS = {
    "rim": material("Mat_RimAlloy", (0.10, 0.108, 0.125, 1), 0.9, 0.25),   # spec #1E2024 reads black against the dark showroom; lifted so spokes stay legible
    "tire": material("Mat_TireRubber", (0.045, 0.045, 0.05, 1), 0.0, 0.92),
    "letter": material("Mat_TireLetter", (0.62, 0.62, 0.6, 1), 0.0, 0.7),
    "stripe": material("Mat_TireStripe", srgb("#FF1E56"), 0.0, 0.5),
    "disc": material("Mat_BrakeDisc", (0.19, 0.19, 0.2, 1), 0.55, 0.38),
    "hat": material("Mat_DiscHat", srgb("#B8935A"), 0.9, 0.32),
    "nut": material("Mat_CenterNut", srgb("#E61C38"), 0.85, 0.2),
    "steel": material("Mat_Steel", srgb("#9A9CA0"), 1.0, 0.35),
    "caliper": material("Mat_BrakeCaliper", srgb("#FFC200"), 0.1, 0.3),
}

# ----------------------------------------------------------------------------------------------
# scene bookkeeping: park the previous (primitive) wheel objects instead of deleting them
for o in list(bpy.data.objects):
    if o.get(TAG):
        me = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if me and me.users == 0 and hasattr(me, "vertices"):
            bpy.data.meshes.remove(me)
for n in ("GT3_Wheel_Assembly", "WheelRotating", "GT3_AlloyRim", "GT3_BrakeDisc", "GT3_CenterNut",
          "GT3_SidewallStripe", "GT3_TireRubber", "GT3_BrakeCaliper"):
    o = bpy.data.objects.get(n)
    if o and not o.get(TAG):
        o.name = "OLD_" + n
        o.hide_viewport = True
        o.hide_render = True

# ----------------------------------------------------------------------------------------------
# geometry helpers
def revolve(bm, profile, segs=96, closed=True):
    """profile = [(x, r)] in the XZ plane, spun about the X axis."""
    vs = [bm.verts.new((x, 0.0, r)) for x, r in profile]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    if closed:
        es.append(bm.edges.new((vs[-1], vs[0])))
    bmesh.ops.spin(bm, geom=vs + es, cent=(0, 0, 0), axis=(1, 0, 0), angle=TAU, steps=segs)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)

def prism(bm, polys, x0, x1, mat_index=0):
    """Extrude 2D polygons given as (y, z) lists along X from x0 to x1."""
    for poly in polys:
        f = bm.faces.new([bm.verts.new((x0, y, z)) for y, z in poly])
        r = bmesh.ops.extrude_face_region(bm, geom=[f])
        vs = [g for g in r["geom"] if isinstance(g, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, vec=(x1 - x0, 0, 0), verts=vs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)      # polygons arrive with mixed winding; exact boolean needs outward normals
    for f in bm.faces:
        f.material_index = mat_index

def cyl_x(bm, x0, x1, r0, r1=None, segs=32, cy=0.0, cz=0.0, cap=True):
    m = Matrix.Translation(((x0 + x1) / 2, cy, cz)) @ Matrix.Rotation(pi / 2, 4, "Y")
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=segs, radius1=r0,
                          radius2=r0 if r1 is None else r1, depth=x1 - x0, matrix=m)

def finish(bm, deg=35):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    th = radians(deg)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > th:
            e.smooth = False

def make_obj(name, bm, mats, parent=None, deg=35):
    finish(bm, deg)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    o = bpy.data.objects.new(name, me)
    o[TAG] = True
    bpy.context.scene.collection.objects.link(o)
    o.parent = parent
    return o

def boolean_diff(bm_target, bm_cutter):
    """Exact-solver difference of two bmeshes via depsgraph evaluation. Returns a new bmesh."""
    def tmp(bm, n):
        me = bpy.data.meshes.new(n)
        bm.to_mesh(me)
        ob = bpy.data.objects.new(n, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob
    ot, oc = tmp(bm_target, "_t"), tmp(bm_cutter, "_c")
    md = ot.modifiers.new("b", "BOOLEAN")
    md.operation, md.object, md.solver = "DIFFERENCE", oc, "EXACT"
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ot.evaluated_get(dg))
    out = bmesh.new()
    out.from_mesh(me)
    for ob in (ot, oc):
        m = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.meshes.remove(m)
    bpy.data.meshes.remove(me)
    return out

def catmull(points, n=5):
    P = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(n):
            t = k / n
            out.append(tuple(0.5 * (2 * p1[j] + (-p0[j] + p2[j]) * t
                                    + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t ** 3) for j in range(2)))
    out.append(tuple(points[-1]))
    return out

def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)

def table(tb, r):
    """Cosine-smoothed interpolation through [(r, value)] rows."""
    if r <= tb[0][0]:
        return tb[0][1]
    for (r0, v0), (r1, v1) in zip(tb, tb[1:]):
        if r <= r1:
            return v0 + (v1 - v0) * smoothstep((r - r0) / (r1 - r0))
    return tb[-1][1]

def polar(r, th):
    return (r * sin(th), r * cos(th))      # (y, z); th = 0 at top, grows toward +Y (rear)

# ----------------------------------------------------------------------------------------------
# hierarchy
asm = bpy.data.objects.new("GT3_Wheel_Assembly", None)
asm.empty_display_type = "PLAIN_AXES"
asm[TAG] = True
bpy.context.scene.collection.objects.link(asm)
spin = bpy.data.objects.new("WheelRotating", None)
spin.empty_display_type = "PLAIN_AXES"
spin[TAG] = True
bpy.context.scene.collection.objects.link(spin)
spin.parent = asm

# ----------------------------------------------------------------------------------------------
# TIRE  (outer sidewall = +X). Cross-section is built crown -> bead, mirrored for the inboard side.
GROOVE_R0, GROOVE_R1, GROOVE_D = 0.262, 0.278, 0.0035     # stripe groove on the outer sidewall, centred on r = 0.27
SIDE_CTRL = [(0.095, 0.327), (0.110, 0.3210), (0.124, 0.3120), (0.134, 0.3010), (0.139, 0.2900),
             (0.140, 0.2800), (0.137, 0.2700), (0.132, 0.2610), (0.125, 0.2540), (0.118, 0.2490),
             (0.111, 0.2450), (0.108, 0.2400)]
side = catmull(SIDE_CTRL, 3)                                  # crown -> bead, r descending
_sr = [p[1] for p in reversed(side)]
_sx = [p[0] for p in reversed(side)]

def xs(r):
    """Sidewall surface x at radius r (outboard)."""
    i = max(1, min(len(_sr) - 1, bisect.bisect_left(_sr, r)))
    t = (r - _sr[i - 1]) / (_sr[i] - _sr[i - 1])
    return _sx[i - 1] + (_sx[i] - _sx[i - 1]) * t

def crown_half():
    pts, R = [], R_TIRE
    rc = lambda x: R - 0.0006 * (x / 0.095) ** 2
    pts.append((0.0, R))
    for g in (0.032, 0.070):                                   # circumferential tread grooves
        w, d = 0.0035, 0.0035
        pts += [(g - w, rc(g - w)), (g - w, rc(g - w) - d), (g + w, rc(g + w) - d), (g + w, rc(g + w))]
    pts.append((0.095, rc(0.095)))
    return pts

def outer_profile(groove):
    pts = []
    for x, r in side[1:]:
        pts.append((x, r))
    if not groove:
        return pts
    res = [p for p in pts if p[1] > GROOVE_R1]
    res += [(xs(GROOVE_R1), GROOVE_R1), (xs(GROOVE_R1) - GROOVE_D, GROOVE_R1)]
    for r in (0.2755, 0.2725, 0.2695, 0.2665, 0.2635):
        res.append((xs(r) - GROOVE_D, r))
    res += [(xs(GROOVE_R0) - GROOVE_D, GROOVE_R0), (xs(GROOVE_R0), GROOVE_R0)]
    res += [p for p in pts if p[1] < GROOVE_R0]
    return res

right = crown_half() + outer_profile(True)
left = crown_half()[1:] + outer_profile(False)
liner = [(0.108, 0.2275)]
loop = right + liner + [(-0.108, 0.2275)] + [(-x, r) for x, r in reversed(left)]

bm = bmesh.new()
revolve(bm, loop, 80)
# embossed lettering on the outer sidewall, mapped onto the sidewall surface
def arc_text(bm, text, phi_deg, r_base, height, emboss=0.0016, mat_index=1):
    cu = bpy.data.curves.new("_t", "FONT")
    cu.body, cu.size, cu.align_x, cu.extrude = text, height, "CENTER", 0.0005
    cu.resolution_u = 4
    ob = bpy.data.objects.new("_t", cu)
    bpy.context.scene.collection.objects.link(ob)
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.curves.remove(cu)
    phi_c = radians(phi_deg)
    tb = bmesh.new()
    tb.from_mesh(me)
    bpy.data.meshes.remove(me)
    for v in tb.verts:
        u, w, e = v.co
        r = r_base + w
        a = phi_c + u / r_base
        top = e > 0
        v.co = Vector((xs(r) + (emboss if top else -0.0006), r * sin(a), r * cos(a)))
    for f in tb.faces:
        f.material_index = mat_index
    bm_mesh = bpy.data.meshes.new("_tm")
    tb.to_mesh(bm_mesh)
    tb.free()
    bm.from_mesh(bm_mesh)
    bpy.data.meshes.remove(bm_mesh)

bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
for f in bm.faces:
    f.material_index = 0
arc_text(bm, "GT3 RACING", 62, 0.2865, 0.016)
arc_text(bm, "GT3 RACING", 242, 0.2865, 0.016)
tire = make_obj("GT3_TireRubber", bm, [MATS["tire"], MATS["letter"]], spin, deg=40)

# ----------------------------------------------------------------------------------------------
# SIDEWALL STRIPE : thin ring sitting in the groove (surface 0 is overridden per compound in Godot)
bm = bmesh.new()
top = [(xs(r) - 0.0008, r) for r in [GROOVE_R0 + 0.0008 + i * (GROOVE_R1 - GROOVE_R0 - 0.0016) / 6 for i in range(7)]]
bot = [(xs(r) - GROOVE_D + 0.0003, r) for r, _ in [(p[1], 0) for p in top]]
revolve(bm, top + list(reversed(bot)), 80)
stripe = make_obj("GT3_SidewallStripe", bm, [MATS["stripe"]], spin, deg=60)

# ----------------------------------------------------------------------------------------------
# ALLOY RIM : barrel + concave 5 Y-split dish + hub boss
bm = bmesh.new()
barrel_o = [(0.122, 0.2425), (0.1165, 0.2430), (0.112, 0.2380), (0.105, 0.2300), (0.095, 0.2290),
            (0.085, 0.2270), (0.075, 0.2200), (0.060, 0.2120), (0.0, 0.2100), (-0.060, 0.2120),
            (-0.075, 0.2200), (-0.085, 0.2270), (-0.095, 0.2290), (-0.105, 0.2300), (-0.112, 0.2380),
            (-0.1165, 0.2430), (-0.122, 0.2425)]
barrel_i = [(x, r - 0.004) for x, r in reversed(barrel_o)]
revolve(bm, barrel_o + barrel_i, 72)
barrel = bm

HUB_R, CUT_R, SPLIT_R, N_SP = 0.082, 0.2125, 0.122, 5
R_DISH_OUT = 0.2290

def x_face(r):
    t = max(0.0, (r - HUB_R) / (0.2275 - HUB_R))
    return 0.052 + (0.112 - 0.052) * t ** 1.9

def th_face(r):
    return 0.018 - 0.006 * max(0.0, (r - HUB_R) / (0.2275 - HUB_R))

rs = [0.040 + (R_DISH_OUT - 0.040) * (i / 15) ** 0.85 for i in range(16)]
dish_top = [(x_face(r) + th_face(r) / 2, r) for r in rs]
dish_bot = [(x_face(r) - th_face(r) / 2, r) for r in reversed(rs)]
dish = bmesh.new()
revolve(dish, dish_top + dish_bot, 72)

HW = [(HUB_R, 0.037), (0.13, 0.031), (0.17, 0.037), (CUT_R, 0.055)]     # spoke outer half-width
SLOT = [(SPLIT_R, 0.0), (0.130, 0.0035), (0.165, 0.0105), (0.198, 0.0185)]  # Y notch half-width
cut = bmesh.new()
polys = []
for k in range(N_SP):
    t0, t1 = k * TAU / N_SP, (k + 1) * TAU / N_SP
    A, B = [], []
    rr = [HUB_R + (CUT_R - HUB_R) * i / 24 for i in range(25)]
    for r in rr:
        phi = asin(min(0.99, table(HW, r) / r))
        A.append(polar(r, t0 + phi))
        B.append(polar(r, t1 - phi))
    pw = list(A)
    po, pi_ = asin(table(HW, CUT_R) / CUT_R), asin(table(HW, HUB_R) / HUB_R)
    pw += [polar(CUT_R, t0 + po + (t1 - t0 - 2 * po) * j / 10) for j in range(1, 10)]
    pw += list(reversed(B))
    pw += [polar(HUB_R, t1 - pi_ - (t1 - t0 - 2 * pi_) * j / 6) for j in range(1, 6)]
    polys.append(pw)
    # Y-split notch down the spoke centre line (spoke k sits at angle t0 + half pitch? no: at t0)
    a = Vector((sin(t0), cos(t0)))
    p = Vector((cos(t0), -sin(t0)))
    ends = 0.198
    L = [(a * r + p * table(SLOT, r)) for r in [SPLIT_R + (ends - SPLIT_R) * i / 14 for i in range(15)]]
    Rr = [(a * r - p * table(SLOT, r)) for r in [SPLIT_R + (ends - SPLIT_R) * i / 14 for i in range(15)]]
    cap = [a * (ends + 0.0185 * sin(q)) + p * 0.0185 * cos(q) for q in [pi / 2 * j / 6 for j in range(1, 7)]]
    cap += [a * (ends + 0.0185 * sin(q)) - p * 0.0185 * cos(q) for q in [pi / 2 * (6 - j) / 6 for j in range(1, 6)]]
    notch = [(v.x, v.y) for v in L + cap + list(reversed(Rr))[:-1]]   # L[0] and Rr[0] are the same tip point
    polys.append(notch)
    # weight-relief stadium on the spoke root
    st = []
    for q in [pi * j / 8 for j in range(9)]:
        st.append(a * (0.0975 + 0.0045 * sin(q) * 1.0 + 0.0075) + p * 0.0045 * cos(q))
    for q in [pi * j / 8 for j in range(9)]:
        st.append(a * (0.0975 - 0.0075 - 0.0045 * sin(q)) - p * 0.0045 * cos(q))
    polys.append([(v.x, v.y) for v in st])
prism(cut, polys, 0.0, 0.2)
print("dish pre-cut", len(dish.verts), "cutter", len(cut.verts), len(cut.faces))
dish = boolean_diff(dish, cut)
print("dish post-cut", len(dish.verts))
cut.free()

boss = bmesh.new()
revolve(boss, [(0.050, 0.041), (0.071, 0.041), (0.071, 0.074), (0.068, 0.079), (0.058, 0.0805), (0.050, 0.0805)], 64)

# spoke-edge bevel is applied on the evaluated result via a modifier pass
def bevelled(bm_in, width, deg):
    me = bpy.data.meshes.new("_b")
    bm_in.to_mesh(me)
    ob = bpy.data.objects.new("_b", me)
    bpy.context.scene.collection.objects.link(ob)
    md = ob.modifiers.new("v", "BEVEL")
    md.width, md.segments, md.limit_method, md.angle_limit = width, 1, "ANGLE", radians(deg)
    md.harden_normals = False
    dg = bpy.context.evaluated_depsgraph_get()
    me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    out = bmesh.new()
    out.from_mesh(me2)
    bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.meshes.remove(me)
    bpy.data.meshes.remove(me2)
    return out

dish = bevelled(dish, 0.0012, 50)
rim_bm = bmesh.new()
for part in (barrel, dish, boss):
    me = bpy.data.meshes.new("_p")
    part.to_mesh(me)
    part.free()
    rim_bm.from_mesh(me)
    bpy.data.meshes.remove(me)
rim = make_obj("GT3_AlloyRim", rim_bm, [MATS["rim"]], spin, deg=40)

# ----------------------------------------------------------------------------------------------
# BRAKE DISC : drilled friction rings + curved vanes + aluminium hat
bm = bmesh.new()
for sgn in (1, -1):
    x0, x1 = sorted((sgn * 0.0055, sgn * 0.012))
    revolve(bm, [(x0, 0.105), (x1, 0.105), (x1, R_DISC - 0.001), (x1, R_DISC), (x0, R_DISC)], 80)
for f in bm.faces:
    f.material_index = 0
drill = bmesh.new()
for row, (rr_, n_, off) in enumerate(((0.130, 36, 0.0), (0.158, 36, 0.5))):
    for i in range(n_):
        a_ = (i + off) * TAU / n_
        y, z = polar(rr_, a_)
        cyl_x(drill, -0.03, 0.03, 0.0036, segs=8, cy=y, cz=z)
bm = boolean_diff(bm, drill)
drill.free()
for f in bm.faces:
    f.material_index = 0
vanes = bmesh.new()
vp = []
for i in range(36):
    t0 = i * TAU / 36
    inner = [polar(0.106 + 0.078 * j / 5, t0 + 0.55 * (j / 5)) for j in range(6)]
    outer = [polar(0.106 + 0.078 * j / 5, t0 + 0.55 * (j / 5) + 0.07) for j in range(6)]
    vp.append(inner + list(reversed(outer)))
prism(vanes, vp, -0.0065, 0.0065)
vm = bpy.data.meshes.new("_v")
vanes.to_mesh(vm)
vanes.free()
bm.from_mesh(vm)
bpy.data.meshes.remove(vm)
hat = bmesh.new()
revolve(hat, [(0.034, 0.046), (0.0405, 0.046), (0.0405, 0.104), (0.008, 0.104), (0.008, 0.099), (0.034, 0.099)], 72)
for f in hat.faces:
    f.material_index = 1
hm = bpy.data.meshes.new("_h")
hat.to_mesh(hm)
hat.free()
bm.from_mesh(hm)
bpy.data.meshes.remove(hm)
disc = make_obj("GT3_BrakeDisc", bm, [MATS["disc"], MATS["hat"]], spin, deg=40)

# ----------------------------------------------------------------------------------------------
# CENTER-LOCK NUT : red anodised hex with seat collar, cap and retention clip
bm = bmesh.new()
cyl_x(bm, 0.057, 0.070, 0.049, segs=48)
cyl_x(bm, 0.070, 0.094, 0.0405, segs=6)
for f in bm.faces:
    f.material_index = 0
bmesh.ops.bevel(bm, geom=[e for e in bm.edges], offset=0.0016, segments=2, affect="EDGES")
cap = bmesh.new()
revolve(cap, [(0.094, 0.008), (0.094, 0.027), (0.098, 0.027), (0.1005, 0.024), (0.1005, 0.014),
              (0.0965, 0.012), (0.0965, 0.008)], 40)
cm = bpy.data.meshes.new("_c")
cap.to_mesh(cm)
cap.free()
bm.from_mesh(cm)
bpy.data.meshes.remove(cm)
for f in bm.faces:
    f.material_index = 0
clip = bmesh.new()
prism(clip, [[(-0.006, 0.0405), (0.006, 0.0405), (0.006, 0.047), (-0.006, 0.047)]], 0.0705, 0.0745, 1)
prism(clip, [[(-0.002, 0.040), (0.002, 0.040), (0.002, 0.052), (-0.002, 0.052)]], 0.0705, 0.0925, 1)
clm = bpy.data.meshes.new("_cl")
clip.to_mesh(clm)
clip.free()
bm.from_mesh(clm)
bpy.data.meshes.remove(clm)
nut = make_obj("GT3_CenterNut", bm, [MATS["nut"], MATS["steel"]], spin, deg=40)

# ----------------------------------------------------------------------------------------------
# CALIPER : static 6-piston monobloc, mounted trailing at ~15 deg above the axle line
CAL_PHI, CAL_SPAN = 105.0, 66.0                 # centre angle from top (toward +Y = rear), arc length
bm = bmesh.new()
sect = [(-0.046, 0.128), (-0.016, 0.128), (-0.016, 0.190), (0.016, 0.190), (0.016, 0.128),
        (0.046, 0.128), (0.046, 0.205), (-0.046, 0.205)]
vs = [bm.verts.new((x, 0.0, r)) for x, r in sect]
fc = bm.faces.new(vs)
bmesh.ops.spin(bm, geom=[fc] + vs + list(fc.edges), cent=(0, 0, 0), axis=(1, 0, 0),
               angle=-radians(CAL_SPAN), steps=16)           # negative = toward +Y (rear)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(-radians(CAL_PHI - CAL_SPAN / 2), 3, "X"), verts=bm.verts)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm = bevelled(bm, 0.0025, 40)
# piston bores on the outboard face + bleed screws
pock = bmesh.new()
mid = radians(CAL_PHI)
bores = []
for off, rad in ((-20, 0.0100), (0, 0.0118), (20, 0.0100)):
    a_ = mid + radians(off)
    y, z = polar(0.1665, a_)
    bores.append((y, z, rad))
    cyl_x(pock, 0.040, 0.06, rad, segs=24, cy=y, cz=z)
bm = boolean_diff(bm, pock)
pock.free()
for f in bm.faces:
    f.material_index = 0
pist = bmesh.new()
for y, z, rad in bores:
    cyl_x(pist, 0.0405, 0.0445, rad - 0.0012, segs=24, cy=y, cz=z)
y, z = polar(0.2085, mid - radians(8))
cyl_x(pist, -0.012, 0.012, 0.0035, segs=12, cy=y, cz=z)
for f in pist.faces:
    f.material_index = 1
pm = bpy.data.meshes.new("_p")
pist.to_mesh(pm)
pist.free()
bm.from_mesh(pm)
bpy.data.meshes.remove(pm)
caliper = make_obj("GT3_BrakeCaliper", bm, [MATS["caliper"], MATS["steel"]], asm, deg=40)

# ----------------------------------------------------------------------------------------------
# report
for o in (caliper, rim, disc, nut, stripe, tire):
    me = o.data
    print(f"{o.name:20s} v={len(me.vertices):6d} tris~{sum(len(p.vertices) - 2 for p in me.polygons):6d} "
          f"dims={tuple(round(d, 3) for d in o.dimensions)}")

if DO_EXPORT:
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.get(TAG):
            o.select_set(True)
    bpy.context.view_layer.objects.active = asm
    bpy.ops.export_scene.gltf(filepath=EXPORT_PATH, use_selection=True, export_format="GLB", export_apply=True,
                              export_yup=True, export_cameras=False, export_lights=False,
                              export_image_format="NONE", export_animations=False)
    print("exported", EXPORT_PATH)
