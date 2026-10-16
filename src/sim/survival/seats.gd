class_name Seats
extends RefCounted
## Who sits where (multiplayer, step 3; static, given the server): a player
## sitting down (Msg.SIT, from FurnitureUse) takes a seat within reach that
## nobody else holds (PlayerSession.sits_on); refused (taken: HUD_SEAT_TAKEN),
## Msg.STAND_UP gets them up again in their game. Msg.STAND, moving off it
## (MoveCheck) or the seat gone (`update`) frees it. The others see them
## seated (Peers.state), MoveCheck lets them be. Beds: one sleeper each
## (Beds).

const MESSAGES: Array[String] = [Msg.SIT, Msg.STAND]


static func handle(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> bool:
	if not message.get("t") in MESSAGES:
		return false
	if not session.joined:
		return true
	if message.get("t") == Msg.STAND:
		session.sits_on = GameServer.NO_CELL
		return true
	var cell: Vector3i = message.get("cell", GameServer.NO_CELL)
	var block := Voxels.block_of(server.world.voxel_at(cell))
	var near := Mining.reach_to(session.position, session.height, cell)
	var free := taker(server, cell) in [null, session]
	if (
		Furniture.is_seat(block)
		and near <= Mining.REACH + GameServer.REACH_LEEWAY
		and session.alive()
		and not session.sleeping
		and free
	):
		session.sits_on = cell
		return true
	session.transport.send(Msg.stand_up())
	if not free:
		session.transport.send(Msg.notice("HUD_SEAT_TAKEN"))
	return true


## Who sits in `cell` (null: nobody).
static func taker(server: GameServer, cell: Vector3i) -> GameServer.PlayerSession:
	for session in server.sessions:
		if session.joined and session.sits_on == cell:
			return session
	return null


## Seats broken free their sitters.
static func update(server: GameServer) -> void:
	for session in server.sessions:
		if session.sits_on == GameServer.NO_CELL:
			continue
		var block := Voxels.block_of(server.world.loaded_voxel_at(session.sits_on))
		if not Furniture.is_seat(block) or not session.alive():
			session.sits_on = GameServer.NO_CELL
