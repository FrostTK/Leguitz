class_name Furnace
extends RefCounted
## A furnace standing in the world, its fire and how far what is in it has
## cooked (Smelting says what it makes). The food furnace cooks one thing at
## a time: what it cooks (INPUT), what it burns (FUEL), what it made
## (OUTPUT). The factory furnace cooks up to four kinds at once (LANES, one
## kind each; is_factory) on one fire, which burns as many times faster as
## lanes are cooking; three chests go with it: what is to cook (TO_COOK:
## the lanes take their stacks from it, a kind none of them holds), its fuel
## (FUELS) and what it made (COOKED: only gives). The server runs it
## (step()), saves it with its chunk and sends it to the players who opened
## it; their clients show it and predict their clicks
## (Inventory.click_furnace).

## What a step did: nothing to tell, its slots or its fire changed (lit or
## out), or ore melted in a food furnace broke it.
enum Step { NOTHING, CHANGED, BROKE }

## A food furnace's slots.
const INPUT := 0
const FUEL := 1
const OUTPUT := 2
const SLOTS := 3
## A factory furnace's slots: its lanes, then its chests (CHEST_COLUMNS
## across): what is to cook, its fuel, what it made.
const LANES := 0
const LANE_COUNT := 4
const TO_COOK := LANES + LANE_COUNT
const TO_COOK_SIZE := 18
const FUELS := TO_COOK + TO_COOK_SIZE
const FUELS_SIZE := 12
const COOKED := FUELS + FUELS_SIZE
const COOKED_SIZE := 30
const FACTORY_SLOTS := COOKED + COOKED_SIZE
const CHEST_COLUMNS := 6

## Its unlit kind: Tiles.Block.FOOD_FURNACE or FACTORY_FURNACE.
var kind := Tiles.Block.FOOD_FURNACE
## The slots (the first slot_count() of an Inventory: clicked like a
## chest's).
var slots := Inventory.new()
## What is left of the fuel burning (1 -> 0) and how long it lasts (real
## seconds, paced).
var fire := 0.0
var fire_seconds := 0.0
## How far the item in INPUT has cooked (0 -> 1); a factory furnace's,
## each lane's.
var progress := 0.0
var lane_progress: Array[float] = [0.0, 0.0, 0.0, 0.0]

## The item `progress` belongs to: another one put in starts from 0 (a
## factory furnace's: each lane's).
var _cooking := Items.Id.NONE
var _lane_cooking: Array[int] = [Items.Id.NONE, Items.Id.NONE, Items.Id.NONE, Items.Id.NONE]


func _init(furnace_kind := Tiles.Block.FOOD_FURNACE) -> void:
	kind = furnace_kind


func burning() -> bool:
	return fire > 0.0


func is_factory() -> bool:
	return kind == Tiles.Block.FACTORY_FURNACE


## How many slots it has.
func slot_count() -> int:
	return FACTORY_SLOTS if is_factory() else SLOTS


## Whether an item may go in a slot: what it cooks in INPUT, fuel in FUEL
## (a factory furnace: a kind no other lane holds in a lane, what it cooks
## in TO_COOK, fuel in FUELS); OUTPUT and COOKED only give.
func fits(slot: int, item: int) -> bool:
	if not is_factory():
		match slot:
			INPUT:
				return Smelting.accepts(kind, item)
			FUEL:
				return Smelting.is_fuel(item)
		return false
	if slot >= LANES and slot < TO_COOK:
		return Smelting.accepts(kind, item) and lane_holding(item, slot) == -1
	if slot >= TO_COOK and slot < FUELS:
		return Smelting.accepts(kind, item)
	if slot >= FUELS and slot < COOKED:
		return Smelting.is_fuel(item)
	return false


## Whether a slot only gives (what the furnace made).
func gives_only(slot: int) -> bool:
	return slot >= COOKED and slot < FACTORY_SLOTS if is_factory() else slot == OUTPUT


## Where a stack shifted in from the bag goes, in turn: what it cooks, else
## what it burns.
func shift_places() -> Array[Array]:
	if is_factory():
		return [range(TO_COOK, FUELS), range(FUELS, COOKED)]
	return [[INPUT], [FUEL]]


## The lane holding `item` other than `but` (-1: none).
func lane_holding(item: int, but := -1) -> int:
	for lane in LANE_COUNT:
		if LANES + lane != but and slots.items[LANES + lane] == item:
			return LANES + lane
	return -1


## How many lanes are cooking (something in them, with room for what it
## makes).
func lanes_cooking() -> int:
	var cooking := 0
	for lane in LANE_COUNT:
		if _lane_makes(lane) != Items.Id.NONE:
			cooking += 1
	return cooking


## Runs the furnace for `delta` real seconds, paced by `clock`: while there
## is something to cook (and room for what it makes), fuel is lit when the
## fire is out; while it burns, what is in it cooks. Without fire, what
## cooked cools back.
func step(delta: float, clock: WorldClock) -> Step:
	if is_factory():
		return _step_factory(delta, clock)
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
		"slots": slots.contents(slot_count()),
		"fire": fire,
		"fire_seconds": fire_seconds,
		"progress": progress,
		"lanes": PackedFloat32Array(lane_progress),
	}


## Takes back what to_dict kept. A factory furnace saved with a food
## furnace's three slots (before it had lanes and chests): its fuel goes to
## FUELS, what it made to COOKED.
func load_dict(data: Dictionary) -> void:
	kind = int(data.get("kind", kind))
	var saved: Dictionary = data.get("slots", {})
	slots.load_dict(saved)
	var old := (saved.get("items", PackedInt32Array()) as PackedInt32Array).size() <= SLOTS
	if is_factory() and old:
		_move(FUEL, FUELS)
		_move(OUTPUT, COOKED)
	fire = clampf(float(data.get("fire", 0.0)), 0.0, 1.0)
	fire_seconds = maxf(float(data.get("fire_seconds", 0.0)), 0.0)
	progress = clampf(float(data.get("progress", 0.0)), 0.0, 1.0)
	var lanes: PackedFloat32Array = data.get("lanes", PackedFloat32Array())
	for lane in LANE_COUNT:
		lane_progress[lane] = clampf(lanes[lane], 0.0, 1.0) if lane < lanes.size() else 0.0
		_lane_cooking[lane] = slots.items[LANES + lane]
	_cooking = slots.items[INPUT]


static func from_dict(data: Dictionary) -> Furnace:
	var furnace := Furnace.new()
	furnace.load_dict(data)
	return furnace


## A factory furnace: its empty lanes take a stack from TO_COOK (a kind no
## lane holds); while there is something to cook, fuel is lit from FUELS;
## while it burns (faster for each lane cooking), the lanes cook, what they
## make going to COOKED. Without fire, what cooked cools back.
func _step_factory(delta: float, clock: WorldClock) -> Step:
	var result := Step.CHANGED if _fill_lanes() else Step.NOTHING
	var was_burning := burning()
	var cooking := lanes_cooking()
	if not burning() and cooking > 0:
		var fuel := _first_fuel()
		if fuel >= 0:
			fire_seconds = clock.scale_duration(Smelting.burn_seconds(slots.items[fuel]))
			fire = 1.0
			slots.take(fuel, 1)
			result = Step.CHANGED
	var cook_seconds := clock.scale_duration(Smelting.COOK_SECONDS)
	for lane in LANE_COUNT:
		if slots.items[LANES + lane] != _lane_cooking[lane]:
			_lane_cooking[lane] = slots.items[LANES + lane]
			lane_progress[lane] = 0.0
	if burning():
		fire = maxf(fire - delta * maxi(cooking, 1) / maxf(fire_seconds, 0.01), 0.0)
		for lane in LANE_COUNT:
			var made := _lane_makes(lane)
			if made == Items.Id.NONE:
				lane_progress[lane] = 0.0
				continue
			lane_progress[lane] += delta / cook_seconds
			if lane_progress[lane] >= 1.0:
				lane_progress[lane] = 0.0
				slots.take(LANES + lane, 1)
				slots._add_to(made, 1, range(COOKED, FACTORY_SLOTS))
				result = Step.CHANGED
	else:
		for lane in LANE_COUNT:
			lane_progress[lane] = maxf(lane_progress[lane] - 2.0 * delta / cook_seconds, 0.0)
	if burning() != was_burning:
		result = Step.CHANGED
	return result


## Each empty lane takes the first stack of TO_COOK of a kind no lane
## holds. Returns whether one did.
func _fill_lanes() -> bool:
	var filled := false
	for lane in LANE_COUNT:
		var at := LANES + lane
		if slots.items[at] != Items.Id.NONE:
			continue
		for from in range(TO_COOK, FUELS):
			var item := slots.items[from]
			if item != Items.Id.NONE and lane_holding(item) == -1 and fits(at, item):
				_move(from, at)
				filled = true
				break
	return filled


## What a lane's item makes when it is done, or Items.Id.NONE: nothing in
## it, or no room for it in COOKED.
func _lane_makes(lane: int) -> int:
	var item := slots.items[LANES + lane]
	if item == Items.Id.NONE:
		return Items.Id.NONE
	var made := Smelting.result_of(kind, item)
	if made == Items.Id.NONE or made == Smelting.BREAKS:
		return Items.Id.NONE
	var stack := Items.max_stack(made)
	for slot in range(COOKED, FACTORY_SLOTS):
		var there := slots.items[slot]
		if there == Items.Id.NONE or (there == made and slots.counts[slot] < stack):
			return made
	return Items.Id.NONE


## The first slot of FUELS holding fuel (-1: none).
func _first_fuel() -> int:
	for slot in range(FUELS, COOKED):
		if Smelting.is_fuel(slots.items[slot]):
			return slot
	return -1


## Moves a whole stack from one of its slots to another (empty) one.
func _move(from: int, to: int) -> void:
	if slots.items[from] == Items.Id.NONE or slots.items[to] != Items.Id.NONE:
		return
	slots.items[to] = slots.items[from]
	slots.counts[to] = slots.counts[from]
	slots.wear[to] = slots.wear[from]
	slots.items[from] = Items.Id.NONE
	slots.counts[from] = 0
	slots.wear[from] = 0


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
