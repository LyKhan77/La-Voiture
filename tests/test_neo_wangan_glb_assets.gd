extends SceneTree

const DIRECTORY := "res://assets/tracks/neo_wangan/models/"
const MODELS: Array[String] = ["shuto_bridge_pylon", "tunnel_portal_overpass", "harbor_gantry_crane", "skyscraper_tower_a", "skyscraper_tower_b", "skyscraper_tower_c"]
var failures: int = 0

func check(ok: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1

func _initialize() -> void:
	for model: String in MODELS:
		var path: String = DIRECTORY + model + ".glb"
		check(ResourceLoader.exists(path), model + " GLB exists")
		if not ResourceLoader.exists(path):
			continue
		var scene: PackedScene = load(path) as PackedScene
		check(scene != null, model + " imports as PackedScene")
		if scene == null:
			continue
		var node: Node3D = scene.instantiate() as Node3D
		var bounds := AABB()
		var triangles: int = 0
		var material_names: Array[String] = []
		var vertex_colors: bool = true
		for child: Node in node.find_children("*", "MeshInstance3D", true, false):
			var instance := child as MeshInstance3D
			bounds = bounds.merge(instance.transform * instance.get_aabb())
			for surface: int in range(instance.mesh.get_surface_count()):
				var arrays: Array = instance.mesh.surface_get_arrays(surface)
				vertex_colors = vertex_colors and arrays[Mesh.ARRAY_COLOR] is PackedColorArray and (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() > 0
				triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				material_names.append(instance.mesh.surface_get_material(surface).resource_name)
		check(triangles > 100 and triangles <= 5000, "%s meaningful mesh within 5000 tris (%d)" % [model, triangles])
		check(vertex_colors, model + " retains authored palette vertex colors")
		if model == "shuto_bridge_pylon":
			check(bounds.size.y >= 65.0 and bounds.size.x >= 44.0 and material_names.has("StayCablesMat"), "44 x 65 m H-frame and steel cable surface")
		elif model == "tunnel_portal_overpass":
			check(bounds.size.x >= 25.0 and bounds.size.y >= 8.0 and node.find_child("*Portal*", true, false) != null, "Heavy tunnel portal includes overpass mass")
		elif model == "harbor_gantry_crane":
			check(bounds.size.y >= 28.0 and bounds.size.x >= 32.0 and material_names.has("HarborCraneMat"), "28 m harbor crane with 32 m boom")
		else:
			check(bounds.size.y >= 24.0, model + " has architectural tower silhouette")
		node.free()
	print("NEO-WANGAN GLB ASSETS: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
