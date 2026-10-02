class_name ArmorModels
extends RefCounted
## Armor in voxels (Armor): the pieces as the player wears them (see
## PlayerModel.set_armor: a helmet over the head, a chestplate round the
## torso with pads on the shoulders, leggings round the thighs, boots on
## the feet), and their icons (flat outlines). Shells a voxel off the
## body, shaded lighter at the top, a dark rim at the bottom; leather
## stitched, metal riveted.

## Colors (dark to light) of each material.
const COLORS := {
	Armor.Kind.HIDE: ["#4a2d16", "#6a4224", "#8a5a32", "#a8744a"],
	Armor.Kind.COPPER: ["#7a3a1c", "#b9612d", "#e2894a", "#f9b67e"],
	Armor.Kind.IRON: ["#55555c", "#8e8e96", "#b4b4bc", "#e2e2e8"],
	Armor.Kind.GOLD: ["#94640f", "#dda72a", "#f6cd47", "#fff2a0"],
	Armor.Kind.DIAMOND: ["#11757b", "#35c2c6", "#86eeee", "#e2ffff"],
}

## The icons' outlines (rows from the top), by Armor.Piece.
const ICON_SHAPES := {
	Armor.Piece.HELMET:
	[
		"....#######....",
		"..###########..",
		".#############.",
		".#############.",
		".#############.",
		".####.....####.",
		".###.......###.",
		".###.......###.",
		".###.......###.",
		"..##.......##..",
	],
	Armor.Piece.CHESTPLATE:
	[
		"####......####",
		"#####....#####",
		"##############",
		"##############",
		"##############",
		".############.",
		"..##########..",
		"..##########..",
		"..##########..",
		"..##########..",
		"..##########..",
		"..##########..",
		"...########...",
	],
	Armor.Piece.LEGGINGS:
	[
		"############",
		"############",
		"############",
		"#####..#####",
		"####....####",
		"####....####",
		"####....####",
		"####....####",
		"####....####",
		"####....####",
		"####....####",
		"####....####",
	],
	Armor.Piece.BOOTS:
	[
		"...####....####",
		"...####....####",
		"...####....####",
		"...####....####",
		"..#####...#####",
		"#######.#######",
		"#######.#######",
	],
}

static var _worn: Dictionary[int, Array] = {}


## What a piece puts on the body: [[where (a PlayerModel part: "body",
## "arm_r", "arm_l", "leg_r", "leg_l"), its voxels, where its base's middle
## sits from that part's joint (voxels)]], built once.
static func worn(item: int) -> Array:
	if _worn.has(item):
		return _worn[item]
	var colors: Array = COLORS[Armor.material_of(item)]
	var parts := []
	match Armor.piece_of(item):
		Armor.Piece.HELMET:
			var helmet := _shell(Vector3i(10, 5, 10), colors, true, item)
			# The face stays open under the brow.
			for x in range(2, 8):
				helmet.set_voxel(Vector3i(x, 0, 9), 0)
			parts.append(["body", helmet, Vector3(0, 20, 0)])
		Armor.Piece.CHESTPLATE:
			var chest := _shell(Vector3i(10, 8, 6), colors, true, item)
			for x in range(3, 7):
				for z in range(1, 5):
					chest.set_voxel(Vector3i(x, 7, z), 0)
			parts.append(["body", chest, Vector3(0, 9, 0)])
			for arm: String in ["arm_r", "arm_l"]:
				parts.append(
					[arm, _shell(Vector3i(4, 3, 4), colors, true, item), Vector3(0, -3, 0)]
				)
		Armor.Piece.LEGGINGS:
			for leg: String in ["leg_r", "leg_l"]:
				parts.append(
					[leg, _shell(Vector3i(6, 6, 6), colors, false, item), Vector3(0, -6, 0)]
				)
		_:
			for leg: String in ["leg_r", "leg_l"]:
				parts.append(
					[leg, _shell(Vector3i(6, 3, 6), colors, false, item), Vector3(0, -8, 0)]
				)
	_worn[item] = parts
	return parts


## A piece's icon (and the item on the ground, in hand): its outline seen
## from the front, flat like a tool's (ItemModels.is_flat), framed dark,
## lit from the top left; hide stitched, metal riveted.
static func icon(item: int) -> VoxelGrid:
	var colors: Array = COLORS[Armor.material_of(item)]
	var hide := Armor.material_of(item) == Armor.Kind.HIDE
	var shape: Array = ICON_SHAPES[Armor.piece_of(item)]
	var width: int = shape[0].length()
	var grid := VoxelGrid.new(Vector3i(width, shape.size(), 1))
	for row in shape.size():
		for x in width:
			if not _filled(shape, x, row):
				continue
			var shade := 2
			if not (
				_filled(shape, x - 1, row)
				and _filled(shape, x + 1, row)
				and _filled(shape, x, row - 1)
				and _filled(shape, x, row + 1)
			):
				shade = 0
			elif not _filled(shape, x, row - 2) or not _filled(shape, x - 2, row):
				shade = 3
			elif not _filled(shape, x, row + 2) or not _filled(shape, x + 2, row):
				shade = 1
			elif hide and row % 3 == 1 and x % 2 == 0:
				shade = 3
			elif not hide and row % 4 == 2 and x % 4 == 1:
				shade = 3
			grid.set_voxel(Vector3i(x, shape.size() - 1 - row, 0), _v(colors[shade]))
	return grid


static func _filled(shape: Array, x: int, row: int) -> bool:
	if row < 0 or row >= shape.size() or x < 0 or x >= shape[row].length():
		return false
	return shape[row][x] == "#"


static func _v(hex: String) -> int:
	return VoxelGrid.voxel(Color(hex))


## A hollow box `size` voxels (closed on top if `capped`): lighter higher
## up, a dark rim along its bottom, stitches (hide) or rivets (metal); its
## top (lit by the sun: kept darker) framed by a light rim, a crest along
## its middle.
static func _shell(size: Vector3i, colors: Array, capped: bool, item: int) -> VoxelGrid:
	var grid := VoxelGrid.new(size)
	var hide := Armor.material_of(item) == Armor.Kind.HIDE
	for z in size.z:
		for y in size.y:
			for x in size.x:
				var outside := x == 0 or z == 0 or x == size.x - 1 or z == size.z - 1
				if not outside and not (capped and y == size.y - 1):
					continue
				var shade := 1 if y < size.y / 2 else 2
				if y == size.y - 1 and capped:
					shade = 2 if outside or x == size.x / 2 else 1
				if y == 0:
					shade = 0
				var corner := (x == 0 or x == size.x - 1) and (z == 0 or z == size.z - 1)
				if y == size.y / 2 and (x + z) % 3 == 0 and not corner:
					shade = 3 if hide else shade
				if not hide and corner and y == 1:
					shade = 3
				grid.set_voxel(Vector3i(x, y, z), _v(colors[shade]))
	return grid
