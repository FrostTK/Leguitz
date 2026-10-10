extends TestCase
## Curtains and rugs (phase 8, step 3): curtains drawn and tied back
## (keeping their tint), keeping the daylight out drawn; long ones wanting
## the floor free; rugs lying under what is placed on them and coming
## back, falling with their floor; rugs joining those of their tint; dyed
## cloth carrying its color; the recipes.

const SEA := GameConst.SEA_LEVEL
const N := Items.Id.NONE

var _server: GameServer
var _client: LocalTransport
var _session: GameServer.PlayerSession


## A server, a player, the cell two tiles east of their feet on stone, free
## up to three rows.
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
	var cell := Vector3i(feet.x + 2, floori(_session.height + 0.01) + SEA, feet.y)
	_server.world.set_voxel(cell + Vector3i.DOWN, Voxels.of_block(Tiles.Block.STONE))
	for up in 3:
		_server.world.set_voxel(cell + Vector3i(0, up, 0), Voxels.AIR)
	return cell


func _hold(item: int, count := 1) -> void:
	_session.inventory.items[0] = item
	_session.inventory.counts[0] = count
	_session.inventory.wear[0] = 0


func _send(message: Dictionary) -> void:
	_client.send(message)
	_server.process_messages()


func test_curtains_are_drawn_and_keep_the_daylight_out() -> void:
	var cell := _start()
	var wall := cell + Vector3i(1, 1, 0)
	_server.world.set_voxel(wall, Voxels.of_block(Tiles.Block.WINDOW))
	var at := cell + Vector3i(0, 1, 0)
	var west := ObjectShapes.facing(Tiles.Block.CURTAINS_IRON, Vector2i(-1, 0))
	_server.world.set_voxel(at, Voxels.of_block(west))
	_hold(Items.Id.PAINT_BURGUNDY)
	_send(Msg.tint(at, 0, false))
	assert_eq(Tints.at(_server.world, at), Tints.pack(14, -1), "dyed")
	_send(Msg.swing_gate(at))
	var drawn := Voxels.block_of(_server.world.voxel_at(at))
	assert_eq(ObjectShapes.kind_of(drawn), Tiles.Block.CURTAINS_IRON_CLOSED, "drawn")
	assert_eq(ObjectShapes.front_of(drawn), Vector2i(-1, 0), "the same way")
	assert_eq(Tints.at(_server.world, at), Tints.pack(14, -1), "their tint kept")
	assert_eq(LightField.passing(Voxels.of_block(drawn)), LightField.OPAQUE, "no daylight")
	assert_eq(LightField.passing(Voxels.of_block(west)), LightField.CLEAR, "tied back: some")
	var rng := RandomNumberGenerator.new()
	var drops := Items.drops(Voxels.of_block(drawn), Vector2i.ZERO, rng)
	assert_eq(drops[0].x, Items.Id.CURTAINS_IRON, "they give themselves back")
	_send(Msg.swing_gate(at))
	assert_eq(_server.world.voxel_at(at), Voxels.of_block(west), "tied back again")
	assert_true(ObjectShapes.same_piece(drawn, west))
	assert_false(ObjectShapes.same_piece(drawn, Tiles.Block.CURTAINS))


func test_long_curtains_hang_down_to_a_free_floor() -> void:
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var cells := {Vector3i(1, 1, 0): stone}
	var at := func(cell: Vector3i) -> int: return cells.get(cell, Voxels.AIR)
	var long := Voxels.of_block(Tiles.Block.CURTAINS_LONG)
	var hung := Mining.placement(Vector3i(0, 1, 0), long, Vector2i(-1, 0), at, Vector3i.LEFT)
	assert_eq(hung.size(), 1, "the floor under them free")
	cells[Vector3i(0, 0, 0)] = stone
	assert_true(
		Mining.placement(Vector3i(0, 1, 0), long, Vector2i(-1, 0), at, Vector3i.LEFT).is_empty(),
		"a block under them"
	)
	assert_eq(ObjectShapes.SUNK[Tiles.Block.CURTAINS_LONG_CLOSED], 1.0, "drawn down a level")
	assert_true(ObjectShapes.is_wall_mounted(Tiles.Block.CURTAINS_LONG_IRON_CLOSED_EAST))


func test_a_rug_lies_under_furniture_and_comes_back() -> void:
	var chunk := ChunkData.new(Vector2i.ZERO)
	var cell := Vector3i(3, SEA, 4)
	chunk.set_voxel(cell, ChunkData.RUG)
	chunk.tints[cell] = Tints.pack(2, -1)
	chunk.set_voxel(cell, Voxels.of_block(Tiles.Block.TABLE))
	assert_eq(chunk.rugs.get(cell, -1), Tints.pack(2, -1), "under the table, blue")
	assert_false(chunk.tints.has(cell))
	var copy := ChunkData.from_dict(chunk.to_dict())
	assert_eq(copy.rugs.size(), 1, "sent with the chunk")
	chunk.set_voxel(cell, Voxels.AIR)
	assert_eq(chunk.get_voxel(cell), ChunkData.RUG, "back when the table goes")
	assert_eq(chunk.tints.get(cell, 0), Tints.pack(2, -1), "in its color")
	assert_true(chunk.rugs.is_empty())
	chunk.set_voxel(cell, Voxels.AIR)
	assert_eq(chunk.get_voxel(cell), Voxels.AIR, "then it goes too")


func test_the_server_puts_furniture_on_a_rug() -> void:
	var cell := _start()
	_hold(Items.Id.RUG)
	_send(Msg.block_place(cell, 0, Vector2i(0, 1), Vector3i.UP))
	assert_eq(_server.world.voxel_at(cell), ChunkData.RUG, "a rug on the stone")
	_hold(Items.Id.RUG)
	_send(Msg.block_place(cell, 0, Vector2i(0, 1), Vector3i.UP))
	assert_eq(_session.inventory.counts[0], 1, "not a rug on a rug")
	_hold(Items.Id.CHEST)
	_send(Msg.block_place(cell, 0, Vector2i(0, 1), Vector3i.UP))
	assert_eq(
		ObjectShapes.kind_of(Voxels.block_of(_server.world.voxel_at(cell))), Tiles.Block.CHEST
	)
	_send(Msg.block_break(cell, -1))
	assert_eq(_server.world.voxel_at(cell), ChunkData.RUG, "the chest gone, the rug is there")
	var told := _client.poll().filter(
		func(m: Dictionary) -> bool: return m["t"] == Msg.BLOCK_CHANGED
	)
	assert_eq(told.back()["voxel"], ChunkData.RUG, "and the player is told so")
	_hold(Items.Id.TABLE)
	_send(Msg.block_place(cell, 0, Vector2i(0, 1), Vector3i.UP))
	assert_eq(_server.world.voxel_at(cell), Voxels.of_block(Tiles.Block.TABLE))
	_server.items.clear()
	_send(Msg.block_break(cell + Vector3i.DOWN, -1))
	assert_eq(_server.world.voxel_at(cell), Voxels.AIR, "its floor broken, both fall")
	var lying := _server.items.values().map(func(d: DroppedItem) -> int: return d.item)
	assert_true(Items.Id.TABLE in lying and Items.Id.RUG in lying, "and give themselves back")


## A chunk on stone with `cells` set (tinted by `tints`), built.
func _built(cells: Dictionary, tints: Dictionary) -> ChunkMesher.Result:
	var chunk := ChunkData.new(Vector2i.ZERO)
	for lz in GameConst.CHUNK_SIZE:
		for lx in GameConst.CHUNK_SIZE:
			chunk.set_voxel(Vector3i(lx, SEA - 1, lz), Voxels.of_block(Tiles.Block.STONE))
	for cell: Vector3i in cells:
		chunk.set_voxel(cell, cells[cell])
		if tints.has(cell):
			chunk.tints[cell] = tints[cell]
	chunk.recompute_tops()
	var job := ChunkJob.of_chunk(chunk, func(_c: Vector2i) -> ChunkData: return null)
	job.variants.resize(Tiles.Block.size())
	job.variants[Tiles.Block.RUG] = ObjectShapes.FENCE_VARIANTS
	job.variants[Tiles.Block.TABLE] = 1
	return ChunkMesher.build(job)


func test_rugs_join_those_of_their_color() -> void:
	var rug := ChunkData.RUG
	var red := Tints.pack(0, -1)
	var cells := {
		Vector3i(4, SEA, 4): rug,
		Vector3i(5, SEA, 4): rug,
		Vector3i(6, SEA, 4): rug,
		Vector3i(10, SEA, 4): rug,
	}
	var tints := {Vector3i(4, SEA, 4): red, Vector3i(5, SEA, 4): red}
	var result := _built(cells, tints)
	var versions := {}
	var dyed := 0
	for key: Vector2i in result.props:
		if key.x == Tiles.Block.RUG:
			versions[key.y] = versions.get(key.y, 0) + result.props[key].size()
			for prop: Array in result.props[key]:
				if (prop[1] as Color).a >= ChunkProps.DYED:
					dyed += 1
					assert_almost((prop[1] as Color).r, Tints.color(0).r, 0.001, "its color")
	# North 1, east 2, south 4, west 8.
	assert_eq(versions.get(2, 0), 1, "the west red one joins east")
	assert_eq(versions.get(8, 0), 1, "the east red one joins west")
	assert_eq(versions.get(0, 0), 2, "the plain one and the lone one: alone")
	assert_eq(dyed, 2, "the red ones are dyed")
	# A rug under a table still joins and is drawn.
	var chunk := ChunkData.new(Vector2i.ZERO)
	for c: Vector3i in [Vector3i(4, SEA, 4), Vector3i(5, SEA, 4), Vector3i(6, SEA, 4)]:
		chunk.set_voxel(c, rug)
		chunk.tints[c] = red
	chunk.set_voxel(Vector3i(6, SEA, 4), Voxels.of_block(Tiles.Block.TABLE))
	assert_eq(chunk.rugs.get(Vector3i(6, SEA, 4), -1), red)
	var job := ChunkJob.of_chunk(chunk, func(_c: Vector2i) -> ChunkData: return null)
	assert_eq(job.rugs.size(), 1, "the build knows it")


func test_the_recipes() -> void:
	var w := Items.Id.WOOL
	var l := Items.Id.LINEN
	var rugs := Recipes.result_of(PackedInt32Array([w, l, N, N, N, N, N, N, N]), 3)
	assert_eq(rugs, Vector2i(Items.Id.RUG, 3))
	var s := Items.Id.STICK
	var i := Items.Id.IRON_INGOT
	var iron := Recipes.result_of(PackedInt32Array([i, i, i, w, N, w, w, N, w]), 3)
	assert_eq(iron, Vector2i(Items.Id.CURTAINS_IRON, 2))
	var grid := PackedInt32Array()
	grid.resize(25)
	grid.fill(N)
	for at: int in [0, 1, 2, 5, 7, 10, 12, 15, 17]:
		grid[at] = s if at < 3 else w
	assert_eq(Recipes.result_of(grid, 5), Vector2i(Items.Id.CURTAINS_LONG, 1), "at the workbench")
	for item: int in [Items.Id.CURTAINS_LONG, Items.Id.CURTAINS_LONG_IRON, Items.Id.RUG]:
		assert_true(Tints.dyed(Voxels.block_of(Items.placed_voxel(item))), "dyed")
		assert_true(Tints.tintable(Voxels.block_of(Items.placed_voxel(item))))
	var drawn := ObjectShapes.facing(Tiles.Block.CURTAINS_LONG_CLOSED, Vector2i(1, 0))
	assert_eq(Items.item_placing(ObjectShapes.base_kind(drawn)), Items.Id.CURTAINS_LONG, "drawn")
	assert_eq(ObjectShapes.swung(drawn), Tiles.Block.CURTAINS_LONG_EAST)
