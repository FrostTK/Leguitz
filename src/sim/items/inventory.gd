class_name Inventory
extends RefCounted
## A player's items: the hotbar (HOTBAR slots, the selected one is in
## hand), the bag, and the stack the cursor holds while things are moved
## around (slot CURSOR). The server keeps the real one; clients run their
## clicks on a copy at once (same rules, Minecraft's) and get corrected.

const HOTBAR := 9
const BAG := 27
const SLOTS := HOTBAR + BAG
const CURSOR := SLOTS

var items := PackedInt32Array()
var counts := PackedInt32Array()
## The hotbar slot in hand.
var selected := 0


func _init() -> void:
	items.resize(SLOTS + 1)
	counts.resize(SLOTS + 1)


## The item in hand.
func held() -> int:
	return items[selected]


## Adds items to the slots, hotbar first: onto stacks of the same item,
## then into empty slots. Returns how many did not fit.
func add(item: int, count: int) -> int:
	return _add_to(item, count, range(SLOTS))


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
	return taken


## A click on a slot, Minecraft's rules: left picks a stack up, puts the
## held one down, adds it onto the same item or swaps the two; right picks
## half a stack up or puts one item down; shift moves the stack between
## the hotbar and the bag.
func click(slot: int, right: bool, shift: bool) -> void:
	if slot < 0 or slot >= SLOTS:
		return
	if shift:
		var item := items[slot]
		var count := take(slot, counts[slot])
		var others := range(HOTBAR, SLOTS) if slot < HOTBAR else range(HOTBAR)
		var left := _add_to(item, count, others)
		if left > 0:
			items[slot] = item
			counts[slot] = left
		return
	var held_item := items[CURSOR]
	if held_item == Items.Id.NONE:
		if items[slot] == Items.Id.NONE:
			return
		items[CURSOR] = items[slot]
		counts[CURSOR] = take(slot, (counts[slot] + 1) / 2 if right else counts[slot])
		return
	if items[slot] == Items.Id.NONE or items[slot] == held_item:
		var amount := mini(
			1 if right else counts[CURSOR], Items.max_stack(held_item) - counts[slot]
		)
		if amount <= 0:
			return
		items[slot] = held_item
		counts[slot] += amount
		take(CURSOR, amount)
		return
	if not right:
		var item := items[slot]
		var count := counts[slot]
		items[slot] = held_item
		counts[slot] = counts[CURSOR]
		items[CURSOR] = item
		counts[CURSOR] = count


## Puts the cursor's stack back into the slots (the inventory closes);
## returns what did not fit [item, count] (to drop), clearing the cursor.
func put_back_cursor() -> Vector2i:
	var item := items[CURSOR]
	var left := add(item, take(CURSOR, counts[CURSOR])) if item != Items.Id.NONE else 0
	return Vector2i(item, left) if left > 0 else Vector2i.ZERO


func to_dict() -> Dictionary:
	return {"items": items, "counts": counts, "selected": selected}


func load_dict(data: Dictionary) -> void:
	var loaded_items: PackedInt32Array = data.get("items", PackedInt32Array())
	var loaded_counts: PackedInt32Array = data.get("counts", PackedInt32Array())
	for slot in mini(loaded_items.size(), SLOTS + 1):
		var item := loaded_items[slot]
		var count := loaded_counts[slot] if slot < loaded_counts.size() else 0
		var valid := Items.is_valid(item) and count > 0
		items[slot] = item if valid else Items.Id.NONE
		counts[slot] = mini(count, Items.max_stack(item)) if valid else 0
	selected = clampi(int(data.get("selected", 0)), 0, HOTBAR - 1)


func _add_to(item: int, count: int, slots: Array) -> int:
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
			if items[slot] == item and counts[slot] < stack:
				var moved := mini(left, stack - counts[slot])
				counts[slot] += moved
				left -= moved
	return left
