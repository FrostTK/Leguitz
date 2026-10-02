class_name FarmModels
extends RefCounted
## Crops in their stages (Farming), sown in rows across their tile: wheat
## (stalks turning golden, heavy heads), carrots (feathery tops, orange
## shoulders showing when ripe), potatoes (bushes that flower); and the
## farm's items: wheat, carrot, potato, baked potato, dough, bread.

const WHEAT_GREEN := ["#3f7a2c", "#58993a", "#7cb84e"]
const WHEAT_GOLD := ["#a8822e", "#d2a943", "#efcf6a", "#8a6a24"]
const CARROT_TOP := ["#2f6e28", "#45903a", "#69b04f"]
const CARROT := ["#b8501a", "#e2752a", "#f59a4a"]
const POTATO_LEAF := ["#2f5e2a", "#467f38", "#62a049"]
const POTATO := ["#8a6a3e", "#b08c55", "#c9a66b"]
const FLOWER := ["#efe6f5", "#c7a6e0"]
## The rows across the tile (z, voxels) and the plants in each.
const ROWS: Array[int] = [3, 8, 13]
const PER_ROW := 4

## Each crop's stage (0 to 3).
const STAGE := {
	Tiles.Block.WHEAT_0: 0,
	Tiles.Block.WHEAT_1: 1,
	Tiles.Block.WHEAT_2: 2,
	Tiles.Block.WHEAT_3: 3,
	Tiles.Block.CARROTS_0: 0,
	Tiles.Block.CARROTS_1: 1,
	Tiles.Block.CARROTS_2: 2,
	Tiles.Block.CARROTS_3: 3,
	Tiles.Block.POTATOES_0: 0,
	Tiles.Block.POTATOES_1: 1,
	Tiles.Block.POTATOES_2: 2,
	Tiles.Block.POTATOES_3: 3,
}


static func build(block: int, variant: int) -> VoxelGrid:
	var rng := RandomNumberGenerator.new()
	rng.seed = HashUtil.hash2(0xFA21, block, variant)
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	grid.pivot = Vector2(8, 8)
	var stage: int = STAGE[block]
	var kind := Farming.sown_of(block)
	for z in ROWS:
		for i in PER_ROW:
			var x := 2 + i * 4 + rng.randi_range(-1, 1)
			var foot := Vector3(x, 0, z + rng.randi_range(-1, 1))
			match kind:
				Tiles.Block.WHEAT_0:
					_wheat(grid, rng, foot, stage)
				Tiles.Block.CARROTS_0:
					_carrot(grid, rng, foot, stage)
				_:
					_potato(grid, rng, foot, stage)
	grid.sway = 0.6
	grid.sway_from = 1
	return grid


## The model of a farm item (null for others).
static func item(item_id: int) -> VoxelGrid:
	match item_id:
		Items.Id.WHEAT:
			return _sheaf()
		Items.Id.CARROT:
			return _root()
		Items.Id.POTATO:
			return _tuber(POTATO, false)
		Items.Id.BAKED_POTATO:
			return _tuber(["#7a4f22", "#a8722f", "#d9a04a"], true)
		Items.Id.DOUGH:
			return _dough()
		Items.Id.BREAD:
			return _bread()
	return null


## A stalk of wheat: green and short at first, then tall and golden under
## a heavy head.
static func _wheat(grid: VoxelGrid, rng: RandomNumberGenerator, foot: Vector3, stage: int) -> void:
	var height: int = [2, 5, 9, 12][stage] + rng.randi_range(-1, 0)
	var lean := Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.6, 0.6)) * stage * 0.3
	var top := foot + Vector3(0, height, 0) + lean
	var colors: Array = WHEAT_GOLD if stage == 3 else WHEAT_GREEN
	grid.line(foot, top, 0.0, _leaf(colors[1]))
	# A leaf off the stalk.
	if stage >= 1:
		var mid := foot.lerp(top, 0.4)
		grid.line(
			mid,
			mid + Vector3(rng.randi_range(-2, 2), 1, rng.randi_range(-1, 1)),
			0.0,
			_leaf(colors[0])
		)
	if stage >= 2:
		var head: Array = WHEAT_GOLD if stage == 3 else ["#8fae4a", "#a9c35a", "#c2d470"]
		for k in 3:
			grid.set_voxel(Vector3i((top + Vector3(0, k, 0)).round()), _leaf(head[k % 2 + 1]))
		grid.set_voxel(Vector3i((top + Vector3(1, 1, 0)).round()), _leaf(head[0]))


## A carrot's feathery top; ripe, its orange shoulder shows at the ground.
static func _carrot(grid: VoxelGrid, rng: RandomNumberGenerator, foot: Vector3, stage: int) -> void:
	var height: int = [2, 4, 6, 7][stage]
	for k in 3:
		var tip := foot + Vector3(rng.randf_range(-1.6, 1.6), height, rng.randf_range(-1.2, 1.2))
		grid.line(foot, tip, 0.0, _leaf(CARROT_TOP[k % 3]))
		if stage >= 2:
			grid.set_voxel(Vector3i(tip.round()) + Vector3i(0, 1, 0), _leaf(CARROT_TOP[2]))
	if stage == 3:
		grid.set_voxel(Vector3i(foot), _solid(CARROT[1]))
		grid.set_voxel(Vector3i(foot) + Vector3i(1, 0, 0), _solid(CARROT[2]))
		grid.set_voxel(Vector3i(foot) + Vector3i(0, 0, 1), _solid(CARROT[0]))


## A potato plant: a bush of leaves growing rounder; ripe, it flowers and
## a potato peeks out at its foot.
static func _potato(grid: VoxelGrid, rng: RandomNumberGenerator, foot: Vector3, stage: int) -> void:
	var radius: float = [0.6, 1.4, 2.0, 2.3][stage]
	var center := foot + Vector3(0, radius * 0.9 + 0.5, 0)
	grid.ellipsoid(center, Vector3(radius, radius * 0.85, radius), _leaf(POTATO_LEAF[1]))
	grid.set_voxel(
		Vector3i(center.round()) + Vector3i(0, int(radius * 0.8), 0), _leaf(POTATO_LEAF[2])
	)
	if stage >= 1:
		var spot := center + Vector3(rng.randf_range(-1, 1), -radius * 0.5, rng.randf_range(-1, 1))
		grid.set_voxel(Vector3i(spot.round()), _leaf(POTATO_LEAF[0]))
	if stage == 3:
		for k in 2:
			var flower := (
				center
				+ Vector3(rng.randf_range(-1.5, 1.5), radius * 0.8, rng.randf_range(-1.5, 1.5))
			)
			grid.set_voxel(Vector3i(flower.round()), _leaf(FLOWER[k]))
		grid.set_voxel(Vector3i(foot) + Vector3i(2, 0, 1), _solid(POTATO[1]))


## A sheaf of wheat: golden stalks spreading up from a tied band.
static func _sheaf() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(11, 14, 11))
	var middle := Vector3(5, 0, 5)
	for i in 7:
		var angle := TAU * i / 7.0
		var out := Vector3(cos(angle), 0, sin(angle))
		var top := middle + out * 3.6 + Vector3(0, 11, 0)
		grid.line(middle + out * 1.2, top, 0.0, _solid(WHEAT_GOLD[1 + i % 2]))
		grid.line(
			top, top + Vector3(0, 2, 0) + out * 0.6, 0.0, _solid(WHEAT_GOLD[3 if i % 3 else 2])
		)
	grid.cylinder(Vector2(5, 5), 1.6, 4, 5, _solid("#7a4f22"))
	return grid


## A carrot lying down: an orange root tapering to its tip, its top green.
static func _root() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(15, 6, 6))
	for x in 12:
		var radius := lerpf(2.3, 0.4, x / 11.0)
		var shade: String = CARROT[1] if x % 3 else CARROT[0]
		_ring(grid, x + 3, radius, shade)
	for k in 3:
		grid.line(Vector3(3, 3, 3), Vector3(0, 3 + k - 1, 3 + k - 1), 0.0, _solid(CARROT_TOP[k]))
	grid.set_voxel(Vector3i(5, 4, 3), _solid(CARROT[2]))
	return grid


## A cross-section of the carrot along x (a disc in y and z).
static func _ring(grid: VoxelGrid, x: int, radius: float, hex: String) -> void:
	for y in 6:
		for z in 6:
			if Vector2(y + 0.5 - 3.0, z + 0.5 - 3.0).length() <= radius + 0.25:
				grid.set_voxel(Vector3i(x, y, z), _solid(hex))


## A potato: a lumpy oval with darker eyes; baked, split on top showing
## its golden inside.
static func _tuber(colors: Array, baked: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(10, 7, 8))
	grid.ellipsoid(Vector3(5, 3, 4), Vector3(4.2, 2.8, 3.2), _solid(colors[1]))
	grid.ellipsoid(Vector3(3.2, 4, 3.4), Vector3(1.6, 1.2, 1.4), _solid(colors[2]))
	for spot: Vector3i in [Vector3i(2, 3, 6), Vector3i(7, 4, 6), Vector3i(5, 5, 2)]:
		grid.set_voxel(spot, _solid(colors[0]))
	if baked:
		grid.box(Vector3i(3, 5, 3), Vector3i(7, 5, 4), _solid("#f2d27a"))
		grid.box(Vector3i(4, 6, 3), Vector3i(6, 6, 4), _solid("#fbe7a3"))
	return grid


static func _dough() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(10, 5, 10))
	grid.ellipsoid(Vector3(5, 2, 5), Vector3(4.3, 2.2, 4.3), _solid("#e9d6ad"))
	grid.ellipsoid(Vector3(4, 3, 4), Vector3(2, 1, 2), _solid("#f6e8c8"))
	return grid


## A loaf: long and domed, golden brown, with scores across its top.
static func _bread() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(14, 7, 8))
	grid.ellipsoid(Vector3(7, 2.5, 4), Vector3(6.4, 3.0, 3.4), _solid("#b8742f"))
	grid.ellipsoid(Vector3(7, 3.4, 4), Vector3(5.6, 2.4, 2.6), _solid("#cf8f45"))
	for x: int in [4, 7, 10]:
		for z in range(2, 6):
			grid.set_voxel(Vector3i(x + (z - 2) / 2, 5, z), _solid("#e9b86a"))
	return grid


static func _solid(hex: String) -> int:
	return VoxelGrid.voxel(Color(hex))


static func _leaf(hex: String) -> int:
	return VoxelGrid.voxel(Color(hex), VoxelGrid.Kind.FOLIAGE)
