class_name Furnaces
extends RefCounted
## The furnaces on the server (static, given the server; moved out of
## GameServer): players open them (within reach, not a broken one) and
## click their slots; GameServer.tick steps those of the loaded chunks
## every FURNACE_TICKS; each change is saved with its chunk, lit or put
## out (its lit kind), and shown to every player who has it open. Ore
## melted in a food furnace breaks it.


## A player opened a furnace within reach (not a broken one): they see
## it, and their clicks go to it until they close it.
static func open(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> void:
	if not session.joined:
		return
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var near := Mining.reach_to(session.position, session.height, cell)
	var there := Voxels.block_of(server.world.voxel_at(cell))
	if ObjectShapes.furnace_kind(there) == -1 or near > Mining.REACH + GameServer.REACH_LEEWAY:
		return
	session.furnace = cell
	session.transport.send(Msg.furnace(cell, server.world.furnace_at(cell)))


## A click on the slots of the furnace a player has open.
static func click(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> void:
	var oven := opened(server, session)
	if oven == null:
		return
	var slot := int(message.get("slot", -1))
	var right: bool = message.get("right", false)
	session.inventory.click_furnace(oven, slot, right, message.get("shift", false))
	session.transport.send(Msg.inventory(session.inventory))
	changed(server, session.furnace)


## The furnace a player has open (null: none, or it is gone).
static func opened(server: GameServer, session: GameServer.PlayerSession) -> Furnace:
	if not session.joined or session.furnace == GameServer.NO_CELL:
		return null
	var block := Voxels.block_of(server.world.voxel_at(session.furnace))
	if ObjectShapes.furnace_kind(block) == -1:
		return null
	return server.world.furnace_at(session.furnace)


## A furnace's slots changed: saved with its chunk, lit or put out, shown
## to every player who has it open.
static func changed(server: GameServer, cell: Vector3i) -> void:
	server.world.contents_changed(cell)
	_show_fire(server, cell)
	_send(server, cell)


## The furnaces of the loaded chunks burn and cook (`delta`: real
## seconds); the players who opened one see it.
static func update(server: GameServer, delta: float) -> void:
	for chunk: ChunkData in server.world.chunks.values():
		if chunk.furnaces.is_empty():
			continue
		for cell: Vector3i in chunk.furnaces.keys():
			var furnace: Furnace = chunk.furnaces[cell]
			var was := [furnace.fire, furnace.progress, furnace.lane_progress.duplicate()]
			match furnace.step(delta, server.clock):
				Furnace.Step.BROKE:
					_break(server, cell)
				Furnace.Step.CHANGED:
					changed(server, cell)
				_:
					if was != [furnace.fire, furnace.progress, furnace.lane_progress]:
						_send(server, cell)


static func _send(server: GameServer, cell: Vector3i) -> void:
	for other in server.sessions:
		if other.joined and other.furnace == cell:
			other.transport.send(Msg.furnace(cell, server.world.furnace_at(cell)))


## A furnace's voxel shows whether it burns (its lit kind, the same way).
static func _show_fire(server: GameServer, cell: Vector3i) -> void:
	var block := Voxels.block_of(server.world.voxel_at(cell))
	var kind := ObjectShapes.furnace_kind(block)
	if kind == -1:
		return
	var lit := server.world.furnace_at(cell).burning()
	var shown := ObjectShapes.facing(
		ObjectShapes.LIT[kind] if lit else kind, ObjectShapes.front_of(block)
	)
	if shown != block:
		server.change_voxel(cell, Voxels.of_block(shown))


## Ore melted in a food furnace: it breaks (the ore is lost), what it held
## spills, and it is useless.
static func _break(server: GameServer, cell: Vector3i) -> void:
	var block := Voxels.block_of(server.world.voxel_at(cell))
	server.spill_contents(cell)
	var broken := ObjectShapes.facing(Tiles.Block.BROKEN_FURNACE, ObjectShapes.front_of(block))
	server.change_voxel(cell, Voxels.of_block(broken))
