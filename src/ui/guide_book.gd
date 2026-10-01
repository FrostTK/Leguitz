class_name GuideBook
extends RefCounted
## What the player's book says (the 10th slot, shown by BookScreen): the
## controls as they are bound (in the player's keyboard layout), the
## gamepad, tips, tools and the recipes. A chapter is a list of entries:
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
]
const TIP_COUNT := 11
## The tools chapter: what each kind of tool is for, shown with this tool.
const TOOL_ROWS := [
	[Items.Id.IRON_PICKAXE, "BOOK_TOOLS_PICKAXE"],
	[Items.Id.IRON_SHOVEL, "BOOK_TOOLS_SHOVEL"],
	[Items.Id.IRON_AXE, "BOOK_TOOLS_AXE"],
]


## The entries of every chapter, in CHAPTERS order.
static func chapters() -> Array[Array]:
	return [_controls(), _gamepad(), _tips(), _tools(), _craft()]


static func _controls() -> Array:
	return [
		_title(CHAPTERS[0]),
		_keys("BOOK_MOVE", [InputNames.movement_keys(), _t("KEY_ARROWS")]),
		_keys("BOOK_SPRINT", InputNames.keys(InputBindings.SPRINT)),
		_keys("BOOK_JUMP", InputNames.keys(InputBindings.JUMP)),
		_keys("BOOK_BREAK", [_t("MOUSE_LEFT")]),
		_keys("BOOK_PLACE", [_t("MOUSE_RIGHT")]),
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
		var speed := "%s  ×%s" % [name, str(Items.TIER_SPEED[tier]).trim_suffix(".0")]
		entries.append(_icon(Items.tools_of_tier(tier)[0], speed))
	entries.append(_text("BOOK_TOOLS_GOLD"))
	entries.append(_text("BOOK_TOOLS_PLANTS"))
	return entries


## How to craft, then every recipe (the logs sawn into planks in one
## entry going through the woods).
static func _craft() -> Array:
	var entries := [_title(CHAPTERS[4]), _text("BOOK_CRAFT_HOW")]
	var planks := []
	for recipe: Dictionary in Recipes.all():
		if recipe.has("ingredients") and Items.PLANKS_OF.has(recipe["ingredients"][0]):
			planks.append(recipe)
	var sawn: int = planks[0]["result"][1]
	entries.append({"kind": Kind.RECIPE, "text": _t("BOOK_CRAFT_PLANKS") % sawn, "recipes": planks})
	for recipe: Dictionary in Recipes.all():
		if not recipe in planks:
			var result: Array = recipe["result"]
			var made := _t(Items.name_key(result[0]))
			if result[1] > 1:
				made += "  ×%d" % result[1]
			entries.append({"kind": Kind.RECIPE, "text": made, "recipes": [recipe]})
	entries.append(_text("BOOK_CRAFT_MORE"))
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


static func _t(key: String) -> String:
	return String(TranslationServer.translate(key))
