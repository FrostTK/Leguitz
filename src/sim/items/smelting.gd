class_name Smelting
extends RefCounted
## What furnaces make, shared by the server (which runs them, see Furnace)
## and the client (which shows them and predicts clicks). The food furnace
## cooks food: berries dry, mushrooms simmer into a stew, meat roasts; ore melted in it
## is too hot for it and breaks it. The factory furnace smelts ores into
## ingots, chars logs into charcoal, melts sand into glass, smooths stone
## and fires mud into bricks; food put in it comes out charred.
## Durations are authored for the default 20-minute day and go through
## WorldClock.scale_duration().

## Seconds to cook or smelt one item.
const COOK_SECONDS := 10.0
## What the food furnace makes of each food.
const FOOD := {
	Items.Id.RAW_FISH: Items.Id.COOKED_FISH,
	Items.Id.BERRIES: Items.Id.DRIED_BERRIES,
	Items.Id.MUSHROOM_RED: Items.Id.MUSHROOM_STEW,
	Items.Id.MUSHROOM_BROWN: Items.Id.MUSHROOM_STEW,
	Items.Id.RAW_MUTTON: Items.Id.COOKED_MUTTON,
	Items.Id.RAW_PORK: Items.Id.COOKED_PORK,
	Items.Id.RAW_CHICKEN: Items.Id.COOKED_CHICKEN,
	Items.Id.RAW_VENISON: Items.Id.COOKED_VENISON,
	Items.Id.DOUGH: Items.Id.BREAD,
	Items.Id.POTATO: Items.Id.BAKED_POTATO,
	Items.Id.CORN: Items.Id.ROASTED_CORN,
	Items.Id.RICE: Items.Id.COOKED_RICE,
	Items.Id.EGG: Items.Id.FRIED_EGG,
	Items.Id.RAW_BEEF: Items.Id.COOKED_BEEF,
	Items.Id.RAW_RABBIT: Items.Id.COOKED_RABBIT,
	Items.Id.RAW_DUCK: Items.Id.COOKED_DUCK,
}
## Food, raw or cooked: it chars in the factory furnace.
const FOODS := {
	Items.Id.RAW_FISH: true,
	Items.Id.BERRIES: true,
	Items.Id.MUSHROOM_RED: true,
	Items.Id.MUSHROOM_BROWN: true,
	Items.Id.DRIED_BERRIES: true,
	Items.Id.MUSHROOM_STEW: true,
	Items.Id.RAW_MUTTON: true,
	Items.Id.COOKED_MUTTON: true,
	Items.Id.RAW_PORK: true,
	Items.Id.COOKED_PORK: true,
	Items.Id.RAW_CHICKEN: true,
	Items.Id.COOKED_CHICKEN: true,
	Items.Id.RAW_VENISON: true,
	Items.Id.CARROT: true,
	Items.Id.POTATO: true,
	Items.Id.BAKED_POTATO: true,
	Items.Id.DOUGH: true,
	Items.Id.BREAD: true,
	Items.Id.COOKED_VENISON: true,
	Items.Id.BEETROOT: true,
	Items.Id.CABBAGE: true,
	Items.Id.CORN: true,
	Items.Id.ROASTED_CORN: true,
	Items.Id.TOMATO: true,
	Items.Id.STRAWBERRY: true,
	Items.Id.MELON_SLICE: true,
	Items.Id.RICE: true,
	Items.Id.COOKED_RICE: true,
	Items.Id.GRAPES: true,
	Items.Id.APPLE: true,
	Items.Id.CHERRIES: true,
	Items.Id.ORANGE: true,
	Items.Id.RASPBERRY: true,
	Items.Id.PEACH: true,
	Items.Id.EGG: true,
	Items.Id.FRIED_EGG: true,
	Items.Id.RAW_BEEF: true,
	Items.Id.COOKED_BEEF: true,
	Items.Id.RAW_RABBIT: true,
	Items.Id.COOKED_RABBIT: true,
	Items.Id.RAW_DUCK: true,
	Items.Id.COOKED_DUCK: true,
}
## What the factory furnace makes of the rest.
const FACTORY := {
	Items.Id.RAW_COPPER: Items.Id.COPPER_INGOT,
	Items.Id.RAW_IRON: Items.Id.IRON_INGOT,
	Items.Id.RAW_GOLD: Items.Id.GOLD_INGOT,
	Items.Id.OAK_LOG: Items.Id.CHARCOAL,
	Items.Id.BIRCH_LOG: Items.Id.CHARCOAL,
	Items.Id.SPRUCE_LOG: Items.Id.CHARCOAL,
	Items.Id.DARK_OAK_LOG: Items.Id.CHARCOAL,
	Items.Id.JUNGLE_LOG: Items.Id.CHARCOAL,
	Items.Id.ACACIA_LOG: Items.Id.CHARCOAL,
	Items.Id.SAND: Items.Id.GLASS,
	Items.Id.RED_SAND: Items.Id.GLASS,
	Items.Id.STONE: Items.Id.SMOOTH_STONE,
	Items.Id.MUD: Items.Id.BRICK,
}
## Ores: melted in a food furnace, they break it.
const ORES := {
	Items.Id.RAW_COPPER: true,
	Items.Id.RAW_IRON: true,
	Items.Id.RAW_GOLD: true,
}
## How long each fuel burns (seconds; Minecraft's: coal smelts 8 items).
const FUEL_SECONDS := {
	Items.Id.WISP_EMBER: 200.0,
	Items.Id.COAL: 80.0,
	Items.Id.CHARCOAL: 80.0,
	Items.Id.OAK_LOG: 15.0,
	Items.Id.BIRCH_LOG: 15.0,
	Items.Id.SPRUCE_LOG: 15.0,
	Items.Id.DARK_OAK_LOG: 15.0,
	Items.Id.JUNGLE_LOG: 15.0,
	Items.Id.ACACIA_LOG: 15.0,
	Items.Id.OAK_PLANKS: 15.0,
	Items.Id.BIRCH_PLANKS: 15.0,
	Items.Id.SPRUCE_PLANKS: 15.0,
	Items.Id.DARK_OAK_PLANKS: 15.0,
	Items.Id.JUNGLE_PLANKS: 15.0,
	Items.Id.ACACIA_PLANKS: 15.0,
	Items.Id.WORKBENCH: 15.0,
	Items.Id.CHEST: 15.0,
	Items.Id.STICK: 5.0,
}
## result_of(): ore in a food furnace.
const BREAKS := -1


## What a furnace (its unlit kind, Tiles.Block.FOOD_FURNACE or
## FACTORY_FURNACE) makes of an item: the item made, BREAKS, or
## Items.Id.NONE (it does not go in).
static func result_of(kind: int, item: int) -> int:
	if kind == Tiles.Block.FOOD_FURNACE:
		if ORES.has(item):
			return BREAKS
		return FOOD.get(item, Items.Id.NONE)
	if FOODS.has(item):
		return Items.Id.CHARRED_FOOD
	return FACTORY.get(item, Items.Id.NONE)


## Whether an item goes in a furnace to be cooked or smelted.
static func accepts(kind: int, item: int) -> bool:
	return result_of(kind, item) != Items.Id.NONE


static func is_fuel(item: int) -> bool:
	return FUEL_SECONDS.has(item)


## Seconds a fuel burns (authored, see WorldClock.scale_duration).
static func burn_seconds(item: int) -> float:
	return FUEL_SECONDS.get(item, 0.0)
