class_name ClimateGrid
extends RefCounted
## Climate parameters sampled every GRID_STEP tiles over a rectangle, then
## bilinearly interpolated per tile. A tile always gets the same values no
## matter which rectangle it is sampled from (grid points are aligned on
## world coordinates), so chunks, maps and spawn search agree exactly.
##
## Usage: grid.sample(tx, ty), then read the five public fields.

const STEP := ClimateSampler.GRID_STEP

var continentalness := 0.0
var erosion := 0.0
var weirdness := 0.0
var temperature := 0.0
var humidity := 0.0

var _origin_x := 0
var _origin_y := 0
var _columns := 0
var _values: Array[PackedFloat32Array] = []


func _init(sampler: ClimateSampler, tile_rect: Rect2i) -> void:
	var gx0 := floori(float(tile_rect.position.x) / STEP)
	var gy0 := floori(float(tile_rect.position.y) / STEP)
	var gx1 := floori(float(tile_rect.end.x - 1) / STEP) + 1
	var gy1 := floori(float(tile_rect.end.y - 1) / STEP) + 1
	_origin_x = gx0 * STEP
	_origin_y = gy0 * STEP
	_columns = gx1 - gx0 + 1
	var rows := gy1 - gy0 + 1
	_values.resize(ClimateSampler.PARAM_COUNT)
	for param in ClimateSampler.PARAM_COUNT:
		var values := PackedFloat32Array()
		values.resize(_columns * rows)
		var index := 0
		for j in rows:
			var y := float((gy0 + j) * STEP)
			for i in _columns:
				values[index] = sampler.raw(param, float((gx0 + i) * STEP), y)
				index += 1
		_values[param] = values


func sample(tx: int, ty: int) -> void:
	var fx := float(tx - _origin_x) / STEP
	var fy := float(ty - _origin_y) / STEP
	var ix := int(fx)
	var iy := int(fy)
	var u := fx - ix
	var v := fy - iy
	var i00 := iy * _columns + ix
	var i10 := i00 + 1
	var i01 := i00 + _columns
	var i11 := i01 + 1
	continentalness = _lerp2(_values[0], i00, i10, i01, i11, u, v)
	erosion = _lerp2(_values[1], i00, i10, i01, i11, u, v)
	weirdness = _lerp2(_values[2], i00, i10, i01, i11, u, v)
	temperature = _lerp2(_values[3], i00, i10, i01, i11, u, v)
	humidity = _lerp2(_values[4], i00, i10, i01, i11, u, v)


static func _lerp2(
	values: PackedFloat32Array, i00: int, i10: int, i01: int, i11: int, u: float, v: float
) -> float:
	var top := values[i00] + (values[i10] - values[i00]) * u
	var bottom := values[i01] + (values[i11] - values[i01]) * u
	return top + (bottom - top) * v
