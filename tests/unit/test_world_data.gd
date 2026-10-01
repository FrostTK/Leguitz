extends TestCase

const SEA := GameConst.SEA_LEVEL


## A chunk of grass at level `level` on dirt and stone.
static func _flat_chunk(level := 0) -> ChunkData:
	var chunk := ChunkData.new(Vector2i(2, -3))
	for lz in GameConst.CHUNK_SIZE:
		for lx in GameConst.CHUNK_SIZE:
			for y in SEA + level:
				var ground := Tiles.Ground.GRASS if y == SEA + level - 1 else Tiles.Ground.DIRT
				chunk.set_voxel(Vector3i(lx, y, lz), Voxels.of_ground(ground))
	return chunk


func test_voxel_ids_keep_grounds_and_blocks_apart() -> void:
	var grass := Voxels.of_ground(Tiles.Ground.GRASS)
	var oak := Voxels.of_block(Tiles.Block.OAK)
	assert_eq(Voxels.ground_of(grass), Tiles.Ground.GRASS)
	assert_eq(Voxels.block_of(grass), Tiles.Block.AIR)
	assert_eq(Voxels.block_of(oak), Tiles.Block.OAK)
	assert_eq(Voxels.ground_of(oak), Tiles.Ground.NONE)
	assert_eq(Voxels.of_block(Tiles.Block.AIR), Voxels.AIR)
	assert_true(Tiles.Ground.size() <= Voxels.BLOCK_BASE, "grounds fit below the blocks")
	assert_true(Voxels.BLOCK_BASE + Tiles.Block.size() < Voxels.UNKNOWN, "blocks fit in a byte")


func test_voxel_flags() -> void:
	var grass := Voxels.of_ground(Tiles.Ground.GRASS)
	var water := Voxels.of_ground(Tiles.Ground.WATER)
	var lava := Voxels.of_ground(Tiles.Ground.LAVA)
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var oak := Voxels.of_block(Tiles.Block.OAK)
	var flower := Voxels.of_block(Tiles.Block.FLOWER_RED)
	assert_true(Voxels.is_cube(grass) and Voxels.is_solid(grass))
	assert_true(Voxels.is_cube(stone))
	assert_true(
		Voxels.is_liquid(water) and not Voxels.is_solid(water) and not Voxels.is_cube(water)
	)
	assert_true(Voxels.is_liquid(lava) and Voxels.is_solid(lava), "lava blocks for now")
	assert_true(Voxels.is_object(oak) and Voxels.is_solid(oak) and not Voxels.is_cube(oak))
	assert_true(Voxels.is_object(flower) and not Voxels.is_solid(flower), "flowers are walkable")
	assert_false(Voxels.is_solid(Voxels.AIR) or Voxels.is_object(Voxels.AIR))
	assert_true(Voxels.is_solid(Voxels.UNKNOWN), "unknown terrain blocks")


func test_chunk_voxels_and_column_tops() -> void:
	var chunk := _flat_chunk(3)
	var local := Vector2i(4, 5)
	assert_eq(chunk.top_row(local), SEA + 3)
	assert_eq(chunk.surface_height(local), 3.0)
	assert_eq(chunk.surface_voxel(local), Voxels.of_ground(Tiles.Ground.GRASS))
	var above := Vector3i(local.x, SEA + 3, local.y)
	chunk.set_voxel(above, Voxels.of_block(Tiles.Block.OAK))
	assert_eq(chunk.top_row(local), SEA + 3, "a tree is not terrain")
	assert_eq(chunk.object_on_surface(local), Voxels.of_block(Tiles.Block.OAK))
	chunk.set_voxel(above, Voxels.of_block(Tiles.Block.STONE))
	assert_eq(chunk.top_row(local), SEA + 4, "a placed cube raises the column")
	chunk.set_voxel(above, Voxels.AIR)
	chunk.set_voxel(Vector3i(local.x, SEA + 2, local.y), Voxels.AIR)
	assert_eq(chunk.top_row(local), SEA + 2, "digging lowers it")
	chunk.set_voxel(Vector3i(local.x, SEA + 1, local.y), Voxels.of_ground(Tiles.Ground.WATER))
	assert_almost(chunk.surface_height(local), 2.0 - ChunkData.WATER_DROP)
	var copy := ChunkData.new(chunk.coord)
	copy.voxels = chunk.voxels.duplicate()
	copy.recompute_tops()
	assert_eq(copy.tops, chunk.tops, "recomputed tops match the kept ones")


func test_chunk_duplicate_is_independent() -> void:
	var chunk := _flat_chunk()
	var copy := chunk.duplicate_chunk()
	copy.set_voxel(Vector3i(1, SEA, 1), Voxels.of_block(Tiles.Block.STONE))
	assert_eq(chunk.get_voxel(Vector3i(1, SEA, 1)), Voxels.AIR)
	assert_eq(chunk.top_row(Vector2i(1, 1)), SEA)


func test_chunk_serialization_round_trip() -> void:
	var chunk := WorldGenerator.new(7).generate_chunk(Vector2i(-4, 9))
	var copy := ChunkData.from_dict(bytes_to_var(var_to_bytes(chunk.to_dict())))
	assert_eq(copy.coord, chunk.coord)
	assert_eq(copy.voxels, chunk.voxels)
	assert_eq(copy.biome, chunk.biome)
	assert_eq(copy.tops, chunk.tops)


func test_world_settings_round_trip() -> void:
	var settings := WorldSettings.create("Test", "hello", WorldSettings.GameMode.HARDCORE)
	assert_eq(settings.world_seed, HashUtil.seed_from_text("hello"))
	var copy := WorldSettings.new()
	copy.load_dict(settings.to_dict())
	assert_eq(copy.world_name, "Test")
	assert_eq(copy.world_seed, settings.world_seed)
	assert_eq(copy.game_mode, WorldSettings.GameMode.HARDCORE)


func test_world_state_finds_floors_below_and_above() -> void:
	var world := WorldState.new(WorldGenerator.new(42))
	var spawn := world.generator.find_spawn_tile()
	var surface := world.surface_height(spawn)
	var found := world.find_floor(spawn, surface, -1)
	assert_false(found.is_empty(), "a cave somewhere under the spawn")
	var tile: Vector2i = found[0]
	var height: float = found[1]
	assert_true(height < surface - 2.0, "below the surface")
	assert_true(world.can_stand(tile, int(height) + SEA), "on a floor with room above")
	var back := world.next_floor(tile, height, 1)
	assert_false(is_nan(back), "and a way back up")
	assert_true(back > height)
