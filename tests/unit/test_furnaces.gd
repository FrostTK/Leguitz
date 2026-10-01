extends TestCase
## Furnaces: the food furnace cooks food (ore breaks it), the factory
## furnace smelts ores and chars logs (food comes out charred); fuel burns
## while there is something to cook, paced by the day's length; the server
## runs them, lights them, saves them and spills them.

const SEA := GameConst.SEA_LEVEL
const FOLDER := "user://test_worlds/furnaces"
const FOOD := Tiles.Block.FOOD_FURNACE
const FACTORY := Tiles.Block.FACTORY_FURNACE
const N := Items.Id.NONE


func test_each_furnace_makes_its_own_things() -> void:
	assert_eq(Smelting.result_of(FOOD, Items.Id.BERRIES), Items.Id.DRIED_BERRIES)
	assert_eq(Smelting.result_of(FOOD, Items.Id.MUSHROOM_RED), Items.Id.MUSHROOM_STEW)
	assert_eq(Smelting.result_of(FOOD, Items.Id.MUSHROOM_BROWN), Items.Id.MUSHROOM_STEW)
	assert_eq(Smelting.result_of(FOOD, Items.Id.RAW_IRON), Smelting.BREAKS, "ore breaks it")
	assert_false(Smelting.accepts(FOOD, Items.Id.OAK_LOG), "no charcoal in the oven")
	assert_eq(Smelting.result_of(FACTORY, Items.Id.RAW_COPPER), Items.Id.COPPER_INGOT)
	assert_eq(Smelting.result_of(FACTORY, Items.Id.RAW_IRON), Items.Id.IRON_INGOT)
	assert_eq(Smelting.result_of(FACTORY, Items.Id.RAW_GOLD), Items.Id.GOLD_INGOT)
	assert_eq(Smelting.result_of(FACTORY, Items.Id.SPRUCE_LOG), Items.Id.CHARCOAL)
	assert_eq(Smelting.result_of(FACTORY, Items.Id.BERRIES), Items.Id.CHARRED_FOOD, "charred")
	assert_eq(Smelting.result_of(FACTORY, Items.Id.MUSHROOM_STEW), Items.Id.CHARRED_FOOD)
	assert_false(Smelting.accepts(FACTORY, Items.Id.DIRT))
	assert_true(Smelting.is_fuel(Items.Id.CHARCOAL))
	assert_false(Smelting.is_fuel(Items.Id.DIRT))


func test_fuel_burns_while_food_cooks() -> void:
	var clock := WorldClock.new()
	var furnace := Furnace.new(FOOD)
	furnace.slots.items[Furnace.INPUT] = Items.Id.BERRIES
	furnace.slots.counts[Furnace.INPUT] = 3
	furnace.slots.items[Furnace.FUEL] = Items.Id.COAL
	furnace.slots.counts[Furnace.FUEL] = 2
	assert_eq(furnace.step(0.1, clock), Furnace.Step.CHANGED, "lit")
	assert_true(furnace.burning())
	assert_eq(furnace.slots.counts[Furnace.FUEL], 1, "a lump of coal taken")
	_run(furnace, clock, 9.8)
	assert_eq(furnace.slots.items[Furnace.OUTPUT], N, "not yet")
	_run(furnace, clock, 0.2)
	assert_eq(furnace.slots.items[Furnace.OUTPUT], Items.Id.DRIED_BERRIES, "10 s: one done")
	assert_eq(furnace.slots.counts[Furnace.INPUT], 2)
	_run(furnace, clock, 20.0)
	assert_eq(furnace.slots.counts[Furnace.OUTPUT], 3, "all of them")
	_run(furnace, clock, 50.0)
	assert_false(furnace.burning(), "its coal burnt out")
	assert_eq(furnace.slots.counts[Furnace.FUEL], 1, "nothing left to cook: no more lit")


func test_without_fire_what_cooked_cools_back() -> void:
	var clock := WorldClock.new()
	var furnace := Furnace.new(FOOD)
	furnace.slots.items[Furnace.INPUT] = Items.Id.BERRIES
	furnace.slots.counts[Furnace.INPUT] = 5
	furnace.slots.items[Furnace.FUEL] = Items.Id.STICK
	furnace.slots.counts[Furnace.FUEL] = 1
	_run(furnace, clock, 5.2)
	assert_false(furnace.burning(), "a stick lasts 5 s")
	assert_true(furnace.progress > 0.3, "half cooked")
	assert_eq(furnace.slots.items[Furnace.OUTPUT], N)
	_run(furnace, clock, 3.0)
	assert_eq(furnace.progress, 0.0, "cooled back")


func test_longer_days_cook_slower() -> void:
	var clock := WorldClock.new()
	clock.set_normal(120.0)
	var furnace := Furnace.new(FACTORY)
	furnace.slots.items[Furnace.INPUT] = Items.Id.RAW_GOLD
	furnace.slots.counts[Furnace.INPUT] = 1
	furnace.slots.items[Furnace.FUEL] = Items.Id.COAL
	furnace.slots.counts[Furnace.FUEL] = 1
	_run(furnace, clock, 10.5)
	assert_eq(furnace.slots.items[Furnace.OUTPUT], N, "a 2-hour day: slower")
	_run(furnace, clock, clock.scale_duration(Smelting.COOK_SECONDS) - 10.0)
	assert_eq(furnace.slots.items[Furnace.OUTPUT], Items.Id.GOLD_INGOT)


func test_ore_breaks_a_food_furnace_and_food_chars_in_a_factory_one() -> void:
	var clock := WorldClock.new()
	var oven := Furnace.new(FOOD)
	oven.slots.items[Furnace.INPUT] = Items.Id.RAW_COPPER
	oven.slots.counts[Furnace.INPUT] = 5
	oven.slots.items[Furnace.FUEL] = Items.Id.COAL
	oven.slots.counts[Furnace.FUEL] = 1
	var broke := false
	for i in 120:
		if oven.step(0.1, clock) == Furnace.Step.BROKE:
			broke = true
			break
	assert_true(broke, "the ore melted: it broke")
	assert_eq(oven.slots.counts[Furnace.INPUT], 4, "the ore is lost")
	var factory := Furnace.new(FACTORY)
	factory.slots.items[Furnace.INPUT] = Items.Id.MUSHROOM_RED
	factory.slots.counts[Furnace.INPUT] = 1
	factory.slots.items[Furnace.FUEL] = Items.Id.OAK_PLANKS
	factory.slots.counts[Furnace.FUEL] = 1
	_run(factory, clock, 10.1)
	assert_eq(factory.slots.items[Furnace.OUTPUT], Items.Id.CHARRED_FOOD)


func test_no_room_for_what_it_makes_keeps_the_fire_out() -> void:
	var clock := WorldClock.new()
	var furnace := Furnace.new(FACTORY)
	furnace.slots.items[Furnace.INPUT] = Items.Id.RAW_IRON
	furnace.slots.counts[Furnace.INPUT] = 1
	furnace.slots.items[Furnace.FUEL] = Items.Id.COAL
	furnace.slots.counts[Furnace.FUEL] = 1
	furnace.slots.items[Furnace.OUTPUT] = Items.Id.COPPER_INGOT
	furnace.slots.counts[Furnace.OUTPUT] = 1
	assert_eq(furnace.step(0.1, clock), Furnace.Step.NOTHING)
	assert_false(furnace.burning(), "copper ingots in the way: not lit")
	var copy := Furnace.from_dict(furnace.to_dict())
	assert_eq(copy.kind, FACTORY, "its state travels")
	assert_eq(copy.slots.items[Furnace.OUTPUT], Items.Id.COPPER_INGOT)


func test_clicks_put_things_where_they_belong() -> void:
	var bag := Inventory.new()
	var furnace := Furnace.new(FOOD)
	bag.add(Items.Id.COAL, 10)
	bag.add(Items.Id.BERRIES, 20)
	bag.add(Items.Id.DIRT, 5)
	bag.click(0, false, false)
	bag.click_furnace(furnace, Furnace.INPUT, false, false)
	assert_eq(furnace.slots.items[Furnace.INPUT], N, "coal is no food")
	bag.click_furnace(furnace, Furnace.FUEL, false, false)
	assert_eq(furnace.slots.counts[Furnace.FUEL], 10, "but it burns")
	bag.click(1, false, true, null, furnace)
	assert_eq(furnace.slots.counts[Furnace.INPUT], 20, "shift: berries to cook")
	bag.click(2, false, true, null, furnace)
	assert_eq(bag.items[Inventory.HOTBAR], Items.Id.DIRT, "dirt: to the bag as usual")
	furnace.slots.items[Furnace.OUTPUT] = Items.Id.DRIED_BERRIES
	furnace.slots.counts[Furnace.OUTPUT] = 3
	bag.click(Inventory.HOTBAR, false, false)
	bag.click_furnace(furnace, Furnace.OUTPUT, false, false)
	assert_eq(furnace.slots.counts[Furnace.OUTPUT], 3, "nothing goes into what it made")
	bag.click(Inventory.HOTBAR, false, false)
	bag.click_furnace(furnace, Furnace.OUTPUT, false, false)
	assert_eq(bag.items[Inventory.CURSOR], Items.Id.DRIED_BERRIES, "taken")
	furnace.slots.items[Furnace.OUTPUT] = Items.Id.DRIED_BERRIES
	furnace.slots.counts[Furnace.OUTPUT] = 2
	bag.click_furnace(furnace, Furnace.OUTPUT, false, false)
	assert_eq(bag.counts[Inventory.CURSOR], 5, "onto the cursor's stack")


func test_furnaces_are_placed_facing_the_player_and_made() -> void:
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var voxel_at := func(cell: Vector3i) -> int: return stone if cell.y < SEA else Voxels.AIR
	var at := Vector3i(0, SEA, 0)
	var placed := Mining.placement(
		at, Items.placed_voxel(Items.Id.FOOD_FURNACE), Vector2i(-1, 0), voxel_at
	)
	assert_eq(placed, {at: Voxels.of_block(Tiles.Block.FOOD_FURNACE_WEST)})
	var lit := Voxels.of_block(Tiles.Block.FACTORY_FURNACE_LIT_NORTH)
	assert_true(ObjectShapes.is_lit(Tiles.Block.FACTORY_FURNACE_LIT_NORTH))
	assert_eq(ObjectShapes.furnace_kind(Tiles.Block.FACTORY_FURNACE_LIT_NORTH), FACTORY)
	assert_eq(
		ObjectShapes.model_block(Tiles.Block.FACTORY_FURNACE_LIT_NORTH),
		Tiles.Block.FACTORY_FURNACE_LIT
	)
	assert_true(Mining.opens(lit))
	assert_false(Mining.opens(Voxels.of_block(Tiles.Block.BROKEN_FURNACE_EAST)), "broken: useless")
	assert_eq(Mining.tool_for(lit), Items.Tool.PICKAXE)
	var rng := RandomNumberGenerator.new()
	assert_eq(Items.drops(lit, Vector2i.ZERO, rng)[0].x, Items.Id.FACTORY_FURNACE)
	var rubble := Items.drops(Voxels.of_block(Tiles.Block.BROKEN_FURNACE), Vector2i.ZERO, rng)
	assert_eq(rubble[0].x, Items.Id.STONE, "a broken one gives stones back")
	var ring := PackedInt32Array([Items.Id.STONE, Items.Id.STONE, Items.Id.DEEPSLATE])
	ring.append_array([Items.Id.STONE, N, Items.Id.STONE])
	ring.append_array([Items.Id.STONE, Items.Id.STONE, Items.Id.STONE])
	assert_eq(Recipes.result_of(ring, 3), Vector2i(Items.Id.FOOD_FURNACE, 1), "8 stones")
	ring[4] = Items.Id.CHARCOAL
	assert_eq(Recipes.result_of(ring, 3), Vector2i.ZERO, "the factory one: at the workbench")
	var bench := PackedInt32Array()
	bench.resize(Inventory.GRID * Inventory.GRID)
	for row in 3:
		for column in 3:
			bench[row * Inventory.GRID + column] = ring[row * 3 + column]
	assert_eq(Recipes.result_of(bench, Inventory.GRID), Vector2i(Items.Id.FACTORY_FURNACE, 1))


func test_the_server_runs_lights_saves_and_breaks_furnaces() -> void:
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
	session.inventory.add(Items.Id.MUSHROOM_BROWN, 2)
	session.inventory.add(Items.Id.COAL, 1)
	var feet := Coords.world_to_tile(session.position)
	var row := floori(session.height + 0.01) + SEA
	var cell := Vector3i(feet.x + 2, row, feet.y)
	server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.FOOD_FURNACE_EAST))
	client.send(Msg.open_furnace(cell))
	client.send(Msg.slot_click(0, false, true))
	client.send(Msg.slot_click(1, false, true))
	server.process_messages()
	var oven := server.world.furnace_at(cell)
	assert_eq(oven.slots.counts[Furnace.INPUT], 2, "mushrooms in")
	assert_eq(oven.slots.items[Furnace.FUEL], Items.Id.COAL, "coal under them")
	for i in GameConst.TICKS_PER_SECOND * 11:
		server.tick()
	assert_eq(oven.slots.items[Furnace.OUTPUT], Items.Id.MUSHROOM_STEW, "a stew after 10 s")
	var lit := Voxels.of_block(Tiles.Block.FOOD_FURNACE_LIT_EAST)
	assert_eq(server.world.voxel_at(cell), lit, "it burns, facing the same way")
	var seen := client.poll().filter(func(m: Dictionary) -> bool: return m["t"] == Msg.FURNACE)
	assert_true(seen.size() > 10, "the player watching sees it cook")
	assert_true(server.save())
	var again := GameServer.new(settings, null, false)
	again.use_storage(WorldStorage.new(FOLDER), storage.read_world())
	var kept := again.world.furnace_at(cell)
	assert_eq(kept.slots.items[Furnace.OUTPUT], Items.Id.MUSHROOM_STEW, "saved with its chunk")
	assert_true(kept.burning(), "still burning")
	# Ore melted in it: broken, its stew spilled.
	client.send(Msg.inventory_close())
	server.process_messages()
	oven.slots.items[Furnace.INPUT] = Items.Id.RAW_IRON
	oven.slots.counts[Furnace.INPUT] = 1
	for i in GameConst.TICKS_PER_SECOND * 11:
		server.tick()
	var broken := Voxels.of_block(Tiles.Block.BROKEN_FURNACE_EAST)
	assert_eq(server.world.voxel_at(cell), broken, "broken by the ore")
	var spilled := server.items.values().map(func(d: DroppedItem) -> int: return d.item)
	assert_true(Items.Id.MUSHROOM_STEW in spilled, "what it held spills")
	assert_false(Items.Id.RAW_IRON in spilled, "the ore is lost")
	client.send(Msg.open_furnace(cell))
	server.process_messages()
	assert_eq(session.furnace, GameServer.NO_CELL, "a broken furnace does not open")
	storage.erase()


func _run(furnace: Furnace, clock: WorldClock, seconds: float) -> void:
	for i in roundi(seconds / 0.1):
		furnace.step(0.1, clock)
