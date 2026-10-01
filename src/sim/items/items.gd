class_name Items
extends RefCounted
## Item registry: every item's name, stack size and the block it places,
## and what each broken voxel gives ("every block gives something": grass
## gives dirt, a tree its logs...). Ids are saved in inventories and in the
## world: only append to the enum, never renumber.

enum Id {
	NONE,
	DIRT,
	SAND,
	RED_SAND,
	GRAVEL,
	SNOW_BLOCK,
	MUD,
	ICE,
	TERRACOTTA,
	LIGHT_TERRACOTTA,
	STONE,
	DEEPSLATE,
	SANDSTONE,
	PACKED_ICE,
	COAL,
	RAW_COPPER,
	RAW_IRON,
	RAW_GOLD,
	LAPIS,
	RUBY,
	DIAMOND,
	EMERALD,
	OAK_LOG,
	BIRCH_LOG,
	SPRUCE_LOG,
	DARK_OAK_LOG,
	JUNGLE_LOG,
	ACACIA_LOG,
	STICK,
	SEEDS,
	BERRIES,
	FLOWER_RED,
	FLOWER_YELLOW,
	FLOWER_BLUE,
	FLOWER_WHITE,
	FLOWER_PINK,
	MUSHROOM_RED,
	MUSHROOM_BROWN,
	CACTUS,
	SUGAR_CANE,
	LILY_PAD,
	FERN,
}

const MAX_STACK := 64

## Items that are blocks: the voxel they place.
const PLACES := {
	Id.DIRT: Tiles.Ground.DIRT,
	Id.SAND: Tiles.Ground.SAND,
	Id.RED_SAND: Tiles.Ground.RED_SAND,
	Id.GRAVEL: Tiles.Ground.GRAVEL,
	Id.SNOW_BLOCK: Tiles.Ground.SNOW,
	Id.MUD: Tiles.Ground.MUD,
	Id.ICE: Tiles.Ground.ICE,
	Id.TERRACOTTA: Tiles.Ground.TERRACOTTA,
	Id.LIGHT_TERRACOTTA: Tiles.Ground.TERRACOTTA_LIGHT,
}
const PLACES_BLOCK := {
	Id.STONE: Tiles.Block.STONE,
	Id.DEEPSLATE: Tiles.Block.DEEPSLATE,
	Id.SANDSTONE: Tiles.Block.SANDSTONE,
	Id.PACKED_ICE: Tiles.Block.PACKED_ICE,
}

## What a ground gives (soil gives dirt); grounds left out give nothing.
const GROUND_DROPS := {
	Tiles.Ground.GRASS: Id.DIRT,
	Tiles.Ground.FOREST_GRASS: Id.DIRT,
	Tiles.Ground.MEADOW_GRASS: Id.DIRT,
	Tiles.Ground.TAIGA_GRASS: Id.DIRT,
	Tiles.Ground.JUNGLE_GRASS: Id.DIRT,
	Tiles.Ground.SWAMP_GRASS: Id.DIRT,
	Tiles.Ground.DRY_GRASS: Id.DIRT,
	Tiles.Ground.PODZOL: Id.DIRT,
	Tiles.Ground.MYCELIUM: Id.DIRT,
	Tiles.Ground.DIRT: Id.DIRT,
	Tiles.Ground.SAND: Id.SAND,
	Tiles.Ground.RED_SAND: Id.RED_SAND,
	Tiles.Ground.GRAVEL: Id.GRAVEL,
	Tiles.Ground.SNOW: Id.SNOW_BLOCK,
	Tiles.Ground.MUD: Id.MUD,
	Tiles.Ground.ICE: Id.ICE,
	Tiles.Ground.TERRACOTTA: Id.TERRACOTTA,
	Tiles.Ground.TERRACOTTA_LIGHT: Id.LIGHT_TERRACOTTA,
	Tiles.Ground.STONE_FLOOR: Id.STONE,
	Tiles.Ground.DEEPSLATE_FLOOR: Id.DEEPSLATE,
}
## What a block gives: [item, fewest, most].
const BLOCK_DROPS := {
	Tiles.Block.STONE: [Id.STONE, 1, 1],
	Tiles.Block.DEEPSLATE: [Id.DEEPSLATE, 1, 1],
	Tiles.Block.COAL_ORE: [Id.COAL, 1, 2],
	Tiles.Block.COPPER_ORE: [Id.RAW_COPPER, 1, 3],
	Tiles.Block.IRON_ORE: [Id.RAW_IRON, 1, 1],
	Tiles.Block.GOLD_ORE: [Id.RAW_GOLD, 1, 1],
	Tiles.Block.LAPIS_ORE: [Id.LAPIS, 2, 4],
	Tiles.Block.RUBY_ORE: [Id.RUBY, 1, 1],
	Tiles.Block.DIAMOND_ORE: [Id.DIAMOND, 1, 1],
	Tiles.Block.EMERALD_ORE: [Id.EMERALD, 1, 1],
	Tiles.Block.SANDSTONE: [Id.SANDSTONE, 1, 1],
	Tiles.Block.PACKED_ICE: [Id.PACKED_ICE, 1, 1],
	Tiles.Block.ROCK: [Id.STONE, 2, 3],
	Tiles.Block.MOSSY_ROCK: [Id.STONE, 2, 3],
	Tiles.Block.CACTUS: [Id.CACTUS, 1, 2],
	Tiles.Block.BIG_MUSHROOM: [Id.MUSHROOM_RED, 2, 3],
	Tiles.Block.TALL_GRASS: [Id.SEEDS, 1, 1],
	Tiles.Block.FERN: [Id.FERN, 1, 1],
	Tiles.Block.DEAD_BUSH: [Id.STICK, 1, 2],
	Tiles.Block.BUSH: [Id.STICK, 1, 2],
	Tiles.Block.BERRY_BUSH: [Id.BERRIES, 1, 3],
	Tiles.Block.FLOWER_RED: [Id.FLOWER_RED, 1, 1],
	Tiles.Block.FLOWER_YELLOW: [Id.FLOWER_YELLOW, 1, 1],
	Tiles.Block.FLOWER_BLUE: [Id.FLOWER_BLUE, 1, 1],
	Tiles.Block.FLOWER_WHITE: [Id.FLOWER_WHITE, 1, 1],
	Tiles.Block.FLOWER_PINK: [Id.FLOWER_PINK, 1, 1],
	Tiles.Block.MUSHROOM_RED: [Id.MUSHROOM_RED, 1, 1],
	Tiles.Block.MUSHROOM_BROWN: [Id.MUSHROOM_BROWN, 1, 1],
	Tiles.Block.SUGAR_CANE: [Id.SUGAR_CANE, 1, 1],
	Tiles.Block.LILY_PAD: [Id.LILY_PAD, 1, 1],
}
## A felled tree gives a log per level of trunk, and a stick or two.
const TREE_LOGS := {
	Tiles.Block.OAK: Id.OAK_LOG,
	Tiles.Block.SWAMP_OAK: Id.OAK_LOG,
	Tiles.Block.BIRCH: Id.BIRCH_LOG,
	Tiles.Block.SPRUCE: Id.SPRUCE_LOG,
	Tiles.Block.SNOWY_SPRUCE: Id.SPRUCE_LOG,
	Tiles.Block.DARK_OAK: Id.DARK_OAK_LOG,
	Tiles.Block.JUNGLE_TREE: Id.JUNGLE_LOG,
	Tiles.Block.ACACIA: Id.ACACIA_LOG,
}


static func is_valid(item: int) -> bool:
	return item > Id.NONE and item < Id.size()


## Translation key of an item's name ("ITEM_DIRT"...).
static func name_key(item: int) -> String:
	return "ITEM_" + String(Id.find_key(item)) if is_valid(item) else ""


static func max_stack(item: int) -> int:
	return MAX_STACK if is_valid(item) else 0


## The voxel a block item places, or Voxels.AIR for other items.
static func placed_voxel(item: int) -> int:
	if PLACES.has(item):
		return Voxels.of_ground(PLACES[item])
	if PLACES_BLOCK.has(item):
		return Voxels.of_block(PLACES_BLOCK[item])
	return Voxels.AIR


## What breaking a voxel gives: [[item, count], ...]. `tile` is where it
## stood (trees: their size), `rng` draws the counts.
static func drops(voxel: int, tile: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var block := Voxels.block_of(voxel)
	if block == Tiles.Block.AIR:
		var item: int = GROUND_DROPS.get(Voxels.ground_of(voxel), Id.NONE)
		if item != Id.NONE:
			result.append(Vector2i(item, 1))
	elif TREE_LOGS.has(block):
		var variant := ObjectShapes.variant_at(block, tile)
		result.append(Vector2i(TREE_LOGS[block], ObjectShapes.blocking_levels(block, variant)))
		result.append(Vector2i(Id.STICK, rng.randi_range(1, 2)))
	elif BLOCK_DROPS.has(block):
		var drop: Array = BLOCK_DROPS[block]
		result.append(Vector2i(drop[0], rng.randi_range(drop[1], drop[2])))
	return result
