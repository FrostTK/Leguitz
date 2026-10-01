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


static func is_tree(block: int) -> bool:
	return TREES.has(block)


static func variant_count(block: int) -> int:
	return TREE_VARIANTS if TREES.has(block) else VARIANTS


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
	if TREES.has(block):
		return trunk(block, variant).x
	if SOLIDS.has(block):
		return SOLIDS[block][0]
	return 0


## Levels an object blocks, from its voxel up.
static func blocking_levels(block: int, variant: int) -> int:
	if TREES.has(block):
		return ceili(trunk(block, variant).y / float(GameConst.TILE_SIZE))
	if SOLIDS.has(block):
		return SOLIDS[block][1]
	return 0


## The box (world pixels) an object standing on a tile blocks (empty if it
## blocks nothing).
static func footprint_rect(block: int, tile: Vector2i) -> Rect2:
	var size := footprint(block, variant_at(block, tile))
	if size == 0:
		return Rect2()
	var center := Coords.tile_to_world_center(tile) + Vector2(offset_at(block, tile))
	return Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size)
