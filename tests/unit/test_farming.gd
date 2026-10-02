extends TestCase
## Fields and crops (Farming): tilling with a hoe, farmland wet near water
## or drying back to dirt, sowing on farmland only, crops growing by stages
## in the light, what they give, bread and baked potatoes.

const SEA := GameConst.SEA_LEVEL

var _server: GameServer


func _grass_at(cell: Vector3i) -> int:
	if cell.y < SEA - 1:
		return Voxels.of_block(Tiles.Block.STONE)
	return Voxels.of_ground(Tiles.Ground.GRASS) if cell.y == SEA - 1 else Voxels.AIR


## A grass field around the origin at noon (see test_growth).
func _field() -> GameServer:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	_server = GameServer.new(settings, null, false)
	_server.clock.set_frozen(WorldClock.FROZEN_NOON)
	for x in range(-12, 13):
		for z in range(-12, 13):
			for y in range(SEA - 3, SEA + 6):
				_server.world.set_voxel(Vector3i(x, y, z), _grass_at(Vector3i(x, y, z)))
	return _server


func _at(x: int, y: int, z: int) -> int:
	return _server.world.voxel_at(Vector3i(x, SEA + y, z))


func _put(x: int, y: int, z: int, voxel: int) -> void:
	_server.world.set_voxel(Vector3i(x, SEA + y, z), voxel)


func test_a_hoe_tills_grass_and_dirt() -> void:
	var cell := Vector3i(0, SEA - 1, 0)
	var farmland := Voxels.of_ground(Tiles.Ground.FARMLAND)
	assert_eq(Farming.tilled(cell, _grass_at), {cell: farmland})
	var grassy := func(at: Vector3i) -> int:
		if at == cell + Vector3i.UP:
			return Voxels.of_block(Tiles.Block.TALL_GRASS)
		return _grass_at(at)
	assert_eq(Farming.tilled(cell, grassy)[cell + Vector3i.UP], Voxels.AIR, "the grass goes")
	var torch := func(at: Vector3i) -> int:
		return Voxels.of_block(Tiles.Block.TORCH) if at == cell + Vector3i.UP else _grass_at(at)
	assert_true(Farming.tilled(cell, torch).is_empty(), "not under what was placed")
	var stone := func(_at: Vector3i) -> int: return Voxels.of_block(Tiles.Block.STONE)
	assert_true(Farming.tilled(cell, stone).is_empty())
	# Through the server, with a hoe in hand: it wears.
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	server.process_messages()
	var session := server.first_session()
	var tile := Coords.world_to_tile(session.position)
	var here := Vector3i(tile.x + 1, SEA - 1, tile.y)
	for at: Vector3i in [here, here + Vector3i(1, 0, 0)]:
		server.world.set_voxel(at, Voxels.of_ground(Tiles.Ground.GRASS))
		server.world.set_voxel(at + Vector3i.UP, Voxels.AIR)
	session.height = 0.0
	session.inventory.items[0] = Items.Id.IRON_HOE
	session.inventory.counts[0] = 1
	transports[0].send(Msg.till(here, 0))
	server.process_messages()
	assert_true(Farming.is_farmland(server.world.voxel_at(here)))
	assert_eq(session.inventory.wear[0], 1, "the hoe wears")
	session.inventory.items[0] = Items.Id.STICK
	transports[0].send(Msg.till(here + Vector3i(1, 0, 0), 0))
	server.process_messages()
	assert_false(Farming.is_farmland(server.world.voxel_at(here + Vector3i(1, 0, 0))), "no hoe")


func test_farmland_is_wet_near_water_and_dry_far_goes_back_to_dirt() -> void:
	_field()
	_put(0, -1, 0, Voxels.of_ground(Tiles.Ground.WATER))
	_put(3, -1, 0, Voxels.of_ground(Tiles.Ground.FARMLAND))
	_put(8, -1, 0, Voxels.of_ground(Tiles.Ground.FARMLAND))
	_put(8, -1, 3, Voxels.of_ground(Tiles.Ground.FARMLAND))
	_put(8, 0, 3, Voxels.of_block(Tiles.Block.WHEAT_0))
	Growth.update(_server, 0.0)
	assert_eq(_at(3, -1, 0), Voxels.of_ground(Tiles.Ground.FARMLAND_WET), "wet near water")
	assert_eq(_at(8, -1, 0), Voxels.of_ground(Tiles.Ground.FARMLAND), "dry far from it")
	Growth.update(_server, 1.0)
	assert_eq(_at(8, -1, 0), Voxels.of_ground(Tiles.Ground.DIRT), "left dry and bare: dirt")
	assert_true(Farming.is_farmland(_at(8, -1, 3)), "not under a crop")
	assert_true(Farming.is_farmland(_at(3, -1, 0)), "not when wet")


func test_crops_are_sown_on_farmland_and_grow_in_the_light() -> void:
	_field()
	var seeds := Items.placed_voxel(Items.Id.SEEDS)
	assert_eq(Voxels.block_of(seeds), Tiles.Block.WHEAT_0)
	var cell := Vector3i(2, SEA, 2)
	var voxel_at := _server.world.voxel_at
	assert_true(Mining.placement(cell, seeds, Vector2i(0, 1), voxel_at).is_empty(), "not on grass")
	_put(2, -1, 2, Voxels.of_ground(Tiles.Ground.FARMLAND))
	assert_eq(Mining.placement(cell, seeds, Vector2i(0, 1), voxel_at), {cell: seeds})
	assert_true(Mining.can_place(Items.placed_voxel(Items.Id.CARROT)), "a carrot is sown")
	_server.world.set_voxel(cell, seeds)
	assert_false(Mining.is_replaceable(Voxels.of_block(Tiles.Block.WHEAT_2)), "a crop stays")
	_server.clock.set_frozen(WorldClock.FROZEN_MIDNIGHT)
	Growth.update(_server, 1.0)
	assert_eq(Voxels.block_of(_at(2, 0, 2)), Tiles.Block.WHEAT_0, "not at night")
	_server.clock.set_frozen(WorldClock.FROZEN_NOON)
	for i in 3:
		Growth.update(_server, 1.0)
	assert_eq(Voxels.block_of(_at(2, 0, 2)), Tiles.Block.WHEAT_3, "ripe")
	var chunk: ChunkData = _server.world.chunks[Vector2i.ZERO]
	assert_false(chunk.growing.has(cell), "ripe, it grows no more")
	assert_true(chunk.growing.has(cell + Vector3i.DOWN), "its farmland still settles")
	assert_true(
		Farming.stage_seconds(_server.world, cell) > Farming.STAGE_SECONDS, "slower on dry farmland"
	)


func test_what_crops_and_grass_give_and_what_wheat_makes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var wheat := Items.drops(Voxels.of_block(Tiles.Block.WHEAT_3), Vector2i.ZERO, rng)
	assert_eq(wheat[0], Vector2i(Items.Id.WHEAT, 1))
	assert_eq(wheat[1].x, Items.Id.SEEDS, "and seeds")
	var green := Items.drops(Voxels.of_block(Tiles.Block.WHEAT_1), Vector2i.ZERO, rng)
	assert_eq(green, [Vector2i(Items.Id.SEEDS, 1)], "too soon: its seed back")
	var carrots := Items.drops(Voxels.of_block(Tiles.Block.CARROTS_3), Vector2i.ZERO, rng)
	assert_true(carrots[0].x == Items.Id.CARROT and carrots[0].y >= 2)
	var potato := Items.drops(Voxels.of_block(Tiles.Block.POTATOES_2), Vector2i.ZERO, rng)
	assert_eq(potato, [Vector2i(Items.Id.POTATO, 1)])
	var roots := 0
	for i in 200:
		var grass := Items.drops(Voxels.of_block(Tiles.Block.TALL_GRASS), Vector2i.ZERO, rng)
		assert_eq(grass[0], Vector2i(Items.Id.SEEDS, 1))
		roots += grass.size() - 1
	assert_true(roots > 3 and roots < 40, "now and then a wild root: %d" % roots)
	# Three wheat make dough; the food furnace bakes bread and potatoes.
	var cells := PackedInt32Array()
	cells.resize(Inventory.OWN_GRID * Inventory.OWN_GRID)
	for i in 3:
		cells[i] = Items.Id.WHEAT
	assert_eq(Recipes.result_of(cells, Inventory.OWN_GRID), Vector2i(Items.Id.DOUGH, 1))
	var oven := Tiles.Block.FOOD_FURNACE
	assert_eq(Smelting.result_of(oven, Items.Id.DOUGH), Items.Id.BREAD)
	assert_eq(Smelting.result_of(oven, Items.Id.POTATO), Items.Id.BAKED_POTATO)
	assert_true(Items.FOOD[Items.Id.BREAD] > Items.FOOD[Items.Id.POTATO], "cooked feeds more")
	assert_eq(
		Items.drops(Voxels.of_ground(Tiles.Ground.FARMLAND_WET), Vector2i.ZERO, rng)[0].x,
		Items.Id.DIRT
	)
