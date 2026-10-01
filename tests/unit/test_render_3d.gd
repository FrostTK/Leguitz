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
	var surfaces := ChunkMesher.build_surfaces(_flat_chunk(2), _no_neighbor)
	assert_eq(surfaces[0].vertices.size(), GameConst.CHUNK_AREA * 4, "one quad per tile")
	assert_true(surfaces[1].is_empty(), "no faces on flat ground")
	assert_almost(surfaces[0].vertices[0].y, 2.0 * Render3D.LEVEL_HEIGHT)


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


func test_step_makes_faces() -> void:
	var chunk := _flat_chunk(0)
	# Raise the northern half by one level: one east-west cliff line.
	for i in GameConst.CHUNK_AREA / 2:
		chunk.levels[i] = 1
	var surfaces := ChunkMesher.build_surfaces(chunk, _no_neighbor)
	assert_eq(surfaces[1].vertices.size(), GameConst.CHUNK_SIZE * 4, "one face per edge tile")
	for normal in surfaces[1].normals:
		assert_eq(normal, Vector3.BACK, "the cliff faces south, towards the camera")


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
