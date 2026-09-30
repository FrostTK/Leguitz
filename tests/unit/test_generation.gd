extends TestCase

const SEED := 42


func test_spline_hits_points_and_clamps() -> void:
	var spline := Spline.new([[-1.0, 0.0], [0.0, 10.0], [1.0, 12.0]])
	assert_almost(spline.sample(-1.0), 0.0)
	assert_almost(spline.sample(0.0), 10.0)
	assert_almost(spline.sample(1.0), 12.0)
	assert_almost(spline.sample(-5.0), 0.0, 0.0001, "clamped below")
	assert_almost(spline.sample(5.0), 12.0, 0.0001, "clamped above")
	var previous := -INF
	for i in 101:
		var value := spline.sample(-1.0 + i * 0.02)
		assert_true(value >= previous - 0.0001, "monotone data stays monotone")
		previous = value


func test_climate_grid_is_consistent_between_rectangles() -> void:
	var sampler := ClimateSampler.new(SEED)
	var a := ClimateGrid.new(sampler, Rect2i(-37, 12, 40, 40))
	var b := ClimateGrid.new(sampler, Rect2i(-10, 30, 3, 3))
	for tile in [Vector2i(-9, 31), Vector2i(-8, 32), Vector2i(-10, 30)]:
		a.sample(tile.x, tile.y)
		b.sample(tile.x, tile.y)
		assert_eq(a.continentalness, b.continentalness)
		assert_eq(a.weirdness, b.weirdness)
		assert_eq(a.temperature, b.temperature)


func test_peaks_and_valleys() -> void:
	assert_almost(TerrainShaper.peaks_valleys(0.0), -1.0)
	assert_almost(TerrainShaper.peaks_valleys(2.0 / 3.0), 1.0)
	assert_almost(TerrainShaper.peaks_valleys(-2.0 / 3.0), 1.0)
	assert_almost(TerrainShaper.peaks_valleys(1.0 / 3.0), 0.0)


func test_biome_selection_rules() -> void:
	# Arguments: continentalness, erosion, weirdness, temperature, humidity, h, river.
	assert_true(Biomes.is_ocean(Biomes.select(-0.6, 0.0, 0.5, 0.0, 0.0, -30.0, false)))
	assert_eq(Biomes.select(0.2, 0.0, 0.01, 0.0, 0.0, -1.0, true), Biomes.Id.RIVER)
	assert_eq(Biomes.select(0.2, 0.0, 0.01, -0.8, 0.0, -1.0, true), Biomes.Id.FROZEN_RIVER)
	assert_eq(Biomes.select(0.3, 0.0, 0.5, 0.8, 0.0, 10.0, false), Biomes.Id.DESERT)
	assert_eq(Biomes.select(0.3, 0.0, 0.5, 0.0, 0.2, 10.0, false), Biomes.Id.BIRCH_FOREST)
	assert_eq(Biomes.select(0.3, -0.8, 0.7, -0.8, 0.0, 95.0, false), Biomes.Id.JAGGED_PEAKS)
	assert_eq(Biomes.select(0.3, -0.8, 0.7, 0.8, 0.0, 95.0, false), Biomes.Id.STONY_PEAKS)
	assert_eq(Biomes.select(-0.95, 0.0, 0.6, 0.0, 0.0, 3.0, false), Biomes.Id.MUSHROOM_FIELDS)


func test_world_has_varied_biomes_and_some_ocean() -> void:
	var generator := WorldGenerator.new(SEED)
	var counts := {}
	var samples := 0
	var ocean := 0
	for y in range(-3000, 3000, 96):
		for x in range(-3000, 3000, 96):
			var biome := generator.sample_column(x, y).biome
			counts[biome] = true
			samples += 1
			if Biomes.is_ocean(biome):
				ocean += 1
	var ocean_ratio := float(ocean) / samples
	assert_true(ocean_ratio > 0.15 and ocean_ratio < 0.55, "ocean ratio %.2f" % ocean_ratio)
	assert_true(counts.size() >= 20, "%d biomes found" % counts.size())


func test_surface_chunks_are_coherent() -> void:
	var generator := WorldGenerator.new(SEED)
	var spawn_chunk := Coords.tile_to_chunk(generator.find_spawn_tile())
	for offset in [Vector2i.ZERO, Vector2i(3, -2), Vector2i(-5, 4), Vector2i(20, 20)]:
		var chunk := generator.generate_chunk(spawn_chunk + offset)
		for i in GameConst.CHUNK_AREA:
			var ground := chunk.ground[i]
			var block := chunk.blocks[i]
			var shape := chunk.shapes[i]
			if Tiles.is_water(ground):
				assert_eq(chunk.levels[i], 0, "water is at sea level")
				assert_eq(shape & ChunkData.SHAPE_EDGE_MASK, 0, "water is never a cliff")
				assert_true(block == Tiles.Block.AIR or block == Tiles.Block.LILY_PAD)
			if shape & ChunkData.SHAPE_EDGE_MASK != 0:
				assert_eq(block, Tiles.Block.AIR, "nothing grows on cliff edges")


func test_cliff_edges_match_across_chunk_borders() -> void:
	var generator := WorldGenerator.new(SEED)
	# Look for a hilly area so there are cliffs to compare.
	var base := Coords.tile_to_chunk(Vector2i(76, 123))
	var left := generator.generate_chunk(base)
	var right := generator.generate_chunk(base + Vector2i.RIGHT)
	for ly in GameConst.CHUNK_SIZE:
		var a := Vector2i(15, ly)
		var b := Vector2i(0, ly)
		var lower_east := left.get_shape(a) & ChunkData.SHAPE_LOWER_E != 0
		var expected := (
			right.get_level(b) < left.get_level(a) and not Tiles.is_water(left.get_ground(a))
		)
		if not Tiles.is_water(left.get_ground(a)):
			assert_eq(lower_east, expected, "row %d" % ly)
		var lower_west := right.get_shape(b) & ChunkData.SHAPE_LOWER_W != 0
		if not Tiles.is_water(right.get_ground(b)):
			assert_eq(lower_west, left.get_level(a) < right.get_level(b), "row %d" % ly)


func test_generation_is_deterministic() -> void:
	for layer in [0, -2, -6]:
		var a := WorldGenerator.new(12345).generate_chunk(Vector2i(-3, 7), layer)
		var b := WorldGenerator.new(12345).generate_chunk(Vector2i(-3, 7), layer)
		assert_eq(a.ground, b.ground, "layer %d" % layer)
		assert_eq(a.blocks, b.blocks, "layer %d" % layer)
		assert_eq(a.shapes, b.shapes, "layer %d" % layer)


func test_different_seeds_give_different_worlds() -> void:
	var differences := 0
	for i in 4:
		var coord := Vector2i(i * 5, -i * 3)
		var a := WorldGenerator.new(1).generate_chunk(coord)
		var b := WorldGenerator.new(2).generate_chunk(coord)
		if a.ground != b.ground or a.blocks != b.blocks:
			differences += 1
	assert_true(differences > 0)


func test_spawn_is_safe() -> void:
	for world_seed in [1, 42, 987654321, -5]:
		var generator := WorldGenerator.new(world_seed)
		var spawn := generator.find_spawn_tile()
		var chunk := generator.generate_chunk(Coords.tile_to_chunk(spawn))
		var local := Coords.tile_to_local(spawn)
		assert_false(chunk.is_solid(local), "seed %d" % world_seed)
		assert_false(Tiles.is_water(chunk.get_ground(local)), "seed %d" % world_seed)
		assert_true(WorldGenerator.SPAWN_BIOMES.has(chunk.get_biome(local)), "seed %d" % world_seed)


func test_underground_layers() -> void:
	var generator := WorldGenerator.new(SEED)
	for layer in range(-1, WorldGenerator.MIN_LAYER - 1, -1):
		var depth := -layer
		var open := 0
		var total := 0
		for cy in 4:
			for cx in 4:
				var chunk := generator.generate_chunk(Vector2i(cx * 3, cy * 3), layer)
				for i in GameConst.CHUNK_AREA:
					total += 1
					var block := chunk.blocks[i]
					var ground := chunk.ground[i]
					if not Tiles.is_block_solid(block):
						open += 1
					if ground == Tiles.Ground.LAVA:
						assert_true(depth >= 5, "lava only deep down")
					if Tiles.is_water(ground):
						assert_true(depth <= 3, "lakes only near the surface")
					if depth < CaveGenerator.DEEPSLATE_DEPTH:
						assert_ne(block, Tiles.Block.DEEPSLATE)
					else:
						assert_ne(block, Tiles.Block.STONE)
					_check_ore_depth(block, depth)
		var ratio := float(open) / total
		assert_true(ratio > 0.1 and ratio < 0.5, "layer %d open ratio %.2f" % [layer, ratio])


func _check_ore_depth(block: int, depth: int) -> void:
	for ore: Array in CaveGenerator.ORES:
		if block == ore[0]:
			assert_true(depth >= ore[1] and depth <= ore[2], "%s at depth %d" % [block, depth])
	assert_ne(block, Tiles.Block.EMERALD_ORE, "emeralds only in mountains")


func test_map_renderer_sizes() -> void:
	var generator := WorldGenerator.new(SEED)
	var surface := WorldMapRenderer.render(generator, 0, Vector2i.ZERO, 32, 4)
	var underground := WorldMapRenderer.render(generator, -4, Vector2i.ZERO, 32, 1)
	assert_eq(surface.get_size(), Vector2i(32, 32))
	assert_eq(underground.get_size(), Vector2i(32, 32))


func test_threaded_generation_matches_sync() -> void:
	var generator := WorldGenerator.new(SEED)
	var queue := ChunkGenerationQueue.new(generator, true)
	var keys: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, -2)]
	for key in keys:
		assert_true(queue.request(key))
	queue.wait_all()
	var chunks := queue.collect()
	assert_eq(chunks.size(), keys.size())
	assert_eq(queue.pending_count(), 0)
	for chunk in chunks:
		var expected := generator.generate_chunk(chunk.coord, chunk.layer)
		assert_eq(chunk.blocks, expected.blocks)
		assert_eq(chunk.ground, expected.ground)


func test_every_tile_has_an_atlas_cell() -> void:
	var ground_rows := TerrainRenderer.GROUND_ATLAS.get_height() / GameConst.TILE_SIZE
	assert_true(Tiles.Ground.size() <= ground_rows, "ground atlas has a row per ground")
	var block_size := TileAtlas.BLOCK_TEXTURE.get_size() / GameConst.TILE_SIZE
	for block in range(1, Tiles.Block.size()):
		var cell := TileAtlas.block_cell(block)
		assert_true(cell.x + 1 < block_size.x and cell.y + 2 < block_size.y, "block %d" % block)
	var wall_rows := TerrainRenderer.WALL_ATLAS.get_height() / GameConst.TILE_SIZE
	assert_eq(wall_rows, TileAtlas.WALL_KINDS.size(), "one wall atlas row per wall kind")
