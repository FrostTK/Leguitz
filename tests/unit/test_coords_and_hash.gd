extends TestCase


func test_negative_tiles_floor_to_the_right_chunk() -> void:
	assert_eq(Coords.tile_to_chunk(Vector2i(-1, -1)), Vector2i(-1, -1))
	assert_eq(Coords.tile_to_local(Vector2i(-1, -1)), Vector2i(15, 15))
	assert_eq(Coords.tile_to_chunk(Vector2i(16, -17)), Vector2i(1, -2))
	assert_eq(Coords.tile_to_local(Vector2i(16, -17)), Vector2i(0, 15))
	assert_eq(Coords.chunk_origin_tile(Vector2i(-2, 3)), Vector2i(-32, 48))


func test_world_to_tile_floors() -> void:
	assert_eq(Coords.world_to_tile(Vector2(-0.5, 3.2)), Vector2i(-1, 0))
	assert_eq(Coords.world_to_tile(Vector2(16.0, 31.99)), Vector2i(1, 1))
	assert_eq(Coords.world_to_chunk(Vector2(-1.0, 256.0)), Vector2i(-1, 1))


func test_chunk_distance_is_chebyshev() -> void:
	assert_eq(Coords.chunk_distance(Vector2i(0, 0), Vector2i(3, -1)), 3)
	assert_eq(Coords.chunk_distance(Vector2i(-2, 5), Vector2i(-2, 5)), 0)


## Reference values computed independently (Python) so world generation
## stays identical on every platform and engine version.
func test_hash_functions_match_reference_values() -> void:
	assert_eq(HashUtil.mul32(0xDEADBEEF, 0x85EBCA6B), 2611766245)
	assert_eq(HashUtil.mul32(-5, 12345), 4294905571)
	assert_eq(HashUtil.fmix32(1), 0x514E28B7)
	assert_eq(HashUtil.fmix32(123456789), 3126909082)
	assert_eq(HashUtil.hash2(7, -3, 12), 4044857331)
	assert_eq(HashUtil.hash2(0xFFFFFFFF, 100000, -100000), 2871701185)
	assert_eq(HashUtil.derive_seed(42, 1), 2489784932)
	assert_eq(HashUtil.derive_seed(-1, 3), 2149042184)


func test_seed_from_text() -> void:
	assert_eq(HashUtil.seed_from_text("42"), 42)
	assert_eq(HashUtil.seed_from_text("  -7 "), -7)
	assert_eq(HashUtil.seed_from_text("hello"), 4919825491372110482)
	assert_eq(HashUtil.seed_from_text("Leguitz"), 9137353188525850724)


func test_unit_hash_is_in_range() -> void:
	for i in 200:
		var value := HashUtil.unit2(99, i * 7 - 300, i * 13 - 50)
		assert_true(value >= 0.0 and value < 1.0)
