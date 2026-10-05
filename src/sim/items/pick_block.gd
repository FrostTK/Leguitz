class_name PickBlock
extends RefCounted
## The middle click on a block in first person: the item of the block
## aimed at goes in hand. In creative it is taken from the catalog into
## the hotbar when no hotbar slot holds it. In survival and hardcore only
## when the player has some: the hotbar slot holding it is chosen, or a
## stack of it in the bag comes to the hotbar (swapped with what was
## there); nothing is made. Shared: the client guesses it, the server does
## it (Msg.PICK_BLOCK, `on_message`).


## The item picked on `voxel` (Items.Id.NONE: none): the one placing it,
## whatever way it faces, its stage or its fire; in creative, else the
## first thing breaking it gives (grass: dirt; a tree: its log).
static func item_of(voxel: int, creative: bool) -> int:
	if voxel == Voxels.AIR or Voxels.is_liquid(voxel):
		return Items.Id.NONE
	if voxel < Voxels.BLOCK_BASE:
		for item: int in Items.PLACES:
			if Voxels.of_ground(Items.PLACES[item]) == voxel:
				return item
	else:
		var block := Voxels.block_of(voxel)
		var kinds := [block, ObjectShapes.base_kind(block), Farming.sown_of(block)]
		for unlit: int in ObjectShapes.LIT:
			if ObjectShapes.LIT[unlit] == ObjectShapes.base_kind(block):
				kinds.append(unlit)
		for kind: int in kinds:
			var item := Items.item_placing(kind)
			if item != Items.Id.NONE:
				return item
	if not creative:
		return Items.Id.NONE
	var rng := RandomNumberGenerator.new()
	var drops := Items.drops(voxel, Vector2i.ZERO, rng)
	return drops[0].x if not drops.is_empty() else Items.Id.NONE


## Puts `item` in `bag`'s hand (see the class); returns the hotbar slot now
## in hand, -1 when nothing changed (survival without any).
static func pick(bag: Inventory, item: int, creative: bool) -> int:
	if not Items.is_valid(item) or item == Items.Id.GUIDE_BOOK:
		return -1
	for slot in Inventory.HOTBAR:
		if bag.items[slot] == item:
			bag.selected = slot
			return slot
	var from := -1
	for slot in range(Inventory.HOTBAR, Inventory.SLOTS):
		if bag.items[slot] == item:
			from = slot
			break
	if from < 0 and not creative:
		return -1
	var to := bag.selected
	if bag.items[to] != Items.Id.NONE:
		for slot in Inventory.HOTBAR:
			if bag.items[slot] == Items.Id.NONE:
				to = slot
				break
	if from >= 0:
		_swap(bag, from, to)
	else:
		# From the catalog; what was in that slot goes into the bag if
		# there is room.
		if bag.items[to] != Items.Id.NONE:
			for slot in range(Inventory.HOTBAR, Inventory.SLOTS):
				if bag.items[slot] == Items.Id.NONE:
					_swap(bag, to, slot)
					break
		bag.items[to] = item
		bag.counts[to] = Items.max_stack(item)
		bag.wear[to] = Items.CAN_WATER if item == Items.Id.WATERING_CAN else 0
	bag.selected = to
	return to


## A player picked `item` with the middle click (the client already shows
## it in hand).
static func on_message(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> void:
	if not session.joined or not session.alive():
		return
	var item := int(message.get("item", Items.Id.NONE))
	if pick(session.inventory, item, GameModes.creative(server)) >= 0:
		session.transport.send(Msg.inventory(session.inventory))


static func _swap(bag: Inventory, a: int, b: int) -> void:
	var item := bag.items[a]
	var count := bag.counts[a]
	var worn := bag.wear[a]
	bag.items[a] = bag.items[b]
	bag.counts[a] = bag.counts[b]
	bag.wear[a] = bag.wear[b]
	bag.items[b] = item
	bag.counts[b] = count
	bag.wear[b] = worn
