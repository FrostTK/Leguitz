extends TestCase
## The kitchen: dishes made only at the kitchen counter (what held a
## liquid stays in the grid), the mill, the butter churn, the barrel (juice,
## then cider, into glass bottles) and the cheese cellar, what a broken
## machine spills, and what dishes do (Effects): eaten even full, healing,
## slowing hunger, worn off, saved.

const SEA := GameConst.SEA_LEVEL

var _server: GameServer
var _client: LocalTransport
var _session: GameServer.PlayerSession


## A server, a player on flat grass, noon, nothing around.
func _kitchen() -> void:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	_server = GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	_server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	_server.process_messages()
	_client = transports[0]
	_session = _server.first_session()
	_session.height = 0.0
	_server.clock.set_frozen(WorldClock.FROZEN_NOON)
	var tile := Coords.world_to_tile(_session.position)
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			var column := Vector3i(tile.x + dx, SEA - 1, tile.y + dz)
			_server.world.set_voxel(column, Voxels.of_ground(Tiles.Ground.GRASS))
			for up in range(1, 6):
				_server.world.set_voxel(column + Vector3i(0, up, 0), Voxels.AIR)


func _cell(dx: int, dz: int) -> Vector3i:
	var tile := Coords.world_to_tile(_session.position)
	return Vector3i(tile.x + dx, SEA, tile.y + dz)


func _hold(item: int, count := 1) -> void:
	_session.inventory.items[0] = item
	_session.inventory.counts[0] = count
	_session.inventory.wear[0] = 0


func _held(item: int) -> int:
	var count := 0
	for slot in Inventory.SLOTS:
		if _session.inventory.items[slot] == item:
			count += _session.inventory.counts[slot]
	return count


func _block(cell: Vector3i) -> int:
	return Voxels.block_of(_server.world.voxel_at(cell))


func _use(cell: Vector3i) -> void:
	_client.send(Msg.use_machine(cell, 0))
	_server.process_messages()


func _put_in_grid(items: Array) -> Inventory:
	var bag := Inventory.new()
	for i in items.size():
		var cell := Inventory.CRAFT + (i / Inventory.OWN_GRID) * Inventory.GRID
		cell += i % Inventory.OWN_GRID
		bag.items[cell] = items[i]
		bag.counts[cell] = 1
	return bag


func test_dishes_are_made_at_the_kitchen_counter_only() -> void:
	var omelette := _put_in_grid([Items.Id.EGG, Items.Id.EGG, Items.Id.BUTTER])
	assert_eq(omelette.craft_result(Inventory.OWN_GRID), Vector2i.ZERO, "not in the inventory")
	var dish := omelette.craft_result(Inventory.OWN_GRID, true)
	assert_eq(dish, Vector2i(Items.Id.OMELETTE, 1), "at the counter")
	var planks := _put_in_grid(
		[Items.Id.OAK_PLANKS, Items.Id.NONE, Items.Id.NONE, Items.Id.OAK_PLANKS]
	)
	assert_eq(
		planks.craft_result(Inventory.OWN_GRID, true), Vector2i.ZERO, "the counter only cooks"
	)
	assert_eq(planks.craft_result(Inventory.OWN_GRID), Vector2i(Items.Id.STICK, 4))
	# Groups: any meat, any mushroom...
	var stew := _put_in_grid(
		[Items.Id.COOKED_FISH, Items.Id.POTATO, Items.Id.CARROT, Items.Id.MUSHROOM_RED]
	)
	assert_eq(stew.craft_result(Inventory.OWN_GRID, true), Vector2i(Items.Id.MEAT_STEW, 2))
	for recipe: Dictionary in Recipes.all():
		if recipe.get("kitchen", false):
			var made: int = recipe["result"][0]
			assert_true(Items.is_food(made), "%s feeds" % Items.name_key(made))


func test_what_held_milk_or_jam_stays_in_the_grid() -> void:
	var crepes := _put_in_grid([Items.Id.FLOUR, Items.Id.EGG, Items.Id.MILK_BUCKET])
	crepes.craft(Inventory.OWN_GRID, false, true)
	assert_eq(crepes.items[Inventory.CURSOR], Items.Id.CREPES)
	assert_eq(crepes.counts[Inventory.CURSOR], 3)
	assert_eq(crepes.items[Inventory.CRAFT + 2], Items.Id.BUCKET, "the bucket stays")
	assert_eq(crepes.items[Inventory.CRAFT], Items.Id.NONE, "the flour went")
	var tartine := _put_in_grid([Items.Id.BREAD, Items.Id.BUTTER, Items.Id.JAM])
	tartine.craft(Inventory.OWN_GRID, false, true)
	assert_eq(tartine.items[Inventory.CURSOR], Items.Id.TARTINE)
	assert_eq(tartine.items[Inventory.CRAFT + 2], Items.Id.GLASS_BOTTLE, "the jar stays")


func test_the_counter_opens_its_grid_to_the_dishes() -> void:
	_kitchen()
	var counter := _cell(1, 0)
	_server.world.set_voxel(counter, Voxels.of_block(Tiles.Block.KITCHEN_WEST))
	assert_true(Mining.opens(_server.world.voxel_at(counter)), "it opens")
	_client.send(Msg.open_workbench(counter))
	_server.process_messages()
	assert_true(_session.kitchen, "its grid cooks")
	var bag := _session.inventory
	for i in 3:
		bag.items[Inventory.CRAFT + i] = Items.Id.FLOUR
		bag.counts[Inventory.CRAFT + i] = 1
	_client.send(Msg.craft(false))
	_server.process_messages()
	assert_eq(bag.items[Inventory.CURSOR], Items.Id.BREAD, "bread from flour")
	assert_eq(bag.counts[Inventory.CURSOR], 2)
	_client.send(Msg.inventory_close())
	_server.process_messages()
	assert_false(_session.kitchen, "closed: the inventory's own grid again")


func test_the_mill_grinds_grain_into_flour() -> void:
	_kitchen()
	var mill := _cell(1, 0)
	_server.world.set_voxel(mill, Voxels.of_block(Tiles.Block.MILL))
	_hold(Items.Id.WHEAT, 20)
	_use(mill)
	assert_eq(_block(mill), Tiles.Block.MILL_WORKING, "it grinds")
	assert_eq(
		_held(Items.Id.WHEAT), 20 - Machines.CAPACITY[Machines.Kind.MILL], "as much as it takes"
	)
	_use(mill)
	assert_eq(_held(Items.Id.WHEAT), 4, "nothing more while it works")
	Machines.update(_server, 1.0)
	assert_eq(_block(mill), Tiles.Block.MILL_WORKING, "a grain takes a while")
	Machines.update(_server, 16 * Machines.SECONDS[Machines.Kind.MILL] * 3.0)
	assert_eq(_block(mill), Tiles.Block.MILL_READY, "done")
	_use(mill)
	assert_eq(_held(Items.Id.FLOUR), 16, "a flour a grain")
	assert_eq(_block(mill), Tiles.Block.MILL, "empty again")


func test_the_churn_and_the_cellar_give_the_bucket_back() -> void:
	_kitchen()
	var churn := _cell(1, 0)
	var cellar := _cell(-1, 0)
	_server.world.set_voxel(churn, Voxels.of_block(Tiles.Block.BUTTER_CHURN))
	_server.world.set_voxel(cellar, Voxels.of_block(Tiles.Block.CHEESE_CELLAR))
	_hold(Items.Id.MILK_BUCKET)
	_use(churn)
	assert_eq(_session.inventory.items[0], Items.Id.BUCKET, "the bucket back in hand")
	_hold(Items.Id.MILK_BUCKET)
	_use(cellar)
	assert_eq(_block(cellar), Tiles.Block.CHEESE_CELLAR_WORKING)
	Machines.update(_server, 10000.0)
	assert_eq(_block(churn), Tiles.Block.BUTTER_CHURN_READY)
	assert_eq(_block(cellar), Tiles.Block.CHEESE_CELLAR_READY)
	_hold(Items.Id.NONE, 0)
	_use(churn)
	_use(cellar)
	assert_eq(_held(Items.Id.BUTTER), 2, "butter")
	assert_eq(_held(Items.Id.CHEESE), 3, "cheese")


func test_the_barrel_makes_juice_then_cider_into_bottles() -> void:
	_kitchen()
	var barrel := _cell(1, 0)
	_server.world.set_voxel(barrel, Voxels.of_block(Tiles.Block.BARREL))
	_hold(Items.Id.APPLE, 4)
	_use(barrel)
	assert_eq(_block(barrel), Tiles.Block.BARREL_WORKING)
	Machines.update(_server, 400.0)
	assert_eq(_block(barrel), Tiles.Block.BARREL_READY, "juice")
	_hold(Items.Id.NONE, 0)
	_use(barrel)
	assert_eq(_held(Items.Id.APPLE_JUICE), 0, "no bottle, no juice")
	_hold(Items.Id.GLASS_BOTTLE, 2)
	_use(barrel)
	assert_eq(_held(Items.Id.APPLE_JUICE), 2, "a juice a bottle")
	assert_eq(_block(barrel), Tiles.Block.BARREL_READY, "some left")
	Machines.update(_server, 1000.0)
	_hold(Items.Id.GLASS_BOTTLE, 5)
	_use(barrel)
	assert_eq(_held(Items.Id.CIDER), 2, "left longer, apple juice turns into cider")
	assert_eq(_held(Items.Id.GLASS_BOTTLE), 3, "the bottles left")
	assert_eq(_block(barrel), Tiles.Block.BARREL, "empty")
	# Other fruit make fruit juice.
	_hold(Items.Id.GRAPES, 3)
	_use(barrel)
	Machines.update(_server, 400.0)
	_hold(Items.Id.GLASS_BOTTLE, 3)
	_use(barrel)
	assert_eq(_held(Items.Id.FRUIT_JUICE), 3)


func test_a_broken_machine_spills_what_it_held() -> void:
	_kitchen()
	var mill := _cell(1, 0)
	_server.world.set_voxel(mill, Voxels.of_block(Tiles.Block.MILL))
	_hold(Items.Id.CORN, 5)
	_use(mill)
	_server.spill_contents(mill)
	var lying := 0
	for dropped: DroppedItem in _server.items.values():
		if dropped.item == Items.Id.CORN:
			lying += dropped.count
	assert_eq(lying, 5, "the grain falls out")
	var chunk: ChunkData = _server.world.chunks[Coords.tile_to_chunk(Vector2i(mill.x, mill.z))]
	assert_false(chunk.machines.has(mill), "forgotten")


func test_dishes_give_effects_eaten_even_full() -> void:
	_kitchen()
	_session.food = Vitals.MAX_FOOD
	_hold(Items.Id.BREAD, 2)
	Survival.eat(_server, _session, 0)
	assert_eq(_held(Items.Id.BREAD), 2, "full: bread is not eaten")
	_hold(Items.Id.CAKE, 2)
	Survival.eat(_server, _session, 0)
	assert_eq(_held(Items.Id.CAKE), 1, "a dish with effects is")
	assert_true(Effects.has(_session.effects, Effects.Kind.REGEN))
	assert_true(Effects.has(_session.effects, Effects.Kind.SWIFT))
	# Regeneration heals whatever the satiety.
	_session.health = 10
	_session.food = 2
	_session.since_hurt = 0.0
	Survival.update(_server, [_session], 3.5)
	assert_true(_session.health > 10, "healed by the cake")
	# Well fed, hunger comes slower.
	_session.effects = {Effects.Kind.FED: 100.0}
	_session.food = 10
	_session.effort = 0.0
	Survival.spend(_server, _session, 1.5)
	assert_eq(_session.food, 10, "half the effort: not yet a point")
	# They wear off, and the player is told.
	_client.poll()
	Survival.update(_server, [_session], 200.0)
	assert_true(_session.effects.is_empty(), "worn off")
	var told := _client.poll().filter(func(m: Dictionary) -> bool: return m["t"] == Msg.VITALS)
	assert_false(told.is_empty(), "told")
	# Saved with the player.
	_session.effects = {Effects.Kind.STRONG: 30.0}
	var state := GameServer.player_state(_session)
	assert_eq(Effects.from_dict(state["effects"]), {Effects.Kind.STRONG: 30.0})


func test_kitchen_items_are_named_and_modeled() -> void:
	var items: Array[int] = [
		Items.Id.FLOUR,
		Items.Id.BUTTER,
		Items.Id.CHEESE,
		Items.Id.APPLE_JUICE,
		Items.Id.FRUIT_JUICE,
		Items.Id.CIDER,
		Items.Id.JAM,
		Items.Id.VEGETABLE_SOUP,
		Items.Id.MEAT_STEW,
		Items.Id.FRUIT_PIE,
		Items.Id.OMELETTE,
		Items.Id.CAKE,
		Items.Id.CREPES,
		Items.Id.GRATIN,
		Items.Id.TARTINE,
		Items.Id.KITCHEN,
		Items.Id.MILL,
		Items.Id.BUTTER_CHURN,
		Items.Id.BARREL,
		Items.Id.CHEESE_CELLAR,
	]
	for item in items:
		var name := Items.name_key(item)
		assert_ne(tr(name), name, "%s named" % name)
		var grid := ItemModels.build(item)
		assert_true(grid != null and not grid.is_empty(), "%s modeled" % name)
	for kind: int in Effects.Kind.values():
		assert_ne(tr(Effects.NAME_KEYS[kind]), Effects.NAME_KEYS[kind])
		assert_ne(tr(Effects.HOW_KEYS[kind]), Effects.HOW_KEYS[kind])
	for food: int in Effects.OF_FOOD:
		assert_true(Items.is_food(food), "%s feeds" % Items.name_key(food))
	for kind: int in Machines.STAGES:
		for block: int in Machines.STAGES[kind]:
			assert_true(KitchenModels.build(block) != null, "a model each stage")
			assert_eq(ObjectShapes.base_kind(block), Machines.STAGES[kind][0], "one kind")
