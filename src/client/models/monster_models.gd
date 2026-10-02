class_name MonsterModels
extends RefCounted
## The monsters' voxel models, in parts that move (see CreatureModels): the
## lantern moth (a furry body, broad pale wings with glowing eyespots, plumed
## antennae), the shade lurker (a tall hunched shadow, long arms, two pale
## eyes), the rock mimic (a mossy boulder on six stone legs, with amber eyes
## and a jagged mouth that only show awake) and the will-o'-wisp (a glowing
## orb trailing flames). Glowing voxels light themselves.

const MOTH_FUR := ["#8a7c66", "#a8987e", "#c8b99c", "#e0d4bb"]
const MOTH_WING := "#e6dcc4"
const MOTH_EDGE := "#7a5a3c"
const MOTH_SPOT := "#9fd8ff"
const MOTH_RING := "#2c3550"
const SHADE := ["#0c0912", "#151020", "#1f1830", "#2a2142"]
const SHADE_EYE := "#d8f4ff"
const STONE := ["#4a4954", "#5c5b66", "#7c7b87", "#9d9ca7"]
const MOSS := "#4f7a34"
const MIMIC_EYE := "#ffb030"
const WISP := ["#8ee060", "#c8ff8a", "#f4ffd0"]


static func build(kind: int) -> Array:
	match kind:
		Species.Id.LANTERN_MOTH:
			return _moth()
		Species.Id.SHADE_LURKER:
			return _lurker()
		Species.Id.ROCK_MIMIC:
			return _mimic()
	return _wisp()


static func _v(hex: String, kind := VoxelGrid.Kind.SOLID) -> int:
	return VoxelGrid.voxel(Color(hex), kind)


static func _glow(hex: String) -> int:
	return _v(hex, VoxelGrid.Kind.GLOW)


static func _noise(p: Vector3i, salt: int) -> float:
	return HashUtil.unit2(salt + p.z * 7919, p.x, p.y)


## Paints from a palette (dark to light) in blotches, lighter higher up.
static func _shaded(palette: Array, low: float, high: float, salt: int) -> Callable:
	var values: Array[int] = []
	for hex: String in palette:
		values.append(_v(hex))
	var last := values.size() - 1
	return func(p: Vector3i) -> int:
		var t := clampf((p.y - low) / maxf(1.0, high - low), 0.0, 1.0)
		var n := _noise(p / 2, salt)
		return values[clampi(int(t * last + (n - 0.5) * 1.6 + 0.5), 0, last)]


# ---------------------------------------------------------------- moth


static func _moth() -> Array:
	var parts: Array = []
	var body := VoxelGrid.new(Vector3i(5, 8, 12))
	var fur := _shaded(MOTH_FUR, 0.0, 4.0, 43)
	# A striped abdomen, a fluffy thorax, a small head with plumed antennae.
	body.ellipsoid(Vector3(2.5, 2.0, 3.5), Vector3(1.7, 1.7, 3.4), fur)
	for z in [1, 3, 5]:
		for x in 5:
			for y in 4:
				if body.get_voxel(Vector3i(x, y, z)) != 0:
					body.set_voxel(Vector3i(x, y, z), _v("#6a5c48"))
	body.ellipsoid(Vector3(2.5, 2.4, 7.5), Vector3(2.1, 2.0, 1.8), fur)
	body.box(Vector3i(2, 2, 9), Vector3i(3, 3, 10), _v("#5a4a3a"))
	body.set_voxel(Vector3i(1, 3, 10), _glow("#203048"))
	body.set_voxel(Vector3i(4, 3, 10), _glow("#203048"))
	for side: int in [-1, 1]:
		var x := 2 if side < 0 else 3
		body.line(Vector3(x, 3.5, 10), Vector3(x + side * 1.5, 7.2, 11.5), 0.4, _v("#8a7458"))
	parts.append(CreatureModels.make_part("body", body, Vector3(-2.5, 3.0, -6.0), Vector3(0, 4, 0)))
	for side in [["wing_l", -1], ["wing_r", 1]]:
		var wing := VoxelGrid.new(Vector3i(10, 1, 11))
		for x in 10:
			for z in 11:
				# Broad at the front, narrowing back; the outer edge rounded.
				var reach := 10.0 - absf(z - 6.5) * 0.6 - (0.0 if z > 3 else (3 - z) * 0.8)
				if x >= reach:
					continue
				var edge := x >= reach - 1.0 or z == 0 or z == 10
				var hex := MOTH_EDGE if edge else MOTH_WING
				if (x + z) % 5 == 0 and not edge:
					hex = "#cfc2a6"
				wing.set_voxel(Vector3i(x, 0, z), _v(hex))
		# The eyespot: a dark ring round a glowing blue heart.
		for x in range(4, 8):
			for z in range(5, 9):
				var d := Vector2(x - 5.5, z - 6.5).length()
				if d < 1.0:
					wing.set_voxel(Vector3i(x, 0, z), _glow(MOTH_SPOT))
				elif d < 2.0:
					wing.set_voxel(Vector3i(x, 0, z), _v(MOTH_RING))
		if side[1] < 0:
			wing = _mirror_x(wing)
		var corner := Vector3(-10.5 if side[1] < 0 else 0.5, 6.0, -3.5)
		var joint := Vector3(-0.5 if side[1] < 0 else 0.5, 6.0, 1.5)
		parts.append(CreatureModels.make_part(side[0], wing, corner, joint))
	return parts


## The grid turned over left to right.
static func _mirror_x(grid: VoxelGrid) -> VoxelGrid:
	var mirrored := VoxelGrid.new(grid.size)
	for z in grid.size.z:
		for y in grid.size.y:
			for x in grid.size.x:
				mirrored.set_voxel(
					Vector3i(grid.size.x - 1 - x, y, z), grid.get_voxel(Vector3i(x, y, z))
				)
	return mirrored


# ---------------------------------------------------------------- lurker


static func _lurker() -> Array:
	var parts: Array = []
	var dark := _shaded(SHADE, 0.0, 12.0, 47)
	for side in [["leg_l", -2.0], ["leg_r", 2.0]]:
		var leg := VoxelGrid.new(Vector3i(3, 12, 3))
		leg.box(Vector3i(0, 0, 0), Vector3i(2, 11, 2), dark)
		leg.box(Vector3i(0, 0, 2), Vector3i(2, 0, 3), _v(SHADE[0]))
		var hip := Vector3(side[1], 12.0, 0.0)
		parts.append(CreatureModels.make_part(side[0], leg, hip - Vector3(1.5, 12.0, 1.5), hip))
	# A hunched body leaning forward, ragged at its edges.
	var torso := VoxelGrid.new(Vector3i(10, 11, 8))
	for y in 11:
		var lean := y / 3
		for x in range(1, 9):
			for z in range(lean, lean + 4):
				var edge := x == 1 or x == 8 or z == lean
				if edge and _noise(Vector3i(x, y, z), 51) < 0.3:
					continue
				torso.set_voxel(Vector3i(x, y, z), dark.call(Vector3i(x, y, z)))
	parts.append(
		CreatureModels.make_part("body", torso, Vector3(-5.0, 11.0, -2.0), Vector3(0, 11, 0))
	)
	# A hooded head, two pale eyes in the dark of the hood.
	var head := VoxelGrid.new(Vector3i(7, 7, 7))
	head.ellipsoid(Vector3(3.5, 3.4, 3.2), Vector3(3.3, 3.4, 3.2), dark)
	head.box(Vector3i(2, 1, 6), Vector3i(4, 3, 6), _v(SHADE[0]))
	head.set_voxel(Vector3i(2, 3, 6), _glow(SHADE_EYE))
	head.set_voxel(Vector3i(4, 3, 6), _glow(SHADE_EYE))
	parts.append(
		CreatureModels.make_part("head", head, Vector3(-3.5, 21.0, 0.0), Vector3(0, 22, 2))
	)
	for side in [["arm_l", -5.0], ["arm_r", 5.0]]:
		var arm := VoxelGrid.new(Vector3i(2, 15, 2))
		arm.box(Vector3i(0, 2, 0), Vector3i(1, 14, 1), dark)
		# Long pale claws.
		arm.box(Vector3i(0, 0, 1), Vector3i(1, 1, 1), _v("#6e6280"))
		var shoulder := Vector3(side[1], 20.0, 1.0)
		parts.append(
			CreatureModels.make_part(side[0], arm, shoulder - Vector3(1.0, 15.0, 1.0), shoulder)
		)
	return parts


# ---------------------------------------------------------------- mimic


## A mossy boulder; awake, it stands on six legs, its eyes and mouth open
## (the parts "legs" and "face" show only then: CreatureBody).
static func _mimic() -> Array:
	var parts: Array = []
	var shell := VoxelGrid.new(Vector3i(14, 10, 14))
	var stone := _shaded(STONE, 0.0, 9.0, 53)
	for z in 14:
		for y in 10:
			for x in 14:
				var p := Vector3i(x, y, z)
				var d := (
					(Vector3(p) + Vector3.ONE * 0.5 - Vector3(7, 3.6, 7)) / Vector3(6.6, 5.0, 6.6)
				)
				var lump := (_noise(p / 2, 59) - 0.5) * 0.35
				if d.length_squared() <= 1.0 + lump and y >= 0:
					var hex_moss := y >= 7 and _noise(p, 61) < 0.45
					shell.set_voxel(p, _v(MOSS) if hex_moss else stone.call(p))
	parts.append(
		CreatureModels.make_part("body", shell, Vector3(-7.0, 4.0, -7.0), Vector3(0, 4, 0))
	)
	var face := VoxelGrid.new(Vector3i(9, 5, 1))
	face.box(Vector3i(1, 0, 0), Vector3i(7, 1, 0), _v("#1a1416"))
	for x in [1, 3, 5, 7]:
		face.set_voxel(Vector3i(x, 1, 0), _v("#e8e0cc"))
	face.box(Vector3i(1, 3, 0), Vector3i(2, 4, 0), _glow(MIMIC_EYE))
	face.box(Vector3i(6, 3, 0), Vector3i(7, 4, 0), _glow(MIMIC_EYE))
	parts.append(CreatureModels.make_part("face", face, Vector3(-4.5, 6.0, 6.6), Vector3(0, 4, 0)))
	for i in 6:
		var leg := VoxelGrid.new(Vector3i(1, 5, 1))
		leg.box(Vector3i.ZERO, Vector3i(0, 4, 0), stone)
		leg.set_voxel(Vector3i.ZERO, _v("#2c2b33"))
		var x := -6.0 if i < 3 else 6.0
		var hip := Vector3(x, 5.0, -4.0 + (i % 3) * 4.0)
		parts.append(
			CreatureModels.make_part("leg_%d" % (i + 1), leg, hip - Vector3(0.5, 5.0, 0.5), hip)
		)
	return parts


# ---------------------------------------------------------------- wisp


## A glowing orb, bright at its heart, flames flickering up from it.
static func _wisp() -> Array:
	var orb := VoxelGrid.new(Vector3i(6, 9, 6))
	orb.ellipsoid(Vector3(3, 3, 3), Vector3(2.6, 2.6, 2.6), _glow(WISP[0]))
	orb.ellipsoid(Vector3(3, 3, 3), Vector3(1.7, 1.7, 1.7), _glow(WISP[1]))
	orb.box(Vector3i(2, 2, 2), Vector3i(3, 3, 3), _glow(WISP[2]))
	var flames: Array[Vector3i] = [
		Vector3i(2, 6, 3), Vector3i(3, 7, 2), Vector3i(3, 6, 3), Vector3i(4, 8, 3)
	]
	for flame in flames:
		orb.set_voxel(flame, _glow(WISP[1] if flame.y < 7 else WISP[0]))
	return [CreatureModels.make_part("body", orb, Vector3(-3.0, 0.0, -3.0), Vector3(0, 3, 0))]
