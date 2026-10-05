class_name ApiaryModels
extends RefCounted
## The bees' models: the beehive players make (a box of planks on legs under
## a lid, its door a slot at the bottom of its front, honey oozing down it
## as it fills: Apiary levels 0 to FULL) and the wild bee nest (a papery
## nest on an old stump, its door a hole, honey dripping as it fills), and
## the items: a glass bottle, a bottle of honey, honeycomb, the beehive.

const WOOD := ["#5e4026", "#86603a", "#a07a4a", "#bc9660"]
const LID := ["#4a3020", "#6a4630"]
const HONEY := ["#b86a0e", "#e0921e", "#f4b838", "#fcdc78"]
const PAPER := ["#8a7656", "#a8946c", "#c4b088", "#ddc9a0"]
const BARK := ["#3a2a1a", "#523c26", "#6a5034"]
const RINGS := ["#a8865a", "#c4a070"]
const GLASS := ["#8eb4c6", "#c4dce6", "#eef8fc"]
const CORK := ["#8a5e34", "#a87a4a"]
const DOOR := "#24160c"
## Where honey oozes down a hive's front and a nest's side, the first ones
## first: [x, highest row, rows down] (z: in front of the face).
const HIVE_DRIPS: Array[Vector3i] = [
	Vector3i(9, 11, 3),
	Vector3i(5, 11, 5),
	Vector3i(11, 8, 4),
	Vector3i(4, 7, 3),
	Vector3i(7, 10, 6),
	Vector3i(10, 11, 7),
]
const NEST_DRIPS: Array[Vector3i] = [
	Vector3i(9, 7, 3),
	Vector3i(6, 8, 4),
	Vector3i(10, 10, 5),
	Vector3i(5, 11, 6),
	Vector3i(8, 6, 3),
	Vector3i(11, 9, 4),
]


## The model of a hive or nest block (null for other blocks).
static func build(block: int) -> VoxelGrid:
	if not Apiary.is_hive(block):
		return null
	var level := Apiary.level_of(block)
	return hive(level) if block in Apiary.HIVES[0] else nest(level)


## A beehive holding `level` honey.
static func hive(level: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 14, 16))
	grid.pivot = Vector2(8, 8)
	for x: int in [3, 11]:
		for z: int in [3, 11]:
			grid.box(Vector3i(x, 0, z), Vector3i(x + 1, 2, z + 1), _solid(WOOD[0]))
	grid.box(Vector3i(2, 3, 2), Vector3i(13, 3, 13), _solid(WOOD[1]))
	# Two boxes stacked, a dark seam between them, planks lighter up.
	for y in range(4, 12):
		var paint := _solid(WOOD[0] if y == 8 else WOOD[2 if y % 4 < 2 else 3])
		grid.box(Vector3i(3, y, 3), Vector3i(12, y, 12), paint)
	# Hand holds on the sides.
	for z: int in [7, 8]:
		grid.set_voxel(Vector3i(3, 10, z), _solid(WOOD[0]))
		grid.set_voxel(Vector3i(12, 10, z), _solid(WOOD[0]))
	grid.box(Vector3i(2, 12, 2), Vector3i(13, 12, 13), _solid(LID[0]))
	grid.box(Vector3i(3, 13, 3), Vector3i(12, 13, 12), _solid(LID[1]))
	# The door, a slot at the bottom of the front over a landing board.
	grid.box(Vector3i(5, 4, 12), Vector3i(10, 4, 12), _solid(DOOR))
	grid.box(Vector3i(5, 3, 14), Vector3i(10, 3, 14), _solid(WOOD[2]))
	for i in mini(level * 2, HIVE_DRIPS.size()):
		_drip(grid, HIVE_DRIPS[i], 13)
	if level >= Apiary.FULL:
		grid.box(Vector3i(6, 3, 13), Vector3i(9, 3, 14), _solid(HONEY[2]))
		grid.box(Vector3i(6, 4, 13), Vector3i(9, 4, 13), _solid(HONEY[1]))
	return grid


## A wild bee nest holding `level` honey: a round papery nest in bands on
## an old stump, its door a dark hole.
static func nest(level: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 14, 16))
	grid.pivot = Vector2(8, 8)
	var bark := func(p: Vector3i) -> int:
		var ridge := (p.x * 3 + p.z * 5) % 4 == 0
		return _solid(BARK[0] if ridge else BARK[1 + int(HashUtil.unit2(0xB4C, p.x, p.y) * 1.9)])
	grid.cylinder(Vector2(8, 8), 4.6, 0, 4, bark)
	grid.disc(Vector2(8, 8), 4.2, 4, _solid(RINGS[0]))
	grid.disc(Vector2(8, 8), 2.4, 4, _solid(RINGS[1]))
	var paper := func(p: Vector3i) -> int:
		var band := (p.y + int(HashUtil.unit2(0x9E5, p.x, p.z) * 1.6)) % 3
		return _solid(PAPER[3 - band if p.y > 9 else 2 - band])
	grid.ellipsoid(Vector3(8.0, 9.4, 8.0), Vector3(4.8, 4.6, 4.8), paper)
	# The door, low on its front, honey around it once there is some.
	grid.box(Vector3i(7, 7, 12), Vector3i(8, 8, 12), _solid(DOOR))
	grid.box(Vector3i(7, 7, 11), Vector3i(8, 8, 11), _solid(DOOR))
	for i in mini(level * 2, NEST_DRIPS.size()):
		_drip(grid, NEST_DRIPS[i], -1)
	if level >= Apiary.FULL:
		grid.box(Vector3i(6, 6, 12), Vector3i(9, 6, 12), _solid(HONEY[2]))
	return grid


## The model of a bees' item (null for others).
static func item(item_id: int) -> VoxelGrid:
	match item_id:
		Items.Id.BEEHIVE:
			return hive(0)
		Items.Id.GLASS_BOTTLE:
			return _bottle(false)
		Items.Id.HONEY_BOTTLE:
			return _bottle(true)
		Items.Id.HONEYCOMB:
			return _comb()
	return null


## Honey oozing down from `at` (x, highest row, rows down; lighter at the
## top), at `z` in front of the face (-1: on the outside of whatever is
## there, a nest's round side).
static func _drip(grid: VoxelGrid, at: Vector3i, z: int) -> void:
	for i in at.z:
		var y := at.y - i
		var front := z
		if front < 0:
			front = grid.size.z - 1
			while front > 0 and grid.get_voxel(Vector3i(at.x, y, front - 1)) == 0:
				front -= 1
			if front == 0:
				continue
		var shade: String = HONEY[3 - mini(i * 3 / maxi(at.z, 1), 3)]
		grid.set_voxel(Vector3i(at.x, y, front), _solid(shade))


## A glass bottle with a cork; full of honey, golden up to its shoulders.
static func _bottle(full: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(7, 10, 7))
	var middle := Vector2(3.5, 3.5)
	for y in 6:
		var radius := 3.2 if y < 5 else 2.4
		grid.disc(middle, radius, y, _solid(GLASS[1]))
		if full and y < 5:
			grid.disc(middle, radius - 0.6, y, _solid(HONEY[1 + mini(y / 2, 2)]))
	# The light on the glass, its darker rim.
	for y in range(1, 5):
		grid.set_voxel(Vector3i(1, y, 2), _solid(GLASS[2]))
		grid.set_voxel(Vector3i(5, y, 4), _solid(GLASS[0]))
	grid.cylinder(middle, 1.3, 6, 7, _solid(GLASS[0]))
	grid.cylinder(middle, 1.3, 8, 9, _solid(CORK[1]))
	grid.set_voxel(Vector3i(3, 9, 3), _solid(CORK[0]))
	return grid


## A slab of honeycomb: hexagonal cells of wax, some still full and
## shining.
static func _comb() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 3, 10))
	for z in range(1, 9):
		var shift := 1 if (z / 2) % 2 else 0
		for x in range(1, 11):
			var wall := z % 2 == 0 or (x + shift * 2) % 4 == 0
			var full := HashUtil.unit2(0xC0B, x / 4, z / 2) > 0.45
			grid.set_voxel(Vector3i(x, 0, z), _solid(HONEY[1]))
			grid.set_voxel(Vector3i(x, 1, z), _solid(HONEY[0] if wall else HONEY[1]))
			if wall:
				grid.set_voxel(Vector3i(x, 2, z), _solid(HONEY[3]))
			elif full:
				grid.set_voxel(Vector3i(x, 2, z), _solid(HONEY[2]))
	return grid


static func _solid(hex: String) -> int:
	return VoxelGrid.voxel(Color(hex))
