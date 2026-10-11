class_name Hearths
extends RefCounted
## Fireplaces and stoves (phase 8, step 8; static, given the server). Fed
## a fuel (Msg.STOKE: a right click or E with what burns in hand, one at a
## time; Smelting's fuels), a hearth lights (its lit kind, LIT: it shines,
## smokes up a chimney over it, RoofBlocks.FIRES, and warms the players
## around it, Warmth) and burns BURN_SLOWER times the fuel's time in a
## furnace (paced by WorldClock.scale_duration), MOST_SECONDS at most
## stored; then it goes out. The watering can puts it out. What is left to
## burn is kept per cell (ChunkData.fires, the cell holding its model;
## saved with the region); GameServer.tick runs `update` every TICKS.

const MESSAGES: Array[String] = [Msg.STOKE]
const TICKS := 20
## The hearths (unlit, as placed) and their lit kind.
const LIT := {
	Tiles.Block.FIREPLACE: Tiles.Block.FIREPLACE_LIT,
	Tiles.Block.STOVE: Tiles.Block.STOVE_LIT,
}
const BURN_SLOWER := 8.0
const MOST_SECONDS := 2400.0


## A fireplace or a stove, lit or not, any part of it.
static func is_hearth(block: int) -> bool:
	return LIT.has(ObjectShapes.pair_of(ObjectShapes.base_kind(block)))


static func is_lit(block: int) -> bool:
	return LIT.values().has(ObjectShapes.base_kind(block))


## Whether a right click with `item` does something to a hearth (fuel, the
## watering can).
static func feeds(item: int) -> bool:
	return Smelting.is_fuel(item) or item == Items.Id.WATERING_CAN


## Msg.STOKE: a fuel in hotbar slot `slot` goes into the hearth in `cell`
## (it lights), the watering can puts it out. False: not this message.
static func handle(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> bool:
	if not message.get("t") in MESSAGES:
		return false
	var world := server.world
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var slot := clampi(int(message.get("slot", 0)), 0, Inventory.HOTBAR - 1)
	var voxel := world.voxel_at(cell)
	var near := Mining.reach_to(session.position, session.height, cell)
	if not session.joined or not session.alive() or not is_hearth(Voxels.block_of(voxel)):
		return true
	if near > Mining.REACH + GameServer.REACH_LEEWAY:
		return true
	cell = Mining.object_cells(cell, voxel, world.voxel_at)[0]
	var chunk: ChunkData = world.chunks.get(Coords.tile_to_chunk(Vector2i(cell.x, cell.z)))
	var bag := session.inventory
	var held := bag.items[slot]
	if chunk == null:
		return true
	if held == Items.Id.WATERING_CAN:
		chunk.fires.erase(cell)
		world.contents_changed(cell)
		_show(server, cell, false)
		return true
	if not Smelting.is_fuel(held):
		session.transport.send(Msg.notice("HUD_HEARTH_FUEL"))
		return true
	var most := server.clock.scale_duration(MOST_SECONDS)
	var left: float = chunk.fires.get(cell, 0.0)
	if left >= most:
		session.transport.send(Msg.notice("HUD_HEARTH_FULL"))
		return true
	var adds := server.clock.scale_duration(Smelting.burn_seconds(held) * BURN_SLOWER)
	chunk.fires[cell] = minf(left + adds, most)
	world.contents_changed(cell)
	if not GameModes.creative(server):
		bag.take(slot, 1)
	_show(server, cell, true)
	session.transport.send(Msg.inventory(bag))
	return true


## The fires of the loaded chunks burn (`seconds` real seconds); burnt out,
## a hearth goes out.
static func update(server: GameServer, seconds: float) -> void:
	for chunk: ChunkData in server.world.chunks.values():
		if chunk.fires.is_empty():
			continue
		for cell: Vector3i in chunk.fires.keys():
			var left: float = chunk.fires[cell] - seconds
			if not is_hearth(Voxels.block_of(server.world.voxel_at(cell))):
				chunk.fires.erase(cell)
				continue
			if left > 0.0:
				chunk.fires[cell] = left
				continue
			chunk.fires.erase(cell)
			server.world.contents_changed(cell)
			_show(server, cell, false)


## The hearth in `cell` (the cell of its model) shows its fire, or not.
static func _show(server: GameServer, cell: Vector3i, lit: bool) -> void:
	var world := server.world
	var voxel := world.voxel_at(cell)
	if is_lit(Voxels.block_of(voxel)) == lit:
		return
	for part in Mining.object_cells(cell, voxel, world.voxel_at):
		var block := Voxels.block_of(world.voxel_at(part))
		server.change_voxel(part, Voxels.of_block(ObjectShapes.swung(block)))
