extends TestCase
## Roofs (phase 8, step 5): slopes turn their corners (hips, valleys),
## ridges hip their ends and cross, gentle slopes go low then high; a roof
## is walked up, keeps the sky out and tops its column; dormers go in a
## roof, a chimney rises on a chimney and smokes over a fire; the meshes;
## the items and recipes.

const SEA := GameConst.SEA_LEVEL
const SOUTH := Vector2i(0, 1)
const EAST := Vector2i(1, 0)


## Voxels from a dictionary (cell -> voxel; air elsewhere).
func _world(cells: Dictionary) -> Callable:
	return func(cell: Vector3i) -> int: return cells.get(cell, Voxels.AIR)


func _slope(kind: int, front: Vector2i) -> int:
	return Voxels.of_block(ObjectShapes.facing(kind, front))


func _height(cells: Dictionary, cell: Vector3i, x: float, z: float) -> float:
	var block := Voxels.block_of(cells[cell])
	return RoofBlocks.height_at(RoofBlocks.surface(block, cell, _world(cells)), x, z)


func test_every_piece_is_a_roof() -> void:
	var count := 0
	for block: int in Tiles.Block.values():
		if not Tiles.is_roof(block):
			continue
		count += 1
		var voxel := Voxels.of_block(block)
		var name := String(Tiles.Block.find_key(block))
		assert_true(Voxels.is_roof(voxel) and Voxels.is_shaped(voxel), name)
		assert_eq(LightField.passing(voxel), LightField.OPAQUE, "%s keeps the sky out" % name)
		assert_true(RoofBlocks.covering_of(block) >= 0, name)
		assert_true(Tiles.is_cube(RoofBlocks.material_of(block)), "%s has a covering" % name)
	assert_eq(count, RoofBlocks.COVERINGS.size() * 14)
	for entry: Array in RoofBlocks.items():
		var item: int = entry[0]
		assert_ne(tr(Items.name_key(item)), Items.name_key(item), "named")
		assert_true(Mining.can_place(Items.placed_voxel(item)), "placed")
	var items: Array[int] = [Items.Id.CHIMNEY]
	for covering: Array in RoofBlocks.COVERINGS:
		items.append(covering[2])
		items.append(Items.item_placing(covering[3]))
	for entry: Array in RoofBlocks.items():
		items.append(entry[0])
	for item in items:
		assert_ne(tr(Items.name_key(item)), Items.name_key(item), "%d named" % item)
		var made := false
		for recipe: Dictionary in Recipes.all():
			made = made or recipe["result"][0] == item
		assert_true(made, "%s has a recipe" % Items.name_key(item))


func test_a_slope_rises_away_and_turns_its_corners() -> void:
	var cell := Vector3i(0, SEA, 0)
	var cells := {cell: _slope(Tiles.Block.TILE_ROOF, SOUTH)}
	assert_almost(_height(cells, cell, 0.5, 0.0), 1.0, 0.001, "high at its back")
	assert_almost(_height(cells, cell, 0.5, 1.0), 0.0, 0.001, "low in front")
	# A slope facing east behind it: an outer corner, a hip.
	cells[cell - Vector3i(0, 0, 1)] = _slope(Tiles.Block.TILE_ROOF, EAST)
	assert_almost(_height(cells, cell, 0.9, 0.1), 0.1, 0.001, "the hip")
	assert_almost(_height(cells, cell, 0.1, 0.1), 0.9, 0.001)
	# Instead, one facing east in front of it: an inner corner, a valley.
	cells.erase(cell - Vector3i(0, 0, 1))
	cells[cell + Vector3i(0, 0, 1)] = _slope(Tiles.Block.SLATE_ROOF, EAST)
	assert_almost(_height(cells, cell, 0.1, 0.9), 0.9, 0.001, "the valley")
	assert_almost(_height(cells, cell, 0.9, 0.9), 0.1, 0.001)


func test_ridges_hip_their_ends_and_cross() -> void:
	var cell := Vector3i(0, SEA + 1, 0)
	var ridge := Voxels.of_block(Tiles.Block.THATCH_ROOF_RIDGE)
	var cells := {cell: ridge}
	assert_almost(_height(cells, cell, 0.5, 0.5), 0.5, 0.001, "peaks in the middle")
	assert_almost(_height(cells, cell, 0.5, 0.0), 0.0, 0.001, "down both sides")
	assert_almost(_height(cells, cell, 1.0, 0.5), 0.5, 0.001, "a gable's end")
	# A roof goes on lower east of it: its east end is hipped.
	cells[cell + Vector3i(1, -1, 0)] = _slope(Tiles.Block.THATCH_ROOF, EAST)
	assert_almost(_height(cells, cell, 1.0, 0.5), 0.0, 0.001, "hipped")
	assert_almost(_height(cells, cell, 0.0, 0.5), 0.5, 0.001, "not the other end")
	var peaks := RoofBlocks.peaks(Tiles.Block.THATCH_ROOF_RIDGE, cell, _world(cells))
	assert_eq(peaks[0][1], Vector2(0.5, 0.5), "its cap stops at the hip")
	# A ridge running off south across it.
	cells[cell + Vector3i(0, 0, 1)] = Voxels.of_block(Tiles.Block.THATCH_ROOF_RIDGE_NS)
	assert_almost(_height(cells, cell, 0.5, 0.9), 0.5, 0.001, "the branch")
	assert_almost(_height(cells, cell, 0.5, 0.1), 0.1, 0.001, "not north")
	# Placed beside a ridge, a ridge lies along it.
	var placed := RoofBlocks.placement(
		cell + Vector3i(-1, 0, 0), Tiles.Block.TILE_ROOF_RIDGE, EAST, false, _world(cells)
	)
	assert_eq(placed.values()[0], Voxels.of_block(Tiles.Block.TILE_ROOF_RIDGE))


func test_gentle_slopes_go_low_then_high() -> void:
	var cell := Vector3i(0, SEA, 0)
	var cells := {}
	var at := _world(cells)
	var low := RoofBlocks.placement(cell, Tiles.Block.SLATE_ROOF_GENTLE, SOUTH, false, at)
	cells[cell] = low[cell]
	assert_eq(Voxels.block_of(cells[cell]), Tiles.Block.SLATE_ROOF_GENTLE, "low first")
	var back := cell - Vector3i(0, 0, 1)
	var high := RoofBlocks.placement(back, Tiles.Block.SLATE_ROOF_GENTLE, SOUTH, false, at)
	cells[back] = high[back]
	assert_eq(Voxels.block_of(cells[back]), Tiles.Block.SLATE_ROOF_GENTLE_HIGH, "then high")
	assert_almost(_height(cells, cell, 0.5, 0.0), 0.5, 0.001)
	assert_almost(_height(cells, back, 0.5, 1.0), 0.5, 0.001, "they meet")
	assert_almost(_height(cells, back, 0.5, 0.0), 1.0, 0.001)
	# Shift turns a slope the other way.
	var turned := RoofBlocks.placement(cell, Tiles.Block.TILE_ROOF, SOUTH, true, _world({}))
	assert_eq(RoofBlocks.front_of(Voxels.block_of(turned[cell])), -SOUTH)


func test_a_roof_is_walked_up() -> void:
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var cells := {}
	for x in range(-1, 2):
		for z in range(-3, 4):
			cells[Vector3i(x, SEA - 1, z)] = stone
	for step in 3:
		cells[Vector3i(0, SEA + step, 1 - step)] = _slope(Tiles.Block.SHINGLE_ROOF, SOUTH)
	var at := _world(cells)
	var body := PlayerBody.new()
	body.place(Vector2(8.0, 2.5 * 16.0), 0.0)
	var last := body.height
	for i in 22:
		body.step(Vector2(0.0, -2.0), false, 0.05, at)
		assert_true(body.height - last < PlayerBody.STEP_UP, "smoothly")
		last = body.height
	assert_true(body.height > 2.0, "up on the roof: %f" % body.height)
	var alone := RoofBlocks.surface(Tiles.Block.TILE_ROOF, Vector3i.ZERO, at)
	assert_eq(RoofBlocks.boxes(alone, Vector3i.ZERO).size(), RoofBlocks.BOX_STEPS, "columns joined")


func test_a_roof_keeps_the_sky_out_and_tops_its_column() -> void:
	var chunk := ChunkData.new(Vector2i.ZERO)
	for z in 16:
		for x in 16:
			chunk.set_voxel(Vector3i(x, SEA - 1, z), Voxels.of_block(Tiles.Block.STONE))
	for z in range(4, 9):
		for x in range(4, 9):
			chunk.set_voxel(Vector3i(x, SEA + 3, z), _slope(Tiles.Block.TILE_ROOF, SOUTH))
	assert_eq(chunk.top_row(Vector2i(6, 6)), SEA + 4, "the roof tops its column")
	assert_eq(chunk.top_row(Vector2i(1, 1)), SEA, "not beside it")
	var sky := LightField.sky(chunk.voxels, chunk.tops, 16)
	var levels: PackedByteArray = sky[0]
	var under := (6 * 16 + 6) * ChunkData.HEIGHT + SEA
	assert_true(levels[under] < LightField.MAX, "darker under it: %d" % levels[under])
	chunk.set_voxel(Vector3i(6, SEA + 3, 6), Voxels.AIR)
	assert_eq(chunk.top_row(Vector2i(6, 6)), SEA, "gone, the column is open")


func test_dormers_and_chimneys() -> void:
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var chimney := Voxels.of_block(Tiles.Block.CHIMNEY)
	var cell := Vector3i(0, SEA + 2, 0)
	# A dormer needs nothing under it.
	var dormer := Voxels.of_block(Tiles.Block.SLATE_DORMER)
	var placed := Mining.placement(cell, dormer, SOUTH, _world({}))
	assert_eq(placed.size(), 1, "in a roof, over the attic")
	assert_true(RoofBlocks.is_dormer(Voxels.block_of(placed[cell])))
	assert_false(Mining.needs_support(placed[cell]))
	assert_eq(RoofBlocks.covering_of(Voxels.block_of(placed[cell])), 1, "slates")
	# A chimney on a floor, then on itself.
	var cells := {Vector3i(0, SEA - 1, 0): stone}
	var foot := Vector3i(0, SEA, 0)
	assert_eq(Mining.placement(foot, chimney, SOUTH, _world(cells)).size(), 1, "on a floor")
	assert_true(Mining.placement(cell, chimney, SOUTH, _world(cells)).is_empty(), "not in the air")
	cells[foot + Vector3i.UP] = chimney
	var stacked := Mining.placement(foot + Vector3i(0, 2, 0), chimney, SOUTH, _world(cells))
	assert_eq(stacked.size(), 1, "on a chimney")
	# It smokes with a fire under it, not without.
	assert_false(RoofBlocks.smokes(foot + Vector3i.UP, _world(cells)), "no fire")
	cells[foot] = Voxels.of_block(Tiles.Block.CAMPFIRE)
	assert_true(RoofBlocks.smokes(foot + Vector3i.UP, _world(cells)), "a campfire under it")
	cells[foot] = Voxels.of_block(ObjectShapes.facing(Tiles.Block.FOOD_FURNACE_LIT, EAST))
	assert_true(RoofBlocks.smokes(foot + Vector3i.UP, _world(cells)), "a lit furnace")
	cells[foot] = Voxels.of_block(ObjectShapes.facing(Tiles.Block.FOOD_FURNACE, EAST))
	assert_false(RoofBlocks.smokes(foot + Vector3i.UP, _world(cells)), "out")
	assert_eq(ObjectShapes.variant_count(Tiles.Block.CHIMNEY), 2, "shaft and top")


func test_the_meshes() -> void:
	var voxels := PackedInt32Array()
	voxels.resize(ShapedFaces.SPAN * ShapedFaces.SPAN * ShapedFaces.HEIGHT)
	var flags := Voxels.flag_table()
	var kinds := PackedInt32Array()
	kinds.resize(Voxels.used_ids())
	for voxel in Voxels.used_ids():
		kinds[voxel] = ChunkMesher.face_kind(voxel)
	var column := (3 + 1) * ShapedFaces.SPAN + 4 + 1
	var index := column * ShapedFaces.HEIGHT + 70
	voxels[index] = _slope(Tiles.Block.TILE_ROOF, SOUTH)
	var bricks := Voxels.of_block(Tiles.Block.BRICKS)
	voxels[index - 1] = bricks
	var lights := PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
	var alone := ChunkMesher.Surface.new()
	RoofFaces.add(alone, voxels, flags, kinds, Vector3i(4, 70, 3), 0.0, lights)
	var roofs := 0
	var gables := 0
	for i in alone.uv2s.size():
		if alone.uv2s[i].y == RoofFaces.ROOF_FACE:
			roofs += 1
		elif alone.normals[i].x != 0.0 and int(alone.uv2s[i].x) == kinds[bricks]:
			gables += 1
	assert_true(roofs >= 4, "its covering on top: %d" % roofs)
	assert_eq(gables, 16, "both gables in the wall's bricks")
	# A slope beside it: that gable is covered, the other has its verge.
	voxels[index + ShapedFaces.HEIGHT] = voxels[index]
	var joined := ChunkMesher.Surface.new()
	RoofFaces.add(joined, voxels, flags, kinds, Vector3i(4, 70, 3), 0.0, lights)
	var east := 0
	for i in joined.normals.size():
		if joined.normals[i] == Vector3.RIGHT and joined.uv2s[i].y != RoofFaces.ROOF_FACE:
			east += 1
	assert_eq(east, 0, "covered on the east")
	var mesh := ItemLibrary._roof(Items.placed_voxel(Items.Id.THATCH_ROOF_RIDGE))
	assert_true(mesh.get_surface_count() > 0, "an icon")
