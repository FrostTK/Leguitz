extends TestCase
## Multiplayer, step 2: players seeing each other (Peers: who comes into
## view, their moves and looks relayed, who goes), the roster, a player
## back from the same machine taking over, the bodies' poses, gliding
## between moves, the servers joined lately and the join screen's address.


## A dedicated server (not saved), nobody on it.
func _server() -> GameServer:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	server.dedicated = true
	server.creatures.living.clear()
	return server


func _join(server: GameServer, name: String) -> LocalTransport:
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	transports[0].send(Msg.hello(name, 2))
	server.process_messages()
	return transports[0]


## The messages of kind `kind` among `messages`.
func _of(messages: Array, kind: String) -> Array:
	return messages.filter(func(m: Dictionary) -> bool: return m["t"] == kind)


func test_players_see_each_other() -> void:
	var server := _server()
	var alex := _join(server, "Alex")
	var bea := _join(server, "Bea")
	var bea_session := Chat.find_player(server, "Bea")
	server.tick()
	var got := alex.poll()
	var peers := _of(got, Msg.PEER)
	assert_eq(peers.size(), 1, "Bea comes into Alex's view")
	assert_eq(peers[0]["name"], "Bea")
	assert_eq(peers[0]["id"], bea_session.id)
	assert_eq(peers[0]["pos"], bea_session.position)
	assert_eq(peers[0]["tick"], server.tick_count, "stamped with the tick")
	assert_eq(peers[0]["armor"].size(), Armor.PIECES)
	assert_eq(_of(bea.poll(), Msg.PEER).size(), 1, "and Alex into Bea's")
	server.tick()
	assert_true(_of(alex.poll(), Msg.PEER_MOVE).is_empty(), "nothing changed, nothing sent")
	var walked := bea_session.position + Vector2(8.0, 0.0)
	var pose := PlayerModel.Pose.SWING | PlayerModel.Pose.AIR
	bea.send(Msg.player_move(walked, Vector2i.RIGHT, bea_session.height, 0.0, 1.5, pose, 3))
	server.process_messages()
	server.tick()
	var moves := _of(alex.poll(), Msg.PEER_MOVE)
	assert_eq(moves.size(), 1)
	assert_eq(moves[0]["pos"], walked)
	assert_almost(moves[0]["yaw"], 1.5)
	assert_eq(moves[0]["pose"], pose)
	assert_eq(moves[0]["swings"], 3)
	assert_false(moves[0].has("armor"), "only what changed")
	bea_session.inventory.items[0] = Items.Id.TORCH
	bea_session.inventory.counts[0] = 1
	bea_session.inventory.selected = 0
	server.tick()
	moves = _of(alex.poll(), Msg.PEER_MOVE)
	assert_eq(moves[0].get("held"), Items.Id.TORCH, "what they hold")
	bea.close()
	server.process_messages()
	server.tick()
	var gone := _of(alex.poll(), Msg.PEER_GONE)
	assert_eq(gone.size(), 1, "gone when they leave")
	assert_eq(gone[0]["id"], bea_session.id)


func test_who_is_not_seen() -> void:
	var server := _server()
	var alex := _join(server, "Alex")
	var bea := _join(server, "Bea")
	var bea_session := Chat.find_player(server, "Bea")
	server.tick()
	alex.poll()
	# Far away, out of the chunks Alex has.
	bea_session.position += Vector2(GameConst.CHUNK_SIZE * GameConst.TILE_SIZE * 40.0, 0.0)
	server.tick()
	assert_eq(_of(alex.poll(), Msg.PEER_GONE).size(), 1, "out of view")
	bea_session.position = Chat.find_player(server, "Alex").position
	server.tick()
	assert_eq(_of(alex.poll(), Msg.PEER).size(), 1, "back in view")
	bea.poll()
	bea_session.spectator = true
	server.tick()
	assert_eq(_of(alex.poll(), Msg.PEER_GONE).size(), 1, "a spectator is seen by nobody")
	assert_true(_of(bea.poll(), Msg.PEER_GONE).is_empty(), "but sees")
	# What is no number is ignored.
	bea.send({"t": Msg.PLAYER_MOVE, "pos": bea_session.position, "yaw": "x", "pose": [1]})
	bea.send({"t": Msg.PLAYER_MOVE, "pos": bea_session.position, "yaw": NAN, "pose": 1 << 20})
	server.process_messages()
	assert_true(is_finite(bea_session.yaw))
	assert_eq(bea_session.pose, 0, "kept to the pose's bits")


func test_the_roster() -> void:
	var server := _server()
	var alex := _join(server, "Alex")
	var bea := _join(server, "Bea")
	var rosters := _of(alex.poll(), Msg.PLAYERS)
	assert_eq(rosters.size(), 2, "told when each comes")
	var players: Array = rosters[-1]["players"]
	assert_eq(players.map(func(p: Dictionary) -> String: return p["name"]), ["Alex", "Bea"])
	assert_true(players[0]["admin"], "the first one there is an admin")
	assert_false(players[1]["admin"])
	assert_eq(players[0]["ping"], 0, "no network here")
	bea.close()
	server.process_messages()
	rosters = _of(alex.poll(), Msg.PLAYERS)
	assert_eq(rosters[-1]["players"].size(), 1, "and when one goes")


func test_back_from_the_same_machine() -> void:
	var server := _server()
	var net := NetServer.new()
	var port := 0
	for attempt in 5:
		port = 30000 + randi() % 20000
		if net.listen("127.0.0.1", port, 4) == OK:
			break
		port = 0
	assert_ne(port, 0, "listening")
	var first := NetClient.new()
	first.connect_to("127.0.0.1", port)
	first.send(Msg.hello("Alex", 2))
	assert_true(_welcomed(server, net, first), "joined")
	# Their game stopped short; they join again before the server noticed.
	var second := NetClient.new()
	second.connect_to("127.0.0.1", port)
	second.send(Msg.hello("alex", 2))
	assert_true(_welcomed(server, net, second), "back: their old connection gives way")
	assert_eq(Lobby.players(server), 1, "one Alex")
	second.close()
	first.close()
	net.close()


## Services both ends until `client` is welcomed (or a few seconds).
func _welcomed(server: GameServer, net: NetServer, client: NetClient) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		for transport in net.service():
			server.connect_client(transport)
		server.process_messages()
		net.flush()
		for message in client.poll():
			if message["t"] == Msg.WELCOME:
				return true
		OS.delay_msec(5)
	return false


func test_a_body_tells_its_pose() -> void:
	var body := PlayerModel.new()
	body.swimming = true
	body.swinging = true
	body.aiming = 0.6
	body.draw = 1.0
	body.seated = true
	body.set_down(1.0)
	var bits := body.pose(true)
	for flag in [
		PlayerModel.Pose.SWIM,
		PlayerModel.Pose.AIR,
		PlayerModel.Pose.SWING,
		PlayerModel.Pose.AIM,
		PlayerModel.Pose.SEATED,
		PlayerModel.Pose.DOWN,
	]:
		assert_true(bits & flag != 0, str(flag))
	assert_false(bits & PlayerModel.Pose.EAT != 0)
	var other := PlayerModel.new()
	other.take_pose(bits)
	assert_true(other.swimming and other.swinging and other.seated)
	assert_false(other.eating)
	assert_almost(other.draw, 1.0, 0.01, "the bow's draw")
	body.swing()
	body.swing()
	assert_eq(body.swings, 2, "strokes counted")
	body.free()
	other.free()


func test_gliding_between_moves() -> void:
	var moves: Array[Array] = [
		[10, Vector2(0, 0), 0.0, 0.0],
		[11, Vector2(16, 0), 1.0, PI * 0.5],
		[13, Vector2(16, 32), 1.0, PI * 0.5],
	]
	assert_eq(PeersView.sample(moves, 5.0)[0], Vector2(0, 0), "before them all: the first")
	var halfway := PeersView.sample(moves, 10.5)
	assert_eq(halfway[0], Vector2(8, 0))
	assert_almost(halfway[1], 0.5)
	assert_almost(halfway[2], PI * 0.25)
	assert_eq(PeersView.sample(moves, 12.0)[0], Vector2(16, 16), "between ticks apart")
	assert_eq(PeersView.sample(moves, 20.0)[0], Vector2(16, 32), "after them all: the last")


func test_servers_joined_lately() -> void:
	var list := ServerList.new()
	list.path = "user://test_servers.cfg"
	list.servers.clear()
	for i in ServerList.MOST + 2:
		list.remember("10.0.0.%d" % i, 27420, "Alex")
	list.remember("play.example.org", 27500, "Bea")
	list.remember("10.0.0.9", 27420, "Alex")
	var again := ServerList.new()
	again.path = list.path
	again.load_list()
	assert_eq(again.servers.size(), ServerList.MOST, "at most MOST")
	assert_eq(again.servers[0]["address"], "10.0.0.9", "the last joined first, once")
	assert_eq(again.servers[1]["port"], 27500)
	assert_eq(again.last_name(), "Alex")
	again.forget("10.0.0.9", 27420)
	list.load_list()
	assert_eq(list.servers[0]["address"], "play.example.org")
	DirAccess.remove_absolute(list.path)


func test_the_join_screen_reads_addresses() -> void:
	assert_eq(JoinScreen.parse("play.example.org", 27420), ["play.example.org", 27420])
	assert_eq(JoinScreen.parse(" 51.75.12.3:27500 ", 27420), ["51.75.12.3", 27500])
	assert_eq(JoinScreen.parse("host:port", 27420), [], "no port")
	assert_eq(JoinScreen.parse("", 27420), [])
	assert_eq(JoinScreen.parse("my server", 27420), [])
	assert_eq(JoinScreen.parse("host", 70000), [])
	assert_true(Lobby.is_name("Béa_2") and not Lobby.is_name("a b"))
