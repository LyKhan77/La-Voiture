extends SceneTree

## The shared pieces the circuit environments and the sim lean on instead of copying them:
## WorldSkyRig (one sky/fog/sun driver, per-circuit profiles) and GtPitLayout (the sim's own default pit lane,
## which ApexPitComplex is built from, so scripts/gt never loads a circuit script).
## Run: godot --headless --path . -s res://tests/test_environment_shared_kit.gd

const ApexPit := preload("res://scripts/world/circuits/apex_ring/apex_pit_complex.gd")
const STORM := Color("#4a5260")
const PROFILE: Dictionary = {
	"sky_top": Color("#3f7fd0"), "sky_horizon": Color("#cfe3f5"), "ground": Color("#7fa06a"), "fog": Color("#dce8f5"),
	"fog_density": 0.0002, "ambient_energy": 0.9, "sun": Color("#fff3db"), "sun_energy": 1.2,
}

var failures: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	_test_sky_rig()
	_test_pit_layout()
	quit(1 if failures else 0)


func _test_sky_rig() -> void:
	var shared := Environment.new()
	var world_env := WorldEnvironment.new()
	world_env.environment = shared
	var sun := DirectionalLight3D.new()
	var rig := WorldSkyRig.new()
	rig.apply(world_env, sun, PROFILE, 0.0, STORM)
	var live: Environment = world_env.environment
	var sky: ProceduralSkyMaterial = live.sky.sky_material
	check(live != shared and shared.sky == null, "sky rig: the shared Environment resource is duplicated, never written to")
	check(live.background_mode == Environment.BG_SKY and live.fog_enabled, "sky rig: live environment shows a sky and fog")
	check(sky.sky_top_color.is_equal_approx(PROFILE["sky_top"]) and sky.sky_horizon_color.is_equal_approx(PROFILE["sky_horizon"]), "sky rig: clear weather paints the profile's sky")
	check(is_equal_approx(sun.light_energy, 1.2) and sun.light_color.is_equal_approx(PROFILE["sun"]), "sky rig: sun takes the profile's colour and energy")
	check(live.ambient_light_source != Environment.AMBIENT_SOURCE_COLOR, "sky rig: no ambient colour key leaves the ambient source alone")
	rig.apply(world_env, sun, PROFILE, 1.0, STORM)
	check(world_env.environment == live, "sky rig: a second apply reuses the live environment")
	check(sky.sky_horizon_color.is_equal_approx((PROFILE["sky_horizon"] as Color).lerp(STORM, WorldSkyRig.SKY_GLOOM_MIX)), "sky rig: full gloom greys the horizon toward the storm colour")
	check(is_equal_approx(sun.light_energy, 1.2 * (1.0 - WorldSkyRig.SUN_GLOOM_DIM)) and is_equal_approx(live.fog_density, 0.0004), "sky rig: full gloom dims the sun and thickens the fog")
	var aimed: Dictionary = PROFILE.duplicate()
	aimed["ambient"] = Color("#a3c2f0")
	aimed["sun_pitch"] = 40.0
	aimed["sun_yaw"] = 200.0
	rig.apply(world_env, sun, aimed, 0.0, STORM)
	check(live.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and live.ambient_light_color.is_equal_approx(aimed["ambient"]), "sky rig: an ambient key switches the ambient light to that colour")
	check(is_equal_approx(sun.rotation_degrees.x, -40.0) and is_equal_approx(sun.rotation_degrees.y, 200.0), "sky rig: pitch and yaw keys aim the sun")
	var tonemapped := WorldSkyRig.new()
	tonemapped.aces_tonemap = true
	tonemapped.fog_sky_affect = 0.15
	var other_env := WorldEnvironment.new()
	other_env.environment = Environment.new()
	tonemapped.apply(other_env, null, PROFILE, 0.0, STORM)
	check(other_env.environment.tonemap_mode == Environment.TONE_MAPPER_ACES and is_equal_approx(other_env.environment.fog_sky_affect, 0.15), "sky rig: ACES tonemap and fog-to-sky blend apply when a circuit asks for them")
	tonemapped.apply(null, sun, PROFILE, 0.0, STORM)
	check(true, "sky rig: no WorldEnvironment is a no-op")
	for node: Node in [world_env, sun, other_env]:
		node.free()


func _test_pit_layout() -> void:
	var layout: Dictionary = GtPitLayout.default_layout()
	check(layout == GtRace.default_pit_layout(), "pit layout: GtRace falls back on GtPitLayout")
	check(is_equal_approx(float(layout["entry_s"]), ApexPit.ENTRY_S) and is_equal_approx(float(layout["exit_s"]), ApexPit.EXIT_S)
		and is_equal_approx(float(layout["stall_first_s"]), ApexPit.STALL_FIRST_S) and is_equal_approx(float(layout["stall_pitch_m"]), ApexPit.STALL_PITCH_M)
		and is_equal_approx(float(layout["stall_lane_m"]), ApexPit.STALL_LANE_M) and is_equal_approx(float(layout["fast_lane_m"]), ApexPit.FAST_LANE_M)
		and is_equal_approx(float(layout["edge_lateral_m"]), ApexPit.EDGE_LATERAL_M) and is_equal_approx(float(layout["queue_gap_m"]), ApexPit.QUEUE_GAP_M)
		and is_equal_approx(float(layout["lane_ramp_in_m"]), ApexPit.RAMP_IN_M) and is_equal_approx(float(layout["lane_ramp_out_m"]), ApexPit.RAMP_OUT_M)
		and is_equal_approx(GtPitLayout.GARAGE_FRONT_M, ApexPit.GARAGE_FRONT_M), "pit layout: the Apex lane is built from the same numbers")
	check(layout["entry_s"] == 4000.0 and layout["fast_lane_m"] == 11.6, "pit layout: values are those of the Apex Ring's lane")
	var coupled: Array[String] = []
	for dir_path: String in ["res://scripts/gt", "res://scripts/car"]:
		for file_name: String in DirAccess.get_files_at(dir_path):
			if file_name.ends_with(".gd") and FileAccess.get_file_as_string("%s/%s" % [dir_path, file_name]).contains("res://scripts/world/circuits/"):
				coupled.append("%s/%s" % [dir_path, file_name])
	check(coupled.is_empty(), "pit layout: sim and car scripts load no circuit script (%s)" % ", ".join(coupled))
