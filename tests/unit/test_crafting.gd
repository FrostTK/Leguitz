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


func test_planks_and_the_workbench_are_wooden() -> void:
	for item: int in Recipes.PLANKS + [Items.Id.WORKBENCH]:
		var voxel := Items.placed_voxel(item)
		assert_true(Mining.can_place(voxel), "%s is placed" % Items.name_key(item))
		assert_eq(Mining.tool_for(voxel), Items.Tool.AXE, "an axe for wood")
		var drops := Items.drops(voxel, Vector2i.ZERO, RandomNumberGenerator.new())
		assert_eq(drops[0], Vector2i(item, 1), "it gives itself back")
	for item: int in Recipes.PLANKS:
		assert_true(Voxels.is_cube(Items.placed_voxel(item)), "planks are blocks")
	assert_true(Voxels.is_object(Items.placed_voxel(Items.Id.WORKBENCH)), "the bench is a model")


func test_the_workbench_stands_on_two_tiles_facing_the_player() -> void:
	var sea := GameConst.SEA_LEVEL
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var cells := {}
	var voxel_at := func(cell: Vector3i) -> int:
		return cells.get(cell, stone if cell.y < sea else Voxels.AIR)
	var bench := Items.placed_voxel(Items.Id.WORKBENCH)
	var at := Vector3i(0, sea, 0)
	var south := Mining.front_towards(at, Vector2(8, 80))
	assert_eq(south, Vector2i(0, 1), "it faces the player")
	var placed := Mining.placement(at, bench, south, voxel_at)
	var left := Voxels.of_block(Tiles.Block.WORKBENCH)
	var end_x := Voxels.of_block(Tiles.Block.WORKBENCH_END_X)
	assert_eq(placed, {at: left, at + Vector3i(1, 0, 0): end_x}, "its right end on the east")
	var east := Mining.front_towards(at, Vector2(80, 8))
	placed = Mining.placement(at, bench, east, voxel_at)
	var end_z := Voxels.of_block(Tiles.Block.WORKBENCH_END_Z)
	var facing_east := Voxels.of_block(Tiles.Block.WORKBENCH_EAST)
	assert_eq(placed, {at: facing_east, at + Vector3i(0, 0, -1): end_z}, "turned")
	cells[at + Vector3i(1, 0, 0)] = stone
	placed = Mining.placement(at, bench, south, voxel_at)
	assert_eq(placed, {at - Vector3i(1, 0, 0): left, at: end_x}, "no room: to the left")
	var floating := Mining.placement(at + Vector3i(0, 2, 0), bench, south, voxel_at)
	assert_true(floating.is_empty(), "it stands on the ground")
	for cell: Vector3i in placed:
		cells[cell] = placed[cell]
	var both: Array[Vector3i] = [at - Vector3i(1, 0, 0), at]
	assert_eq(Mining.object_cells(at, end_x, voxel_at), both, "from its right end")
	assert_eq(Mining.object_cells(both[0], left, voxel_at), both, "from its left end")
	var rect := ObjectShapes.footprint_rect(Tiles.Block.WORKBENCH_END_X, Vector2i.ZERO)
	assert_eq(rect.size, Vector2(16, ObjectShapes.BENCH_DEPTH), "bodies kept out end to end")
	assert_eq(ObjectShapes.model_block(Tiles.Block.WORKBENCH_NORTH), Tiles.Block.WORKBENCH)
	assert_eq(ObjectShapes.model_block(Tiles.Block.WORKBENCH_END_Z), -1, "no model of its own")


func test_the_server_places_and_breaks_a_whole_workbench() -> void:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	var client: LocalTransport = transports[0]
	client.send(Msg.hello("Alex", 2))
	server.process_messages()
	var session := server.first_session()
	session.inventory.add(Items.Id.WORKBENCH, 1)
	var feet := Coords.world_to_tile(session.position)
	var row := floori(session.height + 0.01) + GameConst.SEA_LEVEL
	var cell := Vector3i(feet.x + 2, row, feet.y)
	for x in [cell.x, cell.x + 1]:
		server.world.set_voxel(Vector3i(x, row - 1, cell.z), Voxels.of_block(Tiles.Block.STONE))
		for y in [row, row + 1]:
			server.world.set_voxel(Vector3i(x, y, cell.z), Voxels.AIR)
	client.send(Msg.block_place(cell, 0, Vector2i(0, 1)))
	server.process_messages()
	var left := Voxels.of_block(Tiles.Block.WORKBENCH)
	assert_eq(server.world.voxel_at(cell), left, "its left end")
	var end := cell + Vector3i(1, 0, 0)
	assert_eq(server.world.voxel_at(end), Voxels.of_block(Tiles.Block.WORKBENCH_END_X))
	assert_eq(session.inventory.items[0], N, "it left the hand")
	client.poll()
	client.send(Msg.block_break(end))
	server.process_messages()
	assert_eq(server.world.voxel_at(cell), Voxels.AIR, "both ends go")
	assert_eq(server.world.voxel_at(end), Voxels.AIR)
	assert_eq(server.items.size(), 1, "one workbench given back")
	assert_eq(server.items.values()[0].item, Items.Id.WORKBENCH)


func test_tools_are_made_at_the_workbench_in_minecraft_shapes() -> void:
	var stick := Items.Id.STICK
	var stone := Items.Id.STONE
	var deepslate := Items.Id.DEEPSLATE
	var pickaxe := [[OAK, BIRCH, OAK], [N, stick, N], [N, stick, N]]
	var wide := _grid(Inventory.GRID, Vector2i(2, 2), pickaxe)
	var wooden := Vector2i(Items.Id.WOODEN_PICKAXE, 1)
	assert_eq(Recipes.result_of(wide, Inventory.GRID), wooden, "anywhere in the 5 x 5 grid")
	var small := _grid(Inventory.OWN_GRID, Vector2i.ZERO, pickaxe)
	assert_eq(Recipes.result_of(small, Inventory.OWN_GRID), Vector2i.ZERO, "only at a workbench")
	var axe := _grid(
		Inventory.GRID, Vector2i.ZERO, [[stone, deepslate], [stick, stone], [stick, N]]
	)
	var stone_axe := Vector2i(Items.Id.STONE_AXE, 1)
	assert_eq(Recipes.result_of(axe, Inventory.GRID), stone_axe, "mirrored, any stone")
	var shovel := [[Items.Id.IRON_INGOT], [stick], [stick]]
	var iron := _grid(Inventory.GRID, Vector2i(4, 1), shovel)
	assert_eq(Recipes.result_of(iron, Inventory.GRID).x, Items.Id.IRON_SHOVEL, "iron ingots")
	var raw := _grid(Inventory.GRID, Vector2i(4, 1), [[Items.Id.RAW_IRON], [stick], [stick]])
	assert_eq(Recipes.result_of(raw, Inventory.GRID), Vector2i.ZERO, "not raw iron")
	for tool: int in Items.TOOLS:
		var made := Recipes.all().filter(
			func(recipe: Dictionary) -> bool: return recipe["result"][0] == tool
		)
		assert_eq(made.size(), 1, "%s has its recipe" % Items.name_key(tool))
	var two_sand := [Items.Id.SAND, Items.Id.SAND]
	var sand := _grid(Inventory.OWN_GRID, Vector2i(1, 1), [two_sand, two_sand])
	assert_eq(Recipes.result_of(sand, Inventory.OWN_GRID).x, Items.Id.SANDSTONE, "4 sand")


func test_a_workbench_opened_lends_its_grid() -> void:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	var client: LocalTransport = transports[0]
	client.send(Msg.hello("Alex", 2))
	server.process_messages()
	var session := server.first_session()
	var feet := Coords.world_to_tile(session.position)
	var row := floori(session.height + 0.01) + GameConst.SEA_LEVEL
	var bench := Vector3i(feet.x + 2, row, feet.y)
	server.world.set_voxel(bench, Voxels.of_block(Tiles.Block.WORKBENCH))
	var bag := session.inventory
	var cells := [OAK, OAK, OAK, N, Items.Id.STICK, N, N, Items.Id.STICK, N]
	for i in cells.size():
		var cell := Inventory.CRAFT + (i / 3) * Inventory.GRID + i % 3 + 2
		if cells[i] != N:
			bag.items[cell] = cells[i]
			bag.counts[cell] = 1
	client.send(Msg.craft(false))
	server.process_messages()
	assert_eq(bag.items[Inventory.CURSOR], N, "the inventory's own grid cannot")
	client.send(Msg.open_workbench(bench))
	client.send(Msg.craft(false))
	server.process_messages()
	assert_eq(bag.items[Inventory.CURSOR], Items.Id.WOODEN_PICKAXE, "the workbench's can")
	client.send(Msg.inventory_close())
	server.process_messages()
	assert_eq(session.craft_width, Inventory.OWN_GRID, "closed: back to the inventory's")
	client.send(Msg.open_workbench(bench + Vector3i(0, 0, 3)))
	server.process_messages()
	assert_eq(session.craft_width, Inventory.OWN_GRID, "no workbench there")


## A crafting grid `width` across holding `rows` of items from `at`.
static func _grid(width: int, at: Vector2i, rows: Array) -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.resize(width * width)
	cells.fill(N)
	for y in rows.size():
		for x in rows[y].size():
			cells[(at.y + y) * width + at.x + x] = rows[y][x]
	return cells
