class_name Recipes
extends RefCounted
## Crafting recipes: what a grid of items makes (shared by the client, who
## shows it at once, and the server, who decides). A shaped recipe is a
## pattern of ingredients that may sit anywhere in the grid, mirrored too;
## a shapeless one only counts its ingredients. An ingredient is an item or
## a group of items (any planks...). The inventory's 3 x 3 grid makes the
## recipes that fit in it, the workbench's grid (WORKBENCH_GRID) all of
## them, some only there ("workbench": true: the tools, Minecraft's
## shapes; the 5 x 5 grid waits for bigger recipes to come). The kitchen
## counter's grid makes the dishes ("kitchen": true, KITCHEN), and only
## them; what holds a liquid stays in the grid (Items.LEFT_AFTER: the
## bucket of the milk, the jar of the jam).

const WORKBENCH_GRID := 5
## Any planks.
const PLANKS: Array[int] = [
	Items.Id.OAK_PLANKS,
	Items.Id.BIRCH_PLANKS,
	Items.Id.SPRUCE_PLANKS,
	Items.Id.DARK_OAK_PLANKS,
	Items.Id.JUNGLE_PLANKS,
	Items.Id.ACACIA_PLANKS,
]
## Any stone.
const STONES: Array[int] = [Items.Id.STONE, Items.Id.DEEPSLATE]
## Kitchen groups: any cooked meat, any mushroom, the greens of a soup,
## the fruits of a pie and of a jam.
const COOKED_MEATS: Array[int] = [
	Items.Id.COOKED_MUTTON,
	Items.Id.COOKED_PORK,
	Items.Id.COOKED_CHICKEN,
	Items.Id.COOKED_VENISON,
	Items.Id.COOKED_BEEF,
	Items.Id.COOKED_RABBIT,
	Items.Id.COOKED_DUCK,
	Items.Id.COOKED_FISH,
]
const MUSHROOMS: Array[int] = [Items.Id.MUSHROOM_BROWN, Items.Id.MUSHROOM_RED]
const SOUP_GREENS: Array[int] = [Items.Id.CABBAGE, Items.Id.TOMATO, Items.Id.BEETROOT]
const PIE_FRUITS: Array[int] = [
	Items.Id.APPLE,
	Items.Id.CHERRIES,
	Items.Id.PEACH,
	Items.Id.BERRIES,
	Items.Id.RASPBERRY,
	Items.Id.STRAWBERRY,
	Items.Id.PUMPKIN,
]
const JAM_FRUITS: Array[int] = [
	Items.Id.APPLE,
	Items.Id.CHERRIES,
	Items.Id.PEACH,
	Items.Id.ORANGE,
	Items.Id.GRAPES,
	Items.Id.BERRIES,
	Items.Id.RASPBERRY,
	Items.Id.STRAWBERRY,
]
## Any raw fish, crayfish or crab (fishing).
const SEAFOOD: Array[int] = [
	Items.Id.RAW_FISH,
	Items.Id.PERCH,
	Items.Id.TROUT,
	Items.Id.CARP,
	Items.Id.PIKE,
	Items.Id.CATFISH,
	Items.Id.EEL,
	Items.Id.SALMON,
	Items.Id.SARDINE,
	Items.Id.MACKEREL,
	Items.Id.COD,
	Items.Id.SEA_BASS,
	Items.Id.TUNA,
	Items.Id.LANTERNFISH,
	Items.Id.CAVE_FISH,
	Items.Id.CRAYFISH,
	Items.Id.CRAB,
]
## Pigments (a pot of paint: linseed oil and one, or two mixed).
const REDS: Array[int] = [Items.Id.FLOWER_RED, Items.Id.BEETROOT]
const BLUES: Array[int] = [Items.Id.FLOWER_BLUE, Items.Id.LAPIS]
## Coal or charcoal.
const COALS: Array[int] = [Items.Id.COAL, Items.Id.CHARCOAL]
## Any log.
const LOGS: Array[int] = [
	Items.Id.OAK_LOG,
	Items.Id.BIRCH_LOG,
	Items.Id.SPRUCE_LOG,
	Items.Id.DARK_OAK_LOG,
	Items.Id.JUNGLE_LOG,
	Items.Id.ACACIA_LOG,
]
## The recipes besides the logs sawn into planks and the tools (see
## all()): a "pattern" (rows of letters, spaces left empty) and its "keys"
## (letter -> ingredient), and the "result" [item, count].
const SHAPED := [
	{"pattern": ["P", "P"], "keys": {"P": PLANKS}, "result": [Items.Id.STICK, 4]},
	{"pattern": ["PP", "PP"], "keys": {"P": PLANKS}, "result": [Items.Id.WORKBENCH, 1]},
	{"pattern": ["PPP", "P P", "PPP"], "keys": {"P": PLANKS}, "result": [Items.Id.CHEST, 1]},
	{"pattern": ["SS", "SS"], "keys": {"S": Items.Id.SAND}, "result": [Items.Id.SANDSTONE, 1]},
	{
		"pattern": ["III", "III", "III"],
		"keys": {"I": Items.Id.ICE},
		"result": [Items.Id.PACKED_ICE, 1],
	},
	{"pattern": ["SS", "SS"], "keys": {"S": Items.Id.STONE}, "result": [Items.Id.STONE_BRICKS, 4]},
	{
		"pattern": ["DD", "DD"],
		"keys": {"D": Items.Id.DEEPSLATE},
		"result": [Items.Id.DEEPSLATE_BRICKS, 4],
	},
	{
		"pattern": ["SS", "SS"],
		"keys": {"S": Items.Id.SANDSTONE},
		"result": [Items.Id.CUT_SANDSTONE, 4],
	},
	{"pattern": ["BB", "BB"], "keys": {"B": Items.Id.BRICK}, "result": [Items.Id.BRICKS, 1]},
	{"ingredients": [Items.Id.WOOL], "result": [Items.Id.STRING, 4]},
	{
		"ingredients": [Items.Id.WHEAT, Items.Id.WHEAT, Items.Id.WHEAT],
		"result": [Items.Id.DOUGH, 1],
	},
	# The farm's: a watering can (its spout up a corner), a composter.
	{
		"pattern": ["C  ", " CC", " CC"],
		"keys": {"C": Items.Id.COPPER_INGOT},
		"result": [Items.Id.WATERING_CAN, 1],
	},
	{"pattern": ["P P", "P P", "PPP"], "keys": {"P": PLANKS}, "result": [Items.Id.COMPOSTER, 1]},
	# More crops: seeds from fruit, sugar, flax into string and linen, a
	# trellis for the vines.
	{"ingredients": [Items.Id.PUMPKIN], "result": [Items.Id.PUMPKIN_SEEDS, 4]},
	{"ingredients": [Items.Id.MELON_SLICE], "result": [Items.Id.MELON_SEEDS, 1]},
	{"ingredients": [Items.Id.TOMATO], "result": [Items.Id.TOMATO_SEEDS, 2]},
	{"ingredients": [Items.Id.GRAPES], "result": [Items.Id.GRAPE_SEEDS, 2]},
	{"ingredients": [Items.Id.APPLE], "result": [Items.Id.APPLE_SEEDS, 2]},
	{"ingredients": [Items.Id.CHERRIES], "result": [Items.Id.CHERRY_PITS, 2]},
	{"ingredients": [Items.Id.ORANGE], "result": [Items.Id.ORANGE_SEEDS, 2]},
	{"ingredients": [Items.Id.PEACH], "result": [Items.Id.PEACH_PIT, 1]},
	{"ingredients": [Items.Id.SUGAR_CANE], "result": [Items.Id.SUGAR, 1]},
	{"ingredients": [Items.Id.BEETROOT], "result": [Items.Id.SUGAR, 1]},
	{"ingredients": [Items.Id.FLAX], "result": [Items.Id.STRING, 1]},
	{"pattern": ["FF", "FF"], "keys": {"F": Items.Id.FLAX}, "result": [Items.Id.LINEN, 1]},
	# Fishing: the rod (its line hanging from the tip), a trap of sticks
	# and string, baits, driftwood broken into sticks.
	{
		"pattern": ["  S", " ST", "S T"],
		"keys": {"S": Items.Id.STICK, "T": Items.Id.STRING},
		"result": [Items.Id.FISHING_ROD, 1],
	},
	{
		"pattern": ["STS", "S S", "SSS"],
		"keys": {"S": Items.Id.STICK, "T": Items.Id.STRING},
		"result": [Items.Id.FISH_TRAP, 1],
	},
	{"ingredients": [Items.Id.FLOUR, Items.Id.CORN], "result": [Items.Id.BAIT_BALL, 4]},
	{"ingredients": [SEAFOOD], "result": [Items.Id.FISH_BAIT, 4]},
	{"ingredients": [Items.Id.DRIFTWOOD], "result": [Items.Id.STICK, 2]},
	# Boats, at the workbench: the shipyard (string rigging, an iron
	# winch), the hull's bow, sections and stern (its tiller), the coal
	# engine (a boiler around a factory furnace, a copper propeller), benches.
	{
		"pattern": ["T T", "LIL", "PPP"],
		"keys": {"T": Items.Id.STRING, "L": LOGS, "I": Items.Id.IRON_INGOT, "P": PLANKS},
		"result": [Items.Id.SHIPYARD, 1],
		"workbench": true,
	},
	{
		"pattern": [" P ", "P P", "PPP"],
		"keys": {"P": PLANKS},
		"result": [Items.Id.BOAT_BOW, 1],
		"workbench": true,
	},
	{
		"pattern": ["P P", "PPP"],
		"keys": {"P": PLANKS},
		"result": [Items.Id.BOAT_SECTION, 1],
		"workbench": true,
	},
	{
		"pattern": ["PSP", "P P", "PPP"],
		"keys": {"P": PLANKS, "S": Items.Id.STICK},
		"result": [Items.Id.BOAT_STERN, 1],
		"workbench": true,
	},
	{
		"pattern": ["III", "IFI", "III"],
		"keys": {"I": Items.Id.IRON_INGOT, "F": Items.Id.FACTORY_FURNACE},
		"result": [Items.Id.BOILER, 1],
		"workbench": true,
	},
	{
		"pattern": [" C ", "CIC", " C "],
		"keys": {"C": Items.Id.COPPER_INGOT, "I": Items.Id.IRON_INGOT},
		"result": [Items.Id.PROPELLER, 1],
		"workbench": true,
	},
	{
		"pattern": ["B", "I", "P"],
		"keys": {"B": Items.Id.BOILER, "I": Items.Id.IRON_INGOT, "P": Items.Id.PROPELLER},
		"result": [Items.Id.COAL_ENGINE, 1],
		"workbench": true,
	},
	{
		"pattern": ["PPP", "S S"],
		"keys": {"P": PLANKS, "S": Items.Id.STICK},
		"result": [Items.Id.BOAT_BENCH, 2],
		"workbench": true,
	},
	# The net (lead weights), mended with string; pots of paint.
	{
		"pattern": ["TTT", "TTT", "I I"],
		"keys": {"T": Items.Id.STRING, "I": Items.Id.IRON_INGOT},
		"result": [Items.Id.FISHING_NET, 1],
		"workbench": true,
	},
	{
		"ingredients": [Items.Id.FISHING_NET, Items.Id.STRING, Items.Id.STRING, Items.Id.STRING],
		"result": [Items.Id.FISHING_NET, 1],
	},
	{"ingredients": [Items.Id.LINSEED_OIL, REDS], "result": [Items.Id.PAINT_RED, 1]},
	{
		"ingredients": [Items.Id.LINSEED_OIL, Items.Id.FLOWER_YELLOW],
		"result": [Items.Id.PAINT_YELLOW, 1]
	},
	{"ingredients": [Items.Id.LINSEED_OIL, BLUES], "result": [Items.Id.PAINT_BLUE, 1]},
	{
		"ingredients": [Items.Id.LINSEED_OIL, Items.Id.FLOWER_WHITE],
		"result": [Items.Id.PAINT_WHITE, 1]
	},
	{
		"ingredients": [Items.Id.LINSEED_OIL, Items.Id.FLOWER_PINK],
		"result": [Items.Id.PAINT_PINK, 1]
	},
	{"ingredients": [Items.Id.LINSEED_OIL, Items.Id.CACTUS], "result": [Items.Id.PAINT_GREEN, 1]},
	{"ingredients": [Items.Id.LINSEED_OIL, COALS], "result": [Items.Id.PAINT_BLACK, 1]},
	{
		"ingredients": [Items.Id.LINSEED_OIL, REDS, Items.Id.FLOWER_YELLOW],
		"result": [Items.Id.PAINT_ORANGE, 1],
	},
	{"ingredients": [Items.Id.LINSEED_OIL, REDS, BLUES], "result": [Items.Id.PAINT_PURPLE, 1]},
	{
		"pattern": ["S S", "SSS", "S S"],
		"keys": {"S": Items.Id.STICK},
		"result": [Items.Id.TRELLIS, 2],
	},
	# Husbandry: shears, a bucket, a lead, a nest box.
	{"pattern": [" I", "I "], "keys": {"I": Items.Id.IRON_INGOT}, "result": [Items.Id.SHEARS, 1]},
	{"pattern": ["I I", " I "], "keys": {"I": Items.Id.IRON_INGOT}, "result": [Items.Id.BUCKET, 1]},
	{"pattern": ["SS", "SS"], "keys": {"S": Items.Id.STRING}, "result": [Items.Id.LEAD, 2]},
	{
		"pattern": ["PWP", "PPP"],
		"keys": {"P": PLANKS, "W": Items.Id.WHEAT},
		"result": [Items.Id.NEST_BOX, 1],
	},
	# Bees: glass bottles for the honey, a beehive of planks and honeycomb.
	{
		"pattern": ["G G", " G "],
		"keys": {"G": Items.Id.GLASS},
		"result": [Items.Id.GLASS_BOTTLE, 3],
	},
	{
		"pattern": ["PPP", "HHH", "PPP"],
		"keys": {"P": PLANKS, "H": Items.Id.HONEYCOMB},
		"result": [Items.Id.BEEHIVE, 1],
	},
	{
		"pattern": [" U ", "SWS", " S "],
		"keys": {"U": Items.Id.PUMPKIN, "S": Items.Id.STICK, "W": Items.Id.WHEAT},
		"result": [Items.Id.SCARECROW, 1],
	},
	{
		"pattern": ["P", "S", "F"],
		"keys": {"P": STONES, "S": Items.Id.STICK, "F": Items.Id.FEATHER},
		"result": [Items.Id.ARROW, 4],
	},
	{
		"pattern": [" SR", "S R", " SR"],
		"keys": {"S": Items.Id.STICK, "R": Items.Id.STRING},
		"result": [Items.Id.BOW, 1],
		"workbench": true,
	},
	{
		"pattern": ["SSS", "S S", "SSS"],
		"keys": {"S": STONES},
		"result": [Items.Id.FOOD_FURNACE, 1],
	},
	{
		"pattern": ["SSS", "SCS", "SSS"],
		"keys": {"S": STONES, "C": COALS},
		"result": [Items.Id.FACTORY_FURNACE, 1],
		"workbench": true,
	},
	# What houses and gardens are made of.
	{
		"pattern": ["I", "S"],
		"keys": {"I": Items.Id.IRON_INGOT, "S": Items.Id.STICK},
		"result": [Items.Id.TORCH_BRACKET, 2],
	},
	{
		"pattern": ["C", "S"],
		"keys": {"C": COALS, "S": Items.Id.STICK},
		"result": [Items.Id.TORCH, 4],
	},
	{
		"pattern": ["I", "T", "I"],
		"keys": {"I": Items.Id.IRON_INGOT, "T": Items.Id.TORCH},
		"result": [Items.Id.LANTERN, 1],
	},
	{
		"pattern": ["SSS", "W W", "W W"],
		"keys": {"S": Items.Id.STICK, "W": [Items.Id.WOOL, Items.Id.LINEN]},
		"result": [Items.Id.CURTAINS, 1],
	},
	{"pattern": ["GGG", "GGG"], "keys": {"G": Items.Id.GLASS}, "result": [Items.Id.GLASS_PANE, 16]},
	{
		"pattern": ["PPP", "PGP", "PPP"],
		"keys": {"P": PLANKS, "G": Items.Id.GLASS},
		"result": [Items.Id.WINDOW, 4],
	},
	{
		"pattern": ["PPP", "S S", "S S"],
		"keys": {"P": PLANKS, "S": Items.Id.STICK},
		"result": [Items.Id.TABLE, 1],
	},
	{
		"pattern": ["P  ", "PPP", "S S"],
		"keys": {"P": PLANKS, "S": Items.Id.STICK},
		"result": [Items.Id.CHAIR, 1],
	},
	{
		"pattern": ["PSP", "PSP"],
		"keys": {"P": PLANKS, "S": Items.Id.STICK},
		"result": [Items.Id.FENCE, 3],
	},
	{
		"pattern": ["SPS", "SPS"],
		"keys": {"P": PLANKS, "S": Items.Id.STICK},
		"result": [Items.Id.GATE, 1],
	},
	{
		"pattern": [" S ", "SCS", "LLL"],
		"keys": {"S": Items.Id.STICK, "C": COALS, "L": LOGS},
		"result": [Items.Id.CAMPFIRE, 1],
	},
	{
		"pattern": ["  I", "SSS", "PPP"],
		"keys": {"I": Items.Id.IRON_INGOT, "S": STONES, "P": PLANKS},
		"result": [Items.Id.SINK, 1],
		"workbench": true,
	},
	{
		"pattern": ["M  ", "MMM", " M "],
		"keys": {"M": Items.Id.SMOOTH_STONE},
		"result": [Items.Id.TOILET, 1],
		"workbench": true,
	},
	{
		"pattern": ["SPPPS", "SPPPS"],
		"keys": {"P": PLANKS, "S": Items.Id.STICK},
		"result": [Items.Id.BIG_GATE, 1],
		"workbench": true,
	},
	{
		"pattern": ["SSS", "PFP", "PPP"],
		"keys": {"S": STONES, "F": Items.Id.FOOD_FURNACE, "P": PLANKS},
		"result": [Items.Id.KITCHEN, 1],
		"workbench": true,
	},
	{
		"pattern": [" P ", "SSS", "PPP"],
		"keys": {"P": PLANKS, "S": STONES},
		"result": [Items.Id.MILL, 1],
	},
	{
		"pattern": [" T ", "P P", "PPP"],
		"keys": {"T": Items.Id.STICK, "P": PLANKS},
		"result": [Items.Id.BUTTER_CHURN, 1],
	},
	{
		"pattern": ["PIP", "P P", "PIP"],
		"keys": {"P": PLANKS, "I": Items.Id.IRON_INGOT},
		"result": [Items.Id.BARREL, 1],
	},
	{
		"pattern": ["PPP", "PLP", "PPP"],
		"keys": {"P": PLANKS, "L": Items.Id.LINEN},
		"result": [Items.Id.CHEESE_CELLAR, 1],
	},
]
## The tools, at the workbench: Minecraft's shapes ("M": the material,
## "S": a stick), and what each tier's are made of.
const TOOL_PATTERNS := {
	Items.Tool.PICKAXE: ["MMM", " S ", " S "],
	Items.Tool.AXE: ["MM", "MS", " S"],
	Items.Tool.SHOVEL: ["M", "S", "S"],
	Items.Tool.SWORD: ["M", "M", "S"],
	Items.Tool.HOE: ["MM", " S", " S"],
}
const TOOL_MATERIALS := {
	Items.Tier.WOOD: PLANKS,
	Items.Tier.STONE: STONES,
	Items.Tier.COPPER: Items.Id.COPPER_INGOT,
	Items.Tier.IRON: Items.Id.IRON_INGOT,
	Items.Tier.GOLD: Items.Id.GOLD_INGOT,
	Items.Tier.DIAMOND: Items.Id.DIAMOND,
}

## The kitchen counter's dishes (see the class): their ingredients, in any
## order.
const KITCHEN := [
	{
		"ingredients": [Items.Id.FLOUR, Items.Id.FLOUR, Items.Id.FLOUR],
		"result": [Items.Id.BREAD, 2]
	},
	{
		"ingredients": [Items.Id.CARROT, Items.Id.POTATO, SOUP_GREENS],
		"result": [Items.Id.VEGETABLE_SOUP, 2],
	},
	{
		"ingredients": [COOKED_MEATS, Items.Id.POTATO, Items.Id.CARROT, MUSHROOMS],
		"result": [Items.Id.MEAT_STEW, 2],
	},
	{
		"ingredients": [Items.Id.FLOUR, Items.Id.BUTTER, Items.Id.EGG, Items.Id.SUGAR, PIE_FRUITS],
		"result": [Items.Id.FRUIT_PIE, 1],
	},
	{
		"ingredients": [Items.Id.EGG, Items.Id.EGG, Items.Id.BUTTER],
		"result": [Items.Id.OMELETTE, 1]
	},
	{
		"ingredients":
		[
			Items.Id.FLOUR,
			Items.Id.FLOUR,
			Items.Id.EGG,
			Items.Id.SUGAR,
			Items.Id.BUTTER,
			Items.Id.MILK_BUCKET,
		],
		"result": [Items.Id.CAKE, 1],
	},
	{
		"ingredients": [Items.Id.FLOUR, Items.Id.EGG, Items.Id.MILK_BUCKET],
		"result": [Items.Id.CREPES, 3],
	},
	{
		"ingredients": [Items.Id.POTATO, Items.Id.POTATO, Items.Id.CHEESE, Items.Id.MILK_BUCKET],
		"result": [Items.Id.GRATIN, 2],
	},
	{
		"ingredients": [JAM_FRUITS, JAM_FRUITS, Items.Id.SUGAR, Items.Id.GLASS_BOTTLE],
		"result": [Items.Id.JAM, 1],
	},
	{
		"ingredients": [Items.Id.BREAD, Items.Id.BUTTER, Items.Id.JAM],
		"result": [Items.Id.TARTINE, 2],
	},
	{
		"ingredients": [SEAFOOD, SEAFOOD, Items.Id.POTATO, Items.Id.TOMATO],
		"result": [Items.Id.FISH_SOUP, 2],
	},
	{
		"ingredients": [Items.Id.COOKED_RICE, SEAFOOD, Items.Id.SEAWEED],
		"result": [Items.Id.SUSHI, 3],
	},
	{
		"ingredients": [SEAFOOD, Items.Id.POTATO, Items.Id.FLOUR, Items.Id.BUTTER],
		"result": [Items.Id.FRIED_FISH, 2],
	},
]

static var _all: Array[Dictionary] = []


## Every recipe: each log gives 4 planks (shapeless: "ingredients"),
## SHAPED, then the tools, the armor, and the kitchen's dishes.
static func all() -> Array[Dictionary]:
	if _all.is_empty():
		for log_item: int in Items.PLANKS_OF:
			_all.append({"ingredients": [log_item], "result": [Items.PLANKS_OF[log_item], 4]})
		for recipe: Dictionary in SHAPED:
			_all.append(recipe)
		for tool: int in Items.TOOLS:
			var keys := {"M": TOOL_MATERIALS[Items.tier_of(tool)], "S": Items.Id.STICK}
			var pattern: Array = TOOL_PATTERNS[Items.tool_of(tool)]
			_all.append({"pattern": pattern, "keys": keys, "result": [tool, 1], "workbench": true})
		for piece: int in Armor.ITEMS:
			var keys := {"M": Armor.MADE_OF[Armor.material_of(piece)]}
			var pattern: Array = Armor.PATTERNS[Armor.piece_of(piece)]
			_all.append({"pattern": pattern, "keys": keys, "result": [piece, 1], "workbench": true})
		for recipe: Dictionary in KITCHEN:
			var dish := recipe.duplicate()
			dish["kitchen"] = true
			_all.append(dish)
	return _all


## What a crafting grid makes: [item, count] (Vector2i.ZERO: nothing).
## `cells` holds width x width items, row by row (Items.Id.NONE: empty);
## `kitchen`: the kitchen counter's grid (its dishes only).
static func result_of(cells: PackedInt32Array, width: int, kitchen := false) -> Vector2i:
	var recipe := find(cells, width, kitchen)
	if recipe.is_empty():
		return Vector2i.ZERO
	return Vector2i(recipe["result"][0], recipe["result"][1])


## The recipe a crafting grid makes ({} if none).
static func find(cells: PackedInt32Array, width: int, kitchen := false) -> Dictionary:
	var low := Vector2i(width, width)
	var high := Vector2i(-1, -1)
	var used: Array[int] = []
	for row in width:
		for column in width:
			var item := cells[row * width + column]
			if item != Items.Id.NONE:
				low = low.min(Vector2i(column, row))
				high = high.max(Vector2i(column, row))
				used.append(item)
	if used.is_empty():
		return {}
	var size := high - low + Vector2i.ONE
	for recipe in all():
		if recipe.get("workbench", false) and width < WORKBENCH_GRID:
			continue
		if recipe.get("kitchen", false) != kitchen:
			continue
		if recipe.has("pattern"):
			if (
				_fits(recipe, cells, width, low, size, false)
				or _fits(recipe, cells, width, low, size, true)
			):
				return recipe
		elif _same_ingredients(recipe["ingredients"], used):
			return recipe
	return {}


## Whether an ingredient (an item or a group of items) takes an item.
static func accepts(ingredient: Variant, item: int) -> bool:
	if ingredient is Array:
		return item in ingredient
	return item == int(ingredient)


## The ingredient a shaped recipe wants at a cell of its pattern (null:
## the cell stays empty).
static func ingredient_at(recipe: Dictionary, cell: Vector2i) -> Variant:
	var row: String = recipe["pattern"][cell.y]
	var key := row[cell.x] if cell.x < row.length() else " "
	return null if key == " " else recipe["keys"][key]


## Whether the used part of the grid (`low`, `size`) is the recipe's
## pattern, mirrored or not.
static func _fits(
	recipe: Dictionary,
	cells: PackedInt32Array,
	width: int,
	low: Vector2i,
	size: Vector2i,
	mirrored: bool
) -> bool:
	var pattern: Array = recipe["pattern"]
	if size != Vector2i(String(pattern[0]).length(), pattern.size()):
		return false
	for y in size.y:
		for x in size.x:
			var ingredient: Variant = ingredient_at(
				recipe, Vector2i(size.x - 1 - x if mirrored else x, y)
			)
			var item := cells[(low.y + y) * width + low.x + x]
			if ingredient == null:
				if item != Items.Id.NONE:
					return false
			elif not accepts(ingredient, item):
				return false
	return true


## Whether the items used are the ingredients, one each, in any order.
static func _same_ingredients(ingredients: Array, used: Array[int]) -> bool:
	if ingredients.size() != used.size():
		return false
	var left := used.duplicate()
	# Single items first: the groups take what is left.
	var ordered := ingredients.duplicate()
	ordered.sort_custom(func(a: Variant, b: Variant) -> bool: return not a is Array and b is Array)
	for ingredient: Variant in ordered:
		var found := -1
		for i in left.size():
			if accepts(ingredient, left[i]):
				found = i
				break
		if found < 0:
			return false
		left.remove_at(found)
	return true
