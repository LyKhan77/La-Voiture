class_name FlagPanelSet
extends MultiMeshInstance3D

## The trackside digital flag panels of one circuit: ONE MultiMesh, the state of each panel in its instance custom
## data (digital_flag_panel.gdshader draws one pattern per value). A circuit decides where the panels stand (it knows
## its own barriers); this node plans which arcs deserve one, draws them and shows the flag race control shows.

const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")
const PanelShader := preload("res://shaders/digital_flag_panel.gdshader")
const FlagType := preload("res://scripts/gt/gt_types.gd")

const COUNT: int = 8
const W_M: float = 1.8
const H_M: float = 1.2
const BASE_M: float = 1.6
const FRAME_M: float = 0.1
## A panel stands this many metres before the corner it warns of.
const LEAD_M: float = 70.0
## Anchors the same panel may not be repeated within this arc distance.
const MIN_SPACING_M: float = 150.0
## The panel before the start / finish line is always first.
const FINISH_LEAD_M: float = 60.0
## At most this many panels come from the preferred anchors; the rest split the biggest gaps of the lap.
const MAX_PREFERRED: int = 5
const POST_COLOR := Color("#4a505c")
const HOUSING_COLOR := Color("#14161c")

## Instance custom data x of a panel.
enum PanelState { GREEN, YELLOW, SC }

## One record per panel: {s, side, sector (1..3)}.
var records: Array[Dictionary] = []
## PanelState of each panel as last written; headless runs cannot read MultiMesh custom data back.
var states: Array[int] = []
## Where each panel stands; kept here as well because headless runs cannot read MultiMesh transforms back.
var poses: Array[Transform3D] = []
var count: int = 0


## The arcs panels stand at: the finish line first, then the `preferred` anchors ({s, side}) in order while they keep
## MIN_SPACING_M from every panel chosen (at most MAX_PREFERRED panels in all), then the middle of the widest gap
## until there are COUNT.
static func plan(length_m: float, preferred: Array[Dictionary]) -> Array[Dictionary]:
	var anchors: Array[Dictionary] = [{"s": fposmod(-FINISH_LEAD_M, length_m), "side": -1.0}]
	for candidate: Dictionary in preferred:
		if anchors.size() < MAX_PREFERRED and _clear_of(anchors, float(candidate["s"]), length_m):
			anchors.append({"s": fposmod(float(candidate["s"]), length_m), "side": float(candidate["side"])})
	while anchors.size() < COUNT:
		anchors.append({"s": _widest_gap_midpoint(anchors, length_m), "side": -1.0})
	return anchors


## `anchors` ({s, side}) and `poses` (where each panel stands, facing back along the road) are parallel.
func build(length_m: float, anchors: Array[Dictionary], p_poses: Array[Transform3D]) -> void:
	records.clear()
	states.clear()
	poses = p_poses
	for anchor: Dictionary in anchors:
		var s: float = float(anchor["s"])
		records.append({"s": s, "side": float(anchor["side"]), "sector": mini(2, floori(s / length_m * 3.0)) + 1})
		states.append(PanelState.GREEN)
	count = poses.size()
	var panels := MultiMesh.new()
	panels.transform_format = MultiMesh.TRANSFORM_3D
	panels.use_custom_data = true # must be set while the instance count is still 0
	panels.mesh = _mesh()
	panels.instance_count = count
	for index: int in range(count):
		panels.set_instance_transform(index, poses[index])
		panels.set_instance_custom_data(index, Color(float(PanelState.GREEN), 0.0, 0.0, 0.0))
	multimesh = panels


## The state each panel shows for the current race-control flag. `sector` is 1-based, as in set_flag().
func panel_state_for(flag: int, sector: int, panel_sector: int) -> int:
	if flag == FlagType.Flag.SC:
		return PanelState.SC
	if flag == FlagType.Flag.VSC:
		return PanelState.YELLOW
	if flag == FlagType.Flag.YELLOW and sector == panel_sector:
		return PanelState.YELLOW
	return PanelState.GREEN


## Writes the panel states for the flag race control shows; only a changed panel touches the MultiMesh.
func apply_flag(flag: int, sector: int) -> void:
	for index: int in range(count):
		var state: int = panel_state_for(flag, sector, int(records[index]["sector"]))
		if state != states[index]:
			states[index] = state
			multimesh.set_instance_custom_data(index, Color(float(state), 0.0, 0.0, 0.0))


static func _clear_of(anchors: Array[Dictionary], s: float, length_m: float) -> bool:
	for anchor: Dictionary in anchors:
		var gap: float = absf(fposmod(s - float(anchor["s"]) + length_m * 0.5, length_m) - length_m * 0.5)
		if gap < MIN_SPACING_M:
			return false
	return true


static func _widest_gap_midpoint(anchors: Array[Dictionary], length_m: float) -> float:
	var arcs: Array[float] = []
	for anchor: Dictionary in anchors:
		arcs.append(float(anchor["s"]))
	arcs.sort()
	var best_start: float = arcs[-1]
	var best_gap: float = arcs[0] + length_m - arcs[-1]
	for index: int in range(arcs.size() - 1):
		if arcs[index + 1] - arcs[index] > best_gap:
			best_gap = arcs[index + 1] - arcs[index]
			best_start = arcs[index]
	return fposmod(best_start + best_gap * 0.5, length_m)


## Two posts, a matte black housing and the LED face on its own shader (the face looks toward +z, at the cars).
func _mesh() -> ArrayMesh:
	var batch := MeshBatchScript.new()
	var material: ShaderMaterial = ToonMaterials.vertex_colored()
	var centre_y: float = BASE_M + H_M * 0.5
	for x: float in [-W_M * 0.4, W_M * 0.4]:
		batch.box(material, POST_COLOR, Transform3D(Basis.IDENTITY, Vector3(x, BASE_M * 0.5, -0.06)), Vector3(0.1, BASE_M, 0.1))
	batch.box(material, HOUSING_COLOR, Transform3D(Basis.IDENTITY, Vector3(0.0, centre_y, 0.0)), Vector3(W_M + FRAME_M * 2.0, H_M + FRAME_M * 2.0, 0.14))
	var mesh: ArrayMesh = batch.commit()
	var face := SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	face.set_normal(Vector3.BACK)
	var half_w: float = W_M * 0.5
	var half_h: float = H_M * 0.5
	var corners: Array[Array] = [
		[Vector3(-half_w, centre_y + half_h, 0.075), Vector2(0.0, 0.0)], [Vector3(half_w, centre_y + half_h, 0.075), Vector2(1.0, 0.0)],
		[Vector3(half_w, centre_y - half_h, 0.075), Vector2(1.0, 1.0)], [Vector3(-half_w, centre_y - half_h, 0.075), Vector2(0.0, 1.0)],
	]
	for slot: int in [0, 1, 2, 0, 2, 3]:
		face.set_uv(corners[slot][1])
		face.add_vertex(corners[slot][0])
	face.commit(mesh)
	var face_material := ShaderMaterial.new()
	face_material.shader = PanelShader
	mesh.surface_set_material(mesh.get_surface_count() - 1, face_material)
	return mesh
