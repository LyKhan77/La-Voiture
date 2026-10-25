"""
Bundles pitcrew mesh, armature, and all 4 animation clips (idle, walk, run, tire_service)
into a single production-ready GLB for Godot Engine:
assets/characters/pitcrew/pitcrew_master.glb
"""
import bpy
import os

BASE_DIR = r"D:\Occupation\Porto\genex\La_Voiture\assets\characters\pitcrew"
RIGGED_PATH = os.path.join(BASE_DIR, "pitcrew_rigged.glb")
IDLE_PATH = os.path.join(BASE_DIR, "pitcrew_anim_idle.glb")
WALK_PATH = os.path.join(BASE_DIR, "pitcrew_anim_walk.glb")
RUN_PATH = os.path.join(BASE_DIR, "pitcrew_anim_run.glb")
TIRE_PATH = os.path.join(BASE_DIR, "pitcrew_anim_tire_service.glb")
OUTPUT_PATH = os.path.join(BASE_DIR, "pitcrew_master.glb")

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)

def load_action_from_glb(filepath, target_name):
    # Import temporary GLB
    bpy.ops.import_scene.gltf(filepath=filepath)
    # Find the newly imported action
    action = None
    for a in bpy.data.actions:
        if a.name not in ["idle", "walk", "run", "tire_service"]:
            action = a
            break
    if action:
        action.name = target_name
        action.use_fake_user = True
        print(f"[ACTION] Loaded and renamed {target_name}")
    # Delete temporary imported objects from scene, keep action in bpy.data.actions
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    return action

def main():
    print("=== BUNDLING MASTER PITCREW MODEL & ANIMATIONS ===")
    reset_scene()

    # Step 1: Load actions into bpy.data.actions
    act_idle = load_action_from_glb(IDLE_PATH, "idle")
    act_walk = load_action_from_glb(WALK_PATH, "walk")
    act_run = load_action_from_glb(RUN_PATH, "run")
    act_tire = load_action_from_glb(TIRE_PATH, "tire_service")

    # Step 2: Import base rigged character
    bpy.ops.import_scene.gltf(filepath=RIGGED_PATH)
    arm = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
    if not arm:
        raise RuntimeError("No Armature found in base rigged GLB!")

    arm.name = "PitCrewArmature"
    if arm.animation_data is None:
        arm.animation_data_create()

    # Push all 4 actions to NLA tracks so glTF exporter includes all of them
    actions = [act_idle, act_walk, act_run, act_tire]
    for act in actions:
        if act:
            track = arm.animation_data.nla_tracks.new()
            track.name = act.name
            strip = track.strips.new(act.name, int(act.frame_range[0]), act)
            strip.name = act.name
            print(f"[NLA] Pushed track: {act.name} (frames {act.frame_range[0]} to {act.frame_range[1]})")

    # Default active action is idle
    arm.animation_data.action = act_idle

    # Step 3: Export master GLB
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(
        filepath=OUTPUT_PATH,
        export_format='GLB',
        export_animations=True,
        export_nla_strips=True,
        export_def_bones=True,
        export_apply=False,
        export_yup=True
    )
    print(f"[EXPORT] Successfully bundled to: {OUTPUT_PATH}")

if __name__ == "__main__":
    main()
