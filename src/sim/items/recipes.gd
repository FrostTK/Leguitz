class_name Recipes
extends RefCounted
## Crafting recipes: what a grid of items makes (shared by the client, who
## shows it at once, and the server, who decides). A shaped recipe is a
## pattern of ingredients that may sit anywhere in the grid, mirrored too;
## a shapeless one only counts its ingredients. An ingredient is an item or
## a group of items (any planks...). The inventory's 3 x 3 grid makes the
## recipes that fit in it, the workbench's grid (WORKBENCH_GRID) all of
## them, some only there ("workbench": true: the tools, Minecraft's
## shapes; the 5 x 5 grid waits for bigger recipes to come).

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

static var _all: Array[Dictionary] = []


## Every recipe: each log gives 4 planks (shapeless: "ingredients"),
## SHAPED, then the tools, then the armor.
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
	return _all


## What a crafting grid makes: [item, count] (Vector2i.ZERO: nothing).
## `cells` holds width x width items, row by row (Items.Id.NONE: empty).
static func result_of(cells: PackedInt32Array, width: int) -> Vector2i:
	var recipe := find(cells, width)
	if recipe.is_empty():
		return Vector2i.ZERO
	return Vector2i(recipe["result"][0], recipe["result"][1])


## The recipe a crafting grid makes ({} if none).
static func find(cells: PackedInt32Array, width: int) -> Dictionary:
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
