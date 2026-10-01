extends TestCase
## Chests: placed facing the player, opened with a right click, their 27
## slots kept by the server and saved with their chunk, spilled when broken.

const SEA := GameConst.SEA_LEVEL
const FOLDER := "user://test_worlds/chests"
const N := Items.Id.NONE


func test_a_chest_is_placed_facing_the_player_and_opens() -> void:
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var voxel_at := func(cell: Vector3i) -> int: return stone if cell.y < SEA else Voxels.AIR
	var chest := Items.placed_voxel(Items.Id.CHEST)
	assert_true(Mining.can_place(chest))
	var at := Vector3i(0, SEA, 0)
	var east := Mining.placement(at, chest, Vector2i(1, 0), voxel_at)
	assert_eq(east, {at: Voxels.of_block(Tiles.Block.CHEST_EAST)}, "one cell, facing east")
	assert_true(Mining.placement(at + Vector3i.UP, chest, Vector2i(1, 0), voxel_at).is_empty())
	assert_true(Mining.opens(east[at]), "a right click opens it")
	assert_eq(ObjectShapes.model_block(Tiles.Block.CHEST_NORTH), Tiles.Block.CHEST)
	var made := (
		Recipes
		. result_of(
			PackedInt32Array(
				[
					Items.Id.OAK_PLANKS,
					Items.Id.OAK_PLANKS,
					Items.Id.BIRCH_PLANKS,
					Items.Id.OAK_PLANKS,
					N,
					Items.Id.OAK_PLANKS,
					Items.Id.OAK_PLANKS,
					Items.Id.OAK_PLANKS,
					Items.Id.OAK_PLANKS,
				]
			),
			3
		)
	)
	assert_eq(made, Vector2i(Items.Id.CHEST, 1), "eight planks around an empty middle")


func test_clicks_move_stacks_between_the_chest_and_the_bag() -> void:
	var bag := Inventory.new()
	var chest := Inventory.new()
	bag.add(Items.Id.DIRT, 20)
	bag.add(Items.Id.IRON_PICKAXE, 1, 9)
	bag.click(0, false, false)
	bag.click_chest(chest, 4, false, false)
	assert_eq(chest.items[4], Items.Id.DIRT, "put in the chest")
	assert_eq(chest.counts[4], 20)
	bag.click(1, false, true, chest)
	assert_eq(chest.items[0], Items.Id.IRON_PICKAXE, "shift: into the chest")
	assert_eq(chest.wear[0], 9, "as worn")
	bag.click_chest(chest, 4, true, false)
	assert_eq(bag.counts[Inventory.CURSOR], 10, "a right click takes half")
	bag.click_chest(chest, 0, false, true)
	assert_eq(bag.items[0], Items.Id.IRON_PICKAXE, "shift: back into the bag")
	assert_eq(chest.items[0], N)
	var copy := Inventory.new()
	copy.load_dict(chest.contents(Inventory.CHEST))
	assert_eq(copy.counts[4], 10, "its contents travel")


func test_the_server_keeps_saves_and_spills_a_chest() -> void:
	var storage := WorldStorage.new(FOLDER)
	storage.erase()
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	server.use_storage(storage, {})
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	var client: LocalTransport = transports[0]
	client.send(Msg.hello("Alex", 2))
	server.process_messages()
	client.poll()
	var session := server.first_session()
	session.inventory.add(Items.Id.DIAMOND, 5)
	var feet := Coords.world_to_tile(session.position)
	var row := floori(session.height + 0.01) + SEA
	var cell := Vector3i(feet.x + 2, row, feet.y)
	server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.CHEST))
	client.send(Msg.open_chest(cell))
	server.process_messages()
	var said := client.poll().filter(func(m: Dictionary) -> bool: return m["t"] == Msg.CHEST)
	assert_eq(said.size(), 1, "what it holds is sent")
	client.send(Msg.slot_click(0, false, false))
	client.send(Msg.chest_click(13, false, false))
	server.process_messages()
	assert_eq(server.world.chest_at(cell).items[13], Items.Id.DIAMOND, "stored")
	assert_eq(session.inventory.items[0], N)
	client.send(Msg.inventory_close())
	server.process_messages()
	client.send(Msg.chest_click(13, false, false))
	server.process_messages()
	assert_eq(session.inventory.items[Inventory.CURSOR], N, "closed: no more clicks")
	assert_true(server.save())
	var saved := storage.read_world()
	var again := GameServer.new(settings, null, false)
	again.use_storage(WorldStorage.new(FOLDER), saved)
	var kept := again.world.chest_at(cell)
	assert_eq(kept.items[13], Items.Id.DIAMOND, "saved with its chunk")
	assert_eq(kept.counts[13], 5)
	client.send(Msg.block_break(cell))
	server.process_messages()
	var spilled := server.items.values().map(func(d: DroppedItem) -> int: return d.item)
	assert_true(Items.Id.DIAMOND in spilled, "broken: its diamonds spill")
	assert_true(Items.Id.CHEST in spilled, "and it gives itself back")
	assert_eq(server.world.chest_at(cell).items[13], N, "a new chest there would be empty")
	storage.erase()
