extends TestCase
## Tools wear: each tier lasts its own number of blocks, the wear goes
## with the tool wherever it is moved, worn out it breaks.

const SEA := GameConst.SEA_LEVEL
const PICKAXE := Items.Id.IRON_PICKAXE


func test_each_tier_lasts_its_own_number_of_blocks() -> void:
	assert_eq(Items.durability(Items.Id.WOODEN_SHOVEL), 59)
	assert_eq(Items.durability(Items.Id.DIAMOND_AXE), 1561)
	assert_true(
		Items.durability(Items.Id.GOLDEN_PICKAXE) < Items.durability(Items.Id.WOODEN_PICKAXE),
		"gold: fast but fragile"
	)
	assert_eq(Items.durability(Items.Id.DIRT), 0, "blocks do not wear")
	assert_false(Mining.wears(Voxels.of_block(Tiles.Block.FLOWER_RED)), "flowers go at once")
	assert_true(Mining.wears(Voxels.of_block(Tiles.Block.STONE)))


func test_the_wear_goes_with_the_tool() -> void:
	var bag := Inventory.new()
	bag.add(PICKAXE, 1, 10)
	bag.add(PICKAXE, 1, 3)
	assert_eq(bag.wear[0], 10)
	assert_eq(bag.wear[1], 3)
	bag.click(0, false, false)
	assert_eq(bag.wear[Inventory.CURSOR], 10, "picked up")
	assert_eq(bag.wear[0], 0, "the slot is empty")
	bag.click(1, false, false)
	assert_eq(bag.wear[1], 10, "swapped with the other one")
	assert_eq(bag.wear[Inventory.CURSOR], 3)
	bag.click(20, false, false)
	assert_eq(bag.wear[20], 3, "put down")
	bag.click(20, false, true)
	assert_eq(bag.items[0], PICKAXE, "shift: to the hotbar")
	assert_eq(bag.wear[0], 3)
	var copy := Inventory.new()
	copy.load_dict(bag.to_dict())
	assert_eq(copy.wear[1], 10, "saved")
	bag.items[Inventory.CURSOR] = PICKAXE
	bag.counts[Inventory.CURSOR] = 1
	bag.wear[Inventory.CURSOR] = 7
	for slot in Inventory.SLOTS:
		if bag.items[slot] == Items.Id.NONE:
			bag.items[slot] = Items.Id.DIRT
			bag.counts[slot] = 1
	var left := bag.put_back_all()
	assert_eq(left, [Vector3i(PICKAXE, 1, 7)] as Array[Vector3i], "no room: thrown, worn")


func test_a_worn_out_tool_breaks() -> void:
	var bag := Inventory.new()
	bag.add(Items.Id.GOLDEN_SHOVEL, 1)
	for i in Items.durability(Items.Id.GOLDEN_SHOVEL) - 1:
		assert_false(bag.wear_out(0))
	assert_eq(bag.items[0], Items.Id.GOLDEN_SHOVEL, "one use left")
	assert_true(bag.wear_out(0), "broken")
	assert_eq(bag.items[0], Items.Id.NONE)
	assert_eq(bag.wear[0], 0)
	bag.add(Items.Id.DIRT, 5)
	assert_false(bag.wear_out(0), "dirt does not wear")
	assert_eq(bag.counts[0], 5)


func test_breaking_blocks_wears_the_tool_in_hand() -> void:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	var client: LocalTransport = transports[0]
	client.send(Msg.hello("Alex", 2))
	server.process_messages()
	client.poll()
	var session := server.first_session()
	var bag := session.inventory
	bag.add(PICKAXE, 1)
	var feet := Coords.world_to_tile(session.position)
	var row := floori(session.height + 0.01) + SEA
	var cell := Vector3i(feet.x + 2, row, feet.y)
	server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.STONE))
	client.send(Msg.block_break(cell, 0))
	server.process_messages()
	assert_eq(bag.wear[0], 1, "one block, one use")
	assert_true(client.poll().any(func(m: Dictionary) -> bool: return m["t"] == Msg.INVENTORY))
	server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.FLOWER_RED))
	client.send(Msg.block_break(cell, 0))
	server.process_messages()
	assert_eq(bag.wear[0], 1, "a flower costs nothing")
	server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.STONE))
	client.send(Msg.block_break(cell, -1))
	server.process_messages()
	assert_eq(bag.wear[0], 1, "broken by hand (the book in hand)")
	bag.wear[0] = Items.durability(PICKAXE) - 1
	server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.STONE))
	client.send(Msg.block_break(cell, 0))
	server.process_messages()
	assert_eq(bag.items[0], Items.Id.NONE, "worn out: broken")


func test_a_thrown_tool_keeps_its_wear() -> void:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	var client: LocalTransport = transports[0]
	client.send(Msg.hello("Alex", 2))
	server.process_messages()
	var bag := server.first_session().inventory
	bag.add(PICKAXE, 1, 42)
	client.send(Msg.item_drop(0, false))
	server.process_messages()
	assert_eq(bag.items[0], Items.Id.NONE, "thrown")
	var dropped: DroppedItem = server.items.values()[0]
	assert_eq(dropped.wear, 42)
	assert_eq(DroppedItem.from_dict(dropped.to_dict()).wear, 42, "saved")
	# Back at the player's feet: picked up again.
	var session := server.first_session()
	var feet := session.position / GameConst.TILE_SIZE
	dropped.position = Vector3(feet.x, session.height + 0.5, feet.y)
	dropped.pickup_delay = 0.0
	for i in 40:
		server.tick()
	assert_eq(bag.items[0], PICKAXE, "picked up again")
	assert_eq(bag.wear[0], 42, "as worn as it was")
