extends TestCase
## Torches and lanterns: their recipes, where they go (a torch on the
## ground or into a bracket, a lantern on the ground, from a ceiling or on
## a wall), what falls with what, what they give back, the light they make
## and the monsters they keep away.

const SEA := GameConst.SEA_LEVEL


## A floor of stone at row SEA - 1, air above, a stone wall along x = 5
## (rows SEA to SEA + 2) and a stone ceiling over (3, SEA + 3, 3).
func _voxel_at(cell: Vector3i) -> int:
	if cell.y < SEA:
		return Voxels.of_block(Tiles.Block.STONE)
	if cell.x == 5 and cell.y <= SEA + 2:
		return Voxels.of_block(Tiles.Block.STONE)
	if cell == Vector3i(3, SEA + 3, 3):
		return Voxels.of_block(Tiles.Block.STONE)
	return Voxels.AIR


func test_torches_and_lanterns_are_made_and_burn() -> void:
	var made := {}
	for recipe in Recipes.all():
		made[recipe["result"][0]] = recipe["result"][1]
	assert_eq(made.get(Items.Id.TORCH, 0), 4, "four torches from coal and a stick")
	assert_eq(made.get(Items.Id.LANTERN, 0), 1)
	for block: int in [
		Tiles.Block.TORCH,
		Tiles.Block.TORCH_BRACKET_LIT_NORTH,
		Tiles.Block.LANTERN,
		Tiles.Block.LANTERN_HANGING,
		Tiles.Block.LANTERN_WALL_EAST,
	]:
		assert_true(ObjectShapes.is_lit(block), String(Tiles.Block.find_key(block)))
		assert_false(Tiles.is_block_solid(block), "bodies go by it")
	assert_false(ObjectShapes.is_lit(Tiles.Block.TORCH_BRACKET), "an empty bracket")
	var torch := Voxels.of_block(Tiles.Block.TORCH)
	var voxel_at := func(cell: Vector3i) -> int: return torch if cell == Vector3i(3, SEA, 0) else 0
	assert_true(Light.near_fire(voxel_at, Vector3i(0, SEA, 0)), "monsters keep away")


func test_where_torches_and_lanterns_go() -> void:
	var torch := Items.placed_voxel(Items.Id.TORCH)
	var lantern := Items.placed_voxel(Items.Id.LANTERN)
	var on_floor := Mining.placement(Vector3i(2, SEA, 2), torch, Vector2i(0, 1), _voxel_at)
	assert_eq(Voxels.block_of(on_floor.get(Vector3i(2, SEA, 2), 0)), Tiles.Block.TORCH)
	var on_wall := Vector3i(4, SEA + 1, 2)
	assert_true(
		Mining.placement(on_wall, torch, Vector2i(-1, 0), _voxel_at, Vector3i(-1, 0, 0)).is_empty(),
		"not straight against a wall"
	)
	# Into an empty bracket hung there.
	var bracket := Voxels.of_block(Tiles.Block.TORCH_BRACKET_WEST)
	var with_bracket := func(cell: Vector3i) -> int:
		return bracket if cell == on_wall else _voxel_at(cell)
	assert_true(Mining.fills(bracket, torch))
	var filled := Mining.placement(on_wall, torch, Vector2i(0, 1), with_bracket, Vector3i(-1, 0, 0))
	assert_eq(Voxels.block_of(filled[on_wall]), Tiles.Block.TORCH_BRACKET_LIT_WEST, "lit, same way")
	# A lantern on the floor, from the ceiling, on the wall.
	var floor := Mining.placement(Vector3i(2, SEA, 2), lantern, Vector2i(0, 1), _voxel_at)
	assert_eq(Voxels.block_of(floor.values()[0]), Tiles.Block.LANTERN)
	var under := Vector3i(3, SEA + 2, 3)
	var hung := Mining.placement(under, lantern, Vector2i(0, 1), _voxel_at, Vector3i.DOWN)
	assert_eq(Voxels.block_of(hung[under]), Tiles.Block.LANTERN_HANGING)
	var nothing_above := Vector3i(1, SEA + 2, 1)
	assert_true(
		(
			Mining
			. placement(nothing_above, lantern, Vector2i(0, 1), _voxel_at, Vector3i.DOWN)
			. is_empty()
		)
	)
	var side := Mining.placement(on_wall, lantern, Vector2i(-1, 0), _voxel_at, Vector3i(-1, 0, 0))
	assert_eq(Voxels.block_of(side[on_wall]), Tiles.Block.LANTERN_WALL_WEST)
	# What players placed does not give way to a block like a plant.
	assert_false(Mining.is_replaceable(torch))
	assert_false(Mining.is_replaceable(Voxels.of_block(Tiles.Block.CURTAINS_EAST)))
	assert_true(Mining.is_replaceable(Voxels.of_block(Tiles.Block.TALL_GRASS)), "plants still do")


func test_what_falls_and_what_comes_back() -> void:
	var rng := RandomNumberGenerator.new()
	var lit := Items.drops(Voxels.of_block(Tiles.Block.TORCH_BRACKET_LIT_EAST), Vector2i.ZERO, rng)
	assert_eq(lit, [Vector2i(Items.Id.TORCH_BRACKET, 1), Vector2i(Items.Id.TORCH, 1)])
	for block: int in [Tiles.Block.LANTERN_HANGING, Tiles.Block.LANTERN_WALL_NORTH]:
		var drops := Items.drops(Voxels.of_block(block), Vector2i.ZERO, rng)
		assert_eq(drops, [Vector2i(Items.Id.LANTERN, 1)], "a lantern")
	# A lantern hung from the ceiling falls with it, not with the floor.
	var hung := Voxels.of_block(Tiles.Block.LANTERN_HANGING)
	var voxel_at := func(cell: Vector3i) -> int:
		return hung if cell == Vector3i(3, SEA + 2, 3) else _voxel_at(cell)
	assert_false(Mining.needs_support(hung))
	assert_eq(Mining.hung_on(Vector3i(3, SEA + 3, 3), voxel_at), [Vector3i(3, SEA + 2, 3)])
	assert_true(Mining.hung_on(Vector3i(3, SEA + 1, 3), voxel_at).is_empty())


func test_the_lights_each_burn_their_way() -> void:
	var chunk := ChunkData.new(Vector2i.ZERO)
	for lz in GameConst.CHUNK_SIZE:
		for lx in GameConst.CHUNK_SIZE:
			chunk.set_voxel(Vector3i(lx, SEA - 1, lz), Voxels.of_block(Tiles.Block.STONE))
	chunk.set_voxel(Vector3i(2, SEA, 2), Voxels.of_block(Tiles.Block.TORCH))
	chunk.set_voxel(Vector3i(8, SEA, 8), Voxels.of_block(Tiles.Block.LANTERN))
	var job := ChunkJob.of_chunk(chunk, func(_coord: Vector2i) -> ChunkData: return null)
	job.variants.resize(Tiles.Block.size())
	var result := ChunkMesher.build(job)
	assert_eq(result.lava_spots.size(), 2)
	var torch := result.lava_spots.find(Vector3(2.5, 0.85, 2.5))
	assert_true(torch >= 0, "over the torch's head")
	assert_true(result.lava_flicker[torch] > result.lava_flicker[1 - torch], "a flame flickers")
	assert_ne(result.lava_colors[0], result.lava_colors[1], "each its own color")
	assert_eq(result.lava_colors.size(), result.lava_deep.size())
