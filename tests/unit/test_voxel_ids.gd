extends TestCase
## Voxel ids on 16 bits: blocks far past a byte stay what they are in
## chunks, in what the server sends and in saves; worlds saved with a byte
## per voxel still load; the terrain's maps hold any wall kind.

const FOLDER := "user://test_worlds/voxel_ids"
const SEA := GameConst.SEA_LEVEL


func test_ids_past_a_byte_are_kept_everywhere() -> void:
	var far := Voxels.BLOCK_BASE + 1000
	assert_eq(Voxels.block_of(far), 1000)
	assert_eq(Voxels.ground_of(far), Tiles.Ground.NONE)
	assert_false(Voxels.is_cube(far), "an id with no block yet: nothing, no crash")
	assert_true(Voxels.is_cube(Voxels.UNKNOWN), "unknown terrain stays solid")
	assert_eq(Voxels.block_of(Voxels.UNKNOWN), Tiles.Block.AIR)
	assert_true(Voxels.UNKNOWN >= Voxels.used_ids(), "never taken by a block")
	var chunk := ChunkData.new(Vector2i(3, -2))
	chunk.set_voxel(Vector3i(1, SEA, 2), far)
	chunk.set_voxel(Vector3i(5, SEA + 1, 9), Voxels.of_block(Tiles.Block.CAMPFIRE))
	assert_eq(chunk.get_voxel(Vector3i(1, SEA, 2)), far)
	var sent := ChunkData.from_dict(chunk.duplicate_chunk().to_dict())
	assert_eq(sent.get_voxel(Vector3i(1, SEA, 2)), far, "sent")
	var storage := WorldStorage.new(FOLDER)
	storage.erase()
	storage.store_chunk(chunk)
	assert_true(storage.flush())
	var loaded := WorldStorage.new(FOLDER).load_chunk(chunk.coord)
	assert_eq(loaded.voxels, chunk.voxels, "saved and loaded")
	storage.erase()


func test_worlds_saved_a_byte_per_voxel_still_load() -> void:
	var chunk := ChunkData.new(Vector2i(0, 0))
	for lz in GameConst.CHUNK_SIZE:
		for lx in GameConst.CHUNK_SIZE:
			for y in SEA:
				chunk.set_voxel(Vector3i(lx, y, lz), Voxels.of_block(Tiles.Block.STONE))
	chunk.set_voxel(Vector3i(4, SEA, 4), Voxels.of_block(Tiles.Block.WOOL))
	chunk.set_voxel(Vector3i(4, SEA + 1, 4), Voxels.of_block(Tiles.Block.CHEST_EAST))
	# What older versions wrote: the same ids, a byte each.
	var bytes := PackedByteArray()
	for voxel in chunk.voxels:
		bytes.append(voxel)
	var storage := WorldStorage.new(FOLDER)
	storage.erase()
	storage._region(WorldStorage.region_of(chunk.coord))[chunk.coord] = {
		"voxels": bytes.compress(WorldStorage.COMPRESSION),
		"size": bytes.size(),
		"biome": chunk.biome,
	}
	var loaded := storage.load_chunk(chunk.coord)
	assert_eq(loaded.voxels, chunk.voxels, "the same voxels")
	assert_eq(loaded.tops, chunk.tops)
	storage.erase()


func test_the_maps_hold_any_wall_kind() -> void:
	# The bed under water packs a level, a ground and a wall kind in a float
	# (see bed_of in terrain3d_surface.gdshaderinc).
	for wall: int in [0, 31, 200, TileAtlas.MAX_WALL_KINDS - 1]:
		for level: int in [-SEA, 0, GameConst.WORLD_HEIGHT - SEA - 1]:
			var ground := Tiles.Ground.SAND
			var packed := ((level + 256) * 64 + ground) * 256 + wall
			var code := float(packed)
			assert_eq(int(code), packed, "exact in a float")
			var rest := int(code) / 256
			assert_eq(int(code) % 256, wall)
			assert_eq(rest % 64, ground)
			assert_eq(rest / 64 - 256, level)
	assert_eq(TileAtlas.clear_wall_flags().size(), TileAtlas.MAX_WALL_KINDS)
	assert_eq(TileAtlas.wall_lookup.size(), Tiles.Block.size(), "every block")
	assert_eq(Voxels.used_ids(), Voxels.BLOCK_BASE + Tiles.Block.size())
