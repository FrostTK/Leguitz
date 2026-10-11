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
	WOODEN_HOE,
	STONE_HOE,
	COPPER_HOE,
	IRON_HOE,
	GOLDEN_HOE,
	DIAMOND_HOE,
	WHEAT,
	CARROT,
	POTATO,
	BAKED_POTATO,
	DOUGH,
	BREAD,
	WATERING_CAN,
	COMPOSTER,
	COMPOST,
	BEETROOT_SEEDS,
	BEETROOT,
	CABBAGE_SEEDS,
	CABBAGE,
	CORN,
	ROASTED_CORN,
	TOMATO_SEEDS,
	TOMATO,
	STRAWBERRY,
	FLAX_SEEDS,
	FLAX,
	LINEN,
	PUMPKIN_SEEDS,
	PUMPKIN,
	MELON_SEEDS,
	MELON_SLICE,
	RICE,
	COOKED_RICE,
	SUGAR,
	TRELLIS,
	GRAPE_SEEDS,
	GRAPES,
	APPLE,
	APPLE_SEEDS,
	CHERRIES,
	CHERRY_PITS,
	ORANGE,
	ORANGE_SEEDS,
	RASPBERRY,
	PEACH,
	PEACH_PIT,
	SHEARS,
	BUCKET,
	MILK_BUCKET,
	LEAD,
	EGG,
	FRIED_EGG,
	NEST_BOX,
	RAW_BEEF,
	COOKED_BEEF,
	RAW_RABBIT,
	COOKED_RABBIT,
	RAW_DUCK,
	COOKED_DUCK,
	GLASS_BOTTLE,
	HONEY_BOTTLE,
	HONEYCOMB,
	BEEHIVE,
	RAW_FISH,
	COOKED_FISH,
	SCARECROW,
	TURTLE_EGG,
	# The kitchen: what the mill, the churn, the barrel and the cheese
	# cellar make, the dishes cooked at the kitchen counter, and those.
	FLOUR,
	BUTTER,
	CHEESE,
	APPLE_JUICE,
	FRUIT_JUICE,
	CIDER,
	JAM,
	VEGETABLE_SOUP,
	MEAT_STEW,
	FRUIT_PIE,
	OMELETTE,
	CAKE,
	CREPES,
	GRATIN,
	TARTINE,
	KITCHEN,
	MILL,
	BUTTER_CHURN,
	BARREL,
	CHEESE_CELLAR,
	# Fishing (FishTable, Fishing): the rod, baits, the trap, the fish and
	# what traps catch, raw and grilled, junk a line brings up, the dishes.
	FISHING_ROD,
	WORM,
	BAIT_BALL,
	FISH_BAIT,
	FISH_TRAP,
	PERCH,
	TROUT,
	CARP,
	PIKE,
	CATFISH,
	EEL,
	SALMON,
	SARDINE,
	MACKEREL,
	COD,
	SEA_BASS,
	TUNA,
	LANTERNFISH,
	CAVE_FISH,
	CRAYFISH,
	CRAB,
	COOKED_PERCH,
	COOKED_TROUT,
	COOKED_CARP,
	COOKED_PIKE,
	COOKED_CATFISH,
	COOKED_EEL,
	COOKED_SALMON,
	COOKED_SARDINE,
	COOKED_MACKEREL,
	COOKED_COD,
	COOKED_SEA_BASS,
	COOKED_TUNA,
	COOKED_LANTERNFISH,
	COOKED_CAVE_FISH,
	COOKED_CRAYFISH,
	COOKED_CRAB,
	SEAWEED,
	DRIFTWOOD,
	FISH_SOUP,
	SUSHI,
	FRIED_FISH,
	# Boats (Boats): the shipyard, the hull's parts, the engine and its
	# parts, a bench.
	SHIPYARD,
	BOAT_BOW,
	BOAT_SECTION,
	BOAT_STERN,
	BOILER,
	PROPELLER,
	COAL_ENGINE,
	BOAT_BENCH,
	# The boat's net and paint: linseed oil (the mill's, of flax seeds), a
	# pot of each colour.
	FISHING_NET,
	LINSEED_OIL,
	PAINT_RED,
	PAINT_YELLOW,
	PAINT_BLUE,
	PAINT_WHITE,
	PAINT_PINK,
	PAINT_GREEN,
	PAINT_BLACK,
	PAINT_ORANGE,
	PAINT_PURPLE,
	# Stairs, slabs and side slabs (ShapedBlocks), per material.
	OAK_STAIRS,
	OAK_SLAB,
	OAK_SIDE_SLAB,
	BIRCH_STAIRS,
	BIRCH_SLAB,
	BIRCH_SIDE_SLAB,
	SPRUCE_STAIRS,
	SPRUCE_SLAB,
	SPRUCE_SIDE_SLAB,
	DARK_OAK_STAIRS,
	DARK_OAK_SLAB,
	DARK_OAK_SIDE_SLAB,
	JUNGLE_STAIRS,
	JUNGLE_SLAB,
	JUNGLE_SIDE_SLAB,
	ACACIA_STAIRS,
	ACACIA_SLAB,
	ACACIA_SIDE_SLAB,
	STONE_STAIRS,
	STONE_SLAB,
	STONE_SIDE_SLAB,
	SMOOTH_STONE_STAIRS,
	SMOOTH_STONE_SLAB,
	SMOOTH_STONE_SIDE_SLAB,
	STONE_BRICK_STAIRS,
	STONE_BRICK_SLAB,
	STONE_BRICK_SIDE_SLAB,
	BRICK_STAIRS,
	BRICK_SLAB,
	BRICK_SIDE_SLAB,
	DEEPSLATE_BRICK_STAIRS,
	DEEPSLATE_BRICK_SLAB,
	DEEPSLATE_BRICK_SIDE_SLAB,
	SANDSTONE_STAIRS,
	SANDSTONE_SLAB,
	SANDSTONE_SIDE_SLAB,
	CUT_SANDSTONE_STAIRS,
	CUT_SANDSTONE_SLAB,
	CUT_SANDSTONE_SIDE_SLAB,
	# Paints of the full palette (Tints), glass, panes and windows (Glass).
	PAINT_BROWN,
	PAINT_GREY,
	PAINT_SKY,
	PAINT_LIME,
	PAINT_OCHRE,
	PAINT_BURGUNDY,
	PAINT_TEAL,
	OLD_GLASS,
	LEADED_GLASS,
	OLD_GLASS_PANE,
	LEADED_GLASS_PANE,
	OAK_WINDOW_SMALL,
	OAK_WINDOW_SASH,
	OAK_WINDOW_ROUND,
	BIRCH_WINDOW,
	BIRCH_WINDOW_SMALL,
	BIRCH_WINDOW_SASH,
	BIRCH_WINDOW_ROUND,
	SPRUCE_WINDOW,
	SPRUCE_WINDOW_SMALL,
	SPRUCE_WINDOW_SASH,
	SPRUCE_WINDOW_ROUND,
	DARK_OAK_WINDOW,
	DARK_OAK_WINDOW_SMALL,
	DARK_OAK_WINDOW_SASH,
	DARK_OAK_WINDOW_ROUND,
	JUNGLE_WINDOW,
	JUNGLE_WINDOW_SMALL,
	JUNGLE_WINDOW_SASH,
	JUNGLE_WINDOW_ROUND,
	ACACIA_WINDOW,
	ACACIA_WINDOW_SMALL,
	ACACIA_WINDOW_SASH,
	ACACIA_WINDOW_ROUND,
	IRON_WINDOW,
	IRON_WINDOW_SMALL,
	IRON_WINDOW_SASH,
	IRON_WINDOW_ROUND,
	# Long curtains, on an iron rod; rugs.
	CURTAINS_LONG,
	CURTAINS_IRON,
	CURTAINS_LONG_IRON,
	RUG,
	# Doors, trapdoors, ladders, shutters, bars, railings.
	OAK_DOOR,
	BIRCH_DOOR,
	SPRUCE_DOOR,
	DARK_OAK_DOOR,
	JUNGLE_DOOR,
	ACACIA_DOOR,
	GLAZED_DOOR,
	IRON_DOOR,
	OAK_TRAPDOOR,
	IRON_TRAPDOOR,
	LADDER,
	SHUTTERS,
	IRON_BARS,
	WOOD_RAILING,
	IRON_RAILING,
	# Roofs: the coverings, their pieces, dormers, the chimney.
	ROOF_TILES,
	SLATES,
	SHINGLES,
	THATCH,
	TILE_ROOF,
	TILE_ROOF_RIDGE,
	TILE_ROOF_GENTLE,
	TILE_DORMER,
	SLATE_ROOF,
	SLATE_ROOF_RIDGE,
	SLATE_ROOF_GENTLE,
	SLATE_DORMER,
	SHINGLE_ROOF,
	SHINGLE_ROOF_RIDGE,
	SHINGLE_ROOF_GENTLE,
	SHINGLE_DORMER,
	THATCH_ROOF,
	THATCH_ROOF_RIDGE,
	THATCH_ROOF_GENTLE,
	THATCH_DORMER,
	CHIMNEY,
	# New materials: cubes, stairs and slabs, quarter blocks, walls,
	# pillars, beams.
	COBBLESTONE,
	ASHLAR,
	MOSSY_STONE,
	PLASTER,
	TIMBER_FRAME,
	TIMBER_FRAME_CROSS,
	TIMBER_FRAME_DIAGONAL,
	WATTLE_DAUB,
	OAK_PARQUET,
	OAK_HERRINGBONE,
	BIRCH_PARQUET,
	BIRCH_HERRINGBONE,
	SPRUCE_PARQUET,
	SPRUCE_HERRINGBONE,
	DARK_OAK_PARQUET,
	DARK_OAK_HERRINGBONE,
	JUNGLE_PARQUET,
	JUNGLE_HERRINGBONE,
	ACACIA_PARQUET,
	ACACIA_HERRINGBONE,
	CHECKER_TILES,
	TOMETTES,
	TERRACOTTA_BLOCK,
	POLISHED_SLATE,
	SANDSTONE_BRICKS,
	COBBLESTONE_STAIRS,
	COBBLESTONE_SLAB,
	COBBLESTONE_SIDE_SLAB,
	ASHLAR_STAIRS,
	ASHLAR_SLAB,
	ASHLAR_SIDE_SLAB,
	MOSSY_STONE_STAIRS,
	MOSSY_STONE_SLAB,
	MOSSY_STONE_SIDE_SLAB,
	PLASTER_STAIRS,
	PLASTER_SLAB,
	PLASTER_SIDE_SLAB,
	WATTLE_DAUB_STAIRS,
	WATTLE_DAUB_SLAB,
	WATTLE_DAUB_SIDE_SLAB,
	TERRACOTTA_STAIRS,
	TERRACOTTA_SLAB,
	TERRACOTTA_SIDE_SLAB,
	POLISHED_SLATE_STAIRS,
	POLISHED_SLATE_SLAB,
	POLISHED_SLATE_SIDE_SLAB,
	SANDSTONE_BRICK_STAIRS,
	SANDSTONE_BRICK_SLAB,
	SANDSTONE_BRICK_SIDE_SLAB,
	OAK_QUARTER,
	SPRUCE_QUARTER,
	SMOOTH_STONE_QUARTER,
	STONE_BRICK_QUARTER,
	BRICK_QUARTER,
	PLASTER_QUARTER,
	COBBLESTONE_WALL,
	STONE_BRICK_WALL,
	BRICK_WALL,
	MOSSY_STONE_WALL,
	SANDSTONE_WALL,
	STONE_COLUMN,
	BRICK_PILLAR,
	WOOD_POST,
	OAK_BEAM,
	SPRUCE_BEAM,
	DARK_OAK_BEAM,
	# Bedroom and living room.
	BED,
	WARDROBE,
	DRESSER,
	BOOKCASE,
	COMMODE,
	WALL_CUPBOARD,
	CRATE,
	BASKET,
	SHELF,
	ARMCHAIR,
	SOFA,
	BENCH,
	STOOL,
	ROCKING_CHAIR,
	COFFEE_TABLE,
	DESK,
	NIGHTSTAND,
	PEDESTAL_TABLE,
	TABLECLOTH,
	# Ambiance.
	CANDLE,
	CANDELABRA,
	CHANDELIER,
	BEDSIDE_LAMP,
	WALL_SCONCE,
	FIREPLACE,
	STOVE,
	PAINTING,
	PORTRAIT,
	WALL_CLOCK,
	MIRROR,
	FRAMED_MAP,
	DEER_TROPHY,
	BEAR_TROPHY,
	TAPESTRY,
	SPICE_RACK,
	COAT_RACK,
	CUSHION,
	FLOWER_POT,
	WINDOW_BOX,
	HOUSEPLANT,
	BATHTUB,
	SHOWER,
	WASHBASIN,
	GRANDFATHER_CLOCK,
	TOY_CHEST,
	PIANO,
	CRADLE,
	FOLDING_SCREEN,
}
## What a tool is made for (Mining.tool_for: what it breaks faster).
enum Tool { NONE, PICKAXE, AXE, SHOVEL, SWORD, HOE }
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
	Id.WOODEN_HOE: [Tool.HOE, Tier.WOOD],
	Id.STONE_HOE: [Tool.HOE, Tier.STONE],
	Id.COPPER_HOE: [Tool.HOE, Tier.COPPER],
	Id.IRON_HOE: [Tool.HOE, Tier.IRON],
	Id.GOLDEN_HOE: [Tool.HOE, Tier.GOLD],
	Id.DIAMOND_HOE: [Tool.HOE, Tier.DIAMOND],
}
## How many shots a bow lasts (Minecraft's), how many fleeces shears take,
## how many catches a fishing rod (Minecraft's).
const BOW_DURABILITY := 384
const SHEARS_DURABILITY := 238
const ROD_DURABILITY := 64
## How much a net takes (Nets: wear in the water, catches), how many coats
## a pot of paint gives.
const NET_DURABILITY := 120
const PAINT_COATS := 4
## The pots of paint, in the order of their colours (Boat.paint).
const PAINTS: Array[int] = [
	Id.PAINT_RED,
	Id.PAINT_YELLOW,
	Id.PAINT_BLUE,
	Id.PAINT_WHITE,
	Id.PAINT_PINK,
	Id.PAINT_GREEN,
	Id.PAINT_BLACK,
	Id.PAINT_ORANGE,
	Id.PAINT_PURPLE,
	Id.PAINT_BROWN,
	Id.PAINT_GREY,
	Id.PAINT_SKY,
	Id.PAINT_LIME,
	Id.PAINT_OCHRE,
	Id.PAINT_BURGUNDY,
	Id.PAINT_TEAL,
]
## Fewer of these in a stack.
const SMALL_STACKS := {
	Id.BUCKET: 16,
	Id.EGG: 16,
	Id.LEAD: 16,
	Id.GLASS_BOTTLE: 16,
	Id.HONEY_BOTTLE: 16,
	Id.APPLE_JUICE: 16,
	Id.FRUIT_JUICE: 16,
	Id.CIDER: 16,
	Id.JAM: 16,
	Id.VEGETABLE_SOUP: 16,
	Id.MEAT_STEW: 16,
	Id.CAKE: 16,
	Id.GRATIN: 16,
	Id.FISH_SOUP: 16,
	Id.LINSEED_OIL: 16,
}
## What a food leaves in hand once eaten (milk: its bucket; honey: its
## bottle).
const LEFT_AFTER := {
	Id.MILK_BUCKET: Id.BUCKET,
	Id.HONEY_BOTTLE: Id.GLASS_BOTTLE,
	Id.APPLE_JUICE: Id.GLASS_BOTTLE,
	Id.FRUIT_JUICE: Id.GLASS_BOTTLE,
	Id.CIDER: Id.GLASS_BOTTLE,
	Id.JAM: Id.GLASS_BOTTLE,
}
## How many tiles a full watering can waters (Watering). A can keeps the
## water it holds in its slot's wear (Inventory.wear: 0, empty, as made).
const CAN_WATER := 20
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
## Items that are other blocks (see ItemBlocks).
const PLACES_BLOCK := ItemBlocks.PLACES_BLOCK

## The planks each log is sawn into.
const PLANKS_OF := {
	Id.OAK_LOG: Id.OAK_PLANKS,
	Id.BIRCH_LOG: Id.BIRCH_PLANKS,
	Id.SPRUCE_LOG: Id.SPRUCE_PLANKS,
	Id.DARK_OAK_LOG: Id.DARK_OAK_PLANKS,
	Id.JUNGLE_LOG: Id.JUNGLE_PLANKS,
	Id.ACACIA_LOG: Id.ACACIA_PLANKS,
}
## Block kind -> the item placing it (see Drops).
static var _placed_by := _build_placed_by()


static func is_valid(item: int) -> bool:
	return item > Id.NONE and item < Id.size()


## Translation key of an item's name ("ITEM_DIRT"...).
static func name_key(item: int) -> String:
	return "ITEM_" + String(Id.find_key(item)) if is_valid(item) else ""


static func max_stack(item: int) -> int:
	if not is_valid(item):
		return 0
	if TOOLS.has(item) or item == Id.BOW or Armor.is_armor(item):
		return 1
	if item in [Id.GUIDE_BOOK, Id.WATERING_CAN, Id.SHEARS, Id.MILK_BUCKET, Id.FISHING_ROD]:
		return 1
	if item in [Id.BOAT_BOW, Id.BOAT_STERN, Id.COAL_ENGINE, Id.FISHING_NET] or item in PAINTS:
		return 1
	return SMALL_STACKS.get(item, MAX_STACK)


static func is_food(item: int) -> bool:
	return Food.SATIETY.has(item)


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
	if item == Id.SHEARS:
		return SHEARS_DURABILITY
	if item == Id.FISHING_ROD:
		return ROD_DURABILITY
	if item == Id.FISHING_NET:
		return NET_DURABILITY
	if item in PAINTS:
		return PAINT_COATS
	return Armor.durability(item)


## The most a slot's wear can be for an item (Inventory.wear): a tool's
## uses short of breaking, the water a watering can holds.
static func wear_limit(item: int) -> int:
	if item == Id.WATERING_CAN:
		return CAN_WATER
	return maxi(durability(item) - 1, 0)


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
	return Voxels.of_block(ShapedBlocks.placed_by(item))


## What breaking a voxel gives: [[item, count], ...] (see Drops).
static func drops(voxel: int, tile: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	return Drops.of(voxel, tile, rng)


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
	for tied: int in ObjectShapes.DRAWN:
		lookup[ObjectShapes.DRAWN[tied]] = lookup[tied]
	# Stairs and slabs, any way they face, up or down: the item of their
	# name (OAK_STAIRS_TOP_WEST: OAK_STAIRS; no other table, built after);
	# a roof's pieces: RoofBlocks'.
	for block: int in Tiles.Block.values():
		if Tiles.is_roof(block):
			lookup[block] = RoofBlocks.item_of(block)
			continue
		if not Tiles.is_shaped(block):
			continue
		var name := String(Tiles.Block.find_key(block))
		for shape: String in ["_SIDE_SLAB", "_STAIRS", "_SLAB", "_QUARTER"]:
			if shape in name:
				lookup[block] = Id[name.substr(0, name.find(shape)) + shape]
				break
	for shape: int in ObjectShapes.SHAPE_OF:
		lookup[shape] = lookup[ObjectShapes.SHAPE_OF[shape]]
	lookup[Tiles.Block.TORCH_BRACKET_LIT] = Id.TORCH_BRACKET
	# A bed's head: the bed.
	for way: String in ["", "_WEST", "_NORTH", "_EAST"]:
		lookup[Tiles.Block["BED_HEAD" + way]] = Id.BED
	# Beams lying along x or z: the beam.
	for kind: int in BuildShapes.BEAMS:
		for lying: int in BuildShapes.BEAMS[kind].slice(0, 2):
			lookup[lying] = lookup[kind]
	# A light put out, a shower running, a hearth lit: what placed it.
	for pairs: Dictionary in [Decor.SWITCHED, Hearths.LIT]:
		for placed: int in pairs:
			lookup[pairs[placed]] = lookup[placed]
	return lookup
