class_name Spline
extends RefCounted
## Monotone cubic Hermite spline (Fritsch-Carlson) through sorted points.
## Used like Minecraft's terrain splines: smooth, no overshoot between
## control points, constant beyond the first and last points.

var _xs := PackedFloat32Array()
var _ys := PackedFloat32Array()
var _ms := PackedFloat32Array()


## `points` is an Array of [x, y] pairs sorted by x.
func _init(points: Array) -> void:
	for point: Array in points:
		_xs.append(point[0])
		_ys.append(point[1])
	_compute_tangents()


func sample(x: float) -> float:
	var last := _xs.size() - 1
	if x <= _xs[0]:
		return _ys[0]
	if x >= _xs[last]:
		return _ys[last]
	var i := 0
	while x > _xs[i + 1]:
		i += 1
	var h := _xs[i + 1] - _xs[i]
	var t := (x - _xs[i]) / h
	var t2 := t * t
	var t3 := t2 * t
	return (
		(2.0 * t3 - 3.0 * t2 + 1.0) * _ys[i]
		+ (t3 - 2.0 * t2 + t) * h * _ms[i]
		+ (-2.0 * t3 + 3.0 * t2) * _ys[i + 1]
		+ (t3 - t2) * h * _ms[i + 1]
	)


func _compute_tangents() -> void:
	var n := _xs.size()
	_ms.resize(n)
	if n < 2:
		return
	var slopes := PackedFloat32Array()
	slopes.resize(n - 1)
	for i in n - 1:
		slopes[i] = (_ys[i + 1] - _ys[i]) / (_xs[i + 1] - _xs[i])
	_ms[0] = slopes[0]
	_ms[n - 1] = slopes[n - 2]
	for i in range(1, n - 1):
		if slopes[i - 1] * slopes[i] <= 0.0:
			_ms[i] = 0.0
		else:
			_ms[i] = (slopes[i - 1] + slopes[i]) * 0.5
	for i in n - 1:
		if is_zero_approx(slopes[i]):
			_ms[i] = 0.0
			_ms[i + 1] = 0.0
			continue
		var a := _ms[i] / slopes[i]
		var b := _ms[i + 1] / slopes[i]
		var length_sq := a * a + b * b
		if length_sq > 9.0:
			var tau := 3.0 / sqrt(length_sq)
			_ms[i] = tau * a * slopes[i]
			_ms[i + 1] = tau * b * slopes[i]
