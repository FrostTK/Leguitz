class_name AnimalModels
extends RefCounted
## The animals' voxel models (Species), in parts that move: a body, a head
## (with the neck), legs, and for some wings, antlers. One voxel is one
## art pixel; the model stands on y = 0 and looks towards +Z. Built when
## first needed (a few small grids), not saved.


## A part of a model: its voxels, where it turns (its joint, model voxels)
## and where its mesh sits from the joint (voxels: a mesh's origin is the
## middle of its base, see VoxelMesher).
class Part:
	extends RefCounted
	var name := ""
	var grid: VoxelGrid
	var joint := Vector3.ZERO
	var offset := Vector3.ZERO


const WOOL := ["#d6ccb6", "#e9e1cf", "#f6f1e5", "#fffcf4"]
const SHEEP_FACE := ["#3b302b", "#4f413a", "#66554b"]
const BOAR_HIDE := ["#2c1f18", "#3b2a20", "#4d3729", "#634733"]
const BOAR_SNOUT := ["#8a6555", "#a87e6b"]
const TUSK := "#efe4c4"
const FOWL := ["#8f3d1c", "#b55428", "#d27434", "#e8a046"]
const FOWL_WING := ["#5e2a14", "#7a3a1e"]
const FOWL_TAIL := ["#13281d", "#1f3e2c", "#2f5c40", "#3f7a55"]
const COMB := "#d7322b"
const BEAK := "#e8b23a"
const DEER := ["#7e5432", "#996a40", "#b0804f", "#c49763"]
const DEER_BELLY := "#ecdcbd"
const ANTLER := ["#a8916a", "#cdb98f", "#e6d8b4"]
const HOOF := "#1f1714"
const EYE := "#17110f"
const EYE_SHINE := "#f4efe6"

static var _parts: Dictionary[int, Array] = {}


## The parts of a species' model (built once).
static func parts(kind: int) -> Array:
	if not _parts.has(kind):
		match kind:
			Species.Id.SHEEP:
				_parts[kind] = _sheep()
			Species.Id.BOAR:
				_parts[kind] = _boar()
			Species.Id.CHICKEN:
				_parts[kind] = _chicken()
			_:
				_parts[kind] = _deer()
	return _parts[kind]


static func _v(hex: String) -> int:
	return VoxelGrid.voxel(Color(hex))


static func _noise(p: Vector3i, salt: int) -> float:
	return HashUtil.unit2(salt + p.z * 7919, p.x, p.y)


## A part whose grid has its lowest corner at `corner` and turns about
## `joint` (model voxels).
static func _part(name: String, grid: VoxelGrid, corner: Vector3, joint: Vector3) -> Part:
	var part := Part.new()
	part.name = name
	part.grid = grid
	part.joint = joint
	part.offset = corner + Vector3(grid.size.x * 0.5, 0.0, grid.size.z * 0.5) - joint
	return part


## Paints from a palette (dark to light): lighter higher up, in blotches.
static func _shaded(palette: Array, low: float, high: float, salt: int, patch := 2) -> Callable:
	var values: Array[int] = []
	for hex: String in palette:
		values.append(_v(hex))
	var last := values.size() - 1
	return func(p: Vector3i) -> int:
		var t := clampf((p.y - low) / maxf(1.0, high - low), 0.0, 1.0)
		var n := _noise(p / patch, salt)
		return values[clampi(int(t * last + (n - 0.5) * 1.6 + 0.5), 0, last)]


## A fleece: an ellipsoid whose surface rises and falls in little curls.
static func _fleece(grid: VoxelGrid, center: Vector3, radii: Vector3, salt: int) -> void:
	var paint := _shaded(WOOL, center.y - radii.y, center.y + radii.y, salt)
	var low := Vector3i((center - radii - Vector3.ONE).floor())
	var high := Vector3i((center + radii + Vector3.ONE).ceil())
	for z in range(low.z, high.z + 1):
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var p := Vector3i(x, y, z)
				var d := (Vector3(p) + Vector3.ONE * 0.5 - center) / radii
				var curl := (_noise(p / 2, salt + 3) - 0.5) * 0.45
				if d.length_squared() <= 1.0 + curl:
					grid.set_voxel(p, paint.call(p))


## A leg `height` voxels long, `width` across: hoof at the bottom, `top`
## colors above (dark to light, the lightest at the top).
static func _leg(width: int, height: int, colors: Array, hoof := HOOF) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(width, height, width))
	grid.box(Vector3i.ZERO, Vector3i(width - 1, height - 1, width - 1), _v(colors[0]))
	if colors.size() > 1:
		grid.box(
			Vector3i(0, height / 2, 0),
			Vector3i(width - 1, height - 1, width - 1),
			_v(colors[colors.size() - 1])
		)
	grid.box(Vector3i.ZERO, Vector3i(width - 1, 0, width - 1), _v(hoof))
	return grid


## Four legs at the corners of a body: `half` apart across (from the
## middle to a leg's inner side), front ones from `front`, back ones from
## `back` (z of their lowest corner).
static func _four_legs(leg: VoxelGrid, half: int, front: int, back: int) -> Array[Part]:
	var legs: Array[Part] = []
	var w := leg.size.x
	var spots := [
		["leg_fl", -half - w, front],
		["leg_fr", half, front],
		["leg_bl", -half - w, back],
		["leg_br", half, back],
	]
	for spot: Array in spots:
		var corner := Vector3(spot[1], 0.0, spot[2])
		legs.append(_part(spot[0], leg, corner, corner + Vector3(w * 0.5, leg.size.y, w * 0.5)))
	return legs


## Two eyes on the sides of a head (x at `left` and `right`), with a glint.
static func _eyes(grid: VoxelGrid, left: int, right: int, y: int, z: int) -> void:
	for x in [left, right]:
		grid.set_voxel(Vector3i(x, y, z), _v(EYE))
		grid.set_voxel(Vector3i(x, y + 1, z), _v(EYE_SHINE))


# ---------------------------------------------------------------- sheep


## A round, cream fleece on short dark legs; a dark face with drooping
## ears under a tuft of wool.
static func _sheep() -> Array:
	var leg := _leg(2, 6, ["#3b302b", "#e9e1cf"])
	var parts: Array = _four_legs(leg, 1, 2, -5)
	var body := VoxelGrid.new(Vector3i(13, 11, 17))
	_fleece(body, Vector3(6.5, 5.2, 8.5), Vector3(5.6, 4.6, 7.6), 41)
	# A little tail of wool.
	body.ellipsoid(Vector3(6.5, 7.5, 0.6), Vector3(1.6, 1.6, 1.2), _v(WOOL[2]))
	parts.append(_part("body", body, Vector3(-6.5, 4.0, -8.5), Vector3(0.0, 4.0, 0.0)))
	var head := VoxelGrid.new(Vector3i(9, 7, 7))
	head.box(Vector3i(2, 0, 1), Vector3i(6, 4, 6), _shaded(SHEEP_FACE, 0.0, 4.0, 7))
	head.box(Vector3i(3, 0, 5), Vector3i(5, 1, 6), _v("#7a6658"))
	head.set_voxel(Vector3i(3, 1, 6), _v("#2a201c"))
	head.set_voxel(Vector3i(5, 1, 6), _v("#2a201c"))
	_eyes(head, 2, 6, 2, 5)
	# Ears out to the sides, drooping; a tuft of wool on top.
	for x: int in [0, 1, 7, 8]:
		head.set_voxel(Vector3i(x, 3, 2), _v("#4f413a"))
	head.set_voxel(Vector3i(0, 2, 2), _v("#3b302b"))
	head.set_voxel(Vector3i(8, 2, 2), _v("#3b302b"))
	head.ellipsoid(Vector3(4.5, 5.2, 3.0), Vector3(2.8, 1.8, 2.4), _shaded(WOOL, 4.0, 7.0, 9))
	parts.append(_part("head", head, Vector3(-4.5, 8.0, 5.0), Vector3(0.0, 10.0, 6.0)))
	return parts


# ---------------------------------------------------------------- boar


## A wild boar: a heavy, bristly dark body with a mane along its back,
## short legs, a long head with a pale snout and curved tusks.
static func _boar() -> Array:
	var leg := _leg(2, 4, ["#22180f", "#3b2a20"])
	var parts: Array = _four_legs(leg, 1, 3, -6)
	var body := VoxelGrid.new(Vector3i(11, 10, 17))
	body.ellipsoid(Vector3(5.5, 4.5, 8.5), Vector3(4.8, 4.3, 7.8), _shaded(BOAR_HIDE, 1.0, 8.0, 13))
	# The mane: bristles up the back, taller over the shoulders.
	for z in range(3, 15):
		var tall := 1 if z < 9 else 2
		for y in range(8, 8 + tall + 1):
			body.set_voxel(Vector3i(5, y, z), _v("#1a120d" if (z + y) % 2 else "#2c1f18"))
	# A thin tail with a tuft.
	body.box(Vector3i(5, 6, 0), Vector3i(5, 7, 0), _v("#2c1f18"))
	body.set_voxel(Vector3i(5, 5, 0), _v("#1a120d"))
	parts.append(_part("body", body, Vector3(-5.5, 3.0, -8.5), Vector3(0.0, 3.0, 0.0)))
	var head := VoxelGrid.new(Vector3i(8, 8, 9))
	head.box(Vector3i(1, 0, 0), Vector3i(6, 5, 5), _shaded(BOAR_HIDE, 0.0, 5.0, 17))
	head.box(Vector3i(2, 0, 6), Vector3i(5, 3, 7), _shaded(BOAR_HIDE, 0.0, 3.0, 19))
	head.box(Vector3i(2, 0, 8), Vector3i(5, 2, 8), _v(BOAR_SNOUT[1]))
	head.box(Vector3i(3, 1, 8), Vector3i(4, 1, 8), _v(BOAR_SNOUT[0]))
	# Tusks curving up beside the snout.
	for x: int in [1, 6]:
		head.set_voxel(Vector3i(x, 0, 7), _v(TUSK))
		head.set_voxel(Vector3i(x, 1, 7), _v(TUSK))
		head.set_voxel(Vector3i(x, 2, 6), _v(TUSK))
	_eyes(head, 1, 6, 3, 4)
	# Small pointed ears.
	head.box(Vector3i(1, 6, 1), Vector3i(2, 7, 1), _v("#2c1f18"))
	head.box(Vector3i(5, 6, 1), Vector3i(6, 7, 1), _v("#2c1f18"))
	parts.append(_part("head", head, Vector3(-4.0, 3.5, 6.0), Vector3(0.0, 7.0, 7.0)))
	return parts


# ---------------------------------------------------------------- chicken


## A jungle fowl: a chestnut body, golden hackles, dark green tail feathers
## arching up behind, a red comb, yellow legs.
static func _chicken() -> Array:
	var parts: Array = []
	var leg := VoxelGrid.new(Vector3i(3, 4, 3))
	leg.box(Vector3i(1, 1, 1), Vector3i(1, 3, 1), _v(BEAK))
	leg.box(Vector3i(0, 0, 2), Vector3i(2, 0, 2), _v("#c98f24"))
	leg.set_voxel(Vector3i(1, 0, 0), _v("#c98f24"))
	leg.set_voxel(Vector3i(1, 0, 1), _v("#c98f24"))
	for spot in [["leg_fl", -2.5], ["leg_fr", -0.5]]:
		var corner := Vector3(spot[1], 0.0, -1.5)
		parts.append(_part(spot[0], leg, corner, corner + Vector3(1.5, 4.0, 1.5)))
	var body := VoxelGrid.new(Vector3i(7, 10, 11))
	body.ellipsoid(Vector3(3.5, 3.4, 5.2), Vector3(2.9, 2.8, 3.8), _shaded(FOWL, 1.0, 6.0, 23))
	# Golden hackles over the breast and the neck's base.
	body.ellipsoid(Vector3(3.5, 4.6, 7.6), Vector3(2.2, 1.8, 1.5), _v(FOWL[3]))
	# The tail: feathers arching up and back.
	for i in 6:
		var z := 1.0 - i * 0.2
		var y := 4.0 + i
		body.box(Vector3i(2, int(y), int(z)), Vector3i(4, int(y), int(z) + 1), _v(FOWL_TAIL[i % 4]))
	body.box(Vector3i(3, 9, 0), Vector3i(3, 9, 1), _v(FOWL_TAIL[3]))
	parts.append(_part("body", body, Vector3(-3.5, 3.0, -5.5), Vector3(0.0, 3.0, 0.0)))
	for side in [["wing_l", -3.5, -0.5], ["wing_r", 2.5, 0.5]]:
		var wing := VoxelGrid.new(Vector3i(1, 3, 5))
		wing.box(Vector3i(0, 0, 0), Vector3i(0, 2, 4), _v(FOWL_WING[1]))
		wing.box(Vector3i(0, 0, 0), Vector3i(0, 0, 3), _v(FOWL_WING[0]))
		var corner := Vector3(side[1], 4.5, -2.5)
		parts.append(_part(side[0], wing, corner, corner + Vector3(0.5 - side[2], 3.0, 3.0)))
	var head := VoxelGrid.new(Vector3i(3, 6, 5))
	head.box(Vector3i(0, 0, 0), Vector3i(2, 2, 2), _v(FOWL[3]))
	head.box(Vector3i(1, 3, 0), Vector3i(1, 3, 2), _v(COMB))
	head.set_voxel(Vector3i(1, 4, 1), _v(COMB))
	head.set_voxel(Vector3i(1, 1, 3), _v(BEAK))
	head.set_voxel(Vector3i(1, 0, 3), _v(COMB))
	head.set_voxel(Vector3i(0, 2, 2), _v(EYE))
	head.set_voxel(Vector3i(2, 2, 2), _v(EYE))
	parts.append(_part("head", head, Vector3(-1.5, 7.0, 2.5), Vector3(0.0, 7.0, 3.0)))
	return parts


# ---------------------------------------------------------------- deer


## A deer: slender, tawny, a pale belly and rump, long legs, a long neck,
## big ears; stags carry antlers (a part of their own).
static func _deer() -> Array:
	var leg := _leg(2, 9, ["#5e3e24", "#9a6a40"])
	var parts: Array = _four_legs(leg, 1, 3, -6)
	var body := VoxelGrid.new(Vector3i(9, 9, 17))
	body.ellipsoid(Vector3(4.5, 4.4, 8.5), Vector3(3.8, 3.7, 7.6), _shaded(DEER, 1.0, 8.0, 29))
	body.box(Vector3i(2, 0, 4), Vector3i(6, 1, 13), _v(DEER_BELLY))
	# A pale rump and a short tail, dark on top.
	body.ellipsoid(Vector3(4.5, 5.0, 1.2), Vector3(2.6, 2.4, 1.2), _v("#f2ece0"))
	body.box(Vector3i(4, 6, 0), Vector3i(4, 7, 0), _v("#3a2616"))
	parts.append(_part("body", body, Vector3(-4.5, 8.0, -8.5), Vector3(0.0, 8.0, 0.0)))
	var head := VoxelGrid.new(Vector3i(10, 12, 9))
	var coat := _shaded(DEER, 0.0, 11.0, 31)
	# The neck leans forward from the shoulders.
	for i in 7:
		head.box(Vector3i(3, i, 1 + i / 2), Vector3i(6, i + 1, 3 + i / 2), coat)
	head.box(Vector3i(3, 7, 3), Vector3i(6, 9, 7), coat)
	head.box(Vector3i(3, 7, 6), Vector3i(6, 7, 7), _v(DEER_BELLY))
	head.box(Vector3i(4, 7, 8), Vector3i(5, 8, 8), _v("#4a3020"))
	head.set_voxel(Vector3i(4, 8, 8), _v(EYE))
	head.set_voxel(Vector3i(5, 8, 8), _v(EYE))
	_eyes(head, 3, 6, 8, 6)
	# Big ears, pale inside.
	for x: int in [1, 2, 7, 8]:
		head.set_voxel(Vector3i(x, 10, 4), _v(DEER[2]))
		head.set_voxel(Vector3i(x, 9, 4), _v(DEER_BELLY if x in [2, 7] else DEER[1]))
	parts.append(_part("head", head, Vector3(-5.0, 12.0, 4.0), Vector3(0.0, 13.0, 5.0)))
	var antlers := VoxelGrid.new(Vector3i(11, 7, 4))
	var paint := _shaded(ANTLER, 0.0, 6.0, 37)
	for side: int in [-1, 1]:
		var base := Vector3(5.5 + side * 1.5, 0.0, 1.5)
		var tip := base + Vector3(side * 3.5, 5.5, 0.0)
		antlers.line(base, tip, 0.4, paint)
		var fork := base + Vector3(side * 1.2, 2.0, 0.0)
		antlers.line(fork, base + Vector3(side * 1.6, 4.0, 1.5), 0.4, paint)
		var top := base + Vector3(side * 2.6, 4.0, 0.0)
		antlers.line(top, base + Vector3(side * 2.2, 6.5, 0.5), 0.4, paint)
	var on_head := Vector3(-5.5, 22.0, 5.5)
	parts.append(_part("antlers", antlers, on_head, Vector3(0.0, 13.0, 5.0)))
	return parts
