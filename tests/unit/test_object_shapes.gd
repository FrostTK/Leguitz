extends TestCase
## Shapes of the objects standing in voxels: trunks, footprints, versions.


func test_every_tree_version_has_its_own_size() -> void:
	for block: int in ObjectShapes.TREES:
		var ranges: Array = ObjectShapes.TREES[block]
		var widths: Vector2i = ranges[0]
		var heights: Vector2i = ranges[1]
		var seen_heights := {}
		var seen_widths := {}
		for variant in ObjectShapes.variant_count(block):
			var trunk := ObjectShapes.trunk(block, variant)
			assert_eq(trunk.x % 2, 0, "even widths stay centered on the tile")
			assert_true(trunk.x >= widths.x and trunk.x <= widths.y, "width in range")
			assert_true(trunk.y >= heights.x and trunk.y <= heights.y, "height in range")
			assert_true(trunk.x < GameConst.TILE_SIZE, "a trunk leaves room around it")
			seen_heights[trunk.y] = true
			seen_widths[trunk.x] = true
		assert_true(seen_heights.size() >= 6, "versions of different heights")
		assert_true(seen_widths.size() >= 2, "versions of different widths")


func test_trees_block_their_trunk_only() -> void:
	var tile := Vector2i(5, -3)
	for block: int in ObjectShapes.TREES:
		var variant := ObjectShapes.variant_at(block, tile)
		var trunk := ObjectShapes.trunk(block, variant)
		assert_eq(ObjectShapes.footprint(block, variant), trunk.x)
		var rect := ObjectShapes.footprint_rect(block, tile)
		assert_eq(rect.get_center(), Coords.tile_to_world_center(tile), "centered on the tile")
		assert_eq(rect.size, Vector2.ONE * trunk.x)
		var levels := ObjectShapes.blocking_levels(block, variant)
		assert_true(levels * GameConst.TILE_SIZE >= trunk.y, "blocks the whole trunk")
	assert_eq(ObjectShapes.footprint_rect(Tiles.Block.TALL_GRASS, tile), Rect2(), "grass")


func test_wandering_objects_stay_in_their_tile() -> void:
	var offsets := {}
	for y in 12:
		for x in 12:
			var tile := Vector2i(x - 6, y - 6)
			var rect := ObjectShapes.footprint_rect(Tiles.Block.ROCK, tile)
			var whole := Rect2(
				Vector2(tile * GameConst.TILE_SIZE), Vector2.ONE * GameConst.TILE_SIZE
			)
			assert_true(whole.encloses(rect), "the rock stays in its tile")
			offsets[ObjectShapes.offset_at(Tiles.Block.ROCK, tile)] = true
			assert_eq(ObjectShapes.offset_at(Tiles.Block.OAK, tile), Vector2i.ZERO)
	assert_true(offsets.size() > 10, "rocks lie anywhere in their tile")


func test_versions_come_from_the_tile() -> void:
	var seen := {}
	for x in 200:
		var tile := Vector2i(x * 7 - 300, x * 3)
		var variant := ObjectShapes.variant_at(Tiles.Block.SPRUCE, tile)
		assert_eq(variant, ObjectShapes.variant_at(Tiles.Block.SPRUCE, tile), "stable")
		seen[variant] = true
	assert_eq(seen.size(), ObjectShapes.TREE_VARIANTS, "every version shows up")
