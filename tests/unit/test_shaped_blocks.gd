extends TestCase
## Stairs and slabs (ShapedBlocks): every material's blocks, items and
## recipes; their octants (straight stairs, corners, upside down, slabs,
## side slabs); walked up half a level at a time, stood on, a ceiling;
## aimed at on their octants; placed facing the player, upside down, two
## halves making the cube; their faces in the chunk meshes.

const TS := GameConst.TILE_SIZE
const DT := 1.0 / 60.0
const SEA := GameConst.SEA_LEVEL

## A flat world (ground at level 0, nothing known beyond x = 20) and what
## stands on it.
var _extra: Dictionary[Vector3i, int] = {}


func _voxel_at(cell: Vector3i) -> int:
	if _extra.has(cell):
		return _extra[cell]
	if cell.x > 20:
		return Voxels.UNKNOWN
	return Voxels.of_ground(Tiles.Ground.GRASS) if cell.y < SEA else Voxels.AIR


func _put(x: int, level: int, z: int, block: int) -> void:
	_extra[Vector3i(x, SEA + level, z)] = Voxels.of_block(block)


func _body_at(tile_x: float, height := 0.0) -> PlayerBody:
	var body := PlayerBody.new()
	body.place(Vector2(tile_x * TS, 1.5 * TS), height)
	body.step(Vector2.ZERO, false, DT, _voxel_at)
	return body


func _walk(body: PlayerBody, speed: float, seconds: float, jump := false) -> void:
	for i in int(seconds / DT):
		body.step(Vector2(speed * DT, 0.0), jump, DT, _voxel_at)


func _mask(block: int, x := 0, z := 1) -> int:
	return ShapedBlocks.mask(block, Vector3i(x, SEA, z), _voxel_at)


func test_every_material_has_its_stairs_and_slabs() -> void:
	var rng := RandomNumberGenerator.new()
	var count := 0
	for block: int in Tiles.Block.values():
		if not ShapedBlocks.is_shaped(block):
			continue
		count += 1
		var name := String(Tiles.Block.find_key(block))
		var voxel := Voxels.of_block(block)
		assert_true(Voxels.is_shaped(voxel) and Voxels.is_solid(voxel), name)
		assert_false(Voxels.is_cube(voxel), "%s is no cube" % name)
		var material := ShapedBlocks.material_of(block)
		assert_true(Tiles.is_cube(material), "%s is made of a cube" % name)
		var item := ShapedBlocks.item_of(block)
		assert_eq(Items.drops(voxel, Vector2i.ZERO, rng), [Vector2i(item, 1)], "%s back" % name)
		assert_eq(PickBlock.item_of(voxel, true), item, "%s picked" % name)
		var stone := Voxels.of_block(material)
		assert_eq(Mining.hand_seconds(voxel), Mining.hand_seconds(stone), "%s breaks so" % name)
		assert_eq(Mining.tool_for(voxel), Mining.tool_for(stone))
		assert_false(Mining.needs_support(voxel), "%s may overhang" % name)
	assert_eq(count, ShapedBlocks.MATERIALS.size() * 14)
	assert_eq(ShapedBlocks.items().size(), ShapedBlocks.MATERIALS.size() * 3)
	for entry: Array in ShapedBlocks.items():
		var item: int = entry[0]
		assert_ne(tr(Items.name_key(item)), Items.name_key(item), "named")
		assert_true(Mining.can_place(Items.placed_voxel(item)), "placed")
		var made := false
		for recipe: Dictionary in Recipes.all():
			made = made or recipe["result"][0] == item
		assert_true(made, "%s has a recipe" % Items.name_key(item))
	var mesh := ItemLibrary._shaped(Items.placed_voxel(Items.Id.OAK_STAIRS))
	assert_eq(mesh.get_surface_count(), 2, "an icon: its top and its sides")


func test_their_octants() -> void:
	assert_eq(_mask(Tiles.Block.OAK_SLAB), ShapedBlocks.LOW)
	assert_eq(_mask(Tiles.Block.OAK_SLAB_TOP), ShapedBlocks.HIGH)
	# A side slab fills its back half: facing south, the north half.
	assert_eq(_mask(Tiles.Block.STONE_SIDE_SLAB), ShapedBlocks.side(Vector2i(0, -1)))
	assert_eq(_mask(Tiles.Block.STONE_SIDE_SLAB_EAST), ShapedBlocks.side(Vector2i(-1, 0)))
	# Stairs facing south: the low step south, the high part north.
	var north_high := ShapedBlocks.side(Vector2i(0, -1)) & ShapedBlocks.HIGH
	assert_eq(_mask(Tiles.Block.OAK_STAIRS), ShapedBlocks.LOW | north_high)
	var under := ShapedBlocks.side(Vector2i(0, -1)) & ShapedBlocks.LOW
	assert_eq(_mask(Tiles.Block.OAK_STAIRS_TOP), ShapedBlocks.HIGH | under, "upside down")
	# Behind it (north) stairs rising west: an outer corner, a quarter high.
	_put(0, 0, 0, Tiles.Block.BRICK_STAIRS_EAST)
	var quarter := north_high & ShapedBlocks.side(Vector2i(-1, 0))
	assert_eq(_mask(Tiles.Block.OAK_STAIRS), ShapedBlocks.LOW | quarter, "outer corner")
	_extra.clear()
	# In front (south) stairs rising west: an inner corner, three quarters.
	_put(0, 0, 2, Tiles.Block.BRICK_STAIRS_EAST)
	var more := ShapedBlocks.side(Vector2i(0, 1)) & ShapedBlocks.side(Vector2i(-1, 0))
	assert_eq(
		_mask(Tiles.Block.OAK_STAIRS),
		ShapedBlocks.LOW | north_high | (more & ShapedBlocks.HIGH),
		"inner corner"
	)
	_extra.clear()
	var boxes := ShapedBlocks.boxes(ShapedBlocks.LOW, Vector3i(2, SEA, 3))
	var total := 0.0
	for box in boxes:
		total += box.get_volume()
	assert_true(absf(total - 0.5) < 0.001, "a slab is half a cell")
	assert_true(boxes.size() <= 2, "its halves joined")


func test_bodies_walk_up_half_a_level_and_stand_on_them() -> void:
	_extra.clear()
	_put(3, 0, 1, Tiles.Block.STONE_SLAB)
	for x in range(4, 9):
		_put(x, 0, 1, Tiles.Block.STONE)
	var body := _body_at(1.5)
	_walk(body, 4.0 * TS, 1.0)
	assert_true(body.feet.x > 4.0 * TS, "up the slab, then onto the block, without jumping")
	assert_eq(body.height, 1.0)
	# A whole level still wants a jump.
	_extra.clear()
	_put(3, 0, 1, Tiles.Block.STONE)
	body = _body_at(1.5)
	_walk(body, 4.0 * TS, 1.0)
	assert_true(body.feet.x < 3.0 * TS, "a block is jumped")
	# Stairs rising east (facing west): two steps.
	_extra.clear()
	_put(3, 0, 1, Tiles.Block.OAK_STAIRS_WEST)
	body = _body_at(1.5)
	_walk(body, 3.0 * TS, 0.8)
	assert_eq(body.height, 1.0, "up the stairs")
	assert_true(body.feet.x > 3.5 * TS)
	# Standing on a slab.
	_extra.clear()
	_put(2, 0, 1, Tiles.Block.OAK_SLAB)
	body = _body_at(2.5, 0.5)
	assert_eq(body.height, 0.5, "on the slab")
	# A high slab over the head is a ceiling.
	_extra.clear()
	_put(2, 2, 1, Tiles.Block.OAK_SLAB_TOP)
	body = _body_at(2.5)
	_walk(body, 0.0, 0.4, true)
	var highest := body.height
	for i in 30:
		body.step(Vector2.ZERO, i == 0, DT, _voxel_at)
		highest = maxf(highest, body.height)
	assert_true(highest <= 2.5 - PlayerBody.BODY_HEIGHT + 0.01, "bumped: %.2f" % highest)
	assert_eq(Pathfinder.ground_at(Vector2i(2, 1), 0.0, _voxel_at, 1.0), 0.0, "under it")
	_put(5, 0, 1, Tiles.Block.OAK_SLAB)
	assert_eq(Pathfinder.ground_at(Vector2i(5, 1), 0.0, _voxel_at, 1.0), 0.5, "animals too")
	_extra.clear()


func test_they_are_aimed_at_on_their_octants() -> void:
	_extra.clear()
	_put(2, 0, 2, Tiles.Block.OAK_SLAB)
	var down := VoxelRay.cast(Vector3(2.5, 3.0, 2.5), Vector3.DOWN, 6.0, _voxel_at)
	assert_eq(down.cell, Vector3i(2, SEA, 2))
	assert_eq(down.normal, Vector3i.UP)
	assert_true(absf(down.point.y - 0.5) < 0.001, "on the slab's top")
	# Over the slab, the ray goes on.
	var over := VoxelRay.cast(Vector3(0.5, 0.75, 2.5), Vector3.RIGHT, 6.0, _voxel_at)
	assert_true(over == null or over.cell != Vector3i(2, SEA, 2), "the empty half let through")
	var side := VoxelRay.cast(Vector3(0.5, 0.25, 2.5), Vector3.RIGHT, 6.0, _voxel_at)
	assert_eq(side.cell, Vector3i(2, SEA, 2))
	assert_eq(side.normal, Vector3i(-1, 0, 0))
	_extra.clear()


func test_they_are_placed_facing_the_player_and_halves_join() -> void:
	_extra.clear()
	var at := Vector3i(2, SEA, 2)
	var stairs := Items.placed_voxel(Items.Id.OAK_STAIRS)
	var placed := Mining.placement(at, stairs, Vector2i(1, 0), _voxel_at)
	assert_eq(placed, {at: Voxels.of_block(Tiles.Block.OAK_STAIRS_EAST)}, "facing the player")
	placed = Mining.placement(at, stairs, Vector2i(1, 0), _voxel_at, Vector3i(-1, 0, 0), true)
	var flipped := Voxels.of_block(Tiles.Block.OAK_STAIRS_TOP_EAST)
	assert_eq(placed, {at: flipped}, "aimed high: upside down")
	placed = Mining.placement(at, stairs, Vector2i(1, 0), _voxel_at, Vector3i.DOWN)
	assert_eq(placed, {at: flipped}, "under a ceiling")
	var slab := Items.placed_voxel(Items.Id.BRICK_SLAB)
	assert_eq(Mining.placement(at, slab, Vector2i(0, 1), _voxel_at), {at: slab}, "low")
	placed = Mining.placement(at, slab, Vector2i(0, 1), _voxel_at, Vector3i.DOWN)
	assert_eq(placed, {at: Voxels.of_block(Tiles.Block.BRICK_SLAB_TOP)}, "high")
	_extra[at] = slab
	assert_true(ShapedBlocks.completes(slab, Vector3i.UP, Items.Id.BRICK_SLAB))
	assert_false(ShapedBlocks.completes(slab, Vector3i.UP, Items.Id.OAK_SLAB), "not oak")
	placed = Mining.placement(at, slab, Vector2i(0, 1), _voxel_at, Vector3i.UP)
	assert_eq(placed, {at: Voxels.of_block(Tiles.Block.BRICKS)}, "two halves: the block")
	# A side slab against the wall aimed at (its east side), facing away.
	_extra.clear()
	var side := Items.placed_voxel(Items.Id.STONE_SIDE_SLAB)
	placed = Mining.placement(at, side, Vector2i(0, 1), _voxel_at, Vector3i(1, 0, 0))
	assert_eq(placed, {at: Voxels.of_block(Tiles.Block.STONE_SIDE_SLAB_EAST)})
	_extra[at] = placed[at]
	placed = Mining.placement(at, side, Vector2i(0, 1), _voxel_at, Vector3i(-1, 0, 0))
	assert_eq(placed, {at: Voxels.of_block(Tiles.Block.STONE)}, "the other half")
	_extra.clear()


func test_placed_through_the_server_and_crafted() -> void:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	var client: LocalTransport = transports[0]
	client.send(Msg.hello("Alex", 2))
	server.process_messages()
	var session := server.first_session()
	var tile := Coords.world_to_tile(session.position)
	var row := floori(session.height + 0.01) + SEA
	var cell := Vector3i(tile.x + 2, row, tile.y)
	server.world.set_voxel(cell, Voxels.AIR)
	server.world.set_voxel(cell + Vector3i.UP, Voxels.AIR)
	server.world.set_voxel(cell + Vector3i.DOWN, Voxels.of_block(Tiles.Block.STONE))
	session.inventory.items[0] = Items.Id.STONE_BRICK_STAIRS
	session.inventory.counts[0] = 3
	client.send(Msg.block_place(cell, 0, Vector2i(-1, 0), Vector3i(-1, 0, 0), true))
	server.process_messages()
	var there := Voxels.block_of(server.world.voxel_at(cell))
	assert_eq(there, Tiles.Block.STONE_BRICK_STAIRS_TOP_WEST, "upside down, facing the player")
	assert_eq(session.inventory.counts[0], 2)
	var grid := PackedInt32Array()
	grid.resize(9)
	for i: int in [0, 3, 4, 6, 7, 8]:
		grid[i] = Items.Id.OAK_PLANKS
	assert_eq(Recipes.result_of(grid, 3), Vector2i(Items.Id.OAK_STAIRS, 4), "six planks")
	grid.fill(Items.Id.NONE)
	for i: int in [3, 4, 5]:
		grid[i] = Items.Id.SANDSTONE
	assert_eq(Recipes.result_of(grid, 3), Vector2i(Items.Id.SANDSTONE_SLAB, 6), "three in a row")
	grid.fill(Items.Id.NONE)
	grid[0] = Items.Id.SANDSTONE_SLAB
	grid[4] = Items.Id.SANDSTONE_SLAB
	assert_eq(Recipes.result_of(grid, 3), Vector2i(Items.Id.SANDSTONE, 1), "two halves")


func test_their_faces_in_the_meshes() -> void:
	var voxels := PackedInt32Array()
	voxels.resize(ShapedFaces.SPAN * ShapedFaces.SPAN * ShapedFaces.HEIGHT)
	var flags := Voxels.flag_table()
	var slab := Voxels.of_block(Tiles.Block.OAK_SLAB)
	var index := ((2 + 1) * ShapedFaces.SPAN + 3 + 1) * ShapedFaces.HEIGHT + 70
	voxels[index] = slab
	var kind := ChunkMesher.face_kind(Voxels.of_block(Tiles.Block.OAK_PLANKS))
	var alone := ChunkMesher.Surface.new()
	ShapedFaces.add(alone, voxels, flags, kind, 3, 70, 2, Color.WHITE)
	assert_eq(alone.quad_count(), 16, "four octants: tops, bottoms, the sides out")
	voxels[index - 1] = Voxels.of_block(Tiles.Block.STONE)
	voxels[index + ShapedFaces.HEIGHT] = slab
	var joined := ChunkMesher.Surface.new()
	ShapedFaces.add(joined, voxels, flags, kind, 3, 70, 2, Color.WHITE)
	assert_eq(joined.quad_count(), 10, "on a block, beside a slab: those faces hidden")
	var tops := 0
	for uv2 in joined.uv2s:
		if uv2.y == ShapedFaces.TOP_FACE:
			tops += 1
	assert_eq(tops, 16, "its tops wear the material's top (4 vertices each)")
