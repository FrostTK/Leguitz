extends TestCase
## Glass and panes (phase 8, step 2): tints packed, a pot of paint tinting
## glass or a window's frame, the watering can washing it, the axe scraping
## a frame, the last coat leaving its bottle, tints saved with their chunk
## and lost with their block, glass side by side drawn as one pane, panes
## joining their neighbors, the recipes.

const SEA := GameConst.SEA_LEVEL
const N := Items.Id.NONE
const FOLDER := "user://test_worlds/glass"

var _server: GameServer
var _client: LocalTransport
var _session: GameServer.PlayerSession


## A server, a player, the cell two tiles east of their feet.
func _start(mode := WorldSettings.GameMode.SURVIVAL) -> Vector3i:
	var settings := WorldSettings.create("Test", "42", mode)
	_server = GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	_server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	_server.process_messages()
	_client = transports[0]
	_session = _server.first_session()
	var feet := Coords.world_to_tile(_session.position)
	return Vector3i(feet.x + 2, floori(_session.height + 0.01) + SEA, feet.y)


func _tint(cell: Vector3i, item: int, frame := false) -> void:
	_session.inventory.items[0] = item
	_session.inventory.counts[0] = 1
	_session.inventory.wear[0] = 0
	_client.send(Msg.tint(cell, 0, frame))
	_server.process_messages()


func test_tints_are_packed() -> void:
	assert_eq(Tints.pack(-1, -1), 0, "none")
	var packed := Tints.pack(5, 15)
	assert_eq(Tints.glass_of(packed), 5)
	assert_eq(Tints.frame_of(packed), 15)
	assert_eq(Tints.COLORS.size(), Items.PAINTS.size(), "a color per pot")
	assert_eq(BoatModels.PAINT_COLORS, Tints.COLORS, "the boats' palette too")


func test_a_pot_tints_glass_and_the_can_washes_it() -> void:
	var cell := _start()
	_server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.GLASS))
	_tint(cell, Items.Id.PAINT_BLUE)
	assert_eq(Tints.at(_server.world, cell), Tints.pack(2, -1), "blue glass")
	assert_eq(_session.inventory.wear[0], 1, "a coat used")
	_tint(cell, Items.Id.PAINT_RED, true)
	assert_eq(Tints.at(_server.world, cell), Tints.pack(0, -1), "glass has no frame: its glass")
	var told := _client.poll().filter(func(m: Dictionary) -> bool: return m["t"] == Msg.TINTED)
	assert_eq(told.size(), 2, "the player is told")
	_tint(cell, Items.Id.WATERING_CAN)
	assert_eq(Tints.at(_server.world, cell), 0, "washed")
	_tint(cell, Items.Id.STONE)
	assert_eq(Tints.at(_server.world, cell), 0, "a stone does nothing")
	var far := cell + Vector3i(12, 0, 0)
	_server.world.set_voxel(far, Voxels.of_block(Tiles.Block.GLASS))
	_tint(far, Items.Id.PAINT_BLUE)
	assert_eq(Tints.at(_server.world, far), 0, "out of reach")


func test_a_window_frame_is_painted_and_scraped() -> void:
	var cell := _start()
	var window := Glass.window(Glass.Design.ROUND, 6)
	assert_eq(window, Tiles.Block.IRON_WINDOW_ROUND)
	_server.world.set_voxel(cell, Voxels.of_block(window))
	_tint(cell, Items.Id.PAINT_GREEN, true)
	assert_eq(Tints.frame_of(Tints.at(_server.world, cell)), 5, "a green frame")
	assert_eq(Tints.glass_of(Tints.at(_server.world, cell)), -1, "its glass clear")
	_tint(cell, Items.Id.PAINT_PINK)
	assert_eq(Tints.at(_server.world, cell), Tints.pack(4, 5), "pink glass in a green frame")
	_tint(cell, Items.Id.IRON_AXE)
	assert_eq(Tints.at(_server.world, cell), Tints.pack(4, -1), "the axe scrapes the frame")
	assert_eq(_session.inventory.wear[0], 1, "and wears")
	_tint(cell, Items.Id.WATERING_CAN)
	assert_eq(Tints.at(_server.world, cell), 0)


func test_the_last_coat_leaves_its_bottle() -> void:
	var cell := _start()
	_server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.LEADED_GLASS))
	var bag := _session.inventory
	bag.items[0] = Items.Id.PAINT_TEAL
	bag.counts[0] = 1
	bag.wear[0] = Items.PAINT_COATS - 1
	_client.send(Msg.tint(cell, 0, false))
	_server.process_messages()
	assert_eq(Tints.glass_of(Tints.at(_server.world, cell)), 15, "teal")
	assert_eq(bag.items[0], Items.Id.GLASS_BOTTLE, "the pot is empty: its bottle is left")
	assert_eq(bag.counts[0], 1)


func test_tints_are_saved_and_go_with_their_block() -> void:
	var storage := WorldStorage.new(FOLDER)
	storage.erase()
	var cell := _start()
	_server.use_storage(storage, {})
	_server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.OLD_GLASS))
	_tint(cell, Items.Id.PAINT_OCHRE)
	assert_true(_server.save())
	var again := GameServer.new(_server.settings, null, false)
	again.use_storage(WorldStorage.new(FOLDER), storage.read_world())
	again.world.get_or_create_chunk(Coords.tile_to_chunk(Vector2i(cell.x, cell.z)))
	assert_eq(Tints.at(again.world, cell), Tints.pack(13, -1), "saved with its chunk")
	var chunk := ChunkData.from_dict(again.world.chunks.values()[0].to_dict())
	assert_eq(chunk.tints.size(), 1, "sent with the chunk")
	_server.world.set_voxel(cell, Voxels.AIR)
	assert_eq(Tints.at(_server.world, cell), 0, "broken, its tint goes")
	storage.erase()


## A chunk on stone with glass on it.
func _built(cells: Dictionary) -> ChunkMesher.Result:
	var chunk := ChunkData.new(Vector2i.ZERO)
	for lz in GameConst.CHUNK_SIZE:
		for lx in GameConst.CHUNK_SIZE:
			chunk.set_voxel(Vector3i(lx, SEA - 1, lz), Voxels.of_block(Tiles.Block.STONE))
	for cell: Vector3i in cells:
		chunk.set_voxel(cell, cells[cell])
	chunk.recompute_tops()
	return ChunkMesher.build(ChunkJob.of_chunk(chunk, func(_c: Vector2i) -> ChunkData: return null))


func test_glass_side_by_side_is_one_pane() -> void:
	var glass := Voxels.of_block(Tiles.Block.GLASS)
	var none := _built({})
	var one := _built({Vector3i(4, SEA, 4): glass})
	assert_eq(one.parts[ChunkMesher.Part.GLASS].quad_count(), 5, "five faces (on stone)")
	var frames := one.parts[ChunkMesher.Part.FACES].quad_count()
	assert_eq(frames - none.parts[ChunkMesher.Part.FACES].quad_count(), 5, "and their borders")
	var two := _built({Vector3i(4, SEA, 4): glass, Vector3i(5, SEA, 4): glass})
	assert_eq(two.parts[ChunkMesher.Part.GLASS].quad_count(), 8, "nothing between them")
	var edges := []
	for i in two.parts[ChunkMesher.Part.GLASS].quad_count():
		var info := int(two.parts[ChunkMesher.Part.GLASS].uv2s[i * 4].y)
		edges.append(info & 15)
	assert_true(GlassFaces.U_END in edges or GlassFaces.U_START in edges, "the border goes")


func test_panes_join_their_neighbors() -> void:
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var cells := {Vector3i(1, 0, 0): stone, Vector3i(-1, 0, 0): stone}
	var at := func(cell: Vector3i) -> int: return cells.get(cell, Voxels.AIR)
	var pane := Tiles.Block.OLD_GLASS_PANE
	assert_eq(Glass.pane_sides(pane, Vector3i.ZERO, at), 0b1010, "east and west")
	cells.clear()
	assert_eq(Glass.pane_sides(pane, Vector3i.ZERO, at), 0b1010, "alone: across, facing south")
	var west := ObjectShapes.facing(pane, Vector2i(-1, 0))
	assert_eq(Glass.pane_sides(west, Vector3i.ZERO, at), 0b0101, "facing west: north to south")
	assert_true(Glass.is_pane(west))
	assert_eq(Glass.pane_glass(west), Tiles.Block.OLD_GLASS)
	assert_false(Tiles.Block.OLD_GLASS_PANE in VoxelModels.modeled_blocks(), "meshed as terrain")
	var built := _built({Vector3i(4, SEA, 4): Voxels.of_block(Tiles.Block.GLASS_PANE)})
	assert_true(built.parts[ChunkMesher.Part.GLASS].quad_count() > 0, "drawn as glass")
	assert_true(built.props.is_empty(), "no model")


func test_the_recipes() -> void:
	var g := Items.Id.GLASS
	var p := Items.Id.BIRCH_PLANKS
	var i := Items.Id.IRON_INGOT
	var four := Recipes.result_of(PackedInt32Array([p, p, p, p, g, p, p, p, p]), 3)
	assert_eq(four, Vector2i(Items.Id.BIRCH_WINDOW, 4))
	var oak := Items.Id.OAK_PLANKS
	assert_eq(
		Recipes.result_of(PackedInt32Array([oak, oak, oak, oak, g, oak, oak, oak, oak]), 3).x,
		Items.Id.WINDOW,
		"oak: the old window"
	)
	var small := Recipes.result_of(PackedInt32Array([i, g, i, i, g, i, i, g, i]), 3)
	assert_eq(small, Vector2i(Items.Id.IRON_WINDOW_SMALL, 4))
	var leaded := Recipes.result_of(PackedInt32Array([g, g, g, g, i, g, g, g, g]), 3)
	assert_eq(leaded, Vector2i(Items.Id.LEADED_GLASS, 8))
	var old := Recipes.result_of(PackedInt32Array([g, g, N, g, g, Items.Id.SAND, N, N, N]), 3)
	assert_eq(old, Vector2i(Items.Id.OLD_GLASS, 4))
	var o := Items.Id.LINSEED_OIL
	var paint := Recipes.result_of(PackedInt32Array([o, Items.Id.RED_SAND, N, N, N, N, N, N, N]), 3)
	assert_eq(paint.x, Items.Id.PAINT_OCHRE)
	for frame in Glass.FRAMES.size():
		for design in Glass.DESIGNS.size():
			var window := Glass.window(design, frame)
			assert_true(Glass.is_window(window))
			assert_true(TileAtlas.CLEAR_WALLS.has(window), "seen through")
			assert_true(Items.item_placing(window) != N, "an item places it")
