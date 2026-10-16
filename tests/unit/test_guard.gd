extends TestCase
## Multiplayer, step 3: a dedicated server trusts nobody. Messages that
## make no sense or come in floods are dropped (a flood gets the player
## kicked); moves too fast, through walls, too high or hanging in the air
## are put back, numbered (older moves dropped); falls are measured by the
## server; breaking takes its time; a seat holds one player, a bed one
## sleeper. A solo game trusts its client.

const SEA := GameConst.SEA_LEVEL
const TILE := GameConst.TILE_SIZE


## A dedicated server (not saved), nobody on it, its console listened to.
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
	transports[0].poll()
	return transports[0]


## A flat floor of stone around the player (13 x 13 tiles), air over it;
## the player stands in its middle. Returns the floor's row.
func _arena(server: GameServer, session: GameServer.PlayerSession) -> int:
	var tile := Coords.world_to_tile(session.position)
	var row := floori(session.height + 0.01) + SEA - 1
	var stone := Voxels.of_block(Tiles.Block.STONE)
	for dz in range(-6, 7):
		for dx in range(-6, 7):
			server.world.set_voxel(Vector3i(tile.x + dx, row, tile.y + dz), stone)
			for up in range(1, 9):
				server.world.set_voxel(Vector3i(tile.x + dx, row + up, tile.y + dz), Voxels.AIR)
	session.position = Coords.tile_to_world_center(tile)
	session.height = row + 1 - SEA
	return row


## The player says they are at `pos`, `height`, `later` seconds after the
## last move (the guard's clock moves on).
func _move(
	server: GameServer,
	client: LocalTransport,
	session: GameServer.PlayerSession,
	pos: Vector2,
	height: float,
	later := 0.05,
	fell := 0.0
) -> void:
	server.time_shift += later
	var seq := session.guard.move.seq
	client.send(Msg.player_move(pos, Vector2i.DOWN, height, fell, 0.0, 0, 0, seq))
	server.process_messages()


func _of(messages: Array, kind: String) -> Array:
	return messages.filter(func(m: Dictionary) -> bool: return m["t"] == kind)


func test_messages_that_make_no_sense() -> void:
	var server := _server()
	var alex := _join(server, "Alex")
	var session := Chat.find_player(server, "Alex")
	var console := LocalTransport.create_pair()
	server.console = console[1]
	var chunks := server.world.chunks.size()
	var far := Vector3i(100000, SEA, 0)
	alex.send(Msg.block_break(far, 0))
	alex.send({"t": Msg.BLOCK_BREAK, "cell": "here", "slot": 0})
	alex.send({"t": Msg.PLAYER_MOVE, "pos": Vector2(NAN, 0.0), "h": 0.0, "seq": 0})
	alex.send({"t": Msg.SELECT_SLOT, "slot": [1]})
	server.process_messages()
	assert_eq(server.world.chunks.size(), chunks, "no chunk made far away")
	assert_true(session.position.is_finite(), "no NaN position")
	assert_eq(session.inventory.selected, 0)
	var told := console[0].poll()
	assert_eq(told.size(), 1, "told once")
	assert_eq(told[0]["key"], "GUARD_MALFORMED")
	assert_eq(told[0]["args"][0], "Alex")


func test_floods() -> void:
	var server := _server()
	var alex := _join(server, "Alex")
	var bea := _join(server, "Bea")
	bea.poll()
	for i in 10:
		bea.send(Msg.chat("hello %d" % i))
	server.process_messages()
	var lines := _of(alex.poll(), Msg.CHAT_LINE).filter(
		func(m: Dictionary) -> bool: return m.has("from")
	)
	assert_eq(lines.size(), roundi(Guard.LIMITS[Msg.CHAT][1]), "a few lines at once")
	var slow := _of(bea.poll(), Msg.CHAT_LINE)
	assert_true(slow.any(func(m: Dictionary) -> bool: return m.get("key") == "CHAT_TOO_FAST"))
	var session := Chat.find_player(server, "Bea")
	for i in roundi(Guard.BURST) + Guard.KICK_DROPS + 10:
		bea.send(Msg.select_slot(1))
	server.process_messages()
	assert_eq(_of(bea.poll(), Msg.KICKED).size(), 1, "kicked")
	assert_eq(Chat.find_player(server, "Bea"), null, "gone")
	assert_false(session.joined)
	assert_eq(Lobby.players(server), 1)


func test_moves_too_fast_are_put_back() -> void:
	var server := _server()
	var alex := _join(server, "Alex")
	var session := Chat.find_player(server, "Alex")
	_arena(server, session)
	var start := session.position
	var height := session.height
	_move(server, alex, session, start, height)
	assert_eq(session.guard.move.seq, 0)
	# Walking at a run: taken.
	var run := PlayerBody.WALK_SPEED * PlayerBody.SPRINT_MULTIPLIER * 0.05
	for i in 20:
		var at := start + Vector2(run * ((i % 10) - 5), 0.0)
		_move(server, alex, session, at, height)
	assert_eq(session.guard.move.seq, 0, "never put back")
	alex.poll()
	# Twice as fast, for long: put back.
	var pos := session.position
	for i in 40:
		pos.x += run * 2.0 * (1.0 if i < 20 else -1.0)
		_move(server, alex, session, pos, height)
	var corrections := _of(alex.poll(), Msg.PLAYER_CORRECTION)
	assert_false(corrections.is_empty(), "put back")
	assert_eq(corrections[0]["seq"], 1, "numbered")
	# A correction gives no burst back.
	var there := session.position
	_move(server, alex, session, there + Vector2(TILE * 3, 0), height)
	assert_eq(session.position, there, "still too fast")
	# A move sent before the correction is dropped; after it, taken.
	alex.send(Msg.player_move(there + Vector2(4, 0), Vector2i.DOWN, height, 0.0, 0.0, 0, 0, 0))
	server.process_messages()
	assert_eq(session.position, there, "an older move")
	_move(server, alex, session, there + Vector2(4, 0), height, 0.5)
	assert_eq(session.position, there + Vector2(4, 0), "answering it")


func test_walls_heights_and_hovering() -> void:
	var server := _server()
	var alex := _join(server, "Alex")
	var session := Chat.find_player(server, "Alex")
	var row := _arena(server, session)
	var tile := Coords.world_to_tile(session.position)
	for up in [1, 2]:
		server.world.set_voxel(
			Vector3i(tile.x + 1, row + up, tile.y), Voxels.of_block(Tiles.Block.STONE)
		)
	var start := session.position
	var height := session.height
	_move(server, alex, session, start, height)
	_move(server, alex, session, start + Vector2(TILE * 1.5, 0), height)
	assert_eq(session.position, start, "not through the wall")
	_move(server, alex, session, start, height + 3.0, 0.5)
	assert_eq(session.height, height, "not three levels up: on the ground")
	# A jump goes up and comes down.
	_move(server, alex, session, start, height + 1.0, 0.5)
	_move(server, alex, session, start, height + 1.2)
	assert_almost(session.height, height + 1.2, 0.001, "a jump")
	_move(server, alex, session, start, height, 0.3)
	alex.poll()
	# Hanging in the air.
	_move(server, alex, session, start, height + 1.0, 0.5)
	_move(server, alex, session, start, height + 1.0, 1.2)
	assert_eq(session.height, height, "put down")
	assert_false(_of(alex.poll(), Msg.PLAYER_CORRECTION).is_empty())


func test_falls_are_measured() -> void:
	var server := _server()
	var alex := _join(server, "Alex")
	var session := Chat.find_player(server, "Alex")
	var row := _arena(server, session)
	var tile := Coords.world_to_tile(session.position)
	# A pit six levels deep east of the player.
	for down in range(0, 6):
		server.world.set_voxel(Vector3i(tile.x + 1, row - down, tile.y), Voxels.AIR)
	var start := session.position
	var height := session.height
	_move(server, alex, session, start, height)
	var over := start + Vector2(TILE, 0)
	_move(server, alex, session, over, height)
	var t := 0.0
	while t < 0.6:
		t += 0.05
		var fallen := minf(16.0 * t * t, 6.0)
		_move(server, alex, session, over, height - fallen)
	# The client says nothing of the fall: it still hurts.
	_move(server, alex, session, over, height - 6.0)
	assert_eq(session.health, Vitals.MAX_HEALTH - Vitals.fall_damage(6.0), "six levels")
	# The same landing told later is not counted twice.
	_move(server, alex, session, over, height - 6.0, 0.05, 6.0)
	assert_eq(session.health, Vitals.MAX_HEALTH - Vitals.fall_damage(6.0))


func test_breaking_takes_its_time() -> void:
	var server := _server()
	var alex := _join(server, "Alex")
	var session := Chat.find_player(server, "Alex")
	var row := _arena(server, session)
	var tile := Coords.world_to_tile(session.position)
	var cell := Vector3i(tile.x + 1, row + 1, tile.y)
	var stone := Voxels.of_block(Tiles.Block.STONE)
	server.world.set_voxel(cell, stone)
	alex.send(Msg.block_break(cell, 0))
	server.process_messages()
	assert_eq(server.world.voxel_at(cell), stone, "not at once")
	assert_eq(_of(alex.poll(), Msg.BLOCK_CHANGED)[-1]["voxel"], stone, "the client told")
	alex.send(Msg.dig(cell))
	server.process_messages()
	server.time_shift += Mining.break_seconds(stone, Items.Id.NONE) * 0.5
	alex.send(Msg.block_break(cell, 0))
	server.process_messages()
	assert_eq(server.world.voxel_at(cell), stone, "not halfway")
	alex.send(Msg.dig(cell))
	server.process_messages()
	server.time_shift += Mining.break_seconds(stone, Items.Id.NONE)
	alex.send(Msg.block_break(cell, 0))
	server.process_messages()
	assert_eq(server.world.voxel_at(cell), Voxels.AIR, "once it took its time")
	# Small plants break at once.
	var flower := Voxels.of_block(Tiles.Block.FLOWER_RED)
	server.world.set_voxel(cell, flower)
	alex.send(Msg.block_break(cell, 0))
	server.process_messages()
	assert_eq(server.world.voxel_at(cell), Voxels.AIR, "a flower")


func test_one_seat_one_sitter() -> void:
	var server := _server()
	var alex := _join(server, "Alex")
	var bea := _join(server, "Bea")
	var a := Chat.find_player(server, "Alex")
	var b := Chat.find_player(server, "Bea")
	var row := _arena(server, a)
	b.position = a.position
	b.height = a.height
	var tile := Coords.world_to_tile(a.position)
	var cell := Vector3i(tile.x + 1, row + 1, tile.y)
	server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.CHAIR))
	alex.send(Msg.sit(cell))
	server.process_messages()
	assert_eq(a.sits_on, cell, "sat down")
	assert_true(Peers.state(a)["pose"] & Peers.Pose.SEATED != 0, "the others see it")
	bea.poll()
	bea.send(Msg.sit(cell))
	server.process_messages()
	var got := bea.poll()
	assert_eq(_of(got, Msg.STAND_UP).size(), 1, "taken: up again")
	assert_eq(_of(got, Msg.NOTICE)[0]["key"], "HUD_SEAT_TAKEN")
	assert_eq(b.sits_on, GameServer.NO_CELL)
	alex.send(Msg.stand())
	server.process_messages()
	assert_eq(a.sits_on, GameServer.NO_CELL, "free again")
	bea.send(Msg.sit(cell))
	server.process_messages()
	assert_eq(b.sits_on, cell)
	server.world.set_voxel(cell, Voxels.AIR)
	server.tick()
	assert_eq(b.sits_on, GameServer.NO_CELL, "the seat gone")


func test_a_solo_game_trusts_its_client() -> void:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var client := _join(server, "Player")
	var session := server.first_session()
	var far := session.position + Vector2(GameServer.MAX_MOVE_PER_UPDATE - 1.0, 0.0)
	client.send(Msg.player_move(far, Vector2i.DOWN, session.height + 1.5))
	server.process_messages()
	assert_eq(session.position, far, "taken")
	for i in roundi(Guard.BURST) + Guard.KICK_DROPS + 10:
		client.send(Msg.select_slot(1))
	server.process_messages()
	assert_true(session.joined, "never kicked")
