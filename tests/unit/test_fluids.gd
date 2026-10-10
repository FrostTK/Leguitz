extends TestCase
## Water and lava flowing (Fluids): spreading a level a cell, falling,
## drying up once cut off, endless water, lava hardening into stone where
## it meets water; what bodies and the meshes make of flowing liquids.

const SEA := GameConst.SEA_LEVEL
const WATER := Tiles.Ground.WATER
const LAVA := Tiles.Ground.LAVA

var _server: GameServer


## A closed stone box around the origin: floor at row SEA - 1, air from
## SEA to SEA + 4 over x and z -8 to 8, a roof over it.
func _box() -> GameServer:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	_server = GameServer.new(settings, null, false)
	var stone := Voxels.of_block(Tiles.Block.STONE)
	for x in range(-9, 10):
		for z in range(-9, 10):
			for y in range(SEA - 2, SEA + 6):
				var inside := absi(x) <= 8 and absi(z) <= 8 and y >= SEA and y <= SEA + 4
				_server.world.set_voxel(Vector3i(x, y, z), Voxels.AIR if inside else stone)
	return _server


func _at(x: int, y: int, z: int) -> int:
	return _server.world.voxel_at(Vector3i(x, SEA + y, z))


## Puts a voxel without stirring the liquids (as generated).
func _put(x: int, y: int, z: int, voxel: int) -> void:
	_server.world.set_voxel(Vector3i(x, SEA + y, z), voxel)


## Runs the liquids for `steps` water steps.
func _flow(steps: int) -> void:
	for i in steps * Fluids.WATER_TICKS:
		_server.tick_count += 1
		_server.fluids.update(_server)


func _ground(x: int, y: int, z: int) -> int:
	return Voxels.ground_of(_at(x, y, z))


func test_water_spreads_a_level_a_cell_then_dries_up() -> void:
	_box()
	_put(0, 0, 0, WATER)
	assert_eq(_at(1, 0, 0), Voxels.AIR, "still until something changes")
	_server.change_voxel(Vector3i(0, SEA + 1, 0), Voxels.AIR)
	_flow(20)
	assert_eq(_ground(1, 0, 0), Tiles.Ground.WATER_FLOW_1)
	assert_eq(_ground(0, 0, -2), Tiles.Ground.WATER_FLOW_2)
	assert_eq(_ground(1, 0, 1), Tiles.Ground.WATER_FLOW_2, "around corners")
	assert_eq(_ground(4, 0, 0), Tiles.Ground.WATER_FLOW_4)
	assert_eq(_at(5, 0, 0), Voxels.AIR, "no farther than its reach")
	assert_eq(_ground(0, 0, 0), WATER, "the source stays")
	assert_false(_server.fluids.is_moving(), "settled")
	# Cut from its source, it dries up.
	_server.change_voxel(Vector3i(0, SEA, 0), Voxels.of_block(Tiles.Block.STONE))
	_flow(20)
	for x in range(1, 6):
		assert_eq(_at(x, 0, 0), Voxels.AIR, "dried up at %d" % x)


func test_water_falls_then_spreads_where_it_lands() -> void:
	_box()
	var stone := Voxels.of_block(Tiles.Block.STONE)
	for y in 3:
		_put(0, y, 0, stone)
	_put(0, 3, 0, WATER)
	_server.change_voxel(Vector3i(0, SEA + 4, 0), Voxels.AIR)
	_flow(30)
	assert_eq(_ground(1, 3, 0), Tiles.Ground.WATER_FLOW_1, "off the pillar")
	assert_eq(_at(2, 3, 0), Voxels.AIR, "it does not spread over the drop")
	for y in 3:
		assert_eq(_ground(1, y, 0), Tiles.Ground.WATER_FALLING, "falling at %d" % y)
	assert_eq(_ground(2, 0, 0), Tiles.Ground.WATER_FLOW_1, "spreading where it lands")
	assert_eq(_ground(5, 0, 0), Tiles.Ground.WATER_FLOW_4)
	# A body walks in a shallow flow, swims in deep water.
	var shallow := Fluids.surface(Voxels.of_ground(Tiles.Ground.WATER_FLOW_4))
	assert_true(shallow < Fluids.surface(Voxels.of_ground(Tiles.Ground.WATER_FLOW_1)))
	assert_almost(Fluids.surface(Voxels.of_ground(WATER)), 1.0 - ChunkData.WATER_DROP, 0.001)
	var feet := Coords.tile_to_world_center(Vector2i(5, 0))
	var voxel_at := _server.world.voxel_at
	assert_eq(PlayerBody.liquid_at(feet, 0.0, voxel_at), _at(5, 0, 0), "the feet are in it")
	assert_eq(PlayerBody.liquid_at(feet, shallow + 0.01, voxel_at), Voxels.AIR, "not over it")


func test_two_sources_make_a_third_and_water_hardens_lava() -> void:
	_box()
	_put(0, 0, 0, WATER)
	_put(2, 0, 0, WATER)
	_server.change_voxel(Vector3i(1, SEA, 0), Voxels.AIR)
	_flow(3)
	assert_eq(_ground(1, 0, 0), WATER, "endless water")
	# Lava meeting water turns into stone.
	_put(-4, 0, -6, LAVA)
	_put(-1, 0, -6, WATER)
	_server.change_voxel(Vector3i(-2, SEA, -6), Voxels.AIR)
	_flow(10)
	assert_eq(_at(-4, 0, -6), Voxels.of_block(Tiles.Block.STONE), "lava + water = stone")
	# Lava flows, slower and not as far.
	_put(4, 0, 6, LAVA)
	_server.change_voxel(Vector3i(5, SEA, 6), Voxels.AIR)
	_flow(Fluids.LAVA_TICKS / Fluids.WATER_TICKS)
	assert_eq(_ground(5, 0, 6), Tiles.Ground.LAVA_FLOW_1)
	_flow(Fluids.LAVA_TICKS / Fluids.WATER_TICKS * 4)
	assert_eq(_ground(6, 0, 6), Tiles.Ground.LAVA_FLOW_2)
	assert_eq(_at(7, 0, 6), Voxels.AIR, "lava reaches less far")
	assert_true(Voxels.is_lava(_at(6, 0, 6)) and Voxels.is_solid(_at(6, 0, 6)))


func test_flowing_liquids_show_their_sides() -> void:
	var chunk := ChunkData.new(Vector2i.ZERO)
	var stone := Voxels.of_block(Tiles.Block.STONE)
	for lz in GameConst.CHUNK_SIZE:
		for lx in GameConst.CHUNK_SIZE:
			chunk.set_voxel(Vector3i(lx, SEA - 1, lz), stone)
	# A waterfall off a pillar, a flow at its foot.
	for y in range(SEA, SEA + 3):
		chunk.set_voxel(Vector3i(5, y, 5), stone)
		chunk.set_voxel(Vector3i(6, y, 5), Voxels.of_ground(Tiles.Ground.WATER_FALLING))
	chunk.set_voxel(Vector3i(5, SEA + 3, 5), Voxels.of_ground(WATER))
	chunk.set_voxel(Vector3i(6, SEA + 3, 5), Voxels.of_ground(Tiles.Ground.WATER_FLOW_1))
	chunk.set_voxel(Vector3i(7, SEA, 5), Voxels.of_ground(Tiles.Ground.WATER_FLOW_1))
	var job := ChunkJob.of_chunk(chunk, func(_coord: Vector2i) -> ChunkData: return null)
	job.variants.resize(Tiles.Block.size())
	var result := ChunkMesher.build(job)
	var water := result.parts[ChunkMesher.Part.WATER]
	var sides := 0
	var lowest := INF
	for i in water.vertices.size():
		if water.colors[i].r > 0.5:
			sides += 1
			lowest = minf(lowest, water.vertices[i].y)
		else:
			assert_eq(water.uv2s[i].x, float(WATER), "drawn as the water it flows from")
	assert_true(sides >= 4 * 3, "the waterfall shows its sides: %d" % sides)
	assert_almost(lowest, 0.0, 0.001, "down to the ground")
	# The flow's top is lower than the source's.
	var tops := {}
	for i in water.vertices.size():
		if water.colors[i].r < 0.5:
			tops[snappedf(water.vertices[i].y, 0.001)] = true
	assert_true(
		tops.has(snappedf(Fluids.surface(Voxels.of_ground(Tiles.Ground.WATER_FLOW_1)), 0.001))
	)
