extends TestCase
## Walking, falling, jumping and bumping among voxels (PlayerBody).

const TS := GameConst.TILE_SIZE
const DT := 1.0 / 60.0
const SEA := GameConst.SEA_LEVEL

## A small test world: ground at level 0, a one-level step from tile x = 3,
## a two-level wall from x = 6, a low ceiling over x = -3..-1 (two levels
## up), a tree at (1, 3), and nothing known beyond x = 20.
var _extra: Dictionary[Vector3i, int] = {}


func _voxel_at(cell: Vector3i) -> int:
	if _extra.has(cell):
		return _extra[cell]
	if cell.x > 20:
		return Voxels.UNKNOWN
	var top := SEA
	if cell.x >= 6:
		top = SEA + 2
	elif cell.x >= 3:
		top = SEA + 1
	if cell.y < top:
		return Voxels.of_ground(Tiles.Ground.GRASS)
	if cell.x < 0 and cell.x >= -3 and cell.y == SEA + 2:
		return Voxels.of_block(Tiles.Block.STONE)
	return Voxels.AIR


func _body_at(tile_x: float, height := 0.0) -> PlayerBody:
	var body := PlayerBody.new()
	body.place(Vector2(tile_x * TS, 1.5 * TS), height)
	body.step(Vector2.ZERO, false, DT, _voxel_at)
	return body


func _walk(body: PlayerBody, speed: float, seconds: float, jump := false) -> void:
	for i in int(seconds / DT):
		body.step(Vector2(speed * DT, 0.0), jump, DT, _voxel_at)


func test_lands_on_the_ground_when_placed() -> void:
	var body := _body_at(4.5, 1.0)
	assert_false(body.needs_landing)
	assert_eq(body.height, 1.0)
	assert_true(body.on_ground)


func test_a_step_blocks_walking_but_not_jumping() -> void:
	var body := _body_at(1.5)
	_walk(body, 5.0 * TS, 1.0)
	assert_true(body.feet.x < 3.0 * TS, "stopped by the one-level step")
	assert_eq(body.height, 0.0)
	_walk(body, 5.0 * TS, 0.5, true)
	_walk(body, 5.0 * TS, 0.2)
	assert_true(body.feet.x > 3.0 * TS, "jumped onto it")
	assert_true(body.feet.x < 6.0 * TS, "but not onto the two-level wall")
	assert_eq(body.height, 1.0)


func test_jump_height_is_one_and_a_quarter() -> void:
	var body := _body_at(1.5)
	var highest := 0.0
	body.step(Vector2.ZERO, true, DT, _voxel_at)
	for i in 60:
		body.step(Vector2.ZERO, false, DT, _voxel_at)
		highest = maxf(highest, body.height)
	assert_almost(highest, PlayerBody.JUMP_HEIGHT, 0.06)
	assert_true(body.on_ground, "back on the ground")


func test_a_low_ceiling_stops_the_jump() -> void:
	var body := _body_at(-1.5)
	var highest := 0.0
	body.step(Vector2.ZERO, true, DT, _voxel_at)
	for i in 60:
		body.step(Vector2.ZERO, false, DT, _voxel_at)
		highest = maxf(highest, body.height)
	assert_almost(highest, 2.0 - PlayerBody.BODY_HEIGHT, 0.01, "head against the ceiling")
	assert_true(body.on_ground)


func test_walking_off_an_edge_falls() -> void:
	var body := _body_at(4.5, 1.0)
	_walk(body, -5.0 * TS, 0.6)
	assert_true(body.feet.x < 3.0 * TS)
	assert_eq(body.height, 0.0, "fell down to the lower ground")


func test_falls_into_a_hole_and_walks_under_a_roof() -> void:
	# A two-deep hole at x = 1: the body drops into it.
	_extra[Vector3i(1, SEA - 1, 1)] = Voxels.AIR
	_extra[Vector3i(1, SEA - 2, 1)] = Voxels.AIR
	var body := _body_at(1.5)
	assert_eq(body.height, -2.0)
	# The low ceiling (two levels up) leaves room to walk under it.
	var walker := _body_at(0.5)
	_walk(walker, -5.0 * TS, 0.4)
	assert_true(walker.feet.x < -1.0 * TS, "walked under the roof")


func test_obstacles_and_unknown_ground_block() -> void:
	_extra[Vector3i(1, SEA, 3)] = Voxels.of_block(Tiles.Block.OAK)
	var body := _body_at(1.5)
	for i in 60:
		body.step(Vector2(0.0, 5.0 * TS * DT), true, DT, _voxel_at)
	var trunk := ObjectShapes.footprint_rect(Tiles.Block.OAK, Vector2i(1, 3))
	assert_true(body.feet.y <= trunk.position.y + 0.1, "a tree cannot be jumped over")
	var edge := _body_at(19.5, 2.0)
	_walk(edge, 5.0 * TS, 1.0)
	assert_true(edge.feet.x <= 21.0 * TS, "unknown terrain blocks")
	var nowhere := PlayerBody.new()
	nowhere.place(Vector2(30 * TS, 0.0), 0.0)
	nowhere.step(Vector2.ZERO, false, DT, _voxel_at)
	assert_true(nowhere.needs_landing, "waits for the ground to be known")


func test_walks_between_trees_but_not_through_trunks() -> void:
	# Two oaks two tiles apart, the body between them, walking north.
	_extra[Vector3i(0, SEA, 8)] = Voxels.of_block(Tiles.Block.OAK)
	_extra[Vector3i(2, SEA, 8)] = Voxels.of_block(Tiles.Block.OAK)
	var body := PlayerBody.new()
	body.place(Vector2(1.5 * TS, 10.5 * TS), 0.0)
	for i in 60:
		body.step(Vector2(0.0, -5.0 * TS * DT), false, DT, _voxel_at)
	assert_true(body.feet.y < 7.0 * TS, "went between the trunks")
	# Straight into a trunk: stopped, even jumping (trees rise too high).
	var walker := PlayerBody.new()
	walker.place(Vector2(2.5 * TS, 10.5 * TS), 0.0)
	for i in 60:
		walker.step(Vector2(0.0, -5.0 * TS * DT), true, DT, _voxel_at)
	var trunk := ObjectShapes.footprint_rect(Tiles.Block.OAK, Vector2i(2, 8))
	assert_true(walker.feet.y >= trunk.end.y, "the trunk stops it")
	var whole_tile := 9.0 * TS + PlayerBody.BOX.y
	assert_true(walker.feet.y < whole_tile - 1.0, "only at the trunk, not at the tile's edge")


## A pool three levels deep over tiles x = 0..2 (z = 0..2), its water at
## the ground's level; the one-level step from x = 3 is its bank.
func _pool(ground: int) -> void:
	for x in 3:
		for z in 3:
			for row in range(SEA - 3, SEA):
				_extra[Vector3i(x, row, z)] = Voxels.of_ground(ground)


func test_swims_sinks_floats_and_leaps_out() -> void:
	_pool(Tiles.Ground.WATER)
	var body := _body_at(1.5)
	assert_eq(body.height, -3.0, "nothing stands on water: down to the bed")
	_walk(body, 0.0, 2.0, true)
	var surface := -ChunkData.WATER_DROP
	assert_true(body.in_liquid)
	assert_almost(body.height, surface - PlayerBody.FLOAT_DEPTH, 0.05, "floating, head out")
	assert_false(PlayerBody.eye_in_water(body.feet, body.height, _voxel_at), "breathing")
	_walk(body, 0.0, 1.0)
	assert_true(body.height < surface - 1.0, "sinking without jump")
	assert_true(PlayerBody.eye_in_water(body.feet, body.height, _voxel_at), "under water")
	_walk(body, 0.0, 3.0)
	assert_eq(body.height, -3.0, "back on the bed")
	assert_true(body.on_ground)
	# Up, then along against the bank (x = 3, a level over the water) and out.
	_walk(body, 0.0, 2.0, true)
	_walk(body, 2.0 * TS, 1.0, true)
	_walk(body, 2.0 * TS, 0.8)
	assert_true(body.feet.x > 3.0 * TS, "leapt out")
	assert_eq(body.height, 1.0, "on the bank")
	assert_false(body.in_liquid)
	_extra.clear()


func test_falls_end_in_water_and_lava_is_swum_too() -> void:
	_pool(Tiles.Ground.WATER)
	var body := _body_at(1.5)
	body.place(body.feet, 8.0)
	body.needs_landing = false
	body.on_ground = false
	body.take_fall()
	_walk(body, 0.0, 4.0)
	assert_eq(body.height, -3.0)
	assert_true(body.take_fall() < 0.5, "the water broke the fall")
	_extra.clear()
	_pool(Tiles.Ground.LAVA)
	var swimmer := _body_at(1.5)
	assert_eq(swimmer.height, -3.0, "lava is swum in too")
	_walk(swimmer, 0.0, 1.0, true)
	assert_true(swimmer.in_liquid)
	assert_eq(Voxels.ground_of(swimmer.liquid), Tiles.Ground.LAVA)
	_extra.clear()


func test_falls_are_measured_from_their_highest_point() -> void:
	# Off a pillar three levels over the two-level wall (x >= 6).
	for row in range(SEA + 2, SEA + 5):
		_extra[Vector3i(10, row, 1)] = Voxels.of_block(Tiles.Block.STONE)
	var body := _body_at(10.5, 5.0)
	body.take_fall()
	_walk(body, 3.0 * TS, 1.2)
	assert_eq(body.height, 2.0)
	assert_almost(body.take_fall(), 3.0, 0.05, "three levels down")
	_extra.clear()
	assert_eq(body.take_fall(), 0.0, "told once")
	_walk(body, 0.0, 1.0, true)
	assert_almost(body.take_fall(), PlayerBody.JUMP_HEIGHT, 0.05, "a jump falls from its top")
	assert_eq(Vitals.fall_damage(3.0), 0, "three levels are harmless")
	assert_eq(Vitals.fall_damage(4.0), 1)
	assert_eq(Vitals.fall_damage(10.5), 7)


func test_jumps_onto_furniture_and_stands_on_it() -> void:
	_extra[Vector3i(2, SEA, 1)] = Voxels.of_block(Tiles.Block.CHEST_EAST)
	var body := _body_at(1.2)
	_walk(body, 3.0 * TS, 0.6)
	assert_true(body.feet.x < 2.0 * TS, "the chest blocks walking")
	assert_eq(body.height, 0.0, "standing beside it, not on it")
	body.step(Vector2(1.5 * TS * DT, 0.0), true, DT, _voxel_at)
	_walk(body, 1.5 * TS, 0.5)
	assert_true(body.on_ground)
	assert_almost(body.height, 13.0 / 16.0, 0.0001, "on the chest's lid, not inside it")
	_walk(body, 2.0 * TS, 1.0)
	assert_true(body.feet.x > 3.0 * TS, "from the chest up the step without jumping")
	assert_eq(body.height, 1.0)
	_extra.clear()


func test_furniture_tops_and_items_resting_on_them() -> void:
	assert_almost(ObjectShapes.stand_height(Tiles.Block.WORKBENCH_END_Z), 15.0 / 16.0)
	assert_almost(ObjectShapes.stand_height(Tiles.Block.FACTORY_FURNACE_LIT_WEST), 14.0 / 16.0)
	assert_eq(ObjectShapes.stand_height(Tiles.Block.OAK), 0.0, "no standing on trees")
	_extra[Vector3i(1, SEA, 1)] = Voxels.of_block(Tiles.Block.FOOD_FURNACE)
	var item := DroppedItem.create(Items.Id.DIRT, 1, Vector3(1.5, 2.0, 1.5), Vector3.ZERO)
	for i in 120:
		item.step(DT, _voxel_at)
	assert_true(item.resting)
	assert_almost(item.position.y, 14.0 / 16.0 + DroppedItem.RADIUS, 0.0001, "on the furnace")
	_extra.clear()
