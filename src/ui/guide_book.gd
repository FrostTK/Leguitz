class_name GuideBook
extends RefCounted
## What the player's book says (the 10th slot, shown by BookScreen): the
## controls as they are bound (in the player's keyboard layout), the
## gamepad, tips, tools, the recipes, the furnaces, home and garden,
## survival, the animals,
## the monsters, combat (swords, the bow, armor) and the game modes
## (creative's flight and debug keys). A chapter is a list of entries:
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
	"BOOK_CHAPTER_HOME",
	"BOOK_CHAPTER_FARM",
	"BOOK_CHAPTER_SURVIVAL",
	"BOOK_CHAPTER_ANIMALS",
	"BOOK_CHAPTER_MONSTERS",
	"BOOK_CHAPTER_COMBAT",
	"BOOK_CHAPTER_MODES",
]
const TIP_COUNT := 16
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
	[Items.Id.IRON_SWORD, "BOOK_TOOLS_SWORD"],
	[Items.Id.IRON_HOE, "BOOK_TOOLS_HOE"],
]


## The entries of every chapter, in CHAPTERS order.
static func chapters() -> Array[Array]:
	return [
		_controls(),
		_gamepad(),
		_tips(),
		_tools(),
		_craft(),
		_furnaces(),
		_home(),
		_farm(),
		_survival(),
		_animals(),
		_monsters(),
		_combat(),
		_modes(),
	]


static func _controls() -> Array:
	return [
		_title("BOOK_CHAPTER_CONTROLS"),
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
		_keys("BOOK_ZOOM_VIEW", InputNames.keys(InputBindings.ZOOM_VIEW)),
		_keys("BOOK_CAMERA_RESET", InputNames.keys(InputBindings.CAMERA_RESET)),
		_keys("BOOK_PAUSE", InputNames.keys(InputBindings.PAUSE)),
		_keys("BOOK_DEBUG_SCREEN", InputNames.keys(InputBindings.TOGGLE_DEBUG)),
	]


static func _gamepad() -> Array:
	return [
		_title("BOOK_CHAPTER_GAMEPAD"),
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
		_keys("BOOK_PAUSE", InputNames.pad(InputBindings.PAUSE)),
		_keys("BOOK_DEBUG_SCREEN", InputNames.pad(InputBindings.TOGGLE_DEBUG)),
		_text("BOOK_GAMEPAD_AIM"),
	]


static func _tips() -> Array:
	var entries := [_title("BOOK_CHAPTER_TIPS")]
	for i in TIP_COUNT:
		entries.append({"kind": Kind.TIP, "text": _t("BOOK_TIP_%d" % (i + 1))})
	return entries


static func _tools() -> Array:
	var entries := [_title("BOOK_CHAPTER_TOOLS"), _text("BOOK_TOOLS_INTRO")]
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
## and each piece of armor in one entry going through the materials, the
## factory furnace).
static func _craft() -> Array:
	var entries := [_title("BOOK_CHAPTER_CRAFT"), _text("BOOK_CRAFT_HOW")]
	var planks := []
	var tools := {}
	var armor := {}
	for recipe: Dictionary in Recipes.all():
		var made: int = recipe["result"][0]
		if recipe.has("ingredients") and Items.PLANKS_OF.has(recipe["ingredients"][0]):
			planks.append(recipe)
		elif Items.TOOLS.has(made):
			tools.get_or_add(Items.tool_of(made), []).append(recipe)
		elif Armor.is_armor(made):
			armor.get_or_add(Armor.piece_of(made), []).append(recipe)
	var sawn: int = planks[0]["result"][1]
	entries.append({"kind": Kind.RECIPE, "text": _t("BOOK_CRAFT_PLANKS") % sawn, "recipes": planks})
	var at_bench := []
	for recipe: Dictionary in Recipes.all():
		var item: int = recipe["result"][0]
		if not recipe in planks and not Items.TOOLS.has(item) and not Armor.is_armor(item):
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
	for piece: int in armor:
		var label := _t("BOOK_CRAFT_" + String(Armor.Piece.find_key(piece)))
		entries.append({"kind": Kind.RECIPE, "text": label, "recipes": armor[piece]})
	entries.append_array(at_bench)
	entries.append(_text("BOOK_CRAFT_MORE"))
	return entries


## How furnaces work, what each makes (drawn like recipes: one item in,
## what comes out), what breaks or chars, and the fuels.
static func _furnaces() -> Array:
	var entries := [_title("BOOK_CHAPTER_FURNACES"), _text("BOOK_FURNACE_HOW")]
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


## What furnishes a house and a garden: what hangs on a wall, the
## furniture, the lights, fences and gates, the campfire.
static func _home() -> Array:
	return [
		_title("BOOK_CHAPTER_HOME"),
		_text("BOOK_HOME_INTRO"),
		_text("BOOK_HOME_WALL"),
		_icon(Items.Id.TORCH_BRACKET, _t("BOOK_HOME_BRACKET")),
		_icon(Items.Id.CURTAINS, _t("BOOK_HOME_CURTAINS")),
		_icon(Items.Id.WINDOW, _t("BOOK_HOME_WINDOW")),
		_icon(Items.Id.GLASS_PANE, _t("BOOK_HOME_PANE")),
		_icon(Items.Id.TABLE, _t("BOOK_HOME_FURNITURE")),
		_heading("BOOK_HOME_LIGHTS"),
		_icon(Items.Id.TORCH, _t("BOOK_HOME_TORCH")),
		_icon(Items.Id.LANTERN, _t("BOOK_HOME_LANTERN")),
		_text("BOOK_HOME_LIGHTS_KEEP"),
		_heading("BOOK_HOME_GARDEN"),
		_icon(Items.Id.FENCE, _t("BOOK_HOME_FENCE")),
		_icon(Items.Id.GATE, _t("BOOK_HOME_GATE")),
		_icon(Items.Id.BIG_GATE, _t("BOOK_HOME_BIG_GATE")),
		_icon(Items.Id.CAMPFIRE, _t("BOOK_HOME_CAMPFIRE")),
	]


## What grows: saplings into trees, grass back on bare dirt, fields and
## crops, watering and compost (animals later in phase 7).
static func _farm() -> Array:
	return [
		_title("BOOK_CHAPTER_FARM"),
		_text("BOOK_FARM_INTRO"),
		_heading("BOOK_FARM_TREES"),
		_icon(Items.Id.OAK_SAPLING, _t("BOOK_FARM_SAPLING")),
		_icon(Items.Id.SPRUCE_SAPLING, _t("BOOK_FARM_YOUNG")),
		_heading("BOOK_FARM_GRASS"),
		_icon(Items.Id.DIRT, _t("BOOK_FARM_GRASS_BACK")),
		_heading("BOOK_FARM_FIELDS"),
		_icon(Items.Id.IRON_HOE, _t("BOOK_FARM_TILL")),
		_icon(Items.Id.SEEDS, _t("BOOK_FARM_SOW")),
		_icon(Items.Id.WHEAT, _t("BOOK_FARM_HARVEST")),
		_icon(Items.Id.BREAD, _t("BOOK_FARM_BREAD")),
		_heading("BOOK_FARM_CARE"),
		_icon(Items.Id.WATERING_CAN, _t("BOOK_FARM_CAN")),
		_text("BOOK_FARM_RAIN"),
		_text("BOOK_FARM_CANAL"),
		_icon(Items.Id.COMPOSTER, _t("BOOK_FARM_COMPOSTER")),
		_icon(Items.Id.COMPOST, _t("BOOK_FARM_COMPOST")),
		_icon(Items.Id.LANTERN, _t("BOOK_FARM_LIGHT")),
		_heading("BOOK_FARM_MORE"),
		_icon(Items.Id.BEETROOT_SEEDS, _t("BOOK_FARM_WILD")),
		_icon(Items.Id.CABBAGE, _t("BOOK_FARM_SOW_MORE")),
		_icon(Items.Id.TOMATO, _t("BOOK_FARM_PICK")),
		_icon(Items.Id.PUMPKIN, _t("BOOK_FARM_STEMS")),
		_icon(Items.Id.RICE, _t("BOOK_FARM_RICE")),
		_icon(Items.Id.SUGAR_CANE, _t("BOOK_FARM_CANE")),
		_icon(Items.Id.TRELLIS, _t("BOOK_FARM_TRELLIS")),
		_icon(Items.Id.FLAX, _t("BOOK_FARM_FLAX")),
		_heading("BOOK_FARM_FRUIT_TREES"),
		_icon(Items.Id.APPLE, _t("BOOK_FARM_ORCHARD")),
		_icon(Items.Id.APPLE_SEEDS, _t("BOOK_FARM_PIPS")),
	]


## Vitality and satiety: what wears them down, how to eat, what feeds.
static func _survival() -> Array:
	var entries := [
		_title("BOOK_CHAPTER_SURVIVAL"),
		_text("BOOK_SURVIVAL_VITALITY"),
		_text("BOOK_SURVIVAL_FOOD"),
		_text("BOOK_SURVIVAL_WATER"),
		_heading("BOOK_SURVIVAL_FOODS"),
	]
	var foods := Items.FOOD.keys()
	foods.sort_custom(func(a: int, b: int) -> bool: return Items.FOOD[a] > Items.FOOD[b])
	for item: int in foods:
		var text := _t("BOOK_SURVIVAL_FEEDS") % [_t(Items.name_key(item)), Items.FOOD[item]]
		if Vitals.POISONS.has(item):
			text += " " + _t("BOOK_SURVIVAL_SICK")
		entries.append(_icon(item, text))
	entries.append(_text("BOOK_SURVIVAL_COOK"))
	return entries


## Where each animal lives and what it gives (its first gift's icon), how
## to hunt and to cook.
static func _animals() -> Array:
	var entries := [_title("BOOK_CHAPTER_ANIMALS"), _text("BOOK_ANIMALS_INTRO")]
	for kind: int in Species.BIOMES:
		var gifts := PackedStringArray()
		for drop: Array in Species.DROPS[kind]:
			gifts.append(_t(Items.name_key(drop[0])).to_lower())
		var text := (
			_t("BOOK_ANIMALS_ENTRY")
			% [_t(Species.NAME_KEYS[kind]), _t(Species.HOME_KEYS[kind]), ", ".join(gifts)]
		)
		entries.append(_icon(Species.DROPS[kind][0][0], text))
	entries.append(_text("BOOK_ANIMALS_COOK"))
	(
		entries
		. append_array(
			[
				_heading("BOOK_ANIMALS_FARM"),
				_icon(Items.Id.WHEAT, _t("BOOK_ANIMALS_BREED")),
			_text("BOOK_ANIMALS_FEED"),
				_icon(Items.Id.LEAD, _t("BOOK_ANIMALS_LEAD")),
				_icon(Items.Id.SHEARS, _t("BOOK_ANIMALS_SHEAR")),
				_icon(Items.Id.MILK_BUCKET, _t("BOOK_ANIMALS_MILK")),
				_icon(Items.Id.NEST_BOX, _t("BOOK_ANIMALS_EGGS")),
				_text("BOOK_ANIMALS_LOVE"),
				_text("BOOK_ANIMALS_SHELTER"),
			]
		)
	)
	return entries


## Each monster: where and when it comes out, how it hunts (the icon of
## what it leaves).
static func _monsters() -> Array:
	var entries := [_title("BOOK_CHAPTER_MONSTERS"), _text("BOOK_MONSTERS_INTRO")]
	for kind: int in Species.MONSTERS:
		var text := (
			_t("BOOK_ANIMALS_ENTRY")
			% [_t(Species.NAME_KEYS[kind]), _t(Species.HOME_KEYS[kind]), _t(Species.HOW_KEYS[kind])]
		)
		entries.append(_icon(Species.DROPS[kind][0][0], text))
	return entries


## Blows (what each sword takes off), the bow and arrows, armor (each
## material's protection and how long it lasts).
static func _combat() -> Array:
	var entries := [_title("BOOK_CHAPTER_COMBAT"), _text("BOOK_COMBAT_MELEE")]
	entries.append(_heading("BOOK_COMBAT_SWORDS"))
	for tier in Items.Tier.size():
		var sword := Items.Id.NONE
		for tool in Items.tools_of_tier(tier):
			if Items.tool_of(tool) == Items.Tool.SWORD:
				sword = tool
		var name := _t("TIER_" + String(Items.Tier.find_key(tier)))
		entries.append(_icon(sword, _t("BOOK_COMBAT_DAMAGE") % [name, Combat.damage_of(sword)]))
	entries.append(_text(_t("BOOK_COMBAT_HAND") % Combat.HAND_DAMAGE, false))
	entries.append(_heading("ITEM_BOW"))
	entries.append(_icon(Items.Id.BOW, _t("BOOK_COMBAT_BOW")))
	entries.append(_icon(Items.Id.ARROW, _t("BOOK_COMBAT_ARROWS")))
	entries.append(_heading("BOOK_COMBAT_ARMOR"))
	entries.append(_text("BOOK_COMBAT_ARMOR_HOW"))
	for kind: int in Armor.DEFENSE:
		var points := 0
		var lasts: Array[int] = []
		var chestplate := Items.Id.NONE
		for item: int in Armor.ITEMS:
			if Armor.material_of(item) == kind:
				points += Armor.points_of(item)
				lasts.append(Armor.durability(item))
				if Armor.piece_of(item) == Armor.Piece.CHESTPLATE:
					chestplate = item
		var name := _t("ARMOR_" + String(Armor.Kind.find_key(kind)))
		var text := _t("BOOK_COMBAT_ARMOR_KIND") % [name, points, lasts.min(), lasts.max()]
		entries.append(_icon(chestplate, text))
	entries.append(_text("BOOK_COMBAT_FALLS"))
	return entries


## Creative (flight, the catalog, its debug keys), survival, hardcore.
static func _modes() -> Array:
	return [
		_title("BOOK_CHAPTER_MODES"),
		_heading("GAME_MODE_CREATIVE"),
		_text("BOOK_MODES_CREATIVE"),
		_combo("BOOK_FLY", "BOOK_FLY_HOW"),
		_text("BOOK_MODES_CATALOG"),
		_heading("BOOK_MODES_TOOLS"),
		_keys(
			"BOOK_MAP",
			InputNames.keys(InputBindings.TOGGLE_MAP) + InputNames.pad(InputBindings.TOGGLE_MAP)
		),
		_keys(
			"BOOK_DEPTH",
			InputNames.keys(InputBindings.DEPTH_DOWN) + InputNames.keys(InputBindings.DEPTH_UP)
		),
		_keys("BOOK_NOCLIP", InputNames.keys(InputBindings.TOGGLE_NOCLIP)),
		_keys("BOOK_WEATHER", InputNames.keys(InputBindings.CYCLE_WEATHER)),
		_keys("BOOK_GIVE_TOOLS", InputNames.keys(InputBindings.GIVE_TOOLS)),
		_heading("GAME_MODE_SURVIVAL"),
		_text("BOOK_MODES_SURVIVAL"),
		_heading("GAME_MODE_HARDCORE"),
		_text("BOOK_MODES_HARDCORE"),
	]


static func _title(key: String) -> Dictionary:
	return {"kind": Kind.TITLE, "text": _t(key)}


static func _heading(key: String) -> Dictionary:
	return {"kind": Kind.HEADING, "text": _t(key)}


## A paragraph: a key to translate (or, `translate` false, the text).
static func _text(key: String, translate := true) -> Dictionary:
	return {"kind": Kind.TEXT, "text": _t(key) if translate else key}


## A control: what it does, and the keys (or buttons) to press.
static func _keys(label_key: String, names: Array) -> Dictionary:
	return {"kind": Kind.KEYS, "text": _t(label_key), "keys": PackedStringArray(names)}


## A control done with a gesture, told in words under what it does.
static func _combo(label_key: String, how_key: String) -> Dictionary:
	return {"kind": Kind.COMBO, "text": _t(label_key), "how": _t(how_key)}


static func _icon(item: int, text: String) -> Dictionary:
	return {"kind": Kind.ICON, "item": item, "text": text}


## A translated text; {use}, {inventory}, {jump} and {sprint} in it name
## the keys of those controls as they are bound ({place}: the button).
static func _t(key: String) -> String:
	var text := String(TranslationServer.translate(key))
	if not "{" in text:
		return text
	var keys := {
		"use": " / ".join(InputNames.keys(InputBindings.USE)),
		"inventory": " / ".join(InputNames.keys(InputBindings.INVENTORY)),
		"place": String(TranslationServer.translate("MOUSE_RIGHT")).to_lower(),
		"jump": " / ".join(InputNames.keys(InputBindings.JUMP)),
		"sprint": " / ".join(InputNames.keys(InputBindings.SPRINT)),
		"break": String(TranslationServer.translate("MOUSE_LEFT")).to_lower(),
	}
	return text.format(keys)
