class_name PitCrewFigure
extends RefCounted

## Low-poly pit crew people built from boxes through MeshBatch (feet at the origin, facing -Z, about
## 1.8 m tall): boots, legs, torso with a chest stripe, arms with gloves, head, helmet and visor, plus the
## gear of each role. One figure is a single merged surface, so a garage's standing crew is one draw call and
## an animated crew member is one node. Used for the crew standing by in the garages (static) and for the
## crew that steps out and works on the car (PitstopChoreographer).

const MeshBatchScript := preload("res://scripts/world/shared/mesh_batch.gd")
const ToonMaterials := preload("res://scripts/world/shared/toon_materials.gd")
const Liveries := preload("res://scripts/car/team_liveries.gd")

enum Role { GUNNER, HANDLER, JACK, FUELER, FIRE, LOLLIPOP, ENGINEER }

const ROLE_NAMES: Array[String] = ["gunner", "handler", "jack", "fueler", "fire", "lollipop", "engineer"]

const BOOT_COLOR := Color("#16171c")
const GLOVE_COLOR := Color("#202228")
const SKIN_COLOR := Color("#f0c8a4")
const HELMET_COLOR := Color("#f4f5f7")
const VISOR_COLOR := Color("#0c0d12")
const STRIPE_COLOR := Color("#f4f5f7")
const FIRE_SUIT_COLOR := Color("#c9cdd6")
const ENGINEER_JACKET_COLOR := Color("#2a2d36")
const GUN_COLOR := Color("#ffd400")
const HOSE_COLOR := Color("#23252c")
const EXTINGUISHER_COLOR := Color("#e0212e")

const HEIGHT_M: float = 1.8

static var _mesh_cache: Dictionary = {}


## Adds one standing person to `batch` at `xform` (feet on its origin, facing its -Z).
static func add(batch: MeshBatchScript, material: Material, xform: Transform3D, role: int, team_color: Color) -> void:
	var overall: Color = FIRE_SUIT_COLOR if role == Role.FIRE else (ENGINEER_JACKET_COLOR if role == Role.ENGINEER else team_color)
	for side: float in [-1.0, 1.0]:
		batch.box(material, BOOT_COLOR, _at(xform, Vector3(side * 0.1, 0.06, -0.04)), Vector3(0.16, 0.12, 0.3))
		batch.box(material, overall, _at(xform, Vector3(side * 0.1, 0.51, 0.0)), Vector3(0.15, 0.78, 0.17))
		batch.box(material, overall, _at(xform, Vector3(side * 0.29, 1.19, 0.0)), Vector3(0.11, 0.56, 0.13))
		batch.box(material, GLOVE_COLOR, _at(xform, Vector3(side * 0.29, 0.86, 0.0)), Vector3(0.12, 0.12, 0.14))
	batch.box(material, overall, _at(xform, Vector3(0.0, 1.22, 0.0)), Vector3(0.44, 0.62, 0.26))
	batch.box(material, STRIPE_COLOR if role != Role.ENGINEER else team_color, _at(xform, Vector3(0.0, 1.36, -0.005)), Vector3(0.46, 0.09, 0.27))
	batch.cylinder(material, SKIN_COLOR, _at(xform, Vector3(0.0, 1.53, 0.0)), 0.1, 0.1, 0.2, 8, true, false)
	if role == Role.ENGINEER:
		# A team cap and a headset instead of a helmet.
		batch.cylinder(material, team_color, _at(xform, Vector3(0.0, 1.66, 0.0)), 0.125, 0.115, 0.1, 8)
		batch.box(material, VISOR_COLOR, _at(xform, Vector3(0.0, 1.62, 0.0)), Vector3(0.3, 0.04, 0.06))
	else:
		batch.cylinder(material, HELMET_COLOR if role != Role.LOLLIPOP else team_color, _at(xform, Vector3(0.0, 1.6, 0.0)), 0.135, 0.125, 0.17, 8)
		batch.box(material, VISOR_COLOR, _at(xform, Vector3(0.0, 1.66, -0.1)), Vector3(0.2, 0.07, 0.06))
	_gear(batch, material, xform, role)


## The mesh of one person for an animated node; cached per role and team colour.
static func mesh_for(role: int, team_color: Color) -> ArrayMesh:
	var key: String = "%d_%s" % [role, team_color.to_html()]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var batch := MeshBatchScript.new()
	add(batch, ToonMaterials.vertex_colored(false), Transform3D.IDENTITY, role, team_color)
	var mesh: ArrayMesh = batch.commit()
	_mesh_cache[key] = mesh
	return mesh


static func clear_cache() -> void:
	_mesh_cache.clear()


## What each role carries: the wheel gun, a jack handle, the fuel nozzle, the extinguisher.
static func _gear(batch: MeshBatchScript, material: Material, xform: Transform3D, role: int) -> void:
	match role:
		Role.GUNNER:
			batch.box(material, GUN_COLOR, _at(xform, Vector3(-0.29, 0.9, -0.26)), Vector3(0.1, 0.12, 0.42))
			batch.box(material, HOSE_COLOR, _at(xform, Vector3(-0.29, 0.78, 0.0)), Vector3(0.04, 0.04, 0.5))
		Role.JACK:
			batch.box(material, GUN_COLOR, _at(xform, Vector3(0.29, 0.6, -0.32)), Vector3(0.05, 0.05, 0.72))
		Role.FUELER:
			batch.box(material, Color("#9aa1ae"), _at(xform, Vector3(0.29, 0.95, -0.3)), Vector3(0.08, 0.1, 0.4))
			batch.box(material, HOSE_COLOR, _at(xform, Vector3(0.29, 0.5, -0.05)), Vector3(0.05, 0.05, 0.6))
		Role.FIRE:
			batch.cylinder(material, EXTINGUISHER_COLOR, _at(xform, Vector3(0.29, 0.62, -0.18)), 0.07, 0.07, 0.4, 8)
		Role.HANDLER:
			# Both hands free for the wheel: a stripe of compound colour is painted on the wheel prop itself.
			pass
		Role.ENGINEER:
			batch.box(material, Color("#1d2430"), _at(xform, Vector3(0.0, 1.25, -0.2)), Vector3(0.3, 0.2, 0.03))


static func _at(xform: Transform3D, local: Vector3) -> Transform3D:
	return Transform3D(xform.basis, xform * local)
