class_name RanchModels
extends RefCounted
## Husbandry's models: the nest box with 0 to 3 eggs in its straw
## (Husbandry.NESTS), and the items: shears, a bucket and a bucket of milk,
## a lead, an egg, a fried egg.

const WOOD := ["#6a4a2a", "#8a6640", "#a8824e"]
const STRAW := ["#b08a3a", "#d2ae52", "#e8cc74"]
const EGG := ["#d8c8a6", "#eee2c8", "#fbf4e4"]
const IRON := ["#6e7078", "#9a9ca4", "#c4c6cc", "#e2e3e6"]
const HANDLE := ["#7a2a22", "#a63a2e"]
const ROPE := ["#7a5a32", "#9a7a4a", "#b89a62"]
const MILK := "#f6f4ee"
const YOLK := ["#e8a020", "#f8c840"]
## Where the eggs lie in the straw (voxels), the first ones first.
const EGG_SPOTS: Array[Vector3i] = [Vector3i(5, 4, 6), Vector3i(9, 4, 8), Vector3i(6, 4, 10)]


## The model of a nest box block (null for other blocks).
static func build(block: int) -> VoxelGrid:
	var eggs := Husbandry.NESTS.find(block)
	return nest(eggs) if eggs >= 0 else null


## A nest box: a low plank box full of straw, `eggs` eggs in its hollow.
static func nest(eggs: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 8, 16))
	grid.pivot = Vector2(8, 8)
	grid.box(Vector3i(1, 0, 1), Vector3i(14, 0, 14), _solid(WOOD[0]))
	for y in range(1, 7):
		var plank := _solid(WOOD[2] if y == 6 else WOOD[1 if y % 3 else 0])
		for i in range(1, 15):
			for at: Vector3i in [
				Vector3i(i, y, 1), Vector3i(i, y, 14), Vector3i(1, y, i), Vector3i(14, y, i)
			]:
				grid.set_voxel(at, plank)
	# Straw heaped against the walls, a hollow in the middle.
	for z in range(2, 14):
		for x in range(2, 14):
			var hollow := Vector2(x - 7.5, z - 8.0).length() < 3.6
			var top := 3 if hollow else 4 + int(HashUtil.unit2(0x57A3, x, z) * 2.0)
			for y in range(1, top + 1):
				var shade := int(HashUtil.unit2(0x57A4 + y, x, z) * STRAW.size())
				grid.set_voxel(Vector3i(x, y, z), _solid(STRAW[mini(shade, STRAW.size() - 1)]))
	for i in mini(eggs, EGG_SPOTS.size()):
		_egg_at(grid, EGG_SPOTS[i])
	return grid


## The model of a husbandry item (null for others).
static func item(item_id: int) -> VoxelGrid:
	match item_id:
		Items.Id.NEST_BOX:
			return nest(0)
		Items.Id.SHEARS:
			return _shears()
		Items.Id.BUCKET:
			return _bucket(false)
		Items.Id.MILK_BUCKET:
			return _bucket(true)
		Items.Id.LEAD:
			return _lead()
		Items.Id.EGG:
			return _egg()
		Items.Id.FRIED_EGG:
			return _fried_egg()
	return null


## An egg lying in the straw, its top lit.
static func _egg_at(grid: VoxelGrid, at: Vector3i) -> void:
	grid.box(at, at + Vector3i(1, 0, 2), _solid(EGG[1]))
	grid.box(at + Vector3i(0, 1, 0), at + Vector3i(1, 1, 2), _solid(EGG[2]))
	grid.set_voxel(at + Vector3i(1, 0, 2), _solid(EGG[0]))


## Shears: two iron blades crossed on a rivet, red grips (flat, on the
## diagonal like the tools).
static func _shears() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(14, 14, 2))
	grid.line(Vector3(6, 6, 0), Vector3(12.5, 12.5, 0), 0.0, _solid(IRON[2]))
	grid.line(Vector3(7, 6, 0), Vector3(13.5, 11.5, 0), 0.0, _solid(IRON[3]))
	grid.line(Vector3(6, 7, 1), Vector3(11.5, 13.5, 1), 0.0, _solid(IRON[1]))
	grid.set_voxel(Vector3i(6, 6, 1), _solid(IRON[0]))
	for loop: Vector2 in [Vector2(2.5, 4.5), Vector2(4.5, 2.5)]:
		for k in 8:
			var angle := TAU * k / 8.0
			var at := Vector3(loop.x + cos(angle) * 1.6, loop.y + sin(angle) * 1.6, 0)
			grid.set_voxel(Vector3i(at.round()), _solid(HANDLE[k % 2]))
	grid.line(Vector3(4, 5, 0), Vector3(6, 6, 0), 0.0, _solid(IRON[1]))
	grid.line(Vector3(5, 4, 0), Vector3(6, 6, 0), 0.0, _solid(IRON[1]))
	return grid


## A bucket: an iron pail widening to its rim, an arched handle; full of
## milk, white inside.
static func _bucket(full: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(10, 11, 10))
	var middle := Vector2(5, 5)
	for y in 7:
		var radius := lerpf(3.2, 4.2, y / 6.0)
		var paint := _solid(IRON[3] if y == 6 else IRON[1 + (y + 1) % 2])
		grid.disc(middle, radius, y, paint)
	grid.disc(middle, 3.4, 6, _solid(MILK if full else IRON[0]))
	for k in 9:
		var angle := PI * k / 8.0
		var at := Vector3(5.0 + cos(angle) * 4.2, 7.0 + sin(angle) * 3.0, 5.0)
		grid.set_voxel(Vector3i(at.round()), _solid(IRON[2]))
	return grid


## A coiled lead: rings of rope, an end hanging out.
static func _lead() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 4, 12))
	for ring in 3:
		var radius := 4.6 - ring * 0.9
		for k in 24:
			var angle := TAU * k / 24.0
			var at := Vector3(6.0 + cos(angle) * radius, ring, 6.0 + sin(angle) * radius)
			grid.set_voxel(Vector3i(at.floor()), _solid(ROPE[(k + ring) % 3]))
	grid.line(Vector3(10, 2, 6), Vector3(11, 0, 1), 0.0, _solid(ROPE[1]))
	return grid


static func _egg() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(6, 8, 6))
	var paint := func(p: Vector3i) -> int:
		return _solid(EGG[2] if p.y >= 5 and p.x <= 2 else (EGG[1] if p.y >= 2 else EGG[0]))
	grid.ellipsoid(Vector3(3, 3.6, 3), Vector3(2.6, 3.6, 2.6), paint)
	return grid


## A fried egg: a white with ragged edges, a round yolk.
static func _fried_egg() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(11, 3, 11))
	var white := func(p: Vector3i) -> int:
		if HashUtil.unit2(0xE66, p.x, p.z) < 0.15 and Vector2(p.x - 5, p.z - 5).length() > 4.0:
			return 0
		return _solid("#f8f6ee" if (p.x + p.z) % 4 else "#ece8da")
	grid.disc(Vector2(5.5, 5.5), 5.2, 0, white)
	grid.ellipsoid(Vector3(5.5, 1.0, 5.0), Vector3(1.9, 1.4, 1.9), _solid(YOLK[0]))
	grid.set_voxel(Vector3i(5, 2, 4), _solid(YOLK[1]))
	return grid


static func _solid(hex: String) -> int:
	return VoxelGrid.voxel(Color(hex))
