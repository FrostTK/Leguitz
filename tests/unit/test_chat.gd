extends TestCase
## The chat and its commands: what players say goes to everyone, commands
## run on the server and answer in the chat, admins (the first player to
## join, saved with the world), tp (random: far away on dry land; tiles,
## ~, players), time, weather, game mode, give (names in English or
## French, accents aside), summon, heal; names and words matched plainly.

const SEA := GameConst.SEA_LEVEL

var _server: GameServer
var _clients: Array[LocalTransport] = []


## A server with `count` players (the first one joined first), noon.
func _start(count := 1) -> void:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	_server = GameServer.new(settings, null, false)
	_clients.clear()
	for i in count:
		var transports := LocalTransport.create_pair()
		_server.connect_client(transports[1])
		transports[0].send(Msg.hello(["Alex", "Sam", "Lou"][i], 2))
		_server.process_messages()
		_clients.append(transports[0])
	_server.clock.set_frozen(WorldClock.FROZEN_NOON)
	for client in _clients:
		client.poll()


func _session(index := 0) -> GameServer.PlayerSession:
	return _server.sessions[index]


## Player `index` types `text`; returns the chat lines they got.
func _type(text: String, index := 0) -> Array:
	_clients[index].send(Msg.chat(text))
	_server.process_messages()
	return _lines(index)


func _lines(index: int) -> Array:
	return _clients[index].poll().filter(
		func(message: Dictionary) -> bool: return message["t"] == Msg.CHAT_LINE
	)


func _keys(lines: Array) -> Array:
	return lines.map(func(line: Dictionary) -> String: return line.get("key", ""))


func _held(item: int) -> int:
	var count := 0
	for slot in Inventory.SLOTS:
		if _session().inventory.items[slot] == item:
			count += _session().inventory.counts[slot]
	return count


func test_what_a_player_says_goes_to_everyone() -> void:
	_start(2)
	var mine := _type("  Hello there  ")
	for lines: Array in [mine, _lines(1)]:
		assert_eq(lines.size(), 1, "everyone reads it")
		assert_eq(lines[0]["from"], "Alex")
		assert_eq(lines[0]["text"], "Hello there", "trimmed")
	_type("   ")
	assert_true(_lines(1).is_empty(), "nothing said")
	_type("x".repeat(Chat.MAX_LENGTH + 50))
	assert_eq(String(_lines(1)[0]["text"]).length(), Chat.MAX_LENGTH, "cut")


func test_commands_answer_in_the_chat_and_admins_rule() -> void:
	_start(2)
	assert_eq(_server.settings.admins, ["Alex"], "the first to join is the admin")
	assert_eq(_keys(_type("/dance")), ["CHAT_UNKNOWN"])
	assert_eq(_keys(_type("/")), ["CHAT_HOW"])
	# Sam may use the commands for everyone, not the admins'.
	assert_eq(_keys(_type("/tp random", 1)), ["CHAT_NOT_ADMIN"])
	var help := _type("/aide", 1)
	assert_eq(help.size(), 1 + Commands.available(_server, _session(1)).size())
	assert_eq(help.size(), 6, "the five for everyone")
	assert_eq(_type("/help", 0).size(), 1 + Commands.LIST.size(), "an admin's are all")
	assert_eq(_keys(_type("/AIDE tp", 1)), ["CHAT_HELP_LINE", "CMD_TP_HELP"], "in detail")
	assert_eq(_keys(_type("/joueurs", 1)), ["CMD_PLAYERS_DONE"])
	# A whisper reaches one player.
	_type("/mp sam see you", 0)
	var heard := _lines(1)
	assert_eq(_keys(heard), ["CMD_MSG_FROM"])
	assert_eq(heard[0]["args"], ["Alex", "see you"])
	assert_eq(_keys(_type("/msg nobody hi")), ["CHAT_NO_PLAYER"])
	# Admins are named and kept with the world.
	assert_eq(_keys(_type("/admin ajoute Sam")), ["CMD_ADMIN_ADDED"])
	assert_eq(_keys(_lines(1)), ["CMD_ADMIN_YOU"], "Sam is told")
	assert_eq(_keys(_type("/météo pluie", 1)), ["CMD_WEATHER_DONE"], "Sam may now")
	assert_eq(_keys(_type("/admin retire alex", 1)), ["CMD_ADMIN_REMOVED"])
	assert_eq(_keys(_type("/admin remove Sam", 1)), ["CMD_ADMIN_LAST"], "one at least")
	var saved := WorldSettings.new()
	saved.load_dict(_server.settings.to_dict())
	assert_eq(saved.admins, ["Sam"], "saved with the world")
	assert_eq(_keys(_type("/tp spawn", 0)), ["CHAT_NOT_ADMIN"], "Alex no longer")


func test_tp_random_lands_far_away_on_dry_ground() -> void:
	_start()
	var session := _session()
	var from := Coords.world_to_tile(session.position)
	var lines := _type("/tp hasard")
	assert_eq(_keys(lines), ["CMD_TP_DONE", "CMD_TP_RANDOM"])
	var tile := Coords.world_to_tile(session.position)
	var distance := Vector2(tile - from).length()
	assert_true(distance >= WorldCommands.RANDOM_NEAR - 1.0, "far away: %d" % distance)
	assert_true(distance <= WorldCommands.RANDOM_FAR + 1.0)
	var row := floori(session.height + 0.01) + SEA
	var ground := _server.world.voxel_at(Vector3i(tile.x, row - 1, tile.y))
	assert_true(Voxels.is_cube(ground), "on solid ground, not water nor lava")
	assert_true(_server.world.can_stand(tile, row), "room to stand")


func test_tp_to_tiles_places_and_players() -> void:
	_start(2)
	var session := _session()
	var from := Coords.world_to_tile(session.position)
	_type("/tp ~10 ~-4")
	var tile := Coords.world_to_tile(session.position)
	assert_true(Vector2(tile - (from + Vector2i(10, -4))).length() <= 6.0, "near there")
	assert_almost(session.height, _server.world.surface_height(tile), 0.01, "on the ground")
	_type("/tp 100 30 -200")
	assert_eq(Coords.world_to_tile(session.position), Vector2i(100, -200))
	assert_almost(session.height, 30.0, 0.001, "at the level asked")
	_type("/tp sam")
	assert_eq(session.position.distance_to(_session(1).position) < 16.0, true, "by Sam")
	assert_eq(_keys(_type("/tp here there")), ["CHAT_USAGE"], "not coordinates")
	assert_eq(WorldCommands.coordinate("~", 5.0), 5.0)
	assert_eq(WorldCommands.coordinate("~-2.5", 5.0), 2.5)
	assert_true(is_nan(WorldCommands.coordinate("north", 5.0)))


func test_time_weather_and_game_mode() -> void:
	_start()
	var clock := _server.clock
	clock.set_normal(20.0)
	_type("/heure minuit")
	assert_eq(clock.hour(), 0)
	assert_eq(clock.mode, WorldClock.Mode.NORMAL, "the clock goes on")
	_type("/time 7h30")
	assert_eq([clock.hour(), clock.minute()], [7, 30])
	_type("/heure fige")
	assert_eq(clock.mode, WorldClock.Mode.FROZEN)
	_type("/time noon")
	assert_eq([clock.hour(), clock.mode], [12, WorldClock.Mode.FROZEN], "still frozen")
	assert_eq(_keys(_type("/time 25:00")), ["CHAT_USAGE"])
	clock.set_synced()
	assert_eq(_keys(_type("/time day")), ["CMD_TIME_SYNCED"])
	assert_eq(WorldCommands.hour_of("19h"), 19.0)
	_type("/meteo orage")
	assert_eq(_server.weather.kind, Weather.Kind.THUNDER)
	_type("/weather clear")
	assert_eq(_server.weather.kind, Weather.Kind.CLEAR)
	_type("/mode créatif")
	assert_eq(_server.settings.game_mode, WorldSettings.GameMode.CREATIVE)
	_type("/gamemode survival")
	assert_eq(_server.settings.game_mode, WorldSettings.GameMode.SURVIVAL)
	_server.settings.game_mode = WorldSettings.GameMode.HARDCORE
	assert_eq(_keys(_type("/mode creatif")), ["CMD_MODE_HARDCORE"])


func test_give_summon_and_heal() -> void:
	_start()
	_type("/give oak_planks 70")
	assert_eq(_held(Items.Id.OAK_PLANKS), 70, "by its own name, more than a stack")
	_type("/donne pot de miel 2")
	assert_eq(_held(Items.Id.HONEY_BOTTLE), 2, "by its French name")
	_type("/donne Planches de chene")
	assert_eq(_held(Items.Id.OAK_PLANKS), 71, "accents aside")
	_type("/give honeycomb")
	assert_eq(_held(Items.Id.HONEYCOMB), 1, "in English")
	var lines := _type("/give planches")
	assert_eq(_keys(lines), ["CHAT_WHICH"], "several planks")
	assert_eq(_keys(_type("/give unobtainium")), ["CMD_GIVE_UNKNOWN"])
	assert_eq(_keys(_type("/give")), ["CHAT_USAGE"])
	_type("/give watering can")
	var bag := _session().inventory
	var can := Array(bag.items).find(Items.Id.WATERING_CAN)
	assert_eq(bag.wear[can], Items.CAN_WATER, "a can comes full")
	var before := _server.creatures.living.size()
	lines = _type("/invoque vache 3")
	assert_eq(_keys(lines), ["CMD_SUMMON_DONE"])
	assert_eq(_server.creatures.living.size(), before + 3)
	assert_eq(_keys(_type("/summon bee")), ["CMD_SUMMON_UNKNOWN"], "bees come from hives")
	_session().health = 3
	_session().food = 2
	_type("/soigne")
	assert_eq([_session().health, _session().food], [Vitals.MAX_HEALTH, Vitals.MAX_FOOD])


func test_names_are_matched_plainly() -> void:
	assert_eq(Chat.plain("  Pot_de   MIEL "), "pot de miel")
	assert_eq(Chat.plain("Créatif Œuf"), "creatif oeuf")
	var names := {"oak planks": 1, "oak log": 2, "stone": 3}
	assert_eq(Chat.lookup(names, "Stone"), 3)
	assert_eq(Chat.lookup(names, "oak p"), 1, "the only one starting so")
	var close: Array = []
	assert_eq(Chat.lookup(names, "oak", close), -1)
	assert_eq(close.size(), 2, "the names it could be")
	assert_eq(Commands.find("MÉTÉO")["name"], "weather")
	assert_true(Commands.find("fly").is_empty())
	for command in Commands.LIST:
		for key in [Commands.usage_key(command), Commands.help_key(command)]:
			assert_ne(tr(key), key, "%s translated" % key)
