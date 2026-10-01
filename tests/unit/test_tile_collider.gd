extends TestCase

const BOX := Vector2(10.0, 6.0)

## A solid tile at (2, 0), and a trunk 6 px wide in the middle of (0, 3).
var _obstacles: Dictionary[Vector2i, Rect2] = {
	Vector2i(2, 0): Rect2(32, 0, 16, 16),
	Vector2i(0, 3): Rect2(5, 53, 6, 6),
}


func _obstacle_at(tile: Vector2i) -> Rect2:
	return _obstacles.get(tile, Rect2())


func test_free_movement_is_not_blocked() -> void:
	var feet := TileCollider.move(Vector2(24, 12), Vector2(0, 40), BOX, _obstacle_at)
	assert_almost(feet.x, 24.0)
	assert_almost(feet.y, 52.0)


func test_stops_against_a_solid_tile() -> void:
	# Tile (2, 0) spans x in [32, 48). The box is 10 wide around feet.x.
	var feet := TileCollider.move(Vector2(8, 12), Vector2(60, 0), BOX, _obstacle_at)
	assert_almost(feet.x, 32.0 - 5.0, 0.05)
	assert_false(TileCollider.overlaps(feet, BOX, _obstacle_at))


func test_slides_along_a_wall_diagonally() -> void:
	var feet := TileCollider.move(Vector2(20, 12), Vector2(30, 30), BOX, _obstacle_at)
	assert_true(feet.y > 12.0 + 20.0, "kept moving down")
	assert_false(TileCollider.overlaps(feet, BOX, _obstacle_at))


func test_cannot_tunnel_through_with_a_big_step() -> void:
	var feet := TileCollider.move(Vector2(8, 12), Vector2(500, 0), BOX, _obstacle_at)
	assert_true(feet.x < 32.0)


func test_can_escape_when_already_inside() -> void:
	var feet := TileCollider.move(Vector2(40, 12), Vector2(0, 20), BOX, _obstacle_at)
	assert_almost(feet.y, 32.0)


func test_a_trunk_only_blocks_its_own_box() -> void:
	# Straight at the trunk: stopped against it.
	var feet := TileCollider.move(Vector2(8, 40), Vector2(0, 30), BOX, _obstacle_at)
	assert_almost(feet.y, 53.0, 0.05, "stops at the trunk")
	# Beside it, in the same tile: goes past.
	var beside := TileCollider.move(Vector2(19, 40), Vector2(0, 30), BOX, _obstacle_at)
	assert_almost(beside.y, 70.0, 0.05, "walks past the trunk")
