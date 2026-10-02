class_name Watering
extends RefCounted
## Watering farmland, on the server (static, given the server; Growth lets
## the rain fall). A watering can (Items.Id.WATERING_CAN) is filled at
## water, still or flowing, or at a sink (`fill`: Items.CAN_WATER tiles'
## worth, kept in its slot's wear) and waters a tile of farmland at a time
## (`water`; aimed at a crop, the farmland under it): the farmland stays
## wet for WATERED_SECONDS (paced by WorldClock.scale_duration; the time
## left is in ChunkData.watered) wherever the water is. The rain waters
## farmland under the open sky the same way (`rain`), and canals as any
## water near (Farming.wet_near: flowing water counts).

## How long (seconds, a quarter of the default day) watered farmland stays
## wet.
const WATERED_SECONDS := 300.0
## Server: a can is used this far at most (local units, like placing).
const REACH_LEEWAY := 1.5


## Whether a can is filled from a voxel: water (still or flowing), a sink.
static func fills_from(voxel: int) -> bool:
	return (
		Voxels.is_water(voxel) or ObjectShapes.base_kind(Voxels.block_of(voxel)) == Tiles.Block.SINK
	)


## The farmland a can aimed at a cell waters: the cell, or the farmland
## under the crop aimed at (Vector3i.MAX: none).
static func bed_of(cell: Vector3i, voxel_at: Callable) -> Vector3i:
	var voxel: int = voxel_at.call(cell)
	if Farming.is_farmland(voxel):
		return cell
	var under := cell + Vector3i.DOWN
	if Farming.is_crop(Voxels.block_of(voxel)) and Farming.is_farmland(voxel_at.call(under)):
		return under
	return Vector3i.MAX


## Whether the rain falls on a cell: nothing over it but air and objects
## (no cube, no liquid; glass is a roof).
static func under_sky(world: WorldState, cell: Vector3i) -> bool:
	var tile := Vector2i(cell.x, cell.z)
	var chunk: ChunkData = world.chunks.get(Coords.tile_to_chunk(tile))
	return chunk != null and chunk.top_row(Coords.tile_to_local(tile)) <= cell.y + 1


## A player filled the can in hotbar slot `slot` at `cell` (Msg.FILL_CAN):
## water or a sink within reach fills it up.
static func fill(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> void:
	if not session.joined or not session.alive():
		return
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var slot := clampi(int(message.get("slot", 0)), 0, Inventory.HOTBAR - 1)
	var bag := session.inventory
	var near := Mining.reach_to(session.position, session.height, cell)
	if (
		bag.items[slot] == Items.Id.WATERING_CAN
		and near <= Mining.REACH + REACH_LEEWAY
		and fills_from(server.world.voxel_at(cell))
	):
		bag.wear[slot] = Items.CAN_WATER
	session.transport.send(Msg.inventory(bag))


## A player watered the farmland at `cell` with the can in hotbar slot
## `slot` (Msg.WATER): within reach, with water in the can (any in
## creative, where it is not used up). Refused, they are told what is there.
static func water(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> void:
	if not session.joined or not session.alive():
		return
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var slot := clampi(int(message.get("slot", 0)), 0, Inventory.HOTBAR - 1)
	var bag := session.inventory
	var creative := GameModes.creative(server)
	var near := Mining.reach_to(session.position, session.height, cell)
	if (
		not Farming.is_farmland(server.world.voxel_at(cell))
		or near > Mining.REACH + REACH_LEEWAY
		or bag.items[slot] != Items.Id.WATERING_CAN
		or (bag.wear[slot] <= 0 and not creative)
	):
		session.transport.send(Msg.block_changed(cell, server.world.voxel_at(cell)))
		session.transport.send(Msg.inventory(bag))
		return
	wet(server, cell)
	if not creative:
		bag.wear[slot] -= 1
	session.transport.send(Msg.inventory(bag))


## Farmland gets water (a can, the rain): wet for WATERED_SECONDS.
static func wet(server: GameServer, cell: Vector3i) -> void:
	var tile := Vector2i(cell.x, cell.z)
	var chunk: ChunkData = server.world.chunks.get(Coords.tile_to_chunk(tile))
	if chunk == null:
		return
	chunk.watered[cell] = server.clock.scale_duration(WATERED_SECONDS)
	server.world.contents_changed(cell)
	var wet_voxel := Voxels.of_ground(Tiles.Ground.FARMLAND_WET)
	if server.world.loaded_voxel_at(cell) != wet_voxel:
		server.change_voxel(cell, wet_voxel)


## Farmland watered keeps wet a while, `seconds` less each check (Growth);
## under the open sky the rain waters it again. Returns whether it is
## still wet from the can or the rain.
static func dry_out(server: GameServer, chunk: ChunkData, cell: Vector3i, seconds: float) -> bool:
	if server.weather.is_raining() and under_sky(server.world, cell):
		chunk.watered[cell] = server.clock.scale_duration(WATERED_SECONDS)
		return true
	if not chunk.watered.has(cell):
		return false
	var left: float = chunk.watered[cell] - seconds
	if left <= 0.0:
		chunk.watered.erase(cell)
		return false
	chunk.watered[cell] = left
	return true
