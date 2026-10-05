class_name WorldCommands
extends RefCounted
## The commands about travel and the world (Commands; static, given the
## server): tp (random: a safe spot far away, spawn, a player, a tile, a
## place), time, weather and the game mode. Each returns false when its
## words do not fit (Commands then shows its usage).

## tp random: how far it goes (tiles, fewest and most) and how many spots
## it tries.
const RANDOM_NEAR := 600.0
const RANDOM_FAR := 3000.0
const RANDOM_TRIES := 48
## tp x z: how far around the tile it looks for room to stand.
const LANDING_SEARCH := 4
## The words of the times of day (plain), and the hour each sets.
const TIMES := {
	"day": 7.0,
	"jour": 7.0,
	"morning": 6.5,
	"matin": 6.5,
	"noon": 12.0,
	"midi": 12.0,
	"evening": 18.5,
	"soir": 18.5,
	"night": 21.0,
	"nuit": 21.0,
	"midnight": 0.0,
	"minuit": 0.0,
}
const FREEZE := ["freeze", "stop", "fige", "arrete"]
const RUN := ["run", "go", "reprend", "repars"]
const WEATHERS := {
	"clear": Weather.Kind.CLEAR,
	"sun": Weather.Kind.CLEAR,
	"beau": Weather.Kind.CLEAR,
	"soleil": Weather.Kind.CLEAR,
	"rain": Weather.Kind.RAIN,
	"pluie": Weather.Kind.RAIN,
	"storm": Weather.Kind.THUNDER,
	"thunder": Weather.Kind.THUNDER,
	"orage": Weather.Kind.THUNDER,
}
const WEATHER_KEYS := {
	Weather.Kind.CLEAR: "CMD_WEATHER_CLEAR",
	Weather.Kind.RAIN: "CMD_WEATHER_RAIN",
	Weather.Kind.THUNDER: "CMD_WEATHER_THUNDER",
}
const MODES := {
	"survival": WorldSettings.GameMode.SURVIVAL,
	"survie": WorldSettings.GameMode.SURVIVAL,
	"creative": WorldSettings.GameMode.CREATIVE,
	"creatif": WorldSettings.GameMode.CREATIVE,
}


## tp random | spawn | <player> | <x> <z> | <x> <level> <z> (~: from where
## the player is, ~5: 5 further).
static func teleport(server: GameServer, session: GameServer.PlayerSession, args: Array) -> bool:
	var tile := Coords.world_to_tile(session.position)
	match args.size():
		1:
			if Commands.is_word(args[0], ["random", "hasard", "aleatoire"]):
				_random(server, session)
			elif Commands.is_word(args[0], ["spawn", "depart"]):
				_go(session, server.spawn_tile, server.world.surface_height(server.spawn_tile))
			else:
				var other := Chat.find_player(server, args[0])
				if other == null:
					Chat.tell(session, "CHAT_NO_PLAYER", [args[0]], Chat.Tone.ERROR)
				else:
					session.facing = other.facing
					_go(session, Coords.world_to_tile(other.position), other.height)
			return true
		2:
			var x := coordinate(args[0], tile.x)
			var z := coordinate(args[1], tile.y)
			if is_nan(x) or is_nan(z):
				return false
			var landing := _landing(server, Vector2i(floori(x), floori(z)))
			_go(session, landing, server.world.surface_height(landing))
			return true
		3:
			var x := coordinate(args[0], tile.x)
			var level := coordinate(args[1], session.height)
			var z := coordinate(args[2], tile.y)
			if is_nan(x) or is_nan(level) or is_nan(z):
				return false
			var row_limit := GameConst.WORLD_HEIGHT - GameConst.SEA_LEVEL
			level = clampf(level, -GameConst.SEA_LEVEL + 1.0, row_limit - 2.0)
			_go(session, Vector2i(floori(x), floori(z)), level)
			return true
	return false


## A coordinate typed: a number, or ~ (`base`) and ~n (`base` + n); NAN if
## it is neither.
static func coordinate(typed: String, base: float) -> float:
	if typed.begins_with("~"):
		var more := typed.substr(1)
		if more.is_empty():
			return base
		return base + more.to_float() if more.is_valid_float() else NAN
	return typed.to_float() if typed.is_valid_float() else NAN


## time day | noon | night | midnight | <hour>[:minutes] | freeze | run.
static func time(server: GameServer, session: GameServer.PlayerSession, args: Array) -> bool:
	if args.size() != 1:
		return false
	var clock := server.clock
	var typed := Chat.plain(args[0])
	if typed in FREEZE:
		clock.set_frozen(clock.time_of_day())
	elif typed in RUN:
		if clock.mode != WorldClock.Mode.NORMAL:
			clock.set_normal(clock.day_minutes)
	else:
		var hours: float = TIMES.get(typed, hour_of(typed))
		if is_nan(hours):
			return false
		if clock.mode == WorldClock.Mode.SYNCED:
			Chat.tell(session, "CMD_TIME_SYNCED", [], Chat.Tone.ERROR)
			return true
		var frozen := clock.mode == WorldClock.Mode.FROZEN
		var minutes := clock.day_minutes
		# Frozen there, then going on from there if it went on.
		clock.set_frozen(hours * 3600.0)
		if not frozen:
			clock.set_normal(minutes)
	server.broadcast(Msg.time_state(clock))
	Chat.tell(session, "CMD_TIME_DONE", [clock.formatted_time()], Chat.Tone.DONE)
	return true


## An hour typed: 7, 7:30, 7h30, 19h (NAN if it is none).
static func hour_of(typed: String) -> float:
	var parts := typed.replace("h", ":").split(":")
	if parts.size() > 2 or not parts[0].is_valid_int():
		return NAN
	var minutes := 0
	if parts.size() == 2 and not parts[1].is_empty():
		if not parts[1].is_valid_int():
			return NAN
		minutes = parts[1].to_int()
	var hours := parts[0].to_int()
	if hours < 0 or hours > 23 or minutes < 0 or minutes > 59:
		return NAN
	return hours + minutes / 60.0


## weather clear | rain | storm.
static func weather(server: GameServer, session: GameServer.PlayerSession, args: Array) -> bool:
	if args.size() != 1 or not WEATHERS.has(Chat.plain(args[0])):
		return false
	var kind: Weather.Kind = WEATHERS[Chat.plain(args[0])]
	server.weather.set_kind(kind, server.clock)
	server.broadcast(Msg.weather_state(server.weather))
	Chat.tell(session, "CMD_WEATHER_DONE", [Chat.word(WEATHER_KEYS[kind])], Chat.Tone.DONE)
	return true


## gamemode survival | creative (a hardcore world stays hardcore).
static func game_mode(server: GameServer, session: GameServer.PlayerSession, args: Array) -> bool:
	if args.size() != 1 or not MODES.has(Chat.plain(args[0])):
		return false
	if GameModes.hardcore(server):
		Chat.tell(session, "CMD_MODE_HARDCORE", [], Chat.Tone.ERROR)
		return true
	if not session.alive():
		Chat.tell(session, "CHAT_PASSED_OUT", [], Chat.Tone.ERROR)
		return true
	var mode: int = MODES[Chat.plain(args[0])]
	GameModes.set_mode(server, session, mode)
	var key: String = WorldSettings.GAME_MODE_KEYS[mode]
	Chat.tell(session, "CMD_MODE_DONE", [Chat.word(key)], Chat.Tone.DONE)
	return true


## Somewhere far away (RANDOM_NEAR to RANDOM_FAR) on dry land with room to
## stand: not in water nor lava, not in a tree.
static func _random(server: GameServer, session: GameServer.PlayerSession) -> void:
	var from := Coords.world_to_tile(session.position)
	var world := server.world
	for i in RANDOM_TRIES:
		var away := Vector2.from_angle(server.rng.randf() * TAU)
		away *= server.rng.randf_range(RANDOM_NEAR, RANDOM_FAR)
		var tile := from + Vector2i(away.round())
		var column := world.generator.sample_column(tile.x, tile.y)
		if column.water or Biomes.is_ocean(column.biome):
			continue
		var chunk := world.get_or_create_chunk(Coords.tile_to_chunk(tile))
		if not WorldGenerator.is_free_ground(chunk, Coords.tile_to_local(tile)):
			continue
		var height := world.surface_height(tile)
		if not world.can_stand(tile, floori(height + 0.01) + GameConst.SEA_LEVEL):
			continue
		_go(session, tile, height)
		Chat.tell(session, "CMD_TP_RANDOM", [Chat.word(Biomes.name_key(column.biome))])
		return
	Chat.tell(session, "CMD_TP_NOWHERE", [], Chat.Tone.ERROR)


## The tile nearest `tile` (within LANDING_SEARCH) where a body stands on
## the ground; `tile` itself when there is none.
static func _landing(server: GameServer, tile: Vector2i) -> Vector2i:
	var world := server.world
	for radius in LANDING_SEARCH + 1:
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dz)) != radius:
					continue
				var spot := tile + Vector2i(dx, dz)
				var row := floori(world.surface_height(spot) + 0.01) + GameConst.SEA_LEVEL
				if world.can_stand(spot, row):
					return spot
	return tile


## Puts the player on `tile` at `height` (levels) and tells them where.
static func _go(session: GameServer.PlayerSession, tile: Vector2i, height: float) -> void:
	session.position = Coords.tile_to_world_center(tile) + Vector2(0, 4)
	session.height = height
	session.transport.send(Msg.player_teleport(session.position, session.height))
	Chat.tell(session, "CMD_TP_DONE", [tile.x, roundi(height), tile.y], Chat.Tone.DONE)
