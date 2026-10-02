class_name Armor
extends RefCounted
## What players wear (four slots of their Inventory from Inventory.ARMOR):
## a helmet, a chestplate, leggings and boots, of hide, copper, iron, gold
## or diamond. Each piece gives protection points (Minecraft's numbers,
## copper between leather and iron); each point takes REDUCTION_PER_POINT
## off monsters' blows (see Survival.hurt), which wear every piece worn
## once. Shared: the server keeps it, the client shows it.

enum Piece { HELMET, CHESTPLATE, LEGGINGS, BOOTS }
## What a piece is made of.
enum Kind { HIDE, COPPER, IRON, GOLD, DIAMOND }

const PIECES := 4
## Item -> [Piece, Kind].
const ITEMS := {
	Items.Id.HIDE_HELMET: [Piece.HELMET, Kind.HIDE],
	Items.Id.HIDE_CHESTPLATE: [Piece.CHESTPLATE, Kind.HIDE],
	Items.Id.HIDE_LEGGINGS: [Piece.LEGGINGS, Kind.HIDE],
	Items.Id.HIDE_BOOTS: [Piece.BOOTS, Kind.HIDE],
	Items.Id.COPPER_HELMET: [Piece.HELMET, Kind.COPPER],
	Items.Id.COPPER_CHESTPLATE: [Piece.CHESTPLATE, Kind.COPPER],
	Items.Id.COPPER_LEGGINGS: [Piece.LEGGINGS, Kind.COPPER],
	Items.Id.COPPER_BOOTS: [Piece.BOOTS, Kind.COPPER],
	Items.Id.IRON_HELMET: [Piece.HELMET, Kind.IRON],
	Items.Id.IRON_CHESTPLATE: [Piece.CHESTPLATE, Kind.IRON],
	Items.Id.IRON_LEGGINGS: [Piece.LEGGINGS, Kind.IRON],
	Items.Id.IRON_BOOTS: [Piece.BOOTS, Kind.IRON],
	Items.Id.GOLDEN_HELMET: [Piece.HELMET, Kind.GOLD],
	Items.Id.GOLDEN_CHESTPLATE: [Piece.CHESTPLATE, Kind.GOLD],
	Items.Id.GOLDEN_LEGGINGS: [Piece.LEGGINGS, Kind.GOLD],
	Items.Id.GOLDEN_BOOTS: [Piece.BOOTS, Kind.GOLD],
	Items.Id.DIAMOND_HELMET: [Piece.HELMET, Kind.DIAMOND],
	Items.Id.DIAMOND_CHESTPLATE: [Piece.CHESTPLATE, Kind.DIAMOND],
	Items.Id.DIAMOND_LEGGINGS: [Piece.LEGGINGS, Kind.DIAMOND],
	Items.Id.DIAMOND_BOOTS: [Piece.BOOTS, Kind.DIAMOND],
}
## Protection points of each piece (Piece order), by material.
const DEFENSE := {
	Kind.HIDE: [1, 3, 2, 1],
	Kind.COPPER: [2, 4, 3, 1],
	Kind.IRON: [2, 6, 5, 2],
	Kind.GOLD: [2, 5, 3, 1],
	Kind.DIAMOND: [3, 8, 6, 3],
}
## How many blows a piece lasts: its base (Piece order) times its
## material's factor (Minecraft's).
const BASE_DURABILITY: Array[int] = [11, 16, 15, 13]
const MATERIAL_DURABILITY := {
	Kind.HIDE: 5,
	Kind.COPPER: 10,
	Kind.IRON: 15,
	Kind.GOLD: 7,
	Kind.DIAMOND: 33,
}
## What each material is made of (the recipes), and their shapes ("M").
const MADE_OF := {
	Kind.HIDE: Items.Id.HIDE,
	Kind.COPPER: Items.Id.COPPER_INGOT,
	Kind.IRON: Items.Id.IRON_INGOT,
	Kind.GOLD: Items.Id.GOLD_INGOT,
	Kind.DIAMOND: Items.Id.DIAMOND,
}
const PATTERNS := {
	Piece.HELMET: ["MMM", "M M"],
	Piece.CHESTPLATE: ["M M", "MMM", "MMM"],
	Piece.LEGGINGS: ["MMM", "M M", "M M"],
	Piece.BOOTS: ["M M", "M M"],
}
## Each point of protection takes this much off a blow, at most
## MAX_REDUCTION in all.
const REDUCTION_PER_POINT := 0.04
const MAX_REDUCTION := 0.8


static func is_armor(item: int) -> bool:
	return ITEMS.has(item)


## The piece an item is (Piece; -1: not armor).
static func piece_of(item: int) -> int:
	return ITEMS[item][0] if ITEMS.has(item) else -1


static func material_of(item: int) -> int:
	return ITEMS[item][1] if ITEMS.has(item) else -1


## How many blows a piece lasts (0: not armor).
static func durability(item: int) -> int:
	if not ITEMS.has(item):
		return 0
	return BASE_DURABILITY[piece_of(item)] * MATERIAL_DURABILITY[material_of(item)]


static func points_of(item: int) -> int:
	return DEFENSE[material_of(item)][piece_of(item)] if ITEMS.has(item) else 0


## The protection points of what a player wears.
static func defense(bag: Inventory) -> int:
	var total := 0
	for piece in PIECES:
		total += points_of(bag.items[Inventory.ARMOR + piece])
	return total


## What is left of `points` of a blow through `protection` points.
static func reduce(points: float, protection: int) -> float:
	return points * (1.0 - minf(protection * REDUCTION_PER_POINT, MAX_REDUCTION))


## Every piece worn wears once; returns the pieces that broke.
static func wear_out(bag: Inventory) -> Array[int]:
	var broken: Array[int] = []
	for piece in PIECES:
		var slot := Inventory.ARMOR + piece
		var item := bag.items[slot]
		if item != Items.Id.NONE and bag.wear_out(slot):
			broken.append(item)
	return broken


## A click on an armor slot with `bag`'s cursor: the piece in hand goes on
## (swapping with what was worn), only into its own slot; with empty
## hands the piece comes off. Shift moves it into the slots.
static func click(bag: Inventory, slot: int, shift: bool) -> void:
	var piece := slot - Inventory.ARMOR
	if piece < 0 or piece >= PIECES:
		return
	if shift:
		bag._move(slot, bag, range(Inventory.SLOTS))
		return
	var held := bag.items[Inventory.CURSOR]
	if held != Items.Id.NONE and piece_of(held) != piece:
		return
	bag._click_on(bag, slot, false)


## Shift on a piece of armor in the slots: it goes on if its slot is free.
## Returns whether it did.
static func put_on(bag: Inventory, slot: int) -> bool:
	var piece := piece_of(bag.items[slot])
	if piece < 0 or bag.items[Inventory.ARMOR + piece] != Items.Id.NONE:
		return false
	bag._move(slot, bag, [Inventory.ARMOR + piece])
	return true
