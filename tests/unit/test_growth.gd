extends TestCase
## What grows by itself (Growth): saplings planted in soil become young
## trees then trees, in the light and with room; bare dirt next to grass
## turns green; what trees give; the growing cells are saved.

const SEA := GameConst.SEA_LEVEL
const FOLDER := "user://test_worlds/growth"

var _server: GameServer


## An open field around the origin: grass at row SEA - 1 over stone, air
## above up to SEA + 12, at noon.
func _field() -> GameServer:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	_server = GameServer.new(settings, null, false)
	_server.clock.set_frozen(WorldClock.FROZEN_NOON)
	var stone := Voxels.of_block(Tiles.Block.STONE)
	for x in range(-10, 11):
		for z in range(-10, 11):
			for y in range(SEA - 3, SEA + 13):
				var voxel := Voxels.AIR
				if y < SEA - 1:
					voxel = stone
				elif y == SEA - 1:
					voxel = Voxels.of_ground(Tiles.Ground.GRASS)
				_server.world.set_voxel(Vector3i(x, y, z), voxel)
	return _server


func _block(x: int, z: int) -> int:
	return Voxels.block_of(_server.world.voxel_at(Vector3i(x, SEA, z)))


func _plant(x: int, z: int, block: int) -> void:
	_server.world.set_voxel(Vector3i(x, SEA, z), Voxels.of_block(block))


func test_saplings_go_in_soil_only() -> void:
	var sapling := Items.placed_voxel(Items.Id.OAK_SAPLING)
	var grass := Voxels.of_ground(Tiles.Ground.GRASS)
	var on := func(ground: int) -> Callable:
		return func(cell: Vector3i) -> int: return ground if cell.y < SEA else Voxels.AIR
	var cell := Vector3i(0, SEA, 0)
	assert_eq(Mining.placement(cell, sapling, Vector2i(0, 1), on.call(grass)), {cell: sapling})
	var dirt := Voxels.of_ground(Tiles.Ground.DIRT)
	assert_false(Mining.placement(cell, sapling, Vector2i(0, 1), on.call(dirt)).is_empty())
	var stone := Voxels.of_block(Tiles.Block.STONE)
	assert_true(Mining.placement(cell, sapling, Vector2i(0, 1), on.call(stone)).is_empty())
	var water := func(at: Vector3i) -> int:
		return grass if at.y < SEA else Voxels.of_ground(Tiles.Ground.WATER)
	assert_true(Mining.placement(cell, sapling, Vector2i(0, 1), water).is_empty(), "not in water")
	assert_false(Tiles.is_block_solid(Tiles.Block.OAK_SAPLING), "bodies walk through it")


func test_a_sapling_grows_into_a_tree_in_the_light() -> void:
	_field()
	_plant(0, 0, Tiles.Block.OAK_SAPLING)
	var chunk: ChunkData = _server.world.chunks[Vector2i.ZERO]
	assert_true(chunk.growing.has(Vector3i(0, SEA, 0)), "noted")
	Growth.update(_server, 1.0)
	assert_eq(_block(0, 0), Tiles.Block.YOUNG_OAK)
	assert_true(Tiles.is_block_solid(Tiles.Block.YOUNG_OAK), "its trunk blocks bodies")
	Growth.update(_server, 1.0)
	assert_eq(_block(0, 0), Tiles.Block.OAK, "a tree")
	assert_false(chunk.growing.has(Vector3i(0, SEA, 0)), "done growing")
	# Never by chance alone: on average after its time.
	_plant(4, 4, Tiles.Block.BIRCH_SAPLING)
	Growth.update(_server, 0.0)
	assert_eq(_block(4, 4), Tiles.Block.BIRCH_SAPLING)


func test_the_dark_a_roof_or_a_neighbor_stop_it() -> void:
	_field()
	_server.clock.set_frozen(WorldClock.FROZEN_MIDNIGHT)
	_plant(0, 0, Tiles.Block.OAK_SAPLING)
	Growth.update(_server, 1.0)
	assert_eq(_block(0, 0), Tiles.Block.OAK_SAPLING, "not at night")
	_plant(1, 0, Tiles.Block.TORCH)
	Growth.update(_server, 1.0)
	assert_eq(_block(0, 0), Tiles.Block.YOUNG_OAK, "a torch is light enough")
	_server.clock.set_frozen(WorldClock.FROZEN_NOON)
	# No room: stone two rows up.
	_plant(-5, -5, Tiles.Block.SPRUCE_SAPLING)
	_server.world.set_voxel(Vector3i(-5, SEA + 2, -5), Voxels.of_block(Tiles.Block.STONE))
	Growth.update(_server, 1.0)
	assert_eq(_block(-5, -5), Tiles.Block.SPRUCE_SAPLING, "no room over it")
	# A rock right beside: bodies could not pass between.
	_plant(5, -5, Tiles.Block.ACACIA_SAPLING)
	_plant(6, -5, Tiles.Block.ROCK)
	Growth.update(_server, 1.0)
	assert_eq(_block(5, -5), Tiles.Block.ACACIA_SAPLING, "too close to a rock")
	assert_eq(
		Growth.tree_for(Tiles.Block.YOUNG_SPRUCE, Biomes.Id.SNOWY_TAIGA), Tiles.Block.SNOWY_SPRUCE
	)
	assert_eq(Growth.tree_for(Tiles.Block.YOUNG_SPRUCE, Biomes.Id.TAIGA), Tiles.Block.SPRUCE)


func test_bare_dirt_turns_green_next_to_grass() -> void:
	_field()
	var dirt := Voxels.of_ground(Tiles.Ground.DIRT)
	_server.world.set_voxel(Vector3i(2, SEA - 1, 2), dirt)
	Growth.update(_server, 1.0)
	assert_eq(_server.world.voxel_at(Vector3i(2, SEA - 1, 2)), Voxels.of_ground(Tiles.Ground.GRASS))
	# Under a block it stays dirt (and is forgotten).
	_server.world.set_voxel(Vector3i(-2, SEA - 1, 2), dirt)
	_server.world.set_voxel(Vector3i(-2, SEA, 2), Voxels.of_block(Tiles.Block.STONE))
	Growth.update(_server, 1.0)
	assert_eq(_server.world.voxel_at(Vector3i(-2, SEA - 1, 2)), dirt)
	var chunk: ChunkData = _server.world.chunks[Coords.tile_to_chunk(Vector2i(-2, 2))]
	assert_false(chunk.growing.has(Vector3i(-2, SEA - 1, 2)))
	# Breaking what lay on dirt lays it bare: it is noted again.
	_server.world.set_voxel(Vector3i(-2, SEA, 2), Voxels.AIR)
	assert_true(chunk.growing.has(Vector3i(-2, SEA - 1, 2)))


func test_trees_give_saplings_and_growing_cells_are_saved() -> void:
	var rng := RandomNumberGenerator.new()
	var oak := Items.drops(Voxels.of_block(Tiles.Block.OAK), Vector2i(3, 4), rng)
	var items := oak.map(func(drop: Vector2i) -> int: return drop.x)
	assert_true(items.has(Items.Id.OAK_SAPLING), "a felled tree gives saplings")
	var young := Items.drops(Voxels.of_block(Tiles.Block.YOUNG_SPRUCE), Vector2i(3, 4), rng)
	assert_eq(young[0], Vector2i(Items.Id.SPRUCE_SAPLING, 1), "a young one its sapling back")
	var snowy := Items.drops(Voxels.of_block(Tiles.Block.SNOWY_SPRUCE), Vector2i(3, 4), rng)
	assert_true(snowy.map(func(d: Vector2i) -> int: return d.x).has(Items.Id.SPRUCE_SAPLING))
	# Saved with the chunk.
	var storage := WorldStorage.new(FOLDER)
	storage.erase()
	var chunk := ChunkData.new(Vector2i(2, 3))
	chunk.growing[Vector3i(33, SEA, 50)] = true
	storage.store_chunk(chunk)
	assert_true(storage.flush())
	var loaded := WorldStorage.new(FOLDER).load_chunk(Vector2i(2, 3))
	assert_true(loaded.growing.has(Vector3i(33, SEA, 50)))
	storage.erase()
