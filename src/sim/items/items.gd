class_name Items
extends RefCounted
## Item registry: every item's name, stack size and the block it places,
## what each broken voxel gives ("every block gives something": grass
## gives dirt, a tree its logs...) and the tools (what each one is made
## for and of, see Mining.break_seconds). Ids are saved in inventories and
## in the world: only append to the enum, never renumber.

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
	WOODEN_PICKAXE,
	WOODEN_AXE,
	WOODEN_SHOVEL,
	STONE_PICKAXE,
	STONE_AXE,
	STONE_SHOVEL,
	COPPER_PICKAXE,
	COPPER_AXE,
	COPPER_SHOVEL,
	IRON_PICKAXE,
	IRON_AXE,
	IRON_SHOVEL,
	GOLDEN_PICKAXE,
	GOLDEN_AXE,
	GOLDEN_SHOVEL,
	DIAMOND_PICKAXE,
	DIAMOND_AXE,
	DIAMOND_SHOVEL,
	GUIDE_BOOK,
	OAK_PLANKS,
	BIRCH_PLANKS,
	SPRUCE_PLANKS,
	DARK_OAK_PLANKS,
	JUNGLE_PLANKS,
	ACACIA_PLANKS,
	WORKBENCH,
	COPPER_INGOT,
	IRON_INGOT,
	GOLD_INGOT,
	CHEST,
	FOOD_FURNACE,
	FACTORY_FURNACE,
	DRIED_BERRIES,
	MUSHROOM_STEW,
	CHARCOAL,
	CHARRED_FOOD,
	STONE_BRICKS,
	SMOOTH_STONE,
	BRICK,
	BRICKS,
	DEEPSLATE_BRICKS,
	CUT_SANDSTONE,
	GLASS,
	WOOL,
	RAW_MUTTON,
	COOKED_MUTTON,
	RAW_PORK,
	COOKED_PORK,
	RAW_CHICKEN,
	COOKED_CHICKEN,
	RAW_VENISON,
	COOKED_VENISON,
	FEATHER,
	HIDE,
	MOTH_DUST,
	SHADE_ESSENCE,
	WISP_EMBER,
	WOODEN_SWORD,
	STONE_SWORD,
	COPPER_SWORD,
	IRON_SWORD,
	GOLDEN_SWORD,
	DIAMOND_SWORD,
	BOW,
	ARROW,
	STRING,
	HIDE_HELMET,
	HIDE_CHESTPLATE,
	HIDE_LEGGINGS,
	HIDE_BOOTS,
	COPPER_HELMET,
	COPPER_CHESTPLATE,
	COPPER_LEGGINGS,
	COPPER_BOOTS,
	IRON_HELMET,
	IRON_CHESTPLATE,
	IRON_LEGGINGS,
	IRON_BOOTS,
	GOLDEN_HELMET,
	GOLDEN_CHESTPLATE,
	GOLDEN_LEGGINGS,
	GOLDEN_BOOTS,
	DIAMOND_HELMET,
	DIAMOND_CHESTPLATE,
	DIAMOND_LEGGINGS,
	DIAMOND_BOOTS,
	TORCH_BRACKET,
	CURTAINS,
	GLASS_PANE,
	WINDOW,
	SINK,
	TOILET,
	TABLE,
	CHAIR,
	FENCE,
	GATE,
	BIG_GATE,
	CAMPFIRE,
	TORCH,
	LANTERN,
	OAK_SAPLING,
	BIRCH_SAPLING,
	SPRUCE_SAPLING,
	DARK_OAK_SAPLING,
	JUNGLE_SAPLING,
	ACACIA_SAPLING,
	SWAMP_OAK_SAPLING,
}
## What a tool is made for (Mining.tool_for: what it breaks faster).
enum Tool { NONE, PICKAXE, AXE, SHOVEL, SWORD }
## What a tool is made of.
enum Tier { WOOD, STONE, COPPER, IRON, GOLD, DIAMOND }

const MAX_STACK := 64
## Tools: [Tool, Tier]. They do not stack.
const TOOLS := {
	Id.WOODEN_PICKAXE: [Tool.PICKAXE, Tier.WOOD],
	Id.WOODEN_AXE: [Tool.AXE, Tier.WOOD],
	Id.WOODEN_SHOVEL: [Tool.SHOVEL, Tier.WOOD],
	Id.STONE_PICKAXE: [Tool.PICKAXE, Tier.STONE],
	Id.STONE_AXE: [Tool.AXE, Tier.STONE],
	Id.STONE_SHOVEL: [Tool.SHOVEL, Tier.STONE],
	Id.COPPER_PICKAXE: [Tool.PICKAXE, Tier.COPPER],
	Id.COPPER_AXE: [Tool.AXE, Tier.COPPER],
	Id.COPPER_SHOVEL: [Tool.SHOVEL, Tier.COPPER],
	Id.IRON_PICKAXE: [Tool.PICKAXE, Tier.IRON],
	Id.IRON_AXE: [Tool.AXE, Tier.IRON],
	Id.IRON_SHOVEL: [Tool.SHOVEL, Tier.IRON],
	Id.GOLDEN_PICKAXE: [Tool.PICKAXE, Tier.GOLD],
	Id.GOLDEN_AXE: [Tool.AXE, Tier.GOLD],
	Id.GOLDEN_SHOVEL: [Tool.SHOVEL, Tier.GOLD],
	Id.DIAMOND_PICKAXE: [Tool.PICKAXE, Tier.DIAMOND],
	Id.DIAMOND_AXE: [Tool.AXE, Tier.DIAMOND],
	Id.DIAMOND_SHOVEL: [Tool.SHOVEL, Tier.DIAMOND],
	Id.WOODEN_SWORD: [Tool.SWORD, Tier.WOOD],
	Id.STONE_SWORD: [Tool.SWORD, Tier.STONE],
	Id.COPPER_SWORD: [Tool.SWORD, Tier.COPPER],
	Id.IRON_SWORD: [Tool.SWORD, Tier.IRON],
	Id.GOLDEN_SWORD: [Tool.SWORD, Tier.GOLD],
	Id.DIAMOND_SWORD: [Tool.SWORD, Tier.DIAMOND],
}
## How many shots a bow lasts (Minecraft's).
const BOW_DURABILITY := 384
## How many times faster a tool breaks what it is made for, by tier
## (Minecraft's, copper between stone and iron; gold is the fastest but
## will be the first to wear out once tools wear).
const TIER_SPEED: Array[float] = [2.0, 4.0, 5.0, 6.0, 12.0, 8.0]
## How many blocks a tool of each tier breaks before it breaks (Minecraft's;
## copper between stone and iron).
const TIER_DURABILITY: Array[int] = [59, 131, 190, 250, 32, 1561]

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
	Id.OAK_PLANKS: Tiles.Block.OAK_PLANKS,
	Id.BIRCH_PLANKS: Tiles.Block.BIRCH_PLANKS,
	Id.SPRUCE_PLANKS: Tiles.Block.SPRUCE_PLANKS,
	Id.DARK_OAK_PLANKS: Tiles.Block.DARK_OAK_PLANKS,
	Id.JUNGLE_PLANKS: Tiles.Block.JUNGLE_PLANKS,
	Id.ACACIA_PLANKS: Tiles.Block.ACACIA_PLANKS,
	Id.WORKBENCH: Tiles.Block.WORKBENCH,
	Id.CHEST: Tiles.Block.CHEST,
	Id.FOOD_FURNACE: Tiles.Block.FOOD_FURNACE,
	Id.FACTORY_FURNACE: Tiles.Block.FACTORY_FURNACE,
	Id.STONE_BRICKS: Tiles.Block.STONE_BRICKS,
	Id.SMOOTH_STONE: Tiles.Block.SMOOTH_STONE,
	Id.BRICKS: Tiles.Block.BRICKS,
	Id.DEEPSLATE_BRICKS: Tiles.Block.DEEPSLATE_BRICKS,
	Id.CUT_SANDSTONE: Tiles.Block.CUT_SANDSTONE,
	Id.GLASS: Tiles.Block.GLASS,
	Id.WOOL: Tiles.Block.WOOL,
	Id.WINDOW: Tiles.Block.WINDOW,
	Id.TORCH_BRACKET: Tiles.Block.TORCH_BRACKET,
	Id.CURTAINS: Tiles.Block.CURTAINS,
	Id.GLASS_PANE: Tiles.Block.GLASS_PANE,
	Id.SINK: Tiles.Block.SINK,
	Id.TOILET: Tiles.Block.TOILET,
	Id.TABLE: Tiles.Block.TABLE,
	Id.CHAIR: Tiles.Block.CHAIR,
	Id.FENCE: Tiles.Block.FENCE,
	Id.GATE: Tiles.Block.GATE,
	Id.BIG_GATE: Tiles.Block.BIG_GATE,
	Id.CAMPFIRE: Tiles.Block.CAMPFIRE,
	Id.TORCH: Tiles.Block.TORCH,
	Id.LANTERN: Tiles.Block.LANTERN,
	Id.OAK_SAPLING: Tiles.Block.OAK_SAPLING,
	Id.BIRCH_SAPLING: Tiles.Block.BIRCH_SAPLING,
	Id.SPRUCE_SAPLING: Tiles.Block.SPRUCE_SAPLING,
	Id.DARK_OAK_SAPLING: Tiles.Block.DARK_OAK_SAPLING,
	Id.JUNGLE_SAPLING: Tiles.Block.JUNGLE_SAPLING,
	Id.ACACIA_SAPLING: Tiles.Block.ACACIA_SAPLING,
	Id.SWAMP_OAK_SAPLING: Tiles.Block.SWAMP_OAK_SAPLING,
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
	Tiles.Block.OAK_PLANKS: [Id.OAK_PLANKS, 1, 1],
	Tiles.Block.BIRCH_PLANKS: [Id.BIRCH_PLANKS, 1, 1],
	Tiles.Block.SPRUCE_PLANKS: [Id.SPRUCE_PLANKS, 1, 1],
	Tiles.Block.DARK_OAK_PLANKS: [Id.DARK_OAK_PLANKS, 1, 1],
	Tiles.Block.JUNGLE_PLANKS: [Id.JUNGLE_PLANKS, 1, 1],
	Tiles.Block.ACACIA_PLANKS: [Id.ACACIA_PLANKS, 1, 1],
	Tiles.Block.WORKBENCH: [Id.WORKBENCH, 1, 1],
	Tiles.Block.WORKBENCH_WEST: [Id.WORKBENCH, 1, 1],
	Tiles.Block.WORKBENCH_NORTH: [Id.WORKBENCH, 1, 1],
	Tiles.Block.WORKBENCH_EAST: [Id.WORKBENCH, 1, 1],
	Tiles.Block.WORKBENCH_END_X: [Id.WORKBENCH, 1, 1],
	Tiles.Block.WORKBENCH_END_Z: [Id.WORKBENCH, 1, 1],
	Tiles.Block.CHEST: [Id.CHEST, 1, 1],
	Tiles.Block.CHEST_WEST: [Id.CHEST, 1, 1],
	Tiles.Block.CHEST_NORTH: [Id.CHEST, 1, 1],
	Tiles.Block.CHEST_EAST: [Id.CHEST, 1, 1],
	Tiles.Block.FOOD_FURNACE: [Id.FOOD_FURNACE, 1, 1],
	Tiles.Block.FOOD_FURNACE_WEST: [Id.FOOD_FURNACE, 1, 1],
	Tiles.Block.FOOD_FURNACE_NORTH: [Id.FOOD_FURNACE, 1, 1],
	Tiles.Block.FOOD_FURNACE_EAST: [Id.FOOD_FURNACE, 1, 1],
	Tiles.Block.FOOD_FURNACE_LIT: [Id.FOOD_FURNACE, 1, 1],
	Tiles.Block.FOOD_FURNACE_LIT_WEST: [Id.FOOD_FURNACE, 1, 1],
	Tiles.Block.FOOD_FURNACE_LIT_NORTH: [Id.FOOD_FURNACE, 1, 1],
	Tiles.Block.FOOD_FURNACE_LIT_EAST: [Id.FOOD_FURNACE, 1, 1],
	Tiles.Block.FACTORY_FURNACE: [Id.FACTORY_FURNACE, 1, 1],
	Tiles.Block.FACTORY_FURNACE_WEST: [Id.FACTORY_FURNACE, 1, 1],
	Tiles.Block.FACTORY_FURNACE_NORTH: [Id.FACTORY_FURNACE, 1, 1],
	Tiles.Block.FACTORY_FURNACE_EAST: [Id.FACTORY_FURNACE, 1, 1],
	Tiles.Block.FACTORY_FURNACE_LIT: [Id.FACTORY_FURNACE, 1, 1],
	Tiles.Block.FACTORY_FURNACE_LIT_WEST: [Id.FACTORY_FURNACE, 1, 1],
	Tiles.Block.FACTORY_FURNACE_LIT_NORTH: [Id.FACTORY_FURNACE, 1, 1],
	Tiles.Block.FACTORY_FURNACE_LIT_EAST: [Id.FACTORY_FURNACE, 1, 1],
	Tiles.Block.BROKEN_FURNACE: [Id.STONE, 2, 4],
	Tiles.Block.BROKEN_FURNACE_WEST: [Id.STONE, 2, 4],
	Tiles.Block.BROKEN_FURNACE_NORTH: [Id.STONE, 2, 4],
	Tiles.Block.BROKEN_FURNACE_EAST: [Id.STONE, 2, 4],
	Tiles.Block.STONE_BRICKS: [Id.STONE_BRICKS, 1, 1],
	Tiles.Block.SMOOTH_STONE: [Id.SMOOTH_STONE, 1, 1],
	Tiles.Block.BRICKS: [Id.BRICKS, 1, 1],
	Tiles.Block.DEEPSLATE_BRICKS: [Id.DEEPSLATE_BRICKS, 1, 1],
	Tiles.Block.CUT_SANDSTONE: [Id.CUT_SANDSTONE, 1, 1],
	Tiles.Block.GLASS: [Id.GLASS, 1, 1],
	Tiles.Block.WOOL: [Id.WOOL, 1, 1],
	Tiles.Block.WINDOW: [Id.WINDOW, 1, 1],
}
## Food: how much satiety eating one gives (Vitals.MAX_FOOD points; see
## also Vitals.POISONS). Cooking pays: dried berries, the stew and cooked
## meat feed best, charred food hardly.
const FOOD := {
	Id.BERRIES: 2,
	Id.DRIED_BERRIES: 4,
	Id.MUSHROOM_BROWN: 1,
	Id.MUSHROOM_RED: 1,
	Id.MUSHROOM_STEW: 8,
	Id.CHARRED_FOOD: 1,
	Id.RAW_MUTTON: 2,
	Id.COOKED_MUTTON: 7,
	Id.RAW_PORK: 3,
	Id.COOKED_PORK: 8,
	Id.RAW_CHICKEN: 2,
	Id.COOKED_CHICKEN: 6,
	Id.RAW_VENISON: 3,
	Id.COOKED_VENISON: 8,
}
## The planks each log is sawn into.
const PLANKS_OF := {
	Id.OAK_LOG: Id.OAK_PLANKS,
	Id.BIRCH_LOG: Id.BIRCH_PLANKS,
	Id.SPRUCE_LOG: Id.SPRUCE_PLANKS,
	Id.DARK_OAK_LOG: Id.DARK_OAK_PLANKS,
	Id.JUNGLE_LOG: Id.JUNGLE_PLANKS,
	Id.ACACIA_LOG: Id.ACACIA_PLANKS,
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
## The sapling a tree (grown or young) gives: a felled tree one or two, a
## young one its own back.
const SAPLING_OF := {
	Tiles.Block.OAK: Id.OAK_SAPLING,
	Tiles.Block.SWAMP_OAK: Id.SWAMP_OAK_SAPLING,
	Tiles.Block.BIRCH: Id.BIRCH_SAPLING,
	Tiles.Block.SPRUCE: Id.SPRUCE_SAPLING,
	Tiles.Block.SNOWY_SPRUCE: Id.SPRUCE_SAPLING,
	Tiles.Block.DARK_OAK: Id.DARK_OAK_SAPLING,
	Tiles.Block.JUNGLE_TREE: Id.JUNGLE_SAPLING,
	Tiles.Block.ACACIA: Id.ACACIA_SAPLING,
	Tiles.Block.YOUNG_OAK: Id.OAK_SAPLING,
	Tiles.Block.YOUNG_SWAMP_OAK: Id.SWAMP_OAK_SAPLING,
	Tiles.Block.YOUNG_BIRCH: Id.BIRCH_SAPLING,
	Tiles.Block.YOUNG_SPRUCE: Id.SPRUCE_SAPLING,
	Tiles.Block.YOUNG_DARK_OAK: Id.DARK_OAK_SAPLING,
	Tiles.Block.YOUNG_JUNGLE_TREE: Id.JUNGLE_SAPLING,
	Tiles.Block.YOUNG_ACACIA: Id.ACACIA_SAPLING,
}

## Block kind -> the item placing it (see drops).
static var _placed_by := _build_placed_by()


static func is_valid(item: int) -> bool:
	return item > Id.NONE and item < Id.size()


## Translation key of an item's name ("ITEM_DIRT"...).
static func name_key(item: int) -> String:
	return "ITEM_" + String(Id.find_key(item)) if is_valid(item) else ""


static func max_stack(item: int) -> int:
	if not is_valid(item):
		return 0
	if TOOLS.has(item) or item == Id.GUIDE_BOOK or item == Id.BOW or Armor.is_armor(item):
		return 1
	return MAX_STACK


static func is_food(item: int) -> bool:
	return FOOD.has(item)


## What a tool is made for (Tool.NONE for other items).
static func tool_of(item: int) -> int:
	return TOOLS[item][0] if TOOLS.has(item) else Tool.NONE


## What a tool is made of (-1 for other items).
static func tier_of(item: int) -> int:
	return TOOLS[item][1] if TOOLS.has(item) else -1


## How many times faster an item breaks what it is made for (1: a hand).
static func tool_speed(item: int) -> float:
	return TIER_SPEED[TOOLS[item][1]] if TOOLS.has(item) else 1.0


## How many uses a tool, a bow or a piece of armor lasts (0: it does not
## wear).
static func durability(item: int) -> int:
	if TOOLS.has(item):
		return TIER_DURABILITY[TOOLS[item][1]]
	if item == Id.BOW:
		return BOW_DURABILITY
	return Armor.durability(item)


## The tools of a tier: its pickaxe, axe and shovel.
static func tools_of_tier(tier: int) -> Array[int]:
	var result: Array[int] = []
	for item: int in TOOLS:
		if TOOLS[item][1] == tier:
			result.append(item)
	return result


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
		result.append(Vector2i(SAPLING_OF[block], rng.randi_range(1, 2)))
	elif SAPLING_OF.has(block):
		# A young tree: its sapling back, and a stick.
		result.append(Vector2i(SAPLING_OF[block], 1))
		result.append(Vector2i(Id.STICK, 1))
	elif BLOCK_DROPS.has(block):
		var drop: Array = BLOCK_DROPS[block]
		result.append(Vector2i(drop[0], rng.randi_range(drop[1], drop[2])))
	elif ObjectShapes.base_kind(block) == Tiles.Block.TORCH_BRACKET_LIT:
		result.append(Vector2i(Id.TORCH_BRACKET, 1))
		result.append(Vector2i(Id.TORCH, 1))
	elif _placed_by.has(ObjectShapes.base_kind(block)):
		# What players place gives itself back, any way it faces, open or
		# shut.
		result.append(Vector2i(_placed_by[ObjectShapes.base_kind(block)], 1))
	return result


## The item placing a block kind (Id.NONE: none; see _build_placed_by).
static func item_placing(kind: int) -> int:
	return _placed_by.get(kind, Id.NONE)


## Block kind -> the item placing it (PLACES_BLOCK; a gate's open kind
## too, a lantern hung up, a bracket holding a torch: the bracket).
static func _build_placed_by() -> Dictionary:
	var lookup := {}
	for item: int in PLACES_BLOCK:
		lookup[PLACES_BLOCK[item]] = item
	for shut: int in ObjectShapes.OPENS:
		lookup[ObjectShapes.OPENS[shut]] = lookup[shut]
	for shape: int in ObjectShapes.SHAPE_OF:
		lookup[shape] = lookup[ObjectShapes.SHAPE_OF[shape]]
	lookup[Tiles.Block.TORCH_BRACKET_LIT] = Id.TORCH_BRACKET
	return lookup
