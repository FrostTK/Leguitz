class_name BagSort
extends RefCounted
## Sorting a bag (static, shared: the client shows it at once, the server
## does it, Msg.SORT_BAG; the inventory's Sort button): the bag's stacks of
## an item are joined, as full as they go, then laid from its first slot in
## the catalog's order (ItemGroups.place_of: tools and gear first, then
## food...), an item's fullest stacks first, worn things by their wear. The
## hotbar, the cursor, the crafting grid and the armor stay as they are.


static func sort(inventory: Inventory) -> void:
	var totals := {}
	var stacks: Array[Vector3i] = []
	for slot in range(Inventory.HOTBAR, Inventory.SLOTS):
		var item := inventory.items[slot]
		if item == Items.Id.NONE:
			continue
		if Items.max_stack(item) > 1 and inventory.wear[slot] == 0:
			totals[item] = totals.get(item, 0) + inventory.counts[slot]
		else:
			stacks.append(Vector3i(item, inventory.counts[slot], inventory.wear[slot]))
	for item: int in totals:
		var left: int = totals[item]
		var most := Items.max_stack(item)
		while left > 0:
			stacks.append(Vector3i(item, mini(left, most), 0))
			left -= most
	stacks.sort_custom(_before)
	for at in Inventory.BAG:
		var stack := stacks[at] if at < stacks.size() else Vector3i(Items.Id.NONE, 0, 0)
		var slot := Inventory.HOTBAR + at
		inventory.items[slot] = stack.x
		inventory.counts[slot] = stack.y
		inventory.wear[slot] = stack.z


## Whether stack `a` [item, count, wear] goes before stack `b`.
static func _before(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x:
		var first := ItemGroups.place_of(a.x)
		var second := ItemGroups.place_of(b.x)
		return first < second if first != second else a.x < b.x
	if a.y != b.y:
		return a.y > b.y
	return a.z < b.z
