class_name Shelves
extends RefCounted
## Display shelves (phase 8, step 7; static, given the server): a shelf on
## a wall holds SLOTS things, shown on it (ChunkData.shelves: cell -> the
## items, Items.Id.NONE where none; saved with the region and sent with the
## chunk; ShelvesView draws them). A right click (Msg.SHELF) with something
## in hand puts one of it on the shelf, empty-handed takes the last back
## (Msg.SHELF_ITEMS tells the players having the chunk). Broken, a shelf's
## things fall (`spill`).

const SLOTS := 3
const MESSAGES: Array[String] = [Msg.SHELF]


static func handle(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> bool:
	if not message.get("t") in MESSAGES:
		return false
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var slot := clampi(int(message.get("slot", 0)), 0, Inventory.HOTBAR - 1)
	var block := Voxels.block_of(server.world.voxel_at(cell))
	var near := Mining.reach_to(session.position, session.height, cell)
	if not session.joined or not session.alive() or not Furniture.is_shelf(block):
		return true
	if near > Mining.REACH + GameServer.REACH_LEEWAY:
		return true
	var items := items_at(server.world, cell)
	var bag := session.inventory
	var held := bag.items[slot]
	var free := items.find(Items.Id.NONE)
	if held != Items.Id.NONE and free >= 0:
		items[free] = held
		bag.take(slot, 1)
	else:
		var last := SLOTS - 1
		while last >= 0 and items[last] == Items.Id.NONE:
			last -= 1
		if last < 0:
			return true
		if bag.add(items[last], 1) > 0:
			server.throw_item(session, items[last], 1)
		items[last] = Items.Id.NONE
	_store(server, cell, items)
	session.transport.send(Msg.inventory(bag))
	return true


## What a shelf holds (SLOTS items; NONE: empty).
static func items_at(world: WorldState, cell: Vector3i) -> PackedInt32Array:
	var chunk: ChunkData = world.chunks.get(Coords.tile_to_chunk(Vector2i(cell.x, cell.z)))
	if chunk != null and chunk.shelves.has(cell):
		return chunk.shelves[cell].duplicate()
	var empty := PackedInt32Array()
	empty.resize(SLOTS)
	empty.fill(Items.Id.NONE)
	return empty


## A shelf broken: its things fall.
static func spill(server: GameServer, cell: Vector3i) -> void:
	var chunk: ChunkData = server.world.chunks.get(Coords.tile_to_chunk(Vector2i(cell.x, cell.z)))
	if chunk == null or not chunk.shelves.has(cell):
		return
	var middle := Vector3(cell.x + 0.5, cell.y - GameConst.SEA_LEVEL + 0.5, cell.z + 0.5)
	for item in chunk.shelves[cell]:
		if item != Items.Id.NONE:
			server.spawn_item(item, 1, middle, Vector3(0.0, 2.0, 0.0))
	var empty := PackedInt32Array()
	_store(server, cell, empty)


## A shelf's things changed: kept (none: forgotten), saved, told.
static func _store(server: GameServer, cell: Vector3i, items: PackedInt32Array) -> void:
	var coord := Coords.tile_to_chunk(Vector2i(cell.x, cell.z))
	var chunk: ChunkData = server.world.chunks.get(coord)
	if chunk == null:
		return
	if items.count(Items.Id.NONE) == items.size():
		chunk.shelves.erase(cell)
	else:
		chunk.shelves[cell] = items
	server.world.contents_changed(cell)
	for session in server.sessions:
		if session.joined and session.sent_chunks.has(coord):
			session.transport.send(Msg.shelf_items(cell, chunk.shelves.get(cell, items)))
