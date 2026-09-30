class_name Tiles
extends RefCounted
## Tile registry (Phase 0 placeholder set).
##
## Each world cell has a GROUND tile (what you walk on) and a BLOCK tile
## (what stands on it: trees, rocks, placed blocks). Ids are stored in
## chunks, so never renumber existing entries: only append.
## Phase 3 replaces this with a data-driven block/item registry.

enum Ground {
	NONE,
	DEEP_WATER,
	WATER,
	SAND,
	GRASS,
	FOREST_GRASS,
	STONE_FLOOR,
	SNOW,
}

enum Block {
	AIR,
	TREE,
	ROCK,
	BUSH,
	PINE,
}

## Movement speed multiplier per ground type (swimming is slower).
const GROUND_SPEED := {
	Ground.NONE: 1.0,
	Ground.DEEP_WATER: 0.45,
	Ground.WATER: 0.6,
	Ground.SAND: 0.9,
	Ground.GRASS: 1.0,
	Ground.FOREST_GRASS: 1.0,
	Ground.STONE_FLOOR: 1.0,
	Ground.SNOW: 0.85,
}

const SOLID_BLOCKS := {
	Block.TREE: true,
	Block.ROCK: true,
	Block.PINE: true,
}


static func is_block_solid(block: int) -> bool:
	return SOLID_BLOCKS.has(block)


static func ground_speed(ground: int) -> float:
	return GROUND_SPEED.get(ground, 1.0)


static func is_water(ground: int) -> bool:
	return ground == Ground.WATER or ground == Ground.DEEP_WATER
