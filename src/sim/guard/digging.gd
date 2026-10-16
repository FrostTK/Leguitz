class_name Digging
extends RefCounted
## How long breaking takes, on a dedicated server (multiplayer, step 3;
## static, given the server; a solo game trusts its client): the client
## says when it starts on a block (Msg.DIG, its cell: `start`) and a break
## (Msg.BLOCK_BREAK) is only taken (`allows`) SHARE of Mining.break_seconds
## later (with what is in that hand slot, faster with a HASTE dish; SLACK
## seconds less for the network), on that very cell; what breaks at once
## (Mining.INSTANT_SECONDS) breaks at once; in creative, BREAK_PAUSE *
## SHARE after the last break. Refused, the block stays (BLOCK_CHANGED) and
## Guard.report tells the console.

const SHARE := 0.8
const SLACK := 0.1


## A player starts breaking the block in `cell`.
static func start(server: GameServer, session: GameServer.PlayerSession, cell: Vector3i) -> void:
	session.guard.dig_cell = cell
	session.guard.dig_since = server.now()


## Whether `session` may break `voxel` in `cell` now, holding hotbar slot
## `slot` (-1: nothing of it).
static func allows(
	server: GameServer, session: GameServer.PlayerSession, cell: Vector3i, voxel: int, slot: int
) -> bool:
	if not server.dedicated:
		return true
	var watch := session.guard
	var now := server.now()
	var allowed := true
	if GameModes.creative(server):
		allowed = now - watch.last_break >= Mining.BREAK_PAUSE * SHARE
	else:
		var bag := session.inventory
		var held := bag.items[slot] if slot >= 0 and slot < Inventory.HOTBAR else Items.Id.NONE
		var seconds := Mining.break_seconds(voxel, held)
		if Effects.has(session.effects, Effects.Kind.HASTE):
			seconds /= Effects.HASTE_SPEED
		if seconds > Mining.INSTANT_SECONDS:
			var long_enough := now - watch.dig_since >= seconds * SHARE - SLACK
			allowed = watch.dig_cell == cell and long_enough
	if not allowed:
		Guard.report(server, session, "GUARD_DIG")
		return false
	watch.last_break = now
	watch.dig_cell = Vector3i.MAX
	return true
