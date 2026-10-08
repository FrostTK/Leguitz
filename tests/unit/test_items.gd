extends TestCase
## Items: what blocks give, the inventory, items lying around.

const SEA := GameConst.SEA_LEVEL
const FOLDER := "user://test_worlds/items"


func test_every_block_gives_something_with_a_name() -> void:
	var names := _translated_keys()
	var rng := RandomNumberGenerator.new()
	var voxels: Array[int] = []
	for ground: int in Tiles.Ground.values():
		voxels.append(Voxels.of_ground(ground))
	for block: int in Tiles.Block.values():
		if block != Tiles.Block.AIR:
			voxels.append(Voxels.of_block(block))
	for voxel in voxels:
		if not Mining.can_break(voxel, SEA):
			continue
		var drops := Items.drops(voxel, Vector2i(3, 4), rng)
		assert_false(drops.is_empty(), "voxel %d gives something" % voxel)
		for drop in drops:
			assert_true(Items.is_valid(drop.x), "voxel %d gives a real item" % voxel)
			assert_true(drop.y > 0)
	for item in range(1, Items.Id.size()):
		assert_true(names.has(Items.name_key(item)), "%s has a name" % Items.name_key(item))
	var grass := Items.drops(Voxels.of_ground(Tiles.Ground.GRASS), Vector2i.ZERO, rng)
	assert_eq(grass[0].x, Items.Id.DIRT, "grass gives dirt")
	var oak := Items.drops(Voxels.of_block(Tiles.Block.OAK), Vector2i(3, 4), rng)
	assert_eq(oak[0].x, Items.Id.OAK_LOG, "a tree gives logs")
	assert_true(oak[0].y >= 3, "one per level of trunk")


func test_block_items_place_their_block() -> void:
	assert_eq(Items.placed_voxel(Items.Id.DIRT), Voxels.of_ground(Tiles.Ground.DIRT))
	assert_eq(Items.placed_voxel(Items.Id.STONE), Voxels.of_block(Tiles.Block.STONE))
	assert_eq(Items.placed_voxel(Items.Id.DIAMOND), Voxels.AIR, "not a block")
	for item in range(1, Items.Id.size()):
		var voxel := Items.placed_voxel(item)
		if voxel != Voxels.AIR:
			assert_true(Mining.can_place(voxel), "%s places a block" % Items.name_key(item))


func test_items_stack_up_to_a_full_stack() -> void:
	var bag := Inventory.new()
	assert_eq(bag.add(Items.Id.DIRT, 70), 0)
	assert_eq(bag.items[0], Items.Id.DIRT)
	assert_eq(bag.counts[0], Items.MAX_STACK, "a full stack in the first slot")
	assert_eq(bag.counts[1], 70 - Items.MAX_STACK, "the rest in the next")
	bag.add(Items.Id.SAND, 1)
	bag.add(Items.Id.DIRT, 3)
	assert_eq(bag.counts[1], 70 - Items.MAX_STACK + 3, "onto the dirt, not a new slot")
	assert_eq(bag.items[2], Items.Id.SAND)
	assert_eq(bag.take(0, 100), Items.MAX_STACK)
	assert_eq(bag.items[0], Items.Id.NONE, "an empty slot")
	var full := Inventory.new()
	assert_eq(full.add(Items.Id.STONE, Inventory.SLOTS * Items.MAX_STACK + 5), 5, "5 do not fit")
	assert_eq(full.room_for(Items.Id.STONE), 0)


func test_tools_do_not_stack() -> void:
	assert_eq(Items.max_stack(Items.Id.IRON_PICKAXE), 1)
	var bag := Inventory.new()
	assert_eq(bag.add(Items.Id.IRON_PICKAXE, 2), 0)
	assert_eq(bag.items[1], Items.Id.IRON_PICKAXE, "one per slot")
	assert_eq(bag.counts[0], 1)
	bag.click(0, false, false)
	bag.click(1, false, false)
	assert_eq(bag.counts[1], 1, "not two in a slot")
	assert_eq(bag.items[Inventory.CURSOR], Items.Id.IRON_PICKAXE, "swapped instead")
	for tier in Items.Tier.size():
		var tools := Items.tools_of_tier(tier)
		assert_eq(tools.size(), 5, "a pickaxe, an axe, a shovel, a sword and a hoe")
		assert_eq(Items.tool_of(tools[0]), Items.Tool.PICKAXE)
		assert_eq(Items.tool_of(tools[1]), Items.Tool.AXE)
		assert_eq(Items.tool_of(tools[2]), Items.Tool.SHOVEL)
		assert_eq(Items.tool_of(tools[3]), Items.Tool.SWORD)
		assert_eq(Items.tier_of(tools[2]), tier)
	assert_eq(Items.tool_of(Items.Id.STICK), Items.Tool.NONE)
	assert_eq(Items.placed_voxel(Items.Id.GOLDEN_AXE), Voxels.AIR, "tools are not placed")


func test_every_item_has_a_model_and_tools_a_handle() -> void:
	for item in range(1, Items.Id.size()):
		if Items.placed_voxel(item) == Voxels.AIR:
			var grid := ItemModels.build(item)
			assert_true(grid != null and not grid.is_empty(), "%s looks" % Items.name_key(item))
	for item: int in Items.TOOLS.keys() + [Items.Id.BOW]:
		var name := Items.name_key(item)
		var model := ToolModels.held(item)
		assert_false(model.is_empty(), "%s in hand" % name)
		var grip := ToolModels.grip(item) * 16.0
		var cell := Vector3i(Vector3(model.pivot.x, grip.y, model.pivot.y).floor())
		assert_ne(model.get_voxel(cell), 0, "%s held by its grip" % name)
	for stage in ToolModels.DRAW_STAGES:
		assert_false(ToolModels.held(Items.Id.BOW, stage).is_empty(), "the bow drawn")
	var hand := Vector3(0.1, -0.4, 0.2)
	var grip := ToolModels.grip(Items.Id.DIAMOND_PICKAXE)
	var held := ItemLibrary.in_hand(Vector3(0, 0.3, 1), Vector3.DOWN, grip, 0.5, hand)
	assert_true((held * grip).is_equal_approx(hand), "the grip in the hand")
	var handle := held.basis.y.normalized()
	assert_true(handle.z > 0.9 and handle.y > 0.2, "the handle forward, lifted a little")


func test_clicks_move_stacks_like_minecraft() -> void:
	var bag := Inventory.new()
	bag.add(Items.Id.DIRT, 10)
	bag.click(0, false, false)
	assert_eq(bag.items[Inventory.CURSOR], Items.Id.DIRT, "picked up")
	assert_eq(bag.counts[Inventory.CURSOR], 10)
	assert_eq(bag.items[0], Items.Id.NONE)
	bag.click(5, true, false)
	assert_eq(bag.counts[5], 1, "a right click puts one down")
	bag.click(12, false, false)
	assert_eq(bag.counts[12], 9, "a left click puts the rest down")
	assert_eq(bag.items[Inventory.CURSOR], Items.Id.NONE)
	bag.click(12, true, false)
	assert_eq(bag.counts[Inventory.CURSOR], 5, "a right click picks up half")
	assert_eq(bag.counts[12], 4)
	bag.click(5, false, false)
	assert_eq(bag.counts[5], 6, "added onto the same item")
	bag.add(Items.Id.SAND, 2)
	var sand := bag.items.find(Items.Id.SAND)
	bag.click(sand, false, false)
	bag.click(5, false, false)
	assert_eq(bag.items[5], Items.Id.SAND, "swapped")
	assert_eq(bag.items[Inventory.CURSOR], Items.Id.DIRT)
	assert_true(bag.put_back_all().is_empty(), "back in the slots")
	assert_eq(bag.items[Inventory.CURSOR], Items.Id.NONE)
	# Shift moves a stack between the hotbar and the bag.
	bag.click(5, false, true)
	assert_eq(bag.items[5], Items.Id.NONE)
	assert_eq(bag.items[Inventory.HOTBAR], Items.Id.SAND, "into the bag's first free slot")


func test_an_inventory_survives_saving() -> void:
	var bag := Inventory.new()
	bag.add(Items.Id.RUBY, 3)
	bag.selected = 4
	var copy := Inventory.new()
	copy.load_dict(bag.to_dict())
	assert_eq(copy.items, bag.items)
	assert_eq(copy.counts, bag.counts)
	assert_eq(copy.selected, 4)
	var bad := Inventory.new()
	bad.load_dict(
		{"items": PackedInt32Array([999, Items.Id.DIRT]), "counts": PackedInt32Array([5, 0])}
	)
	assert_eq(bad.items[0], Items.Id.NONE, "unknown items are dropped")
	assert_eq(bad.items[1], Items.Id.NONE, "empty stacks too")


func test_items_fall_rest_and_float() -> void:
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var water := Voxels.of_ground(Tiles.Ground.WATER)
	var ground := func(cell: Vector3i) -> int: return stone if cell.y < SEA else Voxels.AIR
	var dropped := DroppedItem.create(Items.Id.DIRT, 1, Vector3(0.5, 3.0, 0.5), Vector3.ZERO)
	for i in 60:
		dropped.step(0.05, ground)
	assert_true(dropped.resting, "on the ground")
	assert_almost(dropped.position.y, DroppedItem.RADIUS, 0.01)
	var pond := func(cell: Vector3i) -> int:
		if cell.y < SEA - 3:
			return stone
		return water if cell.y < SEA else Voxels.AIR
	var floating := DroppedItem.create(Items.Id.DIRT, 1, Vector3(0.5, -2.5, 0.5), Vector3.ZERO)
	for i in 120:
		floating.step(0.05, pond)
	assert_almost(floating.position.y, -ChunkData.WATER_DROP, 0.01, "floats up to the surface")


## Returns [server, client transport, session] with a joined player.
func _joined(storage: WorldStorage = null) -> Array:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	if storage != null:
		server.use_storage(storage, {})
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	server.process_messages()
	transports[0].poll()
	return [server, transports[0], server.first_session()]


func test_broken_blocks_drop_items_players_pick_up() -> void:
	var setup := _joined()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var session: GameServer.PlayerSession = setup[2]
	var tile := Coords.world_to_tile(session.position) + Vector2i(1, 0)
	var top := server.world.get_or_create_chunk(Coords.tile_to_chunk(tile)).top_row(
		Coords.tile_to_local(tile)
	)
	var cell := Vector3i(tile.x, top - 1, tile.y)
	var voxel := server.world.voxel_at(cell)
	var expected := Items.drops(voxel, tile, RandomNumberGenerator.new())[0].x
	client.send(Msg.block_break(cell))
	server.process_messages()
	assert_eq(server.items.size(), 1, "it lies where the block was")
	var said := client.poll().filter(func(m: Dictionary) -> bool: return m["t"] == Msg.ITEM_SPAWN)
	assert_eq(said[0]["item"], expected)
	for i in 40:
		server.tick()
	assert_true(server.items.is_empty(), "picked up")
	assert_eq(session.inventory.items[0], expected, "now in the hotbar")
	said = client.poll()
	assert_true(
		said.any(
			func(m: Dictionary) -> bool: return m["t"] == Msg.ITEM_REMOVE and m["by"] == session.id
		)
	)
	assert_true(said.any(func(m: Dictionary) -> bool: return m["t"] == Msg.INVENTORY))


func test_the_debug_key_gives_tools_in_creative() -> void:
	var setup := _joined()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var session: GameServer.PlayerSession = setup[2]
	client.send(Msg.debug_give_tools(Items.Tier.IRON))
	server.process_messages()
	assert_eq(session.inventory.items[0], Items.Id.NONE, "not in survival")
	server.settings.game_mode = WorldSettings.GameMode.CREATIVE
	client.send(Msg.debug_give_tools(Items.Tier.IRON))
	server.process_messages()
	assert_eq(session.inventory.items[0], Items.Id.IRON_PICKAXE)
	assert_eq(session.inventory.items[1], Items.Id.IRON_AXE)
	assert_eq(session.inventory.items[2], Items.Id.IRON_SHOVEL)
	assert_eq(session.inventory.items[3], Items.Id.IRON_SWORD)
	assert_eq(session.inventory.items[4], Items.Id.IRON_HOE)
	assert_true(client.poll().any(func(m: Dictionary) -> bool: return m["t"] == Msg.INVENTORY))
	server.allow_debug_commands = false
	client.send(Msg.debug_give_tools(Items.Tier.GOLD))
	server.process_messages()
	assert_eq(session.inventory.items[5], Items.Id.NONE, "only with debug commands")


func test_thrown_items_are_not_picked_up_at_once() -> void:
	var setup := _joined()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var session: GameServer.PlayerSession = setup[2]
	session.inventory.add(Items.Id.DIAMOND, 3)
	client.send(Msg.item_drop(0, false))
	server.process_messages()
	assert_eq(session.inventory.counts[0], 2, "one thrown")
	assert_eq(server.items.size(), 1)
	server.tick()
	assert_eq(server.items.size(), 1, "not picked up right away")
	client.send(Msg.item_drop(0, true))
	server.process_messages()
	assert_eq(session.inventory.items[0], Items.Id.NONE, "the whole stack thrown")


func test_inventory_and_lying_items_are_saved() -> void:
	var storage := WorldStorage.new(FOLDER)
	storage.erase()
	var setup := _joined(storage)
	var server: GameServer = setup[0]
	var session: GameServer.PlayerSession = setup[2]
	session.inventory.add(Items.Id.EMERALD, 7)
	server.spawn_item(Items.Id.COAL, 4, Vector3(100.5, 1.15, 100.5), Vector3.ZERO)
	assert_true(server.save())
	var saved := storage.read_world()
	var settings := WorldSettings.new()
	settings.load_dict(saved["settings"])
	var again := GameServer.new(settings, null, false)
	again.use_storage(WorldStorage.new(FOLDER), saved)
	assert_eq(again.items.size(), 1, "the coal still lies there")
	assert_eq(again.items.values()[0].count, 4)
	var transports := LocalTransport.create_pair()
	again.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	again.process_messages()
	var inventory := again.first_session().inventory
	assert_eq(inventory.items[0], Items.Id.EMERALD, "the inventory came back")
	assert_eq(inventory.counts[0], 7)
	storage.erase()


static func _translated_keys() -> Dictionary:
	var keys := {}
	var file := FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() >= 3 and not line[1].is_empty() and not line[2].is_empty():
			keys[line[0]] = true
	return keys


func test_a_left_drag_shares_a_stack_evenly() -> void:
	var own := func(slot: int) -> Vector2i: return Vector2i(Inventory.Holder.OWN, slot)
	var bag := Inventory.new()
	bag.add(Items.Id.STONE, 64)
	bag.items[20] = Items.Id.SAND
	bag.counts[20] = 5
	bag.items[21] = Items.Id.STONE
	bag.counts[21] = 60
	bag.click(0, false, false)
	var before := bag.snapshot()
	bag.spread([own.call(10), own.call(20), own.call(11), own.call(10), own.call(21)])
	assert_eq(bag.counts[10], 21, "64 between three slots: 21 each")
	assert_eq(bag.counts[11], 21)
	assert_eq(bag.counts[21], 64, "as much as fits")
	assert_eq(bag.counts[20], 5, "sand does not take stones")
	assert_eq(bag.counts[Inventory.CURSOR], 18, "the rest stays in hand")
	bag.restore(before)
	assert_eq(bag.counts[Inventory.CURSOR], 64, "back as it was")
	assert_eq(bag.items[10], Items.Id.NONE)
	# More slots crossed than items: one each, as far as they go.
	bag.take(Inventory.CURSOR, 62)
	bag.spread([own.call(1), own.call(2), own.call(3), own.call(4)])
	assert_eq([bag.counts[1], bag.counts[2], bag.counts[3]], [1, 1, 0])
	assert_eq(bag.items[Inventory.CURSOR], Items.Id.NONE)


func test_a_left_drag_reaches_chests_furnaces_and_the_grid() -> void:
	var bag := Inventory.new()
	var chest := Inventory.new()
	var furnace := Furnace.new(Tiles.Block.FACTORY_FURNACE)
	bag.add(Items.Id.COAL, 10)
	bag.click(0, false, false)
	var targets := [
		Vector2i(Inventory.Holder.CHEST, 4),
		Vector2i(Inventory.Holder.FURNACE, Furnace.LANES),
		Vector2i(Inventory.Holder.FURNACE, Furnace.FUELS),
		Vector2i(Inventory.Holder.FURNACE, Furnace.COOKED),
		Vector2i(Inventory.Holder.OWN, Inventory.CRAFT + 6),
		Vector2i(Inventory.Holder.OWN, Inventory.CURSOR),
	]
	bag.spread(targets, chest, furnace)
	assert_eq(chest.counts[4], 3, "the chest")
	assert_eq(furnace.slots.counts[Furnace.FUELS], 3, "coal burns")
	assert_eq(furnace.slots.items[Furnace.LANES], Items.Id.NONE, "but does not cook")
	assert_eq(furnace.slots.items[Furnace.COOKED], Items.Id.NONE, "what it made only gives")
	assert_eq(bag.counts[Inventory.CRAFT + 6], 3, "the crafting grid")
	assert_eq(bag.counts[Inventory.CURSOR], 1)
	bag.spread(targets)
	assert_eq(bag.counts[Inventory.CURSOR], 0, "no chest open: its own slots only")
	assert_eq(bag.counts[Inventory.CRAFT + 6], 4)


func test_the_server_shares_a_stack_like_the_client() -> void:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	var client: LocalTransport = transports[0]
	client.send(Msg.hello("Alex", 2))
	server.process_messages()
	var session := server.first_session()
	session.inventory.add(Items.Id.DIRT, 9)
	client.send(Msg.slot_click(0, false, false))
	var targets := [Vector2i(Inventory.Holder.OWN, 3), Vector2i(Inventory.Holder.OWN, 4)]
	client.send(Msg.slot_spread(targets))
	client.send(Msg.slot_spread(["nonsense", 7]))
	server.process_messages()
	assert_eq(session.inventory.counts[3], 4)
	assert_eq(session.inventory.counts[4], 4)
	assert_eq(session.inventory.counts[Inventory.CURSOR], 1)


func test_a_double_click_gathers_the_same_items() -> void:
	var bag := Inventory.new()
	var chest := Inventory.new()
	bag.add(Items.Id.STONE, 10)
	bag.items[Inventory.CRAFT + 1] = Items.Id.STONE
	bag.counts[Inventory.CRAFT + 1] = 3
	bag.items[Inventory.CRAFT + 6] = Items.Id.STONE
	bag.counts[Inventory.CRAFT + 6] = 3
	bag.items[Inventory.CRAFT + 7] = Items.Id.COAL
	bag.counts[Inventory.CRAFT + 7] = 33
	bag.items[20] = Items.Id.STONE
	bag.counts[20] = 64
	chest.items[4] = Items.Id.STONE
	chest.counts[4] = 5
	bag.click(0, false, false)
	bag.collect(chest)
	assert_eq(bag.counts[Inventory.CURSOR], 64, "10 + 3 + 3 + 5, topped up from the full stack")
	assert_eq(bag.items[Inventory.CRAFT + 1], Items.Id.NONE, "the grid gave its stones")
	assert_eq(chest.items[4], Items.Id.NONE, "so did the chest")
	assert_eq(bag.counts[Inventory.CRAFT + 7], 33, "coal stays")
	assert_eq(bag.counts[20], 64 - 43, "the full stack last, only what was missing")
	var tools := Inventory.new()
	tools.add(Items.Id.IRON_AXE, 1)
	tools.add(Items.Id.IRON_AXE, 1)
	tools.click(0, false, false)
	tools.collect()
	assert_eq(tools.counts[Inventory.CURSOR], 1, "tools do not stack")
