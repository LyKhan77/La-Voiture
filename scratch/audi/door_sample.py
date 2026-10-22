import bpy, numpy as np
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath="D:/Occupation/Porto/genex/La_Voiture/assets/cars/audi_r8/raw/audi_r8_raw.glb")
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]; me = ob.data
im = [n.image for n in me.materials[0].node_tree.nodes if n.type == "TEX_IMAGE"][0]
im.colorspace_settings.name = "Non-Color"
W, H = im.size; px = np.array(im.pixels[:]).reshape(H, W, 4)
uv = me.uv_layers.active.data
for z in np.arange(-0.20, 0.12, 0.03):
    hit, loc, nrm, idx = ob.ray_cast(Vector((0.10, 0.9, z)), Vector((0, -1, 0)))
    if not hit: print("DS z %.2f no hit" % z); continue
    p = me.polygons[idx]; l = list(p.loop_indices)
    a, b, c = [me.vertices[me.loops[i].vertex_index].co for i in l[:3]]
    ua, ub, uc = [uv[i].uv for i in l[:3]]
    v0, v1, v2 = b - a, c - a, loc - a
    d00, d01, d11, d20, d21 = v0.dot(v0), v0.dot(v1), v1.dot(v1), v2.dot(v0), v2.dot(v1)
    den = d00 * d11 - d01 * d01; bv = (d11 * d20 - d01 * d21) / den; bw = (d00 * d21 - d01 * d20) / den; bu = 1 - bv - bw
    u = ua * bu + ub * bv + uc * bw
    x, y = int(u.x * (W - 1)), int(u.y * (H - 1))
    r, g, bl = px[y, x, :3]
    mx, mn = max(r, g, bl), min(r, g, bl)
    print("DS z %.2f rgb %.2f %.2f %.2f  lum %.2f sat %.2f" % (z, r, g, bl, 0.2126 * r + 0.7152 * g + 0.0722 * bl, (mx - mn) / max(mx, 1e-4)))
