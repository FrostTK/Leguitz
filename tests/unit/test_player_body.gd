extends TestCase
## Walking, falling and jumping over terrain heights (PlayerBody).

const TS := GameConst.TILE_SIZE
const DT := 1.0 / 60.0

## Heights of a small test world: ground at level 0, a one-level step from
## tile x = 3, a two-level wall from x = 6, a tree at (1, 3).
var _tops: Dictionary[Vector2i, float] = {}


func _top_at(tile: Vector2i) -> float:
	if _tops.has(tile):
		return _tops[tile]
	if tile.x >= 6:
		return 2.0
	if tile.x >= 3:
		return 1.0
	return 0.0


func _body_at(tile_x: float) -> PlayerBody:
	var body := PlayerBody.new()
	body.place(Vector2(tile_x * TS, 1.5 * TS))
	body.step(Vector2.ZERO, false, DT, _top_at)
	return body


func _walk(body: PlayerBody, speed: float, seconds: float, jump := false) -> void:
	for i in int(seconds / DT):
		body.step(Vector2(speed * DT, 0.0), jump, DT, _top_at)


func test_lands_on_the_ground_when_placed() -> void:
	var body := _body_at(4.5)
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
	body.step(Vector2.ZERO, true, DT, _top_at)
	for i in 60:
		body.step(Vector2.ZERO, false, DT, _top_at)
		highest = maxf(highest, body.height)
	assert_almost(highest, PlayerBody.JUMP_HEIGHT, 0.06)
	assert_true(body.on_ground, "back on the ground")


func test_walking_off_an_edge_falls() -> void:
	var body := _body_at(4.5)
	_walk(body, -5.0 * TS, 0.6)
	assert_true(body.feet.x < 3.0 * TS)
	assert_eq(body.height, 0.0, "fell down to the lower ground")


func test_obstacles_and_unknown_ground_block() -> void:
	_tops[Vector2i(1, 3)] = INF
	var body := PlayerBody.new()
	body.place(Vector2(1.5 * TS, 1.5 * TS))
	body.step(Vector2.ZERO, false, DT, _top_at)
	for i in 60:
		body.step(Vector2(0.0, 5.0 * TS * DT), true, DT, _top_at)
	assert_true(body.feet.y <= 3.0 * TS, "a tree cannot be jumped over")
	var nowhere := PlayerBody.new()
	nowhere.place(Vector2.ZERO)
	nowhere.step(Vector2.ZERO, false, DT, func(_tile: Vector2i) -> float: return INF)
	assert_true(nowhere.needs_landing, "waits for the ground to be known")
