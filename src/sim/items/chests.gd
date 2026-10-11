class_name Chests
extends RefCounted
## What players store things in (static, given the server; moved out of
## GameServer): chests and the storage furniture (ObjectShapes.is_chest),
## a boat's chests (Boats.chest_cell). A player opens one within reach
## (Msg.OPEN_CHEST) and sees what it holds (Msg.CHEST) until they close it;
## their clicks, drags and double clicks (Msg.SLOT_CLICK, SLOT_SPREAD,
## SLOT_COLLECT, CHEST_CLICK) go to it and to the open furnace; everyone who
## has a chest open sees it change.

const MESSAGES: Array[String] = [
	Msg.OPEN_CHEST, Msg.CHEST_CLICK, Msg.SLOT_CLICK, Msg.SLOT_SPREAD, Msg.SLOT_COLLECT
]


## One of MESSAGES (false: not one of them).
static func handle(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> bool:
	if not message.get("t") in MESSAGES:
		return false
	if not session.joined:
		return true
	match message.get("t"):
		Msg.OPEN_CHEST:
			_open(server, session, message)
		Msg.CHEST_CLICK:
			var chest := opened(server, session)
			if chest != null:
				var slot := int(message.get("slot", -1))
				var right: bool = message.get("right", false)
				session.inventory.click_chest(chest, slot, right, message.get("shift", false))
				session.transport.send(Msg.inventory(session.inventory))
				changed(server, session.chest)
		Msg.SLOT_CLICK:
			var slot := int(message.get("slot", -1))
			var open := opened(server, session)
			var oven := Furnaces.opened(server, session)
			var right: bool = message.get("right", false)
			session.inventory.click(slot, right, message.get("shift", false), open, oven)
			_told(server, session, open, oven)
		Msg.SLOT_SPREAD:
			var targets: Variant = message.get("targets", [])
			if targets is Array:
				var open := opened(server, session)
				var oven := Furnaces.opened(server, session)
				var limit := Inventory.SIZE + Inventory.CHEST
				session.inventory.spread((targets as Array).slice(0, limit), open, oven)
				_told(server, session, open, oven)
		Msg.SLOT_COLLECT:
			var open := opened(server, session)
			var oven := Furnaces.opened(server, session)
			session.inventory.collect(open, oven)
			_told(server, session, open, oven)
	return true


## The chest a player has open (null: none, or it is gone; a boat's: see
## Boats.chest_cell).
static func opened(server: GameServer, session: GameServer.PlayerSession) -> Inventory:
	if not session.joined or session.chest == GameServer.NO_CELL:
		return null
	if session.chest.y <= Boats.CHEST_ROW:
		return server.boats.chest_at(session.chest)
	if not ObjectShapes.is_chest(Voxels.block_of(server.world.voxel_at(session.chest))):
		return null
	return server.world.chest_at(session.chest)


## A chest's items changed: saved with its chunk, shown to every player
## who has it open.
static func changed(server: GameServer, cell: Vector3i) -> void:
	var boat_chest := cell.y <= Boats.CHEST_ROW
	if not boat_chest:
		server.world.contents_changed(cell)
	var chest := server.boats.chest_at(cell) if boat_chest else server.world.chest_at(cell)
	for other in server.sessions:
		if other.joined and other.chest == cell and chest != null:
			other.transport.send(Msg.chest(cell, chest))


## A player opened a chest within reach (the foot of one two levels tall).
static func _open(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> void:
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var near := Mining.reach_to(session.position, session.height, cell)
	var there := Voxels.block_of(server.world.voxel_at(cell))
	if not ObjectShapes.is_chest(there) or near > Mining.REACH + GameServer.REACH_LEEWAY:
		return
	session.chest = cell
	session.transport.send(Msg.chest(cell, server.world.chest_at(cell)))


## Their inventory, the open chest and furnace after a click.
static func _told(
	server: GameServer, session: GameServer.PlayerSession, open: Inventory, oven: Furnace
) -> void:
	session.transport.send(Msg.inventory(session.inventory))
	if open != null:
		changed(server, session.chest)
	if oven != null:
		Furnaces.changed(server, session.furnace)
