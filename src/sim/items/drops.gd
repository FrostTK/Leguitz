class_name Drops
extends RefCounted
## What breaking a voxel gives (shared; Items.drops): a ground its soil,
## sand or stone (a worm now and then), a tree its logs, sticks and
## saplings, a crop its harvest, a block what BLOCK_DROPS says, what
## players place itself back (Items.item_placing).

## What a ground gives (soil gives dirt); grounds left out give nothing.
const GROUND_DROPS := {
	Tiles.Ground.GRASS: Items.Id.DIRT,
	Tiles.Ground.FOREST_GRASS: Items.Id.DIRT,
	Tiles.Ground.MEADOW_GRASS: Items.Id.DIRT,
	Tiles.Ground.TAIGA_GRASS: Items.Id.DIRT,
	Tiles.Ground.JUNGLE_GRASS: Items.Id.DIRT,
	Tiles.Ground.SWAMP_GRASS: Items.Id.DIRT,
	Tiles.Ground.DRY_GRASS: Items.Id.DIRT,
	Tiles.Ground.PODZOL: Items.Id.DIRT,
	Tiles.Ground.MYCELIUM: Items.Id.DIRT,
	Tiles.Ground.DIRT: Items.Id.DIRT,
	Tiles.Ground.FARMLAND: Items.Id.DIRT,
	Tiles.Ground.FARMLAND_WET: Items.Id.DIRT,
	Tiles.Ground.SAND: Items.Id.SAND,
	Tiles.Ground.RED_SAND: Items.Id.RED_SAND,
	Tiles.Ground.GRAVEL: Items.Id.GRAVEL,
	Tiles.Ground.SNOW: Items.Id.SNOW_BLOCK,
	Tiles.Ground.MUD: Items.Id.MUD,
	Tiles.Ground.ICE: Items.Id.ICE,
	Tiles.Ground.TERRACOTTA: Items.Id.TERRACOTTA,
	Tiles.Ground.TERRACOTTA_LIGHT: Items.Id.LIGHT_TERRACOTTA,
	Tiles.Ground.STONE_FLOOR: Items.Id.STONE,
	Tiles.Ground.DEEPSLATE_FLOOR: Items.Id.DEEPSLATE,
}
## What a block gives: [item, fewest, most].
const BLOCK_DROPS := {
	Tiles.Block.STONE: [Items.Id.STONE, 1, 1],
	Tiles.Block.DEEPSLATE: [Items.Id.DEEPSLATE, 1, 1],
	Tiles.Block.COAL_ORE: [Items.Id.COAL, 1, 2],
	Tiles.Block.COPPER_ORE: [Items.Id.RAW_COPPER, 1, 3],
	Tiles.Block.IRON_ORE: [Items.Id.RAW_IRON, 1, 1],
	Tiles.Block.GOLD_ORE: [Items.Id.RAW_GOLD, 1, 1],
	Tiles.Block.LAPIS_ORE: [Items.Id.LAPIS, 2, 4],
	Tiles.Block.RUBY_ORE: [Items.Id.RUBY, 1, 1],
	Tiles.Block.DIAMOND_ORE: [Items.Id.DIAMOND, 1, 1],
	Tiles.Block.EMERALD_ORE: [Items.Id.EMERALD, 1, 1],
	Tiles.Block.SANDSTONE: [Items.Id.SANDSTONE, 1, 1],
	Tiles.Block.PACKED_ICE: [Items.Id.PACKED_ICE, 1, 1],
	Tiles.Block.ROCK: [Items.Id.STONE, 2, 3],
	Tiles.Block.MOSSY_ROCK: [Items.Id.STONE, 2, 3],
	Tiles.Block.CACTUS: [Items.Id.CACTUS, 1, 2],
	Tiles.Block.BIG_MUSHROOM: [Items.Id.MUSHROOM_RED, 2, 3],
	Tiles.Block.TALL_GRASS: [Items.Id.SEEDS, 1, 1],
	Tiles.Block.FERN: [Items.Id.FERN, 1, 1],
	Tiles.Block.DEAD_BUSH: [Items.Id.STICK, 1, 2],
	Tiles.Block.BUSH: [Items.Id.STICK, 1, 2],
	Tiles.Block.BERRY_BUSH: [Items.Id.BERRIES, 1, 3],
	Tiles.Block.FLOWER_RED: [Items.Id.FLOWER_RED, 1, 1],
	Tiles.Block.FLOWER_YELLOW: [Items.Id.FLOWER_YELLOW, 1, 1],
	Tiles.Block.FLOWER_BLUE: [Items.Id.FLOWER_BLUE, 1, 1],
	Tiles.Block.FLOWER_WHITE: [Items.Id.FLOWER_WHITE, 1, 1],
	Tiles.Block.FLOWER_PINK: [Items.Id.FLOWER_PINK, 1, 1],
	Tiles.Block.MUSHROOM_RED: [Items.Id.MUSHROOM_RED, 1, 1],
	Tiles.Block.MUSHROOM_BROWN: [Items.Id.MUSHROOM_BROWN, 1, 1],
	Tiles.Block.SUGAR_CANE: [Items.Id.SUGAR_CANE, 1, 1],
	Tiles.Block.LILY_PAD: [Items.Id.LILY_PAD, 1, 1],
	Tiles.Block.OAK_PLANKS: [Items.Id.OAK_PLANKS, 1, 1],
	Tiles.Block.BIRCH_PLANKS: [Items.Id.BIRCH_PLANKS, 1, 1],
	Tiles.Block.SPRUCE_PLANKS: [Items.Id.SPRUCE_PLANKS, 1, 1],
	Tiles.Block.DARK_OAK_PLANKS: [Items.Id.DARK_OAK_PLANKS, 1, 1],
	Tiles.Block.JUNGLE_PLANKS: [Items.Id.JUNGLE_PLANKS, 1, 1],
	Tiles.Block.ACACIA_PLANKS: [Items.Id.ACACIA_PLANKS, 1, 1],
	Tiles.Block.WORKBENCH: [Items.Id.WORKBENCH, 1, 1],
	Tiles.Block.WORKBENCH_WEST: [Items.Id.WORKBENCH, 1, 1],
	Tiles.Block.WORKBENCH_NORTH: [Items.Id.WORKBENCH, 1, 1],
	Tiles.Block.WORKBENCH_EAST: [Items.Id.WORKBENCH, 1, 1],
	Tiles.Block.WORKBENCH_END_X: [Items.Id.WORKBENCH, 1, 1],
	Tiles.Block.WORKBENCH_END_Z: [Items.Id.WORKBENCH, 1, 1],
	Tiles.Block.CHEST: [Items.Id.CHEST, 1, 1],
	Tiles.Block.CHEST_WEST: [Items.Id.CHEST, 1, 1],
	Tiles.Block.CHEST_NORTH: [Items.Id.CHEST, 1, 1],
	Tiles.Block.CHEST_EAST: [Items.Id.CHEST, 1, 1],
	Tiles.Block.FOOD_FURNACE: [Items.Id.FOOD_FURNACE, 1, 1],
	Tiles.Block.FOOD_FURNACE_WEST: [Items.Id.FOOD_FURNACE, 1, 1],
	Tiles.Block.FOOD_FURNACE_NORTH: [Items.Id.FOOD_FURNACE, 1, 1],
	Tiles.Block.FOOD_FURNACE_EAST: [Items.Id.FOOD_FURNACE, 1, 1],
	Tiles.Block.FOOD_FURNACE_LIT: [Items.Id.FOOD_FURNACE, 1, 1],
	Tiles.Block.FOOD_FURNACE_LIT_WEST: [Items.Id.FOOD_FURNACE, 1, 1],
	Tiles.Block.FOOD_FURNACE_LIT_NORTH: [Items.Id.FOOD_FURNACE, 1, 1],
	Tiles.Block.FOOD_FURNACE_LIT_EAST: [Items.Id.FOOD_FURNACE, 1, 1],
	Tiles.Block.FACTORY_FURNACE: [Items.Id.FACTORY_FURNACE, 1, 1],
	Tiles.Block.FACTORY_FURNACE_WEST: [Items.Id.FACTORY_FURNACE, 1, 1],
	Tiles.Block.FACTORY_FURNACE_NORTH: [Items.Id.FACTORY_FURNACE, 1, 1],
	Tiles.Block.FACTORY_FURNACE_EAST: [Items.Id.FACTORY_FURNACE, 1, 1],
	Tiles.Block.FACTORY_FURNACE_LIT: [Items.Id.FACTORY_FURNACE, 1, 1],
	Tiles.Block.FACTORY_FURNACE_LIT_WEST: [Items.Id.FACTORY_FURNACE, 1, 1],
	Tiles.Block.FACTORY_FURNACE_LIT_NORTH: [Items.Id.FACTORY_FURNACE, 1, 1],
	Tiles.Block.FACTORY_FURNACE_LIT_EAST: [Items.Id.FACTORY_FURNACE, 1, 1],
	Tiles.Block.BROKEN_FURNACE: [Items.Id.STONE, 2, 4],
	Tiles.Block.BROKEN_FURNACE_WEST: [Items.Id.STONE, 2, 4],
	Tiles.Block.BROKEN_FURNACE_NORTH: [Items.Id.STONE, 2, 4],
	Tiles.Block.BROKEN_FURNACE_EAST: [Items.Id.STONE, 2, 4],
	Tiles.Block.STONE_BRICKS: [Items.Id.STONE_BRICKS, 1, 1],
	Tiles.Block.SMOOTH_STONE: [Items.Id.SMOOTH_STONE, 1, 1],
	Tiles.Block.BRICKS: [Items.Id.BRICKS, 1, 1],
	Tiles.Block.DEEPSLATE_BRICKS: [Items.Id.DEEPSLATE_BRICKS, 1, 1],
	Tiles.Block.CUT_SANDSTONE: [Items.Id.CUT_SANDSTONE, 1, 1],
	Tiles.Block.GLASS: [Items.Id.GLASS, 1, 1],
	Tiles.Block.WOOL: [Items.Id.WOOL, 1, 1],
	Tiles.Block.WINDOW: [Items.Id.WINDOW, 1, 1],
	Tiles.Block.MELON: [Items.Id.MELON_SLICE, 3, 6],
	Tiles.Block.BEE_NEST: [Items.Id.HONEYCOMB, 1, 2],
	Tiles.Block.BEE_NEST_1: [Items.Id.HONEYCOMB, 1, 2],
	Tiles.Block.BEE_NEST_2: [Items.Id.HONEYCOMB, 1, 3],
	Tiles.Block.BEE_NEST_3: [Items.Id.HONEYCOMB, 2, 3],
	Tiles.Block.MOLEHILL: [Items.Id.DIRT, 1, 1],
	Tiles.Block.BEAVER_DAM: [Items.Id.STICK, 2, 4],
	Tiles.Block.TURTLE_EGGS: [Items.Id.TURTLE_EGG, 1, 1],
	Tiles.Block.TURTLE_EGGS_1: [Items.Id.TURTLE_EGG, 1, 1],
	Tiles.Block.TURTLE_EGGS_2: [Items.Id.TURTLE_EGG, 1, 1],
}
## Digging soil turns up a worm this often.
const WORM_CHANCE := 0.06
## A felled tree gives a log per level of trunk, and a stick or two.
const TREE_LOGS := {
	Tiles.Block.OAK: Items.Id.OAK_LOG,
	Tiles.Block.SWAMP_OAK: Items.Id.OAK_LOG,
	Tiles.Block.BIRCH: Items.Id.BIRCH_LOG,
	Tiles.Block.SPRUCE: Items.Id.SPRUCE_LOG,
	Tiles.Block.SNOWY_SPRUCE: Items.Id.SPRUCE_LOG,
	Tiles.Block.DARK_OAK: Items.Id.DARK_OAK_LOG,
	Tiles.Block.JUNGLE_TREE: Items.Id.JUNGLE_LOG,
	Tiles.Block.ACACIA: Items.Id.ACACIA_LOG,
	Tiles.Block.APPLE_TREE: Items.Id.OAK_LOG,
	Tiles.Block.CHERRY_TREE: Items.Id.OAK_LOG,
	Tiles.Block.ORANGE_TREE: Items.Id.OAK_LOG,
	Tiles.Block.APPLE_TREE_FRUIT: Items.Id.OAK_LOG,
	Tiles.Block.CHERRY_TREE_FRUIT: Items.Id.OAK_LOG,
	Tiles.Block.ORANGE_TREE_FRUIT: Items.Id.OAK_LOG,
	Tiles.Block.PEACH_TREE: Items.Id.OAK_LOG,
	Tiles.Block.PEACH_TREE_FRUIT: Items.Id.OAK_LOG,
}
## The chance that tall grass broken gives a wild carrot or potato too.
const WILD_ROOTS := 0.08
## The sapling a tree (grown or young) gives: a felled tree one or two, a
## young one its own back (a fruit tree's are its pips).
const SAPLING_OF := {
	Tiles.Block.APPLE_TREE: Items.Id.APPLE_SEEDS,
	Tiles.Block.CHERRY_TREE: Items.Id.CHERRY_PITS,
	Tiles.Block.ORANGE_TREE: Items.Id.ORANGE_SEEDS,
	Tiles.Block.APPLE_TREE_FRUIT: Items.Id.APPLE_SEEDS,
	Tiles.Block.CHERRY_TREE_FRUIT: Items.Id.CHERRY_PITS,
	Tiles.Block.ORANGE_TREE_FRUIT: Items.Id.ORANGE_SEEDS,
	Tiles.Block.YOUNG_APPLE_TREE: Items.Id.APPLE_SEEDS,
	Tiles.Block.YOUNG_CHERRY_TREE: Items.Id.CHERRY_PITS,
	Tiles.Block.YOUNG_ORANGE_TREE: Items.Id.ORANGE_SEEDS,
	Tiles.Block.PEACH_TREE: Items.Id.PEACH_PIT,
	Tiles.Block.PEACH_TREE_FRUIT: Items.Id.PEACH_PIT,
	Tiles.Block.YOUNG_PEACH_TREE: Items.Id.PEACH_PIT,
	Tiles.Block.OAK: Items.Id.OAK_SAPLING,
	Tiles.Block.SWAMP_OAK: Items.Id.SWAMP_OAK_SAPLING,
	Tiles.Block.BIRCH: Items.Id.BIRCH_SAPLING,
	Tiles.Block.SPRUCE: Items.Id.SPRUCE_SAPLING,
	Tiles.Block.SNOWY_SPRUCE: Items.Id.SPRUCE_SAPLING,
	Tiles.Block.DARK_OAK: Items.Id.DARK_OAK_SAPLING,
	Tiles.Block.JUNGLE_TREE: Items.Id.JUNGLE_SAPLING,
	Tiles.Block.ACACIA: Items.Id.ACACIA_SAPLING,
	Tiles.Block.YOUNG_OAK: Items.Id.OAK_SAPLING,
	Tiles.Block.YOUNG_SWAMP_OAK: Items.Id.SWAMP_OAK_SAPLING,
	Tiles.Block.YOUNG_BIRCH: Items.Id.BIRCH_SAPLING,
	Tiles.Block.YOUNG_SPRUCE: Items.Id.SPRUCE_SAPLING,
	Tiles.Block.YOUNG_DARK_OAK: Items.Id.DARK_OAK_SAPLING,
	Tiles.Block.YOUNG_JUNGLE_TREE: Items.Id.JUNGLE_SAPLING,
	Tiles.Block.YOUNG_ACACIA: Items.Id.ACACIA_SAPLING,
}


## What breaking a voxel gives: [[item, count], ...]. `tile` is where it
## stood (trees: their size), `rng` draws the counts.
static func of(voxel: int, tile: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var block := Voxels.block_of(voxel)
	if block == Tiles.Block.AIR:
		var item: int = GROUND_DROPS.get(Voxels.ground_of(voxel), Items.Id.NONE)
		if item != Items.Id.NONE:
			result.append(Vector2i(item, 1))
		# Now and then a worm in the soil (a bait: Fishing).
		if Growth.is_soil(voxel) and rng.randf() < WORM_CHANCE:
			result.append(Vector2i(Items.Id.WORM, 1))
	elif TREE_LOGS.has(block):
		var variant := ObjectShapes.variant_at(block, tile)
		result.append(Vector2i(TREE_LOGS[block], ObjectShapes.blocking_levels(block, variant)))
		result.append(Vector2i(Items.Id.STICK, rng.randi_range(1, 2)))
		result.append(Vector2i(SAPLING_OF[block], rng.randi_range(1, 2)))
		# A fruit tree felled bearing fruit: the fruit too.
		if Picking.PICKED.has(block):
			result.append(Picking.picking(block, rng))
	elif SAPLING_OF.has(block):
		# A young tree: its sapling back, and a stick.
		result.append(Vector2i(SAPLING_OF[block], 1))
		result.append(Vector2i(Items.Id.STICK, 1))
	elif Farming.STAGES.has(block) or Farming.RIPE.has(block):
		result.append_array(Farming.harvest(block, rng))
	elif Farming.WILD.has(block):
		result.append_array(Farming.wild_harvest(block, rng))
	elif block == Tiles.Block.TALL_GRASS:
		result.append(Vector2i(Items.Id.SEEDS, 1))
		# Now and then a wild carrot or potato in the grass.
		if rng.randf() < WILD_ROOTS:
			result.append(Vector2i(Items.Id.CARROT if rng.randf() < 0.5 else Items.Id.POTATO, 1))
	elif BLOCK_DROPS.has(block):
		var drop: Array = BLOCK_DROPS[block]
		result.append(Vector2i(drop[0], rng.randi_range(drop[1], drop[2])))
	elif Picking.PICKED.has(block) and ObjectShapes.STAGE_OF.has(block):
		# A nest box holding eggs: the box and its eggs.
		result.append(Vector2i(Items.item_placing(ObjectShapes.base_kind(block)), 1))
		result.append(Picking.picking(block, rng))
	elif block == Tiles.Block.COMPOSTER_READY:
		result.append(Vector2i(Items.Id.COMPOSTER, 1))
		result.append(Vector2i(Items.Id.COMPOST, 1))
	elif ObjectShapes.base_kind(block) == Tiles.Block.TORCH_BRACKET_LIT:
		result.append(Vector2i(Items.Id.TORCH_BRACKET, 1))
		result.append(Vector2i(Items.Id.TORCH, 1))
	elif Items.item_placing(ObjectShapes.base_kind(block)) != Items.Id.NONE:
		# What players place gives itself back, any way it faces, open or
		# shut.
		result.append(Vector2i(Items.item_placing(ObjectShapes.base_kind(block)), 1))
	return result
