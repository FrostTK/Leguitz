extends TestCase


func _messages_of_type(messages: Array[Dictionary], type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for message in messages:
		if message["t"] == type:
			result.append(message)
	return result


func _new_server() -> Array:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
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
	var setup := _new_server()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	client.send(Msg.hello("Alex", 2))
	server.process_messages()
	var messages := client.poll()
	assert_eq(messages[0]["t"], Msg.WELCOME)
	assert_eq(messages[1]["t"], Msg.TIME_STATE)
	assert_eq(_messages_of_type(messages, Msg.CHUNK_DATA).size(), 25, "5x5 chunks")
	assert_eq(server.player_count(), 1)


func test_chunks_stream_and_unload_as_the_player_moves() -> void:
	var setup := _new_server()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	client.send(Msg.hello("Alex", 2))
	server.process_messages()
	var spawn: Vector2 = client.poll()[0]["spawn"]
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
	assert_true(_messages_of_type(messages, Msg.CHUNK_UNLOAD).size() > 0, "old chunks dropped")
	assert_eq(_messages_of_type(messages, Msg.PLAYER_CORRECTION).size(), 0)


func test_teleport_attempts_are_corrected() -> void:
	var setup := _new_server()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	client.send(Msg.hello("Alex", 2))
	server.process_messages()
	var spawn: Vector2 = client.poll()[0]["spawn"]
	client.send(Msg.player_move(spawn + Vector2(5000, 0), Vector2i.RIGHT))
	server.process_messages()
	var corrections := _messages_of_type(client.poll(), Msg.PLAYER_CORRECTION)
	assert_eq(corrections.size(), 1)
	assert_eq(corrections[0]["pos"], spawn)


func test_time_settings_are_applied_and_broadcast() -> void:
	var setup := _new_server()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	client.send(Msg.hello("Alex", 2))
	server.process_messages()
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
