class_name Recipes
extends RefCounted
## Crafting recipes: what a grid of items makes (shared by the client, who
## shows it at once, and the server, who decides). A shaped recipe is a
## pattern of ingredients that may sit anywhere in the grid, mirrored too;
## a shapeless one only counts its ingredients. An ingredient is an item or
## a group of items (any planks...). The inventory's 3 x 3 grid makes the
## recipes that fit in it, the workbench's grid (WORKBENCH_GRID) all of
## them, some only there ("workbench": true).

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
## The recipes besides the logs sawn into planks (see all()): a "pattern"
## (rows of letters, spaces left empty) and its "keys" (letter ->
## ingredient), and the "result" [item, count].
const SHAPED := [
	{"pattern": ["P", "P"], "keys": {"P": PLANKS}, "result": [Items.Id.STICK, 4]},
	{"pattern": ["PP", "PP"], "keys": {"P": PLANKS}, "result": [Items.Id.WORKBENCH, 1]},
]

static var _all: Array[Dictionary] = []


## Every recipe: each log gives 4 planks (shapeless: "ingredients"), then
## SHAPED.
static func all() -> Array[Dictionary]:
	if _all.is_empty():
		for log_item: int in Items.PLANKS_OF:
			_all.append({"ingredients": [log_item], "result": [Items.PLANKS_OF[log_item], 4]})
		for recipe: Dictionary in SHAPED:
			_all.append(recipe)
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
