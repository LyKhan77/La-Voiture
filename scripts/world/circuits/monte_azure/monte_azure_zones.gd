class_name MonteAzureZones
extends RefCounted

## The blueprint's environment strip (`final/environment_strip.json`) as data: which kind of ground and dressing lies
## beside the road at a given arc distance and side. Read it per NEAREST road station, never as a rectangle projected
## across the loop: the loop is only ~600 m across, so the R "urban 240-680, 300 m deep" band, projected sideways, lands on
## the climb past the casino (road s 809-1026). The nearest-leg rule keeps every leg to its own band.

## {s0, s1, side (+1 right / inside of the loop, -1 left / harbour), zone, offset_m, depth_m, height_m, density}.
const SEGMENTS: Array[Dictionary] = [
	{"s0": 0.0, "s1": 480.0, "side": -1.0, "zone": "water", "offset_m": 24.0, "depth_m": 320.0, "height_m": 0.0, "density": 1.0},
	{"s0": 480.0, "s1": 1020.0, "side": -1.0, "zone": "urban", "offset_m": 12.0, "depth_m": 260.0, "height_m": 45.0, "density": 0.9},
	{"s0": 1020.0, "s1": 1580.0, "side": -1.0, "zone": "forest", "offset_m": 10.0, "depth_m": 200.0, "height_m": 12.0, "density": 0.7},
	{"s0": 1580.0, "s1": 2850.0, "side": -1.0, "zone": "water", "offset_m": 22.0, "depth_m": 300.0, "height_m": 0.0, "density": 1.0},
	{"s0": 240.0, "s1": 680.0, "side": 1.0, "zone": "urban", "offset_m": 10.0, "depth_m": 300.0, "height_m": 40.0, "density": 0.9},
	{"s0": 680.0, "s1": 1200.0, "side": 1.0, "zone": "forest", "offset_m": 10.0, "depth_m": 240.0, "height_m": 12.0, "density": 0.7},
	{"s0": 1200.0, "s1": 1760.0, "side": 1.0, "zone": "urban", "offset_m": 10.0, "depth_m": 320.0, "height_m": 48.0, "density": 0.9},
	{"s0": 1760.0, "s1": 2140.0, "side": 1.0, "zone": "paddock", "offset_m": 26.0, "depth_m": 220.0, "height_m": 8.0, "density": 0.5},
	{"s0": 2190.0, "s1": 2850.0, "side": 1.0, "zone": "paddock", "offset_m": 24.0, "depth_m": 200.0, "height_m": 8.0, "density": 0.5},
]
## Where no strip band covers a side (the pit side before s=240, the gap 2140-2190), the ground is paddock deck.
const DEFAULT_ZONE := "paddock"


## The strip segment at arc `s` on `side` (+1 right, -1 left); empty when no band covers it.
static func segment_at(s: float, side: float) -> Dictionary:
	for segment: Dictionary in SEGMENTS:
		if signf(float(segment["side"])) == signf(side) and s >= float(segment["s0"]) and s < float(segment["s1"]):
			return segment
	return {}


static func zone_at(s: float, side: float) -> String:
	var segment: Dictionary = segment_at(s, side)
	return String(segment["zone"]) if not segment.is_empty() else DEFAULT_ZONE
