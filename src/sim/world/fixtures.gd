class_name Fixtures
extends RefCounted
## What players build into their houses and gardens, on the server: gates
## swinging open and shut (Msg.SWING_GATE), what hangs on a wall falling
## with it.


## A player swung the gate in `cell`: kept if within reach and not shutting
## on anybody. Refused, the player is told what is there.
static func swing_gate(
	server: GameServer, session: GameServer.PlayerSession, cell: Vector3i
) -> void:
	var world := server.world
	var voxel := world.voxel_at(cell)
	var near := Mining.reach_to(session.position, session.height, cell)
	var cells := {}
	if (
		session.joined
		and session.alive()
		and Mining.swings(voxel)
		and near <= Mining.REACH + GameServer.REACH_LEEWAY
	):
		cells = Mining.swung_cells(cell, voxel, world.voxel_at)
	for at: Vector3i in cells.keys():
		if Voxels.is_solid(cells[at]) and someone_in(server, at):
			cells.clear()
			break
	if cells.is_empty():
		for at in Mining.object_cells(cell, voxel, world.voxel_at):
			session.transport.send(Msg.block_changed(at, world.voxel_at(at)))
		return
	for at: Vector3i in cells:
		server.change_voxel(at, cells[at])


## What hung on the cube broken in `cell` falls, and gives itself back
## (`drops`, not in creative).
static func drop_hung(server: GameServer, cell: Vector3i, drops: bool) -> void:
	for at in Mining.hung_on(cell, server.world.voxel_at):
		var voxel := server.world.voxel_at(at)
		server.change_voxel(at, Voxels.AIR)
		if drops:
			server.drop_from(at, voxel)


## Whether a player or a creature stands in a cell.
static func someone_in(server: GameServer, cell: Vector3i) -> bool:
	for other in server.sessions:
		if other.joined and Mining.overlaps_body(cell, other.position, other.height):
			return true
	for creature: Creature in server.creatures.living.values():
		var body := creature.body
		if Mining.overlaps_body(cell, body.feet, body.height, body.box, body.tall):
			return true
	return false
