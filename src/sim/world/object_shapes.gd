class_name ObjectShapes
extends RefCounted
## Shapes of the objects standing in voxels (trees, rocks, cacti...), shared
## by physics and by the voxel models: the trunk drawn is the trunk that
## blocks. Each object block has a few versions (trees: TREE_VARIANTS); the
## version of a tile, and where small things stand in it, come from its
## position, so the server and every client agree.

const VARIANTS := 3
const TREE_VARIANTS := 8
const SALT := 0x9A0B
const SIZE_SALT := 0x51E5

## Per tree: trunk width (voxels = world pixels, even) and trunk height
## (voxels, 16 per level), smallest and largest.
const TREES := {
	Tiles.Block.OAK: [Vector2i(6, 10), Vector2i(44, 66)],
	Tiles.Block.BIRCH: [Vector2i(4, 6), Vector2i(58, 84)],
	Tiles.Block.DARK_OAK: [Vector2i(10, 14), Vector2i(40, 56)],
	Tiles.Block.JUNGLE_TREE: [Vector2i(8, 12), Vector2i(88, 128)],
	Tiles.Block.SWAMP_OAK: [Vector2i(6, 8), Vector2i(46, 62)],
	Tiles.Block.ACACIA: [Vector2i(4, 6), Vector2i(36, 48)],
	Tiles.Block.SPRUCE: [Vector2i(4, 6), Vector2i(84, 120)],
	Tiles.Block.SNOWY_SPRUCE: [Vector2i(4, 6), Vector2i(84, 120)],
}
## Other solid objects: the size of the square they block (voxels) and how
## many levels up.
const SOLIDS := {
	Tiles.Block.ROCK: [10, 1],
	Tiles.Block.MOSSY_ROCK: [10, 1],
	Tiles.Block.CACTUS: [8, 2],
	Tiles.Block.BIG_MUSHROOM: [8, 3],
}
## The ways an object placed facing the player can face, in the order of
## the blocks of each kind in FACING_KINDS.
const WAYS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)]
## Objects placed facing the player: each kind (its first block, whose
## model the others share) and its block for each of the WAYS. The
## workbench's are its left end seen from its front; furnaces come unlit
## and lit, and a food furnace that melted ore is broken.
const FACING_KINDS := {
	Tiles.Block.WORKBENCH:
	[
		Tiles.Block.WORKBENCH,
		Tiles.Block.WORKBENCH_WEST,
		Tiles.Block.WORKBENCH_NORTH,
		Tiles.Block.WORKBENCH_EAST,
	],
	Tiles.Block.CHEST:
	[
		Tiles.Block.CHEST,
		Tiles.Block.CHEST_WEST,
		Tiles.Block.CHEST_NORTH,
		Tiles.Block.CHEST_EAST,
	],
	Tiles.Block.FOOD_FURNACE:
	[
		Tiles.Block.FOOD_FURNACE,
		Tiles.Block.FOOD_FURNACE_WEST,
		Tiles.Block.FOOD_FURNACE_NORTH,
		Tiles.Block.FOOD_FURNACE_EAST,
	],
	Tiles.Block.FOOD_FURNACE_LIT:
	[
		Tiles.Block.FOOD_FURNACE_LIT,
		Tiles.Block.FOOD_FURNACE_LIT_WEST,
		Tiles.Block.FOOD_FURNACE_LIT_NORTH,
		Tiles.Block.FOOD_FURNACE_LIT_EAST,
	],
	Tiles.Block.FACTORY_FURNACE:
	[
		Tiles.Block.FACTORY_FURNACE,
		Tiles.Block.FACTORY_FURNACE_WEST,
		Tiles.Block.FACTORY_FURNACE_NORTH,
		Tiles.Block.FACTORY_FURNACE_EAST,
	],
	Tiles.Block.FACTORY_FURNACE_LIT:
	[
		Tiles.Block.FACTORY_FURNACE_LIT,
		Tiles.Block.FACTORY_FURNACE_LIT_WEST,
		Tiles.Block.FACTORY_FURNACE_LIT_NORTH,
		Tiles.Block.FACTORY_FURNACE_LIT_EAST,
	],
	Tiles.Block.BROKEN_FURNACE:
	[
		Tiles.Block.BROKEN_FURNACE,
		Tiles.Block.BROKEN_FURNACE_WEST,
		Tiles.Block.BROKEN_FURNACE_NORTH,
		Tiles.Block.BROKEN_FURNACE_EAST,
	],
}
## The workbench stands on two tiles: its left end (FACING_KINDS) holds
## the model, its right end lies beside it (one block per axis it lies
## along). It is BENCH_DEPTH voxels deep.
const BENCH_ENDS := {
	Tiles.Block.WORKBENCH_END_X: Vector2i(1, 0),
	Tiles.Block.WORKBENCH_END_Z: Vector2i(0, 1),
}
const BENCH_DEPTH := 14
## Chests and furnaces: so many voxels square, a level high.
const BOX_SIZE := 14
## Furniture bodies stand on (jumping onto it), by kind: how high its top
## is (voxels: their models' tops, WorkbenchModel, ChestModel,
## FurnaceModels). It blocks bodies up to there.
const TOPS := {
	Tiles.Block.WORKBENCH: 15,
	Tiles.Block.CHEST: 13,
	Tiles.Block.FOOD_FURNACE: 14,
	Tiles.Block.FOOD_FURNACE_LIT: 14,
	Tiles.Block.FACTORY_FURNACE: 14,
	Tiles.Block.FACTORY_FURNACE_LIT: 14,
	Tiles.Block.BROKEN_FURNACE: 14,
}
## The furnaces (their unlit kind) and their lit kind.
const LIT := {
	Tiles.Block.FOOD_FURNACE: Tiles.Block.FOOD_FURNACE_LIT,
	Tiles.Block.FACTORY_FURNACE: Tiles.Block.FACTORY_FURNACE_LIT,
}
## Small things stand anywhere in their tile (whole voxels), not centered.
const WANDERING := {
	Tiles.Block.TALL_GRASS: true,
	Tiles.Block.FERN: true,
	Tiles.Block.DEAD_BUSH: true,
	Tiles.Block.FLOWER_RED: true,
	Tiles.Block.FLOWER_YELLOW: true,
	Tiles.Block.FLOWER_BLUE: true,
	Tiles.Block.FLOWER_WHITE: true,
	Tiles.Block.FLOWER_PINK: true,
	Tiles.Block.MUSHROOM_RED: true,
	Tiles.Block.MUSHROOM_BROWN: true,
	Tiles.Block.LILY_PAD: true,
	Tiles.Block.ROCK: true,
	Tiles.Block.MOSSY_ROCK: true,
}

## block -> (kind, way index), for the facing objects.
static var _facing := _build_facing()


static func is_tree(block: int) -> bool:
	return TREES.has(block)


static func variant_count(block: int) -> int:
	if _facing.has(block) or BENCH_ENDS.has(block):
		return 1
	return TREE_VARIANTS if TREES.has(block) else VARIANTS


## The kind of a facing object (see FACING_KINDS; -1: not one).
static func kind_of(block: int) -> int:
	return _facing[block].x if _facing.has(block) else -1


## A part of a workbench (either end).
static func is_bench(block: int) -> bool:
	return kind_of(block) == Tiles.Block.WORKBENCH or BENCH_ENDS.has(block)


## A workbench's left end (the block holding its model).
static func is_bench_left(block: int) -> bool:
	return kind_of(block) == Tiles.Block.WORKBENCH


## A chest, whichever way it faces.
static func is_chest(block: int) -> bool:
	return kind_of(block) == Tiles.Block.CHEST


## A furnace that works, lit or not (its unlit kind; -1: not one).
static func furnace_kind(block: int) -> int:
	var kind := kind_of(block)
	for unlit: int in LIT:
		if kind == unlit or kind == LIT[unlit]:
			return unlit
	return -1


## A furnace burning (its lit kind).
static func is_lit(block: int) -> bool:
	return _facing.has(block) and kind_of(block) in LIT.values()


## The block whose model a block shows: the ways a facing object faces
## share one; -1 for the blocks showing none (a workbench's right end).
static func model_block(block: int) -> int:
	if BENCH_ENDS.has(block):
		return -1
	return kind_of(block) if _facing.has(block) else block


## Which way a facing object faces (ZERO: not one).
static func front_of(block: int) -> Vector2i:
	return WAYS[_facing[block].y] if _facing.has(block) else Vector2i.ZERO


## The block of a facing object (`kind`: see FACING_KINDS) facing `front`
## (a unit step on the ground).
static func facing(kind: int, front: Vector2i) -> int:
	return FACING_KINDS[kind][maxi(WAYS.find(front), 0)]


## How a facing object turns its model (made facing +z), radians about the
## vertical.
static func turn_of(block: int) -> float:
	var front := front_of(block)
	return atan2(front.x, front.y)


## How high (levels) the top of a piece of furniture is, to stand on it
## (0: not something to stand on).
static func stand_height(block: int) -> float:
	var kind := Tiles.Block.WORKBENCH if BENCH_ENDS.has(block) else kind_of(block)
	return TOPS.get(kind, 0) / float(GameConst.TILE_SIZE)


## How high (levels) an object blocks bodies from its voxel up: furniture
## up to its top, the others whole levels (blocking_levels).
static func blocking_height(block: int, variant: int) -> float:
	var top := stand_height(block)
	return top if top > 0.0 else float(blocking_levels(block, variant))


## Where a workbench's right end lies from its left end (on its right,
## seen from its front).
static func bench_right(block: int) -> Vector2i:
	var front := front_of(block)
	return Vector2i(front.y, -front.x)


## The block of a workbench's right end lying `right` of its left end.
static func bench_end(right: Vector2i) -> int:
	return Tiles.Block.WORKBENCH_END_X if right.x != 0 else Tiles.Block.WORKBENCH_END_Z


## Version of an object standing on a tile.
static func variant_at(block: int, tile: Vector2i) -> int:
	return HashUtil.hash2(SALT, tile.x, tile.y) % variant_count(block)


## Where an object stands in its tile (voxels from the center).
static func offset_at(block: int, tile: Vector2i) -> Vector2i:
	if not WANDERING.has(block):
		return Vector2i.ZERO
	var h := HashUtil.hash2(SALT, tile.x, tile.y)
	return Vector2i((h >> 8) % 7 - 3, (h >> 12) % 7 - 3)


## Trunk of a tree version: width and height (voxels). The versions spread
## over the whole range, in a shuffled order: every tree differs from its
## neighbors.
static func trunk(block: int, variant: int) -> Vector2i:
	var ranges: Array = TREES[block]
	var widths: Vector2i = ranges[0]
	var heights: Vector2i = ranges[1]
	var a := HashUtil.unit2(SIZE_SALT, block, variant)
	var b := (variant + HashUtil.unit2(SIZE_SALT + 1, block, variant)) / TREE_VARIANTS
	var width := roundi(lerpf(widths.x, widths.y, a) / 2.0) * 2
	return Vector2i(width, roundi(lerpf(heights.x, heights.y, b)))


## Size of the square an object blocks at its foot (voxels; 0: bodies walk
## through it).
static func footprint(block: int, variant: int) -> int:
	if _facing.has(block) and not is_bench_left(block):
		return BOX_SIZE
	if TREES.has(block):
		return trunk(block, variant).x
	if SOLIDS.has(block):
		return SOLIDS[block][0]
	return 0


## Levels an object blocks, from its voxel up.
static func blocking_levels(block: int, variant: int) -> int:
	if _facing.has(block) or BENCH_ENDS.has(block):
		return 1
	if TREES.has(block):
		return ceili(trunk(block, variant).y / float(GameConst.TILE_SIZE))
	if SOLIDS.has(block):
		return SOLIDS[block][1]
	return 0


## The box (world pixels) an object standing on a tile blocks (empty if it
## blocks nothing).
static func footprint_rect(block: int, tile: Vector2i) -> Rect2:
	if is_bench(block):
		# Its whole tile along the bench, BENCH_DEPTH across.
		var along: Vector2i = BENCH_ENDS.get(block, Vector2i.ZERO)
		if is_bench_left(block):
			along = bench_right(block).abs()
		var bench := (
			Vector2(along) * GameConst.TILE_SIZE + Vector2(Vector2i.ONE - along) * BENCH_DEPTH
		)
		return Rect2(Coords.tile_to_world_center(tile) - bench * 0.5, bench)
	var size := footprint(block, variant_at(block, tile))
	if size == 0:
		return Rect2()
	var center := Coords.tile_to_world_center(tile) + Vector2(offset_at(block, tile))
	return Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size)


static func _build_facing() -> Dictionary:
	var lookup := {}
	for kind: int in FACING_KINDS:
		var blocks: Array = FACING_KINDS[kind]
		for way in blocks.size():
			lookup[blocks[way]] = Vector2i(kind, way)
	return lookup
