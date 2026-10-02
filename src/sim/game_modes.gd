class_name GameModes
extends RefCounted
## The game modes' rules on the server (WorldSettings.GameMode, the
## world's). Creative: players fly (their clients), their blocks never run
## out, what they break goes at once and drops nothing, their tools never
## wear, nothing hurts them nor makes them hungry (Survival), they take any
## item from the catalog (take_from_catalog) and use the debug
## commands. Survival is the game. Hardcore is survival with one life: a
## player who passes out only watches the world from then on, a spectator
## (Survival, saved with them). The world goes from survival to creative
## and back (Msg.SET_GAME_MODE, from the pause menu); a hardcore world stays
## hardcore. Stateless: each call is given the server (take_from_catalog,
## shared, also runs the client's guess).


static func creative(server: GameServer) -> bool:
	return server.settings.game_mode == WorldSettings.GameMode.CREATIVE


static func hardcore(server: GameServer) -> bool:
	return server.settings.game_mode == WorldSettings.GameMode.HARDCORE


## Whether a player may use the debug commands: in creative, where the
## server allows them (in every mode with `cheats_anywhere`).
static func cheats(server: GameServer, session: GameServer.PlayerSession) -> bool:
	return (
		session.joined
		and server.allow_debug_commands
		and (creative(server) or server.cheats_anywhere)
	)


## A player asks for another mode: survival and creative swap (back in
## creative, the players are well again); a hardcore world stays hardcore,
## and a player passed out waits to get up. Every player is told the mode.
static func set_mode(server: GameServer, session: GameServer.PlayerSession, mode: int) -> void:
	if not session.joined:
		return
	var swaps := [WorldSettings.GameMode.CREATIVE, WorldSettings.GameMode.SURVIVAL]
	if session.alive() and not hardcore(server) and mode in swaps:
		server.settings.game_mode = mode as WorldSettings.GameMode
		if creative(server):
			for other in server.sessions:
				if other.joined and other.alive():
					_restore(other)
	for other in server.sessions:
		if other.joined:
			other.transport.send(Msg.game_mode(server.settings.game_mode, other.spectator))


## Vitality, satiety and air full again (told).
static func _restore(session: GameServer.PlayerSession) -> void:
	session.health = Vitals.MAX_HEALTH
	session.food = Vitals.MAX_FOOD
	session.air = Vitals.MAX_AIR
	session.air_told = Vitals.MAX_AIR
	session.effort = 0.0
	session.transport.send(Msg.vitals(session.health, session.food))


## A click on an item of the creative catalog, which never runs out, with
## `bag`'s cursor: with empty hands, left takes a stack of it, right one;
## with it in hand, left fills the stack, right adds one; with something
## else in hand, that goes away. Shift puts a stack of it into the slots
## (hotbar first).
static func take_from_catalog(bag: Inventory, item: int, right: bool, shift: bool) -> void:
	if not Items.is_valid(item) or item == Items.Id.GUIDE_BOOK:
		return
	var stack := Items.max_stack(item)
	if shift:
		bag.add(item, stack)
		return
	var held := bag.items[Inventory.CURSOR]
	if held == Items.Id.NONE:
		bag.items[Inventory.CURSOR] = item
		bag.counts[Inventory.CURSOR] = 1 if right else stack
		bag.wear[Inventory.CURSOR] = 0
	elif held == item:
		var more := mini(bag.counts[Inventory.CURSOR] + 1, stack)
		bag.counts[Inventory.CURSOR] = more if right else stack
	else:
		bag.take(Inventory.CURSOR, bag.counts[Inventory.CURSOR])


## A player clicked the creative catalog (take_from_catalog).
static func catalog_click(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> void:
	if not session.joined:
		return
	if creative(server) and session.alive():
		var item := int(message.get("item", Items.Id.NONE))
		take_from_catalog(
			session.inventory, item, message.get("right", false), message.get("shift", false)
		)
	session.transport.send(Msg.inventory(session.inventory))


## Debug: jump down to the next cave (or back up towards the surface),
## in the player's column or the closest one that has such a place.
static func move_depth(
	server: GameServer, session: GameServer.PlayerSession, direction: int
) -> void:
	if not cheats(server, session) or direction == 0:
		return
	var tile := Coords.world_to_tile(session.position)
	var found := server.world.find_floor(tile, session.height, signi(direction))
	if found.is_empty():
		return
	session.position = Coords.tile_to_world_center(found[0]) + Vector2(0, 4)
	session.height = found[1]
	session.transport.send(Msg.player_teleport(session.position, session.height))


## Debug: a player gets the tools of a tier (what does not fit is thrown
## at their feet).
static func give_tools(server: GameServer, session: GameServer.PlayerSession, tier: int) -> void:
	if not cheats(server, session):
		return
	for item in Items.tools_of_tier(clampi(tier, 0, Items.Tier.size() - 1)):
		if session.inventory.add(item, 1) > 0:
			server.throw_item(session, item, 1)
	session.transport.send(Msg.inventory(session.inventory))


## Debug: the weather changes at once.
static func set_weather(server: GameServer, session: GameServer.PlayerSession, kind: int) -> void:
	if not cheats(server, session):
		return
	server.weather.set_kind(clampi(kind, 0, Weather.Kind.size() - 1) as Weather.Kind, server.clock)
	server.broadcast(Msg.weather_state(server.weather))
