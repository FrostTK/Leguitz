class_name Inventory
extends RefCounted
## A player's items: the hotbar (HOTBAR slots, the selected one is in
## hand), the bag, the stack the cursor holds while things are moved
## around (slot CURSOR) and the crafting grid. Tools wear: each slot keeps
## the wear of what it holds, which goes with it wherever it is moved. The
## server keeps the real one; clients run their clicks on a copy at once
## (same rules, Minecraft's) and get corrected.

## Who holds a slot a left drag shares a stack over (see spread).
enum Holder { OWN, CHEST, FURNACE }

const HOTBAR := 9
const BAG := 27
const SLOTS := HOTBAR + BAG
const CURSOR := SLOTS
## The crafting grid: GRID x GRID cells from CRAFT, row by row. The
## inventory's own grid is the top left OWN_GRID x OWN_GRID, a
## workbench's all of it; what lies there goes back when the screen
## closes (put_back_all).
const GRID := 5
const OWN_GRID := 3
const CRAFT := CURSOR + 1
## What the player wears: Armor.PIECES slots from ARMOR (helmet,
## chestplate, leggings, boots).
const ARMOR := CRAFT + GRID * GRID
const SIZE := ARMOR + Armor.PIECES
## A chest's slots (the first ones of an Inventory of its own).
const CHEST := 27

var items := PackedInt32Array()
var counts := PackedInt32Array()
## The wear of each slot's tool (uses; 0: new; Items.durability: broken),
## the water of a watering can (0: empty; Items.CAN_WATER: full).
var wear := PackedInt32Array()
## The hotbar slot in hand.
var selected := 0


func _init() -> void:
	items.resize(SIZE)
	counts.resize(SIZE)
	wear.resize(SIZE)


## The item in hand.
func held() -> int:
	return items[selected]


## Adds items to the slots, hotbar first: onto stacks of the same item,
## then into empty slots (`worn`: the wear of a tool). Returns how many
## did not fit.
func add(item: int, count: int, worn := 0) -> int:
	return _add_to(item, count, range(SLOTS), worn)


## How many of an item would fit in the slots.
func room_for(item: int) -> int:
	var stack := Items.max_stack(item)
	var room := 0
	for slot in SLOTS:
		if items[slot] == Items.Id.NONE:
			room += stack
		elif items[slot] == item:
			room += stack - counts[slot]
	return room


## Takes up to `count` items from a slot; returns how many were taken.
func take(slot: int, count: int) -> int:
	var taken := mini(count, counts[slot])
	counts[slot] -= taken
	if counts[slot] <= 0:
		items[slot] = Items.Id.NONE
		counts[slot] = 0
		wear[slot] = 0
	return taken


## Uses the tool in a slot once: it wears, and worn out it breaks (the slot
## empties). Returns true if it broke.
func wear_out(slot: int) -> bool:
	var durability := Items.durability(items[slot])
	if durability == 0:
		return false
	wear[slot] += 1
	if wear[slot] < durability:
		return false
	take(slot, counts[slot])
	return true


## A click on a slot (or a cell of the crafting grid), Minecraft's rules:
## left picks a stack up, puts the held one down, adds it onto the same
## item or swaps the two (tools, which do not stack, swap); right picks
## half a stack up or puts one item down; shift moves the stack between
## the hotbar and the bag (from the grid: into the slots; with a chest
## open, `chest`: into the chest; with a furnace open, `furnace`: what it
## cooks or burns into it; a piece of armor goes on when its slot is
## free). Armor slots follow Armor.click.
func click(
	slot: int, right: bool, shift: bool, chest: Inventory = null, furnace: Furnace = null
) -> void:
	if slot < 0 or slot >= SIZE or slot == CURSOR:
		return
	if slot >= ARMOR:
		Armor.click(self, slot, shift)
		return
	if shift and slot < SLOTS and chest == null and furnace == null and Armor.put_on(self, slot):
		return
	if shift and furnace != null and slot < SLOTS:
		var before := counts[slot]
		for into: int in [Furnace.INPUT, Furnace.FUEL]:
			if items[slot] != Items.Id.NONE and furnace.fits(into, items[slot]):
				_move(slot, furnace.slots, [into])
		if counts[slot] != before:
			return
	if shift:
		var others := range(HOTBAR, SLOTS) if slot < HOTBAR else range(HOTBAR)
		if slot >= CRAFT:
			others = range(SLOTS)
		if chest != null and slot < SLOTS:
			_move(slot, chest, range(CHEST))
		else:
			_move(slot, self, others)
		return
	_click_on(self, slot, right)


## A click on a slot of a chest (its own Inventory) with this inventory's
## cursor: the same rules; shift moves the stack into this inventory's
## slots.
func click_chest(chest: Inventory, slot: int, right: bool, shift: bool) -> void:
	if slot < 0 or slot >= CHEST:
		return
	if shift:
		chest._move(slot, self, range(SLOTS))
	else:
		_click_on(chest, slot, right)


## A click on a slot of a furnace with this inventory's cursor: what it
## cooks and what it burns only go where they belong (Furnace.fits); what
## it made only comes out, onto the cursor's stack too. Shift moves a
## stack into this inventory's slots.
func click_furnace(furnace: Furnace, slot: int, right: bool, shift: bool) -> void:
	if slot < 0 or slot >= Furnace.SLOTS:
		return
	var oven := furnace.slots
	if shift:
		oven._move(slot, self, range(SLOTS))
		return
	var held_item := items[CURSOR]
	if slot == Furnace.OUTPUT:
		var made := oven.items[slot]
		if held_item == Items.Id.NONE:
			_click_on(oven, slot, right)
		elif made == held_item:
			var amount := mini(oven.counts[slot], Items.max_stack(made) - counts[CURSOR])
			counts[CURSOR] += oven.take(slot, maxi(amount, 0))
		return
	if held_item == Items.Id.NONE or furnace.fits(slot, held_item):
		_click_on(oven, slot, right)


## Whether a slot can take `item` from a left drag: `target` is
## Vector2i(Holder, index): one of this inventory's slots or crafting
## cells, of the open `chest`, or what the open `furnace` cooks or burns
## (as it fits), empty or holding the same item with room.
func can_spread_to(
	target: Vector2i, item: int, chest: Inventory = null, furnace: Furnace = null
) -> bool:
	var holder := _holder(target, chest, furnace)
	if holder == null or item == Items.Id.NONE:
		return false
	if target.x == Holder.FURNACE and not furnace.fits(target.y, item):
		return false
	var there := holder.items[target.y]
	if there == Items.Id.NONE:
		return true
	return there == item and holder.counts[target.y] < Items.max_stack(item)


## Shares the cursor's stack evenly between slots (Minecraft's left drag):
## the `targets` (Vector2i(Holder, index), in the order crossed) that can
## take it, no more of them than items in hand; each gets the same share,
## as much as fits, and the rest stays in hand.
func spread(targets: Array, chest: Inventory = null, furnace: Furnace = null) -> void:
	var item := items[CURSOR]
	var taking: Array[Vector2i] = []
	for target: Variant in targets:
		if taking.size() >= counts[CURSOR]:
			break
		if target is Vector2i and not taking.has(target):
			if can_spread_to(target, item, chest, furnace):
				taking.append(target)
	if taking.is_empty():
		return
	var share := counts[CURSOR] / taking.size()
	var worn := wear[CURSOR]
	for target in taking:
		var holder := _holder(target, chest, furnace)
		var amount := mini(share, Items.max_stack(item) - holder.counts[target.y])
		if holder.items[target.y] == Items.Id.NONE:
			holder.items[target.y] = item
			holder.wear[target.y] = worn
		holder.counts[target.y] += amount
		take(CURSOR, amount)


## Gathers into the cursor's stack the same items lying elsewhere
## (Minecraft's double click): from the crafting grid, the open `chest`, the
## open `furnace`, the bag and the hotbar, part stacks before full ones, as
## many as the stack takes.
func collect(chest: Inventory = null, furnace: Furnace = null) -> void:
	var item := items[CURSOR]
	var stack := Items.max_stack(item)
	if item == Items.Id.NONE or stack <= 1:
		return
	var sources: Array[Array] = []
	for slot in range(CRAFT, ARMOR):
		sources.append([self, slot])
	if chest != null:
		for slot in CHEST:
			sources.append([chest, slot])
	if furnace != null:
		for slot in Furnace.SLOTS:
			sources.append([furnace.slots, slot])
	for slot in range(HOTBAR, SLOTS) + range(HOTBAR):
		sources.append([self, slot])
	for full_ones in [false, true]:
		for source in sources:
			var holder: Inventory = source[0]
			var slot: int = source[1]
			if counts[CURSOR] >= stack:
				return
			if holder.items[slot] != item or (holder.counts[slot] >= stack) != full_ones:
				continue
			counts[CURSOR] += holder.take(slot, mini(stack - counts[CURSOR], holder.counts[slot]))


## A copy of the slots (to go back to, see restore).
func snapshot() -> Inventory:
	var copy := Inventory.new()
	copy.restore(self)
	return copy


## Takes back the slots of `from` (a snapshot).
func restore(from: Inventory) -> void:
	items = from.items.duplicate()
	counts = from.counts.duplicate()
	wear = from.wear.duplicate()


## The items of the slots (to save a chest: its first CHEST slots).
func contents(slots: int) -> Dictionary:
	return {
		"items": items.slice(0, slots),
		"counts": counts.slice(0, slots),
		"wear": wear.slice(0, slots)
	}


## A left or right click on `holder`'s `slot` with this inventory's cursor.
func _click_on(holder: Inventory, slot: int, right: bool) -> void:
	var held_item := items[CURSOR]
	if held_item == Items.Id.NONE:
		if holder.items[slot] == Items.Id.NONE:
			return
		items[CURSOR] = holder.items[slot]
		wear[CURSOR] = holder.wear[slot]
		var half := (holder.counts[slot] + 1) / 2
		counts[CURSOR] = holder.take(slot, half if right else holder.counts[slot])
		return
	if (
		holder.items[slot] == Items.Id.NONE
		or (holder.items[slot] == held_item and Items.max_stack(held_item) > 1)
	):
		var amount := mini(
			1 if right else counts[CURSOR], Items.max_stack(held_item) - holder.counts[slot]
		)
		if amount <= 0:
			return
		if holder.items[slot] == Items.Id.NONE:
			holder.wear[slot] = wear[CURSOR]
		holder.items[slot] = held_item
		holder.counts[slot] += amount
		take(CURSOR, amount)
		return
	if not right:
		var item := holder.items[slot]
		var count := holder.counts[slot]
		var worn := holder.wear[slot]
		holder.items[slot] = held_item
		holder.counts[slot] = counts[CURSOR]
		holder.wear[slot] = wear[CURSOR]
		items[CURSOR] = item
		counts[CURSOR] = count
		wear[CURSOR] = worn


## Moves the stack of a slot into `into`'s `slots` (what does not fit
## stays).
func _move(slot: int, into: Inventory, slots: Array) -> void:
	var item := items[slot]
	var worn := wear[slot]
	var count := take(slot, counts[slot])
	var left := into._add_to(item, count, slots, worn)
	if left > 0:
		items[slot] = item
		counts[slot] = left
		wear[slot] = worn


## The inventory holding a left drag's slot (null: none, or a slot it may
## not fill: the cursor, a furnace's output).
func _holder(target: Vector2i, chest: Inventory, furnace: Furnace) -> Inventory:
	var slot := target.y
	match target.x:
		Holder.OWN:
			if (slot >= 0 and slot < SLOTS) or (slot >= CRAFT and slot < ARMOR):
				return self
		Holder.CHEST:
			if chest != null and slot >= 0 and slot < CHEST:
				return chest
		Holder.FURNACE:
			if furnace != null and (slot == Furnace.INPUT or slot == Furnace.FUEL):
				return furnace.slots
	return null


## The items of the crafting grid `width` cells wide, row by row.
func grid(width: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	for row in width:
		for column in width:
			cells.append(items[CRAFT + row * GRID + column])
	return cells


## What the crafting grid `width` cells wide makes: [item, count]
## (Vector2i.ZERO: nothing).
func craft_result(width: int) -> Vector2i:
	return Recipes.result_of(grid(width), width)


## Takes what the grid makes into the cursor (onto the same item if there
## is room), using one of each ingredient; with shift, makes as many as
## the slots can take, straight into them.
func craft(width: int, shift: bool) -> void:
	var result := craft_result(width)
	if result == Vector2i.ZERO:
		return
	if shift:
		var first := result.x
		while result.x == first and room_for(result.x) >= result.y:
			add(result.x, result.y)
			_use_grid(width)
			result = craft_result(width)
		return
	var held := items[CURSOR]
	if held != Items.Id.NONE:
		if held != result.x or counts[CURSOR] + result.y > Items.max_stack(held):
			return
	items[CURSOR] = result.x
	counts[CURSOR] += result.y
	_use_grid(width)


## Puts the cursor's stack and the crafting grid back into the slots (the
## screen closes); returns what did not fit ([item, count, wear]: to
## throw).
func put_back_all() -> Array[Vector3i]:
	var left: Array[Vector3i] = []
	for slot in [CURSOR] + range(CRAFT, ARMOR):
		var item := items[slot]
		if item != Items.Id.NONE:
			var worn := wear[slot]
			var over := add(item, take(slot, counts[slot]), worn)
			if over > 0:
				left.append(Vector3i(item, over, worn))
	return left


func to_dict() -> Dictionary:
	return {"items": items, "counts": counts, "wear": wear, "selected": selected}


func load_dict(data: Dictionary) -> void:
	var loaded_items: PackedInt32Array = data.get("items", PackedInt32Array())
	var loaded_counts: PackedInt32Array = data.get("counts", PackedInt32Array())
	var loaded_wear: PackedInt32Array = data.get("wear", PackedInt32Array())
	for slot in mini(loaded_items.size(), SIZE):
		var item := loaded_items[slot]
		var count := loaded_counts[slot] if slot < loaded_counts.size() else 0
		var valid := Items.is_valid(item) and count > 0
		items[slot] = item if valid else Items.Id.NONE
		counts[slot] = mini(count, Items.max_stack(item)) if valid else 0
		var worn := loaded_wear[slot] if slot < loaded_wear.size() else 0
		wear[slot] = clampi(worn, 0, Items.wear_limit(item)) if valid else 0
	selected = clampi(int(data.get("selected", 0)), 0, HOTBAR - 1)


## One of each item in the grid `width` cells wide goes (it was crafted).
func _use_grid(width: int) -> void:
	for row in width:
		for column in width:
			take(CRAFT + row * GRID + column, 1)


func _add_to(item: int, count: int, slots: Array, worn := 0) -> int:
	var left := count
	var stack := Items.max_stack(item)
	if stack == 0:
		return left
	for pass_empty in [false, true]:
		for slot: int in slots:
			if left == 0:
				return 0
			if pass_empty and items[slot] == Items.Id.NONE:
				items[slot] = item
				counts[slot] = 0
				wear[slot] = worn
			if items[slot] == item and counts[slot] < stack:
				var moved := mini(left, stack - counts[slot])
				counts[slot] += moved
				left -= moved
	return left
