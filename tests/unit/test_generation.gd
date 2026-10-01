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
		for lz in GameConst.CHUNK_SIZE:
			for lx in GameConst.CHUNK_SIZE:
				var local := Vector2i(lx, lz)
				var top := chunk.top_row(local)
				var surface := chunk.surface_voxel(local)
				assert_true(top > GameConst.SEA_LEVEL - 2, "terrain near or above sea level")
				if Voxels.is_liquid(surface):
					var swamp := Voxels.ground_of(surface) == Tiles.Ground.SWAMP_WATER
					assert_true(swamp or top == GameConst.SEA_LEVEL, "the sea at sea level")
				var thing := chunk.object_on_surface(local)
				if thing == Voxels.of_block(Tiles.Block.LILY_PAD):
					assert_true(Voxels.is_liquid(surface), "lily pads float")
				elif thing != Voxels.AIR and not Voxels.is_cube(thing):
					assert_true(Voxels.is_cube(surface), "plants grow on ground")


func test_terrain_heights_match_the_columns() -> void:
	var generator := WorldGenerator.new(SEED)
	# A hilly area, across a chunk border.
	var base := Coords.tile_to_chunk(Vector2i(76, 123))
	for coord in [base, base + Vector2i.RIGHT]:
		var chunk := generator.generate_chunk(coord)
		var origin := Coords.chunk_origin_tile(coord)
		for lz in range(0, GameConst.CHUNK_SIZE, 5):
			for lx in [0, 15]:
				var column := generator.sample_column(origin.x + lx, origin.y + lz)
				var row := GameConst.SEA_LEVEL + column.level - 1
				var voxel := chunk.get_voxel(Vector3i(lx, row, lz))
				assert_true(Voxels.is_cube(voxel) or Voxels.is_liquid(voxel), "surface voxel")
				assert_false(
					Voxels.is_cube(chunk.get_voxel(Vector3i(lx, row + 2, lz))), "air above it"
				)


func test_generation_is_deterministic() -> void:
	var a := WorldGenerator.new(12345).generate_chunk(Vector2i(-3, 7))
	var b := WorldGenerator.new(12345).generate_chunk(Vector2i(-3, 7))
	assert_eq(a.voxels, b.voxels)
	assert_eq(a.biome, b.biome)


func test_different_seeds_give_different_worlds() -> void:
	var differences := 0
	for i in 4:
		var coord := Vector2i(i * 5, -i * 3)
		var a := WorldGenerator.new(1).generate_chunk(coord)
		var b := WorldGenerator.new(2).generate_chunk(coord)
		if a.voxels != b.voxels:
			differences += 1
	assert_true(differences > 0)


func test_spawn_is_safe() -> void:
	for world_seed in [1, 42, 987654321, -5]:
		var generator := WorldGenerator.new(world_seed)
		var spawn := generator.find_spawn_tile()
		var chunk := generator.generate_chunk(Coords.tile_to_chunk(spawn))
		var local := Coords.tile_to_local(spawn)
		assert_true(WorldGenerator.is_free_ground(chunk, local), "seed %d" % world_seed)
		assert_true(WorldGenerator.SPAWN_BIOMES.has(chunk.get_biome(local)), "seed %d" % world_seed)


func test_caves_and_ores_underground() -> void:
	var generator := WorldGenerator.new(SEED)
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var deepslate := Voxels.of_block(Tiles.Block.DEEPSLATE)
	var water := Voxels.of_ground(Tiles.Ground.WATER)
	var lava := Voxels.of_ground(Tiles.Ground.LAVA)
	var open := 0
	var total := 0
	for cz in 3:
		for cx in 3:
			var chunk := generator.generate_chunk(Vector2i(cx * 3, cz * 3))
			for column in GameConst.CHUNK_AREA:
				var base := column * GameConst.WORLD_HEIGHT
				var top: int = chunk.tops[column]
				for y in top - 1:
					var voxel := chunk.voxels[base + y]
					if y < CaveGenerator.MIN_ROW:
						assert_true(Voxels.is_cube(voxel), "the bottom of the world is solid")
					if y >= top - 4 and y < top:
						assert_ne(voxel, Voxels.AIR, "caves never break through the terrain")
					if y >= CaveGenerator.MIN_ROW and y < GameConst.SEA_LEVEL - 8:
						total += 1
						if voxel == Voxels.AIR:
							open += 1
					if voxel == lava:
						assert_true(y < CaveGenerator.LAVA_BELOW_ROW, "lava only deep down")
					if voxel == water and y < GameConst.SEA_LEVEL - 14:
						assert_true(y >= CaveGenerator.LAKES_FROM_ROW, "lakes near the top")
					if voxel == deepslate:
						assert_true(y < CaveGenerator.DEEPSLATE_ROW, "deepslate deep down")
					if voxel == stone:
						assert_true(y >= CaveGenerator.DEEPSLATE_ROW, "stone above it")
					_check_ore_row(voxel, y)
	var ratio := float(open) / total
	assert_true(ratio > 0.03 and ratio < 0.35, "open ratio %.2f" % ratio)


func _check_ore_row(voxel: int, y: int) -> void:
	for ore: Array in CaveGenerator.ORES:
		if voxel == Voxels.of_block(ore[0]):
			assert_true(y >= ore[1] - 1 and y <= ore[2] + 1, "%s at row %d" % [ore[0], y])


func test_map_renderer_sizes() -> void:
	var generator := WorldGenerator.new(SEED)
	var surface := WorldMapRenderer.render(generator, Msg.MAP_SURFACE, Vector2i.ZERO, 32, 4)
	var cut := WorldMapRenderer.render(generator, 30, Vector2i.ZERO, 32, 1)
	assert_eq(surface.get_size(), Vector2i(32, 32))
	assert_eq(cut.get_size(), Vector2i(32, 32))


func test_threaded_generation_matches_sync() -> void:
	var generator := WorldGenerator.new(SEED)
	var queue := ChunkGenerationQueue.new(generator, true)
	var keys: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	for key in keys:
		assert_true(queue.request(key))
	queue.wait_all()
	var chunks := queue.collect()
	assert_eq(chunks.size(), keys.size())
	assert_eq(queue.pending_count(), 0)
	for chunk in chunks:
		var expected := generator.generate_chunk(chunk.coord)
		assert_eq(chunk.voxels, expected.voxels)


func test_every_tile_has_an_atlas_cell() -> void:
	var ground_rows := TerrainRenderer.GROUND_ATLAS.get_height() / GameConst.TILE_SIZE
	assert_true(Tiles.Ground.size() <= ground_rows, "ground atlas has a row per ground")
	for block in VoxelModels.modeled_blocks():
		for variant in VoxelModels.VARIANTS:
			for lod in VoxelModels.LODS:
				var path := VoxelModels.block_path(block, variant, lod)
				assert_true(ResourceLoader.exists(path), "%s exists (tools/gen_models.gd)" % path)
	for part in VoxelModels.PLAYER_PARTS:
		assert_true(ResourceLoader.exists(VoxelModels.player_path(part)), part)
	for block: int in Tiles.CUBE_BLOCKS:
		assert_true(TileAtlas.WALL_KINDS.has(block), "cube block %d has a wall atlas row" % block)
	var wall_rows := TerrainRenderer.WALL_ATLAS.get_height() / GameConst.TILE_SIZE
	assert_eq(wall_rows, TileAtlas.WALL_KINDS.size(), "one wall atlas row per wall kind")
