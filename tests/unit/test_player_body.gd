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
	assert_true(body.feet.y <= 3.0 * TS, "a tree cannot be jumped over")
	var edge := _body_at(19.5, 2.0)
	_walk(edge, 5.0 * TS, 1.0)
	assert_true(edge.feet.x <= 21.0 * TS, "unknown terrain blocks")
	var nowhere := PlayerBody.new()
	nowhere.place(Vector2(30 * TS, 0.0), 0.0)
	nowhere.step(Vector2.ZERO, false, DT, _voxel_at)
	assert_true(nowhere.needs_landing, "waits for the ground to be known")


func test_wades_in_water_and_stays_out_of_lava() -> void:
	_extra[Vector3i(1, SEA - 1, 1)] = Voxels.of_ground(Tiles.Ground.WATER)
	var body := _body_at(1.5)
	assert_almost(body.height, -ChunkData.WATER_DROP, 0.001, "walks on the water surface")
	_extra[Vector3i(2, SEA - 1, 1)] = Voxels.of_ground(Tiles.Ground.LAVA)
	var walker := _body_at(0.5)
	_walk(walker, 5.0 * TS, 1.0)
	assert_true(walker.feet.x < 2.0 * TS, "lava blocks the way")
