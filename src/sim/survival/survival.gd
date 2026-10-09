class_name Survival
extends RefCounted
## Runs the players' vitality and satiety on the server (see Vitals):
## falls (reported by the clients' bodies, PlayerBody.take_fall; water
## breaks them), lava, air and drowning, satiety spent with effort,
## eating, starving, slow
## healing when well fed, passing out (what they carry falls where they
## are) and getting up at the spawn (in hardcore, never: they only watch
## the world, GameModes). Creative players are never hurt nor hungry.
## Dishes' effects (Effects) wear off with time; REGEN heals, FED slows
## hunger. Stateless: each call is given the server.


## A player landed after falling `fell` levels: over FALL_SAFE it hurts,
## unless they landed in water.
static func landed(server: GameServer, session: GameServer.PlayerSession, fell: float) -> void:
	if not _over_water(server, session):
		hurt(server, session, Vitals.fall_damage(fell), Vitals.Cause.FALL)


## A player loses vitality (not in creative mode, not right after another
## hurt; monsters' blows through their armor, Vitals.ARMORED); at 0 they
## pass out.
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
	var lost := points
	if Vitals.ARMORED.has(cause) and Armor.defense(session.inventory) > 0:
		# Armor takes part of the blow (what is left over carries to the
		# next) and wears.
		var taken := Armor.reduce(points, Armor.defense(session.inventory)) + session.hurt_carry
		lost = floori(taken)
		session.hurt_carry = taken - lost
		Armor.wear_out(session.inventory)
		session.transport.send(Msg.inventory(session.inventory))
		if lost <= 0:
			session.immune = Vitals.HURT_IMMUNITY
			return
	session.health = maxi(session.health - lost, 0)
	session.immune = Vitals.HURT_IMMUNITY
	session.since_hurt = 0.0
	_tell(session, true, cause)
	if session.health == 0:
		_pass_out(server, session, cause)


## A player's vitality ran out: what they carried falls where they are,
## what they had open closes, they wait to get up (Msg.RESPAWN).
static func _pass_out(server: GameServer, session: GameServer.PlayerSession, cause: int) -> void:
	session.chest = GameServer.NO_CELL
	session.furnace = GameServer.NO_CELL
	session.craft_width = Inventory.OWN_GRID
	session.kitchen = false
	session.effects.clear()
	var bag := session.inventory
	for left in bag.put_back_all():
		server.throw_item(session, left.x, left.y, left.z)
	var middle := GameServer.body_middle(session)
	for slot in range(Inventory.SLOTS) + range(Inventory.ARMOR, Inventory.SIZE):
		if bag.items[slot] != Items.Id.NONE:
			var speed := Vector3(
				server.rng.randf_range(-2.0, 2.0), 3.0, server.rng.randf_range(-2.0, 2.0)
			)
			var dropped := server.spawn_item(bag.items[slot], bag.counts[slot], middle, speed)
			dropped.wear = bag.wear[slot]
			bag.take(slot, bag.counts[slot])
	session.transport.send(Msg.inventory(bag))
	session.transport.send(Msg.died(cause))
	if GameModes.hardcore(server):
		session.spectator = true
		session.transport.send(Msg.game_mode(server.settings.game_mode, true))


## A player who passed out gets up at the spawn, fully well.
static func get_up(server: GameServer, session: GameServer.PlayerSession) -> void:
	if not session.joined or session.alive() or session.spectator:
		return
	session.health = Vitals.MAX_HEALTH
	session.food = Vitals.MAX_FOOD
	session.effort = 0.0
	session.air = Vitals.MAX_AIR
	session.immune = 0.0
	session.since_hurt = INF
	session.position = Coords.tile_to_world_center(server.spawn_tile) + Vector2(0, 4)
	session.height = server.world.surface_height(server.spawn_tile)
	session.transport.send(Msg.player_teleport(session.position, session.height))
	_tell(session)


## A player spends effort (Vitals: walking, mining, healing): a point of
## satiety goes per point of effort (never in creative mode).
static func spend(server: GameServer, session: GameServer.PlayerSession, effort: float) -> void:
	if (
		effort <= 0.0
		or not session.alive()
		or server.settings.game_mode == WorldSettings.GameMode.CREATIVE
	):
		return
	var slower := Effects.FED_SLOWER if Effects.has(session.effects, Effects.Kind.FED) else 1.0
	session.effort += effort * slower
	if session.effort < 1.0:
		return
	var spent := floori(session.effort)
	session.effort -= spent
	if session.food > 0:
		session.food = maxi(session.food - spent, 0)
		_tell(session)


## A player ate one of what a hotbar slot holds: food fills them up (not
## past full: then nothing is eaten, but for dishes with effects, which they
## take); a raw red mushroom makes them sick.
static func eat(server: GameServer, session: GameServer.PlayerSession, slot: int) -> void:
	if not session.joined or not session.alive() or slot < 0 or slot >= Inventory.HOTBAR:
		return
	var item := session.inventory.items[slot]
	var full := session.food >= Vitals.MAX_FOOD and not Effects.gives(item)
	if not Items.is_food(item) or full:
		session.transport.send(Msg.inventory(session.inventory))
		return
	session.inventory.take(slot, 1)
	if Items.LEFT_AFTER.has(item):
		# Milk drunk: its bucket stays in hand.
		var left: int = Items.LEFT_AFTER[item]
		if session.inventory.items[slot] == Items.Id.NONE:
			session.inventory.items[slot] = left
			session.inventory.counts[slot] = 1
		elif session.inventory.add(left, 1) > 0:
			server.throw_item(session, left, 1)
	session.food = mini(session.food + Items.FOOD[item], Vitals.MAX_FOOD)
	Effects.take(session.effects, item, server.clock.scale_duration(1.0))
	session.transport.send(Msg.inventory(session.inventory))
	_tell(session)
	if Vitals.POISONS.has(item):
		hurt(server, session, Vitals.POISONS[item], Vitals.Cause.POISON)


## Lava burns the players standing in it; satiety goes with time, and
## starving hurts; vitality comes back slowly to those well fed whom
## nothing hurt for a while.
static func update(server: GameServer, sessions: Array, delta: float) -> void:
	for session: GameServer.PlayerSession in sessions:
		if not session.joined or not session.alive():
			continue
		session.immune = maxf(session.immune - delta, 0.0)
		session.since_hurt += delta
		_breathe(server, session, delta)
		var bathed := PlayerBody.liquid_at(session.position, session.height, server.world.voxel_at)
		if Voxels.is_lava(bathed):
			session.burning += delta
			if session.burning >= Vitals.LAVA_SECONDS:
				session.burning = 0.0
				hurt(server, session, Vitals.LAVA_DAMAGE, Vitals.Cause.LAVA)
		else:
			session.burning = Vitals.LAVA_SECONDS
		spend(server, session, delta / server.clock.scale_duration(Vitals.FOOD_SECONDS))
		_starve(server, session, delta)
		_heal(server, session, delta)
		_mend(server, session, delta)
		if Effects.wear(session.effects, delta):
			_tell(session)


## The eye under water uses air; without air, drowning hurts. Out of the
## water, air comes back fast. Told in steps of AIR_STEP.
static func _breathe(server: GameServer, session: GameServer.PlayerSession, delta: float) -> void:
	var under := PlayerBody.eye_in_water(session.position, session.height, server.world.voxel_at)
	if under and server.settings.game_mode != WorldSettings.GameMode.CREATIVE:
		session.air = maxf(session.air - delta, 0.0)
		if session.air == 0.0:
			session.drowning += delta
			if session.drowning >= Vitals.DROWN_SECONDS:
				session.drowning = 0.0
				hurt(server, session, Vitals.DROWN_DAMAGE, Vitals.Cause.DROWNING)
	else:
		session.drowning = 0.0
		session.air = minf(session.air + delta * Vitals.AIR_REFILL, Vitals.MAX_AIR)
	var full := session.air == Vitals.MAX_AIR
	if (
		absf(session.air - session.air_told) >= Vitals.AIR_STEP
		or (full and session.air_told != Vitals.MAX_AIR)
	):
		_tell(session)


## Starving (no satiety left): a point of vitality every STARVE_SECONDS.
static func _starve(server: GameServer, session: GameServer.PlayerSession, delta: float) -> void:
	if session.food > 0 or not session.alive():
		session.starving = 0.0
		return
	session.starving += delta
	if session.starving >= server.clock.scale_duration(Vitals.STARVE_SECONDS):
		session.starving = 0.0
		hurt(server, session, 1, Vitals.Cause.STARVATION)


## Well fed, a point of vitality every REGEN_SECONDS once nothing hurt
## for REGEN_DELAY; it costs satiety.
static func _heal(server: GameServer, session: GameServer.PlayerSession, delta: float) -> void:
	if (
		session.health >= Vitals.MAX_HEALTH
		or not session.alive()
		or session.food < Vitals.FED
		or session.since_hurt < server.clock.scale_duration(Vitals.REGEN_DELAY)
	):
		session.healing = 0.0
		return
	session.healing += delta
	if session.healing >= server.clock.scale_duration(Vitals.REGEN_SECONDS):
		session.healing = 0.0
		session.health += 1
		_tell(session)
		spend(server, session, Vitals.HEAL_EFFORT)


## A dish's REGEN: a point of vitality every Effects.REGEN_EVERY (paced),
## whatever the satiety.
static func _mend(server: GameServer, session: GameServer.PlayerSession, delta: float) -> void:
	if not Effects.has(session.effects, Effects.Kind.REGEN):
		session.mending = 0.0
		return
	session.mending += delta
	if session.mending >= server.clock.scale_duration(Effects.REGEN_EVERY):
		session.mending = 0.0
		if session.health < Vitals.MAX_HEALTH:
			session.health += 1
			_tell(session)


## Tells a player their vitality, satiety and effects (`hurt`: vitality
## just went down, from `cause`).
static func _tell(
	session: GameServer.PlayerSession, hurt := false, cause := Vitals.Cause.NONE
) -> void:
	session.air_told = session.air
	session.transport.send(
		Msg.vitals(session.health, session.food, hurt, cause, session.air, session.effects)
	)


## Whether a player is in water (it breaks falls).
static func _over_water(server: GameServer, session: GameServer.PlayerSession) -> bool:
	var bathed := PlayerBody.liquid_at(session.position, session.height, server.world.voxel_at)
	return Tiles.is_water(Voxels.ground_of(bathed))
