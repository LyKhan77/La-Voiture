class_name GtRng
extends RefCounted

## mulberry32, the reference's `createRng`: the same seed gives the same race.

var _a: int = 0


func _init(seed_value: int = 1) -> void:
	_a = seed_value & 0xFFFFFFFF


## Uniform float in [0, 1).
func next() -> float:
	_a = (_a + 0x6D2B79F5) & 0xFFFFFFFF
	var t: int = _a
	t = _imul(t ^ (t >> 15), t | 1)
	t = (t ^ (t + _imul(t ^ (t >> 7), t | 61))) & 0xFFFFFFFF
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0


func range_int(from: int, to_inclusive: int) -> int:
	return from + int(floor(next() * float(to_inclusive - from + 1)))


## 32-bit signed multiply, as Math.imul, returned as an unsigned 32-bit value.
static func _imul(a: int, b: int) -> int:
	return ((a & 0xFFFFFFFF) * (b & 0xFFFFFFFF)) & 0xFFFFFFFF
