class_name EnhancedTrackGeometry
extends RefCounted

## Procedural track surface geometry (FASE 10): FIA-style 3D sawtooth kerbs, tarmac
## runoff with a blue/white warning edge, gravel traps on the outside of sharp corners
## and the rubber groove along the adaptive racing line. Everything reads the ribbon
## through get_point_at_offset, never edits it, and sits at or above Y = 0 with the
## kerb crest capped at KERB_HEIGHT_M, so the car suspension calibration is untouched.

const TrackRibbonScript := preload("res://scripts/car/track_ribbon.gd")
const AdaptiveLineScript := preload("res://scripts/car/adaptive_racing_line.gd")

# --- kerbs ---------------------------------------------------------------------
## The kerb starts this far inside the road edge, clear of the painted edge line.
const KERB_INSET_M: float = 0.2
const KERB_WIDTH_M: float = 1.2
## Crest sits this far from the track edge of the kerb; it then falls away toward the gravel.
const KERB_CREST_AT_M: float = 0.4
const KERB_HEIGHT_M: float = 0.05
const KERB_STRIPE_M: float = 1.5
## The outer edge of every stripe trails the inner edge: the serrated tooth.
const KERB_SLANT_M: float = 0.5
## Kerb cross-section as (distance from the inner edge, height).
const KERB_PROFILE: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(KERB_CREST_AT_M, KERB_HEIGHT_M), Vector2(KERB_WIDTH_M, 0.0)]

const KERB_RED := Color("#d9232e")
const KERB_WHITE := Color("#f0f2f5")

# --- runoff and gravel ---------------------------------------------------------
const RUNOFF_WIDTH_M: float = 6.0
const GRAVEL_WIDTH_M: float = 8.0
## The strips fan in and out over TAPER_M and start/end RUNOFF_PAD_M beyond the kerb run.
const RUNOFF_PAD_M: float = 10.0
const TAPER_M: float = 14.0
const PLAN_STEP_M: float = 3.0
## Smallest rail distance the search for room will return, and its step.
const MIN_EXTENT_M: float = 1.2
const EXTENT_SEARCH_STEP_M: float = 0.25
## Room kept for the guardrail behind a trap: the rail stands this far outside the trap edge (see
## TracksideFurnitureBuilder.ARMCO_BEHIND_TRAP_M) plus a little slack, and must still be on its own side of the gap.
const BARRIER_ROOM_M: float = 1.8
## A neighbouring stretch must be this far along the lap before it counts as "another road".
const OTHER_ROAD_ARC_M: float = 90.0
const MIN_STRIP_M: float = 2.0
const GATE_RAMP_M: float = 20.0
const WARNING_STRIPE_M: float = 0.8
const RUNOFF_Y: float = 0.008
const WARNING_Y: float = 0.010
const GRAVEL_Y: float = 0.006
## Another stretch of road this close (centre to centre) is "a neighbour"; wide enough that a full-width
## trap (7 + 14 + 1.5 m each side) never meets one unnoticed.
const CLEARANCE_CELL_M: float = 48.0
const CLEARANCE_SAMPLE_M: float = 6.0

const RUNOFF_COLOR := Color("#8b8f9a")
const WARNING_BLUE := Color("#2f6fe0")
const GRAVEL_COLOR := Color("#A69477")

# --- rubber groove -------------------------------------------------------------
const GROOVE_HALF_WIDTH_M: float = 0.9
const GROOVE_Y: float = 0.012
const GROOVE_STEP_M: float = 3.0
const GROOVE_COLOR := Color(0.015, 0.015, 0.02)
## Rubber alpha on a straight and in a full-grip corner (|kappa| >= GROOVE_FULL_KAPPA).
const GROOVE_ALPHA_STRAIGHT: float = 0.16
const GROOVE_ALPHA_CORNER: float = 0.42
const GROOVE_FULL_KAPPA: float = 0.02


# --- kerbs -----------------------------------------------------------------------

## Two surfaces, red then white, striped every KERB_STRIPE_M along each run of `kerbs`.
## `inner_m` is the lateral distance of the kerb's track-side edge from the centreline.
static func kerb_mesh(ribbon: TrackRibbonScript, kerbs: Array[Dictionary], inner_m: float) -> ArrayMesh:
	var red := SurfaceTool.new()
	var white := SurfaceTool.new()
	for surface: SurfaceTool in [red, white]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for kerb: Dictionary in kerbs:
		var side: float = kerb["side"]
		var s: float = float(kerb["s0"])
		var index: int = 0
		while s + KERB_STRIPE_M <= float(kerb["s1"]):
			var target: SurfaceTool = red if index % 2 == 0 else white
			for facet: int in range(KERB_PROFILE.size() - 1):
				var d0: Vector2 = KERB_PROFILE[facet]
				var d1: Vector2 = KERB_PROFILE[facet + 1]
				var a0: Vector3 = _kerb_point(ribbon, s, side, inner_m, d0)
				var a1: Vector3 = _kerb_point(ribbon, s, side, inner_m, d1)
				var b0: Vector3 = _kerb_point(ribbon, s + KERB_STRIPE_M, side, inner_m, d0)
				var b1: Vector3 = _kerb_point(ribbon, s + KERB_STRIPE_M, side, inner_m, d1)
				# Same winding as the flat kerb: low lateral first, top facing front.
				var corners: Array[Vector3] = []
				if side > 0.0:
					corners = [a0, b0, b1, a0, b1, a1]
				else:
					corners = [a1, b1, b0, a1, b0, a0]
				_emit_flat(target, corners)
			s += KERB_STRIPE_M
			index += 1
	var mesh := ArrayMesh.new()
	red.commit(mesh)
	white.commit(mesh)
	return mesh


static func _kerb_point(ribbon: TrackRibbonScript, s: float, side: float, inner_m: float, profile: Vector2) -> Vector3:
	var along: float = s + KERB_SLANT_M * profile.x / KERB_WIDTH_M
	return ribbon.get_point_at_offset(along, side * (inner_m + profile.x)).origin + Vector3.UP * profile.y


## Adds triangles with one flat, upward normal each.
static func _emit_flat(st: SurfaceTool, vertices: Array[Vector3]) -> void:
	for index: int in range(0, vertices.size(), 3):
		var normal: Vector3 = (vertices[index + 1] - vertices[index]).cross(vertices[index + 2] - vertices[index]).normalized()
		if normal.y < 0.0:
			normal = -normal
		for corner: int in range(3):
			st.set_normal(normal)
			st.add_vertex(vertices[index + corner])


# --- runoff and gravel ---------------------------------------------------------------

## One plan per sharp corner: the free outside width sampled every PLAN_STEP_M.
## Dictionary: s0, s1, side (lateral sign of the outside), widths, length.
## `pit_start_s`/`pit_len_m` close the right-hand side (the pit lane's) over that arc.
static func plan_runoffs(ribbon: TrackRibbonScript, kerbs: Array[Dictionary], pit_start_s: float = 0.0, pit_len_m: float = 0.0) -> Array[Dictionary]:
	var samples: Dictionary = hash_samples(ribbon)
	var half: float = ribbon.road_half_width_m
	var plans: Array[Dictionary] = []
	for kerb: Dictionary in kerbs:
		var side: float = -float(kerb["side"])
		var a: float = float(kerb["s0"]) - RUNOFF_PAD_M
		var b: float = float(kerb["s1"]) + RUNOFF_PAD_M
		var count: int = ceili((b - a) / PLAN_STEP_M) + 1
		var widths := PackedFloat32Array()
		widths.resize(count)
		for index: int in range(count):
			var s: float = a + PLAN_STEP_M * float(index)
			var pose: Transform3D = ribbon.get_point_at_offset(s, 0.0)
			# Beside another stretch of road the trap and its guardrail share the gap: the rail must stay on this
			# road's side of the middle, so the trap gets what is left of that room after the rail's own share.
			var free: float = max_extent(samples, ribbon, s, side, RUNOFF_WIDTH_M + GRAVEL_WIDTH_M + BARRIER_ROOM_M) - BARRIER_ROOM_M
			var taper: float = smoothstep(a, a + TAPER_M, s) * smoothstep(b, b - TAPER_M, s)
			var gate: float = _pit_gate(s, ribbon.length_m, pit_start_s, pit_len_m) if side > 0.0 and pit_len_m > 0.0 else 1.0
			var total: float = clampf(free, 0.0, RUNOFF_WIDTH_M + GRAVEL_WIDTH_M) * taper * gate
			widths[index] = total if total >= MIN_STRIP_M else 0.0
		plans.append({"s0": a, "s1": b, "side": side, "widths": widths, "length": ribbon.length_m})
	return plans


## Free width (m) beyond the road edge on the plan's outside at arc distance s; 0 outside the plan.
static func plan_width_at(plan: Dictionary, s: float) -> float:
	var widths: PackedFloat32Array = plan["widths"]
	var rel: float = fposmod(s - float(plan["s0"]), float(plan["length"]))
	if rel > float(plan["s1"]) - float(plan["s0"]):
		return 0.0
	var position: float = rel / PLAN_STEP_M
	var index: int = mini(int(position), widths.size() - 1)
	return lerpf(widths[index], widths[mini(index + 1, widths.size() - 1)], position - float(index))


## Free outside width at s on the given side (-1 left, +1 right), the widest plan wins.
static func outside_width_at(plans: Array[Dictionary], side: float, s: float) -> float:
	var best: float = 0.0
	for plan: Dictionary in plans:
		if float(plan["side"]) == side:
			best = maxf(best, plan_width_at(plan, s))
	return best


## surface 0 tarmac, 1 blue and 2 white warning dashes.
static func runoff_mesh(ribbon: TrackRibbonScript, plans: Array[Dictionary]) -> ArrayMesh:
	var half: float = ribbon.road_half_width_m
	var tarmac := SurfaceTool.new()
	var blue := SurfaceTool.new()
	var white := SurfaceTool.new()
	for surface: SurfaceTool in [tarmac, blue, white]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_normal(Vector3.UP)
	for plan: Dictionary in plans:
		var widths: PackedFloat32Array = plan["widths"]
		for index: int in range(widths.size() - 1):
			var ra: float = _runoff_part(widths[index])
			var rb: float = _runoff_part(widths[index + 1])
			if ra <= 0.0 and rb <= 0.0:
				continue
			var sa: float = float(plan["s0"]) + PLAN_STEP_M * float(index)
			_band(tarmac, ribbon, plan, sa, half, half + ra, half, half + rb, RUNOFF_Y)
			if ra >= 2.0 * WARNING_STRIPE_M and rb >= 2.0 * WARNING_STRIPE_M:
				_band(blue if index % 2 == 0 else white, ribbon, plan, sa, half + ra - WARNING_STRIPE_M, half + ra, half + rb - WARNING_STRIPE_M, half + rb, WARNING_Y)
	var mesh := ArrayMesh.new()
	tarmac.commit(mesh)
	blue.commit(mesh)
	white.commit(mesh)
	return mesh


static func gravel_mesh(ribbon: TrackRibbonScript, plans: Array[Dictionary]) -> ArrayMesh:
	var half: float = ribbon.road_half_width_m
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for plan: Dictionary in plans:
		var widths: PackedFloat32Array = plan["widths"]
		for index: int in range(widths.size() - 1):
			var ia: float = _runoff_part(widths[index])
			var ib: float = _runoff_part(widths[index + 1])
			var oa: float = widths[index]
			var ob: float = widths[index + 1]
			if oa <= 0.0 and ob <= 0.0:
				continue
			_band(st, ribbon, plan, float(plan["s0"]) + PLAN_STEP_M * float(index), half + ia, half + oa, half + ib, half + ob, GRAVEL_Y)
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	return mesh


## Tarmac share of the free width: the tarmac comes first, gravel takes the rest.
static func _runoff_part(total: float) -> float:
	return total * RUNOFF_WIDTH_M / (RUNOFF_WIDTH_M + GRAVEL_WIDTH_M)


## Quad between distances `in_a`/`out_a` (arc sa) and `in_b`/`out_b` (arc sa + PLAN_STEP_M), measured outward from the centreline.
static func _band(
	st: SurfaceTool, ribbon: TrackRibbonScript, plan: Dictionary, sa: float,
	in_a: float, out_a: float, in_b: float, out_b: float, y: float
) -> void:
	var side: float = plan["side"]
	var sb: float = sa + PLAN_STEP_M
	# strip_mesh winding: lower lateral first. Outside right: inner is the lower lateral; outside left: outer is.
	var lo_a: float = side * (in_a if side > 0.0 else out_a)
	var hi_a: float = side * (out_a if side > 0.0 else in_a)
	var lo_b: float = side * (in_b if side > 0.0 else out_b)
	var hi_b: float = side * (out_b if side > 0.0 else in_b)
	var left_a: Vector3 = ribbon.get_point_at_offset(sa, lo_a).origin + Vector3.UP * y
	var right_a: Vector3 = ribbon.get_point_at_offset(sa, hi_a).origin + Vector3.UP * y
	var left_b: Vector3 = ribbon.get_point_at_offset(sb, lo_b).origin + Vector3.UP * y
	var right_b: Vector3 = ribbon.get_point_at_offset(sb, hi_b).origin + Vector3.UP * y
	for v: Vector3 in [left_a, left_b, right_b, left_a, right_b, right_a]:
		st.add_vertex(v)


## 0 inside the closed arc, ramping to 1 over GATE_RAMP_M either side of it.
static func _pit_gate(s: float, length: float, start: float, zone: float) -> float:
	var r: float = fposmod(s - start, length)
	if r < zone:
		return 0.0
	return smoothstep(0.0, GATE_RAMP_M, minf(length - r, r - zone))


## Grid hash of centreline samples as Vector3(x, arc, z), for "is another road near this strip".
static func hash_samples(ribbon: TrackRibbonScript) -> Dictionary:
	var cells: Dictionary = {}
	var s: float = 0.0
	while s < ribbon.length_m:
		var point: Vector3 = ribbon.get_point_at_offset(s, 0.0).origin
		var key := Vector2i(floori(point.x / CLEARANCE_CELL_M), floori(point.z / CLEARANCE_CELL_M))
		if not cells.has(key):
			cells[key] = PackedVector3Array()
		cells[key].append(Vector3(point.x, s, point.z))
		s += CLEARANCE_SAMPLE_M
	return cells


## Largest distance `e` (m beyond the road edge, at most `wanted`) at which a barrier at arc distance s
## on `side` still belongs to its own road: it may reach the middle of the gap to another stretch of
## road, never cross it. Returns `wanted` unless another road is close (so most calls cost one lookup).
static func max_extent(cells: Dictionary, ribbon: TrackRibbonScript, s: float, side: float, wanted: float) -> float:
	var pose: Transform3D = ribbon.get_point_at_offset(s, 0.0)
	var half: float = ribbon.road_half_width_m
	var e: float = wanted
	while e > MIN_EXTENT_M:
		var point: Vector3 = pose.origin + pose.basis.x * side * (half + e)
		if half + e <= other_road_distance(cells, ribbon, s, point):
			return e
		e -= EXTENT_SEARCH_STEP_M
	return MIN_EXTENT_M


## Distance on the ground plane from `point` to the nearest centreline sample on a different stretch of
## road than the one at arc distance `s` (INF when none within reach).
static func other_road_distance(cells: Dictionary, ribbon: TrackRibbonScript, s: float, point: Vector3) -> float:
	var best: float = INF
	var cx: int = floori(point.x / CLEARANCE_CELL_M)
	var cz: int = floori(point.z / CLEARANCE_CELL_M)
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			if not cells.has(key):
				continue
			for sample: Vector3 in cells[key]:
				var arc: float = absf(fposmod(sample.y - s + ribbon.length_m * 0.5, ribbon.length_m) - ribbon.length_m * 0.5)
				if arc < OTHER_ROAD_ARC_M:
					continue
				best = minf(best, Vector2(sample.x - point.x, sample.z - point.z).length())
	return best


# --- rubber groove ---------------------------------------------------------------------

## Dark rubber band along the adaptive racing line; vertex alpha deepens through corners.
static func groove_mesh(ribbon: TrackRibbonScript, line: AdaptiveLineScript) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var count: int = ceili(ribbon.length_m / GROOVE_STEP_M)
	for index: int in range(count):
		var sa: float = ribbon.length_m * float(index) / float(count)
		var sb: float = ribbon.length_m * float(index + 1) / float(count)
		var corners: Array[Vector3] = []
		var alphas: Array[float] = []
		for s: float in [sa, sb]:
			var centre: float = line.target_offset(s)
			for lateral: float in [centre - GROOVE_HALF_WIDTH_M, centre + GROOVE_HALF_WIDTH_M]:
				corners.append(ribbon.get_point_at_offset(s, lateral).origin + Vector3.UP * GROOVE_Y)
				alphas.append(lerpf(GROOVE_ALPHA_STRAIGHT, GROOVE_ALPHA_CORNER, clampf(absf(line.curvature_at(s)) / GROOVE_FULL_KAPPA, 0.0, 1.0)))
		# corners: left_a, right_a, left_b, right_b
		for slot: int in [0, 2, 3, 0, 3, 1]:
			st.set_color(Color(GROOVE_COLOR, alphas[slot]))
			st.add_vertex(corners[slot])
	return st.commit()
