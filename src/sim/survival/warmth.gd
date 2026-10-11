class_name Warmth
extends RefCounted
## The cold of winter and the warmth of a fire (phase 8, step 8; static,
## given the server; Survival.update runs `update` every TICKS). A player
## within WARM_RANGE tiles of a campfire, or indoors (under a roof, not
## Watering.under_sky) of a lit fireplace or stove (Hearths), is warm
## (Effects.Kind.WARM, for WARM_SECONDS after, paced): the cold spares them
## and they heal faster (Survival). Where winters bite
## (Seasons.snows_in: winter, not a mild biome), a player who is not warm
## is cold (Effects.Kind.COLD, while it lasts): hunger comes faster and
## they no longer heal. Never in creative mode.

const TICKS := 20
## Tiles around a player a fire warms (and rows under and over the feet).
const WARM_RANGE := 5
const ROWS_UNDER := 1
const ROWS_OVER := 2
const WARM_SECONDS := 90.0
## A warm player is told again once this much of their warmth went by.
const TELL_AFTER := 10.0
## The cold lasts while it is cold (Warmth takes it off).
const COLD_SECONDS := 1.0e6
## What warms (lit hearths too: Hearths.is_lit), by kind.
const FIRES := {Tiles.Block.CAMPFIRE: true}


## Warms or chills a player (see the class); tells them when it changes.
static func update(server: GameServer, session: GameServer.PlayerSession) -> void:
	if GameModes.creative(server):
		if session.effects.has(Effects.Kind.COLD):
			session.effects.erase(Effects.Kind.COLD)
			Survival.tell(session)
		return
	var effects := session.effects
	var told := false
	if near_fire(server, session):
		var full := server.clock.scale_duration(WARM_SECONDS)
		told = full - effects.get(Effects.Kind.WARM, 0.0) > TELL_AFTER
		told = told or effects.has(Effects.Kind.COLD)
		effects[Effects.Kind.WARM] = full
		effects.erase(Effects.Kind.COLD)
	elif cold_here(server, session) and not Effects.has(effects, Effects.Kind.WARM):
		told = not effects.has(Effects.Kind.COLD)
		effects[Effects.Kind.COLD] = COLD_SECONDS
	elif effects.has(Effects.Kind.COLD):
		effects.erase(Effects.Kind.COLD)
		told = true
	if told:
		Survival.tell(session)


## Whether a fire burns within WARM_RANGE of a player (a hearth: when they
## are indoors, as it is).
static func near_fire(server: GameServer, session: GameServer.PlayerSession) -> bool:
	var feet := Coords.world_to_tile(session.position)
	var row := floori(session.height + 0.01) + GameConst.SEA_LEVEL
	var indoors := not Watering.under_sky(server.world, Vector3i(feet.x, row + 1, feet.y))
	for dy in range(-ROWS_UNDER, ROWS_OVER + 1):
		for dz in range(-WARM_RANGE, WARM_RANGE + 1):
			for dx in range(-WARM_RANGE, WARM_RANGE + 1):
				var at := Vector3i(feet.x + dx, row + dy, feet.y + dz)
				var block := Voxels.block_of(server.world.loaded_voxel_at(at))
				if block == Tiles.Block.AIR:
					continue
				if FIRES.has(block) or (indoors and Hearths.is_lit(block)):
					return true
	return false


## Whether winter bites where a player stands (Seasons.snows_in).
static func cold_here(server: GameServer, session: GameServer.PlayerSession) -> bool:
	var tile := Coords.world_to_tile(session.position)
	var chunk: ChunkData = server.world.chunks.get(Coords.tile_to_chunk(tile))
	if chunk == null:
		return false
	return Seasons.snows_in(server.clock, chunk.get_biome(Coords.tile_to_local(tile)))
