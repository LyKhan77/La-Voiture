"""
Procedural generator for GT3 Pit Stop Equipment Pack in Blender 5.2.
Generates:
1. Prop_WheelGun: High-speed Paeoli pneumatic wheel gun with 33mm socket and air hose fitting.
2. Prop_QuickJack: Low-profile front/rear lever jack with twin wheels and lift cradle.
3. Prop_FuelNozzle: Dual-handle endurance refueling rig nozzle with dry-break valve and flex hose.
4. Prop_LollipopBoard: 2.3m pit stop stop/go lollipop gantry sign.
5. Prop_FireExtinguisher: High-capacity pressure extinguisher with discharge horn.

Exports both individual GLB models and combined pack to assets/props/.
"""

import bpy
import bmesh
import math
import os
from math import pi, sin, cos, radians
from mathutils import Vector, Matrix, Euler

PROPS_DIR = r"D:\Occupation\Porto\genex\La_Voiture\assets\props"
os.makedirs(PROPS_DIR, exist_ok=True)

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Ensure a clean scene
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh, do_unlink=True)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat, do_unlink=True)

def srgb(h):
    c = [int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c) + (1.0,)

def make_material(name, color, metallic=0.0, roughness=0.5, emit=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emit:
        bsdf.inputs["Emission Color"].default_value = emit
        bsdf.inputs["Emission Strength"].default_value = 1.0
    return mat

def get_material(name):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    palette = {
        "Mat_Gunmetal": (srgb("#242830"), 0.9, 0.3, None),
        "Mat_Steel": (srgb("#888C94"), 0.95, 0.25, None),
        "Mat_GoldBrass": (srgb("#D4AF37"), 0.85, 0.3, None),
        "Mat_NeonAccent": (srgb("#D8FF00"), 0.1, 0.4, srgb("#D8FF00")),
        "Mat_RacingRed": (srgb("#E61C38"), 0.2, 0.35, None),
        "Mat_GoGreen": (srgb("#00E676"), 0.1, 0.35, srgb("#00E676")),
        "Mat_RubberBlack": (srgb("#141618"), 0.0, 0.85, None),
        "Mat_CarbonFiber": (srgb("#181A1D"), 0.3, 0.5, None),
        "Mat_Chrome": (srgb("#E0E4E8"), 0.98, 0.1, None),
    }
    color, metal, rough, emit = palette.get(name, (srgb("#888888"), 0.5, 0.5, None))
    return make_material(name, color, metal, rough, emit)

# Helper to create primitive mesh objects
def add_cylinder(name, radius, depth, location, rotation=(0,0,0), mat=None, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation
    )
    obj = bpy.context.active_object
    obj.name = name
    if mat:
        obj.data.materials.append(mat)
    return obj

def add_box(name, size, location, rotation=(0,0,0), mat=None):
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=location,
        rotation=rotation
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = Vector(size)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        obj.data.materials.append(mat)
    return obj

def join_objects(obj_list, final_name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in obj_list:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obj_list[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = final_name
    return obj

# -----------------------------------------------------------------------------
# 1. WHEEL GUN (Paeoli Style)
# -----------------------------------------------------------------------------
def build_wheel_gun():
    parts = []
    # Main motor body cylinder (along Y axis: front is -Y)
    parts.append(add_cylinder("WG_MotorHousing", radius=0.045, depth=0.18, location=(0, -0.02, 0.08), rotation=(pi/2, 0, 0), mat=get_material("Mat_Gunmetal")))
    # Rear housing cap
    parts.append(add_cylinder("WG_RearCap", radius=0.048, depth=0.03, location=(0, 0.08, 0.08), rotation=(pi/2, 0, 0), mat=get_material("Mat_RacingRed")))
    # Front gearbox nose
    parts.append(add_cylinder("WG_FrontNose", radius=0.035, depth=0.06, location=(0, -0.13, 0.08), rotation=(pi/2, 0, 0), mat=get_material("Mat_Steel")))
    # 33mm Center-lock socket (Hexagonal/cylindrical)
    parts.append(add_cylinder("WG_Socket", radius=0.032, depth=0.05, location=(0, -0.18, 0.08), rotation=(pi/2, 0, 0), mat=get_material("Mat_GoldBrass"), vertices=6))
    
    # Handle grip (angled down from motor housing)
    parts.append(add_cylinder("WG_Grip", radius=0.018, depth=0.14, location=(0, 0.01, -0.01), rotation=(radians(15), 0, 0), mat=get_material("Mat_RubberBlack")))
    # Handle base block
    parts.append(add_box("WG_GripBase", size=(0.04, 0.05, 0.02), location=(0, 0.03, -0.09), mat=get_material("Mat_Gunmetal")))
    # Air line quick-release fitting at base
    parts.append(add_cylinder("WG_AirFitting", radius=0.012, depth=0.03, location=(0, 0.035, -0.11), rotation=(radians(15), 0, 0), mat=get_material("Mat_GoldBrass")))
    # Trigger guard and trigger
    parts.append(add_box("WG_TriggerGuard", size=(0.01, 0.03, 0.04), location=(0, -0.02, 0.01), mat=get_material("Mat_Gunmetal")))
    parts.append(add_box("WG_Trigger", size=(0.008, 0.012, 0.02), location=(0, -0.015, 0.015), mat=get_material("Mat_NeonAccent")))
    # Accent ring on housing
    parts.append(add_cylinder("WG_AccentStripe", radius=0.046, depth=0.015, location=(0, -0.06, 0.08), rotation=(pi/2, 0, 0), mat=get_material("Mat_NeonAccent")))

    gun = join_objects(parts, "Prop_WheelGun")
    # Position origin at handle grip center (so it snaps nicely to Hand.R)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR', center='MEDIAN')
    return gun

# -----------------------------------------------------------------------------
# 2. QUICK-JACK (Low-Profile Front/Rear Lever Jack)
# -----------------------------------------------------------------------------
def build_quick_jack():
    parts = []
    # Frame base rails (X = width, Y = length, Z = height)
    # Cradle that goes under car splitter (Y = -0.4 to 0.0)
    parts.append(add_box("QJ_CradleLeft", size=(0.03, 0.35, 0.03), location=(-0.16, -0.20, 0.04), mat=get_material("Mat_Gunmetal")))
    parts.append(add_box("QJ_CradleRight", size=(0.03, 0.35, 0.03), location=(0.16, -0.20, 0.04), mat=get_material("Mat_Gunmetal")))
    parts.append(add_box("QJ_CradleCross", size=(0.35, 0.03, 0.03), location=(0, -0.36, 0.04), mat=get_material("Mat_Gunmetal")))
    # Rubber lift pads (which touch chassis hard points)
    parts.append(add_box("QJ_PadLeft", size=(0.05, 0.08, 0.015), location=(-0.16, -0.32, 0.06), mat=get_material("Mat_RubberBlack")))
    parts.append(add_box("QJ_PadRight", size=(0.05, 0.08, 0.015), location=(0.16, -0.32, 0.06), mat=get_material("Mat_RubberBlack")))

    # Fulcrum cross axle and twin wheels
    parts.append(add_cylinder("QJ_Axle", radius=0.012, depth=0.42, location=(0, 0.0, 0.05), rotation=(0, pi/2, 0), mat=get_material("Mat_Steel")))
    parts.append(add_cylinder("QJ_WheelLeft", radius=0.05, depth=0.035, location=(-0.20, 0.0, 0.05), rotation=(0, pi/2, 0), mat=get_material("Mat_RubberBlack")))
    parts.append(add_cylinder("QJ_WheelRight", radius=0.05, depth=0.035, location=(0.20, 0.0, 0.05), rotation=(0, pi/2, 0), mat=get_material("Mat_RubberBlack")))
    # Wheel hub caps
    parts.append(add_cylinder("QJ_HubLeft", radius=0.02, depth=0.04, location=(-0.20, 0.0, 0.05), rotation=(0, pi/2, 0), mat=get_material("Mat_RacingRed")))
    parts.append(add_cylinder("QJ_HubRight", radius=0.02, depth=0.04, location=(0.20, 0.0, 0.05), rotation=(0, pi/2, 0), mat=get_material("Mat_RacingRed")))

    # Long curved lever handle extending backward (+Y and up +Z)
    # Lower handle arm
    parts.append(add_cylinder("QJ_HandleLower", radius=0.018, depth=0.70, location=(0, 0.32, 0.28), rotation=(radians(50), 0, 0), mat=get_material("Mat_Steel")))
    # Upper handle arm (more horizontal)
    parts.append(add_cylinder("QJ_HandleUpper", radius=0.018, depth=0.65, location=(0, 0.85, 0.52), rotation=(radians(20), 0, 0), mat=get_material("Mat_Steel")))
    # Crossbar handle grip at end
    parts.append(add_cylinder("QJ_GripBar", radius=0.018, depth=0.38, location=(0, 1.15, 0.63), rotation=(0, pi/2, 0), mat=get_material("Mat_RubberBlack")))
    parts.append(add_box("QJ_NeonStrip", size=(0.20, 0.03, 0.01), location=(0, 0.85, 0.54), mat=get_material("Mat_NeonAccent")))

    jack = join_objects(parts, "Prop_QuickJack")
    # Base at Z=0
    return jack

# -----------------------------------------------------------------------------
# 3. REFUELING RIG NOZZLE (Endurance Dry-Break Coupling)
# -----------------------------------------------------------------------------
def build_fuel_nozzle():
    parts = []
    # Main valve cylinder (pointing -Y forward into car filler)
    parts.append(add_cylinder("FN_CouplerNose", radius=0.055, depth=0.10, location=(0, -0.22, 0), rotation=(pi/2, 0, 0), mat=get_material("Mat_Chrome")))
    # Dual concentric dry-break seal ring
    parts.append(add_cylinder("FN_SealRing", radius=0.062, depth=0.02, location=(0, -0.26, 0), rotation=(pi/2, 0, 0), mat=get_material("Mat_RubberBlack")))
    # Valve body chamber
    parts.append(add_cylinder("FN_ValveBody", radius=0.07, depth=0.24, location=(0, -0.06, 0), rotation=(pi/2, 0, 0), mat=get_material("Mat_Steel")))
    # Locking collar & levers
    parts.append(add_cylinder("FN_LockCollar", radius=0.078, depth=0.04, location=(0, -0.14, 0), rotation=(pi/2, 0, 0), mat=get_material("Mat_RacingRed")))
    parts.append(add_box("FN_LeverLeft", size=(0.02, 0.08, 0.04), location=(-0.09, -0.14, 0), mat=get_material("Mat_RacingRed")))
    parts.append(add_box("FN_LeverRight", size=(0.02, 0.08, 0.04), location=(0.09, -0.14, 0), mat=get_material("Mat_RacingRed")))

    # Dual control handles:
    # Top carry & thrust handle
    parts.append(add_box("FN_TopStrutFront", size=(0.02, 0.02, 0.09), location=(0, -0.10, 0.11), mat=get_material("Mat_Gunmetal")))
    parts.append(add_box("FN_TopStrutRear", size=(0.02, 0.02, 0.09), location=(0, 0.04, 0.11), mat=get_material("Mat_Gunmetal")))
    parts.append(add_cylinder("FN_TopGrip", radius=0.016, depth=0.18, location=(0, -0.03, 0.15), rotation=(pi/2, 0, 0), mat=get_material("Mat_RubberBlack")))
    
    # Side stabilization handle
    parts.append(add_cylinder("FN_SideGrip", radius=0.016, depth=0.14, location=(0.14, -0.05, 0), rotation=(0, pi/2, 0), mat=get_material("Mat_RubberBlack")))

    # Trailing heavy flex hose (corrugated rubber stub pointing backward/upward)
    parts.append(add_cylinder("FN_HoseAdapter", radius=0.06, depth=0.06, location=(0, 0.08, 0), rotation=(pi/2, 0, 0), mat=get_material("Mat_Gunmetal")))
    for i in range(5):
        # segmented curved hose
        y_pos = 0.13 + (i * 0.07)
        z_pos = (i * 0.03)
        parts.append(add_cylinder(f"FN_HoseSegment_{i}", radius=0.052, depth=0.055, location=(0, y_pos, z_pos), rotation=(radians(100 + i*4), 0, 0), mat=get_material("Mat_RubberBlack")))

    nozzle = join_objects(parts, "Prop_FuelNozzle")
    return nozzle

# -----------------------------------------------------------------------------
# 4. PIT STOP LOLLIPOP BOARD (Stop / Go Sign)
# -----------------------------------------------------------------------------
def build_lollipop_board():
    parts = []
    # 2.3m Carbon Fiber Pole (vertical along Z)
    parts.append(add_cylinder("LP_Pole", radius=0.016, depth=2.30, location=(0, 0, 1.15), mat=get_material("Mat_CarbonFiber"), vertices=12))
    # Rubber foot cap at bottom
    parts.append(add_cylinder("LP_FootCap", radius=0.02, depth=0.04, location=(0, 0, 0.02), mat=get_material("Mat_RubberBlack")))
    # Two hand grips for pit controller (lower and upper)
    parts.append(add_cylinder("LP_GripLower", radius=0.022, depth=0.22, location=(0, 0, 0.95), mat=get_material("Mat_RubberBlack")))
    parts.append(add_cylinder("LP_GripUpper", radius=0.022, depth=0.22, location=(0, 0, 1.35), mat=get_material("Mat_RubberBlack")))
    # Neon safety indicator bands on pole
    parts.append(add_cylinder("LP_Band1", radius=0.019, depth=0.03, location=(0, 0, 1.10), mat=get_material("Mat_NeonAccent")))
    parts.append(add_cylinder("LP_Band2", radius=0.019, depth=0.03, location=(0, 0, 1.75), mat=get_material("Mat_NeonAccent")))

    # Top sign disc mount
    parts.append(add_box("LP_DiscMount", size=(0.05, 0.05, 0.08), location=(0, 0, 2.32), mat=get_material("Mat_Gunmetal")))
    # Outer circular frame (radius = 0.22m, thin in Y)
    parts.append(add_cylinder("LP_SignRim", radius=0.23, depth=0.03, location=(0, 0, 2.50), rotation=(pi/2, 0, 0), mat=get_material("Mat_Gunmetal"), vertices=32))
    # Face A: STOP / BRAKE (Facing -Y)
    parts.append(add_cylinder("LP_SignFaceRed", radius=0.21, depth=0.012, location=(0, -0.01, 2.50), rotation=(pi/2, 0, 0), mat=get_material("Mat_RacingRed"), vertices=32))
    # Face B: GO! (Facing +Y)
    parts.append(add_cylinder("LP_SignFaceGreen", radius=0.21, depth=0.012, location=(0, 0.01, 2.50), rotation=(pi/2, 0, 0), mat=get_material("Mat_GoGreen"), vertices=32))

    lollipop = join_objects(parts, "Prop_LollipopBoard")
    return lollipop

# -----------------------------------------------------------------------------
# 5. PIT FIRE EXTINGUISHER
# -----------------------------------------------------------------------------
def build_fire_extinguisher():
    parts = []
    # Main cylinder pressure tank (vertical along Z)
    parts.append(add_cylinder("FE_TankBody", radius=0.085, depth=0.38, location=(0, 0, 0.22), mat=get_material("Mat_RacingRed"), vertices=24))
    # Rounded top and bottom caps
    parts.append(add_cylinder("FE_BottomBase", radius=0.088, depth=0.04, location=(0, 0, 0.02), mat=get_material("Mat_RubberBlack")))
    parts.append(add_cylinder("FE_TopDome", radius=0.075, depth=0.05, location=(0, 0, 0.42), mat=get_material("Mat_RacingRed")))
    
    # Valve assembly on top
    parts.append(add_cylinder("FE_ValveNeck", radius=0.025, depth=0.05, location=(0, 0, 0.46), mat=get_material("Mat_GoldBrass")))
    # Squeeze handle lever
    parts.append(add_box("FE_HandleFixed", size=(0.02, 0.12, 0.015), location=(0, 0.04, 0.50), mat=get_material("Mat_Gunmetal")))
    parts.append(add_box("FE_HandleTrigger", size=(0.018, 0.10, 0.012), location=(0, 0.03, 0.525), rotation=(0, radians(-15), 0), mat=get_material("Mat_Gunmetal")))
    # Pressure gauge dial
    parts.append(add_cylinder("FE_Gauge", radius=0.018, depth=0.015, location=(0.035, 0, 0.48), rotation=(0, pi/2, 0), mat=get_material("Mat_Chrome")))
    # Hose & discharge horn nozzle
    parts.append(add_cylinder("FE_HoseStub", radius=0.012, depth=0.32, location=(-0.09, 0, 0.30), rotation=(0, 0, 0), mat=get_material("Mat_RubberBlack")))
    parts.append(add_cylinder("FE_DischargeHorn", radius=0.032, depth=0.12, location=(-0.09, 0, 0.12), rotation=(0, 0, 0), mat=get_material("Mat_RubberBlack")))

    fe = join_objects(parts, "Prop_FireExtinguisher")
    return fe

# -----------------------------------------------------------------------------
# MASTER BUILD & EXPORT
# -----------------------------------------------------------------------------
def export_prop(obj, filename):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    filepath = os.path.join(PROPS_DIR, filename)
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        use_selection=True,
        export_format='GLB',
        export_apply=True,
        export_yup=True
    )
    print(f"[EXPORT] Saved {filename} ({filepath})")

def main():
    print("=== BUILDING PIT STOP EQUIPMENT PACK ===")
    
    # 1. Wheel Gun
    reset_scene()
    wg = build_wheel_gun()
    export_prop(wg, "wheel_gun.glb")

    # 2. Quick Jack
    reset_scene()
    qj = build_quick_jack()
    export_prop(qj, "quick_jack.glb")

    # 3. Fuel Nozzle
    reset_scene()
    fn = build_fuel_nozzle()
    export_prop(fn, "fuel_nozzle.glb")

    # 4. Lollipop Board
    reset_scene()
    lp = build_lollipop_board()
    export_prop(lp, "lollipop_board.glb")

    # 5. Fire Extinguisher
    reset_scene()
    fe = build_fire_extinguisher()
    export_prop(fe, "fire_extinguisher.glb")

    # 6. Combined Pack
    reset_scene()
    wg = build_wheel_gun()
    qj = build_quick_jack()
    fn = build_fuel_nozzle()
    lp = build_lollipop_board()
    fe = build_fire_extinguisher()
    
    # Space them out nicely in the combined pack
    wg.location = (-0.8, -0.5, 0.15)
    fn.location = (-0.8, 0.5, 0.15)
    fe.location = (-0.8, 0.0, 0.0)
    qj.location = (0.5, 0.0, 0.0)
    lp.location = (0.0, -0.8, 0.0)
    
    bpy.ops.object.select_all(action='SELECT')
    pack_path = os.path.join(PROPS_DIR, "pit_equipment_pack.glb")
    bpy.ops.export_scene.gltf(
        filepath=pack_path,
        use_selection=False,
        export_format='GLB',
        export_apply=True,
        export_yup=True
    )
    print(f"[EXPORT] Saved combined pit_equipment_pack.glb ({pack_path})")
    print("=== PIT EQUIPMENT PACK BUILD FINISHED ===")

if __name__ == "__main__":
    main()
