extends TestCase


func test_chunk_get_set() -> void:
	var chunk := ChunkData.new(Vector2i(2, -3))
	chunk.set_ground(Vector2i(3, 4), Tiles.Ground.SAND)
	chunk.set_block(Vector2i(15, 15), Tiles.Block.ROCK)
	assert_eq(chunk.get_ground(Vector2i(3, 4)), Tiles.Ground.SAND)
	assert_eq(chunk.get_block(Vector2i(15, 15)), Tiles.Block.ROCK)
	assert_eq(chunk.get_block(Vector2i(0, 0)), Tiles.Block.AIR)


func test_chunk_duplicate_is_independent() -> void:
	var chunk := ChunkData.new(Vector2i.ZERO)
	var copy := chunk.duplicate_chunk()
	copy.set_block(Vector2i(1, 1), Tiles.Block.TREE)
	assert_eq(chunk.get_block(Vector2i(1, 1)), Tiles.Block.AIR)


func test_chunk_serialization_round_trip() -> void:
	var chunk := ChunkData.new(Vector2i(-4, 9))
	chunk.set_ground(Vector2i(5, 6), Tiles.Ground.SNOW)
	chunk.set_block(Vector2i(7, 8), Tiles.Block.PINE)
	var copy := ChunkData.from_dict(bytes_to_var(var_to_bytes(chunk.to_dict())))
	assert_eq(copy.coord, Vector2i(-4, 9))
	assert_eq(copy.ground, chunk.ground)
	assert_eq(copy.blocks, chunk.blocks)


func test_generation_is_deterministic() -> void:
	var a := TerrainGenerator.new(12345).generate_chunk(Vector2i(-3, 7))
	var b := TerrainGenerator.new(12345).generate_chunk(Vector2i(-3, 7))
	assert_eq(a.ground, b.ground)
	assert_eq(a.blocks, b.blocks)


func test_different_seeds_give_different_worlds() -> void:
	var differences := 0
	for i in 4:
		var coord := Vector2i(i * 5, -i * 3)
		var a := TerrainGenerator.new(1).generate_chunk(coord)
		var b := TerrainGenerator.new(2).generate_chunk(coord)
		if a.ground != b.ground:
			differences += 1
	assert_true(differences > 0)


func test_spawn_is_on_free_grass() -> void:
	for world_seed in [1, 42, 987654321]:
		var generator := TerrainGenerator.new(world_seed)
		var spawn := generator.find_spawn_tile()
		var chunk := generator.generate_chunk(Coords.tile_to_chunk(spawn))
		var local := Coords.tile_to_local(spawn)
		assert_eq(chunk.get_ground(local), Tiles.Ground.GRASS, "seed %d" % world_seed)
		assert_eq(chunk.get_block(local), Tiles.Block.AIR, "seed %d" % world_seed)


func test_world_settings_round_trip() -> void:
	var settings := WorldSettings.create("Test", "hello", WorldSettings.GameMode.HARDCORE)
	assert_eq(settings.world_seed, HashUtil.seed_from_text("hello"))
	var copy := WorldSettings.new()
	copy.load_dict(settings.to_dict())
	assert_eq(copy.world_name, "Test")
	assert_eq(copy.world_seed, settings.world_seed)
	assert_eq(copy.game_mode, WorldSettings.GameMode.HARDCORE)
