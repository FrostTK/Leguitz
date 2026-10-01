extends TestCase
## Crafting: recipes, the inventory's grid, the server's word.

const N := Items.Id.NONE
const LOG := Items.Id.OAK_LOG
const OAK := Items.Id.OAK_PLANKS
const BIRCH := Items.Id.BIRCH_PLANKS


func test_logs_make_planks_and_planks_make_sticks_and_a_workbench() -> void:
	assert_eq(Recipes.result_of(PackedInt32Array([N, N, N, N, N, N, N, N, N]), 3), Vector2i.ZERO)
	var planks := Recipes.result_of(PackedInt32Array([N, N, N, N, N, N, N, N, LOG]), 3)
	assert_eq(planks, Vector2i(OAK, 4), "a log, anywhere: 4 planks of its wood")
	var spruce := PackedInt32Array([Items.Id.SPRUCE_LOG, N, N, N, N, N, N, N, N])
	assert_eq(Recipes.result_of(spruce, 3).x, Items.Id.SPRUCE_PLANKS)
	var sticks := Recipes.result_of(PackedInt32Array([N, OAK, N, N, BIRCH, N, N, N, N]), 3)
	assert_eq(sticks, Vector2i(Items.Id.STICK, 4), "two planks of any wood, one on the other")
	var lying := Recipes.result_of(PackedInt32Array([OAK, OAK, N, N, N, N, N, N, N]), 3)
	assert_eq(lying, Vector2i.ZERO, "side by side they make nothing")
	var square := PackedInt32Array([N, N, N, N, OAK, BIRCH, N, BIRCH, OAK])
	assert_eq(Recipes.result_of(square, 3), Vector2i(Items.Id.WORKBENCH, 1), "four planks")
	square[0] = Items.Id.DIRT
	assert_eq(Recipes.result_of(square, 3), Vector2i.ZERO, "nothing else in the grid")
	var wide := PackedInt32Array()
	wide.resize(25)
	wide.fill(N)
	wide[24] = LOG
	assert_eq(Recipes.result_of(wide, 5), Vector2i(OAK, 4), "a workbench's grid makes them too")
	for recipe in Recipes.all():
		assert_true(Items.is_valid(recipe["result"][0]), "a recipe makes a real item")


func test_crafting_uses_one_of_each_ingredient() -> void:
	var bag := Inventory.new()
	var cell := Inventory.CRAFT + 1 * Inventory.GRID + 2
	bag.items[cell] = LOG
	bag.counts[cell] = 3
	assert_eq(bag.craft_result(Inventory.OWN_GRID), Vector2i(OAK, 4))
	bag.craft(Inventory.OWN_GRID, false)
	assert_eq(bag.items[Inventory.CURSOR], OAK, "taken in the cursor")
	assert_eq(bag.counts[Inventory.CURSOR], 4)
	assert_eq(bag.counts[cell], 2, "one log used")
	bag.craft(Inventory.OWN_GRID, false)
	assert_eq(bag.counts[Inventory.CURSOR], 8, "onto the same planks")
	bag.craft(Inventory.OWN_GRID, true)
	assert_eq(bag.items[cell], N, "shift: as many as possible")
	assert_eq(bag.items[0], OAK, "straight into the slots")
	assert_eq(bag.counts[0], 4)
	bag.items[cell] = LOG
	bag.counts[cell] = 1
	bag.items[Inventory.CURSOR] = Items.Id.DIRT
	bag.counts[Inventory.CURSOR] = 1
	bag.craft(Inventory.OWN_GRID, false)
	assert_eq(bag.counts[cell], 1, "not with something else in the cursor")
	var outside := Inventory.CRAFT + 4
	bag.items[outside] = LOG
	bag.counts[outside] = 1
	assert_eq(bag.craft_result(Inventory.OWN_GRID).x, OAK, "past the inventory's 3 x 3: unseen")
	var left := bag.put_back_all()
	assert_true(left.is_empty(), "everything goes back")
	assert_eq(bag.items[cell], N)
	assert_eq(bag.items[outside], N)
	assert_eq(bag.items[Inventory.CURSOR], N)


func test_the_grid_is_clicked_like_slots_and_saved() -> void:
	var bag := Inventory.new()
	bag.add(LOG, 5)
	var cell := Inventory.CRAFT
	bag.click(0, false, false)
	bag.click(cell, true, false)
	assert_eq(bag.counts[cell], 1, "a right click puts one log in the grid")
	bag.click(cell, false, false)
	assert_eq(bag.counts[cell], 5, "a left click the rest")
	bag.click(cell, false, true)
	assert_eq(bag.items[cell], N, "shift sends it back to the slots")
	assert_eq(bag.counts[0], 5)
	bag.click(0, false, false)
	bag.click(cell, false, false)
	var copy := Inventory.new()
	copy.load_dict(bag.to_dict())
	assert_eq(copy.items[cell], LOG, "what lies in the grid is saved")


func test_the_server_crafts_and_gives_the_grid_back() -> void:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	var client: LocalTransport = transports[0]
	client.send(Msg.hello("Alex", 2))
	server.process_messages()
	client.poll()
	var bag := server.first_session().inventory
	bag.items[Inventory.CRAFT] = LOG
	bag.counts[Inventory.CRAFT] = 2
	client.send(Msg.craft(false))
	server.process_messages()
	assert_eq(bag.items[Inventory.CURSOR], OAK, "crafted")
	assert_eq(bag.counts[Inventory.CRAFT], 1)
	assert_true(client.poll().any(func(m: Dictionary) -> bool: return m["t"] == Msg.INVENTORY))
	client.send(Msg.inventory_close())
	server.process_messages()
	assert_eq(bag.items[Inventory.CRAFT], N, "the grid goes back")
	assert_eq(bag.items[Inventory.CURSOR], N)
	assert_eq(bag.items[0], OAK)
	assert_eq(bag.items[1], LOG)


func test_planks_and_the_workbench_are_wooden_blocks() -> void:
	for item: int in Recipes.PLANKS + [Items.Id.WORKBENCH]:
		var voxel := Items.placed_voxel(item)
		assert_true(Voxels.is_cube(voxel), "%s is a block" % Items.name_key(item))
		assert_eq(Mining.tool_for(voxel), Items.Tool.AXE, "an axe for wood")
		var drops := Items.drops(voxel, Vector2i.ZERO, RandomNumberGenerator.new())
		assert_eq(drops[0], Vector2i(item, 1), "it gives itself back")
