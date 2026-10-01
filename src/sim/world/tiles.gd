class_name Tiles
extends RefCounted
## Tile registry.
##
## Each world cell has a GROUND tile (what you walk on) and a BLOCK tile
## (what stands on it: trees, rocks, walls, ores, plants). Ids are stored in
## chunks: never renumber existing entries, only append.
## Phase 3 turns blocks into a data-driven block/item registry.

enum Ground {
	NONE,
	DEEP_WATER,
	WATER,
	SAND,
	GRASS,
	FOREST_GRASS,
	STONE_FLOOR,
	SNOW,
	DIRT,
	PODZOL,
	DRY_GRASS,
	JUNGLE_GRASS,
	SWAMP_GRASS,
	MEADOW_GRASS,
	TAIGA_GRASS,
	RED_SAND,
	TERRACOTTA,
	TERRACOTTA_LIGHT,
	GRAVEL,
	ICE,
	MUD,
	MYCELIUM,
	DEEPSLATE_FLOOR,
	LAVA,
	SWAMP_WATER,
	WARM_WATER,
}

enum Block {
	AIR,
	OAK,
	ROCK,
	BUSH,
	SPRUCE,
	STONE,
	DEEPSLATE,
	COAL_ORE,
	COPPER_ORE,
	IRON_ORE,
	GOLD_ORE,
	LAPIS_ORE,
	RUBY_ORE,
	DIAMOND_ORE,
	EMERALD_ORE,
	BIRCH,
	DARK_OAK,
	JUNGLE_TREE,
	ACACIA,
	SNOWY_SPRUCE,
	CACTUS,
	DEAD_BUSH,
	TALL_GRASS,
	FERN,
	FLOWER_RED,
	FLOWER_YELLOW,
	FLOWER_BLUE,
	FLOWER_WHITE,
	FLOWER_PINK,
	MUSHROOM_RED,
	MUSHROOM_BROWN,
	BIG_MUSHROOM,
	SUGAR_CANE,
	LILY_PAD,
	MOSSY_ROCK,
	SANDSTONE,
	BERRY_BUSH,
	PACKED_ICE,
	SWAMP_OAK,
	OAK_PLANKS,
	BIRCH_PLANKS,
	SPRUCE_PLANKS,
	DARK_OAK_PLANKS,
	JUNGLE_PLANKS,
	ACACIA_PLANKS,
	WORKBENCH,
	WORKBENCH_WEST,
	WORKBENCH_NORTH,
	WORKBENCH_EAST,
	WORKBENCH_END_X,
	WORKBENCH_END_Z,
	CHEST,
	CHEST_WEST,
	CHEST_NORTH,
	CHEST_EAST,
	FOOD_FURNACE,
	FOOD_FURNACE_WEST,
	FOOD_FURNACE_NORTH,
	FOOD_FURNACE_EAST,
	FOOD_FURNACE_LIT,
	FOOD_FURNACE_LIT_WEST,
	FOOD_FURNACE_LIT_NORTH,
	FOOD_FURNACE_LIT_EAST,
	FACTORY_FURNACE,
	FACTORY_FURNACE_WEST,
	FACTORY_FURNACE_NORTH,
	FACTORY_FURNACE_EAST,
	FACTORY_FURNACE_LIT,
	FACTORY_FURNACE_LIT_WEST,
	FACTORY_FURNACE_LIT_NORTH,
	FACTORY_FURNACE_LIT_EAST,
	BROKEN_FURNACE,
	BROKEN_FURNACE_WEST,
	BROKEN_FURNACE_NORTH,
	BROKEN_FURNACE_EAST,
	STONE_BRICKS,
	SMOOTH_STONE,
	BRICKS,
	DEEPSLATE_BRICKS,
	CUT_SANDSTONE,
	GLASS,
}

const FLOWERS: Array[Block] = [
	Block.FLOWER_RED,
	Block.FLOWER_YELLOW,
	Block.FLOWER_BLUE,
	Block.FLOWER_WHITE,
	Block.FLOWER_PINK,
]

const ORES: Array[Block] = [
	Block.COAL_ORE,
	Block.COPPER_ORE,
	Block.IRON_ORE,
	Block.GOLD_ORE,
	Block.LAPIS_ORE,
	Block.RUBY_ORE,
	Block.DIAMOND_ORE,
	Block.EMERALD_ORE,
]

## Movement speed multiplier per ground type (swimming, snow, mud...).
const GROUND_SPEED := {
	Ground.DEEP_WATER: 0.45,
	Ground.WATER: 0.6,
	Ground.SWAMP_WATER: 0.6,
	Ground.WARM_WATER: 0.6,
	Ground.SAND: 0.92,
	Ground.RED_SAND: 0.92,
	Ground.SNOW: 0.85,
	Ground.MUD: 0.75,
	Ground.GRAVEL: 0.95,
}

const WATER_GROUNDS := {
	Ground.DEEP_WATER: true,
	Ground.WATER: true,
	Ground.SWAMP_WATER: true,
	Ground.WARM_WATER: true,
}

## Grounds you cannot walk on (for now: lava).
const SOLID_GROUNDS := {Ground.LAVA: true, Ground.NONE: true}
## Full cube blocks (stone and the like): one level tall; on the surface a
## player can jump on top of them. Other solid blocks (trees, boulders...)
## are obstacles nobody stands on.
const CUBE_BLOCKS := {
	Block.STONE: true,
	Block.DEEPSLATE: true,
	Block.COAL_ORE: true,
	Block.COPPER_ORE: true,
	Block.IRON_ORE: true,
	Block.GOLD_ORE: true,
	Block.LAPIS_ORE: true,
	Block.RUBY_ORE: true,
	Block.DIAMOND_ORE: true,
	Block.EMERALD_ORE: true,
	Block.SANDSTONE: true,
	Block.PACKED_ICE: true,
	Block.OAK_PLANKS: true,
	Block.BIRCH_PLANKS: true,
	Block.SPRUCE_PLANKS: true,
	Block.DARK_OAK_PLANKS: true,
	Block.JUNGLE_PLANKS: true,
	Block.ACACIA_PLANKS: true,
	Block.STONE_BRICKS: true,
	Block.SMOOTH_STONE: true,
	Block.BRICKS: true,
	Block.DEEPSLATE_BRICKS: true,
	Block.CUT_SANDSTONE: true,
	Block.GLASS: true,
}

const NON_SOLID_BLOCKS := {
	Block.AIR: true,
	Block.BUSH: true,
	Block.DEAD_BUSH: true,
	Block.TALL_GRASS: true,
	Block.FERN: true,
	Block.FLOWER_RED: true,
	Block.FLOWER_YELLOW: true,
	Block.FLOWER_BLUE: true,
	Block.FLOWER_WHITE: true,
	Block.FLOWER_PINK: true,
	Block.MUSHROOM_RED: true,
	Block.MUSHROOM_BROWN: true,
	Block.SUGAR_CANE: true,
	Block.LILY_PAD: true,
	Block.BERRY_BUSH: true,
}


static func is_block_solid(block: int) -> bool:
	return not NON_SOLID_BLOCKS.has(block)


static func is_cube(block: int) -> bool:
	return CUBE_BLOCKS.has(block)


static func is_ground_solid(ground: int) -> bool:
	return SOLID_GROUNDS.has(ground)


static func ground_speed(ground: int) -> float:
	return GROUND_SPEED.get(ground, 1.0)


static func is_water(ground: int) -> bool:
	return WATER_GROUNDS.has(ground)


static func is_ore(block: int) -> bool:
	return block >= Block.COAL_ORE and block <= Block.EMERALD_ORE
