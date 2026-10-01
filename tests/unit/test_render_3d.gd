extends TestCase
## The 3D view: tile to 3D mapping, chunk meshes and the sky light.

const SEA := GameConst.SEA_LEVEL


## Grass at `level` on stone, as a mesher job with no neighbors.
func _flat_chunk(level: int) -> ChunkData:
	var chunk := ChunkData.new(Vector2i.ZERO)
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var grass := Voxels.of_ground(Tiles.Ground.GRASS)
	for lz in GameConst.CHUNK_SIZE:
		for lx in GameConst.CHUNK_SIZE:
			for y in SEA + level:
				chunk.set_voxel(Vector3i(lx, y, lz), grass if y == SEA + level - 1 else stone)
	return chunk


func _no_neighbor(_coord: Vector2i) -> ChunkData:
	return null


## Ground area (tiles) covered by the horizontal quads of a surface.
static func _area(surface: ChunkMesher.Surface) -> float:
	var area := 0.0
	for quad in surface.quad_count():
		var a := surface.vertices[quad * 4]
		var c := surface.vertices[quad * 4 + 2]
		area += absf((c.x - a.x) * (c.z - a.z))
	return area


func _build(chunk: ChunkData, cut_row := ChunkData.HEIGHT) -> ChunkMesher.Result:
	var job := ChunkMesher.Job.of_chunk(chunk, _no_neighbor)
	job.variants.resize(256)
	job.cut_row = cut_row
	return ChunkMesher.build(job)


func test_local_mapping_and_root_stretch() -> void:
	var p := Render3D.world_px_to_local(Vector2(32, 16), 1.5)
	assert_eq(p, Vector3(2.0, 1.5, 1.0))
	assert_eq(Render3D.tile_center_local(Vector2i(0, 0), 0.0), Vector3(0.5, 0.0, 0.5))
	# At the default angle a tile top and a one-level face both show 16 px.
	var pitch := deg_to_rad(Render3D.DEFAULT_PITCH)
	var root := Render3D.root_basis(0.0, pitch)
	assert_almost((root * Vector3.BACK).z * sin(pitch), 1.0)
	assert_almost((root * Vector3.UP).y * cos(pitch), 1.0)
	assert_almost((root * Vector3.RIGHT).x, 1.0)
	# The stretch turns with the camera: tiles stay square on screen.
	var turned := Render3D.root_basis(PI / 2.0, pitch)
	assert_almost((turned * Vector3.RIGHT).length(), Render3D.depth_stretch(pitch))
	assert_almost((turned * Vector3.BACK).length(), 1.0)


func test_lower_camera_does_not_stretch_things() -> void:
	var default_pitch := deg_to_rad(Render3D.DEFAULT_PITCH)
	var previous_top := 0.0
	for degrees in range(int(Render3D.MIN_PITCH), int(Render3D.DEFAULT_PITCH) + 1, 5):
		var pitch := deg_to_rad(degrees)
		var root := Render3D.root_basis(0.0, pitch)
		# A level keeps its 16 px on screen: nothing gets taller...
		assert_almost((root * Vector3.UP).y * cos(pitch), 1.0)
		# ...while the ground flattens as the camera goes down.
		var top := (root * Vector3.BACK).z * sin(pitch)
		assert_true(top > previous_top, "tile tops grow with the pitch")
		previous_top = top
	# Near the horizon the stretch fades out: a cube looks like a cube.
	var low := deg_to_rad(Render3D.MIN_PITCH)
	assert_almost(Render3D.vertical_scale(low), 1.0, 0.05)
	assert_almost(Render3D.depth_stretch(low), 1.0, 0.01)
	# Looking down more steeply keeps the default stretch.
	var steep := deg_to_rad(Render3D.MAX_PITCH)
	assert_almost(Render3D.vertical_scale(steep), Render3D.vertical_scale(default_pitch))
	assert_almost(Render3D.depth_stretch(steep), Render3D.depth_stretch(default_pitch))
	assert_true(Render3D.MIN_PITCH <= 15.0, "the camera can go down low")


func test_screen_directions_follow_the_camera() -> void:
	var yaw := 0.7
	var ground := Render3D.screen_to_ground(Vector2(0.3, -0.8), yaw)
	var back := Render3D.ground_to_screen(ground, yaw)
	assert_almost(back.x, 0.3)
	assert_almost(back.y, -0.8)
	assert_eq(Render3D.screen_to_ground(Vector2.UP, 0.0), Vector2.UP)
	# Turned a quarter, "up" on screen walks west... or east: never north.
	assert_almost(absf(Render3D.screen_to_ground(Vector2.UP, PI / 2.0).x), 1.0)


func test_flat_chunk_has_only_tops() -> void:
	var result := _build(_flat_chunk(2))
	var tops := result.parts[ChunkMesher.Part.TOPS]
	assert_eq(tops.quad_count(), 1, "the same ground merges into one quad")
	assert_almost(_area(tops), GameConst.CHUNK_AREA, 0.001, "covering every column")
	assert_true(result.parts[ChunkMesher.Part.FACES].is_empty(), "no faces on flat ground")
	assert_true(result.parts[ChunkMesher.Part.DEEP_TOPS].is_empty(), "no caves")
	var bottom := result.parts[ChunkMesher.Part.DEEP_FACES]
	assert_almost(_area(bottom), GameConst.CHUNK_AREA, 0.001, "the bottom closes the rock")
	assert_almost(tops.vertices[0].y, 2.0 * Render3D.LEVEL_HEIGHT)


func test_ground_variant_matches_shader_hash() -> void:
	# Same arithmetic as the shader's hash2(p) & 3 (32-bit unsigned).
	assert_eq(ChunkMesher.ground_variant(Vector2i(0, 0)), _shader_variant(0, 0))
	assert_eq(ChunkMesher.ground_variant(Vector2i(-5, 17)), _shader_variant(-5, 17))
	for tile in [Vector2i(0, 0), Vector2i(-5, 17), Vector2i(123456, -98765)]:
		var variant := ChunkMesher.ground_variant(tile)
		assert_true(variant >= 0 and variant <= 3)
	var counts := [0, 0, 0, 0]
	for x in 40:
		for y in 40:
			counts[ChunkMesher.ground_variant(Vector2i(x, y))] += 1
	for count: int in counts:
		assert_true(count > 300, "variants are spread evenly")


func test_step_makes_merged_faces_with_a_lip() -> void:
	var chunk := _flat_chunk(0)
	# Raise the northern half by three levels: one east-west cliff line.
	var dirt := Voxels.of_ground(Tiles.Ground.DIRT)
	var grass := Voxels.of_ground(Tiles.Ground.GRASS)
	for lz in GameConst.CHUNK_SIZE / 2:
		for lx in GameConst.CHUNK_SIZE:
			chunk.set_voxel(Vector3i(lx, SEA - 1, lz), dirt)
			chunk.set_voxel(Vector3i(lx, SEA, lz), dirt)
			chunk.set_voxel(Vector3i(lx, SEA + 1, lz), dirt)
			chunk.set_voxel(Vector3i(lx, SEA + 2, lz), grass)
	var faces := _build(chunk).parts[ChunkMesher.Part.FACES]
	assert_eq(faces.quad_count(), GameConst.CHUNK_SIZE, "one merged face per edge tile")
	for normal in faces.normals:
		assert_eq(normal, Vector3.BACK, "the cliff faces south, towards the camera")
	assert_almost(faces.vertices[0].y - faces.vertices[3].y, 3.0, 0.001, "three levels tall")
	assert_eq(int(faces.uv2s[0].y), Tiles.Ground.GRASS + 1, "grass hangs over it")


func test_caves_are_meshed_apart_and_the_map_follows_the_cut() -> void:
	var chunk := _flat_chunk(4)
	# A room three levels tall under the middle of the chunk.
	for lz in range(5, 10):
		for lx in range(5, 10):
			for y in range(SEA - 6, SEA - 3):
				chunk.set_voxel(Vector3i(lx, y, lz), Voxels.AIR)
	var result := _build(chunk)
	assert_almost(_area(result.parts[ChunkMesher.Part.TOPS]), GameConst.CHUNK_AREA, 0.001)
	assert_true(result.parts[ChunkMesher.Part.FACES].is_empty(), "nothing shows from the sky")
	assert_almost(_area(result.parts[ChunkMesher.Part.DEEP_TOPS]), 25.0, 0.001, "the floor")
	# Walls (5 per side, each three levels tall), ceiling and world bottom.
	assert_eq(result.parts[ChunkMesher.Part.DEEP_FACES].quad_count(), 20 + 1 + 1)
	var column := (7 + 1) * ChunkMesher.SPAN + (7 + 1)
	assert_almost(result.surface_map[column * 4 + 2], 4.0, 0.001, "from the sky: the grass")
	var cut := _build(chunk, SEA - 4)
	assert_almost(cut.surface_map[column * 4 + 2], -6.0, 0.001, "under the cut: the floor")


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


func test_terraces_rise_one_level_at_a_time() -> void:
	# Players climb by jumping one level: the smooth height never skips one.
	var previous := 0
	for meters in range(0, 600):
		var level := TerrainShaper.level_for_height(meters)
		assert_true(level >= previous, "levels never go down with height")
		assert_true(level - previous <= 1, "one level at a time")
		previous = level


## Straightforward 32-bit port of hash2 from terrain3d_common.gdshaderinc.
func _shader_variant(x: int, y: int) -> int:
	var mask := 0xFFFFFFFF
	var qx := (x + 16777216) & mask
	var qy := (y + 16777216) & mask
	var h := ((qx * 374761393) & mask) + ((qy * 668265263) & mask)
	h &= mask
	h = ((h ^ (h >> 13)) * 1274126177) & mask
	return (h ^ (h >> 16)) & 3
