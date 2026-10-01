class_name Furnace
extends RefCounted
## A furnace standing in the world: what it cooks (INPUT), what it burns
## (FUEL), what it made (OUTPUT), its fire and how far the item in it has
## cooked (Smelting says what it makes). The server runs it (step()),
## saves it with its chunk and sends it to the players who opened it;
## their clients show it and predict their clicks (Inventory.click_furnace).

## What a step did: nothing to tell, its slots or its fire changed (lit or
## out), or ore melted in a food furnace broke it.
enum Step { NOTHING, CHANGED, BROKE }

## Its slots.
const INPUT := 0
const FUEL := 1
const OUTPUT := 2
const SLOTS := 3

## Its unlit kind: Tiles.Block.FOOD_FURNACE or FACTORY_FURNACE.
var kind := Tiles.Block.FOOD_FURNACE
## The slots (the first SLOTS of an Inventory: clicked like a chest's).
var slots := Inventory.new()
## What is left of the fuel burning (1 -> 0) and how long it lasts (real
## seconds, paced).
var fire := 0.0
var fire_seconds := 0.0
## How far the item in INPUT has cooked (0 -> 1).
var progress := 0.0

## The item `progress` belongs to: another one put in starts from 0.
var _cooking := Items.Id.NONE


func _init(furnace_kind := Tiles.Block.FOOD_FURNACE) -> void:
	kind = furnace_kind


func burning() -> bool:
	return fire > 0.0


## Whether an item may go in a slot: what it cooks in INPUT, fuel in FUEL;
## OUTPUT only gives.
func fits(slot: int, item: int) -> bool:
	match slot:
		INPUT:
			return Smelting.accepts(kind, item)
		FUEL:
			return Smelting.is_fuel(item)
	return false


## Runs the furnace for `delta` real seconds, paced by `clock`: while there
## is something to cook (and room for what it makes), fuel is lit when the
## fire is out; while it burns, the item in INPUT cooks. Without fire,
## what cooked cools back.
func step(delta: float, clock: WorldClock) -> Step:
	var result := Step.NOTHING
	var was_burning := burning()
	if slots.items[INPUT] != _cooking:
		_cooking = slots.items[INPUT]
		progress = 0.0
	var made := _to_make()
	if not burning() and made != Items.Id.NONE and Smelting.is_fuel(slots.items[FUEL]):
		fire_seconds = clock.scale_duration(Smelting.burn_seconds(slots.items[FUEL]))
		fire = 1.0
		slots.take(FUEL, 1)
		result = Step.CHANGED
	var cook_seconds := clock.scale_duration(Smelting.COOK_SECONDS)
	if burning():
		fire = maxf(fire - delta / maxf(fire_seconds, 0.01), 0.0)
		if made == Items.Id.NONE:
			progress = 0.0
		else:
			progress += delta / cook_seconds
			if progress >= 1.0:
				progress = 0.0
				slots.take(INPUT, 1)
				if made == Smelting.BREAKS:
					return Step.BROKE
				slots.items[OUTPUT] = made
				slots.counts[OUTPUT] += 1
				result = Step.CHANGED
	elif progress > 0.0:
		progress = maxf(progress - 2.0 * delta / cook_seconds, 0.0)
	if burning() != was_burning:
		result = Step.CHANGED
	return result


func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"slots": slots.contents(SLOTS),
		"fire": fire,
		"fire_seconds": fire_seconds,
		"progress": progress,
	}


func load_dict(data: Dictionary) -> void:
	kind = int(data.get("kind", kind))
	slots.load_dict(data.get("slots", {}))
	fire = clampf(float(data.get("fire", 0.0)), 0.0, 1.0)
	fire_seconds = maxf(float(data.get("fire_seconds", 0.0)), 0.0)
	progress = clampf(float(data.get("progress", 0.0)), 0.0, 1.0)
	_cooking = slots.items[INPUT]


static func from_dict(data: Dictionary) -> Furnace:
	var furnace := Furnace.new()
	furnace.load_dict(data)
	return furnace


## What the item in INPUT makes when it is done (Smelting.BREAKS too), or
## Items.Id.NONE: nothing in, or no room for it in OUTPUT.
func _to_make() -> int:
	var item := slots.items[INPUT]
	if item == Items.Id.NONE:
		return Items.Id.NONE
	var made := Smelting.result_of(kind, item)
	if made == Items.Id.NONE or made == Smelting.BREAKS:
		return made
	var out := slots.items[OUTPUT]
	if out != Items.Id.NONE and (out != made or slots.counts[OUTPUT] >= Items.max_stack(made)):
		return Items.Id.NONE
	return made
