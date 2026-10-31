class_name ArdennesZones
extends RefCounted

## The blueprint's environment strip (`final/environment_strip.json`) as data: which kind of ground and dressing lies beside
## the road at a given arc distance and side. Read it per NEAREST road station, never as a rectangle projected across the loop:
## the Ardennes loop folds back on itself, so the L "forest 2750-3700, 350 m deep" band projected sideways reaches the road at
## s 4022-4113 and the L "forest 3700-4800" band the road at s 3444-3480. The nearest-leg rule keeps every leg to its own band.

## {s0, s1, side (+1 right / -1 left), zone, offset_m, depth_m, height_m, density}.
const SEGMENTS: Array[Dictionary] = [
	{"s0": 0.0, "s1": 450.0, "side": -1.0, "zone": "urban", "offset_m": 20.0, "depth_m": 180.0, "height_m": 25.0, "density": 0.8},
	{"s0": 450.0, "s1": 920.0, "side": -1.0, "zone": "water", "offset_m": 18.0, "depth_m": 250.0, "height_m": 0.0, "density": 1.0},
	{"s0": 920.0, "s1": 1850.0, "side": -1.0, "zone": "forest", "offset_m": 14.0, "depth_m": 350.0, "height_m": 28.0, "density": 0.85},
	{"s0": 1850.0, "s1": 2750.0, "side": -1.0, "zone": "forest", "offset_m": 14.0, "depth_m": 300.0, "height_m": 26.0, "density": 0.8},
	{"s0": 2750.0, "s1": 3700.0, "side": -1.0, "zone": "forest", "offset_m": 14.0, "depth_m": 350.0, "height_m": 28.0, "density": 0.85},
	{"s0": 3700.0, "s1": 4800.0, "side": -1.0, "zone": "forest", "offset_m": 14.0, "depth_m": 320.0, "height_m": 26.0, "density": 0.8},
	{"s0": 4800.0, "s1": 5400.0, "side": -1.0, "zone": "urban", "offset_m": 18.0, "depth_m": 220.0, "height_m": 28.0, "density": 0.9},
	{"s0": 0.0, "s1": 520.0, "side": 1.0, "zone": "paddock", "offset_m": 22.0, "depth_m": 200.0, "height_m": 12.0, "density": 0.6},
	{"s0": 520.0, "s1": 1020.0, "side": 1.0, "zone": "rock", "offset_m": 14.0, "depth_m": 280.0, "height_m": 45.0, "density": 0.9},
	{"s0": 1020.0, "s1": 1900.0, "side": 1.0, "zone": "forest", "offset_m": 14.0, "depth_m": 350.0, "height_m": 28.0, "density": 0.85},
	{"s0": 1900.0, "s1": 2800.0, "side": 1.0, "zone": "rock", "offset_m": 16.0, "depth_m": 260.0, "height_m": 35.0, "density": 0.8},
	{"s0": 2800.0, "s1": 3700.0, "side": 1.0, "zone": "forest", "offset_m": 14.0, "depth_m": 350.0, "height_m": 28.0, "density": 0.85},
	{"s0": 3700.0, "s1": 4900.0, "side": 1.0, "zone": "forest", "offset_m": 14.0, "depth_m": 320.0, "height_m": 26.0, "density": 0.8},
	{"s0": 4900.0, "s1": 5400.0, "side": 1.0, "zone": "paddock", "offset_m": 20.0, "depth_m": 220.0, "height_m": 12.0, "density": 0.6},
]
## Where no strip band covers a side, the ground is forest (the strip covers both sides of the whole lap, so this is a guard).
const DEFAULT_ZONE := "forest"


## The strip segment at arc `s` on `side` (+1 right, -1 left); empty when no band covers it.
static func segment_at(s: float, side: float) -> Dictionary:
	for segment: Dictionary in SEGMENTS:
		if signf(float(segment["side"])) == signf(side) and s >= float(segment["s0"]) and s < float(segment["s1"]):
			return segment
	return {}


static func zone_at(s: float, side: float) -> String:
	var segment: Dictionary = segment_at(s, side)
	return String(segment["zone"]) if not segment.is_empty() else DEFAULT_ZONE


## Tree and rock density (0..1) of the band at (s, side).
static func density_at(s: float, side: float) -> float:
	var segment: Dictionary = segment_at(s, side)
	return float(segment["density"]) if not segment.is_empty() else 0.8
