extends TestCase
## Game modes: creative builds without using anything up, breaks without
## drops nor wear, takes from the catalog; survival and creative swap,
## hardcore stays; a hardcore player who passes out only watches (saved).

const SEA := GameConst.SEA_LEVEL
const FOLDER := "user://test_worlds/modes"


## Returns [server, client transport, session] with a joined player.
func _joined(mode := WorldSettings.GameMode.CREATIVE) -> Array:
	var settings := WorldSettings.create("Test", "42", mode)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	server.process_messages()
	return [server, transports[0], server.first_session()]


## The voxel cell `offset` tiles from the player's, on the ground surface.
func _ground_cell(
	server: GameServer, session: GameServer.PlayerSession, offset: Vector2i
) -> Vector3i:
	var tile := Coords.world_to_tile(session.position) + offset
	var top := server.world.get_or_create_chunk(Coords.tile_to_chunk(tile)).top_row(
		Coords.tile_to_local(tile)
	)
	return Vector3i(tile.x, top - 1, tile.y)


func _said(client: LocalTransport, kind: String) -> Array:
	return client.poll().filter(func(m: Dictionary) -> bool: return m["t"] == kind)


func test_joining_tells_the_mode() -> void:
	var setup := _joined(WorldSettings.GameMode.HARDCORE)
	var told := _said(setup[1], Msg.GAME_MODE)
	assert_eq(told.size(), 1)
	assert_eq(told[0]["mode"], WorldSettings.GameMode.HARDCORE)
	assert_false(told[0]["spectator"])


func test_creative_blocks_never_run_out_and_breaking_drops_nothing() -> void:
	var setup := _joined()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var session: GameServer.PlayerSession = setup[2]
	var bag := session.inventory
	bag.add(Items.Id.DIRT, 5)
	bag.items[1] = Items.Id.IRON_PICKAXE
	bag.counts[1] = 1
	var cell := _ground_cell(server, session, Vector2i(2, 0)) + Vector3i.UP
	server.world.set_voxel(cell, Voxels.AIR)
	client.send(Msg.block_place(cell, 0))
	server.process_messages()
	assert_eq(server.world.voxel_at(cell), Voxels.of_ground(Tiles.Ground.DIRT), "placed")
	assert_eq(bag.counts[0], 5, "none used")
	server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.STONE))
	client.poll()
	client.send(Msg.block_break(cell, 1))
	server.process_messages()
	assert_eq(server.world.voxel_at(cell), Voxels.AIR, "broken")
	assert_eq(_said(client, Msg.ITEM_SPAWN).size(), 0, "nothing drops")
	assert_true(server.items.is_empty())
	assert_eq(bag.wear[1], 0, "the pickaxe did not wear")


func test_the_catalog_gives_any_item_in_creative_only() -> void:
	var bag := Inventory.new()
	GameModes.take_from_catalog(bag, Items.Id.STONE, false, false)
	assert_eq([bag.items[Inventory.CURSOR], bag.counts[Inventory.CURSOR]], [Items.Id.STONE, 64])
	bag.take(Inventory.CURSOR, 60)
	GameModes.take_from_catalog(bag, Items.Id.STONE, true, false)
	assert_eq(bag.counts[Inventory.CURSOR], 5, "right: one more")
	GameModes.take_from_catalog(bag, Items.Id.STONE, false, false)
	assert_eq(bag.counts[Inventory.CURSOR], 64, "left: a full stack")
	GameModes.take_from_catalog(bag, Items.Id.DIAMOND, false, false)
	assert_eq(bag.items[Inventory.CURSOR], Items.Id.NONE, "something else: thrown away")
	GameModes.take_from_catalog(bag, Items.Id.DIAMOND, true, false)
	assert_eq([bag.items[Inventory.CURSOR], bag.counts[Inventory.CURSOR]], [Items.Id.DIAMOND, 1])
	GameModes.take_from_catalog(bag, Items.Id.IRON_AXE, false, true)
	assert_eq([bag.items[0], bag.counts[0]], [Items.Id.IRON_AXE, 1], "shift: into the slots")
	GameModes.take_from_catalog(bag, Items.Id.GUIDE_BOOK, false, true)
	assert_eq(bag.items[1], Items.Id.NONE, "never the book")
	var shown := CreativeCatalog.order()
	assert_eq(shown.size(), Items.Id.size() - 2, "every item but the book")
	assert_eq(shown[0], Items.Id.DIRT, "blocks first")
	assert_true(Armor.is_armor(shown[-1]), "armor last")
	assert_true(shown.find(Items.Id.DIAMOND_SWORD) < shown.find(Items.Id.BOW), "after the tools")
	# Through the server: in creative only.
	var setup := _joined()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var session: GameServer.PlayerSession = setup[2]
	client.send(Msg.catalog_click(Items.Id.GLASS, false, true))
	server.process_messages()
	assert_eq(session.inventory.items[0], Items.Id.GLASS)
	server.settings.game_mode = WorldSettings.GameMode.SURVIVAL
	client.send(Msg.catalog_click(Items.Id.BRICKS, false, true))
	server.process_messages()
	assert_eq(session.inventory.items[1], Items.Id.NONE, "not in survival")


func test_survival_and_creative_swap_and_hardcore_stays() -> void:
	var setup := _joined(WorldSettings.GameMode.SURVIVAL)
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var session: GameServer.PlayerSession = setup[2]
	session.health = 7
	session.food = 3
	client.poll()
	client.send(Msg.set_game_mode(WorldSettings.GameMode.CREATIVE))
	server.process_messages()
	assert_eq(server.settings.game_mode, WorldSettings.GameMode.CREATIVE)
	assert_eq([session.health, session.food], [Vitals.MAX_HEALTH, Vitals.MAX_FOOD], "well again")
	var said := client.poll()
	assert_true(said.any(func(m: Dictionary) -> bool: return m["t"] == Msg.VITALS))
	var told := said.filter(func(m: Dictionary) -> bool: return m["t"] == Msg.GAME_MODE)
	assert_eq(told[0]["mode"], WorldSettings.GameMode.CREATIVE, "every player is told")
	client.send(Msg.set_game_mode(WorldSettings.GameMode.HARDCORE))
	server.process_messages()
	assert_eq(server.settings.game_mode, WorldSettings.GameMode.CREATIVE, "never into hardcore")
	client.send(Msg.set_game_mode(WorldSettings.GameMode.SURVIVAL))
	server.process_messages()
	assert_eq(server.settings.game_mode, WorldSettings.GameMode.SURVIVAL)
	var hardcore := _joined(WorldSettings.GameMode.HARDCORE)
	hardcore[1].send(Msg.set_game_mode(WorldSettings.GameMode.CREATIVE))
	hardcore[0].process_messages()
	assert_eq(hardcore[0].settings.game_mode, WorldSettings.GameMode.HARDCORE, "stays hardcore")


func test_a_hardcore_player_who_passes_out_only_watches_from_then_on() -> void:
	var storage := WorldStorage.new(FOLDER)
	storage.erase()
	var setup := _joined(WorldSettings.GameMode.HARDCORE)
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var session: GameServer.PlayerSession = setup[2]
	server.use_storage(storage, {})
	session.inventory.add(Items.Id.DIAMOND, 2)
	client.poll()
	server.hurt(session, Vitals.MAX_HEALTH, Vitals.Cause.FALL)
	assert_true(session.spectator, "their one life is over")
	var told := _said(client, Msg.GAME_MODE)
	assert_eq(told.size(), 1)
	assert_true(told[0]["spectator"])
	assert_eq(server.items.size(), 1, "what they carried fell")
	client.send(Msg.respawn())
	server.process_messages()
	assert_eq(session.health, 0, "they do not get up")
	# They fly around (no fall hurts them), pick nothing up, change nothing.
	var away := session.position + Vector2(40.0, 0.0)
	client.send(Msg.player_move(away, Vector2i.RIGHT, session.height + 20.0, 25.0))
	server.process_messages()
	assert_eq(session.position, away, "watching from anywhere")
	var cell := _ground_cell(server, session, Vector2i(1, 0))
	var there := server.world.voxel_at(cell)
	client.send(Msg.block_break(cell))
	server.process_messages()
	assert_eq(server.world.voxel_at(cell), there)
	assert_true(server.save())
	var again := GameServer.new(server.settings, null, false)
	again.use_storage(WorldStorage.new(FOLDER), storage.read_world())
	var pair := LocalTransport.create_pair()
	again.connect_client(pair[1])
	pair[0].send(Msg.hello("Alex", 2))
	again.process_messages()
	var back := again.first_session()
	assert_true(back.spectator, "saved")
	assert_eq(back.health, 0)
	assert_eq(back.position, away, "where they watched from")
	var said: Array = pair[0].poll().filter(
		func(m: Dictionary) -> bool: return m["t"] == Msg.GAME_MODE
	)
	assert_true(said[0]["spectator"], "told when they come back")
	storage.erase()


func test_flying_rises_sinks_bumps_and_lands() -> void:
	var floor_top := 2
	var ceiling := 9
	var voxel_at := func(cell: Vector3i) -> int:
		var level := cell.y - SEA
		if level < floor_top or level == ceiling:
			return Voxels.of_block(Tiles.Block.STONE)
		if cell.x == 3 and level < ceiling:
			return Voxels.of_block(Tiles.Block.STONE)
		return Voxels.AIR
	var body := PlayerBody.new()
	body.place(Vector2(8.0, 8.0), floor_top)
	body.step(Vector2.ZERO, false, 0.05, voxel_at)
	body.flying = true
	for i in 20:
		body.fly(Vector2.ZERO, true, false, 0.05, voxel_at)
	assert_true(body.height > floor_top + 3.0, "rises: %.2f" % body.height)
	for i in 40:
		body.fly(Vector2.ZERO, true, false, 0.05, voxel_at)
	assert_almost(body.height, ceiling - PlayerBody.BODY_HEIGHT, 0.01, "bumps the ceiling")
	for i in 20:
		body.fly(Vector2(4.0, 0.0), false, false, 0.05, voxel_at)
	assert_true(body.feet.x < 3 * GameConst.TILE_SIZE, "walls stop it")
	var hovering := body.height
	for i in 10:
		body.fly(Vector2.ZERO, false, false, 0.05, voxel_at)
	assert_almost(body.height, hovering, 0.01, "no gravity")
	for i in 60:
		body.fly(Vector2.ZERO, false, true, 0.05, voxel_at)
	assert_false(body.flying, "landed")
	assert_true(body.on_ground)
	assert_almost(body.height, floor_top, 0.001)
	assert_eq(body.take_fall(), 0.0, "a flight is no fall")
	# A ghost goes through everything.
	var ghost := PlayerBody.new()
	ghost.place(Vector2(8.0, 8.0), floor_top)
	for i in 20:
		ghost.fly(Vector2(4.0, 0.0), false, true, 0.05, voxel_at, true)
	assert_true(ghost.feet.x > 3 * GameConst.TILE_SIZE, "through the wall")
	assert_true(ghost.height < floor_top - 2.0, "into the ground")
