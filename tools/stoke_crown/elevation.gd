extends RefCounted

## Smoothstep height between authored (s, y) keys, matching the builders'
## `elevation_at`. Keys are authored on the finished lap in metres.


static func height_at(samples: Array, length: float, distance: float) -> float:
	if samples.size() < 2 or length <= 0.0:
		return 0.0
	var s: float = fposmod(distance, length)
	for index: int in range(samples.size() - 1):
		var a: Array = samples[index]
		var b: Array = samples[index + 1]
		var s0: float = float(a[0])
		var s1: float = float(b[0])
		if s >= s0 - 1.0e-9 and s <= s1 + 1.0e-9:
			var t: float = inverse_lerp(s0, s1, s) if s1 > s0 else 0.0
			var y0: float = float(a[1])
			var y1: float = float(b[1])
			return lerpf(y0, y1, t * t * (3.0 - 2.0 * t))
	return 0.0
