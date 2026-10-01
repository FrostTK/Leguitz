class_name GuideBook
extends RefCounted
## What the player's book says (the 10th slot, shown by BookScreen): the
## controls as they are bound (in the player's keyboard layout), the
## gamepad, tips, tools, the recipes and the furnaces. A chapter is a list of entries:
## Dictionaries with a "kind" (Kind) and their text already translated,
## built again when the language changes.

enum Kind { TITLE, HEADING, TEXT, TIP, KEYS, COMBO, ICON, RECIPE }

## The chapters (their tab and title), in order.
const CHAPTERS: Array[String] = [
	"BOOK_CHAPTER_CONTROLS",
	"BOOK_CHAPTER_GAMEPAD",
	"BOOK_CHAPTER_TIPS",
	"BOOK_CHAPTER_TOOLS",
	"BOOK_CHAPTER_CRAFT",
	"BOOK_CHAPTER_FURNACES",
]
const TIP_COUNT := 15
## The tools chapter: what each kind of tool is for, shown with this tool.
## The fuels shown in the furnaces chapter: an item and its name.
const FUEL_ROWS := [
	[Items.Id.COAL, "ITEM_COAL"],
	[Items.Id.CHARCOAL, "ITEM_CHARCOAL"],
	[Items.Id.OAK_LOG, "BOOK_FURNACE_WOOD"],
	[Items.Id.STICK, "ITEM_STICK"],
]
const TOOL_ROWS := [
	[Items.Id.IRON_PICKAXE, "BOOK_TOOLS_PICKAXE"],
	[Items.Id.IRON_SHOVEL, "BOOK_TOOLS_SHOVEL"],
	[Items.Id.IRON_AXE, "BOOK_TOOLS_AXE"],
]


## The entries of every chapter, in CHAPTERS order.
static func chapters() -> Array[Array]:
	return [_controls(), _gamepad(), _tips(), _tools(), _craft(), _furnaces()]


static func _controls() -> Array:
	return [
		_title(CHAPTERS[0]),
		_keys("BOOK_MOVE", [InputNames.movement_keys(), _t("KEY_ARROWS")]),
		_keys("BOOK_SPRINT", InputNames.keys(InputBindings.SPRINT)),
		_keys("BOOK_JUMP", InputNames.keys(InputBindings.JUMP)),
		_keys("BOOK_BREAK", [_t("MOUSE_LEFT")]),
		_keys("BOOK_PLACE", [_t("MOUSE_RIGHT")]),
		_keys("BOOK_USE", InputNames.keys(InputBindings.USE)),
		_combo("BOOK_CAMERA", "BOOK_CAMERA_MOUSE"),
		_combo("BOOK_ZOOM", "BOOK_ZOOM_MOUSE"),
		_combo("BOOK_HAND", "BOOK_HAND_KEYS"),
		_keys("BOOK_INVENTORY", InputNames.keys(InputBindings.INVENTORY)),
		_keys("BOOK_DROP", InputNames.keys(InputBindings.DROP_ITEM)),
		_keys("BOOK_VIEW", InputNames.keys(InputBindings.TOGGLE_VIEW)),
		_keys("BOOK_CAMERA_RESET", InputNames.keys(InputBindings.CAMERA_RESET)),
		_keys("BOOK_PAUSE", InputNames.keys(InputBindings.PAUSE)),
		_heading("BOOK_DEBUG"),
		_keys("BOOK_DEBUG_SCREEN", InputNames.keys(InputBindings.TOGGLE_DEBUG)),
		_keys("BOOK_MAP", InputNames.keys(InputBindings.TOGGLE_MAP)),
		_keys(
			"BOOK_DEPTH",
			InputNames.keys(InputBindings.DEPTH_DOWN) + InputNames.keys(InputBindings.DEPTH_UP)
		),
		_keys("BOOK_NOCLIP", InputNames.keys(InputBindings.TOGGLE_NOCLIP)),
		_keys("BOOK_WEATHER", InputNames.keys(InputBindings.CYCLE_WEATHER)),
		_keys("BOOK_GIVE_TOOLS", InputNames.keys(InputBindings.GIVE_TOOLS)),
	]


static func _gamepad() -> Array:
	return [
		_title(CHAPTERS[1]),
		_keys("BOOK_MOVE", InputNames.pad(InputBindings.MOVE_UP)),
		_keys("BOOK_SPRINT", InputNames.pad(InputBindings.SPRINT)),
		_keys("BOOK_JUMP", InputNames.pad(InputBindings.JUMP)),
		_keys("BOOK_BREAK", InputNames.pad(InputBindings.BREAK)),
		_keys("BOOK_PLACE", InputNames.pad(InputBindings.PLACE)),
		_keys("BOOK_USE", InputNames.pad(InputBindings.USE)),
		_keys(
			"BOOK_HAND",
			(
				InputNames.pad(InputBindings.HOTBAR_PREVIOUS)
				+ InputNames.pad(InputBindings.HOTBAR_NEXT)
			)
		),
		_keys("BOOK_CAMERA", InputNames.pad(InputBindings.CAMERA_LEFT)),
		_keys("BOOK_CAMERA_RESET", InputNames.pad(InputBindings.CAMERA_RESET)),
		_keys("BOOK_VIEW", InputNames.pad(InputBindings.TOGGLE_VIEW)),
		_keys("BOOK_MAP", InputNames.pad(InputBindings.TOGGLE_MAP)),
		_keys("BOOK_PAUSE", InputNames.pad(InputBindings.PAUSE)),
		_keys("BOOK_DEBUG_SCREEN", InputNames.pad(InputBindings.TOGGLE_DEBUG)),
		_text("BOOK_GAMEPAD_AIM"),
	]


static func _tips() -> Array:
	var entries := [_title(CHAPTERS[2])]
	for i in TIP_COUNT:
		entries.append({"kind": Kind.TIP, "text": _t("BOOK_TIP_%d" % (i + 1))})
	return entries


static func _tools() -> Array:
	var entries := [_title(CHAPTERS[3]), _text("BOOK_TOOLS_INTRO")]
	for row: Array in TOOL_ROWS:
		entries.append(_icon(row[0], _t(row[1])))
	entries.append(_heading("BOOK_TOOLS_SPEED"))
	# Slowest first, from the tools' own speeds.
	var tiers := range(Items.Tier.size())
	tiers.sort_custom(
		func(a: int, b: int) -> bool: return Items.TIER_SPEED[a] < Items.TIER_SPEED[b]
	)
	for tier: int in tiers:
		var name := _t("TIER_" + String(Items.Tier.find_key(tier)))
		var speed := str(Items.TIER_SPEED[tier]).trim_suffix(".0")
		var lasts := Items.TIER_DURABILITY[tier]
		var text := _t("BOOK_TOOLS_TIER") % [name, speed, lasts]
		entries.append(_icon(Items.tools_of_tier(tier)[0], text))
	entries.append(_text("BOOK_TOOLS_WEAR"))
	entries.append(_text("BOOK_TOOLS_GOLD"))
	entries.append(_text("BOOK_TOOLS_PLANTS"))
	return entries


## How to craft, then every recipe (the logs sawn into planks in one
## entry going through the woods), the workbench's last (each kind of tool
## in one entry going through the materials, the factory furnace).
static func _craft() -> Array:
	var entries := [_title(CHAPTERS[4]), _text("BOOK_CRAFT_HOW")]
	var planks := []
	var tools := {}
	for recipe: Dictionary in Recipes.all():
		var made: int = recipe["result"][0]
		if recipe.has("ingredients") and Items.PLANKS_OF.has(recipe["ingredients"][0]):
			planks.append(recipe)
		elif Items.TOOLS.has(made):
			tools.get_or_add(Items.tool_of(made), []).append(recipe)
	var sawn: int = planks[0]["result"][1]
	entries.append({"kind": Kind.RECIPE, "text": _t("BOOK_CRAFT_PLANKS") % sawn, "recipes": planks})
	var at_bench := []
	for recipe: Dictionary in Recipes.all():
		if not recipe in planks and not Items.TOOLS.has(recipe["result"][0]):
			var result: Array = recipe["result"]
			var made := _t(Items.name_key(result[0]))
			if result[1] > 1:
				made += "  ×%d" % result[1]
			var entry := {"kind": Kind.RECIPE, "text": made, "recipes": [recipe]}
			(at_bench if recipe.get("workbench", false) else entries).append(entry)
	entries.append(_heading("BOOK_CRAFT_AT_BENCH"))
	for kind: int in tools:
		var label := _t("BOOK_CRAFT_" + String(Items.Tool.find_key(kind)))
		entries.append({"kind": Kind.RECIPE, "text": label, "recipes": tools[kind]})
	entries.append_array(at_bench)
	entries.append(_text("BOOK_CRAFT_MORE"))
	return entries


## How furnaces work, what each makes (drawn like recipes: one item in,
## what comes out), what breaks or chars, and the fuels.
static func _furnaces() -> Array:
	var entries := [_title(CHAPTERS[5]), _text("BOOK_FURNACE_HOW")]
	for kind: int in [Tiles.Block.FOOD_FURNACE, Tiles.Block.FACTORY_FURNACE]:
		var food := kind == Tiles.Block.FOOD_FURNACE
		entries.append(_heading("ITEM_FOOD_FURNACE" if food else "ITEM_FACTORY_FURNACE"))
		# What each makes, items making the same thing in one entry.
		var made := {}
		for item: int in Smelting.FOOD if food else Smelting.FACTORY:
			var result := Smelting.result_of(kind, item)
			made.get_or_add(result, []).append({"ingredients": [item], "result": [result, 1]})
		for result: int in made:
			entries.append(
				{"kind": Kind.RECIPE, "text": _t(Items.name_key(result)), "recipes": made[result]}
			)
		entries.append(_text("BOOK_FURNACE_FOOD_ORE" if food else "BOOK_FURNACE_FACTORY_FOOD"))
	entries.append(_heading("BOOK_FURNACE_FUELS"))
	for fuel: Array in FUEL_ROWS:
		var cooks := Smelting.burn_seconds(fuel[0]) / Smelting.COOK_SECONDS
		var amount := str(cooks).trim_suffix(".0").replace(".", _t("DECIMAL_SEPARATOR"))
		var text := _t("BOOK_FURNACE_FUEL") % [_t(fuel[1]), amount]
		entries.append(_icon(fuel[0], text))
	entries.append(_text("BOOK_FURNACE_PACE"))
	return entries


static func _title(key: String) -> Dictionary:
	return {"kind": Kind.TITLE, "text": _t(key)}


static func _heading(key: String) -> Dictionary:
	return {"kind": Kind.HEADING, "text": _t(key)}


static func _text(key: String) -> Dictionary:
	return {"kind": Kind.TEXT, "text": _t(key)}


## A control: what it does, and the keys (or buttons) to press.
static func _keys(label_key: String, names: Array) -> Dictionary:
	return {"kind": Kind.KEYS, "text": _t(label_key), "keys": PackedStringArray(names)}


## A control done with a gesture, told in words under what it does.
static func _combo(label_key: String, how_key: String) -> Dictionary:
	return {"kind": Kind.COMBO, "text": _t(label_key), "how": _t(how_key)}


static func _icon(item: int, text: String) -> Dictionary:
	return {"kind": Kind.ICON, "item": item, "text": text}


## A translated text; {use} and {inventory} in it name the keys of those
## controls as they are bound.
static func _t(key: String) -> String:
	var text := String(TranslationServer.translate(key))
	if not "{" in text:
		return text
	var keys := {
		"use": " / ".join(InputNames.keys(InputBindings.USE)),
		"inventory": " / ".join(InputNames.keys(InputBindings.INVENTORY)),
	}
	return text.format(keys)
