extends TestCase
## New materials (phase 8, step 6): the cubes, their stairs and slabs,
## quarter blocks, painted plaster (in the meshes too), walls joining and
## stacking, pillars' bases and capitals, beams along the side aimed at,
## the recipes.

const SEA := GameConst.SEA_LEVEL
const SOUTH := Vector2i(0, 1)

var _server: GameServer
var _client: LocalTransport
var _session: GameServer.PlayerSession


## Voxels from a dictionary (cell -> voxel; air elsewhere).
func _world(cells: Dictionary) -> Callable:
	return func(cell: Vector3i) -> int: return cells.get(cell, Voxels.AIR)


## A server, a player, the cell two tiles east of their feet.
func _start() -> Vector3i:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	_server = GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	_server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	_server.process_messages()
	_client = transports[0]
	_session = _server.first_session()
	var feet := Coords.world_to_tile(_session.position)
	return Vector3i(feet.x + 2, floori(_session.height + 0.01) + SEA, feet.y)


func _made(item: int) -> bool:
	for recipe: Dictionary in Recipes.all():
		if recipe["result"][0] == item:
			return true
	return Smelting.FACTORY.values().has(item)


func test_every_new_cube() -> void:
	var rng := RandomNumberGenerator.new()
	var first := Tiles.Block.COBBLESTONE
	for block in range(first, Tiles.Block.SANDSTONE_BRICKS + 1):
		var name := String(Tiles.Block.find_key(block))
		var voxel := Voxels.of_block(block)
		assert_true(Voxels.is_cube(voxel), "%s is a cube" % name)
		assert_true(TileAtlas.BUILDING_WALLS.has(block), "%s is built with" % name)
		assert_eq(LightField.passing(voxel), LightField.OPAQUE)
		var item := Items.item_placing(block)
		assert_ne(item, Items.Id.NONE, "%s has an item" % name)
		assert_eq(Items.drops(voxel, Vector2i.ZERO, rng), [Vector2i(item, 1)], "%s back" % name)
		assert_ne(tr(Items.name_key(item)), Items.name_key(item), "%s named" % name)
		assert_true(_made(item), "%s is made" % name)
	assert_eq(Mining.tool_for(Voxels.of_block(Tiles.Block.OAK_HERRINGBONE)), Items.Tool.AXE)
	assert_eq(Mining.tool_for(Voxels.of_block(Tiles.Block.ASHLAR)), Items.Tool.PICKAXE)
	var stairs := Voxels.of_block(Tiles.Block.MOSSY_STONE_STAIRS_TOP_EAST)
	assert_true(Voxels.is_shaped(stairs), "stairs of the new stones")
	assert_eq(ShapedBlocks.material_of(Voxels.block_of(stairs)), Tiles.Block.MOSSY_STONE)
	var baked := Smelting.result_of(Tiles.Block.FACTORY_FURNACE, Items.Id.TERRACOTTA)
	assert_eq(baked, Items.Id.TERRACOTTA_BLOCK, "the factory furnace bakes terracotta")


func test_quarter_blocks() -> void:
	var block := Tiles.Block.STONE_BRICK_QUARTER
	var cell := Vector3i(0, SEA, 0)
	assert_eq(ShapedBlocks.shape_of(block), ShapedBlocks.Shape.QUARTER)
	var back := ShapedBlocks.side(-SOUTH)
	assert_eq(
		ShapedBlocks.mask(block, cell, Callable()), back & ShapedBlocks.LOW, "low, at the back"
	)
	# Against a wall's side (facing away from it), low or high.
	var wall := {cell + Vector3i(0, 0, -1): Voxels.of_block(Tiles.Block.STONE)}
	var low := ShapedBlocks.placement(cell, block, -SOUTH, Vector3i(0, 0, 1), false, _world(wall))
	assert_eq(Voxels.block_of(low[cell]), Tiles.Block.STONE_BRICK_QUARTER, "low, facing away")
	var high := ShapedBlocks.placement(cell, block, -SOUTH, Vector3i(0, 0, 1), true, _world(wall))
	var sill := Voxels.block_of(high[cell])
	assert_eq(ShapedBlocks.shape_of(sill), ShapedBlocks.Shape.QUARTER_TOP, "a sill")
	assert_eq(ShapedBlocks.mask(sill, cell, Callable()), back & ShapedBlocks.HIGH)
	assert_eq(ShapedBlocks.item_of(sill), Items.Id.STONE_BRICK_QUARTER, "one item")
	var made := false
	for recipe: Dictionary in Recipes.all():
		if recipe["result"][0] == Items.Id.STONE_BRICK_QUARTER:
			made = recipe["keys"]["M"] == Items.Id.STONE_BRICK_SLAB
	assert_true(made, "from slabs")


func test_plaster_takes_paint() -> void:
	var cell := _start()
	assert_true(Tints.painted(Tiles.Block.PLASTER))
	assert_true(Tints.painted(Tiles.Block.TIMBER_FRAME_CROSS))
	assert_true(Tints.painted(Tiles.Block.PLASTER_STAIRS_WEST), "its stairs")
	assert_true(Tints.painted(Tiles.Block.PLASTER_QUARTER_TOP), "its quarters")
	assert_false(Tints.painted(Tiles.Block.ASHLAR))
	_server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.PLASTER))
	_session.inventory.items[0] = Items.Id.PAINT_OCHRE
	_session.inventory.counts[0] = 1
	_client.send(Msg.tint(cell, 0, false))
	_server.process_messages()
	assert_eq(Tints.glass_of(Tints.at(_server.world, cell)), 13, "ochre plaster")


func test_painted_plaster_in_the_meshes() -> void:
	var chunk := ChunkData.new(Vector2i.ZERO)
	for lz in GameConst.CHUNK_SIZE:
		for lx in GameConst.CHUNK_SIZE:
			chunk.set_voxel(Vector3i(lx, SEA - 1, lz), Voxels.of_block(Tiles.Block.STONE))
	var wall := Vector3i(4, SEA, 4)
	var stairs := Vector3i(8, SEA, 4)
	chunk.set_voxel(wall, Voxels.of_block(Tiles.Block.PLASTER))
	chunk.set_voxel(stairs, Voxels.of_block(Tiles.Block.PLASTER_STAIRS))
	chunk.tints[wall] = Tints.pack(2, -1)
	chunk.tints[stairs] = Tints.pack(5, -1)
	chunk.recompute_tops()
	var job := ChunkJob.of_chunk(chunk, func(_c: Vector2i) -> ChunkData: return null)
	job.variants.resize(Tiles.Block.size())
	var result := ChunkMesher.build(job)
	var faces: ChunkMesher.Surface = result.parts[ChunkMesher.Part.FACES]
	var tops: ChunkMesher.Surface = result.parts[ChunkMesher.Part.TOPS]
	var plaster := ChunkMesher.top_code(Voxels.of_block(Tiles.Block.PLASTER))
	var codes := Array(tops.uv2s).map(func(uv: Vector2) -> int: return roundi(uv.x))
	assert_true(plaster + ChunkMesher.TINTED_CODE * 3 in codes, "a blue top")
	var sides := Array(faces.uv2s).map(func(uv: Vector2) -> float: return uv.y)
	assert_true(ChunkMesher.TINTED_SIDE - 2 in sides, "blue sides")
	assert_true(ShapedFaces.TINTED_TOP - 5 in sides, "green stairs' tops")
	assert_true(ChunkMesher.TINTED_SIDE - 5 in sides, "and sides")


func test_walls_join_and_stack() -> void:
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var wall := Tiles.Block.COBBLESTONE_WALL
	var gate := Voxels.of_block(ObjectShapes.facing(Tiles.Block.GATE, SOUTH))
	assert_true(Openings.joins(wall, stone), "a wall")
	assert_true(Openings.joins(wall, Voxels.of_block(Tiles.Block.BRICK_WALL)), "another wall")
	assert_true(Openings.joins(wall, gate), "a gate")
	assert_false(Openings.joins(wall, Voxels.AIR))
	assert_eq(ObjectShapes.variant_count(wall), ObjectShapes.FENCE_VARIANTS, "one per sides")
	var cells := {Vector3i(0, SEA - 1, 0): stone, Vector3i(0, SEA, 0): Voxels.of_block(wall)}
	var at := _world(cells)
	var tile := Vector2i.ZERO
	assert_true(PlayerBody.obstacle(tile, 0.0, at).has_area(), "nobody walks through")
	assert_true(PlayerBody.obstacle(tile, 1.0, at).has_area(), "nor jumps over")
	var stacked := Mining.placement(Vector3i(0, SEA + 1, 0), Voxels.of_block(wall), SOUTH, at)
	assert_eq(stacked.size(), 1, "it stacks")


func test_pillars_and_beams() -> void:
	var column := Voxels.of_block(Tiles.Block.STONE_COLUMN)
	var both := BuildShapes.BASE | BuildShapes.CAPITAL
	assert_eq(BuildShapes.pillar_bits(column, Voxels.AIR, Voxels.AIR), both, "alone")
	assert_eq(BuildShapes.pillar_bits(column, column, Voxels.AIR), BuildShapes.BASE, "foot")
	assert_eq(BuildShapes.pillar_bits(column, Voxels.AIR, column), BuildShapes.CAPITAL, "head")
	assert_eq(ObjectShapes.variant_count(Tiles.Block.WOOD_POST), BuildShapes.PILLAR_VARIANTS)
	# A beam lies along the side aimed at, needs nothing under it.
	var beam := Voxels.of_block(Tiles.Block.SPRUCE_BEAM)
	var cell := Vector3i(0, SEA + 3, 0)
	var along_x := Mining.placement(cell, beam, SOUTH, _world({}), Vector3i(1, 0, 0))
	assert_eq(Voxels.block_of(along_x[cell]), Tiles.Block.SPRUCE_BEAM_X, "along x")
	var up := Mining.placement(cell, beam, SOUTH, _world({}), Vector3i.UP)
	assert_eq(Voxels.block_of(up[cell]), Tiles.Block.SPRUCE_BEAM, "standing")
	assert_false(Mining.needs_support(along_x[cell]))
	var rng := RandomNumberGenerator.new()
	var drops := Items.drops(along_x[cell], Vector2i.ZERO, rng)
	assert_eq(drops, [Vector2i(Items.Id.SPRUCE_BEAM, 1)], "the beam back")
	assert_eq(Mining.tool_for(along_x[cell]), Items.Tool.AXE)
	for item: int in [Items.Id.STONE_COLUMN, Items.Id.WOOD_POST, Items.Id.DARK_OAK_BEAM]:
		assert_true(_made(item), "%d is made" % item)
	for item: int in Recipes.WALLS:
		assert_true(_made(item), "%d is made" % item)
