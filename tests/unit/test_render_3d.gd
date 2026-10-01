extends TestCase
## The 3D view: tile to 3D mapping, chunk meshes and the sky light.


func _flat_chunk(level: int) -> ChunkData:
	var chunk := ChunkData.new(Vector2i.ZERO)
	for i in GameConst.CHUNK_AREA:
		chunk.ground[i] = Tiles.Ground.GRASS
		chunk.levels[i] = level
	return chunk


func _no_neighbor(_coord: Vector2i) -> ChunkData:
	return null


func test_world_to_3d_mapping() -> void:
	var p := Render3D.world_px_to_3d(Vector2(32, 16), 1.5)
	assert_almost(p.x, 2.0)
	assert_almost(p.y, 1.5)
	assert_almost(p.z, Render3D.z_stretch)
	var center := Render3D.tile_center_3d(Vector2i(0, 0), 0.0)
	assert_almost(center.x, 0.5)
	# A tile top and a one-level face both show 16 px on screen.
	var pitch := deg_to_rad(Render3D.PITCH_DEGREES)
	assert_almost(Render3D.z_stretch * sin(pitch), 1.0)
	assert_almost(Render3D.LEVEL_HEIGHT * cos(pitch), 1.0)


func test_flat_chunk_has_only_tops() -> void:
	var surfaces := ChunkMesher.build_surfaces(_flat_chunk(2), _no_neighbor)
	assert_eq(surfaces[0].vertices.size(), GameConst.CHUNK_AREA * 4, "one quad per tile")
	assert_true(surfaces[1].is_empty(), "no faces on flat ground")
	assert_almost(surfaces[0].vertices[0].y, 2.0 * Render3D.LEVEL_HEIGHT)


func test_step_makes_faces() -> void:
	var chunk := _flat_chunk(0)
	# Raise the northern half by one level: one east-west cliff line.
	for i in GameConst.CHUNK_AREA / 2:
		chunk.levels[i] = 1
	var surfaces := ChunkMesher.build_surfaces(chunk, _no_neighbor)
	assert_eq(surfaces[1].vertices.size(), GameConst.CHUNK_SIZE * 4, "one face per edge tile")
	for normal in surfaces[1].normals:
		assert_eq(normal, Vector3.BACK, "the cliff faces south, towards the camera")


func test_ramp_height_is_continuous() -> void:
	var world := ClientWorld.new()
	var chunk := _flat_chunk(0)
	var index := 5 * GameConst.CHUNK_SIZE + 5
	chunk.levels[index] = 1
	chunk.shapes[index] = ChunkData.SHAPE_LOWER_S | ChunkData.SHAPE_RAMP
	world.store(chunk)
	var top := ChunkMesher.height_at(world, Vector2(5.5, 5.01) * GameConst.TILE_SIZE)
	var bottom := ChunkMesher.height_at(world, Vector2(5.5, 5.99) * GameConst.TILE_SIZE)
	assert_almost(top, Render3D.LEVEL_HEIGHT, 0.05)
	assert_true(bottom < top and bottom > 0.0, "the ramp goes down towards the south")
	assert_almost(ChunkMesher.height_at(world, Vector2(1, 1) * GameConst.TILE_SIZE), 0.0)


func test_sky_light_path() -> void:
	var sunrise := LightingController.sky_direction(LightingController.sun_angle(6.0))
	var noon := LightingController.sky_direction(LightingController.sun_angle(12.75))
	var sunset := LightingController.sky_direction(LightingController.sun_angle(19.5))
	assert_true(sunrise.x > 0.8, "the sun rises in the east")
	assert_true(sunset.x < -0.8, "and sets in the west")
	assert_true(noon.z > 0.3 and absf(noon.x) < 0.05, "it culminates in the south")
	assert_true(noon.y > sunrise.y, "higher at noon")
	assert_true(sunrise.y > 0.15, "never so low that shadows cross the screen")
	var night := LightingController.sun_angle(1.0)
	assert_true(night > PI and night < TAU, "the moon's turn at night")


func test_mountain_terraces_are_double() -> void:
	var previous := 0
	for meters in range(0, 400, 2):
		var level := TerrainShaper.level_for_height(meters)
		assert_true(level >= previous, "levels never go down with height")
		assert_true(level - previous <= TerrainShaper.HIGH_LEVELS_PER_STEP, "no big jumps")
		previous = level
	var above := TerrainShaper.level_for_height(TerrainShaper.HIGH_LEVELS_FROM + 1.0)
	var next := TerrainShaper.level_for_height(
		TerrainShaper.HIGH_LEVELS_FROM + TerrainShaper.HIGH_LEVEL_STEP + 1.0
	)
	assert_eq(next - above, TerrainShaper.HIGH_LEVELS_PER_STEP)
