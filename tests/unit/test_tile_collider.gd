extends TestCase

const BOX := Vector2(10.0, 6.0)

## A single solid tile at (2, 0).
var _solid := {Vector2i(2, 0): true}


func _is_solid(tile: Vector2i) -> bool:
	return _solid.has(tile)


func test_free_movement_is_not_blocked() -> void:
	var feet := TileCollider.move(Vector2(8, 12), Vector2(0, 40), BOX, _is_solid)
	assert_almost(feet.x, 8.0)
	assert_almost(feet.y, 52.0)


func test_stops_against_a_solid_tile() -> void:
	# Tile (2, 0) spans x in [32, 48). The box is 10 wide around feet.x.
	var feet := TileCollider.move(Vector2(8, 12), Vector2(60, 0), BOX, _is_solid)
	assert_almost(feet.x, 32.0 - 5.0, 0.05)
	assert_false(TileCollider.overlaps_solid(feet, BOX, _is_solid))


func test_slides_along_a_wall_diagonally() -> void:
	var feet := TileCollider.move(Vector2(20, 12), Vector2(30, 30), BOX, _is_solid)
	assert_true(feet.y > 12.0 + 20.0, "kept moving down")
	assert_false(TileCollider.overlaps_solid(feet, BOX, _is_solid))


func test_cannot_tunnel_through_with_a_big_step() -> void:
	var feet := TileCollider.move(Vector2(8, 12), Vector2(500, 0), BOX, _is_solid)
	assert_true(feet.x < 32.0)


func test_can_escape_when_already_inside() -> void:
	var feet := TileCollider.move(Vector2(40, 12), Vector2(0, 20), BOX, _is_solid)
	assert_almost(feet.y, 32.0)
