extends SceneTree
## Captures the street-manga Team Garage: weather-adaptive tyre pick, critical mismatch, the wheatpaste
## override poster and the team-colour accent on three differently coloured teams.
## Run: godot --path . --resolution 1920x1080 --script res://scratch/capture_garage_step2.gd
const ConfigScript := preload("res://scripts/core/race_config_data.gd")
const Types := preload("res://scripts/gt/gt_types.gd")
const OUT_DIR: String = "res://executor-report/screenshots/phases"
func _initialize() -> void:
	call_deferred("_run")
func _shot(name: String) -> void:
	for _i: int in range(40):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("%s/%s" % [OUT_DIR, name]))
	print("Saved screenshot: ", name)
func _garage(weather: int) -> Node:
	var config := ConfigScript.reset()
	config.weather_preset = weather
	config.car1_starting_compound = Types.Compound.SOFT
	config.car2_starting_compound = Types.Compound.MEDIUM
	var garage: Node = load("res://scenes/ui/garage_team_select.tscn").instantiate()
	root.add_child(garage)
	return garage
func _run() -> void:
	var garage: Node = _garage(3)
	await _shot("phase-11-step-2-garage-weather-pick.png")
	garage.select_compound(0, Types.Compound.SOFT)
	await _shot("phase-11-step-2-garage-slicks-mismatch.png")
	garage.launch()
	await _shot("phase-11-step-2-critical-mismatch-modal.png")
	garage._hide_mismatch_modal()
	garage.select_team(2)
	await _shot("phase-11-step-2-garage-team-crimson-cyan-shadow.png")
	garage.select_team(7)
	await _shot("phase-11-step-2-garage-team-white.png")
	garage.queue_free()
	await process_frame
	garage = _garage(0)
	garage.select_compound(1, Types.Compound.WET)
	await _shot("phase-11-step-2-garage-dry-wets-mismatch.png")
	garage.launch()
	await _shot("phase-11-step-2-critical-mismatch-modal-wets-on-dry.png")
	print("All Phase 11 Step 2 UI screenshots captured successfully!")
	quit(0)
