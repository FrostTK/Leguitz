class_name Monsters
extends RefCounted
## How monsters come and go and hunt, on the server (Creatures runs them;
## stateless: each call is given the server). Around each player they may
## hunt (`hunts`: awake, not a spectator, never in creative), monsters come
## out one at a time (a chance in COME_CHANCE every
## Creatures.MONSTER_TICKS), up to MAX_NEAR within
## NEAR tiles (MAX_OF of a kind), SPAWN_DISTANCE away from every player,
## where it is dark (Light): at night under the open sky the lantern moth,
## the shade lurker and over swamps the will-o'-wisp; in caves (CAVE_DEPTH
## under the surface) the lurker and the rock mimic, by day too. They go
## when no player is within GONE_DISTANCE; under the open sky, the moth,
## the lurker and the wisp melt in daylight. Each hunts the nearest such
## player within SENSE tiles (`sense`); its blows (`land_blow`) hurt them
## (Species.DAMAGE, CAUSE), push them back (Msg.PUSH), and the moth's put
## their lantern out (Msg.LANTERN_OUT).

const NEAR := 48.0
const MAX_NEAR := 6
const COME_CHANCE := 0.4
const MAX_OF := {
	Species.Id.LANTERN_MOTH: 3,
	Species.Id.SHADE_LURKER: 4,
	Species.Id.ROCK_MIMIC: 3,
	Species.Id.WISP: 2,
}
const SPAWN_DISTANCE := Vector2(16.0, 32.0)
const GONE_DISTANCE := 64.0
## How far (tiles across, levels up or down) a monster feels its prey.
const SENSE := 16.0
const SENSE_HEIGHT := 8.0
## Caves start this many rows under the surface.
const CAVE_DEPTH := 6
## A moth comes out this high over the ground, a wisp this high.
const MOTH_RISE := 3.0
const WISP_RISE := 1.0
## A blow pushes the player back this fast (tiles per second) and up
## (levels per second); the moth's puts their lantern out this long.
const PUSH := Vector2(7.0, 4.5)
const LANTERN_OUT := 8.0
## A blow lands up to this much farther than Monster.REACH (the player
## moves while messages travel).
const REACH_LEEWAY := 0.6
## The lurker feels the light this often (seconds).
const LIGHT_CHECK := 0.5
## Those melting in daylight under the open sky.
const NIGHT_ONLY := {
	Species.Id.LANTERN_MOTH: true,
	Species.Id.SHADE_LURKER: true,
	Species.Id.WISP: true,
}
const SWAMPS := {Biomes.Id.SWAMP: true}


## Whether monsters hunt a player (and come out around them).
static func hunts(server: GameServer, session: GameServer.PlayerSession) -> bool:
	return (
		session.joined
		and session.alive()
		and not session.spectator
		and not GameModes.creative(server)
	)


## Monsters far from everyone or in daylight go; new ones may come out.
static func come_and_go(server: GameServer, creatures: Creatures) -> void:
	_go(server, creatures)
	for session in server.sessions:
		if hunts(server, session):
			_come(server, creatures, session)


## The nearest player it may hunt within SENSE tiles is its prey; the
## lurker feels whether it stands in the light.
static func sense(server: GameServer, creatures: Creatures, monster: Monster, delta: float) -> void:
	var best: GameServer.PlayerSession = null
	var nearest := SENSE
	for session in server.sessions:
		if not hunts(server, session):
			continue
		var distance := session.position.distance_to(monster.center()) / GameConst.TILE_SIZE
		if distance <= nearest and absf(session.height - monster.body.height) <= SENSE_HEIGHT:
			best = session
			nearest = distance
	if best != null:
		monster.hunt(best.position, best.height)
		monster.prey_id = best.id
	else:
		monster.forget()
		monster.prey_id = -1
	if monster.species == Species.Id.SHADE_LURKER:
		monster.light_wait -= delta
		if monster.light_wait <= 0.0:
			monster.light_wait = LIGHT_CHECK
			monster.lit = Light.is_lit(creatures.world, _cell(monster), server.clock)


## A monster's blow landed on its prey: hurt, pushed back, and a moth's
## puts their lantern out.
static func land_blow(server: GameServer, monster: Monster) -> void:
	monster.strike = false
	var session: GameServer.PlayerSession = null
	for other in server.sessions:
		if other.id == monster.prey_id:
			session = other
	if session == null or not hunts(server, session):
		return
	var feet := session.position / GameConst.TILE_SIZE
	var chest := Vector3(feet.x, session.height + 0.9, feet.y)
	if monster.middle().distance_to(chest) > Monster.REACH + REACH_LEEWAY:
		return
	Survival.hurt(server, session, Species.DAMAGE[monster.species], Species.CAUSE[monster.species])
	var away := session.position - monster.center()
	if away.length() < 0.01:
		away = monster.heading
	session.transport.send(Msg.push(away.normalized() * PUSH.x * GameConst.TILE_SIZE, PUSH.y))
	if monster.species == Species.Id.LANTERN_MOTH:
		session.transport.send(Msg.lantern_out(LANTERN_OUT))


static func _go(server: GameServer, creatures: Creatures) -> void:
	var day := not server.clock.is_night()
	for creature: Creature in creatures.living.values():
		if not creature is Monster:
			continue
		var nearest := INF
		for session in server.sessions:
			if session.joined:
				nearest = minf(nearest, session.position.distance_to(creature.center()))
		if nearest / GameConst.TILE_SIZE > GONE_DISTANCE:
			creatures.remove(server, creature, false)
		elif day and NIGHT_ONLY.has(creature.species):
			if Light.sky_open(creatures.world, _cell(creature)):
				creatures.remove(server, creature, true)


## Maybe one monster comes out around a player (see the class).
static func _come(
	server: GameServer, creatures: Creatures, session: GameServer.PlayerSession
) -> void:
	var counts := {}
	var total := 0
	for creature: Creature in creatures.living.values():
		if creature is Monster:
			if session.position.distance_to(creature.center()) <= NEAR * GameConst.TILE_SIZE:
				counts[creature.species] = counts.get(creature.species, 0) + 1
				total += 1
	var rng := creatures.rng
	if total >= MAX_NEAR or rng.randf() >= COME_CHANCE:
		return
	var offset := Vector2.RIGHT.rotated(rng.randf() * TAU)
	offset *= rng.randf_range(SPAWN_DISTANCE.x, SPAWN_DISTANCE.y)
	var tile := Coords.world_to_tile(session.position) + Vector2i(offset.round())
	for other in server.sessions:
		var gap := other.position.distance_to(Coords.tile_to_world_center(tile))
		if other.joined and gap < SPAWN_DISTANCE.x * GameConst.TILE_SIZE:
			return
	var chunk: ChunkData = creatures.world.chunks.get(Coords.tile_to_chunk(tile))
	if chunk == null:
		return
	var choices := _choices(server, creatures, chunk, tile)
	choices = choices.filter(
		func(choice: Array) -> bool: return counts.get(choice[0], 0) < MAX_OF[choice[0]]
	)
	if choices.is_empty():
		return
	var pick: Array = choices[rng.randi() % choices.size()]
	var box: Vector2 = Species.BOX[pick[0]]
	creatures.add(pick[0], Coords.tile_to_world_center(tile) + Vector2(0.0, box.y * 0.5), pick[1])


## Which monsters may come out on a tile, and at what height: [kind,
## height] each.
static func _choices(
	server: GameServer, creatures: Creatures, chunk: ChunkData, tile: Vector2i
) -> Array:
	var sea := GameConst.SEA_LEVEL
	var local := Coords.tile_to_local(tile)
	var top := chunk.top_row(local)
	var choices := []
	var at := creatures.voxel_at
	var swamp := SWAMPS.has(chunk.get_biome(local))
	if server.clock.is_night() and top > 0 and top < GameConst.WORLD_HEIGHT - 4:
		if not Light.near_fire(at, Vector3i(tile.x, top, tile.y)):
			var surface := chunk.get_voxel(Vector3i(local.x, top - 1, local.y))
			var ground := float(top - sea)
			if swamp:
				choices.append([Species.Id.WISP, ground + WISP_RISE])
			if not Voxels.is_liquid(surface):
				choices.append([Species.Id.LANTERN_MOTH, ground + MOTH_RISE])
				if Creatures.free_spot(chunk, local, top, Species.TALL[Species.Id.SHADE_LURKER]):
					choices.append([Species.Id.SHADE_LURKER, ground])
	var cave := _cave_floor(chunk, local, top - CAVE_DEPTH, creatures.rng)
	if cave > 0 and not Light.near_fire(at, Vector3i(tile.x, cave, tile.y)):
		choices.append([Species.Id.SHADE_LURKER, float(cave - sea)])
		choices.append([Species.Id.ROCK_MIMIC, float(cave - sea)])
	return choices


## A row of a cave floor in a column under `below` (a cube under two free
## voxels), picked at random; -1 if none.
static func _cave_floor(
	chunk: ChunkData, local: Vector2i, below: int, rng: RandomNumberGenerator
) -> int:
	var floors: Array[int] = []
	for y in range(mini(below, GameConst.WORLD_HEIGHT - 3), 2, -1):
		var under := chunk.get_voxel(Vector3i(local.x, y - 1, local.y))
		if not Voxels.is_cube(under):
			continue
		var free := true
		for up in 2:
			var voxel := chunk.get_voxel(Vector3i(local.x, y + up, local.y))
			if Voxels.is_solid(voxel) or Voxels.is_liquid(voxel):
				free = false
		if free:
			floors.append(y)
	return floors[rng.randi() % floors.size()] if not floors.is_empty() else -1


## The cell of a creature's feet.
static func _cell(creature: Creature) -> Vector3i:
	var tile := creature.tile()
	return Vector3i(tile.x, floori(creature.body.height + 0.01) + GameConst.SEA_LEVEL, tile.y)
