class_name Survival
extends RefCounted
## Runs the players' vitality on the server (see Vitals): falls (reported
## by the clients' bodies, PlayerBody.take_fall; water breaks them), lava,
## slow healing, passing out (what they carry falls where they are) and
## getting up at the spawn. Creative players are never hurt. Stateless:
## each call is given the server.


## A player landed after falling `fell` levels: over FALL_SAFE it hurts,
## unless they landed in water.
static func landed(server: GameServer, session: GameServer.PlayerSession, fell: float) -> void:
	if not _over_water(server, session):
		hurt(server, session, Vitals.fall_damage(fell), Vitals.Cause.FALL)


## A player loses vitality (not in creative mode, not right after another
## hurt); at 0 they pass out.
static func hurt(
	server: GameServer, session: GameServer.PlayerSession, points: int, cause: int
) -> void:
	if (
		points <= 0
		or not session.alive()
		or session.immune > 0.0
		or server.settings.game_mode == WorldSettings.GameMode.CREATIVE
	):
		return
	session.health = maxi(session.health - points, 0)
	session.immune = Vitals.HURT_IMMUNITY
	session.since_hurt = 0.0
	session.transport.send(Msg.health(session.health, true, cause))
	if session.health == 0:
		_pass_out(server, session, cause)


## A player's vitality ran out: what they carried falls where they are,
## what they had open closes, they wait to get up (Msg.RESPAWN).
static func _pass_out(server: GameServer, session: GameServer.PlayerSession, cause: int) -> void:
	session.chest = GameServer.NO_CELL
	session.furnace = GameServer.NO_CELL
	session.craft_width = Inventory.OWN_GRID
	var bag := session.inventory
	for left in bag.put_back_all():
		server.throw_item(session, left.x, left.y, left.z)
	var middle := GameServer.body_middle(session)
	for slot in Inventory.SLOTS:
		if bag.items[slot] != Items.Id.NONE:
			var speed := Vector3(
				server.rng.randf_range(-2.0, 2.0), 3.0, server.rng.randf_range(-2.0, 2.0)
			)
			var dropped := server.spawn_item(bag.items[slot], bag.counts[slot], middle, speed)
			dropped.wear = bag.wear[slot]
			bag.take(slot, bag.counts[slot])
	session.transport.send(Msg.inventory(bag))
	session.transport.send(Msg.died(cause))


## A player who passed out gets up at the spawn, fully well.
static func get_up(server: GameServer, session: GameServer.PlayerSession) -> void:
	if not session.joined or session.alive():
		return
	session.health = Vitals.MAX_HEALTH
	session.immune = 0.0
	session.since_hurt = INF
	session.position = Coords.tile_to_world_center(server.spawn_tile) + Vector2(0, 4)
	session.height = server.world.surface_height(server.spawn_tile)
	session.transport.send(Msg.player_teleport(session.position, session.height))
	session.transport.send(Msg.health(session.health))


## Lava burns the players standing in it; vitality comes back slowly to
## those nothing hurt for a while.
static func update(server: GameServer, sessions: Array, delta: float) -> void:
	for session: GameServer.PlayerSession in sessions:
		if not session.joined or not session.alive():
			continue
		session.immune = maxf(session.immune - delta, 0.0)
		session.since_hurt += delta
		if _feet_ground(server, session) == Tiles.Ground.LAVA:
			session.burning += delta
			if session.burning >= Vitals.LAVA_SECONDS:
				session.burning = 0.0
				hurt(server, session, Vitals.LAVA_DAMAGE, Vitals.Cause.LAVA)
		else:
			session.burning = Vitals.LAVA_SECONDS
		if session.health >= Vitals.MAX_HEALTH or not session.alive():
			session.healing = 0.0
			continue
		if session.since_hurt < server.clock.scale_duration(Vitals.REGEN_DELAY):
			continue
		session.healing += delta
		if session.healing >= server.clock.scale_duration(Vitals.REGEN_SECONDS):
			session.healing = 0.0
			session.health += 1
			session.transport.send(Msg.health(session.health))


## The ground (Tiles.Ground) under a player's feet: water or lava they
## stand on, the ground they walk on (NONE on blocks).
static func _feet_ground(server: GameServer, session: GameServer.PlayerSession) -> int:
	var tile := Coords.world_to_tile(session.position)
	var row := floori(session.height + ChunkData.WATER_DROP + 0.01) + GameConst.SEA_LEVEL - 1
	return Voxels.ground_of(server.world.voxel_at(Vector3i(tile.x, row, tile.y)))


## Whether a player stands on water (it breaks falls).
static func _over_water(server: GameServer, session: GameServer.PlayerSession) -> bool:
	return Tiles.is_water(_feet_ground(server, session))
