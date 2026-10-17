extends TestCase
## Multiplayer, step 1: players joining and leaving a dedicated server,
## refused (version, password, name, full), messages crossing as bytes,
## over ENet on this machine, the server's settings and its console, the
## world's settings kept to its admins.


## A dedicated server (not saved), nobody on it.
func _server() -> GameServer:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	server.dedicated = true
	server.creatures.living.clear()
	return server


## A player saying hello as `name`: their end of the connection.
func _join(server: GameServer, name: String, hello := {}) -> LocalTransport:
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	var message := Msg.hello(name, 2)
	message.merge(hello, true)
	transports[0].send(message)
	server.process_messages()
	return transports[0]


func _kinds(transport: Transport) -> Array:
	return transport.poll().map(func(m: Dictionary) -> String: return m["t"])


## The chat notices a player got (their keys).
func _notices(transport: Transport) -> Array:
	var notices := transport.poll().filter(
		func(m: Dictionary) -> bool: return m["t"] == Msg.CHAT_LINE and m.has("key")
	)
	return notices.map(func(m: Dictionary) -> String: return m["key"])


func test_players_join_and_leave() -> void:
	var server := _server()
	var alex := _join(server, "Alex")
	assert_true(Msg.WELCOME in _kinds(alex), "welcome")
	var bea := _join(server, "Béa")
	assert_true(Msg.WELCOME in _kinds(bea), "a name of letters with accents")
	assert_eq(_notices(alex), ["CHAT_JOINED"], "told of who comes")
	assert_eq(Lobby.players(server), 2)
	bea.close()
	server.process_messages()
	assert_eq(Lobby.players(server), 1, "gone")
	assert_eq(server.sessions.size(), 1)
	assert_eq(_notices(alex), ["CHAT_LEFT"], "told of who goes")


func test_who_is_refused() -> void:
	var server := _server()
	server.password = "secret"
	server.max_players = 1
	var refusals := {
		"REFUSED_VERSION": ["Alex", {"protocol": Msg.PROTOCOL + 1, "password": "secret"}],
		"REFUSED_PASSWORD": ["Alex", {"password": "guess"}],
		"REFUSED_NAME": ["a/b", {"password": "secret"}],
	}
	for reason: String in refusals:
		var entry: Array = refusals[reason]
		var player := _join(server, entry[0], entry[1])
		var got := player.poll()
		assert_eq(got.size(), 1, reason)
		assert_eq(got[0].get("reason"), reason)
		server.process_messages()
		assert_false(player.is_open(), "let go")
	assert_true(server.sessions.is_empty(), "nobody stays")
	var alex := _join(server, "Alex", {"password": "secret"})
	assert_true(Msg.WELCOME in _kinds(alex))
	var other := _join(server, "alex", {"password": "secret"})
	assert_eq(other.poll()[0].get("reason"), "REFUSED_NAME_TAKEN", "the same name")
	var third := _join(server, "Chloé", {"password": "secret"})
	assert_eq(third.poll()[0].get("reason"), "REFUSED_FULL")
	# Solo: anyone (Player, no password).
	var solo := GameServer.new(server.settings, null, false)
	assert_true(Msg.WELCOME in _kinds(_join(solo, "Player")))


func test_messages_cross_as_bytes() -> void:
	LocalTransport.serialize = true
	var server := _server()
	var alex := _join(server, "Alex")
	var got := alex.poll()
	LocalTransport.serialize = false
	var welcome: Dictionary = got.filter(func(m: Dictionary) -> bool: return m["t"] == Msg.WELCOME)[0]
	assert_true(welcome["spawn"] is Vector2, "values keep their types")
	var chunks := got.filter(func(m: Dictionary) -> bool: return m["t"] == Msg.CHUNK_DATA)
	assert_false(chunks.is_empty(), "chunks sent")
	var chunk := ChunkData.from_dict(chunks[0]["chunk"])
	assert_eq(chunk.voxels.size(), GameConst.CHUNK_AREA * GameConst.WORLD_HEIGHT, "whole")
	var inventory := Inventory.new()
	var sent: Array = got.filter(func(m: Dictionary) -> bool: return m["t"] == Msg.INVENTORY)
	inventory.load_dict(sent[0]["inventory"])
	assert_eq(inventory.items.size(), Inventory.SIZE)


func test_over_the_network() -> void:
	var server := _server()
	var net := NetServer.new()
	var port := 0
	for attempt in 5:
		port = 30000 + randi() % 20000
		if net.listen("127.0.0.1", port, 4) == OK:
			break
		port = 0
	assert_ne(port, 0, "listening")
	var client := NetClient.new()
	assert_eq(client.connect_to("127.0.0.1", port), OK)
	client.send(Msg.hello("Alex", 2))
	var welcomed := false
	var deadline := Time.get_ticks_msec() + 5000
	while not welcomed and Time.get_ticks_msec() < deadline:
		for transport in net.service():
			server.connect_client(transport)
		server.process_messages()
		net.flush()
		for message in client.poll():
			welcomed = welcomed or message["t"] == Msg.WELCOME
		OS.delay_msec(5)
	assert_true(welcomed, "joined over ENet")
	assert_eq(client.state, NetClient.State.CONNECTED)
	client.close()
	deadline = Time.get_ticks_msec() + 5000
	while not server.sessions.is_empty() and Time.get_ticks_msec() < deadline:
		net.service()
		server.process_messages()
		OS.delay_msec(5)
	assert_true(server.sessions.is_empty(), "gone when they leave")
	net.close()
	var lost := NetClient.new()
	lost.connect_seconds = 0.5
	lost.connect_to("127.0.0.1", port)
	deadline = Time.get_ticks_msec() + 3000
	while lost.is_open() and Time.get_ticks_msec() < deadline:
		lost.poll()
		OS.delay_msec(20)
	assert_false(lost.is_open(), "nobody listens any more")
	assert_eq(lost.ending, "CONNECTION_UNREACHABLE")


func test_the_server_settings() -> void:
	var saved := ConfigFile.new()
	saved.parse('[server]\nport=3000\nmax_players="4"\ngame_mode="creative"\nworld="../x"\n')
	var config := ServerConfig.new()
	config.take(saved, {"port": "4000", "password": "pw", "view-distance": "99"})
	assert_eq(config.port, 4000, "the options over the file")
	assert_eq(config.max_players, 4)
	assert_eq(config.game_mode, WorldSettings.GameMode.CREATIVE)
	assert_eq(config.password, "pw")
	assert_false("/" in config.world, "a folder's name only")
	assert_eq(config.view_distance, 12, "out of range: as it was")
	assert_eq(config.problems.size(), 1, "and told")
	assert_eq(ServerConfig.new().port, ServerConfig.DEFAULT_PORT)
	var template := ConfigFile.new()
	assert_eq(template.parse(ServerConfig.TEMPLATE), OK, "the file written first reads back")
	var fresh := ServerConfig.new()
	fresh.take(template, {})
	assert_true(fresh.problems.is_empty())


func test_the_console() -> void:
	var server := _server()
	var alex := _join(server, "Alex")
	alex.poll()
	var console := ServerConsole.new(server)
	var printed: Array[String] = []
	console.out = func(line: String) -> void: printed.append(line)
	console.run("say Bonjour")
	var said := alex.poll().filter(func(m: Dictionary) -> bool: return m.has("from"))
	assert_eq(said[0]["text"], "Bonjour", "to every player")
	console.run("list")
	assert_true("Alex" in printed[-1], "who plays")
	console.run("/time 18h")
	assert_almost(server.clock.time_of_day(), 18.0 * 3600.0, 1.0, "an admin's command")
	console.run("tp Alex 0 0")
	assert_true("tp" in printed[-1], "not from the console")
	assert_eq(console.run("stop"), ServerConsole.Act.STOP)
	# Alex is no admin here (the first player became one): the time is not
	# theirs to change.
	server.settings.admins.clear()
	alex.send(Msg.set_time(WorldClock.Mode.FROZEN, 6.0))
	server.process_messages()
	assert_almost(server.clock.time_of_day(), 18.0 * 3600.0, 60.0, "a player's ignored")


## Multiplayer, step 5: a server's key and certificate are made once and
## kept; nothing but an encrypted game is heard.
func test_connections_are_encrypted() -> void:
	var folder := "user://test_tls"
	_remove(folder.path_join(NetTls.FOLDER))
	var made := NetTls.server_options(folder)
	assert_true(made != null, "made")
	var key_path := folder.path_join(NetTls.FOLDER).path_join(NetTls.KEY_FILE)
	var certificate_path := folder.path_join(NetTls.FOLDER).path_join(NetTls.CERTIFICATE_FILE)
	assert_true(FileAccess.file_exists(key_path), "the key kept")
	assert_true(FileAccess.file_exists(certificate_path), "the certificate kept")
	var first := FileAccess.get_file_as_string(certificate_path)
	NetTls.server_options(folder)
	assert_eq(FileAccess.get_file_as_string(certificate_path), first, "the same the next time")
	var server := _server()
	var net := NetServer.new()
	var port := 0
	for attempt in 5:
		port = 30000 + randi() % 20000
		if net.listen("127.0.0.1", port, 4, made) == OK:
			break
		port = 0
	assert_ne(port, 0, "listening")
	# A game that does not encrypt is never heard.
	var plain := ENetConnection.new()
	plain.create_host(1, 1)
	plain.compress(ENetConnection.COMPRESS_ZSTD)
	var peer := plain.connect_to_host("127.0.0.1", port, 1)
	var said := false
	var deadline := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline:
		var event := plain.service()
		if event[0] == ENetConnection.EVENT_CONNECT and not said:
			peer.send(0, var_to_bytes(Msg.hello("Eve", 2)), ENetPacketPeer.FLAG_RELIABLE)
			said = true
		for transport in net.service():
			server.connect_client(transport)
		server.process_messages()
		net.flush()
		OS.delay_msec(10)
	assert_false(said, "no connection without encryption")
	assert_true(server.sessions.is_empty(), "nobody joined")
	plain.destroy()
	net.close()
	_remove(folder.path_join(NetTls.FOLDER))


func _remove(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)


## Commands dropped in the console's folder (leguitz-console) are run, the
## files gone; one still being written waits.
func test_commands_dropped_in_the_console_folder() -> void:
	var server := _server()
	var console := ServerConsole.new(server)
	var printed: Array[String] = []
	console.out = func(line: String) -> void: printed.append(line)
	console.folder = "user://test_console"
	DirAccess.make_dir_recursive_absolute(console.folder)
	for file in DirAccess.get_files_at(console.folder):
		DirAccess.remove_absolute(console.folder.path_join(file))
	var dropped := FileAccess.open(console.folder.path_join("1-a.txt"), FileAccess.WRITE)
	dropped.store_string("list\nsay Hello\n")
	dropped.close()
	var writing := FileAccess.open(console.folder.path_join("2-b.tmp"), FileAccess.WRITE)
	writing.store_string("stop\n")
	writing.close()
	console.poll_folder(ServerConsole.FOLDER_SECONDS)
	assert_eq(Array(console.take_lines()), ["list", "say Hello"], "in order, the file read")
	assert_false(FileAccess.file_exists(console.folder.path_join("1-a.txt")), "and gone")
	assert_true(
		FileAccess.file_exists(console.folder.path_join("2-b.tmp")), "one being written waits"
	)
	console.poll_folder(0.1)
	assert_true(console.take_lines().is_empty(), "looked into once a second")
	DirAccess.remove_absolute(console.folder.path_join("2-b.tmp"))
	DirAccess.remove_absolute(console.folder)
