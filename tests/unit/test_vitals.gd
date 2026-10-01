extends TestCase
## Vitality: falls (water breaks them), lava, passing out (what the player
## carried falls where they are), getting up at the spawn, healing, saves.

const SEA := GameConst.SEA_LEVEL
const FOLDER := "user://test_worlds/vitals"


func _server(mode := WorldSettings.GameMode.SURVIVAL) -> Array:
	var settings := WorldSettings.create("Test", "42", mode)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	var client: LocalTransport = transports[0]
	client.send(Msg.hello("Alex", 2))
	server.process_messages()
	client.poll()
	return [server, client, server.first_session()]


## The voxel under a player's feet becomes `ground`.
func _under(server: GameServer, session: GameServer.PlayerSession, ground: int) -> void:
	var tile := Coords.world_to_tile(session.position)
	var row := floori(session.height + 0.01) + SEA - 1
	server.world.set_voxel(Vector3i(tile.x, row, tile.y), Voxels.of_ground(ground))


func _fall(client: LocalTransport, session: GameServer.PlayerSession, levels: float) -> void:
	client.send(Msg.player_move(session.position, session.facing, session.height, levels))


func _ticks(server: GameServer, seconds: float) -> void:
	for i in roundi(seconds * GameConst.TICKS_PER_SECOND):
		server.tick()


func _said(client: LocalTransport, kind: String) -> Array:
	return client.poll().filter(func(m: Dictionary) -> bool: return m["t"] == kind)


func test_falls_hurt_unless_into_water() -> void:
	var made := _server()
	var server: GameServer = made[0]
	var client: LocalTransport = made[1]
	var session: GameServer.PlayerSession = made[2]
	assert_eq(session.health, Vitals.MAX_HEALTH)
	_fall(client, session, 3.0)
	server.process_messages()
	assert_eq(session.health, Vitals.MAX_HEALTH, "three levels: nothing")
	_fall(client, session, 5.2)
	server.process_messages()
	assert_eq(session.health, Vitals.MAX_HEALTH - 2, "five: two points")
	var told := _said(client, Msg.HEALTH)
	assert_eq(told.size(), 1)
	assert_true(told[0]["hurt"])
	assert_eq(told[0]["cause"], Vitals.Cause.FALL)
	_ticks(server, 0.5)
	_under(server, session, Tiles.Ground.WATER)
	_fall(client, session, 12.0)
	server.process_messages()
	assert_eq(session.health, Vitals.MAX_HEALTH - 2, "into water: nothing")
	var creative := _server(WorldSettings.GameMode.CREATIVE)
	_fall(creative[1], creative[2], 30.0)
	creative[0].process_messages()
	assert_eq(creative[2].health, Vitals.MAX_HEALTH, "creative players are never hurt")


func test_lava_burns_until_the_player_passes_out_and_gets_up() -> void:
	var made := _server()
	var server: GameServer = made[0]
	var client: LocalTransport = made[1]
	var session: GameServer.PlayerSession = made[2]
	session.inventory.add(Items.Id.DIAMOND, 3)
	session.inventory.add(Items.Id.IRON_PICKAXE, 1, 40)
	var spot := session.position
	_under(server, session, Tiles.Ground.LAVA)
	_ticks(server, 2.0)
	assert_true(session.health <= Vitals.MAX_HEALTH - 6, "burnt: %d" % session.health)
	assert_true(session.health >= Vitals.MAX_HEALTH - 10)
	_ticks(server, 5.0)
	assert_eq(session.health, 0, "passed out")
	assert_false(session.alive())
	var died := _said(client, Msg.DIED)
	assert_eq(died.size(), 1)
	assert_eq(died[0]["cause"], Vitals.Cause.LAVA)
	var lying := server.items.values().map(func(d: DroppedItem) -> int: return d.item)
	assert_true(Items.Id.DIAMOND in lying, "what they carried lies there")
	assert_true(Items.Id.IRON_PICKAXE in lying)
	assert_eq(session.inventory.items[0], Items.Id.NONE, "nothing left on them")
	_ticks(server, 1.0)
	lying = server.items.values().map(func(d: DroppedItem) -> int: return d.item)
	assert_true(Items.Id.DIAMOND in lying, "nobody passed out picks things up")
	client.send(Msg.player_move(spot + Vector2(5, 0), session.facing, session.height))
	server.process_messages()
	assert_eq(session.position, spot, "nor moves")
	client.send(Msg.respawn())
	server.process_messages()
	assert_eq(session.health, Vitals.MAX_HEALTH, "up again, fully well")
	assert_eq(Coords.world_to_tile(session.position), server.spawn_tile, "at the spawn")
	var said := client.poll().map(func(m: Dictionary) -> String: return m["t"])
	assert_true(Msg.PLAYER_TELEPORT in said)
	assert_true(Msg.HEALTH in said)


func test_vitality_comes_back_and_is_saved() -> void:
	var storage := WorldStorage.new(FOLDER)
	storage.erase()
	var made := _server()
	var server: GameServer = made[0]
	var session: GameServer.PlayerSession = made[2]
	server.use_storage(storage, {})
	session.health = 10
	_ticks(server, Vitals.REGEN_SECONDS * 2.0 + 0.2)
	assert_eq(session.health, 12, "a point every few seconds")
	server.hurt(session, 1, Vitals.Cause.FALL)
	_ticks(server, Vitals.REGEN_DELAY - 1.0)
	assert_eq(session.health, 11, "not right after a hurt")
	_ticks(server, Vitals.REGEN_SECONDS + 1.2)
	assert_eq(session.health, 12)
	assert_true(server.save())
	var again := GameServer.new(server.settings, null, false)
	again.use_storage(WorldStorage.new(FOLDER), storage.read_world())
	var transports := LocalTransport.create_pair()
	again.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	again.process_messages()
	assert_eq(again.first_session().health, 12, "saved")
	again.first_session().health = 0
	assert_true(again.save())
	var third := GameServer.new(server.settings, null, false)
	third.use_storage(WorldStorage.new(FOLDER), storage.read_world())
	var pair := LocalTransport.create_pair()
	third.connect_client(pair[1])
	pair[0].send(Msg.hello("Alex", 2))
	third.process_messages()
	var back := third.first_session()
	assert_eq(back.health, Vitals.MAX_HEALTH, "left while passed out: up at the spawn")
	assert_eq(Coords.world_to_tile(back.position), third.spawn_tile)
	storage.erase()
