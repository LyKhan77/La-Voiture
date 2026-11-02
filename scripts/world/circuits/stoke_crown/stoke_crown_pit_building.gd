extends Node3D

## Crown Wing GLB architecture; team fascia stays live when the field is re-seated.
const Batch := preload("res://scripts/world/shared/mesh_batch.gd")
const Toon := preload("res://scripts/world/shared/toon_materials.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")
const Look := preload("res://scripts/world/circuits/stoke_crown/stoke_crown_toon.gd")
const MODEL := "res://assets/tracks/stoke_crown/models/crown_wing_paddock.glb"
const Model := preload("res://scripts/world/circuits/stoke_crown/stoke_crown_model.gd")
var structure: MeshInstance3D
var name_plates: Array = []

func build() -> void:
	var model := Model.load_batched(MODEL, true)
	assert(model != null)
	add_child(model)
	Look.apply_materials(model)
	structure = MeshInstance3D.new()
	structure.name = "TeamFascia"
	add_child(structure)

func apply_teams(ids: Array[int]) -> void:
	var batch := Batch.new()
	var material: Material = Toon.vertex_colored(false)
	for i: int in range(ids.size()):
		var z := -20.0 * (float(i) - 4.5)
		batch.box(material, Liveries.color_for(ids[i]), Transform3D(Basis.IDENTITY, Vector3(-0.05, 6.35, z)), Vector3(0.12, 0.55, 17.8))
	structure.mesh = batch.commit()
