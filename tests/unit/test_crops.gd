extends TestCase
## More crops (Farming, Picking, Growth): new crops sown on farmland, rice
## over shallow water, sugar cane by water, grapes on a trellis, stems
## bearing fruit beside them, ripe plants picked again and again, fruit
## trees blossoming and bearing, wild plants and fruit trees in the world,
## what they give and make.

const SEA := GameConst.SEA_LEVEL

var _server: GameServer


func _grass_at(cell: Vector3i) -> int:
	if cell.y < SEA - 1:
		return Voxels.of_block(Tiles.Block.STONE)
	return Voxels.of_ground(Tiles.Ground.GRASS) if cell.y == SEA - 1 else Voxels.AIR


## A grass field around the origin at noon (see test_farming).
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


func _block(x: int, y: int, z: int) -> int:
	return Voxels.block_of(_at(x, y, z))


## How many of an item a bag holds.
func _count(bag: Inventory, item: int) -> int:
	var count := 0
	for slot in Inventory.SLOTS:
		if bag.items[slot] == item:
			count += bag.counts[slot]
	return count


## A server with a player standing on grass by `tile`, the cells around
## cleared (returns [server, transport, session]).
func _player() -> Array:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	server.process_messages()
	var session := server.first_session()
	var tile := Coords.world_to_tile(session.position)
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var cell := Vector3i(tile.x + dx, SEA - 1, tile.y + dz)
			server.world.set_voxel(cell, Voxels.of_ground(Tiles.Ground.GRASS))
			for up in range(1, 9):
				server.world.set_voxel(cell + Vector3i(0, up, 0), Voxels.AIR)
	session.height = 0.0
	return [server, transports[0], session]


func test_new_crops_are_sown_on_farmland_and_grow() -> void:
	_field()
	var voxel_at := _server.world.voxel_at
	var cell := Vector3i(2, SEA, 2)
	for item: int in [
		Items.Id.BEETROOT_SEEDS,
		Items.Id.CABBAGE_SEEDS,
		Items.Id.CORN,
		Items.Id.TOMATO_SEEDS,
		Items.Id.STRAWBERRY,
		Items.Id.RASPBERRY,
		Items.Id.FLAX_SEEDS,
		Items.Id.PUMPKIN_SEEDS,
		Items.Id.MELON_SEEDS,
	]:
		var seeds := Items.placed_voxel(item)
		var name := Items.name_key(item)
		assert_true(Farming.SOWN.has(Voxels.block_of(seeds)), "%s is sown" % name)
		_put(2, -1, 2, Voxels.of_ground(Tiles.Ground.GRASS))
		assert_true(Mining.placement(cell, seeds, Vector2i(0, 1), voxel_at).is_empty(), name)
		_put(2, -1, 2, Voxels.of_ground(Tiles.Ground.FARMLAND_WET))
		assert_eq(Mining.placement(cell, seeds, Vector2i(0, 1), voxel_at), {cell: seeds}, name)
		_server.world.set_voxel(cell, seeds)
		for i in 3:
			Growth.update(_server, 1.0)
		var block := _block(2, 0, 2)
		assert_true(Farming.RIPE.has(block), "%s ripens: %d" % [name, block])
		assert_eq(Farming.stage_of(block), 3)
		assert_eq(Farming.sown_of(block), Voxels.block_of(seeds))
		_put(2, 0, 2, Voxels.AIR)


func test_rice_is_sown_over_shallow_still_water() -> void:
	_field()
	var voxel_at := _server.world.voxel_at
	var rice := Items.placed_voxel(Items.Id.RICE)
	var water := Voxels.of_ground(Tiles.Ground.WATER)
	# A paddy: water one deep over dirt.
	_put(3, -1, 3, water)
	_put(3, -2, 3, Voxels.of_ground(Tiles.Ground.DIRT))
	var cell := Vector3i(3, SEA, 3)
	assert_eq(Mining.placement(cell, rice, Vector2i(0, 1), voxel_at), {cell: rice})
	assert_true(
		Mining.placement(Vector3i(3, SEA - 1, 3), rice, Vector2i(0, 1), voxel_at).is_empty(),
		"not into the water"
	)
	_put(3, -2, 3, water)
	_put(3, -3, 3, Voxels.of_ground(Tiles.Ground.DIRT))
	assert_true(Mining.placement(cell, rice, Vector2i(0, 1), voxel_at).is_empty(), "too deep")
	_put(3, -2, 3, Voxels.of_ground(Tiles.Ground.DIRT))
	_put(3, -1, 3, Voxels.of_ground(Tiles.Ground.WATER_FLOW_2))
	assert_true(Mining.placement(cell, rice, Vector2i(0, 1), voxel_at).is_empty(), "still water")
	_put(3, -1, 3, water)
	_server.world.set_voxel(cell, rice)
	for i in 3:
		Growth.update(_server, 1.0)
	assert_eq(_block(3, 0, 3), Tiles.Block.RICE_3, "ripe over the water")
	var rng := RandomNumberGenerator.new()
	var grains := Items.drops(_at(3, 0, 3), Vector2i(3, 3), rng)
	assert_true(grains[0].x == Items.Id.RICE and grains[0].y >= 2)
	assert_eq(Smelting.result_of(Tiles.Block.FOOD_FURNACE, Items.Id.RICE), Items.Id.COOKED_RICE)


func test_sugar_cane_grows_by_water_and_grows_back_once_cut() -> void:
	var made := _player()
	var server: GameServer = made[0]
	var transport: LocalTransport = made[1]
	var session: GameServer.PlayerSession = made[2]
	server.clock.set_frozen(WorldClock.FROZEN_NOON)
	var tile := Coords.world_to_tile(session.position)
	var soil := Vector3i(tile.x + 1, SEA - 1, tile.y)
	var cell := soil + Vector3i.UP
	var cane := Items.placed_voxel(Items.Id.SUGAR_CANE)
	server.world.set_voxel(soil, Voxels.of_ground(Tiles.Ground.SAND))
	var voxel_at := server.world.voxel_at
	assert_true(Mining.placement(cell, cane, Vector2i(0, 1), voxel_at).is_empty(), "no water")
	server.world.set_voxel(soil + Vector3i(0, 0, 1), Voxels.of_ground(Tiles.Ground.WATER))
	assert_eq(Mining.placement(cell, cane, Vector2i(0, 1), voxel_at), {cell: cane}, "by water")
	server.world.set_voxel(cell, cane)
	for i in 2:
		Growth.update(server, 1.0)
	assert_eq(Voxels.block_of(server.world.voxel_at(cell)), Tiles.Block.SUGAR_CANE, "grown")
	transport.send(Msg.pick(cell))
	server.process_messages()
	assert_eq(Voxels.block_of(server.world.voxel_at(cell)), Tiles.Block.SUGAR_CANE_0, "cut back")
	assert_true(_count(session.inventory, Items.Id.SUGAR_CANE) >= 2, "into the bag")
	transport.send(Msg.pick(cell))
	server.process_messages()
	assert_eq(Voxels.block_of(server.world.voxel_at(cell)), Tiles.Block.SUGAR_CANE_0, "not twice")
	for i in 2:
		Growth.update(server, 1.0)
	assert_eq(Voxels.block_of(server.world.voxel_at(cell)), Tiles.Block.SUGAR_CANE, "grows back")


func test_ripe_plants_are_picked_into_the_bag_and_ripen_again() -> void:
	var made := _player()
	var server: GameServer = made[0]
	var transport: LocalTransport = made[1]
	var session: GameServer.PlayerSession = made[2]
	server.clock.set_frozen(WorldClock.FROZEN_NOON)
	var tile := Coords.world_to_tile(session.position)
	var bed := Vector3i(tile.x + 1, SEA - 1, tile.y)
	var cell := bed + Vector3i.UP
	server.world.set_voxel(bed, Voxels.of_ground(Tiles.Ground.FARMLAND_WET))
	server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.TOMATOES_3))
	assert_true(Picking.can_pick(server.world.voxel_at(cell)))
	transport.send(Msg.pick(cell))
	server.process_messages()
	assert_eq(Voxels.block_of(server.world.voxel_at(cell)), Tiles.Block.TOMATOES_2)
	assert_true(_count(session.inventory, Items.Id.TOMATO) >= 2, "tomatoes in the bag")
	Growth.update(server, 1.0)
	assert_eq(Voxels.block_of(server.world.voxel_at(cell)), Tiles.Block.TOMATOES_3, "ripe again")
	# Out of reach, nothing happens.
	var far := Vector3i(tile.x + 9, SEA, tile.y)
	server.world.set_voxel(far + Vector3i.DOWN, Voxels.of_ground(Tiles.Ground.FARMLAND_WET))
	server.world.set_voxel(far, Voxels.of_block(Tiles.Block.STRAWBERRIES_3))
	transport.send(Msg.pick(far))
	server.process_messages()
	assert_eq(Voxels.block_of(server.world.voxel_at(far)), Tiles.Block.STRAWBERRIES_3)
	assert_false(Picking.can_pick(Voxels.of_block(Tiles.Block.WHEAT_3)), "wheat is reaped")
	# Broken ripe, a tomato plant gives its fruit and its seed.
	var rng := RandomNumberGenerator.new()
	var gifts := Items.drops(Voxels.of_block(Tiles.Block.TOMATOES_3), Vector2i.ZERO, rng)
	assert_eq(gifts[0].x, Items.Id.TOMATO)
	assert_eq(gifts[1], Vector2i(Items.Id.TOMATO_SEEDS, 1))


func test_grapes_climb_a_trellis() -> void:
	_field()
	var voxel_at := _server.world.voxel_at
	var trellis := Items.placed_voxel(Items.Id.TRELLIS)
	var cell := Vector3i(4, SEA, 4)
	assert_eq(Mining.placement(cell, trellis, Vector2i(0, 1), voxel_at), {cell: trellis})
	var grapes := Items.placed_voxel(Items.Id.GRAPE_SEEDS)
	assert_true(Mining.placement(cell, grapes, Vector2i(0, 1), voxel_at).is_empty(), "no trellis")
	_server.world.set_voxel(cell, trellis)
	assert_true(Mining.fills(_at(4, 0, 4), grapes), "sown into the trellis")
	assert_eq(Mining.placement(cell, grapes, Vector2i(0, 1), voxel_at), {cell: grapes})
	assert_false(Mining.is_replaceable(trellis), "a trellis stays")
	_server.world.set_voxel(cell, grapes)
	for i in 3:
		Growth.update(_server, 1.0)
	assert_eq(_block(4, 0, 4), Tiles.Block.GRAPES_3, "grown on grass")
	var rng := RandomNumberGenerator.new()
	var gifts := Items.drops(_at(4, 0, 4), Vector2i.ZERO, rng)
	assert_eq(gifts[0], Vector2i(Items.Id.TRELLIS, 1), "its trellis back")
	assert_eq(gifts[1].x, Items.Id.GRAPES)
	var young := Items.drops(Voxels.of_block(Tiles.Block.GRAPES_1), Vector2i.ZERO, rng)
	assert_eq(young, [Vector2i(Items.Id.TRELLIS, 1), Vector2i(Items.Id.GRAPE_SEEDS, 1)])


func test_grown_stems_bear_their_fruit_beside_them() -> void:
	_field()
	_put(0, -1, 0, Voxels.of_ground(Tiles.Ground.FARMLAND_WET))
	_put(0, 0, 0, Voxels.of_block(Tiles.Block.PUMPKIN_STEM_2))
	# Stone all around but on one side: the fruit goes there.
	for side: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		_put(side.x, 0, side.y, Voxels.of_block(Tiles.Block.STONE))
	Growth.update(_server, 1.0)
	assert_eq(_block(0, 0, 0), Tiles.Block.PUMPKIN_STEM_3, "grown")
	Growth.update(_server, 1.0)
	assert_eq(_block(1, 0, 0), Tiles.Block.PUMPKIN, "a pumpkin beside it")
	Growth.update(_server, 1.0)
	assert_eq(_block(0, 0, 0), Tiles.Block.PUMPKIN_STEM_3, "the stem stays")
	_put(1, 0, 0, Voxels.AIR)
	Growth.update(_server, 1.0)
	assert_eq(_block(1, 0, 0), Tiles.Block.PUMPKIN, "another once taken")
	_put(1, 0, 0, Voxels.AIR)
	_put(1, -1, 0, Voxels.of_block(Tiles.Block.STONE))
	Growth.update(_server, 1.0)
	assert_eq(_at(1, 0, 0), Voxels.AIR, "never on stone")
	assert_true(Voxels.is_solid(Voxels.of_block(Tiles.Block.PUMPKIN)), "stood on, not through")
	assert_true(ObjectShapes.stand_height(Tiles.Block.PUMPKIN) > 0.5)
	var rng := RandomNumberGenerator.new()
	var slices := Items.drops(Voxels.of_block(Tiles.Block.MELON), Vector2i.ZERO, rng)
	assert_true(slices[0].x == Items.Id.MELON_SLICE and slices[0].y >= 3, "a melon in slices")
	var pumpkin := Items.drops(Voxels.of_block(Tiles.Block.PUMPKIN), Vector2i.ZERO, rng)
	assert_eq(pumpkin, [Vector2i(Items.Id.PUMPKIN, 1)])


func test_fruit_trees_blossom_bear_fruit_and_are_picked() -> void:
	_field()
	var pips := Items.placed_voxel(Items.Id.APPLE_SEEDS)
	var cell := Vector3i(0, SEA, 0)
	var voxel_at := _server.world.voxel_at
	assert_eq(Mining.placement(cell, pips, Vector2i(0, 1), voxel_at), {cell: pips}, "in grass")
	_server.world.set_voxel(cell, pips)
	for i in 2:
		Growth.update(_server, 1.0)
	assert_eq(_block(0, 0, 0), Tiles.Block.APPLE_TREE, "a tree in blossom")
	Growth.update(_server, 1.0)
	assert_eq(_block(0, 0, 0), Tiles.Block.APPLE_TREE_FRUIT, "bearing apples")
	assert_eq(
		ObjectShapes.trunk(Tiles.Block.APPLE_TREE, 3),
		ObjectShapes.trunk(Tiles.Block.APPLE_TREE_FRUIT, 3),
		"the same tree"
	)
	assert_eq(Picking.PICKED[Tiles.Block.APPLE_TREE_FRUIT], Tiles.Block.APPLE_TREE)
	var rng := RandomNumberGenerator.new()
	var felled := Items.drops(_at(0, 0, 0), Vector2i.ZERO, rng)
	assert_eq(felled[0].x, Items.Id.OAK_LOG)
	assert_eq(felled[2].x, Items.Id.APPLE_SEEDS, "its pips")
	assert_eq(felled[3].x, Items.Id.APPLE, "and its fruit")
	# Compost makes one in blossom bear at once.
	_put(0, 0, 0, Voxels.of_block(Tiles.Block.CHERRY_TREE))
	var chunk: ChunkData = _server.world.chunks[Vector2i.ZERO]
	assert_eq(
		Composting.spread_on(_server.world, cell, _at(0, 0, 0)),
		Voxels.of_block(Tiles.Block.CHERRY_TREE_FRUIT)
	)
	assert_true(chunk.growing.has(cell), "noted to bear fruit")


func test_raspberries_and_peaches_are_picked() -> void:
	var made := _player()
	var server: GameServer = made[0]
	var transport: LocalTransport = made[1]
	var session: GameServer.PlayerSession = made[2]
	server.clock.set_frozen(WorldClock.FROZEN_NOON)
	var tile := Coords.world_to_tile(session.position)
	var bed := Vector3i(tile.x + 1, SEA - 1, tile.y)
	server.world.set_voxel(bed, Voxels.of_ground(Tiles.Ground.FARMLAND_WET))
	server.world.set_voxel(bed + Vector3i.UP, Voxels.of_block(Tiles.Block.RASPBERRIES_3))
	transport.send(Msg.pick(bed + Vector3i.UP))
	server.process_messages()
	var picked := Voxels.block_of(server.world.voxel_at(bed + Vector3i.UP))
	assert_eq(picked, Tiles.Block.RASPBERRIES_2, "the canes stay")
	assert_true(_count(session.inventory, Items.Id.RASPBERRY) >= 2, "raspberries in the bag")
	# A peach pit grows into a tree in blossom, then bearing peaches.
	var cell := Vector3i(tile.x - 2, SEA, tile.y)
	var pit := Items.placed_voxel(Items.Id.PEACH_PIT)
	assert_eq(Mining.placement(cell, pit, Vector2i(0, 1), server.world.voxel_at), {cell: pit})
	server.world.set_voxel(cell, pit)
	for i in 3:
		Growth.update(server, 1.0)
	assert_eq(Voxels.block_of(server.world.voxel_at(cell)), Tiles.Block.PEACH_TREE_FRUIT)
	transport.send(Msg.pick(cell))
	server.process_messages()
	assert_eq(
		Voxels.block_of(server.world.voxel_at(cell)), Tiles.Block.PEACH_TREE, "blossoms again"
	)
	assert_true(_count(session.inventory, Items.Id.PEACH) >= 2, "peaches in the bag")
	var cells := PackedInt32Array()
	cells.resize(Inventory.OWN_GRID * Inventory.OWN_GRID)
	cells[0] = Items.Id.PEACH
	assert_eq(Recipes.result_of(cells, Inventory.OWN_GRID), Vector2i(Items.Id.PEACH_PIT, 1))
	assert_true(Items.FOOD.has(Items.Id.RASPBERRY) and Items.FOOD.has(Items.Id.PEACH))


func test_a_tree_falls_only_when_it_is_gone() -> void:
	var fruit := Voxels.of_block(Tiles.Block.PEACH_TREE_FRUIT)
	var blossom := Voxels.of_block(Tiles.Block.PEACH_TREE)
	assert_true(BlockInteraction.fells(fruit, Voxels.AIR), "felled")
	assert_false(BlockInteraction.fells(fruit, blossom), "picked: the same tree in blossom")
	assert_false(BlockInteraction.fells(blossom, fruit), "bearing fruit")
	var young := Voxels.of_block(Tiles.Block.YOUNG_OAK)
	assert_false(BlockInteraction.fells(young, Voxels.of_block(Tiles.Block.OAK)), "grown up")
	assert_false(BlockInteraction.fells(Voxels.AIR, young))


func test_wild_plants_and_fruit_trees_grow_in_the_world() -> void:
	var generator := WorldGenerator.new(42)
	var found := {}
	var blossoms := 0
	# Plains and meadows, a flower forest, a swamp, a jungle (seed 42).
	for center: Vector2i in [
		Vector2i(-12, 21), Vector2i(-119, -12), Vector2i(-334, -498), Vector2i(4, -6)
	]:
		var base := Coords.tile_to_chunk(center)
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				var chunk := generator.generate_chunk(base + Vector2i(dx, dz))
				blossoms += chunk.growing.size()
				for lz in GameConst.CHUNK_SIZE:
					for lx in GameConst.CHUNK_SIZE:
						var block := Voxels.block_of(chunk.object_on_surface(Vector2i(lx, lz)))
						if (
							Farming.WILD.has(block)
							or SurfaceBuilder.WILD_FRUITS.has(block)
							or Picking.PICKED.has(block)
							or Growth.FRUITING.has(block)
						):
							found[block] = found.get(block, 0) + 1
	assert_true(found.size() >= 4, "wild plants and fruit trees: %s" % found)
	assert_true(blossoms > 0, "fruit trees in blossom are noted to bear fruit")


func test_what_the_new_crops_make() -> void:
	var grid := func(items: Array) -> PackedInt32Array:
		var cells := PackedInt32Array()
		cells.resize(Inventory.OWN_GRID * Inventory.OWN_GRID)
		for i in items.size():
			cells[i] = items[i]
		return cells
	var width := Inventory.OWN_GRID
	var none := Items.Id.NONE
	var flax := Items.Id.FLAX
	assert_eq(Recipes.result_of(grid.call([Items.Id.PUMPKIN]), width).x, Items.Id.PUMPKIN_SEEDS)
	assert_eq(Recipes.result_of(grid.call([Items.Id.SUGAR_CANE]), width).x, Items.Id.SUGAR)
	assert_eq(Recipes.result_of(grid.call([Items.Id.BEETROOT]), width).x, Items.Id.SUGAR)
	assert_eq(Recipes.result_of(grid.call([flax]), width).x, Items.Id.STRING)
	assert_eq(
		Recipes.result_of(grid.call([flax, flax, none, flax, flax]), width),
		Vector2i(Items.Id.LINEN, 1)
	)
	assert_eq(Recipes.result_of(grid.call([Items.Id.APPLE]), width).x, Items.Id.APPLE_SEEDS)
	var stick := Items.Id.STICK
	var trellis := [stick, none, stick, stick, stick, stick, stick, none, stick]
	assert_eq(Recipes.result_of(grid.call(trellis), width), Vector2i(Items.Id.TRELLIS, 2))
	var oven := Tiles.Block.FOOD_FURNACE
	assert_eq(Smelting.result_of(oven, Items.Id.CORN), Items.Id.ROASTED_CORN)
	assert_true(Items.FOOD[Items.Id.ROASTED_CORN] > Items.FOOD[Items.Id.CORN], "cooked feeds more")
	for item: int in [Items.Id.CABBAGE, Items.Id.GRAPES, Items.Id.APPLE_SEEDS, Items.Id.FLAX]:
		assert_true(Composting.COMPOSTABLE.has(item), "%s composts" % Items.name_key(item))
	var rng := RandomNumberGenerator.new()
	for wild: int in Farming.WILD:
		var gifts := Items.drops(Voxels.of_block(wild), Vector2i.ZERO, rng)
		assert_false(gifts.is_empty(), "a wild plant gives something")
		assert_true(Mining.is_replaceable(Voxels.of_block(wild)), "a wild plant is a small plant")
