extends TestCase


func _messages_of_type(messages: Array[Dictionary], type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for message in messages:
		if message["t"] == type:
			result.append(message)
	return result


## Returns [server, client_transport] with a joined player (view distance 2).
func _joined_server() -> Array:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	server.process_messages()
	return [server, transports[0]]


func test_local_transport_keeps_order_and_sides() -> void:
	var transports := LocalTransport.create_pair()
	transports[0].send({"t": "a"})
	transports[0].send({"t": "b"})
	transports[1].send({"t": "c"})
	var received := transports[1].poll()
	assert_eq(received.size(), 2)
	assert_eq(received[0]["t"], "a")
	assert_eq(received[1]["t"], "b")
	assert_eq(transports[1].poll().size(), 0, "poll clears the inbox")
	assert_eq(transports[0].poll()[0]["t"], "c")


func test_hello_sends_welcome_time_and_the_initial_view() -> void:
	var setup := _joined_server()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var messages := client.poll()
	assert_eq(messages[0]["t"], Msg.WELCOME)
	assert_eq(messages[0]["layer"], 0)
	assert_eq(messages[1]["t"], Msg.TIME_STATE)
	server.tick()
	messages.append_array(client.poll())
	var chunks := _messages_of_type(messages, Msg.CHUNK_DATA)
	assert_eq(chunks.size(), 25, "5x5 chunks")
	assert_eq(server.player_count(), 1)


func test_chunks_stream_and_unload_as_the_player_moves() -> void:
	var setup := _joined_server()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var spawn: Vector2 = client.poll()[0]["spawn"]
	server.tick()
	client.poll()
	# Walk 3 chunks east in steps the server accepts.
	var target := spawn + Vector2(GameConst.CHUNK_PIXELS * 3, 0)
	var position := spawn
	while position.x < target.x:
		position.x = minf(position.x + 64.0, target.x)
		client.send(Msg.player_move(position, Vector2i.RIGHT))
		server.process_messages()
	for i in 10:
		server.tick()
	var messages := client.poll()
	assert_true(_messages_of_type(messages, Msg.CHUNK_DATA).size() > 0, "new chunks sent")
	var unloads := _messages_of_type(messages, Msg.CHUNK_UNLOAD)
	assert_true(unloads.size() > 0, "old chunks dropped")
	assert_true(unloads[0]["key"] is Vector3i)
	assert_eq(_messages_of_type(messages, Msg.PLAYER_CORRECTION).size(), 0)


func test_teleport_attempts_are_corrected() -> void:
	var setup := _joined_server()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var spawn: Vector2 = client.poll()[0]["spawn"]
	client.send(Msg.player_move(spawn + Vector2(5000, 0), Vector2i.RIGHT))
	server.process_messages()
	var corrections := _messages_of_type(client.poll(), Msg.PLAYER_CORRECTION)
	assert_eq(corrections.size(), 1)
	assert_eq(corrections[0]["pos"], spawn)


func test_time_settings_are_applied_and_broadcast() -> void:
	var setup := _joined_server()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	client.poll()
	client.send(Msg.set_time(WorldClock.Mode.NORMAL, 60.0))
	server.process_messages()
	assert_almost(server.clock.day_minutes, 60.0)
	var states := _messages_of_type(client.poll(), Msg.TIME_STATE)
	assert_eq(states.size(), 1)
	var mirror := WorldClock.new()
	mirror.load_dict(states[0]["clock"])
	assert_almost(mirror.day_minutes, 60.0)
	client.send(Msg.set_time(WorldClock.Mode.FROZEN, WorldClock.FROZEN_MIDNIGHT))
	server.process_messages()
	assert_eq(server.clock.mode, WorldClock.Mode.FROZEN)
	assert_almost(server.clock.time_of_day(), 0.0)


func test_changing_layer_teleports_to_an_open_tile() -> void:
	var setup := _joined_server()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	server.tick()
	client.poll()
	client.send(Msg.debug_change_layer(-2))
	server.process_messages()
	server.tick()
	var messages := client.poll()
	var teleports := _messages_of_type(messages, Msg.PLAYER_TELEPORT)
	assert_eq(teleports.size(), 1)
	assert_eq(teleports[0]["layer"], -2)
	var tile := Coords.world_to_tile(teleports[0]["pos"])
	assert_false(server.world.is_solid(tile, -2), "lands in a cave, not in rock")
	assert_eq(_messages_of_type(messages, Msg.CHUNK_UNLOAD).size(), 25, "surface unloaded")
	for chunk in _messages_of_type(messages, Msg.CHUNK_DATA):
		assert_eq(chunk["chunk"]["layer"], -2)
	client.send(Msg.debug_change_layer(-10))
	server.process_messages()
	assert_eq(server.first_session().layer, WorldGenerator.MIN_LAYER, "clamped")


func test_map_request_returns_an_image() -> void:
	var setup := _joined_server()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	client.poll()
	client.send(Msg.map_request(Vector2i.ZERO, 0, 64, 4))
	server.process_messages()
	var maps := _messages_of_type(client.poll(), Msg.MAP_DATA)
	assert_eq(maps.size(), 1)
	var image := Image.new()
	assert_eq(image.load_png_from_buffer(maps[0]["png"]), OK)
	assert_eq(image.get_size(), Vector2i(64, 64))


func test_debug_commands_can_be_disabled() -> void:
	var setup := _joined_server()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	client.poll()
	server.allow_debug_commands = false
	client.send(Msg.debug_change_layer(-1))
	client.send(Msg.map_request(Vector2i.ZERO, 0, 64, 4))
	server.process_messages()
	assert_eq(client.poll().size(), 0)
	assert_eq(server.first_session().layer, 0)
