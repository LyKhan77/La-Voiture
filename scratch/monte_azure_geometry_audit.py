# Independent check of the Monte Azure blueprint against the production builder pattern (BrianzaCircuitBuilder._walk_plan):
#   python -I scratch/monte_azure_geometry_audit.py [path/to/blueprint.track.json]
# Prints plan_scale, world radii, clamped fillets, grade, road-to-road separation, pit/landmark placement and the strip
# bands that swallow another road leg. Read-only; needs no Godot.
import json, math, sys

BP = sys.argv[1] if len(sys.argv) > 1 else r"D:\Occupation\Porto\genex\mapgen-circuit\designs\monte_azure\final\blueprint.track.json"
bp = json.load(open(BP, encoding="utf-8"))
V = [tuple(v) for v in bp["alignment"]["vertices"]]
R = bp["alignment"]["radii"]
TARGET = bp["alignment"]["length_target_m"]
ROAD = bp["road"]["width_m"]
START = tuple(bp["alignment"]["start"])
names = ["S/F"] + [t["name"] for t in bp["turns"]]


def sub(a, b): return (a[0]-b[0], a[1]-b[1])
def norm(a):
    l = math.hypot(*a); return (a[0]/l, a[1]/l)
def dist(a, b): return math.hypot(a[0]-b[0], a[1]-b[1])

# --- replicate BrianzaCircuitBuilder._walk_plan (the production pattern) ---
pts = []   # (x, z, s)
dist_acc = 0.0
prev_exit = START
prev = START
n = len(V)
info = []
def straight(a, b, s0):
    L = dist(a, b)
    steps = max(1, math.ceil(L/6.0))
    first = 0 if not pts else 1
    for k in range(first, steps+1):
        t = k/steps
        pts.append((a[0]+(b[0]-a[0])*t, a[1]+(b[1]-a[1])*t, s0+L*t))
for i in range(n):
    v = V[i]; nx = V[(i+1) % n]
    ind = norm(sub(v, prev)); outd = norm(sub(nx, v))
    inl = dist(v, prev); outl = dist(nx, v)
    cross = ind[0]*outd[1]-ind[1]*outd[0]; dot = ind[0]*outd[0]+ind[1]*outd[1]
    ang = math.atan2(cross, dot)
    r_req = R[i]; r = r_req
    th = math.tan(abs(ang)/2)
    tan = r*th
    maxt = min(inl*0.48, outl*0.48)
    clamped = False
    if tan > maxt:
        r = maxt/th; tan = maxt; clamped = True
    entry = (v[0]-ind[0]*tan, v[1]-ind[1]*tan)
    exitp = (v[0]+outd[0]*tan, v[1]+outd[1]*tan)
    straight(prev_exit, entry, dist_acc)
    dist_acc += dist(prev_exit, entry)
    enter_s = dist_acc
    arc = abs(ang)*r
    sg = 1.0 if ang > 0 else -1.0
    perp = (-ind[1]*sg, ind[0]*sg)
    centre = (entry[0]+perp[0]*r, entry[1]+perp[1]*r)
    off = (entry[0]-centre[0], entry[1]-centre[1])
    steps = max(2, math.ceil(abs(ang)/0.07))
    for k in range(1, steps+1):
        th2 = ang*k/steps
        c, s_ = math.cos(th2), math.sin(th2)
        at = (centre[0]+off[0]*c-off[1]*s_, centre[1]+off[0]*s_+off[1]*c)
        pts.append((at[0], at[1], enter_s+arc*k/steps))
    dist_acc += arc
    info.append(dict(i=i, name=names[i+1] if i < 19 else "closing", ang=math.degrees(ang), r_req=r_req, r_used=r, clamped=clamped,
                     enter_s=enter_s, exit_s=dist_acc, tan=tan, inl=inl, outl=outl))
    prev_exit = exitp; prev = v
straight(prev_exit, START, dist_acc)
dist_acc += dist(prev_exit, START)
plan_len = dist_acc
scale = TARGET/plan_len
print(f"plan length {plan_len:.3f}  target {TARGET}  plan_scale {scale:.6f}")
print(f"road width {ROAD}  half {ROAD/2}")
print()
print(f"{'#':>2} {'turn':<20} {'ang':>7} {'Rreq':>6} {'Rused':>7} {'Rscaled':>8} {'clamp':>5} {'s_in':>7} {'s_out':>7} {'span':>6}")
minr = 1e9
for k in info[:19]:
    rs = k['r_used']*scale
    minr = min(minr, rs)
    print(f"{k['i']+1:>2} {k['name']:<20} {k['ang']:>7.1f} {k['r_req']:>6.0f} {k['r_used']:>7.1f} {rs:>8.1f} {'YES' if k['clamped'] else '':>5} {k['enter_s']*scale:>7.0f} {k['exit_s']*scale:>7.0f} {(k['exit_s']-k['enter_s'])*scale:>6.0f}")
print("min scaled radius:", round(minr, 2))
print("clamped fillets:", [(k['i']+1, round(k['r_req'], 0), round(k['r_used'], 1)) for k in info if k['clamped']])

# scale pts
P = [(x*scale, z*scale, s*scale) for x, z, s in pts]
L = TARGET

# --- elevation (smoothstep between keys, as Brianza) ---
E = bp["elevation"]["samples"]
def elev(s):
    x = s % L
    for a, b in zip(E, E[1:]):
        if a[0] <= x <= b[0]:
            t = (x-a[0])/(b[0]-a[0]); return a[1]+(b[1]-a[1])*t*t*(3-2*t)
    return 0.0
mx = 0.0; arg = 0
prevy = elev(0)
for k in range(1, int(L)+1):
    y = elev(k)
    g = abs(y-prevy);
    if g > mx: mx = g; arg = k
    prevy = y
print(f"max grade (1 m step): {mx*100:.1f}%  at s={arg}")

# --- helpers ---
def at_s(s):
    s = s % L
    lo, hi = 0, len(P)-1
    while hi-lo > 1:
        m = (lo+hi)//2
        if P[m][2] <= s: lo = m
        else: hi = m
    a, b = P[lo], P[hi]
    t = 0 if b[2] == a[2] else (s-a[2])/(b[2]-a[2])
    x = a[0]+(b[0]-a[0])*t; z = a[1]+(b[1]-a[1])*t
    h = norm((b[0]-a[0], b[1]-a[1]))
    return x, z, h
def side_pt(s, lat, side):  # side +1 right, -1 left
    x, z, h = at_s(s)
    rx, rz = -h[1], h[0]
    return x+rx*lat*side, z+rz*lat*side

# --- min separation between non-adjacent road sections ---
def sdiff(a, b):
    d = abs(a-b) % L; return min(d, L-d)
best = []
for i in range(0, len(P), 2):
    for j in range(i+1, len(P), 2):
        if sdiff(P[i][2], P[j][2]) < 150: continue
        d = math.hypot(P[i][0]-P[j][0], P[i][1]-P[j][1])
        best.append((d, P[i][2], P[j][2]))
best.sort()
print("\nclosest non-adjacent centreline pairs (s_a, s_b, dist):")
seen = []
for d, a, b in best:
    if any(sdiff(a, x[0]) < 60 and sdiff(b, x[1]) < 60 or sdiff(a, x[1]) < 60 and sdiff(b, x[0]) < 60 for x in seen): continue
    seen.append((a, b))
    print(f"  s={a:7.0f} vs s={b:7.0f}  d={d:6.1f} m  (road {ROAD} -> edge gap {d-ROAD:5.1f} m)")
    if len(seen) >= 8: break

# --- bounding box ---
xs = [p[0] for p in P]; zs = [p[1] for p in P]
print(f"\nbbox x[{min(xs):.0f},{max(xs):.0f}] z[{min(zs):.0f},{max(zs):.0f}]")

# --- pit ---
pit = bp["pit"]
e, x_ = pit["entry_s"], pit["exit_s"]
lane = (x_ - e) % TARGET
print(f"\npit lane arc {lane:.1f} (blueprint {pit['lane_length_m']}); T19 exit_s={info[18]['exit_s']*scale:.1f}; entry gap after T19 arc end = {e-info[18]['exit_s']*scale:.1f} m")
print(f"T1 enter_s={info[0]['enter_s']*scale:.1f}; exit mouth 260 -> T1 = {info[0]['enter_s']*scale-260:.0f} m")
sp = pit['stall_pitch_m']; cnt = pit['stall_count']
mid = (e + lane/2) % L
print(f"lane mid s={mid:.0f}; stall block {cnt*sp} m -> s {mid-cnt*sp/2:.0f}..{mid+cnt*sp/2:.0f}; entry->first stall {(mid-cnt*sp/2 - e)%L:.0f} m; last stall->exit {(x_-(mid+cnt*sp/2))%L:.0f} m")

# --- landmarks vs turns ---
print("\nlandmarks (s, side, offset) vs nearest turns:")
for lm in bp["grounding"]["pending_assets"]:
    s = lm["s"]
    near = sorted(info[:19], key=lambda k: abs((k['enter_s']+k['exit_s'])/2*scale - s))[:2]
    sd = -1 if lm["side"] == "L" else 1
    cx, cz = side_pt(s, lm["offset_m"], sd)
    # distance to other road centrelines (s farther than 150 m)
    dmin = min(math.hypot(p[0]-cx, p[1]-cz) for p in P if sdiff(p[2], s) > 150)
    dself = min(math.hypot(p[0]-cx, p[1]-cz) for p in P)
    print(f"  {lm['name']:<28} s={s:5.0f} {lm['side']} off={lm['offset_m']:>3}  footprint {lm['footprint_length_m']}x{lm['footprint_depth_m']}  nearest turns: "
          + ", ".join(f"T{k['i']+1} {k['name']}@{(k['enter_s']+k['exit_s'])/2*scale:.0f}" for k in near)
          + f" | centre->other road {dmin:.0f} m, ->nearest road {dself:.0f} m")

# --- strip bands vs other road ---
print("\nstrip bands: other-road centreline points inside the band rectangle (s-range, side, off..off+depth):")
for sg in bp["grounding"]["strip"]["segments"]:
    side = 1 if sg["side"] == "R" else -1
    inside = []
    s0, s1 = sg["s0"], sg["s1"]
    for p in P:
        if s0 <= p[2] <= s1: continue
        # check against band samples
        for s in range(int(s0), int(s1)+1, 20):
            x, z, h = at_s(s)
            rx, rz = -h[1]*side, h[0]*side
            dx, dz = p[0]-x, p[1]-z
            lat = dx*rx+dz*rz; along = dx*h[0]+dz*h[1]
            if sg["band_offset_m"] <= lat <= sg["band_offset_m"]+sg["band_depth_m"] and abs(along) < 12:
                inside.append(p[2]); break
    if inside:
        print(f"  {sg['zone']:<7} {sg['side']} s{s0:.0f}-{s1:.0f} off {sg['band_offset_m']} depth {sg['band_depth_m']}: road s=[{min(inside):.0f}..{max(inside):.0f}] ({len(inside)} pts) inside band")
    else:
        print(f"  {sg['zone']:<7} {sg['side']} s{s0:.0f}-{s1:.0f}: clear")

# --- grandstand vs water band ---
print("\ngrandstand (left, front 19, depth 38, span s=75+-120) vs L water band offset 24: stand occupies lat 19..57 -> overlaps water band start (24)")

# --- optional: where did a builder place its GLBs relative to the road? (python -I ... blueprint.json placement-manifest.json)
if len(sys.argv) > 2:
    pm = json.load(open(sys.argv[2], encoding="utf-8"))
    print("\nbuilder placements: nearest road station and signed lateral (+ right, - left) of the GLB origin")
    for pl in pm["placements"]:
        px, _, pz = pl["position"]
        best = min(P, key=lambda p: (p[0]-px)**2 + (p[1]-pz)**2)
        x, z, h = at_s(best[2])
        lat = (px-x)*(-h[1]) + (pz-z)*h[0]
        print(f"  {pl['id']:<40} s={best[2]:7.1f} lateral={lat:7.1f} m  dist={math.hypot(px-x, pz-z):6.1f} m  yaw={math.degrees(pl['rotation_y_rad']):7.1f} deg")
