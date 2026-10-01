extends TestCase


func test_chunk_get_set() -> void:
	var chunk := ChunkData.new(Vector2i(2, -3), -2)
	chunk.set_ground(Vector2i(3, 4), Tiles.Ground.SAND)
	chunk.set_block(Vector2i(15, 15), Tiles.Block.ROCK)
	assert_eq(chunk.get_ground(Vector2i(3, 4)), Tiles.Ground.SAND)
	assert_eq(chunk.get_block(Vector2i(15, 15)), Tiles.Block.ROCK)
	assert_eq(chunk.get_block(Vector2i(0, 0)), Tiles.Block.AIR)
	assert_eq(chunk.key(), Vector3i(2, -3, -2))


func test_solidity_rules() -> void:
	var chunk := ChunkData.new()
	chunk.ground.fill(Tiles.Ground.GRASS)
	var tile := Vector2i(4, 4)
	assert_false(chunk.is_solid(tile))
	chunk.set_block(tile, Tiles.Block.FLOWER_RED)
	assert_false(chunk.is_solid(tile), "flowers are walkable")
	chunk.set_block(tile, Tiles.Block.OAK)
	assert_true(chunk.is_solid(tile), "trees block")
	chunk.set_block(tile, Tiles.Block.AIR)
	chunk.shapes[Coords.local_index(tile)] = ChunkData.SHAPE_LOWER_S
	assert_false(chunk.is_solid(tile), "a cliff edge is ground like any other (heights decide)")
	chunk.shapes[Coords.local_index(tile)] = 0
	chunk.set_ground(tile, Tiles.Ground.LAVA)
	assert_true(chunk.is_solid(tile), "lava blocks for now")


func test_top_heights() -> void:
	var chunk := ChunkData.new()
	chunk.ground.fill(Tiles.Ground.GRASS)
	var tile := Vector2i(4, 4)
	chunk.levels[Coords.local_index(tile)] = 3
	assert_eq(chunk.top_height(tile), 3.0)
	chunk.set_block(tile, Tiles.Block.STONE)
	assert_eq(chunk.top_height(tile), 4.0, "a cube block can be climbed on the surface")
	chunk.set_block(tile, Tiles.Block.OAK)
	assert_eq(chunk.top_height(tile), INF, "nobody stands on a tree")
	chunk.set_block(tile, Tiles.Block.FLOWER_BLUE)
	assert_eq(chunk.top_height(tile), 3.0, "flowers are walked through")
	chunk.set_ground(tile, Tiles.Ground.WATER)
	assert_almost(chunk.top_height(tile), 3.0 - ChunkData.WATER_DROP)
	var cave := ChunkData.new(Vector2i.ZERO, -2)
	cave.ground.fill(Tiles.Ground.STONE_FLOOR)
	cave.set_block(tile, Tiles.Block.STONE)
	assert_eq(cave.top_height(tile), INF, "underground, rock fills the layer")


func test_chunk_duplicate_is_independent() -> void:
	var chunk := ChunkData.new(Vector2i.ZERO)
	var copy := chunk.duplicate_chunk()
	copy.set_block(Vector2i(1, 1), Tiles.Block.OAK)
	copy.levels[3] = 7
	assert_eq(chunk.get_block(Vector2i(1, 1)), Tiles.Block.AIR)
	assert_eq(chunk.levels[3], 0)


func test_chunk_serialization_round_trip() -> void:
	var chunk := WorldGenerator.new(7).generate_chunk(Vector2i(-4, 9))
	var copy := ChunkData.from_dict(bytes_to_var(var_to_bytes(chunk.to_dict())))
	assert_eq(copy.key(), chunk.key())
	assert_eq(copy.ground, chunk.ground)
	assert_eq(copy.blocks, chunk.blocks)
	assert_eq(copy.levels, chunk.levels)
	assert_eq(copy.shapes, chunk.shapes)
	assert_eq(copy.biome, chunk.biome)


func test_world_settings_round_trip() -> void:
	var settings := WorldSettings.create("Test", "hello", WorldSettings.GameMode.HARDCORE)
	assert_eq(settings.world_seed, HashUtil.seed_from_text("hello"))
	var copy := WorldSettings.new()
	copy.load_dict(settings.to_dict())
	assert_eq(copy.world_name, "Test")
	assert_eq(copy.world_seed, settings.world_seed)
	assert_eq(copy.game_mode, WorldSettings.GameMode.HARDCORE)


func test_world_state_find_open_tile() -> void:
	var world := WorldState.new(WorldGenerator.new(42))
	var tile := world.find_open_tile(Vector2i(10, 10), -3)
	assert_false(world.is_solid(tile, -3))
	assert_true(world.has_chunk(WorldState.key_of(tile, -3)))
