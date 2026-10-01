class_name Debris
extends MultiMeshInstance3D
## Bits flying off what is being broken: tiny cubes thrown up, falling and
## shrinking away. World space (outside the stretched world root, like the
## other particles).

const MAX_BITS := 192
## World units: the size of a bit (about an art pixel) and gravity.
const SIZE := 0.075
const GRAVITY := 9.0

## One entry per bit: [position, velocity, life left, life, color].
var _bits: Array[Array] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * SIZE
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	box.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = box
	multimesh.instance_count = MAX_BITS
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rng.randomize()


## Throws `count` bits of `color` from `at` (world space); `spread` widens
## where they start (world units).
func throw(at: Vector3, color: Color, count: int, spread := 0.15) -> void:
	for i in count:
		var start := (
			at
			+ Vector3(
				_rng.randf_range(-spread, spread),
				_rng.randf_range(-spread, spread) * 0.5,
				_rng.randf_range(-spread, spread)
			)
		)
		var velocity := Vector3(
			_rng.randf_range(-1.2, 1.2), _rng.randf_range(1.2, 2.8), _rng.randf_range(-1.2, 1.2)
		)
		var shade := _rng.randf_range(0.8, 1.15)
		var life := _rng.randf_range(0.45, 0.9)
		_bits.append(
			[start, velocity, life, life, Color(color.r * shade, color.g * shade, color.b * shade)]
		)
	while _bits.size() > MAX_BITS:
		_bits.pop_front()


func _process(delta: float) -> void:
	if _bits.is_empty():
		multimesh.visible_instance_count = 0
		return
	var alive: Array[Array] = []
	for bit in _bits:
		bit[2] -= delta
		if bit[2] <= 0.0:
			continue
		bit[1].y -= GRAVITY * delta
		bit[0] += bit[1] * delta
		alive.append(bit)
	_bits = alive
	for i in _bits.size():
		var bit: Array = _bits[i]
		var size := clampf(bit[2] / bit[3] * 1.6, 0.0, 1.0)
		multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * size), bit[0]))
		multimesh.set_instance_color(i, bit[4])
	multimesh.visible_instance_count = _bits.size()
