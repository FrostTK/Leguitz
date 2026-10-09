class_name Boat
extends RefCounted
## A boat (Boats keeps them on the server; the clients' copies come in
## Msg.BOAT): its parts in `slots` (an Inventory of its own, its first
## SLOT_COUNT slots: BOW, SECTIONS holding 0 to MOST_SECTIONS hull sections,
## STERN, ENGINE, FUEL, NET (the net to come), then a place each from PLACE:
## a bench or a chest), its chests' contents by place, where it is (`at`:
## the middle of its hull at the water's surface, local units; `yaw`:
## radians, its bow towards +z at 0; `speed`: tiles a second along it) or
## the shipyard holding it (`yard`), its pilot and who sits on its places
## (`seats`: place -> a player's id, or -id for an animal), the coal burning
## (`burn`: seconds left of it). The hull is a bow, its sections and a stern
## (lengths in model voxels, 1/16 tile): a place in the stern, one in each
## section, one in the bow (2 + sections), the pilot at the stern's end,
## the engine behind them. Shared: the pilot's client steps its copy
## (BoatBody).

const BOW := 0
const SECTIONS := 1
const STERN := 2
const ENGINE := 3
const FUEL := 4
const NET := 5
const PLACE := 6
const MOST_SECTIONS := 3
const MOST_PLACES := 2 + MOST_SECTIONS
const SLOT_COUNT := PLACE + MOST_PLACES
## On no shipyard (afloat).
const NO_YARD := Vector3i(0, -1, 0)
## The hull's parts' lengths and its width (model voxels).
const BOW_LENGTH := 16
const SECTION_LENGTH := 12
const STERN_LENGTH := 20
const WIDTH := 20
## Where the pilot sits from the stern's end, the stern's place, the bow's
## from the bow's start (model voxels).
const PILOT_AT := 7.0
const STERN_PLACE_AT := 15.0
const BOW_PLACE_AT := 6.0
## Seats are this high over the water (levels).
const SEAT_HEIGHT := 0.1
## What the engine burns.
const COALS: Array[int] = [Items.Id.COAL, Items.Id.CHARCOAL]
const VOXEL := 1.0 / 16.0

var id := 0
var slots := Inventory.new()
var chests: Dictionary[int, Inventory] = {}
var at := Vector3.ZERO
var yaw := 0.0
var speed := 0.0
var yard := NO_YARD
var pilot := -1
var seats: Dictionary[int, int] = {}
var burn := 0.0
## What the pilot asks: the throttle (-1 astern to 1), full throttle.
var throttle := 0.0
var full := false


## Whether `item` goes in a slot.
static func takes(slot: int, item: int) -> bool:
	match slot:
		BOW:
			return item == Items.Id.BOAT_BOW
		SECTIONS:
			return item == Items.Id.BOAT_SECTION
		STERN:
			return item == Items.Id.BOAT_STERN
		ENGINE:
			return item == Items.Id.COAL_ENGINE
		FUEL:
			return item in COALS
		NET:
			return false
	return slot >= PLACE and slot < SLOT_COUNT and item in [Items.Id.BOAT_BENCH, Items.Id.CHEST]


## How many a slot holds at most.
static func holds(slot: int) -> int:
	if slot == SECTIONS:
		return MOST_SECTIONS
	return Items.MAX_STACK if slot == FUEL else 1


## Whether a slot is part of the hull (only changed at a shipyard).
static func is_hull(slot: int) -> bool:
	return slot in [BOW, SECTIONS, STERN]


func sections() -> int:
	return slots.counts[SECTIONS] if slots.items[SECTIONS] == Items.Id.BOAT_SECTION else 0


## How many places it has (the pilot's besides).
func places() -> int:
	return 2 + sections()


## A bow and a stern: it floats.
func complete() -> bool:
	return slots.items[BOW] == Items.Id.BOAT_BOW and slots.items[STERN] == Items.Id.BOAT_STERN


## Its length (tiles).
func length() -> float:
	return (BOW_LENGTH + SECTION_LENGTH * sections() + STERN_LENGTH) * VOXEL


## The way its bow points (on the ground).
func forward() -> Vector2:
	return Vector2(sin(yaw), cos(yaw))


func has_engine() -> bool:
	return slots.items[ENGINE] == Items.Id.COAL_ENGINE


func fuel() -> int:
	return slots.counts[FUEL] if slots.items[FUEL] in COALS else 0


## Its engine runs: some coal burning or to burn.
func powered() -> bool:
	return has_engine() and (burn > 0.0 or fuel() > 0)


## What sits on a place: a bench, a chest (Items.Id.NONE: nothing).
func place_item(place: int) -> int:
	return slots.items[PLACE + place] if place >= 0 and place < places() else Items.Id.NONE


## Where a place is along it from its middle (tiles, towards the bow); -1
## the pilot's.
func place_along(place: int) -> float:
	var stern := -length() * 0.5
	if place < 0:
		return stern + PILOT_AT * VOXEL
	if place == 0:
		return stern + STERN_PLACE_AT * VOXEL
	if place <= sections():
		return stern + (STERN_LENGTH + SECTION_LENGTH * (place - 0.5)) * VOXEL
	return stern + (STERN_LENGTH + SECTION_LENGTH * sections() + BOW_PLACE_AT) * VOXEL


## Where one sits on a place (-1: the pilot), local units (feet).
func seat(place: int) -> Vector3:
	var along := place_along(place)
	var way := forward()
	return at + Vector3(way.x * along, SEAT_HEIGHT, way.y * along)


## The first free bench from the stern (from the bow: animals, away from
## the pilot), -1: none.
func free_bench(from_bow := false) -> int:
	for i in places():
		var place := places() - 1 - i if from_bow else i
		if place_item(place) == Items.Id.BOAT_BENCH and not seats.has(place):
			return place
	return -1


func is_empty() -> bool:
	return pilot < 0 and seats.is_empty()


## Why a slot's stack may not be taken now ("": it may): the hull only at
## a shipyard, a section only with the last place empty, a chest only
## empty, a bench nobody sits on.
func refusal(slot: int, at_yard: bool) -> String:
	if slot < 0 or slot >= SLOT_COUNT or slots.items[slot] == Items.Id.NONE:
		return "-"
	if is_hull(slot) and not at_yard:
		return "HUD_BOAT_HULL_AT_YARD"
	if slot == SECTIONS and place_item(places() - 1) != Items.Id.NONE:
		return "HUD_BOAT_LAST_PLACE"
	if slot >= PLACE:
		var place := slot - PLACE
		if seats.has(place):
			return "HUD_BOAT_SEAT_TAKEN"
		var chest: Inventory = chests.get(place)
		if chest != null and not chest.contents(Inventory.CHEST).is_empty():
			return "HUD_BOAT_CHEST_FULL"
	return ""


## A click on a slot with the player's cursor (`bag`): takes a stack up,
## puts what fits down (the places only as many as the hull has), swaps;
## shift sends a stack into the bag. Returns why it was refused ("": done,
## "-": nothing to do).
func click(bag: Inventory, slot: int, right: bool, shift: bool, at_yard: bool) -> String:
	if slot < 0 or slot >= SLOT_COUNT:
		return "-"
	var held := bag.items[Inventory.CURSOR]
	if shift or held == Items.Id.NONE:
		var refused := refusal(slot, at_yard)
		if refused != "":
			return refused
		var item := slots.items[slot]
		var count := slots.counts[slot]
		if shift:
			count = count - bag.add(item, count, slots.wear[slot])
		elif right:
			count = (count + 1) / 2
		if not shift:
			bag.items[Inventory.CURSOR] = item
			bag.counts[Inventory.CURSOR] = count
			bag.wear[Inventory.CURSOR] = slots.wear[slot]
		slots.take(slot, count)
		_settle(slot)
		return ""
	if not takes(slot, held) or (slot >= PLACE and slot - PLACE >= places()):
		return "-"
	if is_hull(slot) and not at_yard:
		return "HUD_BOAT_HULL_AT_YARD"
	if slots.items[slot] == held or slots.items[slot] == Items.Id.NONE:
		var amount := mini(
			1 if right else bag.counts[Inventory.CURSOR], holds(slot) - slots.counts[slot]
		)
		if amount <= 0:
			return "-"
		slots.items[slot] = held
		slots.counts[slot] += amount
		bag.take(Inventory.CURSOR, amount)
		_settle(slot)
		return ""
	var refused := refusal(slot, at_yard)
	if refused != "" or bag.counts[Inventory.CURSOR] != 1:
		return refused if refused != "" else "-"
	var swapped := slots.items[slot]
	slots.items[slot] = held
	bag.items[Inventory.CURSOR] = swapped
	_settle(slot)
	return ""


## Everything it is made of and carries, to be dropped ([item, count]).
func contents() -> Array[Vector2i]:
	var all: Array[Vector2i] = []
	for slot in SLOT_COUNT:
		if slots.items[slot] != Items.Id.NONE:
			all.append(Vector2i(slots.items[slot], slots.counts[slot]))
	for place: int in chests:
		var chest := chests[place]
		for slot in Inventory.CHEST:
			if chest.items[slot] != Items.Id.NONE:
				all.append(Vector2i(chest.items[slot], chest.counts[slot]))
	return all


func to_dict() -> Dictionary:
	var kept := {}
	for place: int in chests:
		kept[place] = chests[place].to_dict()
	return {
		"id": id,
		"slots": slots.to_dict(),
		"chests": kept,
		"at": at,
		"yaw": yaw,
		"speed": speed,
		"yard": yard,
		"pilot": pilot,
		"seats": seats.duplicate(),
		"burn": burn,
	}


static func from_dict(data: Dictionary) -> Boat:
	var boat := Boat.new()
	boat.id = int(data.get("id", 0))
	boat.slots.load_dict(data.get("slots", {}))
	var kept: Dictionary = data.get("chests", {})
	for place: int in kept:
		var chest := Inventory.new()
		chest.load_dict(kept[place])
		boat.chests[place] = chest
	boat.at = data.get("at", Vector3.ZERO)
	boat.yaw = float(data.get("yaw", 0.0))
	boat.speed = float(data.get("speed", 0.0))
	boat.yard = data.get("yard", NO_YARD)
	boat.pilot = int(data.get("pilot", -1))
	var seated: Dictionary = data.get("seats", {})
	for place: int in seated:
		boat.seats[place] = int(seated[place])
	boat.burn = float(data.get("burn", 0.0))
	return boat


## A place took or lost a chest: its contents with it.
func _settle(slot: int) -> void:
	if slot < PLACE:
		return
	var place := slot - PLACE
	if slots.items[slot] == Items.Id.CHEST and not chests.has(place):
		chests[place] = Inventory.new()
	elif slots.items[slot] != Items.Id.CHEST:
		chests.erase(place)
